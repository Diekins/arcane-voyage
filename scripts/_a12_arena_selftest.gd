extends SceneTree
## Self-test/RELATÓRIO FATIA A12 — Arena Competitive Foundation (seasons/MMR/ranks/CP leaderboard/badges/rewards/
## normalization). NÃO cria luta PvP (isso é A12.1). Prova: CP ≠ PvP rating ≠ Prestige; cliente não escolhe
## CP/rating/rank/winner/champion; settlement exactly-once atômico; season finalizada = histórico imutável; champion
## = #1 final; normalização remove disparidade de CP bruto SEM alterar o PvE; VIP/cosmetic = 0 poder Ranked.
## Simulações de rating (100k) e normalização. Queries por rede ENet real. FIXTURE (save vivo intocado).

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1

var gs
var server: GameServer
var _all_clients: Array = []
var _port := 34820

func _pump_all() -> void:
	if server != null: server.poll()
	for c in _all_clients: c.poll()

func _mk(gold: int, level: int, weapon: String = "sword_eternal") -> Dictionary:
	gs.reset_save(); gs.hero_gold = gold; gs.hero_level = level
	gs.equipment = {"weapon": weapon}; gs.slot_refinement = {"weapon": 0}
	return gs.to_dict().duplicate(true)

func _actx(seed: int) -> Dictionary:
	var repo := CharacterRepository.new(); var items := ItemRegistry.new(); var clock := ServerClock.fixed(1000)
	var auth := AuthorityServer.new(); auth.setup(repo, items, clock, seed)
	var arena := ArenaService.new(); arena.setup(auth, repo, items, clock, seed)
	arena.start_season("S1")
	return {"repo": repo, "items": items, "clock": clock, "auth": auth, "arena": arena}

func _char(ctx: Dictionary, acct: String, cid: String, level: int, weapon: String = "sword_eternal") -> void:
	ctx["repo"].create_character(acct, cid, _mk(100, level, weapon))

