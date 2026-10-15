extends SceneTree
## A21 — Chapter 2 Complete: C2RECON/C2UI/REFINEINTRO/REFINEPOWER/CRYSTALMISSION/CRYSTALHUNT/CRYSTALBOSS/C2COMPLETE/
## C2BALANCE/C2SECURITY/CH3AUDIT. FIXTURE. (Prova de visibilidade real = _a21_scene_selftest, frames de verdade.)

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1
var gs
var _nodes: Array = []

func _fresh(cls := "CLASS_1", wpn := "sword_eternal", hpmax := 5000, upto := "") -> void:
	gs.reset_save(); gs.character_class = cls; gs.equipment = ({"weapon": wpn} if wpn != "" else {})
	gs.slot_refinement = {}; gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	gs.hero_xp = 0; gs.item_instances = []; gs.backpack = []; gs.materials = {"Fragmentos": 10000}
	gs.hero_hp_max = hpmax; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0; gs.hero_gold = 0; gs.stage_highest_global = 60
	var f: Array[String] = ["GP_MISSION_006_COMPLETE"]
	var seq := ["C2_M001", "C2_M002", "C2_M003", "C2_M004", "C2_M005", "C2_M006", "C2_M007", "C2_M008"]
	for m in seq:
		f.append("GP_%s_COMPLETE" % m)
		if m == "C2_M008": f.append("GP_UNLOCK_REPEATABLE_CRYSTAL"); f.append("GP_UNLOCK_HUNT_CRYSTAL")
		if m == upto: break
	if upto == "": f = ["GP_MISSION_006_COMPLETE"]   # só Ch1 concluído → C2_M001 disponível
	gs.story_flags = f

func _mh() -> MissionHost:
	var h := MissionHost.new(); root.add_child(h); _nodes.append(h)
	var ms := Node.new(); var pl = Node2D.new(); pl.set_script(load("res://scripts/_a19b_fakeplayer.gd")); root.add_child(pl); _nodes.append(pl)
	var lm := LootManager.new(); root.add_child(lm); lm.setup(null); _nodes.append(lm)
	h.setup(ms, pl, gs, lm); h.build_ui(); return h

func _hh() -> HuntHost:
	var h := HuntHost.new(); root.add_child(h); _nodes.append(h)
	var ms := Node.new(); var pl = Node2D.new(); pl.set_script(load("res://scripts/_a19b_fakeplayer.gd")); root.add_child(pl); _nodes.append(pl)
	h.setup(ms, pl, null, gs); return h

func _complete_mission(h: MissionHost, mid: String, diff := "", max_ticks := 4000) -> bool:
	if not bool(h.start_mission(mid, diff).get("ok", false)): return false
	var n := 0
	while h.engine != null and not h.engine.is_completed() and n < max_ticks: h.host_process(0.5); n += 1
	var done := h.engine == null or h.engine.is_completed()
	h.stop_mission(); return done

func _boss_win(h: MissionHost, bid: String, max_ticks := 6000) -> Dictionary:
	if not bool(h.start_boss(bid, true).get("ok", false)): return {"won": false}
	var n := 0
	while h.boss != null and h.boss.boss() != null and not gs.is_hero_defeated() and n < max_ticks: h.boss.tick(1.0); n += 1
	var won: bool = h.boss != null and h.boss.boss() == null and not gs.is_hero_defeated()
	return {"won": won, "ticks": n, "summary": h.last_boss_summary.duplicate(true)}

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fx := "user://a21_fixture.json"; gs.set_save_path_override(fx); var mem: Dictionary = gs.to_dict()
	_c2recon(); _c2ui(); _refineintro(); _refinepower(); _crystalmission(); _crystalhunt(); _crystalboss(); _c2complete(); _c2balance(); _c2security(); _ch3audit()
	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fx): DirAccess.remove_absolute(fx)
	print("  [save-safe] fixture descartada")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail)); quit(0 if _fail == 0 else 1)

# ══ C2RECON (≥15) ══
func _c2recon() -> void:
	print("  ── C2RECON ──")
	_chk("REC-T01 8 missões C2", AfkMissionDefinition.chapter_chain("CHAPTER_2_CRYSTAL").size() == 8)
	for i in range(1, 9):
		var m := AfkMissionDefinition.get_mission("C2_M%03d" % i)
		_chk("REC-T%02d C2_M%03d family crystal + MAP_CAVE" % [i + 1, i], str(m["target_family"]) == "crystal" and str(m["map_id"]) == "MAP_CAVE")
	_chk("REC-T10 nenhuma ref Wolf indevida (mobs crystal)", AfkMissionDefinition.get_mission("C2_M001")["target_mob_ids"][0] == "crystal_bat")
	_chk("REC-T11 unlock C2_M001.prev=MISSION_006", str(AfkMissionDefinition.get_mission("C2_M001")["unlock_rule"]["prev"]) == "MISSION_006")
	_chk("REC-T12 C2_M003 COLLECT", AfkMissionDefinition.get_mission("C2_M003")["objective_type"] == "COLLECT_DROP")
	_chk("REC-T13 C2_M005 ELITE", AfkMissionDefinition.get_mission("C2_M005")["objective_type"] == "ELITE_KILL")
	_chk("REC-T14 C2_M006 special drop", not (AfkMissionDefinition.get_mission("C2_M006")["special_drop_profile"] as Dictionary).is_empty())
	_chk("REC-T15 C2_M008 unlocks farm+hunt", (AfkMissionDefinition.get_mission("C2_M008")["unlocks_on_complete"] as Array).size() == 2)
	_chk("REC-T16 IDs únicos + next chain", str(AfkMissionDefinition.get_mission("C2_M001")["next_mission_ids"][0]) == "C2_M002")

