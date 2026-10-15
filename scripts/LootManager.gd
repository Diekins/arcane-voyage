class_name LootManager extends Node
## LootManager — SUSTENTABILIDADE DE LOOT / INVENTÁRIO IDLE / SINK SEGURO (FATIA A3.5).
##
## PROBLEMA: o AutoPlay mata para sempre → drops sem parar → a mochila (equipáveis não-stackáveis) crescia
## SEM LIMITE (não havia capacidade). A3.5 torna o loot sustentável para farmar horas SEM o jogador ter de
## abrir a mochila — sem NUNCA destruir algo potencialmente útil.
##
## ★ POLÍTICA (§6): PRESERVAR PRIMEIRO, DESCARTAR DEPOIS. Nunca auto-salvage de: equipado · locked · id
## desconhecido · UPGRADE (projected CP > atual, via PowerBudget) · item de slot ainda vazio (é upgrade).
## Só vira salvage o equipamento CLARAMENTE INFERIOR e seguro (projected CP ≤ atual).
##
## SEPARAÇÃO: usa o inventário REAL (_gs().backpack/materials/equipment) — SEM 2ª fonte. O recurso de
## salvage é "Fragmentos" no dict `materials` já existente (§13-Opção-3; UM único recurso novo, §14),
## preparado p/ refino/códice futuros (A7).
##
## NÃO é A7 (refino/códice/crafting) nem a A5 (baú AFK). É só a fundação de sustentabilidade.

signal item_salvaged(item_id: String)
signal item_discovered(item_id: String)   # 1ª vez que um id é visto na sessão (prepara Códice — §31)

const LOOT_DEBUG := true

# ── POLÍTICA (LootPolicy — §40; sem números mágicos espalhados) ──
const BACKPACK_CAPACITY := 30       # slots de mochila (entradas; stack = 1 slot). Antes: ILIMITADO.
const OVERFLOW_CAP := 20            # buffer de segurança p/ itens protegidos/upgrade que não couberam
const AUTO_SALVAGE := true          # ON só p/ equipamento CLARAMENTE INFERIOR e SEGURO (§17)
const PRESERVE_UPGRADES := true
const SALVAGE_RESOURCE := "Fragmentos"   # PT-BR, recurso neutro; vive em _gs().materials
const FRAGMENT_FACTOR := 0.5        # escala conservadora (§16) sobre o sell_value existente
const RARITY_MULT := {"common": 1.0, "uncommon": 1.6, "rare": 3.0, "epic": 5.0, "legendary": 8.0}

# ── Classificação (§11) ──
enum Cls { PROTECTED, UPGRADE, KEEP, STACKABLE, SALVAGEABLE, UNKNOWN }

# ── Telemetria RUNTIME (não persiste) ──
var loot_received := 0
var loot_kept := 0
var loot_upgrades := 0
var loot_salvaged := 0
var overflow_added := 0
var overflow_recovered := 0
var loot_rejected := 0
var salvage_generated := 0

var _seen: Dictionary = {}          # ids já vistos nesta sessão (dedup do sinal item_discovered)

func setup(_host = null) -> void:
	pass

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# ENTRADA PRINCIPAL — um item de loot chegou (id do catálogo). Materiais por NOME (não-id) são tratados
# fora daqui (dict materials, já sustentável). qty>1 só p/ stackáveis.
# ══════════════════════════════════════════════════════════════════════════════════════════════════
func receive_loot(id: String, qty: int = 1) -> void:
	if qty <= 0:
		return
	loot_received += qty
	_discover(id)
	# id desconhecido → PROTEGIDO (nunca salvage; §7). Vai ao overflow (não entra na mochila real).
	if not ItemDB.exists(id):
		_to_overflow(id, qty)
		return
	# STACKÁVEL (consumível/poção): empilha — nunca estoura slot.
	if ItemDB.is_stackable(id):
		_gs().backpack_add_silent(id, qty)
		loot_kept += qty
		return
	# EQUIPÁVEL / não-stackável: processa unidade a unidade (drops normais são qty 1).
	for i in range(qty):
		_receive_one_gear(id)
	_drain_overflow()

## FATIA A5 — recebe um LOTE de loot (do claim do baú AFK). Cada item passa pela MESMA política (stack /
## preserve upgrade / salvage / overflow) — NÃO cria 2ª lógica de inventário. `items` = {id: qty} (equipáveis/
## consumíveis do catálogo); `materials` = {nome: qty} (materiais por nome). NÃO salva por item (silencioso).
func receive_batch(items: Dictionary, materials: Dictionary = {}) -> void:
	for id in items:
		receive_loot(str(id), int(items[id]))
	for nm in materials:
		var q := int(materials[nm])
		if str(nm) != "" and q > 0:
			_gs().add_material_silent(str(nm), q)

