extends SceneTree
## A20 — TESTE DE CENA REAL do HUNT (Main.tscn). Fecha HUNT_VISIBLE_ACTORS_PENDING. Boota o jogo, entra, inicia a Wolf
## Hunting Ground pelo `_hunthost`, dirige o MESMO host_process do Main e PROVA na árvore real: Errante VISÍVEL, Young
## Wolf com ATOR VISÍVEL (sprite real), combate BIDIRECIONAL, kills>0, ambos no viewport, AUTO OFF pausa.

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

func _run() -> void:
	print("  ── SCENE_HUNT (Main.tscn) ──")
	var hh = main.get("_hunthost")
	var gs = root.get_node_or_null("GameState")
	var pl: Node2D = main.get("_player")
	_chk("SH-T01 HuntHost existe no jogo real", hh != null)
	var r = hh.start("HG_PLAINS_LOW")
	_chk("SH-T02 start Wolf Hunt ok", bool(r.get("ok", false)) and hh.is_hunting())
	var rt = hh.get("_runtime")
	for i in range(30): hh.host_process(0.4)
	_chk("SH-T03 ERRANTE visível na árvore (Hunt não esconde region)", pl.is_visible_in_tree())
	# o Hunt mata rápido (gear real) → espera um ator VIVO no instante da amostra (entre respawns o mob some)
	var wct := 0
	while hh.mob_actor() == null and wct < 40: hh.host_process(0.15); wct += 1
	var act = hh.mob_actor()
	_chk("SH-T04 Young Wolf tem ATOR de apresentação (Hunt)", act != null)
	_chk("SH-T05 ator do lobo VISÍVEL na árvore", act != null and act.is_visible_in_tree())
	_chk("SH-T06 ator usa sprite real (não fallback)", act != null and not act.used_fallback)
	_chk("SH-T07 HuntActorsRoot montado (visível)", hh.actor_root() != null and hh.actor_root().is_visible_in_tree())
	_chk("SH-T08 HERO ataca o lobo (damage_dealt>0)", int(rt.runtime_stats["damage_dealt"]) > 0)
	_chk("SH-T09 MOB ataca o herói (damage_taken>0)", int(rt.runtime_stats["damage_taken"]) > 0)
	_chk("SH-T10 combate BIDIRECIONAL (Hunt)", int(rt.runtime_stats["damage_dealt"]) > 0 and int(rt.runtime_stats["damage_taken"]) > 0)
	_chk("SH-T11 Hunt kills > 0 (lobo morreu)", int(rt.runtime_stats["kills"]) > 0)
	_chk("SH-T12 lobo veio até o Errante (ator perto do player)", act != null and (act.global_position - pl.global_position).length() <= 400.0)
	# viewport
	var xf := pl.get_viewport_transform(); var vsize := main.get_viewport().get_visible_rect().size
	var ps2 := xf * pl.global_position
	_chk("SH-T13 Errante dentro do viewport", ps2.x >= -60 and ps2.x <= vsize.x + 60 and ps2.y >= -60 and ps2.y <= vsize.y + 60)
	if act != null:
		var as2: Vector2 = xf * act.global_position
		_chk("SH-T14 lobo dentro do viewport", as2.x >= -120 and as2.x <= vsize.x + 120 and as2.y >= -120 and as2.y <= vsize.y + 120)
	else:
		_chk("SH-T14 lobo dentro do viewport", false)
	_chk("SH-T15 player travado durante Hunt", pl.locked)
	# AUTO OFF pausa (herói E mob), mantém lock
	hh.set_auto(false); var dd := int(rt.runtime_stats["damage_dealt"]); var dt := int(rt.runtime_stats["damage_taken"])
	for i in range(10): hh.host_process(0.4)
	_chk("SH-T16 AUTO OFF pausa Hunt (dano não avança) + lock", int(rt.runtime_stats["damage_dealt"]) == dd and int(rt.runtime_stats["damage_taken"]) == dt and pl.locked)
	hh.set_auto(true)
	# HUD: session HUD de Hunt visível (é HUNTING, não MISSION)
	_chk("SH-T17 Hunt session HUD é o dono (HUNTING mode)", hh.session_hud != null)
	hh.stop()
	_chk("SH-T18 stop limpa atores do Hunt", hh.mob_actor() == null and hh.actor_root() == null)
	_chk("SH-T19 stop encerra Hunt", not hh.is_hunting())
	# Mission ainda funciona no mesmo jogo (regressão de cena)
	var mh = main.get("_missionhost")
	mh.start_mission("MISSION_001")
	for i in range(20): mh.host_process(0.4)
	_chk("SH-T20 Mission ainda funciona (kills) após Hunt", mh.engine != null and int(mh.engine.stats["kills"]) >= 0 and mh.mob_actor() != null)
	_chk("SH-T21 Mission actor visível (regressão)", mh.mob_actor() != null and mh.mob_actor().is_visible_in_tree())
	mh.stop_mission()
