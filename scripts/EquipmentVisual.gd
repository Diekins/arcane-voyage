class_name EquipmentVisual extends RefCounted
## FATIA A15.4 — CONTRATO de equipamento visual modular (§45-59). ★ NÃO integra assets Codex (§45): só a arquitetura
## que permitirá DEPOIS mostrar o equipamento REAL no personagem sem refazer Character/Class/Equipment. O visual do
## item vem do item_id via CATÁLOGO server-side (§46/§57) — nunca de visual_id/path enviado pelo cliente. sword_A e
## sword_B (mesma família) PODEM ter visual_id diferente (§46/VIS-T01). Fallback previsível, sem crash (§52). 0 CP
## (§64) — visual nunca dá stat.

# slots VISUAIS (§45). Opcionais/futuros: GLOVES/CAPE/BACK/AURA/COSMETIC_OVERLAY.
const SLOT_BODY := "BODY"
const SLOT_HAIR := "HAIR"
const SLOT_HEAD := "HEAD"
const SLOT_CHEST := "CHEST"
const SLOT_LEGS := "LEGS"
const SLOT_BOOTS := "BOOTS"
const SLOT_MAIN_HAND := "MAIN_HAND"
const SLOT_OFF_HAND := "OFF_HAND"
const VISUAL_SLOTS := [SLOT_BODY, SLOT_HAIR, SLOT_HEAD, SLOT_CHEST, SLOT_LEGS, SLOT_BOOTS, SLOT_MAIN_HAND, SLOT_OFF_HAND]

# mapa slot-de-equipamento (ItemDB) → slot VISUAL
const EQUIP_TO_VISUAL := {"weapon": SLOT_MAIN_HAND, "offhand": SLOT_OFF_HAND, "head": SLOT_HEAD, "chest": SLOT_CHEST, "legs": SLOT_LEGS, "boots": SLOT_BOOTS}

const FALLBACK := {
	SLOT_MAIN_HAND: "vis_none_mainhand", SLOT_OFF_HAND: "vis_none_offhand", SLOT_HEAD: "vis_none_head",
	SLOT_CHEST: "vis_body_chest", SLOT_LEGS: "vis_body_legs", SLOT_BOOTS: "vis_body_boots",
	SLOT_BODY: "vis_body_default", SLOT_HAIR: "vis_hair_default",
}

## Catálogo de OVERRIDE (item_id → visual_id específico). Vazio hoje (assets do Codex chegam depois); o default já
## dá identidade POR ITEM, então sword_01/02/03 divergem naturalmente (§46). Preenchível sem refactor.
const VISUAL_OVERRIDE := {}

## visual_id AUTORITATIVO de um item (§46/§57). Deriva do item_id ⇒ cada item tem o SEU visual (não por família).
static func visual_id_of(item_id: String) -> String:
	if item_id == "" or not ItemDB.exists(item_id):
		return ""
	if VISUAL_OVERRIDE.has(item_id):
		return str(VISUAL_OVERRIDE[item_id])
	return "vis_" + _safe(item_id)

## Só letras/números/_ — impede path injection (§57). O cliente NUNCA fornece isto; é sempre derivado do item_id.
static func _safe(s: String) -> String:
	var out := ""
	for i in range(s.length()):
		var c := s[i]
		if (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			out += c
	return out

static func is_safe_visual_id(vid: String) -> bool:
	return vid == _safe(vid) and not vid.contains("..") and not vid.contains("/") and not vid.contains("\\")

## EquipmentVisualDescriptor (§48) — sem pixels/base64; só metadata de composição.
static func descriptor(item_id: String) -> Dictionary:
	if not ItemDB.exists(item_id):
		return {}
	var slot_eq := ItemDB.slot_of(item_id)
	var vslot := str(EQUIP_TO_VISUAL.get(slot_eq, ""))
	var fam := str(ItemDB.get_item(item_id).get("weapon_kind", ""))
	return {
		"item_id": item_id, "slot": vslot, "visual_id": visual_id_of(item_id),
		"weapon_family": fam, "actor_compat": "ANY",
		"layer_z": _z_for(vslot), "anchor_profile": ("weapon_" + fam) if fam != "" else vslot.to_lower(),
		"fallback": str(FALLBACK.get(vslot, "vis_body_default")),
	}

# ordem de camada (z) — off_hand atrás, main_hand na frente; corpo/roupa no meio (contrato §53)
static func _z_for(vslot: String) -> int:
	match vslot:
		SLOT_OFF_HAND: return 5
		SLOT_BODY: return 10
		SLOT_LEGS: return 12
		SLOT_BOOTS: return 13
		SLOT_CHEST: return 14
		SLOT_HEAD: return 16
		SLOT_HAIR: return 17
		SLOT_MAIN_HAND: return 20
		_: return 10
