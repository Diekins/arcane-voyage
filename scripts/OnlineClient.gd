class_name OnlineClient extends RefCounted
## FATIA A11.1 — FAÇADE do cliente online (§25). Concentra request_id/command_id/envio/espera num só lugar (não
## espalha rede em 30 pontos §25). Cada ação econômica gera um command_id lógico (reusável no retry §26) e um rid
## novo por troca. `pump` é injetado pelo dono do loop (no jogo real = _process; no harness = serviço server+client)
## — a façade não conhece o servidor (Transport ≠ Authority). NUNCA aplica economia local (§24): só manda COMMAND.

var client: GameClient
var pump: Callable                 # func() -> void : bombeia a rede (server+client) uma vez
var default_timeout_ms := 3000
var _cid_counter := 0
var _prefix := "cmd"

func setup(p_client: GameClient, p_pump: Callable, cid_prefix: String = "cmd") -> void:
	client = p_client
	pump = p_pump
	_prefix = cid_prefix

func _auto_cid() -> String:
	_cid_counter += 1
	return "%s_%d" % [_prefix, _cid_counter]

## Espera a resposta de um rid, bombeando a rede até chegar (ou timeout). Retorna o payload da resposta, ou
## {timeout:true} se estourar. `budget` = nº de ciclos de pump (cada um serve a rede uma vez).
func _await(rid: String, timeout_ms: int = 0) -> Dictionary:
	var budget := timeout_ms if timeout_ms > 0 else default_timeout_ms
	var waited := 0
	while waited < budget:
		if pump.is_valid(): pump.call()
		if client.has_response(rid):
			return client.take_response(rid).get("p", {})
		OS.delay_msec(1); waited += 1   # tempo real p/ o loopback mover bytes
	return {"timeout": true}

# ── handshake / sessão ──
func connect_and_login(account: String, timeout_ms: int = 3000) -> Dictionary:
	# espera conexão ENet (tempo real)
	var waited := 0
	while not client.net_connected() and waited < timeout_ms:
		if pump.is_valid(): pump.call()
		OS.delay_msec(1); waited += 1
	if not client.net_connected():
		return {"ok": false, "reason": "NOT_CONNECTED"}
	var h := _await(client.hello())
	var l := _await(client.login(account))
	return {"ok": bool(l.get("ok", false)), "hello": h, "login": l}

func open_character(character_id: String) -> Dictionary:
	var rid := client.open_character(character_id)
	var r := _await(rid)
	# adota o token emitido pelo servidor
	if bool(r.get("ok", false)) and r.has("token"):
		client.session_token = str(r["token"])
		if r.has("view") and int(r.get("revision", -1)) >= 0:
			client.view.apply(int(r["revision"]), r["view"])
	return r

# ── ações econômicas (§25). command_id opcional = retry (§26) ──
func refine(slot: String, catalyst: String = "", command_id: String = "") -> Dictionary:
	var cid := command_id if command_id != "" else _auto_cid()
	return _await(client.command("REFINE_SLOT", cid, {"slot": slot, "catalyst": catalyst}))

func claim_offline(command_id: String = "") -> Dictionary:
	var cid := command_id if command_id != "" else _auto_cid()
	return _await(client.command("CLAIM_OFFLINE", cid, {}))

func prestige(command_id: String = "") -> Dictionary:
	var cid := command_id if command_id != "" else _auto_cid()
	return _await(client.command("PRESTIGE", cid, {}))

func equip(iid: String, command_id: String = "") -> Dictionary:
	var cid := command_id if command_id != "" else _auto_cid()
	return _await(client.command("EQUIP_INSTANCE", cid, {"iid": iid}))

## Comandos INTERNOS pela rede do cliente comum → devem ser NEGADOS (§57/§58). Usado só p/ provar a fronteira.
func try_grant_loot(item_id: String, command_id: String = "") -> Dictionary:
	var cid := command_id if command_id != "" else _auto_cid()
	return _await(client.command("GRANT_LOOT", cid, {"item_id": item_id}))

func try_clear_boss(global_stage: int, command_id: String = "") -> Dictionary:
	var cid := command_id if command_id != "" else _auto_cid()
	return _await(client.command("CLEAR_BOSS", cid, {"global_stage": global_stage}))

func reconnect(token: String) -> Dictionary:
	var r := _await(client.reconnect(token))
	if bool(r.get("ok", false)):
		client.session_token = token
		if r.has("view") and int(r.get("revision", -1)) >= 0:
			client.view.apply(int(r["revision"]), r["view"])
	return r

func get_state() -> Dictionary:
	return _await(client.get_state())

# ── A11.2 — Trade P2P (§55). command_id opcional = retry idempotente (§62-65) ──
func invite_trade(target: String, command_id: String = "") -> Dictionary:
	var c := command_id if command_id != "" else _auto_cid()
	return _await(client.command("TRADE_INVITE", c, {"target": target}))

