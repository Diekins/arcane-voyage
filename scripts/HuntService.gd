class_name HuntService extends RefCounted
## FATIA A16.2/A16.4/A16.6 — ORQUESTRADOR das Hunting Grounds. Server-authoritative (§120/§121): o cliente só manda
## ground_id; spot/shard/xp/loot/elite/apex/kill são do SERVIDOR. Loop infinito de respawn (§37). XP real (§44) —
## PARTY compartilha (§68) com conservação (§69); LOOT pessoal por owner do spot (§72). Non-party isolado (§76). 1
## AFK/conta (§124 — paid slots não multiplicam). Offline agregado (§106/§111, sem AI frame-a-frame). Bench de
## economia (§113). Puro/testável (RNG semeada).

var repo: CharacterRepository
var items: ItemRegistry
var authority: AuthorityServer
var _clock: ServerClock
var world: HuntWorld
var party: HuntParty
var pve: PveMode
var _sessions: Dictionary = {}         # character_id → session
var _account_hunting: Dictionary = {}  # account → character (1 AFK/conta §124)
var _rng := RandomNumberGenerator.new()
var audit_log: Array = []

func setup(p_repo: CharacterRepository, p_items: ItemRegistry, p_authority: AuthorityServer, p_clock: ServerClock, rng_seed: int = 161616) -> void:
	repo = p_repo; items = p_items; authority = p_authority; _clock = p_clock
	world = HuntWorld.new(); world.setup(_clock)
	party = HuntParty.new()
	pve = PveMode.new()
	_rng.seed = rng_seed

# ── START / STOP (§36/§119/§122/§124) ──
func start_hunt(account: String, character: String, ground_id: String) -> Dictionary:
	if not repo.owns(account, character):
		return {"ok": false, "reason": "NOT_OWNER"}
	# idempotente (§122): já caçando a mesma ground → devolve a sessão
	if _sessions.has(character) and str(_sessions[character]["ground_id"]) == ground_id:
		return {"ok": true, "duplicate": true, "session": _public_session(character)}
	# 1 AFK/conta (§124) — outro char da conta já caçando → recusa
	if _account_hunting.has(account) and str(_account_hunting[account]) != character:
		return {"ok": false, "reason": "ACCOUNT_ALREADY_HUNTING"}
	if not HuntingGround.exists(ground_id):
		return {"ok": false, "reason": "NO_GROUND"}
	# unlock por CP + stage (server-authoritative)
	var ps := authority.power_snapshot(character)
	var cp := int(ps.get("cp", 0))
	var stage := int(ps.get("highest_stage", 1))
	if not HuntingGround.is_unlocked(ground_id, cp, stage):
		return {"ok": false, "reason": "LOCKED"}
	# guard de modo (§97): PROGRESSION↔HUNTING exclusivos
	var em := pve.enter_hunt(character)
	if not bool(em["ok"]):
		return {"ok": false, "reason": str(em["reason"])}
	# aloca spot (server §50)
	var alloc := world.allocate(ground_id, character)
	if not bool(alloc["ok"]):
		pve.exit_hunt(character)
		return {"ok": false, "reason": str(alloc["reason"])}
	_sessions[character] = {
		"character": character, "account": account, "ground_id": ground_id,
		"shard_key": str(alloc["shard_key"]), "spot_id": str(alloc["spot_id"]), "anchor": alloc["anchor"],
		"state": "HUNTING", "alive": true,
		"stats": {"elapsed": 0, "kills": 0, "xp": 0, "gold": 0, "items": 0, "elite": 0, "apex": 0, "deaths": 0, "apex_alive": 0},
	}
	_account_hunting[account] = character
	return {"ok": true, "session": _public_session(character)}

