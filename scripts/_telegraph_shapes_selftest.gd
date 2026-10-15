extends SceneTree
## Self-test TELEGRAPH_SHAPES_PASS_01 — a LINGUAGEM dos telegraphs. Prova que as 3 FORMAS produzem 3 ZONAS de acerto
## DIFERENTES (logo, 3 reações diferentes) e que a "line" AVANÇA (investida). Constrói um Mob.gd destacado, trava a
## mira (_aim_dir) e chama _player_in_shape() com o alvo em posições-chave. Save-safe (não toca GameState). Rodar:
##   godot --headless --path godot -s res://scripts/_telegraph_shapes_selftest.gd

func _mk_mob() -> Node2D:
	var m := Node2D.new()
	m.set_script(load("res://scripts/Mob.gd"))
	m.set("mob_id", "shape_test")
	m.position = Vector2.ZERO
	root.add_child(m)   # dispara _ready (cria _anim/_tele/_body)
	return m

func _hit(m: Node2D, player: Node2D, ppos: Vector2) -> bool:
	player.position = ppos
	m.set("_player", player)
	return m.call("_player_in_shape")

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var player := Node2D.new()
	player.set_script(load("res://scripts/PlayerController.gd"))
	root.add_child(player)

	var m := _mk_mob()
	m.set("_aim_dir", Vector2(0, 1))   # mira travada p/ BAIXO em todos os casos
	# _player_in_shape lê o BEAT ATUAL (_cur_*), setado no _begin_windup; aqui setamos direto (BOSS_IDENTITY refactor).

	# ───── ① FAIXA / LINE — "saia da trajetória" ─────
	m.set("_cur_shape", "line"); m.set("_cur_reach", 200.0); m.set("_cur_half", 36.0)
	var line_onaxis := _hit(m, player, Vector2(0, 120))     # na trajetória → ACERTA
	var line_offaxis := not _hit(m, player, Vector2(80, 120)) # 80px de lado (>36) → ERRA (saiu da trajetória)
	var line_ok: bool = line_onaxis and line_offaxis
	print("  ① LINE: na-trajetória acerta=%s / passo-lateral erra=%s  %s" % [str(line_onaxis), str(line_offaxis), ("OK" if line_ok else "✗")])
	if not line_ok: ok = false

	# ───── ② LEQUE / CONE — "não fique na frente" ─────
	m.set("_cur_shape", "cone"); m.set("_cur_reach", 200.0); m.set("_cur_cone", 80.0)
	var cone_front := _hit(m, player, Vector2(0, 120))       # na frente, dentro do ângulo → ACERTA
	var cone_side := not _hit(m, player, Vector2(120, 0))    # 90° de lado → ERRA (gire pro lado)
	var cone_far := not _hit(m, player, Vector2(0, 260))     # na frente mas além do alcance → ERRA
	var cone_ok: bool = cone_front and cone_side and cone_far
	print("  ② CONE: frente acerta=%s / lado erra=%s / longe-demais erra=%s  %s" % [str(cone_front), str(cone_side), str(cone_far), ("OK" if cone_ok else "✗")])
	if not cone_ok: ok = false

	# ───── ③ ANEL / CIRCLE — "afaste-se" (legado) ─────
	m.set("_cur_shape", "circle"); m.set("attack_range", 90.0)   # hit = dist ≤ 90*1.2 = 108
	var circ_near := _hit(m, player, Vector2(0, 80))         # dentro do raio → ACERTA
	var circ_far := not _hit(m, player, Vector2(0, 150))     # fora do raio → ERRA (afaste-se)
	var circ_ok: bool = circ_near and circ_far
	print("  ③ CIRCLE: perto acerta=%s / longe erra=%s  %s" % [str(circ_near), str(circ_far), ("OK" if circ_ok else "✗")])
	if not circ_ok: ok = false

	# ───── ★ CROSS-CHECK: a MESMA posição exige reações DIFERENTES ─────
	# (60,40): dentro do anel (dist 72 ≤ 108) MAS fora da faixa (60px de lado > 36). Logo: o ANEL acerta e a FAIXA
	# erra no mesmo ponto → as formas NÃO são intercambiáveis (o jogador precisa LER a forma, não só a distância).
	m.set("_cur_shape", "circle"); m.set("attack_range", 90.0)
	var cross_circle := _hit(m, player, Vector2(60, 40))
	m.set("_cur_shape", "line"); m.set("_cur_reach", 200.0); m.set("_cur_half", 36.0)
	var cross_line := _hit(m, player, Vector2(60, 40))
	var cross_ok: bool = cross_circle and not cross_line
	print("  ★ CROSS (60,40): anel ACERTA=%s e faixa ERRA=%s → reações distintas  %s" % [str(cross_circle), str(cross_line), ("OK" if cross_ok else "✗")])
	if not cross_ok: ok = false

	# ───── ④ INVESTIDA: a "line" AVANÇA na direção travada ao disparar ─────
	var lm := _mk_mob()
	lm.set("_cur_shape", "line"); lm.set("_cur_reach", 200.0); lm.set("_cur_half", 36.0)
	lm.set("_aim_dir", Vector2(0, 1)); lm.set("attack_range", 90.0)
	lm.set("alive", true); lm.set("combat_enabled", true)
	lm.set("_player", player); player.position = Vector2(0, 120)   # alvo na trajetória
	var y0: float = lm.position.y
	lm.call("_on_tele_fired")
	var lunging: bool = lm.get("_lunging")
	for i in range(6):
		lm.call("_process", 0.05)   # ~0.3s cobre lunge_time (0.18)
	var advanced: bool = lm.position.y - y0 > 100.0   # avançou p/ baixo (direção travada)
	var lunge_ok: bool = lunging and advanced
	print("  ④ INVESTIDA: disparou lunge=%s / avançou %.0fpx na mira=%s  %s" % [str(lunging), lm.position.y - y0, str(advanced), ("OK" if lunge_ok else "✗")])
	if not lunge_ok: ok = false

	# limpeza + save-safe
	for n in [m, lm, player]:
		if n.get_parent() != null: n.get_parent().remove_child(n)
		n.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
