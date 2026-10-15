extends SceneTree
## Self-test COMBAT_LANGUAGE_PASS_01 — a linguagem de combate chegou ao MUNDO. Roda cada config real de mob por
## _apply_combat_language() e confere que cada FAMÍLIA recebeu a forma certa (line/cone), que bosses/ranged/amorfos/
## test-mobs CONTINUAM círculo, que shaped têm reach>0 e windup≥0.3, e que as 3 línguas aparecem. Save-safe
## (snapshot/restore). Rodar:  godot --headless --path godot -s res://scripts/_combat_language_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var regions := ["plains", "cave", "swamp", "swamp_pit", "old_road", "ashen_grove", "deep_grove",
		"ancient_root_nest", "saltwind_shore", "castaway_sandbar", "salt_split_isle", "khet_sar_sands", "khet_oasis"]
	var shapes := {}   # id -> shape
	var windups := {}  # id -> windup (após apply)
	var reaches := {}  # id -> reach
	for reg in regions:
		for cfg in main._mob_configs(reg):
			var m := Node2D.new(); m.set_script(load("res://scripts/Mob.gd"))
			main._apply_combat_language(m, cfg)
			var id := str(cfg.get("id", ""))
			shapes[id] = str(m.get("telegraph_shape"))
			windups[id] = float(m.get("windup_time"))
			reaches[id] = float(m.get("telegraph_reach"))
			m.free()

	# ── (1) famílias LINE (rusher) ──
	var want_line := ["young_wolf", "starving_wolf", "road_bandit", "crystal_bat", "crawling_shade", "grove_spider",
		"dusk_bat", "iron_leech", "ruin_raider", "feral_hound", "ash_wolf", "veil_spider", "dark_sprout",
		"root_spider", "hungry_root", "dune_skitter", "khet_skitter", "khet_wind_shade"]
	var line_bad := []
	for id in want_line:
		if shapes.has(id) and shapes[id] != "line": line_bad.append("%s=%s" % [id, shapes[id]])
	print("  (1) famílias LINE corretas: %s  %s" % [("todas" if line_bad.is_empty() else str(line_bad)), ("OK" if line_bad.is_empty() else "✗")])
	if not line_bad.is_empty(): ok = false

	# ── (2) famílias CONE (sweeper) ──
	var want_cone := ["wild_boar", "elder_boar", "stone_sentinel", "fallen_sentry", "moss_warden",
		"hollow_watcher", "hollow_husk", "tide_warden"]
	var cone_bad := []
	for id in want_cone:
		if shapes.has(id) and shapes[id] != "cone": cone_bad.append("%s=%s" % [id, shapes[id]])
	print("  (2) famílias CONE corretas: %s  %s" % [("todas" if cone_bad.is_empty() else str(cone_bad)), ("OK" if cone_bad.is_empty() else "✗")])
	if not cone_bad.is_empty(): ok = false

	# ── (3) CONTINUAM CÍRCULO: amorfos + olho + ranged + test (os mini-bosses agora viraram FRASES no
	#    BOSS_IDENTITY_PASS_01 — cobertos pelo _boss_identity_selftest). khet_oasis_salt_echo = mini-evento, circle.
	var want_circle := ["green_slime", "living_shard", "bog_crawler", "sap_eye", "musgo_voraz", "mage_of_heaven",
		"salt_husk", "khet_dry_sentry"]
	var circle_bad := []
	for id in want_circle:
		if shapes.has(id) and shapes[id] != "circle": circle_bad.append("%s=%s" % [id, shapes[id]])
	print("  (3) CONTINUAM círculo (amorfos/ranged/test): %s  %s" % [("todos" if circle_bad.is_empty() else str(circle_bad)), ("OK" if circle_bad.is_empty() else "✗")])
	if not circle_bad.is_empty(): ok = false

	# ── (4) shaped têm reach>0 e windup≥0.3 (legibilidade) ──
	var shaped_bad := []
	for id in shapes.keys():
		if str(shapes[id]) != "circle":
			if float(reaches[id]) <= 0.0: shaped_bad.append("%s:reach0" % id)
			if float(windups[id]) < 0.3 - 0.001: shaped_bad.append("%s:win%.2f" % [id, windups[id]])
	print("  (4) shaped com reach>0 e windup≥0.3: %s  %s" % [("todos" if shaped_bad.is_empty() else str(shaped_bad)), ("OK" if shaped_bad.is_empty() else "✗")])
	if not shaped_bad.is_empty(): ok = false

	# ── (5) variedade: as 3 línguas aparecem no mundo + contagem ──
	var n_line := 0; var n_cone := 0; var n_circle := 0
	for id in shapes.keys():
		match str(shapes[id]):
			"line": n_line += 1
			"cone": n_cone += 1
			_: n_circle += 1
	var variety_ok: bool = n_line >= 12 and n_cone >= 6 and n_circle >= 6
	print("  (5) variedade no mundo: line=%d cone=%d circle=%d  %s" % [n_line, n_cone, n_circle, ("OK" if variety_ok else "✗")])
	if not variety_ok: ok = false

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
