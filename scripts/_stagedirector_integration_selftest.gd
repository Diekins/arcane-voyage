extends SceneTree
## Self-test FATIA A2 — INTEGRAÇÃO REAL: StageDirector contra o adapter REAL do Main.gd. Prova: resolução de
## região (stagedirector_region_id), o FILTRO DE CANDIDATO via autoplay_acquire_nearest (boss FORA de mira na
## fase normal; boss ALVO na fase 10), e a persistência (stagedirector_persist → GameState). Save snapshot/
## restore. Rodar:
##   godot --headless --path godot -s res://scripts/_stagedirector_integration_selftest.gd

class StubMob extends Node2D:
	var alive := true
	var mob_id := "young_wolf"
	var mob_name := "Stub"
	var deaths := 0
	func is_alive() -> bool: return alive

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1

func _initialize() -> void:
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()
	var gs = root.get_node_or_null("GameState")
	var region_before: String = gs.current_region_id if gs != null else "starter_village"

	# Main sandbox
	var main = load("res://scripts/Main.gd").new()
	main.set("_title_open", false)
	main.set("_inv_open", false); main.set("_shop_open", false)
	main.set("_stash_open", false); main.set("_mastery_open", false)
	main.set("_dialog", null)
	main.set("_macro_current_region", "")

	var p := Node2D.new(); p.set_script(load("res://scripts/PlayerController.gd"))
	p.position = Vector2(500, 500); root.add_child(p)
	main.set("_player", p)

	# região = plains (direto no autoload, SEM save)
	if gs != null: gs.current_region_id = "plains"
	_chk("adapter region_id = plains", main.call("stagedirector_region_id") == "plains")

	# StageDirector real, host = Main
	var sd = load("res://scripts/StageDirector.gd").new()
	sd.name = "StageDirector"; main.add_child(sd)
	sd.setup(main)
	main.set("_stagedirector", sd)
	_chk("StageDirector iniciou em fase normal (RUNNING)", sd.get_state() == sd.St.RUNNING)

	# mobs: 1 young_wolf perto + 1 boss stub (Lobo Alfa) mais perto ainda
	var wolf := StubMob.new(); wolf.mob_id = "young_wolf"; wolf.position = Vector2(560, 500)
	root.add_child(wolf)
	var boss := StubMob.new(); boss.mob_id = "boss"; boss.mob_name = "Lobo Alfa"; boss.position = Vector2(520, 500)
	root.add_child(boss)
	main.set("_mobs", [wolf])
	main.set("_current_boss", boss)
	main.set("_boss_name", "Lobo Alfa")

	# FASE NORMAL: acquire deve pegar o MOB, IGNORANDO o boss (mesmo estando mais perto) — filtro do StageDirector
	main.call("autoplay_release")
	var acq1: bool = main.call("autoplay_acquire_nearest")
	var t1 = main.get("_auto_target")
	_chk("fase normal: acquire pega o MOB, ignora o boss (mais perto)", acq1 and t1 == wolf)

	# FASE BOSS (10): força a fase; agora o candidato válido é o BOSS
	sd.stage = 10
	sd.call("_enter_stage", false)
	_chk("forçou fase 1-10 (BOSS_STAGE)", sd.stage_label() == "1-10" and sd.get_state() == sd.St.BOSS_STAGE)
	main.call("autoplay_release")
	var acq2: bool = main.call("autoplay_acquire_nearest")
	var t2 = main.get("_auto_target")
	_chk("fase boss: acquire pega o BOSS", acq2 and t2 == boss)

	# candidate_ok direto pelo adapter do Main
	_chk("_stage_candidate_ok(mob,false) na fase boss = false", main.call("_stage_candidate_ok", "young_wolf", false) == false)
	_chk("_stage_candidate_ok(boss,true) na fase boss = true", main.call("_stage_candidate_ok", "lobo alfa", true) == true)

	# PERSISTÊNCIA: persist → GameState recebe os campos
	main.call("stagedirector_persist", 2, 3, 4, 25)
	var persist_ok: bool = gs != null and gs.stage_chapter == 2 and gs.stage_index == 3 and gs.stage_kills == 4 and gs.stage_highest_global == 25
	_chk("stagedirector_persist grava em GameState", persist_ok)

	# REVIVE-T06 (A1.5): auto-revive NÃO mexe na fase/progresso do StageDirector. Coloca a SD numa fase/
	# contagem conhecida, força o herói abatido, pede o revive via adapter, e confere que a SD não mudou.
	sd.stage = 6; sd.stage_kills = 12; sd.call("_enter_stage", false)
	var stage_before: String = sd.stage_label()
	var kills_before: int = sd.stage_kills
	if gs != null: gs.hero_hp = 0   # abatido
	main.call("autoplay_request_revive")
	var revived: bool = gs != null and not gs.is_hero_defeated()
	var sd_intact: bool = sd.stage_label() == stage_before and sd.stage_kills == kills_before
	_chk("REVIVE-T06 auto-revive não altera fase/progresso do StageDirector", revived and sd_intact)

	# limpeza + save-safe (restaura região e o arquivo de save)
	if gs != null:
		gs.current_region_id = region_before
		gs.stage_chapter = 1; gs.stage_index = 1; gs.stage_kills = 0; gs.stage_highest_global = 1
	main.call("autoplay_release")
	sd.free(); main.free()
	for n in [p, wolf, boss]:
		if n.get_parent() != null: n.get_parent().remove_child(n)
		n.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)
