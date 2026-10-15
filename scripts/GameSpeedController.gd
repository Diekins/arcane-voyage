class_name GameSpeedController extends Node
## GameSpeedController — a ÚNICA autoridade da VELOCIDADE de gameplay (FATIA A4).
##
## A3.75 tirou o `Engine.time_scale` das mãos do hit-stop (agora local). Este controlador é o ÚNICO writer
## de `Engine.time_scale` no jogo — x1/x2/x3 aceleram a SIMULAÇÃO (combate/cooldowns/movimento/IA/progressão
## de fase/AutoPlay), que rodam por `delta` (escalado pelo time_scale).
##
## O que NÃO acelera (roda em TEMPO REAL, imune ao time_scale):
##   • autosave/debounce do GameState (usa Time.get_ticks_msec — A4/§24);
##   • hit-stop (HitStopController usa timer real ignore_time_scale — A3.75/§26);
##   • toasts/UI técnicos que optarem por process_always/tempo real.
##
## Persistência: `GameState.game_speed` (campo opcional, default 1.0; valor inválido → x1 no boot).

signal speed_changed(mult: float)

const SPEEDS := [1.0, 2.0, 3.0]

var _speed := 1.0

func setup(_host = null) -> void:
	# aplica a velocidade PERSISTIDA (já validada no load do GameState → 1/2/3, senão 1).
	var saved := 1.0
	var gs = _gs()
	if gs != null:
		saved = float(gs.game_speed)
	apply_speed(saved, false)   # aplica sem re-persistir (já veio do save)

## Define a velocidade (1.0/2.0/3.0). Valor inválido → x1 (§52-T10). `persist` grava no save (via flush).
func apply_speed(mult: float, persist: bool = true) -> void:
	if not SPEEDS.has(mult):
		mult = 1.0
	_speed = mult
	Engine.time_scale = mult   # ★ ÚNICO ponto que escreve Engine.time_scale no jogo
	var gs = _gs()
	if gs != null and persist:
		gs.game_speed = mult
		gs.save_game()      # marca sujo (debounced) — preferência do jogador não exige flush imediato
	speed_changed.emit(mult)

func get_speed() -> float:
	return _speed

## Índice atual (0=x1,1=x2,2=x3). (NÃO usar get_index — colide com Node.get_index.)
func speed_index() -> int:
	var i := SPEEDS.find(_speed)
	return i if i >= 0 else 0

## Cicla x1→x2→x3→x1.
func cycle() -> void:
	apply_speed(SPEEDS[(speed_index() + 1) % SPEEDS.size()])

func label() -> String:
	return "x%d" % int(_speed)

func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null
