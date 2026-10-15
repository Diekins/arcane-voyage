class_name ArenaSettlementService extends RefCounted
## FATIA A12 — SETTLEMENT do match (§9/§10). ★ SERVER_INTERNAL: o RESULTADO NUNCA vem do cliente (§10/§74). A
## futura A12.1 fornecerá o resultado da simulação server-authoritative; aqui só existe a interface interna. Aplica
## rating de A e B + o match record ATOMICAMENTE (§75): se qualquer parte falhar, NENHUM rating muda. EXACTLY-ONCE
## por match_id (§45/§95): duplicate settlement devolve o resultado anterior, sem 2º Elo. NO_CONTEST/SERVER_ABORT =
## 0 rating / 0 reward (§46/§84). FORFEIT/DISCONNECT_FORFEIT contam como loss/win conforme policy (§47). Draw
## suportado (§48). Reasons: NORMAL/FORFEIT/DISCONNECT_FORFEIT/NO_CONTEST/SERVER_ABORT (§83).

var profiles: ArenaProfileRepository
var matches: ArenaMatchRepository
var seasons: ArenaSeasonManager
var _clock: ServerClock
var _fault := ""   # injeção de falha p/ testes (§108)
var audit_log: Array = []

func setup(p_profiles: ArenaProfileRepository, p_matches: ArenaMatchRepository, p_seasons: ArenaSeasonManager, p_clock: ServerClock) -> void:
	profiles = p_profiles; matches = p_matches; seasons = p_seasons; _clock = p_clock

func set_fault(f: String) -> void: _fault = f

## SERVER_INTERNAL. winner ∈ {"a","b","draw"}. reason ∈ NORMAL/FORFEIT/DISCONNECT_FORFEIT/NO_CONTEST/SERVER_ABORT.
func settle(match_id: String, winner: String, reason: String) -> Dictionary:
	if not matches.has(match_id):
		return {"ok": false, "reason": "NO_MATCH"}
	# idempotência (§45/§95): já settled → devolve o anterior, sem re-aplicar
	if matches.is_settled(match_id):
		var prior := matches.get_match(match_id)
		return {"ok": true, "duplicate": true, "winner": str(prior["result"]), "reason": str(prior["reason"]), "rating_after": prior["rating_after"]}
	var m := matches.get_match(match_id)
	var a := str(m["participant_a"]); var b := str(m["participant_b"]); var season_id := str(m["season_id"])
	# NO_CONTEST / SERVER_ABORT → 0 rating (§46/§84)
	if reason == "NO_CONTEST" or reason == "SERVER_ABORT":
		var st := ArenaMatchRepository.NO_CONTEST if reason == "NO_CONTEST" else ArenaMatchRepository.CANCELLED
		matches.mark_settled(match_id, "NO_CONTEST", reason, {}, {}, {}, st, _clock.now())
		return {"ok": true, "no_rating": true, "reason": reason}
	# perfis (rating pertence ao CHARACTER §12)
	var pa := profiles.get_or_create(a, season_id); var ra := profiles.revision_of(a)
	var pb := profiles.get_or_create(b, season_id); var rb := profiles.revision_of(b)
	var rating_a := int(pa["current_rating"]); var rating_b := int(pb["current_rating"])
	var score_a := ArenaRating.WIN if winner == "a" else (ArenaRating.LOSS if winner == "b" else ArenaRating.DRAW)
	var score_b := 1.0 - score_a
	var dA := ArenaRating.delta(rating_a, rating_b, score_a, int(pa["placements_played"]))
	var dB := ArenaRating.delta(rating_b, rating_a, score_b, int(pb["placements_played"]))
	var new_a := ArenaRating.with_floor(rating_a + dA)
	var new_b := ArenaRating.with_floor(rating_b + dB)
	var forfeit := reason == "FORFEIT" or reason == "DISCONNECT_FORFEIT"
	var na := _apply(pa, score_a, new_a, forfeit and winner == "b")
	var nb := _apply(pb, score_b, new_b, forfeit and winner == "a")
	# §93 crash-before-commit: NADA muda
	if _fault == "BEFORE_COMMIT":
		return {"ok": false, "reason": "FAULT_BEFORE_COMMIT"}
	# commit ATÔMICO dos 2 perfis (§75) — valida ambas revisions, aplica ambas ou nada
	var cm := profiles.commit_two(a, ra, na, b, rb, nb)
	if not bool(cm["ok"]):
		return {"ok": false, "reason": "STALE_SETTLEMENT"}   # zero commit, nunca parcial
	# marca o match settled (mesma chamada síncrona → sem estado meio-a-meio)
	matches.mark_settled(match_id, winner, reason, {a: rating_a, b: rating_b}, {a: dA, b: dB}, {a: new_a, b: new_b}, ArenaMatchRepository.FINISHED, _clock.now())
	_audit(match_id, a, b, winner, reason, rating_a, rating_b, dA, dB, new_a, new_b)
	return {"ok": true, "winner": winner, "reason": reason, "rating_before": {a: rating_a, b: rating_b}, "rating_delta": {a: dA, b: dB}, "rating_after": {a: new_a, b: new_b}}

func _apply(profile: Dictionary, score: float, new_rating: int, is_forfeiter: bool) -> Dictionary:
	var p := profile.duplicate(true)
	p["current_rating"] = new_rating
	p["peak_rating"] = maxi(int(p["peak_rating"]), new_rating)
	if score == ArenaRating.WIN:
		p["wins"] = int(p["wins"]) + 1; p["lifetime_wins"] = int(p["lifetime_wins"]) + 1
		p["current_streak"] = (int(p["current_streak"]) + 1) if int(p["current_streak"]) > 0 else 1
	elif score == ArenaRating.LOSS:
		p["losses"] = int(p["losses"]) + 1; p["lifetime_losses"] = int(p["lifetime_losses"]) + 1
		p["current_streak"] = 0
	else:
		p["draws"] = int(p["draws"]) + 1; p["current_streak"] = 0
	p["best_streak"] = maxi(int(p["best_streak"]), int(p["current_streak"]))
	if is_forfeiter:
		p["forfeits"] = int(p["forfeits"]) + 1
	p["placements_played"] = int(p["placements_played"]) + 1
	p["season_matches"] = int(p["season_matches"]) + 1
	p["current_rank_id"] = ArenaRank.rank_for(new_rating)
	p["peak_rank_id"] = ArenaRank.higher(str(p["peak_rank_id"]), str(p["current_rank_id"]))
	p["last_match_at"] = _clock.now()
	return p

func _audit(match_id: String, a: String, b: String, winner: String, reason: String, ra: int, rb: int, da: int, db: int, na: int, nb: int) -> void:
	audit_log.append({
		"t": _clock.now(), "match_id": match_id, "a": a, "b": b, "winner": winner, "reason": reason,
		"rating_before": {a: ra, b: rb}, "rating_delta": {a: da, b: db}, "rating_after": {a: na, b: nb},
	})   # §41 dados úteis p/ anti-wintrade futuro; sem token/account privado
