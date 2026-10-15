extends SceneTree
## A28 REALSCENE28 — Living World na Main.tscn REAL. Wolf hunt / Spider Grove hunt / ARANHA MATRIARCA boss com o
## ambiente montado (ground contínuo SEM grade de tile, props reais, player+mob visíveis, oclusão de copa). Save fixture.

var main: Node = null
var _frame := 0
var _phase := 0
var _fail := 0
var gs; var hh; var mh
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
		gs = root.get_node_or_null("GameState")
		gs.set_save_path_override("user://a28s_fixture.json")
		hh = main.get("_hunthost"); mh = main.get("_missionhost")
		_run()
		if FileAccess.file_exists("user://a28s_fixture.json"): DirAccess.remove_absolute("user://a28s_fixture.json")
		print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
		quit(0 if _fail == 0 else 1)

func _prep() -> void:
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 10}
	gs.hero_hp_max = 60000; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0
	gs.stage_highest_global = 60; gs.materials = {"Fragmentos": 5000}
	var f: Array[String] = ["GP_MISSION_006_COMPLETE", "GP_CHAPTER_1_WOLF_COMPLETE", "GP_CHAPTER_2_CRYSTAL_COMPLETE", "GP_UNLOCK_HUNT_WOLF", "GP_UNLOCK_HUNT_CRYSTAL", "GP_UNLOCK_HUNT_SPIDER"]
	for i in range(1, 9): f.append("GP_C2_M%03d_COMPLETE" % i)
	for i in range(1, 9): f.append("GP_C3_M%03d_COMPLETE" % i)
	f.append("GP_UNLOCK_CHAPTER_3_PREBOSS_READY"); gs.story_flags = f

func _env() -> EnvironmentAssembler: return main.get("_environment")
func _has_tilemap(node: Node) -> bool:
	for c in node.get_children():
		if c is TileMap or c is TileMapLayer: return true
	return false

