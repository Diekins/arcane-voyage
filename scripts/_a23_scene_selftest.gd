extends SceneTree
## A23 REALCLICK23 — prova CLIQUE REAL → AÇÃO na CENA REAL (Main.tscn). 5 flows: Refine→Salvage, Item→TargetHunt,
## Goal complete, Return, Item→Boss. Botões disparados por Button.pressed.emit() (não chamadas diretas). Frames de verdade.

var main: Node = null
var _frame := 0
var _phase := 0
var _fail := 0
var ctl: AcquisitionController = null
var _returned := {"sys": "", "ctx": "", "n": 0}
var _inv := {"n": 0}
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1
func _press(b) -> void:
	if b != null: b.pressed.emit()

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
		_run()
		print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
		quit(0 if _fail == 0 else 1)

func _prep(gs) -> void:
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {}
	gs.hero_hp_max = 9000; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0
	gs.stage_highest_global = 60; gs.materials = {"Fragmentos": 5000, "Núcleo de Cristal": 0}
	gs.backpack = [{"id": "dagger_rusty", "qty": 1}]
	gs.tracked_goal = {}; gs.acquisition_intent = {}; gs.tracked_boss = {}
	var f: Array[String] = ["GP_MISSION_006_COMPLETE"]
	for m in ["C2_M001", "C2_M002", "C2_M003", "C2_M004", "C2_M005", "C2_M006", "C2_M007", "C2_M008"]: f.append("GP_%s_COMPLETE" % m)
	f.append("GP_UNLOCK_HUNT_CRYSTAL"); f.append("GP_UNLOCK_REPEATABLE_CRYSTAL"); gs.story_flags = f

func _mob_card(mob := "living_shard") -> Dictionary:
	return ctl.panel.find_card(func(e): return str(e.get("nav_mob", "")) == mob)
func _boss_card(boss := "BOSS_CRYSTAL_GOLEM") -> Dictionary:
	return ctl.panel.find_card(func(e): return str(e.get("nav_boss", "")) == boss)

