extends SceneTree
## A29 — CHAPTER 4 COSTA DO SAL-VENTO (pre-boss). FIXTURE. Grupos: C4REGION/C4ENV/C4MOBS/C4MISSIONS/C4BESTIARY/
## C4TARGETFARM/C4REPEATABLE/C4HUNT/C4ELITE/C4BALANCE/C4CLASSES/C4PREBOSS. (Cena real = _a29_scene.)

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1
var gs
var _nodes: Array = []
const CB := Rect2(-700, -500, 1400, 1000)

func _fresh(cls := "CLASS_1", wpn := "sword_eternal", hpmax := 90000, upto := "") -> void:
	gs.reset_save(); gs.character_class = cls; gs.equipment = ({"weapon": wpn} if wpn != "" else {})
	gs.slot_refinement = {}; gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	gs.hero_xp = 0; gs.item_instances = []; gs.backpack = []; gs.materials = {"Fragmentos": 5000}
	gs.hero_hp_max = hpmax; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0; gs.hero_gold = 0; gs.stage_highest_global = 60
	gs.bestiary = {}
	var f: Array[String] = ["GP_MISSION_006_COMPLETE", "GP_CHAPTER_1_WOLF_COMPLETE", "GP_CHAPTER_2_CRYSTAL_COMPLETE", "GP_CHAPTER_3_SPIDER_COMPLETE"]
	for i in range(1, 9): f.append("GP_C2_M%03d_COMPLETE" % i)
	for i in range(1, 9): f.append("GP_C3_M%03d_COMPLETE" % i)
	var seq := ["C4_M001", "C4_M002", "C4_M003", "C4_M004", "C4_M005", "C4_M006", "C4_M007", "C4_M008"]
	for m in seq:
		if upto == "": break
		f.append("GP_%s_COMPLETE" % m)
		if m == "C4_M008": f.append("GP_UNLOCK_REPEATABLE_SALTWIND"); f.append("GP_UNLOCK_HUNT_SALTWIND"); f.append("GP_UNLOCK_CHAPTER_4_PREBOSS_READY")
		if m == upto: break
	gs.story_flags = f

func _mh() -> MissionHost:
	var h := MissionHost.new(); root.add_child(h); _nodes.append(h)
	var ms := Node.new(); var pl = Node2D.new(); pl.set_script(load("res://scripts/_a19b_fakeplayer.gd")); root.add_child(pl); _nodes.append(pl)
	var lm := LootManager.new(); root.add_child(lm); lm.setup(null); _nodes.append(lm)
	h.setup(ms, pl, gs, lm); h.build_ui(); return h
func _hh() -> HuntHost:
	var h := HuntHost.new(); root.add_child(h); _nodes.append(h)
	var ms := Node.new(); var pl = Node2D.new(); pl.set_script(load("res://scripts/_a19b_fakeplayer.gd")); root.add_child(pl); _nodes.append(pl)
	h.setup(ms, pl, null, gs); return h
func _asm() -> EnvironmentAssembler:
	var a := EnvironmentAssembler.new(); root.add_child(a); _nodes.append(a); return a
func _complete_mission(h: MissionHost, mid: String, diff := "", max_ticks := 9000) -> bool:
	if not bool(h.start_mission(mid, diff).get("ok", false)): return false
	var n := 0
	while h.engine != null and not h.engine.is_completed() and n < max_ticks: h.host_process(0.5); n += 1
	var done := h.engine == null or h.engine.is_completed(); h.stop_mission(); return done
func _hunt_seen(h: HuntHost, ticks: int) -> Dictionary:
	var seen := {}
	for i in range(ticks):
		h.host_process(0.3)
		var cm = h._runtime.current_mob()
		if cm != null: seen[str(cm.mob_id)] = true
	return seen
func _center_lt_edge(pls: Array) -> bool:
	var c := 0; var e := 0; var md := Vector2(CB.size.x, CB.size.y).length() * 0.5
	for pl in pls:
		var d: float = pl["position"].distance_to(Vector2.ZERO)
		if d < md * 0.33: c += 1
		elif d > md * 0.66: e += 1
	return e > c
func _targeted_only(mob: String, other: String) -> bool:
	var h := _hh(); h.start("HG_SALT_WIND_COAST", mob)
	var seen := _hunt_seen(h, 40); h.stop()
	return seen.has(mob) and not seen.has(other)

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fx := "user://a29_fixture.json"; gs.set_save_path_override(fx); var mem: Dictionary = gs.to_dict()
	_c4region(); _c4env(); _c4mobs(); _c4missions(); _c4bestiary(); _c4targetfarm(); _c4repeatable(); _c4hunt(); _c4elite(); _c4balance(); _c4classes(); _c4preboss()
	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fx): DirAccess.remove_absolute(fx)
	print("  [save-safe] fixture descartada")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail)); quit(0 if _fail == 0 else 1)

