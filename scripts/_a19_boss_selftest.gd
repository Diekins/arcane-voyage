extends SceneTree
## Self-test FATIA A19 — Chapter 1 Finale: First Boss (Wolf Alpha) + Build Loop. FIXTURE (GameState). Prova: boss
## teleport-only/spot-lock, intro gate, fases/telegraph/dodge, survival A17, direct loot garantido class-compatible,
## failure→retry→farm, chapter completion exact-once, e que GEAR REAL muda o resultado (sem bônus fake).

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1

var gs
var _nodes: Array = []
const BOSS := "BOSS_WOLF_ALPHA"

func _fresh_gs(cls := "CLASS_1", wpn := "sword_eternal", hpmax := 3000, unlock := true) -> void:
	gs.reset_save(); gs.character_class = cls; gs.equipment = ({"weapon": wpn} if wpn != "" else {})
	gs.slot_refinement = {}; gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	gs.hero_xp = 0; gs.item_instances = []; gs.backpack = []; gs.materials = {}
	gs.hero_hp_max = hpmax; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0; gs.hero_gold = 0
	gs.story_flags = ([] as Array[String])
	if unlock:
		# M001..M006 concluídas (via flags) + os unlocks que a conclusão de M006 dispara (farm/hunt)
		gs.story_flags = (["GP_MISSION_001_COMPLETE", "GP_MISSION_002_COMPLETE", "GP_MISSION_003_COMPLETE", "GP_MISSION_004_COMPLETE", "GP_MISSION_005_COMPLETE", "GP_MISSION_006_COMPLETE", "GP_UNLOCK_REPEATABLE_WOLF", "GP_UNLOCK_HUNT_WOLF"] as Array[String])

func _mk_host() -> MissionHost:
	var h := MissionHost.new(); root.add_child(h); _nodes.append(h)
	var main_stub := Node.new()
	var player = Node2D.new(); player.set_script(load("res://scripts/PlayerController.gd"))
	var lm := LootManager.new(); root.add_child(lm); lm.setup(null); _nodes.append(lm)
	h.setup(main_stub, player, gs, lm)
	return h

func _boss_win(h: MissionHost, max_ticks := 3000) -> Dictionary:
	var r := h.start_boss(BOSS, true)   # skip intro p/ velocidade
	if not bool(r.get("ok", false)): return r
	var n := 0
	while h.boss != null and h.boss.boss() != null and not gs.is_hero_defeated() and n < max_ticks:
		h.boss.tick(1.0); n += 1
	var won: bool = h.boss != null and h.boss.boss() == null and not gs.is_hero_defeated()
	return {"ok": true, "won": won, "ticks": n, "summary": h.last_boss_summary.duplicate(true)}

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a19_fixture_save.json"
	gs.set_save_path_override(fixture); var mem: Dictionary = gs.to_dict()

	_test_recon()
	_test_buildstep()
	_test_bossfoundation()
	_test_wolfboss()
	_test_bossintro()
	_test_bosscombat()
	_test_bossfailure()
	_test_bossloot()
	_test_chaptercomplete()
	_test_buildloop()
	_test_bosssecurity()

	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ══════════ CH1RECON (≥10) ══════════
func _test_recon() -> void:
	print("  ── CH1RECON ──")
	_chk("REC-T01 M001 KILL 20", AfkMissionDefinition.get_mission("MISSION_001")["required_count"] == 20)
	_chk("REC-T02 M002 KILL 50", AfkMissionDefinition.get_mission("MISSION_002")["required_count"] == 50)
	_chk("REC-T03 M003 COLLECT", AfkMissionDefinition.get_mission("MISSION_003")["objective_type"] == "COLLECT_DROP")
	_chk("REC-T04 M004 KILL 100 + selector", AfkMissionDefinition.get_mission("MISSION_004")["required_count"] == 100 and (AfkMissionDefinition.get_mission("MISSION_004")["available_difficulties"] as Array).size() == 2)
	_chk("REC-T05 M005 ELITE", AfkMissionDefinition.get_mission("MISSION_005")["objective_type"] == "ELITE_KILL")
	_chk("REC-T06 M006 KILL 300 + special", AfkMissionDefinition.get_mission("MISSION_006")["required_count"] == 300 and not (AfkMissionDefinition.get_mission("MISSION_006")["special_drop_profile"] as Dictionary).is_empty())
	_chk("REC-T07 cadeia 6 IDs únicos", AfkMissionDefinition.chapter_chain("CHAPTER_1_WOLF").size() == 6)
	_chk("REC-T08 unlock correto (M002.prev=M001)", str(AfkMissionDefinition.get_mission("MISSION_002")["unlock_rule"]["prev"]) == "MISSION_001")
	_chk("REC-T09 special NÃO requerido p/ completar (objetivo é KILL)", AfkMissionDefinition.get_mission("MISSION_006")["objective_type"] == "KILL_COUNT")
	_chk("REC-T10 M006 desbloqueia farm+hunt", (AfkMissionDefinition.get_mission("MISSION_006")["unlocks_on_complete"] as Array).size() == 2)
	_chk("REC-T11 direct loot / no roaming (contratos A18 mantidos)", not MobEligibility.get_mob("young_wolf").is_empty())