## Party entra JUNTA (§64/§65/§67) — valida TODOS, aloca spots adjacentes ATOMICAMENTE, senão rollback total.
func start_party_hunt(leader: String, ground_id: String) -> Dictionary:
	var pid := party.party_of(leader)
	if pid == "" or party.leader_of(pid) != leader:
		return {"ok": false, "reason": "NOT_LEADER"}
	if not HuntingGround.exists(ground_id):
		return {"ok": false, "reason": "NO_GROUND"}
	var members: Array = party.members_of(pid)
	# valida TODOS antes de alocar (§64)
	for m in members:
		var acc := repo.owner_of(m)
		if acc == "": return {"ok": false, "reason": "NO_MEMBER", "member": m}
		if _sessions.has(m): return {"ok": false, "reason": "MEMBER_HUNTING", "member": m}
		if _account_hunting.has(acc) and str(_account_hunting[acc]) != m: return {"ok": false, "reason": "ACCOUNT_ALREADY_HUNTING", "member": m}
		var ps := authority.power_snapshot(m)
		if not HuntingGround.is_unlocked(ground_id, int(ps.get("cp", 0)), int(ps.get("highest_stage", 1))):
			return {"ok": false, "reason": "LOCKED", "member": m}
		if not pve.can_enter_hunt(m):
			return {"ok": false, "reason": "MODE_BUSY", "member": m}
	# alocação atômica de spots adjacentes (§67)
	var alloc := world.allocate_party(ground_id, members)
	if not bool(alloc["ok"]):
		return {"ok": false, "reason": str(alloc["reason"])}
	# cria sessões
	for a in alloc["assignments"]:
		var m := str(a["character"]); var sp: Dictionary = a["spot"]
		pve.enter_hunt(m)
		_sessions[m] = {"character": m, "account": repo.owner_of(m), "ground_id": ground_id,
			"shard_key": str(sp["shard_key"]), "spot_id": str(sp["spot_id"]), "anchor": sp["anchor"],
			"state": "HUNTING", "alive": true,
			"stats": {"elapsed": 0, "kills": 0, "xp": 0, "gold": 0, "items": 0, "elite": 0, "apex": 0, "deaths": 0, "apex_alive": 0}}
		_account_hunting[repo.owner_of(m)] = m
	return {"ok": true, "party_id": pid, "shard_key": str(alloc["shard_key"]), "cluster": str(alloc["cluster"]), "members": members}

func stop_hunt(character: String) -> Dictionary:
	if not _sessions.has(character):
		return {"ok": true, "already": true}
	var acc := str(_sessions[character]["account"])
	world.release(character)
	pve.exit_hunt(character)
	_sessions.erase(character)
	if str(_account_hunting.get(acc, "")) == character:
		_account_hunting.erase(acc)
	return {"ok": true}

# ── KILL → REWARD (server-internal §121). rng determinístico. ──
func tick_kill(character: String) -> Dictionary:
	if not _sessions.has(character):
		return {"ok": false, "reason": "NO_SESSION"}
	var s: Dictionary = _sessions[character]
	var ground_id := str(s["ground_id"])
	var g := HuntingGround.get_ground(ground_id)
	# seleciona mob (weighted), rolls de elite/apex — AUTORIDADE decide (§40)
	var mob := HuntingGround.roll_mob(ground_id, _rng.randf())
	var base_xp := int(mob.get("base_xp", 10))
	var base_gold := int(mob.get("base_gold", 0))
	var is_elite := false; var is_apex := false
	var apex: Dictionary = g.get("apex_profile", {})
	if int(s["stats"]["apex_alive"]) < int(apex.get("cap", 1)) and _rng.randf() < float(apex.get("chance", 0.0)):
		is_apex = true
	elif _rng.randf() < float(g.get("elite_profile", {}).get("chance", 0.0)):
		is_elite = true
	# xp final (profile × elite/apex)
	var xp_mult := float(g.get("xp_profile", {}).get("mult", 1.0))
	if is_apex: xp_mult *= float(apex.get("xp_mult", 1.0))
	elif is_elite: xp_mult *= float(g.get("elite_profile", {}).get("xp_mult", 1.0))
	var kill_xp := int(round(float(base_xp) * xp_mult))
	# XP: party compartilha (§68/§69); solo = só o char
	var eligible := _eligible_xp_members(character, ground_id)
	var shares := HuntParty.share_xp(kill_xp, eligible)
	for m in shares:
		_grant_xp(str(m), int(shares[m]))
	# LOOT PESSOAL (§72) — só o owner do spot
	var drops := _roll_loot(character, ground_id, is_elite, is_apex)
	# gold (pessoal, do owner)
	_grant_gold(character, base_gold)
	# stats
	s["stats"]["kills"] = int(s["stats"]["kills"]) + 1
	s["stats"]["xp"] = int(s["stats"]["xp"]) + int(shares.get(character, 0))
	s["stats"]["gold"] = int(s["stats"]["gold"]) + base_gold
	s["stats"]["items"] = int(s["stats"]["items"]) + drops.size()
	if is_elite: s["stats"]["elite"] = int(s["stats"]["elite"]) + 1
	if is_apex: s["stats"]["apex"] = int(s["stats"]["apex"]) + 1
	return {"ok": true, "mob": str(mob.get("mob_id", "")), "elite": is_elite, "apex": is_apex, "xp_shares": shares, "drops": drops, "kill_xp": kill_xp}

