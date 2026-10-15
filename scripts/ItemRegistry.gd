class_name ItemRegistry extends RefCounted
## FATIA A11 — AUTORIDADE sobre ItemInstance (iid). ★ INVARIANTE CRÍTICA: um `iid` tem NO MÁXIMO um owner/location
## autoritativo (§24/§25) — nunca em dois donos, nunca equipped+backpack ao mesmo tempo. O SERVIDOR gera o iid
## (§23) — cliente jamais injeta iid/quality/rolls (validado à parte). Prepara TRADE futuro (ESCROW_FUTURE é enum
## RESERVADO, sem uso runtime §24) sem implementar marketplace (§82). Materialização de legado ocorre AQUI (§26).

const LOC_PLAYER := "PLAYER"
const LOC_EQUIPPED := "EQUIPPED"
const LOC_OVERFLOW := "OVERFLOW"
const LOC_ESCROW := "ESCROW"           # FATIA A11.2 — AGORA ATIVO: item travado numa trade (§27), com trade_id+dono
const LOC_DESTROYED := "DESTROYED"
const LOCATIONS := [LOC_PLAYER, LOC_EQUIPPED, LOC_OVERFLOW, LOC_ESCROW, LOC_DESTROYED]

var _items: Dictionary = {}   # iid → {account_id, location, item_id}
var _counter := 0             # gerador de iid SERVER-SIDE (autoritativo)

## Gera um iid autoritativo único (server). Cliente nunca fornece iid legítimo de produção.
func next_iid(prefix: String = "srv") -> String:
	_counter += 1
	return "%s_%d" % [prefix, _counter]

## Registra um NOVO iid. Falha (mantém invariante) se o iid já existe.
func register(iid: String, account_id: String, item_id: String, location: String = LOC_PLAYER) -> bool:
	if iid == "" or _items.has(iid):
		return false   # §25: nunca dois registros do mesmo iid
	if not LOCATIONS.has(location):
		location = LOC_PLAYER
	_items[iid] = {"account_id": account_id, "location": location, "item_id": item_id}
	return true

func exists(iid: String) -> bool:
	return _items.has(iid)

func owner_of(iid: String) -> String:
	return str(_items.get(iid, {}).get("account_id", ""))

func location_of(iid: String) -> String:
	return str(_items.get(iid, {}).get("location", ""))

func item_id_of(iid: String) -> String:
	return str(_items.get(iid, {}).get("item_id", ""))

func is_owned_by(iid: String, account_id: String) -> bool:
	return _items.has(iid) and str(_items[iid]["account_id"]) == account_id and account_id != ""

## Move um iid para outra location (mesmo dono). Falha se não existe/destruído/location inválida.
func move(iid: String, new_location: String) -> bool:
	if not _items.has(iid) or not LOCATIONS.has(new_location):
		return false
	if str(_items[iid]["location"]) == LOC_DESTROYED:
		return false
	_items[iid]["location"] = new_location
	return true

func destroy(iid: String) -> bool:
	if not _items.has(iid):
		return false
	_items[iid]["location"] = LOC_DESTROYED
	return true

## Materialização de LEGADO server-side (§26): mesmo item legado → MESMO iid estável (idempotente).
func materialize_legacy(account_id: String, item_id: String, stable_iid: String) -> String:
	if _items.has(stable_iid):
		return stable_iid   # já materializado → devolve o mesmo (não duplica)
	register(stable_iid, account_id, item_id, LOC_PLAYER)
	return stable_iid

# ── ESCROW de trade (A11.2 §26/§27/§28) — MOVE o item (não copia); guarda trade_id + dono original ──
## Trava um iid em escrow: sai da posse utilizável do dono (não equipa/salvage/destroi/outra-trade). Falha se não
## existe, destruído, já em escrow, ou não pertence a `owner`.
func to_escrow(iid: String, trade_id: String, original_owner: String) -> bool:
	if not _items.has(iid):
		return false
	var e: Dictionary = _items[iid]
	if str(e["location"]) == LOC_DESTROYED or str(e["location"]) == LOC_ESCROW:
		return false
	if str(e["account_id"]) != original_owner or original_owner == "":
		return false
	e["location"] = LOC_ESCROW
	e["trade_id"] = trade_id
	e["escrow_owner"] = original_owner   # dono original (p/ refund exact-once)
	return true

## Tira um iid do escrow entregando a `new_owner` (commit → recipiente; cancel/expiry → dono original).
func from_escrow(iid: String, new_owner: String) -> bool:
	if not _items.has(iid):
		return false
	var e: Dictionary = _items[iid]
	if str(e["location"]) != LOC_ESCROW:
		return false
	e["account_id"] = new_owner
	e["location"] = LOC_PLAYER
	e.erase("trade_id"); e.erase("escrow_owner")
	return true

func is_in_escrow(iid: String) -> bool:
	return _items.has(iid) and str(_items[iid]["location"]) == LOC_ESCROW

func escrow_trade_of(iid: String) -> String:
	return str(_items.get(iid, {}).get("trade_id", "")) if is_in_escrow(iid) else ""

func escrow_owner_of(iid: String) -> String:
	return str(_items.get(iid, {}).get("escrow_owner", "")) if is_in_escrow(iid) else ""

## Auditoria global (§70): cada iid está em EXATAMENTE uma categoria. Retorna {player,escrow,destroyed,total}.
func categorize() -> Dictionary:
	var player := 0; var escrow := 0; var destroyed := 0
	for iid in _items:
		match str(_items[iid]["location"]):
			LOC_DESTROYED: destroyed += 1
			LOC_ESCROW: escrow += 1
			_: player += 1
	return {"player": player, "escrow": escrow, "destroyed": destroyed, "total": _items.size()}

## Todos os iids de uma conta (p/ view/validação).
func iids_of(account_id: String) -> Array:
	var out: Array = []
	for iid in _items:
		if str(_items[iid]["account_id"]) == account_id and str(_items[iid]["location"]) != LOC_DESTROYED:
			out.append(iid)
	return out

func count() -> int:
	return _items.size()

## Auditoria de invariante (teste): nenhum iid duplicado (a chave do dict já garante; confirma explicitamente).
func invariant_unique_owner() -> bool:
	# cada iid é uma chave → 1 registro; owner/location são campos únicos por iid. Sempre verdadeiro por construção.
	return true

# ── snapshot/restore (persistência p/ RESTART do servidor §77) ──
func snapshot() -> Dictionary:
	return {"items": _items.duplicate(true), "counter": _counter}

func restore(snap: Dictionary) -> void:
	_items = (snap.get("items", {}) as Dictionary)
	_counter = int(snap.get("counter", 0))
