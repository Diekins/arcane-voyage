class_name ArenaService extends RefCounted
## FATIA A12 — ORQUESTRADOR da Arena Competitive Foundation. Reúne profiles/seasons/matches/settlement/CP-leaderboard
## e expõe: queries de leitura (CLIENT_ALLOWED §117), settlement INTERNO (§10 — nunca do cliente), finalize de
## season, soft reset, badges/nameplate. PvP leaderboard = rating↓, wins↓, losses↑, char↑ (§54), provisional
## EXCLUÍDO. CP leaderboard delega ao PowerLeaderboardService. Três identidades separadas: CP ≠ PvP Rating ≠
## Prestige (§2) — nunca um ranking único.

var authority: AuthorityServer
var char_repo: CharacterRepository
var items: ItemRegistry
var _clock: ServerClock

var profiles: ArenaProfileRepository
var seasons: ArenaSeasonManager
var matches: ArenaMatchRepository
var settlement: ArenaSettlementService
var power: PowerLeaderboardService
var current_season_id := ""

func setup(p_authority: AuthorityServer, p_char_repo: CharacterRepository, p_items: ItemRegistry, p_clock: ServerClock, rng_seed: int = 13579) -> void:
	authority = p_authority; char_repo = p_char_repo; items = p_items; _clock = p_clock
	profiles = ArenaProfileRepository.new()
	seasons = ArenaSeasonManager.new(); seasons.setup(_clock)
	matches = ArenaMatchRepository.new(); matches.setup(rng_seed)
	settlement = ArenaSettlementService.new(); settlement.setup(profiles, matches, seasons, _clock)
	power = PowerLeaderboardService.new(); power.setup(authority, _clock)

# ── SEASONS ──
func start_season(season_id: String, duration: int = 100000) -> Dictionary:
	var now := _clock.now()
	seasons.create_season(season_id, now, now + duration)
	seasons.activate(season_id)
	current_season_id = season_id
	return {"ok": true, "season_id": season_id}

func lock_season(season_id: String) -> Dictionary:
	return seasons.lock(season_id)

## Finaliza: ordena os classificados (não-provisionais §54), congela resultados, aplica badges PERMANENTES aos perfis.
func finalize_season(season_id: String) -> Dictionary:
	seasons.lock(season_id)
	var ordered := pvp_ordered_profiles(season_id)
	var fin := seasons.finalize(season_id, ordered)
	if bool(fin.get("already", false)):
		return fin   # §18 idempotente — badges já aplicados
	# aplica badges permanentes (§31) aos perfis
	for res in fin["results"]:
		var cid := str(res["character_id"])
		var badge := ""
		if int(res["position"]) == 1: badge = "SEASON_CHAMPION_" + season_id      # §29 só o #1
		elif int(res["position"]) <= 10: badge = "TOP_10_" + season_id
		elif int(res["position"]) <= 100: badge = "TOP_100_" + season_id
		if badge != "":
			_add_permanent_badge(cid, badge)
	return fin

func _add_permanent_badge(character_id: String, badge: String) -> void:
	if not profiles.has(character_id): return
	var rev := profiles.revision_of(character_id)
	var p := profiles.get_profile(character_id)
	var b: Array = p["badges"]
	if not b.has(badge):
		b.append(badge); p["badges"] = b
		profiles.save(character_id, rev, p)

## Soft reset p/ nova season (§78/§79): rating puxado ao baseline, placements/season stats zerados, lifetime+badges
## permanentes PRESERVADOS. Prestige do PvE NÃO afeta isso (§82).
func soft_reset_for_new_season(new_season_id: String) -> int:
	var n := 0
	for cid in profiles.all_ids():
		var rev := profiles.revision_of(cid)
		var p := profiles.get_profile(cid)
		p["current_rating"] = ArenaRating.soft_reset(int(p["current_rating"]))
		p["peak_rating"] = int(p["current_rating"])
		p["placements_played"] = 0
		p["wins"] = 0; p["losses"] = 0; p["draws"] = 0; p["forfeits"] = 0
		p["current_streak"] = 0; p["best_streak"] = 0; p["season_matches"] = 0
		p["current_rank_id"] = ArenaRank.rank_for(int(p["current_rating"]))
		p["peak_rank_id"] = p["current_rank_id"]
		p["season_id"] = new_season_id
		profiles.save(cid, rev, p)
		n += 1
	start_season(new_season_id)
	return n

