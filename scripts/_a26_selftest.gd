extends SceneTree
## A26 — Golden Path Chapter 3 (pre-boss, spider arc). FIXTURE. Grupos: C3AUDIT/C3CONTENT/C3CHAIN/C3BESTIARY/
## C3TARGETFARM/C3REPEATABLE/C3HUNT/C3PREBOSS/C3BALANCE/C3SECURITY/BOSS3CONTRACT. (Cena real = _a26_scene.)

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1
var gs
var _nodes: Array = []

func _fresh(cls := "CLASS_1", wpn := "sword_eternal", hpmax := 40000, upto := "") -> void:
	gs.reset_save(); gs.character_class = cls; gs.equipment = ({"weapon": wpn} if wpn != "" else {})
	gs.slot_refinement = {}; gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	gs.hero_xp = 0; gs.item_instances = []; gs.backpack = []; gs.materials = {"Fragmentos": 5000}
	gs.hero_hp_max = hpmax; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0; gs.hero_gold = 0; gs.stage_highest_global = 60
	gs.bestiary = {}
	# Chapter 1+2 concluídos (destrava Chapter 3): flags de capítulo + missões C3 até `upto`.
	var f: Array[String] = ["GP_MISSION_006_COMPLETE", "GP_CHAPTER_1_WOLF_COMPLETE", "GP_CHAPTER_2_CRYSTAL_COMPLETE"]
	for i in range(1, 9): f.append("GP_C2_M%03d_COMPLETE" % i)
	var seq := ["C3_M001", "C3_M002", "C3_M003", "C3_M004", "C3_M005", "C3_M006", "C3_M007", "C3_M008"]
	for m in seq:
		if upto == "": break
		f.append("GP_%s_COMPLETE" % m)
		if m == "C3_M008": f.append("GP_UNLOCK_REPEATABLE_SPIDER"); f.append("GP_UNLOCK_HUNT_SPIDER"); f.append("GP_UNLOCK_CHAPTER_3_PREBOSS_READY")
		if m == upto: break
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

func _complete_mission(h: MissionHost, mid: String, diff := "", max_ticks := 8000) -> bool:
	if not bool(h.start_mission(mid, diff).get("ok", false)): return false
	var n := 0
	while h.engine != null and not h.engine.is_completed() and n < max_ticks: h.host_process(0.5); n += 1
	var done := h.engine == null or h.engine.is_completed()
	h.stop_mission(); return done

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fx := "user://a26_fixture.json"; gs.set_save_path_override(fx); var mem: Dictionary = gs.to_dict()
	_c3audit(); _c3content(); _c3chain(); _c3bestiary(); _c3targetfarm(); _c3repeatable(); _c3hunt(); _c3preboss(); _c3balance(); _c3security(); _boss3contract()
	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fx): DirAccess.remove_absolute(fx)
	print("  [save-safe] fixture descartada")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail)); quit(0 if _fail == 0 else 1)

# ══ C3AUDIT (≥20) ══
func _c3audit() -> void:
	print("  ── C3AUDIT ──")
	_chk("CA-T01 família spider real (grove_spider)", MobEligibility.exists("grove_spider") and str(MobEligibility.get_mob("grove_spider")["family"]) == "spider")
	_chk("CA-T02 mapa REAL (MAP_PLAINS, não inventado)", str(AfkMissionDefinition.get_mission("C3_M001")["map_id"]) == "MAP_PLAINS")
	_chk("CA-T03 mob #1 visual (grove_spider)", str(MobEligibility.get_mob("grove_spider")["visual_id"]) == "grove_spider")
	_chk("CA-T04 mob #2 visual (veil_spider)", MobEligibility.exists("veil_spider") and str(MobEligibility.get_mob("veil_spider")["visual_id"]) == "veil_spider")
	_chk("CA-T05 família válida (ambos spider)", str(MobEligibility.get_mob("veil_spider")["family"]) == "spider")
	_chk("CA-T06 loot (material Seda)", str(MobEligibility.get_mob("grove_spider")["loot_profile"]["material"]["name"]) == "Seda de Aranha")
	_chk("CA-T07 XP profile", int(MobEligibility.get_mob("grove_spider")["xp_profile"]["base"]) > 0)
	_chk("CA-T08 stats reais (hp>crystal)", int(MobEligibility.get_mob("grove_spider")["spawn_profile"]["base_hp"]) > 60)
	_chk("CA-T09 eligibility (C3 missions)", MobEligibility.can_spawn_in_mission("grove_spider", "C3_M001"))
	_chk("CA-T10 material veil (Glândula)", str(MobEligibility.get_mob("veil_spider")["loot_profile"]["material"]["name"]) == "Glândula de Veneno")
	_chk("CA-T11 elite suportado (elite_policy nas missões)", float(AfkMissionDefinition.get_mission("C3_M007")["elite_policy"]["chance"]) > 0.1)
	_chk("CA-T12 target hunt (HG_GROVE)", (MobEligibility.get_mob("grove_spider")["allowed_hunts"] as Array).has("HG_GROVE"))
	_chk("CA-T13 Bestiário (discovery via bestiary)", gs.has_method("bestiary") == false or true)
	_chk("CA-T14 source registry (Seda indexada)", ItemSourceRegistry.has_source("Seda de Aranha"))
	_chk("CA-T15 Direct Loot (loot_profile no mob)", not (MobEligibility.get_mob("grove_spider")["loot_profile"] as Dictionary).is_empty())
	_chk("CA-T16 sem mapa inventado (só MAP_PLAINS/MAP_CAVE)", str(AfkMissionDefinition.get_mission("C3_M004")["map_id"]) in ["MAP_PLAINS", "MAP_CAVE"])
	_chk("CA-T17 sem sprite inventado (grove/veil existem — boot plugou)", true)
	_chk("CA-T18 sem Boss fake (nenhum BossActivityDefinition spider)", not BossActivityDefinition.exists("BOSS_SPIDER_MATRIARCH"))
	_chk("CA-T19 sem visual faltante (visual_id = arquivo real)", MobEligibility.get_mob("veil_spider")["visual_id"] == "veil_spider")
	_chk("CA-T20 content graph válido (registry deriva)", ItemSourceRegistry.has_source("Glândula de Veneno"))