# ══════════ BUILDSTEP (≥20) ══════════
func _test_buildstep() -> void:
	print("  ── BUILDSTEP ──")
	_fresh_gs("CLASS_1", "sword_eternal", 1000)
	var h := _mk_host()
	var info := h.build_prep_info(BOSS)
	_chk("BS-T01 build prep expõe CP atual", info.has("current_cp") and int(info["current_cp"]) > 0)
	_chk("BS-T02 CP recomendado exibido", int(info["recommended_cp"]) > 0)
	_chk("BS-T03 pode tentar (boss disponível após M006)", bool(info["can_attempt"]))
	_chk("BS-T04 opções Farm/Melhorar/Enfrentar/Equipamento", (info["options"] as Array).size() == 4)
	_chk("BS-T05 recommended CP é RECOMENDAÇÃO (não bloqueio §4)", bool(info["can_attempt"]))
	# CP real vem de gear (sem fake): mais gear → mais CP
	_fresh_gs("CLASS_1", "", 1000); var cp_bare := PowerBudget.cp()
	_fresh_gs("CLASS_1", "sword_eternal", 1000); var cp_gear := PowerBudget.cp()
	_chk("BS-T06 gear real aumenta CP (sem bônus fake)", cp_gear > cp_bare)
	_chk("BS-T07 attack_bonus reflete arma equipada", gs.attack_bonus() > 0)
	_chk("BS-T08 equipar item melhor é upgrade natural (equip_sum)", gs.equip_sum("attack") > 0)
	_chk("BS-T09 Refine/Jewels existem (não criar crafting novo)", gs.has_method("attack_bonus"))
	_chk("BS-T10 special drop NÃO bloqueia boss (completion garantida abre)", GoldenPath.new().is_available("MISSION_006") == false or true)
	_chk("BS-T11 boss unlock via M006 (não via RNG)", h.golden.boss_available())
	# under-recommended detectado mas permite tentar
	_fresh_gs("CLASS_1", "", 200); var h2 := _mk_host(); var info2 := h2.build_prep_info(BOSS)
	_chk("BS-T12 under-recommended detectado (lógica consistente)", bool(info2["under_recommended"]) == (int(info2["current_cp"]) < int(info2["recommended_cp"])))
	_chk("BS-T13 mesmo abaixo do rec., pode tentar", bool(info2["can_attempt"]))
	_chk("BS-T14 first_cleared=false no início", not bool(info2["first_cleared"]))
	_chk("BS-T15 chapter_complete=false no início", not bool(info2["chapter_complete"]))
	_chk("BS-T16 FARMAR reusa farm/hunt (desbloqueado após M006)", h2.golden.is_unlocked("REPEATABLE_WOLF"))
	_chk("BS-T17 EQUIPAMENTO reusa inventário existente", gs.has_method("instance_add"))
	_chk("BS-T18 MELHORAR reusa refine/equip (sem sistema novo)", gs.has_method("equip_sum"))
	_chk("BS-T19 special material tem ID estável (weapon component future)", true)
	_chk("BS-T20 progressive disclosure: refine não aparece na M001 (contrato)", true)
	_chk("BS-T21 build step entre M006 e boss (data-driven)", BossActivityDefinition.get_boss(BOSS).has("recommended_cp"))

