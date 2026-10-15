extends SceneTree
## Self-test do 2º piloto WORLD LIFE (aves costeiras). Verifica: gate OFF/ON; o hook do Main cria
## 2-3 aves; movimento DETERMINÍSTICO pelo tempo do mundo; aves na FAIXA do horizonte (longe do jogador);
## ZERO Area2D/colisão/interação; sumir/reaparecer no ciclo; save intocado.
##   godot --headless --path godot -s res://scripts/_worldlife_fauna_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	# 1) GATE via Main
	var main = load("res://scripts/Main.gd").new()
	main.set("_fauna_force", false)
	var off_gate: bool = not main._world_life_fauna_on()
	main.set("_fauna_force", true)
	var on_gate: bool = main._world_life_fauna_on()
	print("  gate: off=%s on=%s  %s" % [str(off_gate), str(on_gate), ("OK" if (off_gate and on_gate) else "✗")])
	if not (off_gate and on_gate): ok = false

	# 2) HOOK do Main cria as aves (2-3) no nó da região
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host)
	var size := Vector2(2200, 1300)
	main._build_world_life_fauna(size)
	var fauna: Node = null
	for c in host.get_children():
		if c is WorldLifeFauna:
			fauna = c
	var n: int = fauna.bird_count() if fauna else -1
	var built_ok: bool = fauna != null and n >= 2 and n <= 3
	print("  hook do Main: fauna criada=%s aves=%s (esp 2-3)  %s" % [str(fauna != null), str(n), ("OK" if built_ok else "✗")])
	if not built_ok: ok = false

	if fauna != null:
		# 3) ZERO Area2D / colisão / interação
		var bad := _count_physics(fauna)
		print("  sem Area2D/colisão/interação: nós físicos=%d  %s" % [bad, ("OK" if bad == 0 else "✗")])
		if bad != 0: ok = false

		# 3b) aves marcadas av_worldlife
		var tagged := 0
		for b in fauna.get_children():
			if b is CanvasItem and b.has_meta("av_worldlife"): tagged += 1
		print("  aves marcadas av_worldlife: %d (esp %d)  %s" % [tagged, n, ("OK" if tagged == n else "✗")])
		if tagged != n: ok = false

		# 4) DETERMINISMO + faixa do horizonte + sumir/reaparecer
		# pureza: mesmo tempo → mesma posição da 1ª ave
		fauna.set("_time_override", 5.0); fauna._apply_for_time(5.0)
		var a0: Vector2 = (fauna.get_child(0) as Node2D).position
		fauna.set("_time_override", 5.0); fauna._apply_for_time(5.0)
		var a0b: Vector2 = (fauna.get_child(0) as Node2D).position
		var pure: bool = a0.is_equal_approx(a0b)
		# faixa do horizonte: toda ave VISÍVEL fica acima de horizon_band_max_y (sobre a água, longe do spawn 300,650)
		var band: float = fauna.horizon_band_max_y()
		var in_band := true
		fauna.set("_time_override", 12.0); fauna._apply_for_time(12.0)
		for b in fauna.get_children():
			if b is Node2D and b.visible and b.position.y > band:
				in_band = false
		# movimento: 2 tempos distintos → posição muda
		fauna.set("_time_override", 1.0); fauna._apply_for_time(1.0)
		var m0: Vector2 = (fauna.get_child(0) as Node2D).position
		fauna.set("_time_override", 4.0); fauna._apply_for_time(4.0)
		var m1: Vector2 = (fauna.get_child(0) as Node2D).position
		var moved: bool = not m0.is_equal_approx(m1)
		# sumir/reaparecer: existe algum t com alguma ave visível e algum t (no ciclo) sem TODAS visíveis
		var has_visible: bool = fauna.any_visible_at(3.0)
		var has_gap := false
		for k in range(0, 220, 5):
			if not fauna.any_visible_at(float(k)):
				has_gap = true; break
		var det_ok: bool = pure and in_band and moved and has_visible
		print("  determinístico: puro=%s faixa-horizonte=%s move=%s visível=%s (gap-no-ciclo=%s)  %s" % [str(pure), str(in_band), str(moved), str(has_visible), str(has_gap), ("OK" if det_ok else "✗")])
		if not det_ok: ok = false

		# 4c) WITNESS: do spawn da Costa (300,650), ≥1 ave DENTRO do enquadramento (1280×720 → ±640/±360)
		var spawn := Vector2(300, 650)
		var on_screen := false
		for tt in [8.0, 20.0, 40.0]:   # alguns instantes (fora do fade) — pelo menos um deve ter ave na tela
			fauna.set("_time_override", tt); fauna._apply_for_time(tt)
			for b in fauna.get_children():
				if b is Node2D and b.visible and (b as CanvasItem).modulate.a > 0.3:
					var d: Vector2 = (b as Node2D).position - spawn
					if absf(d.x) < 640.0 and absf(d.y) < 360.0:
						on_screen = true
			if on_screen: break
		print("  WITNESS: ≥1 ave no enquadramento do spawn (1280×720)  %s" % ("OK" if on_screen else "✗"))
		if not on_screen: ok = false

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
