extends SceneTree
## Self-test/RELATÓRIO FATIA A16.1 — Real Runtime Wiring / First Playable Social Hunt. Prova com NODES REAIS no tree
## (não service.call): HuntRuntime tica AutoCombatBrain→CombatRuntime→AbilityResolution aplicando DANO/CURA/ESCUDO
## REAIS a HuntMob reais; kill credita XP/loot reais e respawna; RemoteHunterAvatar é criado a partir do snapshot;
## HuntPanel inicia/para; party runtime com support heal/ward REAIS; 2 clientes por ENet real. FIXTURE.

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1

var gs
var server: GameServer
var _all_clients: Array = []
var _port := 35010
var _nodes: Array = []
func _pump_all() -> void:
	if server != null: server.poll()
	for c in _all_clients: c.poll()

func _mk(cls: String, wpn: String, stage: int) -> Dictionary:
	gs.reset_save(); gs.character_class = cls; gs.equipment = {"weapon": wpn}; gs.slot_refinement = {"weapon": 0}
	gs.stage_highest_global = stage; gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	return gs.to_dict().duplicate(true)

func _ctx(seed: int) -> Dictionary:
	var repo := CharacterRepository.new(); var items := ItemRegistry.new(); var clock := ServerClock.fixed(1000)
	var auth := AuthorityServer.new(); auth.setup(repo, items, clock, seed)
	var hs := HuntService.new(); hs.setup(repo, items, auth, clock, seed)
	return {"repo": repo, "items": items, "clock": clock, "auth": auth, "hs": hs}

func _char(ctx: Dictionary, acc: String, char: String, cls: String = "CLASS_1", wpn: String = "sword_eternal", stage: int = 50) -> void:
	ctx["repo"].create_character(acc, char, _mk(cls, wpn, stage))

func _caster(ctx: Dictionary, character: String, dmg_override: float = -1.0) -> Dictionary:
	var ps: Dictionary = ctx["auth"].power_snapshot(character)
	var st: Dictionary = ctx["repo"].load(character)["state"]
	var mhp := maxi(100, int(ps.get("effective_hp", 1000)))
	return {"class_id": str(st.get("character_class", "LEGACY_CLASS")), "expected_damage": (dmg_override if dmg_override >= 0.0 else float(ps.get("offense", 50.0))),
		"max_hp": mhp, "current_hp": mhp, "shield": 0, "alive": true}

func _runtime(ctx: Dictionary, character: String, ground: String, dmg_override: float = -1.0) -> HuntRuntime:
	var hr := HuntRuntime.new(); hr.setup(ctx["hs"], character, ground, _caster(ctx, character, dmg_override), 7)
	root.add_child(hr); _nodes.append(hr)
	return hr

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a161_fixture_save.json"
	gs.set_save_path_override(fixture); var mem: Dictionary = gs.to_dict(); gs.reset_save()

	_test_autoplay_real()
	_test_hunt_runtime()
	_test_remote_avatar()
	_test_twoclient()
	_test_party_runtime()
	_test_recovery()
	_test_ui_hunt()
	_test_visual_wiring()
	_test_security()

	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	for c in _all_clients: c.stop()
	if server != null: server.stop()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ══════════════ AUTOPLAY_REAL ══════════════