func _receive_one_gear(id: String) -> void:
	var cls := classify(id)
	# INFERIOR e SEGURO → auto-salvage direto (não ocupa slot). É o coração da sustentabilidade.
	if cls == Cls.SALVAGEABLE and AUTO_SALVAGE:
		_salvage_new(id)
		return
	# KEEP / UPGRADE / PROTECTED → precisa de slot.
	if _gs().backpack_slots_used() < BACKPACK_CAPACITY:
		_gs().backpack_add_silent(id, 1)
		loot_kept += 1
		if cls == Cls.UPGRADE:
			loot_upgrades += 1
		return
	# MOCHILA CHEIA (§21): tenta abrir espaço salvando um candidato INFERIOR seguro do inventário.
	if _make_room():
		_gs().backpack_add_silent(id, 1)
		loot_kept += 1
		if cls == Cls.UPGRADE:
			loot_upgrades += 1
		return
	# Sem candidato seguro p/ liberar → o item (protegido/upgrade) vai ao OVERFLOW (nunca some, §22).
	_to_overflow(id, 1)

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# CLASSIFICAÇÃO (§11) — decisão explícita e testável.
# ══════════════════════════════════════════════════════════════════════════════════════════════════
func classify(id: String) -> int:
	if not ItemDB.exists(id):
		return Cls.UNKNOWN            # desconhecido → protegido
	if _gs().is_item_locked(id):
		return Cls.PROTECTED
	if _gs().is_item_equipped(id):
		return Cls.PROTECTED
	if ItemDB.is_stackable(id):
		return Cls.STACKABLE
	if ItemDB.is_equippable(id):
		if PRESERVE_UPGRADES and _is_upgrade(id):
			return Cls.UPGRADE       # projected CP > atual (inclui slot vazio → sempre upgrade → preservado, §19)
		return Cls.SALVAGEABLE       # equipamento inferior/duplicado, seguro
	return Cls.KEEP                  # não-equipável sem stack (misc/uso especial) → preserva por segurança

## Equipar este item elevaria o CP acima do MELHOR que o jogador JÁ GUARDA para aquele slot? (SIM = upgrade
## potencial → NUNCA auto-salvage, §9). Comparar com o melhor-guardado (equipado OU já na mochila) faz a
## 2ª cópia de um upgrade virar SALVAGEABLE (§20: preserva UMA, excedente pode salvage). Simulação PURA
## (snapshot/restore) — não equipa de verdade, não toca save/inventário/stage/CP.
func _is_upgrade(id: String) -> bool:
	var slot := ItemDB.slot_of(id)
	if slot == "":
		return false
	return _projected_cp_with(id) > _best_kept_cp_for_slot(slot)

## CP projetado equipando `id` no seu slot (sobre o equipamento atual).
func _projected_cp_with(id: String) -> int:
	var slot := ItemDB.slot_of(id)
	var cand: Dictionary = _gs().equipment.duplicate()
	cand[slot] = id
	return int(PowerAdvisor.project_equipment(cand)["projected_cp"])

## Melhor CP alcançável para `slot` com o que o jogador JÁ TEM (equipado atual + cada item do slot na mochila).
func _best_kept_cp_for_slot(slot: String) -> int:
	var best := PowerBudget.cp()   # manter o equipado atual (baseline)
	for e in _gs().backpack:
		var bid := str(e.get("id", ""))
		if ItemDB.slot_of(bid) == slot:
			best = maxi(best, _projected_cp_with(bid))
	return best

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# SALVAGE (§13-Opção-3 / §15) — equipamento inferior → Fragmentos (recurso neutro em `materials`).
# ══════════════════════════════════════════════════════════════════════════════════════════════════
## Valor de salvage (data-driven, sem nome textual): sell_value existente × raridade × fator conservador.
func salvage_value(id: String) -> int:
	if not ItemDB.exists(id):
		return 0
	var base := maxi(1, ItemDB.sell_value(id))
	var mult: float = RARITY_MULT.get(ItemDB.rarity(id), 1.0)
	return maxi(1, int(round(float(base) * mult * FRAGMENT_FACTOR)))

