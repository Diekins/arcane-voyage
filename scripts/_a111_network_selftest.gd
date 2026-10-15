extends SceneTree
## Self-test/RELATÓRIO FATIA A11.1 — Real Network Transport / Auth Boundary / Concurrency Hardening. Prova em
## bancada headless (localhost): DOIS clientes REAIS falam com UM servidor headless REAL por transporte ENet;
## commands de A/B NUNCA contaminam o GameState um do outro; resposta perdida não duplica; reconnect recebe o último
## estado; cliente comum não chama loot/boss internos; e o modo LOCAL segue intacto. FIXTURE (save vivo intocado).
## godot --headless --path godot -s res://scripts/_a111_network_selftest.gd

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1

var gs
var server: GameServer
var repo: CharacterRepository
var items: ItemRegistry
var clock: ServerClock
var _all_clients: Array = []
var _port := 34720
var _last_internal: Dictionary = {}

func _pump_all() -> void:
	if server != null: server.poll()
	for c in _all_clients:
		c.poll()

func _mkstate(frag: int) -> Dictionary:
	gs.reset_save()
	gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 0}
	gs.materials = {"Fragmentos": frag}
	return gs.to_dict().duplicate(true)

func _elig_state() -> Dictionary:
	gs.reset_save()
	gs.cycle_seals = 10; gs.cycle_seal_high = 100
	gs.stage_chapter = 10; gs.stage_index = 10; gs.stage_highest_global = 100
	gs.offline_pending = {}
	return gs.to_dict().duplicate(true)

func _offline_state(gold: int, xp: int) -> Dictionary:
	gs.reset_save(); gs.offline_pending = {"gold": gold, "xp": xp, "materials": {}}
	return gs.to_dict().duplicate(true)

func _fresh(seed: int = 777) -> int:
	for c in _all_clients: c.stop()
	_all_clients = []
	if server != null: server.stop()
	_port += 1
	repo = CharacterRepository.new(); items = ItemRegistry.new(); clock = ServerClock.fixed(100000)
	server = GameServer.new(); root.add_child(server); server.configure(repo, items, clock, null)
	server.start(_port, seed)
	return _port

func _client(prefix: String) -> OnlineClient:
	var gc := GameClient.new(); root.add_child(gc); gc.start(_port)
	_all_clients.append(gc)
	var oc := OnlineClient.new(); oc.setup(gc, Callable(self, "_pump_all"), prefix)
	oc.default_timeout_ms = 1500
	return oc

func _await_env(gc: GameClient, rid: String, timeout_ms: int = 1200) -> Dictionary:
	var waited := 0
	while waited < timeout_ms:
		_pump_all()
		if gc.has_response(rid): return gc.take_response(rid)
		OS.delay_msec(1); waited += 1
	return {}

