extends SceneTree
## Self-test do piloto WORLD LIFE (caravana nos Areais). Verifica: gate OFF/ON; o hook do Main
## cria 3 entidades; movimento DETERMINÍSTICO pelo tempo do mundo; ZERO Area2D/colisão/interação;
## ausência no gap do ciclo (trânsito, não loop); save intocado. NÃO toca recompensa/save.
##   godot --headless --path godot -s res://scripts/_worldlife_caravan_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	# 1) GATE via Main: OFF por padrão; ON via _caravan_force
	var main = load("res://scripts/Main.gd").new()
	main.set("_caravan_force", false)
	var off_gate: bool = not main._world_life_caravan_on()
	main.set("_caravan_force", true)
	var on_gate: bool = main._world_life_caravan_on()
	print("  gate: off=%s on=%s  %s" % [str(off_gate), str(on_gate), ("OK" if (off_gate and on_gate) else "✗")])
	if not (off_gate and on_gate): ok = false

	# 2) HOOK do Main cria a caravana (3 entidades) no nó da região
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host)
	main.set("_player_start", Vector2(280, 650))   # KHET_SPAWN → a caravana ancora a rota neste y
	main._build_world_life_caravan(Vector2(2000, 1300))
	var caravan: Node = null
	for c in host.get_children():
		if c is WorldLifeCaravan:
			caravan = c
	var built_ok: bool = caravan != null and caravan.member_count() == 3
	print("  hook do Main: caravana criada=%s membros=%s (esp 3)  %s" % [str(caravan != null), str(caravan.member_count() if caravan else -1), ("OK" if built_ok else "✗")])
	if not built_ok: ok = false

	if caravan != null:
		# 3) ZERO Area2D / colisão / interação em toda a subárvore
		var bad := _count_physics(caravan)
		print("  sem Area2D/colisão/interação: nós físicos=%d  %s" % [bad, ("OK" if bad == 0 else "✗")])
		if bad != 0: ok = false

		# 3b) as 3 entidades estão marcadas av_worldlife
		var tagged := 0
		for m in caravan.get_children():
			if m is CanvasItem and m.has_meta("av_worldlife"): tagged += 1
		print("  entidades marcadas av_worldlife: %d (esp 3)  %s" % [tagged, ("OK" if tagged == 3 else "✗")])
		if tagged != 3: ok = false

		# 4) DETERMINISMO: rota O→L (bordas off-screen) + pureza + presença/ausência no ciclo
		var p0: float = caravan.progress_at(0.0)
		var a0: Vector2 = caravan.anchor_at(0.0)
		var a1: Vector2 = caravan.anchor_at(1.0)
		var west_off: bool = a0.x < 0.0                      # entra ALÉM da borda oeste
		var east_off: bool = a1.x > 2000.0                   # some ALÉM da borda leste
		# pureza: mesmo tempo → mesma posição (2 chamadas)
		var pure: bool = is_equal_approx(caravan.anchor_at(0.37).x, caravan.anchor_at(0.37).x) and caravan.progress_at(50.0) == caravan.progress_at(50.0)
		# presença: dentro de CROSS_DURATION presente; no gap ausente (trânsito, não loop)
		var present_mid: bool = caravan.is_present_at(40.0)       # phase 40 < 96 → presente
		var absent_gap: bool = not caravan.is_present_at(180.0)   # phase 180 ∈ [96,240) → ausente
		var det_ok: bool = west_off and east_off and pure and present_mid and absent_gap and p0 >= 0.0
		print("  determinístico: oeste=%s leste=%s puro=%s presente@40s=%s ausente@180s=%s  %s" % [str(west_off), str(east_off), str(pure), str(present_mid), str(absent_gap), ("OK" if det_ok else "✗")])
		if not det_ok: ok = false

		# 4b) movimento avança no tempo do mundo (2 tempos distintos → posições distintas e = anchor_at)
		caravan.set("_time_override", 10.0); caravan._apply_for_time(10.0)
		var m0: Vector2 = (caravan.get_child(0) as Node2D).position
		caravan.set("_time_override", 60.0); caravan._apply_for_time(60.0)
		var m1: Vector2 = (caravan.get_child(0) as Node2D).position
		var moved: bool = m1.x > m0.x   # avança p/ leste com o tempo
		print("  movimento avança no tempo: x %.0f→%.0f  %s" % [m0.x, m1.x, ("OK" if moved else "✗")])
		if not moved: ok = false

		# WITNESS: do spawn (280,650), a caravana passa DENTRO do enquadramento (1280×720 → ±640/±360) em algum progresso
		var spawn := Vector2(280, 650)
		var seen := false
		for k in range(0, 101):
			var ap: Vector2 = caravan.anchor_at(float(k) / 100.0)
			if absf(ap.x - spawn.x) < 640.0 and absf(ap.y - spawn.y) < 360.0:
				seen = true
				break
		print("  WITNESS: caravana passa no enquadramento do spawn  %s" % ("OK" if seen else "✗"))
		if not seen: ok = false

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)

## Conta nós de física/interação (devem ser ZERO: a caravana pertence ao mundo, não interage).
func _count_physics(node: Node) -> int:
	var n := 0
	if node is Area2D or node is CollisionObject2D or node is CollisionShape2D or node is PhysicsBody2D:
		n += 1
	for c in node.get_children():
		n += _count_physics(c)
	return n
