extends SceneTree
## Self-test do piloto DESERT CITY ATMO ("Cidade do Deserto como lugar vivo" — praça do portão). Main DESTACADO +
## snapshot/restore do user://save. Verifica: GATE off/on; OFF = zero presença (cidade idêntica); ON = presença criada;
## presença ancorada na praça do PORTÃO (sul, y>=800). NÃO toca recompensa/save. Rodar:
##   godot --headless --path godot -s res://scripts/_desertcity_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()

	# GATE
	main.set("_desertcity_force", false)
	var off_gate: bool = not main._desert_city_atmo_on()
	main.set("_desertcity_force", true)
	var on_gate: bool = main._desert_city_atmo_on()
	print("  gate: off=%s on=%s  %s" % [str(off_gate), str(on_gate), ("OK" if (off_gate and on_gate) else "✗")])
	if not (off_gate and on_gate): ok = false

	# OFF: _build_desert_city_atmo NÃO é chamado (cidade idêntica) — provamos pelo gate falso + nenhuma criação
	main.set("_desertcity_force", false)
	var h_off := Node2D.new(); root.add_child(h_off)
	_prep(main, h_off)
	if main._desert_city_atmo_on():
		main._build_desert_city_atmo()
	var off_n := _count(h_off)
	print("  OFF: presença=%d (esperado 0)  %s" % [off_n, ("OK" if off_n == 0 else "✗")])
	if off_n != 0: ok = false
	h_off.queue_free()

	# ON: _build_desert_city_atmo cria presença
	main.set("_desertcity_force", true)
	var h_on := Node2D.new(); root.add_child(h_on)
	_prep(main, h_on)
	main._build_desert_city_atmo()
	var on_n := _count(h_on)
	print("  ON: presença=%d (esperado >0)  %s" % [on_n, ("OK" if on_n > 0 else "✗")])
	if on_n <= 0: ok = false

	# ANCORAGEM: a presença mora na praça do PORTÃO (sul, y>=800)
	var south := 0
	for c in h_on.get_children():
		if c is CanvasItem and c.has_meta("av_desertcity"):
			if c.position.y >= 800.0:
				south += 1
	print("  ancorado na praça sul (y>=800): %d elementos  %s" % [south, ("OK" if south >= 10 else "✗")])
	if south < 10: ok = false

	# ANONIMATO: nenhum elemento do piloto é Area2D/CollisionObject (nada que dispare ou colida com o jogador)
	var bad := 0
	for c in h_on.get_children():
		if c.has_meta("av_desertcity") and (c is Area2D or c is CollisionObject2D):
			bad += 1
	print("  anonimato (0 Area2D/colisão): %d violações  %s" % [bad, ("OK" if bad == 0 else "✗")])
	if bad != 0: ok = false
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
		if c.has_meta("av_desertcity"): n += 1
	return n