## O item é elegível a salvage AGORA? (equipável, existe, não locked/equipado). Usado por SalvageSystem/tests.
func is_salvageable(id: String) -> bool:
	return ItemDB.exists(id) and ItemDB.is_equippable(id) and not _gs().is_item_locked(id) and not _gs().is_item_equipped(id)

## Salvage de um item NOVO (ainda não na mochila): só credita Fragmentos.
func _salvage_new(id: String) -> void:
	var v := salvage_value(id)
	_gs().add_material_silent(SALVAGE_RESOURCE, v)
	salvage_generated += v
	loot_salvaged += 1
	item_salvaged.emit(id)

## Salvage de um item que ESTÁ na mochila: remove 1 unidade + credita Fragmentos. Retorna se removeu.
func _salvage_from_backpack(id: String) -> bool:
	if not _gs().backpack_remove_one_silent(id):
		return false
	var v := salvage_value(id)
	_gs().add_material_silent(SALVAGE_RESOURCE, v)
	salvage_generated += v
	loot_salvaged += 1
	item_salvaged.emit(id)
	return true

## A25.4 — SALVAGE MANUAL player-facing: o jogador escolhe desmontar UM item da mochila. AUTHORITY: valida iid/posse/
## proteção (is_salvageable já barra locked/equipado/não-equipável/inexistente) e usa a MESMA fórmula (salvage_value,
## single truth). Exact-once via backpack_remove_one_silent. Retorna {ok, yield, reason}.
func manual_salvage(id: String) -> Dictionary:
	if not is_salvageable(id):
		return {"ok": false, "yield": 0, "reason": "nao_salvageavel"}
	if _gs().backpack_count(id) <= 0:
		return {"ok": false, "yield": 0, "reason": "nao_possui"}
	var v := salvage_value(id)
	if not _salvage_from_backpack(id):
		return {"ok": false, "yield": 0, "reason": "remove_falhou"}
	_gs().save_game()
	return {"ok": true, "yield": v, "reason": ""}

## Itens da mochila elegíveis a salvage manual (para a UI listar). [{id, qty, yield}]
func salvageable_backpack() -> Array:
	var out: Array = []
	var seen := {}
	for e in _gs().backpack:
		var id := str(e.get("id", ""))
		if id == "" or seen.has(id): continue
		seen[id] = true
		if is_salvageable(id):
			out.append({"id": id, "qty": int(_gs().backpack_count(id)), "yield": salvage_value(id)})
	return out

## Abre 1 slot salvando o PRIMEIRO candidato SALVAGEABLE da mochila (inferior/duplicado seguro). Retorna sucesso.
func _make_room() -> bool:
	for e in _gs().backpack:
		var id := str(e.get("id", ""))
		if classify(id) == Cls.SALVAGEABLE:
			return _salvage_from_backpack(id)
	return false

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# OVERFLOW (§23-25) — buffer de segurança; nunca perde item protegido silenciosamente.
# ══════════════════════════════════════════════════════════════════════════════════════════════════
func _to_overflow(id: String, qty: int) -> void:
	for i in range(qty):
		if _gs().overflow_count() < OVERFLOW_CAP:
			_gs().overflow_push(id, 1)
			overflow_added += 1
		else:
			# Overflow cheio (§24): 1) o próprio item, se for salvageable seguro, vira salvage; 2) senão,
			# tenta salvar um item INFERIOR do overflow p/ abrir espaço; 3) senão, rejeita com log de integridade.
			if classify(id) == Cls.SALVAGEABLE:
				_salvage_new(id)
			elif _salvage_worst_overflow():
				_gs().overflow_push(id, 1)
				overflow_added += 1
			else:
				loot_rejected += 1
				push_warning("[LootManager] INTEGRIDADE: overflow cheio de itens protegidos — item '%s' rejeitado (sem perda de quest/key: não há neste fluxo)." % id)

## Salva o pior (salvageable) item do overflow p/ abrir espaço. Retorna se abriu.
func _salvage_worst_overflow() -> bool:
	for idx in range(_gs().loot_overflow.size()):
		var id := str(_gs().loot_overflow[idx].get("id", ""))
		if classify(id) == Cls.SALVAGEABLE:
			var q := int(_gs().loot_overflow[idx].get("qty", 1)) - 1
			if q <= 0:
				_gs().loot_overflow.remove_at(idx)
			else:
				_gs().loot_overflow[idx]["qty"] = q
			_salvage_new(id)
			return true
	return false

## Público (§25): drena o overflow quando espaço abrir (ex.: jogador vendeu/usou item, ou ação COLETAR).
func drain_overflow() -> void:
	_drain_overflow()

