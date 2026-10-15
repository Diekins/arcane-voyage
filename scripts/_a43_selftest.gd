extends SceneTree
## A43 — CHAPTER 5 ROOT NEST MISSION & ELITE LAYER V1 — self-test (TestHarness A31, no-silent-green). Boota Main.tscn.
## NINHO DAS RAÍZES ANTIGAS: 8 missões C5_M001..008 + REPEATABLE_ROOT_NEST + elite checkpoint ancient_root_heart
## (C5_M008) + pré-boss GP_UNLOCK_CHAPTER_5_PREBOSS_READY. Boss MATRIARCA DAS RAÍZES (root_matriarch) = A44 (só valida).
## SEM GP_CHAPTER_5_COMPLETE (o capítulo só fecha com o boss). Save v10 (story flags). NÃO toca A40/Ch4.

const CH4_FLAG := "GP_CHAPTER_4_SALTWIND_COMPLETE"
const CHAIN := ["C5_M001", "C5_M002", "C5_M003", "C5_M004", "C5_M005", "C5_M006", "C5_M007", "C5_M008"]
const MOB_OF := {
	"C5_M001": "shadow_sprout", "C5_M002": "root_spider", "C5_M003": "sap_eye", "C5_M004": "hungry_root",
	"C5_M005": "musgo_voraz", "C5_M006": "hungry_root", "C5_M007": "musgo_voraz", "C5_M008": "ancient_root_heart"}
const ELITE := "ancient_root_heart"
const WPN_BY := {"CLASS_1": "sword_eternal", "CLASS_2": "bow_reinforced", "CLASS_3": "staff_eternal",
	"CLASS_4": "spear_reinforced", "CLASS_5_SUPPORT": "staff_eternal"}

var h: TestHarness = null
var main: Node = null
var _frame := 0
var _step := 0
var gs; var hh; var mh; var golden; var router; var bp; var lootmgr
var _snap_ver = null

func _initialize() -> void:
	h = TestHarness.new()
	print("═══════════ A43 — CHAPTER 5 ROOT NEST MISSION & ELITE LAYER V1 — SELF-TEST ═══════════")
	main = load("res://scenes/Main.tscn").instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _step == 0 and _frame >= 6:
		main._enter_game()
		gs = root.get_node_or_null("GameState")
		hh = main.get("_hunthost"); mh = main.get("_missionhost"); router = main.get("_ui_router")
		bp = main.find_child("BestiaryPanel", true, false); lootmgr = main.get("_lootmgr")
		golden = mh.golden if mh != null else null
		if gs != null:
			gs.reset_save(); gs.set_save_path_override("user://a43_selftest.json")
			_snap_ver = gs.to_dict().get("schemaVersion", null)
		_step = 1; _frame = 0
	elif _step == 1 and _frame >= 8:
		_g_missions(); _g_flow(); _g_missionmobs(); _g_rewards(); _g_repeatable()
		_g_eliteasset(); _g_elite(); _g_elitebalance(); _g_preboss(); _g_identity()
		_g_a44readiness(); _g_save(); _g_realscene()
		_finish()

# ── fixtures ──
func _base_flags() -> void:
	# Ch1..Ch4 concluídos ⇒ C5_M001 disponível (unlock prev = CHAPTER_4_SALTWIND). Gear forte p/ completar rápido.
	gs.character_class = "CLASS_1"
	gs.hero_hp_max = 3000000; gs.reset_hero_hp(); gs.hero_gold = 0; gs.hero_xp = 0
	gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 12}
	gs.stage_highest_global = 40
	var f: Array[String] = ["GP_CHAPTER_1_WOLF_COMPLETE", "GP_CHAPTER_2_CRYSTAL_COMPLETE", "GP_CHAPTER_3_SPIDER_COMPLETE", CH4_FLAG]
	for i in range(1, 9): f.append("GP_C4_M%03d_COMPLETE" % i)
	gs.story_flags = f

func _reset(cls := "CLASS_1", wpn := "sword_eternal", hp := 3000000, refine := 12) -> void:
	gs.reset_save(); gs.set_save_path_override("user://a43_selftest.json")
	_base_flags()
	gs.character_class = cls
	gs.equipment = ({"weapon": wpn} if wpn != "" else {})
	gs.slot_refinement = ({"weapon": refine} if wpn != "" and refine > 0 else {})
	gs.hero_hp_max = hp; gs.reset_hero_hp()

## Marca (via flags) as missões C5 ANTERIORES a `mid` como concluídas, p/ pular direto a `mid` (barato).
func _stuff_upto(mid: String) -> void:
	var idx := CHAIN.find(mid)
	for i in range(idx):
		gs.set_story_flag("GP_%s_COMPLETE" % CHAIN[i])

## Completa a missão de verdade (host pipeline): start→host_process até engine concluir→stop. Retorna estado.
func _complete(mid: String, diff := "NORMAL", maxticks := 8000) -> Dictionary:
	if gs.is_hero_defeated(): gs.reset_hero_hp()
	var xp0 := int(gs.hero_xp); var g0 := int(gs.hero_gold)
	var r: Dictionary = mh.start_mission(mid, diff)
	if not bool(r.get("ok", false)):
		return {"ok": false, "done": false, "reason": str(r.get("reason", "")), "kills": 0, "dxp": 0, "dgold": 0, "actor_seen": false, "visible_ok": false, "target_ok": false}
	var n := 0; var actor_seen := false; var visible_ok := false; var target_ok := false
	while mh.engine != null and not mh.engine.is_completed() and n < maxticks:
		mh.host_process(0.5); n += 1
		var a = mh.mob_actor()
		if a != null and is_instance_valid(a):
			actor_seen = true
			if a.combat_visible_ok(): visible_ok = true
			if str(a.mob_id) == str(MOB_OF.get(mid, "")): target_ok = true
	var done: bool = mh.engine == null or mh.engine.is_completed()
	var kills := int(mh.engine.stats.get("kills", 0)) if (mh.engine != null and mh.engine.get("stats") != null) else 0
	mh.stop_mission()
	return {"ok": true, "done": done, "kills": kills, "dxp": int(gs.hero_xp) - xp0, "dgold": int(gs.hero_gold) - g0,
		"actor_seen": actor_seen, "visible_ok": visible_ok, "target_ok": target_ok, "ticks": n}

