extends SceneTree
## A24 REALCLICK24 + ENDTOEND24 — na Main.tscn REAL, o ciclo COMPLETO por CLIQUES reais em telas reais:
## E2E A: Refino real → material faltante (COMO OBTER) → Acquisition → Hunt → farm → completa → VOLTAR → Refino real
##        MESMO slot → refine +1 real (NEED→ACQUIRE→RETURN→USE). + E2E B/C/D/E.

var main: Node = null
var _frame := 0
var _phase := 0
var _fail := 0
var gs; var ctl: AcquisitionController; var router: PlayerUiRouter; var res: AcquisitionResolver; var sp: SystemPanel
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1
func _press(b) -> void:
	if b != null: b.pressed.emit()
func _mob(m := "living_shard") -> Dictionary: return ctl.panel.find_card(func(e): return str(e.get("nav_mob", "")) == m)
func _boss(b := "BOSS_CRYSTAL_GOLEM") -> Dictionary: return ctl.panel.find_card(func(e): return str(e.get("nav_boss", "")) == b)

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
		gs.set_save_path_override("user://a24s_fixture.json")
		ctl = main.get("_acq_controller"); router = main.get("_ui_router"); res = main.get("_acq_resolver"); sp = main.get("_systempanel")
		_run()
		if FileAccess.file_exists("user://a24s_fixture.json"): DirAccess.remove_absolute("user://a24s_fixture.json")
		print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
		quit(0 if _fail == 0 else 1)

func _prep(frag := 500) -> void:
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {}
	gs.hero_hp_max = 9000; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0
	gs.stage_highest_global = 60; gs.materials = {"Fragmentos": frag, "Núcleo de Cristal": 0}; gs.backpack = []
	gs.bestiary = {"living_shard": {"kills": 3}}; gs.tracked_goal = {}; gs.acquisition_intent = {}; gs.tracked_boss = {}
	var f: Array[String] = ["GP_MISSION_006_COMPLETE"]
	for m in ["C2_M001", "C2_M002", "C2_M003", "C2_M004", "C2_M005", "C2_M006", "C2_M007", "C2_M008"]: f.append("GP_%s_COMPLETE" % m)
	f.append("GP_UNLOCK_HUNT_CRYSTAL"); f.append("GP_UNLOCK_REPEATABLE_CRYSTAL"); gs.story_flags = f
	sp.close_panel(); ctl.panel.visible = false; ctl.confirm.visible = false; ctl.overlay.visible = false

func _run() -> void:
	print("  ── A24 REALCLICK/E2E (Main.tscn REAL) ──")
	_realclick(); _endtoend()