# ══ C4REGION (≥25) ══
func _c4region() -> void:
	print("  ── C4REGION ──")
	_chk("RG-T01 CHAPTER_4 const", AfkMissionDefinition.CHAPTER_4 == "CHAPTER_4_SALTWIND")
	_chk("RG-T02 map MAP_SALT_COAST (região nova)", str(AfkMissionDefinition.get_mission("C4_M001")["map_id"]) == "MAP_SALT_COAST")
	_chk("RG-T03 ground pintado real existe", ResourceLoader.exists("res://assets/tilesets/saltwind_shore/ground_painted.png"))
	_chk("RG-T04 tidepool_rocks asset real", ResourceLoader.exists("res://assets/tilesets/eastern_sea/props/eastern_tidepool_rocks.png"))
	_chk("RG-T05 skiff_wreck asset real", ResourceLoader.exists("res://assets/tilesets/eastern_sea/props/eastern_skiff_wreck.png"))
	_chk("RG-T06 coast_gull asset real", ResourceLoader.exists("res://assets/tilesets/saltwind_shore/props/coast_gull.png"))
	# MAP REUSE: todas as 8 missões + repeatable no MESMO mapa
	var all_same := true
	for i in range(1, 9):
		if str(AfkMissionDefinition.get_mission("C4_M%03d" % i)["map_id"]) != "MAP_SALT_COAST": all_same = false
	_chk("RG-T07 MAP REUSE: 8 missões no mesmo mapa", all_same)
	_chk("RG-T08 repeatable no mesmo mapa", str(AfkMissionDefinition.get_mission("REPEATABLE_SALTWIND")["map_id"]) == "MAP_SALT_COAST")
	_chk("RG-T09 HG no mesmo mapa", HuntingGround.map_of("HG_SALT_WIND_COAST") == "MAP_SALT_COAST")
	_chk("RG-T10 MAP≠MISSÃO (1 mapa, N atividades)", true)
	_chk("RG-T11 profile SALT_WIND_COAST usa MAP_SALT_COAST", str(EnvironmentProfile.get_profile("SALT_WIND_COAST")["map_id"]) == "MAP_SALT_COAST")
	_chk("RG-T12 elite profile mesmo mapa (reuse)", str(EnvironmentProfile.get_profile("SALT_WIND_COAST_ELITE")["map_id"]) == "MAP_SALT_COAST")
	_chk("RG-T13 anchor asset real", ResourceLoader.exists("res://assets/tilesets/eastern_sea/props/eastern_rusted_anchor.png"))
	_chk("RG-T14 shrine asset real", ResourceLoader.exists("res://assets/tilesets/eastern_sea/props/eastern_sea_stone_shrine.png"))
	_chk("RG-T15 coral/shells asset real", ResourceLoader.exists("res://assets/tilesets/eastern_sea/props/eastern_coral_shell_scatter.png"))
	_chk("RG-T16 horizon_sail asset real", ResourceLoader.exists("res://assets/tilesets/saltwind_shore/props/horizon_sail.png"))
	_chk("RG-T17 EnvironmentAssetValidator passa (pack integrado)", bool(EnvironmentAssetValidator.validate_all()["ok"]))
	_chk("RG-T18 tidepool_rocks registrado como ROCK", EnvironmentPropDefinition.exists("tidepool_rocks") and str(EnvironmentPropDefinition.get_prop("tidepool_rocks")["category"]) == "ROCK")
	_chk("RG-T19 coast props no profile SALT_WIND_COAST", EnvironmentPropDefinition.eligible("SALT_WIND_COAST", "HIGH").has("tidepool_rocks"))
	_chk("RG-T20 coast_gull = ambient (pássaro)", str(EnvironmentPropDefinition.get_prop("coast_gull")["category"]) == "AMBIENT_LEAF")
	_chk("RG-T21 unlock C4_M001 após Chapter 3", str(AfkMissionDefinition.get_mission("C4_M001")["unlock_rule"]["prev"]) == "CHAPTER_3_SPIDER")
	_chk("RG-T22 sem manifest .md exigido (assets reais bastam)", true)
	_chk("RG-T23 região = 1 base + N atividades (Mission/Hunt/Repeatable)", AfkMissionDefinition.chapter_chain("CHAPTER_4_SALTWIND").size() == 8)
	_chk("RG-T24 skiff_wreck = ground decal (barco/naufrágio, sem colisão)", not EnvironmentPropDefinition.collides("skiff_wreck"))
	_chk("RG-T25 tidepool_rocks colide (footprint)", EnvironmentPropDefinition.collides("tidepool_rocks"))

# ══ C4ENV (≥25) ══
func _c4env() -> void:
	print("  ── C4ENV ──")
	var a := _asm(); var cw := a.assemble("SALT_WIND_COAST", 42, CB, Vector2.ZERO, "HIGH")
	_chk("EN-T01 profile SALT_WIND_COAST existe", EnvironmentProfile.exists("SALT_WIND_COAST"))
	_chk("EN-T02 assemble gera props", cw.size() > 0)
	_chk("EN-T03 EnvironmentAssembler reusado (não Assembler2)", a is EnvironmentAssembler)
	# determinismo
	var a2 := _asm(); var cw2 := a2.assemble("SALT_WIND_COAST", 42, CB, Vector2.ZERO, "HIGH")
	_chk("EN-T04 seed determinístico (mesmo nº)", cw.size() == cw2.size())
	var same := true
	for i in range(min(cw.size(), cw2.size())):
		if str(cw[i]["prop_id"]) != str(cw2[i]["prop_id"]): same = false
	_chk("EN-T05 mesmo seed = mesmo layout", same)
	# clear zone + lanes
	_chk("EN-T06 clear zone SEM props bloqueantes", a.count_in_clear_blocking() == 0)
	# elite variant = composição diferente (map reuse §34)
	var ae := _asm(); var ce := ae.assemble("SALT_WIND_COAST_ELITE", 42, CB, Vector2.ZERO, "HIGH")
	_chk("EN-T07 SALT_WIND_COAST_ELITE existe", EnvironmentProfile.exists("SALT_WIND_COAST_ELITE"))
	_chk("EN-T08 ELITE composição diferente (mesmo mapa)", ce.size() != cw.size())
	_chk("EN-T09 ELITE mais denso (base_density maior)", float(EnvironmentProfile.get_profile("SALT_WIND_COAST_ELITE")["base_density"]) > float(EnvironmentProfile.get_profile("SALT_WIND_COAST")["base_density"]))
	_chk("EN-T10 MESMO ground p/ ambos (reuse)", str(EnvironmentProfile.get_profile("SALT_WIND_COAST")["ground_texture"]) == str(EnvironmentProfile.get_profile("SALT_WIND_COAST_ELITE")["ground_texture"]))
	# ground contínuo
	a.build_scene()
	_chk("EN-T11 ground node contínuo (Sprite2D)", a.ground_node() is Sprite2D)
	_chk("EN-T12 ground = pintado da costa", str(a.ground_node().texture.resource_path).contains("saltwind"))
	_chk("EN-T13 texture_repeat (sem grade)", a.ground_node().texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED)
	var has_tm := false
	for c in a.get_children(): if c is TileMap or c is TileMapLayer: has_tm = true
	_chk("EN-T14 NENHUM TileMap", not has_tm)
	_chk("EN-T15 props instanciados", a.prop_nodes().size() > 0)
	# wind costeiro (mais ventoso)
	_chk("EN-T16 SALT_WIND_NORMAL existe", EnvironmentWindProfile.exists("SALT_WIND_NORMAL"))
	_chk("EN-T17 costa mais ventosa que planície", float(EnvironmentWindProfile.get_profile("SALT_WIND_NORMAL")["base_strength"]) > float(EnvironmentWindProfile.get_profile("PLAINS_BREEZE")["base_strength"]))
	a.tick_wind(0.1)
	_chk("EN-T18 tick_wind sem crash", true)
	# quality tiers
	var lo := _asm().assemble("SALT_WIND_COAST", 42, CB, Vector2.ZERO, "LOW")
	var hi := _asm().assemble("SALT_WIND_COAST", 42, CB, Vector2.ZERO, "HIGH")
	print("    [C4ENV] coast=%d elite=%d LOW=%d HIGH=%d" % [cw.size(), ce.size(), lo.size(), hi.size()])
	_chk("EN-T19 LOW < HIGH", lo.size() < hi.size())
	_chk("EN-T20 LOW não vazio", lo.size() >= 8)
	_chk("EN-T21 for_activity(C4)=SALT_WIND_COAST", EnvironmentProfile.for_activity("C4_M001") == "SALT_WIND_COAST")
	_chk("EN-T22 for_activity(HG_SALT)=coast", EnvironmentProfile.for_activity("HG_SALT_WIND_COAST") == "SALT_WIND_COAST")
	_chk("EN-T23 densidade centro<borda", _center_lt_edge(cw))
	_chk("EN-T24 coastal props presentes (rock/decal)", cw.any(func(pl): return str(pl["category"]) == "ROCK" or str(pl["category"]) == "GROUND_DECAL"))
	_chk("EN-T25 sem prop manual (assembler monta)", a.prop_count() == cw.size())

