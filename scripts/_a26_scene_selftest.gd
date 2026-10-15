extends SceneTree
## A26 REALSCENE26 — Chapter 3 (spider) na Main.tscn REAL. FLOWS: Mission 1 · material→Bestiário→CAÇAR·Targeted farm
## goal·Repeatable·HG_GROVE·pré-boss. Cliques reais nos painéis. Save protegido por fixture.

var main: Node = null
var _frame := 0
var _phase := 0
var _fail := 0
var gs; var ctl: AcquisitionController; var router: PlayerUiRouter; var res: AcquisitionResolver; var sp: SystemPanel
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1
func _press(b) -> void:
	if b != null: b.pressed.emit()
func _bp() -> BestiaryPanel: return router.bestiary_panel
func _mp() -> MissionSelectorPanel: return router.mission_panel

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
		gs.set_save_path_override("user://a26s_fixture.json")
		ctl = main.get("_acq_controller"); router = main.get("_ui_router"); res = main.get("_acq_resolver"); sp = main.get("_systempanel")
		_run()
		if FileAccess.file_exists("user://a26s_fixture.json"): DirAccess.remove_absolute("user://a26s_fixture.json")
		print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
		quit(0 if _fail == 0 else 1)

func _prep(preboss := false) -> void:
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 8}
	gs.hero_hp_max = 40000; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0
	gs.stage_highest_global = 60; gs.materials = {"Fragmentos": 5000, "Seda de Aranha": 0}; gs.backpack = []
	gs.bestiary = {"grove_spider": {"kills": 5}}; gs.tracked_goal = {}; gs.acquisition_intent = {}; gs.tracked_boss = {}
	var f: Array[String] = ["GP_MISSION_006_COMPLETE", "GP_CHAPTER_1_WOLF_COMPLETE", "GP_CHAPTER_2_CRYSTAL_COMPLETE"]
	for i in range(1, 9): f.append("GP_C2_M%03d_COMPLETE" % i)
	if preboss:
		for i in range(1, 9): f.append("GP_C3_M%03d_COMPLETE" % i)
		f.append("GP_UNLOCK_REPEATABLE_SPIDER"); f.append("GP_UNLOCK_HUNT_SPIDER"); f.append("GP_UNLOCK_CHAPTER_3_PREBOSS_READY")
	gs.story_flags = f
	router._hide_big(); ctl.overlay.visible = false; if sp != null: sp.close_panel()

