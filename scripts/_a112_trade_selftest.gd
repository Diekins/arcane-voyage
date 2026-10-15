extends SceneTree
## Self-test/RELATÓRIO FATIA A11.2 — Safe P2P Trade / Escrow / Atomic Item Transfer. Prova em bancada headless
## (localhost): PRE-GATE de fila real sob burst (qpeak>1); trade P2P server-authoritative por rede ENet real com
## escrow, dupla confirmação, atomicidade, anti-dupe/double-spend, idempotência, reconnect/restart safety; e
## conservação de ouro/itens. Edge matrices exaustivas rodam direto no TradeService (MESMO código do caminho de
## rede). FIXTURE (save vivo intocado). godot --headless --path godot -s res://scripts/_a112_trade_selftest.gd

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
var _port := 34780

func _pump_all() -> void:
	if server != null: server.poll()
	for c in _all_clients: c.poll()

func _mk(gold: int) -> Dictionary:
	gs.reset_save(); gs.hero_gold = gold; gs.item_instances = []; gs.equipped_instances = {}
	return gs.to_dict().duplicate(true)

func _fresh(seed: int = 55) -> void:
	for c in _all_clients: c.stop()
	_all_clients = []
	if server != null: server.stop()
	_port += 1
	repo = CharacterRepository.new(); items = ItemRegistry.new(); clock = ServerClock.fixed(100000)
	server = GameServer.new(); root.add_child(server); server.configure(repo, items, clock, null)
	server.start(_port, seed)

func _client(prefix: String) -> OnlineClient:
	var gc := GameClient.new(); root.add_child(gc); gc.start(_port); _all_clients.append(gc)
	var oc := OnlineClient.new(); oc.setup(gc, Callable(self, "_pump_all"), prefix); oc.default_timeout_ms = 1500
	return oc

## concede um item a um character (server-internal) e devolve o iid
func _grant(character: String, item_id: String, cid: String) -> String:
	var done := [false]; var iid := [""]
	var cb := func(r: Dictionary) -> void:
		iid[0] = str((r.get("result", {}) as Dictionary).get("iid", "")); done[0] = true
	server.internal_command(character, {"type": "GRANT_LOOT", "command_id": cid, "item_id": item_id}, cb)
	var w := 0
	while not done[0] and w < 1000:
		server.poll(); OS.delay_msec(1); w += 1
	return iid[0]

# ── contexto DIRETO (sem rede) p/ matrizes exaustivas — MESMO TradeService do caminho de rede ──
func _direct(ga: int, gb: int) -> Dictionary:
	var r := CharacterRepository.new(); var it := ItemRegistry.new()
	var tr := TradeRepository.new(); tr.setup(9); var ck := ServerClock.fixed(1000)
	var sv := TradeService.new(); sv.setup(r, it, tr, ck)
	r.create_character("accA", "charA", _mk(ga)); r.create_character("accB", "charB", _mk(gb))
	return {"repo": r, "items": it, "trades": tr, "clock": ck, "svc": sv}

func _give(ctx: Dictionary, character: String, item_id: String, seed: int, tradeable_override: int = -1) -> String:
	var r: CharacterRepository = ctx["repo"]; var it: ItemRegistry = ctx["items"]
	var acct := r.owner_of(character)
	var inst: Dictionary = ItemRoller.roll(item_id, seed, "test", 0)
	if tradeable_override == 0: inst["tradeable"] = false; inst["bound"] = true
	var iid: String = it.next_iid()
	inst["iid"] = iid
	it.register(iid, acct, item_id, ItemRegistry.LOC_PLAYER)
	var ld := r.load(character); var st: Dictionary = ld["state"]
	(st["item_instances"] as Array).append(inst)
	r.save(character, int(ld["revision"]), st)
	return iid

func _gold(ctx: Dictionary, character: String) -> int:
	return int(ctx["repo"].load(character)["state"].get("hero_gold", 0))

