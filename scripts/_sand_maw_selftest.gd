extends SceneTree
## Self-test KHETSAR_HUNT_REGION_01 — A Garganta das Areias. Verifica: (1) a região CONSTRÓI (portal de volta +
## descobertas + cover/blockers); (2) o bestiário tem rushers/sweeper/zoner/apex; (3) a LINGUAGEM (chacal/skitter=line,
## carniceiro=cone, apex=frase line→cone, cuspe=ranged); (4) PREDOMÍNIO claro de rushers (line). Save-safe
## (snapshot/restore; pré-seta a flag p/ não disparar popup). Rodar:
##   godot --headless --path godot -s res://scripts/_sand_maw_selftest.gd

func _shapes_of(cycle: Array) -> Array:
	var out := []
	for b in cycle: out.append(str((b as Dictionary).get("shape", "?")))
	return out

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host)
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_mobs", []); main.set("_chests", [])
	var gs = root.get_node_or_null("GameState")
	if gs != null: gs.call("set_story_flag", "sand_maw_reached")   # pré-seta → _build não dispara reward popup

	main._build_khet_sand_maw(Vector2(2000, 1400))

	# ── (1) a região construiu: portal de volta + descobertas + cover ──
	var portals: Array = main.get("_portals")
	var back_ok := false
	for p in portals:
		if str((p as Dictionary).get("target", "")) == "khet_sar_sands": back_ok = true
	var svcs: Array = main.get("_services")
	var marks := 0
	for s in svcs:
		if str((s as Dictionary).get("kind", "")) == "future_exit" and str((s as Dictionary).get("id", "")).begins_with("maw_"): marks += 1
	var blockers: Array = main.get("_blockers_by_level").get(0, [])
	var build_ok: bool = back_ok and marks >= 2 and blockers.size() >= 6
	print("  (1) região construiu: portal-volta=%s descobertas=%d cover(blockers)=%d  %s" % [str(back_ok), marks, blockers.size(), ("OK" if build_ok else "✗")])
	if not build_ok: ok = false

	# ── (2) bestiário: rushers + sweeper + zoner + apex ──
	var cfgs: Array = main._mob_configs("khet_sand_maw")
	var by_id := {}
	for c in cfgs: by_id[str(c.get("id", ""))] = c
	var want := ["chacal_das_dunas", "necrofago_skitter", "carniceiro_areias", "cuspe_areia", "maw_apex_jackal"]
	var missing := []
	for id in want:
		if not by_id.has(id): missing.append(id)
	print("  (2) bestiário completo (rusher×2/sweeper/zoner/apex): %s  %s" % [("todos" if missing.is_empty() else str(missing)), ("OK" if missing.is_empty() else "✗")])
	if not missing.is_empty(): ok = false

	# ── (3) LINGUAGEM aplicada ──
	var shapes := {}
	var cycles := {}
	for id in want:
		if not by_id.has(id): continue
		var m := Node2D.new(); m.set_script(load("res://scripts/Mob.gd"))
		main._apply_combat_language(m, by_id[id])
		shapes[id] = str(m.get("telegraph_shape"))
		cycles[id] = _shapes_of(m.get("telegraph_cycle"))
		m.free()
	var lang_ok: bool = shapes.get("chacal_das_dunas") == "line" and shapes.get("necrofago_skitter") == "line" \
		and shapes.get("carniceiro_areias") == "cone" and cycles.get("maw_apex_jackal") == ["line", "cone"] \
		and bool(by_id["cuspe_areia"].get("ranged", false))
	print("  (3) linguagem: chacal=%s skitter=%s carniceiro=%s apex=%s cuspe.ranged=%s  %s" % [
		shapes.get("chacal_das_dunas"), shapes.get("necrofago_skitter"), shapes.get("carniceiro_areias"),
		str(cycles.get("maw_apex_jackal")), str(by_id["cuspe_areia"].get("ranged", false)), ("OK" if lang_ok else "✗")])
	if not lang_ok: ok = false

	# ── (4) PREDOMÍNIO de rushers (line) sobre sweeper+zoner ──
	var line_spawns := int((by_id["chacal_das_dunas"]["spawns"] as Array).size()) + int((by_id["necrofago_skitter"]["spawns"] as Array).size())
	var other_spawns := int((by_id["carniceiro_areias"]["spawns"] as Array).size()) + int((by_id["cuspe_areia"]["spawns"] as Array).size())
	var dom_ok: bool = line_spawns >= 2 * other_spawns and line_spawns >= 6
	print("  (4) predomínio rushers: line=%d vs sweeper+zoner=%d  %s" % [line_spawns, other_spawns, ("OK" if dom_ok else "✗")])
	if not dom_ok: ok = false

	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
