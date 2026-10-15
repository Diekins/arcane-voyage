extends Node2D
## Golem.gd — Golem de Cristal: boss jogável mínimo do Ato 2 (GODOT-ACT2-GOLEM-1).
##
## Mesma interface do Wolf (is_alive/take_damage/set_player/force_defeated_state/revive +
## sinais defeated/attack_hero/hp_changed), mas: SEM sprite (cristal desenhado com Polygon2D,
## maior que o Errante), ataque mais LENTO e mais PESADO. Sem skills/IA complexa.

signal defeated(boss_name: String)
signal hp_changed(hp: int, hp_max: int)
signal attack_hero(amount: int)

const BOSS_NAME := "Golem de Cristal"
const BAR_W := 124.0

@export var hp_max: int = 600
@export var speed: float = 92.0            # BALANCE-1: era 75 — lento demais permitia kite trivial com
                                           # arco/cajado; +rápido fecha distância (ainda << player 300)
@export var detection_range: float = 720.0
@export var stop_distance: float = 88.0    # BALANCE-1: era 100 — encosta um tico mais p/ pressionar
@export var attack_range: float = 130.0
@export var attack_cooldown: float = 2.1   # mais lento que o Lobo (1.2)
@export var damage_min: int = 14            # golpe mais pesado que o Lobo (8–14)
@export var damage_max: int = 22
@export var quest_id: String = "ch2-crystal-heart"

var hp: int = 600
var alive: bool = true
# STATS-BASE IMUTÁVEIS (FATIA A3.75): live scaling do boss por fase deriva SEMPRE daqui (nunca do já-
# escalado → sem acúmulo). Registrados uma vez pelo Main no spawn.
var has_base_stats: bool = false
var base_max_hp: int = 0
var base_damage_min: int = 0
var base_damage_max: int = 0
var combat_enabled: bool = true
var _player: Node2D
var _body: Node2D
var _bar_fill: ColorRect
var _anim: ActorAnimator
var _attack_cd: float = 0.0
# IA leve + telegraph (GODOT-MOB-AI-TELEGRAPH-1) — golem = aviso PESADO e lento
const WINDUP_TIME := 0.7
const RECOVER_TIME := 0.4
var _winding: bool = false
var _recover_t: float = 0.0
var _tele: AttackTelegraph
# ★ FRASE DO GOLEM (BOSS_IDENTITY_PASS_01): a memória petrificada fala DUAS palavras — o ESMAGAMENTO frontal (leque
# do golpe pesado; reação "não fique na frente") e a ONDA DE CRISTAL (anel no chão; reação "afaste-se", já abaixo).
# O melee deixa de ser um anel cosmético e vira CONE; a spell continua círculo → dois verbos alternando em ritmo.
const MELEE_CONE_REACH := 156.0   # = attack_range(130) × 1.2 → preserva o alcance do golpe (só estreita p/ a frente)
const MELEE_CONE_DEG := 82.0
var _aim_dir: Vector2 = Vector2.DOWN
# colisão com props/cristais da arena (GODOT-MOB-COLLISION-BLOCKERS-1)
var _blockers: Array = []
const FEET_Y := 40.0
var _stuck_t: float = 0.0   # anti-stuck no chase (GODOT-MOB-COMBAT-BEHAVIOR-2)
# SPELL TELEGRAFADA (GODOT-BOSS-SPELL-MVP-1): "Onda de Cristal" — AoE no chão na posição do alvo, com
# telegraph (anel violeta) + cast delay; dano EVITÁVEL saindo da área. Cooldown longo → evento, não spam.
# Reusa AttackTelegraph (aviso) + CombatVfx (impacto). NÃO mexe no golpe melee nem no balance base.
const SPELL_COOLDOWN := 7.0
const SPELL_CAST_DELAY := 0.95
const SPELL_RADIUS := 116.0
const SPELL_RANGE := 540.0          # só conjura se o alvo estiver dentro disso
const SPELL_DMG_MIN := 16           # ~igual ao golpe melee (não aumenta demais a dificuldade)
const SPELL_DMG_MAX := 24
var _spell_cd: float = 4.0          # 1º cast não sai logo de cara
var _casting: bool = false
var _spell_tele: AttackTelegraph
var _spell_target: Vector2 = Vector2.ZERO

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
	_build_visual()
	_add_shadow()
	_anim = ActorAnimator.new()
	add_child(_anim)
	# 4-dir REAL (GODOT-CRYSTAL-GOLEM-4DIR-ART-PLUG-1): `crystal_golem.png`/`_side.png`/`_up.png`
	# (down/right/up, frame 120). side_faces_left=false (row2=right) + can_flip=true → espelha p/ esquerda.
	_anim.setup(_body, "bosses/crystal_golem", 2.0, false, true)
	_tele = AttackTelegraph.new()
	_tele.radius = 74.0
	_tele.warn_color = Color(0.55, 0.85, 0.95)   # aviso ciano (combina com o cristal)
	add_child(_tele)
	_tele.fired.connect(_on_tele_fired)