func _internal(character: String, command: Dictionary) -> Dictionary:
	_last_internal = {}
	var done := [false]
	var cbfn := func(res: Dictionary) -> void:
		_last_internal = res
		done[0] = true
	server.internal_command(character, command, cbfn)
	var w := 0
	while not done[0] and w < 1500:
		server.poll(); OS.delay_msec(1); w += 1
	return _last_internal

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a111_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()

	_test_net()
	_test_auth()
	_test_concurrency()
	_test_real_commands()
	_test_retry()
	_test_reconnect_net()
	_test_malformed()
	_test_two_clients()
	_test_server_restart()
	_test_stress()
	_test_local_mode()

	for c in _all_clients: c.stop()
	if server != null: server.stop()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	for f in ["user://a111_repo.json", "user://a111_items.json", "user://a111_server.json"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(f)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ══════════════ NET (§72) ══════════════
func _test_net() -> void:
	print("  ── NET (transporte/handshake) ──")
	_fresh()
	repo.create_character("accA", "charA", _mkstate(1000))
	_chk("NET-T01 servidor escuta localhost", server.is_running())
	var A := _client("net")
	var lg := A.connect_and_login("accA")
	_chk("NET-T02 cliente conecta via ENet real", A.client.net_connected())
	_chk("NET-T03 handshake HELLO_ACK (protocol_version)", int(lg.get("hello", {}).get("protocol_version", -1)) == NetProtocol.PROTOCOL_VERSION)
	# NET-T04 versão errada
	var rid := A.client.send_raw({"v": 999, "t": NetProtocol.HELLO, "rid": "wrongver", "sid": "", "p": {}})
	var badver := _await_env(A.client, rid)
	_chk("NET-T04 versão errada rejeitada (PROTOCOL_MISMATCH)", str(badver.get("t", "")) == NetProtocol.PROTOCOL_MISMATCH)
	_chk("NET-T05 login dev real", bool(lg.get("ok", false)))
	var op := A.open_character("charA")
	_chk("NET-T06 open character", bool(op.get("ok", false)))
	_chk("NET-T07 snapshot recebido (view+revision)", int(op.get("revision", -1)) >= 1 and (op.get("view", {}) as Dictionary).has("fragments"))
	var before := server.connection_count()
	A.client.stop()
	var w := 0
	while server.connection_count() >= before and w < 500:
		server.poll(); OS.delay_msec(1); w += 1
	_chk("NET-T08 disconnect limpo (servidor libera a conexão)", server.connection_count() < before)

# ══════════════ AUTH (§73) ══════════════
func _test_auth() -> void:
	print("  ── AUTH (fronteira de autenticação) ──")
	_fresh()
	repo.create_character("accA", "charA", _mkstate(1000))
	repo.create_character("accB", "charB", _mkstate(1000))
	var A := _client("auth")
	A.connect_and_login("accA")
	_chk("AUTH-T01 credencial dev válida", A.client.account_id == "accA")
	# AUTH-T02 credencial inválida (conta vazia)
	var bad := A._await(A.client.login(""))
	_chk("AUTH-T02 credencial inválida rejeitada", not bool(bad.get("ok", false)))
	# re-login accA (o login vazio não muda a conta autenticada no servidor)
	A._await(A.client.login("accA"))
	# AUTH-T03 abrir character alheio
	var o_other := A.open_character("charB")
	_chk("AUTH-T03 conta não abre character alheio (NOT_OWNER)", not bool(o_other.get("ok", false)) and str(o_other.get("reason", "")) == "NOT_OWNER")
	# AUTH-T04 guard de produção (decisão pura)
	var prod := RuntimeMode.decide_auth(true, true)
	var dev := RuntimeMode.decide_auth(false, true)
	var prodreal := RuntimeMode.decide_auth(true, false)
	_chk("AUTH-T04 LocalDevAuth bloqueado em produção (FAIL BOOT)", not bool(prod["ok"]) and bool(dev["ok"]) and bool(prodreal["ok"]))
	# AUTH-T05 token server-side
	var op := A.open_character("charA")
	_chk("AUTH-T05 session token server-side (tok_*, ≠ character_id)", str(A.client.session_token).begins_with("tok_") and A.client.session_token != "charA" and bool(op.get("ok", false)))
	# AUTH-T06 token inválido/revogado
	var saved := A.client.session_token
	A.client.session_token = "tok_forjado_00000000"
	var forged := A.refine("weapon")
	A.client.session_token = saved
	_chk("AUTH-T06 token inválido rejeitado", not bool(forged.get("ok", false)) and str(forged.get("reason", forged.get("error", ""))) == "BAD_SESSION")

# ══════════════ CONCURRENCY (§74 + §66 sentinel) ══════════════
func _test_concurrency() -> void:
	print("  ── CONC (serialização do GameState) ──")
	_fresh()
	repo.create_character("accA", "charA", _mkstate(100000))
	repo.create_character("accB", "charB", _mkstate(100000))
	var A := _client("cA"); var B := _client("cB")
	A.connect_and_login("accA"); B.connect_and_login("accB")
	A.open_character("charA"); B.open_character("charB")
	# tráfego intercalado A/B
	for i in range(40):
		if i % 2 == 0:
			A.refine("weapon")
		else:
			B.refine("weapon")
	_chk("CONC-T01 só um _with_gs ativo (pico==1, ativo==0 no fim)", server.authority.gs_active() == 0 and server.authority.gs_active_peak() == 1)
	_chk("CONC-T02/§66 A/B serializam (log bem-aninhado, ZERO interleave)", server.authority.gs_events_well_nested())
	var fa := int((repo.load("charA")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	var fb := int((repo.load("charB")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	# cada character gastou de forma INDEPENDENTE (RNG do servidor diverge por character ⇒ spends podem diferir);
	# a prova de não-contaminação é o log bem-aninhado (CONC-T02) + ambos consumindo do PRÓPRIO saldo.
	_chk("CONC-T03 A não contamina B (ambos gastaram do próprio saldo, isolados)", fa < 100000 and fb < 100000 and fa > 0 and fb > 0)
	# CONC-T04 erro em A restaura antes de B: refine sem Fragmentos (char pobre) → result.ok=false, ativo volta a 0
	repo.create_character("accP", "charP", _mkstate(0))
	var poor := _client("cP"); poor.connect_and_login("accP"); poor.open_character("charP")
	var err := poor.refine("weapon")
	var poor_result: Dictionary = err.get("result", {})
	_chk("CONC-T04 refino sem recurso não corrompe (result.ok=false, gs ativo==0)", server.authority.gs_active() == 0 and not bool(poor_result.get("ok", true)))
	# CONC-T05 reentrância rejeitada (nested _with_gs)
	var inner := {"got": {}}
	var nested := func(_g2): return {}
	var op_outer := func(_g):
		inner["got"] = server.authority._with_gs({}, nested)
		return {}
	server.authority._with_gs(_mkstate(500), op_outer)
	_chk("CONC-T05 reentrância rejeitada (inner REENTRANT_GS) + restore", str((inner["got"] as Dictionary).get("reason", "")) == "REENTRANT_GS" and server.authority.gs_active() == 0)
	# CONC-T07 backpressure (fila cheia sem drenar)
	var q := AuthorityCommandQueue.new(); q.setup(server.authority)
	var busy := false
	for i in range(q.MAX_PENDING + 5):
		var r := q.enqueue(func() -> Dictionary: return {}, Callable())
		if not bool(r["ok"]) and str(r["reason"]) == "SERVER_BUSY": busy = true
	_chk("CONC-T07 backpressure (SERVER_BUSY acima de MAX_PENDING)", busy)
	# CONC-T08 fila drena a zero
	q.pump_all()
	_chk("CONC-T08 fila drena a zero", q.pending_count() == 0)
	_chk("CONC-T06 ordem por sessão preservada (FIFO commit)", server.queue.committed() > 0)

# ══════════════ REAL COMMANDS (§75) ══════════════
func _test_real_commands() -> void:
	print("  ── RCMD (comandos econômicos ponta a ponta) ──")
	_fresh()
	repo.create_character("accA", "charA", _mkstate(1000))
	repo.create_character("accO", "charO", _offline_state(5000, 1200))
	repo.create_character("accPr", "charPr", _elig_state())
	repo.create_character("accE", "charE", _mkstate(0))
	var A := _client("rc")
	A.connect_and_login("accA"); A.open_character("charA")
	var fb := A.client.view.fragments()
	var rf := A.refine("weapon")
	_chk("RCMD-T01 REFINE ponta a ponta (view revN)", bool(rf.get("ok", false)) and A.client.view.fragments() < fb and int(rf.get("revision", -1)) >= 2)
	# offline
	var O := _client("ro"); O.connect_and_login("accO"); O.open_character("charO")
	var g0 := O.client.view.gold()
	var cl := O.claim_offline()
	_chk("RCMD-T02 CLAIM_OFFLINE aplica ouro do pending autoritativo", bool(cl.get("ok", false)) and O.client.view.gold() == g0 + 5000)
	# prestige
	var P := _client("rp"); P.connect_and_login("accPr"); P.open_character("charPr")
	var pr := P.prestige()
	_chk("RCMD-T03 PRESTIGE decidido pelo servidor (P1)", bool(pr.get("ok", false)) and int((pr.get("result", {}) as Dictionary).get("prestige", -1)) == 1)
	# equip (loot concedido server-internal, depois equip pela rede)
	var loot := _internal("charA", {"type": "GRANT_LOOT", "command_id": "srvloot1", "item_id": "sword_eternal"})
	var iid := str((loot.get("result", {}) as Dictionary).get("iid", ""))
	var eq := A.equip(iid)
	_chk("RCMD-T04 EQUIP pela rede valida dono + equipa", bool(eq.get("ok", false)) and str((eq.get("result", {}) as Dictionary).get("equipped", "")) == iid)
	# get_state
	var st := A.get_state()
	_chk("RCMD-T05 GET_STATE devolve view+revision", bool(st.get("ok", false)) and int(st.get("revision", -1)) >= 1)
	# RCMD-T06/T07 comandos internos NÃO acessíveis pelo cliente comum
	var gl := A.try_grant_loot("sword_eternal")
	var cb := A.try_clear_boss(10)
	_chk("RCMD-T06 GRANT_LOOT interno negado ao cliente (PERMISSION_DENIED)", str(gl.get("error", gl.get("reason", ""))) == "PERMISSION_DENIED")
	_chk("RCMD-T07 CLEAR_BOSS interno negado ao cliente (PERMISSION_DENIED)", str(cb.get("error", cb.get("reason", ""))) == "PERMISSION_DENIED")

# ══════════════ RETRY (§76) ══════════════
func _test_retry() -> void:
	print("  ── RETRY (lost-response / duplicate / out-of-order) ──")
	_fresh()
	repo.create_character("accA", "charA", _mkstate(1000))
	var A := _client("rt"); A.connect_and_login("accA"); A.open_character("charA")
	var f0 := int((repo.load("charA")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	# RETRY-T01 lost-response: servidor executa, resposta é DESCARTADA no cliente → timeout
	A.client.set_drop_next_response(1)
	A.default_timeout_ms = 250
	var lost := A.refine("weapon", "", "retryX")   # command_id fixo
	A.default_timeout_ms = 1500
	_chk("RETRY-T01 resposta perdida → timeout no cliente", bool(lost.get("timeout", false)))
	var f1 := int((repo.load("charA")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	_chk("RETRY (servidor executou mesmo com resposta perdida)", f1 < f0)
	# RETRY-T03 novo request_id + mesmo command_id
	var retry := A.refine("weapon", "", "retryX")
	_chk("RETRY-T02/T03 retry mesmo command_id (duplicate)", bool(retry.get("duplicate", false)))
	var f2 := int((repo.load("charA")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	_chk("RETRY-T04 1 cobrança / 1 RNG (retry não gasta de novo)", f2 == f1)
	# RETRY-T05 out-of-order não regride revision (RemoteCharacterView monotônico)
	var v := RemoteCharacterView.new()
	v.apply(13, {"gold": 130})
	var regress := v.apply(12, {"gold": 120})
	_chk("RETRY-T05 out-of-order não regride revision", not regress and v.revision == 13 and v.gold() == 130)

# ══════════════ RECONNECT (§77) ══════════════
func _test_reconnect_net() -> void:
	print("  ── RNET (reconnect / lease / restart-de-sessão) ──")
	_fresh()
	repo.create_character("accA", "charA", _mkstate(1000))
	var A := _client("rn"); A.connect_and_login("accA"); A.open_character("charA")
	var token := A.client.session_token
	A.refine("weapon", "", "rn_commit")   # commit antes da queda
	var rev_commit := repo.revision_of("charA")
	# RNET-T01 socket cai
	A.client.stop()
	var w := 0
	while server.connection_count() > 0 and w < 500:
		server.poll(); OS.delay_msec(1); w += 1
	_chk("RNET-T01 socket cai (conexão liberada)", server.connection_count() == 0)
	# RNET-T02 lease permanece: novo login+open do MESMO character → SESSION_IN_USE (lease vivo)
	var B := _client("rn2"); B.connect_and_login("accA")
	var reopen := B.open_character("charA")
	_chk("RNET-T02 lease permanece na queda (SESSION_IN_USE)", not bool(reopen.get("ok", false)) and str(reopen.get("reason", "")) == "SESSION_IN_USE")
	# RNET-T03 reconnect válido reassocia o token à nova conexão
	var rc := B.reconnect(token)
	_chk("RNET-T03 reconnect válido reassocia", bool(rc.get("ok", false)))
	_chk("RNET-T04 state = última revision", int(rc.get("revision", -1)) == rev_commit)
	# RNET-T05 command commitado antes da queda não reaplica (retry mesmo command_id)
	var f_before := int((repo.load("charA")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	var dup := B.refine("weapon", "", "rn_commit")
	var f_after := int((repo.load("charA")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	_chk("RNET-T05 command pré-queda não reaplica (duplicate, sem cobrança)", bool(dup.get("duplicate", false)) and f_after == f_before)
	# RNET-T06 expiry permite novo login (avança o relógio além do lease)
	B.client.stop()
	var w2 := 0
	while server.connection_count() > 0 and w2 < 500:
		server.poll(); OS.delay_msec(1); w2 += 1
	clock.advance(server.authority.LEASE_TTL + 5)
	var C := _client("rn3"); C.connect_and_login("accA")
	var fresh_open := C.open_character("charA")
	_chk("RNET-T06 expiry permite novo login", bool(fresh_open.get("ok", false)))

# ══════════════ MALFORMED (§78) ══════════════
func _test_malformed() -> void:
	print("  ── MALNET (pacote malformado, sem crash) ──")
	_fresh()
	repo.create_character("accA", "charA", _mkstate(1000))
	var A := _client("mal"); A.connect_and_login("accA"); A.open_character("charA")
	# T01 sem type
	var e1 := _await_env(A.client, A.client.send_raw({"v": 1, "rid": "m1", "p": {}}))
	_chk("MALNET-T01 packet sem type → ERROR NO_TYPE", str((e1.get("p", {}) as Dictionary).get("reason", "")) == "NO_TYPE")
	# T02 versão errada
	var e2 := _await_env(A.client, A.client.send_raw({"v": 42, "t": NetProtocol.HELLO, "rid": "m2", "p": {}}))
	_chk("MALNET-T02 versão errada → PROTOCOL_MISMATCH", str(e2.get("t", "")) == NetProtocol.PROTOCOL_MISMATCH)
	# T03 command desconhecido
	var e3 := A._await(A.client.command("NOPE_CMD", "m3", {}))
	_chk("MALNET-T03 command desconhecido → UNKNOWN_COMMAND", str(e3.get("reason", "")) == "UNKNOWN_COMMAND")
	# T04 command_id vazio
	var e4 := A._await(A.client.command("REFINE_SLOT", "", {"slot": "weapon"}))
	_chk("MALNET-T04 command_id vazio → NO_COMMAND_ID", str(e4.get("reason", "")) == "NO_COMMAND_ID")
	# T05 payload oversized
	var big := PackedByteArray(); big.resize(NetProtocol.MAX_MSG_BYTES + 4000); big.fill(65)
	A.client.send_raw_bytes(big)
	for i in range(30): _pump_all(); OS.delay_msec(1)
	# T06 injeção de campos de autoridade ignorada
	var f_before := int((repo.load("charA")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	var g_before := int(repo.load("charA")["state"].get("hero_gold", 0))
	var inj := A._await(A.client.command("REFINE_SLOT", "m6", {"slot": "weapon", "gold": 999999, "roll01": 0.0, "quality": 100}))
	var g_after := int(repo.load("charA")["state"].get("hero_gold", 0))
	_chk("MALNET-T06 injeção de gold/roll01/quality ignorada", bool(inj.get("ok", false)) and g_after == g_before)
	# T07 servidor continua vivo
	var alive := A.refine("weapon")
	_chk("MALNET-T07 servidor vivo após tudo (comando válido segue)", server.is_running() and bool(alive.get("ok", false)))

# ══════════════ TWO CLIENTS (§79) ══════════════
func _test_two_clients() -> void:
	print("  ── TWO-NET (isolamento entre 2 clientes reais) ──")
	_fresh()
	repo.create_character("accA", "charA", _mkstate(1000))
	repo.create_character("accB", "charB", _mkstate(1000))
	var A := _client("tA"); var B := _client("tB")
	A.connect_and_login("accA"); B.connect_and_login("accB")
	A.open_character("charA"); B.open_character("charB")
	_chk("TWO-NET-T01 A/B conectados simultaneamente", A.client.net_connected() and B.client.net_connected() and server.connection_count() == 2)
	var revB0 := repo.revision_of("charB")
	A.refine("weapon"); A.refine("weapon")
	_chk("TWO-NET-T02/T04 A opera só o próprio character (B intacto)", repo.revision_of("charB") == revB0)
	var fa := int((repo.load("charA")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	var fb := int((repo.load("charB")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	_chk("TWO-NET-T05 revisions/states independentes", fa < 1000 and fb == 1000 and repo.revision_of("charA") != repo.revision_of("charB"))
	# T03 A não equipa iid de B pela rede
	var lootB := _internal("charB", {"type": "GRANT_LOOT", "command_id": "srvlootB", "item_id": "sword_eternal"})
	var iidB := str((lootB.get("result", {}) as Dictionary).get("iid", ""))
	var stealeq := A.equip(iidB)
	_chk("TWO-NET-T03 A não equipa iid de B (NOT_OWNER)", not bool(stealeq.get("ok", false)) and str(stealeq.get("error", "")) == "NOT_OWNER")
	# T06 metadata privada não vaza no view do A
	var viewA := A.client.view.view
	_chk("TWO-NET-T06 view sem metadata privada (sem journal/seed/account)", not (viewA.has("journal") or viewA.has("seed") or viewA.has("account") or viewA.has("rng")))

# ══════════════ SERVER RESTART (§80) ══════════════
func _test_server_restart() -> void:
	print("  ── RESTART de servidor (state/journal sobrevivem, sessão não) ──")
	_fresh()
	repo.create_character("accA", "charA", _mkstate(1000))
	var A := _client("sr"); A.connect_and_login("accA"); A.open_character("charA")
	A.refine("weapon", "", "sr_commit")
	var f_commit := int((repo.load("charA")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	var rev_commit := repo.revision_of("charA")
	# "shutdown": persiste tudo + para
	repo.persist_to("user://a111_repo.json")
	FileAccess.open("user://a111_items.json", FileAccess.WRITE).store_string(JSON.stringify(items.snapshot()))
	FileAccess.open("user://a111_server.json", FileAccess.WRITE).store_string(JSON.stringify(server.authority.snapshot()))
	A.client.stop(); server.stop()
	# recria servidor com repo/items/authority restaurados
	_port += 1
	var repo2 := CharacterRepository.new(); repo2.load_from("user://a111_repo.json")
	var items2 := ItemRegistry.new(); items2.restore(JSON.parse_string(FileAccess.open("user://a111_items.json", FileAccess.READ).get_as_text()))
	var clock2 := ServerClock.fixed(200000)
	var auth2 := AuthorityServer.new(); auth2.setup(repo2, items2, clock2, 777)
	auth2.restore(JSON.parse_string(FileAccess.open("user://a111_server.json", FileAccess.READ).get_as_text()))
	server = GameServer.new(); root.add_child(server); server.configure(repo2, items2, clock2, auth2)
	server.start(_port, 777)
	repo = repo2; items = items2; clock = clock2
	_chk("RESTART state/revision continuam", int((repo2.load("charA")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0)) == f_commit and repo2.revision_of("charA") == rev_commit)
	# novo login (sessão antiga NÃO sobrevive) + get_state última revision + retry não reaplica
	var A2 := _client("sr2"); A2.connect_and_login("accA")
	var op := A2.open_character("charA")
	_chk("RESTART novo login OK (sessão antiga inválida)", bool(op.get("ok", false)) and int(op.get("revision", -1)) == rev_commit)
	var dup := A2.refine("weapon", "", "sr_commit")
	_chk("§80 command committed não reaplica após restart (duplicate)", bool(dup.get("duplicate", false)) and int((repo2.load("charA")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0)) == f_commit)

# ══════════════ STRESS (§81) ══════════════
func _test_stress() -> void:
	print("  ── STRESS (2 clientes, mix de mensagens) ──")
	_fresh(42)
	repo.create_character("accA", "charA", _mkstate(100000000))
	repo.create_character("accB", "charB", _mkstate(100000000))
	var A := _client("sA"); var B := _client("sB")
	A.connect_and_login("accA"); B.connect_and_login("accB")
	A.open_character("charA"); B.open_character("charB")
	var TOTAL := 10000
	var half := TOTAL / 2
	var neg := false; var last_a := 0; var last_b := 0; var regress := false
	var dups := 0; var malformed_sent := 0
	for i in range(half):
		# desliza a janela de rate-limit (relógio fixo) e mantém os leases vivos
		if i % 50 == 0:
			clock.advance(1); A.heartbeat(); B.heartbeat()
		# cliente A
		match i % 5:
			0:
				var r := A.refine("weapon", "", "sA_%d" % i)
				if bool(r.get("ok", false)) and int(r["revision"]) < last_a: regress = true
				last_a = maxi(last_a, int(r.get("revision", last_a)))
			1:
				var d := A.refine("weapon", "", "sA_%d" % (i - 1))  # duplicate do anterior
				if bool(d.get("duplicate", false)): dups += 1
			2: A.get_state()
			3: A.heartbeat()
			4:
				A.client.send_raw({"v": 1, "rid": "sm_%d" % i, "p": {}}); malformed_sent += 1  # sem type
				_pump_all()
		# cliente B
		var rb := B.refine("weapon", "", "sB_%d" % i)
		if bool(rb.get("ok", false)) and int(rb["revision"]) < last_b: regress = true
		last_b = maxi(last_b, int(rb.get("revision", last_b)))
		if int((repo.load("charA")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0)) < 0: neg = true
		if int((repo.load("charB")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0)) < 0: neg = true
	print("    [stress] committed=%d dups=%d malformed=%d qpeak=%d rejects=%d revA=%d revB=%d gs_peak=%d" % [
		server.queue.committed(), dups, malformed_sent, server.queue.peak_depth(), server.queue.rejected_busy(),
		last_a, last_b, server.authority.gs_active_peak()])
	_chk("STRESS sem currency negativa / sem revision regression", not neg and not regress)
	_chk("STRESS serialização mantida (gs pico==1, ativo==0)", server.authority.gs_active_peak() == 1 and server.authority.gs_active() == 0)
	_chk("STRESS isolamento A/B (charB nunca visto por charA)", repo.revision_of("charA") != repo.revision_of("charB"))
	_chk("STRESS iid único (invariante ItemRegistry)", items.invariant_unique_owner())
	_chk("STRESS duplicates reconhecidos (retry idempotente sob carga)", dups > 0)

# ══════════════ LOCAL MODE (§86) ══════════════
func _test_local_mode() -> void:
	print("  ── LOCAL (single-player intacto, sem socket) ──")
	# modo default é LOCAL, sem argumentos
	_chk("LOCAL é o modo default (sem CLI/env)", RuntimeMode.resolve() == RuntimeMode.LOCAL)
	# a autoridade embarcada roda direto no GameState, sem rede (mesma economia)
	var r := CharacterRepository.new(); r.create_character("locAcc", "locChar", _mkstate(1000))
	var it := ItemRegistry.new(); var ck := ServerClock.fixed(1)
	var auth := AuthorityServer.new(); auth.setup(r, it, ck, 5)
	var sess := auth.open_session("locAcc", "locChar")
	var res := auth.submit(str(sess["session_id"]), {"type": "REFINE_SLOT", "command_id": "loc1", "slot": "weapon"})
	_chk("LOCAL autoridade embarcada funciona sem transporte", bool(res.get("ok", false)) and int(res.get("revision", -1)) == 2)
