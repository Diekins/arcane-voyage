extends SceneTree
## F5-shot harness (Pack 06) — renderiza cada prop recém-integrado e salva PNG p/ inspeção visual.
## JANELADO (precisa render real). Save-safe (snapshot/restore). NÃO toca GameState/save/sistemas.
## Cada job: constrói a região num host offsetado, move a câmera ao prop, desenha linha-de-chão (y=pos.y)
## + ponto-âncora (vermelho), espera frames assentarem e captura o viewport.
## Rodar:  godot --path godot --resolution 1000x760 -s res://scripts/_pack06_shot_harness.gd
## Saída:  user://_pack06_shots/<NN_nome>.png

const SAVE := "user://arcane_voyage_save.json"
const OUT := "user://_pack06_shots/"
const SETTLE := 5          # frames p/ assentar render antes de capturar
const ZOOM := 1.3

var _jobs := []
var _i := -1
var _frame_in_job := 0
var _main = null
var _host = null
var _cam: Camera2D = null
var _bg: ColorRect = null
var _built_region := ""
var _snap := ""
var _had := false

func _build_region(region: String, offset: Vector2) -> void:
	# reseta os arrays (padrão dos selftests) e repinta num host novo offsetado
	if _host != null:
		_host.queue_free()
	_host = Node2D.new(); _host.position = offset; root.add_child(_host)
	_main.set("_region_node", _host); _main.set("_services", []); _main.set("_portals", [])
	_main.set("_blockers", []); _main.set("_blockers_by_level", {}); _main.set("_npcs", [])
	_main.set("_mobs", []); _main.set("_chests", [])
	match region:
		"iron_channels": _main._build_iron_channels(Vector2(2200, 1500))
		"khet_colonnade": _main._build_khet_colonnade(Vector2(2100, 1400))
		"khet_citadel": _main._build_khet_citadel(Vector2(2400, 1500))
		"khet_sand_maw": _main._build_khet_sand_maw(Vector2(2000, 1400))
		"saltwind_shore": _main._build_saltwind_shore(Vector2(2200, 1300))
		"praia_das_velas": _main._build_praia_das_velas(Vector2(2000, 1100))
		"cais_dos_ausentes": _main._build_cais_dos_ausentes(Vector2(2200, 1300))
		"salt_split_isle": _main._build_salt_split_isle(Vector2(2000, 1200))
		"deep_dunes": _main._build_deep_dunes(Vector2(2400, 1000))
	_built_region = region

func _initialize() -> void:
	# ── snapshot save (save-safe) ──
	_had = FileAccess.file_exists(SAVE)
	if _had:
		var rf := FileAccess.open(SAVE, FileAccess.READ)
		if rf != null: _snap = rf.get_as_text(); rf.close()
	DirAccess.make_dir_recursive_absolute(OUT)

	_main = load("res://scripts/Main.gd").new()
	# pré-set flags de "chegada" p/ os builds costeiros não dispararem reward-popup no screenshot (in-memory; save é restaurado)
	var gs = root.get_node_or_null("GameState")
	if gs != null:
		for fl in ["coast_route_found", "other_shore_reached", "other_shore_arc_complete", "cais_ausentes_reached", "salt_isle_reached"]:
			gs.call("set_story_flag", fl)
	# câmera + fundo neutro (areia/pedra) p/ ler silhueta e flutuação
	_bg = ColorRect.new(); _bg.color = Color(0.34, 0.30, 0.24); _bg.size = Vector2(4000, 3000)
	_bg.position = Vector2(-1000, -1000); _bg.z_index = -1000; root.add_child(_bg)
	_cam = Camera2D.new(); _cam.zoom = Vector2(ZOOM, ZOOM); root.add_child(_cam); _cam.make_current()

	# offsets por região (bem separados p/ não sobrepor)
	var OFF := {"saltwind_shore": Vector2(0, 0), "praia_das_velas": Vector2(6000, 0),
		"cais_dos_ausentes": Vector2(12000, 0), "salt_split_isle": Vector2(18000, 0),
		"deep_dunes": Vector2(24000, 0)}
	# jobs: DEEP_DUNES PACK10 — DEPOIS
	_jobs = [
		{"r": "deep_dunes", "p": Vector2(1150, 520), "n": "p10_after_ov", "z": 0.32, "over": true},
		{"r": "deep_dunes", "p": Vector2(1300, 700), "n": "p10_after_arch", "z": 0.7, "over": true},
		{"r": "deep_dunes", "p": Vector2(900, 700), "n": "p10_after_grid_walls", "z": 0.7, "over": true},
		{"r": "deep_dunes", "p": Vector2(540, 520), "n": "p10_after_west", "z": 0.6, "over": true},
		{"r": "deep_dunes", "p": Vector2(1180, 420), "n": "p10_after_camp", "z": 0.75, "over": true},
	]
	for j in _jobs: j["off"] = OFF.get(j["r"], Vector2.ZERO)   # robusto: nunca erra se faltar offset
	print("[harness] %d jobs, OUT=%s" % [_jobs.size(), OUT])

func _process(_dt: float) -> bool:
	# Godot 4 MainLoop: retornar TRUE = encerrar. Retornamos FALSE p/ continuar; quit() finaliza.
	if _i == -1:
		_advance()
		return false
	_frame_in_job += 1
	if _frame_in_job == SETTLE:
		_capture(_jobs[_i])
		_advance()
	return false

func _advance() -> void:
	_i += 1
	if _i >= _jobs.size():
		_finish()
		return
	var j = _jobs[_i]
	if j["r"] != _built_region:
		_build_region(j["r"], j["off"])
	_cam.zoom = Vector2(j.get("z", ZOOM), j.get("z", ZOOM))
	var world := (j["off"] as Vector2) + (j["p"] as Vector2)
	if not j.get("over", false):
		# overlays de leitura (só nos close-ups): linha-de-chão (y=pos.y) + ponto-âncora
		var gl := Line2D.new(); gl.z_index = 4000
		gl.points = PackedVector2Array([world + Vector2(-400, 0), world + Vector2(400, 0)])
		gl.width = 2.0; gl.default_color = Color(0.1, 0.9, 0.4, 0.55); _host.add_child(gl)
		var dot := Polygon2D.new(); var dp := PackedVector2Array()
		for k in range(10):
			var a := TAU * float(k) / 10.0
			dp.append((j["p"] as Vector2) + Vector2(cos(a) * 5.0, sin(a) * 5.0))
		dot.polygon = dp; dot.color = Color(1, 0.15, 0.1); dot.z_index = 4001; _host.add_child(dot)
	_cam.position = world
	_frame_in_job = 0

func _capture(j) -> void:
	var img := root.get_texture().get_image()
	var path := OUT + str(j["n"]) + ".png"
	img.save_png(path)
	print("[shot] %s -> %s (%dx%d)" % [j["n"], path, img.get_width(), img.get_height()])

func _finish() -> void:
	if _had:
		var wf := FileAccess.open(SAVE, FileAccess.WRITE)
		if wf != null: wf.store_string(_snap); wf.close()
		print("[save-safe] user://save restaurado")
	print(">>> SHOTS OK")
	quit(0)