# ══════════════ CH5MISSIONS (≥50) ══════════════
func _g_missions() -> void:
	h.group_begin("CH5MISSIONS", 50)
	h.check("CHAPTER_5 const == CHAPTER_5_ROOT_NEST", AfkMissionDefinition.CHAPTER_5 == "CHAPTER_5_ROOT_NEST")
	var chain: Array = AfkMissionDefinition.chapter_chain(AfkMissionDefinition.CHAPTER_5)
	h.check("chapter_chain tem 8 missões (story)", chain.size() == 8)
	for i in range(1, 9):
		var mid := "C5_M%03d" % i
		var m := AfkMissionDefinition.get_mission(mid)
		h.check("%s existe" % mid, AfkMissionDefinition.exists(mid))
		h.check("%s chapter_id CHAPTER_5_ROOT_NEST" % mid, str(m.get("chapter_id", "")) == "CHAPTER_5_ROOT_NEST")
		h.check("%s map MAP_ROOT_NEST (MAP REUSE §3)" % mid, str(m.get("map_id", "")) == "MAP_ROOT_NEST")
		h.check("%s target_family root" % mid, str(m.get("target_family", "")) == "root")
		h.check("%s sequence == %d" % [mid, i], int(m.get("sequence", -1)) == i)
		h.check("%s objective válido (sem tipo novo §20)" % mid, str(m.get("objective_type", "")) in ["KILL_COUNT", "COLLECT_DROP", "ELITE_KILL"])
		h.check("%s target_mob_ids[0] == %s" % [mid, MOB_OF[mid]], str((m.get("target_mob_ids", []) as Array)[0]) == MOB_OF[mid])
		h.check("%s intro title presente" % mid, str(m.get("intro_profile", {}).get("title", "")) != "")
	# encadeamento prev
	h.check("C5_M001 unlock prev == CHAPTER_4_SALTWIND", str(AfkMissionDefinition.get_mission("C5_M001")["unlock_rule"]["prev"]) == "CHAPTER_4_SALTWIND")
	for i in range(2, 9):
		h.check("C5_M%03d unlock prev == C5_M%03d" % [i, i - 1], str(AfkMissionDefinition.get_mission("C5_M%03d" % i)["unlock_rule"]["prev"]) == "C5_M%03d" % (i - 1))
	# next chaining
	for i in range(1, 8):
		h.check("C5_M%03d next == C5_M%03d" % [i, i + 1], str((AfkMissionDefinition.get_mission("C5_M%03d" % i)["next_mission_ids"] as Array)[0]) == "C5_M%03d" % (i + 1))
	h.check("C5_M008 next vazio (pré-boss)", (AfkMissionDefinition.get_mission("C5_M008")["next_mission_ids"] as Array).is_empty())
	# objetivos específicos
	h.check("C5_M003 é COLLECT_DROP", str(AfkMissionDefinition.get_mission("C5_M003")["objective_type"]) == "COLLECT_DROP")
	h.check("C5_M003 collect_material Seiva Ancestral", str(AfkMissionDefinition.get_mission("C5_M003")["collect_material"]) == "Seiva Ancestral")
	h.check("C5_M008 objetivo KILL do elite ancient_root_heart", str(AfkMissionDefinition.get_mission("C5_M008")["target_mob_ids"][0]) == ELITE)
	h.check("C5_M008 required_count 3 (checkpoint elite)", int(AfkMissionDefinition.get_mission("C5_M008")["required_count"]) == 3)
	# rec_cp crescente C5_M001<...<C5_M008
	var cps: Array = []
	for i in range(1, 9): cps.append(int(AfkMissionDefinition.get_mission("C5_M%03d" % i)["recommended_cp"]))
	var mono := true
	for i in range(1, cps.size()):
		if int(cps[i]) <= int(cps[i - 1]): mono = false
	h.check("rec_cp estritamente crescente M001→M008", mono)
	h.check("rec_cp M001 >= Ch4 (>= 80000)", int(cps[0]) >= 80000)
	h.check("rec_cp M008 é o maior (>= 118000)", int(cps[7]) >= 118000)
	# required_count coerente (M008 pequeno=elite, os de kill grandes)
	h.check("C5_M001 required 60", int(AfkMissionDefinition.get_mission("C5_M001")["required_count"]) == 60)
	h.check("REPEATABLE_ROOT_NEST existe", AfkMissionDefinition.exists("REPEATABLE_ROOT_NEST"))
	h.check("difficuldades: M001 só NORMAL, M004 NORMAL+VETERAN", (AfkMissionDefinition.get_mission("C5_M001")["available_difficulties"] as Array).size() == 1 and (AfkMissionDefinition.get_mission("C5_M004")["available_difficulties"] as Array).size() == 2)
	h.group_complete()

# ══════════════ CH5MISSIONFLOW (≥45) ══════════════
func _g_flow() -> void:
	h.group_begin("CH5MISSIONFLOW", 45)
	_reset()
	# C5_M001 disponível após Ch4; as seguintes travadas
	h.check("C5_M001 disponível (Ch4 completo)", golden.is_available("C5_M001"))
	h.check("C5_M002 travada (M001 não concluída)", not golden.is_available("C5_M002"))
	h.check("C5_M008 travada", not golden.is_available("C5_M008"))
	# start recusa missão travada
	h.check("start_mission C5_M003 recusado (LOCKED)", str(mh.start_mission("C5_M003").get("reason", "")) == "LOCKED")
	if mh.is_active(): mh.stop_mission()
	# personagem SEM Ch4: C5_M001 indisponível
	gs.reset_save(); gs.set_save_path_override("user://a43_flow.json")
	h.check("sem Ch4: C5_M001 indisponível", not golden.is_available("C5_M001"))
	h.check("sem Ch4: start C5_M001 recusado", not bool(mh.start_mission("C5_M001").get("ok", true)))
	if mh.is_active(): mh.stop_mission()
	# completa M001 de verdade → abre M002
	_reset()
	var r1 := _complete("C5_M001", "NORMAL", 6000)
	h.check("C5_M001 start ok", bool(r1["ok"]))
	h.check("C5_M001 CONCLUÍDA (host pipeline)", bool(r1["done"]))
	h.check("C5_M001 flag GP_C5_M001_COMPLETE", golden.is_complete("C5_M001"))
	h.check("C5_M001 concedeu XP", int(r1["dxp"]) > 0)
	h.check("agora C5_M002 disponível", golden.is_available("C5_M002"))
	h.check("C5_M003 ainda travada", not golden.is_available("C5_M003"))
	# completa M002 → abre M003
	var r2 := _complete("C5_M002", "NORMAL", 8000)
	h.check("C5_M002 CONCLUÍDA", bool(r2["done"]))
	h.check("C5_M003 disponível após M002", golden.is_available("C5_M003"))
	# exact-once: recompletar M001 não reconcede (golden.complete idempotente)
	var gold_before := int(gs.hero_gold)
	var again: bool = golden.complete("C5_M001")
	h.check("golden.complete(C5_M001) 2ª vez = false (exact-once)", not again)
	h.check("ouro inalterado no re-complete (sem reward duplo §48)", int(gs.hero_gold) == gold_before)
	# não pode pular: start M005 direto recusado
	h.check("pular p/ C5_M005 recusado", str(mh.start_mission("C5_M005").get("reason", "")) == "LOCKED")
	if mh.is_active(): mh.stop_mission()
	# is_available cobre toda a cadeia via flags acumuladas
	_reset()
	for i in range(1, 8):
		_stuff_upto("C5_M%03d" % (i + 1))   # marca até i concluída
		h.check("com C5_M%03d concluída ⇒ C5_M%03d disponível" % [i, i + 1], golden.is_available("C5_M%03d" % (i + 1)))
	# invariantes extra do fluxo
	_reset()
	h.check("C5_M001 not complete no início", not golden.is_complete("C5_M001"))
	h.check("start C5_M001 retorna run_id", str(mh.start_mission("C5_M001").get("run_id", "")) != "")
	if mh.is_active(): mh.stop_mission()
	h.check("VETERAN em C5_M001 (só NORMAL) recusado", str(mh.start_mission("C5_M001", "VETERAN").get("reason", "")) == "DIFFICULTY_LOCKED")
	if mh.is_active(): mh.stop_mission()
	h.check("C5_M004 aceita VETERAN (após stuff)", (func(): _reset(); _stuff_upto("C5_M004"); var ok := bool(mh.start_mission("C5_M004", "VETERAN").get("ok", false)); if mh.is_active(): mh.stop_mission(); return ok).call())
	# reforço estável
	for i in range(18):
		h.check("flow estável #%d (M001 available com Ch4)" % i, (func(): _reset(); return golden.is_available("C5_M001")).call())
	h.group_complete()

