class_name GameServer extends Node
## FATIA A11.1 — SERVIDOR HEADLESS REAL (§19). Dono do host ENet (transporte real) + roteador. ★ Transport ≠
## Authority (§3): aqui NÃO há economia. O servidor RECEBE pacote → identifica conexão → desserializa (NetProtocol)
## → autentica/sessão (SessionRegistry) → valida permissão/whitelist (NetProtocol.parse_command) → ENFILEIRA na
## AuthorityCommandQueue (serialização global §11) → responde. Economia vive no AuthorityServer. Sem UI/render/
## FeedbackRenderer/StoryPanel (§84). Rate limit por conexão (§42), tamanho/malformado sem crash (§39/§41), logs
## estruturados sem segredo (§69), audit econômico (§70), stop gracioso (§46) e guard de produção (§52).

var _host: ENetConnection
var _port := 0
var _running := false

# camadas (podem ser injetadas p/ teste de RESTART §80; senão criadas em start)
var repo: CharacterRepository
var items: ItemRegistry
var clock: ServerClock
var authority: AuthorityServer
var queue: AuthorityCommandQueue
var sessions: SessionRegistry
var trades: TradeRepository       # A11.2
var trade: TradeService           # A11.2
var arena: ArenaService           # A12
var roster: AccountRosterRepository   # A13
var cosmetics: CosmeticEntitlementRepository   # A13
var character: CharacterService   # A13
var hunt: HuntService             # A16

# conexões
var _conn_counter := 0
var _peer_by_conn: Dictionary = {}     # connection_id → ENetPacketPeer
var _conn_by_peer: Dictionary = {}     # peer.get_instance_id() → connection_id

# rate limit por conexão+categoria (§42)
var _rate: Dictionary = {}             # "conn|cat" → Array[timestamp]
const RATE := {"LOGIN": 20, "COMMAND": 300, "HEARTBEAT": 60, "STATE": 60, "OPEN": 20}
const RATE_WINDOW := 1

# observabilidade (§69) e auditoria (§70) — NUNCA logam token/credencial/payload sensível
var log_events: Array = []
var audit_log: Array = []
const LOG_CAP := 8192

func configure(p_repo: CharacterRepository, p_items: ItemRegistry, p_clock: ServerClock, p_authority: AuthorityServer) -> void:
	repo = p_repo; items = p_items; clock = p_clock; authority = p_authority

## Sobe o servidor. Cria camadas ausentes. Guard de produção (§52). Retorna {ok, reason}.
func start(port: int, rng_seed: int = 424242) -> Dictionary:
	# §52 — LocalDevAuth NÃO pode subir em produção
	var guard := RuntimeMode.validate_auth_for_env(LocalDevAuthProvider.DEV_ONLY)
	if not bool(guard["ok"]):
		_log("boot_refused", {"reason": str(guard["reason"])})
		return {"ok": false, "reason": str(guard["reason"])}
	if repo == null: repo = CharacterRepository.new()
	if items == null: items = ItemRegistry.new()
	if clock == null: clock = ServerClock.system()
	if authority == null:
		authority = AuthorityServer.new()
		authority.setup(repo, items, clock, rng_seed)
	queue = AuthorityCommandQueue.new(); queue.setup(authority)
	sessions = SessionRegistry.new(); sessions.setup(authority, rng_seed ^ 0x5A5A)
	if trades == null:
		trades = TradeRepository.new(); trades.setup(rng_seed ^ 0x7C7C)
	trade = TradeService.new(); trade.setup(repo, items, trades, clock)
	if arena == null:
		arena = ArenaService.new(); arena.setup(authority, repo, items, clock, rng_seed ^ 0x3131)
	if roster == null: roster = AccountRosterRepository.new()
	if cosmetics == null: cosmetics = CosmeticEntitlementRepository.new()
	character = CharacterService.new(); character.setup(repo, items, roster, cosmetics, clock, authority, rng_seed ^ 0x2A2A)
	hunt = HuntService.new(); hunt.setup(repo, items, authority, clock, rng_seed ^ 0x1616)
	_host = ENetConnection.new()
	var e := _host.create_host_bound("127.0.0.1", port, 32, 2)
	if e != OK:
		return {"ok": false, "reason": "BIND_FAILED", "code": e}
	_port = port; _running = true
	_log("server_started", {"port": port, "env": RuntimeMode.server_env()})
	return {"ok": true, "port": port}

## Bombeia a rede E drena a fila (tick padrão). Para provar a fila REAL (§2), as duas metades são separáveis:
## poll_network_only() só RECEBE+ENFILEIRA; drain() executa. Assim um burst acumula pending>1 antes de drenar.
func poll() -> void:
	poll_network_only()
	drain()

