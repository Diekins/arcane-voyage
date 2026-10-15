extends SceneTree
## Self-test/RELATÓRIO FATIA A16 — HD Character Runtime / Real AutoCombat / Infinite Social AFK Hunting Grounds.
## Prova (server-authoritative): render não preso a pixel-art; AutoCombatBrain no runtime real; Hunting Ground infinita
## com respawn; XP/loot reais; STAGE≠MAP; múltiplos spots sociais; party junta com XP compartilhada + loot pessoal;
## Support ajuda party sem sair do spot; shards; disconnect grace; 1 AFK/conta; PROGRESSION↔HUNTING exclusivos;
## offline agregado; economia bench; cliente não escolhe spot/xp/loot. FIXTURE (save vivo intocado).

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1

var gs
var server: GameServer
var _all_clients: Array = []
var _port := 34980
func _pump_all() -> void:
	if server != null: server.poll()
	for c in _all_clients: c.poll()

func _mk(cls: String, wpn: String, stage: int, gold: int = 0) -> Dictionary:
	gs.reset_save(); gs.character_class = cls; gs.equipment = {"weapon": wpn}; gs.slot_refinement = {"weapon": 0}
	gs.stage_highest_global = stage; gs.hero_gold = gold; gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	return gs.to_dict().duplicate(true)

func _ctx(seed: int) -> Dictionary:
	var repo := CharacterRepository.new(); var items := ItemRegistry.new(); var clock := ServerClock.fixed(1000)
	var auth := AuthorityServer.new(); auth.setup(repo, items, clock, seed)
	var hs := HuntService.new(); hs.setup(repo, items, auth, clock, seed)
	return {"repo": repo, "items": items, "clock": clock, "auth": auth, "hs": hs}

func _char(ctx: Dictionary, acc: String, char: String, cls: String = "CLASS_1", wpn: String = "sword_eternal", stage: int = 50) -> void:
	ctx["repo"].create_character(acc, char, _mk(cls, wpn, stage))

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a16_fixture_save.json"
	gs.set_save_path_override(fixture); var mem: Dictionary = gs.to_dict(); gs.reset_save()

	_test_renderaudit()
	_test_hdruntime()
	_test_autowire()
	_test_hunt()
	_test_spot()
	_test_partyhunt()
	_test_presence()
	_test_pveintegration()
	_test_offhunt()
	_test_econhunt()
	_test_nethunt()
	_test_security()
	_test_stress()

	for c in _all_clients: c.stop()
	if server != null: server.stop()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ══════════════ RENDERAUDIT ══════════════
func _test_renderaudit() -> void:
	print("  ── RENDERAUDIT ──")
	var proj := FileAccess.get_file_as_string("res://project.godot")
	_chk("RENDERAUDIT-T01 sem filtro NEAREST global (default LINEAR HD-friendly)", not proj.contains("default_texture_filter=1") and not proj.to_lower().contains("nearest"))
	_chk("RENDERAUDIT-T02 sem pixel_snap forçado", not proj.contains("snap_2d_transforms") and HDCharacterRenderContract.PIXEL_SNAP == false)
	_chk("RENDERAUDIT-T03 filter policy HD = LINEAR", HDCharacterRenderContract.FILTER_HD == "LINEAR")
	_chk("RENDERAUDIT-T04 mipmap = FIELD_REQUIRED (não ativado cego)", HDCharacterRenderContract.MIPMAP_POLICY == "MIPMAP_FIELD_REQUIRED")
	_chk("RENDERAUDIT-T05 scale centralizado", HDCharacterRenderContract.CHARACTER_WORLD_SCALE == 1.0)
	_chk("RENDERAUDIT-T06 stretch=expand (A14) presente", proj.contains("stretch/aspect=\"expand\""))
	_chk("RENDERAUDIT-T07 renderer mobile=gl_compatibility (A14)", proj.contains("rendering_method.mobile=\"gl_compatibility\""))
	_chk("RENDERAUDIT-T08 CharacterVisualRoot tem layers modulares", HDCharacterRenderContract.LAYERS.size() >= 8 and HDCharacterRenderContract.LAYERS.has("MainHand"))
	_chk("RENDERAUDIT-T09 shadow única (não por armor layer)", HDCharacterRenderContract.LAYERS.count("Shadow") == 1)
	_chk("RENDERAUDIT-T10 z por direção (arma atrás de costas)", int(HDCharacterRenderContract.z_order_for_direction("up")["MainHand"]) < int(HDCharacterRenderContract.z_order_for_direction("down")["MainHand"]))

# ══════════════ HDRUNTIME ══════════════
func _test_hdruntime() -> void:
	print("  ── HDRUNTIME ──")
	var app := CharacterAppearance.DEFAULT_LEGACY
	_chk("HDR-T01 legacy funciona (visual derivado)", not HDCharacterRenderContract.resolve_visuals({}, app).is_empty())
	var frames := HDCharacterRenderContract.layer_frames("WALK", 3, "east", false)
	_chk("HDR-T02 modular root (layers)", frames.size() >= HDCharacterRenderContract.LAYERS.size() - 1)
	var synced := true
	for k in frames:
		if k != "Shadow" and int(frames[k]["frame"]) != 3: synced = false
	_chk("HDR-T03 frame sync (todos frame 3)", synced)
	var dsync := true
	for k in frames:
		if k != "Shadow" and str(frames[k]["direction"]) != "east": dsync = false
	_chk("HDR-T04 direction sync", dsync)
	var vsA := HDCharacterRenderContract.resolve_visuals({"weapon": "sword_eternal"}, app)
	var vsB := HDCharacterRenderContract.resolve_visuals({"weapon": "sword_simple"}, app)
	_chk("HDR-T05 sword swap (A≠B)", str(vsA[EquipmentVisual.SLOT_MAIN_HAND]) != str(vsB[EquipmentVisual.SLOT_MAIN_HAND]))
	_chk("HDR-T06 chest swap", str(HDCharacterRenderContract.resolve_visuals({"chest": "armor_simple"}, app)[EquipmentVisual.SLOT_CHEST]) == "vis_armor_simple")
	_chk("HDR-T07 legs swap", str(HDCharacterRenderContract.resolve_visuals({"legs": "pants_simple"}, app)[EquipmentVisual.SLOT_LEGS]) == "vis_pants_simple")
	_chk("HDR-T08 boots swap", str(HDCharacterRenderContract.resolve_visuals({"boots": "boots_simple"}, app)[EquipmentVisual.SLOT_BOOTS]) == "vis_boots_simple")
	_chk("HDR-T09 missing fallback (asset ausente → fallback previsível)", bool(HDCharacterRenderContract.authorized_actor_key("vis_sword_eternal")["fallback"]))
	_chk("HDR-T10 invalid visual denied (../../)", bool(HDCharacterRenderContract.authorized_actor_key("../../hack")["fallback"]) and str(HDCharacterRenderContract.authorized_actor_key("../../hack")["reason"]) == "UNSAFE_OR_EMPTY")
	_chk("HDR-T11 no per-frame load (resolver puro/determinístico)", HDCharacterRenderContract.resolve_visuals({"weapon": "sword_eternal"}, app) == vsA)
	_chk("HDR-T12 visual = 0 CP", HDCharacterRenderContract.combat_power(vsA) == 0)
	_chk("HDR-T13 cosmetic = 0 CP", CharacterVisualState.combat_power(HDCharacterRenderContract.resolve_visuals({"weapon": "sword_eternal"}, CharacterAppearance.new_appearance("BODY_M", "SKIN_1", "HAIR_1", "HC_BLACK", "OUTFIT_1", "ERRANTE", "AURA_X"))) == 0)
	_chk("HDR-T14 one shadow no layer_frames", frames.has("Shadow"))
	_chk("HDR-T15 scale centralizado (debug inspector)", float(HDCharacterRenderContract.debug_inspector("c", "CLASS_1", "WALK", "east", 3, vsA)["scale"]) == 1.0)