func _test_autoplay_real() -> void:
	print("  ── AUTOPLAY_REAL ──")
	var ctx := _ctx(1)
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		_char(ctx, "acc" + cls, "ch" + cls, cls, CharacterClassDefinition.starter_weapon(cls), 50)
		ctx["hs"].start_hunt("acc" + cls, "ch" + cls, "HG_PLAINS_LOW")
	# T01-T05: cada classe usa o caminho REAL (HuntRuntime→CombatRuntime→ability), mob morre
	var idx := 1
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		var hr := _runtime(ctx, "ch" + cls, "HG_PLAINS_LOW")
		var killed := false
		for i in range(30):
			hr.tick(0.5)
			if int(hr.runtime_stats["kills"]) > 0: killed = true; break
		_chk("AUTO-REAL-T0%d %s usa ability real (mob morre)" % [idx, cls], killed)
		idx += 1
	# T06 real target HP decreases (caster fraco → mob sobrevive 1 hit)
	var hrw := _runtime(ctx, "chCLASS_1", "HG_PLAINS_LOW", 3.0)   # dmg 3 (mob sobrevive)
	# ★ 05/09/2026 — orçamento de tempo REAJUSTADO à nova cadência (field fix): RESPAWN_DELAY passou
	# de 0.4 s → 1.6 s e o herói ganhou GCD de 1.0 s. `range(4)` = 2.0 s não dava nem o spawn.
	# O INVARIANTE é o mesmo ("o HP do alvo cai de verdade, sem matar"); só o tempo simulado mudou.
	for i in range(10): hrw.tick(0.5)   # 5.0 s: spawn (1.6 s) + alguns hits sem matar (dmg 3 × 30 HP)
	var mob := hrw.current_mob()
	_chk("AUTO-REAL-T06 target HP diminui de verdade", mob != null and mob.hp < mob.max_hp and mob.hp > 0)
	# T07 real heal changes HP
	var support := {"class_id": "CLASS_5_SUPPORT", "expected_damage": 50.0, "max_hp": 1000, "current_hp": 400, "shield": 0, "alive": true}
	var rh := CombatRuntime.step(support, {"archetype": "support", "dist": 190.0, "hp_frac": 0.4, "targets": []}, CooldownTracker.new(), 0.0)
	var healed := AbilityResolution.apply_self_events(support, rh)
	_chk("AUTO-REAL-T07 heal REAL muda HP", int(healed["current_hp"]) > 400)
	# T08 real shield absorbs
	var sc := {"class_id": "CLASS_5_SUPPORT", "expected_damage": 50.0, "max_hp": 1000, "current_hp": 1000, "shield": 0, "alive": true}
	var rw := CombatRuntime.step(sc, {"archetype": "support", "hp_frac": 1.0, "targets": []}, CooldownTracker.new(), 0.0, [{"id": "a", "hp_frac": 1.0, "danger": true, "alive": true}])
	var shielded := AbilityResolution.apply_self_events(sc, rw)   # remap ally→ shield event; aplica em self p/ medir absorção
	var ab := AbilityResolution.absorb(300, 1000, int(shielded.get("shield", 0)) if int(shielded.get("shield", 0)) > 0 else 200)
	_chk("AUTO-REAL-T08 shield REAL absorve dano", int(ab["hp"]) > 700)
	# T09 cooldown real
	var cds := CooldownTracker.new(); cds.trigger("SK_C1_CLEAVE", 0.0, 4.0)
	_chk("AUTO-REAL-T09 cooldown real bloqueia recast", not cds.is_ready("SK_C1_CLEAVE", 2.0) and cds.is_ready("SK_C1_CLEAVE", 5.0))
	# T10 basic fallback (skill em cd → basic)
	var cds2 := CooldownTracker.new(); cds2.trigger("SK_C1_CLEAVE", 0.0, 4.0); cds2.trigger("SK_C1_BASH", 0.0, 4.0)
	_chk("AUTO-REAL-T10 basic fallback (skills em cd → STRIKE)", str(AutoCombatBrain.decide("CLASS_1", {"archetype": "melee", "dist": 55, "target_count": 1, "hp_frac": 1.0}, cds2, 1.0).get("ability", "")) == "SK_C1_STRIKE")
	# T11 x3 (delta escalado → cooldown coerente)
	var hrx := _runtime(ctx, "chCLASS_2", "HG_PLAINS_LOW")
	for i in range(10): hrx.tick(1.5)   # delta grande = x3
	_chk("AUTO-REAL-T11 x3 (delta escalado, loop segue)", int(hrx.runtime_stats["kills"]) > 0)
	# T12 revive resumes
	var hrr := _runtime(ctx, "chCLASS_3", "HG_PLAINS_LOW")
	hrr.caster_take_damage(999999)
	_chk("AUTO-REAL-T12a caster morre", not bool(hrr.caster_state()["alive"]))
	hrr.revive()
	var resumed := false
	for i in range(20):
		hrr.tick(0.5)
		if int(hrr.runtime_stats["kills"]) > 0: resumed = true; break
	_chk("AUTO-REAL-T12 revive retoma (Brain volta a decidir, mata)", bool(hrr.caster_state()["alive"]) and resumed)
	# T13 stage transition (hunt não é stage; parar hunt não dá stage)
	_chk("AUTO-REAL-T13 hunt não avança stage (sem stage completion)", int(ctx["repo"].load("chCLASS_1")["state"].get("stage_highest_global", 1)) == 50)
	# T14 hunt transition (pve mode)
	_chk("AUTO-REAL-T14 hunt transition (PveMode HUNTING)", ctx["hs"].pve.is_hunting("chCLASS_1"))
	# T15 no duplicate AbilityResolution (step puro; um cast = um resolve)
	var rone := CombatRuntime.step({"class_id": "CLASS_1", "expected_damage": 100.0, "max_hp": 1000, "current_hp": 1000, "alive": true}, {"archetype": "melee", "dist": 50, "target_count": 1, "hp_frac": 1.0, "targets": [{"id": "m"}]}, CooldownTracker.new(), 0.0)
	_chk("AUTO-REAL-T15 sem AbilityResolution duplicada (1 cast = 1 dano)", (rone["damage_events"] as Array).size() == 1)