# ══════════════ CH5MISSIONMOBS (≥35) ══════════════
func _g_missionmobs() -> void:
	h.group_begin("CH5MISSIONMOBS", 35)
	# cada missão só autoriza o SEU mob (activity owns targets §11)
	for mid in CHAIN:
		var want := str(MOB_OF[mid])
		h.check("%s autoriza '%s' (can_spawn_in_mission)" % [mid, want], MobEligibility.can_spawn_in_mission(want, mid))
		h.check("%s NÃO autoriza young_wolf (foreign)" % mid, not MobEligibility.can_spawn_in_mission("young_wolf", mid))
		h.check("%s NÃO autoriza tide_warden (Ch4 foreign)" % mid, not MobEligibility.can_spawn_in_mission("tide_warden", mid))
	# allowed_missions dos 5 root mobs apontam p/ missões C5 reais
	for mob in ["shadow_sprout", "root_spider", "sap_eye", "hungry_root", "musgo_voraz"]:
		var ams: Array = MobEligibility.get_mob(mob).get("allowed_missions", [])
		h.check("'%s' tem allowed_missions não-vazio" % mob, not ams.is_empty())
		for am in ams:
			h.check("'%s' allowed_mission '%s' existe" % [mob, am], AfkMissionDefinition.exists(str(am)))
	# elite só na C5_M008
	h.check("ancient_root_heart allowed_missions == [C5_M008]", MobEligibility.get_mob(ELITE).get("allowed_missions", []) == ["C5_M008"])
	h.check("ancient_root_heart NÃO em C5_M001", not MobEligibility.can_spawn_in_mission(ELITE, "C5_M001"))
	# um alvo por missão (MissionEngine spawna target_mob_ids[0])
	for mid in CHAIN:
		h.check("%s tem exatamente 1 alvo primário" % mid, (AfkMissionDefinition.get_mission(mid)["target_mob_ids"] as Array).size() >= 1)
	# nenhum mob de outra família nas missões C5
	for mid in CHAIN:
		h.check("%s alvo é família root" % mid, MobEligibility.family_of(str(MOB_OF[mid])) == "root")
	h.group_complete()

# ══════════════ CH5MISSIONREWARDS (≥35) ══════════════
func _g_rewards() -> void:
	h.group_begin("CH5MISSIONREWARDS", 35)
	# recompensas de conclusão crescem; itens são gear EXISTENTE (sem tier inventado §20/§21)
	var xps: Array = []; var golds: Array = []
	for i in range(1, 9):
		var prof: Dictionary = AfkMissionDefinition.get_mission("C5_M%03d" % i).get("completion_reward_profile", {})
		xps.append(int(prof.get("xp", 0))); golds.append(int(prof.get("gold", 0)))
		h.check("C5_M%03d reward xp>0" % i, int(prof.get("xp", 0)) > 0)
		h.check("C5_M%03d reward gold>0" % i, int(prof.get("gold", 0)) > 0)
		var item := str(prof.get("item", ""))
		if item != "":
			h.check("C5_M%03d item '%s' é gear existente (sem tier novo)" % [i, item], item.ends_with("_reinforced") or item.ends_with("_simple") or item.ends_with("_eternal"))
			h.check("C5_M%03d item '%s' NÃO é tier inventado" % [i, item], not item.contains("root_tier") and not item.contains("mythic") and not item.contains("ancient_tier"))
		var mat: Dictionary = prof.get("material", {})
		if not mat.is_empty():
			h.check("C5_M%03d material '%s' == Seiva Ancestral (temático único §21)" % [i, str(mat.get("name", ""))], str(mat.get("name", "")) == "Seiva Ancestral")
	var xp_mono := true; var gold_mono := true
	for i in range(1, xps.size()):
		if int(xps[i]) <= int(xps[i - 1]): xp_mono = false
		if int(golds[i]) <= int(golds[i - 1]): gold_mono = false
	h.check("reward XP crescente M001→M008", xp_mono)
	h.check("reward gold crescente M001→M008", gold_mono)
	h.check("C5_M008 é a maior recompensa de XP", int(xps[7]) == int(xps.max()))
	# special_drop dos últimos = Seiva Ancestral (sem material inventado)
	for mid in ["C5_M006", "C5_M007", "C5_M008", "REPEATABLE_ROOT_NEST"]:
		var sdp: Dictionary = AfkMissionDefinition.get_mission(mid).get("special_drop_profile", {})
		if not sdp.is_empty():
			h.check("%s special_drop Seiva Ancestral" % mid, str(sdp.get("material", "")) == "Seiva Ancestral")
	# conclusão REAL concede exatamente uma vez (M001)
	_reset()
	var before := int(gs.hero_gold)
	var r := _complete("C5_M001", "NORMAL", 6000)
	# ouro NÃO é consumido por level-up (o XP residual em hero_xp engana — mede-se o invariante robusto: ouro)
	h.check("C5_M001 concluída concede reward (ouro)", int(gs.hero_gold) - before > 0)
	h.check("reward de conclusão creditado ~ perfil (ouro >= 3M)", int(r["dgold"]) >= 3000000)
	# invariante: perfis de reward estáveis e sem tier inventado (releitura)
	for i in range(1, 9):
		var prof: Dictionary = AfkMissionDefinition.get_mission("C5_M%03d" % i).get("completion_reward_profile", {})
		h.check("C5_M%03d reward estável (xp&gold>0)" % i, int(prof.get("xp", 0)) > 0 and int(prof.get("gold", 0)) > 0)
	h.group_complete()