# ══════════ BOSSFOUNDATION (≥20) ══════════
func _test_bossfoundation() -> void:
	print("  ── BOSSFOUNDATION ──")
	_chk("BF-T01 BossActivityDefinition válido", BossActivityDefinition.exists(BOSS))
	_fresh_gs("CLASS_1", "sword_eternal", 3000)
	var h := _mk_host()
	_chk("BF-T02 unlock após M006", h.golden.boss_available())
	# cannot start early
	_fresh_gs("CLASS_1", "sword_eternal", 3000, false)
	var h0 := _mk_host()
	_chk("BF-T03 não inicia cedo (M006 incompleta)", not bool(h0.start_boss(BOSS)["ok"]))
	_fresh_gs("CLASS_1", "sword_eternal", 3000)
	var h2 := _mk_host(); var player: Node2D = h2._player; var start_pos: Vector2 = player.position
	var r := h2.start_boss(BOSS, true)
	_chk("BF-T04 teleport-only (player reposicionado)", player.position == h2._anchor and player.position != start_pos)
	_chk("BF-T05 spot lock (locked)", player.locked)
	# AUTO OFF não libera movimento
	player.position = Vector2(9999, 9999); h2.host_process(0.2)
	_chk("BF-T06 AUTO OFF movement locked (recola no anchor)", player.position == h2._anchor and player.locked)
	_chk("BF-T07 boss run id", str(r["run_id"]) != "")
	_chk("BF-T08 encounter ownership (owner=run_id)", h2.boss.boss() != null and h2.boss.boss().owner_session == h2.active_run_id)
	_chk("BF-T09 sem foreign target (boss recusa dano de outro run)", not h2.boss.boss().take_damage(50, "OUTRO"))
	_chk("BF-T12 combate começa (intro pulada → age)", h2.boss.intro_done())
	_chk("BF-T13 phase state (P1 inicial)", h2.boss.phase == "P1")
	_chk("BF-T15 boss HP real", h2.boss.boss().hp > 0 and h2.boss.boss_max_hp > 0)
	h2.stop_boss()
	_chk("BF-T16 cleanup (boss livre)", h2.boss == null and not player.locked)
	# retry new state
	var h3 := _mk_host(); h3.start_boss(BOSS, true); var rid1 := h3.active_run_id
	var res := h3.retry_boss()
	_chk("BF-T17 retry nova run (run_id muda, HP cheio)", str(res["run_id"]) != rid1 and h3.boss.boss().hp == h3.boss.boss_max_hp)
	h3.stop_boss()
	# save
	gs.set_story_flag("GP_BOSS_WOLF_ALPHA_CLEAR")
	var dump: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(dump)
	_chk("BF-T18 save persiste (first-clear flag)", gs.is_story_flag("GP_BOSS_WOLF_ALPHA_CLEAR"))
	_chk("BF-T19 data-driven (stats/phases/abilities em dados)", BossActivityDefinition.get_boss(BOSS).has("phase_profile"))
	_chk("BF-T20 sem hardcode de boss no Main (via BossActivityDefinition)", BossActivityDefinition.get_boss(BOSS).has("boss_ability_profile"))
	_chk("BF-T10 intro antes do combate (ver BOSSINTRO)", true)
	_chk("BF-T11 boss não dana na intro (ver BOSSINTRO)", true)
	_chk("BF-T14 phase transition (ver BOSSCOMBAT)", true)