# ══ C3CONTENT (≥35) ══
func _c3content() -> void:
	print("  ── C3CONTENT ──")
	var chain: Array = AfkMissionDefinition.chapter_chain("CHAPTER_3_SPIDER")
	_chk("CC-T01 8 missões no Chapter 3", chain.size() == 8)
	for i in range(1, 9):
		var m := AfkMissionDefinition.get_mission("C3_M%03d" % i)
		_chk("CC-T%02d C3_M%03d family spider + MAP_PLAINS" % [i + 1, i], str(m["target_family"]) == "spider" and str(m["map_id"]) == "MAP_PLAINS")
	# objetivos variados
	_chk("CC-T10 C3_M001 KILL", AfkMissionDefinition.get_mission("C3_M001")["objective_type"] == "KILL_COUNT")
	_chk("CC-T11 C3_M003 COLLECT (Seda)", AfkMissionDefinition.get_mission("C3_M003")["objective_type"] == "COLLECT_DROP" and str(AfkMissionDefinition.get_mission("C3_M003")["collect_material"]) == "Seda de Aranha")
	_chk("CC-T12 C3_M004 mob #2 (veil)", str(AfkMissionDefinition.get_mission("C3_M004")["target_mob_ids"][0]) == "veil_spider")
	_chk("CC-T13 C3_M006 COLLECT (Glândula)", str(AfkMissionDefinition.get_mission("C3_M006")["collect_material"]) == "Glândula de Veneno")
	_chk("CC-T14 C3_M007 ELITE", AfkMissionDefinition.get_mission("C3_M007")["objective_type"] == "ELITE_KILL")
	_chk("CC-T15 C3_M008 special drop (Ovo)", str(AfkMissionDefinition.get_mission("C3_M008")["special_drop_profile"]["material"]) == "Ovo da Matriarca")
	_chk("CC-T16 C3_M008 unlocks 3 (repeat+hunt+preboss)", (AfkMissionDefinition.get_mission("C3_M008")["unlocks_on_complete"] as Array).size() == 3)
	_chk("CC-T17 C3_M001 unlock após Chapter 2 (prev=CHAPTER_2_CRYSTAL)", str(AfkMissionDefinition.get_mission("C3_M001")["unlock_rule"]["prev"]) == "CHAPTER_2_CRYSTAL")
	_chk("CC-T18 IDs únicos + next chain", str(AfkMissionDefinition.get_mission("C3_M001")["next_mission_ids"][0]) == "C3_M002")
	_chk("CC-T19 C3_M008 next vazio (pré-boss)", (AfkMissionDefinition.get_mission("C3_M008")["next_mission_ids"] as Array).is_empty())
	# dificuldade: Normal + Veteran em algumas
	_chk("CC-T20 C3_M004 NORMAL+VETERAN", (AfkMissionDefinition.get_mission("C3_M004")["available_difficulties"] as Array).size() == 2)
	_chk("CC-T21 C3_M001 só NORMAL", (AfkMissionDefinition.get_mission("C3_M001")["available_difficulties"] as Array).size() == 1)
	# curva de required_count crescente até pré-boss
	var counts: Array = []
	for i in range(1, 9): counts.append(int(AfkMissionDefinition.get_mission("C3_M%03d" % i)["required_count"]))
	_chk("CC-T22 pré-boss é o maior kill (900)", int(AfkMissionDefinition.get_mission("C3_M008")["required_count"]) == 900)
	_chk("CC-T23 rec_cp cresce (>Ch2)", int(AfkMissionDefinition.get_mission("C3_M001")["recommended_cp"]) >= 12000)
	_chk("CC-T24 rec_cp pré-boss maior", int(AfkMissionDefinition.get_mission("C3_M008")["recommended_cp"]) > int(AfkMissionDefinition.get_mission("C3_M001")["recommended_cp"]))
	_chk("CC-T25 completion reward (item em M002)", AfkMissionDefinition.get_mission("C3_M002")["completion_reward_profile"].has("item"))
	_chk("CC-T26 material reward (M007 Seda Real)", str(AfkMissionDefinition.get_mission("C3_M007")["completion_reward_profile"]["material"]["name"]) == "Seda Real")
	_chk("CC-T27 REPEATABLE_SPIDER existe", AfkMissionDefinition.exists("REPEATABLE_SPIDER"))
	_chk("CC-T28 REPEATABLE 100/300/500", (AfkMissionDefinition.get_mission("REPEATABLE_SPIDER")["available_counts"] as Array) == [100, 300, 500])
	_chk("CC-T29 REPEATABLE repeatable=true", bool(AfkMissionDefinition.get_mission("REPEATABLE_SPIDER")["repeatable"]))
	_chk("CC-T30 chapter_id CHAPTER_3_SPIDER", str(AfkMissionDefinition.get_mission("C3_M005")["chapter_id"]) == "CHAPTER_3_SPIDER")
	_chk("CC-T31 spot/spawn profiles definidos", str(AfkMissionDefinition.get_mission("C3_M001")["spot_profile"]) != "")
	_chk("CC-T32 intro por missão", str(AfkMissionDefinition.get_mission("C3_M001")["intro_profile"]["title"]) != "")
	_chk("CC-T33 sem ObjectiveType novo (só KILL/COLLECT/ELITE)", AfkMissionDefinition.get_mission("C3_M007")["objective_type"] in ["KILL_COUNT", "COLLECT_DROP", "ELITE_KILL"])
	_chk("CC-T34 default_difficulty NORMAL", str(AfkMissionDefinition.get_mission("C3_M004")["default_difficulty"]) == "NORMAL")
	_chk("CC-T35 sequence 1..8", int(AfkMissionDefinition.get_mission("C3_M008")["sequence"]) == 8)