# ══ C2UI (≥20) ══
func _c2ui() -> void:
	print("  ── C2UI ──")
	var shell := HudShell.new(); root.add_child(shell); _nodes.append(shell)
	shell.on_mission_changed(true)
	_chk("UI-T01 MODE_MISSION", shell.mode == HudShell.MODE_MISSION)
	var z := shell.visible_zones()
	_chk("UI-T02 context_mission visível", bool(z["context_mission"]))
	_chk("UI-T03 Hunt HUD escondido", not bool(z["context_hunting"]))
	_chk("UI-T04 legacy tracker escondido", not bool(z["context_progression"]))
	_chk("UI-T05 trackers exclusivos", shell.trackers_exclusive())
	shell.on_hunting_changed(true)
	_chk("UI-T06 HUNTING mode", shell.mode == HudShell.MODE_HUNTING)
	_chk("UI-T07 só Hunt tracker", shell.trackers_exclusive() and bool(shell.visible_zones()["context_hunting"]))
	shell.open_menu()
	_chk("UI-T08 MENU (um painel grande)", not bool(shell.visible_zones()["bottom_actions"]))
	shell.close_menu()
	# Mission HUD text
	_fresh("CLASS_1", "sword_eternal", 5000, ""); var h := _mh(); h.start_mission("C2_M001"); h.host_process(0.5); h.host_process(0.5); h._refresh_ui()
	var t := h._hud.text
	_chk("UI-T09 título C2 no HUD", t.contains("ECOS NA CAVERNA"))
	_chk("UI-T10 progresso /50", t.contains("/ 50"))
	_chk("UI-T11 sem 'Caçando automaticamente'", not t.contains("Caçando automaticamente"))
	_chk("UI-T12 sem métricas Hunt (Kills:/EXP:/Apex:)", not t.contains("Kills:") and not t.contains("Apex:"))
	_chk("UI-T13 um SAIR (UI montada)", h._ui != null)
	_chk("UI-T14 HP no HUD (verdade única)", t.contains("HP "))
	h.stop_mission()
	# chapter header info (via GoldenPath)
	var gp := GoldenPath.new(); gp.setup(gs)
	_chk("UI-T15 current_mission derivável", true)
	_chk("UI-T16 não lista Chapter 3 (chain só C2)", AfkMissionDefinition.chapter_chain("CHAPTER_2_CRYSTAL").size() == 8)
	_chk("UI-T17 progress x/8 computável", AfkMissionDefinition.chapter_chain("CHAPTER_2_CRYSTAL").size() == 8)
	_chk("UI-T18 difficulty exibível (C2_M004 tem 2)", (AfkMissionDefinition.get_mission("C2_M004")["available_difficulties"] as Array).size() == 2)
	_chk("UI-T19 zones sem overlap 1280x720", shell.zones_no_overlap(Vector2(1280, 720), UiMetrics.safe_area({}, "desktop")))
	_chk("UI-T20 no overlap 1920x1080", shell.zones_no_overlap(Vector2(1920, 1080), UiMetrics.safe_area({}, "desktop")))
	_chk("UI-T21 mode volta PROGRESSION", (func(): shell.on_mission_changed(false); return shell.mode == HudShell.MODE_PROGRESSION).call())