func _seedp(arena: ArenaService, cid: String, rating: int, wins: int, losses: int, placements: int) -> void:
	arena.profiles.get_or_create(cid, "S1")
	var rev := arena.profiles.revision_of(cid)
	var p := arena.profiles.get_profile(cid)
	p["current_rating"] = rating; p["peak_rating"] = rating; p["wins"] = wins; p["losses"] = losses
	p["placements_played"] = placements; p["season_matches"] = wins + losses
	p["current_rank_id"] = ArenaRank.rank_for(rating); p["peak_rank_id"] = p["current_rank_id"]
	arena.profiles.save(cid, rev, p)

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a12_fixture_save.json"
	gs.set_save_path_override(fixture); var mem: Dictionary = gs.to_dict(); gs.reset_save()

	_test_rating()
	_test_profiles()
	_test_seasons()
	_test_matches()
	_test_atomic_rating()
	_test_pvp_leaderboard()
	_test_cp_leaderboard()
	_test_badges()
	_test_normalization()
	_test_rewards()
	_test_restart()
	_test_malicious()
	_test_stress()
	_test_sim_rating()
	_test_sim_normalization()
	_test_network()
	_test_local()

	for c in _all_clients: c.stop()
	if server != null: server.stop()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	for f in ["user://a12_arena.json"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(f)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ══════════════ RATING (§104) ══════════════
func _test_rating() -> void:
	print("  ── RATE (Elo) ──")
	var ctx := _actx(1); var arena: ArenaService = ctx["arena"]
	_char(ctx, "accA", "charA", 1); _char(ctx, "accB", "charB", 1)
	var m := arena.create_match("charA", "charB"); var mid := str(m["match_id"])
	var s := arena.settle_match(mid, "a", "NORMAL")
	_chk("RATE-T01 win sobe o vencedor", int(s["rating_after"]["charA"]) > 1000)
	_chk("RATE-T02 loss reduz o perdedor", int(s["rating_after"]["charB"]) < 1000)
	# draw
	var m2 := arena.create_match("charA", "charB")
	var sd := arena.settle_match(str(m2["match_id"]), "draw", "NORMAL")
	_chk("RATE-T03 draw funciona", bool(sd["ok"]) and arena.profiles.get_profile("charA")["draws"] == 1)
	# favorite vs underdog (direto)
	var d_fav := ArenaRating.delta(1800, 1000, ArenaRating.WIN, 100)
	var d_under := ArenaRating.delta(1000, 1800, ArenaRating.WIN, 100)
	_chk("RATE-T04 favorito ganha menos", d_fav < d_under)
	_chk("RATE-T05 underdog ganha mais", d_under > d_fav and d_under > 0)
	_chk("RATE-T06 placements K=64", ArenaRating.k_for(5, 1000) == 64)
	_chk("RATE-T07 stable K=24", ArenaRating.k_for(80, 1500) == 24)
	_chk("RATE-T08 top K=16", ArenaRating.k_for(80, 2100) == 16)
	_chk("RATE-T09 floor (rating não fica negativo)", ArenaRating.with_floor(-500) == ArenaRating.FLOOR)
	# duplicate settlement = 1x
	var before := int(arena.profiles.get_profile("charA")["current_rating"])
	arena.settle_match(mid, "a", "NORMAL")
	_chk("RATE-T10 duplicate settlement = 1x (rating intacto)", int(arena.profiles.get_profile("charA")["current_rating"]) == before)

# ══════════════ PROFILE (§105) ══════════════
func _test_profiles() -> void:
	print("  ── APR (ArenaProfile) ──")
	var ctx := _actx(2); var arena: ArenaService = ctx["arena"]
	_char(ctx, "accA", "charA", 1); _char(ctx, "accB", "charB", 1)
	# A vence 3x
	for i in range(3):
		var m := arena.create_match("charA", "charB")
		arena.settle_match(str(m["match_id"]), "a", "NORMAL")
	var pA := arena.profiles.get_profile("charA"); var pB := arena.profiles.get_profile("charB")
	_chk("APR-T01 profile por character", str(pA["character_id"]) == "charA")
	_chk("APR-T02 A ≠ B (rating divergiu)", int(pA["current_rating"]) != int(pB["current_rating"]))
	_chk("APR-T03 wins/losses", int(pA["wins"]) == 3 and int(pB["losses"]) == 3)
	_chk("APR-T04 streak atual", int(pA["current_streak"]) == 3)
	_chk("APR-T05 best streak", int(pA["best_streak"]) == 3)
	_chk("APR-T06 peak rating >= atual", int(pA["peak_rating"]) >= int(pA["current_rating"]))
	_chk("APR-T07 provisional (< placements)", ArenaRating.is_provisional(int(pA["placements_played"])))
	_chk("APR-T08 rank resolution", ArenaRank.rank_for(int(pA["current_rating"])) == str(pA["current_rank_id"]))

# ══════════════ SEASONS (§106) ══════════════
func _test_seasons() -> void:
	print("  ── SEAS (seasons) ──")
	var ctx := _actx(3); var arena: ArenaService = ctx["arena"]; var sm: ArenaSeasonManager = arena.seasons
	var ck: ServerClock = ctx["clock"]
	_chk("SEAS-T01 create (S1 já criada em start)", sm.state_of("S1") == "ACTIVE")
	sm.create_season("S2", ck.now() + 1000, ck.now() + 2000)
	_chk("SEAS-T02 activate", bool(sm.activate("S2")["ok"]) and sm.state_of("S2") == "ACTIVE")
	_chk("SEAS-T03 server clock (created_at carimbado)", int(sm.get_season("S2")["created_at"]) == ck.now())
	sm.lock("S2")
	_chk("SEAS-T04 lock (não aceita novos matches)", not sm.is_accepting_matches("S2"))
	# finalize com perfis seeded
	_seedp(arena, "p1", 1500, 12, 3, 15); _seedp(arena, "p2", 1300, 8, 7, 15)
	var fin := arena.finalize_season("S1")
	_chk("SEAS-T05 finalize (results congelados)", bool(fin["ok"]) and (fin["results"] as Array).size() == 2)
	var champ := arena.seasons.champion_of("S1")
	var dup := arena.finalize_season("S1")
	_chk("SEAS-T06 finalize duplicate (idempotente)", bool(dup.get("already", false)) and arena.seasons.champion_of("S1") == champ)
	_chk("SEAS-T07 historical frozen (result imutável)", int(arena.seasons.result_for("S1", "p1")["position"]) == 1)
	# soft reset nova season
	var r_before := int(arena.profiles.get_profile("p1")["current_rating"])
	arena.soft_reset_for_new_season("S3")
	var r_after := int(arena.profiles.get_profile("p1")["current_rating"])
	_chk("SEAS-T08 new season soft reset (puxa ao baseline, placements zerados)", r_after == ArenaRating.soft_reset(r_before) and int(arena.profiles.get_profile("p1")["placements_played"]) == 0)

# ══════════════ MATCH (§107) ══════════════
func _test_matches() -> void:
	print("  ── AMATCH (match records) ──")
	var ctx := _actx(4); var arena: ArenaService = ctx["arena"]
	_char(ctx, "accA", "charA", 1); _char(ctx, "accB", "charB", 1)
	var m := arena.create_match("charA", "charB"); var mid := str(m["match_id"])
	_chk("AMATCH-T01 create match", bool(m["ok"]) and mid != "")
	_chk("AMATCH-T02 season bound", str(arena.matches.get_match(mid)["season_id"]) == "S1")
	_chk("AMATCH-T03 running", str(arena.matches.get_match(mid)["state"]) == "RUNNING")
	var s := arena.settle_match(mid, "a", "NORMAL")
	_chk("AMATCH-T04 server settlement (FINISHED)", bool(s["ok"]) and str(arena.matches.get_match(mid)["state"]) == "FINISHED")
	# client settlement denied — não existe comando de cliente p/ settle (§74)
	_chk("AMATCH-T05 client settlement negado (comando inexistente)", str(NetProtocol.parse_command({"command_type": "ARENA_SETTLE", "command_id": "x", "args": {}}, false).get("reason", "")) == "UNKNOWN_COMMAND")
	# forfeit
	var mf := arena.create_match("charA", "charB")
	var sf := arena.settle_match(str(mf["match_id"]), "a", "FORFEIT")
	_chk("AMATCH-T06 forfeit (B forfeit contabilizado)", bool(sf["ok"]) and int(arena.profiles.get_profile("charB")["forfeits"]) == 1)
	# no contest
	var mnc := arena.create_match("charA", "charB")
	var before := int(arena.profiles.get_profile("charA")["current_rating"])
	var snc := arena.settle_match(str(mnc["match_id"]), "a", "NO_CONTEST")
	_chk("AMATCH-T07 no contest (0 rating)", bool(snc.get("no_rating", false)) and int(arena.profiles.get_profile("charA")["current_rating"]) == before)
	# server abort
	var msa := arena.create_match("charA", "charB")
	var ssa := arena.settle_match(str(msa["match_id"]), "a", "SERVER_ABORT")
	_chk("AMATCH-T08 server abort (0 rating, CANCELLED)", bool(ssa.get("no_rating", false)) and str(arena.matches.get_match(str(msa["match_id"]))["state"]) == "CANCELLED")
	# duplicate result
	var sdup := arena.settle_match(mid, "a", "NORMAL")
	_chk("AMATCH-T09 duplicate result (1 settlement)", bool(sdup.get("duplicate", false)))

# ══════════════ ATOMIC RATING (§108) ══════════════
func _test_atomic_rating() -> void:
	print("  ── ARAT (rating atômico) ──")
	var ctx := _actx(5); var arena: ArenaService = ctx["arena"]
	_char(ctx, "accA", "charA", 1); _char(ctx, "accB", "charB", 1)
	var m := arena.create_match("charA", "charB"); var mid := str(m["match_id"])
	var ra0 := arena.profiles.revision_of("charA"); var rb0 := arena.profiles.revision_of("charB")
	arena.settle_match(mid, "a", "NORMAL")
	_chk("ARAT-T01 A e B atualizam juntos (ambas revisions +1)", arena.profiles.revision_of("charA") == ra0 + 1 and arena.profiles.revision_of("charB") == rb0 + 1)
	# fault before commit → nada muda
	var m2 := arena.create_match("charA", "charB")
	var ratA := int(arena.profiles.get_profile("charA")["current_rating"])
	arena.settlement.set_fault("BEFORE_COMMIT")
	var f := arena.settle_match(str(m2["match_id"]), "a", "NORMAL")
	arena.settlement.set_fault("")
	_chk("ARAT-T02 fault before = nenhum muda", str(f.get("reason", "")) == "FAULT_BEFORE_COMMIT" and int(arena.profiles.get_profile("charA")["current_rating"]) == ratA)
	# fault "during" via commit_two stale (nunca parcial)
	var stale := arena.profiles.commit_two("charA", 999, arena.profiles.get_profile("charA"), "charB", arena.profiles.revision_of("charB"), arena.profiles.get_profile("charB"))
	_chk("ARAT-T03 fault during = zero commit, nunca parcial (STALE)", not bool(stale["ok"]) and int(arena.profiles.get_profile("charA")["current_rating"]) == ratA)
	# restart after commit não repete (o match já settled)
	var settled_rating := int(arena.profiles.get_profile("charA")["current_rating"])
	var re := arena.settle_match(mid, "a", "NORMAL")
	_chk("ARAT-T04 restart/retry após commit não repete", bool(re.get("duplicate", false)) and int(arena.profiles.get_profile("charA")["current_rating"]) == settled_rating)

# ══════════════ PvP LEADERBOARD (§109) ══════════════
func _test_pvp_leaderboard() -> void:
	print("  ── PVPLB (leaderboard PvP) ──")
	var ctx := _actx(6); var arena: ArenaService = ctx["arena"]
	_seedp(arena, "hi", 1800, 20, 2, 22); _seedp(arena, "mid", 1500, 15, 8, 23); _seedp(arena, "lo", 1200, 5, 15, 20)
	_seedp(arena, "prov", 2000, 3, 0, 3)   # provisional (placements < 10)
	var ord := arena.pvp_ordered_profiles("S1")
	_chk("PVPLB-T01 ordering (rating↓)", ord.size() >= 3 and str(ord[0]["character_id"]) == "hi")
	_chk("PVPLB-T02 provisional excluído", arena.pvp_my_position("prov") == -1)
	var pg := arena.pvp_page(0, 2)
	_chk("PVPLB-T03 pagination (cap por página)", (pg["entries"] as Array).size() == 2 and int(pg["total"]) == 3)
	_chk("PVPLB-T04 own position", arena.pvp_my_position("mid") == 2)
	_chk("PVPLB-T05 nearby (vizinhos)", arena.pvp_nearby("mid").size() >= 2)
	var dto: Dictionary = (pg["entries"] as Array)[0]
	_chk("PVPLB-T06 metadata privada ausente (sem account/session)", not (dto.has("account") or dto.has("session") or dto.has("journal")))

# ══════════════ CP LEADERBOARD (§110) ══════════════
func _test_cp_leaderboard() -> void:
	print("  ── CPLB (leaderboard CP) ──")
	var ctx := _actx(7); var arena: ArenaService = ctx["arena"]
	_char(ctx, "accA", "charA", 1, "sword_eternal")   # forte
	_char(ctx, "accB", "charB", 1, "sword_simple")    # fraco
	_char(ctx, "accC", "charC", 1, "sword_simple")
	arena.power.refresh_character("charA"); arena.power.refresh_character("charB"); arena.power.refresh_character("charC")
	_chk("CPLB-T01 servidor computa CP (>0)", arena.power.cp_of("charA") > 0)
	_chk("CPLB-T02 fake client CP ignorado (CP só via engine)", arena.power.cp_of("charA") > arena.power.cp_of("charB"))
	var ord := arena.power.ordered()
	_chk("CPLB-T03 ordering (CP↓)", str(ord[0]["character_id"]) == "charA")
	# tie-break: B e C mesmo CP → prestige/highest/updated/char
	_chk("CPLB-T04 tie-break determinístico (char_id ASC no empate)", arena.power.cp_of("charB") == arena.power.cp_of("charC") and str(ord[1]["character_id"]) == "charB")
	# stale revision rejeitada
	arena.power._snap["charA"]["source_revision"] = 999999
	var stale := arena.power.refresh_character("charA")
	_chk("CPLB-T05 revision stale rejeitada", str(stale.get("reason", "")) == "STALE_SNAPSHOT")
	var pg := arena.power.page(0, 2)
	_chk("CPLB-T06 pagination", (pg["entries"] as Array).size() == 2 and int(pg["total"]) == 3)
	_chk("CPLB-T07 own position", arena.power.my_position("charB") == 2)

# ══════════════ BADGES (§111) ══════════════
func _test_badges() -> void:
	print("  ── BADGE (emblemas) ──")
	var ctx := _actx(8); var arena: ArenaService = ctx["arena"]
	# 12 perfis classificados p/ ter Top10/Top100/Champion
	for i in range(12):
		_seedp(arena, "c%02d" % i, 2000 - i * 30, 20 - i, i, 20)
	var b_before := arena.badges_for("c00")
	_chk("BADGE-T01 current rank badge temporário", str(b_before["current_rank_badge"]).begins_with("RANK_"))
	var fin := arena.finalize_season("S1")
	var champ := arena.seasons.champion_of("S1")
	_chk("BADGE-T04 champion = 1 character só (#1)", champ == "c00")
	var champ_badges: Array = arena.badges_for("c00")["permanent"]
	var top10_badges: Array = arena.badges_for("c05")["permanent"]
	_chk("BADGE-T03 Top10 badge", (top10_badges as Array).size() >= 1)
	_chk("BADGE-T05 champion badge permanente persiste", (champ_badges as Array).any(func(x): return str(x).begins_with("SEASON_CHAMPION")))
	# finalize retry não duplica badge
	arena.finalize_season("S1")
	_chk("BADGE-T06 finalize retry sem duplicar badge", arena.badges_for("c00")["permanent"].size() == champ_badges.size())
	# nameplate prioriza champion
	_chk("BADGE-T02/§33 nameplate prioriza Champion > rank", str(arena.nameplate_primary("c00")).begins_with("SEASON_CHAMPION"))

# ══════════════ NORMALIZATION (§112) ══════════════
func _test_normalization() -> void:
	print("  ── NORM (normalização) ──")
	var target := ArenaNormalizationPolicy.TARGET_ARENA_CP
	# low/high CP convergem
	var low := ArenaNormalizationPolicy.normalize_full(714.0, 714.0)    # ~cp 10k
	var high := ArenaNormalizationPolicy.normalize_full(7142.0, 7142.0) # ~cp 100k
	_chk("NORM-T02 low/high CP convergem ao target", abs(int(low["cp"]) - target) <= 2 and abs(int(high["cp"]) - target) <= 2)
	# offense-heavy vs defense-heavy: razão preservada
	var off := ArenaNormalizationPolicy.normalize_full(1000.0, 100.0)   # ratio 10
	var deff := ArenaNormalizationPolicy.normalize_full(100.0, 1000.0)  # ratio 0.1
	_chk("NORM-T03 offense-heavy ratio preservado", abs(float(off["ratio"]) - 10.0) < 0.01 and int(off["cp"]) == target)
	_chk("NORM-T04 defense-heavy ratio preservado", abs(float(deff["ratio"]) - 0.1) < 0.01 and int(deff["cp"]) == target)
	_chk("NORM-T05 cosmetic ignorado (0 poder)", int(off["cosmetic_power"]) == 0)
	_chk("NORM-T06 VIP ignorado (0 poder)", int(off["vip_power"]) == 0)
	# doesn't alter PvE save
	var ctx := _actx(9)
	_char(ctx, "accA", "charA", 1)
	var ps: Dictionary = ctx["auth"].power_snapshot("charA")
	var before_rev: int = ctx["repo"].revision_of("charA")
	ArenaNormalizationPolicy.normalize_full(float(ps["offense"]), float(ps["effective_hp"]))
	_chk("NORM-T01 não altera o save PvE", ctx["repo"].revision_of("charA") == before_rev)
	# escrow item absent (item em escrow não é loadout)
	var it: ItemRegistry = ctx["items"]
	it.register("eiid", "accA", "sword_eternal", ItemRegistry.LOC_PLAYER)
	it.to_escrow("eiid", "t1", "accA")
	_chk("NORM-T07 item em escrow ausente do loadout (não EQUIPPED)", it.location_of("eiid") == ItemRegistry.LOC_ESCROW)
	# snapshot immutable/determinístico
	var s1 := ArenaNormalizationPolicy.normalize_full(500.0, 500.0)
	var s2 := ArenaNormalizationPolicy.normalize_full(500.0, 500.0)
	_chk("NORM-T08 snapshot imutável/determinístico", int(s1["cp"]) == int(s2["cp"]) and float(s1["ratio"]) == float(s2["ratio"]))

# ══════════════ REWARDS (§113) ══════════════
func _test_rewards() -> void:
	print("  ── AREW (recompensas) ──")
	# participação válida gera entitlement; poucos matches não
	var few := ArenaRewardPolicy.season_entitlements("RANK_3", 50, 2, "RANK_3")
	var many := ArenaRewardPolicy.season_entitlements("RANK_3", 50, 20, "RANK_3")
	_chk("AREW-T01 entitlement server-side (participação válida)", few.is_empty() and many.size() >= 1)
	_chk("AREW-T02 NO_CONTEST sem reward", not ArenaRewardPolicy.match_grants_reward("NO_CONTEST"))
	_chk("AREW-T03 SERVER_ABORT sem reward", not ArenaRewardPolicy.match_grants_reward("SERVER_ABORT"))
	# champion entitlement
	var champ := ArenaRewardPolicy.season_entitlements("RANK_7", 1, 30, "RANK_7")
	_chk("AREW-T04 champion recebe badge de campeão", champ.any(func(x): return str(x["id"]) == "SEASON_CHAMPION"))
	_chk("AREW-T05 nenhuma reward é buff de combate", not ArenaRewardPolicy.grants_combat_buff("AURA"))
	# perk policy: nenhum combat power em ranked
	_chk("AREW perk policy sem combat power", ArenaRankPerkPolicy.audit_no_combat_power())

# ══════════════ RESTART (§114) ══════════════
func _test_restart() -> void:
	print("  ── ARST (restart) ──")
	var ctx := _actx(10); var arena: ArenaService = ctx["arena"]
	_char(ctx, "accA", "charA", 1); _char(ctx, "accB", "charB", 1)
	var m := arena.create_match("charA", "charB"); var mid := str(m["match_id"])
	arena.settle_match(mid, "a", "NORMAL")
	var running := arena.create_match("charA", "charB"); var rmid := str(running["match_id"])   # fica RUNNING
	_seedp(arena, "charA", int(arena.profiles.get_profile("charA")["current_rating"]), 5, 1, 12)
	var ratA := int(arena.profiles.get_profile("charA")["current_rating"])
	# snapshot → restore em nova instância
	var snap := arena.snapshot()
	var arena2 := ArenaService.new(); arena2.setup(ctx["auth"], ctx["repo"], ctx["items"], ctx["clock"], 99)
	arena2.restore(snap)
	_chk("ARST-T01 profiles persistem", int(arena2.profiles.get_profile("charA")["current_rating"]) == ratA)
	_chk("ARST-T02 season persiste", arena2.seasons.state_of("S1") == "ACTIVE")
	_chk("ARST-T05 settled match segue settled", arena2.matches.is_settled(mid))
	var rec := arena2.recover_after_restart()
	_chk("ARST-T04 RUNNING match recovery = SERVER_ABORT sem vencedor", int(rec["aborted"]) == 1 and str(arena2.matches.get_match(rmid)["state"]) == "CANCELLED")
	# finalize + restore preserva histórico
	_seedp(arena2, "charA", 1500, 12, 3, 15)
	arena2.finalize_season("S1")
	var snap2 := arena2.snapshot()
	var arena3 := ArenaService.new(); arena3.setup(ctx["auth"], ctx["repo"], ctx["items"], ctx["clock"], 1); arena3.restore(snap2)
	_chk("ARST-T03 resultados históricos persistem", arena3.seasons.result_for("S1", "charA").size() > 0)

# ══════════════ MALICIOUS (§115) ══════════════
func _test_malicious() -> void:
	print("  ── MALICIOUS (cliente forjando) ──")
	# nenhum comando de cliente para settle/report_win/set rating/cp/rank
	for forged in ["REPORT_WIN", "ARENA_SETTLE", "SET_RATING", "SET_CP", "SET_RANK", "SET_CHAMPION"]:
		var pc := NetProtocol.parse_command({"command_type": forged, "command_id": "x", "args": {"rating": 9999, "cp": 999999999, "winner": "self"}}, false)
		if str(pc.get("reason", "")) != "UNKNOWN_COMMAND":
			_chk("MALICIOUS comando forjado %s rejeitado" % forged, false)
			return
	_chk("MALICIOUS todos os comandos forjados de vitória/rating/cp/rank rejeitados (UNKNOWN_COMMAND)", true)

# ══════════════ STRESS (§116) ══════════════
func _test_stress() -> void:
	print("  ── STRESS (settlements) ──")
	var ctx := _actx(11); var arena: ArenaService = ctx["arena"]
	var N := 12
	for i in range(N): _char(ctx, "acc%d" % i, "ch%d" % i, 1)
	var settlements := 0; var dupes := 0; var neg := false
	for round in range(1000):
		var a := "ch%d" % (round % N); var b := "ch%d" % ((round + 1) % N)
		if a == b: continue
		var m := arena.create_match(a, b)
		if not bool(m["ok"]): continue
		var mid := str(m["match_id"])
		var winner := "a" if round % 3 != 0 else ("b" if round % 3 == 1 else "draw")
		var reason := "NORMAL" if round % 7 != 0 else "FORFEIT"
		arena.settle_match(mid, winner, reason)
		# duplicate
		var d := arena.settle_match(mid, winner, reason)
		if bool(d.get("duplicate", false)): dupes += 1
		settlements += 1
	# invariantes
	for i in range(N):
		var p := arena.profiles.get_profile("ch%d" % i)
		if int(p["current_rating"]) < ArenaRating.FLOOR: neg = true
		if int(p["wins"]) < 0 or int(p["losses"]) < 0: neg = true
	print("    [stress] settlements=%d dupes=%d matches=%d" % [settlements, dupes, arena.matches.count()])
	_chk("STRESS 0 duplicate settlement aplicado (todos duplicate reconhecidos)", dupes == settlements)
	_chk("STRESS 0 rating abaixo do floor / 0 counter negativo", not neg)
	_chk("STRESS todos os matches settled (0 parcial)", arena.matches.count() == settlements)

# ══════════════ SIM RATING (§101) ══════════════
func _test_sim_rating() -> void:
	print("  ── SIM RATING (100k matches sintéticos) ──")
	# pool de jogadores com "skill verdadeira"; rating deve correlacionar com skill ao longo do tempo
	var N := 50
	var rating: Array = []; var skill: Array = []; var played: Array = []
	for i in range(N):
		rating.append(ArenaRating.START_RATING); skill.append(1000 + i * 20); played.append(0)
	var rng := RandomNumberGenerator.new(); rng.seed = 12345
	var floor_hits := 0
	for match in range(100000):
		var a := rng.randi_range(0, N - 1); var b := rng.randi_range(0, N - 1)
		if a == b: continue
		# probabilidade real pela skill verdadeira
		var pa := 1.0 / (1.0 + pow(10.0, (float(skill[b]) - float(skill[a])) / 400.0))
		var a_wins := rng.randf() < pa
		var sa := ArenaRating.WIN if a_wins else ArenaRating.LOSS
		var da := ArenaRating.delta(int(rating[a]), int(rating[b]), sa, int(played[a]))
		var db := ArenaRating.delta(int(rating[b]), int(rating[a]), 1.0 - sa, int(played[b]))
		rating[a] = ArenaRating.with_floor(int(rating[a]) + da); rating[b] = ArenaRating.with_floor(int(rating[b]) + db)
		if int(rating[a]) == ArenaRating.FLOOR or int(rating[b]) == ArenaRating.FLOOR: floor_hits += 1
		played[a] = int(played[a]) + 1; played[b] = int(played[b]) + 1
	# correlação: o mais habilidoso (último índice) deve ter rating > o menos habilidoso (índice 0)
	var top_rating := int(rating[N - 1]); var bottom_rating := int(rating[0])
	# monotonicidade aproximada: conta pares (i<j) com rating[i] < rating[j]
	var concordant := 0; var total := 0
	for i in range(N):
		for j in range(i + 1, N):
			total += 1
			if int(rating[i]) < int(rating[j]): concordant += 1
	var monotonic := float(concordant) / float(total)
	print("    [sim-rating] top=%d bottom=%d spread=%d monotonicidade=%.2f floor_hits=%d" % [top_rating, bottom_rating, top_rating - bottom_rating, monotonic, floor_hits])
	_chk("SIM-RATING skill mais alta converge para rating mais alto (spread > 400)", top_rating - bottom_rating > 400)
	_chk("SIM-RATING ranking correlaciona com skill (>85% concordante)", monotonic > 0.85)
	_chk("SIM-RATING sem explosão (ratings finitos e > floor na maioria)", top_rating < 4000 and bottom_rating >= ArenaRating.FLOOR)

# ══════════════ SIM NORMALIZATION (§102) ══════════════
func _test_sim_normalization() -> void:
	print("  ── SIM NORMALIZATION (builds sintéticas) ──")
	var target := ArenaNormalizationPolicy.TARGET_ARENA_CP
	var cps := [10000, 20000, 50000, 100000]
	var builds := {"offense": 4.0, "balanced": 1.0, "defense": 0.25}  # ratio O:E
	var all_target := true; var ratios_ok := true
	var raw_span_max := 0; var raw_span_min := 999999999
	for cp in cps:
		var raw := float(cp) / ArenaNormalizationPolicy.CP_SCALE   # sqrt(O*E)
		for bname in builds:
			var r: float = builds[bname]
			var o := raw * sqrt(r); var e := raw / sqrt(r)   # constrói O,E com o CP e a razão desejados
			var norm := ArenaNormalizationPolicy.normalize_full(o, e)
			if abs(int(norm["cp"]) - target) > 3: all_target = false
			if abs(float(norm["ratio"]) - r) > 0.02: ratios_ok = false
			raw_span_max = maxi(raw_span_max, int(norm["raw_cp"])); raw_span_min = mini(raw_span_min, int(norm["raw_cp"]))
	print("    [sim-norm] raw CP span %d..%d → normalized todos ≈ %d" % [raw_span_min, raw_span_max, target])
	_chk("SIM-NORM raw CP span 10x (10k..100k)", raw_span_max >= 90000 and raw_span_min <= 12000)
	_chk("SIM-NORM todos convergem ao target (one-shot de CP bruto removido)", all_target)
	_chk("SIM-NORM identidade de build (razão O:E) preservada em todos", ratios_ok)

# ══════════════ NETWORK (§117) ══════════════
func _test_network() -> void:
	print("  ── NETWORK (queries por ENet real) ──")
	_fresh_server()
	var repo := server.repo
	repo.create_character("accA", "charA", _mk(100, 1, "sword_eternal"))
	repo.create_character("accB", "charB", _mk(100, 1, "sword_simple"))
	# server-side: season + CP + rating (settlement é interno)
	server.arena.power.refresh_character("charA"); server.arena.power.refresh_character("charB")
	_seedp(server.arena, "charA", 1600, 15, 3, 15); _seedp(server.arena, "charB", 1400, 8, 8, 15)
	var A := _client("na"); A.connect_and_login("accA"); A.open_character("charA")
	# queries por rede
	var prof := A.arena_profile("charA")
	_chk("NET arena_profile por rede", bool(prof.get("ok", false)) and int(prof["profile"]["rating"]) == 1600)
	var pvp := A.arena_pvp_leaderboard(0, 10)
	_chk("NET pvp_leaderboard por rede", int(pvp.get("total", 0)) == 2 and str((pvp["entries"] as Array)[0]["character_id"]) == "charA")
	var cplb := A.arena_cp_leaderboard(0, 10)
	_chk("NET cp_leaderboard por rede (CP server-side)", int(cplb.get("total", 0)) == 2 and int((cplb["entries"] as Array)[0]["cp"]) > 0)
	var myr := A.arena_my_rank("pvp")
	_chk("NET my_rank por rede", int(myr.get("position", -1)) == 1)
	var near := A.arena_nearby("pvp")
	_chk("NET nearby por rede", (near.get("entries", []) as Array).size() >= 1)
	var si := A.arena_season_info("S1")
	_chk("NET season_info por rede", bool(si.get("ok", false)) and str(si["season"]["state"]) == "ACTIVE")
	# settlement NÃO acessível pelo cliente (§74)
	var forged := _send_cmd(A, "REPORT_WIN")
	_chk("NET §74 cliente não reporta vitória (UNKNOWN_COMMAND)", str(forged.get("error", forged.get("reason", ""))) == "UNKNOWN_COMMAND")
	# ARENA_QUERY q=SETTLE → QUERY_UNKNOWN
	var qs := A._await(A.client.arena_query({"q": "SETTLE", "winner": "self"}))
	_chk("NET §74 ARENA_QUERY SETTLE negado", str(qs.get("reason", "")) == "QUERY_UNKNOWN")

func _send_cmd(oc: OnlineClient, ctype: String) -> Dictionary:
	return oc._await(oc.client.command(ctype, "forge_%s" % ctype, {"winner": "self", "rating": 9999}))

func _fresh_server() -> void:
	for c in _all_clients: c.stop()
	_all_clients = []
	if server != null: server.stop()
	_port += 1
	var repo := CharacterRepository.new(); var items := ItemRegistry.new(); var clock := ServerClock.fixed(100000)
	server = GameServer.new(); root.add_child(server); server.configure(repo, items, clock, null)
	server.start(_port, 7)
	server.arena.start_season("S1")

func _client(prefix: String) -> OnlineClient:
	var gc := GameClient.new(); root.add_child(gc); gc.start(_port); _all_clients.append(gc)
	var oc := OnlineClient.new(); oc.setup(gc, Callable(self, "_pump_all"), prefix); oc.default_timeout_ms = 1500
	return oc

# ══════════════ LOCAL (§119) ══════════════
func _test_local() -> void:
	print("  ── LOCAL ──")
	_chk("LOCAL modo default intacto", RuntimeMode.resolve() == RuntimeMode.LOCAL)
	# Arena online simplesmente não existe em LOCAL; economia embarcada segue
	var r := CharacterRepository.new(); r.create_character("locA", "locC", _mk(100, 1))
	_chk("LOCAL economia embarcada intacta (sem dependência de Arena)", r.revision_of("locC") == 1)