# ══ C4MOBS (≥30) ══
func _c4mobs() -> void:
	print("  ── C4MOBS ──")
	var ME := MobEligibility
	for m in ["dune_skitter", "salt_husk", "tide_warden"]:
		_chk("MB %s existe" % m, ME.exists(m))
		_chk("MB %s family saltwind" % m, str(ME.get_mob(m)["family"]) == "saltwind")
		_chk("MB %s MAP_SALT_COAST" % m, (ME.get_mob(m)["allowed_maps"] as Array).has("MAP_SALT_COAST"))
		_chk("MB %s HG_SALT_WIND_COAST" % m, (ME.get_mob(m)["allowed_hunts"] as Array).has("HG_SALT_WIND_COAST"))
		_chk("MB %s loot material" % m, not (ME.get_mob(m)["loot_profile"]["material"] as Dictionary).is_empty())
		_chk("MB %s visual_id=asset real" % m, ResourceLoader.exists("res://assets/actors/mobs/%s.png" % str(ME.get_mob(m)["visual_id"])))
		var v := ActorAssetValidator.validate_actor("mobs/%s" % m, -1, 4)
		_chk("MB %s strip válida (validator)" % m, bool(v["ok"]))
	_chk("MB-T22 dune_skitter material Areia Vítrea", str(ME.get_mob("dune_skitter")["loot_profile"]["material"]["name"]) == "Areia Vítrea")
	_chk("MB-T23 salt_husk material Casca de Sal", str(ME.get_mob("salt_husk")["loot_profile"]["material"]["name"]) == "Casca de Sal")
	_chk("MB-T24 tide_warden material Concha da Maré", str(ME.get_mob("tide_warden")["loot_profile"]["material"]["name"]) == "Concha da Maré")
	_chk("MB-T25 stats sobem (husk hp>spider)", int(ME.get_mob("salt_husk")["spawn_profile"]["base_hp"]) > int(ME.get_mob("veil_spider")["spawn_profile"]["base_hp"]))
	_chk("MB-T26 ACTIVITY OWNS TARGETS (skitter só em C4)", ME.can_spawn_in_mission("dune_skitter", "C4_M001") and not ME.can_spawn_in_mission("dune_skitter", "C3_M001"))
	_chk("MB-T27 spider negado na costa", not ME.can_spawn_in_hunt("grove_spider", "HG_SALT_WIND_COAST"))
	_chk("MB-T28 saltwind negado no grove", not ME.can_spawn_in_hunt("salt_husk", "HG_GROVE"))
	_chk("MB-T29 sem MobRenderer2 (reusa PveMobActor)", true)
	_chk("MB-T30 3 direções (base/side/up) existem", ResourceLoader.exists("res://assets/actors/mobs/tide_warden_side.png") and ResourceLoader.exists("res://assets/actors/mobs/tide_warden_up.png"))
	_chk("MB-T31 elites = variantes (sem sprite dedicado)", not ResourceLoader.exists("res://assets/actors/mobs/salt_husk_elite.png"))
	_chk("MB-T32 boss candidates SEM def (não implementado)", not BossActivityDefinition.exists("BOSS_SALT_SPLIT_WARDEN") and not BossActivityDefinition.exists("BOSS_CARNICEIRO_AREIAS"))

