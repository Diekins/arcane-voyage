class_name PlatformCapabilities extends RefCounted
## FATIA A14.0 — modelo de PLATAFORMA centralizado (§1/§2). ★ A UI pergunta AQUI, nunca espalha OS.has_feature por
## 30 arquivos. DESKTOP/MOBILE/WEB + capability flags INDEPENDENTES (§1: tablet pode ter teclado/mouse ⇒ MOBILE ≠
## TOUCH-ONLY). Detecção via APIs oficiais Godot; override explícito p/ testar layouts sem aparelho (§79, dev-only,
## nunca vira produção por acidente — precisa ser setado à mão).

const DESKTOP := "DESKTOP"
const MOBILE := "MOBILE"
const WEB := "WEB"

# override de teste (dev): {platform, has_touch, has_mouse, has_keyboard}. Vazio = detecção real.
static var _override: Dictionary = {}

static func set_override(o: Dictionary) -> void: _override = o.duplicate(true)
static func clear_override() -> void: _override = {}
static func has_override() -> bool: return not _override.is_empty()

## Plataforma real (ou override). WEB tem precedência (roda dentro do browser, mesmo em celular).
static func platform() -> String:
	if _override.has("platform"): return str(_override["platform"])
	if OS.has_feature("web"): return WEB
	if OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]: return MOBILE
	return DESKTOP

static func is_desktop() -> bool: return platform() == DESKTOP
static func is_mobile() -> bool: return platform() == MOBILE
static func is_web() -> bool: return platform() == WEB

static func has_touch() -> bool:
	if _override.has("has_touch"): return bool(_override["has_touch"])
	return DisplayServer.has_feature(DisplayServer.FEATURE_TOUCHSCREEN) or OS.has_feature("mobile")

static func has_mouse() -> bool:
	if _override.has("has_mouse"): return bool(_override["has_mouse"])
	return DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE)

static func has_keyboard() -> bool:
	if _override.has("has_keyboard"): return bool(_override["has_keyboard"])
	# desktop/web assumem teclado físico; mobile só se houver hardware (não detectável com certeza → usa mouse como proxy)
	return is_desktop() or is_web() or has_mouse()

## Modo de APRESENTAÇÃO (§42): TOUCH quando há toque e NÃO há mouse; senão POINTER (densidade menor no PC).
const PRESENT_TOUCH := "TOUCH"
const PRESENT_POINTER := "POINTER"
static func presentation() -> String:
	if _override.has("presentation"): return str(_override["presentation"])
	return PRESENT_TOUCH if (has_touch() and not has_mouse()) else PRESENT_POINTER

## Método de input atual p/ prompts/telemetria (§80) — NÃO altera MMR.
const INPUT_KB_MOUSE := "KEYBOARD_MOUSE"
const INPUT_TOUCH := "TOUCH"
const INPUT_GAMEPAD_FUTURE := "GAMEPAD_FUTURE"
static func default_input_method() -> String:
	return INPUT_TOUCH if presentation() == PRESENT_TOUCH else INPUT_KB_MOUSE

static func summary() -> Dictionary:
	return {"platform": platform(), "presentation": presentation(), "has_touch": has_touch(), "has_mouse": has_mouse(), "has_keyboard": has_keyboard(), "input_method": default_input_method()}
