extends Node2D
## Projectile — disparo simples do Errante (GODOT-WEAPON-ARCHETYPE-1) p/ arco (físico) e cajado
## (arcano). Viaja em linha reta na direção mirada; ao tocar o 1º inimigo VIVO no raio, aplica
## `take_damage` (que já dá o número flutuante + flinch do alvo) e some. Some também ao esgotar a
## distância. Os alvos são um SNAPSHOT no disparo (voo curto; nenhum mob novo nasce no meio).
##
## É adicionado ao _region_node (mesmo espaço dos inimigos) → compara `position` (não global).

var _dir := Vector2.RIGHT
var _speed := 600.0
var _remaining := 600.0        # distância restante até sumir
var _damage := 10
var _enemies: Array = []        # mobs + boss (snapshot); validados a cada frame
var _color := Color.WHITE       # cor do disparo (passa pro impacto/faísca)
var _kind := ""                 # "bow"/"staff" — staff dispara o impacto MÁGICO (azul) no acerto
var _main                       # ref ao Main p/ disparar o game-feel (_juice_hit) no acerto
const HIT_RADIUS := 32.0

func setup(dir: Vector2, speed: float, max_dist: float, damage: int, color: Color, enemies: Array, kind: String) -> void:
	_dir = dir.normalized() if dir.length() > 0.01 else Vector2.DOWN
	_speed = speed
	_remaining = max_dist
	_damage = damage
	_enemies = enemies
	_color = color
	_kind = kind
	z_as_relative = false
	z_index = 4050   # acima dos atores, abaixo dos números de dano (4090)
	rotation = _dir.angle()
	_build_visual(color, kind)

## Visual discreto: flecha (físico) = pequeno losango alongado; arcano (cajado) = orbe ciano com halo.
func _build_visual(color: Color, kind: String) -> void:
	if kind == "staff" or kind == "book":   # cajado e livro (Página Cortante) = orbe arcano (GODOT-ORACLE-WEAPON-BOOK-1)
		var halo := Polygon2D.new()
		halo.polygon = _circle(11.0)
		halo.color = Color(color.r, color.g, color.b, 0.28)
		add_child(halo)
		var core := Polygon2D.new()
		core.polygon = _circle(5.5)
		core.color = color
		add_child(core)
	else:
		# flecha: haste fina + ponta (apontando p/ +X; o nó já está rotacionado p/ _dir)
		var shaft := Polygon2D.new()
		shaft.polygon = PackedVector2Array([Vector2(-12, -1.6), Vector2(7, -1.6), Vector2(7, 1.6), Vector2(-12, 1.6)])
		shaft.color = color
		add_child(shaft)
		var head := Polygon2D.new()
		head.polygon = PackedVector2Array([Vector2(7, -4.5), Vector2(15, 0), Vector2(7, 4.5)])
		head.color = Color(color.r * 0.8, color.g * 0.8, color.b * 0.8)
		add_child(head)

func _circle(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(12):
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _process(delta: float) -> void:
	var step := _speed * delta
	position += _dir * step
	_remaining -= step
	for e in _enemies:
		if is_instance_valid(e) and e.is_alive() and position.distance_to(e.position) <= HIT_RADIUS:
			e.take_damage(_damage)
			if _main != null and is_instance_valid(_main):
				_main.call("_juice_hit", e, _damage, _color, _kind == "staff" or _kind == "book")   # hit-stop + shake + faísca + knockback (+impacto mágico se cajado/livro)
			queue_free()
			return
	if _remaining <= 0.0:
		queue_free()