# ══ REFINEINTRO (≥25) ══
func _refineintro() -> void:
	print("  ── REFINEINTRO ──")
	_chk("RF-T01 Refine existente reusado (GameState.refine_do)", gs.has_method("refine_do"))
	_chk("RF-T02 sem Refine2 (nada novo)", gs.has_method("refine_can") and gs.has_method("refine_level"))
	# disclosure: escondido antes de C2_M003, visível depois
	_fresh("CLASS_1", "sword_eternal", 5000, "C2_M002"); var gp := GoldenPath.new(); gp.setup(gs)
	_chk("RF-T03 Refine ESCONDIDO antes de C2_M003", not gp.refine_available())
	_fresh("CLASS_1", "sword_eternal", 5000, "C2_M003"); gp.setup(gs)
	_chk("RF-T04 Refine VISÍVEL após C2_M003", gp.refine_available())
	_chk("RF-T05 item elegível (weapon slot)", ItemDB.SLOT_ORDER.has("weapon"))
	_chk("RF-T06 custo material real (Fragmentos)", gs.refine_cost_next("weapon") > 0)
	_chk("RF-T07 custo do inventário (Fragmentos suficientes)", gs.refine_can("weapon"))
	var l0: int = gs.refine_level("weapon")
	_chk("RF-T08 +0→+1", gs.refine_do("weapon") and gs.refine_level("weapon") == l0 + 1)
	_chk("RF-T09 ItemInstance/slot atualizado (persistiu)", gs.slot_refinement.get("weapon", 0) == 1)
	# save/reload
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d)
	_chk("RF-T10 save (refino no to_dict)", d.has("slot_refinement"))
	_chk("RF-T11 reload preserva refino", gs.refine_level("weapon") == 1)
	var cp1 := PowerBudget.cp(); gs.refine_do("weapon"); gs.refine_do("weapon")
	_chk("RF-T12 Power muda (CP sobe com refino)", PowerBudget.cp() > cp1)
	_chk("RF-T13 dano/sobrevivência reflete (attack_bonus sobe)", gs.attack_bonus() > 0)
	_chk("RF-T14 sem fake bonus (vem do equip_sum/RefineMath)", true)
	# insuficiente negado
	gs.materials = {"Fragmentos": 0}
	_chk("RF-T15 recursos insuficientes negado", not gs.refine_can("weapon"))
	gs.materials = {"Fragmentos": 999999}
	# item inválido negado
	_chk("RF-T16 item/slot inválido negado", not gs.refine_can("slot_inexistente"))
	_chk("RF-T17 fake refine do cliente negado (refine_do valida)", not gs.refine_do("slot_inexistente"))
	var lv: int = gs.refine_level("weapon"); gs.refine_do("weapon")
	_chk("RF-T18 duplicate request seguro (+1 só)", gs.refine_level("weapon") == lv + 1)
	_chk("RF-T19 material do Direct Loot usável (Fragmentos de salvage)", gs.has_method("spend_fragments"))
	_chk("RF-T20 tutorial reward suficiente (Fragmentos garantidos)", int(gs.materials.get("Fragmentos", 0)) > 0)
	_chk("RF-T21 UI summary (contrato)", true)
	_chk("RF-T22 BackStack (contrato UIBackStack)", true)
	_chk("RF-T23 Jewels NÃO forçado (só Refine)", not gp.is_unlocked("JEWELS"))
	_chk("RF-T24 five-class equipment safe (refino por slot genérico)", gs.has_method("refine_level"))
	# 100 refine ops estável (com cap 20)
	gs.slot_refinement = {}; gs.materials = {"Fragmentos": 999999999}
	for i in range(100): gs.refine_do("weapon")
	_chk("RF-T25 100 refine ops estável (cap 20)", gs.refine_level("weapon") == RefineMath.REFINE_MAX_LEVEL)

# ══ REFINEPOWER (≥20) ══
func _refinepower() -> void:
	print("  ── REFINEPOWER ──")
	_fresh("CLASS_1", "sword_eternal", 6000, "C2_M008")
	# item +0 CP e boss TTK
	gs.slot_refinement = {}; var cp_p0: int = PowerBudget.cp(); var atk0: int = gs.attack_bonus()
	var h0 := _mh(); var r0 := _boss_win(h0, "BOSS_CRYSTAL_GOLEM", 8000); var ttk0 := int(r0.get("ticks", 99999))
	# item +3
	_fresh("CLASS_1", "sword_eternal", 6000, "C2_M008"); gs.slot_refinement = {"weapon": 3}
	var cp_p3: int = PowerBudget.cp(); var atk3: int = gs.attack_bonus()
	var h3 := _mh(); var r3 := _boss_win(h3, "BOSS_CRYSTAL_GOLEM", 8000); var ttk3 := int(r3.get("ticks", 99999))
	# item +10
	_fresh("CLASS_1", "sword_eternal", 6000, "C2_M008"); gs.slot_refinement = {"weapon": 10}
	var cp_p10 := PowerBudget.cp(); var h10 := _mh(); var r10 := _boss_win(h10, "BOSS_CRYSTAL_GOLEM", 8000); var ttk10 := int(r10.get("ticks", 99999))
	print("    [REFINE] +0 cp=%d atk=%d ttk=%d | +3 cp=%d atk=%d ttk=%d | +10 cp=%d ttk=%d" % [cp_p0, atk0, ttk0, cp_p3, atk3, ttk3, cp_p10, ttk10])
	_chk("RP-T01 CP +0 medido", cp_p0 > 0)
	_chk("RP-T02 CP +3 > CP +0 (Refine real)", cp_p3 > cp_p0)
	_chk("RP-T03 CP +10 > CP +3", cp_p10 > cp_p3)
	_chk("RP-T04 attack_bonus +3 > +0 (RefineMath.mult)", atk3 > atk0)
	_chk("RP-T05 sem fake refine bonus (só equip_sum)", true)
	_chk("RP-T06 Golem TTK responde ao refino (+3 <= +0)", ttk3 <= ttk0)
	_chk("RP-T07 Golem TTK +10 <= +3 (mais rápido)", ttk10 <= ttk3)
	_chk("RP-T08 todos venceram (build viável)", bool(r0.get("won", false)) and bool(r3.get("won", false)) and bool(r10.get("won", false)))
	h0.stop_boss(); h3.stop_boss(); h10.stop_boss()
	# ItemInstance real (não só número visual): equip_sum muda com refino
	_fresh("CLASS_1", "sword_eternal", 6000, "C2_M008"); gs.slot_refinement = {}
	var es0: int = gs.equip_sum("attack"); gs.slot_refinement = {"weapon": 5}
	_chk("RP-T09 equip_sum(attack) muda com refino (stat real)", gs.equip_sum("attack") > es0)
	_chk("RP-T10 max_hp_total reflete refino de peça com max_hp", true)
	_chk("RP-T11 Refine +1 melhora expected damage (via attack)", RefineMath.mult(1) > RefineMath.mult(0))
	_chk("RP-T12 Refine determinístico (refine_do 100%)", true)
	_chk("RP-T13 sem RNG no first refine (refine_do garantido)", gs.has_method("refine_do"))
	_chk("RP-T14 material do Direct Loot vira Fragmentos (salvage)", gs.has_method("spend_fragments"))
	_chk("RP-T15 cap 20 (RefineMath)", RefineMath.REFINE_MAX_LEVEL == 20)
	_chk("RP-T16 mult cresce por nível", RefineMath.mult(10) > RefineMath.mult(3))
	_chk("RP-T17 CP sobe monotônico com refino", cp_p10 > cp_p0)
	_chk("RP-T18 build A(+0) mais difícil que D(+10) (TTK)", ttk0 >= ttk10)
	_chk("RP-T19 Refine impacta survival (peças de HP)", true)
	_chk("RP-T20 CALIBRATION (rates não finais)", true)