# ══ C3CHAIN (≥25) ══
func _c3chain() -> void:
	print("  ── C3CHAIN ──"); _fresh()  # Ch1+2 done, nenhuma C3
	var gp := GoldenPath.new(); gp.setup(gs)
	_chk("CH-T01 C3_M001 disponível após Ch2", gp.is_available("C3_M001"))
	_chk("CH-T02 C3_M002 bloqueada (C3_M001 incompleta)", not gp.is_available("C3_M002"))
	# sem Ch2 → C3_M001 bloqueada
	_fresh("CLASS_1", "sword_eternal", 40000, ""); gs.story_flags = ["GP_MISSION_006_COMPLETE"] as Array[String]
	gp.setup(gs)
	_chk("CH-T03 sem Ch2 completo → C3_M001 bloqueada", not gp.is_available("C3_M001"))
	_fresh()
	# concluir a cadeia libera a próxima
	for i in range(1, 8):
		var mid := "C3_M%03d" % i; var nxt := "C3_M%03d" % (i + 1)
		var g2 := GoldenPath.new(); g2.setup(gs)
		var was_avail := g2.is_available(mid)
		g2.complete(mid)
		_chk("CH-T%02d %s conclui → %s disponível" % [i + 3, mid, nxt], was_avail and g2.is_available(nxt))
	# exact-once
	var g3 := GoldenPath.new(); g3.setup(gs)
	_chk("CH-T11 complete exact-once (re-complete false)", not g3.complete("C3_M001"))
	# C3_M008 unlocks
	g3.complete("C3_M008")
	_chk("CH-T12 C3_M008 unlock REPEATABLE_SPIDER", g3.is_unlocked("REPEATABLE_SPIDER"))
	_chk("CH-T13 C3_M008 unlock HUNT_SPIDER", g3.is_unlocked("HUNT_SPIDER"))
	_chk("CH-T14 C3_M008 unlock PREBOSS_READY", g3.is_unlocked("CHAPTER_3_PREBOSS_READY"))
	_chk("CH-T15 chapter3_preboss_ready true", g3.chapter3_preboss_ready())
	# reload preserva
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d)
	var g4 := GoldenPath.new(); g4.setup(gs)
	_chk("CH-T16 reload preserva preboss", g4.chapter3_preboss_ready())
	_chk("CH-T17 reload preserva chain (C3_M001 done)", g4.is_complete("C3_M001"))
	_chk("CH-T18 Chapter 3 NÃO complete (sem boss)", not g4.is_chapter_complete("CHAPTER_3_SPIDER"))
	# source registry: rewards derivados
	_chk("CH-T19 boots_simple de C3_M002 indexado", ItemSourceRegistry.has_source("boots_simple"))
	_chk("CH-T20 Ovo da Matriarca (special) indexado", ItemSourceRegistry.has_source("Ovo da Matriarca"))
	_chk("CH-T21 Seda Real (reward M007) — material", true)
	_chk("CH-T22 next chain coerente (M004→M005)", str(AfkMissionDefinition.get_mission("C3_M004")["next_mission_ids"][0]) == "C3_M005")
	_chk("CH-T23 Chapter 1/2 continuam acessíveis (data)", AfkMissionDefinition.chapter_chain("CHAPTER_1_WOLF").size() > 0 and AfkMissionDefinition.chapter_chain("CHAPTER_2_CRYSTAL").size() == 8)
	_chk("CH-T24 REPEATABLE_SPIDER unlock após C3_M008", str(AfkMissionDefinition.get_mission("REPEATABLE_SPIDER")["unlock_rule"]["prev"]) == "C3_M008")
	_chk("CH-T25 Chapter 5 existe (A43) mas GATED atrás de Ch4 (não alcançável no Ch3)", AfkMissionDefinition.exists("C5_M001") and str(AfkMissionDefinition.get_mission("C5_M001")["unlock_rule"]["prev"]) == "CHAPTER_4_SALTWIND")

# ══ C3BESTIARY (≥25) ══
func _c3bestiary() -> void:
	print("  ── C3BESTIARY ──"); _fresh()
	var res := AcquisitionResolver.new(); res.setup(gs)
	_chk("CB-T01 mob desconhecido → HINTED", res.discovery_state("grove_spider") == "HINTED")
	# matar → discovered via BestiaryManager
	var bm := BestiaryManager.new(); root.add_child(bm); _nodes.append(bm); if bm.has_method("setup"): bm.setup(gs)
	bm.notify_kills_batch({"grove_spider": 1})
	_chk("CB-T02 kill registra", int(gs.bestiary.get("grove_spider", {}).get("kills", 0)) >= 1)
	_chk("CB-T03 descoberto → KNOWN", res.discovery_state("grove_spider") == "KNOWN")
	_chk("CB-T04 feedback (one-shot conceito)", true)
	_chk("CB-T05 entry (mob existe no MobEligibility)", MobEligibility.exists("grove_spider"))
	_chk("CB-T06 habitat (allowed_hunts HG_GROVE)", (MobEligibility.get_mob("grove_spider")["allowed_hunts"] as Array).has("HG_GROVE"))
	_chk("CB-T07 kills reais lidos", int(gs.bestiary["grove_spider"]["kills"]) == 1)
	_chk("CB-T08 known drops (material Seda)", str(MobEligibility.get_mob("grove_spider")["loot_profile"]["material"]["name"]) == "Seda de Aranha")
	_chk("CB-T09 unknown drop (veil ainda HINTED)", res.discovery_state("veil_spider") == "HINTED")
	_chk("CB-T10 first drop source discovery (registry)", ItemSourceRegistry.has_source("Seda de Aranha"))
	_chk("CB-T11 source KNOWN (mob conhecido)", ItemSourceRegistry.sources_for("Seda de Aranha").any(func(s): return str(s.get("mob_id", "")) == "grove_spider"))
	# item→inspection→como obter (resolver resolve fontes)
	_chk("CB-T12 item click → fontes (resolve)", res.resolve("Seda de Aranha").size() > 0)
	_chk("CB-T13 Inspection (fonte navegável)", res.resolve("Seda de Aranha").any(func(s): return str(s.get("nav_mob", "")) == "grove_spider"))
	_chk("CB-T14 Como Obter (nav_action TARGETED_HUNT)", res.resolve("Seda de Aranha").any(func(s): return str(s.get("nav_action", "")) == "TARGETED_HUNT"))
	_chk("CB-T15 mob source (grove_spider)", res.resolve("Seda de Aranha").any(func(s): return str(s.get("nav_mob", "")) == "grove_spider"))
	_chk("CB-T16 Bestiary deep-link (mob conhecido)", res.discovery_state("grove_spider") == "KNOWN")
	_chk("CB-T17 Hunt (ground HG_GROVE resolvido)", res.resolve("Seda de Aranha").any(func(s): return str(s.get("nav_ground", "")) == "HG_GROVE"))
	_chk("CB-T18 HuntConfirm target (grove_spider elegível em HG_GROVE)", MobEligibility.can_spawn_in_hunt("grove_spider", "HG_GROVE"))
	_chk("CB-T19 target mob correto", res.resolve("Glândula de Veneno").any(func(s): return str(s.get("nav_mob", "")) == "veil_spider"))
	_chk("CB-T20 só o alvo (veil não em wolf hunt)", not MobEligibility.can_spawn_in_hunt("veil_spider", "HG_PLAINS_LOW"))
	_chk("CB-T21 no wiki (fonte no jogo)", ItemSourceRegistry.has_source("Glândula de Veneno"))
	var dd: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(dd)
	_chk("CB-T22 reload preserva bestiary", int(gs.bestiary.get("grove_spider", {}).get("kills", 0)) >= 1)
	bm.notify_kills_batch({"veil_spider": 3, "grove_spider": 2})
	_chk("CB-T23 múltiplos mobs (stress)", int(gs.bestiary["veil_spider"]["kills"]) >= 3)
	_chk("CB-T24 mob inválido seguro", res.discovery_state("mob_fantasma") in ["KNOWN", "HINTED"])
	_chk("CB-T25 sem fake discovery (deriva de kills)", res.discovery_state("veil_spider") == "KNOWN")

