extends SceneTree
## A22REALSCENE — prova na CENA REAL (Main.tscn): FLOW A (Refine→falta material→Como Obter→mob source→Targeted Hunt
## →teleport→mob visível→kill→Direct Loot→goal progride/completa→Hunt continua→return origin) e
## FLOW B (item→Boss source→AVAILABLE→ENFRENTAR→Boss visível). Frames de verdade.

var main: Node = null
var _frame := 0
var _phase := 0
var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _phase == 0 and _frame >= 3:
		_phase = 1
		if main.has_method("_enter_game"): main._enter_game()
	elif _phase == 1 and _frame >= 8:
		_phase = 2
		_run()
		print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
		quit(0 if _fail == 0 else 1)

func _prep(gs) -> void:
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {}
	gs.hero_hp_max = 9000; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0
	gs.stage_highest_global = 60; gs.materials = {"Fragmentos": 5000, "Núcleo de Cristal": 0}
	gs.tracked_goal = {}; gs.acquisition_intent = {}; gs.tracked_boss = {}
	var f: Array[String] = ["GP_MISSION_006_COMPLETE"]
	for m in ["C2_M001", "C2_M002", "C2_M003", "C2_M004", "C2_M005", "C2_M006", "C2_M007", "C2_M008"]: f.append("GP_%s_COMPLETE" % m)
	f.append("GP_UNLOCK_HUNT_CRYSTAL"); f.append("GP_UNLOCK_REPEATABLE_CRYSTAL"); gs.story_flags = f

func _run() -> void:
	print("  ── A22 SCENE (Main.tscn) ──")
	var mh = main.get("_missionhost"); var hh = main.get("_hunthost")
	var gs = root.get_node_or_null("GameState"); var pl: Node2D = main.get("_player")
	_prep(gs)
	var res := AcquisitionResolver.new(); res.setup(gs)
	# ═══ FLOW A: Refine precisa de Núcleo de Cristal ═══
	res.set_intent("REFINE", "weapon", "Núcleo de Cristal")
	var goal := res.start_goal("Núcleo de Cristal", 2, "REFINE", "weapon", {})
	_chk("A22RS-T01 intent Refine + goal criado", res.has_goal() and str(res.intent()["origin_system"]) == "REFINE")
	var sources := res.resolve("Núcleo de Cristal")
	var mob_src := sources.filter(func(s): return str(s.get("nav_action", "")) == "TARGETED_HUNT" and str(s.get("nav_mob", "")) == "living_shard")
	_chk("A22RS-T02 source panel tem mob (living_shard)", mob_src.size() > 0)
	_chk("A22RS-T03 source AVAILABLE (caça infinita)", mob_src.size() > 0 and bool(mob_src[0]["available"]))
	var ground := str(mob_src[0]["nav_ground"]); var target := str(mob_src[0]["nav_mob"])
	# one-click: item → source → targeted hunt → teleport
	var r = hh.start(ground, target, "NORMAL")
	_chk("A22RS-T04 Targeted Hunt confirm→teleport ok", bool(r.get("ok", false)) and hh.is_hunting())
	_chk("A22RS-T05 teleport (player no anchor)", pl.position == hh._anchor)
	for i in range(20): hh.host_process(0.4)
	var wct := 0
	while hh.mob_actor() == null and wct < 40: hh.host_process(0.15); wct += 1
	_chk("A22RS-T06 Caverna: Errante visível", pl.is_visible_in_tree())
	_chk("A22RS-T07 player visível", pl.visible)
	_chk("A22RS-T08 mob-alvo VISÍVEL (living_shard, sprite real)", hh.mob_actor() != null and hh.mob_actor().is_visible_in_tree() and not hh.mob_actor().used_fallback)
	_chk("A22RS-T09 SÓ o alvo (mob_id=living_shard)", hh.mob_actor() != null and hh.mob_actor().mob_id == "living_shard")
	var rt = hh.get("_runtime")
	_chk("A22RS-T10 combate bidirecional (dealt+taken)", int(rt.runtime_stats["damage_dealt"]) > 0 and int(rt.runtime_stats["damage_taken"]) > 0)
	_chk("A22RS-T11 kill", int(rt.runtime_stats["kills"]) > 0)
	_chk("A22RS-T12 Direct Loot (XP, sem floor)", int(gs.hero_xp) > 0)
	# goal progride até completar (material dropa do mob-alvo)
	var g := 0
	while not res.goal_check_complete() and g < 3000: hh.host_process(0.3); g += 1
	_chk("A22RS-T13 tracked quantity subiu (material do alvo)", res.goal_progress()["have"] >= 2)
	_chk("A22RS-T14 goal COMPLETO", res.goal_progress()["complete"])
	_chk("A22RS-T15 Hunt CONTINUA após goal (não força saída)", hh.is_hunting())
	# return origin
	var back := res.return_target()
	_chk("A22RS-T16 return origin válido (REFINE/weapon)", str(back["origin_system"]) == "REFINE" and str(back["origin_context_id"]) == "weapon")
	hh.stop()
	_chk("A22RS-T17 saída limpa (not hunting, sem ator)", not hh.is_hunting() and hh.mob_actor() == null)
	# ═══ FLOW B: item de boss ═══
	_prep(gs)
	var db := res.resolve("sword_reinforced")
	var boss_src := db.filter(func(s): return str(s.get("nav_action", "")) == "BOSS_FIGHT" and str(s.get("nav_boss", "")) == "BOSS_CRYSTAL_GOLEM")
	_chk("A22RS-T18 Boss source panel (Golem)", boss_src.size() > 0)
	_chk("A22RS-T19 Boss AVAILABLE (story ALWAYS)", boss_src.size() > 0 and bool(boss_src[0]["available"]))
	var rb = mh.start_boss(str(boss_src[0]["nav_boss"]), true)   # skip intro p/ ir ao combate
	_chk("A22RS-T20 ENFRENTAR→teleport ok", bool(rb.get("ok", false)))
	for i in range(20): mh.host_process(0.4)
	_chk("A22RS-T21 Golem VISÍVEL (sprite real)", mh.mob_actor() != null and mh.mob_actor().is_visible_in_tree() and mh.mob_actor().mob_id == "BOSS_CRYSTAL_GOLEM")
	_chk("A22RS-T22 boss HP cai (combate bidirecional)", mh.boss.boss_hp_frac() < 1.0)
	_chk("A22RS-T23 player travado + visível (boss)", pl.locked and pl.is_visible_in_tree())
	mh.stop_boss()
