extends SceneTree
## A29 REALSCENE29 — CHAPTER 4 COSTA DO SAL-VENTO na Main.tscn REAL. Unlock após Ch3 → Mission (dune_skitter + ambiente
## costeiro) → targeted hunt → M008 → GP_CHAPTER_4_PREBOSS_READY. + ARANHA MATRIARCA regressão. Save fixture.

var main: Node = null
var _frame := 0
var _phase := 0
var _fail := 0
var gs; var mh; var hh; var router: PlayerUiRouter; var res: AcquisitionResolver
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _phase == 0 and _frame >= 3:
		_phase = 1
		if main.has_method("_enter_game"): main._enter_game()
	elif _phase == 1 and _frame >= 8:
		_phase = 2
		gs = root.get_node_or_null("GameState")
		gs.set_save_path_override("user://a29s_fixture.json")
		mh = main.get("_missionhost"); hh = main.get("_hunthost"); router = main.get("_ui_router"); res = main.get("_acq_resolver")
		_run()
		if FileAccess.file_exists("user://a29s_fixture.json"): DirAccess.remove_absolute("user://a29s_fixture.json")
		print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
		quit(0 if _fail == 0 else 1)

func _prep(preboss := false) -> void:
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 10}
	gs.hero_hp_max = 120000; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0
	gs.stage_highest_global = 60; gs.materials = {"Fragmentos": 5000}; gs.backpack = []; gs.locked_items.clear()
	gs.bestiary = {"tide_warden": {"kills": 5}}; gs.tracked_goal = {}; gs.acquisition_intent = {}; gs.tracked_boss = {}
	var f: Array[String] = ["GP_MISSION_006_COMPLETE", "GP_CHAPTER_1_WOLF_COMPLETE", "GP_CHAPTER_2_CRYSTAL_COMPLETE", "GP_CHAPTER_3_SPIDER_COMPLETE", "GP_UNLOCK_HUNT_SALTWIND"]
	for i in range(1, 9): f.append("GP_C2_M%03d_COMPLETE" % i)
	for i in range(1, 9): f.append("GP_C3_M%03d_COMPLETE" % i)
	if preboss:
		for i in range(1, 9): f.append("GP_C4_M%03d_COMPLETE" % i)
		f.append("GP_UNLOCK_REPEATABLE_SALTWIND"); f.append("GP_UNLOCK_CHAPTER_4_PREBOSS_READY")
	gs.story_flags = f

func _env(): return main.get("_environment")

