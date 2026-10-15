extends Node2D
## Wolf.gd — Lobo Alfa: ESQUELETO de combate 2D (GODOT-COMBAT-SKELETON-1).
##
## HP + barra simples, recebe dano (flash vermelho + número flutuante), aproxima-se
## lentamente do Errante quando ele está no alcance, e ao morrer emite `defeated(boss_name)`.
## É MÍNIMO de propósito: SEM dano ao jogador, SEM skills/IA complexa, SEM loot.

signal defeated(boss_name: String)
signal hp_changed(hp: int, hp_max: int)
signal attack_hero(amount: int)   # o Lobo desferiu um golpe (Main decide aplicar o dano)

const BOSS_NAME := "Lobo Alfa"
const BAR_W := 78.0

@export var hp_max: int = 60
@export var speed: float = 120.0          # mapa top-down maior → mob mais ágil
@export var detection_range: float = 600.0
@export var stop_distance: float = 90.0
@export var attack_range: float = 110.0
@export var attack_cooldown: float = 1.2
@export var damage_min: int = 8
@export var damage_max: int = 14
@export var quest_id: String = "ch1-awakening"

var hp: int = 60
var alive: bool = true
# STATS-BASE IMUTÁVEIS (FATIA A3.75): live scaling do boss por fase deriva SEMPRE daqui (nunca do já-
# escalado → sem acúmulo). Registrados uma vez pelo Main no spawn.
var has_base_stats: bool = false
var base_max_hp: int = 0
var base_damage_min: int = 0
var base_damage_max: int = 0
var combat_enabled: bool = true   # Main desliga durante diálogo / herói derrotado
var _player: Node2D
var _sprite: Sprite2D
var _bar_fill: ColorRect
var _anim: ActorAnimator
var _attack_cd: float = 0.0
# IA leve + telegraph (GODOT-MOB-AI-TELEGRAPH-1)
const WINDUP_TIME := 0.5
const RECOVER_TIME := 0.3
var _winding: bool = false
var _recover_t: float = 0.0
var _tele: AttackTelegraph
# ★ FRASE DO ALFA (BOSS_IDENTITY_PASS_01): o rei dos rushers fala DUAS palavras — o BOTE (faixa que atravessa) e a
# MORDIDA (leque frontal quando você cola). "Salta… morde… salta." Reação: esquive o salto, não cole na cara.
const PHRASE := [
	{"shape": "line", "reach": 235.0, "half": 40.0},   # o BOTE — investida longa do Alfa
	{"shape": "cone", "reach": 135.0, "cone": 82.0},   # a MORDIDA — leque frontal
]
const LUNGE_SPEED := 1250.0   # o bote do Alfa é mais forte que o do lobo comum
const LUNGE_TIME := 0.18
var _aim_dir: Vector2 = Vector2.DOWN
var _cycle_idx: int = 0
var _cur_shape: String = "line"
var _cur_reach: float = 235.0
var _cur_cone: float = 82.0
var _cur_half: float = 40.0
var _lunging: bool = false
var _lunge_t: float = 0.0
var _lunge_dir: Vector2 = Vector2.DOWN
# colisão com props/blockers (GODOT-MOB-COLLISION-BLOCKERS-1)
var _blockers: Array = []
const FEET_Y := 26.0
var _stuck_t: float = 0.0   # anti-stuck no chase (GODOT-MOB-COMBAT-BEHAVIOR-2)

func set_blockers(rects: Array) -> void:
	_blockers = rects

func _blocked(p: Vector2) -> bool:
	for r in _blockers:
		if r.has_point(p):
			return true
	return false

func _move_by(disp: Vector2) -> void:
	var feet := Vector2(0, FEET_Y)
	var nx := position.x + disp.x
	if not _blocked(Vector2(nx, position.y) + feet):
		position.x = nx
	var ny := position.y + disp.y
	if not _blocked(Vector2(position.x, ny) + feet):
		position.y = ny

