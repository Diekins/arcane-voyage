extends SceneTree
## A30 REALSCENE30 — paridade de ladder PROVADA na Main.tscn REAL. Por classe: equipa tier ANTERIOR → inspeciona
## Power (PowerBudget.cp, o mesmo que a UI lê) → equipa tier ALTO → Power SOBE → Refina → Power SOBE. + farm real
## em HG_SALT_WIND_COAST (Ch4) com o tier alto do arquétipo do gap (ranged). Save protegido por fixture.

var main: Node = null
var _frame := 0
var _phase := 0
var _fail := 0
var gs; var mh; var hh

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
		gs.set_save_path_override("user://a30s_fixture.json")
		mh = main.get("_missionhost"); hh = main.get("_hunthost")
		_run()
		if FileAccess.file_exists("user://a30s_fixture.json"): DirAccess.remove_absolute("user://a30s_fixture.json")
		print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
		quit(0 if _fail == 0 else 1)

func _fam_allows(cls: String, weapon: String) -> bool:
	var fams: Array = CharacterClassDefinition.CLASSES.get(cls, {}).get("allowed_weapon_families", [])
	return str(ItemDB.get_item(weapon).get("weapon_kind", "")) in fams

# equipa `id` a partir da mochila (Direct Loot real: add → equip). gs.equip já troca o MESMO slot sozinho.
func _equip(id: String) -> bool:
	gs.backpack_add(id, 1)
	return gs.equip(id)

func _env(): return main.get("_environment")

func _run() -> void:
	print("  ── A30 REALSCENE (Main.tscn) ──")
	var pl: Node2D = main.get("_player")
	_chk("RS30-T00 player na cena", pl != null and pl.is_visible_in_tree())
	# ── por classe: equipa prev → Power → high → Power sobe → Refino → Power sobe ──
	var lad := [
		["CLASS_1", "sword_reinforced", "sword_eternal"],
		["CLASS_2", "bow_reinforced", "bow_eternal"],
		["CLASS_3", "staff_reinforced", "staff_eternal"],
		["CLASS_4", "spear_reinforced", "spear_eternal"],
		["CLASS_5_SUPPORT", "book_reinforced", "book_eternal"],
	]
	for row in lad:
		var cls: String = row[0]; var prev: String = row[1]; var high: String = row[2]
		gs.reset_save(); gs.set_save_path_override("user://a30s_fixture.json")
		gs.character_class = cls; gs.equipment = {}; gs.backpack = []
		gs.slot_refinement = {}; gs.materials = {"Fragmentos": 500000}
		gs.hero_hp_max = 8000; gs.hero_hp = gs.max_hp_total()
		# equipa tier ANTERIOR (real, da mochila)
		var okp := _equip(prev)
		var cp_prev: int = PowerBudget.cp()
		_chk("RS30 %s equipa tier anterior (%s)" % [cls, prev], okp and str(gs.equipment.get("weapon")) == prev)
		_chk("RS30 %s Power anterior > 0 (%d)" % [cls, cp_prev], cp_prev > 0)
		# equipa tier ALTO → Power sobe
		var okh := _equip(high)
		var cp_high: int = PowerBudget.cp()
		_chk("RS30 %s equipa tier alto (%s), Power SOBE (%d>%d)" % [cls, high, cp_high, cp_prev], okh and str(gs.equipment.get("weapon")) == high and cp_high > cp_prev)
		# arquétipo correto no tier alto
		_chk("RS30 %s arquétipo correto no tier alto" % cls, gs.current_combat_archetype() == CharacterClassDefinition.archetype_of(cls))
		# Refina +5 (refine_do real, grava no fixture) → Power sobe
		for i in range(5): gs.refine_do("weapon")
		var cp_ref: int = PowerBudget.cp()
		_chk("RS30 %s Refino +5 → Power SOBE (%d>%d)" % [cls, cp_ref, cp_high], int(gs.slot_refinement.get("weapon", 0)) == 5 and cp_ref > cp_high)
	# ── farm REAL Ch4 com o tier alto do arquétipo do gap (ranged/CLASS_2) ──
	gs.reset_save(); gs.set_save_path_override("user://a30s_fixture.json")
	gs.character_class = "CLASS_2"; gs.equipment = {}; gs.backpack = []; gs.slot_refinement = {}
	# build Ch4-capaz (arma tier5 + peito eternal + hp) p/ cruzar o gate cp>=30000 do HG costeiro
	gs.hero_hp_max = 120000; gs.materials = {"Fragmentos": 500000}; gs.stage_highest_global = 60
	_equip("bow_eternal"); _equip("chest_eternal")
	gs.slot_refinement = {"weapon": 8}
	gs.hero_hp = gs.max_hp_total()
	var f: Array[String] = ["GP_MISSION_006_COMPLETE", "GP_CHAPTER_1_WOLF_COMPLETE", "GP_CHAPTER_2_CRYSTAL_COMPLETE", "GP_CHAPTER_3_SPIDER_COMPLETE", "GP_UNLOCK_HUNT_SALTWIND"]
	gs.story_flags = f
	var cp_ch4: int = PowerBudget.cp()
	_chk("RS30-T26 build ranged Ch4 acima do gate (cp=%d>=30000)" % cp_ch4, cp_ch4 >= 30000)
	gs.bestiary = {"dune_skitter": {"kills": 5}}
	var rh: Dictionary = hh.start("HG_SALT_WIND_COAST", "dune_skitter", "NORMAL")
	_chk("RS30-T27 hunt costeiro inicia com tier alto", bool(rh.get("ok", false)))
	for i in range(20): hh.host_process(0.4)
	var wc := 0
	while hh.mob_actor() == null and wc < 40: hh.host_process(0.15); wc += 1
	_chk("RS30-T28 mob costeiro visível (sprite real)", hh.mob_actor() != null and hh.mob_actor().is_visible_in_tree())
	_chk("RS30-T29 ambiente costeiro montado (SALT_WIND_COAST)", _env() != null and _env().profile_id == "SALT_WIND_COAST")
	var rt = hh.get("_runtime")
	var n := 0
	while int(rt.runtime_stats["kills"]) < 3 and n < 6000: hh.host_process(0.3); n += 1
	_chk("RS30-T30 tier alto FARMA de verdade (kills>0 no Ch4)", int(rt.runtime_stats["kills"]) > 0)
	_chk("RS30-T31 combate bidirecional (dano dado)", int(rt.runtime_stats["damage_dealt"]) > 0)
	# eficiência: bow_eternal refinado tem Power acima do bow_reinforced na MESMA base (progressão sentida)
	var cp_high_ranged: int = PowerBudget.cp()
	_equip("bow_reinforced"); gs.slot_refinement = {"weapon": 0}
	var cp_prev_ranged: int = PowerBudget.cp()
	_chk("RS30-T32 eficiência Ch4: bow_eternal+8 >> bow_reinforced (%d>%d)" % [cp_high_ranged, cp_prev_ranged], cp_high_ranged > cp_prev_ranged)
	hh.stop()
	# regressão: ARANHA MATRIARCA reward intacto (sword_reinforced), Ch3 não regride
	_chk("RS30-T33 ARANHA MATRIARCA reward intacto (sword→sword_reinforced)", BossActivityDefinition.guaranteed_gear_for_weapon("sword") == "sword_reinforced")
	_chk("RS30-T34 boss book agora dá gear equipável por support", _fam_allows("CLASS_5_SUPPORT", BossActivityDefinition.guaranteed_gear_for_weapon("book")))