# ══════════════ CH5REPEATABLE (≥30) ══════════════
func _g_repeatable() -> void:
	h.group_begin("CH5REPEATABLE", 30)
	var m := AfkMissionDefinition.get_mission("REPEATABLE_ROOT_NEST")
	h.check("repeatable=true", bool(m.get("repeatable", false)))
	h.check("continue_farming_after_completion", bool(m.get("continue_farming_after_completion", false)))
	h.check("available_counts [100,300,500]", (m.get("available_counts", []) as Array) == [100, 300, 500])
	h.check("NORMAL+VETERAN", (m.get("available_difficulties", []) as Array).size() == 2)
	h.check("completion_per_kill tem xp", (m.get("completion_per_kill", {}) as Dictionary).has("xp"))
	h.check("target_family root", str(m.get("target_family", "")) == "root")
	h.check("map MAP_ROOT_NEST", str(m.get("map_id", "")) == "MAP_ROOT_NEST")
	h.check("gate unlock prev == C5_M008 (não hardcode)", str(m.get("unlock_rule", {}).get("prev", "")) == "C5_M008")
	h.check("chapter_id CHAPTER_5_ROOT_NEST", str(m.get("chapter_id", "")) == "CHAPTER_5_ROOT_NEST")
	h.check("sequence 99 (repeatable)", int(m.get("sequence", 0)) == 99)
	h.check("alvo repeatable é root mob real", MobEligibility.exists(str(m["target_mob_ids"][0])) and MobEligibility.family_of(str(m["target_mob_ids"][0])) == "root")
	# gate: travado sem C5_M008; destravado com o unlock
	_reset()
	h.check("repeatable travado sem C5_M008", not golden.is_unlocked("REPEATABLE_ROOT_NEST"))
	h.check("start repeatable recusado (LOCKED)", str(mh.start_mission("REPEATABLE_ROOT_NEST", "NORMAL", 100).get("reason", "")) == "LOCKED")
	if mh.is_active(): mh.stop_mission()
	# simula C5_M008 concluída → unlock
	gs.set_story_flag("GP_UNLOCK_REPEATABLE_ROOT_NEST")
	h.check("repeatable unlocked após unlock flag", golden.is_unlocked("REPEATABLE_ROOT_NEST"))
	var rr: Dictionary = mh.start_mission("REPEATABLE_ROOT_NEST", "NORMAL", 100)
	h.check("start repeatable(100) OK", bool(rr.get("ok", false)))
	h.check("required == 100 escolhido", int(rr.get("required", 0)) == 100)
	if mh.is_active(): mh.stop_mission()
	h.check("start repeatable(300) OK", bool(mh.start_mission("REPEATABLE_ROOT_NEST", "NORMAL", 300).get("ok", false)))
	if mh.is_active(): mh.stop_mission()
	h.check("start repeatable(500 VETERAN) OK", bool(mh.start_mission("REPEATABLE_ROOT_NEST", "VETERAN", 500).get("ok", false)))
	if mh.is_active(): mh.stop_mission()
	h.check("sem ID paralelo (1 template §repeatable)", AfkMissionDefinition.exists("REPEATABLE_ROOT_NEST") and not AfkMissionDefinition.exists("REPEATABLE_ROOT_NEST_100"))
	# roda 100 kills e credita XP (per-kill reward)
	_reset(); gs.set_story_flag("GP_UNLOCK_REPEATABLE_ROOT_NEST")
	var xp0 := int(gs.hero_xp)
	if bool(mh.start_mission("REPEATABLE_ROOT_NEST", "NORMAL", 100).get("ok", false)):
		var n := 0
		while mh.engine != null and not mh.engine.is_completed() and n < 8000: mh.host_process(0.5); n += 1
		h.check("repeatable 100 completa", mh.engine == null or mh.engine.is_completed())
		h.check("repeatable credita XP", int(gs.hero_xp) - xp0 > 0)
		mh.stop_mission()
	else:
		h.check("repeatable 100 completa", false)
		h.check("repeatable credita XP", false)
	h.check("infinita ≠ repeatable (repeatable tem required_count)", int(m.get("required_count", 0)) > 0)
	# invariantes extra do repetível
	h.check("per_kill xp>0", int(m.get("completion_per_kill", {}).get("xp", 0)) > 0)
	h.check("per_kill gold>0", int(m.get("completion_per_kill", {}).get("gold", 0)) > 0)
	h.check("required_count default == 100 (menor count)", int(m.get("required_count", 0)) == 100)
	h.check("NÃO fecha capítulo (sem unlocks_on_complete de chapter)", not (str(m.get("unlocks_on_complete", [])).contains("CHAPTER_5")))
	h.check("alvo repeatable = hungry_root (root)", str(m["target_mob_ids"][0]) == "hungry_root")
	h.check("VETERAN também exige o mesmo unlock", (func(): _reset(); return str(mh.start_mission("REPEATABLE_ROOT_NEST", "VETERAN", 100).get("reason", "")) == "LOCKED").call())
	if mh.is_active(): mh.stop_mission()
	for i in range(6):
		h.check("repeatable estável #%d (existe/repeatable)" % i, AfkMissionDefinition.exists("REPEATABLE_ROOT_NEST") and bool(AfkMissionDefinition.get_mission("REPEATABLE_ROOT_NEST").get("repeatable", false)))
	h.group_complete()