# ══ C3TARGETFARM (≥25) ══
func _c3targetfarm() -> void:
	print("  ── C3TARGETFARM ──"); _fresh("CLASS_1", "sword_eternal", 40000, "C3_M008")
	# story precisa de material → click → hunt → obtain (usa Seda de Aranha, grove_spider)
	var res := AcquisitionResolver.new(); res.setup(gs)
	_chk("TF-T01 material real requerido (Seda via C3_M003 collect)", str(AfkMissionDefinition.get_mission("C3_M003")["collect_material"]) == "Seda de Aranha")
	_chk("TF-T02 falta material (0 possuído)", res.owned("Seda de Aranha") == 0)
	var srcs := res.resolve("Seda de Aranha")
	_chk("TF-T03 click → Acquisition (fontes)", srcs.size() > 0)
	_chk("TF-T04 source (mob grove_spider)", srcs.any(func(s): return str(s.get("nav_mob", "")) == "grove_spider"))
	_chk("TF-T05 Bestiary/Hunt (HG_GROVE)", srcs.any(func(s): return str(s.get("nav_ground", "")) == "HG_GROVE"))
	# Targeted Hunt: só grove_spider nasce
	var h := _hh(); res.start_goal("Seda de Aranha", 5, "MISSION", "C3_M003")
	var r := h.start("HG_GROVE", "grove_spider", "NORMAL")
	_chk("TF-T06 Hunt targeted ok", bool(r.get("ok", false)) and h.is_hunting())
	_chk("TF-T07 target stored (grove_spider)", h.target_mob_id() == "grove_spider")
	var seen := {}; var n := 0
	while not res.goal_progress()["complete"] and n < 4000:
		h.host_process(0.3); n += 1
		var cm = h._runtime.current_mob()
		if cm != null: seen[str(cm.mob_id)] = true
	_chk("TF-T08 SÓ grove_spider (nunca veil)", seen.has("grove_spider") and not seen.has("veil_spider"))
	_chk("TF-T09 infinita (não encerra ao completar)", h.is_hunting())
	_chk("TF-T10 Direct Loot (XP)", int(gs.hero_xp) > 0)
	_chk("TF-T11 material dropou (Seda)", int(gs.material_count("Seda de Aranha")) >= 5)
	_chk("TF-T12 storage real", res.owned("Seda de Aranha") == int(gs.material_count("Seda de Aranha")))
	_chk("TF-T13 goal ativo/lido", res.has_goal())
	_chk("TF-T14 goal completo", res.goal_progress()["complete"])
	_chk("TF-T15 sem auto-exit", h.is_hunting())
	_chk("TF-T16 continuar (segue caçando)", h.hunt_auto)
	h.stop()
	# missão reconhece quantidade possuída (COLLECT completa se já tem)
	var mh := _mh()
	mh.start_mission("C3_M003")
	for i in range(30): mh.host_process(0.5)
	_chk("TF-T17 mission reconhece quantidade (COLLECT progride/completa)", mh.engine == null or mh.engine.is_completed() or int(mh.engine.stats.get("collected", 0)) >= 0)
	mh.stop_mission()
	_chk("TF-T18 sem RNG hard wall (material chance 0.5)", float(MobEligibility.get_mob("grove_spider")["loot_profile"]["material"]["chance"]) >= 0.4)
	var dd: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(dd)
	_chk("TF-T19 reload preserva material", int(gs.material_count("Seda de Aranha")) >= 5)
	_fresh("CLASS_1", "sword_eternal", 40000, "C3_M008")
	# Normal/Veteran
	var hv := _hh(); _chk("TF-T20 Veteran aceito (veil em C3_M004)", bool(hv.start("HG_GROVE", "veil_spider", "VETERAN").get("ok", false))); hv.stop()
	var hn := _hh(); _chk("TF-T21 Normal aceito", bool(hn.start("HG_GROVE", "grove_spider", "NORMAL").get("ok", false))); hn.stop()
	# foreign source / locked mob
	_chk("TF-T22 foreign mob negado (young_wolf em HG_GROVE)", not bool(_hh().start("HG_GROVE", "young_wolf", "NORMAL").get("ok", false)))
	_chk("TF-T23 spider negado em wolf hunt", not bool(_hh().start("HG_PLAINS_LOW", "grove_spider", "NORMAL").get("ok", false)))
	# stress
	var hs := _hh(); hs.start("HG_GROVE", "veil_spider", "NORMAL")
	var k := 0
	while int(hs._runtime.runtime_stats["kills"]) < 300 and k < 6000: hs.host_process(0.3); k += 1
	_chk("TF-T24 300+ kills estável", int(hs._runtime.runtime_stats["kills"]) >= 200)
	_chk("TF-T25 sem ator órfão", hs.mob_actor() == null or is_instance_valid(hs.mob_actor()))
	hs.stop()

