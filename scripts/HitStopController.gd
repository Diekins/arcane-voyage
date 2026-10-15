class_name HitStopController extends Node
## HitStopController — hit-stop LOCAL (FATIA A3.75). Substitui o antigo `Engine.time_scale = 0.05` GLOBAL.
##
## PROBLEMA (blocker p/ a A4): o freeze-frame de impacto desacelerava o JOGO INTEIRO (a 5%), o que
## brigaria com a velocidade idle x2/x3, os timers, o AutoPlay, o auto-revive, cooldowns e o autosave.
##
## SOLUÇÃO: congela SÓ o ATOR atingido por um instante (o nó fica PROCESS_MODE_DISABLED → seu _process E a
## AnimatedSprite2D filha param = freeze-frame local). `Engine.time_scale` NUNCA é tocado (permanece 1.0).
## Timer em TEMPO REAL (ignore_time_scale + process_always) garante o descongelamento. Guard por instância
## evita re-congelar (nunca "trava" um ator).

var _frozen: Dictionary = {}   # instance_id -> process_mode original

## Congela `node` por `dur` segundos (tempo real). No-op se já congelado / inválido.
func freeze(node: Node, dur: float) -> void:
	if node == null or not is_instance_valid(node) or dur <= 0.0:
		return
	var key := node.get_instance_id()
	if _frozen.has(key):
		return
	_frozen[key] = node.process_mode
	node.process_mode = Node.PROCESS_MODE_DISABLED
	# timer REAL (proc_always=true, ignore_time_scale=true) → restaura mesmo se algo mudasse o tempo.
	# Usa o SceneTree via Engine.get_main_loop() (robusto mesmo se get_tree() estiver nulo no instante).
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		if is_instance_valid(node):
			node.process_mode = _frozen[key]
		_frozen.erase(key)
		return
	await tree.create_timer(dur, true, false, true).timeout
	if _frozen.has(key):
		if is_instance_valid(node):
			node.process_mode = _frozen[key]
		_frozen.erase(key)

## Está congelando algum ator agora?
func is_freezing() -> bool:
	return not _frozen.is_empty()