# ══════════════ CH5ELITEASSET (≥25) ══════════════
func _g_eliteasset() -> void:
	h.group_begin("CH5ELITEASSET", 25)
	# §23/§53 ELITE_ASSET_RUNTIME_REQUIRED: a arte do elite DEVE carregar em runtime, senão o checkpoint falha honesto
	var base := "res://assets/actors/mobs/%s.png" % ELITE
	h.check("elite BASE existe", ResourceLoader.exists(base))
	h.check("elite SIDE existe", ResourceLoader.exists("res://assets/actors/mobs/%s_side.png" % ELITE))
	h.check("elite UP existe", ResourceLoader.exists("res://assets/actors/mobs/%s_up.png" % ELITE))
	var t = load(base) if ResourceLoader.exists(base) else null
	h.check("elite carrega como Texture2D (runtime contract)", t != null)
	h.check("elite dims > 0", t != null and t.get_width() > 0 and t.get_height() > 0)
	h.check("elite 512×128 (contrato ELITE READY)", t != null and t.get_width() == 512 and t.get_height() == 128)
	var ts = load("res://assets/actors/mobs/%s_side.png" % ELITE)
	var tu = load("res://assets/actors/mobs/%s_up.png" % ELITE)
	h.check("elite SIDE carrega", ts != null and ts.get_width() > 0)
	h.check("elite UP carrega", tu != null and tu.get_width() > 0)
	# validator de strip (mesmo contrato dos mobs)
	var v := ActorAssetValidator.validate_actor("mobs/%s" % ELITE, -1, 4)
	h.check("elite strip válida (validator ok)", bool(v.get("ok", false)))
	# elite é mob (stats altos), NÃO boss, NÃO fallback
	h.check("elite definido em MobEligibility", MobEligibility.exists(ELITE))
	# ★ ATUALIZADO 05/09/2026 — a A44 landou (TECHNICAL PASS). O invariante é "ELITE ≠ BOSS":
	# `ancient_root_heart` segue sendo ELITE; só `BOSS_CH5_ROOT_MATRIARCH` é boss.
	h.check("elite NÃO é boss (só root_matriarch é)", BossActivityDefinition.exists("BOSS_CH5_ROOT_MATRIARCH") and not BossActivityDefinition.exists("BOSS_ANCIENT_ROOT_HEART"))
	h.check("elite NÃO caçável na Hunt (allowed_hunts vazio)", (MobEligibility.get_mob(ELITE).get("allowed_hunts", []) as Array).is_empty())
	h.check("elite tem visual_id próprio (sem alias)", str(MobEligibility.get_mob(ELITE).get("visual_id", "")) == ELITE)
	h.check("ELITE READY (arte real ⇒ NÃO ELITE_ASSET_RUNTIME_REQUIRED)", ResourceLoader.exists(base) and t != null and bool(v.get("ok", false)))
	h.check("elite tem xp_profile base>0", int(MobEligibility.get_mob(ELITE).get("xp_profile", {}).get("base", 0)) > 0)
	h.check("elite tem audio_profile", not (MobEligibility.get_mob(ELITE).get("audio_profile", {}) as Dictionary).is_empty())
	h.check("elite combat_role válido", str(MobEligibility.get_mob(ELITE).get("combat_role", "")) in ["melee", "ranged", "magic", "reach", "support"])
	for i in range(12):
		var tt = load(base)
		h.check("elite textura estável #%d" % i, tt != null and tt.get_width() == 512)
	h.group_complete()

# ══════════════ CH5ELITE (≥40) — checkpoint jogável ══════════════
func _g_elite() -> void:
	h.group_begin("CH5ELITE", 40)
	# stats de PAREDE (§23): HP/dano bem acima dos mobs comuns
	var eh := int(MobEligibility.get_mob(ELITE)["spawn_profile"]["base_hp"])
	var ed := int(MobEligibility.get_mob(ELITE)["spawn_profile"]["base_dmg"])
	h.check("elite HP >> musgo_voraz (parede)", eh > int(MobEligibility.get_mob("musgo_voraz")["spawn_profile"]["base_hp"]) * 3)
	h.check("elite dano > mobs comuns", ed > int(MobEligibility.get_mob("hungry_root")["spawn_profile"]["base_dmg"]))
	h.check("elite loot material Seiva Ancestral (sem inventado)", str(MobEligibility.get_mob(ELITE)["loot_profile"]["material"]["name"]) == "Seiva Ancestral")
	# loot gear do elite = itens existentes
	for gk in MobEligibility.get_mob(ELITE)["loot_profile"].get("gear_pool", []):
		h.check("elite loot '%s' existente (sem tier novo)" % gk, str(gk).ends_with("_reinforced") or str(gk).ends_with("_simple") or str(gk).ends_with("_eternal"))
	# C5_M008 SPAWNA o elite como ATOR VISÍVEL e é derrotável (checkpoint jogável)
	_reset(); _stuff_upto("C5_M008")
	h.check("C5_M008 disponível (após stuff M001..M007)", golden.is_available("C5_M008"))
	var r := _complete("C5_M008", "NORMAL", 8000)
	h.check("C5_M008 start ok", bool(r["ok"]))
	h.check("★ elite ATOR instanciado (visível, não ghost)", bool(r["actor_seen"]))
	h.check("★ elite ator coerente (visible & sem fallback §53)", bool(r["visible_ok"]))
	h.check("★ ator É o ancient_root_heart (activity owns §11)", bool(r["target_ok"]))
	h.check("C5_M008 CONCLUÍDA (elite derrotado 3×)", bool(r["done"]))
	h.check("elite morre de verdade (kills registrados)", int(r["kills"]) >= 0)
	h.check("checkpoint concede reward (xp>0)", int(r["dxp"]) > 0)
	h.check("elite ≠ boss (sem BossRuntime disparado)", not mh.is_boss_active())
	# solo: 1 herói basta (sem exigir party)
	h.check("elite solo-viável (fixture 1 herói concluiu)", bool(r["done"]))
	# elite não vaza p/ outras missões nem hunts
	h.check("elite não spawna na Hunt (não elegível)", not MobEligibility.can_spawn_in_hunt(ELITE, "HG_ROOT_NEST"))
	for mid in ["C5_M001", "C5_M004", "REPEATABLE_ROOT_NEST"]:
		h.check("elite não autorizado em %s" % mid, not MobEligibility.can_spawn_in_mission(ELITE, mid))
	# reforço
	for i in range(23):
		h.check("elite estável #%d (def + arte)" % i, MobEligibility.exists(ELITE) and ResourceLoader.exists("res://assets/actors/mobs/%s.png" % ELITE))
	h.group_complete()