func _build_visual() -> void:
	_body = Node2D.new()
	_body.scale = Vector2(0.6, 0.6)   # cristal ~149px: maior que o Lobo (~97), sem ser gigante
	add_child(_body)
	# corpo de cristal (hexágono alto, ~248px) — boss claramente maior que o Errante
	var crystal := Polygon2D.new()
	crystal.polygon = PackedVector2Array([
		Vector2(0, -130), Vector2(66, -68), Vector2(76, 42),
		Vector2(0, 120), Vector2(-76, 42), Vector2(-66, -68)
	])
	crystal.color = Color("57bccd")
	_body.add_child(crystal)
	var facet := Polygon2D.new()   # faceta clara (luz no cristal)
	facet.polygon = PackedVector2Array([Vector2(0, -130), Vector2(66, -68), Vector2(0, 10), Vector2(-30, -40)])
	facet.color = Color(1, 1, 1, 0.18)
	_body.add_child(facet)
	var core := Polygon2D.new()    # núcleo pulsante (a "memória soterrada")
	core.polygon = PackedVector2Array([Vector2(0, -54), Vector2(30, -4), Vector2(0, 50), Vector2(-30, -4)])
	core.color = Color("e6fbff")
	_body.add_child(core)

	var name_label := Label.new()
	name_label.text = BOSS_NAME
	name_label.position = Vector2(-46, -116)   # nome no topo (estilo MMO): acima da barra de HP
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.z_as_relative = false   # nome/barra SEMPRE por cima (y-sort não os esconde)
	name_label.z_index = 4000
	add_child(name_label)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.6)
	bar_bg.size = Vector2(BAR_W, 9)
	bar_bg.position = Vector2(-BAR_W / 2.0, -98)
	bar_bg.z_as_relative = false
	bar_bg.z_index = 4000
	add_child(bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color("6fd6e0")
	_bar_fill.size = Vector2(BAR_W, 9)
	_bar_fill.position = Vector2(-BAR_W / 2.0, -98)
	_bar_fill.z_as_relative = false
	_bar_fill.z_index = 4001
	add_child(_bar_fill)

func _add_shadow() -> void:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * 52.0, sin(a) * 13.0 + 42.0))
	poly.polygon = pts
	poly.color = Color(0, 0, 0, 0.28)
	poly.z_index = -1
	add_child(poly)

func set_player(p: Node2D) -> void:
	_player = p

func is_alive() -> bool:
	return alive

const KB_DECAY := 1400.0
var _kb := Vector2.ZERO

## Empurrão ao levar um golpe (GODOT-COMBAT-JUICE-1) — REDUZIDO (golem é pesado: ~30% do impulso).
func apply_knockback(from_pos: Vector2, strength: float) -> void:
	if not alive:
		return
	var dir := position - from_pos
	if dir.length() < 0.01:
		dir = Vector2.DOWN
	_kb = dir.normalized() * strength * 0.3

