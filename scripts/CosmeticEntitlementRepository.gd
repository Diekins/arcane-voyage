class_name CosmeticEntitlementRepository extends RefCounted
## FATIA A13 — ENTITLEMENTS de cosmético (§50-53,62). Conceito: account OWNS cosmetic_id (§51) — cosméticos são
## ACCOUNT-WIDE (§62), separados do progression state. Opções BÁSICAS não dependem de entitlement (§52). Premium
## futuros (skin/outfit/hair especial/aura/trail/mount/pet/frame) liberados por entitlement — mas NENHUM tem combat
## stats (§53). NÃO existe loja/checkout/R$/currency (§55). Grant idempotente. Persist p/ restart (§83).

# cosméticos BÁSICOS — sempre "owned" por qualquer conta (§52), nunca premium.
const BASE_COSMETICS := ["", "OUTFIT_1", "OUTFIT_2", "OUTFIT_3", "OUTFIT_4", "HAIR_0", "HAIR_1", "HAIR_2", "HAIR_3", "HAIR_4", "HAIR_5"]

var _owned: Dictionary = {}   # account_id → {cosmetic_id: true}

func _ensure(account_id: String) -> void:
	if not _owned.has(account_id):
		_owned[account_id] = {}

## Concede um cosmético a uma conta (idempotente §92-COS-T02). Sem pagamento (§55) — dev/test/entitlement.
func grant(account_id: String, cosmetic_id: String) -> Dictionary:
	_ensure(account_id)
	if (_owned[account_id] as Dictionary).has(cosmetic_id):
		return {"ok": true, "already": true}
	_owned[account_id][cosmetic_id] = true
	return {"ok": true}

## A conta possui/tem direito ao cosmético? Básicos sempre sim (§52); premium só se concedido (§92).
func owns(account_id: String, cosmetic_id: String) -> bool:
	if BASE_COSMETICS.has(cosmetic_id):
		return true
	_ensure(account_id)
	return (_owned[account_id] as Dictionary).has(cosmetic_id)

## Poder de combate do cosmético = SEMPRE 0 (§53/§58).
func combat_power(_cosmetic_id: String) -> int:
	return 0

func snapshot() -> Dictionary:
	return {"owned": _owned.duplicate(true)}

func restore(snap: Dictionary) -> void:
	_owned = (snap.get("owned", {}) as Dictionary)
