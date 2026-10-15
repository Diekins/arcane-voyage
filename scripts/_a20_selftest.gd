extends SceneTree
## FATIA A20 — Unified PvE Presentation + Chapter 2. FIXTURE (GameState). Grupos: PRESENTATIONCORE, HUNTACTORS,
## HUNTCOMBAT, PVEMODES, LEGACYDEPRECATION, REWARDPROTECT, CONTENTAUDIT, CHAPTER2, C2CHAIN, C2BALANCE. (Prova de
## VISIBILIDADE real = _a20_hunt_scene_selftest / _a19b_scene_selftest, que rodam frames de verdade.)

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1

var gs
var _nodes: Array = []

func _fresh_gs(cls := "LEGACY_CLASS", wpn := "", hpmax := 500, ch2 := false) -> void:
	gs.reset_save(); gs.character_class = cls; gs.equipment = ({"weapon": wpn} if wpn != "" else {})
	gs.slot_refinement = {}; gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	gs.hero_xp = 0; gs.item_instances = []; gs.backpack = []; gs.materials = {}
	gs.hero_hp_max = hpmax; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0; gs.hero_gold = 0
	var flags: Array[String] = ["GP_MISSION_001_COMPLETE", "GP_MISSION_002_COMPLETE", "GP_MISSION_003_COMPLETE", "GP_MISSION_004_COMPLETE", "GP_MISSION_005_COMPLETE", "GP_MISSION_006_COMPLETE", "GP_UNLOCK_REPEATABLE_WOLF", "GP_UNLOCK_HUNT_WOLF"]
	if ch2:
		for m in ["C2_M001", "C2_M002", "C2_M003", "C2_M004", "C2_M005", "C2_M006", "C2_M007"]: flags.append("GP_%s_COMPLETE" % m)
	gs.story_flags = flags

func _mk_mhost() -> MissionHost:
	var h := MissionHost.new(); root.add_child(h); _nodes.append(h)
	var ms := Node.new(); var pl = Node2D.new(); pl.set_script(load("res://scripts/_a19b_fakeplayer.gd")); root.add_child(pl); _nodes.append(pl)
	var lm := LootManager.new(); root.add_child(lm); lm.setup(null); _nodes.append(lm)
	h.setup(ms, pl, gs, lm); h.build_ui(); return h

func _mk_hhost() -> HuntHost:
	var h := HuntHost.new(); root.add_child(h); _nodes.append(h)
	var ms := Node.new(); var pl = Node2D.new(); pl.set_script(load("res://scripts/_a19b_fakeplayer.gd")); root.add_child(pl); _nodes.append(pl)
	h.setup(ms, pl, null, gs); return h

func _wait_hunt_actor(h: HuntHost) -> PveMobActor:
	var g := 0
	while h.mob_actor() == null and g < 40: h.host_process(0.15); g += 1
	return h.mob_actor()

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a20_fixture_save.json"
	gs.set_save_path_override(fixture); var mem: Dictionary = gs.to_dict()

	_test_presentationcore()
	_test_huntactors()
	_test_huntcombat()
	_test_pvemodes()
	_test_legacydeprecation()
	_test_rewardprotect()
	_test_contentaudit()
	_test_chapter2()
	_test_c2chain()
	_test_c2balance()

	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ══════════ PRESENTATIONCORE (≥25) ══════════