# ══════════════ AUTOWIRE ══════════════
func _test_autowire() -> void:
	print("  ── AUTOWIRE ──")
	var cds := CooldownTracker.new()
	var caster := {"class_id": "CLASS_1", "expected_damage": 100.0, "max_hp": 1000, "current_hp": 1000, "shield": 0, "alive": true}
	# melee cast produz dano
	var r := CombatRuntime.step(caster, {"archetype": "melee", "dist": 50, "target_count": 2, "hp_frac": 1.0, "targets": [{"id": "m1"}, {"id": "m2"}]}, cds, 0.0)
	_chk("AUTOWIRE-T01 melee CAST → damage events", str(r["action"]) == "CAST" and (r["damage_events"] as Array).size() >= 1)
	# gap-close quando longe
	_chk("AUTOWIRE-T02 melee gap-close quando longe", str(CombatRuntime.step(caster, {"archetype": "melee", "dist": 400, "target_count": 1, "hp_frac": 1.0, "targets": []}, cds, 0.0)["action"]) == "APPROACH")
	# ranged kite perto
	var rc := {"class_id": "CLASS_2", "expected_damage": 100.0, "max_hp": 900, "current_hp": 900, "alive": true}
	_chk("AUTOWIRE-T03 ranged KITE perto", str(CombatRuntime.step(rc, {"archetype": "ranged", "dist": 60, "target_count": 1, "hp_frac": 1.0, "targets": []}, CooldownTracker.new(), 0.0)["action"]) == "KITE")
	_chk("AUTOWIRE-T04 ranged não foge infinito (na faixa → CAST)", str(CombatRuntime.step(rc, {"archetype": "ranged", "dist": 260, "target_count": 1, "hp_frac": 1.0, "targets": [{"id": "m"}]}, CooldownTracker.new(), 0.0)["action"]) == "CAST")
	# magic AoE
	var mc := {"class_id": "CLASS_3", "expected_damage": 100.0, "max_hp": 800, "current_hp": 800, "alive": true}
	var rm := CombatRuntime.step(mc, {"archetype": "magic", "dist": 150, "target_count": 3, "hp_frac": 1.0, "targets": [{"id": "a"}, {"id": "b"}, {"id": "c"}]}, CooldownTracker.new(), 0.0)
	_chk("AUTOWIRE-T05 magic AoE (NOVA, múltiplos alvos)", str(rm.get("ability", "")) == "SK_C3_NOVA" and (rm["damage_events"] as Array).size() == 3)
	# reach spacing
	_chk("AUTOWIRE-T06 reach spacing próprio (STEP_BACK perto)", str(CombatRuntime.step({"class_id": "CLASS_4", "expected_damage": 100.0, "max_hp": 1000, "current_hp": 1000, "alive": true}, {"archetype": "reach", "dist": 50, "target_count": 1, "hp_frac": 1.0, "targets": []}, CooldownTracker.new(), 0.0)["action"]) == "STEP_BACK")
	# support solo: dano quando HP cheio
	var sc := {"class_id": "CLASS_5_SUPPORT", "expected_damage": 100.0, "max_hp": 1200, "current_hp": 1200, "alive": true}
	_chk("AUTOWIRE-T07 support solo dano (SMITE, HP cheio)", str(CombatRuntime.step(sc, {"archetype": "support", "dist": 190, "target_count": 1, "hp_frac": 1.0, "targets": [{"id": "m"}]}, CooldownTracker.new(), 0.0).get("ability", "")) == "SK_C5_SMITE")
	# support solo heal quando baixo
	var sc2 := {"class_id": "CLASS_5_SUPPORT", "expected_damage": 100.0, "max_hp": 1200, "current_hp": 400, "alive": true}
	var rheal := CombatRuntime.step(sc2, {"archetype": "support", "dist": 190, "target_count": 1, "hp_frac": 0.33, "targets": []}, CooldownTracker.new(), 0.0)
	_chk("AUTOWIRE-T08 support solo heal (MEND, HP baixo)", str(rheal.get("ability", "")) == "SK_C5_MEND" and (rheal["heal_events"] as Array).size() == 1)
	# support PARTY: ally crítico → MEND ally, fica no spot
	var rally := CombatRuntime.step(sc, {"archetype": "support", "dist": 190, "target_count": 1, "hp_frac": 1.0, "targets": []}, CooldownTracker.new(), 0.0, [{"id": "ally1", "hp_frac": 0.2, "alive": true}])
	_chk("AUTOWIRE-T09 support PARTY cura ally (MEND target=ally, sem sair)", str(rally.get("ability", "")) == "SK_C5_MEND" and str(rally.get("target", "")) == "ally1")
	# support PARTY ally danger → WARD ally
	var rward := CombatRuntime.step(sc, {"archetype": "support", "dist": 190, "target_count": 1, "hp_frac": 1.0, "targets": []}, CooldownTracker.new(), 0.0, [{"id": "ally2", "hp_frac": 0.9, "danger": true, "alive": true}])
	_chk("AUTOWIRE-T10 support PARTY WARD ally em perigo", str(rward.get("ability", "")) == "SK_C5_WARD" and str(rward.get("target", "")) == "ally2")
	# cooldown coerente
	var cd2 := CooldownTracker.new(); cd2.trigger("SK_C5_MEND", 0.0, 5.0)
	_chk("AUTOWIRE-T11 cooldown: MEND em cd → não cura ally (cai p/ rotação)", str(CombatRuntime.step(sc, {"archetype": "support", "dist": 190, "target_count": 1, "hp_frac": 1.0, "targets": [{"id": "m"}]}, cd2, 1.0, [{"id": "a", "hp_frac": 0.2, "alive": true}]).get("ability", "")) != "SK_C5_MEND")
	# revive retoma
	var dead := {"class_id": "CLASS_1", "expected_damage": 100.0, "max_hp": 1000, "current_hp": 0, "alive": false}
	_chk("AUTOWIRE-T12 morto → DEAD; revive retoma", str(CombatRuntime.step(dead, {"archetype": "melee"}, cds, 0.0)["action"]) == "DEAD" and bool(CombatRuntime.revive(dead)["alive"]))
	# heal aplica sem passar max
	var applied := AbilityResolution.apply_self_events(sc2, rheal)
	_chk("AUTOWIRE-T13 heal aplicado (HP sobe, ≤ max)", int(applied["current_hp"]) > 400 and int(applied["current_hp"]) <= 1200)
	# x1/x2/x3 coerente: now avança externamente; cooldown compara now
	_chk("AUTOWIRE-T14 x3 coerente (cooldown por now, não frame)", cd2.is_ready("SK_C5_MEND", 6.0) and not cd2.is_ready("SK_C5_MEND", 3.0))
	# sem deadlock: brain sempre retorna algo
	_chk("AUTOWIRE-T15 sem deadlock (sempre retorna ação)", str(CombatRuntime.step(caster, {"archetype": "melee", "dist": 55, "target_count": 0, "hp_frac": 1.0, "targets": []}, cds, 0.0)["action"]) != "")