# ── MATCH (server-internal: cria e settle; cliente NUNCA fornece resultado §10) ──
func create_match(a: String, b: String) -> Dictionary:
	if a == b:
		return {"ok": false, "reason": "SAME_CHARACTER"}
	if not seasons.is_accepting_matches(current_season_id):
		return {"ok": false, "reason": "SEASON_NOT_ACTIVE"}   # §16
	profiles.get_or_create(a, current_season_id); profiles.get_or_create(b, current_season_id)
	var mid := matches.new_match_id()
	matches.create_match(mid, current_season_id, a, b, _clock.now())
	matches.set_state(mid, ArenaMatchRepository.RUNNING, _clock.now())
	return {"ok": true, "match_id": mid, "season_id": current_season_id}

func settle_match(match_id: String, winner: String, reason: String) -> Dictionary:
	return settlement.settle(match_id, winner, reason)   # SERVER_INTERNAL (§10)

## A15.5 §63 — snapshot Arena-ready do character: class/loadout/abilities AUTORITATIVOS + combate NORMALIZADO
## (imutável). O cliente não inventa class/skill/weapon (§62). Appearance/cosmetic/visual = 0 poder (§64).
func combat_snapshot_for(character_id: String) -> Dictionary:
	var ld := char_repo.load(character_id)
	if not bool(ld["ok"]): return {}
	var st: Dictionary = ld["state"]
	var ps := authority.power_snapshot(character_id)
	var norm := ArenaNormalizationPolicy.normalize_full(float(ps.get("offense", 0.0)), float(ps.get("effective_hp", 0.0)))
	var class_id := str(st.get("character_class", "LEGACY_CLASS"))
	var loadouts: Array = st.get("loadouts", [])
	var idx := int(st.get("active_loadout", 0))
	var loadout: Dictionary = loadouts[idx] if idx >= 0 and idx < loadouts.size() else {}
	return {
		"character_id": character_id, "class_id": class_id, "loadout": loadout,
		"abilities": ClassAbilityLibrary.abilities_of(class_id),
		"combat": norm, "revision": int(ld["revision"]),
		"appearance_power": 0, "cosmetic_power": 0, "visual_power": 0,   # §64
	}

# ── PvP LEADERBOARD (§54) — rating↓, wins↓, losses↑, char↑; provisional EXCLUÍDO ──
func pvp_ordered_profiles(season_id: String = "") -> Array:
	var arr: Array = []
	for cid in profiles.all_ids():
		var p := profiles.get_profile(cid)
		if season_id != "" and str(p["season_id"]) != season_id: continue
		if ArenaRating.is_provisional(int(p["placements_played"])): continue   # §54/PVPLB-T02
		arr.append(p)
	arr.sort_custom(func(x, y):
		if int(x["current_rating"]) != int(y["current_rating"]): return int(x["current_rating"]) > int(y["current_rating"])
		if int(x["wins"]) != int(y["wins"]): return int(x["wins"]) > int(y["wins"])
		if int(x["losses"]) != int(y["losses"]): return int(x["losses"]) < int(y["losses"])
		return str(x["character_id"]) < str(y["character_id"]))
	return arr

func _pvp_dto(p: Dictionary, position: int) -> Dictionary:
	# DTO seguro (§58) — sem account/session/inventory/journal. rating só se não-provisional.
	var provisional := ArenaRating.is_provisional(int(p["placements_played"]))
	return {
		"position": position, "character_id": str(p["character_id"]), "display_name": str(p["character_id"]),
		"rank": str(p["current_rank_id"]), "rank_display": ArenaRank.display_name(str(p["current_rank_id"])),
		"rating": (int(p["current_rating"]) if not provisional else -1),
		"wins": int(p["wins"]), "losses": int(p["losses"]), "best_streak": int(p["best_streak"]),
		"cp": power.cp_of(str(p["character_id"])), "prestige": int(p.get("prestige", 0)),
		"badge": nameplate_primary(str(p["character_id"])),
	}

func pvp_page(page_num: int, page_size: int) -> Dictionary:
	var size := clampi(page_size, 1, PowerLeaderboardService.MAX_PAGE)
	var ord := pvp_ordered_profiles(current_season_id)
	var start := maxi(page_num, 0) * size
	var out: Array = []
	for i in range(start, mini(start + size, ord.size())):
		out.append(_pvp_dto(ord[i], i + 1))
	return {"entries": out, "total": ord.size(), "page": page_num, "page_size": size}

func pvp_my_position(character_id: String) -> int:
	var ord := pvp_ordered_profiles(current_season_id)
	for i in range(ord.size()):
		if str(ord[i]["character_id"]) == character_id: return i + 1
	return -1