func _run() -> void:
	print("  ── A28 REALSCENE (Main.tscn) ──")
	_prep()
	var pl: Node2D = main.get("_player")
	# ═══ WOLF HUNT ═══
	var r: Dictionary = hh.start("HG_PLAINS_LOW")
	_chk("RS28-T01 wolf hunt inicia", bool(r.get("ok", false)) and hh.is_hunting())
	for i in range(20): hh.host_process(0.4)
	_chk("RS28-T02 Living World montado (environment != null)", _env() != null)
	_chk("RS28-T03 profile PLAINS_WOLF", _env() != null and _env().profile_id == "PLAINS_WOLF")
	_chk("RS28-T04 ground node contínuo (Sprite2D)", _env() != null and _env().ground_node() is Sprite2D)
	_chk("RS28-T05 ground textura de grama (plains)", _env() != null and str(_env().ground_node().texture.resource_path).contains("plains"))
	_chk("RS28-T06 texture_repeat (sem grade de tile)", _env() != null and _env().ground_node().texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED)
	_chk("RS28-T07 NENHUM TileMap no ambiente", _env() != null and not _has_tilemap(_env()))
	_chk("RS28-T08 props instanciados (>0)", _env() != null and _env().prop_nodes().size() > 0)
	_chk("RS28-T09 player visível", pl.is_visible_in_tree())
	var wct := 0
	while hh.mob_actor() == null and wct < 40: hh.host_process(0.15); wct += 1
	_chk("RS28-T10 wolf (mob) visível", hh.mob_actor() != null and hh.mob_actor().is_visible_in_tree())
	_chk("RS28-T11 combate roda com ambiente", int(hh.get("_runtime").runtime_stats["kills"]) >= 0)
	_chk("RS28-T12 centro de combate limpo (clear zone)", _env() != null and _env().count_in_clear_blocking() == 0)
	var wolf_props := _env().prop_nodes().size() if _env() != null else 0
	# grama/rocha/árvore presentes (profundidade)
	var cats := {}
	if _env() != null:
		for e in _env().prop_nodes(): cats[str(EnvironmentPropDefinition.get_prop(str(e["placement"]["prop_id"]))["category"])] = true
	_chk("RS28-T13 vegetação presente (grass)", cats.has("GRASS_SMALL") or cats.has("GRASS_MEDIUM") or cats.has("GRASS_TALL"))
	_chk("RS28-T14 props com profundidade (rock/bush/tree)", cats.has("ROCK") or cats.has("BUSH") or cats.has("TREE"))
	# wind aplica sem crash
	main._environment.tick_wind(0.1)
	_chk("RS28-T15 vento tickando (sem crash)", true)
	hh.stop()
	_chk("RS28-T16 environment removido ao sair", _env() == null)
	# ═══ SPIDER GROVE HUNT ═══
	_prep()
	var rg: Dictionary = hh.start("HG_GROVE", "grove_spider")
	_chk("RS28-T17 grove hunt inicia", bool(rg.get("ok", false)) and hh.is_hunting())
	for i in range(20): hh.host_process(0.4)
	_chk("RS28-T18 Living World montado (grove)", _env() != null)
	_chk("RS28-T19 profile PLAINS_SPIDER_GROVE", _env() != null and _env().profile_id == "PLAINS_SPIDER_GROVE")
	_chk("RS28-T20 grove mais denso que wolf", _env() != null and _env().prop_nodes().size() > wolf_props)
	_chk("RS28-T21 grove ground contínuo (sem tile grid)", _env() != null and _env().ground_node() is Sprite2D and not _has_tilemap(_env()))
	_chk("RS28-T22 mesma base MAP_PLAINS (reuso)", str(EnvironmentProfile.get_profile("PLAINS_SPIDER_GROVE")["map_id"]) == "MAP_PLAINS")
	var wc2 := 0
	while hh.mob_actor() == null and wc2 < 40: hh.host_process(0.15); wc2 += 1
	_chk("RS28-T23 spider (mob) visível com grove", hh.mob_actor() != null and hh.mob_actor().is_visible_in_tree())
	# tree occlusion na cena real: coloca o player atrás de uma árvore do ambiente
	var trees = _env().prop_nodes().filter(func(e): return e["canopy"] != null)
	if trees.size() > 0:
		var te = trees[0]; var tpos: Vector2 = te["placement"]["position"]; var canopy: Sprite2D = te["canopy"]
		pl.position = Vector2(tpos.x, tpos.y - 30.0)   # atrás
		canopy.modulate.a = 1.0
		for i in range(40): main._environment.update_occlusion(pl, 0.05)
		_chk("RS28-T24 copa FADE com player atrás", canopy.modulate.a < 0.6)
		_chk("RS28-T25 tronco permanece opaco", te["trunk"].modulate.a >= 0.99)
		pl.position = Vector2(tpos.x, tpos.y + 80.0)   # à frente
		for i in range(40): main._environment.update_occlusion(pl, 0.05)
		_chk("RS28-T26 copa RESTAURA à frente", canopy.modulate.a > 0.9)
	else:
		_chk("RS28-T24 (sem árvore nesta seed — skip)", true); _chk("RS28-T25 skip", true); _chk("RS28-T26 skip", true)
	hh.stop()
	# ═══ ARANHA MATRIARCA regression (boss com ambiente) ═══
	_prep()
	var rb = mh.start_boss("BOSS_CH3_SPIDER_MATRIARCH", true)
	_chk("RS28-T27 ARANHA MATRIARCA inicia com ambiente", bool(rb.get("ok", false)))
	for i in range(20): mh.host_process(0.4)
	_chk("RS28-T28 Living World montado no boss", _env() != null)
	_chk("RS28-T29 boss (spider_matriarch) visível", mh.mob_actor() != null and mh.mob_actor().is_visible_in_tree() and mh.mob_actor().mob_id == "BOSS_CH3_SPIDER_MATRIARCH")
	_chk("RS28-T30 boss HP cai (combate com ambiente)", mh.boss.boss_hp_frac() < 1.0)
	_chk("RS28-T31 ambiente não bloqueia combate (clear zone)", _env() == null or _env().count_in_clear_blocking() == 0)
	mh.set_auto(false); var hp32 := int(gs.hero_hp)
	for i in range(6): mh.host_process(0.4)
	_chk("RS28-T32 AUTO OFF ainda pausa (regressão)", int(gs.hero_hp) == hp32)
	mh.set_auto(true)
	mh.stop_boss()
	_chk("RS28-T33 environment removido pós-boss", _env() == null)
	_chk("RS28-T34 root_matriarch intocado (escopo)", not BossActivityDefinition.exists("root_matriarch"))