func accept_trade_invite(trade_id: String, command_id: String = "") -> Dictionary:
	var c := command_id if command_id != "" else _auto_cid()
	return _await(client.command("TRADE_ACCEPT_INVITE", c, {"trade_id": trade_id}))

func decline_trade(trade_id: String, command_id: String = "") -> Dictionary:
	var c := command_id if command_id != "" else _auto_cid()
	return _await(client.command("TRADE_DECLINE", c, {"trade_id": trade_id}))

func add_trade_item(trade_id: String, iid: String, command_id: String = "") -> Dictionary:
	var c := command_id if command_id != "" else _auto_cid()
	return _await(client.command("TRADE_ADD_ITEM", c, {"trade_id": trade_id, "iid": iid}))

func remove_trade_item(trade_id: String, iid: String, command_id: String = "") -> Dictionary:
	var c := command_id if command_id != "" else _auto_cid()
	return _await(client.command("TRADE_REMOVE_ITEM", c, {"trade_id": trade_id, "iid": iid}))

func set_trade_gold(trade_id: String, amount: int, command_id: String = "") -> Dictionary:
	var c := command_id if command_id != "" else _auto_cid()
	return _await(client.command("TRADE_SET_GOLD", c, {"trade_id": trade_id, "amount": amount}))

func accept_trade_offer(trade_id: String, offer_version: int, command_id: String = "") -> Dictionary:
	var c := command_id if command_id != "" else _auto_cid()
	return _await(client.command("TRADE_ACCEPT_OFFER", c, {"trade_id": trade_id, "offer_version": offer_version}))

func cancel_trade(trade_id: String, command_id: String = "") -> Dictionary:
	var c := command_id if command_id != "" else _auto_cid()
	return _await(client.command("TRADE_CANCEL", c, {"trade_id": trade_id}))

func get_trade_state(trade_id: String) -> Dictionary:
	return _await(client.command("TRADE_GET_STATE", _auto_cid(), {"trade_id": trade_id}))

# ── A12 — Arena (queries de leitura §117; settlement é SERVER_INTERNAL, não existe aqui) ──
func arena_profile(character_id: String = "") -> Dictionary:
	return _await(client.arena_query({"q": "GET_PROFILE", "character_id": character_id}))

func arena_pvp_leaderboard(page: int = 0, page_size: int = 20) -> Dictionary:
	return _await(client.arena_query({"q": "PVP_LEADERBOARD", "page": page, "page_size": page_size}))

func arena_cp_leaderboard(page: int = 0, page_size: int = 20) -> Dictionary:
	return _await(client.arena_query({"q": "CP_LEADERBOARD", "page": page, "page_size": page_size}))

func arena_my_rank(kind: String = "pvp") -> Dictionary:
	return _await(client.arena_query({"q": "MY_RANK", "kind": kind}))

func arena_nearby(kind: String = "pvp") -> Dictionary:
	return _await(client.arena_query({"q": "NEARBY", "kind": kind}))

func arena_season_info(season_id: String = "") -> Dictionary:
	return _await(client.arena_query({"q": "SEASON_INFO", "season_id": season_id}))

# ── A13 — Character/Roster (nível de conta §75) ──
func char_get_roster() -> Dictionary:
	return _await(client.char_query({"q": "GET_ROSTER"}))

func char_create(class_id: String, display_name: String, appearance: Dictionary) -> Dictionary:
	return _await(client.char_query({"q": "CREATE_CHARACTER", "class_id": class_id, "display_name": display_name, "appearance": appearance}))

func char_identity(character_id: String) -> Dictionary:
	return _await(client.char_query({"q": "GET_IDENTITY", "character_id": character_id}))

func char_select(character_id: String) -> Dictionary:
	return _await(client.char_query({"q": "SELECT_CHARACTER", "character_id": character_id}))

func char_set_loadout(character_id: String, slot: int, loadout: Dictionary) -> Dictionary:
	return _await(client.char_query({"q": "SET_LOADOUT", "character_id": character_id, "slot": slot, "loadout": loadout}))

func char_select_loadout(character_id: String, index: int) -> Dictionary:
	return _await(client.char_query({"q": "SELECT_LOADOUT", "character_id": character_id, "index": index}))

func char_set_appearance(character_id: String, appearance: Dictionary) -> Dictionary:
	return _await(client.char_query({"q": "SET_APPEARANCE", "character_id": character_id, "appearance": appearance}))

# ── A16 — Hunting Ground (cliente só manda ground_id §120) ──
func start_hunt(ground_id: String) -> Dictionary:
	return _await(client.hunt_query({"q": "START_HUNT", "ground_id": ground_id}))
func stop_hunt() -> Dictionary:
	return _await(client.hunt_query({"q": "STOP_HUNT"}))
func hunt_state() -> Dictionary:
	return _await(client.hunt_query({"q": "HUNT_STATE"}))
func hunt_presence() -> Dictionary:
	return _await(client.hunt_query({"q": "PRESENCE"}))

func heartbeat() -> Dictionary:
	return _await(client.heartbeat())