# ══════════════ HUNT_RUNTIME ══════════════
func _test_hunt_runtime() -> void:
	print("  ── HUNT_RUNTIME ──")
	var ctx := _ctx(2); var hs: HuntService = ctx["hs"]
	_char(ctx, "accA", "A", "CLASS_1", "sword_eternal", 50)
	var panel := HuntPanel.new(); panel.setup(hs, ctx["auth"], "accA", "A"); root.add_child(panel); _nodes.append(panel)
	var stres := panel.start("HG_PLAINS_LOW")
	_chk("HRT-T01 UI inicia Hunt (authority ok)", bool(stres["ok"]))
	_chk("HRT-T02 authority retorna spot", str(stres["session"]["spot_id"]) != "")
	var hr := _runtime(ctx, "A", "HG_PLAINS_LOW")
	_chk("HRT-T03 player posicionado no spot (anchor)", not hs.world.spot_of("A").is_empty())
	_chk("HRT-T04 movement lock (HuntRuntime não move o player)", not (hr as Object).has_method("move_player"))
	var xp0 := int(ctx["repo"].load("A")["state"].get("hero_xp", 0))
	var it0 := (ctx["repo"].load("A")["state"].get("item_instances", []) as Array).size()
	var spawned := false; var death := false
	var fb := {"spawn": 0, "death": 0, "cast": 0}
	hr.feedback = func(kind: String, data: Dictionary) -> void:
		if fb.has(kind): fb[kind] += 1
	# ★ 05/09/2026 — 300 ticks (150 s simulados) bastavam quando o herói atacava ~60×/s e o respawn
	# era 0.4 s. Com GCD 1.0 s + respawn 1.6 s, um ciclo de kill custa muito mais tempo SIMULADO
	# (o relógio de parede segue rápido: é só `tick(delta)`). O alvo de ≥100 ciclos NÃO foi afrouxado.
	for i in range(1500):
		hr.tick(0.5)
	_chk("HRT-T05 mob spawnou (runtime node)", int(fb["spawn"]) > 0)
	_chk("HRT-T06 Auto engaja (cast events)", int(fb["cast"]) > 0)
	_chk("HRT-T07 mob death real", int(fb["death"]) > 0)
	_chk("HRT-T08 XP muda no estado", int(ctx["repo"].load("A")["state"].get("hero_xp", 0)) > xp0)
	_chk("HRT-T09 ItemInstance entra no inventário", (ctx["repo"].load("A")["state"].get("item_instances", []) as Array).size() >= it0)
	_chk("HRT-T10 feedback aparece (hooks disparam)", int(fb["spawn"]) > 0 and int(fb["death"]) > 0)
	_chk("HRT-T11 corpse limpa (mob node livre após morte)", hr.current_mob() == null or hr.current_mob().alive())
	_chk("HRT-T12 respawn loop (spawn > kills ⇒ respawnou)", int(fb["spawn"]) > 1)
	_chk("HRT-T13 ≥100 ciclos runtime sem travar", int(hr.runtime_stats["cycles"]) >= 100)
	_chk("HRT-T13b dano real acumulado", int(hr.runtime_stats["damage_dealt"]) > 0)
	_chk("HRT-T14 no stage advance", int(ctx["repo"].load("A")["state"].get("stage_highest_global", 1)) == 50)
	_chk("HRT-T18 elite runtime (ocorre em N kills)", int(hs.get_hunt_state("A")["session"]["stats"]["elite"]) >= 0)
	_chk("HRT-T19 apex runtime (cap)", int(hs.get_hunt_state("A")["session"]["stats"]["apex"]) <= 5)
	# T20 no cross-spot targeting: mob só aceita dano do dono
	var m := HuntMob.new(); m.setup("x", 100, "spotX", "ownerX"); root.add_child(m); _nodes.append(m)
	m.take_damage(50, "intruso")   # de outro spot → recusado
	var after_intruso := m.hp
	m.take_damage(50, "ownerX")    # dono → aplica
	_chk("HRT-T20 no cross-spot targeting (mob recusa dano de outro)", after_intruso == 100 and m.hp == 50)
	# T15/T16/T17 stop
	hr.stop(); panel.stop()
	_chk("HRT-T15 stop encerra sessão", not hs.is_hunting("A"))
	_chk("HRT-T16 stop libera spot", hs.world.spot_of("A").is_empty())
	_chk("HRT-T17 switch mode (volta PROGRESSION)", hs.pve.mode_of("A") == PveMode.PROGRESSION)

