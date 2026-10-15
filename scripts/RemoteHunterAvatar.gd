class_name RemoteHunterAvatar extends Node2D
## FATIA A16.1E — AVATAR REAL de outro player AFK (§25-32). ★ Node de verdade: quando um HuntPresenceSnapshot chega,
## o cliente CRIA/atualiza este node no anchor do SERVIDOR (§27 — client não escolhe transform). Visual = public
## appearance + public CharacterVisualState (§28) via HDCharacterRenderContract; se o asset HD não existe (Codex
## pendente), usa FALLBACK (placeholder), mas o node APARECE. Anima IDLE/ATTACK/SKILL/HIT/DEATH/REVIVE por action
## event (§29). NUNCA gera reward local (§32). Remoção sem ghost (§31).

var character_id := ""
var relationship := "OTHER"
var _current_action := "IDLE"
var _layers: Dictionary = {}   # render_layer (HDCharacterRenderContract.LAYERS) → Node2D (placeholder até o Codex entregar)
var _visuals: Dictionary = {}  # EquipmentVisual slot → visual_id resolvido (o que o CharacterVisualState derivou)

# render layer (contrato HD) → slot do CharacterVisualState/EquipmentVisual. Shadow/Cosmetic não têm slot de equip.
const LAYER_SLOT := {
	"Body": "BODY", "Legs": "LEGS", "Boots": "BOOTS", "Chest": "CHEST",
	"Hair": "HAIR", "Head": "HEAD", "MainHand": "MAIN_HAND", "OffHand": "OFF_HAND",
}

## Aplica um snapshot público. Cria/atualiza os layers e posiciona no anchor server-side (§27).
func apply_snapshot(snap: Dictionary) -> void:
	character_id = str(snap.get("character_id", ""))
	relationship = str(snap.get("relationship", "OTHER"))
	position = snap.get("anchor", Vector2.ZERO)   # ANCHOR do servidor — não do cliente
	_build_layers(snap.get("visual_state", {}))
	set_action(str(snap.get("action", "IDLE")))

func _build_layers(visual_state: Dictionary) -> void:
	# ordem/z do contrato HD; cada layer é um node REAL (placeholder — arte final = Codex, hot-swap §43)
	var z := HDCharacterRenderContract.z_order_for_direction("down")
	for lname in HDCharacterRenderContract.LAYERS:
		var slot := str(LAYER_SLOT.get(lname, ""))
		var vid := str(visual_state.get(slot, "")) if slot != "" else ""
		if not _layers.has(lname):
			var n := Node2D.new(); n.name = lname; add_child(n); _layers[lname] = n
		var layer: Node2D = _layers[lname]
		layer.z_index = int(z.get(lname, 10))
		var resolved := vid if vid != "" else str(HDCharacterRenderContract.authorized_actor_key(vid)["key"])
		layer.set_meta("visual_id", resolved)
		layer.set_meta("fallback", vid == "" or bool(HDCharacterRenderContract.authorized_actor_key(vid)["fallback"]))
		if slot != "": _visuals[slot] = resolved

func set_action(action: String) -> void:
	# só apresentação (§29); NUNCA reward (§32)
	_current_action = action
	set_meta("action", action)

func current_action() -> String: return _current_action
func layer_count() -> int: return _layers.size()
## Consulta por SLOT do CharacterVisualState (ex.: EquipmentVisual.SLOT_MAIN_HAND).
func visual_id_of(slot: String) -> String:
	return str(_visuals.get(slot, ""))

## Poder de combate do avatar remoto = 0 (§32 — evento visual não altera economia).
func combat_power() -> int: return 0

func remove() -> void:
	queue_free()   # sem ghost (§31)