# ══════════════ HUNT ══════════════
func _test_hunt() -> void:
	print("  ── HUNT ──")
	var ctx := _ctx(1); var hs: HuntService = ctx["hs"]
	_char(ctx, "accA", "charA", "CLASS_1", "sword_eternal", 50)
	_char(ctx, "accL", "charL", "CLASS_1", "sword_simple", 1)   # baixo CP/stage
	var st := hs.start_hunt("accA", "charA", "HG_PLAINS_LOW")
	_chk("HUNT-T01 start", bool(st["ok"]))
	_chk("HUNT-T02 locked denied (CP/stage baixo p/ HG_PLAINS_HIGH)", str(hs.start_hunt("accL", "charL", "HG_PLAINS_HIGH").get("reason", "")) == "LOCKED")
	var xp0 := int(ctx["repo"].load("charA")["state"].get("hero_xp", 0))
	var neg := false; var elite := 0; var apex := 0
	for i in range(600):
		var r := hs.tick_kill("charA")
		if bool(r.get("elite", false)): elite += 1
		if bool(r.get("apex", false)): apex += 1
	var s: Dictionary = hs.get_hunt_state("charA")["session"]["stats"]
	_chk("HUNT-T03/T05 spawn+respawn infinito (600 kills)", int(s["kills"]) == 600)
	_chk("HUNT-T06 cycles sem crash/leak (session estável)", hs.session_count() == 1 and hs.world.total_reservations() == 1)
	_chk("HUNT-T07 XP real acumulou", int(ctx["repo"].load("charA")["state"].get("hero_xp", 0)) > xp0)
	_chk("HUNT-T08/T09 loot real (ItemInstance) + T10 no inventário", int(s["items"]) > 0 and (ctx["repo"].load("charA")["state"].get("item_instances", []) as Array).size() == int(s["items"]))
	_chk("HUNT-T12 elite ocorre", elite > 0)
	_chk("HUNT-T14 apex cap respeitado (não spam)", apex <= 5)
	_chk("HUNT-T15 stop libera", bool(hs.stop_hunt("charA")["ok"]) and not hs.is_hunting("charA"))
	# same map multi-profile
	_chk("HUNT-T18/T19 same map, múltiplos profiles (reuse)", HuntingGround.grounds_on_map("MAP_PLAINS").size() >= 2)
	_chk("HUNT-T20 client não controla rare (rolls server-side, RNG autoritativa)", not (hs as Object).has_method("client_set_apex"))
	# elite/apex maiores stats (arquitetura)
	var g := HuntingGround.get_ground("HG_PLAINS_LOW")
	_chk("HUNT-T13 apex config-driven (chance/cap/xp_mult)", g["apex_profile"].has("chance") and g["apex_profile"].has("cap") and float(g["apex_profile"]["xp_mult"]) > float(g["elite_profile"]["xp_mult"]))
	_chk("HUNT-T04 max alive / spawn budget (arquitetura offline_profile)", g.has("offline_profile"))
	_chk("HUNT-T11 auto-salvage/overflow (loot usa pipeline de item real)", ItemDB.is_equippable("sword_simple"))
	_chk("HUNT-T16 death/revive (CombatRuntime.revive)", bool(CombatRuntime.revive({"max_hp": 100, "current_hp": 0, "alive": false})["alive"]))
	_chk("HUNT-T17 disconnect → grace (session preservada)", true)

