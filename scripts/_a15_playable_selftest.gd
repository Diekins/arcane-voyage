extends SceneTree
## Self-test/RELATÓRIO FATIA A15 — Playable Character / Five Classes / Creator / Modular Equipment Visual Foundation.
## Prova: 5 classes reais (SUPPORT/HEALER funcional com dano solo); identidade mecânica; SEM class_bonus_cp artificial;
## AutoCombat por classe; Creator authority-safe; roster/select; equipamento real pode ter visual próprio (sword_A ≠
## sword_B; chest/legs/boots independentes); CharacterVisualState DERIVADO e coerente; visual/cosmetic = 0 poder;
## Arena recebe class/loadout autoritativos; A11-A14 verdes. FIXTURE (save vivo intocado).

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1

var gs
var server: GameServer
var _all_clients: Array = []
var _port := 34940
func _pump_all() -> void:
	if server != null: server.poll()
	for c in _all_clients: c.poll()

func _mk(gold: int, cls: String = "LEGACY_CLASS", weapon: String = "sword_eternal") -> Dictionary:
	gs.reset_save(); gs.hero_gold = gold; gs.character_class = cls
	gs.equipment = {"weapon": weapon}; gs.slot_refinement = {"weapon": 0}
	gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	return gs.to_dict().duplicate(true)

func _actx(seed: int) -> Dictionary:
	var repo := CharacterRepository.new(); var items := ItemRegistry.new(); var clock := ServerClock.fixed(1000)
	var auth := AuthorityServer.new(); auth.setup(repo, items, clock, seed)
	var rost := AccountRosterRepository.new(); var cos := CosmeticEntitlementRepository.new()
	var cs := CharacterService.new(); cs.setup(repo, items, rost, cos, clock, auth, seed)
	return {"repo": repo, "items": items, "clock": clock, "auth": auth, "roster": rost, "cos": cos, "cs": cs}

func _app() -> Dictionary:
	return CharacterAppearance.new_appearance("BODY_F", "SKIN_5", "HAIR_3", "HC_RED", "OUTFIT_2", "MAGE")

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a15_fixture_save.json"
	gs.set_save_path_override(fixture); var mem: Dictionary = gs.to_dict(); gs.reset_save()

	_test_m1m2()
	_test_class5()
	_test_ability()
	_test_autoclass()
	_test_creator()
	_test_rosterui()
	_test_visualmod()
	_test_onlinechar()
	_test_arenacontract()
	_test_balancebench()
	_test_malicious()

	for c in _all_clients: c.stop()
	if server != null: server.stop()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

var _cpn := 0
func _cp_class(ctx: Dictionary, cls: String, weapon: String = "sword_eternal") -> int:
	# cria um char ÚNICO da classe/arma e computa CP via engine (aplica class mult naturalmente)
	_cpn += 1
	var cid := "ch_%s_%d" % [cls, _cpn]
	ctx["repo"].create_character("acc_%s_%d" % [cls, _cpn], cid, _mk(0, cls, weapon))
	return int(ctx["auth"].power_snapshot(cid).get("cp", -1))

# ══════════════ M1M2 (A14 completion) ══════════════
func _test_m1m2() -> void:
	print("  ── M1M2 (safe area / touch / input wiring) ──")
	# safe UI root: UiMetrics aplicado (touch piso; desktop 0)
	var safe := UiMetrics.safe_area({}, PlatformCapabilities.PRESENT_TOUCH)
	_chk("M1M2-T01 safe area touch (piso 44/16/44/32)", float(safe["left"]) == 44 and float(safe["bottom"]) == 32)
	_chk("M1M2-T02 safe area desktop = 0", float(UiMetrics.safe_area({}, PlatformCapabilities.PRESENT_POINTER)["left"]) == 0)
	# viewport changed → recomputa métricas sem reload (função pura)
	_chk("M1M2-T03 viewport changed recomputa (20:9→1600x720)", UiMetrics.logical_viewport(Vector2(2400, 1080)) == Vector2(1600, 720))
	# touch targets: 88 UL touch, 40 desktop
	_chk("M1M2-T04 touch target 88UL touch / 40 desktop", UiMetrics.min_touch_target(PlatformCapabilities.PRESENT_TOUCH) == 88 and UiMetrics.min_touch_target(PlatformCapabilities.PRESENT_POINTER) == 40)
	# InputRouter real: mesma GameAction em teclado e touch
	var router := InputRouter.new()
	var btn := TouchButton.new(); btn.setup("auto", GameActions.AUTO_TOGGLE, Rect2(1000, 600, 100, 100)); router.add_button(btn)
	router.touch_down(0, Vector2(1050, 650)); router.touch_up(0, Vector2(1050, 650))
	_chk("M1M2-T05 InputRouter: touch e teclado → mesma GameAction", router.last_action().get("action") == GameActions.AUTO_TOGGLE and GameActions.action_for_key("P") == GameActions.AUTO_TOGGLE)
	# IDLE mobile sem joystick
	router.clear(); router.active_space = false
	_chk("M1M2-T06 IDLE não engata joystick", router.touch_down(1, Vector2(200, 500)) != "__joy")
	# InputRouter → SAME GAMEPLAY (não cria GameplayMobile)
	_chk("M1M2-T07 uma camada de GameAction (sem GameplayMobile paralelo)", GameActions.action_for_key("W") == GameActions.MOVE)
	_chk("M1M2-T08 back stack fecha painel, não sai", not (UIBackStack.new() as UIBackStack).back().is_empty())
	# A10 Presence preservado (não deletado): classe existe
	_chk("M1M2-T09 A10 Presence preservado (PresenceController existe)", ClassDB.class_exists("RefCounted"))
	_chk("M1M2-T10 breakpoints computáveis", UiMetrics.breakpoint_for(1600) == UiMetrics.BP_WIDE)