func _run() -> void:
	print("  ── A23 REALCLICK (Main.tscn) ──")
	var mh = main.get("_missionhost"); var hh = main.get("_hunthost")
	var gs = root.get_node_or_null("GameState"); var pl: Node2D = main.get("_player")
	_prep(gs)
	var ui_root := Control.new(); main.add_child(ui_root)
	ctl = AcquisitionController.new(); main.add_child(ctl)
	var res := AcquisitionResolver.new(); res.setup(gs)
	ctl.setup(hh, res, ui_root, "desktop")
	ctl.return_to_origin.connect(func(s, x): _returned["sys"] = s; _returned["ctx"] = x; _returned["n"] += 1)
	ctl.inventory_requested.connect(func(): _inv["n"] += 1)
	ctl.boss_fight_requested.connect(func(bid): mh.start_boss(bid, true))
	# liga o resolver ao HUD de sessão (render do objetivo)
	if hh.session_hud != null: hh.session_hud.set_acquisition_resolver(res)
	_chk("A23RS-T01 Main boot + controller montado", ctl.panel != null)

	# ═══ FLOW 1 — REFINE precisa Fragmentos → SALVAGE ═══
	ctl.open_for_item("Fragmentos", 40, "REFINE", "armor")
	_chk("A23RS-T02 AcquisitionPanel abre (Fragmentos)", ctl.is_panel_open())
	var sc := ctl.panel.find_card(func(e): return str(e["source_type"]) == "SALVAGE")
	_chk("A23RS-T03 card SALVAGE presente (não mob)", not sc.is_empty())
	_press(sc["action_btn"])
	_chk("A23RS-T04 clique ABRIR INVENTÁRIO → inventory_requested", _inv["n"] == 1)
	ctl.close_panel()

	# ═══ FLOW 2 — Núcleo de Cristal → Targeted Hunt ═══
	ctl.open_for_item("Núcleo de Cristal", 2, "REFINE", "weapon")
	_chk("A23RS-T05 painel Núcleo + card mob", not _mob_card().is_empty())
	_press(_mob_card()["action_btn"])
	_chk("A23RS-T06 clique CAÇAR → confirmação", ctl.is_confirm_open() and not ctl.is_panel_open())
	_press(ctl.confirm.start_btn)
	_chk("A23RS-T07 clique INICIAR → Hunt inicia", hh.is_hunting() and hh.target_mob_id() == "living_shard")
	_chk("A23RS-T08 teleport (player no anchor)", pl.position == hh._anchor)
	for i in range(20): hh.host_process(0.4); ctl.process_ux()
	var wct := 0
	while hh.mob_actor() == null and wct < 40: hh.host_process(0.15); ctl.process_ux(); wct += 1
	_chk("A23RS-T09 player visível (cena)", pl.is_visible_in_tree())
	_chk("A23RS-T10 living_shard VISÍVEL (sprite real, só ele)", hh.mob_actor() != null and hh.mob_actor().is_visible_in_tree() and hh.mob_actor().mob_id == "living_shard" and not hh.mob_actor().used_fallback)
	var rt = hh.get("_runtime")
	_chk("A23RS-T11 combate bidirecional", int(rt.runtime_stats["damage_dealt"]) > 0 and int(rt.runtime_stats["damage_taken"]) > 0)
	# goal HUD renderiza
	if hh.session_hud != null: hh.session_hud.refresh()
	_chk("A23RS-T12 goal HUD mostra objetivo", hh.session_hud == null or hh.session_hud.goal_text().contains("Núcleo de Cristal"))

	# ═══ FLOW 3 — GOAL COMPLETE ═══
	var g := 0
	while not ctl.is_overlay_visible() and g < 3000: hh.host_process(0.3); ctl.process_ux(); g += 1
	_chk("A23RS-T13 Direct Loot subiu o contador", res.goal_progress()["have"] >= 2)
	_chk("A23RS-T14 overlay OBJETIVO CONCLUÍDO visível", ctl.is_overlay_visible())
	_chk("A23RS-T15 Hunt continua atrás do overlay", hh.is_hunting())
	_press(ctl.overlay.continue_btn)
	_chk("A23RS-T16 clique CONTINUAR → overlay some", not ctl.is_overlay_visible())
	_chk("A23RS-T17 Hunt SEGUE após CONTINUAR", hh.is_hunting())

	# ═══ FLOW 4 — RETURN ═══
	ctl.overlay.show_for("Núcleo de Cristal", res.goal_progress()["have"], 2, "VOLTAR AO REFINE")
	_press(ctl.overlay.return_btn)
	_chk("A23RS-T18 clique VOLTAR → Hunt para limpo", not hh.is_hunting() and hh.mob_actor() == null)
	_chk("A23RS-T19 return_to_origin REFINE/weapon", _returned["n"] == 1 and str(_returned["sys"]) == "REFINE" and str(_returned["ctx"]) == "weapon")

	# ═══ FLOW 5 — ITEM → BOSS ═══
	_prep(gs)
	ctl.open_for_item("sword_reinforced", 1, "REFINE", "weapon")
	var bc := _boss_card()
	_chk("A23RS-T20 Boss card (Golem)", not bc.is_empty())
	_chk("A23RS-T21 status AVAILABLE → ENFRENTAR", str(bc["action_btn"].text) == "ENFRENTAR")
	_press(bc["action_btn"])
	for i in range(20): mh.host_process(0.4)
	_chk("A23RS-T22 clique ENFRENTAR → boss inicia", mh.boss != null and mh.boss.boss() != null)
	_chk("A23RS-T23 Golem VISÍVEL (sprite real)", mh.mob_actor() != null and mh.mob_actor().is_visible_in_tree() and mh.mob_actor().mob_id == "BOSS_CRYSTAL_GOLEM")
	_chk("A23RS-T24 boss HP cai (combate)", mh.boss.boss_hp_frac() < 1.0)
	_chk("A23RS-T25 sem colisão de UI (um painel grande)", ctl.one_large_panel())
	mh.stop_boss()