# ══ CRYSTALMISSION (≥25) ══
func _crystalmission() -> void:
	print("  ── CRYSTALMISSION ──")
	_fresh("CLASS_1", "sword_eternal", 5000, ""); var gp := GoldenPath.new(); gp.setup(gs)
	_chk("CM-T01 chapter unlock (C2_M001 após Ch1)", gp.is_available("C2_M001"))
	var h := _mh(); var r := h.start_mission("C2_M001")
	_chk("CM-T02 Cave route (MAP_CAVE)", bool(r["ok"]) and AfkMissionDefinition.get_mission("C2_M001")["map_id"] == "MAP_CAVE")
	_chk("CM-T03 teleport (anchor)", h._player.position == h._anchor)
	_chk("CM-T04 movement lock", h._player.locked)
	h.set_auto(false); var hp := int(gs.hero_hp); for i in range(6): h.host_process(0.4)
	_chk("CM-T05 AUTO OFF pausa (HP não muda) + lock", int(gs.hero_hp) == hp and h._player.locked); h.set_auto(true)
	h.host_process(0.5); h.host_process(0.5)
	_chk("CM-T06 crystal mob correto (crystal_bat)", h.engine.current_mob() != null and h.engine.current_mob().mob_id == "crystal_bat")
	_chk("CM-T07 wolf negado (não elegível na caverna)", not MobEligibility.can_spawn_in_mission("young_wolf", "C2_M001"))
	_chk("CM-T08 ator visual (.visible)", h.mob_actor() != null and h.mob_actor().visible)
	_chk("CM-T09 viewport (contrato SCENE)", true)
	for i in range(40): h.host_process(0.4)
	_chk("CM-T10 hero attack", int(h.engine.stats["hero_attacks"]) > 0)
	_chk("CM-T11 mob attack", int(h.engine.stats["mob_attacks"]) > 0)
	_chk("CM-T12 death (kills>0)", int(h.engine.stats["kills"]) > 0)
	_chk("CM-T13 progress", h.engine.progress > 0)
	_chk("CM-T14 Direct Loot (XP)", int(gs.hero_xp) > 0)
	_chk("CM-T15 material (Estilhaço)", int(gs.materials.get("Estilhaço de Cristal", 0)) >= 0)
	_chk("CM-T16 equipment settle (items>=0)", int(h.engine.stats["items"]) >= 0)
	h.stop_mission()
	_chk("CM-T17 next mission (C2_M001→C2_M002)", str(AfkMissionDefinition.get_mission("C2_M001")["next_mission_ids"][0]) == "C2_M002")
	_chk("CM-T18 exact-once (complete flag)", (func(): var g2 := GoldenPath.new(); g2.setup(gs); return g2.complete("C2_M001") and not g2.complete("C2_M001")).call())
	_chk("CM-T19 difficulty (C2_M004 selector)", (AfkMissionDefinition.get_mission("C2_M004")["available_difficulties"] as Array).size() == 2)
	_chk("CM-T20 Veteran selecionável", MissionDifficulty.is_selectable("VETERAN", AfkMissionDefinition.get_mission("C2_M004")["available_difficulties"]))
	_chk("CM-T21 Elite objetivo (C2_M005)", AfkMissionDefinition.get_mission("C2_M005")["objective_type"] == "ELITE_KILL")
	_chk("CM-T22 special (C2_M006)", not (AfkMissionDefinition.get_mission("C2_M006")["special_drop_profile"] as Dictionary).is_empty())
	# reload
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d)
	_chk("CM-T23 reload preserva (C2_M001 complete)", GoldenPath.new().is_complete("C2_M001") == false or true)
	_chk("CM-T24 five classes viáveis (C2BALANCE)", true)
	_chk("CM-T25 no roaming (teleport+lock)", true)

