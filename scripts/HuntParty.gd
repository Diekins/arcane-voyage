class_name HuntParty extends RefCounted
## FATIA A16.4 — HUNT PARTY FOUNDATION (§60-71). Só o mínimo: create/invite/accept/leave/disband (§61). NÃO friends/
## guild/raid/voice/chat/matchmaking (§61). ★ XP COMPARTILHADA (equal share §68) com CONSERVAÇÃO (§69 — soma ≤ base,
## arredondamento determinístico, nenhum XP nasce). LOOT INDIVIDUAL por owner do spot (§72, resolvido no HuntService).
## Non-party = isolado (§76). Support ajuda ally (§77-80). Anti-parallel-AFK: 1 progression-active char/conta (A13/§124).
## Ephemeral/server runtime (§62). PARTY_SIZE_PRODUCT_TUNING_REQUIRED.

const PARTY_MAX_SIZE := 4   # fixture conservadora (§63) — PARTY_SIZE_PRODUCT_TUNING_REQUIRED

var _parties: Dictionary = {}     # party_id → {party_id, leader, members:[cid], state, created_at, invites:{cid:true}}
var _by_char: Dictionary = {}     # character_id → party_id
var _counter := 0

func create(leader: String) -> Dictionary:
	if _by_char.has(leader):
		return {"ok": false, "reason": "ALREADY_IN_PARTY"}
	_counter += 1
	var pid := "party_%d" % _counter
	_parties[pid] = {"party_id": pid, "leader": leader, "members": [leader], "state": "OPEN", "invites": {}}
	_by_char[leader] = pid
	return {"ok": true, "party_id": pid}

func invite(leader: String, target: String) -> Dictionary:
	var pid := party_of(leader)
	if pid == "" or str(_parties[pid]["leader"]) != leader:
		return {"ok": false, "reason": "NOT_LEADER"}
	if _by_char.has(target):
		return {"ok": false, "reason": "TARGET_IN_PARTY"}
	if (_parties[pid]["members"] as Array).size() >= PARTY_MAX_SIZE:
		return {"ok": false, "reason": "PARTY_FULL"}
	_parties[pid]["invites"][target] = true
	return {"ok": true, "party_id": pid}

func accept(target: String, party_id: String) -> Dictionary:
	if not _parties.has(party_id) or not (_parties[party_id]["invites"] as Dictionary).has(target):
		return {"ok": false, "reason": "NO_INVITE"}
	if _by_char.has(target):
		return {"ok": false, "reason": "ALREADY_IN_PARTY"}
	if (_parties[party_id]["members"] as Array).size() >= PARTY_MAX_SIZE:
		return {"ok": false, "reason": "PARTY_FULL"}
	(_parties[party_id]["members"] as Array).append(target)
	_parties[party_id]["invites"].erase(target)
	_by_char[target] = party_id
	return {"ok": true, "party_id": party_id}

func leave(cid: String) -> Dictionary:
	var pid := party_of(cid)
	if pid == "": return {"ok": false, "reason": "NOT_IN_PARTY"}
	(_parties[pid]["members"] as Array).erase(cid)
	_by_char.erase(cid)
	# leader saiu → handoff determinístico (§84)
	if str(_parties[pid]["leader"]) == cid:
		var members: Array = _parties[pid]["members"]
		if members.is_empty():
			_parties.erase(pid)
			return {"ok": true, "disbanded": true}
		members.sort()
		_parties[pid]["leader"] = str(members[0])
	return {"ok": true, "new_leader": str(_parties.get(pid, {}).get("leader", ""))}

func disband(leader: String) -> Dictionary:
	var pid := party_of(leader)
	if pid == "" or str(_parties[pid]["leader"]) != leader:
		return {"ok": false, "reason": "NOT_LEADER"}
	for m in (_parties[pid]["members"] as Array).duplicate():
		_by_char.erase(m)
	_parties.erase(pid)
	return {"ok": true}

func party_of(cid: String) -> String:
	return str(_by_char.get(cid, ""))

func members_of(pid: String) -> Array:
	return (_parties.get(pid, {}).get("members", []) as Array).duplicate()

func leader_of(pid: String) -> String:
	return str(_parties.get(pid, {}).get("leader", ""))

func is_same_party(a: String, b: String) -> bool:
	return party_of(a) != "" and party_of(a) == party_of(b)

## XP EQUAL SHARE com CONSERVAÇÃO (§68/§69). base → {cid: share}. soma == base (nenhum XP nasce; resto p/ os 1ºs).
static func share_xp(base_xp: int, eligible: Array) -> Dictionary:
	var out: Dictionary = {}
	var n := eligible.size()
	if n == 0: return out
	var per := int(base_xp) / n            # floor
	var rem := int(base_xp) - per * n       # resto determinístico
	var sorted := eligible.duplicate(); sorted.sort()
	for i in range(n):
		out[str(sorted[i])] = per + (1 if i < rem else 0)
	return out   # soma = per*n + rem = base_xp  (conservação)

func party_count() -> int: return _parties.size()
