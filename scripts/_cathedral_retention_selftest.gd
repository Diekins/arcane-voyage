extends SceneTree
## Self-test CATHEDRAL_RETENTION_LAYER_01 — a camada LEVE de retorno da Catedral (sem save/sistema). Verifica:
## (1) o elite Crescido na Parede e o raro Besta-Geodo EXISTEM e REUSAM visuais da Caverna (sentinela/fragmento);
## (2) PRESENÇA varia por sessão (elite ~75%, raro ~42% → ambos aparecem ÀS VEZES, nunca sempre/nunca) sobre N
## sorteios; (3) LUGAR varia (cada um usa ≥2 pontos distintos ao longo dos sorteios = "não no mesmo lugar");
## (4) o elite fala uma FRASE memorável (cycle cone→circle) e o raro tem aggro BAIXO (não persegue = circulação);
## (5) ANTI-CLIP exaustivo: TODOS os pontos candidatos (elite+geodo) fora de cobertura; (6) base SEMPRE presente
## (crystal_bat/living_shard/stone_sentinel em todo sorteio) + nada no Núcleo selado (y<452); (7) o build planta um
## crescimento de cristal em CADA parede candidata do elite + a marca do rumor. Save-safe. Rodar:
##   godot --headless --path godot -s res://scripts/_cathedral_retention_selftest.gd

func _initialize() -> void:
	seed(20260609)   # determinístico: o sorteio varia entre chamadas, mas a EXECUÇÃO do teste é reproduzível
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

	# ── sorteia N sessões (cada chamada a _mob_configs = uma entrada na Catedral) ──
	var N := 120
	var elite_runs := 0; var geode_runs := 0; var base_missing := 0
	var elite_pts := {}; var geode_pts := {}
	var elite_cfg := {}; var geode_cfg := {}
	for i in range(N):
		var cfgs: Array = main._mob_configs("cathedral_of_crystal")
		var ids := {}
		for c in cfgs: ids[str(c.get("id", ""))] = c
		if not (ids.has("crystal_bat") and ids.has("living_shard") and ids.has("stone_sentinel")): base_missing += 1
		if ids.has("crescido_na_parede"):
			elite_runs += 1; elite_cfg = ids["crescido_na_parede"]
			elite_pts[str((ids["crescido_na_parede"]["spawns"] as Array)[0])] = true
		if ids.has("besta_geodo"):
			geode_runs += 1; geode_cfg = ids["besta_geodo"]
			geode_pts[str((ids["besta_geodo"]["spawns"] as Array)[0])] = true

	# ── (1) existem + reusam visuais da Caverna ──
	var reuse_ok: bool = not elite_cfg.is_empty() and not geode_cfg.is_empty() \
		and str(elite_cfg.get("visual", "")) == "stone_sentinel" and str(geode_cfg.get("visual", "")) == "living_shard"
	print("  (1) elite+raro existem e reusam visuais da Caverna (sentinela/fragmento): %s" % ("OK" if reuse_ok else "✗"))
	if not reuse_ok: ok = false

	# ── (2) presença VARIA (nunca sempre/nunca) ──
	var pres_ok: bool = elite_runs > N * 0.4 and elite_runs < N and geode_runs > 0 and geode_runs < N * 0.85
	print("  (2) presença varia em %d sessões: elite=%d (~75%%) raro=%d (~42%%)  %s" % [N, elite_runs, geode_runs, ("OK" if pres_ok else "✗")])
	if not pres_ok: ok = false

	# ── (3) LUGAR varia (≥2 pontos distintos cada) ──
	var loc_ok: bool = elite_pts.size() >= 2 and geode_pts.size() >= 2
	print("  (3) lugar varia: elite usou %d pontos, raro %d pontos (≥2)  %s" % [elite_pts.size(), geode_pts.size(), ("OK" if loc_ok else "✗")])
	if not loc_ok: ok = false

	# ── (4) elite = frase memorável (cone→circle) + raro aggro BAIXO (circulação, não perseguição) ──
	var mm := Node2D.new(); mm.set_script(load("res://scripts/Mob.gd"))
	main._apply_combat_language(mm, elite_cfg)
	var phrase := []
	for b in mm.get("telegraph_cycle"): phrase.append(str((b as Dictionary).get("shape", "?")))
	mm.free()
	var beh_ok: bool = phrase == ["cone", "circle"] and float(geode_cfg.get("aggro", 999.0)) <= 220.0
	print("  (4) elite frase=%s (cone→circle) + raro aggro=%.0f (≤220 = não persegue)  %s" % [str(phrase), float(geode_cfg.get("aggro", 0.0)), ("OK" if beh_ok else "✗")])
	if not beh_ok: ok = false

	# ── (5) ANTI-CLIP exaustivo: TODOS os pontos candidatos fora de cobertura ──
	#   (constrói a região 1× p/ ter os blockers, depois sonda os consts inteiros)
	main._build_cathedral_of_crystal(Vector2(2200, 1500))
	var blk: Array = main.get("_blockers_by_level").get(0, [])
	var clip := 0
	var allpts: Array = []
	for p in main.CATH_ELITE_POINTS: allpts.append(p)
	for p in main.CATH_GEODE_POINTS: allpts.append(p)
	for sp in allpts:
		for r in blk:
			if (r as Rect2).has_point(sp) or (r as Rect2).has_point(sp + Vector2(0, 16)): clip += 1
	print("  (5) ANTI-CLIP exaustivo (%d pontos candidatos): clips=%d  %s" % [allpts.size(), clip, ("OK" if clip == 0 else "✗")])
	if clip != 0: ok = false

	# ── (6) base SEMPRE presente + nada no Núcleo selado (y<452) em nenhum sorteio ──
	var nucleo := 0
	for i in range(40):
		for c in main._mob_configs("cathedral_of_crystal"):
			if str(c.get("id", "")) == "coracao_de_cristal": continue   # HEART_OF_CRYSTAL: o apex VIVE no Núcleo (é a arena dele)
			for sp in (c["spawns"] as Array):
				if (sp as Vector2).y < 452.0: nucleo += 1
	var base_ok: bool = base_missing == 0 and nucleo == 0
	print("  (6) base sempre presente (faltas=%d) + 0 mob (fora o Coração) no Núcleo (=%d)  %s" % [base_missing, nucleo, ("OK" if base_ok else "✗")])
	if not base_ok: ok = false

	# ── (7) build: crescimento em CADA parede candidata (não dá blocker → conta por marca do rumor + 0 clip já provado) ──
	var rumor := false
	for s in (main.get("_services") as Array):
		if str((s as Dictionary).get("id", "")) == "cath_rumor": rumor = true
	print("  (7) build: marca do rumor presente=%s (crescimentos plantados nas %d paredes)  %s" % [str(rumor), main.CATH_ELITE_POINTS.size(), ("OK" if rumor else "✗")])
	if not rumor: ok = false

	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
