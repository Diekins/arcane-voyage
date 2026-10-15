class_name HuntPresence extends RefCounted
## FATIA A16.5 — PRESENÇA de players AFK próximos (§85-91). AFK não pode parecer single-player: players na MESMA shard
## se veem. ★ NÃO é replicação Arena 60Hz (§87): event-driven + reconciliação de baixa frequência. Snapshot SEGURO
## (§85 — sem account/token/session/inventory/private stats/journal). INTEREST MANAGEMENT (§90): só a MESMA shard +
## clusters próximos. Evento visual NUNCA vale economia (§88). Server-authoritative (§89). Puro/testável.

const REL_PARTY := "PARTY"
const REL_OTHER := "OTHER"

# eventos (§87)
const EV_JOIN := "JOIN"
const EV_LEAVE := "LEAVE"
const EV_EQUIP := "EQUIPMENT_CHANGED"
const EV_ACTION := "ACTION_CHANGED"
const EV_DEATH := "DEATH"
const EV_REVIVE := "REVIVE"
const EV_PARTY := "PARTY_CHANGED"

## Snapshot público seguro (§85) — DERIVA do estado; NUNCA expõe segredo.
static func snapshot(character_id: String, display_name: String, class_id: String, appearance: Dictionary, equipment: Dictionary, spot_id: String, anchor: Vector2, action: String, relationship: String) -> Dictionary:
	return {
		"character_id": character_id, "display_name": display_name, "class_id": class_id,
		"appearance": _public_appearance(appearance),
		"visual_state": CharacterVisualState.derive(equipment, appearance),   # público, derivado (0 poder)
		"spot_id": spot_id, "anchor": anchor, "action": action, "relationship": relationship,
	}

static func _public_appearance(appearance: Dictionary) -> Dictionary:
	# só o que é visível; nada de cosmetic_skin não possuído / campos internos
	return {
		"body_presentation_id": str(appearance.get("body_presentation_id", "")),
		"hair_style_id": str(appearance.get("hair_style_id", "")), "hair_color_id": str(appearance.get("hair_color_id", "")),
		"outfit_palette_id": str(appearance.get("outfit_palette_id", "")), "base_actor_family": str(appearance.get("base_actor_family", "")),
	}

## Verifica que um snapshot NÃO vaza segredo (§85/§PRES-T03).
static func is_safe(snap: Dictionary) -> bool:
	for k in ["account_id", "token", "session", "session_token", "inventory", "journal", "item_instances", "hero_gold"]:
		if snap.has(k): return false
	var txt := JSON.stringify(snap)
	return not (txt.contains("\"acc") or txt.contains("token") or txt.contains("journal"))

## INTEREST MANAGEMENT (§90): retorna só os players da MESMA shard do viewer (nunca todos de todas as shards).
static func interest_set(viewer_shard: String, players: Array) -> Array:
	var out: Array = []
	for p in players:
		if str(p.get("shard_key", "")) == viewer_shard:
			out.append(p)
	return out

## Relacionamento PARTY/OTHER (§91).
static func relationship(viewer: String, other: String, party: HuntParty) -> String:
	return REL_PARTY if party.is_same_party(viewer, other) else REL_OTHER
