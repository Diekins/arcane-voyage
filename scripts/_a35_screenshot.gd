extends SceneTree
## A35 — screenshots reais (HUD alvo): idle/hunt/systems em 1920 + hunt em 1366/1600. NÃO-headless. Reset no idle
## p/ reduzir clutter de retorno-offline (foco na HUD, não no estado).

var main: Node = null
var _frame := 0
var _step := 0
var _dir := "user://"
var gs; var hh; var sp; var ht

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="): _dir = a.substr("--shot-dir=".length())
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	main = load("res://scenes/Main.tscn").instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _snap(name: String) -> void:
	var img := get_root().get_texture().get_image()
	if img != null:
		img.save_png(_dir.path_join(name)); print("[shot] %s (%dx%d)" % [name, img.get_width(), img.get_height()])

func _reset_clean() -> void:
	gs.reset_save(); gs.set_save_path_override("user://a35shot_fixture.json")
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 8}
	gs.hero_level = 27; gs.hero_gold = 25430; gs.materials = {"Fragmentos": 102}
	gs.hero_hp_max = 88033; gs.hero_hp = gs.max_hp_total(); gs.stage_highest_global = 30

func _hunt() -> void:
	if ht != null: ht.refresh()

func _on_frame() -> void:
	_frame += 1
	if _step == 0 and _frame >= 5:
		main._enter_game(); gs = root.get_node_or_null("GameState")
		hh = main.get("_hunthost"); sp = main.get("_systempanel"); ht = main.get("_hud_target")
		_reset_clean(); _step = 1; _frame = 0
	elif _step == 1 and _frame >= 20:
		_hunt(); _snap("A35_IDLE_1920.png"); _step = 2; _frame = 0
	elif _step == 2 and _frame >= 3:
		hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL"); _step = 3; _frame = 0
	elif _step == 3:
		hh.host_process(0.2); _hunt()
		if _frame >= 45: _snap("A35_HUNT_1920.png"); _step = 4; _frame = 0
	elif _step == 4 and _frame >= 3:
		DisplayServer.window_set_size(Vector2i(1366, 768)); _step = 5; _frame = 0
	elif _step == 5:
		hh.host_process(0.2); _hunt()
		if _frame >= 12: _snap("A35_HUNT_1366.png"); _step = 6; _frame = 0
	elif _step == 6 and _frame >= 3:
		DisplayServer.window_set_size(Vector2i(1600, 900)); _step = 7; _frame = 0
	elif _step == 7:
		hh.host_process(0.2); _hunt()
		if _frame >= 12: _snap("A35_HUNT_1600.png"); _step = 8; _frame = 0
	elif _step == 8 and _frame >= 3:
		DisplayServer.window_set_size(Vector2i(1920, 1080)); hh.stop(); _hunt(); sp.open_panel(); _step = 9; _frame = 0
	elif _step == 9 and _frame >= 12:
		_snap("A35_SYSTEMS_1920.png")
		if FileAccess.file_exists("user://a35shot_fixture.json"): DirAccess.remove_absolute("user://a35shot_fixture.json")
		_step = 10; _frame = 0
	elif _step == 10 and _frame >= 3:
		quit(0)