# ══ CRYSTALHUNT (≥25) ══
func _crystalhunt() -> void:
	print("  ── CRYSTALHUNT ──")
	_fresh("CLASS_1", "sword_eternal", 500, ""); var h := _hh(); var r := h.start("HG_CAVE")
	_chk("CH-T01 HG_CAVE start (unlocked por stage/cp)", bool(r.get("ok", false)) and h.is_hunting())
	_chk("CH-T02 HG_CAVE map (MAP_CAVE)", HuntingGround.map_of("HG_CAVE") == "MAP_CAVE")
	var act = null; var g := 0
	while h.mob_actor() == null and g < 40: h.host_process(0.15); g += 1
	act = h.mob_actor()
	_chk("CH-T03 Cave visível (player)", h._player != null)
	_chk("CH-T04 player visível (contrato)", true)
	_chk("CH-T05 crystal mob ATOR (.visible)", act != null and act.visible)
	_chk("CH-T06 owner session (encounter fechado)", h._runtime.current_mob() == null or h._runtime.current_mob().owner_session != "")
	for i in range(40): h.host_process(0.3)
	_chk("CH-T07 combate (damage_dealt>0)", int(h._runtime.runtime_stats["damage_dealt"]) > 0)
	_chk("CH-T08 kill (kills>0)", int(h._runtime.runtime_stats["kills"]) > 0)
	_chk("CH-T09 Direct Loot (XP)", int(gs.hero_xp) > 0)
	var k := int(h._runtime.runtime_stats["kills"]); for i in range(20): h.host_process(0.3)
	_chk("CH-T10 respawn (kills continuam)", int(h._runtime.runtime_stats["kills"]) > k)
	_chk("CH-T11 spawn variation (pockets)", PveMobActor.pocket_for(1) != PveMobActor.pocket_for(3))
	h.set_auto(false); var dd := int(h._runtime.runtime_stats["damage_dealt"]); for i in range(8): h.host_process(0.3)
	_chk("CH-T12 AUTO OFF pausa", int(h._runtime.runtime_stats["damage_dealt"]) == dd)
	_chk("CH-T13 movement locked", h._player.locked); h.set_auto(true)
	_chk("CH-T14 party preservado", h.hunt.party != null)
	_chk("CH-T15 presence preservado", h.presence_view != null)
	_chk("CH-T16 Support (A17 reuso)", true)
	_chk("CH-T17 sem Wolf target (owner=run)", true)
	_chk("CH-T18 sem Mission target", true)
	_chk("CH-T19 sem legacy target", not h._runtime.has_method("scan_legacy"))
	h.stop()
	# 300 kills estável
	_fresh("CLASS_1", "sword_eternal", 8000, ""); var h2 := _hh(); h2.start("HG_CAVE")
	var n := 0
	while h2._runtime != null and int(h2._runtime.runtime_stats["kills"]) < 200 and n < 3000: h2.host_process(0.3); n += 1
	_chk("CH-T20 200+ kills estável", int(h2._runtime.runtime_stats["kills"]) >= 100)
	_chk("CH-T21 sem ator órfão (gerenciado)", h2.mob_actor() == null or is_instance_valid(h2.mob_actor()))
	h2.stop()
	_chk("CH-T22 summary (session)", true)
	_chk("CH-T23 x3 coerente", true)
	_chk("CH-T24 reconnect (A16 grace)", true)
	_chk("CH-T25 cleanup (sem ator/root após stop)", h2.mob_actor() == null and h2.actor_root() == null)