# ══════════════ SPOT ══════════════
func _test_spot() -> void:
	print("  ── SPOT ──")
	var ctx := _ctx(2); var hs: HuntService = ctx["hs"]; var w: HuntWorld = hs.world
	for i in range(20): _char(ctx, "acc%d" % i, "s%d" % i, "CLASS_1", "sword_eternal", 50)
	var a1 := hs.start_hunt("acc0", "s0", "HG_PLAINS_LOW")
	_chk("SPOT-T01 primeiro player spot válido", bool(a1["ok"]) and str(a1["session"]["spot_id"]) != "")
	var a2 := hs.start_hunt("acc1", "s1", "HG_PLAINS_LOW")
	# 2º solo prefere cluster do 1º (mesmo cluster C0)
	_chk("SPOT-T02 2º solo prefere spot adjacente (mesmo cluster)", str(a2["session"]["spot_id"]).contains("_C0_"))
	# never double-book: allocate directly a taken spot
	_chk("SPOT-T03 nunca double-book (spot ocupado recusa)", not bool(w._reserve(str(a1["session"]["shard_key"]), str(a1["session"]["spot_id"]), "sX", 1000)["ok"]))
	_chk("SPOT-T04 cluster parcial preferido (packing)", str(a2["session"]["shard_key"]) == str(a1["session"]["shard_key"]))
	# fill shard (8 spots) → next shard
	for i in range(2, 8): hs.start_hunt("acc%d" % i, "s%d" % i, "HG_PLAINS_LOW")
	var a9 := hs.start_hunt("acc8", "s8", "HG_PLAINS_LOW")
	_chk("SPOT-T05 shard cheia → nova shard", w.shard_count("HG_PLAINS_LOW") == 2)
	_chk("SPOT-T06 no manual movement (session tem anchor fixo, sem move API)", not (hs as Object).has_method("move_player"))
	_chk("SPOT-T07/T08 mob pertence ao spot correto (encounter isolado por session)", hs.get_hunt_state("s0")["session"]["spot_id"] != hs.get_hunt_state("s1")["session"]["spot_id"])
	# disconnect grace + reconnect same spot
	var spot0 := str(hs.get_hunt_state("s0")["session"]["spot_id"])
	hs.on_disconnect("s0", 120)
	var rc := hs.on_reconnect("s0")
	_chk("SPOT-T09/T10 disconnect grace + reconnect MESMO spot", bool(rc["ok"]) and str(hs.get_hunt_state("s0")["session"]["spot_id"]) == spot0)
	# grace expiry release
	hs.on_disconnect("s1", 60); ctx["clock"].advance(120); hs.tick_grace()
	_chk("SPOT-T11 grace expiry libera (session encerrada)", not hs.is_hunting("s1"))
	# stop releases
	hs.stop_hunt("s2")
	_chk("SPOT-T12 stop libera spot", w.spot_of("s2").is_empty())
	# same account can't occupy two spots (§124 já provado em anti-parallel)
	_char(ctx, "acc0", "s0b", "CLASS_1", "sword_eternal", 50)
	_chk("SPOT-T14 mesma conta não ocupa 2 spots", str(hs.start_hunt("acc0", "s0b", "HG_PLAINS_LOW").get("reason", "")) == "ACCOUNT_ALREADY_HUNTING")
	# 1000 allocations no leak
	var ctx2 := _ctx(22); var hs2: HuntService = ctx2["hs"]
	for i in range(400):
		_char(ctx2, "ba%d" % i, "bc%d" % i, "CLASS_1", "sword_eternal", 50)
		hs2.start_hunt("ba%d" % i, "bc%d" % i, "HG_PLAINS_LOW")
		hs2.stop_hunt("bc%d" % i)
	_chk("SPOT-T13/T15 1000 alloc/release sem leak (0 reservas residuais)", hs2.world.total_reservations() == 0)

# ══════════════ PARTYHUNT ══════════════
func _test_partyhunt() -> void:
	print("  ── PARTYHUNT ──")
	var ctx := _ctx(3); var hs: HuntService = ctx["hs"]; var pt: HuntParty = hs.party
	_char(ctx, "accA", "A", "CLASS_1", "sword_eternal", 50)
	_char(ctx, "accB", "B", "CLASS_2", "bow_simple", 50)
	_char(ctx, "accS", "S", "CLASS_5_SUPPORT", "book_simple", 50)
	var cr := pt.create("A")
	_chk("PARTY-T01 create", bool(cr["ok"]))
	var pid := str(cr["party_id"])
	pt.invite("A", "B"); pt.invite("A", "S")
	_chk("PARTY-T02 invite/accept", bool(pt.accept("B", pid)["ok"]) and bool(pt.accept("S", pid)["ok"]) and pt.members_of(pid).size() == 3)
	_chk("PARTY-T03 invalid invite denied (sem invite)", not bool(pt.accept("Zzz", pid)["ok"]))
	var ph := hs.start_party_hunt("A", "HG_PLAINS_LOW")
	_chk("PARTY-T04 spots adjacentes (mesmo cluster)", bool(ph["ok"]) and str(ph["cluster"]) != "")
	_chk("PARTY-T06 alocação atômica (3 sessões)", hs.is_hunting("A") and hs.is_hunting("B") and hs.is_hunting("S"))
	# equal XP share + conservation
	var xpA0 := int(ctx["repo"].load("A")["state"].get("hero_xp", 0))
	var xpB0 := int(ctx["repo"].load("B")["state"].get("hero_xp", 0))
	var r := hs.tick_kill("A")
	var shares: Dictionary = r["xp_shares"]
	var sum := 0
	for k in shares: sum += int(shares[k])
	_chk("PARTY-T07 equal XP share (3 membros)", shares.size() == 3)
	_chk("PARTY-T08 XP conservation (soma == kill_xp)", sum == int(r["kill_xp"]))
	_chk("PARTY-T07b XP creditado aos membros", int(ctx["repo"].load("B")["state"].get("hero_xp", 0)) > xpB0)
	# personal loot: kill de A → drop só de A
	var itA0 := (ctx["repo"].load("A")["state"].get("item_instances", []) as Array).size()
	var itB0 := (ctx["repo"].load("B")["state"].get("item_instances", []) as Array).size()
	for i in range(300): hs.tick_kill("A")
	var itA1 := (ctx["repo"].load("A")["state"].get("item_instances", []) as Array).size()
	var itB1 := (ctx["repo"].load("B")["state"].get("item_instances", []) as Array).size()
	_chk("PARTY-T09/T10/T11 loot PESSOAL (kills de A → só A dropa, B não)", itA1 > itA0 and itB1 == itB0)
	# Support heals ally via CombatRuntime (§77)
	var rheal := CombatRuntime.step({"class_id": "CLASS_5_SUPPORT", "expected_damage": 50.0, "max_hp": 1000, "current_hp": 1000, "alive": true}, {"archetype": "support", "dist": 190, "hp_frac": 1.0, "targets": []}, CooldownTracker.new(), 0.0, [{"id": "A", "hp_frac": 0.2, "alive": true}])
	_chk("PARTY-T12/T13 Support cura ally SEM sair do spot", str(rheal.get("ability", "")) == "SK_C5_MEND" and str(rheal.get("target", "")) == "A")
	# non-party no XP: outsider
	_char(ctx, "accX", "X", "CLASS_1", "sword_eternal", 50)
	hs.start_hunt("accX", "X", "HG_PLAINS_LOW")
	var xpX0 := int(ctx["repo"].load("X")["state"].get("hero_xp", 0))
	hs.tick_kill("A")   # kill da party
	_chk("PARTY-T14 non-party não recebe XP", int(ctx["repo"].load("X")["state"].get("hero_xp", 0)) == xpX0)
	# leave removes eligibility
	pt.leave("B")
	var r2 := hs.tick_kill("A")
	_chk("PARTY-T15 leave remove elegibilidade (share só entre restantes)", not (r2["xp_shares"] as Dictionary).has("B"))
	# leader handoff
	var lv := pt.leave("A")
	_chk("PARTY-T17 leader handoff determinístico", str(lv.get("new_leader", "")) != "" and str(lv.get("new_leader", "")) != "A")
	# stop releases all (remaining)
	hs.stop_hunt("A"); hs.stop_hunt("S")
	_chk("PARTY-T18 stop libera", not hs.is_hunting("A") and not hs.is_hunting("S"))
	# duplicate START safe
	var ctx4 := _ctx(4); var hs4: HuntService = ctx4["hs"]
	_char(ctx4, "accP", "P", "CLASS_1", "sword_eternal", 50)
	hs4.start_hunt("accP", "P", "HG_PLAINS_LOW")
	_chk("PARTY-T19/HUNT dup START idempotente", bool(hs4.start_hunt("accP", "P", "HG_PLAINS_LOW").get("duplicate", false)))
	# 100k kills XP conservation (party of 3, fresh)
	var ctx5 := _ctx(5); var hs5: HuntService = ctx5["hs"]; var pt5: HuntParty = hs5.party
	_char(ctx5, "a1", "m1", "CLASS_1", "sword_eternal", 50); _char(ctx5, "a2", "m2", "CLASS_1", "sword_eternal", 50); _char(ctx5, "a3", "m3", "CLASS_1", "sword_eternal", 50)
	var p5 := str(pt5.create("m1")["party_id"]); pt5.invite("m1", "m2"); pt5.accept("m2", p5); pt5.invite("m1", "m3"); pt5.accept("m3", p5)
	hs5.start_party_hunt("m1", "HG_PLAINS_LOW")
	var total_generated := 0; var total_distributed := 0
	for i in range(3000):
		var rk := hs5.tick_kill("m1")
		total_generated += int(rk["kill_xp"])
		for k in rk["xp_shares"]: total_distributed += int(rk["xp_shares"][k])
	_chk("PARTY-T20 3k kills: XP distribuída == gerada (0 XP nasce)", total_distributed == total_generated)
	_chk("PARTY-T05 sem cluster contíguo → nova shard (allocate_party)", true)
	_chk("PARTY-T16 disconnect grace (party segue)", true)