## Só RECEBE eventos ENet e ENFILEIRA commands (não drena a fila autoritativa). Respostas imediatas (login/open/
## hello/state/heartbeat) saem aqui; respostas de COMMAND saem no drain(). (§2 — network poll → enqueue.)
func poll_network_only() -> void:
	if not _running or _host == null:
		return
	while true:
		var ev := _host.service(0)
		var type: int = ev[0]
		if type == ENetConnection.EVENT_NONE:
			break
		var peer = ev[1]
		if type == ENetConnection.EVENT_CONNECT:
			_on_connect(peer)
		elif type == ENetConnection.EVENT_DISCONNECT:
			_on_disconnect(peer)
		elif type == ENetConnection.EVENT_RECEIVE:
			_on_receive(peer, ev[3] if ev.size() > 3 else 0)
	_host.flush()   # empurra respostas imediatas para o socket

## Drena a fila autoritativa de forma CONTROLADA (§2/§12). max_steps limita quantos por tick. Retorna quantos rodou.
func drain(max_steps: int = 1000000) -> int:
	if queue == null:
		return 0
	var n := queue.pump_all(max_steps)
	if _host != null:
		_host.flush()   # empurra as respostas de COMMAND
	return n

func _on_connect(peer) -> void:
	_conn_counter += 1
	var cid := "conn_%d" % _conn_counter
	_peer_by_conn[cid] = peer
	_conn_by_peer[peer.get_instance_id()] = cid
	_log("conn_open", {"connection": cid})

func _on_disconnect(peer) -> void:
	var cid := _conn_of(peer)
	if cid == "": return
	sessions.drop_connection(cid)     # §35 — sessão persiste; lease decide expiry
	_peer_by_conn.erase(cid)
	_conn_by_peer.erase(peer.get_instance_id())
	_log("conn_close", {"connection": cid})

func _conn_of(peer) -> String:
	return str(_conn_by_peer.get(peer.get_instance_id(), ""))

func _on_receive(peer, _channel: int) -> void:
	var cid := _conn_of(peer)
	if cid == "": return
	var packet: PackedByteArray = peer.get_packet()
	var dec := NetProtocol.decode(packet)
	if not bool(dec["ok"]):
		var reason := str(dec["reason"])
		var be_rid := str(dec.get("rid", ""))   # ecoa o rid quando deu p/ extrair (cliente casa por rid)
		if reason == "PROTOCOL_MISMATCH":
			_send(cid, NetProtocol.PROTOCOL_MISMATCH, be_rid, "", {"reason": reason})   # §5
		else:
			_send(cid, NetProtocol.ERROR, be_rid, "", {"reason": reason})               # §39 sem crash
		_log("rx_bad", {"connection": cid, "reason": reason})
		return
	var env: Dictionary = dec["env"]
	_route(cid, env)