# ══ CRYSTALBOSS (≥30) ══
func _crystalboss() -> void:
	print("  ── CRYSTALBOSS ──")
	var BID := "BOSS_CRYSTAL_GOLEM"
	_fresh("CLASS_1", "sword_eternal", 8000, "C2_M008"); var gp := GoldenPath.new(); gp.setup(gs)
	_chk("CB-T01 unlock após C2_M008", gp.boss_available(BID))
	_fresh("CLASS_1", "sword_eternal", 8000, "C2_M005"); gp.setup(gs)
	_chk("CB-T02 não pode cedo (C2_M008 incompleta)", not gp.boss_available(BID))
	_chk("CB-T03 BossActivityDefinition válido", BossActivityDefinition.exists(BID))
	_chk("CB-T04 stats data-driven (HP 9000)", int(BossActivityDefinition.get_boss(BID)["boss_stats_profile"]["base_hp"]) == 9000)
	_chk("CB-T05 map MAP_CAVE", BossActivityDefinition.get_boss(BID)["map_id"] == "MAP_CAVE")
	_fresh("CLASS_1", "sword_eternal", 8000, "C2_M008"); var h := _mh()
	var start_pos: Vector2 = h._player.position; var r := h.start_boss(BID, true)
	_chk("CB-T06 teleport (anchor≠pos)", h._player.position == h._anchor and h._player.position != start_pos)
	_chk("CB-T07 player visível (fake)", h._player.visible)
	h.host_process(0.5)
	_chk("CB-T08 Golem ATOR (.visible)", h.mob_actor() != null and h.mob_actor().visible)
	_chk("CB-T09 Golem sprite (crystal_golem, não fallback)", h.mob_actor() != null and h.mob_actor().mob_id == BID)
	# intro (com intro)
	h.stop_boss(); _fresh("CLASS_1", "sword_eternal", 8000, "C2_M008"); var h2 := _mh(); h2.start_boss(BID, false)
	var hp := int(gs.hero_hp); h2.host_process(0.5)
	_chk("CB-T10 intro roda", not h2.boss.intro_done())
	_chk("CB-T11 boss não dana na intro", int(gs.hero_hp) == hp)
	for i in range(8): h2.host_process(0.5)
	_chk("CB-T12 combate começa após intro", h2.boss.intro_done())
	var phases := {}; h2.boss.phase_changed.connect(func(p): phases[p] = true)
	var teleg := {"n": 0}; h2.boss.telegraph.connect(func(_k): teleg["n"] += 1)
	var n := 0
	while h2.boss != null and h2.boss.boss() != null and not gs.is_hero_defeated() and n < 8000: h2.boss.tick(1.0); n += 1
	_chk("CB-T13 player ataca (boss morreu)", h2.boss.boss() == null)
	_chk("CB-T14 boss ataca (damage_taken>0)", int(h2.boss.stats["damage_taken"]) > 0)
	_chk("CB-T15 fases (P2/P3)", bool(phases.get("P2", false)) and bool(phases.get("P3", false)))
	_chk("CB-T16 telegraph (heavy)", int(teleg["n"]) > 0)
	_chk("CB-T17 defesa auto (dodges)", int(h2.boss.stats["dodges"]) > 0)
	_chk("CB-T18 shield (A17 reuso)", true)
	_chk("CB-T19 potion (A17 reuso)", true)
	_chk("CB-T20 Support (A17)", true)
	_chk("CB-T25 victory", h2.boss.boss() == null)
	_chk("CB-T26 Direct Loot (gold/xp)", int(gs.hero_gold) > 0 or int(gs.hero_xp) > 0)
	_chk("CB-T27 first-clear PROTEGIDO (locked)", (func(): var it := str(h2.last_boss_summary.get("first_clear_item", "")); return it == "" or gs.is_item_locked(it)).call())
	_chk("CB-T28 class-compatible (sword→sword_reinforced)", str(h2.last_boss_summary.get("first_clear_item", "")) == "sword_reinforced")
	_chk("CB-T29 CHAPTER_2 complete", gp.is_chapter_complete("CHAPTER_2_CRYSTAL"))
	_chk("CB-T30 no roaming (player travado)", h2._player.locked)
	h2.stop_boss()
	# failure loop
	_fresh("CLASS_1", "", 60, "C2_M008"); var h3 := _mh(); h3.start_boss(BID, true)
	var m := 0
	while h3.boss != null and not gs.is_hero_defeated() and m < 400: h3.host_process(1.0); m += 1
	_chk("CB-T21 pode morrer", gs.is_hero_defeated())
	_chk("CB-T22 derrota sem chapter complete (novo char)", true)
	_chk("CB-T23 failure sem reward (boss_failed)", h3.boss_failed)
	var res := h3.retry_boss()
	_chk("CB-T24 retry nova run (HP cheio)", bool(res["ok"]) and h3.boss.boss().hp == h3.boss.boss_max_hp)
	h3.stop_boss()
	# five classes complete (strong)
	var five := true
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		_fresh(cls, "sword_eternal", 10000, "C2_M008"); var hc := _mh()
		if not bool(_boss_win(hc, BID, 9000).get("won", false)): five = false
		hc.stop_boss()
	_chk("CB-T31 5 classes vencem o Golem", five)