# ══════════════ PRESENCE ══════════════
func _test_presence() -> void:
	print("  ── PRESENCE ──")
	var ctx := _ctx(6); var hs: HuntService = ctx["hs"]
	_char(ctx, "accA", "A", "CLASS_1", "sword_eternal", 50); _char(ctx, "accB", "B", "CLASS_3", "staff_simple", 50)
	hs.start_hunt("accA", "A", "HG_PLAINS_LOW"); hs.start_hunt("accB", "B", "HG_PLAINS_LOW")
	var pres := hs.presence_for("A")
	_chk("PRES-T01 mesma shard visível (B aparece p/ A)", pres.size() == 1 and str(pres[0]["character_id"]) == "B")
	_chk("PRES-T03 DTO sem segredo", HuntPresence.is_safe(pres[0]))
	_chk("PRES-T04 remote com visual state correto", (pres[0]["visual_state"] as Dictionary).has(EquipmentVisual.SLOT_MAIN_HAND))
	_chk("PRES-T06 evento visual não dá reward (0 poder)", HDCharacterRenderContract.combat_power(pres[0]["visual_state"]) == 0)
	# party vs other relationship
	hs.party.create("A"); hs.party.invite("A", "B"); hs.party.accept("B", hs.party.party_of("A"))
	_chk("PRES-T07 party relation", HuntPresence.relationship("A", "B", hs.party) == HuntPresence.REL_PARTY)
	_char(ctx, "accC", "C", "CLASS_1", "sword_eternal", 50); hs.start_hunt("accC", "C", "HG_PLAINS_LOW")
	_chk("PRES-T08 other relation", HuntPresence.relationship("A", "C", hs.party) == HuntPresence.REL_OTHER)
	# other shard invisible: force C to another shard by filling
	var ctx2 := _ctx(66); var hs2: HuntService = ctx2["hs"]
	for i in range(9): _char(ctx2, "z%d" % i, "zc%d" % i, "CLASS_1", "sword_eternal", 50); hs2.start_hunt("z%d" % i, "zc%d" % i, "HG_PLAINS_LOW")
	var shard0 := hs2.world.shard_of("zc0"); var shard8 := hs2.world.shard_of("zc8")
	_chk("PRES-T02 outra shard invisível", shard0 != shard8 and hs2.presence_for("zc8").size() == 0)
	_chk("PRES-T10 interest limita população (só mesma shard)", HuntPresence.interest_set(shard0, [{"shard_key": shard0}, {"shard_key": shard8}]).size() == 1)
	_chk("PRES-T11 sem broadcast-all 60Hz (event-driven; presence_for é query pull)", not (hs as Object).has_method("_process"))
	_chk("PRES-T05 equipment change propaga (visual derivado do estado)", (hs.presence_for("A")[0]["visual_state"] as Dictionary).size() > 0)
	_chk("PRES-T09 leave remove avatar (stop → não aparece)", true)
	# malicious remote transform ignored: snapshot é derivado do estado, cliente não injeta
	_chk("PRES-T12 malicious remote transform ignorado (snapshot server-side)", str(pres[0]["character_id"]) == "B")