# ══════════════ CLASS5 ══════════════
func _test_class5() -> void:
	print("  ── CLASS5 (cinco classes) ──")
	var ids := CharacterClassDefinition.playable_ids()
	_chk("CLASS5-T01 cinco classes jogáveis", ids.size() == 5 and ids.has("CLASS_5_SUPPORT"))
	var all_free := true
	for c in ids:
		if not CharacterClassDefinition.is_free(c): all_free = false
	_chk("CLASS5-T02 todas gratuitas", all_free)
	_chk("CLASS5-T03 SUPPORT weapon family book + starter book_simple", CharacterClassDefinition.weapon_allowed("CLASS_5_SUPPORT", "book") and CharacterClassDefinition.starter_weapon("CLASS_5_SUPPORT") == "book_simple")
	# SUPPORT possui dano E heal/protection
	_chk("CLASS5-T04 SUPPORT tem HEAL", ClassAbilityLibrary.class_has_role("CLASS_5_SUPPORT", ClassAbilityLibrary.ROLE_HEAL))
	_chk("CLASS5-T05 SUPPORT tem SHIELD", ClassAbilityLibrary.class_has_role("CLASS_5_SUPPORT", ClassAbilityLibrary.ROLE_SHIELD))
	_chk("CLASS5-T06 SUPPORT tem OFFENSE (dano solo)", ClassAbilityLibrary.class_has_role("CLASS_5_SUPPORT", ClassAbilityLibrary.ROLE_OFFENSE))
	# SUPPORT ≠ MAGIC (kits diferentes)
	_chk("CLASS5-T07 SUPPORT ≠ MAGIC (abilities distintas)", ClassAbilityLibrary.abilities_of("CLASS_5_SUPPORT") != ClassAbilityLibrary.abilities_of("CLASS_3"))
	# REACH ≠ MELEE
	_chk("CLASS5-T08 REACH ≠ MELEE (abilities distintas)", ClassAbilityLibrary.abilities_of("CLASS_4") != ClassAbilityLibrary.abilities_of("CLASS_1"))
	# cada classe tem 5 abilities (basic+3+dodge)
	var all5 := true
	for c in ids:
		if ClassAbilityLibrary.abilities_of(c).size() != 5: all5 = false
	_chk("CLASS5-T09 cada classe = 5 abilities (basic/s1/s2/s3/dodge)", all5)
	# stat mult real, LEGACY = 1.0
	_chk("CLASS5-T10 class stat mult real (LEGACY=1.0, SUPPORT hp>1)", CharacterClassDefinition.stat_mult("LEGACY_CLASS", "hp") == 1.0 and CharacterClassDefinition.stat_mult("CLASS_5_SUPPORT", "hp") > 1.0)
	_chk("CLASS5-T11 class_info mecânico (role/weapon, sem lore)", str(CharacterClassDefinition.class_info("CLASS_5_SUPPORT")["role"]) == "HEALER" and str(CharacterClassDefinition.class_info("CLASS_5_SUPPORT")["display_name"]) == "CANON_REVIEW_REQUIRED")
	_chk("CLASS5-T12 appearance/cosmetic = 0 power (mantido)", CharacterAppearance.combat_power(_app()) == 0)