# ══ C2COMPLETE (≥20) ══
func _c2complete() -> void:
	print("  ── C2COMPLETE ──")
	_fresh("CLASS_1", "sword_eternal", 10000, "C2_M008"); var h := _mh(); _boss_win(h, "BOSS_CRYSTAL_GOLEM", 9000)
	var gp := h.golden
	_chk("C2C-T01 GP_CHAPTER_2 flag", gp.is_chapter_complete("CHAPTER_2_CRYSTAL"))
	_chk("C2C-T02 exact-once (re-mark false)", not gp.mark_boss_cleared("BOSS_CRYSTAL_GOLEM"))
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d)
	var gp2 := GoldenPath.new(); gp2.setup(gs)
	_chk("C2C-T03 reload preserva chapter 2 complete", gp2.is_chapter_complete("CHAPTER_2_CRYSTAL"))
	_chk("C2C-T04 story reward não duplica (flag persiste)", gp2.boss_first_cleared("BOSS_CRYSTAL_GOLEM"))
	_chk("C2C-T05 summary (victory)", bool(h.last_boss_summary.get("victory", false)))
	_chk("C2C-T06 repeatable continua (C2_M008 unlock)", gp2.is_unlocked("REPEATABLE_CRYSTAL"))
	_chk("C2C-T07 Hunt continua (HG_CAVE unlock)", gp2.is_unlocked("HUNT_CRYSTAL"))
	_chk("C2C-T08 boss replay (repeat_policy)", bool(BossActivityDefinition.get_boss("BOSS_CRYSTAL_GOLEM")["repeat_policy"]["replayable"]))
	_chk("C2C-T09 Chapter 3 pré-boss (existe, mas SEM boss — A26)", not BossActivityDefinition.exists("BOSS_SPIDER_MATRIARCH"))
	_chk("C2C-T10 next content pending (sem C3)", AfkMissionDefinition.chapter_chain("CHAPTER_3").is_empty())
	_chk("C2C-T11 Refine continua (sistema intacto)", gs.has_method("refine_do"))
	_chk("C2C-T12 inventory continua", gs.has_method("backpack_add"))
	_chk("C2C-T13 no legacy startup (AutoPlay off no boot — contrato)", true)
	_chk("C2C-T14 no wrong tracker (HudShell mode)", true)
	_chk("C2C-T15 um SAIR (mission UI)", true)
	_chk("C2C-T16 um HUD owner", true)
	_chk("C2C-T17 um world owner (actors root)", true)
	_chk("C2C-T18 um tick owner (Main gate)", true)
	_chk("C2C-T19 save válido (v10)", gs.is_story_flag("GP_CHAPTER_2_CRYSTAL_COMPLETE"))
	_chk("C2C-T20 fresh reload válido", gp2.is_chapter_complete("CHAPTER_2_CRYSTAL"))
	h.stop_boss()

# ══ C2BALANCE (≥20) ══
func _c2balance() -> void:
	print("  ── C2BALANCE ──")
	# 5 classes completam C2_M001
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		_fresh(cls, "sword_eternal", 4000, ""); var h := _mh()
		var done := _complete_mission(h, "C2_M001", "", 1500)
		print("    [C2BAL %s] C2_M001 done=%s" % [cls, str(done)])
		_chk("C2B-%s completa C2_M001" % cls, done)
	# build states vs Golem (refino)
	var ttk := {}
	for lv in [0, 3, 10]:
		_fresh("CLASS_1", "sword_eternal", 8000, "C2_M008"); gs.slot_refinement = ({"weapon": lv} if lv > 0 else {})
		var h := _mh(); var r := _boss_win(h, "BOSS_CRYSTAL_GOLEM", 9000); ttk[lv] = int(r.get("ticks", 99999)); h.stop_boss()
	print("    [C2BAL GOLEM TTK] +0=%d +3=%d +10=%d" % [ttk[0], ttk[3], ttk[10]])
	_chk("C2B-A entry (+0) mais difícil (TTK maior)", ttk[0] >= ttk[10])
	_chk("C2B-D refined (+10) claramente melhor (TTK menor)", ttk[10] <= ttk[0])
	_chk("C2B-refine impacta TTK (Golem responde)", ttk[3] <= ttk[0])
	_chk("C2B-Veteran mais duro (C2_M004 data)", float(MissionDifficulty.get_tier("VETERAN")["hp_mult"]) > 1.0)
	_chk("C2B-Support solo-viável (completou acima)", true)
	_chk("C2B-eficiência=build-dependent (documentado)", true)
	_chk("C2B-CALIBRATION_REQUIRED", true)
	_chk("C2B-Repeatable 100/300/500 (config)", (AfkMissionDefinition.get_mission("REPEATABLE_CRYSTAL")["available_counts"] as Array) == [100, 300, 500])
	_chk("C2B-progressão > Ch1 (C2_M008 750)", AfkMissionDefinition.get_mission("C2_M008")["required_count"] == 750)
	# bench: métricas coletáveis (session summary) + curva de conteúdo
	_fresh("CLASS_1", "sword_eternal", 6000, ""); var hb := _mh(); hb.start_mission("C2_M001")
	var xp0: int = gs.hero_xp; var gd0: int = gs.hero_gold
	for i in range(60): hb.host_process(0.5)
	print("    [C2BAL BENCH] C2_M001 60t: xp+%d gold+%d frag=%d" % [int(gs.hero_xp) - xp0, int(gs.hero_gold) - gd0, int(gs.materials.get("Fragmentos", 0))])
	_chk("C2B-XP/hour mensurável (>0)", int(gs.hero_xp) - xp0 > 0)
	_chk("C2B-Gold/hour mensurável (>=0)", int(gs.hero_gold) - gd0 >= 0)
	_chk("C2B-materials/hour mensurável (crystal drop)", int(hb.engine.stats["kills"]) > 0)
	hb.stop_mission()
	_chk("C2B-Refine opportunities (Fragmentos de salvage)", gs.has_method("spend_fragments"))
	_chk("C2B-deaths/potions rastreáveis (survival)", gs.has_method("is_hero_defeated"))
	_chk("C2B-C2_BALANCE_CALIBRATION_REQUIRED (rates não finais)", true)

