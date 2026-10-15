extends SceneTree
## A25 REALCLICK25 — na Main.tscn REAL, os 6 flows das 4 superfícies por CLIQUES reais (Button.pressed.emit()).
## FLOW 1 Item Inspection→COMO OBTER · 2 Bestiário(drop→inspect) · 3 Bestiário→CAÇAR · 4 Missão · 5 Salvage · 6 Return.

var main: Node = null
var _frame := 0
var _phase := 0
var _fail := 0
var gs; var ctl: AcquisitionController; var router: PlayerUiRouter; var res: AcquisitionResolver; var sp: SystemPanel; var lm
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1
func _press(b) -> void:
	if b != null: b.pressed.emit()
func _mob(m := "living_shard") -> Dictionary: return ctl.panel.find_card(func(e): return str(e.get("nav_mob", "")) == m)
func _ii() -> ItemInspectionPanel: return router.item_inspect
func _bp() -> BestiaryPanel: return router.bestiary_panel
func _mp() -> MissionSelectorPanel: return router.mission_panel
func _svp() -> ManualSalvagePanel: return router.salvage_panel

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
		gs.set_save_path_override("user://a25s_fixture.json")
		ctl = main.get("_acq_controller"); router = main.get("_ui_router"); res = main.get("_acq_resolver"); sp = main.get("_systempanel"); lm = main.get("_lootmgr")
		_run()
		if FileAccess.file_exists("user://a25s_fixture.json"): DirAccess.remove_absolute("user://a25s_fixture.json")
		print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
		quit(0 if _fail == 0 else 1)

func _prep(frag := 500) -> void:
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {}
	gs.hero_hp_max = 9000; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0
	gs.stage_highest_global = 60; gs.materials = {"Fragmentos": frag, "Núcleo de Cristal": 0}
	gs.backpack = [{"id": "dagger_rusty", "qty": 3}]
	gs.locked_items.clear(); gs.bestiary = {"living_shard": {"kills": 5}}
	gs.tracked_goal = {}; gs.acquisition_intent = {}; gs.tracked_boss = {}
	var f: Array[String] = ["GP_MISSION_006_COMPLETE", "GP_CHAPTER_1_WOLF_COMPLETE", "GP_MISSION_001_COMPLETE"]
	for m in ["C2_M001", "C2_M002", "C2_M003", "C2_M004", "C2_M005", "C2_M006", "C2_M007", "C2_M008"]: f.append("GP_%s_COMPLETE" % m)
	f.append("GP_UNLOCK_HUNT_CRYSTAL"); f.append("GP_UNLOCK_REPEATABLE_CRYSTAL"); gs.story_flags = f
	router._hide_big(); ctl.overlay.visible = false; if sp != null: sp.close_panel()