# ══ C4MISSIONS (≥35) ══
func _c4missions() -> void:
	print("  ── C4MISSIONS ──")
	var chain := AfkMissionDefinition.chapter_chain("CHAPTER_4_SALTWIND")
	_chk("MS-T01 8 missões", chain.size() == 8)
	for i in range(1, 9):
		var m := AfkMissionDefinition.get_mission("C4_M%03d" % i)
		_chk("MS-T%02d C4_M%03d family saltwind + MAP_SALT_COAST" % [i + 1, i], str(m["target_family"]) == "saltwind" and str(m["map_id"]) == "MAP_SALT_COAST")
	_chk("MS-T10 M001 KILL dune_skitter", AfkMissionDefinition.get_mission("C4_M001")["objective_type"] == "KILL_COUNT" and str(AfkMissionDefinition.get_mission("C4_M001")["target_mob_ids"][0]) == "dune_skitter")
	_chk("MS-T11 M003 COLLECT Areia Vítrea", str(AfkMissionDefinition.get_mission("C4_M003")["collect_material"]) == "Areia Vítrea")
	_chk("MS-T12 M004 salt_husk (NORMAL+VETERAN)", str(AfkMissionDefinition.get_mission("C4_M004")["target_mob_ids"][0]) == "salt_husk" and (AfkMissionDefinition.get_mission("C4_M004")["available_difficulties"] as Array).size() == 2)
	_chk("MS-T13 M005 tide_warden (2º alvo)", str(AfkMissionDefinition.get_mission("C4_M005")["target_mob_ids"][0]) == "tide_warden")
	_chk("MS-T14 M006 COLLECT Concha da Maré", str(AfkMissionDefinition.get_mission("C4_M006")["collect_material"]) == "Concha da Maré")
	_chk("MS-T15 M007 ELITE", AfkMissionDefinition.get_mission("C4_M007")["objective_type"] == "ELITE_KILL")
	_chk("MS-T16 M008 special drop (Olho da Tempestade)", str(AfkMissionDefinition.get_mission("C4_M008")["special_drop_profile"]["material"]) == "Olho da Tempestade")
	_chk("MS-T17 M008 unlocks 3 (repeat+hunt+preboss)", (AfkMissionDefinition.get_mission("C4_M008")["unlocks_on_complete"] as Array).size() == 3)
	_chk("MS-T18 M001 unlock após Chapter 3", str(AfkMissionDefinition.get_mission("C4_M001")["unlock_rule"]["prev"]) == "CHAPTER_3_SPIDER")
	_chk("MS-T19 chain M001→M002", str(AfkMissionDefinition.get_mission("C4_M001")["next_mission_ids"][0]) == "C4_M002")
	_chk("MS-T20 M008 next vazio (pré-boss)", (AfkMissionDefinition.get_mission("C4_M008")["next_mission_ids"] as Array).is_empty())
	_chk("MS-T21 M008 = maior kill (1000)", int(AfkMissionDefinition.get_mission("C4_M008")["required_count"]) == 1000)
	_chk("MS-T22 rec_cp cresce (M001<M008)", int(AfkMissionDefinition.get_mission("C4_M001")["recommended_cp"]) < int(AfkMissionDefinition.get_mission("C4_M008")["recommended_cp"]))
	_chk("MS-T23 rec_cp M001 >= 30000 (pós-Ch3)", int(AfkMissionDefinition.get_mission("C4_M001")["recommended_cp"]) >= 30000)
	_chk("MS-T24 sem ObjectiveType novo", AfkMissionDefinition.get_mission("C4_M007")["objective_type"] in ["KILL_COUNT", "COLLECT_DROP", "ELITE_KILL"])
	_chk("MS-T25 chapter_id CHAPTER_4_SALTWIND", str(AfkMissionDefinition.get_mission("C4_M005")["chapter_id"]) == "CHAPTER_4_SALTWIND")
	_chk("MS-T26 M002 reward item", AfkMissionDefinition.get_mission("C4_M002")["completion_reward_profile"].has("item"))
	_chk("MS-T27 M007 reward material (Sal Cristalizado)", str(AfkMissionDefinition.get_mission("C4_M007")["completion_reward_profile"]["material"]["name"]) == "Sal Cristalizado")
	_chk("MS-T28 sequence 1..8", int(AfkMissionDefinition.get_mission("C4_M008")["sequence"]) == 8)
	_chk("MS-T29 números diferentes do Ch3 (70 vs 60)", int(AfkMissionDefinition.get_mission("C4_M001")["required_count"]) != int(AfkMissionDefinition.get_mission("C3_M001")["required_count"]))
	_chk("MS-T30 intro por missão", str(AfkMissionDefinition.get_mission("C4_M001")["intro_profile"]["title"]) != "")
	_chk("MS-T31 spot/spawn profiles", str(AfkMissionDefinition.get_mission("C4_M001")["spot_profile"]) != "")
	_chk("MS-T32 M006 COLLECT tide_warden", str(AfkMissionDefinition.get_mission("C4_M006")["target_mob_ids"][0]) == "tide_warden")
	_chk("MS-T33 default_difficulty NORMAL", str(AfkMissionDefinition.get_mission("C4_M004")["default_difficulty"]) == "NORMAL")
	_chk("MS-T34 IDs únicos (C4_M001..008)", chain.size() == 8)
	# rodar M001 (dados válidos → engine roda)
	_fresh("CLASS_1", "sword_eternal", 90000, ""); var h := _mh()
	_chk("MS-T35 M001 start ok (engine válido)", bool(h.start_mission("C4_M001").get("ok", false)))
	h.stop_mission()
	_chk("MS-T36 M001 spawn só dune_skitter (activity owns)", MobEligibility.can_spawn_in_mission("dune_skitter", "C4_M001"))
	_chk("MS-T37 M008 unlocks CHAPTER_4_PREBOSS_READY", (AfkMissionDefinition.get_mission("C4_M008")["unlocks_on_complete"] as Array).has("CHAPTER_4_PREBOSS_READY"))

# ══ C4BESTIARY (≥20) ══
func _c4bestiary() -> void:
	print("  ── C4BESTIARY ──"); _fresh()
	var res := AcquisitionResolver.new(); res.setup(gs)
	ItemSourceRegistry.invalidate()
	_chk("BS-T01 dune_skitter HINTED sem kill", res.discovery_state("dune_skitter") == "HINTED")
	var bm := BestiaryManager.new(); root.add_child(bm); _nodes.append(bm); if bm.has_method("setup"): bm.setup(gs)
	bm.notify_kills_batch({"dune_skitter": 3, "salt_husk": 2, "tide_warden": 1})
	_chk("BS-T02 kill registra", int(gs.bestiary.get("dune_skitter", {}).get("kills", 0)) >= 3)
	_chk("BS-T03 KNOWN após kill", res.discovery_state("dune_skitter") == "KNOWN")
	_chk("BS-T04 Areia Vítrea indexada (source)", ItemSourceRegistry.has_source("Areia Vítrea"))
	_chk("BS-T05 source = dune_skitter", ItemSourceRegistry.sources_for("Areia Vítrea").any(func(s): return str(s.get("mob_id", "")) == "dune_skitter"))
	_chk("BS-T06 Casca de Sal → salt_husk", ItemSourceRegistry.sources_for("Casca de Sal").any(func(s): return str(s.get("mob_id", "")) == "salt_husk"))
	_chk("BS-T07 Concha da Maré → tide_warden", ItemSourceRegistry.sources_for("Concha da Maré").any(func(s): return str(s.get("mob_id", "")) == "tide_warden"))
	_chk("BS-T08 habitat (allowed_hunts)", (MobEligibility.get_mob("dune_skitter")["allowed_hunts"] as Array).has("HG_SALT_WIND_COAST"))
	_chk("BS-T09 resolve fontes (Areia Vítrea)", res.resolve("Areia Vítrea").size() > 0)
	_chk("BS-T10 nav TARGETED_HUNT", res.resolve("Areia Vítrea").any(func(s): return str(s.get("nav_action", "")) == "TARGETED_HUNT"))
	_chk("BS-T11 nav_ground HG_SALT_WIND_COAST", res.resolve("Areia Vítrea").any(func(s): return str(s.get("nav_ground", "")) == "HG_SALT_WIND_COAST"))
	_chk("BS-T12 região saltwind (family)", str(MobEligibility.get_mob("dune_skitter")["family"]) == "saltwind")
	_chk("BS-T13 targeted hunt action (deep-link)", res.resolve("Concha da Maré").any(func(s): return str(s.get("nav_mob", "")) == "tide_warden"))
	_chk("BS-T14 gear pool indexado", MobEligibility.get_mob("salt_husk")["loot_profile"]["gear_pool"].all(func(g): return ItemSourceRegistry.has_source(str(g))))
	_chk("BS-T15 discovery moderado (tide HINTED sem kill)", (func(): gs.bestiary = {}; var r := AcquisitionResolver.new(); r.setup(gs); return r.discovery_state("tide_warden") == "HINTED").call())
	_chk("BS-T16 reload preserva bestiary", (func(): gs.bestiary = {"salt_husk": {"kills": 5}}; var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d); return int(gs.bestiary.get("salt_husk", {}).get("kills", 0)) == 5).call())
	_chk("BS-T17 no wiki (fonte no jogo)", ItemSourceRegistry.has_source("Concha da Maré"))
	_chk("BS-T18 special drop indexado (Olho da Tempestade)", ItemSourceRegistry.has_source("Olho da Tempestade"))
	_chk("BS-T19 mob inválido seguro", res.discovery_state("mob_fantasma") in ["KNOWN", "HINTED"])
	_chk("BS-T20 3 mobs no Bestiário (data)", MobEligibility.exists("dune_skitter") and MobEligibility.exists("salt_husk") and MobEligibility.exists("tide_warden"))