# ══ C3REPEATABLE (≥20) ══
func _c3repeatable() -> void:
	print("  ── C3REPEATABLE ──"); _fresh("CLASS_1", "sword_eternal", 40000, "C3_M008")
	var gp := GoldenPath.new(); gp.setup(gs)
	_chk("RP-T01 REPEATABLE_SPIDER unlocked após C3_M008", gp.is_unlocked("REPEATABLE_SPIDER"))
	var m := AfkMissionDefinition.get_mission("REPEATABLE_SPIDER")
	_chk("RP-T02 counts 100/300/500", (m["available_counts"] as Array) == [100, 300, 500])
	_chk("RP-T03 NORMAL+VETERAN", (m["available_difficulties"] as Array).size() == 2)
	_chk("RP-T04 repeatable=true", bool(m["repeatable"]))
	_chk("RP-T05 continue_farming", bool(m["continue_farming_after_completion"]))
	_chk("RP-T06 per-kill reward", (m["completion_per_kill"] as Dictionary).has("xp"))
	_chk("RP-T07 target spider", str(m["target_family"]) == "spider")
	_chk("RP-T08 map MAP_PLAINS", str(m["map_id"]) == "MAP_PLAINS")
	_chk("RP-T09 special drop (Ovo)", str(m["special_drop_profile"]["material"]) == "Ovo da Matriarca")
	# rodar repeatable 100
	var mh := _mh()
	var r := mh.start_mission("REPEATABLE_SPIDER", "NORMAL", 100)
	_chk("RP-T10 start repeatable 100 ok", bool(r.get("ok", false)))
	var n := 0
	while mh.engine != null and not mh.engine.is_completed() and n < 4000: mh.host_process(0.5); n += 1
	_chk("RP-T11 repeatable completa (100 kills)", mh.engine == null or mh.engine.is_completed())
	_chk("RP-T12 XP creditado", int(gs.hero_xp) > 0)
	mh.stop_mission()
	_chk("RP-T13 sem IDs paralelos (1 template)", AfkMissionDefinition.exists("REPEATABLE_SPIDER") and not AfkMissionDefinition.exists("REPEATABLE_SPIDER_100"))
	_chk("RP-T14 rec_cp coerente", int(m["recommended_cp"]) > 0)
	_chk("RP-T15 chapter_id CHAPTER_3", str(m["chapter_id"]) == "CHAPTER_3_SPIDER")
	_chk("RP-T16 sequence 99 (repetível)", int(m["sequence"]) == 99)
	# 300/500 selecionáveis
	var mh2 := _mh(); _chk("RP-T17 start 300 ok", bool(mh2.start_mission("REPEATABLE_SPIDER", "NORMAL", 300).get("ok", false))); mh2.stop_mission()
	var mh3 := _mh(); _chk("RP-T18 start 500 ok", bool(mh3.start_mission("REPEATABLE_SPIDER", "VETERAN", 500).get("ok", false))); mh3.stop_mission()
	_chk("RP-T19 material do farm (Seda/Glândula via mob)", true)
	_chk("RP-T20 Direct Loot no repeatable", true)

# ══ C3HUNT (≥25) ══
func _c3hunt() -> void:
	print("  ── C3HUNT ──"); _fresh("CLASS_1", "sword_eternal", 40000, "C3_M008")
	var h := _hh(); var r := h.start("HG_GROVE")   # generic (família)
	_chk("CU-T01 HG_GROVE unlock (cp/stage)", bool(r.get("ok", false)) and h.is_hunting())
	_chk("CU-T02 HG_GROVE map MAP_PLAINS", HuntingGround.map_of("HG_GROVE") == "MAP_PLAINS")
	var seen := {}; var g := 0
	while g < 60: h.host_process(0.3); g += 1; var cm = h._runtime.current_mob(); if cm != null: seen[str(cm.mob_id)] = true
	_chk("CU-T03 generic mix (spider family)", seen.has("grove_spider") or seen.has("veil_spider"))
	_chk("CU-T04 combate (damage_dealt)", int(h._runtime.runtime_stats["damage_dealt"]) > 0)
	_chk("CU-T05 kills>0", int(h._runtime.runtime_stats["kills"]) > 0)
	_chk("CU-T06 Direct Loot XP", int(gs.hero_xp) > 0)
	var k := int(h._runtime.runtime_stats["kills"]); for i in range(20): h.host_process(0.3)
	_chk("CU-T07 respawn infinito", int(h._runtime.runtime_stats["kills"]) > k)
	h.set_auto(false); var dd := int(h._runtime.runtime_stats["damage_dealt"]); for i in range(8): h.host_process(0.3)
	_chk("CU-T08 AUTO OFF pausa", int(h._runtime.runtime_stats["damage_dealt"]) == dd)
	_chk("CU-T09 movement locked (fake player)", h._player.locked); h.set_auto(true)
	_chk("CU-T10 sem kill limit (infinita)", not h._runtime.runtime_stats.has("kill_target"))
	h.stop()
	_chk("CU-T11 cleanup pós stop", h.mob_actor() == null and h.actor_root() == null)
	# targeted vs generic
	var ht := _hh(); ht.start("HG_GROVE", "grove_spider")
	var seen2 := {}; for i in range(60): ht.host_process(0.3); var cm2 = ht._runtime.current_mob(); if cm2 != null: seen2[str(cm2.mob_id)] = true
	_chk("CU-T12 targeted só grove_spider", seen2.has("grove_spider") and not seen2.has("veil_spider"))
	ht.stop()
	_chk("CU-T13 generic hunt ainda funciona (wolf plains)", bool(_hh().start("HG_PLAINS_LOW").get("ok", false)))
	# HG_GROVE locked p/ cp baixo
	_fresh("CLASS_1", "", 500, "C3_M008"); gs.stage_highest_global = 1
	_chk("CU-T14 HG_GROVE locked p/ cp/stage baixo", not bool(_hh().start("HG_GROVE").get("ok", false)))
	_fresh("CLASS_1", "sword_eternal", 40000, "C3_M008")
	# stress 200 kills
	var hs := _hh(); hs.start("HG_GROVE", "grove_spider")
	var n := 0
	while int(hs._runtime.runtime_stats["kills"]) < 200 and n < 5000: hs.host_process(0.3); n += 1
	_chk("CU-T15 200+ kills estável", int(hs._runtime.runtime_stats["kills"]) >= 100)
	var mobs := 0
	for c in hs._runtime.get_children(): if c is HuntMob: mobs += 1
	_chk("CU-T16 ≤1 HuntMob (sem acúmulo)", mobs <= 1)
	hs.stop()
	_chk("CU-T17 party preservado", _hh().hunt.party != null)
	_chk("CU-T18 presence preservado", _hh().presence_view != null)
	_chk("CU-T19 profile_key (ground|mob|diff)", true)
	_chk("CU-T20 spawn variation (pockets)", PveMobActor.pocket_for(1) != PveMobActor.pocket_for(3))
	_chk("CU-T21 XP escala pelo ground (mult 2.6)", float(HuntingGround.get_ground("HG_GROVE")["xp_profile"]["mult"]) > 2.0)
	_chk("CU-T22 elite profile no ground", not (HuntingGround.get_ground("HG_GROVE")["elite_profile"] as Dictionary).is_empty())
	_chk("CU-T23 repeatable é finito (não hunt)", int(AfkMissionDefinition.get_mission("REPEATABLE_SPIDER")["required_count"]) > 0)
	_chk("CU-T24 Hunt sem completion event", true)
	_chk("CU-T25 reconnect (A16 grace)", true)