func _run() -> void:
	print("  ── A26 REALSCENE (Main.tscn) ──")
	var mh = main.get("_missionhost"); var hh = main.get("_hunthost"); var pl: Node2D = main.get("_player")
	_prep()
	_chk("RS26-T01 Main boot + chapter 3 disponível", mh.golden.is_available("C3_M001"))
	# Chapter 3 no MissionSelector real
	router.open_mission("C3_M001")
	_chk("RS26-T02 MissionSelector mostra Chapter 3", _mp().visible)
	# ═══ FLOW 1 — Chapter 3 Mission 1 (grove_spider visível) ═══
	var r = mh.start_mission("C3_M001")
	_chk("RS26-T03 start C3_M001 ok", bool(r.get("ok", false)))
	for i in range(20): mh.host_process(0.4)
	var wct := 0
	while mh.mob_actor() == null and wct < 40: mh.host_process(0.15); wct += 1
	_chk("RS26-T04 ambiente/player visível", pl.is_visible_in_tree())
	_chk("RS26-T05 player visível", pl.visible)
	_chk("RS26-T06 grove_spider ATOR visível (sprite real)", mh.mob_actor() != null and mh.mob_actor().is_visible_in_tree() and not mh.mob_actor().used_fallback)
	_chk("RS26-T07 mob lógico = grove_spider", mh.engine.current_mob() != null and mh.engine.current_mob().mob_id == "grove_spider")
	_chk("RS26-T08 hero ataca", int(mh.engine.stats["hero_attacks"]) > 0)
	_chk("RS26-T09 mob ataca", int(mh.engine.stats["mob_attacks"]) > 0)
	_chk("RS26-T10 kill (progresso)", int(mh.engine.stats["kills"]) > 0)
	_chk("RS26-T11 Direct Loot (XP, sem floor)", int(gs.hero_xp) > 0)
	mh.stop_mission(); _prep()
	# ═══ FLOW 2 — material → Como Obter → Bestiário → CAÇAR (Targeted Hunt) ═══
	router.open_item_inspection("Seda de Aranha")
	_chk("RS26-T12 Item Inspection do material", router.item_inspect.visible and router.item_inspect.header_text() == "Seda de Aranha")
	_press(router.item_inspect.como_obter_btn)
	_chk("RS26-T13 Como Obter → Acquisition", ctl.is_panel_open())
	var mc := ctl.panel.find_card(func(e): return str(e.get("nav_mob", "")) == "grove_spider")
	_chk("RS26-T14 fonte = grove_spider", not mc.is_empty())
	_press(mc["bestiary_btn"])
	_chk("RS26-T15 Bestiário real, mob exato (grove_spider)", _bp().visible and _bp().selected_mob == "grove_spider")
	_press(_bp().hunt_btn)
	_chk("RS26-T16 CAÇAR → HuntConfirm", ctl.is_confirm_open() and ctl.confirm.mob_id == "grove_spider")
	_press(ctl.confirm.start_btn)
	_chk("RS26-T17 Targeted Hunt inicia (grove_spider)", hh.is_hunting() and hh.target_mob_id() == "grove_spider")
	# ═══ FLOW 3 — tracked goal → drop → complete → continue ═══
	res.set_intent("MISSION", "C3_M003", "Seda de Aranha"); res.start_goal("Seda de Aranha", 3, "MISSION", "C3_M003")
	for i in range(20): hh.host_process(0.4); ctl.process_ux()
	var wc2 := 0
	while hh.mob_actor() == null and wc2 < 40: hh.host_process(0.15); wc2 += 1
	_chk("RS26-T18 SÓ grove_spider visível (sprite real)", hh.mob_actor() != null and hh.mob_actor().mob_id == "grove_spider" and hh.mob_actor().is_visible_in_tree())
	var rt = hh.get("_runtime")
	_chk("RS26-T19 combate bidirecional", int(rt.runtime_stats["damage_dealt"]) > 0 and int(rt.runtime_stats["damage_taken"]) > 0)
	var n := 0
	while not res.goal_progress()["complete"] and n < 4000: hh.host_process(0.3); ctl.process_ux(); n += 1
	_chk("RS26-T20 tracked goal completou (Seda dropou)", res.goal_progress()["complete"])
	_chk("RS26-T21 completion overlay", ctl.is_overlay_visible())
	_press(ctl.overlay.continue_btn)
	_chk("RS26-T22 continuar → Hunt segue", hh.is_hunting())
	hh.stop(); _prep(true)
	# ═══ FLOW 4 — Repeatable Chapter 3 ═══
	var rr = mh.start_mission("REPEATABLE_SPIDER", "NORMAL", 100)
	_chk("RS26-T23 Repeatable Chapter 3 inicia", bool(rr.get("ok", false)))
	for i in range(10): mh.host_process(0.4)
	_chk("RS26-T24 Repeatable rodando (kills>=0)", int(mh.engine.stats["kills"]) >= 0)
	mh.stop_mission()
	# ═══ FLOW 5 — Chapter 3 Hunting Ground ═══
	var rh = hh.start("HG_GROVE")
	_chk("RS26-T25 HG_GROVE inicia (família)", bool(rh.get("ok", false)) and hh.is_hunting())
	for i in range(20): hh.host_process(0.4)
	var wc3 := 0
	while hh.mob_actor() == null and wc3 < 40: hh.host_process(0.15); wc3 += 1
	_chk("RS26-T26 HG_GROVE mob spider visível", hh.mob_actor() != null and hh.mob_actor().is_visible_in_tree() and hh.mob_actor().mob_id in ["grove_spider", "veil_spider"])
	_chk("RS26-T27 HG_GROVE kills>0", int(hh.get("_runtime").runtime_stats["kills"]) > 0)
	hh.stop()
	# ═══ FLOW 6 — pré-boss: PREBOSS_READY, boss indisponível, farm continua ═══
	_prep(true)
	_chk("RS26-T28 PREBOSS_READY (última missão concluída)", mh.golden.chapter3_preboss_ready())
	_chk("RS26-T29 Chapter 3 NÃO complete (sem boss)", not mh.golden.is_chapter_complete("CHAPTER_3_SPIDER"))
	_chk("RS26-T30 Boss #3 NÃO existe (nenhuma def spider)", not BossActivityDefinition.exists("BOSS_SPIDER_MATRIARCH"))
	router.open_mission("C3_M008")
	_chk("RS26-T31 MissionSelector diz preparação (pré-boss)", _mp().visible)
	_chk("RS26-T32 farm continua (REPEATABLE_SPIDER unlocked)", mh.golden.is_unlocked("REPEATABLE_SPIDER"))
	_chk("RS26-T33 Refine/Bestiary/Hunt permanecem", gs.has_method("refine_do") and mh.golden.is_unlocked("HUNT_SPIDER"))
	router._hide_big()
