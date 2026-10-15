class_name ArenaMatchRepository extends RefCounted
## FATIA A12 — REGISTRO de matches competitivos (§43/§44). Cada match pertence a UMA season (§16) e carrega os dados
## úteis p/ anti-wintrade futuro (§41): participantes, winner, reason, duração, rating antes/delta/depois, tempo do
## servidor. Estados fundação: CREATED→READY→RUNNING→FINISHED / CANCELLED / NO_CONTEST (§44) — a luta NÃO é
## simulada aqui (A12.1). Settlement EXACTLY-ONCE por match_id (§45/§95): o marcador de settled vive no próprio
## record. Sem realtime.

const CREATED := "CREATED"
const READY := "READY"
const RUNNING := "RUNNING"
const FINISHED := "FINISHED"
const CANCELLED := "CANCELLED"
const NO_CONTEST := "NO_CONTEST"

var _matches: Dictionary = {}   # match_id → record
var _counter := 0
var _rng := RandomNumberGenerator.new()

func setup(rng_seed: int = 246810) -> void:
	_rng.seed = rng_seed

func new_match_id() -> String:
	_counter += 1
	return "match_%d_%08x" % [_counter, _rng.randi()]

func create_match(match_id: String, season_id: String, a: String, b: String, now: int) -> Dictionary:
	if _matches.has(match_id):
		return {"ok": false, "reason": "EXISTS"}
	_matches[match_id] = {
		"match_id": match_id, "season_id": season_id,
		"participant_a": a, "participant_b": b, "state": CREATED,
		"created_at": now, "started_at": 0, "finished_at": 0,
		"result": "", "reason": "", "settled": false,
		"rating_before": {}, "rating_delta": {}, "rating_after": {},
	}
	return {"ok": true, "match_id": match_id}

func has(match_id: String) -> bool:
	return _matches.has(match_id)

func get_match(match_id: String) -> Dictionary:
	return _matches.get(match_id, {}).duplicate(true)

func set_state(match_id: String, state: String, now: int = -1) -> void:
	if not _matches.has(match_id): return
	_matches[match_id]["state"] = state
	if state == RUNNING and now >= 0: _matches[match_id]["started_at"] = now

func is_settled(match_id: String) -> bool:
	return _matches.has(match_id) and bool(_matches[match_id]["settled"])

## Marca o match como settled com o resultado (EXACTLY-ONCE §45). Idempotência: quem chama checa is_settled antes.
func mark_settled(match_id: String, result: String, reason: String, before: Dictionary, delta: Dictionary, after: Dictionary, state: String, now: int) -> void:
	if not _matches.has(match_id): return
	var m: Dictionary = _matches[match_id]
	m["settled"] = true; m["result"] = result; m["reason"] = reason; m["state"] = state
	m["finished_at"] = now
	m["rating_before"] = before.duplicate(true); m["rating_delta"] = delta.duplicate(true); m["rating_after"] = after.duplicate(true)

func all_ids() -> Array:
	return _matches.keys()

func count() -> int:
	return _matches.size()

func snapshot() -> Dictionary:
	return {"matches": _matches.duplicate(true), "counter": _counter}

func restore(snap: Dictionary) -> void:
	_matches = (snap.get("matches", {}) as Dictionary)
	_counter = int(snap.get("counter", 0))
