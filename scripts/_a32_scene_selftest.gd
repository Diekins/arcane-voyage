extends SceneTree
## A32 REALSCENE32 — Boss Bestiary na Main.tscn REAL. Bestiary abre → categoria BOSSES → MoonScar/Crystal Golem/
## ARANHA MATRIARCA como entidades corretas → inspect (status/região/disponibilidade/drops/first-clear) → LUTAR →
## encounter REAL (spider_matriarch, NÃO root_matriarch) → locked/unlocked behavior. Fixture-safe. Usa TestHarness.

var H: TestHarness
var main: Node = null
var _frame := 0
var _phase := 0
var gs; var router: PlayerUiRouter; var mh
const WOLF := "BOSS_WOLF_ALPHA"
const GOLEM := "BOSS_CRYSTAL_GOLEM"
const SPIDER := "BOSS_CH3_SPIDER_MATRIARCH"

func _initialize() -> void:
	H = TestHarness.new()
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate() if ps != null else null
	if main != null: root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _phase == 0 and _frame >= 3:
		_phase = 1
		if main != null and main.has_method("_enter_game"): main._enter_game()
	elif _phase == 1 and _frame >= 9:
		_phase = 2
		_run()
		if FileAccess.file_exists("user://a32s_fixture.json"): DirAccess.remove_absolute("user://a32s_fixture.json")
		var res := H.summarize("A32-SCENE")
		quit(0 if bool(res["ok"]) else 1)

func _golden() -> GoldenPath:
	var g := GoldenPath.new(); g.setup(gs); return g

func _prep() -> void:
	gs.reset_save(); gs.set_save_path_override("user://a32s_fixture.json")
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 10}
	gs.hero_hp_max = 500000; gs.hero_hp = gs.max_hp_total(); gs.stage_highest_global = 60
	# WOLF derrotado; GOLEM e SPIDER disponíveis (unlock)
	var f: Array[String] = ["GP_MISSION_006_COMPLETE", "GP_C2_M008_COMPLETE", "GP_C3_M008_COMPLETE"]
	gs.story_flags = f
	_golden().mark_boss_cleared(WOLF)

