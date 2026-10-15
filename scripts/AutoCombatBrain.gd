class_name AutoCombatBrain extends RefCounted
## FATIA A15.2 — CÉREBRO de AutoCombat por CLASSE (§23-31). ★ A IA escolhe a EXECUÇÃO; o jogador escolhe classe/
## build/loadout/gear/refino/progressão (§24). Integra ao AutoPlay atual (não cria sistema rival). Decision tick com
## cadência/contexto (§25) — não avalia tudo por frame. Cada arquétipo joga diferente (§26-30). OFFLINE não roda isto
## frame-a-frame (§31) — o A5 é agregado. Puro/determinístico/testável (contexto sintético).

# distância PREFERIDA por arquétipo (UL). Melee cola; ranged/magic mantêm faixa; reach opera em meio-alcance próprio.
const PREFERRED := {"melee": 60.0, "ranged": 260.0, "magic": 220.0, "reach": 140.0, "support": 190.0}

## ctx = {archetype, dist, target_count, hp_frac, danger, in_line, is_boss}
## cds = CooldownTracker · now = tempo de jogo. Retorna {action, ability, move, reason}.
static func decide(class_id: String, ctx: Dictionary, cds: CooldownTracker, now: float) -> Dictionary:
	class_id = ClassAbilityLibrary.effective_class(class_id)   # FIELD FIX 01B: LEGACY/desconhecido → kit melee básico (herói legado LUTA)
	var arch := str(ctx.get("archetype", "melee"))
	var dist := float(ctx.get("dist", 9999.0))
	var pref := float(PREFERRED.get(arch, 60.0))
	# 1) MOVIMENTO por arquétipo (§26-30) — decidido ANTES da habilidade
	if arch == "melee":
		if dist > pref * 1.2:
			return {"action": "APPROACH", "reason": "gap_close_needed"}   # §26 só quando necessário
	elif arch in ["ranged", "magic", "support"]:
		if dist < pref * 0.5:
			return {"action": "KITE", "reason": "preserve_distance"}      # §27 mantém faixa (kite curto, não foge infinito)
		if dist > pref * 1.3:
			return {"action": "APPROACH", "reason": "get_in_range"}       # §27 não sai do mapa; reaproxima
	elif arch == "reach":
		if dist < pref * 0.55:
			return {"action": "STEP_BACK", "reason": "keep_spacing"}      # §29 faixa própria (≠ melee)
		if dist > pref * 1.3:
			return {"action": "APPROACH", "reason": "get_in_range"}
	# 2) HABILIDADE: maior prioridade PRONTA cuja CONDIÇÃO bate (§30 support prioriza cura)
	var best := {}
	var best_prio := -1
	for aid in ClassAbilityLibrary.abilities_of(class_id):
		var ab := ClassAbilityLibrary.get_ability(aid)
		if str(ab.get("role", "")) == ClassAbilityLibrary.ROLE_MOBILITY:
			continue   # dodge é reativo (não é escolha ofensiva de rotação)
		if not cds.is_ready(aid, now):
			continue
		if not _condition_met(str(ab.get("ai", {}).get("condition", "always")), ctx):
			continue
		var prio := int(ab.get("ai", {}).get("priority", 0))
		if prio > best_prio:
			best_prio = prio; best = ab
	if best.is_empty():
		return {"action": "IDLE", "reason": "no_ability_ready"}
	# habilidade fora de alcance (não é self) → aproxima
	if str(best.get("targeting", "")) != ClassAbilityLibrary.TARGET_SELF and dist > float(best.get("range", 9999.0)):
		return {"action": "APPROACH", "ability": str(best["ability_id"]), "reason": "ability_out_of_range"}
	return {"action": "CAST", "ability": str(best["ability_id"]), "role": str(best["role"]), "reason": "best_ready"}

static func _condition_met(cond: String, ctx: Dictionary) -> bool:
	match cond:
		"always": return true
		"target_ok": return int(ctx.get("target_count", 0)) >= 1
		"multi_target": return int(ctx.get("target_count", 0)) >= 2
		"line_targets": return bool(ctx.get("in_line", false)) and int(ctx.get("target_count", 0)) >= 1
		"boss": return bool(ctx.get("is_boss", false))
		"danger": return bool(ctx.get("danger", false))
		"hp_below_0_5": return float(ctx.get("hp_frac", 1.0)) < 0.5
		"hp_below_0_6": return float(ctx.get("hp_frac", 1.0)) < 0.6
		_: return true
