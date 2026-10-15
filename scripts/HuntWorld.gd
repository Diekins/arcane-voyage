class_name HuntWorld extends RefCounted
## FATIA A16.3 — SPOTS / CLUSTERS / SHARDS (§48-59,92-96). ★ SERVER-AUTHORITATIVE: o cliente NÃO escolhe spot/
## cluster/shard/position (§50/§120). Layout data-driven por MAP (reutilizado por várias grounds §34). SOCIAL PACKING
## (§51): 2º solo prefere spot ADJACENTE; preenche cluster parcial antes de espalhar. Reserva ATÔMICA, nunca 2 no
## mesmo spot (§93). Shard cheia → próxima (§54). Disconnect GRACE (§95): spot fica reservado; reconnect volta ao
## mesmo; expiry libera. Uma conta NÃO ocupa 2 spots (§124 — via HuntService/A13). Puro/testável.

const SHARD_SPOT_CAP := 8   # 2 clusters × 4 spots (config-driven §54)
const CLUSTERS_PER_SHARD := 2
const SPOTS_PER_CLUSTER := 4

# estados de reserva (§92)
const FREE := "FREE"
const RESERVED := "RESERVED"
const OCCUPIED := "OCCUPIED"
const GRACE := "GRACE_RESERVED"

var _clock: ServerClock
var _shards: Dictionary = {}        # shard_key → {ground_id, map_id, index, spots:{spot_id→{state,character,expires}}}
var _by_char: Dictionary = {}       # character_id → {shard_key, spot_id}
var _shard_counter: Dictionary = {} # ground_id → nº de shards criados

func setup(clock: ServerClock) -> void:
	_clock = clock

func _anchor(cluster_i: int, spot_i: int) -> Vector2:
	return Vector2(200.0 + cluster_i * 600.0 + (spot_i % 2) * 180.0, 200.0 + (spot_i / 2) * 180.0)

func _new_shard(ground_id: String) -> String:
	_shard_counter[ground_id] = int(_shard_counter.get(ground_id, 0)) + 1
	var idx := int(_shard_counter[ground_id])
	var key := "%s#shard%d" % [ground_id, idx]
	var spots: Dictionary = {}
	for c in range(CLUSTERS_PER_SHARD):
		for s in range(SPOTS_PER_CLUSTER):
			var sid := "%s_C%d_S%d" % [key, c, s]
			spots[sid] = {"state": FREE, "character": "", "expires": 0, "cluster": "C%d" % c, "anchor": _anchor(c, s)}
	_shards[key] = {"ground_id": ground_id, "map_id": HuntingGround.map_of(ground_id), "index": idx, "spots": spots}
	return key

func _spot_free(sp: Dictionary, now: int) -> bool:
	if str(sp["state"]) == FREE: return true
	if str(sp["state"]) == GRACE and now > int(sp["expires"]): return true
	return false

func _cluster_occupancy(shard: Dictionary, cluster: String, now: int) -> Array:
	var occupied := 0; var total := 0
	for sid in shard["spots"]:
		if str(shard["spots"][sid]["cluster"]) != cluster: continue
		total += 1
		if not _spot_free(shard["spots"][sid], now): occupied += 1
	return [occupied, total]

## Aloca UM spot p/ solo (§51 social packing). Retorna {ok, shard_key, cluster, spot_id, anchor}.
func allocate(ground_id: String, character_id: String) -> Dictionary:
	if _by_char.has(character_id):
		return {"ok": false, "reason": "ALREADY_ALLOCATED"}
	var now := _clock.now()
	# procura em shards existentes da ground; prefere cluster PARCIALMENTE ocupado (social density)
	var candidates: Array = []
	for key in _shards:
		if str(_shards[key]["ground_id"]) != ground_id: continue
		candidates.append(key)
	# ordena por índice; dentro, prefere cluster parcial
	for key in candidates:
		var shard: Dictionary = _shards[key]
		var best_sid := ""
		var best_occ := -1
		for sid in shard["spots"]:
			var sp: Dictionary = shard["spots"][sid]
			if not _spot_free(sp, now): continue
			var occ: Array = _cluster_occupancy(shard, str(sp["cluster"]), now)
			# cluster parcial (occ>0 e não cheio) tem prioridade máxima; senão qualquer free
			var score := int(occ[0]) if int(occ[0]) < int(occ[1]) else -1
			if score > best_occ:
				best_occ = score; best_sid = sid
		if best_sid != "":
			return _reserve(key, best_sid, character_id, now)
	# nenhuma shard com vaga → nova shard (§54)
	var nk := _new_shard(ground_id)
	var first := str((_shards[nk]["spots"] as Dictionary).keys()[0])
	return _reserve(nk, first, character_id, now)

