class_name PowerAdvisor
## PowerAdvisor — recomendações HONESTAS de como aumentar o CP (FATIA A3, V1 mínimo).
##
## O muro precisa dizer algo ÚTIL, mas a A7 (sistemas de poder) ainda não existe. Então este advisor só usa
## o que EXISTE e é COMPROVADO hoje (§28): (1) equipar item MELHOR já na mochila; (2) subir de nível (o
## level-up REAL soma +10 HP máx → mais CP). Se nada render, devolve um fallback honesto (§30) — NUNCA
## inventa "refine sua arma" / "melhore o pet" (não existem no Godot).
##
## ★ SIMULAÇÃO PURA (§29): nunca equipa/desequipa o personagem real nem salva. Faz snapshot em memória do
## `equipment`/`hero_hp_max`, calcula o CP projetado via PowerBudget, e RESTAURA. Sem side-effect no save.

## CP atual (real).
static func current_cp() -> int:
	return PowerBudget.cp()

## Projeta o CP para um `equipment` candidato (dicionário slot→item_id), SEM tocar o save.
static func project_equipment(candidate_equipment: Dictionary) -> Dictionary:
	var orig: Dictionary = _gs().equipment
	var before := PowerBudget.cp()
	_gs().equipment = candidate_equipment
	var after := PowerBudget.cp()
	_gs().equipment = orig   # restaura a referência original (candidate era uma cópia)
	return {"current_cp": before, "projected_cp": after, "delta_cp": after - before}

## FATIA A7.1 — projeta o CP equipando uma ItemInstance guardada, SEM tocar o save (compara CP de INSTÂNCIA, §25).
static func project_instance_equip(inst: Dictionary) -> Dictionary:
	var g = _gs()
	var slot := ItemDB.slot_of(ItemInstance.base_item_id(inst))
	if slot == "":
		return {"current_cp": PowerBudget.cp(), "projected_cp": PowerBudget.cp(), "delta_cp": 0}
	var before := PowerBudget.cp()
	var had_e: bool = g.equipment.has(slot); var old_e = g.equipment.get(slot, null)
	var had_i: bool = g.equipped_instances.has(slot); var old_i = g.equipped_instances.get(slot, null)
	g.equipment[slot] = ItemInstance.base_item_id(inst)
	g.equipped_instances[slot] = inst
	var after := PowerBudget.cp()
	if had_i: g.equipped_instances[slot] = old_i
	else: g.equipped_instances.erase(slot)
	if had_e: g.equipment[slot] = old_e
	else: g.equipment.erase(slot)
	return {"current_cp": before, "projected_cp": after, "delta_cp": after - before}

## Projeta o CP de subir UM nível (+10 HP máx real), SEM tocar o save.
static func project_level_up() -> Dictionary:
	var before := PowerBudget.cp()
	var orig_hp_max: int = _gs().hero_hp_max
	_gs().hero_hp_max = orig_hp_max + 10
	var after := PowerBudget.cp()
	_gs().hero_hp_max = orig_hp_max
	return {"current_cp": before, "projected_cp": after, "delta_cp": after - before}

## FATIA A7 — projeta o CP subindo o Refino de UM slot (+1), SEM tocar o save (snapshot/restore).
static func project_refine(slot: String) -> Dictionary:
	var g = _gs()
	var before := PowerBudget.cp()
	var had: bool = g.slot_refinement.has(slot)
	var old = g.slot_refinement.get(slot, null)
	g.slot_refinement[slot] = int(g.refine_level(slot)) + 1
	var after := PowerBudget.cp()
	if had: g.slot_refinement[slot] = old
	else: g.slot_refinement.erase(slot)
	return {"current_cp": before, "projected_cp": after, "delta_cp": after - before}

## FATIA A7 — projeta o CP lapidando UMA joia (+1), SEM tocar o save.
static func project_jewel(jewel_type: String) -> Dictionary:
	var g = _gs()
	var before := PowerBudget.cp()
	var had: bool = g.jewel_levels.has(jewel_type)
	var old = g.jewel_levels.get(jewel_type, null)
	g.jewel_levels[jewel_type] = int(g.jewel_level(jewel_type)) + 1
	var after := PowerBudget.cp()
	if had: g.jewel_levels[jewel_type] = old
	else: g.jewel_levels.erase(jewel_type)
	return {"current_cp": before, "projected_cp": after, "delta_cp": after - before}

## Localiza um nó gerenciador (Bestiário/Códice) na árvore (independe do path). null se ausente (tests parciais).
static func _find_node(nm: String):
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.find_child(nm, true, false)
	return null