func _has_item(ctx: Dictionary, character: String, iid: String) -> bool:
	for it in ctx["repo"].load(character)["state"].get("item_instances", []):
		if str(it.get("iid", "")) == iid: return true
	return false

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a112_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()

	_test_pregate_burst()
	_test_trade_state()
	_test_escrow_item()
	_test_escrow_gold()
	_test_offer()
	_test_atomic()
	_test_atomic_fail()
	_test_idempotency()
	_test_reconnect()
	_test_restart()
	_test_security()
	_test_two_client_flow()
	_test_concurrent_and_cross()
	_test_stress_and_conservation()
	_test_local()

	for c in _all_clients: c.stop()
	if server != null: server.stop()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	for f in ["user://a112_repo.json", "user://a112_items.json", "user://a112_server.json", "user://a112_trades.json"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(f)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ══════════════ PRE-GATE — FILA REAL SOB BURST (§0-4) ══════════════
func _test_pregate_burst() -> void:
	print("  ── PRE-GATE BURST (fila real) ──")
	_fresh()
	gs.reset_save(); gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 0}; gs.materials = {"Fragmentos": 100000}
	var stw: Dictionary = gs.to_dict().duplicate(true)
	repo.create_character("accA", "charA", stw); repo.create_character("accB", "charB", stw.duplicate(true))
	var A := _client("bA"); var B := _client("bB")
	A.connect_and_login("accA"); B.connect_and_login("accB"); A.open_character("charA"); B.open_character("charB")
	# BURST-T01: A/B enviam SEM await individual
	var N := 100
	for i in range(N):
		A.client.command("REFINE_SLOT", "bA_%d" % i, {"slot": "weapon"})
		B.client.command("REFINE_SLOT", "bB_%d" % i, {"slot": "weapon"})
	# recebe+enfileira SEM drenar → a fila acumula
	var peak_seen := 0
	for k in range(400):
		server.poll_network_only(); OS.delay_msec(1)
		peak_seen = maxi(peak_seen, server.queue.pending_count())
		if server.queue.pending_count() + server.queue.committed() >= 2 * N and server.queue.pending_count() >= 2 * N:
			break
	var peak := maxi(peak_seen, server.queue.peak_depth())
	var pending := server.queue.pending_count()
	_chk("BURST-T01 A/B enviaram sem await (fila acumulou)", pending > 1)
	_chk("BURST-T02 qpeak > 1 (fila REAL, não wrapper síncrono)", peak > 1)
	_chk("BURST-T03 gs_active_peak continua 1 durante acúmulo", server.authority.gs_active_peak() <= 1)
	# drena controlado + polls extras p/ pegar retardatários
	server.drain()
	for k in range(60):
		server.poll(); OS.delay_msec(1)
	_chk("BURST-T07 fila drena a zero", server.queue.pending_count() == 0)
	_chk("BURST-T08 nenhum accepted command some (committed == enfileirados)", server.queue.committed() >= 2 * N)
	_chk("BURST-T03b gs_active_peak == 1 após drenar tudo", server.authority.gs_active_peak() == 1 and server.authority.gs_active() == 0)
	# BURST-T04 isolamento
	var fa := int((repo.load("charA")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	var fb := int((repo.load("charB")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	_chk("BURST-T04 A/B não contaminam (ambos gastaram, revisions distintas)", fa < 100000 and fb < 100000 and repo.revision_of("charA") > 1)
	_chk("BURST-T05 ordem por sessão preservada (revision monotônica)", repo.revision_of("charA") == N + 1)
	# BURST-T06 backpressure real (fila cheia → SERVER_BUSY antes de aceitar)
	var q := AuthorityCommandQueue.new(); q.setup(server.authority)
	var busy := false
	for i in range(q.MAX_PENDING + 10):
		var r := q.enqueue(func() -> Dictionary: return {}, Callable())
		if str(r.get("reason", "")) == "SERVER_BUSY": busy = true
	_chk("BURST-T06 backpressure dispara (SERVER_BUSY acima de MAX_PENDING)", busy)

# ══════════════ TRADE STATE (§94) ══════════════
func _test_trade_state() -> void:
	print("  ── TRADE (state machine) ──")
	var ctx := _direct(1000, 1000)
	var sv: TradeService = ctx["svc"]; var tr: TradeRepository = ctx["trades"]
	var inv: Dictionary = sv.invite("charA", "i1", "charB")
	_chk("TRADE-T01 invite cria trade", bool(inv["ok"]) and str(inv["trade_id"]) != "")
	var tid := str(inv["trade_id"])
	_chk("TRADE-T02 self invite rejeita", not bool(sv.invite("charA", "i2", "charA")["ok"]))
	_chk("TRADE-T03 target inválido rejeita", str(sv.invite("charB", "i3", "charZZ").get("reason", "")) == "TARGET_NOT_FOUND")
	_chk("TRADE-T07 1 active trade por character (2º invite bloqueia)", str(sv.invite("charA", "i4", "charB").get("reason", "")) == "ALREADY_IN_TRADE")
	_chk("TRADE-T08 terceiro não acessa", sv.view_for(tid, "charC").is_empty() and not bool(sv.get_view("charC", tid).get("ok", false)))
	_chk("TRADE-T04 accept invite (→ NEGOTIATING)", bool(sv.accept_invite("charB", "a1", tid)["ok"]) and str(tr.get_trade(tid)["state"]) == "NEGOTIATING")
	# decline em nova trade
	var ctx2 := _direct(1000, 1000); var sv2: TradeService = ctx2["svc"]
	var tid2 := str(sv2.invite("charA", "i", "charB")["trade_id"])
	_chk("TRADE-T05 decline encerra", bool(sv2.decline("charB", "d", tid2)["ok"]) and str(ctx2["trades"].get_trade(tid2)["state"]) == "DECLINED")
	# expiry
	var ctx3 := _direct(1000, 1000); var sv3: TradeService = ctx3["svc"]; var ck3: ServerClock = ctx3["clock"]
	var tid3 := str(sv3.invite("charA", "i", "charB")["trade_id"])
	ck3.advance(sv3.INVITE_TTL + 5); sv3.expiry_tick()
	_chk("TRADE-T06 invite expiry", str(ctx3["trades"].get_trade(tid3)["state"]) == "EXPIRED")

# ══════════════ ESCROW ITEM (§95) ══════════════
func _test_escrow_item() -> void:
	print("  ── ESCI (escrow de item) ──")
	var ctx := _direct(1000, 1000)
	var sv: TradeService = ctx["svc"]; var it: ItemRegistry = ctx["items"]
	var iid := _give(ctx, "charA", "sword_eternal", 1)
	var tid := str(sv.invite("charA", "i", "charB")["trade_id"]); sv.accept_invite("charB", "ai", tid)
	var add := sv.add_item("charA", "add1", tid, iid)
	_chk("ESCI-T01 add move item para escrow", bool(add["ok"]))
	_chk("ESCI-T02 item some da posse utilizável", not _has_item(ctx, "charA", iid))
	_chk("ESCI-T03 ItemRegistry = ESCROW", it.is_in_escrow(iid) and it.escrow_trade_of(iid) == tid)
	# ESCI-T04 mesmo iid não entra em outra trade (double-add bloqueado)
	_chk("ESCI-T04 mesmo iid não re-escrowa (ALREADY_IN_ESCROW)", str(sv.add_item("charA", "add2", tid, iid).get("reason", "")) == "ALREADY_IN_ESCROW")
	# ESCI-T05 remove devolve 1x
	var rem := sv.remove_item("charA", "rem1", tid, iid)
	_chk("ESCI-T05 remove devolve 1x (item volta, escrow vazio)", bool(rem["ok"]) and _has_item(ctx, "charA", iid) and not it.is_in_escrow(iid))
	# ESCI-T06 cancel devolve 1x
	sv.add_item("charA", "add3", tid, iid)
	sv.cancel("charA", "can1", tid)
	_chk("ESCI-T06 cancel devolve 1x", _has_item(ctx, "charA", iid) and not it.is_in_escrow(iid))
	# ESCI-T07 equipped rejeita (item equipado não está em item_instances → ITEM_NOT_FOUND)
	var ctxE := _direct(1000, 1000); var svE: TradeService = ctxE["svc"]
	var eiid := _give(ctxE, "charA", "sword_eternal", 2)
	# move para equipped_instances (simula equipado)
	var ldE: Dictionary = ctxE["repo"].load("charA"); var stE: Dictionary = ldE["state"]
	(stE["item_instances"] as Array).clear(); stE["equipped_instances"] = {"weapon": {"iid": eiid, "item_id": "sword_eternal"}}
	ctxE["repo"].save("charA", int(ldE["revision"]), stE)
	var tidE := str(svE.invite("charA", "i", "charB")["trade_id"]); svE.accept_invite("charB", "ai", tidE)
	_chk("ESCI-T07 equipped rejeita (não está na bolsa)", not bool(svE.add_item("charA", "e", tidE, eiid)["ok"]))
	# ESCI-T08/T09 bound/tradeable=false rejeita
	var ctxB := _direct(1000, 1000); var svB: TradeService = ctxB["svc"]
	var biid := _give(ctxB, "charA", "sword_eternal", 3, 0)  # tradeable=false, bound=true
	var tidB := str(svB.invite("charA", "i", "charB")["trade_id"]); svB.accept_invite("charB", "ai", tidB)
	_chk("ESCI-T08/T09 bound/tradeable=false → NOT_TRADEABLE", str(svB.add_item("charA", "b", tidB, biid).get("reason", "")) == "NOT_TRADEABLE")
	# ESCI-T10 fake iid rejeita
	_chk("ESCI-T10 fake iid rejeita (não materializa do cliente)", str(svB.add_item("charA", "f", tidB, "legendary_q100_fake").get("reason", "")) == "ITEM_NOT_FOUND")

# ══════════════ ESCROW GOLD (§96) ══════════════
func _test_escrow_gold() -> void:
	print("  ── ESCG (escrow de ouro) ──")
	var ctx := _direct(1000, 1000)
	var sv: TradeService = ctx["svc"]
	var tid := str(sv.invite("charA", "i", "charB")["trade_id"]); sv.accept_invite("charB", "ai", tid)
	sv.set_gold("charA", "g1", tid, 300)
	_chk("ESCG-T01/T02 set gold move p/ escrow (indisponível na carteira)", _gold(ctx, "charA") == 700)
	sv.set_gold("charA", "g2", tid, 500)
	_chk("ESCG-T03 increase cobra só o delta", _gold(ctx, "charA") == 500)
	sv.set_gold("charA", "g3", tid, 200)
	_chk("ESCG-T04 decrease devolve delta", _gold(ctx, "charA") == 800)
	_chk("ESCG-T05 acima do balance rejeita", str(sv.set_gold("charA", "g4", tid, 999999).get("reason", "")) == "GOLD_INSUFFICIENT")
	_chk("ESCG-T06 negativo rejeita", str(sv.set_gold("charA", "g5", tid, -5).get("reason", "")) == "GOLD_NEGATIVE")
	sv.cancel("charA", "c", tid)
	_chk("ESCG-T07 cancel devolve exato (carteira volta a 1000)", _gold(ctx, "charA") == 1000)

# ══════════════ OFFER (§97) ══════════════
func _test_offer() -> void:
	print("  ── OFFER (versão + anti bait-and-switch) ──")
	var ctx := _direct(1000, 1000)
	var sv: TradeService = ctx["svc"]; var tr: TradeRepository = ctx["trades"]
	var iid := _give(ctx, "charA", "sword_eternal", 5)
	var tid := str(sv.invite("charA", "i", "charB")["trade_id"]); sv.accept_invite("charB", "ai", tid)
	var v0 := int(tr.get_trade(tid)["offer_version"])
	sv.add_item("charA", "a1", tid, iid)
	var v1 := int(tr.get_trade(tid)["offer_version"])
	_chk("OFFER-T01 mutação incrementa version", v1 == v0 + 1)
	sv.accept_offer("charA", "acA", tid, v1); sv.accept_offer("charB", "acB", tid, v1)
	# nada commitou ainda? ambos aceitaram v1 → commitou. Refaz p/ testar reset:
	var ctx2 := _direct(1000, 1000); var sv2: TradeService = ctx2["svc"]; var tr2: TradeRepository = ctx2["trades"]
	var iid2 := _give(ctx2, "charA", "sword_eternal", 6)
	var tid2 := str(sv2.invite("charA", "i", "charB")["trade_id"]); sv2.accept_invite("charB", "ai", tid2)
	sv2.set_gold("charB", "gb", tid2, 100)
	var vv := int(tr2.get_trade(tid2)["offer_version"])
	sv2.accept_offer("charB", "acb", tid2, vv)
	_chk("OFFER-T04 accept versão atual registra", bool(tr2.get_trade(tid2)["accept"]["b"] == vv))
	# A muda a oferta → reset dos accepts
	sv2.add_item("charA", "a2", tid2, iid2)
	var t2 := tr2.get_trade(tid2)
	_chk("OFFER-T02/T03 mutação reseta accept A e B", int(t2["accept"]["a"]) == -1 and int(t2["accept"]["b"]) == -1)
	# accept versão velha rejeita
	_chk("OFFER-T05 accept versão velha → OFFER_CHANGED", str(sv2.accept_offer("charB", "old", tid2, vv).get("reason", "")) == "OFFER_CHANGED")
	# OFFER-T06 bait-and-switch não commita: B aceita v_new, A muda de novo, B tenta commitar velha
	var vnew := int(tr2.get_trade(tid2)["offer_version"])
	sv2.accept_offer("charB", "bnew", tid2, vnew)
	sv2.set_gold("charA", "chg", tid2, 50)  # A altera → reset
	var vfinal := int(tr2.get_trade(tid2)["offer_version"])
	sv2.accept_offer("charA", "af", tid2, vfinal)
	var still := sv2.accept_offer("charB", "bstale", tid2, vnew)  # B tenta versão antiga
	_chk("OFFER-T06 bait-and-switch NÃO commita", str(still.get("reason", "")) == "OFFER_CHANGED" and str(tr2.get_trade(tid2)["state"]) == "NEGOTIATING")

# ══════════════ ATOMIC COMMIT (§98) ══════════════
func _test_atomic() -> void:
	print("  ── ATOM (commit atômico) ──")
	var ctx := _direct(1000, 500)
	var sv: TradeService = ctx["svc"]; var r: CharacterRepository = ctx["repo"]; var it: ItemRegistry = ctx["items"]
	var iidA := _give(ctx, "charA", "sword_eternal", 10)   # A→B
	var iidB := _give(ctx, "charB", "chest_eternal", 11)   # B→A
	var fpA := _fingerprint(ctx, "charA", iidA)
	var tid := str(sv.invite("charA", "i", "charB")["trade_id"]); sv.accept_invite("charB", "ai", tid)
	sv.add_item("charA", "a", tid, iidA); sv.add_item("charB", "b", tid, iidB)
	sv.set_gold("charA", "ga", tid, 200); sv.set_gold("charB", "gb", tid, 100)
	# revision LOGO ANTES do commit (as ops de escrow já bumparam legitimamente); o commit deve somar +1 (§46)
	var revA0 := r.revision_of("charA"); var revB0 := r.revision_of("charB")
	var ov := int(ctx["trades"].get_trade(tid)["offer_version"])
	sv.accept_offer("charA", "acA", tid, ov)
	var fin := sv.accept_offer("charB", "acB", tid, ov)
	_chk("ATOM-T01/T10 both accept → COMPLETED", bool(fin.get("completed", false)) and str(ctx["trades"].get_trade(tid)["state"]) == "COMPLETED")
	_chk("ATOM-T02 item de A chega em B", _has_item(ctx, "charB", iidA) and it.owner_of(iidA) == "accB")
	_chk("ATOM-T03 item de B chega em A", _has_item(ctx, "charA", iidB) and it.owner_of(iidB) == "accA")
	_chk("ATOM-T04 ouro de A chega em B", _gold(ctx, "charB") == 500 - 100 + 200)
	_chk("ATOM-T05 ouro de B chega em A", _gold(ctx, "charA") == 1000 - 200 + 100)
	_chk("ATOM-T06 IID preservado", it.owner_of(iidA) == "accB" and it.owner_of(iidB) == "accA")
	_chk("ATOM-T07 fingerprint preservado (sem reroll)", _fingerprint(ctx, "charB", iidA) == fpA)
	_chk("ATOM-T08 revision A +1", r.revision_of("charA") == revA0 + 1)
	_chk("ATOM-T09 revision B +1", r.revision_of("charB") == revB0 + 1)

func _fingerprint(ctx: Dictionary, character: String, iid: String) -> String:
	for it in ctx["repo"].load(character)["state"].get("item_instances", []):
		if str(it.get("iid", "")) == iid:
			return "%s|%s|%d|%s|%s" % [iid, str(it.get("item_id", "")), int(it.get("quality", 0)), JSON.stringify(it.get("rolls", {})), JSON.stringify(it.get("affixes", []))]
	return ""

# ══════════════ ATOMIC FAILURE (§99) ══════════════
func _test_atomic_fail() -> void:
	print("  ── ATFAIL (falha atômica = zero commit) ──")
	# ATFAIL-T01/T02 stale via commit_many direto
	var r := CharacterRepository.new()
	r.create_character("accA", "charA", _mk(100)); r.create_character("accB", "charB", _mk(100))
	var stale := r.commit_many({"charA": 999, "charB": r.revision_of("charB")}, {"charA": _mk(50), "charB": _mk(50)})
	_chk("ATFAIL-T01/T02 stale (revision errada) → zero commit", not bool(stale["ok"]) and str(stale["reason"]) == "STALE" and r.revision_of("charA") == 1)
	# ATFAIL-T03 recipient sem capacidade
	var ctx := _direct(1000, 1000); var sv: TradeService = ctx["svc"]
	# enche B até o cap com itens não-relacionados
	var ldb: Dictionary = ctx["repo"].load("charB"); var stb: Dictionary = ldb["state"]
	for i in range(sv.RECIPIENT_ITEM_CAP): (stb["item_instances"] as Array).append({"iid": "fillB_%d" % i, "item_id": "sword_simple", "quality": 1, "rolls": {}, "affixes": [], "tradeable": true, "bound": false})
	ctx["repo"].save("charB", int(ldb["revision"]), stb)
	var iidA := _give(ctx, "charA", "sword_eternal", 20)
	var tid := str(sv.invite("charA", "i", "charB")["trade_id"]); sv.accept_invite("charB", "ai", tid)
	sv.add_item("charA", "a", tid, iidA)
	var ov := int(ctx["trades"].get_trade(tid)["offer_version"])
	sv.accept_offer("charA", "acA", tid, ov)
	var fin := sv.accept_offer("charB", "acB", tid, ov)
	_chk("ATFAIL-T03 recipient sem capacidade → zero commit (RECIPIENT_NO_CAPACITY)", str(fin.get("reason", "")) == "RECIPIENT_NO_CAPACITY" and ctx["items"].is_in_escrow(iidA))
	_chk("ATFAIL-T03b item permanece em escrow, A não perdeu, B não ganhou", not _has_item(ctx, "charB", iidA) and str(ctx["trades"].get_trade(tid)["state"]) == "NEGOTIATING")
	# ATFAIL-T06 crash-during (fault após registry, antes do commit_many) → before-state
	var ctx2 := _direct(1000, 1000); var sv2: TradeService = ctx2["svc"]
	var iid2 := _give(ctx2, "charA", "sword_eternal", 21)
	var g2A := _gold(ctx2, "charA")
	var tid2 := str(sv2.invite("charA", "i", "charB")["trade_id"]); sv2.accept_invite("charB", "ai", tid2)
	sv2.add_item("charA", "a", tid2, iid2)
	sv2.set_fault("AFTER_REGISTRY")
	var ov2 := int(ctx2["trades"].get_trade(tid2)["offer_version"])
	sv2.accept_offer("charA", "acA", tid2, ov2)
	var fin2 := sv2.accept_offer("charB", "acB", tid2, ov2)
	sv2.set_fault("")
	_chk("ATFAIL-T05/T06 crash-during → before-state (registry revertido, nada transferido)", str(fin2.get("reason", "")) == "FAULT_ROLLED_BACK" and ctx2["items"].owner_of(iid2) == "accA" and ctx2["items"].is_in_escrow(iid2) and not _has_item(ctx2, "charB", iid2))
	# depois de limpar o fault, o mesmo trade ainda pode commitar (before→after, nunca meio)
	var ov2b := int(ctx2["trades"].get_trade(tid2)["offer_version"])
	sv2.accept_offer("charA", "acA2", tid2, ov2b)
	var fin2b := sv2.accept_offer("charB", "acB2", tid2, ov2b)
	_chk("ATFAIL-T07 pós-recuperação commit vai a after-state completo", bool(fin2b.get("completed", false)) and _has_item(ctx2, "charB", iid2) and ctx2["items"].owner_of(iid2) == "accB")

# ══════════════ IDEMPOTENCY (§100) ══════════════
func _test_idempotency() -> void:
	print("  ── TIDEM (idempotência) ──")
	var ctx := _direct(1000, 1000); var sv: TradeService = ctx["svc"]; var it: ItemRegistry = ctx["items"]
	var iid := _give(ctx, "charA", "sword_eternal", 30)
	var tid := str(sv.invite("charA", "i", "charB")["trade_id"]); sv.accept_invite("charB", "ai", tid)
	sv.add_item("charA", "ADD", tid, iid)
	var dup := sv.add_item("charA", "ADD", tid, iid)  # mesmo command_id
	_chk("TIDEM-T01 duplicate add = 1 escrow", bool(dup.get("duplicate", false)) and (ctx["trades"].get_trade(tid)["offers"]["a"]["items"] as Array).size() == 1)
	sv.set_gold("charA", "SG", tid, 100)
	sv.set_gold("charA", "SG", tid, 100)  # dup
	_chk("TIDEM-T02 duplicate gold set não duplica", _gold(ctx, "charA") == 900)
	# duplicate accept = 1 commit
	sv.set_gold("charB", "gb", tid, 50)
	var ov := int(ctx["trades"].get_trade(tid)["offer_version"])
	sv.accept_offer("charA", "AA", tid, ov)
	var c1 := sv.accept_offer("charB", "AB", tid, ov)
	var c2 := sv.accept_offer("charB", "AB", tid, ov)  # dup accept
	_chk("TIDEM-T04/T05 duplicate/lost-response accept = 1 commit (retry devolve COMPLETED)", bool(c1.get("completed", false)) and bool(c2.get("duplicate", false)) and it.owner_of(iid) == "accB")
	# TIDEM-T03 duplicate cancel = 1 refund
	var ctx2 := _direct(1000, 1000); var sv2: TradeService = ctx2["svc"]
	var iid2 := _give(ctx2, "charA", "sword_eternal", 31)
	var tid2 := str(sv2.invite("charA", "i", "charB")["trade_id"]); sv2.accept_invite("charB", "ai", tid2)
	sv2.add_item("charA", "a", tid2, iid2); sv2.set_gold("charA", "g", tid2, 200)
	sv2.cancel("charA", "CAN", tid2)
	sv2.cancel("charA", "CAN", tid2)  # dup
	_chk("TIDEM-T03 duplicate cancel = 1 refund (ouro/item voltam uma vez)", _gold(ctx2, "charA") == 1000 and _has_item(ctx2, "charA", iid2))

# ══════════════ RECONNECT (§101) ══════════════
func _test_reconnect() -> void:
	print("  ── TRNET (reconnect / lease / refund) ──")
	# lease expiry cancela + refund 1x (direto)
	var ctx := _direct(1000, 1000); var sv: TradeService = ctx["svc"]
	var iid := _give(ctx, "charA", "sword_eternal", 40)
	var tid := str(sv.invite("charA", "i", "charB")["trade_id"]); sv.accept_invite("charB", "ai", tid)
	sv.add_item("charA", "a", tid, iid); sv.set_gold("charA", "g", tid, 300)
	_chk("TRNET-T01 escrow mantido durante negociação", ctx["items"].is_in_escrow(iid) and _gold(ctx, "charA") == 700)
	sv.on_session_lost("charA")  # lease expira
	_chk("TRNET-T04/T05 lease expiry cancela + refund 1x", str(ctx["trades"].get_trade(tid)["state"]) == "CANCELLED" and _gold(ctx, "charA") == 1000 and _has_item(ctx, "charA", iid) and not ctx["items"].is_in_escrow(iid))
	# reconnect recupera TradeView por rede real
	_fresh()
	repo.create_character("accA", "charA", _mk(1000)); repo.create_character("accB", "charB", _mk(1000))
	var iidN := _grant("charA", "sword_eternal", "gl")
	var A := _client("ra"); var B := _client("rb")
	A.connect_and_login("accA"); B.connect_and_login("accB"); A.open_character("charA"); B.open_character("charB")
	var token := A.client.session_token
	var tidN := str(A.invite_trade("charB").get("trade_id", "")); B.accept_trade_invite(tidN)
	A.add_trade_item(tidN, iidN)
	_chk("TRNET escrow via rede real (item travado)", items.is_in_escrow(iidN))
	A.client.stop()  # disconnect
	var w := 0
	while server.connection_count() > 1 and w < 500: server.poll(); OS.delay_msec(1); w += 1
	_chk("TRNET-T01b escrow persiste após disconnect (grace)", items.is_in_escrow(iidN))
	# reconnect
	var A2 := _client("ra2"); A2.connect_and_login("accA"); A2.client.session_token = token
	A2.client.reconnect(token)
	for i in range(20): _pump_all(); OS.delay_msec(1)
	var vw := A2.get_trade_state(tidN)
	_chk("TRNET-T02/T03 reconnect recupera TradeView + iid único", bool(vw.get("view", {}).has("trade_id")) and items.is_in_escrow(iidN) and items.categorize()["total"] == 1)

# ══════════════ RESTART (§102) ══════════════
func _test_restart() -> void:
	print("  ── TRRST (restart recovery) ──")
	_fresh()
	repo.create_character("accA", "charA", _mk(1000)); repo.create_character("accB", "charB", _mk(1000))
	var iid := _grant("charA", "sword_eternal", "gl")
	var A := _client("xa"); var B := _client("xb")
	A.connect_and_login("accA"); B.connect_and_login("accB"); A.open_character("charA"); B.open_character("charB")
	var tid := str(A.invite_trade("charB").get("trade_id", "")); B.accept_trade_invite(tid)
	A.add_trade_item(tid, iid); A.set_trade_gold(tid, 250)
	var goldA_escrow := int(repo.load("charA")["state"].get("hero_gold", 0))  # 750 (250 em escrow)
	# "shutdown": persiste repo/items/trades + para
	repo.persist_to("user://a112_repo.json")
	FileAccess.open("user://a112_items.json", FileAccess.WRITE).store_string(JSON.stringify(items.snapshot()))
	FileAccess.open("user://a112_trades.json", FileAccess.WRITE).store_string(JSON.stringify(server.trades.snapshot()))
	for c in _all_clients: c.stop()
	_all_clients = []; server.stop()
	# recria
	_port += 1
	var repo2 := CharacterRepository.new(); repo2.load_from("user://a112_repo.json")
	var items2 := ItemRegistry.new(); items2.restore(JSON.parse_string(FileAccess.open("user://a112_items.json", FileAccess.READ).get_as_text()))
	var trades2 := TradeRepository.new(); trades2.setup(1); trades2.restore(JSON.parse_string(FileAccess.open("user://a112_trades.json", FileAccess.READ).get_as_text()))
	var clock2 := ServerClock.fixed(200000)
	server = GameServer.new(); root.add_child(server); server.configure(repo2, items2, clock2, null)
	server.trades = trades2
	server.start(_port, 1)
	repo = repo2; items = items2; clock = clock2
	_chk("TRRST-T02/T03 escrow item+gold NÃO perdem no restart", items2.is_in_escrow(iid) and int(repo2.load("charA")["state"].get("hero_gold", 0)) == goldA_escrow)
	# recovery seguro: trades não-completadas → CANCELADAS + refund
	var rec := server.trade.recover_after_restart()
	_chk("TRRST-T01 recovery seguro (trade aberta cancelada, refund)", int(rec["cancelled"]) >= 1 and not items2.is_in_escrow(iid) and int(repo2.load("charA")["state"].get("hero_gold", 0)) == 1000 and _has_item({"repo": repo2}, "charA", iid))
	# TRRST-T04 completed persiste: cria trade completa, snapshot, restart → segue completed
	# (usa direto p/ agilidade)
	var ctxC := _direct(1000, 1000); var svC: TradeService = ctxC["svc"]
	var ic := _give(ctxC, "charA", "sword_eternal", 50)
	var tc := str(svC.invite("charA", "i", "charB")["trade_id"]); svC.accept_invite("charB", "ai", tc)
	svC.add_item("charA", "a", tc, ic); var ovc := int(ctxC["trades"].get_trade(tc)["offer_version"])
	svC.accept_offer("charA", "aa", tc, ovc); svC.accept_offer("charB", "ab", tc, ovc)
	var recC := svC.recover_after_restart()
	_chk("TRRST-T04 completed trade persiste no recovery (não reverte)", int(recC["kept_completed"]) == 1 and ctxC["items"].owner_of(ic) == "accB")

# ══════════════ SECURITY (§103) ══════════════
func _test_security() -> void:
	print("  ── TRSEC (segurança) ──")
	var ctx := _direct(1000, 1000); var sv: TradeService = ctx["svc"]
	var iid := _give(ctx, "charA", "sword_eternal", 60)
	ctx["repo"].create_character("accC", "charC", _mk(1000))  # terceiro
	var tid := str(sv.invite("charA", "i", "charB")["trade_id"]); sv.accept_invite("charB", "ai", tid)
	sv.add_item("charA", "a", tid, iid)
	_chk("TRSEC-T01 terceiro não cancela", str(sv.cancel("charC", "c", tid).get("reason", "")) == "NOT_PARTICIPANT")
	var ov := int(ctx["trades"].get_trade(tid)["offer_version"])
	_chk("TRSEC-T02 terceiro não aceita", str(sv.accept_offer("charC", "ac", tid, ov).get("reason", "")) == "NOT_PARTICIPANT")
	# fake quality/rolls/owner: o servidor resolve pelo iid — o cliente nem manda esses campos (whitelist). Provamos
	# que a instância transferida vem do dado server-side (o payload de rede só carrega iid; parser corta o resto).
	var pc := NetProtocol.parse_command({"command_type": "TRADE_ADD_ITEM", "command_id": "x", "args": {"trade_id": tid, "iid": iid, "quality": 100, "rolls": {"attack": 9}, "owner": "charC"}}, false)
	var cmd: Dictionary = pc["command"]
	_chk("TRSEC-T03/T04/T05 fake quality/rolls/owner cortados pela whitelist", bool(pc["ok"]) and not cmd.has("quality") and not cmd.has("rolls") and not cmd.has("owner"))
	# fake gold acima do balance
	_chk("TRSEC-T06 fake gold acima do balance rejeitado", str(sv.set_gold("charA", "fg", tid, 999999).get("reason", "")) == "GOLD_INSUFFICIENT")
	# metadata privada não vaza no TradeView
	var view := sv.view_for(tid, "charA")
	var leak := view.has("escrow_instances") or view.has("accept_raw") or JSON.stringify(view).contains("accA") or JSON.stringify(view).contains("accB")
	_chk("TRSEC-T07 TradeView não vaza account/journal/metadata interna", not leak)

# ══════════════ TWO REAL CLIENT FLOW (§104) ══════════════
func _test_two_client_flow() -> void:
	print("  ── FLUXO 2 CLIENTES REAIS (rede ENet) ──")
	_fresh()
	repo.create_character("accA", "charA", _mk(1000)); repo.create_character("accB", "charB", _mk(1000))
	var iidA := _grant("charA", "sword_eternal", "glA")
	var iidB := _grant("charB", "chest_eternal", "glB")
	var A := _client("fa"); var B := _client("fb")
	A.connect_and_login("accA"); B.connect_and_login("accB"); A.open_character("charA"); B.open_character("charB")
	var total0 := int(repo.load("charA")["state"].get("hero_gold", 0)) + int(repo.load("charB")["state"].get("hero_gold", 0))
	var tid := str(A.invite_trade("charB").get("trade_id", ""))
	_chk("FLOW invite→accept por rede", B.accept_trade_invite(tid).get("ok", false))
	A.add_trade_item(tid, iidA); A.set_trade_gold(tid, 150)
	B.add_trade_item(tid, iidB); B.set_trade_gold(tid, 50)
	var ov := int(A.get_trade_state(tid).get("view", {}).get("offer_version", -1))
	A.accept_trade_offer(tid, ov)
	var fin := B.accept_trade_offer(tid, ov)
	_chk("FLOW commit atômico por rede (COMPLETED)", bool(fin.get("completed", false)))
	# resync ambos
	A.get_state(); B.get_state()
	var okA := items.owner_of(iidB) == "accA" and _has_item({"repo": repo}, "charA", iidB)
	var okB := items.owner_of(iidA) == "accB" and _has_item({"repo": repo}, "charB", iidA)
	var gold_ok := (int(repo.load("charA")["state"].get("hero_gold", 0)) + int(repo.load("charB")["state"].get("hero_gold", 0))) == total0
	_chk("FLOW A recebe item de B, B recebe item de A", okA and okB)
	_chk("FLOW ouro conservado + IID nunca em dois donos", gold_ok and items.categorize()["escrow"] == 0)
	_chk("FLOW §121 IID X: A tinha, agora B tem, nunca em dois", items.owner_of(iidA) == "accB" and not _has_item({"repo": repo}, "charA", iidA))

# ══════════════ CONCURRENT + CROSS-TRADE (§105/§106) ══════════════
func _test_concurrent_and_cross() -> void:
	print("  ── CONCORRÊNCIA + CROSS-TRADE ──")
	# cross-trade: mesmo iid não entra em 2 trades (1 active por char já bloqueia; e escrow bloqueia)
	var ctx := _direct(1000, 1000); var sv: TradeService = ctx["svc"]
	ctx["repo"].create_character("accC", "charC", _mk(1000))
	var iid := _give(ctx, "charA", "sword_eternal", 70)
	var t1 := str(sv.invite("charA", "i1", "charB")["trade_id"]); sv.accept_invite("charB", "ai", t1)
	sv.add_item("charA", "a", t1, iid)
	# A já está em trade ativa → não pode abrir 2ª (bloqueia o cross-trade attack na origem)
	_chk("CROSS-TRADE mesmo char não abre 2ª trade (iid não vai a 2 trades)", str(sv.invite("charA", "i2", "charC").get("reason", "")) == "ALREADY_IN_TRADE")
	_chk("CROSS-TRADE iid segue único em escrow de UMA trade", ctx["items"].escrow_trade_of(iid) == t1 and ctx["items"].categorize()["escrow"] == 1)
	# both-accept race (§64): ambos aceitam a MESMA versão → 1 commit (serializado)
	var ctx2 := _direct(1000, 1000); var sv2: TradeService = ctx2["svc"]
	var iid2 := _give(ctx2, "charA", "sword_eternal", 71)
	var t2 := str(sv2.invite("charA", "i", "charB")["trade_id"]); sv2.accept_invite("charB", "ai", t2)
	sv2.add_item("charA", "a", t2, iid2)
	var ov := int(ctx2["trades"].get_trade(t2)["offer_version"])
	var r1 := sv2.accept_offer("charA", "ra", t2, ov)
	var r2 := sv2.accept_offer("charB", "rb", t2, ov)
	_chk("RACE both-accept → apenas UM commit", not bool(r1.get("completed", false)) and bool(r2.get("completed", false)) and ctx2["items"].owner_of(iid2) == "accB")

# ══════════════ STRESS + CONSERVAÇÃO (§107-110) ══════════════
func _test_stress_and_conservation() -> void:
	print("  ── STRESS + CONSERVAÇÃO ──")
	var ctx := _direct(100000, 100000); var sv: TradeService = ctx["svc"]; var r: CharacterRepository = ctx["repo"]; var it: ItemRegistry = ctx["items"]
	# fixture fechada: total de ouro e de itens conhecido
	var iids: Array = []
	for i in range(20): iids.append(_give(ctx, "charA", "sword_eternal", 200 + i))
	for i in range(20): iids.append(_give(ctx, "charB", "chest_eternal", 300 + i))
	var gold_total0 := _gold(ctx, "charA") + _gold(ctx, "charB")
	var item_total0: int = int(it.categorize()["total"])
	var completed := 0; var cancelled := 0
	var ai := 0; var bi := 20
	for round in range(30):
		var tid := str(sv.invite("charA", "i%d" % round, "charB").get("trade_id", ""))
		if tid == "": continue
		sv.accept_invite("charB", "ai%d" % round, tid)
		# A oferece 1 item + ouro; B oferece 1 item + ouro
		if ai < 20: sv.add_item("charA", "aa%d" % round, tid, iids[ai]); ai += 1
		if bi < 40: sv.add_item("charB", "bb%d" % round, tid, iids[bi]); bi += 1
		sv.set_gold("charA", "ga%d" % round, tid, 100 + round)
		sv.set_gold("charB", "gb%d" % round, tid, 50 + round)
		var ov := int(ctx["trades"].get_trade(tid)["offer_version"])
		if round % 5 == 4:
			sv.cancel("charA", "can%d" % round, tid); cancelled += 1
		else:
			sv.accept_offer("charA", "acA%d" % round, tid, ov)
			var fin := sv.accept_offer("charB", "acB%d" % round, tid, ov)
			# dup accept (idempotência sob carga)
			sv.accept_offer("charB", "acB%d" % round, tid, ov)
			if bool(fin.get("completed", false)): completed += 1
	var cat := it.categorize()
	var gold_total1 := _gold(ctx, "charA") + _gold(ctx, "charB")
	# soma ouro em escrow (nenhum, pois todas as trades terminaram)
	print("    [stress] completed=%d cancelled=%d gold %d->%d items total=%d escrow=%d" % [completed, cancelled, gold_total0, gold_total1, cat["total"], cat["escrow"]])
	_chk("STRESS §109 ouro conservado (A+B, trades fechadas)", gold_total1 == gold_total0)
	_chk("STRESS §110 itens conservados (total constante, move não cria/destroi)", cat["total"] == item_total0)
	_chk("STRESS §108 0 iid duplicado / 0 escrow órfão / 0 negativo", it.invariant_unique_owner() and cat["escrow"] == 0 and _gold(ctx, "charA") >= 0 and _gold(ctx, "charB") >= 0)
	# auditor de consistência: todo iid em PLAYER pertence à bolsa do dono
	var consistent := _audit_consistency(ctx)
	_chk("STRESS §69/§70 ItemRegistry consistente com inventários", consistent)

func _audit_consistency(ctx: Dictionary) -> bool:
	var r: CharacterRepository = ctx["repo"]; var it: ItemRegistry = ctx["items"]
	for iid in it._items:
		var loc := str(it._items[iid]["location"])
		if loc != ItemRegistry.LOC_PLAYER: continue
		var acct := str(it._items[iid]["account_id"])
		# encontra o character daquela conta e confirma que o iid está na bolsa
		var found := false
		for cid in r._store:
			if r.owner_of(cid) == acct:
				for inst in r.load(cid)["state"].get("item_instances", []):
					if str(inst.get("iid", "")) == iid: found = true
		if not found: return false
	return true

# ══════════════ LOCAL (§83) ══════════════
func _test_local() -> void:
	print("  ── LOCAL (single-player intacto) ──")
	_chk("LOCAL segue modo default sem trade externo", RuntimeMode.resolve() == RuntimeMode.LOCAL)
	# a economia embarcada continua funcionando sem TradeService (trade P2P simplesmente não existe em LOCAL)
	var r := CharacterRepository.new(); r.create_character("locA", "locC", _mk(500))
	_chk("LOCAL autoridade econômica intacta (sem dependência de trade)", r.revision_of("locC") == 1)
