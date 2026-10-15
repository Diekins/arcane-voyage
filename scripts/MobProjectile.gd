class_name MobProjectile extends Node2D
## Projétil simples de mob RANGED (GODOT-RANGED-COMBAT-MVP-1). Viaja em linha reta até um ponto-alvo
## (snapshot da posição do alvo NO DISPARO) e, ao chegar, dá um impacto: se o player estiver dentro de
## `hit_radius` do ponto de impacto, EMITE `hit(dmg)` — o mob reencaminha p/ `attack_hero` (= mesmo
## caminho de dano do melee). É DODGEÁVEL saindo do ponto. 100% procedural (estilhaço Polygon2D) +
## CombatVfx no impacto. NÃO toca em IA/cooldown/Battle UI; some sozinho. Fallback: sem player → só some.

signal hit(dmg: int)

var _target: Vector2
var _speed: float = 420.0
var _dmg: int = 0
var _player: Node2D
var _hit_radius: float = 70.0
var _impact_vfx: String = "impact_blue_magic"
var _life: float = 2.5
var _arrived: bool = false
# COBERTURA (PROJECTILE_COVER_PASS_01): se o trajeto cruza um blocker (pilar/rocha/destroço), o tiro é ABSORVIDO
# (fizzle, sem dano) — o cenário cumpre a promessa de "quebrar a mira". Default vazio = comportamento legado.
var _blockers: Array = []

## Passa os blockers da região (o mob os tem). Vazio = projétil legado (atravessa tudo).
func set_blockers(rects: Array) -> void:
	_blockers = rects

func _blocked(p: Vector2) -> bool:
	for r in _blockers:
		if (r as Rect2).has_point(p):
			return true
	return false

## Cria e adiciona o projétil em `parent` (a região). Retorna o nó (ou null se parent inválido).
static func spawn(parent: Node, from: Vector2, to: Vector2, p_speed: float, dmg: int, player: Node2D, color: Color, impact_vfx: String, hit_radius: float) -> MobProjectile:
	if parent == null:
		return null
	var p := MobProjectile.new()
	p.position = from
	p._target = to
	p._speed = maxf(60.0, p_speed)
	p._dmg = dmg
	p._player = player
	p._impact_vfx = impact_vfx
	p._hit_radius = maxf(8.0, hit_radius)
	p._make_shard(color, to - from)
	parent.add_child(p)
	return p

func _make_shard(color: Color, dir: Vector2) -> void:
	var shard := Polygon2D.new()   # losango pequeno = "estilhaço de sal"
	shard.polygon = PackedVector2Array([Vector2(11, 0), Vector2(0, 5), Vector2(-9, 0), Vector2(0, -5)])
	shard.color = color
	if dir.length() > 0.01:
		shard.rotation = dir.angle()
	add_child(shard)
	var glow := Polygon2D.new()    # leve halo claro p/ legibilidade
	glow.polygon = PackedVector2Array([Vector2(15, 0), Vector2(0, 8), Vector2(-13, 0), Vector2(0, -8)])
	glow.color = Color(color.r, color.g, color.b, 0.28)
	if dir.length() > 0.01:
		glow.rotation = dir.angle()
	add_child(glow)
	move_child(glow, 0)   # halo atrás do estilhaço

func _process(delta: float) -> void:
	if _arrived:
		return
	_life -= delta
	if _life <= 0.0:
		_arrive()
		return
	var to := _target - position
	var step := _speed * delta
	if to.length() <= step:
		position = _target
		z_index = int(position.y)
		if _blocked(position):   # alvo dentro de um pilar (raro) → o tiro morre na pedra
			_absorb()
		else:
			_arrive()
		return
	var newpos := position + to.normalized() * step
	# COBERTURA: amostra o MEIO do passo + o destino → não atravessa coluna fina mesmo a passo grande.
	if _blocked(newpos) or _blocked((position + newpos) * 0.5):
		position = newpos
		z_index = int(position.y)
		_absorb()
		return
	position = newpos
	z_index = int(position.y)   # y-sort com atores/props (≤ mundo << 4096 → z-fix preservado)

func _arrive() -> void:
	_arrived = true
	var parent := get_parent()
	if parent != null:
		CombatVfx.spawn(parent, _impact_vfx, _target, Vector2.RIGHT, 0.8)   # impacto legível (z=4095, some só)
	if _player != null and is_instance_valid(_player) and _target.distance_to(_player.position) <= _hit_radius:
		hit.emit(_dmg)
	queue_free()

## COBERTURA (PROJECTILE_COVER_PASS_01): o tiro bateu num blocker → fizzle no ponto, SEM dano (não emite hit).
func _absorb() -> void:
	_arrived = true
	var parent := get_parent()
	if parent != null:
		CombatVfx.spawn(parent, _impact_vfx, position, Vector2.RIGHT, 0.55)   # estilhaço menor na pedra (some só)
	queue_free()
