class_name TradeRepository extends RefCounted
## FATIA A11.2 — PERSISTÊNCIA AUTORITATIVA de trades/escrow (§9). Vive FORA do save do personagem (§113). Guarda o
## registro completo de cada trade + o índice "1 trade ativa por character" (§17). O escrow guarda a INSTÂNCIA
## EXATA do item (§28) para transferir o MESMO iid/quality/rolls no commit — nunca reroll. In-memory p/ bancada,
## com persist p/ arquivo (recovery de RESTART §40/§81). trade_id é gerado server-side (§10).

var _trades: Dictionary = {}     # trade_id → record
var _by_char: Dictionary = {}    # character_id → trade_id ativo (§17)
var _counter := 0
var _rng := RandomNumberGenerator.new()

func setup(rng_seed: int = 313131) -> void:
	_rng.seed = rng_seed

func new_trade_id() -> String:
	_counter += 1
	return "trade_%d_%08x" % [_counter, _rng.randi()]

func put(record: Dictionary) -> void:
	_trades[str(record["trade_id"])] = record

func has(trade_id: String) -> bool:
	return _trades.has(trade_id)

func get_trade(trade_id: String) -> Dictionary:
	return _trades.get(trade_id, {})

func remove(trade_id: String) -> void:
	_trades.erase(trade_id)

func active_trade_of(character_id: String) -> String:
	return str(_by_char.get(character_id, ""))

func set_active(character_id: String, trade_id: String) -> void:
	_by_char[character_id] = trade_id

func clear_active(character_id: String) -> void:
	_by_char.erase(character_id)

func all_ids() -> Array:
	return _trades.keys()

# ── snapshot/restore + persistência (recovery de RESTART §40/§81) ──
func snapshot() -> Dictionary:
	return {"trades": _trades.duplicate(true), "by_char": _by_char.duplicate(true), "counter": _counter}

func restore(snap: Dictionary) -> void:
	_trades = (snap.get("trades", {}) as Dictionary)
	_by_char = (snap.get("by_char", {}) as Dictionary)
	_counter = int(snap.get("counter", 0))

func persist_to(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(snapshot())); f.close()
	return true

func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return false
	var j = JSON.parse_string(f.get_as_text()); f.close()
	if typeof(j) != TYPE_DICTIONARY: return false
	restore(j)
	return true
