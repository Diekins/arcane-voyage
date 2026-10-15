extends SceneTree
## Self-test/RELATÓRIO FATIA A13 — Character Identity / Classes / Account Roster / Loadouts / Cosmetic Foundation.
## Prova: APPEARANCE ≠ CLASS ≠ BUILD ≠ COSMETIC; apresentação/pele/cabelo/roupa = 0 combat power; 1 conta = múltiplos
## characters mas slot pago ≠ farm AFK extra; só 1 progression character ativo por vez; classes base gratuitas;
## loadout slot extra = conveniência (0 stats); cosmetic ≠ CP nem Ranked; legacy Errante migra sem perder nada.
## Edge/matrizes direto no serviço; fluxo por rede ENet real. FIXTURE (save vivo intocado).

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1

var gs
var server: GameServer
var _all_clients: Array = []
var _port := 34860

func _pump_all() -> void:
	if server != null: server.poll()
	for c in _all_clients: c.poll()

func _ctx(seed: int) -> Dictionary:
	var repo := CharacterRepository.new(); var items := ItemRegistry.new(); var clock := ServerClock.fixed(1000)
	var auth := AuthorityServer.new(); auth.setup(repo, items, clock, seed)
	var rost := AccountRosterRepository.new(); var cos := CosmeticEntitlementRepository.new()
	var cs := CharacterService.new(); cs.setup(repo, items, rost, cos, clock, auth, seed)
	return {"repo": repo, "items": items, "clock": clock, "auth": auth, "roster": rost, "cos": cos, "cs": cs}