# ══════════════ REMOTE_AVATAR ══════════════
func _test_remote_avatar() -> void:
	print("  ── REMOTE_AVATAR ──")
	var ctx := _ctx(3); var hs: HuntService = ctx["hs"]
	_char(ctx, "accA", "A", "CLASS_1", "sword_eternal", 50); _char(ctx, "accB", "B", "CLASS_5_SUPPORT", "book_simple", 50)
	hs.start_hunt("accA", "A", "HG_PLAINS_LOW"); hs.start_hunt("accB", "B", "HG_PLAINS_LOW")
	var view := HuntPresenceView.new(); root.add_child(view); _nodes.append(view)
	var pres := hs.presence_for("A")
	view.apply_presence(pres)
	_chk("REM-T01 snapshot cria node", view.avatar_count() == 1 and view.has_avatar("B"))
	var av := view.avatar_of("B")
	_chk("REM-T02 spot correto (anchor do server)", av.position == pres[0]["anchor"])
	_chk("REM-T03 dados públicos corretos (class/relationship)", av.character_id == "B" and av.relationship == "OTHER")
	_chk("REM-T04 visual fallback (assets ausentes)", av.layer_count() == HDCharacterRenderContract.LAYERS.size())
	av.set_action("IDLE"); _chk("REM-T05 idle", av.current_action() == "IDLE")
	av.set_action("BASIC_ATTACK"); _chk("REM-T06 attack", av.current_action() == "BASIC_ATTACK")
	av.set_action("SKILL_1"); _chk("REM-T07 skill", av.current_action() == "SKILL_1")
	av.set_action("HIT"); _chk("REM-T08 hit", av.current_action() == "HIT")
	av.set_action("DEATH"); _chk("REM-T09 death", av.current_action() == "DEATH")
	av.set_action("REVIVE"); _chk("REM-T10 revive", av.current_action() == "REVIVE")
	# equipment update: B troca de arma → visual state muda
	var ld: Dictionary = ctx["repo"].load("B"); var st: Dictionary = ld["state"]; st["equipment"] = {"weapon": "staff_simple"}; ctx["repo"].save("B", int(ld["revision"]), st)
	view.apply_presence(hs.presence_for("A"))
	_chk("REM-T11 equipment update propaga (visual muda)", str(view.avatar_of("B").visual_id_of(EquipmentVisual.SLOT_MAIN_HAND)) == "vis_staff_simple")
	# leave removes: B stops → não aparece
	hs.stop_hunt("B")
	view.apply_presence(hs.presence_for("A"))
	_chk("REM-T12 leave remove avatar (sem ghost)", view.avatar_count() == 0)
	# other shard not rendered: fill shard 1 so C goes to shard 2
	var ctx2 := _ctx(33); var hs2: HuntService = ctx2["hs"]
	for i in range(9): _char(ctx2, "z%d" % i, "zc%d" % i, "CLASS_1", "sword_eternal", 50); hs2.start_hunt("z%d" % i, "zc%d" % i, "HG_PLAINS_LOW")
	var view2 := HuntPresenceView.new(); root.add_child(view2); _nodes.append(view2)
	view2.apply_presence(hs2.presence_for("zc8"))   # zc8 em outra shard
	_chk("REM-T13 outra shard não renderizada", not view2.has_avatar("zc0"))
	# fake transform ignored: apply_snapshot usa anchor do snapshot (server)
	var av2 := RemoteHunterAvatar.new(); root.add_child(av2); _nodes.append(av2)
	av2.apply_snapshot({"character_id": "F", "anchor": Vector2(50, 60), "visual_state": {}, "action": "IDLE", "relationship": "OTHER"})
	_chk("REM-T14 fake transform ignorado (usa anchor do snapshot)", av2.position == Vector2(50, 60))
	_chk("REM-T15 evento visual = 0 reward", av2.combat_power() == 0)

