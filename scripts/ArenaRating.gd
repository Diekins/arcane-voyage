class_name ArenaRating extends RefCounted
## FATIA A12 — Modelo de RATING competitivo (§21). ELO-LIKE transparente, SEM multiplicadores escondidos (§22).
## E = 1/(1+10^((Rb-Ra)/400)); Δ = K×(S-E) com S∈{1 win, 0.5 draw, 0 loss}. K variável por nº de partidas e banda
## (§22). Placements (§23) usam K alto p/ convergir rápido; perfil fica PROVISIONAL até o mínimo. Baseline e floor
## explícitos (§24/§25). NADA de VIP/cosmetic/pay entra aqui (§4/§5). Puro/determinístico → simulável (§101).

const START_RATING := 1000       # §24 baseline
const PLACEMENTS_REQUIRED := 10  # §23
const FLOOR := 100               # §25 — rating nunca explode negativo
const TOP_BAND := 2000           # banda competitiva alta (K menor, anti-volatilidade)

const WIN := 1.0
const DRAW := 0.5
const LOSS := 0.0

## Probabilidade esperada de A vencer B.
static func expected(ra: float, rb: float) -> float:
	return 1.0 / (1.0 + pow(10.0, (rb - ra) / 400.0))

## K por nº de partidas jogadas e banda de rating (§22). Sem fatores ocultos.
static func k_for(matches_played: int, rating: int) -> int:
	if matches_played < PLACEMENTS_REQUIRED:
		return 64                # placements — convergência rápida
	if matches_played < 50:
		return 40                # pós-placements, ainda calibrando
	if rating >= TOP_BAND:
		return 16                # topo — estável, baixa volatilidade
	return 24                    # estável

## Delta de rating de um lado. score = WIN/DRAW/LOSS do PRÓPRIO lado.
static func delta(rating_self: int, rating_opp: int, score: float, matches_played: int) -> int:
	var e := expected(float(rating_self), float(rating_opp))
	var k := k_for(matches_played, rating_self)
	return int(round(float(k) * (score - e)))

## Aplica o floor (§25).
static func with_floor(rating: int) -> int:
	return maxi(rating, FLOOR)

## Soft reset de nova season (§78): puxa o rating em direção ao baseline pela metade. Simular antes de aplicar.
static func soft_reset(old_rating: int) -> int:
	return int(round(float(START_RATING) + (float(old_rating) - float(START_RATING)) * 0.5))

static func is_provisional(matches_played: int) -> bool:
	return matches_played < PLACEMENTS_REQUIRED