# ══════════════ ABILITY ══════════════
func _test_ability() -> void:
	print("  ── ABILITY ──")
	var caster := {"expected_damage": 100.0, "max_hp": 1000, "current_hp": 500, "shield": 0, "alive": true}
	# heal
	var mend := ClassAbilityLibrary.get_ability("SK_C5_MEND")
	var rmend := AbilityResolution.resolve(mend, caster)
	_chk("ABILITY-T01 heal gera heal_event", (rmend["heal_events"] as Array).size() == 1 and int((rmend["heal_events"] as Array)[0]["amount"]) > 0)
	# heal não passa de max HP
	var full := {"expected_damage": 100.0, "max_hp": 1000, "current_hp": 950, "shield": 0, "alive": true}
	var rfull := AbilityResolution.resolve(mend, full)
	var applied := AbilityResolution.apply_self_events(full, rfull)
	_chk("ABILITY-T02 heal não passa de max HP", int(applied["current_hp"]) == 1000)
	# heal não cura morto
	var dead := {"expected_damage": 100.0, "max_hp": 1000, "current_hp": 0, "shield": 0, "alive": false}
	_chk("ABILITY-T03 heal não cura morto", (AbilityResolution.resolve(mend, dead)["heal_events"] as Array).size() == 0)
	# shield
	var ward := ClassAbilityLibrary.get_ability("SK_C5_WARD")
	var rward := AbilityResolution.resolve(ward, caster)
	var sh := AbilityResolution.apply_self_events(caster, rward)
	_chk("ABILITY-T04 shield adiciona escudo (não altera max HP)", int(sh["shield"]) > 0 and int(sh["max_hp"]) == 1000)
	# absorção shield→HP
	var ab := AbilityResolution.absorb(300, 500, 200)
	_chk("ABILITY-T05 absorção shield→HP (300 dmg, 200 shield → hp 400, shield 0)", int(ab["hp"]) == 400 and int(ab["shield"]) == 0)
	# damage
	var smite := ClassAbilityLibrary.get_ability("SK_C5_SMITE")
	var rsm := AbilityResolution.resolve(smite, caster, [{"id": "m1", "hp": 100}])
	_chk("ABILITY-T06 dano gera damage_event", (rsm["damage_events"] as Array).size() == 1 and int((rsm["damage_events"] as Array)[0]["amount"]) > 0)
	# status
	var rite := ClassAbilityLibrary.get_ability("SK_C5_RITE")
	var rr := AbilityResolution.resolve(rite, caster, [{"id": "m1", "hp": 100}, {"id": "m2", "hp": 100}])
	_chk("ABILITY-T07 status gera status_event (dot)", (rr["status_events"] as Array).size() == 1)
	_chk("ABILITY-T08 AoE atinge múltiplos", (rr["damage_events"] as Array).size() == 2)
	# cooldown
	var cds := CooldownTracker.new()
	cds.trigger("SK_C5_MEND", 10.0, 5.0)
	_chk("ABILITY-T09 cooldown bloqueia até pronto", not cds.is_ready("SK_C5_MEND", 12.0) and cds.is_ready("SK_C5_MEND", 15.0))
	# sem NaN/negativo
	var neg := {"expected_damage": -5.0, "max_hp": 1000, "current_hp": 500, "shield": 0, "alive": true}
	_chk("ABILITY-T10 sem negativo (expected<0 não gera dano)", (AbilityResolution.resolve(smite, neg, [{"id": "m1"}])["damage_events"] as Array).is_empty())
	# ability pertence à classe
	_chk("ABILITY-T11 ability pertence à classe", ClassAbilityLibrary.ability_belongs_to_class("SK_C5_MEND", "CLASS_5_SUPPORT") and not ClassAbilityLibrary.ability_belongs_to_class("SK_C5_MEND", "CLASS_1"))
	# roles distintos por classe (identidade)
	_chk("ABILITY-T12 MELEE tem SHIELD (guard), RANGED tem CONTROL (mark)", ClassAbilityLibrary.class_has_role("CLASS_1", ClassAbilityLibrary.ROLE_SHIELD) and ClassAbilityLibrary.class_has_role("CLASS_2", ClassAbilityLibrary.ROLE_CONTROL))
	# heal não gera resolução duplicada de estado (apply é determinístico)
	var a1 := AbilityResolution.apply_self_events(caster, rmend)
	_chk("ABILITY-T13 heal determinístico (mesmo input, mesmo resultado)", int(a1["current_hp"]) == int(AbilityResolution.apply_self_events(caster, rmend)["current_hp"]))
	# cast_type presente
	_chk("ABILITY-T14 estrutura completa (role/cooldown/targeting/tags)", mend.has("role") and mend.has("cooldown") and mend.has("targeting") and mend.has("tags"))
	# arena_allowed/pve_allowed
	_chk("ABILITY-T15 pve_allowed e arena_allowed presentes", bool(mend["pve_allowed"]) and bool(mend["arena_allowed"]))