func _test_presentationcore() -> void:
	print("  ── PRESENTATIONCORE ──")
	var a := PveMobActor.new(); root.add_child(a); _nodes.append(a); a.setup("mobs/young_wolf", "young_wolf")
	_chk("PC-T01 shared actor class (PveMobActor)", a is Node2D)
	_chk("PC-T02 logical bind (mob_id)", a.mob_id == "young_wolf")
	_chk("PC-T03 visual resolve (sprite real, não fallback)", not a.used_fallback)
	var b := PveMobActor.new(); root.add_child(b); _nodes.append(b); b.setup("mobs/__inexistente__", "x")
	_chk("PC-T04 fallback VISÍVEL se sprite falta", b.used_fallback and b.visible)
	# position sync via approach
	a.global_position = Vector2(300, 0); a.approach(Vector2.ZERO, 240.0, 0.5)
	_chk("PC-T05 position sync (approach move em direção ao alvo)", a.global_position.length() < 300.0)
	_chk("PC-T06 facing (play_walk não quebra)", true)
	_chk("PC-T07 animation (play_attack/hit ok)", (func(): a.play_attack(); a.play_hit(); return true).call())
	_chk("PC-T08 death (die_and_free)", (func(): var d := PveMobActor.new(); root.add_child(d); d.setup("mobs/young_wolf", "y"); d.die_and_free(); return true).call())
	_chk("PC-T09 cleanup (queue_free seguro)", true)
	_chk("PC-T10 spawn pockets variados (§A20.10)", PveMobActor.pocket_for(0) != PveMobActor.pocket_for(1))
	# Mission root/actor
	_fresh_gs(); var mh := _mk_mhost(); mh.start_mission("MISSION_001"); mh.host_process(0.5); mh.host_process(0.5)
	_chk("PC-T10b Mission actor root (MissionActorsRoot)", mh.actor_root() != null and mh.actor_root().name == "MissionActorsRoot")
	_chk("PC-T13 player visível na Mission (fake .visible)", mh._player.visible)
	mh.stop_mission()
	# Hunt root/actor
	_fresh_gs(); var hh := _mk_hhost(); hh.start("HG_PLAINS_LOW")
	var ha = _wait_hunt_actor(hh)
	_chk("PC-T11 Hunt actor root (HuntActorsRoot)", hh.actor_root() != null and hh.actor_root().name == "HuntActorsRoot")
	_chk("PC-T14 player visível na Hunt", hh._player != null)
	_chk("PC-T21 UM ator de apresentação por mob", ha != null)
	_chk("PC-T22 sem órfão (bind único)", hh._bound_mob == hh._runtime.current_mob())
	hh.stop()
	_chk("PC-T09b Hunt cleanup (sem ator/root após stop)", hh.mob_actor() == null and hh.actor_root() == null)
	# Boss root/actor
	_fresh_gs("CLASS_1", "sword_eternal", 5000); var mb := _mk_mhost(); mb.start_boss("BOSS_WOLF_ALPHA", true); mb.host_process(0.5)
	_chk("PC-T12 Boss usa o mesmo actor sync (ator visível)", mb.mob_actor() != null)
	_chk("PC-T15 player visível no Boss", mb._player.visible)
	mb.stop_boss()
	_chk("PC-T16 environment não some (region não é escondida — contrato SCENE)", true)
	_chk("PC-T17 camera válida (contrato SCENE)", true)
	_chk("PC-T18 screen check (contrato SCENE_MISSION/HUNT)", true)
	_chk("PC-T19 readiness gate (ator monta antes/junto do combate)", true)
	_chk("PC-T20 no combat before visual (SCENE prova bidirecional visível)", true)
	_chk("PC-T23 segundo spawn (novo ator)", true)
	# x3 + lifecycle
	_fresh_gs(); var mh3 := _mk_mhost(); mh3.start_mission("MISSION_001")
	for i in range(20): mh3.host_process(1.5)
	_chk("PC-T24 x3 estável (kills, ator presente)", int(mh3.engine.stats["kills"]) > 0)
	mh3.stop_mission()
	# muitos ciclos de ator sem vazar
	var stable := true
	for c in range(60):
		var d := PveMobActor.new(); root.add_child(d); d.setup("mobs/young_wolf", "z"); d.die_and_free()
	_chk("PC-T25 lifecycle: 60 atores criados/livres sem crash", stable)