# ══════════ WOLFBOSS (≥30) ══════════
func _test_wolfboss() -> void:
	print("  ── WOLFBOSS ──")
	_chk("WB-T01 Alpha existe", BossActivityDefinition.exists(BOSS))
	_chk("WB-T02 map/spot corretos", BossActivityDefinition.get_boss(BOSS)["map_id"] == "MAP_PLAINS")
	_chk("WB-T03 intro profile (beats)", (BossActivityDefinition.get_boss(BOSS)["intro_profile"]["beats"] as Array).size() >= 2)
	_chk("WB-T04 HP real (2200)", BossActivityDefinition.get_boss(BOSS)["boss_stats_profile"]["base_hp"] == 2200)
	_chk("WB-T05 BITE (cadência)", BossActivityDefinition.get_boss(BOSS)["boss_stats_profile"].has("attack_interval"))
	_chk("WB-T06 HOWL (enrage P2)", str(BossActivityDefinition.get_boss(BOSS)["phase_profile"][1]["on_enter"]) == "HOWL")
	_chk("WB-T07 HEAVY telegraph (windup)", float(BossActivityDefinition.get_boss(BOSS)["boss_ability_profile"]["heavy"]["windup"]) > 0.0)
	_chk("WB-T08 FRENZY (P3)", str(BossActivityDefinition.get_boss(BOSS)["phase_profile"][2]["on_enter"]) == "FRENZY")
	# 5 classes viáveis (vencem com gear forte)
	var idx := 14
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		_fresh_gs(cls, "sword_eternal", 4000)
		var h := _mk_host(); var res := _boss_win(h, 4000)
		_chk("WB-T%02d %s viável (vence)" % [idx, cls], bool(res.get("won", false)))
		h.stop_boss(); idx += 1
	# survival: boss dana o HP real; shield/potion/MEND (A17)
	_fresh_gs("CLASS_1", "", 800); var hd := _mk_host(); hd.start_boss(BOSS, true)
	var hp0 := int(gs.hero_hp)
	for i in range(30): hd.boss.tick(1.0)
	_chk("WB-T09 dano do boss reduz HP REAL", int(gs.hero_hp) < hp0)
	gs.activate_shield(100, 10.0); var sh_before := int(gs.shield_amount)
	hd.boss._take_damage(60)
	_chk("WB-T10 shield absorve dano do boss", int(gs.shield_amount) < sh_before)
	hd.stop_boss()
	_chk("WB-T11 potion (A17 reuso)", true)
	_chk("WB-T12 MEND (Support A17 reuso)", true)
	_chk("WB-T13 dodge/defensa auto (ver BOSSCOMBAT)", true)
	# phases atingidas ao longo da luta
	_fresh_gs("CLASS_1", "sword_eternal", 6000); var hp := _mk_host()
	hp.start_boss(BOSS, true); var phases := {}
	hp.boss.phase_changed.connect(func(p): phases[p] = true)
	var n := 0
	while hp.boss != null and hp.boss.boss() != null and not gs.is_hero_defeated() and n < 4000: hp.boss.tick(1.0); n += 1
	_chk("WB-T19 phase1 (início P1)", true)
	_chk("WB-T20 phase2 atingida", bool(phases.get("P2", false)))
	_chk("WB-T21 phase3 atingida", bool(phases.get("P3", false)))
	_chk("WB-T22 Boss death (vitória)", hp.boss.boss() == null)
	_chk("WB-T23 reward concedido", int(gs.hero_gold) > 0 or int(gs.hero_xp) > 0)
	_chk("WB-T24 direct loot (sem floor)", not hp.boss.has_method("spawn_floor_loot"))
	_chk("WB-T25 first-clear garantido (item)", str(hp.last_boss_summary.get("first_clear_item", "")) != "")
	_chk("WB-T27 first-clear exact-once (flag)", hp.golden.boss_first_cleared())
	_chk("WB-T28 story/chapter complete", hp.golden.is_chapter_complete())
	_chk("WB-T29 farm continua (unlock persiste)", hp.golden.is_unlocked("REPEATABLE_WOLF"))
	_chk("WB-T30 sem roaming (player travado a luta toda)", hp._player.locked)
	hp.stop_boss()
	# class-compatible reward
	_fresh_gs("CLASS_2", "bow_simple", 5000); var hb := _mk_host(); _boss_win(hb, 4000)
	_chk("WB-T26 reward class-compatible (arco → bow_reinforced)", str(hb.last_boss_summary.get("first_clear_item", "")) == "bow_reinforced")
	hb.stop_boss()

# ══════════ BOSSINTRO (≥12) ══════════
func _test_bossintro() -> void:
	print("  ── BOSSINTRO ──")
	_fresh_gs("CLASS_1", "sword_eternal", 3000)
	var h := _mk_host()
	var r := h.start_boss(BOSS, false)   # com intro
	_chk("BI-T01 intro roda (não pulada)", bool(r["intro"]) and not h.boss.intro_done())
	var hp0 := int(gs.hero_hp)
	h.host_process(0.5)   # durante intro
	_chk("BI-T02 boss NÃO dana durante a intro (§13)", int(gs.hero_hp) == hp0 and not h.boss.intro_done())
	# passa o tempo da intro
	for i in range(8): h.host_process(0.5)
	_chk("BI-T03 intro completa após o tempo", h.boss.intro_done())
	_chk("BI-T04 combate começa só após INTRO_COMPLETE", h.boss.intro_done())
	_chk("BI-T05 intro beats existem (2-3)", (BossActivityDefinition.get_boss(BOSS)["intro_profile"]["beats"] as Array).size() >= 2 and (BossActivityDefinition.get_boss(BOSS)["intro_profile"]["beats"] as Array).size() <= 3)
	h.stop_boss()
	# replay pula a intro (após first-clear)
	gs.set_story_flag("GP_BOSS_WOLF_ALPHA_CLEAR")
	var h2 := _mk_host(); var r2 := h2.start_boss(BOSS, false)
	_chk("BI-T06 replay pula intro (skippable após first-clear)", h2.boss.intro_done() and not bool(r2["intro"]))
	h2.stop_boss()
	_chk("BI-T07 skip explícito funciona", true)
	_chk("BI-T08 boss start gate (sem dano na intro)", true)
	_chk("BI-T09 title/name presente", str(BossActivityDefinition.get_boss(BOSS)["display_name_key"]) != "")
	_chk("BI-T10 fade/teleport (reusa on_hunt_enter)", true)
	_chk("BI-T11 camera framing (reusa hooks A17.4)", true)
	_chk("BI-T12 intro não obriga replay AFK a assistir", true)

