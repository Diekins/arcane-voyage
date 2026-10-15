class_name ArenaRank extends RefCounted
## FATIA A12 — RANKS por rating (§26-29). IDs ESTÁVEIS (RANK_1..RANK_7) — nomes narrativos ficam pendentes de
## Canon/Visual Bible (§26/§90: display = CANON_REVIEW_REQUIRED). Ranks intermediários têm divisões III/II/I (§27);
## o topo é indivisível. TOP_100/TOP_10/CHAMPION são POSIÇÕES sazonais (§28), não tiers de MMR — vivem no
## leaderboard/season, não aqui. Champion só existe após finalize (§29).

const RANK_1 := "RANK_1"
const RANK_2 := "RANK_2"
const RANK_3 := "RANK_3"
const RANK_4 := "RANK_4"
const RANK_5 := "RANK_5"
const RANK_6 := "RANK_6"
const RANK_7 := "RANK_7"   # topo indivisível

# limites inferiores de cada rank (bandas de 200 a partir de 1000; abaixo de 1000 = RANK_1)
const THRESHOLDS := [
	{"id": RANK_7, "min": 2000},
	{"id": RANK_6, "min": 1800},
	{"id": RANK_5, "min": 1600},
	{"id": RANK_4, "min": 1400},
	{"id": RANK_3, "min": 1200},
	{"id": RANK_2, "min": 1000},
	{"id": RANK_1, "min": -100000},
]

## Resolve o rank_id a partir do rating.
static func rank_for(rating: int) -> String:
	for t in THRESHOLDS:
		if rating >= int(t["min"]):
			return str(t["id"])
	return RANK_1

## Divisão III/II/I dentro do rank (topo = "" indivisível). Cada banda de 200 dividida em 3 (~67 cada).
static func division_for(rating: int) -> String:
	var rid := rank_for(rating)
	if rid == RANK_7 or rid == RANK_1:
		return ""   # topo indivisível; base sem divisão
	var base := _rank_min(rid)
	var within := rating - base   # 0..199
	if within >= 134: return "I"    # mais alto
	if within >= 67: return "II"
	return "III"

static func _rank_min(rank_id: String) -> int:
	for t in THRESHOLDS:
		if str(t["id"]) == rank_id:
			return int(t["min"])
	return 0

## ordem numérica do rank (1..7) p/ comparação de "peak".
static func rank_order(rank_id: String) -> int:
	match rank_id:
		RANK_7: return 7
		RANK_6: return 6
		RANK_5: return 5
		RANK_4: return 4
		RANK_3: return 3
		RANK_2: return 2
		_: return 1

## Mantém o MAIOR entre dois ranks (para peak_rank).
static func higher(a: String, b: String) -> String:
	return a if rank_order(a) >= rank_order(b) else b

## Display name — PENDENTE de Canon/Visual Bible (§26/§90). Nunca congele arte/nome aqui.
static func display_name(_rank_id: String) -> String:
	return "CANON_REVIEW_REQUIRED"