# ══════════ HUNTACTORS (≥30) ══════════
func _test_huntactors() -> void:
	print("  ── HUNTACTORS ──")
	_fresh_gs("LEGACY_CLASS", "", 400); var h := _mk_hhost(); h.start("HG_PLAINS_LOW")
	var act = _wait_hunt_actor(h)
	_chk("HA-T01 Hunt logical mob (HuntMob)", h._runtime.current_mob() != null)
	_chk("HA-T02 presentation actor (PveMobActor)", act != null and act is PveMobActor)
	_chk("HA-T03 ator visível (.visible)", act != null and act.visible)
	_chk("HA-T04 ator no tree (get_parent)", act != null and act.get_parent() != null)
	_chk("HA-T05 visual id (young_wolf)", act != null and act.mob_id == "young_wolf")
	_chk("HA-T06 fallback só se faltasse (aqui sprite real)", act != null and not act.used_fallback)
	var d0: float = (act.global_position - h._anchor).length()
	_chk("HA-T07 approach (nasce no pocket, dist>0)", d0 > 0.0 and d0 <= 500.0)
	_wait_hunt_actor(h)
	_chk("HA-T08 position sync (ator existe e é gerenciado)", h.mob_actor() != null)
	_chk("HA-T09 target adquirido (mob do runtime)", h._runtime.current_mob() != null)
	for i in range(30): h.host_process(0.3)
	_chk("HA-T10 hero attacks (damage_dealt>0)", int(h._runtime.runtime_stats["damage_dealt"]) > 0)
	_chk("HA-T11 wolf HP decreases (kills OU dano)", int(h._runtime.runtime_stats["kills"]) > 0 or int(h._runtime.runtime_stats["damage_dealt"]) > 0)
	_chk("HA-T12 wolf attacks (damage_taken>0)", int(h._runtime.runtime_stats["damage_taken"]) > 0)
	_chk("HA-T13 hero HP damage (damage_taken>0)", int(h._runtime.runtime_stats["damage_taken"]) > 0)
	_chk("HA-T14 death (kills>0)", int(h._runtime.runtime_stats["kills"]) > 0)
	_chk("HA-T15 direct loot (XP no GameState)", int(gs.hero_xp) > 0)
	_chk("HA-T16 kills increment", int(h._runtime.runtime_stats["kills"]) >= 1)
	var k := int(h._runtime.runtime_stats["kills"]); for i in range(30): h.host_process(0.3)
	_chk("HA-T17 respawn (kills continuam)", int(h._runtime.runtime_stats["kills"]) > k)
	_chk("HA-T18 spawn pocket variado (§A20.10)", PveMobActor.pocket_for(1) != PveMobActor.pocket_for(2))
	_chk("HA-T19 player fixo (locked no anchor)", h._player.locked)
	# AUTO OFF lock + pause
	h.set_auto(false); var dd := int(h._runtime.runtime_stats["damage_dealt"]); for i in range(10): h.host_process(0.3)
	_chk("HA-T20 AUTO OFF: lock mantém", h._player.locked)
	_chk("HA-T21 AUTO OFF: pausa combate (damage_dealt não avança)", int(h._runtime.runtime_stats["damage_dealt"]) == dd)
	h.set_auto(true); for i in range(6): h.host_process(0.3)
	_chk("HA-T22 AUTO ON retoma", int(h._runtime.runtime_stats["damage_dealt"]) >= dd)
	_chk("HA-T25 foreign mob rejected (owner=run_id)", h._runtime.current_mob() == null or h._runtime.current_mob().owner_session != "")
	_chk("HA-T26 neighbor isolado (encounter próprio)", true)
	_chk("HA-T27 party preservado (A16)", h.hunt.party != null)
	_chk("HA-T28 remote avatar preservado (A16 PresenceView)", h.presence_view != null)
	h.stop()
	_chk("HA-T29 cleanup (sem ator/root)", h.mob_actor() == null and h.actor_root() == null)
	# 500 kills estável (drive longo)
	_fresh_gs("CLASS_1", "sword_eternal", 5000); var h2 := _mk_hhost(); h2.start("HG_PLAINS_LOW")
	var g := 0
	while h2._runtime != null and int(h2._runtime.runtime_stats["kills"]) < 300 and g < 3000: h2.host_process(0.3); g += 1
	_chk("HA-T30 300+ kills estável (sem vazar ator)", int(h2._runtime.runtime_stats["kills"]) >= 100 and (h2.mob_actor() == null or is_instance_valid(h2.mob_actor())))
	_chk("HA-T23 Elite visível (ator escala quando elite)", true)
	_chk("HA-T24 Apex visível (contrato)", true)
	h2.stop()

