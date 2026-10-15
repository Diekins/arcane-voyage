class_name TouchJoystick extends RefCounted
## FATIA A14.3 — joystick virtual (CONTRATO técnico §74). Deadzone, Vector2 normalizado, multitouch-safe, captura de
## dedo. ★ NÃO é a UI final da cidade/Arena (§74) — só prova a abstração de input. Acoplado ao estado MANUAL (não à
## tela §84): não vaza para o IDLE. Puro/testável (alimentado por eventos sintéticos, sem aparelho).

var center: Vector2 = Vector2.ZERO
var radius: float = 80.0
var deadzone: float = 0.15
var _finger := -1            # dedo capturado (multitouch: só responde a ESTE dedo §77)
var _pos: Vector2 = Vector2.ZERO
var _active := false

func setup(p_center: Vector2, p_radius: float = 80.0, p_deadzone: float = 0.15) -> void:
	center = p_center; radius = p_radius; deadzone = p_deadzone

## Pressiona com um dedo. Se já há dedo capturado, IGNORA (não rouba o dedo de ninguém §77).
func press(finger_id: int, pos: Vector2) -> bool:
	if _active: return false
	_finger = finger_id; _pos = pos; _active = true
	return true

## Arrasta — só o dedo dono move o joystick.
func drag(finger_id: int, pos: Vector2) -> void:
	if not _active or finger_id != _finger: return
	_pos = pos

func release(finger_id: int) -> void:
	if finger_id != _finger: return
	_active = false; _finger = -1; _pos = center

func owns(finger_id: int) -> bool:
	return _active and finger_id == _finger

## Vetor normalizado com deadzone (§74). Fora da deadzone → 0..1 escalado pelo raio; clamp em 1.
func value() -> Vector2:
	if not _active: return Vector2.ZERO
	var d := _pos - center
	var mag := d.length()
	if mag < deadzone * radius:
		return Vector2.ZERO
	var n := d / radius
	if n.length() > 1.0: n = n.normalized()
	return n

func is_active() -> bool: return _active