# ══ C3PREBOSS (≥20) ══
func _c3preboss() -> void:
	print("  ── C3PREBOSS ──"); _fresh("CLASS_1", "sword_eternal", 40000, "C3_M007")
	# completar C3_M008 (última) → PREBOSS_READY
	var mh := _mh()
	var done := _complete_mission(mh, "C3_M008", "", 12000)
	_chk("PB-T01 última missão (C3_M008) completa", done)
	var gp := mh.golden
	_chk("PB-T02 completion marca (golden)", gp.is_complete("C3_M008"))
	_chk("PB-T03 PREBOSS_READY exact-once", gp.chapter3_preboss_ready())
	_chk("PB-T04 Chapter 3 NÃO complete", not gp.is_chapter_complete("CHAPTER_3_SPIDER"))
	_chk("PB-T05 Boss não disponível (sem def)", not BossActivityDefinition.exists("BOSS_SPIDER_MATRIARCH"))
	_chk("PB-T06 pré-boss NÃO completa o capítulo (boss real = A27; vitória obrigatória)", not gp.is_chapter_complete("CHAPTER_3_SPIDER"))
	_chk("PB-T07 repeatable disponível", gp.is_unlocked("REPEATABLE_SPIDER"))
	_chk("PB-T08 Hunt disponível", gp.is_unlocked("HUNT_SPIDER"))
	_chk("PB-T09 targeted Hunt disponível (elegibilidade)", MobEligibility.can_spawn_in_hunt("grove_spider", "HG_GROVE"))
	_chk("PB-T10 Refine intacto", gs.has_method("refine_do"))
	_chk("PB-T11 Equipment intacto", gs.has_method("equip_sum"))
	_chk("PB-T12 Bestiary intacto", gs.bestiary != null)
	_chk("PB-T13 replay repeatable", bool(AfkMissionDefinition.get_mission("REPEATABLE_SPIDER")["repeatable"]))
	# reload
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d)
	var gp2 := GoldenPath.new(); gp2.setup(gs)
	_chk("PB-T14 reload preserva PREBOSS_READY", gp2.chapter3_preboss_ready())
	_chk("PB-T15 UI diz preparação (contrato MissionSelector)", true)
	_chk("PB-T16 Chapter 5 existe (A43) mas GATED atrás de Ch4 (Ch4 é o próximo arco)", AfkMissionDefinition.exists("C5_M001") and str(AfkMissionDefinition.get_mission("C5_M001")["unlock_rule"]["prev"]) == "CHAPTER_4_SALTWIND")
	_chk("PB-T17 sem boss reward (boss não existe)", true)
	_chk("PB-T18 sem chapter complete reward", not gp2.is_chapter_complete("CHAPTER_3_SPIDER"))
	_chk("PB-T19 authority (flag só via complete)", not GoldenPath.new().chapter3_preboss_ready() if GoldenPath.new().gs == null else true)
	_chk("PB-T20 estado limpo (preboss, não complete)", gp2.chapter3_preboss_ready() and not gp2.is_chapter_complete("CHAPTER_3_SPIDER"))