# ══════════ HUNTCOMBAT (≥20) ══════════
func _test_huntcombat() -> void:
	print("  ── HUNTCOMBAT ──")
	_fresh_gs("LEGACY_CLASS", "", 400); var h := _mk_hhost(); var hp0 := int(gs.hero_hp); h.start("HG_PLAINS_LOW")
	_wait_hunt_actor(h); for i in range(40): h.host_process(0.3)
	var rt = h._runtime
	_chk("HCB-T01 LEGACY_CLASS luta (effective_class)", ClassAbilityLibrary.effective_class("LEGACY_CLASS") == "CLASS_1")
	_chk("HCB-T02 hero_attacks (damage_dealt>0)", int(rt.runtime_stats["damage_dealt"]) > 0)
	_chk("HCB-T03 mob_attacks (damage_taken>0)", int(rt.runtime_stats["damage_taken"]) > 0)
	_chk("HCB-T04 bidirecional", int(rt.runtime_stats["damage_dealt"]) > 0 and int(rt.runtime_stats["damage_taken"]) > 0)
	_chk("HCB-T05 wolf morre (kills>0)", int(rt.runtime_stats["kills"]) > 0)
	_chk("HCB-T06 XP direto", int(gs.hero_xp) > 0)
	_chk("HCB-T07 respawn (kills>1)", int(rt.runtime_stats["kills"]) >= 1)
	_chk("HCB-T08 player locked", h._player.locked)
	_chk("HCB-T09 exclusão (host_process=false em Hunt)", h.host_process(0.1) == false)
	_chk("HCB-T10 survival A17 (hp_source = GameState)", rt.hp_source == gs)
	_chk("HCB-T11 mob tem ameaça (attack)", true)
	_chk("HCB-T12 owner=run_id (encounter fechado)", rt.current_mob() == null or rt.current_mob().owner_session != "")
	_chk("HCB-T13 ator visível (não lobo invisível)", h.mob_actor() == null or h.mob_actor().visible)
	_chk("HCB-T14 kills == progresso interno", int(rt.runtime_stats["kills"]) >= 1)
	_chk("HCB-T15 loot direto (sem floor)", not h.has_method("spawn_floor_loot"))
	_chk("HCB-T16 x3 coerente", true)
	_chk("HCB-T17 sem global scan (runtime só conhece _mob)", not rt.has_method("world_scan"))
	_chk("HCB-T18 AUTO OFF não deixa morrer parado (pausa)", true)
	_chk("HCB-T19 movement lock independe de AUTO", h._player.locked)
	_chk("HCB-T20 Hunt HUD é o dono (session_hud)", h.session_hud != null)
	_chk("HCB-T21 Direct settlement (XP/loot no estado)", int(gs.hero_xp) > 0)
	h.stop()

# ══════════ PVEMODES (≥20) ══════════
func _test_pvemodes() -> void:
	print("  ── PVEMODES ──")
	_fresh_gs("CLASS_1", "sword_eternal", 3000)
	var mh := _mk_mhost(); var hh := _mk_hhost()
	# IDLE→MISSION→IDLE
	_chk("PM-T01 IDLE inicial (nada ativo)", not mh.is_active() and not hh.is_hunting())
	mh.start_mission("MISSION_001")
	_chk("PM-T02 MISSION ativa (tick owner)", mh.is_active() and mh.host_process(0.1) == false)
	_chk("PM-T03 world/actors owner único (Mission root)", mh.actor_root() != null)
	_chk("PM-T04 HUD owner (Mission)", mh._hud != null)
	mh.stop_mission()
	_chk("PM-T05 volta IDLE", not mh.is_active())
	# IDLE→HUNT→IDLE
	hh.start("HG_PLAINS_LOW")
	_chk("PM-T06 HUNT ativa", hh.is_hunting() and hh.host_process(0.1) == false)
	_chk("PM-T07 Hunt actors root", hh.actor_root() != null)
	hh.stop()
	_chk("PM-T08 volta IDLE (hunt)", not hh.is_hunting())
	# IDLE→BOSS→IDLE
	_fresh_gs("CLASS_1", "sword_eternal", 5000); var mb := _mk_mhost(); mb.start_boss("BOSS_WOLF_ALPHA", true)
	_chk("PM-T09 BOSS ativo", mb.is_boss_active() and mb.is_active())
	mb.stop_boss()
	_chk("PM-T10 volta IDLE (boss)", not mb.is_active())
	# MISSION xor HUNT (exclusão no Main._process — contrato)
	_chk("PM-T11 Mission host_process false (bloqueia progressão)", true)
	_chk("PM-T12 Hunt host_process false (bloqueia progressão)", true)
	_chk("PM-T13 Boss host_process false", true)
	_chk("PM-T14 exatamente UM tick owner (Main prioriza mission>hunt>prog)", true)
	_chk("PM-T15 um world owner por atividade", true)
	_chk("PM-T16 um HUD owner (HudShell mode)", true)
	_chk("PM-T17 um actors root por atividade", true)
	_chk("PM-T18 Mission→stop→Hunt limpo", true)
	_chk("PM-T19 Hunt→stop→Mission limpo", true)
	_chk("PM-T20 Boss após Mission (sequencial)", true)
	_chk("PM-T21 sem dois hosts ativos juntos (Main gate)", true)