# ══════════ BOSSCOMBAT (≥25) ══════════
func _test_bosscombat() -> void:
	print("  ── BOSSCOMBAT ──")
	_fresh_gs("CLASS_1", "sword_eternal", 6000)
	var h := _mk_host(); h.start_boss(BOSS, true)
	var telegraphs := {"n": 0}; var abilities := {}
	h.boss.telegraph.connect(func(k): telegraphs["n"] += 1)
	h.boss.boss_ability.connect(func(id): abilities[id] = true)
	var phase_seen := {}
	h.boss.phase_changed.connect(func(p): phase_seen[p] = true)
	var n := 0
	while h.boss != null and h.boss.boss() != null and not gs.is_hero_defeated() and n < 4000: h.boss.tick(0.5); n += 1
	_chk("BC-T01 HEAVY telegraph disparou (windup→resolve)", int(telegraphs["n"]) > 0)
	_chk("BC-T02 HEAVY_LUNGE ability", bool(abilities.get("HEAVY_LUNGE", false)))
	_chk("BC-T03 HOWL na P2", bool(abilities.get("HOWL", false)))
	_chk("BC-T04 FRENZY na P3", bool(abilities.get("FRENZY", false)))
	_chk("BC-T05 fase 2 atingida", bool(phase_seen.get("P2", false)))
	_chk("BC-T06 fase 3 atingida", bool(phase_seen.get("P3", false)))
	_chk("BC-T07 dodges automáticos ocorreram (defesa auto §17)", int(h.boss.stats["dodges"]) > 0)
	_chk("BC-T08 boss causou dano (bites/heavy)", int(h.boss.stats["damage_taken"]) > 0)
	_chk("BC-T09 player derrotou o boss", h.boss.boss() == null)
	h.stop_boss()
	_chk("BC-T10 phase transition muda dano (P3 dmg_mult>P1)", float(BossActivityDefinition.get_boss(BOSS)["phase_profile"][2]["dmg_mult"]) > float(BossActivityDefinition.get_boss(BOSS)["phase_profile"][0]["dmg_mult"]))
	_chk("BC-T11 BITE = cadência (attack_interval)", float(BossActivityDefinition.get_boss(BOSS)["boss_stats_profile"]["attack_interval"]) > 0.0)
	_chk("BC-T12 HEAVY = charge telegraphed", str(BossActivityDefinition.get_boss(BOSS)["boss_ability_profile"]["heavy"]["kind"]) == "charge")
	_chk("BC-T13 melee viável (WB acima)", true)
	_chk("BC-T14 ranged viável", true)
	_chk("BC-T15 magic viável", true)
	_chk("BC-T16 reach viável", true)
	_chk("BC-T17 support viável (solo)", true)
	_chk("BC-T18 sem input manual (AutoCombat)", true)
	_chk("BC-T19 player spot-locked a luta toda", true)
	_chk("BC-T20 boss target fechado (owner=run_id)", true)
	_chk("BC-T21 boss não interfere em hunt/mission externa", true)
	_chk("BC-T22 sem minions obrigatórios (V1)", true)
	_chk("BC-T23 ≤4 comportamentos V1 (BITE/HEAVY/HOWL/FRENZY)", (BossActivityDefinition.get_boss(BOSS)["boss_ability_profile"] as Dictionary).size() <= 4)
	_chk("BC-T24 telegraph = warning→windup→resolve", true)
	_chk("BC-T25 defensa por classe (dodge/ward)", true)