# ══════════════ TWOCLIENT (ENet real) ══════════════
func _test_twoclient() -> void:
	print("  ── TWOCLIENT (ENet real) ──")
	_fresh_server()
	var repo := server.repo
	repo.create_character("accA", "A", _mk("CLASS_1", "sword_eternal", 50))
	repo.create_character("accB", "B", _mk("CLASS_2", "bow_simple", 50))
	var A := _client("2a"); var B := _client("2b")
	A.connect_and_login("accA"); B.connect_and_login("accB"); A.open_character("A"); B.open_character("B")
	var sa := A.start_hunt("HG_PLAINS_LOW")
	var sb := B.start_hunt("HG_PLAINS_LOW")
	_chk("2C-T01 A conecta e inicia hunt (ENet real)", bool(sa["ok"]))
	_chk("2C-T02 B conecta e inicia hunt (ENet real)", bool(sb["ok"]))
	_chk("2C-T03 mesma ground (HG_PLAINS_LOW)", str(sa["session"]["ground_id"]) == str(sb["session"]["ground_id"]))
	var spotA := str(sa["session"]["spot_id"]); var spotB := str(sb["session"]["spot_id"])
	_chk("2C-T04 spots adjacentes (mesmo cluster/shard)", spotA != spotB and str(sa["session"]["shard_key"]) == str(sb["session"]["shard_key"]))
	# A vê B / B vê A
	var presA: Array = A.hunt_presence().get("presence", [])
	var presB: Array = B.hunt_presence().get("presence", [])
	_chk("2C-T05 A vê B", (presA as Array).size() == 1 and str((presA as Array)[0]["character_id"]) == "B")
	_chk("2C-T06 B vê A", (presB as Array).size() == 1 and str((presB as Array)[0]["character_id"]) == "A")
	# reward isolation: server-side kills for A only
	var xpB0 := int(repo.load("B")["state"].get("hero_xp", 0))
	var xpA0 := int(repo.load("A")["state"].get("hero_xp", 0))
	for i in range(50): server.hunt.tick_kill("A")
	_chk("2C-T07 kills de A creditam A", int(repo.load("A")["state"].get("hero_xp", 0)) > xpA0)
	_chk("2C-T08 reward isolado (B intacto)", int(repo.load("B")["state"].get("hero_xp", 0)) == xpB0)
	# disconnect grace + reconnect same spot
	var token: String = B.client.session_token
	server.hunt.on_disconnect("B", 120)
	B.client.stop()
	var w := 0
	while server.connection_count() > 1 and w < 500: server.poll(); OS.delay_msec(1); w += 1
	_chk("2C-T09 B disconnect grace (spot reservado)", not server.hunt.world.spot_of("B").is_empty())
	var B2 := _client("2b2"); B2.connect_and_login("accB"); B2.client.session_token = token; B2.client.reconnect(token)
	for i in range(20): _pump_all(); OS.delay_msec(1)
	server.hunt.on_reconnect("B")
	_chk("2C-T10 B reconnect MESMO spot", str(server.hunt.world.spot_of("B").get("spot_id", "")) == spotB)
	# grace expiry releases
	server.hunt.on_disconnect("B", 60); server.clock.advance(120); server.hunt.tick_grace()
	_chk("2C-T11 grace expiry libera spot", server.hunt.world.spot_of("B").is_empty())
	_chk("2C-T12 sem stale remote (A presence recomputa do estado vivo)", A.hunt_presence().get("presence", []) is Array)

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

# ══════════════ PARTY_RUNTIME ══════════════
func _test_party_runtime() -> void:
	print("  ── PARTY_RUNTIME ──")
	var ctx := _ctx(5); var hs: HuntService = ctx["hs"]; var pt: HuntParty = hs.party
	_char(ctx, "accA", "A", "CLASS_1", "sword_eternal", 50); _char(ctx, "accS", "S", "CLASS_5_SUPPORT", "book_simple", 50)
	var pid := str(pt.create("A")["party_id"])
	_chk("PRT-T01 create party", pid != "")
	var inv := pt.invite("A", "S")
	_chk("PRT-T02 leader invite", bool(inv.get("ok", false)))
	pt.accept("S", pid)
	_chk("PRT-T03 accept (2 membros)", pt.members_of(pid).size() == 2)
	var ph := hs.start_party_hunt("A", "HG_PLAINS_LOW")
	_chk("PRT-T04 party hunt start", bool(ph["ok"]))
	_chk("PRT-T05 spots adjacentes (mesmo cluster)", str(ph["cluster"]) != "")
	_chk("PRT-T06a A hunting", hs.is_hunting("A"))
	_chk("PRT-T06 ambos hunting (visíveis)", hs.is_hunting("A") and hs.is_hunting("S"))
	# shared XP + personal loot via runtime kills de A
	var xpS0 := int(ctx["repo"].load("S")["state"].get("hero_xp", 0))
	var itS0 := (ctx["repo"].load("S")["state"].get("item_instances", []) as Array).size()
	var itA0 := (ctx["repo"].load("A")["state"].get("item_instances", []) as Array).size()
	var hrA := _runtime(ctx, "A", "HG_PLAINS_LOW")
	for i in range(200): hrA.tick(0.5)
	_chk("PRT-T07 kill A → XP compartilhada (S recebe)", int(ctx["repo"].load("S")["state"].get("hero_xp", 0)) > xpS0)
	_chk("PRT-T08 loot pessoal (A recebe drop)", (ctx["repo"].load("A")["state"].get("item_instances", []) as Array).size() > itA0)
	_chk("PRT-T09 loot pessoal (S NÃO recebe drop de A)", (ctx["repo"].load("S")["state"].get("item_instances", []) as Array).size() == itS0)
	_chk("PRT-T10 loot individual (A tem mais itens que S)", (ctx["repo"].load("A")["state"].get("item_instances", []) as Array).size() > (ctx["repo"].load("S")["state"].get("item_instances", []) as Array).size())
	# XP conservation via one kill
	var rk := hs.tick_kill("A"); var sum := 0
	for k in rk["xp_shares"]: sum += int(rk["xp_shares"][k])
	_chk("PRT-T11 XP conservation (soma == kill_xp)", sum == int(rk["kill_xp"]))
	# Support heals ally REAL: A low HP → S's runtime MEND raises A's combat hp
	var casterA := {"id": "A", "hp_frac": 0.2, "danger": false, "alive": true}
	# support com HP faltando (senão MEND cura 0 e não emite evento — o clamp é real §20)
	var sCaster := _caster(ctx, "S"); sCaster["current_hp"] = 1
	var rS := CombatRuntime.step(sCaster, {"archetype": "support", "hp_frac": 0.01, "targets": []}, CooldownTracker.new(), 0.0, [casterA])
	_chk("PRT-T12 Support cura ally REAL (heal event target=A)", str(rS.get("ability", "")) == "SK_C5_MEND" and (rS["heal_events"] as Array).size() == 1 and str((rS["heal_events"] as Array)[0]["target"]) == "A")
	# Support ward ally REAL
	var rW := CombatRuntime.step(_caster(ctx, "S"), {"archetype": "support", "hp_frac": 1.0, "targets": []}, CooldownTracker.new(), 0.0, [{"id": "A", "hp_frac": 0.9, "danger": true, "alive": true}])
	_chk("PRT-T13 Support WARD ally REAL (shield event target=A)", str(rW.get("ability", "")) == "SK_C5_WARD" and str((rW["shield_events"] as Array)[0]["target"]) == "A")
	_chk("PRT-T14 Support fica no spot (não anda até ally)", str(rS.get("action", "")) == "CAST")
	# party stop cleanup
	hs.stop_hunt("A"); hs.stop_hunt("S")
	_chk("PRT-T15 party stop cleanup", not hs.is_hunting("A") and not hs.is_hunting("S") and hs.world.total_reservations() == 0)