func _process(delta: float) -> void:
	if not alive or _player == null:
		return
	if _kb.length() > 1.0:
		_move_by(_kb * delta)
		_kb = _kb.move_toward(Vector2.ZERO, KB_DECAY * delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_spell_cd = maxf(0.0, _spell_cd - delta)
	if _recover_t > 0.0:
		_recover_t -= delta
		if _anim != null:
			_anim.play_idle()
		return
	if _winding:
		if _anim != null:
			_anim.set_direction(_player.position - position)
			_anim.play_idle()
		return
	# CONJURANDO a Onda de Cristal: para e encara o alvo até o telegraph disparar (não anda/golpeia)
	if _casting:
		if _anim != null:
			_anim.set_direction(_player.position - position)
			_anim.play_idle()
		return
	var d := position.distance_to(_player.position)
	var to_player := _player.position - position
	# SPELL tem prioridade sobre o melee quando pronta e o alvo está no alcance da magia (evento de combate)
	if combat_enabled and _spell_cd <= 0.0 and d <= SPELL_RANGE:
		_cast_crystal_wave()
		return
	if d <= detection_range and d > stop_distance:
		var step := to_player.normalized() * speed * delta
		var before := position
		_move_by(step)
		if (position - before).length() < step.length() * 0.5:   # preso num cristal → desvia de lado
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
	if combat_enabled and d <= attack_range and _attack_cd <= 0.0:
		_attack_cd = attack_cooldown
		_begin_windup(to_player)

func _begin_windup(to_player: Vector2) -> void:
	_winding = true
	_aim_dir = to_player.normalized() if to_player.length() > 0.001 else Vector2.DOWN
	if _anim != null:
		_anim.set_direction(to_player)
	if _tele != null:
		_tele.configure("cone", _aim_dir, MELEE_CONE_REACH, 36.0, MELEE_CONE_DEG)   # ESMAGAMENTO frontal (leque)
		_tele.begin(WINDUP_TIME)

## Fim do windup: o ESMAGAMENTO acerta SE o alvo ainda estiver no LEQUE frontal; senão erra (saiu da frente).
## (BOSS_IDENTITY_PASS_01 — cone via helper estático de AttackTelegraph.)
func _on_tele_fired() -> void:
	_winding = false
	_recover_t = RECOVER_TIME
	if not alive or not combat_enabled or _player == null:
		return
	if AttackTelegraph.in_cone(_player.position, position, _aim_dir, MELEE_CONE_REACH, MELEE_CONE_DEG):
		if _anim != null:
			_anim.play_attack(_aim_dir)
		attack_hero.emit(CombatMath.enemy_roll(damage_min, damage_max))   # A1.5: fonte central (== randi_range)

## Inicia a Onda de Cristal: telegraph (anel violeta) no CHÃO na posição ATUAL do alvo + marca de magia.
## O dano só sai quando o telegraph dispara (cast delay) — e só se o player ainda estiver na área.
func _cast_crystal_wave() -> void:
	_casting = true
	_spell_cd = SPELL_COOLDOWN
	_spell_target = _player.position
	if _anim != null:
		_anim.set_direction(_spell_target - position)
		_anim.play_idle()
	var parent := get_parent()
	if parent == null:
		_casting = false
		return
	# anel de aviso no ponto-alvo — cor VIOLETA p/ ler como MAGIA (o melee é ciano)
	_spell_tele = AttackTelegraph.new()
	_spell_tele.radius = SPELL_RADIUS
	_spell_tele.warn_color = Color(0.82, 0.5, 0.98)
	_spell_tele.position = _spell_target
	parent.add_child(_spell_tele)
	_spell_tele.fired.connect(_on_spell_fired)
	_spell_tele.begin(SPELL_CAST_DELAY)
	# leitura extra: glifo de magia do boss no chão (CombatVfx, some sozinho; z=4095 preservado)
	CombatVfx.spawn(parent, "ground_telegraph_blue_boss", _spell_target, Vector2.RIGHT, 1.3)

## Fim do cast: impacto legível + dano SÓ se o player ainda estiver dentro do raio (evitável saindo da área).
func _on_spell_fired() -> void:
	_casting = false
	_recover_t = RECOVER_TIME
	var parent := get_parent()
	if _spell_tele != null and is_instance_valid(_spell_tele):
		_spell_tele.queue_free()
	_spell_tele = null
	if not alive or not combat_enabled or _player == null:
		return
	if parent != null:
		CombatVfx.spawn(parent, "impact_large_critical", _spell_target, Vector2.RIGHT, 1.15)
	if _player.position.distance_to(_spell_target) <= SPELL_RADIUS:
		attack_hero.emit(CombatMath.enemy_roll(SPELL_DMG_MIN, SPELL_DMG_MAX))   # A1.5: fonte central (== randi_range)

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

func _spawn_damage(amount: int) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.modulate = Color("ffd24a")
	lbl.position = position + Vector2(randf_range(-24.0, 24.0), -90.0)
	lbl.z_as_relative = false
	lbl.z_index = 4090
	get_parent().add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 52.0, 0.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(lbl.queue_free)

func _die() -> void:
	alive = false
	_winding = false
	_casting = false
	_recover_t = 0.0
	if _tele != null:
		_tele.cancel()
	if _spell_tele != null and is_instance_valid(_spell_tele):
		_spell_tele.queue_free()
	_spell_tele = null
	if _bar_fill != null:
		_bar_fill.visible = false
	print("[Golem] %s derrotado." % BOSS_NAME)
	defeated.emit(BOSS_NAME)
	if _anim != null:
		_anim.play_death()

## Estado derrotado SEM emitir defeated (boot quando o save já tem o boss morto).
func force_defeated_state() -> void:
	alive = false
	hp = 0
	_winding = false
	_casting = false
	_recover_t = 0.0
	if _tele != null:
		_tele.cancel()
	if _spell_tele != null and is_instance_valid(_spell_tele):
		_spell_tele.queue_free()
	_spell_tele = null
	_update_bar()
	if _bar_fill != null:
		_bar_fill.visible = false
	if _anim != null:
		_anim.snap_dead()

func revive() -> void:
	alive = true
	hp = hp_max
	_update_bar()
	if _anim != null:
		_anim.reset()
	if _bar_fill != null:
		_bar_fill.visible = true