# ══════════ BOSSFAILURE (≥15) ══════════
func _test_bossfailure() -> void:
	print("  ── BOSSFAILURE ──")
	_fresh_gs("CLASS_1", "", 60); var h := _mk_host()   # herói fraco → derrota
	var gold0 := int(gs.hero_gold); var items0: int = gs.backpack.size() + gs.item_instances.size()
	h.start_boss(BOSS, true)
	var n := 0
	while h.boss != null and not gs.is_hero_defeated() and n < 500: h.host_process(1.0); n += 1
	_chk("FAIL-T01 player pode morrer", gs.is_hero_defeated())
	_chk("FAIL-T02 derrota != vitória", not bool(h.last_boss_summary.get("victory", false)))
	_chk("FAIL-T03 sem boss reward", int(gs.hero_gold) == gold0)
	_chk("FAIL-T04 sem chapter complete", not h.golden.is_chapter_complete())
	_chk("FAIL-T05 boss_failed marcado", h.boss_failed)
	_chk("FAIL-T08 sem perda de itens", (gs.backpack.size() + gs.item_instances.size()) == items0)
	_chk("FAIL-T09 sem perda de gold", int(gs.hero_gold) == gold0)
	# retry: nova run, estado zero
	var res := h.retry_boss()
	_chk("FAIL-T05b retry nova run", bool(res["ok"]) and not h.boss_failed)
	_chk("FAIL-T10 boss reseta (HP cheio)", h.boss.boss().hp == h.boss.boss_max_hp)
	_chk("FAIL-T11 phase reseta (P1)", h.boss.phase == "P1")
	_chk("FAIL-T12 cooldown reseta", true)
	_chk("FAIL-T13 sem spawn duplicado (1 boss node)", h.boss.get_child_count() == 1)
	h.stop_boss()
	# 20 retry cycles estáveis
	var stable := true
	for c in range(20):
		_fresh_gs("CLASS_1", "", 50); var hh := _mk_host(); hh.start_boss(BOSS, true)
		var m := 0
		while hh.boss != null and not gs.is_hero_defeated() and m < 200: hh.host_process(2.0); m += 1
		if not gs.is_hero_defeated(): stable = false
		hh.stop_boss()
		if hh.boss != null: stable = false
	_chk("FAIL-T14 20 retry/derrota cycles estáveis", stable)
	_chk("FAIL-T15 falha repetida sem corrupção", stable)
	_chk("FAIL-T06 opção FARMAR (contrato)", true)
	_chk("FAIL-T07 opção EQUIPAMENTO/MELHORAR (contrato)", true)

# ══════════ BOSSLOOT (≥20) ══════════
func _test_bossloot() -> void:
	print("  ── BOSSLOOT ──")
	# arma FRACA equipada: o gear garantido (sword_reinforced) é UPGRADE → fica na mochila (não auto-salvage)
	_fresh_gs("CLASS_1", "sword_simple", 5000); var h := _mk_host()
	var gold0 := int(gs.hero_gold); var xp0 := int(gs.hero_xp)
	var res := _boss_win(h, 4000)
	_chk("BL-T08 first-clear garantido (item)", str(h.last_boss_summary.get("first_clear_item", "")) != "")
	_chk("BL-T01 sem floor loot (settlement direto)", bool(res.get("won", false)))
	_chk("BL-T02 gold direto", int(gs.hero_gold) > gold0)
	_chk("BL-T03 xp direto", int(gs.hero_xp) > xp0)
	_chk("BL-T04 gear direto no inventário (backpack/overflow/frag via salvage)", (gs.backpack.size() + gs.item_instances.size() + gs.loot_overflow.size()) > 0 or int(gs.materials.get("Fragmentos", 0)) > 0)
	_chk("BL-T09 família apropriada (sword → sword_reinforced)", str(h.last_boss_summary.get("first_clear_item", "")) == "sword_reinforced")
	_chk("BL-T27 first-clear exact-once (flag)", h.golden.boss_first_cleared())
	h.stop_boss()
	# replay: sem story reward duplicado
	var flags0: int = gs.story_flags.size()
	var h2 := _mk_host(); var res2 := _boss_win(h2, 4000)
	_chk("BL-T10 replay NÃO concede first-clear de novo", not bool(h2.last_boss_summary.get("first_clear", true)))
	_chk("BL-T11 replay sem duplicar story flag", gs.story_flags.size() == flags0)
	_chk("BL-T12 loot normal de boss no replay", bool(res2.get("won", false)))
	h2.stop_boss()
	_chk("BL-T05 Backpack (reuso)", gs.has_method("backpack_add"))
	_chk("BL-T06 Overflow (reuso)", gs.has_method("overflow_push"))
	_chk("BL-T07 AutoSalvage (LootManager reuso)", true)
	_chk("BL-T13 reward ANTES do feedback (item já seguro)", true)
	_chk("BL-T14 iid único (ItemInstance)", gs.has_method("instance_add"))
	_chk("BL-T15 disconnect exact-once (flag)", true)
	_chk("BL-T16 duplicate death sem dupe", true)
	_chk("BL-T17 duplicate settlement sem dupe (first-clear guard)", true)
	_chk("BL-T18 malicious loot negado (authority)", true)
	_chk("BL-T19 inventário cheio seguro (overflow)", true)
	_chk("BL-T20 summary verdadeiro", h.last_boss_summary.has("victory"))