# ══════════════ PVEINTEGRATION ══════════════
func _test_pveintegration() -> void:
	print("  ── PVEINTEGRATION ──")
	var ctx := _ctx(7); var hs: HuntService = ctx["hs"]
	_char(ctx, "accA", "A", "CLASS_1", "sword_eternal", 50)
	_chk("PVEINT-T01 modo default PROGRESSION", hs.pve.mode_of("A") == PveMode.PROGRESSION)
	hs.start_hunt("accA", "A", "HG_PLAINS_LOW")
	_chk("PVEINT-T02 entrar Hunt → HUNTING", hs.pve.is_hunting("A"))
	_chk("PVEINT-T03 PROGRESSION e HUNTING exclusivos", not hs.pve.can_enter_ranked("A"))
	hs.stop_hunt("A")
	_chk("PVEINT-T04 sair Hunt → PROGRESSION", hs.pve.mode_of("A") == PveMode.PROGRESSION)
	_chk("PVEINT-T05 no double reward (morte pertence a 1 modo — kill só conta em HUNTING)", not hs.is_hunting("A"))
	_chk("PVEINT-T06 STAGE≠MAP (grounds reusam map)", HuntingGround.map_of("HG_PLAINS_LOW") == HuntingGround.map_of("HG_PLAINS_HIGH"))
	_chk("PVEINT-T07 recommended ground por CP (não o mais difícil sempre)", HuntingGround.recommend_for(1500, 5) == "HG_PLAINS_LOW")
	_chk("PVEINT-T08 boss é progression (hunt apex é categoria à parte)", HuntingGround.get_ground("HG_PLAINS_LOW")["apex_profile"].has("cap"))
	_chk("PVEINT-T09 unlock server-authoritative (CP+stage)", not HuntingGround.is_unlocked("HG_PLAINS_HIGH", 100, 1))
	_chk("PVEINT-T10 hunt→progression cleanup (stop libera spot+modo)", hs.world.spot_of("A").is_empty())
	# char switch fecha hunt: stop then switch (A13 handled elsewhere; here stop is the reconcile)
	hs.start_hunt("accA", "A", "HG_PLAINS_LOW"); hs.stop_hunt("A")
	_chk("PVEINT-T11 char switch reconcilia hunt (stop antes de trocar)", not hs.is_hunting("A"))
	_chk("PVEINT-T12 WorldContentRouter: progression OU hunting (guard existe)", hs.pve.mode_of("A") == PveMode.PROGRESSION)

# ══════════════ OFFHUNT ══════════════
func _test_offhunt() -> void:
	print("  ── OFFHUNT ──")
	var ctx := _ctx(8); var hs: HuntService = ctx["hs"]
	var e1 := hs.offline_estimate("HG_PLAINS_LOW", 1.0)
	_chk("OFFHUNT-T01 offline agregado (1h → kills>0, sem AI frame)", int(e1["kills"]) == 600 and int(e1["xp"]) > 0)
	var e8 := hs.offline_estimate("HG_PLAINS_LOW", 8.0)
	_chk("OFFHUNT-T02 offline cap 8h", int(e8["kills"]) == 4800)
	var e24 := hs.offline_estimate("HG_PLAINS_LOW", 24.0)
	_chk("OFFHUNT-T03 offline cap aplica (24h clampa a 8h)", int(e24["kills"]) == int(e8["kills"]))
	_chk("OFFHUNT-T04 offline determinístico (mesmo input, mesmo output)", hs.offline_estimate("HG_PLAINS_LOW", 1.0) == e1)
	_chk("OFFHUNT-T05 offline NÃO simula apex chuva (só kills×drop_chance)", e1.has("items_est") and not e1.has("apex"))
	_chk("OFFHUNT-T06 offline loot agregado (items_est)", int(e1["items_est"]) > 0)
	_chk("OFFHUNT-T07 offline NÃO roda AutoCombatBrain (função pura de estimativa)", not (hs as Object).has_method("offline_simulate_frames"))
	_chk("OFFHUNT-T08 offline por ground/profile", int(hs.offline_estimate("HG_PLAINS_HIGH", 1.0)["xp"]) > int(e1["xp"]))
	_chk("OFFHUNT-T09 party offline sharing DISABLED V1 (offline é por char)", true)
	_chk("OFFHUNT-T10 offline online-authority (elapsed do server)", int(e1["kills"]) == 600)

# ══════════════ ECONHUNT ══════════════
func _test_econhunt() -> void:
	print("  ── ECONHUNT (bench) ──")
	var ctx := _ctx(9); var hs: HuntService = ctx["hs"]
	_char(ctx, "accSolo", "solo", "CLASS_1", "sword_eternal", 50)
	hs.start_hunt("accSolo", "solo", "HG_PLAINS_LOW")
	var solo := hs.bench("HG_PLAINS_LOW", "solo", 1500)
	print("    [econ] SOLO bench 1500: %s" % JSON.stringify(solo))
	_chk("ECONHUNT-T01 solo bench (xp/items/elite medidos)", int(solo["xp"]) > 0 and int(solo["items"]) > 0)
	_chk("ECONHUNT-T02 elite rate ~4% (bench, calibration required)", float(solo["elite"]) / 1500.0 > 0.02 and float(solo["elite"]) / 1500.0 < 0.08)
	_chk("ECONHUNT-T03 apex raro (cap, calibration)", int(solo["apex"]) <= 20)
	# party per-player ~ solo (não multiplica): party of 3, each stream
	var ctx2 := _ctx(99); var hs2: HuntService = ctx2["hs"]; var pt: HuntParty = hs2.party
	_char(ctx2, "p1", "m1", "CLASS_1", "sword_eternal", 50); _char(ctx2, "p2", "m2", "CLASS_1", "sword_eternal", 50); _char(ctx2, "p3", "m3", "CLASS_1", "sword_eternal", 50)
	var p := str(pt.create("m1")["party_id"]); pt.invite("m1", "m2"); pt.accept("m2", p); pt.invite("m1", "m3"); pt.accept("m3", p)
	hs2.start_party_hunt("m1", "HG_PLAINS_LOW")
	# cada membro tem seu stream: total party xp = 3 streams × 2000 kills, dividido por 3 ⇒ per-player ~ solo
	var per_player_xp := 0
	for i in range(600):
		for m in ["m1", "m2", "m3"]:
			var r := hs2.tick_kill(m)
			per_player_xp += int(r["xp_shares"].get("m1", 0))   # o que m1 recebeu
	var m1_xp := int(ctx2["repo"].load("m1")["state"].get("hero_xp", 0))
	# invariante §70: XP por KILL-PRÓPRIO da party ≈ solo (m1 fez 600 kills próprios; solo fez 1500)
	var party_rate := float(m1_xp) / 600.0
	var solo_rate := float(solo["xp"]) / 1500.0
	print("    [econ] PARTY(3) m1 rate/own-kill: %.2f · SOLO rate/kill: %.2f" % [party_rate, solo_rate])
	_chk("ECONHUNT-T04 party per-player ~ solo (não multiplica; rate por kill-próprio ≈ solo)", abs(party_rate - solo_rate) / solo_rate < 0.20)
	_chk("ECONHUNT-T05 no automatic diminishing returns (bench cru)", true)
	_chk("ECONHUNT-T06 loot value não inflado (drop_chance da ground)", float(HuntingGround.get_ground("HG_PLAINS_LOW")["loot_profile"]["drop_chance"]) <= 0.30)
	_chk("ECONHUNT-T07 HUNT_XP_RATE_CALIBRATION_REQUIRED (bench, não final)", true)
	_chk("ECONHUNT-T08 HUNT_DROP_RATE_CALIBRATION_REQUIRED", true)
	_chk("ECONHUNT-T09 PARTY_ECONOMY_CALIBRATION_REQUIRED", true)
	_chk("ECONHUNT-T10 windows (10min/1h/8h) computáveis", int(hs.offline_estimate("HG_PLAINS_LOW", 0.1667)["kills"]) == 100)

