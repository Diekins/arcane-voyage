class_name RefineSimulator
## RefineSimulator — MONTE CARLO PURO do refino (FATIA A7.2, §8). Espelha EXATAMENTE a mecânica do runtime
## (GameState.refine_attempt): chance base (RefineMath) + pity PERSISTENTE (zera só em novo recorde) + cap +30pp
## + downgrade -1 a partir de +10 com PISO de segurança + catalisador/preservação/absoluto. Sem GameState, sem
## save (§9). Seed controlável (§17). Reporta média + percentis (§18).

const ATT_CAP := 100000   # teto anti-loop (jornadas saudáveis ficam MUITO abaixo)

## Política de suporte da jornada:
##   cat_from: nível a partir do qual usa catalisador (99 = nunca); cat_pp: pp do catalisador.
##   pres_from: nível a partir do qual usa Selo de Preservação (99 = nunca).
##   abs_from: nível a partir do qual usa Selo Absoluto (99 = nunca).
static func policy(cat_from: int = 99, cat_pp: float = 0.0, pres_from: int = 99, abs_from: int = 99) -> Dictionary:
	return {"cat_from": cat_from, "cat_pp": cat_pp, "pres_from": pres_from, "abs_from": abs_from}

## UMA jornada de `from_lvl` → `to_lvl`. Retorna {fragments, attempts, downgrades, fails, catalysts, preserves, absolutes, reached}.
static func journey(from_lvl: int, to_lvl: int, pol: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	_cur_pity = 0.0
	var L := from_lvl
	var high := from_lvl
	var frag := 0
	var att := 0
	var downs := 0
	var fails := 0
	var cats := 0
	var press := 0
	var absol := 0
	while L < to_lvl and att < ATT_CAP:
		var use_cat: bool = L >= int(pol.get("cat_from", 99))
		var use_abs: bool = L >= int(pol.get("abs_from", 99))
		var use_pres: bool = L >= int(pol.get("pres_from", 99))
		var cat_pp: float = float(pol.get("cat_pp", 0.0)) if use_cat else 0.0
		var chance := 1.0 if use_abs else clampf(RefineMath.base_chance(L) + _cur_pity + cat_pp, 0.0, 1.0)
		frag += RefineMath.cost(L)
		att += 1
		if use_cat: cats += 1
		if use_abs: absol += 1
		if rng.randf() < chance:
			L += 1
			if L > high:
				high = L
				_cur_pity = 0.0
		else:
			fails += 1
			_cur_pity = minf(_cur_pity + RefineMath.PITY_PER_FAIL, RefineMath.PITY_MAX_BONUS)
			if L >= RefineMath.DOWNGRADE_FROM_LEVEL:
				if use_pres:
					press += 1                      # preservou (não cai)
				else:
					L = maxi(RefineMath.downgrade_floor(L), L - 1)
					downs += 1
	return {"fragments": frag, "attempts": att, "downgrades": downs, "fails": fails,
		"catalysts": cats, "preserves": press, "absolutes": absol, "reached": L >= to_lvl}

# pity da jornada corrente (RefineSimulator roda 1 jornada por vez; zerado antes de cada journey no monte_carlo).
static var _cur_pity := 0.0

## MONTE CARLO: N jornadas. Retorna agregados + percentis de fragments/attempts + médias de downgrades/suportes.
static func monte_carlo(from_lvl: int, to_lvl: int, pol: Dictionary, n: int, seed_base: int = 12345) -> Dictionary:
	var frags: Array = []
	var atts: Array = []
	var sum_down := 0
	var sum_cat := 0
	var sum_pres := 0
	var sum_abs := 0
	var reached := 0
	var rng := RandomNumberGenerator.new()
	for i in range(n):
		rng.seed = seed_base + i
		_cur_pity = 0.0
		var j := journey(from_lvl, to_lvl, pol, rng)
		frags.append(int(j["fragments"]))
		atts.append(int(j["attempts"]))
		sum_down += int(j["downgrades"]); sum_cat += int(j["catalysts"])
		sum_pres += int(j["preserves"]); sum_abs += int(j["absolutes"])
		if bool(j["reached"]): reached += 1
	frags.sort(); atts.sort()
	var nn := maxi(1, n)
	return {
		"n": n,
		"frag_mean": _mean(frags), "frag_p50": _pct(frags, 0.50), "frag_p75": _pct(frags, 0.75),
		"frag_p90": _pct(frags, 0.90), "frag_p95": _pct(frags, 0.95),
		"att_mean": _mean(atts), "att_p95": _pct(atts, 0.95),
		"downgrades_avg": float(sum_down) / float(nn), "catalysts_avg": float(sum_cat) / float(nn),
		"preserves_avg": float(sum_pres) / float(nn), "absolutes_avg": float(sum_abs) / float(nn),
		"reached_pct": 100.0 * float(reached) / float(nn),
	}

static func _mean(a: Array) -> int:
	if a.is_empty(): return 0
	var s := 0
	for v in a: s += int(v)
	return s / a.size()

static func _pct(a: Array, p: float) -> int:
	if a.is_empty(): return 0
	return int(a[clampi(int(p * float(a.size())), 0, a.size() - 1)])
