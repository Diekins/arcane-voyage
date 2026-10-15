extends SceneTree
## Self-test PROJECTILE_COVER_PASS_01 — a cobertura cumpre a promessa. Valida: (1) SEM cobertura o tiro acerta;
## (2) COM um pilar no caminho o tiro é absorvido (sem dano); (3) wiring real — Mob ranged passa _blockers ao
## projétil e o pilar barra o golpe (attack_hero não dispara); (4) a Colunata tem pilares na lista plana _blockers.
## Save-safe. Rodar:  godot --headless --path godot -s res://scripts/_projectile_cover_selftest.gd

func _tick(p, n: int) -> void:
	for i in range(n):
		if not is_instance_valid(p) or bool(p.get("_arrived")): return
		p.call("_process", 0.05)

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var host := Node2D.new(); root.add_child(host)
	var player := Node2D.new(); root.add_child(player); player.position = Vector2(400, 0)

	# ── (1) SEM cobertura → ACERTA ──
	var hitsA := [0]
	var pA := MobProjectile.spawn(host, Vector2(0, 0), Vector2(400, 0), 340.0, 10, player, Color.WHITE, "impact_blue_magic", 70.0)
	pA.set_blockers([])
	pA.hit.connect(func(_d): hitsA[0] += 1)
	_tick(pA, 60)
	var no_cover_ok: bool = hitsA[0] == 1
	print("  (1) SEM cobertura o tiro ACERTA: hits=%d  %s" % [hitsA[0], ("OK" if no_cover_ok else "✗")])
	if not no_cover_ok: ok = false

	# ── (2) COM pilar no caminho → ABSORVIDO (sem dano) ──
	var hitsB := [0]
	var pB := MobProjectile.spawn(host, Vector2(0, 0), Vector2(400, 0), 340.0, 10, player, Color.WHITE, "impact_blue_magic", 70.0)
	pB.set_blockers([Rect2(190, -40, 40, 80)])   # "pilar" cruzando o trajeto (y=0)
	pB.hit.connect(func(_d): hitsB[0] += 1)
	_tick(pB, 60)
	var cover_ok: bool = hitsB[0] == 0
	print("  (2) COM pilar no caminho o tiro é BLOQUEADO: hits=%d  %s" % [hitsB[0], ("OK" if cover_ok else "✗")])
	if not cover_ok: ok = false

	# ── (3) WIRING real: Mob ranged → set_blockers no projétil; o pilar barra o golpe ──
	var main = load("res://scripts/Main.gd").new()
	var mhost := Node2D.new(); root.add_child(mhost)
	var mob := Node2D.new(); mob.set_script(load("res://scripts/Mob.gd")); mob.position = Vector2(0, 0); mhost.add_child(mob)
	mob.set("ranged", true); mob.set("_blockers", [Rect2(190, -40, 40, 80)]); mob.set("_player", player)
	var mhits := [0]
	mob.connect("attack_hero", func(_a): mhits[0] += 1)
	mob.call("_fire_projectile", Vector2(400, 0))
	var proj = null
	for ch in mhost.get_children():
		if ch is MobProjectile: proj = ch
	var wired_has_blk: bool = proj != null and (proj.get("_blockers") as Array).size() > 0
	_tick(proj, 60)
	var wired_ok: bool = wired_has_blk and mhits[0] == 0
	print("  (3) wiring: projétil recebe _blockers=%s + pilar barra o golpe (attack_hero=%d)  %s" % [str(wired_has_blk), mhits[0], ("OK" if wired_ok else "✗")])
	if not wired_ok: ok = false

	# ── (4) a Colunata tem pilares na lista plana _blockers (cobertura real disponível) ──
	var gs = root.get_node_or_null("GameState")
	if gs != null: gs.call("set_story_flag", "colonnade_reached")
	var chost := Node2D.new(); root.add_child(chost)
	main.set("_region_node", chost); main.set("_services", []); main.set("_portals", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_mobs", []); main.set("_chests", [])
	main._build_khet_colonnade(Vector2(2100, 1400))
	var flat: Array = main.get("_blockers")
	var colon_ok: bool = flat.size() >= 14
	print("  (4) Colunata: pilares na lista plana _blockers=%d (cobertura disponível)  %s" % [flat.size(), ("OK" if colon_ok else "✗")])
	if not colon_ok: ok = false

	for n in [host, player, mhost, chost]:
		if is_instance_valid(n):
			if n.get_parent() != null: n.get_parent().remove_child(n)
			n.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
