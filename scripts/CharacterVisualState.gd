class_name CharacterVisualState extends RefCounted
## FATIA A15.4 — estado visual DERIVADO do personagem (§49/§58). ★ NÃO é 2ª fonte de verdade econômica (§49): é
## SEMPRE derivado de equipment + appearance; NÃO se salva (§58 — equipment/appearance persistem, o visual é
## recalculado). Coerência garantida (§50): o visual da main_hand vem do MESMO item equipado — nunca "visual diz
## espada, equipment diz arco". Cada layer recebe o MESMO animation state (contrato §54). 0 CP (§64).

## Deriva o estado visual completo. `equipment` = {weapon, offhand, head, chest, legs, boots}; `appearance` = dict A13.
static func derive(equipment: Dictionary, appearance: Dictionary) -> Dictionary:
	var vs: Dictionary = {}
	# BODY/HAIR vêm da aparência (A13)
	vs[EquipmentVisual.SLOT_BODY] = "vis_body_" + _safe(str(appearance.get("base_actor_family", "ERRANTE")).to_lower())
	vs[EquipmentVisual.SLOT_HAIR] = "vis_hair_" + _safe(str(appearance.get("hair_style_id", "HAIR_1")).to_lower()) + "_" + _safe(str(appearance.get("hair_color_id", "HC_BROWN")).to_lower())
	# slots de EQUIPAMENTO → visual_id do item real (ou fallback do corpo)
	for eq_slot in EquipmentVisual.EQUIP_TO_VISUAL:
		var vslot := str(EquipmentVisual.EQUIP_TO_VISUAL[eq_slot])
		var item_id := str(equipment.get(eq_slot, ""))
		if item_id != "" and ItemDB.exists(item_id):
			vs[vslot] = EquipmentVisual.visual_id_of(item_id)
		else:
			vs[vslot] = str(EquipmentVisual.FALLBACK.get(vslot, "vis_body_default"))
	# cosmetic override (§56) — só apresentação, 0 poder
	var cos := str(appearance.get("cosmetic_skin_id", ""))
	if cos != "":
		vs["cosmetic_overlay"] = "vis_skin_" + _safe(cos)
	return vs

static func _safe(s: String) -> String:
	var out := ""
	for i in range(s.length()):
		var c := s[i]
		if (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			out += c
	return out

## Coerência (§50): o visual da main_hand corresponde ao item de arma equipado (mesma família).
static func is_consistent(vs: Dictionary, equipment: Dictionary) -> bool:
	var w := str(equipment.get("weapon", ""))
	if w == "": return true
	return str(vs.get(EquipmentVisual.SLOT_MAIN_HAND, "")) == EquipmentVisual.visual_id_of(w)

## Contrato de SYNC de animação (§54): UM animation_state dirige TODOS os layers (mesmo frame/direção/flip).
static func animation_frame_for_all_layers(anim_state: String, frame: int, direction: String, flip: bool) -> Dictionary:
	var out: Dictionary = {}
	for vslot in EquipmentVisual.VISUAL_SLOTS:
		out[vslot] = {"anim": anim_state, "frame": frame, "direction": direction, "flip": flip}
	return out   # nenhum layer escolhe animação sozinho (§54)

## Poder de combate do estado visual = SEMPRE 0 (§64).
static func combat_power(_vs: Dictionary) -> int:
	return 0
