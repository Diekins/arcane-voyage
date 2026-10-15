class_name AbilityResolution extends RefCounted
## FATIA A15/§13/§20-22 — RESOLVER puro de habilidade → eventos ESTRUTURADOS (damage/heal/shield/status/targets),
## pensado para a futura AUTHORITY de Arena (§13/§62 — o cliente nunca envia dano/cura/cooldown). Reusa a magnitude
## do CombatMath via `expected_damage` do caster (§14 — não cria 2º motor). HEAL (§20): não passa de max HP, não cura
## morto, sem negativo/NaN, sem resolução duplicada. SHIELD (§21): absorção temporária, NÃO altera max HP permanente.
## STATUS (§22): mínimo (slow/dot/hot/vuln/iframe/knockback). Determinístico.

## caster = {expected_damage:float, max_hp:int, current_hp:int, shield:int, alive:bool}
## targets = [{id, hp}] (para dano). Retorna eventos + cooldown.
static func resolve(ability: Dictionary, caster: Dictionary, targets: Array = []) -> Dictionary:
	var exp := maxf(0.0, float(caster.get("expected_damage", 0.0)))
	var max_hp := maxi(1, int(caster.get("max_hp", 1)))
	var cur := int(caster.get("current_hp", max_hp))
	var alive := bool(caster.get("alive", cur > 0))
	var dmg_events: Array = []
	var heal_events: Array = []
	var shield_events: Array = []
	var status_events: Array = []
	# DANO
	var dfactor := float(ability.get("damage", 0.0))
	if dfactor > 0.0:
		for t in targets:
			var amt := int(round(exp * dfactor))
			if amt > 0:
				dmg_events.append({"target": t.get("id", ""), "amount": amt})
	# CURA (§20)
	var hfactor := float(ability.get("heal", 0.0))
	if hfactor > 0.0 and alive:
		var raw := int(round(exp * hfactor))
		var applied := clampi(cur + maxi(0, raw), 0, max_hp) - cur   # nunca acima de max, nunca negativo
		if applied > 0:
			heal_events.append({"target": "self", "amount": applied})
	# ESCUDO (§21) — fração do max HP; NÃO altera max HP permanente
	var sfactor := float(ability.get("shield", 0.0))
	if sfactor > 0.0:
		var samt := int(round(float(max_hp) * sfactor))
		if samt > 0:
			shield_events.append({"target": "self", "amount": samt})
	# STATUS (§22)
	var st: Dictionary = ability.get("status", {})
	if not st.is_empty():
		status_events.append({"target": ("self" if str(ability.get("targeting", "")) == "SELF" else "targets"), "status": st.duplicate(true)})
	return {
		"ability_id": str(ability.get("ability_id", "")), "role": str(ability.get("role", "")),
		"damage_events": dmg_events, "heal_events": heal_events, "shield_events": shield_events,
		"status_events": status_events, "cooldown": float(ability.get("cooldown", 0.0)),
	}

## Aplica os eventos de cura/escudo a um estado de caster (mutável), respeitando as invariantes. Retorna o novo estado.
static func apply_self_events(caster: Dictionary, result: Dictionary) -> Dictionary:
	var s := caster.duplicate(true)
	var max_hp := maxi(1, int(s.get("max_hp", 1)))
	for h in result.get("heal_events", []):
		s["current_hp"] = clampi(int(s.get("current_hp", 0)) + int(h["amount"]), 0, max_hp)
	for sh in result.get("shield_events", []):
		s["shield"] = maxi(0, int(s.get("shield", 0)) + int(sh["amount"]))
	return s

## Absorção de dano pelo escudo (§21): ordem escudo→HP. Retorna {hp, shield}.
static func absorb(damage: int, hp: int, shield: int) -> Dictionary:
	var d := maxi(0, damage)
	var s := maxi(0, shield)
	var absorbed := mini(d, s)
	return {"hp": hp - (d - absorbed), "shield": s - absorbed}