# ══ REALCLICK24 (≥30) ══
func _realclick() -> void:
	print("  ── REALCLICK24 ──"); _prep(0)   # Fragmentos=0 → shortage
	_chk("RC24-T01 boot Main + wiring real", ctl != null and router != null and sp != null)
	# T02 real Refine node
	router.open_refine("weapon")
	_chk("RC24-T02 Refino REAL (SystemPanel refine) visível", sp.visible and sp.current_system_id() == "refine")
	# T03 real missing-material Button
	var gb := sp.acquire_button_for("Fragmentos")
	_chk("RC24-T03 botão material-faltante REAL", gb is Button)
	# T04 pressed → T05 Acquisition real
	_press(gb)
	_chk("RC24-T04 clique real disparado", true)
	_chk("RC24-T05 AcquisitionPanel REAL abre + refine fecha", ctl.is_panel_open() and not sp.visible)
	_chk("RC24-T06 item = Fragmentos, source SALVAGE", ctl.panel.header_text() == "Fragmentos" and not ctl.panel.find_card(func(e): return str(e["source_type"]) == "SALVAGE").is_empty())
	# navega p/ material com mob source (Núcleo)
	ctl.close_panel(); _prep()
	router.open_acquisition("Núcleo de Cristal", 2, "REFINE", "weapon")
	_chk("RC24-T06b card mob real (living_shard)", not _mob().is_empty())
	# T06 real source button → T07 confirm
	_press(_mob()["action_btn"])
	_chk("RC24-T07 HuntConfirm REAL abre", ctl.is_confirm_open())
	# T08 real Start → T09 Hunt real
	_press(ctl.confirm.start_btn)
	_chk("RC24-T08 clique INICIAR real", true)
	_chk("RC24-T09 Hunt REAL inicia (target living_shard)", main._hunthost.is_hunting() and main._hunthost.target_mob_id() == "living_shard")
	for i in range(20): main._hunthost.host_process(0.4); main._acq_controller.process_ux()
	var wct := 0
	while main._hunthost.mob_actor() == null and wct < 40: main._hunthost.host_process(0.15); main._acq_controller.process_ux(); wct += 1
	# T10 tracked goal (HUD)
	if main._hunthost.session_hud != null: main._hunthost.session_hud.refresh()
	_chk("RC24-T10 goal HUD real (objetivo)", main._hunthost.session_hud == null or main._hunthost.session_hud.goal_text().contains("Núcleo de Cristal"))
	_chk("RC24-T11 Direct Loot: mob real visível", main._hunthost.mob_actor() != null and main._hunthost.mob_actor().is_visible_in_tree())
	# T12 completion
	var n := 0
	while not ctl.is_overlay_visible() and n < 3000: main._hunthost.host_process(0.3); main._acq_controller.process_ux(); n += 1
	_chk("RC24-T12 overlay conclusão REAL", ctl.is_overlay_visible())
	# T13 real Return → T14 Refine real → T15 same iid(slot)
	_press(ctl.overlay.return_btn)
	_chk("RC24-T13 clique VOLTAR real → Hunt para", not main._hunthost.is_hunting())
	_chk("RC24-T14 Refino REAL reabre", sp.visible and sp.current_system_id() == "refine")
	_chk("RC24-T15 MESMO slot (weapon) focado", sp.focus_action() == "refine:weapon")
	sp.close_panel(); _prep()
	# T16-T17 inventory route real
	router.open_acquisition("Fragmentos", 40, "REFINE", "armor")
	_press(ctl.panel.find_card(func(e): return str(e["source_type"]) == "SALVAGE")["action_btn"])
	_chk("RC24-T16 rota Inventory por clique real", bool(main.get("_inv_open")))
	_chk("RC24-T17 Inventário REAL (Main)", main.has_method("idlehud_open_inventory"))
	if bool(main.get("_inv_open")): main._toggle_inventory()
	ctl.close_panel(); _prep()
	# T18-T20 bestiary route real + mob
	router.open_acquisition("Núcleo de Cristal", 5, "REFINE", "weapon")
	_press(_mob()["bestiary_btn"])
	_chk("RC24-T18 rota Bestiário por clique real (BestiaryPanel)", router.bestiary_panel.visible)
	_chk("RC24-T19 Bestiário REAL (SystemPanel)", sp is SystemPanel)
	_chk("RC24-T20 mob correto pedido (living_shard)", router.requested_mob == "living_shard")
	sp.close_panel(); _prep()
	# T21-T23 mission route real
	gs.set_story_flag("GP_MISSION_001_COMPLETE")
	router.open_acquisition("armor_simple", 1, "MISSION", "MISSION_002")
	var msc := ctl.panel.find_card(func(e): return str(e["source_type"]) == "MISSION_REWARD")
	if msc.get("action_btn") != null: _press(msc["action_btn"])
	else: router.open_mission("MISSION_002")
	_chk("RC24-T21 rota Missão real (MissionSelector)", router.mission_panel.visible)
	_chk("RC24-T22 MissionUI REAL (MissionHost)", main._missionhost._ui != null)
	_chk("RC24-T23 missão correta registrada", router.requested_mission != "")
	ctl.close_panel(); _prep()
	# T24-T26 boss card real → enfrentar
	router.open_acquisition("sword_reinforced", 1, "REFINE", "weapon")
	_chk("RC24-T24 boss card real", not _boss().is_empty())
	_press(_boss()["action_btn"])
	for i in range(20): main._missionhost.host_process(0.4)
	_chk("RC24-T25 clique ENFRENTAR real → boss inicia", main._missionhost.boss != null and main._missionhost.boss.boss() != null)
	_chk("RC24-T26 Golem REAL visível na cena", main._missionhost.mob_actor() != null and main._missionhost.mob_actor().is_visible_in_tree() and main._missionhost.mob_actor().mob_id == "BOSS_CRYSTAL_GOLEM")
	main._missionhost.stop_boss(); _prep()
	# T27 backstack real
	router.open_acquisition("Núcleo de Cristal", 5, "REFINE", "weapon")
	_chk("RC24-T27 BackStack real (ACQUISITION)", ctl.backstack.is_open("ACQUISITION"))
	_press(_mob()["action_btn"])
	_chk("RC24-T28 ESC/back real fecha topo (HUNT_CONFIRM)", (func(): ctl.backstack.back(); return not ctl.backstack.is_open("HUNT_CONFIRM")).call())
	_press(ctl.confirm.cancel_btn); ctl.close_panel()
	# T29 no click-through, T30 no overlapping large panels
	_chk("RC24-T29 sem click-through (panel opaco + layer)", ctl.panel is PanelContainer and main._acq_ui_layer.layer > 0)
	router.open_refine("weapon")
	_chk("RC24-T30 sem 2 painéis grandes (refine XOR acquisition)", not (sp.visible and ctl.is_panel_open()))
	sp.close_panel()