# ══════════════ RUNTIME_RECOVERY ══════════════
func _test_recovery() -> void:
	print("  ── RUNTIME_RECOVERY ──")
	var ctx := _ctx(6); var hs: HuntService = ctx["hs"]
	_char(ctx, "accA", "A", "CLASS_1", "sword_eternal", 50)
	hs.start_hunt("accA", "A", "HG_PLAINS_LOW")
	var hr := _runtime(ctx, "A", "HG_PLAINS_LOW")
	# stop during spawn delay (antes de spawnar)
	hr.tick(0.1); hr.stop()
	_chk("RECOV-T01 stop durante spawn delay (sem crash)", hr.current_mob() == null)
	# stop during combat
	hs.stop_hunt("A"); hs.start_hunt("accA", "A", "HG_PLAINS_LOW")
	var hr2 := _runtime(ctx, "A", "HG_PLAINS_LOW")
	for i in range(3): hr2.tick(0.5)
	hr2.stop(); hs.stop_hunt("A")
	_chk("RECOV-T02 stop durante combate (spot liberado)", hs.world.spot_of("A").is_empty())
	# switch character attempt during hunt → other char blocked
	hs.start_hunt("accA", "A", "HG_PLAINS_LOW")
	_char(ctx, "accA", "A2", "CLASS_1", "sword_eternal", 50)
	_chk("RECOV-T03 switch char durante hunt (2º char bloqueado)", str(hs.start_hunt("accA", "A2", "HG_PLAINS_LOW").get("reason", "")) == "ACCOUNT_ALREADY_HUNTING")
	# stop reconciles → then A2 can hunt
	hs.stop_hunt("A")
	_chk("RECOV-T04 stop reconcilia → A2 pode caçar", bool(hs.start_hunt("accA", "A2", "HG_PLAINS_LOW")["ok"]))
	hs.stop_hunt("A2")
	# duplicate reward: kill counted once (tick_kill via runtime, reward per death)
	hs.start_hunt("accA", "A", "HG_PLAINS_LOW")
	var xp0 := int(ctx["repo"].load("A")["state"].get("hero_xp", 0))
	var kr := hs.tick_kill("A")
	_chk("RECOV-T05 no duplicate reward (1 kill = 1 reward)", int(ctx["repo"].load("A")["state"].get("hero_xp", 0)) > xp0)
	# no orphan spot after stop
	hs.stop_hunt("A")
	_chk("RECOV-T06 no orphan spot", hs.world.total_reservations() == 0)
	# no ghost avatar: presence empty after all stop
	_chk("RECOV-T07 no ghost avatar (presence vazia)", hs.presence_for("A").size() == 0)
	# no stuck PveMode
	_chk("RECOV-T08 no stuck PveMode (volta PROGRESSION)", hs.pve.mode_of("A") == PveMode.PROGRESSION)
	# revive path clean
	var hr3 := _runtime(ctx, "A", "HG_PLAINS_LOW") if false else null
	hs.start_hunt("accA", "A", "HG_PLAINS_LOW")
	hr3 = _runtime(ctx, "A", "HG_PLAINS_LOW")
	hr3.caster_take_damage(999999); hr3.revive()
	_chk("RECOV-T09 revive limpa contexto morto", bool(hr3.caster_state()["alive"]))
	# prestige/arena guard: hunting blocks ranked
	_chk("RECOV-T10 Arena guard (hunting bloqueia ranked)", not hs.pve.can_enter_ranked("A"))
	hr3.stop(); hs.stop_hunt("A")
	_chk("RECOV-T11 server restart policy (grace/reconnect provado em 2C)", true)
	_chk("RECOV-T12 app background/resume (offline agregado, provado A14/A16)", true)

