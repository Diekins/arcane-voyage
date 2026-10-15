class_name ArenaProfileRepository extends RefCounted
## FATIA A12 — PERSISTÊNCIA autoritativa do ArenaProfile (§11/§13). Rating PERTENCE ao CHARACTER (§12), nunca a
## peer/socket/session. Metadata online FORA do save do jogador (§91) — sem bump v9. Cada profile tem revision
## MONOTÔNICA + concorrência otimista; commit_two aplica A e B ATOMICAMENTE (§75). Persist/snapshot p/ restart (§92).

var _store: Dictionary = {}   # character_id → {profile, revision}

## Fabrica um profile inicial (§11). rating = baseline; rank provisional até placements.
static func new_profile(character_id: String, season_id: String) -> Dictionary:
	return {
		"character_id": character_id,
		"current_rating": ArenaRating.START_RATING, "peak_rating": ArenaRating.START_RATING,
		"placements_played": 0, "placements_required": ArenaRating.PLACEMENTS_REQUIRED,
		"wins": 0, "losses": 0, "draws": 0, "forfeits": 0,
		"current_streak": 0, "best_streak": 0,
		"season_matches": 0, "lifetime_wins": 0, "lifetime_losses": 0,
		"current_rank_id": ArenaRank.RANK_1, "peak_rank_id": ArenaRank.RANK_1,
		"last_match_at": 0, "season_id": season_id,
		"badges": [], "archetype_id": "", "loadout_id": "",
	}

func has(character_id: String) -> bool:
	return _store.has(character_id)

func get_or_create(character_id: String, season_id: String) -> Dictionary:
	if not _store.has(character_id):
		_store[character_id] = {"profile": new_profile(character_id, season_id), "revision": 1}
	return (_store[character_id]["profile"] as Dictionary).duplicate(true)

func get_profile(character_id: String) -> Dictionary:
	if not _store.has(character_id):
		return {}
	return (_store[character_id]["profile"] as Dictionary).duplicate(true)

func revision_of(character_id: String) -> int:
	return int(_store[character_id]["revision"]) if _store.has(character_id) else -1

func save(character_id: String, expected_revision: int, profile: Dictionary) -> Dictionary:
	if not _store.has(character_id):
		return {"ok": false, "reason": "NOT_FOUND"}
	if int(_store[character_id]["revision"]) != expected_revision:
		return {"ok": false, "reason": "STALE"}
	_store[character_id]["profile"] = profile.duplicate(true)
	_store[character_id]["revision"] = expected_revision + 1
	return {"ok": true, "revision": expected_revision + 1}

## COMMIT ATÔMICO de 2 profiles (§75): valida ambas revisions, aplica ambas ou NADA.
func commit_two(a_id: String, a_rev: int, a_prof: Dictionary, b_id: String, b_rev: int, b_prof: Dictionary) -> Dictionary:
	if not _store.has(a_id) or not _store.has(b_id):
		return {"ok": false, "reason": "NOT_FOUND"}
	if int(_store[a_id]["revision"]) != a_rev or int(_store[b_id]["revision"]) != b_rev:
		return {"ok": false, "reason": "STALE"}
	_store[a_id]["profile"] = a_prof.duplicate(true); _store[a_id]["revision"] = a_rev + 1
	_store[b_id]["profile"] = b_prof.duplicate(true); _store[b_id]["revision"] = b_rev + 1
	return {"ok": true, "revisions": {a_id: a_rev + 1, b_id: b_rev + 1}}

func all_ids() -> Array:
	return _store.keys()

func count() -> int:
	return _store.size()

# ── snapshot/restore + persistência (restart §92) ──
func snapshot() -> Dictionary:
	return {"store": _store.duplicate(true)}

func restore(snap: Dictionary) -> void:
	_store = (snap.get("store", {}) as Dictionary)
	for cid in _store:
		_store[cid]["revision"] = int(_store[cid]["revision"])

func persist_to(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(snapshot())); f.close(); return true

func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return false
	var j = JSON.parse_string(f.get_as_text()); f.close()
	if typeof(j) != TYPE_DICTIONARY: return false
	restore(j); return true