## Drena o overflow p/ a mochila enquanto houver espaço (§25). Chamado após liberar espaço.
func _drain_overflow() -> void:
	while _gs().overflow_count() > 0 and _gs().backpack_slots_used() < BACKPACK_CAPACITY:
		var e: Dictionary = _gs().overflow_pop()
		if e.is_empty():
			break
		var id := str(e.get("id", ""))
		var qn := int(e.get("qty", 1))
		if ItemDB.exists(id):
			_gs().backpack_add_silent(id, 1)
			overflow_recovered += 1
			# se a entrada do overflow tinha qty>1, devolve o resto ao overflow
			if qn > 1:
				_gs().overflow_push(id, qn - 1)
		# id inválido é descartado do overflow (não deveria ocorrer — validado no load)

# ── Descoberta (prepara Códice — §31; NÃO constrói painel) ──
func _discover(id: String) -> void:
	if id == "" or _seen.has(id):
		return
	_seen[id] = true
	item_discovered.emit(id)

# ── HUD/telemetria ──
func status_text() -> String:
	return "MOCHILA %d/%d · %s %d · OVERFLOW %d/%d" % [
		_gs().backpack_slots_used(), BACKPACK_CAPACITY,
		SALVAGE_RESOURCE, int(_gs().materials.get(SALVAGE_RESOURCE, 0)),
		_gs().overflow_count(), OVERFLOW_CAP]

func telemetry() -> Dictionary:
	return {
		"loot_received": loot_received, "loot_kept": loot_kept, "loot_upgrades": loot_upgrades,
		"loot_salvaged": loot_salvaged, "overflow_added": overflow_added, "overflow_recovered": overflow_recovered,
		"loot_rejected": loot_rejected, "salvage_generated": salvage_generated,
	}

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# FATIA A7.1 — LOOT DE ITEM INSTANCE. Cópias do MESMO item_id podem ter valor DIFERENTE (§25/§26): a
# classificação/upgrade compara CP da INSTÂNCIA, não item_id==item_id. God roll NUNCA é auto-salvage (§27).
# ══════════════════════════════════════════════════════════════════════════════════════════════════
const INSTANCE_BAG_CAP := 30                 # capacidade da bolsa de instâncias equipáveis
const OVERFLOW_INST_CAP := 20
const HIGH_QUALITY_PROTECT := 95             # quality >= 95 → PROTEGIDA pela política (§27/§ILOOT-T05)
const SALVAGE_QUALITY_MIN := 0.7             # fator de salvage por qualidade (0.7..1.3); god roll NÃO vira milhões (§31)

var _roll_seq := 0                           # contador p/ seed de roll ONLINE (offline usa seed determinística)

## Drop de mundo ONLINE: EQUIPÁVEL → vira ItemInstance com rolls; o resto segue a rota base (stack/material).
func receive_world_drop(id: String) -> void:
	if ItemDB.is_equippable(id):
		_roll_seq += 1
		var inst := ItemRoller.roll(id, hash("online|%s|%d" % [id, _roll_seq]), "loot")
		if not inst.is_empty():
			receive_instance(inst)
			return
	receive_loot(id, 1)

## Recebe uma ItemInstance (drop online já rolado OU claim offline determinístico). Classifica por CP de
## INSTÂNCIA; descobre no Códice por item_id BASE (§30). Preserva-primeiro: nunca some com upgrade/god roll/locked.
func receive_instance(inst: Dictionary) -> void:
	if inst.is_empty():
		return
	loot_received += 1
	var base_id := ItemInstance.base_item_id(inst)
	_gs().codex_discover(base_id)            # descoberta por item_id BASE (§30)
	item_discovered.emit(base_id)
	var cls := classify_instance(inst)
	if cls == Cls.SALVAGEABLE and AUTO_SALVAGE:
		_salvage_instance_new(inst)
		return
	if _gs().item_instances.size() < INSTANCE_BAG_CAP:
		_gs().instance_add(inst); loot_kept += 1
		if cls == Cls.UPGRADE: loot_upgrades += 1
		return
	if _make_room_instances():
		_gs().instance_add(inst); loot_kept += 1
		if cls == Cls.UPGRADE: loot_upgrades += 1
		return
	_to_overflow_instance(inst)

func receive_instances(list: Array) -> void:
	for inst in list:
		if inst is Dictionary:
			receive_instance(inst)

