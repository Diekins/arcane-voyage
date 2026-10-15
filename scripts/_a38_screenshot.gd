extends SceneTree
## A38 — screenshots reais (GPU, não-headless) da HUD FIELD CORRECTION V2.
## Estados: NORMAL · HUNT_SELECTOR · HUNT_ACTIVE · SYSTEMS · MISSIONS · INVENTORY · BESTIARY · MASTERY.
## Resoluções: 1920 (todos) + 1600/1366 (NORMAL/HUNT_ACTIVE/SYSTEMS/MISSIONS). Reset+fixture p/ focar a HUD.

var main: Node = null
var _frame := 0
var _step := 0
var _dir := "user://"
var gs; var hh; var sp; var ht; var router; var mh

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="): _dir = a.substr("--shot-dir=".length())
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	main = load("res://scenes/Main.tscn").instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _snap(name: String) -> void:
	var img := get_root().get_texture().get_image()
	if img != null: img.save_png(_dir.path_join(name)); print("[shot] %s (%dx%d)" % [name, img.get_width(), img.get_height()])

func _clean() -> void:
	gs.reset_save(); gs.set_save_path_override("user://a38shot_fixture.json")
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 8}
	gs.hero_level = 27; gs.hero_gold = 25430; gs.materials = {"Fragmentos": 102}
	gs.hero_hp_max = 88033; gs.hero_hp = int(gs.max_hp_total() * 0.72); gs.stage_highest_global = 30

func _r() -> void:
	if ht != null: ht.refresh()

func _close_all() -> void:
	if sp != null and sp.is_open(): sp.close_panel()
	if bool(main.get("_inv_open")) and main.has_method("_toggle_inventory"): main._toggle_inventory()
	if bool(main.get("_mastery_open")) and main.has_method("_toggle_mastery"): main._toggle_mastery()
	if hh != null and hh.get("panel") != null and hh.panel.visible: hh.toggle_panel()
	var best = main.find_child("BestiaryPanel", true, false)
	if best != null: best.visible = false
	_r()

func _on_frame() -> void:
	_frame += 1
	match _step:
		0:
			if _frame >= 6:
				main._enter_game(); gs = root.get_node_or_null("GameState")
				hh = main.get("_hunthost"); sp = main.get("_systempanel"); ht = main.get("_hud_target")
				router = main.get("_ui_router"); mh = main.get("_missionhost")
				_clean(); _step = 1; _frame = 0
		1:
			if _frame >= 16:
				_r(); _snap("A38_NORMAL_1920.png"); hh.toggle_panel(); _step = 2; _frame = 0
		2:
			if _frame >= 10:
				_r(); _snap("A38_HUNT_SELECTOR_1920.png"); _close_all(); _step = 3; _frame = 0
		3:
			if _frame >= 4:
				hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL"); _step = 4; _frame = 0
		4:
			hh.host_process(0.2); _r()
			if _frame >= 40: _snap("A38_HUNT_ACTIVE_1920.png"); hh.stop(); _close_all(); _step = 5; _frame = 0
		5:
			if _frame >= 4:
				sp.open_panel(); _step = 6; _frame = 0
		6:
			if _frame >= 12:
				_r(); _snap("A38_SYSTEMS_1920.png"); sp.close_panel(); _step = 7; _frame = 0
		7:
			if _frame >= 4:
				if mh != null and mh.has_method("_on_entry_pressed"): mh._on_entry_pressed()
				_step = 8; _frame = 0
		8:
			if mh != null and mh.has_method("host_process"): mh.host_process(0.1)
			_r()
			if _frame >= 14:
				_snap("A38_MISSIONS_1920.png")
				if mh != null and mh.is_active(): mh.stop_mission()
				_close_all(); _step = 9; _frame = 0
		9:
			if _frame >= 4:
				main.idlehud_open_inventory(); _step = 10; _frame = 0
		10:
			if _frame >= 12:
				_r(); _snap("A38_INVENTORY_1920.png"); _close_all(); _step = 11; _frame = 0
		11:
			if _frame >= 4:
				if router != null: router.open_bestiary("young_wolf")
				_step = 12; _frame = 0
		12:
			if _frame >= 12:
				_r(); _snap("A38_BESTIARY_1920.png"); _close_all(); _step = 13; _frame = 0
		13:
			if _frame >= 4:
				main.idlehud_open_mastery(); _step = 14; _frame = 0
		14:
			if _frame >= 12:
				_r(); _snap("A38_MASTERY_1920.png"); _close_all(); _step = 15; _frame = 0
		# ── 1600 ──
		15:
			if _frame >= 2:
				DisplayServer.window_set_size(Vector2i(1600, 900)); _step = 16; _frame = 0
		16:
			if _frame >= 8:
				_r(); _snap("A38_NORMAL_1600.png"); hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL"); _step = 17; _frame = 0
		17:
			hh.host_process(0.2); _r()
			if _frame >= 20: _snap("A38_HUNT_ACTIVE_1600.png"); hh.stop(); _close_all(); sp.open_panel(); _step = 18; _frame = 0
		18:
			if _frame >= 10:
				_r(); _snap("A38_SYSTEMS_1600.png"); sp.close_panel()
				if mh != null and mh.has_method("_on_entry_pressed"): mh._on_entry_pressed()
				_step = 19; _frame = 0
		19:
			_r()
			if _frame >= 12:
				_snap("A38_MISSIONS_1600.png")
				if mh != null and mh.is_active(): mh.stop_mission()
				_close_all(); DisplayServer.window_set_size(Vector2i(1366, 768)); _step = 20; _frame = 0
		# ── 1366 ──
		20:
			if _frame >= 8:
				_r(); _snap("A38_NORMAL_1366.png"); hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL"); _step = 21; _frame = 0
		21:
			hh.host_process(0.2); _r()
			if _frame >= 20: _snap("A38_HUNT_ACTIVE_1366.png"); hh.stop(); _close_all(); sp.open_panel(); _step = 22; _frame = 0
		22:
			if _frame >= 10:
				_r(); _snap("A38_SYSTEMS_1366.png"); sp.close_panel()
				if mh != null and mh.has_method("_on_entry_pressed"): mh._on_entry_pressed()
				_step = 23; _frame = 0
		23:
			_r()
			if _frame >= 12:
				_snap("A38_MISSIONS_1366.png")
				if mh != null and mh.is_active(): mh.stop_mission()
				_step = 24; _frame = 0
		24:
			if FileAccess.file_exists("user://a38shot_fixture.json"): DirAccess.remove_absolute("user://a38shot_fixture.json")
			quit(0)
