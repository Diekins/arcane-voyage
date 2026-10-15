extends SceneTree
## Self-test COMBAT_HONESTY_PASS_01 — valida as 3 correções da auditoria: P0.1 (apex da Colunata FORA do blocker),
## P0.2 (anel do círculo = raio REAL de acerto; Golem-spell legado intacto), P0.3 (folga de leitura na entrada da
## Garganta). Save-safe (snapshot/restore + pré-seta flags). Rodar:
##   godot --headless --path godot -s res://scripts/_combat_honesty_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var gs = root.get_node_or_null("GameState")
	if gs != null:
		gs.call("set_story_flag", "colonnade_reached"); gs.call("set_story_flag", "sand_maw_reached")
	var player := Node2D.new(); player.set_script(load("res://scripts/PlayerController.gd")); root.add_child(player)

	# ── P0.1: o apex da Colunata NÃO nasce dentro de blocker (movimentação livre) ──
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host); main.set("_services", []); main.set("_portals", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_mobs", []); main.set("_chests", [])
	main._build_khet_colonnade(Vector2(2100, 1400))
	var apex := Vector2.ZERO
	for c in main._mob_configs("khet_colonnade"):
		if str(c.get("id", "")) == "colonnade_apex": apex = (c["spawns"] as Array)[0]
	var blk: Array = main.get("_blockers_by_level").get(0, [])
	var inside := false
	for r in blk:
		if (r as Rect2).has_point(apex) or (r as Rect2).has_point(apex + Vector2(0, 16)): inside = true
	print("  P0.1 apex (%s) FORA de blocker (não trava): %s  %s" % [str(apex), str(not inside), ("OK" if not inside else "✗")])
	if inside: ok = false

	# ── P0.2: o anel do CÍRCULO desenha o raio REAL de acerto (Núcleo de Sal) ──
	var ncfg := {}
	for c in main._mob_configs("khet_colonnade"):
		if str(c.get("id", "")) == "nucleo_de_sal": ncfg = c
	var nm := Node2D.new(); nm.set_script(load("res://scripts/Mob.gd")); nm.position = Vector2.ZERO; root.add_child(nm)
	main._apply_combat_language(nm, ncfg)
	nm.set("attack_range", float(ncfg["atk_range"]))   # como em _spawn_mob_group → testa o atk_range REAL do Núcleo (116)
	nm.set("_player", player); player.position = Vector2(0, 100)
	nm.call("_begin_windup", Vector2(0, 100))
	var atk := float(nm.get("attack_range"))
	var hit_r := atk * 1.2
	var ring_r := float(nm.get("_cur_reach"))   # o raio que o Mob ENVIA ao telegraph (= attack_range×1.2)
	# E o telegraph DESENHA esse raio: AttackTelegraph configurado p/ circle com reach>0 usa reach (não o radius legado).
	var t1 = load("res://scripts/AttackTelegraph.gd").new(); root.add_child(t1)
	t1.call("configure", "circle", Vector2(0, 1), hit_r, 36.0, 70.0); t1.call("begin", 0.4)
	var draws_reach: bool = absf(float(t1.get("reach")) - hit_r) < 0.5 and str(t1.get("shape")) == "circle"
	var honest: bool = absf(ring_r - hit_r) < 0.5 and draws_reach
	print("  P0.2 círculo honesto: anel(enviado)=%.0f vs hit=%.0f mismatch=%.0f / telegraph desenha reach=%s  %s" % [ring_r, hit_r, absf(ring_r - hit_r), str(draws_reach), ("OK" if honest else "✗")])
	if not honest: ok = false

	# ── P0.2b: REGRESSÃO — Onda de Cristal do Golem (AttackTelegraph com radius, SEM configure) usa o radius legado ──
	var t2 = load("res://scripts/AttackTelegraph.gd").new(); t2.set("radius", 116.0); root.add_child(t2); t2.call("begin", 0.5)
	var spell_ok: bool = absf(float(t2.get("reach"))) < 0.001   # reach=0 (não-configurado) → desenha pelo radius=116
	print("  P0.2b Golem-spell legado (reach não-configurado=0 → usa radius): %s  %s" % [str(spell_ok), ("OK" if spell_ok else "✗")])
	if not spell_ok: ok = false

	# ── P0.2c: REGRESSÃO — cone NÃO usa attack_range×1.2 (mantém o reach do leque) ──
	var gcfg := {}
	for c in main._mob_configs("khet_colonnade"):
		if str(c.get("id", "")) == "guardiao_coluna": gcfg = c
	var gm := Node2D.new(); gm.set_script(load("res://scripts/Mob.gd")); gm.position = Vector2.ZERO; root.add_child(gm)
	main._apply_combat_language(gm, gcfg); gm.set("_player", player)
	gm.call("_begin_windup", Vector2(0, 100))
	var cone_ok: bool = str(gm.get("_cur_shape")) == "cone" and absf(float(gm.get("_cur_reach")) - float(gm.get("attack_range")) * 1.2) > 1.0
	print("  P0.2c cone mantém reach do leque (%.0f, ≠ hit-círculo): %s  %s" % [float(gm.get("_cur_reach")), str(cone_ok), ("OK" if cone_ok else "✗")])
	if not cone_ok: ok = false

	# ── P0.3: entrada da Garganta tem folga de leitura (menor folga aggro ≥ 100px) ──
	var spawn: Vector2 = main._region_spawn("khet_sand_maw")
	var min_folga := 999999.0; var who := ""
	for c in main._mob_configs("khet_sand_maw"):
		for sp in (c["spawns"] as Array):
			var f := spawn.distance_to(sp) - float(c["aggro"])
			if f < min_folga: min_folga = f; who = str(c["id"])
	var read_ok: bool = min_folga >= 100.0
	print("  P0.3 folga de leitura na entrada da Garganta: %.0fpx (%s)  %s" % [min_folga, who, ("OK" if read_ok else "✗")])
	if not read_ok: ok = false

	for n in [host, nm, gm, t1, t2, player]:
		if n.get_parent() != null: n.get_parent().remove_child(n)
		n.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
