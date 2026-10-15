class_name ArenaNormalizationPolicy extends RefCounted
## FATIA A12 — NORMALIZAÇÃO competitiva (§59-67). Ranked NÃO pode ser "80k CP one-shot 30k CP" (§59). Recebe o poder
## BRUTO de combate (offense = DPS esperado, effective_hp) e produz um ArenaCombatSnapshot SÓ para a partida —
## NUNCA altera os stats PvE persistentes (§61). Preserva a IDENTIDADE DA BUILD: a razão offense:effective_hp
## permanece (§62). Cosmetic/VIP já ficam FORA do poder bruto (a fórmula CP usa só stats de combate §51) → aqui são
## naturalmente ignorados. Dois modelos p/ simular (§64); V1 escolhido = MODEL A (normalização quase total §65),
## porque o CP leaderboard já celebra progressão; Ranked celebra skill/build. NÃO resolve cooldown/range/CC/hitbox
## (§66) — isso é balance de classes futuro. Puro/determinístico.

const CP_SCALE := 14.0                 # espelha PowerBudget.CP_DISPLAY_SCALE
const TARGET_ARENA_CP := 10000         # §63 alvo competitivo (calibrável); CP leaderboard usa CP real, não este
const MODEL_A := "FULL"
const MODEL_B := "COMPRESSION"

# Model B (compressão): mantém banda pequena de vantagem por progressão
const REFERENCE_CP := 30000.0          # referência de população p/ compressão
const COMPRESSION_EXP := 0.15
const BAND := 0.05                      # ±5% (§64 — não usar cegamente; é V1 simulável)

# §67 — caps competitivos p/ stats extremos futuros (crit/dodge/lifesteal/cdr/block). Sem tais stats hoje: passthrough.
const STAT_CAPS := {"crit": 0.50, "dodge": 0.40, "lifesteal": 0.30, "cdr": 0.40, "block": 0.50}

static func _raw(offense: float, effective_hp: float) -> float:
	if offense <= 0.0 or effective_hp <= 0.0:
		return 0.0
	return sqrt(offense * effective_hp)

static func _cp_of(offense: float, effective_hp: float) -> int:
	return int(round(_raw(offense, effective_hp) * CP_SCALE))

## MODEL A — normalização quase total: todos convergem para TARGET_ARENA_CP, RAZÃO offense:effective_hp preservada.
static func normalize_full(offense: float, effective_hp: float) -> Dictionary:
	if offense <= 0.0 or effective_hp <= 0.0:
		return _snapshot(offense, effective_hp, offense, effective_hp, MODEL_A)
	var ratio := offense / effective_hp                 # identidade da build
	var target_raw := float(TARGET_ARENA_CP) / CP_SCALE
	var o2 := target_raw * sqrt(ratio)                  # O' = raw×√r
	var e2 := target_raw / sqrt(ratio)                  # E' = raw/√r  → √(O'E')=raw, O'/E'=r
	return _snapshot(offense, effective_hp, o2, e2, MODEL_A)

## MODEL B — compressão: mantém banda ±BAND de vantagem por progressão (razão preservada).
static func normalize_compressed(offense: float, effective_hp: float) -> Dictionary:
	if offense <= 0.0 or effective_hp <= 0.0:
		return _snapshot(offense, effective_hp, offense, effective_hp, MODEL_B)
	var cp0 := float(_cp_of(offense, effective_hp))
	var target_cp := float(TARGET_ARENA_CP) * pow(cp0 / REFERENCE_CP, COMPRESSION_EXP)
	target_cp = clampf(target_cp, float(TARGET_ARENA_CP) * (1.0 - BAND), float(TARGET_ARENA_CP) * (1.0 + BAND))
	var ratio := offense / effective_hp
	var target_raw := target_cp / CP_SCALE
	var o2 := target_raw * sqrt(ratio)
	var e2 := target_raw / sqrt(ratio)
	return _snapshot(offense, effective_hp, o2, e2, MODEL_B)

## Dispatcher. `model` default = MODEL_A (escolha V1 §65).
static func normalize(offense: float, effective_hp: float, model: String = MODEL_A) -> Dictionary:
	if model == MODEL_B:
		return normalize_compressed(offense, effective_hp)
	return normalize_full(offense, effective_hp)

static func _snapshot(raw_o: float, raw_e: float, o: float, e: float, model: String) -> Dictionary:
	# ArenaCombatSnapshot — congelado no início do match (§68); imutável por convenção do chamador.
	return {
		"model": model,
		"offense": o, "effective_hp": e,
		"cp": _cp_of(o, e),
		"ratio": (o / e) if e > 0.0 else 0.0,
		"raw_offense": raw_o, "raw_effective_hp": raw_e,
		"raw_cp": _cp_of(raw_o, raw_e),
		"cosmetic_power": 0, "vip_power": 0,       # §5/§51 — invariante: cosmético/VIP = 0 poder competitivo
	}

## Hook de caps (§67) — clampa stats extremos futuros. Hoje passthrough (combate não tem crit/dodge% numérico).
static func apply_caps(snapshot: Dictionary, stats: Dictionary) -> Dictionary:
	var capped := stats.duplicate(true)
	for k in STAT_CAPS:
		if capped.has(k):
			capped[k] = clampf(float(capped[k]), 0.0, float(STAT_CAPS[k]))
	snapshot["capped_stats"] = capped
	return snapshot
