class_name AttackTelegraph extends Node2D
## Aviso visual de ataque (GODOT-MOB-AI-TELEGRAPH-1; FORMAS em TELEGRAPH_SHAPES_PASS_01) — uma figura no CHÃO sob a
## criatura que acende e cresce durante o "windup". Ao terminar, emite `fired` (o mob então aplica o golpe SE o alvo
## ainda estiver na ZONA da forma). 100% procedural (Polygon2D), sem arte nova.
##
## ★ A FORMA é a LINGUAGEM (TELEGRAPH_SHAPES_PASS_01): cada família de inimigo "fala" um formato diferente, e o
## jogador aprende a reação pelo DESENHO, não pelo nome do monstro:
##   "circle" → ANEL no chão (controle de espaço; reação: "afaste-se")        [modelo legado, default]
##   "line"   → FAIXA estreita na direção travada (investida; reação: "saia da trajetória")
##   "cone"   → LEQUE frontal na direção travada (golpe em área; reação: "não fique na frente")
##
## Uso: tele = AttackTelegraph.new(); tele.radius = R; tele.warn_color = Color(...); add_child(tele)
##      tele.fired.connect(_on_tele_fired)
##      tele.configure("line", aim_dir, reach, half_width, cone_deg)   # opcional; default = "circle"
##      tele.begin(0.4)  # inicia o aviso (reconstrói a forma)
## `radius`/`warn_color` devem ser setados ANTES do add_child (lidos no _ready); a forma pode mudar a cada windup.

signal fired

@export var radius: float = 30.0
# POLISH_PASS_02A — tom mais QUENTE/vermelho ("isso é perigo"); leitura, não dano/alcance/timing.
@export var warn_color: Color = Color(0.98, 0.28, 0.17)

# FORMA (TELEGRAPH_SHAPES_PASS_01) — reconfigurável a cada windup via configure().
var shape: String = "circle"        # "circle" | "line" | "cone"
var aim: Vector2 = Vector2.DOWN      # direção TRAVADA (line/cone) — definida no início do windup
# `reach` = alcance da forma (comprimento da linha / raio do cone / RAIO HONESTO do círculo). 0 = não-configurado:
# o círculo cai no `radius` legado (ex.: Onda de Cristal do Golem, que seta radius e não chama configure()).
var reach: float = 0.0
var half_width: float = 34.0         # meia-largura da faixa (line)
var cone_deg: float = 70.0           # abertura do leque (cone)

var _t: float = 0.0
var _dur: float = 0.4
var active: bool = false
var _poly: Polygon2D
var _outline: Line2D   # POLISH_PASS_02A — contorno quente que faz a forma POPAR ("zona de perigo"); só leitura

## Cria _poly + _outline (idempotente). Chamado no _ready E no _rebuild → robusto a ordem/timing de chamada.
func _ensure_nodes() -> void:
	if _poly == null:
		_poly = Polygon2D.new()
		_poly.z_index = -2   # no chão, sob o corpo da criatura
		add_child(_poly)
	if _outline == null:   # POLISH_PASS_02A — borda saliente (acompanha _poly: mesma rotação do nó + mesma scale)
		_outline = Line2D.new()
		_outline.width = 3.0
		_outline.z_index = -1
		_outline.joint_mode = Line2D.LINE_JOINT_ROUND
		add_child(_outline)

func _ready() -> void:
	_ensure_nodes()
	_rebuild()
	visible = false

## Define a FORMA do próximo aviso (TELEGRAPH_SHAPES_PASS_01). `p_aim` é a direção travada (line/cone).
func configure(p_shape: String, p_aim: Vector2, p_reach: float, p_half_width: float, p_cone_deg: float) -> void:
	shape = p_shape
	aim = p_aim.normalized() if p_aim.length() > 0.001 else Vector2.DOWN
	reach = p_reach
	half_width = p_half_width
	cone_deg = p_cone_deg

