extends SceneTree
## A34 — captura de screenshots da cena REAL (idle / hunt / systems) em 1920x1080 p/ avaliação humana (§27).
## NÃO é teste; roda NÃO-headless (precisa render real). Salva PNGs no diretório passado por --shot-dir (ou user://).

var main: Node = null
var _frame := 0
var _step := 0
var _dir := "user://"
var gs; var hh; var sp

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="): _dir = a.substr("--shot-dir=".length())
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _snap(name: String) -> void:
	var img := get_root().get_texture().get_image()
	if img != null:
		var p := _dir.path_join(name)
		img.save_png(p)
		print("[shot] %s (%dx%d)" % [p, img.get_width(), img.get_height()])

func _on_frame() -> void:
	_frame += 1
	# passo a passo com folga de frames p/ o render assentar
	if _step == 0 and _frame >= 5:
		if main.has_method("_enter_game"): main._enter_game()
		gs = root.get_node_or_null("GameState")
		hh = main.get("_hunthost"); sp = main.get("_systempanel")
		_step = 1; _frame = 0
	elif _step == 1 and _frame >= 20:
		_snap("a34_idle.png"); _step = 2; _frame = 0
	elif _step == 2 and _frame >= 3:
		# entra numa caça real (planície) p/ o shot de Hunt
		gs.set_save_path_override("user://a34shot_fixture.json")
		gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.hero_hp_max = 80000; gs.hero_hp = gs.max_hp_total(); gs.stage_highest_global = 20
		hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
		_step = 3; _frame = 0
	elif _step == 3:
		hh.host_process(0.2)
		var ht = main.get("_hud_target")
		if ht != null: ht.refresh()   # roda o refresh da HUD alvo (esconde o session_hud legado) como no jogo real
		if _frame >= 40:
			_snap("a34_hunt.png"); hh.stop(); _step = 4; _frame = 0
	elif _step == 4 and _frame >= 8:
		if sp != null: sp.open_panel()
		_step = 5; _frame = 0
	elif _step == 5 and _frame >= 12:
		_snap("a34_systems.png")
		if FileAccess.file_exists("user://a34shot_fixture.json"): DirAccess.remove_absolute("user://a34shot_fixture.json")
		_step = 6; _frame = 0
	elif _step == 6 and _frame >= 3:
		quit(0)