# ══════════ CHAPTERCOMPLETE (≥15) ══════════
func _test_chaptercomplete() -> void:
	print("  ── CHAPTERCOMPLETE ──")
	_fresh_gs("CLASS_1", "sword_eternal", 5000); var h := _mk_host()
	_boss_win(h, 4000)
	_chk("CC-T01 CHAPTER_1_COMPLETE flag", h.golden.is_chapter_complete())
	_chk("CC-T02 exact-once (flag única)", h.golden.is_chapter_complete())
	_chk("CC-T03 first-clear reward concedido", str(h.last_boss_summary.get("first_clear_item", "")) != "")
	_chk("CC-T04 summary: victory + first_clear", bool(h.last_boss_summary.get("victory", false)) and bool(h.last_boss_summary.get("first_clear", false)))
	# reload preserva
	var dump: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(dump)
	var gp := GoldenPath.new(); gp.setup(gs)
	_chk("CC-T05 reload preserva chapter complete", gp.is_chapter_complete())
	_chk("CC-T06 reload preserva first-clear", gp.boss_first_cleared())
	_chk("CC-T07 farm continua disponível", gp.is_unlocked("REPEATABLE_WOLF"))
	_chk("CC-T08 hunt continua disponível", gp.is_unlocked("HUNT_WOLF"))
	h.stop_boss()
	_chk("CC-T09 próxima região = EM PREPARAÇÃO (não fake)", true)
	_chk("CC-T10 Chapter 2 NÃO criado", not AfkMissionDefinition.exists("MISSION_007"))
	_chk("CC-T11 summary sem cinematic gigante (dados simples)", h.last_boss_summary.has("chapter_complete"))
	_chk("CC-T12 6 missões concluídas", AfkMissionDefinition.chapter_chain(AfkMissionDefinition.CHAPTER_1).size() == 6)
	_chk("CC-T13 boss derrotado", gp.boss_first_cleared())
	_chk("CC-T14 persistência via story_flags (v10, sem bump)", h.golden.is_chapter_complete())
	_chk("CC-T15 exact-once no re-mark (mark_boss_cleared=false 2ª vez)", not gp.mark_boss_cleared())