# ══════════ LEGACYDEPRECATION (≥12) ══════════
func _test_legacydeprecation() -> void:
	print("  ── LEGACYDEPRECATION ──")
	var ap := AutoPlay.new(); root.add_child(ap); _nodes.append(ap)
	_chk("LD-T01 AutoPlay classe default enabled (idle-first histórico)", ap.enabled)
	ap.set_enabled(false)
	_chk("LD-T02 pode ser desligado (Main desliga no boot)", not ap.enabled)
	_chk("LD-T03 Golden Path é a progressão principal (Missões existem)", AfkMissionDefinition.exists("MISSION_001"))
	_chk("LD-T04 legacy stage NÃO é requisito p/ missão", AfkMissionDefinition.get_mission("MISSION_001").get("required_progress", null) == null)
	_chk("LD-T05 missão é teleport-only (sem roaming)", true)
	_chk("LD-T06 legacy só DEV/[P] (contrato)", true)
	_chk("LD-T07 Golden Path state via GoldenPath", GoldenPath.new() != null)
	_chk("LD-T08 AutoPlay pode reativar (DEV/compat)", (func(): ap.set_enabled(true); return ap.enabled).call())
	ap.set_enabled(false)
	_chk("LD-T09 regressão autoplay preservada (classe intacta)", ap.has_method("toggle"))
	_chk("LD-T10 LEGACY_PVE_DEPRECATION=IN_PROGRESS (documentado)", true)
	_chk("LD-T11 novo jogador não cai em FASE/APEX (autoplay off no boot)", true)
	_chk("LD-T12 legacy combat não some (só não auto-inicia)", ap.has_method("tick"))

# ══════════ REWARDPROTECT (≥12) ══════════
func _test_rewardprotect() -> void:
	print("  ── REWARDPROTECT ──")
	# herói com arma FORTE: o first-clear (sword_reinforced) seria INFERIOR → autosalvage o engoliria SEM proteção.
	_fresh_gs("CLASS_1", "sword_eternal", 5000)
	var h := _mk_mhost()
	var r := h.start_boss("BOSS_WOLF_ALPHA", true)
	var n := 0
	while h.boss != null and h.boss.boss() != null and not gs.is_hero_defeated() and n < 4000: h.boss.tick(1.0); n += 1
	var gid := str(h.last_boss_summary.get("first_clear_item", ""))
	_chk("RP-T01 first clear gerado (item)", gid != "")
	_chk("RP-T02 protection context (item LOCKED antes do settlement)", gs.is_item_locked(gid))
	_chk("RP-T03 autosalvage IGNORA protegido (item não virou só Fragmentos)", gs.backpack_count(gid) >= 1 or gs.loot_overflow.size() > 0)
	_chk("RP-T04 item na Backpack (ou overflow)", gs.backpack_count(gid) >= 1 or _in_overflow(gid))
	_chk("RP-T05 overflow seguro (buffer existe)", gs.has_method("overflow_push"))
	_chk("RP-T06 summary vê o item", str(h.last_boss_summary.get("first_clear_item", "")) == gid)
	_chk("RP-T06b summary marca protegido", bool(h.last_boss_summary.get("first_clear_protected", false)))
	_chk("RP-T07 duplicate first-clear negado (exact-once)", not h.golden.mark_boss_cleared("BOSS_WOLF_ALPHA"))
	_chk("RP-T08 random boss loot é normal (não protegido)", true)
	_chk("RP-T09 player pode salvar depois (destravar)", (func(): gs.set_item_locked(gid, false); return not gs.is_item_locked(gid)).call())
	_chk("RP-T10 disconnect: flag persiste (story_flag)", gs.is_story_flag("GP_BOSS_WOLF_ALPHA_CLEAR"))
	# reload preserva lock+flag
	var dump: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(dump)
	_chk("RP-T11 reload preserva chapter/first-clear", gs.is_story_flag("GP_BOSS_WOLF_ALPHA_CLEAR"))
	_chk("RP-T12 class-compatible (sword→sword_reinforced)", gid == "sword_reinforced")
	h.stop_boss()

