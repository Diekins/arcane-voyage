class_name ArenaRankPerkPolicy extends RefCounted
## FATIA A12 — POLÍTICA de perks por rank (§34-36). ★ INVARIANTE ABSOLUTA: NENHUM perk de rank dá COMBAT POWER em
## Ranked (§34). Só contrato/entitlement nesta foundation — NÃO altera a economia A7.2 (§35). Tipos permitidos V1:
## social/cosmetic/city-utility/future-convenience. Bônus econômico (+gold/+offline/+craft/+loot) fica
## ECONOMY_CALIBRATION_REQUIRED (§36). PVP_DAMAGE/PVP_HP/PVP_CRIT são PROIBIDOS.

const KIND_SOCIAL := "SOCIAL"
const KIND_COSMETIC := "COSMETIC"
const KIND_CITY := "CITY_UTILITY"
const KIND_CONVENIENCE := "FUTURE_CONVENIENCE"
const KIND_ECONOMY := "ECONOMY_CALIBRATION_REQUIRED"   # documentado, NÃO ativado

# perks PROIBIDOS de existir em Ranked (combat power)
const FORBIDDEN := ["PVP_DAMAGE", "PVP_HP", "PVP_CRIT", "PVP_MITIGATION", "PVP_SPEED"]

## Entitlements por rank (só IDs + kind; sem efeito de combate). Exemplo seguro: CITY_MOVE_SPEED (§35).
const RANK_PERKS := {
	"RANK_1": [],
	"RANK_2": [{"id": "CITY_MOVE_SPEED", "kind": KIND_CITY, "active": true}],
	"RANK_3": [{"id": "CITY_MOVE_SPEED", "kind": KIND_CITY, "active": true}],
	"RANK_4": [{"id": "CITY_MOVE_SPEED", "kind": KIND_CITY, "active": true}, {"id": "ARENA_NAMEPLATE_TINT", "kind": KIND_COSMETIC, "active": true}],
	"RANK_5": [{"id": "CITY_MOVE_SPEED", "kind": KIND_CITY, "active": true}, {"id": "ARENA_NAMEPLATE_TINT", "kind": KIND_COSMETIC, "active": true}],
	"RANK_6": [{"id": "CITY_MOVE_SPEED", "kind": KIND_CITY, "active": true}, {"id": "ARENA_EMOTE_SLOT", "kind": KIND_SOCIAL, "active": true}],
	"RANK_7": [{"id": "CITY_MOVE_SPEED", "kind": KIND_CITY, "active": true}, {"id": "ARENA_EMOTE_SLOT", "kind": KIND_SOCIAL, "active": true}, {"id": "ARENA_ECONOMY_BONUS", "kind": KIND_ECONOMY, "active": false}],
}

static func perks_for(rank_id: String) -> Array:
	return RANK_PERKS.get(rank_id, []).duplicate(true)

## Um perk pode dar poder de combate em Ranked? SEMPRE false para perks válidos (invariante §34).
static func grants_combat_power(perk_id: String) -> bool:
	return FORBIDDEN.has(perk_id)   # só os proibidos "dariam" — e por isso não existem no catálogo

## Auditoria: nenhum perk do catálogo é de combate, e nenhum econômico está ativo (§36).
static func audit_no_combat_power() -> bool:
	for rid in RANK_PERKS:
		for p in RANK_PERKS[rid]:
			if FORBIDDEN.has(str(p["id"])):
				return false
			if str(p["kind"]) == KIND_ECONOMY and bool(p.get("active", false)):
				return false   # econômico não pode estar ativo antes da calibração (§36)
	return true