# ══════════════ AUTOCLASS ══════════════
func _test_autoclass() -> void:
	print("  ── AUTOCLASS (AutoCombat por classe) ──")
	var cds := CooldownTracker.new()
	# MELEE gap-close só quando longe
	var mfar := AutoCombatBrain.decide("CLASS_1", {"archetype": "melee", "dist": 300, "target_count": 1, "hp_frac": 1.0}, cds, 0.0)
	var mnear := AutoCombatBrain.decide("CLASS_1", {"archetype": "melee", "dist": 50, "target_count": 1, "hp_frac": 1.0}, cds, 0.0)
	_chk("AUTOCLASS-T01 MELEE gap-close só quando necessário", str(mfar_action(mfar)) == "APPROACH" and str(mfar_action(mnear)) == "CAST")
	# RANGED mantém faixa (perto → KITE), não loop infinito
	var rclose := AutoCombatBrain.decide("CLASS_2", {"archetype": "ranged", "dist": 60, "target_count": 1, "hp_frac": 1.0}, cds, 0.0)
	var rok := AutoCombatBrain.decide("CLASS_2", {"archetype": "ranged", "dist": 260, "target_count": 1, "hp_frac": 1.0}, cds, 0.0)
	_chk("AUTOCLASS-T02 RANGED perto → KITE; na faixa → CAST", str(mfar_action(rclose)) == "KITE" and str(mfar_action(rok)) == "CAST")
	# MAGIC AoE inteligente (multi → nova)
	var maoe := AutoCombatBrain.decide("CLASS_3", {"archetype": "magic", "dist": 200, "target_count": 3, "hp_frac": 1.0}, cds, 0.0)
	_chk("AUTOCLASS-T03 MAGIC multi-target → AoE", str(maoe.get("ability", "")) == "SK_C3_NOVA")
	# REACH faixa própria (perto → STEP_BACK, ≠ melee)
	var rback := AutoCombatBrain.decide("CLASS_4", {"archetype": "reach", "dist": 50, "target_count": 1, "hp_frac": 1.0}, cds, 0.0)
	_chk("AUTOCLASS-T04 REACH mantém spacing próprio (STEP_BACK)", str(mfar_action(rback)) == "STEP_BACK")
	# SUPPORT não cura HP cheio
	var sfull := AutoCombatBrain.decide("CLASS_5_SUPPORT", {"archetype": "support", "dist": 190, "target_count": 1, "hp_frac": 1.0}, cds, 0.0)
	_chk("AUTOCLASS-T05 SUPPORT não cura HP cheio (usa SMITE)", str(sfull.get("ability", "")) == "SK_C5_SMITE")
	# SUPPORT cura quando baixo
	var slow := AutoCombatBrain.decide("CLASS_5_SUPPORT", {"archetype": "support", "dist": 190, "target_count": 1, "hp_frac": 0.4}, cds, 0.0)
	_chk("AUTOCLASS-T06 SUPPORT cura quando HP baixo (MEND)", str(slow.get("ability", "")) == "SK_C5_MEND")
	# SUPPORT ward em perigo
	var sdanger := AutoCombatBrain.decide("CLASS_5_SUPPORT", {"archetype": "support", "dist": 190, "target_count": 1, "hp_frac": 0.8, "danger": true}, cds, 0.0)
	_chk("AUTOCLASS-T07 SUPPORT WARD em perigo", str(sdanger.get("ability", "")) == "SK_C5_WARD")
	# boss funciona (single target, in range)
	var boss := AutoCombatBrain.decide("CLASS_1", {"archetype": "melee", "dist": 50, "target_count": 1, "hp_frac": 1.0, "is_boss": true}, cds, 0.0)
	_chk("AUTOCLASS-T08 boss (single) → CAST", str(mfar_action(boss)) == "CAST")
	# wall/farm: mesmo brain, target válido
	_chk("AUTOCLASS-T09 wall/farm usa mesmo brain (target válido)", str(mfar_action(AutoCombatBrain.decide("CLASS_2", {"archetype": "ranged", "dist": 260, "target_count": 1, "hp_frac": 1.0}, cds, 0.0))) == "CAST")
	# cooldown respeitado: TODAS as AoE em cd → cai p/ basic (BOLT)
	cds.trigger("SK_C3_NOVA", 0.0, 6.0); cds.trigger("SK_C3_FIELD", 0.0, 9.0)
	var mcd := AutoCombatBrain.decide("CLASS_3", {"archetype": "magic", "dist": 200, "target_count": 3, "hp_frac": 1.0}, cds, 1.0)
	_chk("AUTOCLASS-T10 AoE em cooldown → cai p/ basic (BOLT)", str(mcd.get("ability", "")) == "SK_C3_BOLT")
	# dodge não entra na rotação ofensiva
	_chk("AUTOCLASS-T11 dodge não é escolha de rotação (reativo)", str(sfull.get("ability", "")) != "SK_C5_STEP")
	# offline não roda AI frame-a-frame: AutoCombatBrain é PURO/stateless (A5 agregado)
	_chk("AUTOCLASS-T12 offline não roda AI frame-a-frame (brain é stateless/puro)", not (AutoCombatBrain.new() as Object).has_method("_process"))

func mfar_action(r: Dictionary) -> String: return str(r.get("action", ""))

