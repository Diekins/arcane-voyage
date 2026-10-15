class_name SystemProviders
## SystemProviders — os PROVEDORES dos sistemas de poder para o SystemPanel genérico (FATIA A7, PARTE VII/IX).
##
## ★ MOLDE REPETÍVEL (§4/§5): cada sistema é um PROVIDER com o MESMO contrato. O SystemPanel NÃO conhece regra
## interna de CP (§SYS-T04) — só pergunta ao provider. Adicionar um 7º sistema = escrever um provider (DADO),
## não copiar o painel (§SYS-T05). Todos os providers derivam de `Base`.
##
## CONTRATO (duck-typed):
##   sys_id() · sys_name() · sys_desc() · resource_text() · has_available_action() (badge)
##   rows() -> [{label, detail, action_id, action_label, can_act, projected_cp}]
##   do_action(action_id) -> bool   (executa a linha; NÃO auto-equipa — §9)

static func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null

# ══════════════════════════════════════════════════════════════════════════════════════════════════
class Base extends RefCounted:
	var host = null
	var bestiary = null
	var codex = null
	func bind(h, b = null, c = null) -> void:
		host = h; bestiary = b; codex = c
	func gs():
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			return (loop as SceneTree).root.get_node_or_null("GameState")
		return null
	# defaults (viram override nos concretos)
	func sys_id() -> String: return "?"
	func sys_name() -> String: return "?"
	func sys_desc() -> String: return ""
	func resource_text() -> String:
		var g = gs()
		return "Fragmentos: %d" % (int(g.fragments()) if g != null else 0)
	func has_available_action() -> bool: return false
	func rows() -> Array: return []
	func do_action(_action_id: String) -> bool: return false
	# projeção PURA de CP mudando `field` (Dictionary de níveis) na chave `key` p/ `val`; restaura sem persistir.
	func _project_dict(field: Dictionary, key: String, val) -> int:
		var cp_now: int = PowerBudget.cp()
		var had := field.has(key)
		var old = field.get(key, null)
		field[key] = val
		var cp2: int = PowerBudget.cp()
		if had: field[key] = old
		else: field.erase(key)
		return cp2 - cp_now

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# REFINO — por slot (§ PARTE II). Linhas = slots com item equipado.
class RefineProvider extends Base:
	func sys_id() -> String: return "refine"
	func sys_name() -> String: return "Refino"
	func sys_desc() -> String: return "Reforça o equipamento de cada slot com Fragmentos. Permanente; segue o slot ao trocar o item."
	func has_available_action() -> bool:
		var g = gs()
		if g == null: return false
		for slot in ItemDB.SLOT_ORDER:
			if g.equipment.has(slot) and g.refine_can(slot) and _proj(slot) > 0:
				return true
		return false
	func _proj(slot: String) -> int:
		var g = gs()
		return _project_dict(g.slot_refinement, slot, int(g.refine_level(slot)) + 1)
	func rows() -> Array:
		var g = gs()
		var out: Array = []
		if g == null: return out
		for slot in ItemDB.SLOT_ORDER:
			if not g.equipment.has(slot):
				continue
			var lvl := int(g.refine_level(slot))
			var maxed := RefineMath.is_max(lvl)
			# FATIA A7.1: TRANSPARÊNCIA (§57/§58) — chance base/pity/final + consequência da falha no detalhe.
			var info: Dictionary = g.refine_attempt_info(slot)
			var det := "MÁX"
			if not maxed:
				det = "+%d → +%d · chance %d%% (base %d%% · pity +%d%%)" % [lvl, lvl + 1,
					int(round(float(info["final_chance"]) * 100.0)), int(round(float(info["base_chance"]) * 100.0)), int(round(float(info["pity"]) * 100.0))]
				if bool(info["fails_downgrade"]):
					det += " · falha: -1 nível"
			# A24.3 — se não está no máximo mas faltam Fragmentos p/ a próxima, expõe a fonte (COMO OBTER → SALVAGE).
			var cost: int = g.refine_cost_next(slot)
			var short_frag: bool = (not maxed) and int(g.fragments()) < cost
			out.append({
				"label": "%s (%s)  +%d" % [str(ItemDB.SLOT_LABEL.get(slot, slot)), ItemDB.display_name(str(g.equipment[slot])), lvl],
				"detail": det,
				"action_id": "refine:%s" % slot,
				"action_label": ("—" if maxed else "Tentar (%d Frag)" % cost),
				"can_act": g.refine_can(slot),
				"projected_cp": (0 if maxed else _proj(slot)),   # +CP no SUCESSO (§61: não finge garantia)
				"acquire_hint": ({"item_key": "Fragmentos", "desired": cost} if short_frag else {}),
			})
		return out
	func do_action(action_id: String) -> bool:
		# FATIA A7.1: a ação agora é a TENTATIVA com chance/risco (RNG). +0..+4 são 100% (igual ao antigo).
		if not action_id.begins_with("refine:"): return false
		var res: Dictionary = gs().refine_attempt(action_id.substr(7))
		return bool(res.get("ok", false))

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# JOIAS — por tipo (§ PARTE III).
class JewelProvider extends Base:
	func sys_id() -> String: return "jewels"
	func sys_name() -> String: return "Joias"
	func sys_desc() -> String: return "Lapida joias (Rubi/Safira/Esmeralda) que somam dano, defesa e vida reais."
	func has_available_action() -> bool:
		var g = gs()
		if g == null: return false
		for jt in JewelMath.JEWEL_ORDER:
			if g.jewel_can(jt) and _proj(jt) > 0:
				return true
		return false
	func _proj(jt: String) -> int:
		var g = gs()
		return _project_dict(g.jewel_levels, jt, int(g.jewel_level(jt)) + 1)
	func rows() -> Array:
		var g = gs()
		var out: Array = []
		if g == null: return out
		for jt in JewelMath.JEWEL_ORDER:
			var lvl := int(g.jewel_level(jt))
			var maxed := JewelMath.is_max(lvl)
			out.append({
				"label": "%s  +%d" % [JewelMath.display_name(jt), lvl],
				"detail": ("MÁX" if maxed else "+%d → +%d" % [lvl, lvl + 1]),
				"action_id": "jewel:%s" % jt,
				"action_label": ("—" if maxed else "Lapidar (%d Frag)" % g.jewel_cost_next(jt)),
				"can_act": g.jewel_can(jt),
				"projected_cp": (0 if maxed else _proj(jt)),
			})
		return out
	func do_action(action_id: String) -> bool:
		if not action_id.begins_with("jewel:"): return false
		return gs().jewel_do(action_id.substr(6))

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# BESTIÁRIO (§ PARTE V) — 1 linha: reivindicar todos os tiers.
class BestiaryProvider extends Base:
	func sys_id() -> String: return "bestiary"
	func sys_name() -> String: return "Bestiário"
	func sys_desc() -> String: return "Abater cada mob acumula tiers. Reivindique para ganhar dano e vida reais."
	func resource_text() -> String:
		return bestiary.status_text() if bestiary != null else ""
	func has_available_action() -> bool:
		return bestiary != null and bestiary.has_available_action()
	func rows() -> Array:
		if bestiary == null: return []
		var pend := int(bestiary.claimable_total())
		return [{
			"label": "Almas registradas",
			"detail": ("%d tier(s) a coletar" % pend if pend > 0 else "sem coleta agora"),
			"action_id": "claim",
			"action_label": ("REIVINDICAR (%d)" % pend if pend > 0 else "—"),
			"can_act": pend > 0,
			"projected_cp": int(bestiary.projected_cp_gain()),
		}]
	func do_action(action_id: String) -> bool:
		if action_id != "claim" or bestiary == null: return false
		return bestiary.claim_all() > 0

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# CÓDICE DE ITENS (§ PARTE VI) — 1 linha: reivindicar marcos.
class CodexProvider extends Base:
	func sys_id() -> String: return "codex"
	func sys_name() -> String: return "Códice"
	func sys_desc() -> String: return "Descobrir itens diferentes libera marcos de coleção com bônus reais."
	func resource_text() -> String:
		return codex.status_text() if codex != null else ""
	func has_available_action() -> bool:
		return codex != null and codex.has_available_action()
	func rows() -> Array:
		if codex == null: return []
		var pend := int(codex.claimable())
		return [{
			"label": "Coleção de itens",
			"detail": ("%d marco(s) a coletar" % pend if pend > 0 else "próximo em %d item(ns)" % int(codex.to_next_milestone())),
			"action_id": "claim",
			"action_label": ("REIVINDICAR (%d)" % pend if pend > 0 else "—"),
			"can_act": pend > 0,
			"projected_cp": int(codex.projected_cp_gain()),
		}]
	func do_action(action_id: String) -> bool:
		if action_id != "claim" or codex == null: return false
		return codex.claim() > 0

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# EQUIPAMENTO (§ PARTE I) — resumo + melhor upgrade; NÃO auto-equipa (§9): a ação ABRE o inventário real.
class EquipmentProvider extends Base:
	func sys_id() -> String: return "equipment"
	func sys_name() -> String: return "Equipamento"
	func sys_desc() -> String: return "Seu equipamento atual e o melhor upgrade guardado na mochila."
	func resource_text() -> String:
		return "Poder atual: %d" % PowerBudget.cp()
	func _best() -> Dictionary:
		var sug: Array = PowerAdvisor.suggest(1)
		if not sug.is_empty() and str(sug[0].get("kind", "")) == "equip":
			return sug[0]
		return {}
	func has_available_action() -> bool:
		var b := _best()
		return not b.is_empty() and int(b.get("estimated_cp_gain", 0)) > 0
	func rows() -> Array:
		var b := _best()
		if b.is_empty():
			return [{"label": "Equipamento", "detail": "sem upgrade guardado", "action_id": "open", "action_label": "Abrir inventário", "can_act": true, "projected_cp": 0}]
		return [{
			"label": str(b.get("label", "Upgrade")),
			"detail": "equipar na mochila",
			"action_id": "open",
			"action_label": "Abrir inventário",
			"can_act": true,
			"projected_cp": int(b.get("estimated_cp_gain", 0)),
		}]
	func do_action(action_id: String) -> bool:
		if action_id != "open": return false
		if host != null and host.has_method("idlehud_open_inventory"):
			host.idlehud_open_inventory()
		return true

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# MAESTRIA (§ PARTE IV) — SÓ LEITURA: sobe por USO, sem botão "MELHORAR" inventado (§31/§MAS-T03).
class MasteryProvider extends Base:
	func sys_id() -> String: return "mastery"
	func sys_name() -> String: return "Maestria"
	func sys_desc() -> String: return "Sobe usando a arma/estilo ativo. Já alimenta o dano no combate."
	func resource_text() -> String:
		var g = gs()
		if g == null: return ""
		return "Arma ativa: %s" % g.current_combat_archetype()
	func has_available_action() -> bool:
		return false   # sem ação manual (§32) → sem badge artificial
	func rows() -> Array:
		var g = gs()
		var out: Array = []
		if g == null: return out
		# proficiência da arma ativa (real) + maestrias de classe existentes — só leitura.
		var arch := str(g.current_combat_archetype())
		var pe: Variant = g.proficiency.get(arch, {})   # leitura SEM efeito colateral (não usa vocation_level/_ensure_voc)
		var lvl := int((pe as Dictionary).get("level", 1)) if pe is Dictionary else 1
		out.append({
			"label": "Proficiência (%s)" % arch,
			"detail": "Nível %d — continue usando esta arma" % lvl,
			"action_id": "", "action_label": "", "can_act": false, "projected_cp": 0,
		})
		return out
	func do_action(_action_id: String) -> bool:
		return false
