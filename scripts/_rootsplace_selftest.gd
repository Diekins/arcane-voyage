extends SceneTree
## Self-test do piloto ROOTS PLACE ("Coração das Raízes como Lugar"). Main DESTACADO + snapshot/restore do
## user://save. Verifica: flag OFF = zero presença (Coração idêntico); flag ON = presença criada; pico ancorado
## perto do Rastro da Colhedora (base 0.32,0.64). NÃO toca recompensa/save. Rodar:
##   godot --headless --path godot -s res://scripts/_rootsplace_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_sandbox", true)   # sem boss-system no build da região

	# GATE
	main.set("_rootsplace_force", false)
	var off_gate: bool = not main._roots_place_on()
	main.set("_rootsplace_force", true)
	var on_gate: bool = main._roots_place_on()
	print("  gate: off=%s on=%s  %s" % [str(off_gate), str(on_gate), ("OK" if (off_gate and on_gate) else "✗")])
	if not (off_gate and on_gate): ok = false

	# OFF: _build_deep_grove não cria presença (Coração idêntico)
	main.set("_rootsplace_force", false)
	var h_off := Node2D.new(); root.add_child(h_off)
	_prep(main, h_off)
	main._build_deep_grove(main._region_world_size("deep_grove"))
	var off_n := _count(h_off)
	print("  OFF: _build_deep_grove presença=%d (esperado 0)  %s" % [off_n, ("OK" if off_n == 0 else "✗")])
	if off_n != 0: ok = false
	h_off.queue_free()

	# ON: _build_deep_grove cria presença
	main.set("_rootsplace_force", true)
	var h_on := Node2D.new(); root.add_child(h_on)
	_prep(main, h_on)
	var sz: Vector2 = main._region_world_size("deep_grove")
	main._build_deep_grove(sz)
	var on_n := _count(h_on)
	print("  ON: _build_deep_grove presença=%d (esperado >0)  %s" % [on_n, ("OK" if on_n > 0 else "✗")])
	if on_n <= 0: ok = false

	# PICO ancorado: presença perto da base do Rastro da Colhedora (0.32,0.64)
	var base := Vector2(sz.x * 0.32, sz.y * 0.64)
	var near := 0
	for c in h_on.get_children():
		if c is CanvasItem and c.has_meta("av_rootsplace"):
			var cp: Vector2 = c.position
			if cp.distance_to(base) <= 100.0:
				near += 1
	print("  pico perto da Colhedora (<=100px): %d elementos  %s" % [near, ("OK" if near >= 3 else "✗")])
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
		if c.has_meta("av_rootsplace"): n += 1
	return n
