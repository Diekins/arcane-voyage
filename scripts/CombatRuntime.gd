class_name CombatRuntime extends RefCounted
## FATIA A16.1 — FIAÇÃO REAL do AutoCombat (§19-32). AutoPlay → contexto → AutoCombatBrain → intenção → runtime →
## AbilityResolution → dano/cura/escudo/estado. NÃO cria AutoPlay2 (§19). Basic fallback sem deadlock (§20). Support
## SOLO e em PARTY (§27/§28): pode curar/proteger ally elegível SEM sair do spot (§80). x1/x2/x3 coerentes (o tempo
## de jogo é escalado a montante; o runtime usa `now`). Revive retoma o loop (§31). Puro/testável (contexto sintético).

## step de combate. caster = {class_id, expected_damage, max_hp, current_hp, shield, alive}. ctx = contexto do brain
## (archetype/dist/target_count/hp_frac/danger/in_line/is_boss/targets). allies = [{id, hp_frac, danger, alive}].
## Retorna {action, ability, damage_events, heal_events, shield_events, target}.
## ★★★ FIELD FIX 05/09/2026 — CADÊNCIA GLOBAL (GCD).
## `step()` é chamado a CADA FRAME pelo `HuntRuntime.tick`, e TODOS os básicos das 5 classes têm
## `cooldown: 0.0` com condição `"always"` ⇒ o herói atacava ~60×/s e o mob (30 HP) morria antes de
## terminar de se aproximar. O mob sempre teve `attack_interval` (1.5 s); o herói não tinha cadência
## NENHUMA — assimetria por omissão, não design.
## O GCD fica no ÚNICO ponto por onde todo cast passa: não mexe no dano nem no cooldown de skill
## nenhuma, só impede mais de uma ação por janela.
## ⚠️ O caminho de BOSS (`BossEncounterRuntime`) avança `now` em 1.0 s por tick ⇒ 1 ação por tick,
## exatamente como antes. Esta mudança afeta o loop de caça em tempo real, não o balance do boss.
const GLOBAL_COOLDOWN := 1.0
const GCD_ID := "__GCD__"

static func step(caster: Dictionary, ctx: Dictionary, cds: CooldownTracker, now: float, allies: Array = []) -> Dictionary:
	if not bool(caster.get("alive", true)):
		return {"action": "DEAD", "ability": "", "damage_events": [], "heal_events": [], "shield_events": []}
	# ⚠️ o GCD trava só o CAST, nunca a decisão inteira: a 1ª versão retornava aqui e congelava
	# também o MOVIMENTO — o melee parava de fechar distância (AUTOWIRE-T02 pegou isso).
	# SUPPORT em PARTY (§28/§78) — prioridade: ally crítico → MEND; ally em perigo → WARD. Fica no próprio spot (§80).
	if str(caster.get("class_id", "")) == "CLASS_5_SUPPORT" and allies.size() > 0:
		var ally := _lowest_ally(allies)
		if not ally.is_empty() and cds.is_ready(GCD_ID, now):
			if float(ally.get("hp_frac", 1.0)) < 0.5 and cds.is_ready("SK_C5_MEND", now):
				return _cast("SK_C5_MEND", caster, [], now, cds, str(ally["id"]))
			if bool(ally.get("danger", false)) and cds.is_ready("SK_C5_WARD", now):
				return _cast("SK_C5_WARD", caster, [], now, cds, str(ally["id"]))
	# decisão normal do brain (self)
	var d := AutoCombatBrain.decide(str(caster.get("class_id", "melee")), ctx, cds, now)
	var action := str(d.get("action", "IDLE"))
	if action == "CAST":
		if not cds.is_ready(GCD_ID, now):
			# em GCD: a intenção fica registrada, mas nada é lançado neste tick. O host segue
			# movimentando/animando normalmente — só a AÇÃO espera a janela global.
			return {"action": "GCD", "ability": str(d.get("ability", "")), "damage_events": [], "heal_events": [], "shield_events": [], "reason": "global_cooldown"}
		return _cast(str(d["ability"]), caster, ctx.get("targets", []), now, cds, "self")
	# movimento/idle: sem cast (§20 sem deadlock — brain sempre retorna algo)
	return {"action": action, "ability": str(d.get("ability", "")), "damage_events": [], "heal_events": [], "shield_events": [], "reason": str(d.get("reason", ""))}

static func _cast(ability_id: String, caster: Dictionary, targets: Array, now: float, cds: CooldownTracker, heal_target: String) -> Dictionary:
	var ab := ClassAbilityLibrary.get_ability(ability_id)
	if ab.is_empty():
		return {"action": "IDLE", "ability": "", "damage_events": [], "heal_events": [], "shield_events": []}
	var res := AbilityResolution.resolve(ab, caster, targets)
	cds.trigger(ability_id, now, float(ab.get("cooldown", 0.0)))
	cds.trigger(GCD_ID, now, GLOBAL_COOLDOWN)   # ★ toda ação consome a janela global (ver GCD acima)
	# remapeia heal/shield para o ally quando aplicável (§28)
	var heal_events: Array = res["heal_events"]
	var shield_events: Array = res["shield_events"]
	if heal_target != "self":
		for h in heal_events: h["target"] = heal_target
		for s in shield_events: s["target"] = heal_target
	return {
		"action": "CAST", "ability": ability_id, "role": str(res["role"]),
		"damage_events": res["damage_events"], "heal_events": heal_events, "shield_events": shield_events,
		"status_events": res["status_events"], "target": heal_target,
	}

static func _lowest_ally(allies: Array) -> Dictionary:
	var best := {}
	var best_hp := 2.0
	for a in allies:
		if not bool(a.get("alive", true)): continue
		var hf := float(a.get("hp_frac", 1.0))
		if hf < best_hp:
			best_hp = hf; best = a
	return best

## Revive (§31): restaura HP e marca vivo — o loop de Auto/Hunt retoma.
static func revive(caster: Dictionary) -> Dictionary:
	var c := caster.duplicate(true)
	c["current_hp"] = int(c.get("max_hp", 1)); c["alive"] = true; c["shield"] = 0
	return c
