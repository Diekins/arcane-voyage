extends SceneTree
## Self-test do P2-G (piloto "O Aquietar"). Main DESTACADO + snapshot/restore do user://save. Verifica: flag OFF =
## zero vida ambiente (jogo idêntico); flag ON = vida ambiente criada; recessão por permanência (não-exempt esmaece,
## fio-da-saída exempt NÃO esmaece). NÃO toca recompensa/save. Rodar:
##   godot --headless --path godot -s res://scripts/_p2g_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()

	# --- GATE: OFF por padrão; ON com override de teste ---
	main.set("_quiet_force", false)
	var off_gate: bool = not main._quieting_on()
	main.set("_quiet_force", true)
	var on_gate: bool = main._quieting_on()
	print("  gate: off=%s on=%s  %s" % [str(off_gate), str(on_gate), ("OK" if (off_gate and on_gate) else "✗")])
	if not (off_gate and on_gate): ok = false

	# --- OFF integração: _build_swamp NÃO cria vida ambiente (jogo idêntico) ---
	main.set("_quiet_force", false)
	var h_off := Node2D.new(); root.add_child(h_off)
	_prep(main, h_off)
	main._build_swamp(main._region_world_size("swamp"))
	var off_n := _count_quiet(h_off)
	print("  OFF: _build_swamp vida-ambiente=%d (esperado 0)  %s" % [off_n, ("OK" if off_n == 0 else "✗")])
	if off_n != 0: ok = false
	h_off.queue_free()

	# --- ON integração: _build_swamp cria vida ambiente ---
	main.set("_quiet_force", true)
	var h_on := Node2D.new(); root.add_child(h_on)
	_prep(main, h_on)
	main._build_swamp(main._region_world_size("swamp"))
	var on_n := _count_quiet(h_on)
	print("  ON: _build_swamp vida-ambiente=%d (esperado >0)  %s" % [on_n, ("OK" if on_n > 0 else "✗")])
	if on_n <= 0: ok = false

	# --- nós registrados: há exempt (fio da saída) e não-exempt ---
	var nodes: Array = main.get("_quiet_nodes")
	var n_exempt := 0; var n_recede := 0
	for q in nodes:
		if bool(q["exempt"]): n_exempt += 1
		else: n_recede += 1
	print("  registrados: recuáveis=%d exempt(fio-saída)=%d  %s" % [n_recede, n_exempt, ("OK" if (n_recede > 0 and n_exempt > 0) else "✗")])
	if not (n_recede > 0 and n_exempt > 0): ok = false

	# --- RECESSÃO: permanência longa esmaece os recuáveis; o exempt fica ---
	var sample_recede = null
	var sample_exempt = null
	for q in nodes:
		if bool(q["exempt"]) and sample_exempt == null: sample_exempt = q["node"]
		if not bool(q["exempt"]) and sample_recede == null: sample_recede = q["node"]
	var a_rec_before: float = sample_recede.modulate.a
	var a_exe_before: float = sample_exempt.modulate.a
	for i in range(14):
		main._quiet_tick(2.0)   # acumula permanência muito além dos onsets/span
	var a_rec_after: float = sample_recede.modulate.a
	var a_exe_after: float = sample_exempt.modulate.a
	print("  recessão: recuável %.2f→%.2f | exempt %.2f→%.2f" % [a_rec_before, a_rec_after, a_exe_before, a_exe_after])
	if not (a_rec_after < 0.2): ok = false; print("    ✗ recuável não esmaeceu")
	if not (a_exe_after > 0.85): ok = false; print("    ✗ fio-da-saída (exempt) esmaeceu indevidamente")
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

func _count_quiet(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c.has_meta("av_quiet"): n += 1
	return n