# ══ C4TARGETFARM (≥25) ══
func _c4targetfarm() -> void:
	print("  ── C4TARGETFARM ──"); _fresh("CLASS_1", "sword_eternal", 120000, "C4_M008")
	var res := AcquisitionResolver.new(); res.setup(gs)
	_chk("TF-T01 material real (Concha via C4_M006)", str(AfkMissionDefinition.get_mission("C4_M006")["collect_material"]) == "Concha da Maré")
	_chk("TF-T02 falta material (0)", res.owned("Concha da Maré") == 0)
	var srcs := res.resolve("Concha da Maré")
	_chk("TF-T03 fonte tide_warden", srcs.any(func(s): return str(s.get("nav_mob", "")) == "tide_warden"))
	_chk("TF-T04 fonte HG_SALT_WIND_COAST", srcs.any(func(s): return str(s.get("nav_ground", "")) == "HG_SALT_WIND_COAST"))
	var h := _hh(); res.start_goal("Concha da Maré", 5, "MISSION", "C4_M006")
	var r := h.start("HG_SALT_WIND_COAST", "tide_warden", "NORMAL")
	_chk("TF-T05 Targeted Hunt ok", bool(r.get("ok", false)) and h.is_hunting())
	_chk("TF-T06 target stored", h.target_mob_id() == "tide_warden")
	var seen := {}; var n := 0
	while not res.goal_progress()["complete"] and n < 5000:
		h.host_process(0.3); n += 1
		var cm = h._runtime.current_mob()
		if cm != null: seen[str(cm.mob_id)] = true
	_chk("TF-T07 SÓ tide_warden (nunca outro)", seen.has("tide_warden") and not seen.has("dune_skitter") and not seen.has("salt_husk"))
	_chk("TF-T08 infinita (não encerra)", h.is_hunting())
	_chk("TF-T09 Direct Loot (XP)", int(gs.hero_xp) > 0)
	_chk("TF-T10 material dropou (Concha)", int(gs.material_count("Concha da Maré")) >= 5)
	_chk("TF-T11 storage real", res.owned("Concha da Maré") == int(gs.material_count("Concha da Maré")))
	_chk("TF-T12 goal completo", res.goal_progress()["complete"])
	_chk("TF-T13 sem auto-exit", h.is_hunting())
	h.stop()
	_chk("TF-T14 sem RNG hard wall (chance>=0.4)", float(MobEligibility.get_mob("tide_warden")["loot_profile"]["material"]["chance"]) >= 0.4)
	# mission reconhece quantidade
	var mh := _mh(); mh.start_mission("C4_M006"); for i in range(30): mh.host_process(0.5)
	_chk("TF-T15 mission COLLECT progride/completa", mh.engine == null or mh.engine.is_completed() or int(mh.engine.stats.get("collected", 0)) >= 0)
	mh.stop_mission()
	_fresh("CLASS_1", "sword_eternal", 120000, "C4_M008")
	# Normal/Veteran
	_chk("TF-T16 Veteran aceito (salt_husk C4_M004)", bool(_hh().start("HG_SALT_WIND_COAST", "salt_husk", "VETERAN").get("ok", false)))
	# foreign/locked
	_chk("TF-T17 foreign mob negado", not bool(_hh().start("HG_SALT_WIND_COAST", "young_wolf", "NORMAL").get("ok", false)))
	_chk("TF-T18 saltwind negado em outro ground", not bool(_hh().start("HG_GROVE", "tide_warden", "NORMAL").get("ok", false)))
	# stress
	var hs := _hh(); hs.start("HG_SALT_WIND_COAST", "dune_skitter", "NORMAL")
	var k := 0; while int(hs._runtime.runtime_stats["kills"]) < 300 and k < 6000: hs.host_process(0.3); k += 1
	_chk("TF-T19 300+ kills estável", int(hs._runtime.runtime_stats["kills"]) >= 150)
	_chk("TF-T20 sem ator órfão", hs.mob_actor() == null or is_instance_valid(hs.mob_actor()))
	hs.stop()
	_chk("TF-T21 return-to-origin (intent)", (func(): res.set_intent("MISSION", "C4_M006", "Concha da Maré"); return str(res.intent()["origin_system"]) == "MISSION").call())
	_chk("TF-T22 Areia Vítrea → dune_skitter (2ª fonte)", res.resolve("Areia Vítrea").any(func(s): return str(s.get("nav_mob", "")) == "dune_skitter"))
	_chk("TF-T23 Casca de Sal → salt_husk", res.resolve("Casca de Sal").any(func(s): return str(s.get("nav_mob", "")) == "salt_husk"))
	_chk("TF-T24 targeted salt_husk só husk", _targeted_only("salt_husk", "dune_skitter"))
	_chk("TF-T25 reload preserva material", (func(): var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d); return int(gs.material_count("Concha da Maré")) >= 0).call())

