class_name GameClient extends Node
## FATIA A11.1 — CLIENTE REAL (§20). Conecta por ENet ao GameServer, faz handshake/login DEV/open-character, envia
## commands e recebe results. ★ NÃO é autoridade (§24): NUNCA chama refine_attempt/prestige/etc. sobre save local;
## toda ação econômica vira COMMAND pela rede. Mantém um RemoteCharacterView (espelho §23) aplicado de forma
## MONOTÔNICA por revision (§29/§31) — resposta atrasada não regride. request_id casa a troca de rede (§6);
## command_id é reusado no retry (§26). Pode DESCARTAR a próxima resposta (simula perda real §27) para provar
## idempotência ponta a ponta.

var _host: ENetConnection
var _peer                                  # ENetPacketPeer
var _connected := false
var _rid_counter := 0

var session_token := ""
var account_id := ""
var view := RemoteCharacterView.new()

var _by_rid: Dictionary = {}               # rid → envelope de resposta (casamento §6/§29)
var _drop_next := 0                         # nº de próximas respostas a DESCARTAR (simula perda §27)
var dropped_count := 0

func start(port: int) -> Dictionary:
	_host = ENetConnection.new()
	var e := _host.create_host(1, 2)
	if e != OK:
		return {"ok": false, "reason": "HOST_FAILED", "code": e}
	_peer = _host.connect_to_host("127.0.0.1", port, 2)
	if _peer == null:
		return {"ok": false, "reason": "CONNECT_FAILED"}
	return {"ok": true}

## Bombeia a rede do cliente: processa eventos, guarda respostas por rid, atualiza o view (monotônico).
func poll() -> void:
	if _host == null:
		return
	while true:
		var ev := _host.service(0)
		var type: int = ev[0]
		if type == ENetConnection.EVENT_NONE:
			break
		if type == ENetConnection.EVENT_CONNECT:
			_connected = true
		elif type == ENetConnection.EVENT_DISCONNECT:
			_connected = false
		elif type == ENetConnection.EVENT_RECEIVE:
			_on_receive(ev[1])

func _on_receive(peer) -> void:
	var dec := NetProtocol.decode(peer.get_packet())
	if not bool(dec["ok"]):
		return
	var env: Dictionary = dec["env"]
	# §27 — descarta deliberadamente (perda de resposta simulada)
	if _drop_next > 0:
		_drop_next -= 1; dropped_count += 1
		return
	var rid := str(env["rid"])
	if rid != "":
		_by_rid[rid] = env
	# atualiza o espelho de UI se a resposta trouxe view+revision (§29/§31 monotônico)
	var p: Dictionary = env["p"]
	if p.has("view") and p.get("view") is Dictionary and int(p.get("revision", -1)) >= 0:
		view.apply(int(p["revision"]), p["view"])

# ── envio (gera rid novo a cada troca §6) ──
func _next_rid() -> String:
	_rid_counter += 1
	return "rid_%d" % _rid_counter

func _send(msg_type: String, payload: Dictionary) -> String:
	var rid := _next_rid()
	var env := NetProtocol.envelope(msg_type, rid, session_token, payload)
	_peer.send(0, NetProtocol.encode(env), ENetPacketPeer.FLAG_RELIABLE)
	_host.flush()
	return rid

## Envia um envelope CRU (para testes de malformado/versão §78) — NÃO normaliza; o servidor é quem valida.
func send_raw(env: Dictionary) -> String:
	var rid := str(env.get("rid", _next_rid()))
	env["rid"] = rid
	_peer.send(0, JSON.stringify(env).to_utf8_buffer(), ENetPacketPeer.FLAG_RELIABLE)
	_host.flush()
	return rid

## Envia bytes crus arbitrários (oversized/lixo) — prova que o servidor não quebra (§39/§41).
func send_raw_bytes(bytes: PackedByteArray) -> void:
	_peer.send(0, bytes, ENetPacketPeer.FLAG_RELIABLE)
	_host.flush()

func hello() -> String: return _send(NetProtocol.HELLO, {})
func reconnect(token: String) -> String: return _send(NetProtocol.RECONNECT, {"token": token})
func login(account: String) -> String:
	account_id = account
	return _send(NetProtocol.LOGIN, {"account_id": account})
func open_character(character_id: String) -> String:
	return _send(NetProtocol.OPEN_CHARACTER, {"character_id": character_id})
func get_state() -> String: return _send(NetProtocol.GET_STATE, {})
func arena_query(payload: Dictionary) -> String: return _send(NetProtocol.ARENA_QUERY, payload)   # A12 leitura
func char_query(payload: Dictionary) -> String: return _send(NetProtocol.CHAR_QUERY, payload)     # A13 roster/identity
func hunt_query(payload: Dictionary) -> String: return _send(NetProtocol.HUNT_QUERY, payload)     # A16 hunt
func heartbeat() -> String: return _send(NetProtocol.HEARTBEAT, {})
func logout() -> String: return _send(NetProtocol.LOGOUT, {})

## Envia um COMMAND. `command_id` é a identidade lógica idempotente (reuse no retry §26); rid é novo sempre.
func command(command_type: String, command_id: String, args: Dictionary = {}) -> String:
	return _send(NetProtocol.COMMAND, {"command_type": command_type, "command_id": command_id, "args": args})

# ── envelope de resposta por rid ──
func has_response(rid: String) -> bool: return _by_rid.has(rid)
func take_response(rid: String) -> Dictionary:
	var env: Dictionary = _by_rid.get(rid, {})
	_by_rid.erase(rid)
	return env

## Aplica o token de sessão a partir de um OPEN_RESULT (o cliente guarda o token que o servidor emitiu).
func adopt_session_from(env: Dictionary) -> void:
	var p: Dictionary = env.get("p", {})
	if bool(p.get("ok", false)) and p.has("token"):
		session_token = str(p["token"])

func set_drop_next_response(n: int) -> void: _drop_next = n
func net_connected() -> bool: return _connected

func stop() -> void:
	if _host != null:
		# desconexão graciosa: avisa o par e serve um pouco p/ o servidor receber o EVENT_DISCONNECT (§35)
		if _peer != null:
			_peer.peer_disconnect(0)
			for i in range(10):
				_host.service(5)
		_host.destroy()
		_host = null
	_peer = null
	_connected = false
