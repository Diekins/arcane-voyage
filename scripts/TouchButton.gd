class_name TouchButton extends RefCounted
## FATIA A14.3 — botão de ação touch (CONTRATO §75). Finger-safe, multitouch, press/release, hook de cooldown futuro.
## NÃO desenha arte de skill (§75). Cada botão captura o SEU dedo; o joystick não pode roubá-lo (§77). Puro/testável.

var id := ""
var action := ""
var region: Rect2 = Rect2()
var min_target_ul := 88.0     # §12 — deve atender o alvo mínimo (validável)
var _finger := -1
var _pressed := false
var cooldown_ready := true    # hook de apresentação de cooldown (§75) — não implementa cooldown de combate

func setup(p_id: String, p_action: String, p_region: Rect2, p_min_target: float = 88.0) -> void:
	id = p_id; action = p_action; region = p_region; min_target_ul = p_min_target

func contains(pos: Vector2) -> bool:
	return region.has_point(pos)

func press(finger_id: int, pos: Vector2) -> bool:
	if _pressed or not contains(pos): return false
	_finger = finger_id; _pressed = true
	return true

## Solta. Retorna true se foi um toque VÁLIDO (soltou dentro da região com o mesmo dedo) → dispara a ação.
func release(finger_id: int, pos: Vector2) -> bool:
	if not _pressed or finger_id != _finger:
		return false
	_pressed = false; _finger = -1
	return contains(pos)

func owns(finger_id: int) -> bool:
	return _pressed and finger_id == _finger

## O botão atende o alvo mínimo de toque? (§41 — todo controle P0 precisa alcançar o mínimo lógico)
func target_ok(presentation: String, tt_class: String = "TT_B") -> bool:
	var m := minf(region.size.x, region.size.y)
	return UiMetrics.target_ok(m, presentation, tt_class)