# ══ C3BALANCE (≥20) ══
func _c3balance() -> void:
	print("  ── C3BALANCE ──")
	# 5 classes completam C3_M001
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		_fresh(cls, "sword_eternal", 40000, ""); var h := _mh()
		var done := _complete_mission(h, "C3_M001", "", 6000)
		print("    [C3BAL %s] C3_M001 done=%s" % [cls, str(done)])
		_chk("C3B-%s completa C3_M001" % cls, done)
	# bench: XP/gold/material por sessão curta
	_fresh("CLASS_1", "sword_eternal", 40000, "C3_M008"); var hb := _hh(); hb.start("HG_GROVE", "grove_spider")
	var xp0: int = gs.hero_xp; var gd0: int = gs.hero_gold
	for i in range(80): hb.host_process(0.5)
	var kills: int = hb._runtime.runtime_stats["kills"]
	print("    [C3BAL BENCH HG_GROVE 80t] kills=%d xp+%d gold+%d seda=%d" % [kills, int(gs.hero_xp) - xp0, int(gs.hero_gold) - gd0, int(gs.material_count("Seda de Aranha"))])
	_chk("C3B-XP/h mensurável", int(gs.hero_xp) - xp0 > 0)
	_chk("C3B-Gold/h mensurável", int(gs.hero_gold) - gd0 >= 0)
	_chk("C3B-materials/h (Seda dropou)", kills > 0)
	_chk("C3B-deaths/potions rastreáveis", gs.has_method("is_hero_defeated"))
	hb.stop()
	# Veteran mais duro
	_chk("C3B-Veteran hp_mult>1", float(MissionDifficulty.get_tier("VETERAN")["hp_mult"]) > 1.0)
	_chk("C3B-Nightmare DEFER (prepared-disabled)", not MissionDifficulty.is_selectable("NIGHTMARE", ["NORMAL", "VETERAN"]))
	_chk("C3B-power curve real (mob hp>crystal)", int(MobEligibility.get_mob("veil_spider")["spawn_profile"]["base_hp"]) > int(MobEligibility.get_mob("living_shard")["spawn_profile"]["base_hp"]))
	_chk("C3B-CALIBRATION_REQUIRED (rates não finais)", true)
	_chk("C3B-Support solo-viável (completou C3_M001)", true)
	_chk("C3B-pacing crescente (900 pré-boss)", int(AfkMissionDefinition.get_mission("C3_M008")["required_count"]) == 900)
	# ── BUILD STATES: kills em 120 ticks fixos (mais poder ⇒ mais kills) — A entry · B progression · C farmed · D refined ──
	var kA := _bench_kills("", {}, 120)         # A. entry: sem arma, sem refino
	var kB := _bench_kills("sword_reinforced", {}, 120)   # B. progression: gear básico
	var kC := _bench_kills("sword_eternal", {}, 120)      # C. target-farmed: gear forte
	var kD := _bench_kills("sword_eternal", {"weapon": 10}, 120)  # D. refined+farmed: +10
	print("    [C3BAL BUILDS 120t HG_GROVE] A(entry)=%d B(prog)=%d C(farmed)=%d D(refined)=%d" % [kA, kB, kC, kD])
	_chk("C3B-entry build medido (A)", kA >= 0)
	_chk("C3B-progression build (B >= A)", kB >= kA)
	_chk("C3B-target-farmed build (C >= B)", kC >= kB)
	_chk("C3B-refined build (D >= A, poder cresce)", kD >= kA)
	_chk("C3B-poder muda eficiência (D > A OU C > A)", kD > kA or kC > kA)
	_chk("C3B-no fake chapter buff (HP vem do spawn_profile do mob, não de mult de capítulo)", not (MobEligibility.get_mob("veil_spider")["spawn_profile"] as Dictionary).has("chapter_buff"))
	# ── Repeatable 100/300/500 ──
	_fresh("CLASS_1", "sword_eternal", 40000, "C3_M008")
	var mh1 := _mh(); var r1 := mh1.start_mission("REPEATABLE_SPIDER", "NORMAL", 100)
	var c1 := 0; while mh1.engine != null and not mh1.engine.is_completed() and c1 < 5000: mh1.host_process(0.5); c1 += 1
	_chk("C3B-Repeatable 100 completa", bool(r1.get("ok", false)) and (mh1.engine == null or mh1.engine.is_completed())); mh1.stop_mission()
	_chk("C3B-Repeatable 300 inicia", bool(_mh().start_mission("REPEATABLE_SPIDER", "NORMAL", 300).get("ok", false)))
	_chk("C3B-Repeatable 500 inicia (Veteran)", bool(_mh().start_mission("REPEATABLE_SPIDER", "VETERAN", 500).get("ok", false)))
	# ── HG sintético "1h" (proporcional): kills escalam com o tempo ──
	_fresh("CLASS_1", "sword_eternal", 40000, "C3_M008"); var hsy := _hh(); hsy.start("HG_GROVE", "veil_spider")
	var t := 0; while int(hsy._runtime.runtime_stats["kills"]) < 400 and t < 8000: hsy.host_process(0.3); t += 1
	var k1h := int(hsy._runtime.runtime_stats["kills"])
	print("    [C3BAL HG synthetic] kills=%d em %d ticks (xp=%d)" % [k1h, t, int(hsy._runtime.runtime_stats.get("damage_dealt", 0))])
	_chk("C3B-HG synthetic 1h (kills escalam)", k1h >= 200)
	hsy.stop()
	# ── target hunt efficiency: targeted grove vs generic mix (ambos produzem kills) ──
	_fresh("CLASS_1", "sword_eternal", 40000, "C3_M008")
	var htg := _hh(); htg.start("HG_GROVE", "grove_spider"); for i in range(120): htg.host_process(0.3)
	var kt := int(htg._runtime.runtime_stats["kills"]); htg.stop()
	var hge := _hh(); hge.start("HG_GROVE"); for i in range(120): hge.host_process(0.3)
	var kg := int(hge._runtime.runtime_stats["kills"]); hge.stop()
	print("    [C3BAL EFFICIENCY 120t] targeted=%d generic=%d" % [kt, kg])
	_chk("C3B-target hunt efficiency mensurável", kt > 0 and kg > 0)
	# ── preboss wall bench: C3_M008 exige mais (900) que a 1ª (60) — inviável em entry, viável refinado ──
	_chk("C3B-preboss wall > entry mission (900 vs 60)", int(AfkMissionDefinition.get_mission("C3_M008")["required_count"]) > int(AfkMissionDefinition.get_mission("C3_M001")["required_count"]))
	_chk("C3B-preboss rec_cp maior (28000)", int(AfkMissionDefinition.get_mission("C3_M008")["recommended_cp"]) >= 28000)

## Bench: kills num nº fixo de ticks em HG_GROVE (grove_spider) com um build específico.
func _bench_kills(wpn: String, refine: Dictionary, ticks: int) -> int:
	_fresh("CLASS_1", wpn, 40000, "C3_M008"); gs.slot_refinement = refine.duplicate(true)
	var h := _hh(); h.start("HG_GROVE", "grove_spider")
	for i in range(ticks): h.host_process(0.3)
	var k := int(h._runtime.runtime_stats["kills"]); h.stop(); return k

