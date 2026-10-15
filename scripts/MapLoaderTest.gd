extends Node2D
## Cena de teste OPT-IN do MapLoader (EXPERIMENTAL). A cena principal do jogo continua sendo
## Main.tscn — esta só roda se você abrir MapLoaderTest.tscn manualmente. Não toca em save/progressão.
##
## MAP-LOADER-GODOT-2: vira um mini-sandbox jogável (isolado):
##  - WASD/setas movem o Errante; câmera segue.
##  - chegar perto de um portal → [E] troca pro JSON-alvo (por map.id == target) quando existir.
##  - mobs exportados aparecem (sprite via assetBank) e fazem patrol simples.
##  - [N] alterna entre os data/studio_*.json; [R] recarrega; HUD mostra estado/avisos.
##  - json_path no Inspector força um arquivo (vazio = 1º studio_*.json).

@export var json_path: String = ""

const MARGIN := 48.0
const SPEED := 280.0
const PORTAL_RADIUS := 120.0

var _files: Array = []
var _idx: int = 0
var _ld = null
var _holder: Node2D = null
var _player: Node2D = null
var _cam: Camera2D = null
var _hud: Label = null
var _prompt: Label = null
var _map_size: Vector2 = Vector2(1600, 1100)
var _portals: Array = []     # [{pos, target, title}]
var _mobs: Array = []        # [{node, origin, radius, t}]
var _portal_cd: float = 0.0
var _sprite: Sprite2D = null # corpo do player (p/ flip_h)
var _arrow: Polygon2D = null # seta de direção (facing 4-dir)
var _facing: Vector2 = Vector2.DOWN
var _summary: Dictionary = {}

func _ready() -> void:
	print("[MapLoaderTest] === LABORATÓRIO EXPERIMENTAL Studio→Godot (NÃO é o jogo real). Jogo real = scenes/Main.tscn ===")
	_files = _scan()
	if json_path != "" and FileAccess.file_exists(json_path):
		var only := json_path.get_file()
		if _files.has(only): _idx = _files.find(only)
		else: _files.insert(0, only); _idx = 0
	_build()

func _scan() -> Array:
	var out: Array = []
	var d := DirAccess.open("res://data/")
	if d != null:
		for f in d.get_files():
			if f.begins_with("studio_") and f.ends_with(".json"): out.append(f)
	out.sort()
	return out

func _current_path() -> String:
	if not _files.is_empty(): return "res://data/" + str(_files[_idx])
	return json_path

func _build() -> void:
	if _holder != null and is_instance_valid(_holder): _holder.queue_free()
	if _player != null and is_instance_valid(_player): _player.queue_free()
	_portals = []
	_mobs = []
	_holder = Node2D.new(); _holder.name = "Holder"; add_child(_holder)

	var path := _current_path()
	if path == "" or not FileAccess.file_exists(path):
		_set_hud("nenhum studio_*.json em res://data/ (defina json_path)")
		return
	_ld = load("res://scripts/MapLoader.gd").new()
	if not _ld.load_map_json(path):
		_set_hud("falha ao carregar: " + path)
		return
	var errs: Array = _ld.validate_min()
	if not errs.is_empty():
		push_warning("[MapLoaderTest] validação: " + str(errs))
	_summary = _ld.build_into(_holder, {})
	_map_size = _ld.map_size()
	for w in _ld.warnings:
		push_warning("[MapLoaderTest] " + str(w))
	print("[MapLoaderTest] ", path.get_file(), " => ", _summary)

	# portais (dados p/ interação) + mobs (patrol)
	for p in _ld.portals:
		if p is Dictionary:
			_portals.append({ "pos": Vector2(float(p.get("x", 0)), float(p.get("y", 0))), "target": str(p.get("target", "")), "title": str(p.get("title", "Portal")) })
	for m in _summary.get("mob_nodes", []):
		if m is Dictionary and m.get("node") != null:
			_mobs.append({ "node": m["node"], "origin": m["origin"], "radius": float(m.get("radius", 0)), "t": 0.0 })

	# jogador no spawn + câmera
	_player = _make_player(_ld.map_spawn())
	add_child(_player)
	if _cam == null:
		_cam = Camera2D.new()
	if _cam.get_parent() != null: _cam.get_parent().remove_child(_cam)
	_player.add_child(_cam)
	_cam.zoom = Vector2(0.55, 0.55)
	_cam.make_current()
	_portal_cd = 0.6
	_refresh_hud()

func _make_player(pos: Vector2) -> Node2D:
	var p := Node2D.new(); p.position = pos; p.z_index = 9000
	_sprite = null
	var tex := load("res://assets/actors/hero/errante.png") as Texture2D
	if tex != null:
		var s := Sprite2D.new(); s.texture = tex
		if tex.get_width() > 64:
			s.region_enabled = true; s.region_rect = Rect2(0, 0, 64, tex.get_height())
		p.add_child(s); _sprite = s
	else:
		var c := ColorRect.new(); c.size = Vector2(28, 28); c.position = Vector2(-14, -14); c.color = Color(0.6, 0.8, 1.0); p.add_child(c)
	# seta de direção (facing) — aponta p/ o último movimento (clareza nas 4 direções)
	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([Vector2(15, 0), Vector2(-7, -8), Vector2(-7, 8)])
	_arrow.color = Color("e8c267")
	_arrow.position = Vector2(0, -52)
	_facing = Vector2.DOWN
	_arrow.rotation = _facing.angle()
	p.add_child(_arrow)
	return p

