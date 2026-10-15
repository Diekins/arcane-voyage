extends SceneTree
## A37 — screenshots reais: OFFLINE (card no boot) · IDLE · HUNT (1920/1366/1600) · SYSTEMS · INVENTORY · BESTIARY.
## NÃO-headless. Reset após o offline p/ focar a HUD.

var main: Node = null
var _frame := 0
var _step := 0
var _dir := "user://"
var gs; var hh; var sp; var ht; var router

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
	gs.reset_save(); gs.set_save_path_override("user://a37shot_fixture.json")
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 8}
	gs.hero_level = 27; gs.hero_gold = 25430; gs.materials = {"Fragmentos": 102}
	gs.hero_hp_max = 88033; gs.hero_hp = gs.max_hp_total(); gs.stage_highest_global = 30

func _r() -> void:
	if ht != null: ht.refresh()

func _on_frame() -> void:
	_frame += 1
	if _step == 0 and _frame >= 5:
		main._enter_game(); gs = root.get_node_or_null("GameState")
		hh = main.get("_hunthost"); sp = main.get("_systempanel"); ht = main.get("_hud_target"); router = main.get("_ui_router")
		_step = 1; _frame = 0
	elif _step == 1 and _frame >= 14:
		_r(); _snap("A37_OFFLINE_1920.png")   # card de retorno-offline (estado do boot)
		_clean(); _step = 2; _frame = 0
	elif _step == 2 and _frame >= 16:
		_r(); _snap("A37_IDLE_1920.png"); _step = 3; _frame = 0
	elif _step == 3 and _frame >= 3:
		hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL"); _step = 4; _frame = 0
	elif _step == 4:
		hh.host_process(0.2); _r()
		if _frame >= 40: _snap("A37_HUNT_1920.png"); _step = 5; _frame = 0
	elif _step == 5 and _frame >= 2:
		DisplayServer.window_set_size(Vector2i(1366, 768)); _step = 6; _frame = 0
	elif _step == 6:
		hh.host_process(0.2); _r()
		if _frame >= 10: _snap("A37_HUNT_1366.png"); _step = 7; _frame = 0
	elif _step == 7 and _frame >= 2:
		DisplayServer.window_set_size(Vector2i(1600, 900)); _step = 8; _frame = 0
	elif _step == 8:
		hh.host_process(0.2); _r()
		if _frame >= 10: _snap("A37_HUNT_1600.png"); _step = 9; _frame = 0
	elif _step == 9 and _frame >= 2:
		DisplayServer.window_set_size(Vector2i(1920, 1080)); hh.stop(); _r(); sp.open_panel(); _step = 10; _frame = 0
	elif _step == 10 and _frame >= 12:
		_snap("A37_SYSTEMS_1920.png"); sp.close_panel(); main.idlehud_open_inventory(); _step = 11; _frame = 0
	elif _step == 11 and _frame >= 12:
		_snap("A37_INVENTORY_1920.png")
		if bool(main.get("_inv_open")) and main.has_method("_toggle_inventory"): main._toggle_inventory()
		if router != null: router.open_bestiary("young_wolf")
		_step = 12; _frame = 0
	elif _step == 12 and _frame >= 12:
		_snap("A37_BESTIARY_1920.png")
		if FileAccess.file_exists("user://a37shot_fixture.json"): DirAccess.remove_absolute("user://a37shot_fixture.json")
		_step = 13; _frame = 0
	elif _step == 13 and _frame >= 3:
		quit(0)