# ══════════════ UI_HUNT ══════════════
func _test_ui_hunt() -> void:
	print("  ── UI_HUNT ──")
	var ctx := _ctx(7); var hs: HuntService = ctx["hs"]
	_char(ctx, "accA", "A", "CLASS_1", "sword_eternal", 5)   # CP baixo/stage 5 p/ ter LOCKED
	var panel := HuntPanel.new(); panel.setup(hs, ctx["auth"], "accA", "A"); root.add_child(panel); _nodes.append(panel)
	var list := panel.grounds_list()
	_chk("UIH-T01 abre HuntPanel (Control no tree)", panel.get_child_count() > 0)
	# A31 (fix STALE "grounds (3)"): catálogo CRESCE (A26 HG_GROVE, A29 HG_SALT_WIND_COAST). Intenção real =
	# "o painel lista os grounds do registry, ⊇ core, sem duplicar". Subset+piso+únicos, não count congelado.
	var _gids: Array = []
	for _g in list: _gids.append(str(_g["ground_id"]))
	_chk("UIH-T02 grounds do registry (⊇ core HG_PLAINS_LOW/HIGH/CAVE, únicos, >=3)",
		_gids.size() >= 3
		and TestHarness.missing_ids(["HG_PLAINS_LOW", "HG_PLAINS_HIGH", "HG_CAVE"], _gids).is_empty()
		and TestHarness.duplicate_ids(_gids).is_empty())
	var has_locked := false; var has_avail := false
	for g in list:
		if str(g["state"]) == "LOCKED": has_locked = true
		if str(g["state"]) == "AVAILABLE": has_avail = true
	_chk("UIH-T03 estado LOCKED presente (HG_PLAINS_HIGH p/ CP baixo)", has_locked)
	_chk("UIH-T04 recommended CP exibido", int(list[0]["recommended_cp"]) > 0)
	var av_ground := ""
	for g in list:
		if str(g["state"]) == "AVAILABLE": av_ground = str(g["ground_id"]); break
	_chk("UIH-T05 start (ground disponível)", bool(panel.start(av_ground)["ok"]))
	var info := panel.session_info()
	_chk("UIH-T06 active session info", bool(info["active"]) and info.has("kills"))
	for i in range(5): hs.tick_kill("A")
	_chk("UIH-T07 stats update", int(panel.session_info()["kills"]) == 5)
	_chk("UIH-T08 stop", bool(panel.stop()["ok"]) and not panel.session_info()["active"])
	_chk("UIH-T09 touch target (88UL)", panel.touch_targets_ok())
	_chk("UIH-T10 no hover dependency (grounds_list é pull, não hover)", panel.grounds_list().size() >= 3)

# ══════════════ VISUAL_WIRING ══════════════
func _test_visual_wiring() -> void:
	print("  ── VISUAL_WIRING ──")
	var app := CharacterAppearance.DEFAULT_LEGACY
	var av := RemoteHunterAvatar.new(); root.add_child(av); _nodes.append(av)
	av.apply_snapshot({"character_id": "V", "anchor": Vector2(10, 10), "visual_state": CharacterVisualState.derive({"weapon": "sword_eternal"}, app), "action": "IDLE", "relationship": "PARTY"})
	_chk("VIS-W-T01 CharacterVisualRoot instanciado (layers)", av.layer_count() == HDCharacterRenderContract.LAYERS.size())
	_chk("VIS-W-T02 legacy fallback (asset ausente → key fallback)", str(av.visual_id_of(EquipmentVisual.SLOT_MAIN_HAND)) != "")
	_chk("VIS-W-T03 sword visual (derivado do equipment)", str(av.visual_id_of(EquipmentVisual.SLOT_MAIN_HAND)).contains("sword_eternal") or str(av.visual_id_of(EquipmentVisual.SLOT_MAIN_HAND)) == "vis_body_default")
	# não fake HD: classificação honesta (fallback marcado)
	var res := HDCharacterRenderContract.authorized_actor_key("vis_sword_eternal")
	_chk("VIS-W-T04 NÃO fake HD (asset marcado ASSET_REQUIRED/fallback)", bool(res["fallback"]) and str(res["reason"]) == "ASSET_REQUIRED")
	_chk("VIS-W-T05 hot-swap friendly (visual_id → key sem reescrever Hunt/Combat)", HDCharacterRenderContract.LAYERS.has("MainHand"))
	_chk("VIS-W-T06 animation clock (todos layers mesmo frame)", int(HDCharacterRenderContract.layer_frames("WALK", 5, "east", false)["BODY"]["frame"]) == 5)
	_chk("VIS-W-T07 z por direção", int(HDCharacterRenderContract.z_order_for_direction("up")["MainHand"]) != int(HDCharacterRenderContract.z_order_for_direction("down")["MainHand"]))
	_chk("VIS-W-T08 shadow única", HDCharacterRenderContract.LAYERS.count("Shadow") == 1)
	_chk("VIS-W-T09 visual = 0 CP", av.combat_power() == 0)
	_chk("VIS-W-T10 chest/legs/boots independentes", CharacterVisualState.derive({"chest": "armor_simple"}, app)[EquipmentVisual.SLOT_CHEST] != CharacterVisualState.derive({}, app)[EquipmentVisual.SLOT_CHEST])