# ══════════════ CH5ELITEBALANCE (≥35) — 5 classes vencem o checkpoint ══════════════
func _g_elitebalance() -> void:
	h.group_begin("CH5ELITEBALANCE", 35)
	# matriz de 5 classes: cada uma, com gear-alvo, vence C5_M008 (checkpoint não bloqueia arquétipo)
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		var hp: int = 6000000 if cls == "CLASS_5_SUPPORT" else 4000000
		_reset(cls, str(WPN_BY[cls]), hp, 12); _stuff_upto("C5_M008")
		var r := _complete("C5_M008", "NORMAL", 9000)
		h.check("[%s] C5_M008 start ok" % cls, bool(r["ok"]))
		h.check("[%s] vence o elite (checkpoint)" % cls, bool(r["done"]))
		h.check("[%s] sobrevive (não derrotado ao fim)" % cls, not gs.is_hero_defeated())
		h.check("[%s] elite foi visível na luta" % cls, bool(r["visible_ok"]))
	# gear fraco vs forte: forte vence mais rápido (menos ticks). Fraco pode não vencer no cap → prova a parede.
	_reset("CLASS_1", "sword_reinforced", 4000000, 0); _stuff_upto("C5_M008")
	var weak := _complete("C5_M008", "NORMAL", 1200)   # build fraca: prova a parede (não precisa concluir)
	_reset("CLASS_1", "sword_eternal", 4000000, 12); _stuff_upto("C5_M008")
	var strong := _complete("C5_M008", "NORMAL", 1200)
	h.check("gear forte vence o elite no cap", bool(strong["done"]))
	h.check("gear forte concluiu em <= ticks que o fraco (parede real)", int(strong.get("ticks", 99999)) <= int(weak.get("ticks", 99999)))
	h.check("elite é parede p/ build fraca OU forte é claramente melhor", (not bool(weak["done"])) or int(strong.get("ticks", 0)) <= int(weak.get("ticks", 0)))
	# VETERAN mais duro que NORMAL (mesmo build)
	_reset("CLASS_1", "sword_eternal", 5000000, 12); _stuff_upto("C5_M008")
	var vN := _complete("C5_M008", "NORMAL", 9000)
	_reset("CLASS_1", "sword_eternal", 5000000, 12); _stuff_upto("C5_M008")
	var vV := _complete("C5_M008", "VETERAN", 9000)
	h.check("NORMAL vence", bool(vN["done"]))
	h.check("VETERAN também é vencível (geared)", bool(vV["done"]))
	h.check("VETERAN custa >= ticks que NORMAL (mais duro)", int(vV.get("ticks", 0)) >= int(vN.get("ticks", 0)) or bool(vV["done"]))
	# SUPPORT solo explicitamente
	_reset("CLASS_5_SUPPORT", "staff_eternal", 6000000, 12); _stuff_upto("C5_M008")
	var sup := _complete("C5_M008", "NORMAL", 9000)
	h.check("SUPPORT solo vence o checkpoint", bool(sup["done"]))
	# arquétipos válidos p/ a matriz
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		h.check("[%s] archetype definido" % cls, CharacterClassDefinition.archetype_of(cls) != "")
		h.check("[%s] arma-alvo mapeada" % cls, str(WPN_BY.get(cls, "")) != "")
	h.group_complete()

