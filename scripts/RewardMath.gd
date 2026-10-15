class_name RewardMath
## RewardMath — a economia de FARM/stage idle (FATIA A5). FUNÇÕES PURAS (determinísticas, sem RNG global,
## sem GameState, sem Node). É a FONTE ÚNICA da recompensa de ciclo/stage (online-esperado, offline e taxas
## /h consomem daqui — §23). NÃO toca reward de quest/narrativa (§24).
##
## ★ CALIBRAÇÃO (§22): auditei o pool normal do Cap.1 (young_wolf xp12/gold4, wild_boar xp18/gold7 → média
## ~15xp/~5.5gold por kill; road_bandit 32/22 é o raro). Um CICLO = concluir uma stage normal ≈ 30 kills
## (NORMAL_STAGE_DEFAULT_QUOTA). Logo o ciclo base (stage 1, Q=1) ≈ 30×5.5≈165 ouro e 30×15≈450 XP. Arredondo
## p/ constantes limpas → BASE_GOLD_CYCLE=150, BASE_XP_CYCLE=400 (mesma ordem do sistema ativo, sem ruptura).

const BASE_GOLD_CYCLE := 150.0
const BASE_XP_CYCLE := 400.0
const GOLD_EXP := 0.92
const XP_EXP := 0.95
## FATIA A7.2 (BALANCEAMENTO) — FRAGMENTOS por ciclo, sink-feeder do Refino. A3.5 só dava Fragmentos por salvage
## (raro: loot é quase tudo material) ⇒ ~100/h, insuficiente. Aqui formaliza a renda ESCALADA LINEARMENTE COM A
## FASE (não com Q: Q explode pelo multiplicador de muro composto → trivializaria o refino no endgame). Calibrado
## por simulação (§4/§6): fase6 ~3/ciclo (~336/h) · fase95 ~15 (~1680/h) · fase170 ~26 (~2912/h). Salvage = bônus.
const FRAG_CYCLE_BASE := 2.0
const FRAG_CYCLE_SLOPE := 0.14      # +0.14 Fragmentos/ciclo por fase global
const APEX_FIRST_MULT := 2.0    # 1ª conclusão de APEX/mini em modo AVANÇO (§25)
const BOSS_FIRST_MULT := 4.0    # 1ª conclusão de BOSS em modo AVANÇO (§25)

const T_NORMAL := "normal"
const T_MINIBOSS := "miniboss"
const T_BOSS := "boss"

## Q = required_cp(stage normal) / 1000 — o "tamanho" econômico da fase.
static func q_of(global_stage: int) -> float:
	return float(ProgressionMath.required_cp(global_stage, T_NORMAL)) / 1000.0

## Ouro base de UM ciclo NORMAL na fase (sem multiplicador de encounter). ∝ Q^0.92.
static func gold_cycle(global_stage: int) -> int:
	return maxi(1, int(round(BASE_GOLD_CYCLE * pow(maxf(q_of(global_stage), 0.0001), GOLD_EXP))))

## XP base de UM ciclo NORMAL na fase. ∝ Q^0.95.
static func xp_cycle(global_stage: int) -> int:
	return maxi(1, int(round(BASE_XP_CYCLE * pow(maxf(q_of(global_stage), 0.0001), XP_EXP))))

## FATIA A7.2 — Fragmentos base de UM ciclo na fase. Linear na fase (renda controlada). Fonte do sink de Refino (§4).
static func fragments_cycle(global_stage: int) -> int:
	return maxi(1, int(round(FRAG_CYCLE_BASE + FRAG_CYCLE_SLOPE * float(maxi(1, global_stage)))))

## Fragmentos/hora estimados na fase (projeção; §6). speed_mult = velocidade ativa (offline usa 1.0).
static func fragments_per_hour(global_stage: int, stage_type: String, r: float, speed_mult: float = 1.0) -> float:
	return ProgressionMath.cycles_per_hour(stage_type, r) * float(fragments_cycle(global_stage)) * maxf(speed_mult, 0.0)

## Multiplicador de encounter. Só na PRIMEIRA conclusão em AVANÇO (APEX ×2 / BOSS ×4). FARM (repetível) =
## NORMAL (×1) — nunca ×4 infinito de boss (§26).
static func encounter_mult(stage_type: String, is_first_advance: bool) -> float:
	if not is_first_advance:
		return 1.0
	match stage_type:
		T_MINIBOSS: return APEX_FIRST_MULT
		T_BOSS: return BOSS_FIRST_MULT
		_: return 1.0

## Ouro de completar UMA fase (aplica o multiplicador de encounter quando é 1ª conclusão em avanço).
static func gold_for(global_stage: int, stage_type: String, is_first_advance: bool) -> int:
	return maxi(1, int(round(float(gold_cycle(global_stage)) * encounter_mult(stage_type, is_first_advance))))

static func xp_for(global_stage: int, stage_type: String, is_first_advance: bool) -> int:
	return maxi(1, int(round(float(xp_cycle(global_stage)) * encounter_mult(stage_type, is_first_advance))))

# ── TAXAS POR HORA (projeções; §39-43) ──
## Ouro/h estimado na fase, dado R=cp/required. `speed_mult` = velocidade ATIVA (x1/x2/x3); offline usa 1.0.
static func gold_per_hour(global_stage: int, stage_type: String, r: float, speed_mult: float = 1.0) -> float:
	return ProgressionMath.cycles_per_hour(stage_type, r) * float(gold_cycle(global_stage)) * maxf(speed_mult, 0.0)

static func xp_per_hour(global_stage: int, stage_type: String, r: float, speed_mult: float = 1.0) -> float:
	return ProgressionMath.cycles_per_hour(stage_type, r) * float(xp_cycle(global_stage)) * maxf(speed_mult, 0.0)

# ── DROPS AGREGADOS (§28-29) — O(entradas de loot), NÃO O(kills); sem RNG global; determinístico ──
## Para `kills` mortes e uma loot_table [{name, chance}], devolve {nome_material: quantidade} (esperado +
## arredondamento estocástico DETERMINÍSTICO da fração via seed local). NÃO cria itens fora da tabela.
static func aggregate_drops(kills: int, loot_table: Array, seed_val: int) -> Dictionary:
	var out: Dictionary = {}
	if kills <= 0:
		return out
	for entry in loot_table:
		if not (entry is Dictionary):
			continue
		var nm := str(entry.get("name", ""))
		var chance := float(entry.get("chance", 0.0))
		if nm == "" or chance <= 0.0:
			continue
		var expected := float(kills) * chance
		var count := int(floor(expected))
		var frac := expected - float(count)
		# arredondamento estocástico determinístico: hash(seed, nome) em [0,1) decide o +1 da fração.
		if frac > 0.0:
			var h := hash("%d|%s" % [seed_val, nm])
			var r01 := float(absi(h) % 100000) / 100000.0
			if r01 < frac:
				count += 1
		if count > 0:
			out[nm] = int(out.get(nm, 0)) + count
	return out