func pvp_nearby(character_id: String, radius: int = 2) -> Array:
	var ord := pvp_ordered_profiles(current_season_id)
	var idx := -1
	for i in range(ord.size()):
		if str(ord[i]["character_id"]) == character_id: idx = i; break
	if idx < 0: return []
	var out: Array = []
	for i in range(maxi(0, idx - radius), mini(ord.size(), idx + radius + 1)):
		out.append(_pvp_dto(ord[i], i + 1))
	return out

func current_leader() -> String:
	var ord := pvp_ordered_profiles(current_season_id)
	return str(ord[0]["character_id"]) if ord.size() > 0 else ""   # §29 líder atual ≠ campeão

# ── BADGES / NAMEPLATE (§30-33) ──
func badges_for(character_id: String) -> Dictionary:
	var p := profiles.get_profile(character_id)
	if p.is_empty(): return {}
	return {
		"current_rank_badge": str(p["current_rank_id"]),         # TEMPORÁRIO (§31)
		"permanent": (p["badges"] as Array).duplicate(),         # PERMANENTES (champion/top10/top100)
	}

## Prioridade Champion > Top10 > Current Rank (§33) — 1 destaque só, nunca árvore de natal.
func nameplate_primary(character_id: String) -> String:
	var p := profiles.get_profile(character_id)
	if p.is_empty(): return ""
	for b in p["badges"]:
		if str(b).begins_with("SEASON_CHAMPION"): return str(b)
	for b in p["badges"]:
		if str(b).begins_with("TOP_10"): return str(b)
	return str(p["current_rank_id"])

func nameplate(character_id: String) -> Dictionary:
	# NameplateCompetitiveState (§32) — DTO; sem render.
	return {"character_id": character_id, "primary": nameplate_primary(character_id)}

# ── QUERY DTOs (rede §117) ──
func get_profile_dto(character_id: String) -> Dictionary:
	var p := profiles.get_profile(character_id)
	if p.is_empty(): return {"ok": false, "reason": "NO_PROFILE"}
	var provisional := ArenaRating.is_provisional(int(p["placements_played"]))
	return {"ok": true, "profile": {
		"character_id": character_id, "rating": (int(p["current_rating"]) if not provisional else -1),
		"peak_rating": int(p["peak_rating"]), "provisional": provisional,
		"placements_played": int(p["placements_played"]), "placements_required": int(p["placements_required"]),
		"rank": (str(p["current_rank_id"]) if not provisional else "PROVISIONAL"),
		"division": (ArenaRank.division_for(int(p["current_rating"])) if not provisional else ""),
		"wins": int(p["wins"]), "losses": int(p["losses"]), "draws": int(p["draws"]),
		"current_streak": int(p["current_streak"]), "best_streak": int(p["best_streak"]),
		"badges": (p["badges"] as Array).duplicate(),
	}}

func season_info(season_id: String) -> Dictionary:
	var s := seasons.get_season(season_id)
	if s.is_empty(): return {"ok": false, "reason": "NO_SEASON"}
	s["current_leader"] = current_leader() if str(s["state"]) == ArenaSeasonManager.ACTIVE else ""
	s["champion"] = seasons.champion_of(season_id)   # só após finalize (§29)
	return {"ok": true, "season": s}

# ── restart recovery (§92) ──
## Matches RUNNING no restart viram SERVER_ABORT (0 rating) — nunca inventa vencedor (§92/ARST-T04).
func recover_after_restart() -> Dictionary:
	var aborted := 0
	for mid in matches.all_ids():
		var m := matches.get_match(mid)
		if not bool(m["settled"]) and str(m["state"]) == ArenaMatchRepository.RUNNING:
			matches.mark_settled(mid, "NO_CONTEST", "SERVER_ABORT", {}, {}, {}, ArenaMatchRepository.CANCELLED, _clock.now())
			aborted += 1
	return {"aborted": aborted}

func snapshot() -> Dictionary:
	return {"profiles": profiles.snapshot(), "seasons": seasons.snapshot(), "matches": matches.snapshot(), "power": power.snapshot(), "current_season": current_season_id}

func restore(snap: Dictionary) -> void:
	profiles.restore(snap.get("profiles", {}))
	seasons.restore(snap.get("seasons", {}))
	matches.restore(snap.get("matches", {}))
	power.restore(snap.get("power", {}))
	current_season_id = str(snap.get("current_season", ""))