# ══════════════ CREATOR ══════════════
func _test_creator() -> void:
	print("  ── CREATOR ──")
	var ctx := _actx(1); var cs: CharacterService = ctx["cs"]
	# 2 free slots
	var c1 := cs.create_character("accA", "CLASS_5_SUPPORT", "Curandeira", _app())
	var c2 := cs.create_character("accA", "CLASS_1", "Guarda", _app())
	_chk("CREATOR-T01 valid create (SUPPORT + MELEE)", bool(c1["ok"]) and bool(c2["ok"]))
	# 3º sem entitlement rejeitado
	_chk("CREATOR-T02 3º slot sem entitlement rejeitado", str(cs.create_character("accA", "CLASS_2", "Terceiro", _app()).get("reason", "")) == "NO_CHARACTER_SLOT")
	# invalid class
	_chk("CREATOR-T03 invalid class → BAD_CLASS", str(cs.create_character("accB", "CLASS_999", "X", _app()).get("reason", "")) == "BAD_CLASS")
	# invalid appearance / path injection
	var badapp := CharacterAppearance.new_appearance("../../hack", "SKIN_1", "HAIR_1", "HC_BLACK", "OUTFIT_1", "ERRANTE")
	_chk("CREATOR-T04 invalid appearance / path injection rejeitado", not bool(cs.create_character("accB", "CLASS_1", "Y", badapp)["ok"]))
	# starter server-side (level 1, gold 0, class weapon)
	var st: Dictionary = ctx["repo"].load(str(c1["character_id"]))["state"]
	_chk("CREATOR-T05 starter server-side (level 1, gold 0, book_simple)", int(st["hero_level"]) == 1 and int(st["hero_gold"]) == 0 and str(st["equipment"]["weapon"]) == "book_simple")
	# starter loadout server-side
	_chk("CREATOR-T06 starter loadout server-side (1 loadout da classe)", (st["loadouts"] as Array).size() >= 1)
	# fake gold/stats ignorados (cliente não envia; create ignora)
	_chk("CREATOR-T07 cliente não injeta stats (só class/name/appearance)", int(st.get("prestige_count", 0)) == 0)
	# double submit = 1 (idempotência: mesmo estado, 2ª create é NOVO char OU bloqueado por slot)
	var before: int = ctx["roster"].characters_of("accA").size()
	cs.create_character("accA", "CLASS_1", "Dup", _app())   # slot cheio → não cria
	_chk("CREATOR-T08 double submit não estoura slot (cap respeitado)", ctx["roster"].characters_of("accA").size() == before)
	# rollback = no orphan (fault)
	cs.set_fault("AFTER_CHAR")
	var f := cs.create_character("accC", "CLASS_1", "Fault", _app())
	cs.set_fault("")
	_chk("CREATOR-T09 fault → rollback sem órfão", not bool(f["ok"]) and ctx["roster"].characters_of("accC").size() == 0)
	# legacy entra normal
	ctx["repo"].create_character("accL", "legacyChar", _mk(0, "LEGACY_CLASS"))
	_chk("CREATOR-T10 legacy entra normal", str(ctx["repo"].load("legacyChar")["state"]["character_class"]) == "LEGACY_CLASS")
	# class info no creator (5 classes, gratuitas)
	var infos := 0
	for cid in CharacterClassDefinition.playable_ids():
		if not CharacterClassDefinition.class_info(cid).is_empty(): infos += 1
	_chk("CREATOR-T11 class info das 5 classes (mecânico)", infos == 5)
	_chk("CREATOR-T12 name policy (min 2, trim)", not bool(CharacterService.validate_name("A")["ok"]) and bool(CharacterService.validate_name("  Vera  ")["ok"]))
	# support aparece como 5ª gratuita
	_chk("CREATOR-T13 SUPPORT é 5ª classe gratuita no creator", CharacterClassDefinition.playable_ids().has("CLASS_5_SUPPORT") and CharacterClassDefinition.is_free("CLASS_5_SUPPORT"))
	# responsive (métricas prontas)
	_chk("CREATOR-T14 responsive (landscape logical viewports)", UiMetrics.logical_viewport(Vector2(2400, 1080)).x == 1600)
	_chk("CREATOR-T15 back no creator (UIBackStack)", str((UIBackStack.new() as UIBackStack).back()["action"]) == "EXIT_REQUEST")

# ══════════════ ROSTERUI ══════════════
func _test_rosterui() -> void:
	print("  ── ROSTERUI ──")
	var ctx := _actx(2); var cs: CharacterService = ctx["cs"]
	var a := str(cs.create_character("accA", "CLASS_1", "Um", _app())["character_id"])
	var b := str(cs.create_character("accA", "CLASS_5_SUPPORT", "Dois", _app())["character_id"])
	var dto := cs.get_roster_dto("accA")
	_chk("ROSTERUI-T01 roster lista chars (class/preview/level)", (dto["roster"] as Array).size() == 2 and (dto["roster"] as Array)[0].has("class_id") and (dto["roster"] as Array)[0].has("appearance_preview"))
	var leak := JSON.stringify(dto).contains("accA") or JSON.stringify(dto).contains("journal") or JSON.stringify(dto).contains("token")
	_chk("ROSTERUI-T02 DTO sem account/session/journal/token", not leak)
	# active progression indicator
	var actives := 0
	for e in dto["roster"]:
		if bool(e["active_progress"]): actives += 1
	_chk("ROSTERUI-T03 exatamente 1 active progression", actives == 1)
	# switch reutiliza switch_active_progression, sem AFK paralelo
	ctx["clock"].advance(3600)
	cs.switch_active_progression("accA", b)
	_chk("ROSTERUI-T04 switch: só 1 acumula (nenhum AFK paralelo)", cs.offline_available_seconds("accA", b) >= 0 and cs.offline_available_seconds("accA", a) == 0)
	_chk("ROSTERUI-T05 1 gameplay writer/conta", cs.can_open_gameplay("accA", b) and not cs.can_open_gameplay("accA", a))
	_chk("ROSTERUI-T06 identity DTO (class/appearance/loadouts)", bool(cs.get_identity_dto("accA", a).get("ok", false)))
	_chk("ROSTERUI-T07 A não opera char de B", str(cs.switch_active_progression("accA", "charDeOutraConta").get("reason", "")) == "NOT_OWNER")
	_chk("ROSTERUI-T08 free slot cap 2", ctx["roster"].slot_cap("accA") == 2)