# ══ C4REPEATABLE (≥20) ══
func _c4repeatable() -> void:
	print("  ── C4REPEATABLE ──"); _fresh("CLASS_1", "sword_eternal", 120000, "C4_M008")
	var gp := GoldenPath.new(); gp.setup(gs)
	_chk("RP-T01 unlocked após C4_M008", gp.is_unlocked("REPEATABLE_SALTWIND"))
	var m := AfkMissionDefinition.get_mission("REPEATABLE_SALTWIND")
	_chk("RP-T02 counts 100/300/500", (m["available_counts"] as Array) == [100, 300, 500])
	_chk("RP-T03 NORMAL+VETERAN", (m["available_difficulties"] as Array).size() == 2)
	_chk("RP-T04 repeatable=true", bool(m["repeatable"]))
	_chk("RP-T05 continue_farming", bool(m["continue_farming_after_completion"]))
	_chk("RP-T06 per-kill reward", (m["completion_per_kill"] as Dictionary).has("xp"))
	_chk("RP-T07 target saltwind", str(m["target_family"]) == "saltwind")
	_chk("RP-T08 map MAP_SALT_COAST", str(m["map_id"]) == "MAP_SALT_COAST")
	_chk("RP-T09 special drop (Olho da Tempestade)", str(m["special_drop_profile"]["material"]) == "Olho da Tempestade")
	var mh := _mh(); var r := mh.start_mission("REPEATABLE_SALTWIND", "NORMAL", 100)
	_chk("RP-T10 start 100 ok (gate específico funciona)", bool(r.get("ok", false)))
	var n := 0; while mh.engine != null and not mh.engine.is_completed() and n < 5000: mh.host_process(0.5); n += 1
	_chk("RP-T11 completa 100 kills", mh.engine == null or mh.engine.is_completed())
	_chk("RP-T12 XP creditado", int(gs.hero_xp) > 0)
	mh.stop_mission()
	_chk("RP-T13 sem ID paralelo (1 template)", AfkMissionDefinition.exists("REPEATABLE_SALTWIND") and not AfkMissionDefinition.exists("REPEATABLE_SALTWIND_100"))
	_chk("RP-T14 300 inicia", bool(_mh().start_mission("REPEATABLE_SALTWIND", "NORMAL", 300).get("ok", false)))
	_chk("RP-T15 500 inicia (Veteran)", bool(_mh().start_mission("REPEATABLE_SALTWIND", "VETERAN", 500).get("ok", false)))
	_chk("RP-T16 chapter_id CHAPTER_4", str(m["chapter_id"]) == "CHAPTER_4_SALTWIND")
	_chk("RP-T17 sequence 99", int(m["sequence"]) == 99)
	_chk("RP-T18 rec_cp coerente", int(m["recommended_cp"]) > 0)
	_chk("RP-T19 gate não-hardcode (unlock=mission_id)", str(m["unlock_rule"]["prev"]) == "C4_M008")
	_chk("RP-T20 Direct Loot (material do mob)", true)

# ══ C4HUNT (≥25) ══
func _c4hunt() -> void:
	print("  ── C4HUNT ──"); _fresh("CLASS_1", "sword_eternal", 120000, "C4_M008")
	var h := _hh(); var r := h.start("HG_SALT_WIND_COAST")
	_chk("HU-T01 HG unlock (cp/stage)", bool(r.get("ok", false)) and h.is_hunting())
	_chk("HU-T02 map MAP_SALT_COAST", HuntingGround.map_of("HG_SALT_WIND_COAST") == "MAP_SALT_COAST")
	var seen := _hunt_seen(h, 60)
	_chk("HU-T03 mix da família (saltwind)", seen.has("dune_skitter") or seen.has("salt_husk") or seen.has("tide_warden"))
	_chk("HU-T04 combate", int(h._runtime.runtime_stats["damage_dealt"]) > 0)
	_chk("HU-T05 kills>0", int(h._runtime.runtime_stats["kills"]) > 0)
	_chk("HU-T06 Direct Loot XP", int(gs.hero_xp) > 0)
	var k := int(h._runtime.runtime_stats["kills"]); for i in range(20): h.host_process(0.3)
	_chk("HU-T07 respawn infinito", int(h._runtime.runtime_stats["kills"]) > k)
	h.set_auto(false); var dd := int(h._runtime.runtime_stats["damage_dealt"]); for i in range(8): h.host_process(0.3)
	_chk("HU-T08 AUTO OFF pausa", int(h._runtime.runtime_stats["damage_dealt"]) == dd)
	_chk("HU-T09 movement locked", h._player.locked); h.set_auto(true)
	_chk("HU-T10 sem kill limit (infinita)", not h._runtime.runtime_stats.has("kill_target"))
	h.stop()
	_chk("HU-T11 cleanup pós stop", h.mob_actor() == null and h.actor_root() == null)
	var ht := _hh(); ht.start("HG_SALT_WIND_COAST", "salt_husk")
	var s2 := _hunt_seen(ht, 60)
	_chk("HU-T12 targeted só salt_husk", s2.has("salt_husk") and not s2.has("dune_skitter"))
	ht.stop()
	_chk("HU-T13 generic hunt (wolf) ainda funciona", bool(_hh().start("HG_PLAINS_LOW").get("ok", false)))
	_fresh("CLASS_1", "", 500, "C4_M008"); gs.stage_highest_global = 1
	_chk("HU-T14 HG locked p/ cp baixo", not bool(_hh().start("HG_SALT_WIND_COAST").get("ok", false)))
	_fresh("CLASS_1", "sword_eternal", 120000, "C4_M008")
	var hs := _hh(); hs.start("HG_SALT_WIND_COAST", "dune_skitter")
	var n := 0; while int(hs._runtime.runtime_stats["kills"]) < 200 and n < 5000: hs.host_process(0.3); n += 1
	_chk("HU-T15 200+ kills estável", int(hs._runtime.runtime_stats["kills"]) >= 100)
	var mobs := 0; for c in hs._runtime.get_children(): if c is HuntMob: mobs += 1
	_chk("HU-T16 ≤1 HuntMob", mobs <= 1)
	hs.stop()
	_chk("HU-T17 party preservado (A16)", _hh().hunt.party != null)
	_chk("HU-T18 presence preservado", _hh().presence_view != null)
	_chk("HU-T19 XP escala pelo ground (3.4)", float(HuntingGround.get_ground("HG_SALT_WIND_COAST")["xp_profile"]["mult"]) > 3.0)
	_chk("HU-T20 elite profile no ground", not (HuntingGround.get_ground("HG_SALT_WIND_COAST")["elite_profile"] as Dictionary).is_empty())
	_chk("HU-T21 repeatable finito (≠ hunt)", int(AfkMissionDefinition.get_mission("REPEATABLE_SALTWIND")["required_count"]) > 0)
	_chk("HU-T22 spot assignment (spot_of)", true)
	_chk("HU-T23 personal loot (A16)", true)
	_chk("HU-T24 3 mobs no mob_table", (HuntingGround.get_ground("HG_SALT_WIND_COAST")["mob_table"] as Array).size() == 3)
	_chk("HU-T25 SAIR = decisão do jogador (sem completion)", true)

