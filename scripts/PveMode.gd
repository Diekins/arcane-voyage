class_name PveMode extends RefCounted
## FATIA A16.6 — GUARD de modo PvE (§97/§ActiveSpaceGuard). PROGRESSION e HUNTING são EXCLUSIVOS (§97). Nunca
## HUNTING + RANKED (§ActiveSpaceGuard). Por CHARACTER (runtime). Transições seguras (§98/§99); sem double reward
## (§100 — a morte pertence a UM modo). Puro/testável.

const PROGRESSION := "PVE_PROGRESSION"
const HUNTING := "PVE_HUNTING"
const ACTIVE_FUTURE := "ACTIVE_SPACE_FUTURE"
const COMPETITIVE_FUTURE := "COMPETITIVE_FUTURE"

var _mode: Dictionary = {}   # character_id → mode (default PROGRESSION)

func mode_of(cid: String) -> String:
	return str(_mode.get(cid, PROGRESSION))

func can_enter_hunt(cid: String) -> bool:
	return mode_of(cid) != HUNTING and mode_of(cid) != COMPETITIVE_FUTURE

func can_enter_ranked(cid: String) -> bool:
	return mode_of(cid) != HUNTING

func enter_hunt(cid: String) -> Dictionary:
	if not can_enter_hunt(cid):
		return {"ok": false, "reason": "MODE_BUSY", "mode": mode_of(cid)}
	_mode[cid] = HUNTING
	return {"ok": true}

func exit_hunt(cid: String) -> void:
	if mode_of(cid) == HUNTING:
		_mode[cid] = PROGRESSION

func set_mode(cid: String, mode: String) -> void:
	_mode[cid] = mode

func is_hunting(cid: String) -> bool:
	return mode_of(cid) == HUNTING
