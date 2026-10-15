class_name InputPromptResolver extends RefCounted
## FATIA A14.3 — resolve PROMPTS de UI por plataforma (§81). "Press E" não pode ser hardcoded: desktop mostra a
## tecla, touch mostra só o rótulo (ou ícone futuro). Uma fonte central; a UI pergunta aqui.

const LABELS := {
	GameActions.INTERACT: "Interagir", GameActions.AUTO_TOGGLE: "AUTO", GameActions.RETRY_WALL: "Tentar novamente",
	GameActions.RECOVER: "Recuperar", GameActions.UI_BACK: "Voltar", GameActions.UI_CONFIRM: "Confirmar",
	GameActions.BASIC_ATTACK: "Atacar", GameActions.DODGE: "Esquivar", GameActions.CANCEL_TARGET: "Soltar alvo",
}
const DESKTOP_KEYS := {
	GameActions.INTERACT: "E", GameActions.AUTO_TOGGLE: "P", GameActions.RETRY_WALL: "T",
	GameActions.RECOVER: "R", GameActions.UI_BACK: "Esc", GameActions.UI_CONFIRM: "Enter",
	GameActions.BASIC_ATTACK: "J", GameActions.DODGE: "Espaço", GameActions.CANCEL_TARGET: "K",
}

## Prompt para uma ação. presentation POINTER → "[E] Interagir"; TOUCH → "Interagir".
static func prompt(action: String, presentation: String = "") -> String:
	var p := presentation if presentation != "" else PlatformCapabilities.presentation()
	var label := str(LABELS.get(action, action))
	if p == PlatformCapabilities.PRESENT_POINTER and DESKTOP_KEYS.has(action):
		return "[%s] %s" % [str(DESKTOP_KEYS[action]), label]
	return label