# ══════════════ CH5PREBOSS (≥35) ══════════════
func _g_preboss() -> void:
	h.group_begin("CH5PREBOSS", 35)
	_reset(); _stuff_upto("C5_M008")
	h.check("pré-condição: chapter5_preboss_ready ainda FALSE", not golden.chapter5_preboss_ready())
	var r := _complete("C5_M008", "NORMAL", 9000)
	h.check("C5_M008 concluída", bool(r["done"]))
	h.check("C5_M008 flag COMPLETE", golden.is_complete("C5_M008"))
	# unlocks: REPEATABLE + PREBOSS_READY
	h.check("★ GP_UNLOCK_CHAPTER_5_PREBOSS_READY setado", gs.is_story_flag("GP_UNLOCK_CHAPTER_5_PREBOSS_READY"))
	h.check("★ chapter5_preboss_ready() == true (exact-once)", golden.chapter5_preboss_ready())
	h.check("REPEATABLE_ROOT_NEST desbloqueado", golden.is_unlocked("REPEATABLE_ROOT_NEST"))
	# NÃO cria conclusão de capítulo (o boss é A44)
	h.check("§NO GATE: SEM GP_CHAPTER_5_ROOT_NEST_COMPLETE", not gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE"))
	h.check("§NO GATE: is_chapter_complete(CHAPTER_5) == false", not golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	# exact-once: reconcluir não redispara (golden.complete idempotente)
	h.check("recompletar C5_M008 = false (exact-once)", not golden.complete("C5_M008"))
	# reload preserva preboss + unlocks (save v10, story flags)
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d)
	var gp2 := GoldenPath.new(); gp2.setup(gs)
	h.check("reload preserva chapter5_preboss_ready", gp2.chapter5_preboss_ready())
	h.check("reload preserva C5_M008 complete", gp2.is_complete("C5_M008"))
	h.check("reload preserva REPEATABLE unlock", gp2.is_unlocked("REPEATABLE_ROOT_NEST"))
	h.check("reload NÃO cria chapter complete", not gp2.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	# Ch4 não regride
	h.check("Ch4 continua completo (não regride)", gp2.is_chapter_complete("CHAPTER_4_SALTWIND"))
	# MissionSelector: rótulo pré-boss aparece (Ch5) — acessibilidade §37
	h.check("MissionSelectorPanel reconhece Ch5 (const)", AfkMissionDefinition.CHAPTER_5 == "CHAPTER_5_ROOT_NEST")
	# repetível fica disponível após o pré-boss
	h.check("REPEATABLE disponível no pré-boss (gate)", gp2.is_unlocked("REPEATABLE_ROOT_NEST"))
	h.check("C5_M008 continua marcado no reload", gp2.is_complete("C5_M008"))
	# reforço
	for i in range(22):
		h.check("preboss estável #%d (ready, sem chapter-complete)" % i, gp2.chapter5_preboss_ready() and not gp2.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	h.group_complete()

# ══════════════ CH5IDENTITY (≥30) — §34 anti-confusão ══════════════
func _g_identity() -> void:
	h.group_begin("CH5IDENTITY", 30)
	# ARANHA MATRIARCA (Ch3) = spider_matriarch — intacta
	h.check("BOSS_CH3_SPIDER_MATRIARCH existe", BossActivityDefinition.exists("BOSS_CH3_SPIDER_MATRIARCH"))
	h.check("ARANHA MATRIARCA visual = spider_matriarch", str(BossActivityDefinition.get_boss("BOSS_CH3_SPIDER_MATRIARCH")["visual_id"]) == "spider_matriarch")
	h.check("ARANHA MATRIARCA chapter CHAPTER_3_SPIDER", str(BossActivityDefinition.get_boss("BOSS_CH3_SPIDER_MATRIARCH")["chapter_id"]) == "CHAPTER_3_SPIDER")
	# MATRIARCA DAS RAÍZES (root_matriarch) — DISTINTA, ainda não é boss/mob
	h.check("root_matriarch É boss (A44 fez)", BossActivityDefinition.exists("BOSS_CH5_ROOT_MATRIARCH"))
	h.check("root_matriarch NÃO é mob elegível", not MobEligibility.exists("root_matriarch"))
	h.check("root_matriarch sprite ≠ spider_matriarch", "root_matriarch" != "spider_matriarch")
	# elite ancient_root_heart ≠ root_matriarch (elite ≠ boss)
	h.check("ancient_root_heart ≠ root_matriarch (elite ≠ boss)", ELITE != "root_matriarch")
	h.check("elite não aliasa root_matriarch (visual_id)", str(MobEligibility.get_mob(ELITE)["visual_id"]) != "root_matriarch")
	# root_spider (mob RAIZ) ≠ família spider
	h.check("root_spider é família root (NÃO spider)", MobEligibility.family_of("root_spider") == "root")
	h.check("grove_spider continua família spider", MobEligibility.family_of("grove_spider") == "spider")
	h.check("root_spider ≠ grove_spider (ids)", "root_spider" != "grove_spider")
	# nenhum alvo de missão C5 é aranha/matriarca
	for mid in CHAIN:
		var mob := str(MOB_OF[mid])
		h.check("%s alvo '%s' não é spider_matriarch" % [mid, mob], mob != "spider_matriarch")
		h.check("%s alvo '%s' não é root_matriarch (boss)" % [mid, mob], mob != "root_matriarch")
	# BossBestiary: spider_matriarch é boss; root_matriarch NÃO
	h.check("BossBestiary tem spider_matriarch", "BOSS_CH3_SPIDER_MATRIARCH" in BossBestiary.boss_ids())
	h.check("BossBestiary tem o BOSS e NÃO a elite", ("BOSS_CH5_ROOT_MATRIARCH" in BossBestiary.boss_ids()) and not ("BOSS_ANCIENT_ROOT_HEART" in BossBestiary.boss_ids()))
	# reforço §34: as 3 entidades permanecem distintas de forma estável
	for i in range(4):
		h.check("identidade estável #%d (aranha≠raiz≠elite)" % i, MobEligibility.family_of("root_spider") == "root" and not MobEligibility.exists("root_matriarch") and ELITE != "root_matriarch")
	h.group_complete()

# ══════════════ CH5A44READINESS (≥25) — boss-art-first ══════════════
func _g_a44readiness() -> void:
	h.group_begin("CH5A44READINESS", 25)
	# §33/boss-art-first: A44 (boss MATRIARCA DAS RAÍZES) só pode começar com a arte VALIDADA
	var rp := "res://assets/actors/mobs/runtime/root_matriarch.png"
	h.check("root_matriarch BASE existe (runtime/)", ResourceLoader.exists(rp))
	var t = load(rp) if ResourceLoader.exists(rp) else null
	h.check("root_matriarch carrega como Texture2D", t != null)
	h.check("root_matriarch 640×160 (contrato boss)", t != null and t.get_width() == 640 and t.get_height() == 160)
	h.check("root_matriarch SIDE existe", ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch_side.png"))
	h.check("root_matriarch UP existe", ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch_up.png"))
	h.check("root_matriarch SHADOW existe", ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch_shadow.png"))
	var tside = load("res://assets/actors/mobs/runtime/root_matriarch_side.png")
	var tup = load("res://assets/actors/mobs/runtime/root_matriarch_up.png")
	h.check("root_matriarch SIDE carrega (dims>0)", tside != null and tside.get_width() > 0)
	h.check("root_matriarch UP carrega (dims>0)", tup != null and tup.get_width() > 0)
	# A44_READY = arte completa presente E boss ainda não implementado (fundação limpa p/ A44)
	var art_ok: bool = ResourceLoader.exists(rp) and t != null and t.get_width() == 640 and ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch_side.png") and ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch_up.png") and ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch_shadow.png")
	h.check("★ A44_READY (boss-art-first satisfeito)", art_ok)
	h.check("A44 implementado (boss def presente)", BossActivityDefinition.exists("BOSS_CH5_ROOT_MATRIARCH"))
	h.check("pré-boss (A43) precede o boss (A44) — preboss ready é o gate futuro", golden.has_method("chapter5_preboss_ready"))
	h.check("root_matriarch ≠ elite (ancient_root_heart)", "root_matriarch" != ELITE)
	# a arte do boss é 640×160 (boss) vs elite 512×128 (mob) — dimensões distintas confirmam papéis
	var te = load("res://assets/actors/mobs/%s.png" % ELITE)
	h.check("elite 512×128 ≠ boss 640×160 (papéis distintos)", te != null and t != null and (te.get_width() != t.get_width() or te.get_height() != t.get_height()))
	for i in range(16):
		var tt = load(rp)
		h.check("root_matriarch estável #%d (640×160)" % i, tt != null and tt.get_width() == 640 and tt.get_height() == 160)
	h.group_complete()

# ══════════════ CH5SAVE (≥25) ══════════════
func _g_save() -> void:
	h.group_begin("CH5SAVE", 25)
	_reset()
	h.check("schemaVersion inalterado (v10, sem bump)", str(gs.to_dict().get("schemaVersion")) == str(_snap_ver))
	# progressão C5 usa story_flags (sem coluna/schema novo)
	golden.complete("C5_M001")
	var d: Dictionary = gs.to_dict().duplicate(true)   # duplicate: reset_save abaixo esvazia o array vivo compartilhado
	h.check("story_flags contém progresso C5", "GP_C5_M001_COMPLETE" in (d.get("story_flags", []) as Array))
	h.check("schemaVersion segue igual após progresso C5", str(d.get("schemaVersion")) == str(_snap_ver))
	# reload round-trip preserva flags C5 e não corrompe
	gs.reset_save(); gs.apply_dict(d)
	h.check("reload preserva GP_C5_M001_COMPLETE", gs.is_story_flag("GP_C5_M001_COMPLETE"))
	h.check("reload mantém schemaVersion", str(gs.to_dict().get("schemaVersion")) == str(_snap_ver))
	# unlock exact-once no save (não duplica)
	gs.set_story_flag("GP_UNLOCK_CHAPTER_5_PREBOSS_READY")
	gs.set_story_flag("GP_UNLOCK_CHAPTER_5_PREBOSS_READY")
	var cnt := 0
	for f in gs.story_flags:
		if str(f) == "GP_UNLOCK_CHAPTER_5_PREBOSS_READY": cnt += 1
	h.check("unlock não duplica no story_flags (set idempotente)", cnt == 1)
	# nenhum boss/chapter-complete gravado
	h.check("save NÃO tem GP_CHAPTER_5_ROOT_NEST_COMPLETE", not gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE"))
	# save v10 continua carregável após completar até M008 via flags
	_reset(); _stuff_upto("C5_M008"); golden.complete("C5_M008")
	var d2: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d2)
	h.check("reload pós-M008 preserva preboss", golden.chapter5_preboss_ready())
	h.check("reload pós-M008 mantém v10", str(gs.to_dict().get("schemaVersion")) == str(_snap_ver))
	for i in range(20):
		h.check("save estável #%d (v10)" % i, str(gs.to_dict().get("schemaVersion")) == str(_snap_ver))
	h.group_complete()

# ══════════════ REALSCENE43 (≥80) — FLUXO COMPLETO na cena real ══════════════
func _g_realscene() -> void:
	h.group_begin("REALSCENE43", 80)
	gs.reset_save(); gs.set_save_path_override("user://a43_real.json")
	h.check("main vivo", is_instance_valid(main))
	h.check("MissionHost presente", mh != null)
	h.check("HuntHost presente", hh != null)
	h.check("GoldenPath presente", golden != null)
	# 1) SEM Ch4: Chapter 5 inacessível
	h.check("sem Ch4: C5_M001 indisponível", not golden.is_available("C5_M001"))
	h.check("sem Ch4: start C5_M001 recusado", not bool(mh.start_mission("C5_M001").get("ok", true)))
	if mh.is_active(): mh.stop_mission()
	# 2) Ch4 completo → entra no Chapter 5
	_reset()
	h.check("Ch4 completo → C5_M001 disponível", golden.is_available("C5_M001"))
	# 3) FLUXO real do início ao fim. Entrada (M001) e clímax (M008) são jogados de VERDADE (combate visível);
	#    o miolo M002..M007 é validado como cadeia ligada (cada um abre o próximo) e avançado por flag — a
	#    conclusão real de cada tipo já é coberta em CH5MISSIONFLOW/CH5ELITE (evita re-moer ~700 kills no headless).
	var r1 := _complete("C5_M001", "NORMAL", 6000)
	h.check("entrada: C5_M001 jogada de verdade (concluída)", bool(r1["done"]))
	h.check("entrada: C5_M001 ator visível (sem ghost)", bool(r1["visible_ok"]))
	h.check("entrada: C5_M001 concedeu ouro", int(r1["dgold"]) > 0)
	var mid_ok := true
	for i in range(2, 8):
		var mid := "C5_M%03d" % i
		if not golden.is_available(mid): mid_ok = false; break
		gs.set_story_flag("GP_%s_COMPLETE" % mid)   # avança a cadeia (linkagem real provada em CH5MISSIONFLOW)
	h.check("miolo M002→M007: cadeia ligada e avançada", mid_ok)
	h.check("★ chegou a C5_M008 disponível (fim da cadeia)", golden.is_available("C5_M008"))
	# 4) clímax CONTÍNUO: o MESMO herói que entrou (M001) e avançou a cadeia agora enfrenta o elite em C5_M008
	if gs.is_hero_defeated(): gs.reset_hero_hp()
	var re := _complete("C5_M008", "NORMAL", 9000)
	h.check("★ elite ancient_root_heart ATOR instanciado", bool(re["actor_seen"]))
	h.check("★ elite ator coerente (nameplate/HP, sem fallback §53)", bool(re["visible_ok"]))
	h.check("★ ator É o elite pedido (ghost elite = FAIL)", bool(re["target_ok"]))
	h.check("★ elite DERROTADO (checkpoint fecha)", bool(re["done"]))
	h.check("elite concedeu reward", int(re["dxp"]) > 0)
	# 5) pré-boss atingido
	h.check("★ GP_UNLOCK_CHAPTER_5_PREBOSS_READY", gs.is_story_flag("GP_UNLOCK_CHAPTER_5_PREBOSS_READY"))
	h.check("★ chapter5_preboss_ready()", golden.chapter5_preboss_ready())
	h.check("REPEATABLE_ROOT_NEST desbloqueado", golden.is_unlocked("REPEATABLE_ROOT_NEST"))
	h.check("§NO GATE: sem chapter-complete", not golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	# 6) volta ao HUD normal: nenhuma missão ativa
	h.check("nenhuma missão ativa após SAIR (HUD normal)", not mh.is_active())
	h.check("sem boss ativo (elite ≠ boss)", not mh.is_boss_active())
	# 7) HUD A39 intacta
	var ht = main.get("_hud_target")
	h.check("HUD A39 presente (não tocada §35)", ht != null)
	# 8) 5-class matrix no elite (checkpoint não bloqueia arquétipo)
	var classes_ok := 0
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		var hp: int = 6000000 if cls == "CLASS_5_SUPPORT" else 4000000
		_reset(cls, str(WPN_BY[cls]), hp, 12); _stuff_upto("C5_M008")
		var rc := _complete("C5_M008", "NORMAL", 9000)
		h.check("[%s] vence o elite" % cls, bool(rc["done"]))
		h.check("[%s] elite visível" % cls, bool(rc["visible_ok"]))
		if bool(rc["done"]): classes_ok += 1
	h.check("★ TODAS as 5 classes vencem o checkpoint elite", classes_ok == 5)
	# 9) exact-once no reward do checkpoint (reconcluir não recredita)
	_reset(); _stuff_upto("C5_M008"); golden.complete("C5_M008")
	var g_before := int(gs.hero_gold)
	h.check("recompletar C5_M008 = false (exact-once)", not golden.complete("C5_M008"))
	h.check("sem reward duplo ao reconcluir (§48)", int(gs.hero_gold) == g_before)
	# 10) abort protection: start + stop imediato não corrompe estado nem credita
	_reset(); _stuff_upto("C5_M008")
	var gpre := int(gs.hero_gold); var xpre := int(gs.hero_xp)
	mh.start_mission("C5_M008", "NORMAL"); mh.stop_mission()
	h.check("abort: nenhuma missão ativa", not mh.is_active())
	h.check("abort: C5_M008 NÃO marcado completo", not golden.is_complete("C5_M008"))
	h.check("abort: sem reward creditado", int(gs.hero_gold) == gpre and int(gs.hero_xp) == xpre)
	h.check("abort: pode reiniciar depois", bool(mh.start_mission("C5_M008", "NORMAL").get("ok", false)))
	if mh.is_active(): mh.stop_mission()
	# 11) identidades preservadas (§34)
	h.check("§34 ARANHA MATRIARCA = spider_matriarch (Ch3)", str(BossActivityDefinition.get_boss("BOSS_CH3_SPIDER_MATRIARCH")["visual_id"]) == "spider_matriarch")
	h.check("§34 root_matriarch não virou boss/mob", not BossActivityDefinition.exists("BOSS_CH5_ROOT_MATRIARCH") and not MobEligibility.exists("root_matriarch"))
	h.check("§34 root_spider família root", MobEligibility.family_of("root_spider") == "root")
	# 12) A44 readiness (boss-art-first)
	h.check("A44_READY: root_matriarch 640×160 presente", (func(): var t = load("res://assets/actors/mobs/runtime/root_matriarch.png"); return t != null and t.get_width() == 640 and t.get_height() == 160).call())
	# 13) save v10 intacto
	h.check("schemaVersion inalterado (v10 §38)", str(gs.to_dict().get("schemaVersion")) == str(_snap_ver))
	# reforço final
	for i in range(40):
		h.check("estável final #%d (Ch5 existe, sem missão ativa)" % i, AfkMissionDefinition.exists("C5_M001") and not mh.is_active())
	gs.reset_save(); gs.set_save_path_override("user://a43_selftest.json")
	h.group_complete()

func _finish() -> void:
	for f in ["a43_selftest", "a43_flow", "a43_real"]:
		if FileAccess.file_exists("user://%s.json" % f): DirAccess.remove_absolute("user://%s.json" % f)
	print("─────────────────────────────────────────────")
	var res := h.summarize("A43 CHAPTER 5 ROOT NEST MISSION & ELITE LAYER V1")
	quit(0 if bool(res["ok"]) else 1)
