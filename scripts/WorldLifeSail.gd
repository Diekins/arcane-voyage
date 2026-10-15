extends Node2D
class_name WorldLifeSail
## ─────────────────────────────────────────────────────────────────────────────
## WORLD LIFE — 3º piloto: UMA VELA distante cruza o mar no horizonte da Costa do Sal-Vento.
## Prova ACONTECIMENTO DISTANTE ("tem algo acontecendo lá longe / pra onde aquele barco vai?").
## (caravana provou TRÂNSITO; aves provaram MORADIA.)
##
## ★ Pertence ao MUNDO. Não vem ao jogador, não para, não interage, não tem nome/recompensa.
##   Apenas existe e atravessa, SEMPRE longe (alto no horizonte). Pode ser perdida.
## ★ MMO-first: posição = função DETERMINÍSTICA de Time.get_unix_time_from_system() → todos os
##   jogadores veem a MESMA vela, mesma posição, mesmo momento do ciclo.
##
## SEM: sistema naval / NPC / diálogo / missão / loot / combate / interação / atracação /
## pathfinding / save / UI / marcador / áudio / câmera / Area2D / colisão / framework de eventos.
## ─────────────────────────────────────────────────────────────────────────────

const CYCLE := 300.0            # período longo: o mar fica vazio a maior parte do tempo (raro = especial)
const CROSS := 150.0            # travessia LENTA (distante)
const ENTER_PAD := 180.0        # entra/sai além das bordas (sem pop)
const HORIZON_Y_FRAC := 0.25    # alto na tela (mar distante), mas DENTRO da câmera (1280×720) a partir da praia
const SWAY_AMP := 8.0           # leve balanço do mar
const FADE := 7.0               # fade longo ao surgir/sumir no horizonte (filosofia das aves)
const SIL_COLOR := Color(0.24, 0.24, 0.28, 0.52)   # silhueta enevoada pela distância (não chamativa)
const Z := -1                   # fundo: atrás de props/atores da praia, à frente do chão/água

var _size := Vector2(2200, 1300)
var _sail: Node2D = null
var _time_override := -1.0
var _phase_offset := 0.0        # PRODUÇÃO = 0 (puro/MMO). Só o botão DEV desloca (align_now).
var _setup_done := false

func setup(size: Vector2) -> void:
	if _setup_done:
		return
	_setup_done = true
	_size = size
	_build_sail()
	set_process(true)
	_apply_for_time(_world_time())

func _process(_delta: float) -> void:
	_apply_for_time(_world_time())

func _world_time() -> float:
	if _time_override >= 0.0:
		return _time_override
	return Time.get_unix_time_from_system() + _phase_offset

## DEV-only: desloca o tempo p/ a vela estar entrando agora (teste imediato). Produção nunca chama (offset=0/puro).
func align_now() -> void:
	_phase_offset = 2.0 - fmod(Time.get_unix_time_from_system(), CYCLE)

## Progresso 0..1 da travessia; -1 quando a vela está AUSENTE (mar vazio = acontecimento, não loop).
func progress_at(t: float) -> float:
	var phase := fmod(t, CYCLE)
	if phase < 0.0:
		phase += CYCLE
	if phase >= CROSS:
		return -1.0
	return phase / CROSS

## Posição (centro) p/ um progresso 0..1. PURA função do tempo (determinística). Cruza OESTE→LESTE no horizonte.
func anchor_at(p: float) -> Vector2:
	var x := lerpf(-ENTER_PAD, _size.x + ENTER_PAD, p)
	var y := _size.y * HORIZON_Y_FRAC + sin(p * TAU) * SWAY_AMP
	return Vector2(x, y)

func _apply_for_time(t: float) -> void:
	var p := progress_at(t)
	if p < 0.0:
		visible = false
		return
	visible = true
	position = anchor_at(p)
	var alpha := 1.0
	if p * CROSS < FADE:
		alpha = (p * CROSS) / FADE
	elif p * CROSS > CROSS - FADE:
		alpha = (CROSS - p * CROSS) / FADE
	modulate.a = clampf(alpha, 0.0, 1.0)

# ─── A vela (casco + vela triangular), silhueta distante ─────────────────────
func _build_sail() -> void:
	_sail = Node2D.new()
	_sail.set_meta("av_worldlife", true)
	_sail.z_index = Z
	# WORLDLIFE_PACK_03B: sprite real (vela no horizonte) se existir; senão casco+vela Polygon2D (fallback). O
	# fade/sway/posição (determinísticos) seguem por código sobre _sail/self.
	var path := "res://assets/tilesets/saltwind_shore/props/horizon_sail.png"
	if ResourceLoader.exists(path):
		var s := Sprite2D.new()
		s.texture = load(path)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.offset = Vector2(0.0, -20.0)   # ancora a linha-d'água ~na origem (a vela sobe acima)
		_sail.add_child(s)
	else:
		var hull := Polygon2D.new()
		hull.polygon = PackedVector2Array([Vector2(-10, 0), Vector2(10, 0), Vector2(6, 3), Vector2(-6, 3)])
		hull.color = SIL_COLOR
		_sail.add_child(hull)
		var sail := Polygon2D.new()
		sail.polygon = PackedVector2Array([Vector2(-1, -17), Vector2(-1, -1), Vector2(8, -2)])   # vela triangular inclinada
		sail.color = SIL_COLOR
		_sail.add_child(sail)
	add_child(_sail)

# ─── Introspecção (p/ self-test) ─────────────────────────────────────────────
func is_present_at(t: float) -> bool:
	return progress_at(t) >= 0.0
func horizon_y() -> float:
	return _size.y * HORIZON_Y_FRAC