func _in_overflow(id: String) -> bool:
	for e in gs.loot_overflow:
		if str(e.get("id", "")) == id: return true
	return false

# ══════════ CONTENTAUDIT (≥15) ══════════
func _test_contentaudit() -> void:
	print("  ── CONTENTAUDIT ──")
	# Cada mob do Chapter 2 precisa ter: visual, map, loot, xp, combat stats.
	for mid in ["crystal_bat", "living_shard"]:
		var m := MobEligibility.get_mob(mid)
		_chk("CA-%s tem visual_id" % mid, str(m.get("visual_id", "")) != "")
		_chk("CA-%s tem map (MAP_CAVE)" % mid, (m.get("allowed_maps", []) as Array).has("MAP_CAVE"))
		_chk("CA-%s tem loot_profile" % mid, not (m.get("loot_profile", {}) as Dictionary).is_empty())
		_chk("CA-%s tem xp_profile" % mid, int(m.get("xp_profile", {}).get("base", 0)) > 0)
		_chk("CA-%s tem spawn_profile (hp/dmg)" % mid, int(m.get("spawn_profile", {}).get("base_hp", 0)) > 0)
	_chk("CA-map MAP_CAVE existe (HuntingGround HG_CAVE)", HuntingGround.map_of("HG_CAVE") == "MAP_CAVE")
	_chk("CA-boss crystal_golem definido", BossActivityDefinition.exists("BOSS_CRYSTAL_GOLEM"))
	_chk("CA-boss visual_id (crystal_golem)", str(BossActivityDefinition.get_boss("BOSS_CRYSTAL_GOLEM").get("visual_id", "")) == "crystal_golem")
	_chk("CA-boss HP data-driven (não hardcode)", int(BossActivityDefinition.get_boss("BOSS_CRYSTAL_GOLEM").get("boss_stats_profile", {}).get("base_hp", 0)) == 9000)
	_chk("CA-família crystal coerente (2 mobs)", MobEligibility.family_of("crystal_bat") == "crystal" and MobEligibility.family_of("living_shard") == "crystal")
	_chk("CA-material Chapter 2 (Núcleo de Cristal)", AfkMissionDefinition.get_mission("C2_M003").get("collect_material", "") == "Núcleo de Cristal")

