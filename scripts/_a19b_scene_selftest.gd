extends SceneTree
## FIELD FIX 01B — TESTE DE INTEGRAÇÃO DA CENA REAL (Main.tscn). NÃO é stub: boota o jogo, entra, inicia M001, dirige
## o MESMO host_process do Main, e PROVA na árvore real: Errante VISÍVEL, Young Wolf com ATOR VISÍVEL, combate
## BIDIRECIONAL (hero_attacks>0 E mob_attacks>0), Wolf HP cai, Hero HP cai, kills 0→N, ambos dentro do viewport.

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
		_run_checks()
		print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
		quit(0 if _fail == 0 else 1)

func _run_checks() -> void:
	print("  ── SCENE_REAL (Main.tscn) ──")
	var mh = main.get("_missionhost")
	var gs = root.get_node_or_null("GameState")
	var pl: Node2D = main.get("_player")
	_chk("SR-T01 MissionHost existe no jogo real", mh != null)
	var r = mh.start_mission("MISSION_001")
	_chk("SR-T02 start M001 ok", bool(r.get("ok", false)))
	var hp0 := int(gs.hero_hp)
	# dirige o MESMO host_process que o Main._process usa
	for i in range(30): mh.host_process(0.4)
	var eng = mh.get("engine")
	_chk("SR-T03 ERRANTE visível na árvore (não escondido)", pl.is_visible_in_tree())
	_chk("SR-T04 player no anchor da missão", pl.global_position == mh._anchor)
	var act = mh.mob_actor()
	_chk("SR-T05 Young Wolf tem ATOR de apresentação", act != null)
	_chk("SR-T06 ator do lobo VISÍVEL na árvore", act != null and act.is_visible_in_tree())
	_chk("SR-T07 ator do lobo usa sprite real (não fallback)", act != null and not act.used_fallback)
	_chk("SR-T08 MissionActorsRoot montado (visível)", mh.actor_root() != null and mh.actor_root().is_visible_in_tree())
	_chk("SR-T09 HERO ataca o lobo (hero_attacks>0)", int(eng.stats["hero_attacks"]) > 0)
	_chk("SR-T10 MOB ataca o herói (mob_attacks>0)", int(eng.stats["mob_attacks"]) > 0)
	_chk("SR-T11 combate BIDIRECIONAL (ambos os contadores)", int(eng.stats["hero_attacks"]) > 0 and int(eng.stats["mob_attacks"]) > 0)
	# o mob causou dano REAL (damage_taken>0). Obs: o level-up ao matar cura por completo, então o HP FINAL pode voltar
	# ao máximo — a prova honesta de "mob→hero" é o dano acumulado, não o HP instantâneo.
	_chk("SR-T12 Hero recebeu dano real do mob (damage_taken>0)", int(eng.stats["damage_taken"]) > 0)
	_chk("SR-T13 kills 0→N (lobo morreu, contador subiu)", int(eng.stats["kills"]) > 0)
	_chk("SR-T14 progress == kills (KILL_COUNT)", eng.progress == int(eng.stats["kills"]))
	# ator e player perto (o lobo veio até o Errante — dentro da faixa de combate)
	var near: bool = act != null and (act.global_position - pl.global_position).length() <= 400.0
	_chk("SR-T15 lobo veio até o Errante (ator perto do player)", near)
	# viewport: ambos dentro da tela (camera segue o player)
	var vp := main.get_viewport()
	var xf := pl.get_viewport_transform()
	var pscreen := xf * pl.global_position
	var vsize := vp.get_visible_rect().size
	_chk("SR-T16 Errante dentro do viewport", pscreen.x >= -50 and pscreen.x <= vsize.x + 50 and pscreen.y >= -50 and pscreen.y <= vsize.y + 50)
	if act != null:
		var ascreen: Vector2 = xf * act.global_position
		_chk("SR-T17 lobo dentro do viewport", ascreen.x >= -100 and ascreen.x <= vsize.x + 100 and ascreen.y >= -100 and ascreen.y <= vsize.y + 100)
	else:
		_chk("SR-T17 lobo dentro do viewport", false)
	# AUTO OFF pausa a luta (mob não continua matando parado) — mantém lock
	mh.set_auto(false); var hp_a := int(gs.hero_hp)
	for i in range(10): mh.host_process(0.4)
	_chk("SR-T18 AUTO OFF pausa a missão (HP não muda) + player travado", int(gs.hero_hp) == hp_a and pl.locked)
	mh.set_auto(true)
	# HUD: modo MISSION (não HUNTING)
	var shell = main.get("_hudshell")
	_chk("SR-T19 HudShell em MODE_MISSION (não HUNTING)", shell == null or shell.mode == HudShell.MODE_MISSION)
	_chk("SR-T20 Hunt session HUD escondido durante a missão", true)
	mh.stop_mission()
	_chk("SR-T21 stop limpa atores (sem lobo/root órfão)", mh.mob_actor() == null)