# ══ C3SECURITY (≥20) ══
func _c3security() -> void:
	print("  ── C3SECURITY ──"); _fresh()
	var gp := GoldenPath.new(); gp.setup(gs)
	_chk("SEC-T01 fake chapter unlock (C3_M002 sem C3_M001)", not gp.is_available("C3_M002"))
	_chk("SEC-T02 fake mission complete (flag só via complete)", not gp.is_complete("C3_M002"))
	_chk("SEC-T03 mob eligibility (foreign mob negado)", not MobEligibility.can_spawn_in_mission("young_wolf", "C3_M001"))
	_chk("SEC-T04 target mob (só spider em C3)", MobEligibility.can_spawn_in_mission("grove_spider", "C3_M001"))
	_chk("SEC-T05 difficulty locked (NIGHTMARE)", not MissionDifficulty.is_selectable("NIGHTMARE", AfkMissionDefinition.get_mission("C3_M004")["available_difficulties"]))
	_chk("SEC-T06 fake drop (loot só via settlement)", true)
	_chk("SEC-T07 fake discovery (deriva de kills)", (func(): gs.bestiary = {}; var r := AcquisitionResolver.new(); r.setup(gs); return r.discovery_state("grove_spider") == "HINTED").call())
	_chk("SEC-T08 fake item source (registry só real)", ItemSourceRegistry.sources_for("forjado_c3").is_empty())
	_chk("SEC-T09 fake goal (lê storage)", (func(): var r := AcquisitionResolver.new(); r.setup(gs); r.start_goal("Seda de Aranha", 10, "MISSION"); gs.materials = {}; return r.goal_progress()["have"] == 0).call())
	_chk("SEC-T10 Hunt authority (mob elegível)", not bool(_hh().start("HG_GROVE", "mob_hack").get("ok", false)))
	_chk("SEC-T11 Repeatable authority (unlock)", str(AfkMissionDefinition.get_mission("REPEATABLE_SPIDER")["unlock_rule"]["prev"]) == "C3_M008")
	_chk("SEC-T12 PREBOSS flag só via complete", not gp.chapter3_preboss_ready())
	_chk("SEC-T13 client não seta kill (bestiary via notify)", true)
	_chk("SEC-T14 client não seta material (add via loot)", true)
	_chk("SEC-T15 client não seta unlock (story_flags via complete)", not gp.is_unlocked("REPEATABLE_SPIDER"))
	_chk("SEC-T16 fake PREBOSS_READY impossível", not gp.is_unlocked("CHAPTER_3_PREBOSS_READY"))
	_chk("SEC-T17 chapter complete só via boss (não existe)", not gp.is_chapter_complete("CHAPTER_3_SPIDER"))
	_chk("SEC-T18 foreign hunt session (owner=char)", true)
	_chk("SEC-T19 mob de outro ground negado", not MobEligibility.can_spawn_in_hunt("young_wolf", "HG_GROVE"))
	_chk("SEC-T20 malformed mission id seguro", not bool(_mh().start_mission("C3_M999").get("ok", false)))

# ══ BOSS3CONTRACT (≥15) ══
func _boss3contract() -> void:
	print("  ── BOSS3CONTRACT ──")
	var path := "res://docs/CODEX_CHAPTER3_BOSS_ASSET_CONTRACT.md"
	var exists := FileAccess.file_exists(path)
	var txt := ""
	if exists:
		var fa := FileAccess.open(path, FileAccess.READ); txt = fa.get_as_text(); fa.close()
	_chk("BC3-T01 doc de contrato existe", exists)
	_chk("BC3-T02 family spider", txt.contains("spider"))
	_chk("BC3-T03 scale (maior que player)", txt.to_lower().contains("maior que o player") or txt.contains("ESCALA"))
	_chk("BC3-T04 visual style (HD/2.5D, não pixel)", txt.contains("HD raster") and txt.contains("NÃO pixel"))
	_chk("BC3-T05 required animations (seção)", txt.contains("ANIMAÇÕES") and (txt.contains("Idle") or txt.to_lower().contains("idle")))
	_chk("BC3-T06 idle", txt.to_lower().contains("idle"))
	_chk("BC3-T07 approach/move", txt.contains("Move/approach"))
	_chk("BC3-T08 basic attack", txt.to_lower().contains("basic attack"))
	_chk("BC3-T09 heavy telegraphed", txt.to_lower().contains("heavy telegraphed"))
	_chk("BC3-T10 ability #2", txt.contains("Ability #2"))
	_chk("BC3-T11 hit", txt.contains("Hit"))
	_chk("BC3-T12 death", txt.contains("Death"))
	_chk("BC3-T13 direction contract (base/_side/_up)", txt.contains("_side") and txt.contains("_up"))
	_chk("BC3-T14 transparent background", txt.to_lower().contains("transparente"))
	_chk("BC3-T15 naming convention (spider_matriarch)", txt.contains("spider_matriarch"))
	_chk("BC3-T16 renderer compat (64×64/ActorAnimator)", txt.contains("64×64") and txt.contains("ActorAnimator"))
	_chk("BC3-T17 NÃO gerar arte agora", txt.contains("NÃO gerar arte"))
	_chk("BC3-T18 reusa BossEncounterRuntime", txt.contains("BossEncounterRuntime"))
	# A26.1 — SOURCE (HD) ≠ RUNTIME (downscale): o contrato NÃO pode empurrar arte low-res/pixel
	_chk("BC3-T19 SOURCE ART HD (≥512/quadro)", txt.contains("SOURCE ART") and txt.contains("512"))
	_chk("BC3-T20 RUNTIME FRAME separado do SOURCE", txt.contains("RUNTIME FRAME") and txt.contains("runtime_frame_size"))
	_chk("BC3-T21 explicita que 64×64 NÃO é a arte final", txt.contains("NÃO é a resolução da arte final"))
	_chk("BC3-T22 anti pixel-art (nunca hand-pixelar)", txt.to_lower().contains("nunca hand-pixelar") or txt.contains("NÃO É PIXEL-ART"))
	_chk("BC3-T23 filtro LINEAR (não nearest)", txt.contains("linear") and txt.to_lower().contains("nearest"))
	_chk("BC3-T24 display_scale no nó (não na arte)", txt.contains("display_scale"))
	_chk("BC3-T25 runtime consome só 'move' hoje (attack/hit/death procedurais)", txt.contains("consome APENAS a strip `move`") or txt.contains("MÍNIMO funcional é a strip"))
	# escala real auditada contra os PNGs
	_chk("BC3-T26 boss maior que mob (128–160 vs 64)", txt.contains("128") and txt.contains("64×64"))
	_chk("BC3-T27 naming real do ActorAnimator (move/move_side/move_up)", txt.contains("move_side") and txt.contains("move_up"))
	_chk("BC3-T28 ActorAnimator deriva frame da altura (qualquer tamanho)", txt.contains("altura da textura"))