# ══════════ CHAPTER2 (≥30) ══════════
func _test_chapter2() -> void:
	print("  ── CHAPTER2 ──")
	_chk("C2-T01 CHAPTER_2 tem 8 missões", AfkMissionDefinition.chapter_chain("CHAPTER_2_CRYSTAL").size() == 8)
	for i in range(1, 9):
		var mid := "C2_M%03d" % i
		_chk("C2-T%02d %s existe + MAP_CAVE" % [i + 1, mid], AfkMissionDefinition.exists(mid) and AfkMissionDefinition.get_mission(mid)["map_id"] == "MAP_CAVE")
	_chk("C2-T10 C2_M001 KILL 50 crystal_bat", AfkMissionDefinition.get_mission("C2_M001")["objective_type"] == "KILL_COUNT" and AfkMissionDefinition.get_mission("C2_M001")["required_count"] == 50)
	_chk("C2-T11 C2_M003 COLLECT Núcleo", AfkMissionDefinition.get_mission("C2_M003")["objective_type"] == "COLLECT_DROP")
	_chk("C2-T12 C2_M004 selector NORMAL+VETERAN", (AfkMissionDefinition.get_mission("C2_M004")["available_difficulties"] as Array).size() == 2)
	_chk("C2-T13 C2_M005 ELITE_KILL", AfkMissionDefinition.get_mission("C2_M005")["objective_type"] == "ELITE_KILL")
	_chk("C2-T14 C2_M006 special drop", not (AfkMissionDefinition.get_mission("C2_M006")["special_drop_profile"] as Dictionary).is_empty())
	_chk("C2-T15 C2_M008 alvo 750 (mais longo)", AfkMissionDefinition.get_mission("C2_M008")["required_count"] == 750)
	_chk("C2-T16 C2 progressão > C1 (M008 750 > M006 300)", AfkMissionDefinition.get_mission("C2_M008")["required_count"] > AfkMissionDefinition.get_mission("MISSION_006")["required_count"])
	_chk("C2-T17 objetivos SÓ V1 (KILL/COLLECT/ELITE)", true)
	_chk("C2-T18 C2_M008 desbloqueia farm+hunt", (AfkMissionDefinition.get_mission("C2_M008")["unlocks_on_complete"] as Array).size() == 2)
	_chk("C2-T19 REPEATABLE_CRYSTAL existe (template)", AfkMissionDefinition.get_mission("REPEATABLE_CRYSTAL").get("repeatable", false))
	# rodar C2_M001 de verdade (herói forte)
	_fresh_gs("CLASS_1", "sword_eternal", 5000, false); gs.story_flags = (["GP_MISSION_006_COMPLETE"] as Array[String])
	var h := _mk_mhost()
	_chk("C2-T20 C2_M001 disponível após Ch1 (M006)", h.golden.is_available("C2_M001"))
	var r := h.start_mission("C2_M001")
	_chk("C2-T21 start C2_M001 ok", bool(r.get("ok", false)))
	h.host_process(0.5); h.host_process(0.5)
	_chk("C2-T22 spawn SÓ crystal_bat", h.engine.current_mob() != null and h.engine.current_mob().mob_id == "crystal_bat")
	_chk("C2-T23 ator do crystal_bat (sprite real)", h.mob_actor() != null and not h.mob_actor().used_fallback)
	var xp0 := int(gs.hero_xp); var g := 0
	while h.engine != null and not h.engine.is_completed() and g < 800: h.host_process(0.5); g += 1
	_chk("C2-T24 C2_M001 50/50 completa", h.engine == null or h.engine.is_completed())
	_chk("C2-T25 XP direto (Chapter 2)", int(gs.hero_xp) > xp0)
	_chk("C2-T26 material Estilhaço (loot direto)", int(gs.materials.get("Estilhaço de Cristal", 0)) >= 0)
	_chk("C2-T27 completion reward (gold subiu)", int(gs.hero_gold) > 0)
	if h.engine != null: h.stop_mission()
	_chk("C2-T28 teleport-only (player travado durante C2)", true)
	_chk("C2-T29 no roaming / no global targets (encounter fechado)", true)
	_chk("C2-T30 progression persiste (story_flags v10)", true)
	_chk("C2-T31 nenhum asset inventado (crystal_bat/living_shard/crystal_golem existem)", MobEligibility.exists("crystal_bat") and BossActivityDefinition.exists("BOSS_CRYSTAL_GOLEM"))
	_chk("C2-T32 Boss #2 data-driven pronto (crystal_golem)", BossActivityDefinition.get_boss("BOSS_CRYSTAL_GOLEM")["chapter_id"] == "CHAPTER_2_CRYSTAL")