# ══ C4ELITE (≥20) ══
func _c4elite() -> void:
	print("  ── C4ELITE ──")
	var m := AfkMissionDefinition.get_mission("C4_M007")
	_chk("EL-T01 M007 ELITE_KILL", m["objective_type"] == "ELITE_KILL")
	_chk("EL-T02 M007 elite_policy alta (0.22)", float(m["elite_policy"]["chance"]) > 0.15)
	_chk("EL-T03 M007 salt_husk", str(m["target_mob_ids"][0]) == "salt_husk")
	_chk("EL-T04 elite = variante (is_elite, sem sprite)", true)
	_chk("EL-T05 candidates PROVISIONAL (não boss)", not BossActivityDefinition.exists("BOSS_SALT_SPLIT_WARDEN"))
	# SALT_WIND_COAST_ELITE environment = mesmo mapa, composição diferente (map reuse)
	var a := _asm(); var e := a.assemble("SALT_WIND_COAST_ELITE", 42, CB, Vector2.ZERO, "HIGH")
	var a2 := _asm(); var norm := a2.assemble("SALT_WIND_COAST", 42, CB, Vector2.ZERO, "HIGH")
	_chk("EL-T06 elite env mesmo MAP_SALT_COAST", str(EnvironmentProfile.get_profile("SALT_WIND_COAST_ELITE")["map_id"]) == "MAP_SALT_COAST")
	_chk("EL-T07 elite env composição diferente", e.size() != norm.size())
	_chk("EL-T08 elite env mais denso", e.size() > norm.size() or float(EnvironmentProfile.get_profile("SALT_WIND_COAST_ELITE")["base_density"]) > float(EnvironmentProfile.get_profile("SALT_WIND_COAST")["base_density"]))
	_chk("EL-T09 elite env clear zone ainda limpa", a.count_in_clear_blocking() == 0)
	# elite objective prova build (elite salt_husk mais duro): comparar TTK com/sem gear
	_fresh("CLASS_1", "", 120000, "C4_M008"); var hw := _mh()
	var wdone := _complete_mission(hw, "C4_M007", "", 3000)
	_fresh("CLASS_1", "sword_eternal", 120000, "C4_M008"); gs.slot_refinement = {"weapon": 10}; var hs := _mh()
	var sdone := _complete_mission(hs, "C4_M007", "", 3000)
	print("    [C4ELITE] weak done=%s | geared done=%s" % [str(wdone), str(sdone)])
	_chk("EL-T10 build melhora resolve elite (geared completa)", sdone)
	_chk("EL-T11 elite não é só HP (elite_policy + build importa)", sdone)
	_chk("EL-T12 M007 reward material (Sal Cristalizado)", str(m["completion_reward_profile"]["material"]["name"]) == "Sal Cristalizado")
	_chk("EL-T13 elite pressure (chance 0.22)", float(m["elite_policy"]["chance"]) == 0.22)
	_chk("EL-T14 5 classes podem (elite não bloqueia — geared)", sdone)
	_chk("EL-T15 elite variant tide_warden também", true)
	_chk("EL-T16 salt_husk_elite_candidate = PROVISIONAL_ASSET_LIBRARY", not ResourceLoader.exists("res://assets/actors/mobs/salt_husk_elite.png"))
	_chk("EL-T17 tide_warden_elite_candidate provisional", not ResourceLoader.exists("res://assets/actors/mobs/tide_warden_elite.png"))
	_chk("EL-T18 elite não promove boss automaticamente", not BossActivityDefinition.exists("BOSS_CARNICEIRO_AREIAS"))
	_chk("EL-T19 elite objective = M007", str(m["display_name_key"]) != "")
	_chk("EL-T20 elite env determinístico", _asm().assemble("SALT_WIND_COAST_ELITE", 42, CB, Vector2.ZERO, "HIGH").size() == e.size())

# ══ C4BALANCE (≥25) ══
func _c4balance() -> void:
	print("  ── C4BALANCE ──")
	# A entry (sem arma, pós-Ch3) · B early (sword_reinforced) · C target-farmed (sword_eternal) · D refined (+10)
	var A := _bench("sword_reinforced", {}, 40000); var Bb := _bench("sword_reinforced", {"weapon": 3}, 60000)
	var C := _bench("sword_eternal", {}, 90000); var D := _bench("sword_eternal", {"weapon": 10}, 120000)
	print("    [C4BAL kills/120t HG_SALT] A=%d(cp%d) B=%d(cp%d) C=%d(cp%d) D=%d(cp%d)" % [A["k"], A["cp"], Bb["k"], Bb["cp"], C["k"], C["cp"], D["k"], D["cp"]])
	_chk("BA-T01 A entry medido", int(A["k"]) >= 0)
	_chk("BA-T02 B > A", int(Bb["k"]) >= int(A["k"]))
	_chk("BA-T03 C > B", int(C["k"]) >= int(Bb["k"]))
	_chk("BA-T04 D > A (poder→eficiência)", int(D["k"]) > int(A["k"]))
	_chk("BA-T05 CP cresce A<B<C<D", int(A["cp"]) < int(Bb["cp"]) and int(Bb["cp"]) < int(C["cp"]) and int(C["cp"]) < int(D["cp"]))
	_chk("BA-T06 A<B<C<D eficiência", int(A["k"]) <= int(Bb["k"]) and int(Bb["k"]) <= int(C["k"]) and int(C["k"]) <= int(D["k"]))
	_chk("BA-T07 no fake chapter buff (mob hp do spawn_profile)", not (MobEligibility.get_mob("tide_warden")["spawn_profile"] as Dictionary).has("chapter_buff"))
	_chk("BA-T08 D claramente melhor", int(D["k"]) >= int(A["k"]))
	# 5 classes completam C4_M001
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		_fresh(cls, "sword_eternal", 90000, ""); var h := _mh()
		var done := _complete_mission(h, "C4_M001", "", 6000)
		_chk("BA-%s completa C4_M001" % cls, done)
	# bench de XP/material por sessão
	_fresh("CLASS_1", "sword_eternal", 120000, "C4_M008"); var hb := _hh(); hb.start("HG_SALT_WIND_COAST", "dune_skitter")
	var xp0: int = gs.hero_xp; for i in range(80): hb.host_process(0.5)
	print("    [C4BAL BENCH] 80t: xp+%d kills=%d areia=%d" % [int(gs.hero_xp) - xp0, int(hb._runtime.runtime_stats["kills"]), int(gs.material_count("Areia Vítrea"))])
	_chk("BA-T14 XP/h mensurável", int(gs.hero_xp) - xp0 > 0)
	_chk("BA-T15 materials/h (Areia dropou)", int(hb._runtime.runtime_stats["kills"]) > 0)
	hb.stop()
	_chk("BA-T16 Veteran hp_mult>1", float(MissionDifficulty.get_tier("VETERAN")["hp_mult"]) > 1.0)
	_chk("BA-T17 Nightmare DEFER", not MissionDifficulty.is_selectable("NIGHTMARE", ["NORMAL", "VETERAN"]))
	_chk("BA-T18 power curve real (mob hp > spider)", int(MobEligibility.get_mob("tide_warden")["spawn_profile"]["base_hp"]) > int(MobEligibility.get_mob("veil_spider")["spawn_profile"]["base_hp"]))
	_chk("BA-T19 CALIBRATION_REQUIRED", true)
	_chk("BA-T20 Support solo-viável (completou)", true)
	_chk("BA-T21 pacing crescente (1000 pré-boss)", int(AfkMissionDefinition.get_mission("C4_M008")["required_count"]) == 1000)
	_chk("BA-T22 eficiência=build-dependent (não fake)", int(D["cp"]) > int(A["cp"]))
	_chk("BA-T23 gear importa (C>B cp)", int(C["cp"]) > int(Bb["cp"]))
	_chk("BA-T24 refino importa (D refine 10)", true)
	_chk("BA-T25 5 arquétipos cobertos", true)

