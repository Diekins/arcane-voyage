extends Node2D
## ★ POC ISOLADA E EXPERIMENTAL — Mundo Contínuo (GODOT-CONTINUOUS-ZONE-POC-1)
## Prova de conceito: andar continuamente entre 3 regiões Khet adjacentes num ÚNICO espaço, sem loading.
## NÃO faz parte do jogo de produção: é uma CENA separada (ContinuousZoneTest.tscn), com player/câmera PRÓPRIOS.
## NÃO chama load_region/_build_topdown_map de produção, NÃO escreve save. Reusa os builders do Main via uma
## instância DESTACADA (nunca entra na árvore → _ready de produção NÃO roda).
## Rodar:  godot --path godot res://scenes/ContinuousZoneTest.tscn   (ou abrir a cena no editor e F6)

# Offsets do tools/map-editor/world_layout.json (cantos sup-esq), NORMALIZADOS pelo menor canto (→ inicia em 0,0).
# min_x=26750 (salt_scrub), min_y=18550 (dune_overlook).
const ZONES := [
	{"id": "khet_dune_overlook", "size": Vector2(1000, 700), "offset": Vector2(1750, 0)},
	{"id": "khet_salt_scrub",    "size": Vector2(1100, 750), "offset": Vector2(0, 1975)},
	{"id": "khet_waystation",    "size": Vector2(1000, 700), "offset": Vector2(3650, 800)},
]
const SPEED := 260.0
const HALF := 14.0   # meia-extensão do player p/ colisão AABB

var _main: Node2D            # instância DESTACADA do Main (só p/ reusar os builders)
var _blockers: Array = []    # blockers de PROP em coords GLOBAIS (bordas de região EXCLUÍDAS p/ permitir cruzar)
var _player: Node2D
var _cam: Camera2D
var _fps_label: Label
var _info_label: Label
var _zone_min := Vector2.INF
var _zone_max := Vector2(-INF, -INF)
var _per_zone_nodes := []

func _ready() -> void:
	_main = load("res://scripts/Main.gd").new()   # NÃO add_child → _ready de produção não dispara
	var total_props_blockers := 0
	for z in ZONES:
		var zone := Node2D.new()
		zone.name = "Zone_" + str(z["id"])
		zone.position = z["offset"]
		add_child(zone)
		var nodes_before := zone.get_child_count()
		# repointa o _region_node do Main p/ ESTE nó offsetado → os builders desenham em coords locais aqui dentro
		_main.set("_region_node", zone)
		_main._build_manifest_ground(str(z["id"]), z["size"])   # chão + (bordas → IGNORADAS na colisão)
		var blk_after_ground: int = (_main.get("_blockers") as Array).size()
		_main._build_from_manifest(str(z["id"]))                 # props/portais/npcs + blockers de PROP
		# blockers ADICIONADOS por _build_from_manifest (props/manual) → coords globais; bordas (do ground) ficam de fora
		var allblk: Array = _main.get("_blockers")
		for i in range(blk_after_ground, allblk.size()):
			var r: Rect2 = allblk[i]
			_blockers.append(Rect2(r.position + z["offset"], r.size))
		total_props_blockers = allblk.size()
		_per_zone_nodes.append(zone.get_child_count() - nodes_before)
		# bbox da zona (em global)
		_zone_min = _zone_min.min(z["offset"])
		_zone_max = _zone_max.max(z["offset"] + z["size"])
	_spawn_player()
	_build_hud()
	print("[ContinuousZoneTest] zonas=%d | nós/zona=%s | blockers de prop (global)=%d | bbox=%s..%s | total_nodes=%d" % [
		ZONES.size(), str(_per_zone_nodes), _blockers.size(), str(_zone_min), str(_zone_max), get_tree().get_node_count()])

func _spawn_player() -> void:
	_player = Node2D.new()
	# surge no centro da 1ª zona (dune_overlook)
	_player.position = ZONES[0]["offset"] + ZONES[0]["size"] * 0.5
	_player.z_index = 4000   # POC: acima dos props (z=local y ≤ ~750) e ABAIXO do CombatVfx 4095 (sem estourar CANVAS_ITEM_Z_MAX)
	add_child(_player)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(0, -16), Vector2(12, 0), Vector2(0, 16), Vector2(-12, 0)])
	body.color = Color("3fa7ff")
	_player.add_child(body)
	var tag := Label.new()
	tag.text = "TEST"
	tag.position = Vector2(-16, -38)
	_player.add_child(tag)
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	_cam.limit_left = int(_zone_min.x)
	_cam.limit_top = int(_zone_min.y)
	_cam.limit_right = int(_zone_max.x)
	_cam.limit_bottom = int(_zone_max.y)
	_player.add_child(_cam)
	_cam.make_current()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.position = Vector2(16, 12)
	_fps_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(_fps_label)
	_info_label = Label.new()
	_info_label.position = Vector2(16, 40)
	_info_label.add_theme_font_size_override("font_size", 14)
	_info_label.text = "POC MUNDO CONTÍNUO — WASD mover · Esc sair\nzonas: dune_overlook | salt_scrub | waystation (1 espaço, sem loading)\nblockers de prop: %d · nós/zona: %s · total nós: %d" % [
		_blockers.size(), str(_per_zone_nodes), get_tree().get_node_count()]
	layer.add_child(_info_label)

func _hits(p: Vector2) -> bool:
	var pr := Rect2(p.x - HALF, p.y - HALF, HALF * 2.0, HALF * 2.0)
	for b in _blockers:
		if pr.intersects(b):
			return true
	return false

func _process(_delta: float) -> void:
	if _fps_label != null:
		var cur := _which_zone(_player.position)
		_fps_label.text = "FPS: %d   (zona atual: %s)" % [Engine.get_frames_per_second(), cur]

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): dir.y -= 1
	if Input.is_key_pressed(KEY_S): dir.y += 1
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	if dir == Vector2.ZERO:
		return
	dir = dir.normalized()
	var step := dir * SPEED * delta
	var pos := _player.position
	var tx := pos + Vector2(step.x, 0)   # eixo X (slide)
	if not _hits(tx):
		pos = tx
	var ty := pos + Vector2(0, step.y)   # eixo Y (slide)
	if not _hits(ty):
		pos = ty
	_player.position = pos

func _which_zone(p: Vector2) -> String:
	for z in ZONES:
		var r := Rect2(z["offset"], z["size"])
		if r.has_point(p):
			return str(z["id"])
	return "(entre zonas / vazio)"

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		get_tree().quit()