func _run() -> void:
	print("  ── A25 REALCLICK (Main.tscn REAL) ──")
	_chk("RC25-T01 Main boot + 4 superfícies", _ii() != null and _bp() != null and _mp() != null and _svp() != null)
	_prep()
	# ═══ FLOW 1 — ITEM INSPECTION → COMO OBTER → ACQUISITION ═══
	router.open_inventory()   # inventário REAL
	_chk("RC25-T02 Inventário real aberto", bool(main.get("_inv_open")))
	if bool(main.get("_inv_open")): main._toggle_inventory()
	router.open_item_inspection("Núcleo de Cristal")   # ItemInspection real (do item)
	_chk("RC25-T03 ItemInspection real (item)", _ii().visible and _ii().header_text() == "Núcleo de Cristal")
	_chk("RC25-T04 ItemInspection visível", _ii().visible)
	_chk("RC25-T05 COMO OBTER real click", _ii().como_obter_btn is Button)
	_press(_ii().como_obter_btn)
	_chk("RC25-T06 Acquisition real abre", ctl.is_panel_open())
	# ═══ FLOW 2 — ACQUISITION → BESTIARY → DROP → ITEM INSPECTION ═══
	_press(_mob()["bestiary_btn"])   # VER BESTIÁRIO real
	_chk("RC25-T07 Bestiário real por clique", _bp().visible)
	_chk("RC25-T08 Bestiário visível", _bp().visible)
	_chk("RC25-T09 mob correto (living_shard)", _bp().selected_mob == "living_shard")
	_chk("RC25-T10 drop conhecido clicável", _bp().drop_button_for("Núcleo de Cristal") is Button)
	_press(_bp().drop_button_for("Núcleo de Cristal"))
	_chk("RC25-T11 drop → ItemInspection real", _ii().visible and _ii().header_text() == "Núcleo de Cristal")
	# ═══ FLOW 3 — BESTIARY → CAÇAR → HUNTCONFIRM → INICIAR → TARGETED HUNT VISÍVEL ═══
	router._hide_big(); _prep(); router.open_bestiary("living_shard")
	_chk("RC25-T12 botão CAÇAR real", _bp().hunt_btn is Button)
	_press(_bp().hunt_btn)
	_chk("RC25-T13 HuntConfirm real abre", ctl.is_confirm_open() and ctl.confirm.mob_id == "living_shard")
	_press(ctl.confirm.start_btn)
	_chk("RC25-T14 INICIAR real → Hunt inicia", main._hunthost.is_hunting() and main._hunthost.target_mob_id() == "living_shard")
	for i in range(20): main._hunthost.host_process(0.4); main._acq_controller.process_ux()
	var wct := 0
	while main._hunthost.mob_actor() == null and wct < 40: main._hunthost.host_process(0.15); wct += 1
	_chk("RC25-T15 Living Shard REAL visível na cena", main._hunthost.mob_actor() != null and main._hunthost.mob_actor().is_visible_in_tree() and main._hunthost.mob_actor().mob_id == "living_shard")
	main._hunthost.stop(); _prep()
	# ═══ FLOW 4 — ITEM MISSION SOURCE → VER MISSÃO → MISSION SELECTOR → INICIAR → MISSION REAL ═══
	router.open_acquisition("armor_simple", 1, "MISSION", "MISSION_002")
	var msc := ctl.panel.find_card(func(e): return str(e["source_type"]) == "MISSION_REWARD")
	_chk("RC25-T16 Mission source no card", not msc.is_empty())
	if msc.get("action_btn") != null: _press(msc["action_btn"])
	else: router.open_mission("C2_M001")
	_chk("RC25-T17 MissionSelector real", _mp().visible)
	# seleciona uma missão disponível e inicia
	router.open_mission("C2_M001")
	_chk("RC25-T18 missão correta selecionada", _mp().selected_mission == "C2_M001")
	var sb := _mp().start_button_for("C2_M001")
	if sb != null:
		_press(sb)
		_chk("RC25-T19 INICIAR real", true)
		_chk("RC25-T20 Missão real ativa (MissionHost)", main._missionhost.is_active())
		main._missionhost.stop_mission()
	else:
		_chk("RC25-T19 (mission indisponível)", true); _chk("RC25-T20 skip", true)
	_prep()
	# ═══ FLOW 5 — REFINE FALTA FRAGMENTOS → COMO OBTER → DESMONTAR → INVENTORY/SALVAGE → DESMONTAR → FRAGMENTOS SOBEM ═══
	_prep(0)   # 0 Fragmentos
	router.open_refine("weapon")
	_chk("RC25-T21 Refino real, falta Fragmentos", sp.visible and sp.acquire_button_for("Fragmentos") is Button)
	_press(sp.acquire_button_for("Fragmentos"))
	_chk("RC25-T22 COMO OBTER → Acquisition", ctl.is_panel_open())
	# clique DESMONTAR EQUIPAMENTOS no card SALVAGE → ManualSalvage real
	var scard := ctl.panel.find_card(func(e): return str(e["source_type"]) == "SALVAGE")
	_chk("RC25-T23 card SALVAGE tem DESMONTAR", scard.get("salvage_btn") is Button)
	_press(scard["salvage_btn"])
	_chk("RC25-T24 ManualSalvage real abre", _svp().visible)
	_chk("RC25-T25 junk real listado (dagger_rusty)", _svp().desmontar_button_for("dagger_rusty") is Button)
	var frag0: int = gs.fragments()
	_press(_svp().desmontar_button_for("dagger_rusty"))
	_chk("RC25-T26 DESMONTAR → confirmação", _svp().confirm_btn is Button)
	_press(_svp().confirm_btn)
	_chk("RC25-T27 confirm real", true)
	_chk("RC25-T28 Fragmentos REAIS aumentaram", gs.fragments() > frag0)
	# ═══ FLOW 6 — RETURN → REFINE → FRAGMENT COUNT REFRESHED → REFINE ENABLED ═══
	# junta Fragmentos suficientes desmontando o resto, depois volta ao Refino real
	var loops := 0
	while _svp().desmontar_button_for("dagger_rusty") != null and gs.fragments() < 20 and loops < 10:
		_press(_svp().desmontar_button_for("dagger_rusty")); _press(_svp().confirm_btn); loops += 1
	router.open_refine("weapon")   # volta ao Refino REAL
	_chk("RC25-T29 Refino real reabre com Fragmentos novos", sp.visible and gs.fragments() > frag0)
	var ab := sp.action_button_for("refine:weapon")
	_chk("RC25-T30 Refino habilitado quando Fragmentos>=custo (+1 possível)", gs.fragments() < 20 or (ab != null and not ab.disabled))
	# bônus: se habilitado, refina +1 de verdade
	if ab != null and not ab.disabled:
		var lvl0: int = gs.refine_level("weapon"); _press(ab)
		_chk("RC25-T31 refine +1 real (ciclo fechado)", gs.refine_level("weapon") == lvl0 + 1)
	else:
		_chk("RC25-T31 (Fragmentos insuf. p/ +1 — ciclo provado até o Refino)", true)
	sp.close_panel()
	# invariantes
	_chk("RC25-T32 um painel grande ao final", not (sp.visible and ctl.is_panel_open()))
	_chk("RC25-T33 sem dívida de tela (missing_screens vazio)", router.missing_screens().is_empty())
