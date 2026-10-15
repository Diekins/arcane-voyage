extends SceneTree
## Self-test CATHEDRAL_PRODUCTION_SLICE_F5 — A Catedral de Cristal (slice jogável da expansão da Caverna).
## Verifica: (1) constrói (portal→Caverna + 2 marcas de leitura/grandeza + cobertura/barreira/coração via blockers);
## (2) bestiário REUSADO da Caverna (crystal_bat/living_shard/stone_sentinel); (3) as 3 FORMAS testáveis presentes
## (line/circle/cone) via MOB_COMBAT_LANGUAGE; (4) NÚCLEO bloqueado = barreira sólida atravessa a boca da nave
## (cobertura no eixo central) + Coração placeholder (blocker, SEM mob/boss); (5) ANTI-CLIP (nenhum spawn dentro de
## cobertura/barreira/coração); (6) Entrada SEGURA (folga ≥60px no spawn) + Núcleo SEM mob vivo (slice = sem apex/
## loot-raro); (7) fiação da região (size/spawn/biome). Save-safe (snapshot/restore). Rodar:
##   godot --headless --path godot -s res://scripts/_cathedral_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host); main.set("_services", []); main.set("_portals", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_mobs", []); main.set("_chests", [])
	main._build_cathedral_of_crystal(Vector2(2200, 1500))

	# ── (1) construiu: portal de volta + 2 descobertas + cobertura/barreira (blockers) ──
	var back_ok := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "veins": back_ok = true   # BUILD_VEIOS_F5: a Catedral volta aos Veios (2º degrau)
	var marks := 0
	for s in (main.get("_services") as Array):
		if str((s as Dictionary).get("kind", "")) == "future_exit" and str((s as Dictionary).get("id", "")).begins_with("cath_"): marks += 1
	var blk: Array = main.get("_blockers_by_level").get(0, [])
	var build_ok: bool = back_ok and marks >= 2 and blk.size() >= 12
	print("  (1) construiu: portal→Caverna=%s descobertas=%d cobertura(blockers)=%d  %s" % [str(back_ok), marks, blk.size(), ("OK" if build_ok else "✗")])
	if not build_ok: ok = false

	# ── (2) bestiário REUSADO da Caverna ──
	var by_id := {}
	for c in main._mob_configs("cathedral_of_crystal"): by_id[str(c.get("id", ""))] = c
	var want := ["crystal_bat", "living_shard", "stone_sentinel"]
	var missing := []
	for id in want:
		if not by_id.has(id): missing.append(id)
	print("  (2) bestiário reusado (crystal_bat/living_shard/stone_sentinel): %s  %s" % [("todos" if missing.is_empty() else str(missing)), ("OK" if missing.is_empty() else "✗")])
	if not missing.is_empty(): ok = false

	# ── (3) as 3 FORMAS testáveis: line (crystal_bat) + cone (stone_sentinel) + circle (living_shard) ──
	var shapes := {}
	for id in want:
		if not by_id.has(id): continue
		var mm := Node2D.new(); mm.set_script(load("res://scripts/Mob.gd"))
		main._apply_combat_language(mm, by_id[id])
		shapes[id] = str(mm.get("telegraph_shape"))
		mm.free()
	var has_line: bool = shapes.get("crystal_bat") == "line"
	var has_cone: bool = shapes.get("stone_sentinel") == "cone"
	var has_circle: bool = shapes.get("living_shard") == "circle"
	var forms_ok: bool = has_line and has_cone and has_circle
	print("  (3) 3 FORMAS: line(bat)=%s cone(sentinel)=%s circle(shard)=%s  %s" % [str(has_line), str(has_cone), str(has_circle), ("OK" if forms_ok else "✗")])
	if not forms_ok: ok = false

	# ── (4) NÚCLEO = ARENA do Coração (HEART_OF_CRYSTAL_PROMOTION): BRECHA central aberta (não mais selada) + massa
	#        lateral de cobertura + o Coração boss nos configs + a descida selada às Fendas (marca) ──
	var breach_open := true
	for r in blk:
		if (r as Rect2).has_point(Vector2(1100.0, 452.0)): breach_open = false   # a brecha central NÃO tem barreira
	var side_wall := false
	for r in blk:
		var rr := r as Rect2
		if rr.has_point(Vector2(740.0, 452.0)) and rr.size.x >= 120.0: side_wall = true   # massa lateral = cobertura
	var heart_boss := false
	for c in main._mob_configs("cathedral_of_crystal"):
		if str(c.get("id", "")) == "coracao_de_cristal": heart_boss = true
	var fendas := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "fendas": fendas = true   # BUILD_FENDAS: a descida agora é um portal real
	var nucleo_ok: bool = breach_open and side_wall and heart_boss and fendas
	print("  (4) Núcleo=arena: brecha aberta=%s parede lateral=%s Coração boss=%s Fendas selada=%s  %s" % [str(breach_open), str(side_wall), str(heart_boss), str(fendas), ("OK" if nucleo_ok else "✗")])
	if not nucleo_ok: ok = false

	# ── (5) ANTI-CLIP: nenhum spawn dentro de cobertura/barreira/coração (a disciplina de sonda) ──
	var clip := 0
	for c in main._mob_configs("cathedral_of_crystal"):
		for sp in (c["spawns"] as Array):
			for r in blk:
				if (r as Rect2).has_point(sp) or (r as Rect2).has_point(sp + Vector2(0, 16)): clip += 1
	print("  (5) ANTI-CLIP: spawns dentro de cobertura=%d  %s" % [clip, ("OK" if clip == 0 else "✗")])
	if clip != 0: ok = false

	# ── (6) Entrada SEGURA (folga ≥60 no spawn) + Núcleo só com o CORAÇÃO (o apex enraizado é o único mob ao norte da
	#        brecha; nenhum sealed-apex de respawn ~infinito fora a retenção) ──
	var spawn: Vector2 = main._region_spawn("cathedral_of_crystal")
	var nf := 999999.0
	var apex := 0; var nucleo_mob := 0
	var allowed := ["crescido_na_parede", "besta_geodo", "coracao_de_cristal"]   # retenção (sessão) + o apex recorrente
	for c in main._mob_configs("cathedral_of_crystal"):
		if float(c.get("respawn", 0.0)) > 100000.0 and not (str(c.get("id", "")) in allowed): apex += 1
		for sp in (c["spawns"] as Array):
			var d := spawn.distance_to(sp) - float(c["aggro"])
			if d < nf: nf = d
			if (sp as Vector2).y < 452.0 and str(c.get("id", "")) != "coracao_de_cristal": nucleo_mob += 1   # só o Coração no Núcleo
	var safe_ok: bool = nf >= 60.0 and apex == 0 and nucleo_mob == 0
	print("  (6) Entrada folga=%.0fpx · sealed-apex=%d · mob-não-Coração no Núcleo=%d  %s" % [nf, apex, nucleo_mob, ("OK" if safe_ok else "✗")])
	if not safe_ok: ok = false

	# ── (7) fiação da região: size/spawn/biome ──
	var sz: Vector2 = main._region_world_size("cathedral_of_crystal")
	var biome: String = main._region_biome("cathedral_of_crystal")
	var wire_ok: bool = sz == Vector2(2200, 1500) and spawn == Vector2(1100, 1360) and biome == "caverna"
	print("  (7) fiação: size=%s spawn=%s biome=%s  %s" % [str(sz), str(spawn), biome, ("OK" if wire_ok else "✗")])
	if not wire_ok: ok = false

	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