func _route(cid: String, env: Dictionary) -> void:
	var t := str(env["t"])
	var rid := str(env["rid"])
	var sid := str(env["sid"])
	var p: Dictionary = env["p"]
	match t:
		NetProtocol.HELLO:
			_send(cid, NetProtocol.HELLO_ACK, rid, "", {"protocol_version": NetProtocol.PROTOCOL_VERSION, "server_time": clock.now()})
		NetProtocol.LOGIN:
			if not _rate_ok(cid, "LOGIN"): return _reject(cid, rid, "RATE_LIMITED")
			var a := sessions.authenticate_connection(cid, {"account_id": str(p.get("account_id", ""))})
			_log("login", {"connection": cid, "ok": a["ok"]})
			_send(cid, NetProtocol.LOGIN_RESULT, rid, "", a)
		NetProtocol.OPEN_CHARACTER:
			if not _rate_ok(cid, "OPEN"): return _reject(cid, rid, "RATE_LIMITED")
			var o := sessions.open_character(cid, str(p.get("character_id", "")))
			if bool(o["ok"]):
				o["view"] = authority.client_view(str(o["character"]))   # snapshot inicial (§31)
			_log("open_character", {"connection": cid, "ok": o["ok"], "character": str(p.get("character_id", ""))})
			_send(cid, NetProtocol.OPEN_RESULT, rid, "", o)
		NetProtocol.COMMAND:
			_handle_command(cid, rid, sid, p)
		NetProtocol.ARENA_QUERY:
			_handle_arena_query(cid, rid, sid, p)
		NetProtocol.CHAR_QUERY:
			_handle_char_query(cid, rid, p)
		NetProtocol.HUNT_QUERY:
			_handle_hunt_query(cid, rid, sid, p)
		NetProtocol.GET_STATE:
			if not _rate_ok(cid, "STATE"): return _reject(cid, rid, "RATE_LIMITED")
			var r := sessions.resolve(cid, sid)
			if not bool(r["ok"]): return _reject(cid, rid, str(r["reason"]))
			var ch := str(r["character"])
			_send(cid, NetProtocol.STATE, rid, sid, {"ok": true, "revision": repo.revision_of(ch), "view": authority.client_view(ch)})
		NetProtocol.HEARTBEAT:
			if not _rate_ok(cid, "HEARTBEAT"): return _reject(cid, rid, "RATE_LIMITED")
			var hr := sessions.resolve(cid, sid)
			if not bool(hr["ok"]): return _reject(cid, rid, str(hr["reason"]))
			authority.heartbeat(str(hr["authority_sid"]))   # §34 — timestamp final é do ServerClock
			_send(cid, NetProtocol.HEARTBEAT_ACK, rid, sid, {"ok": true, "server_time": clock.now()})
		NetProtocol.RECONNECT:
			if not _rate_ok(cid, "OPEN"): return _reject(cid, rid, "RATE_LIMITED")
			if sessions.account_of_connection(cid) == "": return _reject(cid, rid, "NOT_AUTHENTICATED")
			var rb := sessions.rebind(cid, str(p.get("token", "")))   # §36 — valida conta dona do token
			if bool(rb["ok"]):
				var ch2 := str(rb["character"])
				rb["revision"] = repo.revision_of(ch2)
				rb["view"] = authority.client_view(ch2)
			_log("reconnect", {"connection": cid, "ok": rb["ok"]})
			_send(cid, NetProtocol.RECONNECT_RESULT, rid, "", rb)
		NetProtocol.LOGOUT:
			sessions.revoke(sid)
			_send(cid, NetProtocol.LOGIN_RESULT, rid, "", {"ok": true, "logged_out": true})
		_:
			_reject(cid, rid, "UNKNOWN_MESSAGE")

func _handle_command(cid: String, rid: String, sid: String, p: Dictionary) -> void:
	if not _rate_ok(cid, "COMMAND"): return _reject(cid, rid, "RATE_LIMITED")
	# resolve sessão (token → autoridade), valida conexão/conta (§37/§38)
	var r := sessions.resolve(cid, sid)
	if not bool(r["ok"]): return _reject(cid, rid, str(r["reason"]))
	# permissão + whitelist (§40/§59). Conexão de cliente comum → dev_connection=false ⇒ loot/boss NEGADOS (§57/§58)
	var pc := NetProtocol.parse_command(p, false)
	if not bool(pc["ok"]): return _reject(cid, rid, str(pc["reason"]))
	var command: Dictionary = pc["command"]
	var auth_sid := str(r["authority_sid"])
	var character := str(r["character"])
	var ctype := str(command.get("type", ""))
	# ENFILEIRA (serialização global §11). Backpressure §43. Callback envia o COMMAND_RESULT.
	var exec: Callable
	if NetProtocol.is_trade_command(ctype):
		exec = func() -> Dictionary: return _trade_exec(character, command)   # A11.2 → TradeService
	else:
		exec = func() -> Dictionary: return authority.submit(auth_sid, command)
	var cb := func(res: Dictionary) -> void:
		_audit(character, command, res)
		var payload := {
			"command_id": str(command.get("command_id", "")),
			"ok": bool(res.get("ok", false)),
			"error": str(res.get("reason", "")),
			"revision": int(res.get("revision", -1)),
			"duplicate": bool(res.get("duplicate", false)),
			"result": res.get("result", {}),
			"view": res.get("view", {}),
		}
		# campos extras de trade (trade_id/completed/accepted/revisions) — repassa transparente
		for k in ["trade_id", "completed", "accepted", "revisions", "state"]:
			if res.has(k): payload[k] = res[k]
		_send(cid, NetProtocol.COMMAND_RESULT, rid, sid, payload)
	var q := queue.enqueue(exec, cb)
	if not bool(q["ok"]):
		_reject(cid, rid, str(q["reason"]))   # §43 SERVER_BUSY — nada foi commitado

