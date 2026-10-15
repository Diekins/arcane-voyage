extends SceneTree
## Self-test THE_STONE_BUILD_01 — a CHEGADA À PEDRA. Main DESTACADO + snapshot/restore do user://save.
## Verifica: a Pedra é materializada (elementos av_stone > 0); HÁ SINAIS DE VIDA NO ALTO (janelas acesas com y bem
## acima do pé = "olhar pra cima"); a SUBIDA não existe (blocker longo no pé); o ECO é fiado SEM erro (dormente sem
## asset). NÃO toca recompensa/save/combate. Rodar:
##   godot --headless --path godot -s res://scripts/_stone_arrival_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_sandbox", true)

	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host)
	main.set("_services", []); main.set("_npcs", []); main.set("_portals", [])
	main.set("_chests", []); main.set("_blockers", [])

	var size: Vector2 = main._region_world_size("deep_dunes")
	print("  região deep_dunes size=%s (esperado x=2400)  %s" % [str(size), ("OK" if size.x == 2400 else "✗")])
	if size.x != 2400: ok = false

	main._build_stone_arrival(size)

	# (1) A PEDRA EXISTE
	var stone := 0
	var windows := 0
	var high_life := 0   # sinais de vida bem acima do pé (foot_y=360) e dentro da faixa visível de baixo
	for c in host.get_children():
		if c is CanvasItem and c.has_meta("av_stone"):
			stone += 1
		if c is CanvasItem and c.has_meta("av_stone_window"):
			windows += 1
			var wy: float = (c as Node2D).position.y
			if wy < 200.0:   # janela MUITO acima do pé → o jogador olha pra CIMA
				high_life += 1
	print("  elementos da Pedra (av_stone): %d (esperado >0)  %s" % [stone, ("OK" if stone > 0 else "✗")])
	if stone <= 0: ok = false
	print("  janelas acesas (sinais de vida): %d (esperado >=3)  %s" % [windows, ("OK" if windows >= 3 else "✗")])
	if windows < 3: ok = false
	print("  WITNESS 'olhar pra cima': %d janelas com y<200 (bem acima do pé 360)  %s" % [high_life, ("OK" if high_life >= 1 else "✗")])
	if high_life < 1: ok = false

	# (2) O PÉ É PAREDE com TRAILHEAD: muros no pé a oeste (x1700) e leste (x2300), e BRECHA aberta (x2050) — a
	# subida começa por um caminho definido (THE_STONE_BUILD_02), não escala-se o paredão em qualquer ponto.
	var blockers: Array = main.get("_blockers")
	var west_wall := _pt_blocked(blockers, Vector2(1700.0, 332.0))
	var east_wall := _pt_blocked(blockers, Vector2(2300.0, 332.0))
	var trailhead := not _pt_blocked(blockers, Vector2(2050.0, 332.0))
	print("  pé murado (oeste=%s leste=%s) + trailhead aberto=%s  %s" % [str(west_wall), str(east_wall), str(trailhead), ("OK" if (west_wall and east_wall and trailhead) else "✗")])
	if not (west_wall and east_wall and trailhead): ok = false

	# (3) O ECO foi fiado SEM erro (dormente sem asset): existe um AudioStreamPlayer2D av_stone_echo no host
	var echo := false
	for c in host.get_children():
		if c.has_meta("av_stone_echo"):
			echo = true
	print("  eco fiado (dormente, sem erro): %s  %s" % [str(echo), ("OK" if echo else "✗")])
	if not echo: ok = false

	host.queue_free()

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)

func _pt_blocked(blockers: Array, p: Vector2) -> bool:
	for b in blockers:
		if (b as Rect2).has_point(p):
			return true
	return false
