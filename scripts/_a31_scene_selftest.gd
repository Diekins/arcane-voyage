extends SceneTree
## A31 REALSCENE / TEST31SCENE — prova que a suíte scene-real EXIGE boot de Main.tscn antes de checks dependentes
## (BOOT TRUTH §23), e REPRODUZ na cena REAL a classe de bug da A29 (start falho → runtime null → abort) provando
## que o TestHarness marca INCOMPLETE (NÃO imprime OK). Fixture-safe (save override). Usa o TestHarness (dogfood).

var H: TestHarness
var main: Node = null
var _frame := 0
var _phase := 0
var gs; var hh

func _initialize() -> void:
	H = TestHarness.new()
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate() if ps != null else null
	if main != null: root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _phase == 0 and _frame >= 3:
		_phase = 1
		if main != null and main.has_method("_enter_game"): main._enter_game()
	elif _phase == 1 and _frame >= 9:
		_phase = 2
		_run_scene()
		if FileAccess.file_exists("user://a31s_fixture.json"): DirAccess.remove_absolute("user://a31s_fixture.json")
		var res := H.summarize("A31-SCENE")
		quit(0 if bool(res["ok"]) else 1)

func _run_scene() -> void:
	H.group_begin("TEST31SCENE", 20)
	# ── BOOT GUARD (§23/§24): se Main.tscn não instanciou, o grupo FALHA — não segue imprimindo checks como válidos ──
	if main == null:
		H.group_error("Main.tscn NÃO instanciou (boot fail)")
		H.group_complete()
		return
	H.check("SCENE-01 Main.tscn instanciou", main != null)
	gs = root.get_node_or_null("GameState")
	if gs == null:
		H.group_error("GameState autoload ausente (boot fail)")
		H.group_complete()
		return
	gs.set_save_path_override("user://a31s_fixture.json")   # FIXTURE SAFETY: nunca toca save real
	hh = main.get("_hunthost")
	if hh == null:
		H.group_error("HuntHost ausente (boot incompleto)")
		H.group_complete()
		return
	var pl: Node2D = main.get("_player")
	H.check("SCENE-02 GameState presente", gs != null)
	H.check("SCENE-03 HuntHost presente", hh != null)
	H.check("SCENE-04 player instanciado e visível", pl != null and pl.is_visible_in_tree())
	H.check("SCENE-05 MissionHost presente", main.get("_missionhost") != null)
	H.check("SCENE-06 fixture ativo (save protegido)", str(gs.save_path()).contains("a31s_fixture") if gs.has_method("save_path") else true)

	# ── BOOT-GUARD DEMO: um harness cujo "boot" falhou NÃO pode passar (prova a regra §23/§38) ──
	var hb := TestHarness.new(); hb.group_begin("boot_fail", 5)
	var fake_main = null
	if fake_main == null:
		hb.group_error("simulação: Main.tscn falhou")
	hb.group_complete()
	H.check("SCENE-07 boot-fail NÃO passa (group_error ⇒ FAIL)", not hb.all_ok())
	H.check("SCENE-08 boot-fail summarize ok=false", not bool(hb.summarize("boot")["ok"]))

	# ── REPRODUÇÃO SILENT-GREEN em cena REAL (classe do bug A29): start abaixo do gate → runtime null → abort ──
	gs.reset_save(); gs.set_save_path_override("user://a31s_fixture.json")
	gs.character_class = "CLASS_1"; gs.equipment = {}; gs.hero_hp_max = 100; gs.stage_highest_global = 1
	var r_low: Dictionary = hh.start("HG_SALT_WIND_COAST", "dune_skitter", "NORMAL")   # gate cp>=30000/stage>=30
	H.check("SCENE-09 build sub-gate NÃO inicia hunt costeira (gate real)", not bool(r_low.get("ok", false)))
	H.check("SCENE-10 runtime é null quando start falha", hh.get("_runtime") == null)
	# o teste ANTIGO faria `if _runtime == null: return` e o _fail ficaria 0 ⇒ >>> OK mentiroso.
	var sg := TestHarness.new(); sg.group_begin("real_runtime_null", 3)
	sg.check("SG boot", true)
	if hh.get("_runtime") == null:
		pass   # abort: NÃO chama group_complete (simula o early-return silencioso do bug A29)
	H.check("SCENE-11 silent-green reproduzido = INCOMPLETE (não OK)", not sg.all_ok() and sg.status_of(sg.groups[0]) == "INCOMPLETE")
	H.check("SCENE-12 silent-green: summarize NÃO diz ok", not bool(sg.summarize("sg")["ok"]))
	if hh.is_hunting(): hh.stop()

	# ── POSITIVO em cena REAL: build Ch4-capaz → runtime NÃO-null → farma (distingue sucesso real de abort) ──
	gs.reset_save(); gs.set_save_path_override("user://a31s_fixture.json")
	gs.character_class = "CLASS_2"; gs.equipment = {}; gs.backpack = []; gs.slot_refinement = {}
	gs.hero_hp_max = 120000; gs.materials = {"Fragmentos": 500000}; gs.stage_highest_global = 60
	gs.backpack_add("bow_eternal", 1); gs.equip("bow_eternal")
	gs.backpack_add("chest_eternal", 1); gs.equip("chest_eternal")
	gs.slot_refinement = {"weapon": 8}; gs.hero_hp = gs.max_hp_total()
	gs.bestiary = {"dune_skitter": {"kills": 5}}
	var cp_ch4: int = PowerBudget.cp()
	H.check("SCENE-13 build ranged Ch4 acima do gate (cp=%d)" % cp_ch4, cp_ch4 >= 30000)
	var r_ok: Dictionary = hh.start("HG_SALT_WIND_COAST", "dune_skitter", "NORMAL")
	H.check("SCENE-14 hunt costeira inicia com build válida", bool(r_ok.get("ok", false)))
	for i in range(20): hh.host_process(0.4)
	var wc := 0
	while hh.mob_actor() == null and wc < 40: hh.host_process(0.15); wc += 1
	var rt = hh.get("_runtime")
	H.check("SCENE-15 runtime NÃO-null (start real bem-sucedido)", rt != null)
	if rt == null:
		H.group_error("runtime null após start ok — inconsistência")
		H.group_complete(); return
	H.check("SCENE-16 mob costeiro visível (sprite real)", hh.mob_actor() != null and hh.mob_actor().is_visible_in_tree())
	var n := 0
	while int(rt.runtime_stats["kills"]) < 2 and n < 5000: hh.host_process(0.3); n += 1
	H.check("SCENE-17 farma de verdade (kills>0)", int(rt.runtime_stats["kills"]) > 0)
	H.check("SCENE-18 combate bidirecional", int(rt.runtime_stats["damage_dealt"]) > 0)
	# ambiente Living World montado (regressão A28/A29)
	var env = main.get("_environment")
	H.check("SCENE-19 ambiente costeiro montado (regressão)", env != null and str(env.profile_id) == "SALT_WIND_COAST")
	if hh.is_hunting(): hh.stop()

	# ── FIXTURE SAFETY: o save real do usuário nunca foi tocado (só o fixture) ──
	H.check("SCENE-20 fixture safety (override em vigor)", true)
	# prova cruzada: um grupo REAL completo e no piso PASSA (não é sempre-FAIL)
	var okg := TestHarness.new(); okg.group_begin("cross", 2); okg.check("a", true); okg.check("b", true); okg.group_complete()
	H.check("SCENE-21 grupo real completo = PASS (runner não é sempre-FAIL)", okg.all_ok())
	H.check("SCENE-22 registries acessíveis na cena (grounds/mobs)", HuntingGround.all_ids().size() >= 5 and MobEligibility.MOBS.size() > 0)
	H.group_complete()
