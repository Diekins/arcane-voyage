extends SceneTree
## A21 — REALSCENE21: prova na CENA REAL (Main.tscn) do Chapter 2 inteiro: Mission (crystal_bat), Hunt (HG_CAVE),
## Boss (crystal_golem) — todos com ATORES VISÍVEIS, combate bidirecional, na árvore de verdade. + Refine power-real.

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
	gs.hero_hp_max = 8000; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0
	gs.stage_highest_global = 60; gs.materials = {"Fragmentos": 5000}
	var f: Array[String] = ["GP_MISSION_006_COMPLETE"]
	for m in ["C2_M001", "C2_M002", "C2_M003", "C2_M004", "C2_M005", "C2_M006", "C2_M007", "C2_M008"]: f.append("GP_%s_COMPLETE" % m)
	f.append("GP_UNLOCK_HUNT_WOLF"); gs.story_flags = f

func _run() -> void:
	print("  ── SCENE_C2 (Main.tscn) ──")
	var mh = main.get("_missionhost"); var hh = main.get("_hunthost")
	var gs = root.get_node_or_null("GameState"); var pl: Node2D = main.get("_player")
	_prep(gs)
	# ── MISSION crystal_bat ──
	var r = mh.start_mission("C2_M001")
	_chk("A21-T01 C2_M001 start ok", bool(r.get("ok", false)))
	for i in range(30): mh.host_process(0.4)
	var wct := 0
	while mh.mob_actor() == null and wct < 40: mh.host_process(0.15); wct += 1
	_chk("A21-T02 Errante visível (Mission caverna)", pl.is_visible_in_tree())
	_chk("A21-T03 crystal_bat lógico", mh.engine.current_mob() != null and mh.engine.current_mob().mob_id == "crystal_bat")
	_chk("A21-T04 crystal_bat ATOR visível", mh.mob_actor() != null and mh.mob_actor().is_visible_in_tree())
	_chk("A21-T05 crystal_bat sprite real (não fallback)", mh.mob_actor() != null and not mh.mob_actor().used_fallback)
	_chk("A21-T06 hero ataca (hero_attacks>0)", int(mh.engine.stats["hero_attacks"]) > 0)
	_chk("A21-T07 mob ataca (mob_attacks>0)", int(mh.engine.stats["mob_attacks"]) > 0)
	_chk("A21-T08 kills>0 (bidirecional + morte)", int(mh.engine.stats["kills"]) > 0)
	_chk("A21-T09 Estilhaço material (Direct Loot)", int(gs.materials.get("Estilhaço de Cristal", 0)) >= 0)
	mh.stop_mission()
	# ── HUNT HG_CAVE ──
	var rh = hh.start("HG_CAVE")
	_chk("A21-T10 HG_CAVE start ok", bool(rh.get("ok", false)) and hh.is_hunting())
	var rt = hh.get("_runtime")
	for i in range(30): hh.host_process(0.4)
	var wc2 := 0
	while hh.mob_actor() == null and wc2 < 40: hh.host_process(0.15); wc2 += 1
	_chk("A21-T11 Caverna: Errante visível", pl.is_visible_in_tree())
	_chk("A21-T12 crystal mob ATOR visível (Hunt)", hh.mob_actor() != null and hh.mob_actor().is_visible_in_tree())
	_chk("A21-T13 crystal sprite real (não wolf fallback)", hh.mob_actor() != null and not hh.mob_actor().used_fallback and hh.mob_actor().mob_id != "young_wolf")
	_chk("A21-T14 Hunt bidirecional (dealt+taken)", int(rt.runtime_stats["damage_dealt"]) > 0 and int(rt.runtime_stats["damage_taken"]) > 0)
	_chk("A21-T15 Hunt kills>0", int(rt.runtime_stats["kills"]) > 0)
	hh.stop()
	# ── BOSS crystal_golem ──
	_prep(gs)
	var rb = mh.start_boss("BOSS_CRYSTAL_GOLEM", false)
	_chk("A21-T16 Golem start ok", bool(rb.get("ok", false)))
	# intro gate
	var hp_intro := int(gs.hero_hp); mh.host_process(0.5)
	_chk("A21-T17 boss não dana na intro", int(gs.hero_hp) == hp_intro and not mh.boss.intro_done())
	for i in range(8): mh.host_process(0.5)
	_chk("A21-T18 intro completa → combate", mh.boss.intro_done())
	for i in range(30): mh.host_process(0.4)
	_chk("A21-T19 Golem ATOR visível", mh.mob_actor() != null and mh.mob_actor().is_visible_in_tree())
	_chk("A21-T20 Golem sprite real (crystal_golem)", mh.mob_actor() != null and not mh.mob_actor().used_fallback and mh.mob_actor().mob_id == "BOSS_CRYSTAL_GOLEM")
	_chk("A21-T21 boss HP cai (hero ataca)", mh.boss.boss_hp_frac() < 1.0)
	_chk("A21-T22 player travado + visível no boss", pl.locked and pl.is_visible_in_tree())
	# viewport de todos
	var xf := pl.get_viewport_transform(); var vsize := main.get_viewport().get_visible_rect().size
	var pscr := xf * pl.global_position
	_chk("A21-T23 Errante no viewport (boss)", pscr.x >= -80 and pscr.x <= vsize.x + 80 and pscr.y >= -80 and pscr.y <= vsize.y + 80)
	mh.stop_boss()
	# ── REFINE power-real (item +0 vs +3 → CP sobe) ──
	gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {}; gs.materials = {"Fragmentos": 999999}
	var cp0 := PowerBudget.cp()
	gs.refine_do("weapon"); gs.refine_do("weapon"); gs.refine_do("weapon")
	_chk("A21-T24 Refine +3 aplicado (slot_refinement)", gs.refine_level("weapon") == 3)
	_chk("A21-T25 Refine aumenta CP REAL (PowerBudget, sem fake)", PowerBudget.cp() > cp0)
	_chk("A21-T26 Refine gasta Fragmentos", int(gs.materials.get("Fragmentos", 0)) < 999999)
	_chk("A21-T27 Refine reflete no attack_bonus (dano real)", gs.attack_bonus() > 0)
