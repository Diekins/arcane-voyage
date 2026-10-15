extends SceneTree
## Self-test KHETSAR_CONSOLIDATION_BUILD_01 — os 4 cortes embarcam sem quebrar nada. Verifica que as regiões que
## recebem os cortes CONSTROEM e mantêm sua estrutura: (1) Areais com as 2 bocas + a silhueta (build sem crash);
## (2) Acampamento com os 3 NPCs (Imir leva o rumor); (3) a Cisterna com a Guardiã (que leva o prenúncio do Arquivo).
## A presença literal das 4 falas/silhueta é conferida por grep no source (passo bash). Save-safe. Rodar:
##   godot --headless --path godot -s res://scripts/_consolidation_selftest.gd

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
		gs.call("set_story_flag", "khet_sar_reached"); gs.call("set_story_flag", "caravan_camp_reached")

	# ── CORTE 1 — Areais: as 2 bocas + a silhueta. Build sem crash; bocas presentes. ──
	var h1 := Node2D.new(); root.add_child(h1); main.set("_region_node", h1)
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_chests", []); main.set("_mobs", [])
	main._build_khet_sar_sands(Vector2(2000, 1300))
	var maw_boca := false; var colon_boca := false
	for p in (main.get("_portals") as Array):
		var t := str((p as Dictionary).get("target", ""))
		if t == "khet_sand_maw": maw_boca = true
		if t == "khet_colonnade": colon_boca = true
	var c1 := maw_boca and colon_boca
	print("  CORTE1 Areais: bocas Garganta=%s Colunata=%s (build OK + silhueta)  %s" % [str(maw_boca), str(colon_boca), ("OK" if c1 else "✗")])
	if not c1: ok = false
	h1.free()

	# ── CORTE 2 — Acampamento: os 3 NPCs (Imir = portador do rumor). Build sem crash. ──
	var h2 := Node2D.new(); root.add_child(h2); main.set("_region_node", h2)
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_chests", []); main.set("_mobs", [])
	main._build_khet_caravan_camp(Vector2(1500, 1000))
	var names := {}
	for n in (main.get("_npcs") as Array):
		names[str((n as Dictionary).get("name", ""))] = true
	var c2 := names.has("Guia Imir") and names.has("Mercadora Yalla") and names.has("Ferreiro Kesh")
	print("  CORTE2 Acampamento: Imir(rumor)+Yalla+Kesh presentes: %s  %s" % [str(names.keys()), ("OK" if c2 else "✗")])
	if not c2: ok = false
	h2.free()

	# ── CORTE 3 — a Cisterna: a Guardiã dos Nomes (leva o prenúncio do Arquivo). Build sem crash; guardiã presente. ──
	var h3 := Node2D.new(); root.add_child(h3); main.set("_region_node", h3)
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_chests", []); main.set("_mobs", []); main.set("_floor_containers", {})
	main._build_stone_cistern(360.0, 1600.0, 2400.0)
	var guard := false
	for s in (main.get("_services") as Array):
		if str((s as Dictionary).get("id", "")) == "stone_guard": guard = true
	print("  CORTE3 Cisterna: a Guardiã dos Nomes (prenúncio) presente: %s  %s" % [str(guard), ("OK" if guard else "✗")])
	if not guard: ok = false
	h3.free()

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
