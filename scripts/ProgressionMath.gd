class_name ProgressionMath
## ProgressionMath — a MATEMÁTICA da dificuldade e da progressão (FATIA A3). Tudo aqui é FUNÇÃO PURA
## (determinística, sem estado, sem RNG, sem GameState) → 100% testável e consumível pelo StageDirector.
##
## Responde: quanto poder a fase exige? como o mob escala por fase? qual a relação jogador/fase (ratio/banda)?
## qual a estimativa de velocidade/ciclos por hora (p/ a A5 consumir depois — NÃO paga reward aqui)?
##
## ★ NÃO destrói config base (§16): o scaling é sempre derivado dos STATS-BASE IMUTÁVEIS do mob (o chamador
## guarda o base e passa aqui) → nunca acumula entre fases.

# ── Curva de CP requerido ────────────────────────────────────────────────────────────────────────
const BASE_STAGE_CP := 1000.0
const CURVE_BASE := 1.027          # +2.7% por fase
const WALL_SIZE := 25              # muro estrutural a cada 25 fases
const WALL_STEP := 1.12            # +12% por bloco de 25
const MINIBOSS_REQ_MULT := 1.05
const BOSS_REQ_MULT := 1.10

# ── Multiplicadores de STAT do encounter (aplicados DEPOIS do stage scale) ─────────────────────────
const MINIBOSS_HP_MULT := 2.20
const MINIBOSS_DMG_MULT := 1.15
const BOSS_HP_MULT := 4.00
const BOSS_DMG_MULT := 1.30

# ── Tipos de fase (espelham StageDirector) ─────────────────────────────────────────────────────────
const T_NORMAL := "normal"
const T_MINIBOSS := "miniboss"
const T_BOSS := "boss"

# ── Estimativa de tempo/velocidade (consumida pela A5; NÃO altera velocidade visual) ───────────────
const NORMAL_BASE_TIME := 30.0
const MINIBOSS_BASE_TIME := 40.0
const BOSS_BASE_TIME := 55.0
const TRANSITION_OVERHEAD := 2.0

## Curva base (sem muro): 1000 × 1.027^(n-1).
static func base_curve(n: int) -> float:
	return BASE_STAGE_CP * pow(CURVE_BASE, float(maxi(1, n) - 1))

## Multiplicador de muro estrutural: 1.12 ^ floor((n-1)/25).
static func wall_multiplier(n: int) -> float:
	return pow(WALL_STEP, floor(float(maxi(1, n) - 1) / float(WALL_SIZE)))

## CP recomendado de uma fase NORMAL global n (float; arredonda só na exibição).
static func normal_required_cp(n: int) -> float:
	return base_curve(n) * wall_multiplier(n)

## CP recomendado por tipo de fase (mini-boss/boss recebem o multiplicador de gate).
static func required_cp(n: int, stage_type: String) -> int:
	var base := normal_required_cp(n)
	match stage_type:
		T_MINIBOSS: base *= MINIBOSS_REQ_MULT
		T_BOSS: base *= BOSS_REQ_MULT
	return int(round(base))

## Escala da fase (relativa à base): NORMAL_REQUIRED_CP(n) / BASE_STAGE_CP.
static func stage_scale(n: int) -> float:
	return normal_required_cp(n) / BASE_STAGE_CP

## Multiplicadores de HP/dano do encounter por tipo (1.0/1.0 p/ normal).
static func encounter_hp_mult(stage_type: String) -> float:
	match stage_type:
		T_MINIBOSS: return MINIBOSS_HP_MULT
		T_BOSS: return BOSS_HP_MULT
		_: return 1.0

static func encounter_dmg_mult(stage_type: String) -> float:
	match stage_type:
		T_MINIBOSS: return MINIBOSS_DMG_MULT
		T_BOSS: return BOSS_DMG_MULT
		_: return 1.0

## Escala os stats de UM mob a partir dos STATS-BASE IMUTÁVEIS (nunca do já-escalado → sem acúmulo).
## Retorna {max_hp, damage_min, damage_max} (inteiros, mínimo 1).
static func scale_mob_stats(base_max_hp: int, base_dmg_min: int, base_dmg_max: int, n: int, stage_type: String) -> Dictionary:
	var s := stage_scale(n)
	var hp_mult := s * encounter_hp_mult(stage_type)
	var dmg_mult := s * encounter_dmg_mult(stage_type)
	return {
		"max_hp": maxi(1, int(round(float(base_max_hp) * hp_mult))),
		"damage_min": maxi(1, int(round(float(base_dmg_min) * dmg_mult))),
		"damage_max": maxi(1, int(round(float(base_dmg_max) * dmg_mult))),
	}

# ── Relação jogador/fase ───────────────────────────────────────────────────────────────────────────
## Razão de poder R = player_cp / required_cp.
static func power_ratio(player_cp: int, required_cp_val: int) -> float:
	return float(player_cp) / maxf(float(required_cp_val), 1.0)

## Classificação V1 da razão (§18).
static func ratio_band(r: float) -> String:
	if r < 0.85: return "MUITO FRACO"
	if r < 0.95: return "ALTO RISCO"
	if r < 1.00: return "DESAFIO"
	if r < 1.20: return "ADEQUADO"
	if r < 1.50: return "FORTE"
	if r < 2.00: return "MUITO FORTE"
	return "DOMINANDO"

# ── Velocidade / ciclos por hora (FUNÇÃO PURA; A5 consome — não paga reward, não altera time_scale) ──
## SPEED_FACTOR = clamp(R^0.65, 0.75, 2.50). Estimativa matemática, NÃO Engine.time_scale.
static func speed_factor(r: float) -> float:
	return clampf(pow(maxf(r, 0.0), 0.65), 0.75, 2.50)

static func base_time(stage_type: String) -> float:
	match stage_type:
		T_MINIBOSS: return MINIBOSS_BASE_TIME
		T_BOSS: return BOSS_BASE_TIME
		_: return NORMAL_BASE_TIME

## Tempo estimado do ciclo = base_time / speed_factor.
static func estimated_time(stage_type: String, r: float) -> float:
	return base_time(stage_type) / speed_factor(r)

## Ciclos por hora = 3600 / (estimated_time + overhead). CAPACIDADE de completar ciclos — NÃO significa
## avançar tantas fases/h (muros convertem avanço em farm).
static func cycles_per_hour(stage_type: String, r: float) -> float:
	return 3600.0 / (estimated_time(stage_type, r) + TRANSITION_OVERHEAD)
