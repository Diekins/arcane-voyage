class_name GameActions extends RefCounted
## FATIA A14.3 — camada SEMÂNTICA de input (§65). Regra de jogo fala em AÇÃO, não em KEY_*/MOUSE_*. Adapters
## (teclado/mouse, toque) traduzem para estas ações. Gamepad = FUTURE (§66). NÃO reescreve o PlayerController (§67):
## é a fundação para CITY/ARENA touch (§73) sem nova API de gameplay.

const MOVE := "MOVE"
const INTERACT := "INTERACT"
const BASIC_ATTACK := "BASIC_ATTACK"
const SKILL_1 := "SKILL_1"
const SKILL_2 := "SKILL_2"
const SKILL_3 := "SKILL_3"
const DODGE := "DODGE"
const TARGET := "TARGET"
const CANCEL_TARGET := "CANCEL_TARGET"
const UI_BACK := "UI_BACK"
const UI_CONFIRM := "UI_CONFIRM"
const AUTO_TOGGLE := "AUTO_TOGGLE"
const GAME_SPEED := "GAME_SPEED"
const RETRY_WALL := "RETRY_WALL"
const RECOVER := "RECOVER"

## Mapa de teclado ATUAL (§13.2) → ação semântica. Preserva os controles de desktop (§67/§INPUT-T01).
const KEY_MAP := {
	"J": BASIC_ATTACK, "1": SKILL_1, "2": SKILL_2, "3": SKILL_3,
	"SPACE": DODGE, "TAB": TARGET, "K": CANCEL_TARGET, "E": INTERACT,
	"R": RECOVER, "P": AUTO_TOGGLE, "T": RETRY_WALL, "ESCAPE": UI_BACK, "ENTER": UI_CONFIRM,
}
# WASD/setas → MOVE (tratadas à parte por serem contínuas)
const MOVE_KEYS := ["W", "A", "S", "D", "UP", "DOWN", "LEFT", "RIGHT"]

static func action_for_key(key: String) -> String:
	var k := key.to_upper()
	if MOVE_KEYS.has(k): return MOVE
	return str(KEY_MAP.get(k, ""))

## Ações que NÃO aparecem no IDLE (§69): o joystick/skill cluster só existe em ACTIVE (city/arena).
const ACTIVE_ONLY := [MOVE, BASIC_ATTACK, SKILL_1, SKILL_2, SKILL_3, DODGE]
static func is_active_only(action: String) -> bool:
	return ACTIVE_ONLY.has(action)
