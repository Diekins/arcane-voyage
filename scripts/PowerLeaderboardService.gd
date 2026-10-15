class_name PowerLeaderboardService extends RefCounted
## FATIA A12 — CP / POWER LEADERBOARD (§49-58). Ranking de PROGRESSÃO (não de skill). Fonte = ESTADO AUTORITATIVO
## do servidor (§49): o CP é computado pelo AuthorityServer.power_snapshot (PowerBudget oficial §50) — o cliente
## NUNCA envia CP (§100/§CPLB-T02). Snapshot com source_revision: snapshot de revision antiga NÃO substitui a nova
## (§99). Cosmetic/VIP não entram no CP (§51 — a fórmula usa só stats de combate). Ordering determinístico com
## tie-break (§53). Paginação + my_rank + nearby (§55-57). DTO seguro, sem account/journal (§52/§58).

var authority: AuthorityServer
var _clock: ServerClock
var _snap: Dictionary = {}   # character_id → snapshot

func setup(p_authority: AuthorityServer, p_clock: ServerClock) -> void:
	authority = p_authority; _clock = p_clock

## Recalcula o CP de um character a partir do estado autoritativo (§98 hook seguro, sem espalhar em 50 arquivos).
func refresh_character(character_id: String) -> Dictionary:
	var ps := authority.power_snapshot(character_id)
	if ps.is_empty():
		return {"ok": false, "reason": "NO_CHARACTER"}
	var src_rev := int(ps["revision"])
	# §99 — snapshot baseado em revision antiga não substitui a nova
	if _snap.has(character_id) and int(_snap[character_id]["source_revision"]) > src_rev:
		return {"ok": false, "reason": "STALE_SNAPSHOT"}
	_snap[character_id] = {
		"character_id": character_id, "display_name": character_id,
		"cp": int(ps["cp"]), "offense": float(ps["offense"]), "effective_hp": float(ps["effective_hp"]),
		"prestige": int(ps["prestige"]), "highest_stage": int(ps["highest_stage"]),
		"source_revision": src_rev, "updated_at": _clock.now(),
	}
	return {"ok": true, "cp": int(ps["cp"])}

func cp_of(character_id: String) -> int:
	return int(_snap.get(character_id, {}).get("cp", -1))

## Ordena determinístico (§53): CP↓, Prestige↓, HighestStage↓, updated_at↑, character_id↑.
func ordered() -> Array:
	var arr: Array = _snap.values().duplicate()
	arr.sort_custom(func(x, y):
		if int(x["cp"]) != int(y["cp"]): return int(x["cp"]) > int(y["cp"])
		if int(x["prestige"]) != int(y["prestige"]): return int(x["prestige"]) > int(y["prestige"])
		if int(x["highest_stage"]) != int(y["highest_stage"]): return int(x["highest_stage"]) > int(y["highest_stage"])
		if int(x["updated_at"]) != int(y["updated_at"]): return int(x["updated_at"]) < int(y["updated_at"])
		return str(x["character_id"]) < str(y["character_id"]))
	return arr

## DTO seguro p/ leaderboard (§52/§58) — sem account/journal/rng.
func _dto(entry: Dictionary, position: int) -> Dictionary:
	return {
		"position": position, "character_id": str(entry["character_id"]), "display_name": str(entry["display_name"]),
		"cp": int(entry["cp"]), "prestige": int(entry["prestige"]), "highest_stage": int(entry["highest_stage"]),
	}

const MAX_PAGE := 100   # §55 cap server-side

func page(page_num: int, page_size: int) -> Dictionary:
	var size := clampi(page_size, 1, MAX_PAGE)
	var ord := ordered()
	var start := maxi(page_num, 0) * size
	var out: Array = []
	for i in range(start, mini(start + size, ord.size())):
		out.append(_dto(ord[i], i + 1))
	return {"entries": out, "total": ord.size(), "page": page_num, "page_size": size}

func my_position(character_id: String) -> int:
	var ord := ordered()
	for i in range(ord.size()):
		if str(ord[i]["character_id"]) == character_id:
			return i + 1
	return -1

func nearby(character_id: String, radius: int = 2) -> Array:
	var ord := ordered()
	var idx := -1
	for i in range(ord.size()):
		if str(ord[i]["character_id"]) == character_id: idx = i; break
	if idx < 0: return []
	var out: Array = []
	for i in range(maxi(0, idx - radius), mini(ord.size(), idx + radius + 1)):
		out.append(_dto(ord[i], i + 1))
	return out

func count() -> int: return _snap.size()

func snapshot() -> Dictionary: return {"snap": _snap.duplicate(true)}
func restore(s: Dictionary) -> void: _snap = (s.get("snap", {}) as Dictionary)