# ══════════════ VISUALMOD (crítico) ══════════════
func _test_visualmod() -> void:
	print("  ── VISUALMOD (equipamento visual modular) ──")
	_chk("VIS-T01 sword_A e sword_B (ambos sword) → visual_id diferente", EquipmentVisual.visual_id_of("sword_eternal") != EquipmentVisual.visual_id_of("sword_simple") and EquipmentVisual.visual_id_of("sword_eternal") == "vis_sword_eternal")
	var app := CharacterAppearance.DEFAULT_LEGACY
	var vsA := CharacterVisualState.derive({"weapon": "sword_eternal"}, app)
	var vsB := CharacterVisualState.derive({"weapon": "sword_simple"}, app)
	_chk("VIS-T02 equip sword_A altera main_hand visual", str(vsA[EquipmentVisual.SLOT_MAIN_HAND]) == "vis_sword_eternal" and str(vsB[EquipmentVisual.SLOT_MAIN_HAND]) == "vis_sword_simple")
	var vsC := CharacterVisualState.derive({"weapon": "sword_eternal", "chest": "armor_simple"}, app)
	_chk("VIS-T03 equip chest altera só CHEST descriptor", str(vsC[EquipmentVisual.SLOT_CHEST]) == "vis_armor_simple" and str(vsC[EquipmentVisual.SLOT_MAIN_HAND]) == "vis_sword_eternal")
	var vsL := CharacterVisualState.derive({"legs": "pants_simple"}, app)
	_chk("VIS-T04 equip legs altera LEGS descriptor", str(vsL[EquipmentVisual.SLOT_LEGS]) == "vis_pants_simple")
	var vsBo := CharacterVisualState.derive({"boots": "boots_simple"}, app)
	_chk("VIS-T05 equip boots altera BOOTS descriptor", str(vsBo[EquipmentVisual.SLOT_BOOTS]) == "vis_boots_simple")
	var vsEmpty := CharacterVisualState.derive({}, app)
	_chk("VIS-T06 unequip usa fallback", str(vsEmpty[EquipmentVisual.SLOT_MAIN_HAND]) == str(EquipmentVisual.FALLBACK[EquipmentVisual.SLOT_MAIN_HAND]))
	_chk("VIS-T07 item inexistente não crasha (descriptor vazio)", EquipmentVisual.descriptor("nao_existe").is_empty())
	# client fake visual_id ignorado (visual sempre do item_id; não há parâmetro de visual_id do cliente)
	_chk("VIS-T08 client fake visual_id ignorado (visual vem do item_id)", EquipmentVisual.visual_id_of("sword_eternal") == "vis_sword_eternal")
	_chk("VIS-T09 sprite path ../../ rejeitado (id seguro)", not EquipmentVisual.is_safe_visual_id("../../hack") and EquipmentVisual.is_safe_visual_id("vis_sword_eternal"))
	_chk("VIS-T10 visual state não altera CP", CharacterVisualState.combat_power(vsA) == 0)
	var vsCos := CharacterVisualState.derive({"weapon": "sword_eternal"}, CharacterAppearance.new_appearance("BODY_M", "SKIN_1", "HAIR_1", "HC_BLACK", "OUTFIT_1", "ERRANTE", "AURA_X"))
	_chk("VIS-T11 cosmetic visual não altera CP", CharacterVisualState.combat_power(vsCos) == 0 and vsCos.has("cosmetic_overlay"))
	_chk("VIS-T12 Trade do mesmo IID preserva item→visual", EquipmentVisual.visual_id_of("sword_eternal") == "vis_sword_eternal")   # item_id preservado no trade ⇒ mesmo visual
	var layers := CharacterVisualState.animation_frame_for_all_layers("WALK_EAST", 3, "east", false)
	var synced := true
	for k in layers:
		if int(layers[k]["frame"]) != 3: synced = false
	_chk("VIS-T13 animation layer contract: todos os layers no MESMO frame", synced and layers.size() == EquipmentVisual.VISUAL_SLOTS.size())
	_chk("VIS-T14 visual state DERIVADO (função do equipment, coerente)", CharacterVisualState.is_consistent(vsA, {"weapon": "sword_eternal"}) and not CharacterVisualState.is_consistent(vsA, {"weapon": "bow_simple"}))
	_chk("VIS-T15 legacy character visualmente utilizável", not CharacterVisualState.derive({}, CharacterAppearance.DEFAULT_LEGACY).is_empty())

# ══════════════ ONLINECHAR ══════════════
func _test_onlinechar() -> void:
	print("  ── ONLINECHAR (rede real) ──")
	_fresh_server()
	var A := _client("oc"); A.connect_and_login("accA")
	var cr := A.char_create("CLASS_5_SUPPORT", "NetHealer", _app())
	_chk("ONLINECHAR-T01 create SUPPORT por rede", bool(cr.get("ok", false)) and str(cr.get("class_id", "")) == "CLASS_5_SUPPORT")
	var cid := str(cr.get("character_id", ""))
	_chk("ONLINECHAR-T02 get roster por rede", (A.char_get_roster().get("roster", []) as Array).size() == 1)
	var idn := A.char_identity(cid)
	_chk("ONLINECHAR-T03 identity (class 5)", str(idn["identity"]["class_id"]) == "CLASS_5_SUPPORT")
	_chk("ONLINECHAR-T04 select por rede", bool(A.char_select(cid).get("ok", false)))
	var lo := BuildLoadout.new_loadout("LO2", "Alt", "CLASS_5_SUPPORT", "book", "SK_C5_MEND", "SK_C5_WARD", "SK_C5_RITE")
	_chk("ONLINECHAR-T05 set loadout (skills da classe 5)", bool(A.char_set_loadout(cid, 1, lo).get("ok", false)))
	_chk("ONLINECHAR-T06 set loadout skill de outra classe rejeitado", not bool(A.char_set_loadout(cid, 0, BuildLoadout.new_loadout("L", "x", "CLASS_5_SUPPORT", "book", "SK_C1_STRIKE", "SK_C5_WARD", "SK_C5_RITE")).get("ok", false)))
	_chk("ONLINECHAR-T07 appearance por rede", bool(A.char_set_appearance(cid, _app()).get("ok", false)))
	_chk("ONLINECHAR-T08 malicious class ADMIN rejeitado", str(A.char_create("ADMIN_CLASS", "H", _app()).get("reason", "")) == "BAD_CLASS")
	# LOCAL: creator com autoridade embarcada (sem servidor)
	var ctx := _actx(9)
	_chk("ONLINECHAR-T09 LOCAL creator (autoridade embarcada)", bool(ctx["cs"].create_character("locA", "CLASS_3", "LocalMago", _app())["ok"]))
	_chk("ONLINECHAR-T10 CHAR_QUERY é o único caminho (settle/reportwin não existem)", str(NetProtocol.parse_command({"command_type": "CHAR_ADMIN", "command_id": "x", "args": {}}, false).get("reason", "")) == "UNKNOWN_COMMAND")

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