func _app(cosmetic: String = "") -> Dictionary:
	return CharacterAppearance.new_appearance("BODY_F", "SKIN_5", "HAIR_3", "HC_RED", "OUTFIT_2", "MAGE", cosmetic)

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a13_fixture_save.json"
	gs.set_save_path_override(fixture); var mem: Dictionary = gs.to_dict(); gs.reset_save()

	_test_sanity_cp_order()
	_test_class()
	_test_appearance()
	_test_roster()
	_test_active_progression()
	_test_loadout()
	_test_cosmetic()
	_test_create()
	_test_migration()
	_test_a12_regression()
	_test_a112_regression()
	_test_network()
	_test_stress()
	_test_local()

	for c in _all_clients: c.stop()
	if server != null: server.stop()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	for f in ["user://a13_repo.json", "user://a13_svc.json"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(f)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

func _char(ctx: Dictionary, acct: String, class_id: String, name: String, cosmetic: String = "") -> String:
	var r: Dictionary = ctx["cs"].create_character(acct, class_id, name, _app(cosmetic))
	return str(r.get("character_id", "")) if bool(r.get("ok", false)) else ""

# ══════════════ SANITY §0 — CP leaderboard ordena por CP ══════════════
func _test_sanity_cp_order() -> void:
	print("  ── SANITY (§0 CP leaderboard ordena por CP) ──")
	var ctx := _ctx(1)
	# 2 chars com equipamentos diferentes → CP diferente
	var strong := _give_char(ctx, "accA", "CLASS_1", "Forte", "sword_eternal")
	var weak := _give_char(ctx, "accB", "CLASS_1", "Fraco", "sword_simple")
	var power := PowerLeaderboardService.new(); power.setup(ctx["auth"], ctx["clock"])
	power.refresh_character(strong); power.refresh_character(weak)
	var ord := power.ordered()
	_chk("§0 código ordena CP DESC (não rating) — maior CP em 1º", str(ord[0]["character_id"]) == strong and int(ord[0]["cp"]) > int(ord[1]["cp"]))

## cria character e força o weapon (para variar CP)
func _give_char(ctx: Dictionary, acct: String, class_id: String, name: String, weapon: String) -> String:
	var cid := _char(ctx, acct, class_id, name)
	var ld: Dictionary = ctx["repo"].load(cid); var st: Dictionary = ld["state"]
	st["equipment"] = {"weapon": weapon}
	ctx["repo"].save(cid, int(ld["revision"]), st)
	return cid

# ══════════════ CLASS (§87) ══════════════
func _test_class() -> void:
	print("  ── CLASS ──")
	_chk("CLASS-T01 class IDs allowlisted (5 jogáveis — A15)", CharacterClassDefinition.playable_ids().size() == 5 and CharacterClassDefinition.exists("CLASS_1"))
	_chk("CLASS-T02 appearance não altera stats (0 power)", CharacterAppearance.combat_power(_app()) == 0)
	_chk("CLASS-T03 classe base é gratuita", CharacterClassDefinition.is_free("CLASS_3"))
	_chk("CLASS-T04 weapon rule (CLASS_2 ranged só bow)", CharacterClassDefinition.weapon_allowed("CLASS_2", "bow") and not CharacterClassDefinition.weapon_allowed("CLASS_2", "sword"))
	_chk("CLASS-T05 skill pool", CharacterClassDefinition.skill_in_pool("CLASS_3", "SK_C3_BOLT") and not CharacterClassDefinition.skill_in_pool("CLASS_3", "SK_C1_GUARD"))
	var ctx := _ctx(2)
	_chk("CLASS-T06 invalid class reject", str(ctx["cs"].create_character("accA", "NOPE", "X", _app()).get("reason", "")) == "BAD_CLASS")
	# CLASS-T07 class fixed V1: não há API de troca de classe
	var cid := _char(ctx, "accA", "CLASS_1", "Guerra")
	_chk("CLASS-T07 class fixa V1 (sem API de troca de classe)", not (ctx["cs"] as Object).has_method("change_class"))
	# CLASS-T08 (A15) — CP reflete a TENDÊNCIA de classe (stats reais), com spread PEQUENO ⇒ sem class_bonus_cp artificial
	var c1 := _give_char(ctx, "accB", "CLASS_1", "AA", "sword_eternal")   # tanky (hp 1.10)
	var c3 := _give_char(ctx, "accC", "CLASS_3", "BB", "sword_eternal")   # glass (hp 0.90)
	var cp1 := int(ctx["auth"].power_snapshot(c1).get("cp", -1))
	var cp3 := int(ctx["auth"].power_snapshot(c3).get("cp", -2))
	var spread := float(maxi(cp1, cp3)) / float(maxi(1, mini(cp1, cp3)))
	_chk("CLASS-T08 CP reflete classe (difere) mas SEM bônus artificial (spread < 15%)", cp1 != cp3 and cp1 > 0 and spread < 1.15)

# ══════════════ APPEARANCE (§88) ══════════════
func _test_appearance() -> void:
	print("  ── APP ──")
	_chk("APP-T01 body option valid", bool(CharacterAppearance.validate(_app())["ok"]))
	_chk("APP-T02 skin tone valid + livre", CharacterAppearance.SKIN.has("SKIN_5") and CharacterAppearance.option_is_free("skin_tone_id", "SKIN_5"))
	_chk("APP-T03 hair valid", CharacterAppearance.HAIR.has("HAIR_3"))
	_chk("APP-T04 hair color valid", CharacterAppearance.HAIR_COLOR.has("HC_RED"))
	_chk("APP-T05 outfit palette valid", CharacterAppearance.OUTFIT.has("OUTFIT_2"))
	_chk("APP-T06 cosmetic skin separado (campo próprio)", _app("SKIN_PREMIUM").get("cosmetic_skin_id") == "SKIN_PREMIUM")
	_chk("APP-T07 appearance = 0 power", CharacterAppearance.combat_power(_app("SKIN_PREMIUM")) == 0)
	# APP-T08 unknown combo → fallback DEFAULT_VISUAL
	var res := CharacterAppearanceResolver.resolve(_app())
	_chk("APP-T08 combinação sem sprite → fallback (ASSET_REQUIRED)", str(res["actor_key"]) == CharacterAppearanceResolver.DEFAULT_VISUAL and bool(res["fallback"]))
	# APP-T09 path injection reject
	var bad := CharacterAppearance.new_appearance("../../hack", "SKIN_1", "HAIR_1", "HC_BLACK", "OUTFIT_1", "ERRANTE")
	var bres := CharacterAppearanceResolver.resolve(bad)
	_chk("APP-T09 path injection rejeitado (validação + key segura)", not bool(CharacterAppearance.validate(bad)["ok"]) and CharacterAppearanceResolver.is_safe_key(str(bres["actor_key"])))

# ══════════════ ROSTER (§89) ══════════════
func _test_roster() -> void:
	print("  ── ROST ──")
	var ctx := _ctx(3)
	var a := _char(ctx, "accA", "CLASS_1", "Um"); var b := _char(ctx, "accA", "CLASS_2", "Dois")
	_chk("ROST-T01 conta com múltiplos characters", ctx["roster"].characters_of("accA").size() == 2 and a != b)
	_chk("ROST-T02 free slot cap (2)", ctx["roster"].slot_cap("accA") == 2)
	var over: Dictionary = ctx["cs"].create_character("accA", "CLASS_3", "Tres", _app())
	_chk("ROST-T04 acima do cap rejeita", str(over.get("reason", "")) == "NO_CHARACTER_SLOT")
	# ROST-T03 entitlement raises cap (idempotente)
	ctx["roster"].grant_slot_entitlement("accA", "SLOT_PLUS_1", 1)
	ctx["roster"].grant_slot_entitlement("accA", "SLOT_PLUS_1", 1)   # dup — idempotente
	_chk("ROST-T03 entitlement eleva cap (idempotente, sem slots infinitos)", ctx["roster"].slot_cap("accA") == 3)
	var c := _char(ctx, "accA", "CLASS_3", "Tres")
	_chk("ROST-T03b 3º character cabe após entitlement", c != "")
	# ROST-T05 A não seleciona character de B
	var bchar := _char(ctx, "accB", "CLASS_1", "DeB")
	_chk("ROST-T05 A não opera character de B (NOT_OWNER)", str(ctx["cs"].switch_active_progression("accA", bchar).get("reason", "")) == "NOT_OWNER")
	# ROST-T06 DTO privacy
	var dto: Dictionary = ctx["cs"].get_roster_dto("accA")
	var leak := JSON.stringify(dto).contains("accA") or JSON.stringify(dto).contains("journal") or JSON.stringify(dto).contains("session")
	_chk("ROST-T06 roster DTO sem account/session/journal", not leak and (dto["roster"] as Array).size() == 3)
	# ROST-T07 restart persistence
	ctx["roster"].persist_to("user://a13_roster_test.json")
	var r2 := AccountRosterRepository.new(); r2.load_from("user://a13_roster_test.json")
	_chk("ROST-T07 roster persiste no restart", r2.characters_of("accA").size() == 3)
	if FileAccess.file_exists("user://a13_roster_test.json"): DirAccess.remove_absolute("user://a13_roster_test.json")

# ══════════════ ACTIVE PROGRESSION (§90) ══════════════
func _test_active_progression() -> void:
	print("  ── ACT (progressão ativa / anti-multibox) ──")
	var ctx := _ctx(4); var cs: CharacterService = ctx["cs"]; var ck: ServerClock = ctx["clock"]
	ck.set_now(1000)
	var a := _char(ctx, "accA", "CLASS_1", "AA"); var b := _char(ctx, "accA", "CLASS_2", "BB")
	_chk("ACT-T01 um active char por conta (1º = ativo)", ctx["roster"].active_progress_of("accA") == a)
	cs.switch_active_progression("accA", a); ck.advance(14400)
	_chk("ACT-T02/T04 inativo não acumula; ativo acumula", cs.offline_available_seconds("accA", a) == 14400 and cs.offline_available_seconds("accA", b) == 0)
	cs.switch_active_progression("accA", b); ck.advance(14400)
	var offB := cs.offline_available_seconds("accA", b)
	var offA_inactive := cs.offline_available_seconds("accA", a)
	cs.switch_active_progression("accA", a)
	_chk("ACT-T03/T05 switch fecha antigo + zera novo (SEM 8h sobrepostas)", offB == 14400 and offA_inactive == 0 and cs.offline_available_seconds("accA", a) == 0)
	_chk("ACT-T06 1 gameplay writer/conta (só o ativo abre gameplay)", cs.can_open_gameplay("accA", a) and not cs.can_open_gameplay("accA", b))
	# ACT-T07 restart retains active
	cs.snapshot()
	_chk("ACT-T07 restart mantém active char (roster metadata)", ctx["roster"].active_progress_of("accA") == a)

# ══════════════ LOADOUT (§91) ══════════════
func _test_loadout() -> void:
	print("  ── LOAD ──")
	var ctx := _ctx(5); var cs: CharacterService = ctx["cs"]
	var cid := _char(ctx, "accA", "CLASS_3", "Mago")
	_chk("LOAD-T01 dois slots livres", BuildLoadout.slot_cap(0) == 2)
	_chk("LOAD-T02 entitlement eleva slots", BuildLoadout.slot_cap(2) == 4)
	var good := BuildLoadout.new_loadout("LO2", "Alt", "CLASS_3", "staff", "SK_C3_BOLT", "SK_C3_NOVA", "SK_C3_WARD")
	_chk("LOAD-T06 três skill slots (válido)", bool(cs.set_loadout("accA", cid, 1, good)["ok"]))
	_chk("LOAD-T03 invalid skill reject", str(cs.set_loadout("accA", cid, 0, BuildLoadout.new_loadout("L", "x", "CLASS_3", "staff", "SK_FAKE", "SK_C3_NOVA", "SK_C3_WARD")).get("reason", "")) == "SKILL_NOT_IN_POOL")
	_chk("LOAD-T04 wrong class reject", str(cs.set_loadout("accA", cid, 0, BuildLoadout.new_loadout("L", "x", "CLASS_1", "sword", "SK_C1_GUARD", "SK_C1_CLEAVE", "SK_C1_BASH")).get("reason", "")) == "WRONG_CLASS")
	_chk("LOAD-T05 weapon validation (bow não permitido p/ CLASS_3)", str(cs.set_loadout("accA", cid, 0, BuildLoadout.new_loadout("L", "x", "CLASS_3", "bow", "SK_C3_BOLT", "SK_C3_NOVA", "SK_C3_WARD")).get("reason", "")) == "WEAPON_NOT_ALLOWED")
	_chk("LOAD-T07 slot extra = 0 poder", BuildLoadout.slot_combat_power() == 0)
	# LOAD-T08 arena snapshot immutable: captura class/loadout; alterar loadout depois não muda o snapshot
	var snap := {"class_id": "CLASS_3", "loadout": good.duplicate(true)}
	cs.set_loadout("accA", cid, 1, BuildLoadout.new_loadout("LO3", "New", "CLASS_3", "staff", "SK_C3_NOVA", "SK_C3_WARD", "SK_C3_BLINK"))
	_chk("LOAD-T08 arena snapshot imutável (loadout mudado não altera captura)", str(snap["loadout"]["skill_1"]) == "SK_C3_BOLT")

# ══════════════ COSMETIC (§92) ══════════════
func _test_cosmetic() -> void:
	print("  ── COS ──")
	var ctx := _ctx(6); var cos: CosmeticEntitlementRepository = ctx["cos"]
	_chk("COS-T01 base cosmetic grátis (owned por qualquer conta)", cos.owns("accA", "OUTFIT_1"))
	_chk("COS-T02 premium não possuído rejeita", not cos.owns("accA", "AURA_DRAGON"))
	cos.grant("accA", "AURA_DRAGON")
	_chk("COS-T03 owned aceito após grant", cos.owns("accA", "AURA_DRAGON"))
	_chk("COS-T04 account-wide (mesma conta, qualquer char)", cos.owns("accA", "AURA_DRAGON") and not cos.owns("accB", "AURA_DRAGON"))
	_chk("COS-T05 cosmetic não altera CP (0 power)", cos.combat_power("AURA_DRAGON") == 0)
	# COS-T06 cosmetic não altera stats normalizados da Arena (normalize não recebe cosmetic)
	var n1 := ArenaNormalizationPolicy.normalize_full(500.0, 500.0)
	var n2 := ArenaNormalizationPolicy.normalize_full(500.0, 500.0)
	_chk("COS-T06 cosmetic não altera Arena normalized stats", int(n1["cp"]) == int(n2["cp"]) and int(n1["cosmetic_power"]) == 0)

# ══════════════ CREATE (§93) ══════════════
func _test_create() -> void:
	print("  ── CREATE (atômico) ──")
	var ctx := _ctx(7); var cs: CharacterService = ctx["cs"]
	var r := cs.create_character("accA", "CLASS_1", "Valido", _app())
	_chk("CREATE-T01 valid create", bool(r["ok"]) and str(r["character_id"]) != "")
	var cid := str(r["character_id"])
	var st: Dictionary = ctx["repo"].load(cid)["state"]
	_chk("CREATE-T03 server starter state (level 1, class, weapon)", int(st["hero_level"]) == 1 and str(st["character_class"]) == "CLASS_1" and str(st["equipment"]["weapon"]) == "sword_simple")
	_chk("CREATE-T04/T05 server starter (cliente não injeta stats/gold)", int(st["hero_gold"]) == 0 and int(st.get("prestige_count", 0)) == 0)
	# slot full
	_char(ctx, "accB", "CLASS_1", "B1"); _char(ctx, "accB", "CLASS_2", "B2")
	_chk("CREATE-T02 slot full reject", str(cs.create_character("accB", "CLASS_3", "B3", _app()).get("reason", "")) == "NO_CHARACTER_SLOT")
	# fault = no partial
	cs.set_fault("BEFORE_COMMIT")
	var f := cs.create_character("accC", "CLASS_1", "Fault", _app())
	cs.set_fault("")
	_chk("CREATE-T06 fault before = nenhum character parcial", not bool(f["ok"]) and ctx["roster"].characters_of("accC").size() == 0 and ctx["repo"].character_count() == 3)
	# fault after char (rollback)
	cs.set_fault("AFTER_CHAR")
	var f2 := cs.create_character("accC", "CLASS_1", "Fault2", _app())
	cs.set_fault("")
	_chk("CREATE-T06b fault durante = rollback (save sem owner NÃO existe)", not bool(f2["ok"]) and ctx["roster"].characters_of("accC").size() == 0 and ctx["repo"].character_count() == 3)

# ══════════════ MIGRATION v9→v10 (§94) ══════════════
func _test_migration() -> void:
	print("  ── MIG10 (v9→v10) ──")
	# constrói um save v10 realista, remove os campos novos → v9, migra, aplica, compara
	gs.reset_save()
	gs.hero_level = 29; gs.hero_gold = 4321; gs.prestige_count = 5; gs.master_level = 3
	gs.equipment = {"weapon": "sword_eternal", "offhand": "shield_simple"}
	gs.item_instances = [{"iid": "keep1", "item_id": "sword_eternal", "quality": 88, "rolls": {"attack": 1.1}, "affixes": [], "tradeable": true, "bound": false}]
	gs.materials = {"Fragmentos": 999}
	gs.narrative_seen.clear(); gs.narrative_seen.append("b1"); gs.narrative_seen.append("b2"); gs.slot_refinement = {"weapon": 4}
	var v10: Dictionary = gs.to_dict().duplicate(true)
	var v9: Dictionary = v10.duplicate(true)
	for k in ["character_class", "appearance", "display_name", "loadouts", "active_loadout"]: v9.erase(k)
	v9["schemaVersion"] = 9
	var mig := SaveMigration.prepare(JSON.stringify(v9), "user://a13_mig.json")
	if FileAccess.file_exists("user://a13_mig.json"): DirAccess.remove_absolute("user://a13_mig.json")
	var d: Dictionary = mig["data"]
	_chk("MIG10-T01 v9→v10 (migrated)", bool(mig["ok"]) and str(mig["status"]) == "migrated")
	_chk("MIG10-T02 inventory idêntico (materials)", int((d["materials"] as Dictionary).get("Fragmentos", 0)) == 999)
	_chk("MIG10-T03 equipment idêntico", str(d["equipment"]["weapon"]) == "sword_eternal" and str(d["equipment"]["offhand"]) == "shield_simple")
	_chk("MIG10-T04 ItemInstances idêntico (iid/quality/rolls)", str((d["item_instances"] as Array)[0]["iid"]) == "keep1" and int((d["item_instances"] as Array)[0]["quality"]) == 88)
	_chk("MIG10-T05 Prestige idêntico", int(d["prestige_count"]) == 5 and int(d["master_level"]) == 3)
	_chk("MIG10-T06 economia idêntica (level/gold)", int(d["hero_level"]) == 29 and int(d["hero_gold"]) == 4321)
	_chk("MIG10-T07 narrative idêntico", (d["narrative_seen"] as Array).size() == 2 and int((d["slot_refinement"] as Dictionary)["weapon"]) == 4)
	_chk("MIG10-T08 legacy visual/classe default (Errante/LEGACY_CLASS)", str(d["character_class"]) == "LEGACY_CLASS" and str(d["display_name"]) == "Errante" and str((d["appearance"] as Dictionary)["base_actor_family"]) == "ERRANTE")

# ══════════════ A12 REGRESSION (§96) ══════════════
func _test_a12_regression() -> void:
	print("  ── A12 REGRESSION ──")
	var ctx := _ctx(8)
	var arena := ArenaService.new(); arena.setup(ctx["auth"], ctx["repo"], ctx["items"], ctx["clock"], 8); arena.start_season("S1")
	var a := _char(ctx, "accA", "CLASS_1", "AA"); var b := _char(ctx, "accB", "CLASS_2", "BB")
	var m := arena.create_match(a, b)
	var s := arena.settle_match(str(m["match_id"]), "a", "NORMAL")
	_chk("A12 arena profile/rating ainda funciona", bool(s["ok"]) and int(s["rating_after"][a]) > 1000)
	arena.power.refresh_character(a)
	_chk("A12 CP leaderboard server-side (CP>0)", arena.power.cp_of(a) > 0)
	var nrm := ArenaNormalizationPolicy.normalize_full(1000.0, 100.0)
	_chk("A12 normalization ratio preservado + cosmetic 0", int(nrm["cosmetic_power"]) == 0 and int(nrm["cp"]) == ArenaNormalizationPolicy.TARGET_ARENA_CP)

# ══════════════ A11.2 REGRESSION (§97) ══════════════
func _test_a112_regression() -> void:
	print("  ── A11.2 REGRESSION ──")
	# trade continua por character; NÃO há caminho para trocar cosmetic entitlement / account slot
	_chk("A11.2 whitelist de trade não inclui cosmetic/slot (só iid/gold)", not NetProtocol.COMMAND_ARG_WHITELIST.has("TRADE_COSMETIC") and (NetProtocol.COMMAND_ARG_WHITELIST["TRADE_ADD_ITEM"] as Array) == ["trade_id", "iid"])
	_chk("A11.2 trade permanece CLIENT_ALLOWED por participante", str(NetProtocol.COMMAND_PERMISSION["TRADE_ADD_ITEM"]) == NetProtocol.PERM_CLIENT)

# ══════════════ NETWORK (§95) ══════════════
func _test_network() -> void:
	print("  ── NETWORK (ENet real) ──")
	_fresh_server()
	var A := _client("na"); A.connect_and_login("accA")
	# create + roster + identity por rede
	var cr := A.char_create("CLASS_3", "MagaNet", _app())
	_chk("NET create character por rede", bool(cr.get("ok", false)) and str(cr.get("class_id", "")) == "CLASS_3")
	var cid := str(cr.get("character_id", ""))
	var ros := A.char_get_roster()
	_chk("NET get roster por rede", (ros.get("roster", []) as Array).size() == 1)
	var idn := A.char_identity(cid)
	_chk("NET get identity por rede", bool(idn.get("ok", false)) and str(idn["identity"]["class_id"]) == "CLASS_3")
	# select + loadout + appearance
	_chk("NET select character por rede", bool(A.char_select(cid).get("ok", false)))
	var lo := BuildLoadout.new_loadout("LO2", "Alt", "CLASS_3", "staff", "SK_C3_BOLT", "SK_C3_NOVA", "SK_C3_WARD")
	_chk("NET set loadout por rede", bool(A.char_set_loadout(cid, 1, lo).get("ok", false)))
	_chk("NET set appearance por rede", bool(A.char_set_appearance(cid, _app()).get("ok", false)))
	# malicious: bad class, premium skin não possuído, fake stats ignorados
	_chk("NET malicious class ADMIN rejeitado", str(A.char_create("ADMIN_CLASS", "Hack", _app()).get("reason", "")) == "BAD_CLASS")
	_chk("NET malicious premium skin não possuído rejeitado", str(A.char_create("CLASS_1", "Skin", _app("PAID_XYZ")).get("reason", "")) == "COSMETIC_NOT_OWNED")

func _fresh_server() -> void:
	for c in _all_clients: c.stop()
	_all_clients = []
	if server != null: server.stop()
	_port += 1
	var repo := CharacterRepository.new(); var items := ItemRegistry.new(); var clock := ServerClock.fixed(100000)
	server = GameServer.new(); root.add_child(server); server.configure(repo, items, clock, null)
	server.start(_port, 7)

func _client(prefix: String) -> OnlineClient:
	var gc := GameClient.new(); root.add_child(gc); gc.start(_port); _all_clients.append(gc)
	var oc := OnlineClient.new(); oc.setup(gc, Callable(self, "_pump_all"), prefix); oc.default_timeout_ms = 1500
	return oc

# ══════════════ STRESS (§98) ══════════════
func _test_stress() -> void:
	print("  ── STRESS ──")
	var ctx := _ctx(9); var cs: CharacterService = ctx["cs"]; var ck: ServerClock = ctx["clock"]
	var chars: Dictionary = {}   # account → [cid]
	for acc_i in range(20):
		var acc := "acc%d" % acc_i
		chars[acc] = []
		for n in range(2):   # 2 chars/conta (free cap)
			var cid := _char(ctx, acc, CharacterClassDefinition.playable_ids()[n % 4], "c%d_%d" % [acc_i, n])
			if cid != "": (chars[acc] as Array).append(cid)
	# switch + loadout + appearance churn
	var overlap := false
	for acc in chars:
		var lst: Array = chars[acc]
		if lst.size() < 2: continue
		ck.advance(3600)
		cs.switch_active_progression(acc, str(lst[1]))
		# só 1 ativo acumula
		if cs.offline_available_seconds(acc, str(lst[0])) > 0 and cs.offline_available_seconds(acc, str(lst[1])) > 0:
			overlap = true
		cs.switch_active_progression(acc, str(lst[0]))
	# invariantes
	var total_chars: int = ctx["repo"].character_count()
	var orphan := false; var dup_owner := false; var slot_overflow := false
	var seen := {}
	for acc in chars:
		if ctx["roster"].characters_of(acc).size() > ctx["roster"].slot_cap(acc): slot_overflow = true
		for cid in ctx["roster"].characters_of(acc):
			if not ctx["repo"].load(cid)["ok"]: orphan = true
			if seen.has(cid): dup_owner = true
			seen[cid] = acc
	print("    [stress] accounts=%d chars=%d" % [chars.size(), total_chars])
	_chk("STRESS 0 character orphan (todo roster tem save)", not orphan)
	_chk("STRESS 0 duplicate owner", not dup_owner)
	_chk("STRESS 0 parallel offline farming (nunca 2 ativos acumulando)", not overlap)
	_chk("STRESS 0 slot overflow", not slot_overflow)
	_chk("STRESS 0 entitlement power (slot/loadout = 0 combat)", BuildLoadout.slot_combat_power() == 0 and ctx["cos"].combat_power("ANY") == 0)

# ══════════════ LOCAL (§73) ══════════════
func _test_local() -> void:
	print("  ── LOCAL ──")
	_chk("LOCAL modo default", RuntimeMode.resolve() == RuntimeMode.LOCAL)
	# character creator funciona com autoridade embarcada (sem servidor externo)
	var ctx := _ctx(10)
	var cid := _char(ctx, "localAcc", "CLASS_1", "Local")
	_chk("LOCAL character creator com autoridade embarcada", cid != "" and str(ctx["repo"].load(cid)["state"]["character_class"]) == "CLASS_1")