func _ready() -> void:
	hp = hp_max
	_sprite = Sprite2D.new()
	var tex := _load_tex("res://assets/scenes/enemy-mist-wolf.png")
	if tex != null:
		_sprite.texture = tex
		_sprite.scale = Vector2(0.2, 0.2)   # 484x515 → ~97x103 (escala top-down)
	add_child(_sprite)
	_add_shadow()

	var name_label := Label.new()
	name_label.text = BOSS_NAME
	name_label.position = Vector2(-30, -100)   # nome no topo (estilo MMO): acima da barra de HP
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.z_as_relative = false   # nome/barra SEMPRE por cima (y-sort não os esconde)
	name_label.z_index = 4000
	add_child(name_label)

	# barra de HP (fundo escuro + preenchimento vermelho) acima da cabeça
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.6)
	bar_bg.size = Vector2(BAR_W, 8)
	bar_bg.position = Vector2(-BAR_W / 2.0, -82)
	bar_bg.z_as_relative = false
	bar_bg.z_index = 4000
	add_child(bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color("c8553d")
	_bar_fill.size = Vector2(BAR_W, 8)
	_bar_fill.position = Vector2(-BAR_W / 2.0, -82)
	_bar_fill.z_as_relative = false
	_bar_fill.z_index = 4001
	add_child(_bar_fill)

	_anim = ActorAnimator.new()
	add_child(_anim)
	_anim.setup(_sprite, "bosses/alpha_wolf", 2.5, true)   # 4-dir real: lateral (row1) encara a ESQUERDA
	_tele = AttackTelegraph.new()
	_tele.radius = 46.0
	add_child(_tele)
	_tele.fired.connect(_on_tele_fired)

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func set_player(p: Node2D) -> void:
	_player = p

func is_alive() -> bool:
	return alive

const KB_DECAY := 1100.0
var _kb := Vector2.ZERO

## Empurrão ao levar um golpe (GODOT-COMBAT-JUICE-1).
func apply_knockback(from_pos: Vector2, strength: float) -> void:
	if not alive:
		return
	var dir := position - from_pos
	if dir.length() < 0.01:
		dir = Vector2.DOWN
	_kb = dir.normalized() * strength

func _process(delta: float) -> void:
	if not alive or _player == null:
		return
	if _kb.length() > 1.0:
		_move_by(_kb * delta)
		_kb = _kb.move_toward(Vector2.ZERO, KB_DECAY * delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	# BOTE do Alfa (faixa): avança rápido na direção travada (follow-through; dano já resolvido no disparo).
	if _lunging:
		_lunge_t -= delta
		_move_by(_lunge_dir * LUNGE_SPEED * delta)
		if _anim != null:
			_anim.play_attack(_lunge_dir)
		if _lunge_t <= 0.0:
			_lunging = false
		return
	# recuperação pós-golpe: parado
	if _recover_t > 0.0:
		_recover_t -= delta
		if _anim != null:
			_anim.play_idle()
		return
	# windup (telegraph aceso): parado encarando o alvo até o aviso disparar
	if _winding:
		if _anim != null:
			_anim.set_direction(_player.position - position)
			_anim.play_idle()
		return
	var d := position.distance_to(_player.position)
	var to_player := _player.position - position
	if d <= detection_range and d > stop_distance:
		var step := to_player.normalized() * speed * delta
		var before := position
		_move_by(step)
		if (position - before).length() < step.length() * 0.5:   # bateu na parede → desvio perpendicular
			_stuck_t += delta
			var sgn := 1.0 if (int(_stuck_t / 0.5) % 2 == 0) else -1.0
			_move_by(Vector2(-to_player.y, to_player.x).normalized() * sgn * 0.9 * speed * delta)
		else:
			_stuck_t = 0.0
		if _anim != null:
			_anim.play_walk(to_player)
	elif _anim != null:
		_stuck_t = 0.0
		_anim.play_idle()
		_anim.set_direction(to_player)
	# ataque com TELEGRAPH: só quando habilitado, perto e fora de cooldown. O golpe sai no fim do windup.
	if combat_enabled and d <= attack_range and _attack_cd <= 0.0:
		_attack_cd = attack_cooldown
		_begin_windup(to_player)

func _begin_windup(to_player: Vector2) -> void:
	_winding = true
	_aim_dir = to_player.normalized() if to_player.length() > 0.001 else Vector2.DOWN
	var beat: Dictionary = PHRASE[_cycle_idx % PHRASE.size()]   # próxima palavra da frase
	_cycle_idx += 1
	_cur_shape = str(beat.get("shape", "circle"))
	_cur_reach = float(beat.get("reach", 220.0))
	_cur_cone = float(beat.get("cone", 70.0))
	_cur_half = float(beat.get("half", 36.0))
	if _anim != null:
		_anim.set_direction(to_player)
	if _tele != null:
		_tele.configure(_cur_shape, _aim_dir, _cur_reach, _cur_half, _cur_cone)
		_tele.begin(WINDUP_TIME)

## Fim do windup: golpe SE o alvo ainda estiver na ZONA da forma do beat; senão erra (desviou). O BOTE (line) ainda
## avança. (BOSS_IDENTITY_PASS_01 — usa os helpers estáticos de AttackTelegraph.)
func _on_tele_fired() -> void:
	_winding = false
	_recover_t = RECOVER_TIME
	if not alive or not combat_enabled or _player == null:
		return
	var hit := false
	match _cur_shape:
		"line": hit = AttackTelegraph.in_line(_player.position, position, _aim_dir, _cur_reach, _cur_half)
		"cone": hit = AttackTelegraph.in_cone(_player.position, position, _aim_dir, _cur_reach, _cur_cone)
		_: hit = (_player.position - position).length() <= attack_range * 1.2
	if hit:
		if _anim != null:
			_anim.play_attack(_aim_dir)
		attack_hero.emit(CombatMath.enemy_roll(damage_min, damage_max))   # A1.5: fonte central (== randi_range)
	if _cur_shape == "line":   # o BOTE atravessa (follow-through)
		_lunging = true
		_lunge_t = LUNGE_TIME
		_lunge_dir = _aim_dir

func take_damage(amount: int) -> void:
	if not alive:
		return
	hp = maxi(0, hp - amount)
	_update_bar()
	_spawn_damage(amount)
	if _anim != null:
		if _player != null:
			_anim.set_direction(_player.position - position)
		_anim.play_hit()
	hp_changed.emit(hp, hp_max)
	if hp <= 0:
		_die()

func _update_bar() -> void:
	if _bar_fill != null:
		_bar_fill.size.x = BAR_W * (float(hp) / float(hp_max))

func _add_shadow() -> void:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * 40.0, sin(a) * 9.0 + 32.0))
	poly.polygon = pts
	poly.color = Color(0, 0, 0, 0.26)
	poly.z_index = -1
	add_child(poly)

