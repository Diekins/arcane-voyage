extends SceneTree
## Self-test do piloto CAVE MEMORY ("Caverna como Lugar"). Main DESTACADO + snapshot/restore do user://save.
## Verifica: flag OFF = zero presença (Caverna idêntica); flag ON = presença criada; pico ancorado perto da
## Contagem (base 0.30,0.62). NÃO toca recompensa/save. Rodar:
##   godot --headless --path godot -s res://scripts/_cavemem_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_sandbox", true)   # evita instanciar o Golem no _build_cave (sandbox = sem boss)

	# PROMOVIDO 2026-06-08: CAVE_MEMORY_ENABLED virou true (produção ON). O gate/OFF abaixo se adaptam à const:
	# - produção ON  -> _cave_memory_on() é sempre true; valida ON + ancoragem (o OFF=idêntico já cumpriu seu papel pré-embarque).
	# - produção OFF -> comportamento original (OFF=0 idêntico, ON via force).
	var prod_on: bool = bool(main.get("CAVE_MEMORY_ENABLED"))

	# GATE
	main.set("_cavemem_force", false)
	var base_off: bool = not main._cave_memory_on()       # sem force/env: reflete só a const
	main.set("_cavemem_force", true)
	var on_gate: bool = main._cave_memory_on()
	if prod_on:
		print("  gate: produção ON (const=true) — on=%s  %s" % [str(on_gate), ("OK" if on_gate else "✗")])
		if not on_gate: ok = false
	else:
		print("  gate: off=%s on=%s  %s" % [str(base_off), str(on_gate), ("OK" if (base_off and on_gate) else "✗")])
		if not (base_off and on_gate): ok = false

	# OFF (só faz sentido com produção OFF): _build_cave não cria memória (Caverna idêntica)
	if not prod_on:
		main.set("_cavemem_force", false)
		var h_off := Node2D.new(); root.add_child(h_off)
		_prep(main, h_off)
		main._build_cave(main._region_world_size("cave"))
		var off_n := _count(h_off)
		print("  OFF: _build_cave memória=%d (esperado 0)  %s" % [off_n, ("OK" if off_n == 0 else "✗")])
		if off_n != 0: ok = false
		h_off.queue_free()
	else:
		print("  OFF: pulado (produção ON — feature embarcada)")

	# ON: _build_cave cria memória
	main.set("_cavemem_force", true)
	var h_on := Node2D.new(); root.add_child(h_on)
	_prep(main, h_on)
	var sz: Vector2 = main._region_world_size("cave")
	main._build_cave(sz)
	var on_n := _count(h_on)
	print("  ON: _build_cave memória=%d (esperado >0)  %s" % [on_n, ("OK" if on_n > 0 else "✗")])
	if on_n <= 0: ok = false

	# PICO ancorado: existe presença perto da base da Contagem (0.30,0.62) — vigília/cristal-sobre-marcas
	var base := Vector2(sz.x * 0.30, sz.y * 0.62)
	var near := 0
	for c in h_on.get_children():
		if c is CanvasItem and c.has_meta("av_cavemem"):
			var cp: Vector2 = c.position
			if cp.distance_to(base) <= 90.0:
				near += 1
	print("  pico perto da Contagem (<=90px): %d elementos  %s" % [near, ("OK" if near >= 3 else "✗")])
	if near < 3: ok = false
	h_on.queue_free()

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)

func _prep(main, host: Node2D) -> void:
	main.set("_region_node", host)
	main.set("_services", []); main.set("_npcs", []); main.set("_portals", [])
	main.set("_chests", []); main.set("_blockers", [])

func _count(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c.has_meta("av_cavemem"): n += 1
	return n