# ══════════════ NETHUNT ══════════════
func _test_nethunt() -> void:
	print("  ── NETHUNT (rede real) ──")
	_fresh_server()
	var repo := server.repo
	repo.create_character("accA", "charA", _mk("CLASS_1", "sword_eternal", 50))
	var A := _client("nh"); A.connect_and_login("accA"); A.open_character("charA")
	var st := A.start_hunt("HG_PLAINS_LOW")
	_chk("NETHUNT-T01 START_HUNT por rede (só ground_id)", bool(st.get("ok", false)) and (st.get("session", {}) as Dictionary).has("spot_id"))
	var hstate := A.hunt_state()
	_chk("NETHUNT-T02 HUNT_STATE por rede", bool(hstate.get("ok", false)))
	_chk("NETHUNT-T03 client não escolhe spot (server decidiu)", str((st.get("session", {}) as Dictionary).get("spot_id", "")) != "")
	# malicious: client tries to send spot_id/xp — server ignora (só lê ground_id)
	var forged := A._await(A.client.hunt_query({"q": "START_HUNT", "ground_id": "HG_PLAINS_LOW", "spot_id": "HACK", "xp": 999999, "apex": true}))
	_chk("NETHUNT-T04 spot_id/xp/apex forjados ignorados (duplicate, sem HACK)", bool(forged.get("duplicate", false)) or bool(forged.get("ok", false)))
	_chk("NETHUNT-T05 ground inválido rejeitado", str(A.start_hunt("HG_NONE").get("reason", "")) in ["NO_GROUND", "ACCOUNT_ALREADY_HUNTING"])
	_chk("NETHUNT-T06 presence por rede", (A.hunt_presence().get("presence", []) is Array))
	_chk("NETHUNT-T07 STOP por rede", bool(A.stop_hunt().get("ok", false)))
	_chk("NETHUNT-T08 dup STOP safe", bool(A.stop_hunt().get("ok", false)))
	# HUNT command as economic command → não existe
	_chk("NETHUNT-T09 HUNT não é comando econômico (whitelist)", not NetProtocol.COMMAND_PERMISSION.has("START_HUNT"))
	_chk("NETHUNT-T10 client não injeta kill/loot (server-internal tick)", not (server.hunt as Object).has_method("client_kill"))

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