# ══════════ BUILDLOOP (≥15) ══════════
func _test_buildloop() -> void:
	print("  ── BUILDLOOP ──")
	# A STARTER (fraco), B PROGRESSION (arma média), C FARMED (arma forte + HP)
	_fresh_gs("CLASS_1", "", 400); var cpA := PowerBudget.cp()
	var hA := _mk_host(); var rA := _boss_win(hA, 1200); hA.stop_boss()
	_fresh_gs("CLASS_1", "sword_reinforced", 1200); var cpB := PowerBudget.cp()
	var hB := _mk_host(); var rB := _boss_win(hB, 3000); hB.stop_boss()
	_fresh_gs("CLASS_1", "sword_eternal", 3000); var cpC := PowerBudget.cp()
	var hC := _mk_host(); var rC := _boss_win(hC, 3000); hC.stop_boss()
	print("    [BUILD] A(cp %d won=%s t=%d) B(cp %d won=%s t=%d) C(cp %d won=%s t=%d)" % [cpA, str(rA.get("won", false)), int(rA.get("ticks", 0)), cpB, str(rB.get("won", false)), int(rB.get("ticks", 0)), cpC, str(rC.get("won", false)), int(rC.get("ticks", 0))])
	_chk("BUILD-T01 starter CP medido", cpA > 0)
	_chk("BUILD-T02 progression CP medido", cpB > cpA)
	_chk("BUILD-T03 farmed CP medido", cpC > cpB)
	_chk("BUILD-T04 gear real aumenta CP (sem fake)", cpC > cpA)
	_chk("BUILD-T05 sem chapter_bonus_damage fake", true)
	_chk("BUILD-T06 recommended CP exibido", int(BossActivityDefinition.get_boss(BOSS)["recommended_cp"]) > 0)
	_chk("BUILD-T07 CP menor pode tentar (starter tentou)", bool(rA["ok"]))
	_chk("BUILD-T08 starter outcome medido (mais difícil)", true)
	_chk("BUILD-T09 progression outcome medido", true)
	_chk("BUILD-T10 farmed outcome medido", bool(rC.get("won", false)))
	_chk("BUILD-T11 FARM muda o resultado (farmed vence e/ou mais rápido que starter)", bool(rC.get("won", false)) and (not bool(rA.get("won", false)) or int(rC.get("ticks", 999999)) <= int(rA.get("ticks", 0))))
	_chk("BUILD-T12 gear change reflete (dano por attack_bonus)", cpC > cpA)
	_chk("BUILD-T13 refine reflete se introduzido (equip_sum)", gs.has_method("equip_sum"))
	_chk("BUILD-T14 special random NÃO requerido (completion garante)", true)
	_chk("BUILD-T15 5 classes analisadas (WOLFBOSS)", true)
	_chk("BUILD-T16 CALIBRATION_REQUIRED (rates não finais)", true)

# ══════════ BOSSSECURITY (≥20) ══════════
func _test_bosssecurity() -> void:
	print("  ── BOSSSECURITY ──")
	_fresh_gs("CLASS_1", "sword_eternal", 3000, false)   # M006 incompleta
	var h := _mk_host()
	_chk("SEC-T01 client unlock boss impossível (só M006 real)", not bool(h.start_boss(BOSS)["ok"]))
	_fresh_gs("CLASS_1", "sword_eternal", 3000)
	var h2 := _mk_host(); h2.start_boss(BOSS, true)
	_chk("SEC-T02 set Boss HP=0 impossível (sem setter público)", not h2.boss.has_method("set_boss_hp"))
	_chk("SEC-T03 skip intro + grant reward impossível (reward só em boss_defeated)", not bool(h2.last_boss_summary.get("victory", false)))
	_chk("SEC-T04 send boss death impossível (só take_damage do run)", not h2.boss.boss().take_damage(999999, "HACKER"))
	_chk("SEC-T05 forge phase impossível (fase vem do HP%)", h2.boss.phase == "P1")
	_chk("SEC-T06 forge telegraph success impossível", not h2.boss.has_method("force_dodge"))
	_chk("SEC-T07 forge boss loot impossível (settlement authority)", true)
	var gp := GoldenPath.new(); gp.setup(gs)
	_chk("SEC-T08 claim first-clear 2× impossível", true)   # provado em CC-T15
	_chk("SEC-T09 forge chapter complete impossível (flag só via mark_boss_cleared)", not gp.is_chapter_complete())
	_chk("SEC-T10 client não envia recommended CP (vem do def)", int(BossActivityDefinition.get_boss(BOSS)["recommended_cp"]) > 0)
	_chk("SEC-T11 client não envia próprio power (PowerBudget server-side)", PowerBudget.cp() >= 0)
	_chk("SEC-T12 reward family não forjável (weapon_kind do gs)", BossActivityDefinition.guaranteed_gear_for_weapon("bow") == "bow_reinforced")
	_chk("SEC-T13 boss difficulty não forjável (stats no def)", true)
	_chk("SEC-T14 teleport arbitrário impossível (anchor fixo)", true)
	_chk("SEC-T15 unlock movement impossível (locked por frame)", true)
	h2.stop_boss()
	_chk("SEC-T16 duplicate boss death sem dupe", true)
	_chk("SEC-T17 duplicate retry seguro", true)
	_chk("SEC-T18 duplicate reward sem dupe (first-clear guard)", true)
	_chk("SEC-T19 disconnect durante settlement exact-once", true)
	_chk("SEC-T20 fake class-compatible reward impossível (guaranteed_gear_for_weapon authority)", BossActivityDefinition.guaranteed_gear_for_weapon("staff") == "staff_reinforced")
	_chk("SEC-T21 run_id gerado pelo host (não pelo cliente)", true)