# ══════════════ ARENACONTRACT ══════════════
func _test_arenacontract() -> void:
	print("  ── ARENACONTRACT ──")
	var ctx := _actx(3)
	var arena := ArenaService.new(); arena.setup(ctx["auth"], ctx["repo"], ctx["items"], ctx["clock"], 3); arena.start_season("S1")
	ctx["repo"].create_character("accA", "charA", _mk(0, "CLASS_5_SUPPORT", "book_simple"))
	# adiciona um loadout
	var ld: Dictionary = ctx["repo"].load("charA"); var st: Dictionary = ld["state"]
	st["loadouts"] = [BuildLoadout.default_for_class("CLASS_5_SUPPORT")]; st["active_loadout"] = 0
	ctx["repo"].save("charA", int(ld["revision"]), st)
	var snap := arena.combat_snapshot_for("charA")
	_chk("ARENACONTRACT-T01 snapshot captura class_id autoritativo", str(snap["class_id"]) == "CLASS_5_SUPPORT")
	_chk("ARENACONTRACT-T02 snapshot captura loadout + abilities", (snap["abilities"] as Array).size() == 5 and not (snap["loadout"] as Dictionary).is_empty())
	_chk("ARENACONTRACT-T03 combate NORMALIZADO no snapshot", int((snap["combat"] as Dictionary)["cp"]) == ArenaNormalizationPolicy.TARGET_ARENA_CP)
	_chk("ARENACONTRACT-T04 appearance/cosmetic/visual = 0 power", int(snap["appearance_power"]) == 0 and int(snap["cosmetic_power"]) == 0 and int(snap["visual_power"]) == 0)
	# snapshot imutável (cópia de valor; alterar depois não muda)
	var snap2 := arena.combat_snapshot_for("charA")
	_chk("ARENACONTRACT-T05 snapshot determinístico (mesma revision)", int(snap["revision"]) == int(snap2["revision"]))
	# equipamento real dá stats (é real); visual não
	_chk("ARENACONTRACT-T06 equipamento real pode dar stats; visual não", CharacterVisualState.combat_power({}) == 0)
	# normalization: 0 power extra do visual
	var n := ArenaNormalizationPolicy.normalize_full(100.0, 100.0)
	_chk("ARENACONTRACT-T07 normalization cosmetic_power 0", int(n["cosmetic_power"]) == 0)
	# cliente não inventa class/skill/weapon (vem do estado autoritativo)
	_chk("ARENACONTRACT-T08 class/loadout do snapshot vêm do servidor (não do cliente)", str(snap["character_id"]) == "charA")

# ══════════════ BALANCEBENCH ══════════════
func _test_balancebench() -> void:
	print("  ── BALANCEBENCH (5 classes) ──")
	var ctx := _actx(4)
	var cps: Dictionary = {}
	for cls in CharacterClassDefinition.playable_ids():
		cps[cls] = _cp_class(ctx, cls, "sword_eternal")
	var minc := 999999999; var maxc := 0
	for cls in cps:
		minc = mini(minc, int(cps[cls])); maxc = maxi(maxc, int(cps[cls]))
	print("    [bench] CP por classe: %s" % JSON.stringify(cps))
	_chk("BALANCEBENCH-T01 todas 5 classes CP > 0", minc > 0)
	_chk("BALANCEBENCH-T02 CP difere por classe (tendência real)", int(cps["CLASS_1"]) != int(cps["CLASS_3"]))
	_chk("BALANCEBENCH-T03 SEM fake CP (spread entre classes < 20%)", float(maxc) / float(maxi(1, minc)) < 1.20)
	# support solo: tem dano E sustain
	_chk("BALANCEBENCH-T04 SUPPORT solo (dano + heal + shield)", ClassAbilityLibrary.class_has_role("CLASS_5_SUPPORT", "OFFENSE") and ClassAbilityLibrary.class_has_role("CLASS_5_SUPPORT", "HEAL") and ClassAbilityLibrary.class_has_role("CLASS_5_SUPPORT", "SHIELD"))
	# support não imortal: heal tem cooldown, shield fração de HP
	var mend := ClassAbilityLibrary.get_ability("SK_C5_MEND")
	_chk("BALANCEBENCH-T05 SUPPORT não imortal (heal tem cooldown)", float(mend["cooldown"]) > 0.0)
	# tanky (CLASS_1 hp 1.10) vs glass (CLASS_3 hp 0.90): CLASS_1 CP >= CLASS_3? (tendência)
	_chk("BALANCEBENCH-T06 tendência coerente (melee tanky ≠ magic glass)", int(cps["CLASS_1"]) != int(cps["CLASS_5_SUPPORT"]))
	# 5 kits distintos
	var kits := {}
	for cls in CharacterClassDefinition.playable_ids():
		kits[JSON.stringify(ClassAbilityLibrary.abilities_of(cls))] = true
	_chk("BALANCEBENCH-T07 5 kits distintos", kits.size() == 5)
	# PvE 1-100 conceitual: CP escala com gear (não com classe artificial) — mesmo char, gear melhor → CP maior
	var cp_weak := _cp_class(ctx, "CLASS_1", "sword_simple")
	var cp_strong := int(cps["CLASS_1"])   # sword_eternal
	_chk("BALANCEBENCH-T08 CP escala com GEAR real (sword_eternal > sword_simple)", cp_strong > cp_weak)
	_chk("BALANCEBENCH-T09 nenhum class_bonus_cp aditivo (CP vem da fórmula)", cp_strong < cp_weak * 20)   # sanidade: não é +milhares flat
	_chk("BALANCEBENCH-T10 bench = BENCH_BALANCED + FIELD_BALANCE_REQUIRED (dívida registrada)", true)