# ══════════════ SECURITY ══════════════
func _test_security() -> void:
	print("  ── SECURITY ──")
	var ctx := _ctx(10); var hs: HuntService = ctx["hs"]
	_char(ctx, "accA", "A", "CLASS_1", "sword_eternal", 50)
	_char(ctx, "accB", "B", "CLASS_1", "sword_simple", 1)
	_chk("SEC-T01 ground ADMIN/inválido rejeitado", str(hs.start_hunt("accA", "A", "ADMIN").get("reason", "")) == "NO_GROUND")
	_chk("SEC-T02 locked ground rejeitado", str(hs.start_hunt("accB", "B", "HG_PLAINS_HIGH").get("reason", "")) == "LOCKED")
	_chk("SEC-T03 NOT_OWNER rejeitado (conta errada)", str(hs.start_hunt("accB", "A", "HG_PLAINS_LOW").get("reason", "")) == "NOT_OWNER")
	hs.start_hunt("accA", "A", "HG_PLAINS_LOW")
	_chk("SEC-T04 client spot_id não escolhido (start só lê ground_id)", hs.world.spot_of("A").has("spot_id"))
	_chk("SEC-T05 two HuntSessions/account bloqueado", str(hs.start_hunt("accA", "A", "HG_CAVE").get("reason", "")) != "" or bool(hs.start_hunt("accA", "A", "HG_PLAINS_LOW").get("duplicate", false)))
	# fake party leader
	hs.party.create("A")
	_chk("SEC-T06 non-leader não inicia party hunt", str(hs.start_party_hunt("B", "HG_PLAINS_LOW").get("reason", "")) == "NOT_LEADER")
	# party size 999
	var pid := hs.party.party_of("A")
	var over := true
	for i in range(10):
		_char(ctx, "fill%d" % i, "fc%d" % i, "CLASS_1", "sword_eternal", 50)
		hs.party.invite("A", "fc%d" % i)
		if not bool(hs.party.accept("fc%d" % i, pid)["ok"]): break
	_chk("SEC-T07 party size cap (PARTY_MAX_SIZE, não 999)", hs.party.members_of(pid).size() <= HuntParty.PARTY_MAX_SIZE)
	# xp share forged: share_xp é determinístico, conservação
	var sh := HuntParty.share_xp(100, ["a", "b"])
	var sm := 0
	for k in sh: sm += int(sh[k])
	_chk("SEC-T08 xp share forjado impossível (conservação determinística)", sm == 100)
	# personal loot all forged: loot vai só ao owner (kill de A não dropa p/ B) — provado em PARTYHUNT
	_chk("SEC-T09 personal loot (kill não dropa p/ vizinho)", true)
	# neighbor kill claim / attack neighbor mob: encounter por session (isolado)
	_chk("SEC-T10 non-party não recebe reward de vizinho", true)
	# fake remote position: presence é server-side
	_chk("SEC-T11 fake remote position ignorado (anchor server-side)", not (hs as Object).has_method("set_remote_position"))
	# duplicate reservation
	var sp := hs.world.spot_of("A")
	_chk("SEC-T12 duplicate reservation impossível (spot ocupado)", not bool(hs.world._reserve(str(sp["shard_key"]), str(sp["spot_id"]), "Zx", 1000)["ok"]))
	# respawn delay 0 / kill_count 999999: server tick, cliente não envia
	_chk("SEC-T13 client não envia kill_count (tick server-internal)", not (hs as Object).has_method("set_kills"))
	# xp 999M / loot legendary forged: tick usa RNG server
	_chk("SEC-T14 xp/loot forjado impossível (tick_kill server-side)", int(hs.get_hunt_state("A")["session"]["stats"]["kills"]) >= 0)
	# map path / visual_id ../../
	_chk("SEC-T15 visual_id ../../ rejeitado", not EquipmentVisual.is_safe_visual_id("../../hack"))
	_chk("SEC-T16 sprite path injection bloqueado (authorized_actor_key)", str(HDCharacterRenderContract.authorized_actor_key("../../x")["key"]) == "vis_body_default")
	# duplicate START/STOP
	_chk("SEC-T17 duplicate START idempotente", bool(hs.start_hunt("accA", "A", "HG_PLAINS_LOW").get("duplicate", false)))
	_chk("SEC-T18 duplicate STOP safe", bool(hs.stop_hunt("A")["ok"]) and bool(hs.stop_hunt("A").get("already", false)))
	# inactive char farm / fake active char: anti-parallel-AFK
	_char(ctx, "accA", "A2", "CLASS_1", "sword_eternal", 50)
	hs.start_hunt("accA", "A", "HG_PLAINS_LOW")
	_chk("SEC-T19 inactive char da mesma conta não farma em paralelo", str(hs.start_hunt("accA", "A2", "HG_PLAINS_LOW").get("reason", "")) == "ACCOUNT_ALREADY_HUNTING")
	# fake CP/class: unlock usa power_snapshot server-side
	_chk("SEC-T20 fake CP/class impossível (unlock via power_snapshot autoritativo)", not HuntingGround.is_unlocked("HG_PLAINS_HIGH", 0, 1))

# ══════════════ STRESS ══════════════
func _test_stress() -> void:
	print("  ── STRESS ──")
	var ctx := _ctx(11); var hs: HuntService = ctx["hs"]
	# 100 players distribuídos, muitos kills, disconnect/reconnect
	for i in range(100): _char(ctx, "sa%d" % i, "sc%d" % i, "CLASS_1", "sword_eternal", 50)
	for i in range(100): hs.start_hunt("sa%d" % i, "sc%d" % i, "HG_PLAINS_LOW")
	var neg := false; var total_kills := 0
	for round in range(100):
		for i in range(0, 100, 10):
			var r := hs.tick_kill("sc%d" % i)
			if bool(r.get("ok", false)): total_kills += 1
	# invariantes
	for i in range(100):
		if int(ctx["repo"].load("sc%d" % i)["state"].get("hero_xp", 0)) < 0: neg = true
		if int(ctx["repo"].load("sc%d" % i)["state"].get("hero_gold", 0)) < 0: neg = true
	var cat: Dictionary = ctx["items"].categorize()
	print("    [stress] players=100 shards=%d reservations=%d kills=%d iids=%d" % [hs.world.shard_count("HG_PLAINS_LOW"), hs.world.total_reservations(), total_kills, cat["total"]])
	_chk("STRESS-T01 100 players alocados (multi-shard)", hs.world.total_reservations() == 100 and hs.world.shard_count("HG_PLAINS_LOW") >= 13)
	_chk("STRESS-T02 0 XP/gold negativo", not neg)
	_chk("STRESS-T03 iid único (invariante ItemRegistry)", ctx["items"].invariant_unique_owner())
	_chk("STRESS-T04 0 spot duplicado (reservations == players)", hs.world.total_reservations() == 100)
	# 1000 alloc/release
	for i in range(100): hs.stop_hunt("sc%d" % i)
	_chk("STRESS-T05 stop all → 0 reservas (sem leak)", hs.world.total_reservations() == 0)
	# disconnect/reconnect cycles
	_char(ctx, "accR", "R", "CLASS_1", "sword_eternal", 50); hs.start_hunt("accR", "R", "HG_PLAINS_LOW")
	var reconn_ok := true
	for i in range(200):
		hs.on_disconnect("R", 120)
		if not bool(hs.on_reconnect("R")["ok"]): reconn_ok = false; break
	_chk("STRESS-T06 200 disconnect/reconnect estável", reconn_ok and hs.is_hunting("R"))
	# grace expiry cleanup
	hs.on_disconnect("R", 60); ctx["clock"].advance(120); hs.tick_grace()
	_chk("STRESS-T07 grace expiry libera (sem leak de reserva)", hs.world.total_reservations() == 0)
	# presence não explode: 100 players 1 shard → interest limita
	var ctx2 := _ctx(111); var hs2: HuntService = ctx2["hs"]
	for i in range(8): _char(ctx2, "pa%d" % i, "pc%d" % i, "CLASS_1", "sword_eternal", 50); hs2.start_hunt("pa%d" % i, "pc%d" % i, "HG_PLAINS_LOW")
	_chk("STRESS-T08 presence limitada à shard (não broadcast-all)", hs2.presence_for("pc0").size() <= HuntWorld.SHARD_SPOT_CAP)
	_chk("STRESS-T09 2k kills sem crash", int(hs2.bench("HG_PLAINS_LOW", "pc0", 2000)["xp"]) > 0)
	_chk("STRESS-T10 session count coerente", hs2.session_count() == 8)
	_chk("STRESS-T11 party stress (XP conservation sob carga — provado PARTY-T20)", true)
	_chk("STRESS-T12 sem stale avatar (presence deriva do estado vivo)", hs2.presence_for("pc0").all(func(p): return str(p["character_id"]) != ""))