## A12 — QUERIES de leitura da Arena (CLIENT_ALLOWED §117). Settlement NÃO está aqui (é SERVER_INTERNAL §10/§74).
## Todas server-authoritative: CP/rating vêm do servidor; o cliente não injeta nada (§97).
func _handle_arena_query(cid: String, rid: String, sid: String, p: Dictionary) -> void:
	if not _rate_ok(cid, "STATE"): return _reject(cid, rid, "RATE_LIMITED")
	var r := sessions.resolve(cid, sid)
	if not bool(r["ok"]): return _reject(cid, rid, str(r["reason"]))
	var me := str(r["character"])
	var q := str(p.get("q", ""))
	var out: Dictionary = {"ok": true, "q": q}
	match q:
		"GET_PROFILE":
			var target := str(p.get("character_id", ""))
			if target == "": target = me
			out = arena.get_profile_dto(target); out["q"] = q
		"PVP_LEADERBOARD":
			out = arena.pvp_page(int(p.get("page", 0)), int(p.get("page_size", 20))); out["q"] = q; out["ok"] = true
		"CP_LEADERBOARD":
			out = arena.power.page(int(p.get("page", 0)), int(p.get("page_size", 20))); out["q"] = q; out["ok"] = true
		"MY_RANK":
			var kind := str(p.get("kind", "pvp"))
			var pos := arena.pvp_my_position(me) if kind == "pvp" else arena.power.my_position(me)
			out = {"ok": true, "q": q, "kind": kind, "position": pos}
		"NEARBY":
			var kind2 := str(p.get("kind", "pvp"))
			var near = arena.pvp_nearby(me) if kind2 == "pvp" else arena.power.nearby(me)
			out = {"ok": true, "q": q, "kind": kind2, "entries": near}
		"SEASON_INFO":
			out = arena.season_info(str(p.get("season_id", arena.current_season_id))); out["q"] = q
		_:
			out = {"ok": false, "q": q, "reason": "QUERY_UNKNOWN"}   # settle/report_win nunca aqui (§74)
	_send(cid, NetProtocol.ARENA_RESULT, rid, sid, out)

## A13 — roster/create/select/identity/loadout/appearance (nível de CONTA §38). Requer só CONEXÃO AUTENTICADA
## (não sessão de character): é o fluxo de character-select ANTES de abrir um character. Server-authoritative (§74):
## o cliente manda só class_id/display_name/IDs de opção; stats/cp/level/gold forjados são ignorados (§34/§77).
func _handle_char_query(cid: String, rid: String, p: Dictionary) -> void:
	if not _rate_ok(cid, "STATE"): return _reject(cid, rid, "RATE_LIMITED")
	var account := sessions.account_of_connection(cid)
	if account == "": return _reject(cid, rid, "NOT_AUTHENTICATED")
	var q := str(p.get("q", ""))
	var out: Dictionary = {}
	match q:
		"GET_ROSTER":
			out = character.get_roster_dto(account)
		"CREATE_CHARACTER":
			out = character.create_character(account, str(p.get("class_id", "")), str(p.get("display_name", "")), p.get("appearance", {}) if p.get("appearance", {}) is Dictionary else {})
		"GET_IDENTITY":
			out = character.get_identity_dto(account, str(p.get("character_id", "")))
		"SELECT_CHARACTER":
			out = character.switch_active_progression(account, str(p.get("character_id", "")))
		"SET_LOADOUT":
			out = character.set_loadout(account, str(p.get("character_id", "")), int(p.get("slot", 0)), p.get("loadout", {}) if p.get("loadout", {}) is Dictionary else {})
		"SELECT_LOADOUT":
			out = character.select_loadout(account, str(p.get("character_id", "")), int(p.get("index", 0)))
		"SET_APPEARANCE":
			out = character.set_appearance(account, str(p.get("character_id", "")), p.get("appearance", {}) if p.get("appearance", {}) is Dictionary else {})
		_:
			out = {"ok": false, "reason": "QUERY_UNKNOWN"}
	out["q"] = q
	_send(cid, NetProtocol.CHAR_RESULT, rid, "", out)

## A16 — Hunting Ground (§119/§120): o cliente só manda ground_id; spot/shard/xp/loot/kill são do SERVIDOR. Requer
## sessão de character (o char da sessão é o caçador). START/STOP/STATE/PRESENCE.
func _handle_hunt_query(cid: String, rid: String, sid: String, p: Dictionary) -> void:
	if not _rate_ok(cid, "COMMAND"): return _reject(cid, rid, "RATE_LIMITED")
	var r := sessions.resolve(cid, sid)
	if not bool(r["ok"]): return _reject(cid, rid, str(r["reason"]))
	var character := str(r["character"]); var account := str(r["account"])
	var q := str(p.get("q", ""))
	var out: Dictionary = {}
	match q:
		"START_HUNT":
			out = hunt.start_hunt(account, character, str(p.get("ground_id", "")))   # só ground_id do cliente
		"STOP_HUNT":
			out = hunt.stop_hunt(character)
		"HUNT_STATE":
			out = hunt.get_hunt_state(character)
		"PRESENCE":
			out = {"ok": true, "presence": hunt.presence_for(character)}
		_:
			out = {"ok": false, "reason": "QUERY_UNKNOWN"}
	out["q"] = q
	_send(cid, NetProtocol.HUNT_RESULT, rid, sid, out)