func _process(delta: float) -> void:
	_portal_cd = maxf(0.0, _portal_cd - delta)
	if _player != null and is_instance_valid(_player):
		var v := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1.0
		if v != Vector2.ZERO:
			_player.position += v.normalized() * SPEED * delta
			_player.position.x = clampf(_player.position.x, MARGIN, _map_size.x - MARGIN)
			_player.position.y = clampf(_player.position.y, MARGIN, _map_size.y - MARGIN)
			# facing: vira o corpo (flip L/R) + seta aponta a direção (4-dir clara)
			_facing = v.normalized()
			if _sprite != null and absf(_facing.x) > 0.1:
				_sprite.flip_h = _facing.x < 0.0
			if _arrow != null:
				_arrow.rotation = _facing.angle()
	# patrol VISUAL calmo: leve oscilação horizontal (amplitude pequena) + bob vertical sutil.
	# Sem IA/colisão — só pra parecer "vivo", não bugado.
	for m in _mobs:
		if not is_instance_valid(m["node"]): continue
		m["t"] += delta
		var amp: float = clampf(float(m["radius"]) * 0.25, 0.0, 48.0)
		var ox := sin(m["t"] * 0.7) * amp
		var oy := sin(m["t"] * 1.6) * 4.0
		m["node"].position = m["origin"] + Vector2(ox, oy)
	_update_prompt()

func _update_prompt() -> void:
	if _prompt == null or _player == null: return
	var near = _nearest_portal()
	if near != null:
		_prompt.text = "[E] entrar: %s → %s" % [near["title"], near["target"] if near["target"] != "" else "(sem target)"]
		_prompt.visible = true
	else:
		_prompt.visible = false

func _nearest_portal():
	if _player == null: return null
	var best = null
	var best_d := PORTAL_RADIUS
	for p in _portals:
		var d: float = _player.position.distance_to(p["pos"])
		if d <= best_d:
			best_d = d; best = p
	return best

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	match event.keycode:
		KEY_N:
			if not _files.is_empty():
				_idx = (_idx + 1) % _files.size(); _build()
		KEY_R:
			_build()
		KEY_E:
			if _portal_cd <= 0.0:
				var near = _nearest_portal()
				if near != null: _enter_portal(near)

func _enter_portal(p: Dictionary) -> void:
	var target := str(p["target"])
	if target == "":
		_set_hud("portal SEM target — nada a carregar (warning).")
		return
	var dest: String = _ld.find_map_for_target(target)
	if dest == "":
		_set_hud("target '%s' não encontrado entre studio_*.json (warning)." % target)
		return
	# alterna o seletor pro arquivo de destino e reconstrói
	var only: String = dest.get_file()
	if _files.has(only): _idx = _files.find(only)
	else: _files.append(only); _idx = _files.size() - 1
	_build()

func _set_hud(text: String) -> void:
	_ensure_hud()
	_hud.text = "[MapLoaderTest] " + text

func _refresh_hud() -> void:
	_ensure_hud()
	var path := _current_path().get_file()
	var map_id := str(_ld.map.get("id", "?")) if _ld != null else "?"
	var warns := int(_summary.get("warnings", 0))
	var wtxt := ("⚠ %d warning(s) — ver console" % warns) if warns > 0 else "sem warnings (caminho feliz)"
	_hud.text = "🧪 MapLoader — SAMPLE EXPERIMENTAL  ·  NÃO é o jogo real (jogo real = scenes/Main.tscn)\n" \
		+ "mapa: %s   ·   arquivo: %s   [%d/%d]\n" % [map_id, path, _idx + 1, max(_files.size(), 1)] \
		+ "objetivo: town → hunt → cave → hunt → town   ·   mobs = visuais (sem IA/combate real)\n" \
		+ "obj %d · blk %d · portais %d · npc %d · svc %d · mob %d · tilemaps %d (%d cél.)   ·   %s\n" % [
			int(_summary.get("objects", 0)), int(_summary.get("blockers", 0)), int(_summary.get("portals", 0)),
			int(_summary.get("npc", 0)), int(_summary.get("service", 0)), int(_summary.get("mob", 0)),
			int(_summary.get("tilemaps", 0)), int(_summary.get("tilecells", 0)), wtxt] \
		+ "WASD/setas mover · [E] portal · [N] próximo mapa · [R] recarregar"

func _ensure_hud() -> void:
	if _hud != null: return
	var layer := CanvasLayer.new(); add_child(layer)
	var bg := ColorRect.new(); bg.color = Color(0, 0, 0, 0.6); bg.position = Vector2(8, 8); bg.size = Vector2(720, 116)
	layer.add_child(bg)
	var stripe := ColorRect.new(); stripe.color = Color("e8c267"); stripe.position = Vector2(8, 8); stripe.size = Vector2(720, 3)
	layer.add_child(stripe)
	_hud = Label.new(); _hud.position = Vector2(14, 14); _hud.add_theme_font_size_override("font_size", 13)
	layer.add_child(_hud)
	_prompt = Label.new(); _prompt.position = Vector2(14, 130); _prompt.add_theme_font_size_override("font_size", 16)
	_prompt.modulate = Color("e8c267"); _prompt.visible = false
	layer.add_child(_prompt)
