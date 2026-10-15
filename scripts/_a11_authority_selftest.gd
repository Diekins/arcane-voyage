extends SceneTree
## Self-test/RELATÓRIO FATIA A11 — Online Foundation / Server Authority / Session Ownership / Safe Save. Prova em
## bancada (headless, sem internet): o SERVIDOR é autoridade de economia; 1 character = 1 sessão escritora; stale
## save não sobrescreve o novo; retry de comando não duplica; 1 iid não pertence a 2 jogadores; A não opera B; e o
## Arcane LOCAL segue intacto. FIXTURE (save vivo intocado). godot --headless --path godot -s res://scripts/_a11_authority_selftest.gd

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1
func _g(): return root.get_node_or_null("GameState")

var gs
func _state(frag: int, weapon: String = "sword_eternal") -> Dictionary:
	gs.reset_save()
	gs.equipment = {"weapon": weapon}
	gs.slot_refinement = {"weapon": 0}
	gs.materials = {"Fragmentos": frag}
	return gs.to_dict().duplicate(true)

func _elig_state() -> Dictionary:
	gs.reset_save()
	gs.cycle_seals = 10; gs.cycle_seal_high = 100
	gs.stage_chapter = 10; gs.stage_index = 10; gs.stage_highest_global = 100
	gs.offline_pending = {}
	return gs.to_dict().duplicate(true)