## Classifica uma instância (§26/§27). PROTECTED = locked-por-iid OU qualidade excepcional; UPGRADE = CP de
## instância > melhor guardado no slot; senão SALVAGEABLE (inferior seguro).
func classify_instance(inst: Dictionary) -> int:
	var iid := str(inst.get("iid", ""))
	if _gs().is_instance_locked(iid):
		return Cls.PROTECTED
	if ItemInstance.quality(inst) >= HIGH_QUALITY_PROTECT:
		return Cls.PROTECTED            # god roll preservado pela política (§27)
	if _is_upgrade_instance(inst):
		return Cls.UPGRADE
	return Cls.SALVAGEABLE

## CP projetado equipando ESTA instância no seu slot (snapshot/restore do overlay; sem tocar save).
func _project_instance_cp(inst: Dictionary) -> int:
	var base_id := ItemInstance.base_item_id(inst)
	var slot := ItemDB.slot_of(base_id)
	if slot == "":
		return 0
	var gs = _gs()
	var had_e: bool = gs.equipment.has(slot)
	var old_e = gs.equipment.get(slot, null)
	var had_i: bool = gs.equipped_instances.has(slot)
	var old_i = gs.equipped_instances.get(slot, null)
	gs.equipment[slot] = base_id
	gs.equipped_instances[slot] = inst
	var cp: int = PowerBudget.cp()
	# restaura
	if had_i: gs.equipped_instances[slot] = old_i
	else: gs.equipped_instances.erase(slot)
	if had_e: gs.equipment[slot] = old_e
	else: gs.equipment.erase(slot)
	return cp

## Melhor CP alcançável no slot com o que o jogador JÁ TEM (equipado atual + instâncias guardadas do slot).
func _best_kept_cp_instance(slot: String) -> int:
	var best: int = PowerBudget.cp()   # manter o equipado atual
	for inst in _gs().item_instances:
		if ItemDB.slot_of(ItemInstance.base_item_id(inst)) == slot:
			best = maxi(best, _project_instance_cp(inst))
	return best

func _is_upgrade_instance(inst: Dictionary) -> bool:
	var slot := ItemDB.slot_of(ItemInstance.base_item_id(inst))
	if slot == "":
		return false
	return _project_instance_cp(inst) > _best_kept_cp_instance(slot)

## Salvage de instância → Fragmentos. Considera sell_value base × raridade × fator de qualidade MODERADO (§31):
## god roll vale mais no MERCADO (market_score), não no triturador.
func salvage_value_instance(inst: Dictionary) -> int:
	var base_id := ItemInstance.base_item_id(inst)
	var base := maxi(1, ItemDB.sell_value(base_id))
	var mult: float = RARITY_MULT.get(ItemDB.rarity(base_id), 1.0)
	var qf := SALVAGE_QUALITY_MIN + (ItemInstance.quality(inst) / 100.0) * 0.6   # 0.7..1.3
	return maxi(1, int(round(float(base) * mult * FRAGMENT_FACTOR * qf)))

func _salvage_instance_new(inst: Dictionary) -> void:
	var v := salvage_value_instance(inst)
	_gs().add_material_silent(SALVAGE_RESOURCE, v)
	salvage_generated += v; loot_salvaged += 1
	item_salvaged.emit(ItemInstance.base_item_id(inst))

## Abre 1 espaço na bolsa salvando a PIOR instância SALVAGEABLE guardada. Retorna sucesso.
func _make_room_instances() -> bool:
	for i in range(_gs().item_instances.size()):
		var inst: Dictionary = _gs().item_instances[i]
		if classify_instance(inst) == Cls.SALVAGEABLE:
			_gs().item_instances.remove_at(i)
			_salvage_instance_new(inst)
			return true
	return false

## Overflow de instância (§29) — preserva a INSTÂNCIA COMPLETA; nunca só o item_id.
func _to_overflow_instance(inst: Dictionary) -> void:
	if _gs().overflow_instances.size() < OVERFLOW_INST_CAP:
		_gs().overflow_instances.append(inst)
		overflow_added += 1
	elif classify_instance(inst) == Cls.SALVAGEABLE:
		_salvage_instance_new(inst)
	else:
		loot_rejected += 1
		push_warning("[LootManager] INTEGRIDADE: overflow de instâncias cheio de protegidas — '%s' rejeitada." % ItemInstance.base_item_id(inst))

## Resolve o autoload GameState em RUNTIME (evita "Identifier not found" ao compilar sob `-s`, e funciona
## mesmo que o nó ainda não esteja na árvore).
func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null