## Membros elegíveis para XP (§71): mesma party + caçando a MESMA ground; senão só o próprio.
func _eligible_xp_members(character: String, ground_id: String) -> Array:
	var pid := party.party_of(character)
	if pid == "":
		return [character]
	var out: Array = []
	for m in party.members_of(pid):
		if _sessions.has(m) and str(_sessions[m]["ground_id"]) == ground_id and str(_sessions[m]["state"]) == "HUNTING":
			out.append(m)
	return out if out.size() > 0 else [character]

func _grant_xp(character: String, xp: int) -> void:
	if xp <= 0: return
	var ld := repo.load(character)
	if not bool(ld["ok"]): return
	var st: Dictionary = ld["state"]
	st["hero_xp"] = int(st.get("hero_xp", 0)) + xp
	repo.save(character, int(ld["revision"]), st)

func _grant_gold(character: String, gold: int) -> void:
	if gold <= 0: return
	var ld := repo.load(character)
	if not bool(ld["ok"]): return
	var st: Dictionary = ld["state"]
	st["hero_gold"] = int(st.get("hero_gold", 0)) + gold
	repo.save(character, int(ld["revision"]), st)

## Loot pessoal (§74) — ItemInstance real; entra no inventário do owner; iid registrado à conta dele.
func _roll_loot(character: String, ground_id: String, is_elite: bool, is_apex: bool) -> Array:
	var g := HuntingGround.get_ground(ground_id)
	var lp: Dictionary = g.get("loot_profile", {})
	var chance := float(lp.get("drop_chance", 0.0))
	var pool: Array = lp.get("pool", [])
	if is_apex: pool = g.get("apex_profile", {}).get("pool", pool); chance = 1.0
	elif is_elite: chance *= float(g.get("elite_profile", {}).get("drop_mult", 1.0))
	var out: Array = []
	if pool.is_empty() or _rng.randf() >= chance:
		return out
	var item_id := str(pool[_rng.randi() % pool.size()])
	if not ItemDB.exists(item_id) or not ItemDB.is_equippable(item_id):
		return out
	var acct := repo.owner_of(character)
	var seed := int(_rng.randi())
	var inst: Dictionary = ItemRoller.roll(item_id, seed, "hunt", 0)
	var iid := "hunt_%s_%08x" % [character, seed]
	inst["iid"] = iid
	if items.register(iid, acct, item_id, ItemRegistry.LOC_PLAYER):
		var ld := repo.load(character)
		var st: Dictionary = ld["state"]
		var arr: Array = st.get("item_instances", []); arr = arr.duplicate(); arr.append(inst); st["item_instances"] = arr
		repo.save(character, int(ld["revision"]), st)
		out.append({"iid": iid, "item_id": item_id})
	return out

# ── DISCONNECT / RECONNECT (§95/§96) ──
func on_disconnect(character: String, grace_secs: int = 120) -> void:
	if _sessions.has(character):
		world.grace(character, grace_secs)
		_sessions[character]["state"] = "GRACE"

func on_reconnect(character: String) -> Dictionary:
	if not _sessions.has(character):
		return {"ok": false, "reason": "NO_SESSION"}
	var rc := world.reconnect(character)
	if not bool(rc["ok"]):
		stop_hunt(character)
		return {"ok": false, "reason": str(rc["reason"])}
	_sessions[character]["state"] = "HUNTING"
	return {"ok": true, "session": _public_session(character)}

