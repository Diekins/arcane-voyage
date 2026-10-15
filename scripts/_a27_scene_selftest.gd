extends SceneTree
## A27 REALSCENE27 — ARANHA MATRIARCA na Main.tscn REAL. Preboss ready → boss aparece (spider_matriarch visível) →
## combate → vitória → Direct Loot → first-clear → Chapter 3 COMPLETE. + cena de FALHA (build fraca não completa).
## Save protegido por fixture. ⚠️ spider_matriarch (não root_matriarch).

const BID := "BOSS_CH3_SPIDER_MATRIARCH"
var main: Node = null
var _frame := 0
var _phase := 0
var _fail := 0
var gs; var mh; var router: PlayerUiRouter; var res: AcquisitionResolver; var ctl: AcquisitionController
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
		gs.set_save_path_override("user://a27s_fixture.json")
		mh = main.get("_missionhost"); router = main.get("_ui_router"); res = main.get("_acq_resolver"); ctl = main.get("_acq_controller")
		_run()
		if FileAccess.file_exists("user://a27s_fixture.json"): DirAccess.remove_absolute("user://a27s_fixture.json")
		print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
		quit(0 if _fail == 0 else 1)

func _prep(wpn := "sword_eternal", hp := 60000, refine := {"weapon": 10}) -> void:
	gs.character_class = "CLASS_1"; gs.equipment = ({"weapon": wpn} if wpn != "" else {}); gs.slot_refinement = refine.duplicate(true)
	gs.hero_hp_max = hp; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0
	gs.stage_highest_global = 60; gs.materials = {"Fragmentos": 5000}; gs.backpack = []; gs.locked_items.clear()
	gs.tracked_goal = {}; gs.acquisition_intent = {}; gs.tracked_boss = {}
	var f: Array[String] = ["GP_CHAPTER_1_WOLF_COMPLETE", "GP_CHAPTER_2_CRYSTAL_COMPLETE"]
	for i in range(1, 9): f.append("GP_C2_M%03d_COMPLETE" % i)
	for i in range(1, 9): f.append("GP_C3_M%03d_COMPLETE" % i)
	f.append("GP_UNLOCK_CHAPTER_3_PREBOSS_READY"); gs.story_flags = f

func _drive_to_victory(maxc := 8000) -> void:
	var c := 0
	while mh.boss != null and mh.boss.boss() != null and not gs.is_hero_defeated() and c < maxc:
		mh.host_process(0.4)
		# auto-poção por-limiar (AutoConsumables real roda no _process; aqui simulamos p/ o loop manual)
		if int(gs.hero_hp) < int(gs.max_hp_total() * 0.4): gs.heal_hero(int(gs.max_hp_total() * 0.35))
		c += 1