func _reserve(shard_key: String, spot_id: String, character_id: String, now: int) -> Dictionary:
	var sp: Dictionary = _shards[shard_key]["spots"][spot_id]
	if not _spot_free(sp, now):
		return {"ok": false, "reason": "SPOT_TAKEN"}   # §93 atômico — nunca dois no mesmo spot
	sp["state"] = OCCUPIED; sp["character"] = character_id; sp["expires"] = 0
	_by_char[character_id] = {"shard_key": shard_key, "spot_id": spot_id, "anchor": sp["anchor"]}   # A17.4: anchor real p/ viagem
	return {"ok": true, "shard_key": shard_key, "cluster": str(sp["cluster"]), "spot_id": spot_id, "anchor": sp["anchor"]}

## Aloca N spots ADJACENTES (mesmo cluster) p/ party, ATÔMICO (§65/§67). Rollback total em falha (§66/§67).
func allocate_party(ground_id: String, member_ids: Array) -> Dictionary:
	if member_ids.is_empty():
		return {"ok": false, "reason": "EMPTY"}
	for m in member_ids:
		if _by_char.has(m): return {"ok": false, "reason": "MEMBER_ALLOCATED"}
	var now := _clock.now()
	# procura um cluster (em qualquer shard existente, senão nova) com N spots livres contíguos
	var keys: Array = []
	for key in _shards:
		if str(_shards[key]["ground_id"]) == ground_id: keys.append(key)
	keys.append("")   # sentinela: tentar nova shard por último
	for key in keys:
		var k: String = key if key != "" else _new_shard(ground_id)
		var shard: Dictionary = _shards[k]
		for c in range(CLUSTERS_PER_SHARD):
			var cluster := "C%d" % c
			var free_spots: Array = []
			for sid in shard["spots"]:
				if str(shard["spots"][sid]["cluster"]) == cluster and _spot_free(shard["spots"][sid], now):
					free_spots.append(sid)
			if free_spots.size() >= member_ids.size():
				# reserva atômica
				var assign: Array = []
				for i in range(member_ids.size()):
					var r := _reserve(k, str(free_spots[i]), str(member_ids[i]), now)
					if not bool(r["ok"]):
						# rollback (§67)
						for a in assign: release(str(a["character"]))
						return {"ok": false, "reason": "RACE_LOST"}
					assign.append({"character": member_ids[i], "spot": r})
				return {"ok": true, "shard_key": k, "cluster": cluster, "assignments": assign}
	return {"ok": false, "reason": "NO_CONTIGUOUS_CLUSTER"}   # §66 party cohesion > vaga isolada

func release(character_id: String) -> void:
	if not _by_char.has(character_id): return
	var loc: Dictionary = _by_char[character_id]
	var sp: Dictionary = _shards[str(loc["shard_key"])]["spots"][str(loc["spot_id"])]
	sp["state"] = FREE; sp["character"] = ""; sp["expires"] = 0
	_by_char.erase(character_id)

## Disconnect grace (§95): mantém o spot reservado por `grace_secs`.
func grace(character_id: String, grace_secs: int) -> void:
	if not _by_char.has(character_id): return
	var loc: Dictionary = _by_char[character_id]
	var sp: Dictionary = _shards[str(loc["shard_key"])]["spots"][str(loc["spot_id"])]
	sp["state"] = GRACE; sp["expires"] = _clock.now() + grace_secs

## Reconnect (§95): se o spot ainda é do char (não expirou), reocupa o MESMO.
func reconnect(character_id: String) -> Dictionary:
	if not _by_char.has(character_id): return {"ok": false, "reason": "NO_RESERVATION"}
	var loc: Dictionary = _by_char[character_id]
	var sp: Dictionary = _shards[str(loc["shard_key"])]["spots"][str(loc["spot_id"])]
	if str(sp["state"]) == GRACE and _clock.now() > int(sp["expires"]):
		release(character_id)
		return {"ok": false, "reason": "GRACE_EXPIRED"}
	sp["state"] = OCCUPIED
	return {"ok": true, "shard_key": str(loc["shard_key"]), "spot_id": str(loc["spot_id"]), "anchor": sp["anchor"]}

## Libera spots com grace expirado (§95). Retorna quantos liberou.
func tick_grace() -> int:
	var now := _clock.now(); var freed := 0
	var to_free: Array = []
	for cid in _by_char:
		var loc: Dictionary = _by_char[cid]
		var sp: Dictionary = _shards[str(loc["shard_key"])]["spots"][str(loc["spot_id"])]
		if str(sp["state"]) == GRACE and now > int(sp["expires"]):
			to_free.append(cid)
	for cid in to_free:
		release(cid); freed += 1
	return freed

func spot_of(character_id: String) -> Dictionary:
	return _by_char.get(character_id, {}).duplicate(true)

func shard_of(character_id: String) -> String:
	return str(_by_char.get(character_id, {}).get("shard_key", ""))

func occupants_of_shard(shard_key: String) -> Array:
	var out: Array = []
	if not _shards.has(shard_key): return out
	for sid in _shards[shard_key]["spots"]:
		var sp: Dictionary = _shards[shard_key]["spots"][sid]
		if str(sp["character"]) != "": out.append(str(sp["character"]))
	return out

func shard_count(ground_id: String) -> int:
	return int(_shard_counter.get(ground_id, 0))

func total_reservations() -> int:
	return _by_char.size()