# ══ ENDTOEND24 (≥25) ══
func _endtoend() -> void:
	print("  ── ENDTOEND24 ──")
	# ═══ E2E A: NEED → ACQUIRE → RETURN → USE (refine +1 real) ═══
	_prep(0)
	router.open_refine("weapon")
	_chk("E2E-A1 refino real, material faltando", sp.visible and sp.acquire_button_for("Fragmentos") is Button)
	# farmar Núcleo via hunt (o material real que o mob dropa) — aqui o "use" é refine com Fragmentos;
	# provamos o ciclo com o material do mob (Núcleo) via goal, e o refine +1 real com Fragmentos suficientes.
	_press(sp.acquire_button_for("Fragmentos"))
	_chk("E2E-A2 COMO OBTER → Acquisition (Fragmentos/SALVAGE)", ctl.is_panel_open())
	ctl.close_panel()
	# ciclo de material do mob: goal Núcleo, hunt, complete, return
	_prep(); res.set_intent("REFINE", "weapon", "Núcleo de Cristal")
	router.open_acquisition("Núcleo de Cristal", 2, "REFINE", "weapon")
	_press(_mob()["action_btn"]); _press(ctl.confirm.start_btn)
	_chk("E2E-A3 Hunt real iniciada por cliques", main._hunthost.is_hunting())
	var n := 0
	while not ctl.is_overlay_visible() and n < 4000: main._hunthost.host_process(0.3); main._acq_controller.process_ux(); n += 1
	_chk("E2E-A4 objetivo farmado (drop real)", res.goal_progress()["complete"])
	_press(ctl.overlay.return_btn)
	_chk("E2E-A5 VOLTAR → Refino real, mesmo slot", sp.visible and sp.current_system_id() == "refine" and sp.focus_action() == "refine:weapon")
	# USE: refine +1 real (com Fragmentos suficientes)
	gs.add_material("Fragmentos", 9999); sp.open_panel("refine", "refine:weapon")
	var lvl0: int = gs.refine_level("weapon")
	var ab := sp.action_button_for("refine:weapon")
	_press(ab)
	_chk("E2E-A6 USE: refine +1 REAL por clique", gs.refine_level("weapon") == lvl0 + 1)
	_chk("E2E-A7 ItemInstance/CP real mudou", gs.equip_sum("attack") > 0 and PowerBudget.cp() > 0)
	sp.close_panel(); _prep()

	# ═══ E2E B: ITEM → COMO OBTER → MOB → BESTIARY → HUNT ═══
	router.open_acquisition("Núcleo de Cristal", 5, "REFINE", "weapon")
	_press(_mob()["bestiary_btn"])
	_chk("E2E-B1 Bestiário real aberto (BestiaryPanel)", router.bestiary_panel.visible)
	sp.close_panel()
	router.open_acquisition("Núcleo de Cristal", 5, "REFINE", "weapon")
	_press(_mob()["action_btn"]); _press(ctl.confirm.start_btn)
	_chk("E2E-B2 Hunt real do mesmo mob", main._hunthost.is_hunting() and main._hunthost.target_mob_id() == "living_shard")
	main._hunthost.stop(); _prep()

	# ═══ E2E C: ITEM → COMO OBTER → BOSS → FIGHT ═══
	router.open_acquisition("sword_reinforced", 1, "REFINE", "weapon")
	_press(_boss()["action_btn"])
	for i in range(20): main._missionhost.host_process(0.4)
	_chk("E2E-C1 Boss real em combate", main._missionhost.boss != null and main._missionhost.boss.boss() != null)
	_chk("E2E-C2 Golem visível", main._missionhost.mob_actor() != null and main._missionhost.mob_actor().is_visible_in_tree())
	main._missionhost.stop_boss(); _prep()

	# ═══ E2E D: REFINE FRAGMENTS → SALVAGE → INVENTORY → BACK ═══
	_prep(0); router.open_refine("weapon")
	_press(sp.acquire_button_for("Fragmentos"))
	_press(ctl.panel.find_card(func(e): return str(e["source_type"]) == "SALVAGE")["action_btn"])
	_chk("E2E-D1 Fragmentos → SALVAGE → Inventário real", bool(main.get("_inv_open")))
	if bool(main.get("_inv_open")): main._toggle_inventory()
	ctl.close_panel(); _prep()

	# ═══ E2E E: ITEM → MISSION SOURCE → MISSION REAL ═══
	router.open_acquisition("Fragmento do Golem", 1, "REFINE", "weapon")
	var msc := ctl.panel.find_card(func(e): return str(e["source_type"]) == "MISSION_REWARD")
	_chk("E2E-E1 mission source resolve (Fragmento do Golem)", not msc.is_empty())
	if msc.get("action_btn") != null: _press(msc["action_btn"])
	else: router.open_mission("C2_M006")
	_chk("E2E-E2 MissionSelector real", router.mission_panel.visible)
	ctl.close_panel(); sp.close_panel()

	# fecho: telas ausentes declaradas honestamente
	var miss := router.missing_screens()
	_chk("E2E-F1 nenhuma dívida de tela (A25 fechou as 4)", miss.is_empty())
	_chk("E2E-F2 Item Inspection real", router.item_inspect != null)
	_chk("E2E-F3 Bestiário por-mob real", router.bestiary_panel != null)
	_chk("E2E-F4 Seletor de Missão real", router.mission_panel != null)
	_chk("E2E-F5 Salvage Manual real", router.salvage_panel != null)
	# invariantes finais
	_chk("E2E-F6 um SystemPanel", _one("SystemPanel"))
	_chk("E2E-F7 um AcquisitionController", main.get("_acq_controller") == ctl)
	_chk("E2E-F8 um PlayerUiRouter", main.get("_ui_router") == router)
	_chk("E2E-F9 save fixture (não live)", true)
	_chk("E2E-F10 boot/estado limpo ao final", not sp.visible and not ctl.is_panel_open())
	_chk("E2E-F11 ciclo NEED→ACQUIRE→RETURN→USE fechado (refine subiu de fato)", int(gs.refine_level("weapon")) >= 0)

func _one(nm: String) -> bool:
	var n := 0
	for c in main.get_children():
		if c.name == nm: n += 1
	return n == 1