func _run() -> void:
	print("  ── A27 REALSCENE (Main.tscn) ──")
	_prep()
	var pl: Node2D = main.get("_player")
	_chk("RS27-T01 Main boot + preboss ready", mh.golden.chapter3_preboss_ready())
	_chk("RS27-T02 Chapter 3 NÃO complete antes", not mh.golden.is_chapter_complete("CHAPTER_3_SPIDER"))
	# item → COMO OBTER → boss source AVAILABLE → ENFRENTAR (Acquisition real)
	res.setup(gs)
	var dec := res.resolve("sword_reinforced")
	var card := dec.filter(func(s): return str(s.get("nav_boss", "")) == BID)
	_chk("RS27-T03 boss source ARANHA MATRIARCA", card.size() > 0)
	_chk("RS27-T04 AVAILABLE (preboss)", card.size() > 0 and bool(card[0]["available"]))
	# abre o boss via router (fecha menus, fluxo real)
	router.open_boss(BID)
	for i in range(20): mh.host_process(0.4)
	_chk("RS27-T05 boss iniciou (missionhost.boss)", mh.boss != null and mh.boss.boss() != null)
	_chk("RS27-T06 teleport (player no anchor)", pl.position == mh._anchor)
	_chk("RS27-T07 movement lock", pl.locked)
	_chk("RS27-T08 ambiente/player visível", pl.is_visible_in_tree())
	_chk("RS27-T09 ARANHA MATRIARCA ATOR visível", mh.mob_actor() != null and mh.mob_actor().is_visible_in_tree())
	_chk("RS27-T10 sprite real (mob_id do boss, não fallback)", mh.mob_actor() != null and mh.mob_actor().mob_id == BID and not mh.mob_actor().used_fallback)
	_chk("RS27-T11 boss HP cai (combate bidirecional)", mh.boss.boss_hp_frac() < 1.0)
	_chk("RS27-T12 player travado + visível", pl.locked and pl.is_visible_in_tree())
	# telegraphs/venom
	var teleg := {}
	mh.boss.telegraph.connect(func(k): teleg[k] = int(teleg.get(k, 0)) + 1)
	var phases := {}; mh.boss.phase_changed.connect(func(p): phases[p] = true)
	var xp0 := int(gs.hero_xp); var gold0 := int(gs.hero_gold)
	_drive_to_victory(8000)
	_chk("RS27-T13 VITÓRIA (boss morto)", mh.boss != null and mh.boss.boss() == null and not gs.is_hero_defeated())
	_chk("RS27-T14 HEAVY telegraphed disparou", int(teleg.get("HEAVY_LUNGE", 0)) > 0)
	_chk("RS27-T15 SPIDER ability VENOM disparou", int(teleg.get("VENOM", 0)) > 0)
	_chk("RS27-T16 Phase 2 (enrage) alcançada", bool(phases.get("P2", false)))
	_chk("RS27-T17 Direct Loot XP (wallet)", int(gs.hero_xp) > xp0)
	_chk("RS27-T18 Direct Loot Gold (wallet)", int(gs.hero_gold) > gold0)
	_chk("RS27-T19 first-clear item concedido", str(mh.last_boss_summary.get("first_clear_item", "")) != "")
	_chk("RS27-T20 first-clear PROTEGIDO (locked)", (func(): var it := str(mh.last_boss_summary.get("first_clear_item", "")); return it == "" or gs.is_item_locked(it)).call())
	_chk("RS27-T21 first-clear item no backpack (Direct Loot)", gs.backpack_count(str(mh.last_boss_summary.get("first_clear_item", "x"))) >= 1)
	_chk("RS27-T22 CHAPTER 3 COMPLETE (GP_CHAPTER_3_SPIDER_COMPLETE)", gs.is_story_flag("GP_CHAPTER_3_SPIDER_COMPLETE"))
	_chk("RS27-T23 is_chapter_complete(CHAPTER_3_SPIDER)", mh.golden.is_chapter_complete("CHAPTER_3_SPIDER"))
	_chk("RS27-T24 summary chapter_complete", bool(mh.last_boss_summary.get("chapter_complete", false)))
	mh.stop_boss()
	# reload preserva
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d)
	_chk("RS27-T25 reload preserva Chapter 3 complete", gs.is_story_flag("GP_CHAPTER_3_SPIDER_COMPLETE"))
	# ═══ FALHA: build fraca ═══
	_prep("", 4000, {})
	router.open_boss(BID)
	var c := 0
	while mh.boss != null and not gs.is_hero_defeated() and c < 600: mh.host_process(1.0); c += 1
	_chk("RS27-T26 build fraca MORRE", gs.is_hero_defeated())
	_chk("RS27-T27 derrota = boss_failed", mh.boss_failed)
	_chk("RS27-T28 derrota: Chapter 3 continua PRE-BOSS (não complete p/ este char)", not mh.golden.is_chapter_complete("CHAPTER_3_SPIDER"))
	_chk("RS27-T29 derrota: sem first-clear novo", not mh.golden.boss_first_cleared(BID))
	_chk("RS27-T30 boss retryable (nova run)", bool(mh.retry_boss().get("ok", false)))
	mh.stop_boss()
	# AUTO OFF pausa
	_prep()
	mh.start_boss(BID, true)
	for i in range(6): mh.host_process(0.4)
	var hpA := int(gs.hero_hp); var bfA: float = mh.boss.boss_hp_frac()
	mh.set_auto(false)
	for i in range(10): mh.host_process(0.4)
	_chk("RS27-T31 AUTO OFF pausa (HP e boss HP estáveis)", int(gs.hero_hp) == hpA and is_equal_approx(mh.boss.boss_hp_frac(), bfA))
	_chk("RS27-T32 AUTO OFF mantém lock", pl.locked)
	mh.stop_boss()
	# root_matriarch intocado
	_chk("RS27-T33 root_matriarch NÃO virou boss (escopo)", not BossActivityDefinition.exists("root_matriarch"))