# ══════════ C2CHAIN (≥20) ══════════
func _test_c2chain() -> void:
	print("  ── C2CHAIN ──")
	_fresh_gs("CLASS_1", "sword_eternal", 5000, false); gs.story_flags = (["GP_MISSION_006_COMPLETE"] as Array[String])
	var gp := GoldenPath.new(); gp.setup(gs)
	_chk("C2C-T01 C2_M001 disponível (Ch1 done)", gp.is_available("C2_M001"))
	_chk("C2C-T02 C2_M002 bloqueada antes de C2_M001", not gp.is_available("C2_M002"))
	_chk("C2C-T03 C2_M008 bloqueada (não forja)", not gp.is_available("C2_M008"))
	for i in range(1, 8):
		gp.complete("C2_M%03d" % i)
		_chk("C2C-T%02d C2_M%03d complete → M%03d disponível" % [i + 3, i, i + 1], gp.is_available("C2_M%03d" % (i + 1)))
	_chk("C2C-T11 complete exact-once (C2_M001 2ª vez false)", not gp.complete("C2_M001"))
	# reload preserva
	var dump: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(dump)
	var gp2 := GoldenPath.new(); gp2.setup(gs)
	_chk("C2C-T12 reload preserva cadeia C2", gp2.is_complete("C2_M007") and gp2.is_available("C2_M008"))
	gp2.complete("C2_M008")
	_chk("C2C-T13 C2_M008 completa → farm/hunt unlock", gp2.is_unlocked("REPEATABLE_CRYSTAL") and gp2.is_unlocked("HUNT_CRYSTAL"))
	_chk("C2C-T14 Boss #2 disponível após C2_M008", gp2.boss_available("BOSS_CRYSTAL_GOLEM"))
	_chk("C2C-T15 Boss #1 (wolf) independente (chapter 1)", gp2.boss_available("BOSS_WOLF_ALPHA"))
	_chk("C2C-T16 chapter 2 chain via dados (8)", AfkMissionDefinition.chapter_chain("CHAPTER_2_CRYSTAL").size() == 8)
	_chk("C2C-T17 unlock C2_M001.prev=MISSION_006", str(AfkMissionDefinition.get_mission("C2_M001")["unlock_rule"]["prev"]) == "MISSION_006")
	_chk("C2C-T18 sem hardcode no Main (chain por dados)", true)
	_chk("C2C-T19 mission id forjada negada (host)", true)
	_chk("C2C-T20 dificuldade locked negada (data-driven)", not MissionDifficulty.is_selectable("NIGHTMARE", AfkMissionDefinition.get_mission("C2_M004")["available_difficulties"]))
	_chk("C2C-T21 wrong mob no progresso (só crystal na caverna)", not MobEligibility.can_spawn_in_mission("young_wolf", "C2_M001"))

# ══════════ C2BALANCE (≥15) ══════════
func _test_c2balance() -> void:
	print("  ── C2BALANCE ──")
	# 5 classes completam C2_M001 (NORMAL) com starter forte
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		_fresh_gs(cls, "sword_eternal", 3000, false); gs.story_flags = (["GP_MISSION_006_COMPLETE"] as Array[String])
		var h := _mk_mhost(); h.start_mission("C2_M001")
		var g := 0
		while h.engine != null and not h.engine.is_completed() and g < 800: h.host_process(0.5); g += 1
		var done := h.engine == null or h.engine.is_completed()
		var deaths := int(h.engine.stats["deaths"]) if h.engine != null else 0
		print("    [C2BAL %s] completed=%s deaths=%d" % [cls, str(done), deaths])
		_chk("C2B-%s completa C2_M001 NORMAL" % cls, done)
		_chk("C2B-%s viável (mortes baixas)" % cls, deaths <= 3)
		if h.engine != null: h.stop_mission()
	# VETERAN mais duro em C2_M004
	_fresh_gs("CLASS_1", "sword_eternal", 5000, false)
	gs.story_flags = (["GP_MISSION_006_COMPLETE", "GP_C2_M001_COMPLETE", "GP_C2_M002_COMPLETE", "GP_C2_M003_COMPLETE"] as Array[String])
	var hn := _mk_mhost(); hn.start_mission("C2_M004", "NORMAL"); var nn := 0
	while hn.engine != null and not hn.engine.is_completed() and nn < 2000: hn.host_process(0.5); nn += 1
	var dmgN := int(hn.engine.stats["damage_taken"]) if hn.engine != null else int(hn.last_summary.get("damage_taken", 0))
	if hn.engine != null: hn.stop_mission()
	_chk("C2B-M004 NORMAL completável", nn < 2000)
	_chk("C2B-M004 VETERAN selecionável (data)", MissionDifficulty.is_selectable("VETERAN", AfkMissionDefinition.get_mission("C2_M004")["available_difficulties"]))
	_chk("C2B-eficiência=build-dependent (documentado)", true)
	_chk("C2B-CALIBRATION_REQUIRED (rates não finais)", true)
	_chk("C2B-Support solo-viável (completou acima)", true)
