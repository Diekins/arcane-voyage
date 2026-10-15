class_name HDCharacterRenderContract extends RefCounted
## FATIA A16.0 — CONTRATO de render HD do personagem (§1-18). ★ Asset HD NÃO pode ser forçado a parecer pixel-art.
## AUDITORIA: o projeto NÃO tem filtro nearest nem pixel-snap (project.godot sem override ⇒ default LINEAR, já
## HD-friendly); ActorAnimator usa UM `_visual` (dívida A15 "1 sprite"). Este contrato formaliza o CharacterVisualRoot
## MODULAR em camadas, o RELÓGIO ÚNICO de animação (§6/§7) e as políticas de filtro/scale/z (§2/§8/§16). NÃO integra
## assets do Codex (CODEX_RUNTIME_ASSETS_REQUIRED) — só a arquitetura para integrá-los sem redesenhar. Reusa A15
## (EquipmentVisual/CharacterVisualState). Puro/testável.

# camadas do CharacterVisualRoot (§5), na ordem base (varia por facing §8)
const LAYERS := ["Shadow", "Body", "Legs", "Boots", "Chest", "Hair", "Head", "MainHand", "OffHand", "Cosmetic"]

# política de filtro (§2): HD usa LINEAR; nearest só onde o asset REALMENTE depender (não é o caso do personagem).
const FILTER_HD := "LINEAR"
const FILTER_PIXEL := "NEAREST"
const MIPMAP_POLICY := "MIPMAP_FIELD_REQUIRED"   # §3 — depende de teste visual em aparelho
const PIXEL_SNAP := false                          # §4 — sem snap de pixel-art destruindo o HD
const CHARACTER_WORLD_SCALE := 1.0                 # §16 — centralizado; tuning de campo depois (HD_SCALE_FIELD_REQUIRED)

## z-ordering por DIREÇÃO (§8): a arma pode ficar atrás (costas) ou na frente (frente). Não "weapon.z=999 sempre".
static func z_order_for_direction(direction: String) -> Dictionary:
	var facing_back := direction in ["up", "north", "back"]
	var z: Dictionary = {}
	for i in range(LAYERS.size()):
		z[LAYERS[i]] = i   # base
	# de costas: mãos vão ATRÁS do corpo; de frente: na frente
	if facing_back:
		z["MainHand"] = 1; z["OffHand"] = 0
	else:
		z["MainHand"] = 20; z["OffHand"] = 5
	return z

## RELÓGIO ÚNICO (§6/§7): um animation_state/frame/direction/flip dirige TODOS os layers. Reusa A15.
static func layer_frames(anim_state: String, frame: int, direction: String, flip: bool) -> Dictionary:
	var base := CharacterVisualState.animation_frame_for_all_layers(anim_state, frame, direction, flip)
	# adiciona z por direção (§8) e a shadow (uma só, §17)
	var z := z_order_for_direction(direction)
	for k in base:
		base[k]["z"] = int(z.get(k, 10))
	base["Shadow"] = {"anim": "shadow", "frame": 0, "direction": direction, "flip": false, "z": 0}   # §17 shadow base única
	return base

## Resolve os visual_ids de um personagem (§9/§10) — DERIVADO de equipment+appearance (A15), catálogo server-side.
static func resolve_visuals(equipment: Dictionary, appearance: Dictionary) -> Dictionary:
	return CharacterVisualState.derive(equipment, appearance)

## Asset resolver seguro (§11): visual_id → recurso AUTORIZADO. Cliente não escolhe path (§57 A15). Fallback (§12).
static func authorized_actor_key(visual_id: String) -> Dictionary:
	if not EquipmentVisual.is_safe_visual_id(visual_id) or visual_id == "":
		return {"key": "vis_body_default", "fallback": true, "reason": "UNSAFE_OR_EMPTY"}
	# como os assets do Codex ainda não existem, tudo cai no fallback previsível (sem crash §12)
	return {"key": visual_id, "fallback": true, "reason": "ASSET_REQUIRED"}

## Poder de combate do render/visual = SEMPRE 0 (§HDR-T12/§HDR-T13).
static func combat_power(_visuals: Dictionary) -> int:
	return 0

## Inspector de debug (§18) — só dados; sem segredo.
static func debug_inspector(character_id: String, class_id: String, anim: String, direction: String, frame: int, visuals: Dictionary) -> Dictionary:
	return {
		"character_id": character_id, "class_id": class_id, "animation": anim, "direction": direction, "frame": frame,
		"visual_ids": visuals.duplicate(true), "scale": CHARACTER_WORLD_SCALE, "filter": FILTER_HD, "pixel_snap": PIXEL_SNAP,
	}