## (Re)constrói a geometria da forma. line/cone são desenhados em LOCAL +X e o NÓ é rotacionado p/ a mira
## (assim a animação de "crescer no comprimento" = scale.x acompanha a direção). circle = elipse achatada legado.
func _rebuild() -> void:
	_ensure_nodes()   # robusto: se begin() vier antes do _ready (timing), os nós existem
	var pts := PackedVector2Array()
	match shape:
		"line":
			rotation = aim.angle()
			var w := half_width
			# faixa do mob (x=0) até o alcance, afinando na ponta (leitura de "vai por aqui")
			pts.append(Vector2(0.0, -w))
			pts.append(Vector2(reach, -w * 0.55))
			pts.append(Vector2(reach, w * 0.55))
			pts.append(Vector2(0.0, w))
		"cone":
			rotation = aim.angle()
			var half := deg_to_rad(cone_deg * 0.5)
			var steps := 12
			pts.append(Vector2.ZERO)
			for i in range(steps + 1):
				var a := -half + (2.0 * half) * float(i) / float(steps)
				pts.append(Vector2(cos(a), sin(a)) * reach)
		_:
			rotation = 0.0
			# CIRCLE HONESTO (COMBAT_HONESTY_PASS_01): se `reach` foi configurado (>0), o anel desenha o RAIO REAL
			# de acerto (o chamador passa attack_range×1.2) — o telegraph não mente mais. Senão usa `radius` legado.
			var cr: float = reach if reach > 0.0 else radius
			for i in range(24):
				var a := TAU * float(i) / 24.0
				# elipse achatada (perspectiva top-down) descendo um tico p/ os "pés"
				pts.append(Vector2(cos(a) * cr, sin(a) * cr * 0.55 + cr * 0.35))
	_poly.polygon = pts
	_poly.color = Color(warn_color.r, warn_color.g, warn_color.b, 0.0)
	_poly.scale = Vector2.ONE
	# POLISH_PASS_02A — o contorno espelha o MESMO polígono local (fechado), com a mesma escala/rotação do fill
	if _outline != null:
		var op := PackedVector2Array(pts)
		if op.size() > 0:
			op.append(pts[0])   # fecha o laço (Line2D.closed varia entre versões — fechar à mão é seguro)
		_outline.points = op
		_outline.scale = Vector2.ONE
		_outline.default_color = Color(warn_color.r, warn_color.g, warn_color.b, 0.0)

## Começa o aviso por `dur` segundos (reconstrói a forma corrente).
func begin(dur: float) -> void:
	_rebuild()
	_dur = maxf(0.06, dur)
	_t = _dur
	active = true
	visible = true

## Cancela o aviso (morte, diálogo, etc.) sem disparar.
func cancel() -> void:
	active = false
	visible = false
	_t = 0.0

# ── GEOMETRIA DAS FORMAS (estática, compartilhada por Mob/Wolf/Golem — TELEGRAPH_SHAPES/BOSS_IDENTITY) ──
## Distância de um ponto ao segmento [a,b] (clamp t∈[0,1] = só o trecho da investida).
static func dist_point_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	var t := 0.0
	if denom > 0.0001:
		t = clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)

## O alvo está dentro da FAIXA [origin → origin+aim·reach] com meia-largura `hw`? ("saia da trajetória")
static func in_line(target: Vector2, origin: Vector2, aim: Vector2, reach: float, hw: float) -> bool:
	var dir := aim.normalized() if aim.length() > 0.001 else Vector2.DOWN
	return dist_point_seg(target, origin, origin + dir * reach) <= hw

## O alvo está dentro do LEQUE frontal (raio `reach`, abertura `cone_deg`) em torno de `aim`? ("não fique na frente")
static func in_cone(target: Vector2, origin: Vector2, aim: Vector2, reach: float, cone_deg: float) -> bool:
	var to := target - origin
	if to.length() > reach:
		return false
	if to.length() < 0.001:
		return true
	var dir := aim.normalized() if aim.length() > 0.001 else Vector2.DOWN
	return rad_to_deg(absf(to.normalized().angle_to(dir))) <= cone_deg * 0.5

func _process(delta: float) -> void:
	if not active:
		return
	_t -= delta
	var p := 1.0 - clampf(_t / _dur, 0.0, 1.0)   # 0 → 1 ao longo do windup
	# POLISH_PASS_02A — SALIÊNCIA (só leitura): fill mais forte + PULSO rápido ("alarme") + contorno quente que
	# acompanha. NÃO toca a geometria/scale/rotação (a hitbox = in_line/in_cone segue idêntica).
	var pulse := 0.5 + 0.5 * sin(_t * 26.0)   # pisca rápido enquanto carrega = "perigo"
	if _poly != null:
		_poly.color.a = (0.20 + 0.55 * p) * (0.82 + 0.18 * pulse)
		match shape:
			"line":
				_poly.scale = Vector2(0.30 + 0.70 * p, 1.0)   # CRESCE no comprimento → "a investida vai por aqui"
			"cone":
				_poly.scale = Vector2.ONE * (0.74 + 0.26 * p)  # o leque "enche" pulsando
			_:
				_poly.scale = Vector2.ONE * (0.62 + 0.50 * p)  # anel cresce (legado)
	if _outline != null and _poly != null:
		_outline.scale = _poly.scale   # acompanha o fill exatamente → fica alinhado
		var oa := (0.30 + 0.45 * p) * (0.6 + 0.4 * pulse)
		_outline.default_color = Color(1.0, 0.5, 0.36, oa)   # borda quente clara = a "moldura do perigo"
	if _t <= 0.0:
		active = false
		visible = false
		fired.emit()
