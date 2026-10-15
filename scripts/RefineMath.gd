class_name RefineMath
## RefineMath — a MATEMÁTICA do Refino de equipamento (FATIA A7, PARTE II). FUNÇÕES PURAS (sem estado/RNG/
## GameState) → testáveis e consumidas por GameState.equip_sum + SystemPanel + PowerAdvisor.
##
## ★ DECISÃO DE DESIGN (§11): REFINO É POR SLOT, NÃO POR INSTÂNCIA DE ITEM. O nível do slot permanece ao trocar
## o item (§21) — evita engenharia de item-instance, não perde investimento no loot, é sink permanente de
## Fragmentos. Recurso = FRAGMENTOS (já existe desde A3.5; §14) — nenhuma moeda nova.
##
## ★ 100% garantido (§17): sem quebra/downgrade/RNG/proteção/cash. Paga → melhora exatamente 1 nível.

const REFINE_MAX_LEVEL := 20                 # cap V1 (§16)
const REFINE_COST_BASE := 20.0               # +0→+1 = 20 (§15; mantido)
## FATIA A7.2 (BALANCEAMENTO, §4/§16/§17): growth 1.55→1.22. O 1.55 tornava +20 ABSURDO (custo +19→20 ≈ 82k,
## +0→20 com retry ≈ 2,9 MILHÕES de Fragmentos) — matematicamente impraticável p/ F2P. 1.22 mantém `cost(0)=20`
## (regressão intacta) e escala saudável. Prova por Monte Carlo no _a72_economy_selftest (antes/depois).
const REFINE_COST_GROWTH := 1.22             # custo ∝ 1.22^level (recalibrado por simulação)
const REFINE_MULT_PER_LEVEL := 0.04          # +4% por nível (§18) — GANHO DE PODER INALTERADO (§39)

## Custo em Fragmentos p/ subir do nível ATUAL `level` → `level+1`. round(20 × 1.55^level).
##   +0→+1=20 · +1→+2=31 · +5→+6≈179 · +10→+11≈1600.
static func cost(level: int) -> int:
	return int(round(REFINE_COST_BASE * pow(REFINE_COST_GROWTH, float(maxi(0, level)))))

## Multiplicador aplicado aos ATRIBUTOS POSITIVOS do item daquele slot. 1 + 0.04×level (linear V1, §18).
static func mult(level: int) -> float:
	return 1.0 + REFINE_MULT_PER_LEVEL * float(clampi(level, 0, REFINE_MAX_LEVEL))

## Já está no teto?
static func is_max(level: int) -> bool:
	return level >= REFINE_MAX_LEVEL

## Custo total acumulado p/ ir de `from_level` até `to_level` (projeções/testes).
static func total_cost(from_level: int, to_level: int) -> int:
	var s := 0
	var l := maxi(0, from_level)
	while l < mini(to_level, REFINE_MAX_LEVEL):
		s += cost(l)
		l += 1
	return s

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# ENDGAME (FATIA A7.1, PARTE F) — CHANCE / RISCO / PITY. O GANHO DE PODER NÃO MUDA (mesmo mult/cap/custo, §39);
# muda a CHANCE de sucesso e a PENALIDADE. Tudo DATA-DRIVEN e TRANSPARENTE (§40/§58).
# ══════════════════════════════════════════════════════════════════════════════════════════════════
## Chance BASE de sucesso da tentativa `level → level+1` (§40). 0..1. Fora da tabela (0..4) = 100%.
const CHANCE_TABLE := {
	0: 1.00, 1: 1.00, 2: 1.00, 3: 1.00, 4: 1.00,
	5: 0.90, 6: 0.85, 7: 0.80, 8: 0.70, 9: 0.60,
	10: 0.50, 11: 0.45, 12: 0.35, 13: 0.30, 14: 0.25,
	15: 0.20, 16: 0.15, 17: 0.12, 18: 0.08, 19: 0.05,
}
## A partir da tentativa `+10 → +11` (level de partida >= 10), a FALHA reduz o slot em 1 (§42). Abaixo disso,
## falha só mantém o nível (§42). Punição MÁXIMA = -1 (nunca zera/quebra/destrói, §43).
const DOWNGRADE_FROM_LEVEL := 10
const PITY_PER_FAIL := 0.02          # +2 pontos percentuais por falha (§44)
## FATIA A7.2 (§19, ajuste COM DADOS): cap +20pp→+30pp. Com cap 20pp + pity que zerava a CADA sucesso, o topo
## (+18→20) era estatisticamente IMPOSSÍVEL (0% chegavam num teto de 4000 tentativas): o re-climb após downgrade
## resetava o pity antes de ele acumular. Correção: (1) pity PERSISTENTE — zera SÓ ao atingir NOVO RECORDE do
## slot (o re-climb mantém o pity); (2) cap 30pp. Resultado: +18→20 vira 100% alcançável (P95 ~180k Frag).
const PITY_MAX_BONUS := 0.30
## PISO DE SEGURANÇA (§20/§43): a falha nunca derruba abaixo do maior piso ≤ nível atual (5/10/15) — bounda o
## worst-case do downgrade, dá tensão sem regressão infinita. +18→20 falha cai no máx até +15, nunca abaixo.
const SAFE_FLOORS := [15, 10, 5]

## Piso p/ o downgrade partindo de `level`: maior floor estritamente MENOR que level (ou 0). O nível pós-falha
## nunca fica abaixo disto.
static func downgrade_floor(level: int) -> int:
	for f in SAFE_FLOORS:
		if level > f:
			return f
	return 0

## Chance base (0..1) da tentativa partindo de `level`. Cap atingido → 0 (não há +20→+21).
static func base_chance(level: int) -> float:
	if level >= REFINE_MAX_LEVEL:
		return 0.0
	return float(CHANCE_TABLE.get(level, 1.0))

## Chance FINAL (0..1) = base + pity + catalisador (pp), clampada em [0,1] (§44/§51). Selo Absoluto força 1.0 fora.
static func final_chance(level: int, pity_bonus: float, catalyst_pp: float) -> float:
	return clampf(base_chance(level) + maxf(0.0, pity_bonus) + maxf(0.0, catalyst_pp), 0.0, 1.0)

## A falha nesta tentativa causa downgrade (-1)? (§42) — só a partir de +10.
static func fails_downgrade(level: int) -> bool:
	return level >= DOWNGRADE_FROM_LEVEL

## Novo pity após uma FALHA (soma +2pp até o cap). Sucesso zera fora (§44).
static func pity_after_fail(pity_bonus: float) -> float:
	return minf(maxf(0.0, pity_bonus) + PITY_PER_FAIL, PITY_MAX_BONUS)