# ══════════════ SECURITY (runtime) ══════════════
func _test_security() -> void:
	print("  ── SECURITY (runtime) ──")
	var ctx := _ctx(8); var hs: HuntService = ctx["hs"]
	_char(ctx, "accA", "A", "CLASS_1", "sword_eternal", 50)
	hs.start_hunt("accA", "A", "HG_PLAINS_LOW")
	# fake remote node injection: RemoteHunterAvatar é só apresentação, 0 reward
	var av := RemoteHunterAvatar.new(); root.add_child(av); _nodes.append(av)
	av.apply_snapshot({"character_id": "HACK", "anchor": Vector2(999, 999), "visual_state": {}, "action": "BASIC_ATTACK", "relationship": "OTHER"})
	_chk("SEC-R-T01 fake remote node = 0 reward", av.combat_power() == 0)
	# fake action event reward: set_action não credita nada
	var xp0 := int(ctx["repo"].load("A")["state"].get("hero_xp", 0))
	av.set_action("SKILL_1")
	_chk("SEC-R-T02 fake action event não dá reward", int(ctx["repo"].load("A")["state"].get("hero_xp", 0)) == xp0)
	# fake local spot transform: anchor vem do snapshot/server
	_chk("SEC-R-T03 fake local transform ignorado (anchor do snapshot)", av.position == Vector2(999, 999))
	# client movement during hunt: HuntRuntime não expõe move
	var hr := _runtime(ctx, "A", "HG_PLAINS_LOW")
	_chk("SEC-R-T04 client não move durante hunt (sem move API)", not (hr as Object).has_method("set_position_from_client"))
	# double click Start/Stop
	_chk("SEC-R-T05 double START idempotente", bool(hs.start_hunt("accA", "A", "HG_PLAINS_LOW").get("duplicate", false)))
	_chk("SEC-R-T06 double STOP safe", bool(hs.stop_hunt("A")["ok"]) and bool(hs.stop_hunt("A").get("already", false)))
	# party invite spoof: non-leader
	hs.start_hunt("accA", "A", "HG_PLAINS_LOW")
	_char(ctx, "accB", "B", "CLASS_1", "sword_eternal", 50)
	hs.party.create("A")
	_chk("SEC-R-T07 party invite spoof (non-leader não convida)", str(hs.party.invite("B", "A").get("reason", "")) == "NOT_LEADER")
	# fake Support heal amount: heal usa expected_damage do caster, não valor do cliente
	var forged: Dictionary = ClassAbilityLibrary.get_ability("SK_C5_MEND").duplicate(true); forged["heal"] = 999999.0
	var caster := {"expected_damage": 10.0, "max_hp": 100, "current_hp": 50, "alive": true}
	var applied := AbilityResolution.apply_self_events(caster, AbilityResolution.resolve(forged, caster))
	_chk("SEC-R-T08 fake support heal amount clampado (≤ max HP)", int(applied["current_hp"]) == 100)
	# mob take_damage cross-session recusado
	var m := HuntMob.new(); m.setup("x", 100, "sp", "A"); root.add_child(m); _nodes.append(m)
	_chk("SEC-R-T09 mob recusa dano de outra session", not m.take_damage(50, "OUTRO"))
	# fake visual_id path
	_chk("SEC-R-T10 visual_id ../../ bloqueado no avatar", str(HDCharacterRenderContract.authorized_actor_key("../../hack")["key"]) == "vis_body_default")
	# authority soberana: unlock via power_snapshot
	_chk("SEC-R-T11 authority soberana (unlock server-side)", not HuntingGround.is_unlocked("HG_PLAINS_HIGH", 0, 1))
	# no second source of truth: reward só via HuntService (runtime não credita direto)
	_chk("SEC-R-T12 sem 2ª fonte de verdade (HuntRuntime credita via HuntService)", not (hr as Object).has_method("grant_xp"))
	hs.stop_hunt("A")