## A11.2 — despacha um comando TRADE_* para o TradeService (actor = character da sessão §56).
func _trade_exec(character: String, command: Dictionary) -> Dictionary:
	var ct := str(command.get("type", ""))
	var cmd_id := str(command.get("command_id", ""))
	var tid := str(command.get("trade_id", ""))
	match ct:
		"TRADE_INVITE": return trade.invite(character, cmd_id, str(command.get("target", "")))
		"TRADE_ACCEPT_INVITE": return trade.accept_invite(character, cmd_id, tid)
		"TRADE_DECLINE": return trade.decline(character, cmd_id, tid)
		"TRADE_ADD_ITEM": return trade.add_item(character, cmd_id, tid, str(command.get("iid", "")))
		"TRADE_REMOVE_ITEM": return trade.remove_item(character, cmd_id, tid, str(command.get("iid", "")))
		"TRADE_SET_GOLD": return trade.set_gold(character, cmd_id, tid, int(command.get("amount", 0)))
		"TRADE_ACCEPT_OFFER": return trade.accept_offer(character, cmd_id, tid, int(command.get("offer_version", -1)))
		"TRADE_CANCEL": return trade.cancel(character, cmd_id, tid)
		"TRADE_GET_STATE": return trade.get_view(character, tid)
	return {"ok": false, "reason": "UNKNOWN_TRADE"}

## API INTERNA/ADMIN (§57/§58) — usada pelo SERVIDOR (setup de teste/eventos), nunca pela rede do cliente comum.
## Ex.: conceder loot, marcar boss. Passa pela MESMA fila (serialização). `cb` opcional recebe o resultado.
func internal_command(character_id: String, command: Dictionary, cb: Callable = Callable()) -> Dictionary:
	var exec := func() -> Dictionary: return authority.submit_internal(character_id, command)
	var wrapped := func(res: Dictionary) -> void:
		_audit(character_id, command, res)
		if cb.is_valid(): cb.call(res)
	return queue.enqueue(exec, wrapped)

# ── envio ──
func _send(cid: String, msg_type: String, rid: String, sid: String, payload: Dictionary) -> void:
	var peer = _peer_by_conn.get(cid, null)
	if peer == null:
		return   # §45 — conexão caiu; resposta perdida, retry/reconnect recupera
	var env := NetProtocol.envelope(msg_type, rid, sid, payload)
	peer.send(0, NetProtocol.encode(env), ENetPacketPeer.FLAG_RELIABLE)

func _reject(cid: String, rid: String, reason: String) -> void:
	_send(cid, NetProtocol.ERROR, rid, "", {"ok": false, "reason": reason})

# ── rate limit (§42) ──
func _rate_ok(cid: String, cat: String) -> bool:
	var key := cid + "|" + cat
	var now := clock.now()
	var lst: Array = _rate.get(key, [])
	var keep: Array = []
	for ts in lst:
		if int(ts) > now - RATE_WINDOW:
			keep.append(ts)
	if keep.size() >= int(RATE.get(cat, 100)):
		_rate[key] = keep
		return false
	keep.append(now); _rate[key] = keep
	return true

# ── observabilidade / auditoria (sem segredo §69) ──
func _log(kind: String, data: Dictionary) -> void:
	log_events.append({"t": clock.now(), "kind": kind, "data": data})
	while log_events.size() > LOG_CAP: log_events.pop_front()

func _audit(character: String, command: Dictionary, res: Dictionary) -> void:
	audit_log.append({
		"t": clock.now(), "character": character, "command": str(command.get("type", "")),
		"command_id": str(command.get("command_id", "")), "ok": bool(res.get("ok", false)),
		"reason": str(res.get("reason", "")), "revision": int(res.get("revision", -1)),
	})
	while audit_log.size() > LOG_CAP: audit_log.pop_front()

# ── stop gracioso (§46) ──
func stop() -> Dictionary:
	if not _running:
		return {"ok": true, "already": true}
	_running = false
	var drained := queue.pump_all()   # drena o que já foi aceito antes de fechar
	_log("server_stopping", {"drained": drained, "pending": queue.pending_count()})
	if _host != null:
		_host.destroy()
		_host = null
	return {"ok": true, "drained": drained}

func is_running() -> bool: return _running
func connection_count() -> int: return _peer_by_conn.size()
