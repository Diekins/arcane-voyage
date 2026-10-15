class_name InputRouter extends RefCounted
## FATIA A14.3 — roteador de input (§65/§66). Game Action ↓ InputRouter ├─ KeyboardMouse ├─ Touch. Multitouch com
## OWNERSHIP de dedo (§76/§77): cada toque pertence a um alvo; o joystick não rouba o dedo de um botão. IDLE não
## expõe joystick/skill (§69/§84). Touch consumido por UI NÃO vira clique no mundo (§INPUT-T06). Preserva teclado
## desktop (§67). last_input_method p/ prompts/telemetria (§80, nunca altera MMR). Puro/testável (eventos sintéticos).

var joystick: TouchJoystick = null
var joystick_region: Rect2 = Rect2()
var _buttons: Array = []                 # TouchButton
var _finger_owner: Dictionary = {}       # finger_id → "__joy" | button_id | "__world"
var emitted: Array = []                  # [{action, source}]
var last_input_method := PlatformCapabilities.INPUT_KB_MOUSE
var active_space := true                 # false = IDLE (joystick/skill cluster OCULTOS §69)

func set_joystick(j: TouchJoystick, region: Rect2) -> void:
	joystick = j; joystick_region = region

func add_button(b: TouchButton) -> void:
	_buttons.append(b)

func _emit(action: String, source: String) -> void:
	if action != "": emitted.append({"action": action, "source": source})

# ── TOUCH ──
func touch_down(finger_id: int, pos: Vector2) -> String:
	last_input_method = PlatformCapabilities.INPUT_TOUCH
	# joystick só existe em ACTIVE (§69); em IDLE o toque nessa área não engata joystick
	if active_space and joystick != null and joystick_region.has_point(pos):
		if joystick.press(finger_id, pos):
			_finger_owner[finger_id] = "__joy"; return "__joy"
	for b in _buttons:
		if b.press(finger_id, pos):
			_finger_owner[finger_id] = b.id; return b.id
	# não consumido por UI → clique no mundo (selecionar inimigo §14 TOUCH_READY)
	_finger_owner[finger_id] = "__world"
	_emit(GameActions.TARGET, "world")
	return "__world"

func touch_move(finger_id: int, pos: Vector2) -> void:
	if str(_finger_owner.get(finger_id, "")) == "__joy" and joystick != null:
		joystick.drag(finger_id, pos)

func touch_up(finger_id: int, pos: Vector2) -> void:
	var owner := str(_finger_owner.get(finger_id, ""))
	if owner == "__joy" and joystick != null:
		joystick.release(finger_id)
	elif owner != "" and owner != "__world":
		for b in _buttons:
			if b.id == owner and b.release(finger_id, pos):
				_emit(b.action, "touch")
	_finger_owner.erase(finger_id)

func owner_of(finger_id: int) -> String:
	return str(_finger_owner.get(finger_id, ""))

# ── KEYBOARD (desktop preservado §67/§INPUT-T01) ──
func key_down(key: String) -> String:
	last_input_method = PlatformCapabilities.INPUT_KB_MOUSE
	var a := GameActions.action_for_key(key)
	_emit(a, "keyboard")
	return a

func last_action() -> Dictionary:
	return emitted[-1].duplicate() if emitted.size() > 0 else {}

func clear() -> void:
	emitted.clear(); _finger_owner.clear()