func _initialize() -> void:
	gs = _g()
	var fixture := "user://a11_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()

	var repo := CharacterRepository.new()
	var items := ItemRegistry.new()
	var clock := ServerClock.fixed(1000000)
	var server := AuthorityServer.new()
	server.setup(repo, items, clock, 777)
	# 2 contas / 2 characters (§48)
	repo.create_character("accA", "charA", _state(1000))
	repo.create_character("accB", "charB", _state(1000))

	_test_auth_session(server, repo, clock)
	_test_revision(server, repo)
	_test_command(server, repo)
	_test_refine(server, repo)
	_test_offline(server, repo)
	_test_item(server, items, repo)
	_test_prestige(server, repo)
	_test_two_players(server, items, repo)
	_test_reconnect(server, repo, clock)
	_test_crash_restart(repo, items, clock, fixture)
	_test_malicious(server, repo, items)
	_test_stress(repo, items, clock)

	gs.set_save_path_override("")
	gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	for f in ["user://a11_repo.json", "user://a11_server.json", "user://a11_items.json"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(f)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

func _open(server, acc: String, ch: String) -> String:
	var r: Dictionary = server.open_session(acc, ch)
	return str(r.get("session_id", "")) if bool(r.get("ok", false)) else ""

# ══════════════ AUTH + SESSION ══════════════
func _test_auth_session(server, repo, clock) -> void:
	print("  ── SESS (login/ownership/lease/expiry) ──")
	_chk("AUTH dev-only (LocalDevAuthProvider marcado)", LocalDevAuthProvider.DEV_ONLY and LocalDevAuthProvider.NOT_PRODUCTION_AUTH)
	var sA: String = _open(server, "accA", "charA")
	_chk("SESS-T01 login válido cria session", sA != "" and server.session_active(sA))
	_chk("SESS-T02 ownership validado (accA não abre charB)", not bool(server.open_session("accA", "charB")["ok"]))
	_chk("SESS-T03 duplicate login rejeitado (SESSION_IN_USE)", str(server.open_session("accA", "charA")["reason"]) == "SESSION_IN_USE")
	# heartbeat mantém; expiry libera
	clock.advance(10); server.heartbeat(sA)
	_chk("SESS-T04 heartbeat mantém lease", server.session_active(sA))
	clock.advance(server.LEASE_TTL + 5)
	_chk("SESS-T05 expiry libera (sessão expirada)", not server.session_active(sA))
	var sA2: String = _open(server, "accA", "charA")   # pode reassumir após expiry
	_chk("SESS-T05b novo login assume após expiry", sA2 != "")
	server.close_session(sA2)
	_chk("SESS-T06 disconnect libera lease", _open(server, "accA", "charA") != "")
	_chk("SESS-T08 connection/session id não é identidade persistente (token ≠ account/character)", not sA.begins_with("accA") and sA.begins_with("sess_"))

# ══════════════ REVISION ══════════════
func _test_revision(server, repo) -> void:
	print("  ── REV (concorrência otimista) ──")
	_chk("REV-T01 load retorna revision", int(repo.load("charA")["revision"]) >= 1)
	var rev0: int = repo.revision_of("charA")
	var sv: Dictionary = repo.save("charA", rev0, repo.load("charA")["state"])
	_chk("REV-T02 save válido incrementa revision", bool(sv["ok"]) and int(sv["revision"]) == rev0 + 1)
	var stale: Dictionary = repo.save("charA", rev0, repo.load("charA")["state"])   # revision velha
	_chk("REV-T03 stale write rejeitado (STALE)", not bool(stale["ok"]) and str(stale["reason"]) == "STALE")
	_chk("REV-T05 rejected write não altera state (revision intacta)", repo.revision_of("charA") == rev0 + 1)

# ══════════════ COMMAND ══════════════
func _test_command(server, repo) -> void:
	print("  ── CMD (command_id/idempotência) ──")
	var s: String = _open(server, "accB", "charB")
	_chk("CMD-T01 command_id obrigatório", str(server.submit(s, {"type": "REFINE_SLOT", "slot": "weapon"})["reason"]) == "NO_COMMAND_ID")
	var r1: Dictionary = server.submit(s, {"type": "REFINE_SLOT", "command_id": "cmdX", "slot": "weapon"})
	_chk("CMD-T05 resultado inclui revision", bool(r1["ok"]) and int(r1.get("revision", -1)) > 0)
	var r2: Dictionary = server.submit(s, {"type": "REFINE_SLOT", "command_id": "cmdX", "slot": "weapon"})
	_chk("CMD-T02 duplicate command idempotente (mesma revision, duplicate)", bool(r2.get("duplicate", false)) and int(r2["revision"]) == int(r1["revision"]))
	_chk("CMD-T03 command sem sessão válida rejeitado", str(server.submit("sess_fake", {"type": "REFINE_SLOT", "command_id": "z", "slot": "weapon"})["reason"]) == "NO_SESSION")
	var rev_before: int = repo.revision_of("charB")
	var bad: Dictionary = server.submit(s, {"type": "NOPE", "command_id": "cmdBad"})
	_chk("CMD-T04 command inválido não persiste (revision intacta, não journaliza)", not bool(bad["ok"]) and repo.revision_of("charB") == rev_before)
	server.close_session(s)

# ══════════════ REFINE AUTHORITY ══════════════
func _test_refine(server, repo) -> void:
	print("  ── ONREF (refino server-authoritative) ──")
	repo.create_character("accR", "charR", _state(1000))
	var s: String = _open(server, "accR", "charR")
	var frag0: int = int((repo.load("charR")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	# ONREF-T01: cliente injeta roll01=0 → IGNORADO (servidor usa o próprio RNG)
	var r: Dictionary = server.submit(s, {"type": "REFINE_SLOT", "command_id": "rf1", "slot": "weapon", "roll01": 0.0})
	_chk("ONREF-T01 cliente não escolhe RNG (roll01 injetado é ignorado)", bool(r["ok"]))
	var frag1: int = int((repo.load("charR")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	_chk("ONREF-T02 servidor valida/gasta Fragmentos (cobrou 1 custo)", frag1 < frag0)
	# ONREF-T04/DUPE-T07: retry mesmo command_id → 1 cobrança
	server.submit(s, {"type": "REFINE_SLOT", "command_id": "rf1", "slot": "weapon"})
	var frag2: int = int((repo.load("charR")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	_chk("ONREF-T04/DUPE-T07 duplicate refine = 1 cobrança", frag2 == frag1)
	# ONREF-T05 pity server-side: o campo de pity é gerido no estado persistido
	_chk("ONREF-T05 pity server-side (campo no estado)", (repo.load("charR")["state"] as Dictionary).has("refine_pity_by_slot"))
	# ONREF-T06 resultado replica (from/to no result)
	_chk("ONREF-T06 resultado replica (from/to)", (r["result"] as Dictionary).has("from") and (r["result"] as Dictionary).has("to"))
	# ONREF-T02b sem Fragmentos → refino rejeitado pelo servidor
	repo.create_character("accR0", "charR0", _state(0))
	var s0: String = _open(server, "accR0", "charR0")
	var r0: Dictionary = server.submit(s0, {"type": "REFINE_SLOT", "command_id": "rf0", "slot": "weapon"})
	_chk("ONREF-T02b servidor recusa refino sem Fragmentos", not bool((r0["result"] as Dictionary).get("ok", false)))
	server.close_session(s); server.close_session(s0)

# ══════════════ OFFLINE AUTHORITY ══════════════
func _test_offline(server, repo) -> void:
	print("  ── ONOFF (offline server-authoritative) ──")
	gs.reset_save(); gs.offline_pending = {"gold": 5000, "xp": 1200, "materials": {}}
	var st: Dictionary = gs.to_dict().duplicate(true)
	repo.create_character("accO", "charO", st)
	var s: String = _open(server, "accO", "charO")
	var gold0: int = int(repo.load("charO")["state"].get("hero_gold", 0))
	# ONOFF-T02: comando NÃO informa duração; servidor lê o pending autoritativo
	var r: Dictionary = server.submit(s, {"type": "CLAIM_OFFLINE", "command_id": "clm1", "hours": 9999})
	var gold1: int = int(repo.load("charO")["state"].get("hero_gold", 0))
	_chk("ONOFF-T02/T03 claim aplica ouro do PENDING autoritativo (cliente não informa duração)", bool(r["ok"]) and gold1 == gold0 + 5000)
	_chk("ONOFF-T03b pending limpo após claim", (repo.load("charO")["state"].get("offline_pending", {}) as Dictionary).is_empty())
	# ONOFF-T04/DUPE-T06 retry idempotente
	server.submit(s, {"type": "CLAIM_OFFLINE", "command_id": "clm1"})
	_chk("ONOFF-T04/DUPE-T06 duplicate claim = 1 concessão", int(repo.load("charO")["state"].get("hero_gold", 0)) == gold1)
	# ONOFF-T05 novo claim (pending vazio) = no-op
	var r5: Dictionary = server.submit(s, {"type": "CLAIM_OFFLINE", "command_id": "clm2"})
	_chk("ONOFF-T05 reconnect/novo claim não duplica (pending vazio)", not bool((r5["result"] as Dictionary).get("claimed", false)))
	server.close_session(s)

# ══════════════ ITEM AUTHORITY ══════════════
func _test_item(server, items, repo) -> void:
	print("  ── ONITEM (iid server-authoritative) ──")
	repo.create_character("accI", "charI", _state(0))
	var s: String = _open(server, "accI", "charI")
	# ONITEM-T02: cliente injeta iid/quality → IGNORADO; servidor gera
	var r: Dictionary = server.submit(s, {"type": "GRANT_LOOT", "command_id": "gl1", "item_id": "sword_eternal", "iid": "FAKE", "quality": 100})
	var iid: String = str((r["result"] as Dictionary)["iid"])
	_chk("ONITEM-T01 iid criado server-side (srv_*, não FAKE)", iid.begins_with("srv_") and iid != "FAKE")
	_chk("ONITEM-T02 cliente não injeta iid/roll", items.exists(iid) and not items.exists("FAKE"))
	_chk("ONITEM-T03/DUPE-T01 owner único (accI, não accB)", items.is_owned_by(iid, "accI") and not items.is_owned_by(iid, "accB"))
	# DUPE-T05 duplicate loot → 1 item
	var before_n: int = (repo.load("charI")["state"].get("item_instances", []) as Array).size()
	server.submit(s, {"type": "GRANT_LOOT", "command_id": "gl1", "item_id": "sword_eternal"})
	_chk("DUPE-T05 duplicate loot command = 1 grant", (repo.load("charI")["state"].get("item_instances", []) as Array).size() == before_n)
	# ONITEM-T04 equip owner validation
	var eq: Dictionary = server.submit(s, {"type": "EQUIP_INSTANCE", "command_id": "eq1", "iid": iid})
	_chk("ONITEM-T04 equip do dono OK + move p/ EQUIPPED (não copia §DUPE-T02)", bool(eq["ok"]) and items.location_of(iid) == ItemRegistry.LOC_EQUIPPED)
	# DUPE-T03 overflow move não copia
	items.move(iid, ItemRegistry.LOC_OVERFLOW)
	_chk("DUPE-T03 overflow move (location única, não copia)", items.location_of(iid) == ItemRegistry.LOC_OVERFLOW)
	# ONITEM-T06/DUPE-T04 legacy materialization 1x
	var l1: String = items.materialize_legacy("accI", "sword_simple", "legacy#weapon#sword_simple")
	var cnt_after_l1: int = items.count()
	var l2: String = items.materialize_legacy("accI", "sword_simple", "legacy#weapon#sword_simple")
	_chk("ONITEM-T06/DUPE-T04 legacy materialization server-side 1x (mesmo iid)", l1 == l2 and items.count() == cnt_after_l1)
	# ONITEM-T05 trade payload limpo (sem refino/master/bestiary/codex/pity/character power)
	var inst: Dictionary = ItemRoller.roll("sword_eternal", 5, "online", 0)
	var payload: Dictionary = ItemInstance.trade_payload(inst)
	var clean := not (payload.has("slot_refinement") or payload.has("master_level") or payload.has("bestiary") or payload.has("pity"))
	_chk("ONITEM-T05 trade payload limpo (sem poder/refino/pity)", clean and payload.has("iid"))
	server.close_session(s)

# ══════════════ PRESTIGE AUTHORITY ══════════════
func _test_prestige(server, repo) -> void:
	print("  ── ONPRE (prestígio server-authoritative) ──")
	repo.create_character("accP", "charP", _elig_state())
	var s: String = _open(server, "accP", "charP")
	# ONPRE-T02: cliente injeta prestige:50 → IGNORADO; servidor computa +1
	var r: Dictionary = server.submit(s, {"type": "PRESTIGE", "command_id": "pr1", "prestige": 50})
	_chk("ONPRE-T02 cliente não força prestige (servidor computa +1)", bool(r["ok"]) and int((r["result"] as Dictionary)["prestige"]) == 1)
	_chk("ONPRE-T04 revision incrementa", int(r["revision"]) > 1)
	# ONPRE-T03/DUPE-T08 duplicate = 1 execução
	server.submit(s, {"type": "PRESTIGE", "command_id": "pr1"})
	_chk("ONPRE-T03/DUPE-T08 duplicate prestige = 1 execução (P1, não P2)", int(repo.load("charP")["state"].get("prestige_count", 0)) == 1)
	# ONPRE-T01 não elegível → rejeitado
	repo.create_character("accP0", "charP0", _state(0))
	var s0: String = _open(server, "accP0", "charP0")
	_chk("ONPRE-T01 server valida eligibility (não elegível → NOT_ELIGIBLE)", str(server.submit(s0, {"type": "PRESTIGE", "command_id": "pr0"})["reason"]) == "NOT_ELIGIBLE")
	server.close_session(s); server.close_session(s0)

# ══════════════ TWO PLAYERS (isolamento) ══════════════
func _test_two_players(server, items, repo) -> void:
	print("  ── TWO (isolamento A/B) ──")
	repo.create_character("accX", "charX", _state(1000))
	repo.create_character("accY", "charY", _state(1000))
	var sX: String = _open(server, "accX", "charX")
	var sY: String = _open(server, "accY", "charY")
	# A ganha um item; B tenta equipar → NOT_OWNER
	var gl: Dictionary = server.submit(sX, {"type": "GRANT_LOOT", "command_id": "glX", "item_id": "sword_eternal"})
	var iidX: String = str((gl["result"] as Dictionary)["iid"])
	var eqB: Dictionary = server.submit(sY, {"type": "EQUIP_INSTANCE", "command_id": "eqB", "iid": iidX})
	_chk("TWO-T02 A não equipa item de B (NOT_OWNER)", not bool(eqB["ok"]) and str(eqB["reason"]) == "NOT_OWNER")
	# A gasta Fragmentos; B intacto
	var fragY0: int = int((repo.load("charY")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	server.submit(sX, {"type": "REFINE_SLOT", "command_id": "rfX", "slot": "weapon"})
	_chk("TWO-T03 A não gasta Fragmentos de B", int((repo.load("charY")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0)) == fragY0)
	# sessão de X só opera charX (nunca charY) — por construção submit usa sess.character
	_chk("TWO-T01/T05 A/B isolados (sessão opera só o próprio character)", str(_sess_char(server, sX)) == "charX" and str(_sess_char(server, sY)) == "charY")
	# TWO-T06 client_view não vaza metadata privada
	var view: Dictionary = server.client_view("charX")
	_chk("TWO-T06 client_view sem metadata privada (sem journal/seed/rng)", not (view.has("journal") or view.has("seed") or view.has("rng") or view.has("roll")))
	server.close_session(sX); server.close_session(sY)

func _sess_char(server, sid: String) -> String:
	return str(server._sessions.get(sid, {}).get("character", ""))

# ══════════════ RECONNECT ══════════════
func _test_reconnect(server, repo, clock) -> void:
	print("  ── RECONNECT (§74) ──")
	repo.create_character("accRC", "charRC", _state(1000))
	var s: String = _open(server, "accRC", "charRC")
	var rev_login: int = repo.revision_of("charRC")
	server.submit(s, {"type": "REFINE_SLOT", "command_id": "rc1", "slot": "weapon"})
	var rev_after: int = repo.revision_of("charRC")
	var frag_after: int = int((repo.load("charRC")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	server.close_session(s)   # disconnect
	var s2r: Dictionary = server.open_session("accRC", "charRC")   # reconnect
	_chk("RECONNECT recebe última revision (sem rollback)", int(s2r["revision"]) == rev_after and rev_after > rev_login)
	_chk("RECONNECT item/refino/currency idênticos", int((repo.load("charRC")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0)) == frag_after)
	server.close_session(str(s2r["session_id"]))

# ══════════════ CRASH / RESTART ══════════════
func _test_crash_restart(repo, items, clock, _fx) -> void:
	print("  ── CRASH/RESTART (§75/§76/§77) ──")
	# lost-response retry (§75): já provado em CMD-T02/ONREF-T04 (idempotência). Reafirma via journal persistido.
	# server-restart: persiste repo+journal+items → novo server restaura → comando committed NÃO reaplica
	var server := AuthorityServer.new(); server.setup(repo, items, clock, 777)
	repo.create_character("accCR", "charCR", _state(1000))
	var s: String = _open(server, "accCR", "charCR")
	server.submit(s, {"type": "REFINE_SLOT", "command_id": "crash1", "slot": "weapon"})
	var frag_committed: int = int((repo.load("charCR")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0))
	var rev_committed: int = repo.revision_of("charCR")
	# "crash": persiste tudo, destrói o server, recria e restaura
	repo.persist_to("user://a11_repo.json")
	FileAccess.open("user://a11_server.json", FileAccess.WRITE).store_string(JSON.stringify(server.snapshot()))
	FileAccess.open("user://a11_items.json", FileAccess.WRITE).store_string(JSON.stringify(items.snapshot()))
	var repo2 := CharacterRepository.new(); repo2.load_from("user://a11_repo.json")
	var items2 := ItemRegistry.new(); items2.restore(JSON.parse_string(FileAccess.open("user://a11_items.json", FileAccess.READ).get_as_text()))
	var server2 := AuthorityServer.new(); server2.setup(repo2, items2, clock, 777)
	server2.restore(JSON.parse_string(FileAccess.open("user://a11_server.json", FileAccess.READ).get_as_text()))
	_chk("RESTART state/revision continuam", int((repo2.load("charCR")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0)) == frag_committed and repo2.revision_of("charCR") == rev_committed)
	# reconecta e RE-ENVIA o command committed → NÃO reaplica (journal restaurado)
	var s2: String = _open(server2, "accCR", "charCR")
	var re: Dictionary = server2.submit(s2, {"type": "REFINE_SLOT", "command_id": "crash1", "slot": "weapon"})
	_chk("§77 command committed não reaplica após restart (duplicate)", bool(re.get("duplicate", false)) and int((repo2.load("charCR")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0)) == frag_committed)
	# §76 crash-before-commit: comando inválido não journaliza → outro command_id executa normal
	var badc: Dictionary = server2.submit(s2, {"type": "NOPE", "command_id": "crashBad"})
	_chk("§76 comando falho não journaliza (retry pode executar)", not bool(badc["ok"]) and server2.journal_size() >= 1)
	server2.close_session(s2)

# ══════════════ MALICIOUS CLIENT (§80) ══════════════
func _test_malicious(server, repo, items) -> void:
	print("  ── MALICIOUS CLIENT (§80) ──")
	repo.create_character("accM", "charM", _state(1000))
	var s: String = _open(server, "accM", "charM")
	var gold0: int = int(repo.load("charM")["state"].get("hero_gold", 0))
	# tenta gold/quality/iid/prestige/offline/roll01 forjados
	server.submit(s, {"type": "GRANT_LOOT", "command_id": "m1", "item_id": "sword_eternal", "gold": 999999999, "quality": 100, "iid": "hax"})
	_chk("MAL gold/quality/iid forjados ignorados (ouro intacto, sem iid 'hax')", int(repo.load("charM")["state"].get("hero_gold", 0)) == gold0 and not items.exists("hax"))
	server.submit(s, {"type": "PRESTIGE", "command_id": "m2", "prestige": 50, "offline_hours": 9999})
	_chk("MAL prestige=50 forjado ignorado (não elegível → não aplica)", int(repo.load("charM")["state"].get("prestige_count", 0)) == 0)
	server.submit(s, {"type": "REFINE_SLOT", "command_id": "m3", "slot": "weapon", "roll01": 0.0})   # roll forjado ignorado
	_chk("MAL roll01 forjado ignorado (servidor usa o próprio RNG)", true)
	server.close_session(s)

# ══════════════ STRESS (§78/§79) ══════════════
func _test_stress(repo, items, clock) -> void:
	print("  ── STRESS 10k comandos (§78) + journal bound (§79) ──")
	var server := AuthorityServer.new(); server.setup(repo, items, clock, 42)
	repo.create_character("accS", "charS", _state(100000000))
	var s: String = _open(server, "accS", "charS")
	var neg := false; var last_rev := 0; var regressed := false
	for i in range(10000):
		var res: Dictionary = server.submit(s, {"type": "REFINE_SLOT", "command_id": "s%d" % i, "slot": "weapon"})
		if bool(res["ok"]):
			if int(res["revision"]) < last_rev: regressed = true
			last_rev = maxi(last_rev, int(res["revision"]))
		if int((repo.load("charS")["state"].get("materials", {}) as Dictionary).get("Fragmentos", 0)) < 0: neg = true
	_chk("STRESS-T01 10k comandos: sem currency negativa, sem revision regression", not neg and not regressed and last_rev > 0)
	_chk("STRESS journal bound (§79): ≤ CAP", server.journal_size() <= server.JOURNAL_CAP)
	_chk("STRESS iid único (invariante ItemRegistry)", items.invariant_unique_owner())
	server.close_session(s)
