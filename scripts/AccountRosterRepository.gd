class_name AccountRosterRepository extends RefCounted
## FATIA A13 — ROSTER da conta (§22-27,80-82). A11 formalizou ACCOUNT ≠ CHARACTER; aqui vira roster REAL: uma conta
## possui MÚLTIPLOS characters (§23). Slots gratuitos + entitlement futuro (§24 — sem preço/pagamento §55). ★ O
## `active_progress_character_id` é metadata de CONTA (§82), não do save de cada character. Slot extra NÃO é extra
## farm (§25): apenas 1 progression character ativo por conta (§26). Entitlement idempotente (§81). Persist p/
## restart (§83). Server decide o cap (§80) — cliente nunca envia "tenho 20 slots".

const FREE_CHARACTER_SLOTS := 2
const MAX_CHARACTER_SLOTS := 8   # teto técnico razoável

var _accounts: Dictionary = {}   # account_id → {characters:[cid], slot_entitlements:int, loadout_entitlements:int, active_progress:String, granted:{entitlement_id:true}}

func ensure(account_id: String) -> void:
	if not _accounts.has(account_id):
		_accounts[account_id] = {"characters": [], "slot_entitlements": 0, "loadout_entitlements": 0, "active_progress": "", "granted": {}}

func slot_cap(account_id: String) -> int:
	ensure(account_id)
	return mini(FREE_CHARACTER_SLOTS + int(_accounts[account_id]["slot_entitlements"]), MAX_CHARACTER_SLOTS)

func characters_of(account_id: String) -> Array:
	ensure(account_id)
	return (_accounts[account_id]["characters"] as Array).duplicate()

func owns(account_id: String, character_id: String) -> bool:
	ensure(account_id)
	return (_accounts[account_id]["characters"] as Array).has(character_id)

## Adiciona um character ao roster SE houver slot livre (§24/§80). Server-authoritative.
func add_character(account_id: String, character_id: String) -> Dictionary:
	ensure(account_id)
	if (_accounts[account_id]["characters"] as Array).size() >= slot_cap(account_id):
		return {"ok": false, "reason": "NO_CHARACTER_SLOT"}   # §89 ROST-T04
	if (_accounts[account_id]["characters"] as Array).has(character_id):
		return {"ok": false, "reason": "EXISTS"}
	(_accounts[account_id]["characters"] as Array).append(character_id)
	if str(_accounts[account_id]["active_progress"]) == "":
		_accounts[account_id]["active_progress"] = character_id   # 1º character = ativo por padrão
	return {"ok": true}

func remove_character(account_id: String, character_id: String) -> void:
	ensure(account_id)
	(_accounts[account_id]["characters"] as Array).erase(character_id)

# ── progression ativo (§26-28) ──
func active_progress_of(account_id: String) -> String:
	ensure(account_id)
	return str(_accounts[account_id]["active_progress"])

func set_active_progress(account_id: String, character_id: String) -> Dictionary:
	ensure(account_id)
	if not owns(account_id, character_id):
		return {"ok": false, "reason": "NOT_OWNER"}
	_accounts[account_id]["active_progress"] = character_id
	return {"ok": true}

# ── entitlements (idempotentes §81; sem pagamento §55) ──
func grant_slot_entitlement(account_id: String, entitlement_id: String, slots: int = 1) -> Dictionary:
	ensure(account_id)
	if (_accounts[account_id]["granted"] as Dictionary).has(entitlement_id):
		return {"ok": true, "already": true}   # §81 idempotente — não cria slots infinitos
	_accounts[account_id]["granted"][entitlement_id] = true
	_accounts[account_id]["slot_entitlements"] = int(_accounts[account_id]["slot_entitlements"]) + slots
	return {"ok": true, "slot_cap": slot_cap(account_id)}

func grant_loadout_entitlement(account_id: String, entitlement_id: String, slots: int = 1) -> Dictionary:
	ensure(account_id)
	if (_accounts[account_id]["granted"] as Dictionary).has(entitlement_id):
		return {"ok": true, "already": true}
	_accounts[account_id]["granted"][entitlement_id] = true
	_accounts[account_id]["loadout_entitlements"] = int(_accounts[account_id]["loadout_entitlements"]) + slots
	return {"ok": true}

func loadout_entitlements(account_id: String) -> int:
	ensure(account_id)
	return int(_accounts[account_id]["loadout_entitlements"])

func account_count() -> int: return _accounts.size()

# ── snapshot/restore (restart §83) ──
func snapshot() -> Dictionary:
	return {"accounts": _accounts.duplicate(true)}

func restore(snap: Dictionary) -> void:
	_accounts = (snap.get("accounts", {}) as Dictionary)

func persist_to(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(snapshot())); f.close(); return true

func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return false
	var j = JSON.parse_string(f.get_as_text()); f.close()
	if typeof(j) != TYPE_DICTIONARY: return false
	restore(j); return true