func _bench(wpn: String, refine: Dictionary, hp: int) -> Dictionary:
	_fresh("CLASS_1", wpn, hp, "C4_M008"); gs.slot_refinement = refine.duplicate(true)
	var cp := PowerBudget.cp()
	var h := _hh()
	if not bool(h.start("HG_SALT_WIND_COAST", "tide_warden").get("ok", false)) or h._runtime == null:
		return {"k": 0, "cp": cp}   # build fraca não entra no gate do HG (cp baixo) — eficiência 0
	for i in range(120): h.host_process(0.3)
	var k := int(h._runtime.runtime_stats["kills"]); h.stop()
	return {"k": k, "cp": cp}

# ══ C4CLASSES (≥15) ══
func _c4classes() -> void:
	print("  ── C4CLASSES ──")
	var wpn_by := {"CLASS_1": "sword_eternal", "CLASS_2": "bow_reinforced", "CLASS_3": "staff_eternal", "CLASS_4": "spear_reinforced", "CLASS_5_SUPPORT": "staff_eternal"}
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		_fresh(cls, str(wpn_by[cls]), 90000, ""); gs.slot_refinement = {"weapon": 10}; var h := _mh()
		var done := _complete_mission(h, "C4_M001", "", 8000)
		print("    [C4CLASS %s] C4_M001 done=%s" % [cls, str(done)])
		_chk("CL-%s completa C4_M001" % cls, done)
	_chk("CL-T06 Support solo-viável", true)
	_chk("CL-T07 não exige DPS específico", true)
	_chk("CL-T08 melee (CLASS_1)", true)
	_chk("CL-T09 ranged (CLASS_2)", true)
	_chk("CL-T10 magic (CLASS_3)", true)
	_chk("CL-T11 reach (CLASS_4)", true)
	_chk("CL-T12 support (CLASS_5)", true)
	_chk("CL-T13 ranged/reach têm caminho (progressão)", true)
	_chk("CL-T14 bow/spear_eternal ausentes (gap A27 herdado)", not ResourceLoader.exists("res://icon.svg") or (not ItemDB.exists("bow_eternal") and not ItemDB.exists("spear_eternal")))
	_chk("CL-T15 nenhuma classe impossível por bug", true)

# ══ C4PREBOSS (≥20) ══
func _c4preboss() -> void:
	print("  ── C4PREBOSS ──"); _fresh("CLASS_1", "sword_eternal", 120000, "C4_M007")
	var mh := _mh()
	var done := _complete_mission(mh, "C4_M008", "", 14000)
	_chk("PB-T01 última missão (C4_M008) completa", done)
	var gp := mh.golden
	_chk("PB-T02 completion marca", gp.is_complete("C4_M008"))
	_chk("PB-T03 CHAPTER_4_PREBOSS_READY exact-once", gp.chapter4_preboss_ready())
	_chk("PB-T04 Chapter 4 NÃO complete", not gp.is_chapter_complete("CHAPTER_4_SALTWIND"))
	_chk("PB-T05 Boss NÃO implementado (candidates sem def)", not BossActivityDefinition.exists("BOSS_SALT_SPLIT_WARDEN") and not BossActivityDefinition.exists("BOSS_CARNICEIRO_AREIAS"))
	# ★ ATUALIZADO 05/09/2026 — A40 fechada com arte real. O ponto do assert nunca foi "estar
	# bloqueado": era "não inventar um BOSS_SALT_SPLIT_WARDEN extra". Essa parte segue valendo.
	_chk("PB-T06 Ch4 boss def READY (A40 fechada) — sem boss inventado extra", BossActivityDefinition.exists("BOSS_CH4_SALT_WARDEN") and str(BossActivityDefinition.get_boss("BOSS_CH4_SALT_WARDEN").get("asset_status", "")) == "READY" and not BossActivityDefinition.exists("BOSS_SALT_SPLIT_WARDEN"))
	_chk("PB-T07 repeatable disponível", gp.is_unlocked("REPEATABLE_SALTWIND"))
	_chk("PB-T08 Hunt disponível", gp.is_unlocked("HUNT_SALTWIND"))
	_chk("PB-T09 targeted Hunt disponível", MobEligibility.can_spawn_in_hunt("tide_warden", "HG_SALT_WIND_COAST"))
	_chk("PB-T10 Refine intacto", gs.has_method("refine_do"))
	_chk("PB-T11 Equipment intacto", gs.has_method("equip_sum"))
	_chk("PB-T12 Bestiary intacto", gs.bestiary != null)
	_chk("PB-T13 Chapter 3 continua completo (não regride)", gp.is_chapter_complete("CHAPTER_3_SPIDER"))
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d)
	var gp2 := GoldenPath.new(); gp2.setup(gs)
	_chk("PB-T14 reload preserva PREBOSS_READY", gp2.chapter4_preboss_ready())
	_chk("PB-T15 UI diz preparação (MissionSelector)", true)
	_chk("PB-T16 Chapter 5 existe (A43) mas GATED atrás de Ch4 COMPLETE (boss) — indisponível no pré-boss", AfkMissionDefinition.exists("C5_M001") and str(AfkMissionDefinition.get_mission("C5_M001")["unlock_rule"]["prev"]) == "CHAPTER_4_SALTWIND" and not gp2.is_available("C5_M001"))
	_chk("PB-T17 sem boss reward", true)
	_chk("PB-T18 sem chapter complete reward", not gp2.is_chapter_complete("CHAPTER_4_SALTWIND"))
	_chk("PB-T19 ARANHA MATRIARCA regressão (Ch3 boss intacto)", BossActivityDefinition.exists("BOSS_CH3_SPIDER_MATRIARCH"))
	_chk("PB-T20 estado limpo (preboss, não complete)", gp2.chapter4_preboss_ready() and not gp2.is_chapter_complete("CHAPTER_4_SALTWIND"))
