extends SceneTree
## Self-test do 3º piloto WORLD LIFE (vela distante). Gate OFF/ON; hook cria 1 vela; movimento
## DETERMINÍSTICO; vela no HORIZONTE (alto, longe do jogador) mas DENTRO do enquadramento do spawn;
## 0 Area2D/colisão; sumir/reaparecer no ciclo; save intocado.
##   godot --headless --path godot -s res://scripts/_worldlife_sail_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	# 1) GATE
	var main = load("res://scripts/Main.gd").new()
	main.set("_sail_force", false)
	var off_gate: bool = not main._world_life_sail_on()
	main.set("_sail_force", true)
	var on_gate: bool = main._world_life_sail_on()
	print("  gate: off=%s on=%s  %s" % [str(off_gate), str(on_gate), ("OK" if (off_gate and on_gate) else "✗")])
	if not (off_gate and on_gate): ok = false

	# 2) HOOK cria a vela (1 entidade)
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host)
	var size := Vector2(2200, 1300)
	main._build_world_life_sail(size)
	var sail: Node = null
	for c in host.get_children():
		if c is WorldLifeSail:
			sail = c
	var built_ok: bool = sail != null
	var tagged := 0
	if sail != null:
		for s in sail.get_children():
			if s is CanvasItem and s.has_meta("av_worldlife"): tagged += 1
	print("  hook do Main: vela criada=%s entidades-marcadas=%d (esp 1)  %s" % [str(sail != null), tagged, ("OK" if (built_ok and tagged == 1) else "✗")])
	if not (built_ok and tagged == 1): ok = false

	if sail != null:
		# 3) ZERO Area2D / colisão
		var bad := _count_physics(sail)
		print("  sem Area2D/colisão/interação: nós físicos=%d  %s" % [bad, ("OK" if bad == 0 else "✗")])
		if bad != 0: ok = false

		# 4) DETERMINISMO: cruza O→L (bordas off-screen), no horizonte (alto), puro, presente/ausente no ciclo
		var a0: Vector2 = sail.anchor_at(0.0)
		var a1: Vector2 = sail.anchor_at(1.0)
		var west_off: bool = a0.x < 0.0
		var east_off: bool = a1.x > 2200.0
		var high: bool = sail.horizon_y() < 650.0 * 0.65   # bem acima do nível do Errante (y~650)
		var pure: bool = sail.anchor_at(0.4).is_equal_approx(sail.anchor_at(0.4)) and sail.progress_at(30.0) == sail.progress_at(30.0)
		var present_mid: bool = sail.is_present_at(40.0)      # phase 40 < CROSS 150 → presente
		var absent_gap: bool = not sail.is_present_at(220.0)  # phase 220 ∈ [150,300) → ausente (mar vazio)
		var det_ok: bool = west_off and east_off and high and pure and present_mid and absent_gap
		print("  determinístico: oeste=%s leste=%s horizonte-alto=%s puro=%s presente@40s=%s ausente@220s=%s  %s" % [str(west_off), str(east_off), str(high), str(pure), str(present_mid), str(absent_gap), ("OK" if det_ok else "✗")])
		if not det_ok: ok = false

		# 5) WITNESS: do spawn da Costa (300,650), a vela passa DENTRO do enquadramento (1280×720 → ±640/±360)
		var spawn := Vector2(300, 650)
		var seen := false
		for k in range(0, 101):
			var ap: Vector2 = sail.anchor_at(float(k) / 100.0)
			if absf(ap.x - spawn.x) < 640.0 and absf(ap.y - spawn.y) < 360.0:
				seen = true
				break
		print("  WITNESS: vela passa no enquadramento do spawn  %s" % ("OK" if seen else "✗"))
		if not seen: ok = false

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)

func _count_physics(node: Node) -> int:
	var n := 0
	if node is Area2D or node is CollisionObject2D or node is CollisionShape2D or node is PhysicsBody2D:
		n += 1
	for c in node.get_children():
		n += _count_physics(c)
	return n