func tick_grace() -> void:
	var freed := world.tick_grace()
	if freed > 0:
		var to_stop: Array = []
		for cid in _sessions:
			if world.spot_of(cid).is_empty():
				to_stop.append(cid)
		for cid in to_stop:
			stop_hunt(cid)

# ── OFFLINE HUNT (§106-111) — AGREGADO, sem AI frame-a-frame ──
func offline_estimate(ground_id: String, hours: float) -> Dictionary:
	var g := HuntingGround.get_ground(ground_id)
	if g.is_empty(): return {}
	var h := clampf(hours, 0.0, 8.0)   # cap 8h (§108)
	var kph := int(g.get("offline_profile", {}).get("kills_per_hour", 0))
	var kills := int(round(float(kph) * h))
	# xp médio determinístico (média ponderada da mob table × profile), sem apex chuva (§109)
	var table: Array = g.get("mob_table", [])
	var tot_w := 0.0; var tot_xp := 0.0; var tot_gold := 0.0
	for e in table:
		tot_w += float(e["weight"]); tot_xp += float(e["weight"]) * float(e["base_xp"]); tot_gold += float(e["weight"]) * float(e.get("base_gold", 0))
	var avg_xp := (tot_xp / tot_w) * float(g.get("xp_profile", {}).get("mult", 1.0)) if tot_w > 0 else 0.0
	var avg_gold := (tot_gold / tot_w) if tot_w > 0 else 0.0
	return {"kills": kills, "xp": int(round(avg_xp * kills)), "gold": int(round(avg_gold * kills)),
		"items_est": int(round(float(kills) * float(g.get("loot_profile", {}).get("drop_chance", 0.0))))}

# ── ECONOMY BENCH (§113) — determinístico, fixture ──
func bench(ground_id: String, character: String, kills: int) -> Dictionary:
	var totals := {"xp": 0, "gold": 0, "items": 0, "elite": 0, "apex": 0}
	for i in range(kills):
		var r := tick_kill(character)
		if not bool(r.get("ok", false)): continue
		totals["xp"] = int(totals["xp"]) + int(r.get("kill_xp", 0))
		totals["items"] = int(totals["items"]) + (r.get("drops", []) as Array).size()
		if bool(r.get("elite", false)): totals["elite"] = int(totals["elite"]) + 1
		if bool(r.get("apex", false)): totals["apex"] = int(totals["apex"]) + 1
	return totals

# ── DTO seguro ──
func _public_session(character: String) -> Dictionary:
	var s: Dictionary = _sessions.get(character, {})
	if s.is_empty(): return {}
	return {"character": character, "ground_id": str(s["ground_id"]), "shard_key": str(s["shard_key"]),
		"spot_id": str(s["spot_id"]), "anchor": s["anchor"], "state": str(s["state"]), "stats": (s["stats"] as Dictionary).duplicate(true)}

func get_hunt_state(character: String) -> Dictionary:
	if not _sessions.has(character): return {"ok": false, "reason": "NO_SESSION"}
	return {"ok": true, "session": _public_session(character)}

func is_hunting(character: String) -> bool:
	return _sessions.has(character)

func session_count() -> int: return _sessions.size()

## Snapshots de presença da shard de um viewer (§85/§90) — só a MESMA shard.
func presence_for(viewer: String) -> Array:
	if not _sessions.has(viewer): return []
	var shard := str(_sessions[viewer]["shard_key"])
	var out: Array = []
	for cid in world.occupants_of_shard(shard):
		if cid == viewer: continue
		var ld := repo.load(cid)
		if not bool(ld["ok"]): continue
		var st: Dictionary = ld["state"]
		var sp := world.spot_of(cid)
		out.append(HuntPresence.snapshot(cid, str(st.get("display_name", "")), str(st.get("character_class", "")),
			st.get("appearance", {}), st.get("equipment", {}), str(sp.get("spot_id", "")), Vector2.ZERO,
			str(_sessions.get(cid, {}).get("state", "HUNTING")), HuntPresence.relationship(viewer, cid, party)))
	return out