## Lista de sugestões ordenadas por ganho de CP (desc). Cada item: {label, estimated_cp_gain, kind, system_id?,
## action_id?}. `max_items` limita. FATIA A7 (PowerAdvisor 2.0): compara EQUIPAR/Refino/Joia/claim-Bestiário/
## claim-Códice/nível. ★ Só entra ação EXECUTÁVEL (afford; §56) → ação impossível NUNCA vence o ranking (PAD-T06).
static func suggest(max_items: int = 3) -> Array:
	var out: Array = []
	var g = _gs()
	# (1) EQUIPAMENTO na mochila: para cada item equipável, simula equipar no seu slot e mede o delta.
	for entry in g.backpack:
		if not (entry is Dictionary):
			continue
		var id := str(entry.get("id", ""))
		var item := ItemDB.get_item(id)
		var slot := str(item.get("slot", ""))
		if slot == "":
			continue   # não-equipável (consumível/material)
		var cand: Dictionary = g.equipment.duplicate()
		cand[slot] = id
		var gain := int(project_equipment(cand)["delta_cp"])
		if gain > 0:
			out.append({"label": "Equipar %s" % str(item.get("name", id)), "estimated_cp_gain": gain, "kind": "equip", "system_id": "equipment"})
	# (1b) INSTÂNCIAS guardadas (A7.1): compara CP de INSTÂNCIA — duas cópias do mesmo item_id podem diferir (§25).
	for inst in g.item_instances:
		if not (inst is Dictionary):
			continue
		var ig := int(project_instance_equip(inst)["delta_cp"])
		if ig > 0:
			var nm := ItemDB.display_name(ItemInstance.base_item_id(inst))
			out.append({"label": "Equipar %s (Qualidade %d)" % [nm, ItemInstance.quality(inst)], "estimated_cp_gain": ig, "kind": "equip", "system_id": "equipment", "iid": str(inst.get("iid", ""))})
	# (2) REFINO — só slots equipados, abaixo do cap E COM Fragmentos (executável). FATIA A7.2 (§41):
	# RISK-ADJUSTED — não finge que o +CP é garantido; ranqueia por expected = chance × ganho_no_sucesso.
	for slot2 in ItemDB.SLOT_ORDER:
		if g.equipment.has(slot2) and g.refine_can(slot2):
			var rg := int(project_refine(slot2)["delta_cp"])   # ganho SE der sucesso
			if rg > 0:
				var lvl := int(g.refine_level(slot2))
				var chance: float = RefineMath.final_chance(lvl, g.refine_pity(slot2), 0.0)
				var cost: int = g.refine_cost_next(slot2)
				var expected := int(round(chance * float(rg)))   # valor esperado risk-adjusted
				out.append({"label": "Refinar %s +%d → +%d" % [str(ItemDB.SLOT_LABEL.get(slot2, slot2)), lvl, lvl + 1],
					"estimated_cp_gain": expected, "cp_gain_success": rg, "success_prob": chance, "kind": "refine",
					"system_id": "refine", "action_id": "refine:%s" % slot2, "cost": cost,
					"cp_per_fragment": (float(chance * float(rg)) / float(maxi(1, cost)))})
	# (3) JOIAS — só tipos abaixo do cap E COM Fragmentos.
	for jt in JewelMath.JEWEL_ORDER:
		if g.jewel_can(jt):
			var jg := int(project_jewel(jt)["delta_cp"])
			if jg > 0:
				out.append({"label": "Lapidar %s +%d → +%d" % [JewelMath.display_name(jt), g.jewel_level(jt), g.jewel_level(jt) + 1],
					"estimated_cp_gain": jg, "kind": "jewel", "system_id": "jewels", "action_id": "jewel:%s" % jt, "cost": g.jewel_cost_next(jt)})
	# (4) CLAIM BESTIÁRIO (sem custo; só se há tiers a coletar).
	var best = _find_node("BestiaryManager")
	if best != null and best.has_available_action():
		var bg := int(best.projected_cp_gain())
		out.append({"label": "Bestiário — reivindicar %d tier(s)" % int(best.claimable_total()), "estimated_cp_gain": bg, "kind": "bestiary", "system_id": "bestiary", "action_id": "claim"})
	# (5) CLAIM CÓDICE.
	var cdx = _find_node("ItemCodex")
	if cdx != null and cdx.has_available_action():
		var cg := int(cdx.projected_cp_gain())
		out.append({"label": "Códice — reivindicar %d marco(s)" % int(cdx.claimable()), "estimated_cp_gain": cg, "kind": "codex", "system_id": "codex", "action_id": "claim"})
	# (6) SUBIR DE NÍVEL (efeito real: +10 HP máx).
	var lvl := project_level_up()
	if int(lvl["delta_cp"]) > 0:
		out.append({"label": "Subir de nível (+10 HP máx)", "estimated_cp_gain": int(lvl["delta_cp"]), "kind": "level", "system_id": ""})
	out.sort_custom(func(a, b): return int(a["estimated_cp_gain"]) > int(b["estimated_cp_gain"]))
	if out.is_empty():
		return [{"label": "Continue farmando para subir de nível ou encontrar equipamento melhor.", "estimated_cp_gain": 0, "kind": "fallback", "system_id": ""}]
	if out.size() > max_items:
		out = out.slice(0, max_items)
	return out

## Resolve o autoload GameState em RUNTIME (funções static não enxergam o identificador global no compile).
static func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null