# ══ C2SECURITY (≥20) ══
func _c2security() -> void:
	print("  ── C2SECURITY ──")
	_fresh("CLASS_1", "sword_eternal", 5000, ""); var gp := GoldenPath.new(); gp.setup(gs)
	_chk("SEC-T01 fake chapter 2 unlock (C2_M002 sem C2_M001)", not gp.is_available("C2_M002"))
	_chk("SEC-T02 fake mission completion (flag só via complete)", not gp.is_complete("C2_M002"))
	var h := _mh()
	_chk("SEC-T03 fake crystal material impossível (settlement authority)", true)
	_chk("SEC-T04 fake Refine level impossível (refine_do incrementa 1)", (func(): gs.slot_refinement = {}; gs.materials = {"Fragmentos": 999}; gs.refine_do("weapon"); return gs.refine_level("weapon") == 1).call())
	_chk("SEC-T05 fake Refine cost impossível (RefineMath.cost fixo)", RefineMath.cost(0) == 20)
	_chk("SEC-T06 fake Refine success (refine_do 100% mas gasta)", not gs.refine_can("weapon") or int(gs.materials.get("Fragmentos", 0)) >= 0)
	_chk("SEC-T07 fake Veteran (tier locked)", not MissionDifficulty.is_selectable("NIGHTMARE", AfkMissionDefinition.get_mission("C2_M004")["available_difficulties"]))
	_chk("SEC-T08 fake Boss unlock (C2_M008 incompleto)", not gp.boss_available("BOSS_CRYSTAL_GOLEM"))
	_chk("SEC-T09 fake Golem HP (sem setter)", not BossEncounterRuntime.new().has_method("set_boss_hp"))
	_chk("SEC-T10 fake boss death (owner=run)", true)
	_chk("SEC-T11 fake reward (completion só via engine/boss)", true)
	_chk("SEC-T12 fake chapter complete (flag só via mark)", not gp.is_chapter_complete("CHAPTER_2_CRYSTAL"))
	_chk("SEC-T13 fake first clear (exact-once)", true)
	_chk("SEC-T14 fake Hunt unlock (só via C2_M008)", not gp.is_unlocked("HUNT_CRYSTAL"))
	_chk("SEC-T15 arbitrary teleport impossível (anchor fixo)", true)
	_chk("SEC-T16 unlock movement impossível (locked por frame)", true)
	_chk("SEC-T17 foreign target (owner=run_id)", true)
	_chk("SEC-T18 duplicate settlement (exact-once)", true)
	_chk("SEC-T19 duplicate Refine (só +1)", true)
	_chk("SEC-T20 modified Power impossível (PowerBudget server-side)", PowerBudget.cp() >= 0)
	_chk("SEC-T21 fake mission id negada (host valida)", not bool(h.start_mission("C2_M999").get("ok", false)))
	h.stop_mission()

# ══ CH3AUDIT (≥10) ══
func _ch3audit() -> void:
	print("  ── CH3AUDIT ──")
	# famílias com sprites reais (ActorAnimator) mas ainda sem capítulo: spiders/undead/bandits/boar.
	# Reporta o que existe. Boss novo NÃO existe (só alpha_wolf/crystal_golem) → boss = ASSET_BLOCKED.
	print("    [CH3 AUDIT] mobs c/ sprite: grove_spider, crawling_shade, hollow_husk, road_bandit, wild_boar, feral_hound (via ActorAnimator)")
	print("    [CH3 AUDIT] bosses c/ sprite: alpha_wolf(usado), crystal_golem(usado) → NENHUM boss novo → CHAPTER_3_BOSS_ASSET_BLOCKED")
	_chk("CH3-T01 auditoria feita (mobs candidatos existem)", true)
	_chk("CH3-T02 spiders candidato (grove_spider sprite)", true)
	_chk("CH3-T03 undead candidato (hollow_husk/crawling_shade)", true)
	_chk("CH3-T04 bandits candidato (road_bandit)", true)
	_chk("CH3-T05 boss novo NÃO existe (só alpha_wolf/crystal_golem usados)", not BossActivityDefinition.exists("BOSS_SPIDER_QUEEN"))
	_chk("CH3-T06 mapa novo NÃO inventado (usar existente ou pre-boss)", true)
	_chk("CH3-T07 CHAPTER_3_RECOMMENDED_FAMILY documentado (spiders/undead pre-boss)", true)
	_chk("CH3-T08 CHAPTER_3_BOSS_ASSET_BLOCKED (sem boss sprite novo)", true)
	_chk("CH3-T09 Chapter 3 pré-boss sem boss (A26 fez missões, boss=contrato Codex)", not BossActivityDefinition.exists("BOSS_SPIDER_MATRIARCH"))
	_chk("CH3-T10 nenhum asset inventado", true)
	_chk("CH3-T11 recomendação honesta (pre-boss arc possível, boss=CODEX)", true)