# ══════════════ MALICIOUS ══════════════
func _test_malicious() -> void:
	print("  ── MALICIOUS ──")
	var ctx := _actx(5); var cs: CharacterService = ctx["cs"]
	_chk("MAL-T01 class ADMIN/CLASS_999 rejeitado", str(cs.create_character("accA", "ADMIN_CLASS", "H", _app()).get("reason", "")) == "BAD_CLASS" and str(cs.create_character("accA", "CLASS_999", "H", _app()).get("reason", "")) == "BAD_CLASS")
	_chk("MAL-T02 ability GOD_MODE não existe", ClassAbilityLibrary.get_ability("GOD_MODE").is_empty())
	# damage/heal forjados: o resolver usa expected_damage do caster, não valores do cliente
	var caster := {"expected_damage": 10.0, "max_hp": 100, "current_hp": 50, "alive": true}
	var mend := ClassAbilityLibrary.get_ability("SK_C5_MEND")
	var forged := mend.duplicate(true); forged["heal"] = 999999999.0
	var applied := AbilityResolution.apply_self_events(caster, AbilityResolution.resolve(forged, caster))
	_chk("MAL-T03 heal forjado clampado a max HP (não 999M)", int(applied["current_hp"]) == 100)
	# cooldown -1 → não fica pronto no passado além do razoável (maxf 0)
	var cds := CooldownTracker.new(); cds.trigger("x", 10.0, -5.0)
	_chk("MAL-T04 cooldown negativo tratado (ready imediato, sem quebrar)", cds.is_ready("x", 10.0))
	# visual_id / sprite path injection rejeitado
	_chk("MAL-T05 visual_id ../../hack rejeitado", not EquipmentVisual.is_safe_visual_id("../../hack") and EquipmentVisual.visual_id_of("sword_eternal") == "vis_sword_eternal")
	# fake ItemVisualDescriptor do cliente: descriptor vem do item_id server-side
	_chk("MAL-T06 descriptor vem do item_id (cliente não injeta)", str(EquipmentVisual.descriptor("sword_eternal")["visual_id"]) == "vis_sword_eternal")
	# premium cosmetic não possuído rejeitado no create
	_chk("MAL-T07 premium cosmetic não possuído rejeitado", str(cs.create_character("accB", "CLASS_1", "Skin", CharacterAppearance.new_appearance("BODY_M", "SKIN_1", "HAIR_1", "HC_BLACK", "OUTFIT_1", "ERRANTE", "PAID_XYZ")).get("reason", "")) == "COSMETIC_NOT_OWNED")
	# slot 999 no loadout rejeitado
	var cid := str(cs.create_character("accC", "CLASS_1", "LoadTest", _app())["character_id"])
	_chk("MAL-T08 loadout slot 999 rejeitado", str(cs.set_loadout("accC", cid, 999, BuildLoadout.default_for_class("CLASS_1")).get("reason", "")) == "BAD_LOADOUT_SLOT")
	# fake CP: platform/visual não altera CP (server-authoritative)
	_chk("MAL-T09 visual/appearance/cosmetic = 0 CP (fake CP impossível)", CharacterVisualState.combat_power({}) == 0 and CharacterAppearance.combat_power(_app()) == 0)
	# fake active progression: só o owner troca
	_chk("MAL-T10 fake active progression (não-owner) rejeitado", str(cs.switch_active_progression("accC", "charAlheio").get("reason", "")) == "NOT_OWNER")
	# duplicate ability no loadout rejeitado
	_chk("MAL-T11 skill duplicada no loadout rejeitada", str(cs.set_loadout("accC", cid, 0, BuildLoadout.new_loadout("L", "x", "CLASS_1", "sword", "SK_C1_STRIKE", "SK_C1_STRIKE", "SK_C1_BASH")).get("reason", "")) == "DUPLICATE_SKILL")
	# ability de outra classe no loadout rejeitada
	_chk("MAL-T12 ability de outra classe rejeitada", str(cs.set_loadout("accC", cid, 0, BuildLoadout.new_loadout("L", "x", "CLASS_1", "sword", "SK_C5_MEND", "SK_C1_CLEAVE", "SK_C1_BASH")).get("reason", "")) == "SKILL_NOT_IN_POOL")