func _run() -> void:
	H.group_begin("REALSCENE32", 30)
	if main == null:
		H.group_error("Main.tscn não instanciou"); H.group_complete(); return
	gs = root.get_node_or_null("GameState")
	router = main.get("_ui_router"); mh = main.get("_missionhost")
	if gs == null or router == null or mh == null:
		H.group_error("boot incompleto (gs/router/missionhost null)"); H.group_complete(); return
	gs.set_save_path_override("user://a32s_fixture.json")
	H.check("RS32-01 Main.tscn + gs + router + missionhost", main != null and gs != null and router != null and mh != null)
	_prep()
	var bp: BestiaryPanel = router.bestiary_panel
	H.check("RS32-02 BestiaryPanel existe", bp != null)
	# ── Bestiary abre e troca p/ categoria BOSSES ──
	router.open_bestiary("young_wolf")
	H.check("RS32-03 Bestiary abre (visível)", bp.visible)
	H.check("RS32-04 categoria default MOBS", bp._category == "MOBS")
	bp.cat_bosses_btn.pressed.emit()
	H.check("RS32-05 troca p/ BOSSES em 1 clique", bp._category == "BOSSES")
	# ── as 3 entradas de boss reais ──
	H.check("RS32-06 MoonScar (BOSS_WOLF_ALPHA) na lista", bp.boss_button_for(WOLF) != null)
	H.check("RS32-07 Crystal Golem na lista", bp.boss_button_for(GOLEM) != null)
	H.check("RS32-08 ARANHA MATRIARCA na lista", bp.boss_button_for(SPIDER) != null)
	H.check("RS32-09 root_matriarch NÃO na lista", bp.boss_button_for("root_matriarch") == null)
	# ── inspect MoonScar (DEFEATED) ──
	bp.boss_button_for(WOLF).pressed.emit()
	H.check("RS32-10 MoonScar selecionado", bp.selected_boss == WOLF)
	var eW := BossBestiary.entry(_golden(), WOLF)
	H.check("RS32-11 MoonScar display MOONSCAR", str(eW["display_name"]).contains("MOONSCAR"))
	H.check("RS32-12 MoonScar DEFEATED + first-clear", bool(eW["defeated"]) and bool(eW["first_clear_complete"]))
	H.check("RS32-13 MoonScar LUTAR NOVAMENTE (replayable)", bp.fight_btn != null and str(bp.fight_btn.text).contains("NOVAMENTE"))
	# ── inspect Crystal Golem (DISCOVERED, available) ──
	bp.boss_button_for(GOLEM).pressed.emit()
	var eG := BossBestiary.entry(_golden(), GOLEM)
	H.check("RS32-14 Crystal Golem display", str(eG["display_name"]).contains("GOLEM"))
	H.check("RS32-15 Crystal Golem available", bool(eG["available"]) and bp.fight_btn != null)
	H.check("RS32-16 Golem region = MAP_CAVE", str(eG["region"]) == "MAP_CAVE")
	H.check("RS32-17 Golem drops (guaranteed presente)", (eG["drops"]["guaranteed"] as Array).size() > 0)
	# ── inspect ARANHA MATRIARCA — entidade correta (spider_matriarch, NÃO root_matriarch) ──
	bp.boss_button_for(SPIDER).pressed.emit()
	var eS := BossBestiary.entry(_golden(), SPIDER)
	H.check("RS32-18 ARANHA MATRIARCA display exato", str(eS["display_name"]) == "ARANHA MATRIARCA")
	H.check("RS32-19 visual_id = spider_matriarch (NÃO root_matriarch)", str(eS["visual_id"]) == "spider_matriarch")
	H.check("RS32-20 região = MAP_PLAINS", str(eS["region"]) == "MAP_PLAINS")
	H.check("RS32-21 available (C3_M008 feito) → LUTAR", bool(eS["available"]) and bp.fight_btn != null)
	# ── LUTAR ARANHA MATRIARCA → encounter REAL ──
	bp.fight_btn.pressed.emit()
	for i in range(24): mh.host_process(0.3)
	H.check("RS32-22 encounter iniciou (boss ativo)", mh.is_boss_active())
	var actor = mh.mob_actor()
	H.check("RS32-23 boss visível na cena", actor != null and actor.is_visible_in_tree())
	H.check("RS32-24 é a ARANHA MATRIARCA (mob_id correto)", actor != null and str(actor.mob_id) == SPIDER)
	H.check("RS32-25 sprite real (não fallback)", actor != null and not actor.used_fallback)
	var bdef := BossActivityDefinition.get_boss(SPIDER)
	H.check("RS32-26 visual_key aponta spider_matriarch (não root)", str(bdef.get("visual_key", "")).contains("spider_matriarch") and not str(bdef.get("visual_key", "")).contains("root"))
	# combate real: HP do boss cai
	for i in range(20): mh.host_process(0.3)
	H.check("RS32-27 HP do boss cai (combate real)", mh.boss.boss_hp_frac() < 1.0)
	mh.stop_boss()
	H.check("RS32-28 encounter encerrado (stop)", not mh.is_boss_active())
	# ── locked behavior: boss sem unlock não inicia + feedback ──
	gs.reset_save(); gs.set_save_path_override("user://a32s_fixture.json"); gs.character_class = "CLASS_1"
	var eLocked := BossBestiary.entry(_golden(), SPIDER)
	H.check("RS32-29 sem unlock → LOCKED + reason (C3_M008)", str(eLocked["action"]) == "LOCKED" and str(eLocked["locked_reason"]).contains("C3_M008"))
	var rl: Dictionary = mh.start_boss(SPIDER, true)
	H.check("RS32-30 start_boss recusa boss LOCKED (gate não burlado)", not bool(rl.get("ok", false)) and str(rl.get("reason", "")) == "LOCKED")
	# ── root_matriarch permanece MOB intocado (não virou boss) ──
	H.check("RS32-31 root_matriarch NÃO é boss (intacto)", not BossActivityDefinition.exists("root_matriarch"))
	H.check("RS32-32 discovery(root_matriarch) = UNKNOWN (não boss)", BossBestiary.discovery_state(_golden(), "root_matriarch") == BossBestiary.UNKNOWN)
	# ── performance: listar não instanciou encounter até LUTAR ──
	router.open_boss_bestiary(GOLEM)
	H.check("RS32-33 open_boss_bestiary abre inspeção do boss", bp.visible and bp.selected_boss == GOLEM)
	H.check("RS32-34 listar não deixou boss ativo", not mh.is_boss_active())
	H.group_complete()
