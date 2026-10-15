class_name ArenaSeasonManager extends RefCounted
## FATIA A12 — SEASONS (§14-20). Estados explícitos UPCOMING→ACTIVE→LOCKED→FINALIZED. Todos os tempos por
## ServerClock (§15) — nunca do cliente. Finalize (§17) congela o leaderboard, calcula posições, gera season
## results + badges/rewards e é IDEMPOTENTE (§18): rodar duas vezes NÃO duplica. Histórico é IMUTÁVEL (§19/§20):
## depois de FINALIZED não muda. Champion = #1 congelado (§29) — líder atual ≠ campeão histórico.

const UPCOMING := "UPCOMING"
const ACTIVE := "ACTIVE"
const LOCKED := "LOCKED"
const FINALIZED := "FINALIZED"

var _clock: ServerClock
var _seasons: Dictionary = {}    # season_id → {season_id, state, starts_at, ends_at, created_at, finalized_at}
var _history: Dictionary = {}    # season_id → Array[ArenaSeasonResult congelado]
var _rewards: Dictionary = {}    # season_id → {character_id → Array[entitlements]}

func setup(clock: ServerClock) -> void:
	_clock = clock

func create_season(season_id: String, starts_at: int, ends_at: int) -> Dictionary:
	if _seasons.has(season_id):
		return {"ok": false, "reason": "EXISTS"}
	_seasons[season_id] = {"season_id": season_id, "state": UPCOMING, "starts_at": starts_at, "ends_at": ends_at, "created_at": _clock.now(), "finalized_at": 0}
	return {"ok": true, "season_id": season_id}

func activate(season_id: String) -> Dictionary:
	if not _seasons.has(season_id): return {"ok": false, "reason": "NOT_FOUND"}
	_seasons[season_id]["state"] = ACTIVE
	return {"ok": true}

func lock(season_id: String) -> Dictionary:
	if not _seasons.has(season_id): return {"ok": false, "reason": "NOT_FOUND"}
	if str(_seasons[season_id]["state"]) == FINALIZED:
		return {"ok": true, "already_finalized": true}   # §18 — NUNCA rebaixa um season finalizado
	_seasons[season_id]["state"] = LOCKED   # §16 — novos ranked matches barrados; os já registrados terminam
	return {"ok": true}

func state_of(season_id: String) -> String:
	return str(_seasons.get(season_id, {}).get("state", ""))

func get_season(season_id: String) -> Dictionary:
	return _seasons.get(season_id, {}).duplicate(true)

func is_accepting_matches(season_id: String) -> bool:
	return state_of(season_id) == ACTIVE   # §16 — só ACTIVE registra novos matches

## FINALIZE (§17/§18) — idempotente. `ordered_profiles` = profiles já ORDENADOS pelo leaderboard PvP (posição 1 = topo).
func finalize(season_id: String, ordered_profiles: Array) -> Dictionary:
	if not _seasons.has(season_id):
		return {"ok": false, "reason": "NOT_FOUND"}
	var s: Dictionary = _seasons[season_id]
	if str(s["state"]) == FINALIZED:
		return {"ok": true, "already": true, "results": _history.get(season_id, []).duplicate(true), "champion": _champion_of(season_id)}
	s["state"] = FINALIZED; s["finalized_at"] = _clock.now()
	var results: Array = []
	var rewards_by_char: Dictionary = {}
	var pos := 0
	for p in ordered_profiles:
		pos += 1
		var prof: Dictionary = p
		var final_rank: String = str(prof["current_rank_id"])
		var peak_rank: String = str(prof["peak_rank_id"])
		# resultado CONGELADO (§19/§20)
		var res := {
			"season_id": season_id, "character_id": str(prof["character_id"]),
			"final_rating": int(prof["current_rating"]), "final_rank": final_rank,
			"position": pos, "wins": int(prof["wins"]), "losses": int(prof["losses"]),
			"matches": int(prof["season_matches"]), "peak_rating": int(prof["peak_rating"]),
			"champion": pos == 1,
		}
		results.append(res)
		# entitlements (§37-40) — participação válida = matches settled reais
		var valid_matches := int(prof["wins"]) + int(prof["losses"]) + int(prof["draws"])
		rewards_by_char[str(prof["character_id"])] = ArenaRewardPolicy.season_entitlements(final_rank, pos, valid_matches, peak_rank)
	_history[season_id] = results
	_rewards[season_id] = rewards_by_char
	return {"ok": true, "results": results.duplicate(true), "champion": _champion_of(season_id)}

func _champion_of(season_id: String) -> String:
	for r in _history.get(season_id, []):
		if int(r["position"]) == 1:
			return str(r["character_id"])
	return ""

func champion_of(season_id: String) -> String:
	return _champion_of(season_id)   # só após finalize (§29)

func history_of(season_id: String) -> Array:
	return _history.get(season_id, []).duplicate(true)

func result_for(season_id: String, character_id: String) -> Dictionary:
	for r in _history.get(season_id, []):
		if str(r["character_id"]) == character_id:
			return r.duplicate(true)
	return {}

func rewards_for(season_id: String, character_id: String) -> Array:
	return _rewards.get(season_id, {}).get(character_id, []).duplicate(true)

# ── snapshot/restore (restart §92) ──
func snapshot() -> Dictionary:
	return {"seasons": _seasons.duplicate(true), "history": _history.duplicate(true), "rewards": _rewards.duplicate(true)}

func restore(snap: Dictionary) -> void:
	_seasons = (snap.get("seasons", {}) as Dictionary)
	_history = (snap.get("history", {}) as Dictionary)
	_rewards = (snap.get("rewards", {}) as Dictionary)