func _spawn_damage(amount: int) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.modulate = Color("ffd24a")
	lbl.position = position + Vector2(randf_range(-22.0, 22.0), -60.0)
	lbl.z_as_relative = false
	lbl.z_index = 4090
	get_parent().add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 48.0, 0.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(lbl.queue_free)

func _die() -> void:
	alive = false
	_winding = false
	_lunging = false
	_recover_t = 0.0
	if _tele != null:
		_tele.cancel()
	if _bar_fill != null:
		_bar_fill.visible = false
	print("[Wolf] %s derrotado." % BOSS_NAME)
	defeated.emit(BOSS_NAME)
	if _anim != null:
		_anim.play_death()

## Coloca o Lobo no estado derrotado SEM emitir `defeated` (usado no boot quando o save já
## marca o boss como morto — evita re-disparar guardian-felled).
func force_defeated_state() -> void:
	alive = false
	hp = 0
	_winding = false
	_lunging = false
	_recover_t = 0.0
	if _tele != null:
		_tele.cancel()
	_update_bar()
	if _bar_fill != null:
		_bar_fill.visible = false
	if _anim != null:
		_anim.snap_dead()

## Revive o Lobo ao estado inicial (usado no reset de save / F12).
func revive() -> void:
	alive = true
	hp = hp_max
	_lunging = false
	_cycle_idx = 0
	_update_bar()
	if _anim != null:
		_anim.reset()
	if _bar_fill != null:
		_bar_fill.visible = true