func _run() -> void:
	print("  ── A29 REALSCENE (Main.tscn) ──")
	var pl: Node2D = main.get("_player")
	# ── Chapter 4 locked antes de Ch3? (novo char sem Ch3) ──
	var f0: Array[String] = ["GP_MISSION_006_COMPLETE"]; gs.reset_save(); gs.story_flags = f0
	_chk("RS29-T01 Chapter 4 LOCKED sem Ch3", not mh.golden.is_available("C4_M001"))
	_prep()
	_chk("RS29-T02 Chapter 4 UNLOCK após ARANHA MATRIARCA (Ch3 complete)", mh.golden.is_available("C4_M001"))
	# ── Mission C4_M001 (dune_skitter + ambiente costeiro) ──
	var r: Dictionary = mh.start_mission("C4_M001")
	_chk("RS29-T03 C4_M001 inicia", bool(r.get("ok", false)))
	for i in range(20): mh.host_process(0.4)
	var wct := 0
	while mh.mob_actor() == null and wct < 40: mh.host_process(0.15); wct += 1
	_chk("RS29-T04 ambiente/player visível", pl.is_visible_in_tree())
	_chk("RS29-T05 Living World montado (SALT_WIND_COAST)", _env() != null and _env().profile_id == "SALT_WIND_COAST")
	_chk("RS29-T06 ground contínuo costeiro (sem tile grid)", _env() != null and _env().ground_node() is Sprite2D and str(_env().ground_node().texture.resource_path).contains("saltwind"))
	_chk("RS29-T07 props costeiros montados (assembler, não manual)", _env() != null and _env().prop_nodes().size() > 0)
	var has_tm := false
	if _env() != null:
		for c in _env().get_children(): if c is TileMap or c is TileMapLayer: has_tm = true
	_chk("RS29-T08 NENHUM TileMap", not has_tm)
	_chk("RS29-T09 dune_skitter ATOR visível (sprite real)", mh.mob_actor() != null and mh.mob_actor().is_visible_in_tree() and not mh.mob_actor().used_fallback)
	_chk("RS29-T10 mob lógico = dune_skitter", mh.engine.current_mob() != null and mh.engine.current_mob().mob_id == "dune_skitter")
	_chk("RS29-T11 hero ataca", int(mh.engine.stats["hero_attacks"]) > 0)
	_chk("RS29-T12 mob ataca", int(mh.engine.stats["mob_attacks"]) > 0)
	_chk("RS29-T13 kill (progresso)", int(mh.engine.stats["kills"]) > 0)
	_chk("RS29-T14 Direct Loot XP (sem floor)", int(gs.hero_xp) > 0)
	_chk("RS29-T15 centro de combate limpo (clear zone)", _env() == null or _env().count_in_clear_blocking() == 0)
	mh.stop_mission()
	_chk("RS29-T16 environment removido ao sair", _env() == null)
	# ── material → Como Obter → Targeted Hunt (tide_warden) ──
	_prep()
	res.setup(gs)
	var srcs := res.resolve("Concha da Maré")
	_chk("RS29-T17 fonte tide_warden (Como Obter)", srcs.any(func(s): return str(s.get("nav_mob", "")) == "tide_warden"))
	var rh: Dictionary = hh.start("HG_SALT_WIND_COAST", "tide_warden", "NORMAL")
	_chk("RS29-T18 Targeted Hunt inicia (tide_warden)", bool(rh.get("ok", false)) and hh.target_mob_id() == "tide_warden")
	for i in range(20): hh.host_process(0.4)
	var wc2 := 0
	while hh.mob_actor() == null and wc2 < 40: hh.host_process(0.15); wc2 += 1
	_chk("RS29-T19 ambiente costeiro no HG", _env() != null and _env().profile_id == "SALT_WIND_COAST")
	_chk("RS29-T20 SÓ tide_warden visível (sprite real)", hh.mob_actor() != null and hh.mob_actor().mob_id == "tide_warden" and hh.mob_actor().is_visible_in_tree())
	var rt = hh.get("_runtime")
	_chk("RS29-T21 combate bidirecional", int(rt.runtime_stats["damage_dealt"]) > 0 and int(rt.runtime_stats["damage_taken"]) > 0)
	# material dropa
	var n := 0
	while int(gs.material_count("Concha da Maré")) < 3 and n < 4000: hh.host_process(0.3); n += 1
	_chk("RS29-T22 material dropou (Concha da Maré)", int(gs.material_count("Concha da Maré")) >= 3)
	_chk("RS29-T23 Hunt infinita (não encerra)", hh.is_hunting())
	# AUTO OFF regressão
	hh.set_auto(false); var dd := int(rt.runtime_stats["damage_dealt"]); for i in range(8): hh.host_process(0.3)
	_chk("RS29-T24 AUTO OFF pausa (regressão)", int(rt.runtime_stats["damage_dealt"]) == dd)
	_chk("RS29-T25 movement locked", hh._player.locked); hh.set_auto(true)
	hh.stop()
	# ── pré-boss: preboss ready, chapter não complete, sem boss ──
	_prep(true)
	_chk("RS29-T26 CHAPTER_4_PREBOSS_READY", mh.golden.chapter4_preboss_ready())
	_chk("RS29-T27 Chapter 4 NÃO complete (sem boss)", not mh.golden.is_chapter_complete("CHAPTER_4_SALTWIND"))
	_chk("RS29-T28 Boss Chapter 4 NÃO existe (candidates)", not BossActivityDefinition.exists("BOSS_SALT_SPLIT_WARDEN") and not BossActivityDefinition.exists("BOSS_CARNICEIRO_AREIAS"))
	_chk("RS29-T29 repeatable disponível", mh.golden.is_unlocked("REPEATABLE_SALTWIND"))
	# MissionSelector diz preparação
	router.open_mission("C4_M001")
	_chk("RS29-T30 MissionSelector mostra Chapter 4", router.mission_panel.visible)
	router._hide_big()
	# ── ARANHA MATRIARCA regressão (Ch3 boss ainda funciona com tudo) ──
	_prep(true)
	var rb = mh.start_boss("BOSS_CH3_SPIDER_MATRIARCH", true)
	_chk("RS29-T31 ARANHA MATRIARCA ainda inicia", bool(rb.get("ok", false)))
	for i in range(20): mh.host_process(0.4)
	_chk("RS29-T32 ARANHA MATRIARCA visível (regressão)", mh.mob_actor() != null and mh.mob_actor().mob_id == "BOSS_CH3_SPIDER_MATRIARCH")
	_chk("RS29-T33 boss HP cai (combate)", mh.boss.boss_hp_frac() < 1.0)
	_chk("RS29-T34 ambiente montado no boss spider (grove)", _env() != null)
	mh.stop_boss()
	_chk("RS29-T35 root_matriarch intocado", not BossActivityDefinition.exists("root_matriarch"))
	_chk("RS29-T36 Chapter 3 continua completo (não regride)", mh.golden.is_chapter_complete("CHAPTER_3_SPIDER"))
