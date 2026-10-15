extends SceneTree
## Self-test READ-ONLY da micro-história "O Barco de Maro" (GODOT-MICRO-STORY-MARO-1). Main DESTACADO +
## snapshot/restore do user://save (⚠️ _build_saltwind_shore chama set_story_flag→save_game). Confirma, ao construir
## a Costa: (1) NPC "Sefa" presente; (2) objeto [E] "A Garrafa de Maro" = future_exit; (3) SEM reward; (4) o marco
## de curiosidade "Além do Mar" coexiste.
## Rodar:  godot --headless --path godot -s res://scripts/_micro_maro_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_sandbox", false)
	var host := Node2D.new()
	root.add_child(host)
	main.set("_region_node", host)
	main.set("_services", [])
	main.set("_npcs", [])
	main._dispatch_region_builder("saltwind_shore", main._region_world_size("saltwind_shore"))

	var sefa := false
	for c in host.get_children():
		if String(c.name).begins_with("Sefa"):
			sefa = true
	var garrafa := {}
	var alem := false
	for s in (main.get("_services") as Array):
		var id := str(s.get("id", ""))
		if id == "curio_a_garrafa_de_maro": garrafa = s
		if id == "curio_além_do_mar" or id == "curio_alem_do_mar": alem = true
	var g_ok := not garrafa.is_empty() and str(garrafa.get("kind", "")) == "future_exit"
	var no_reward := not garrafa.has("reward")
	print("  (1) NPC 'Sefa' presente: %s" % str(sefa))
	print("  (2) 'A Garrafa de Maro' future_exit: %s | (3) sem reward: %s | (4) 'Além do Mar' coexiste: %s" % [str(g_ok), str(no_reward), str(alem)])
	if not sefa: ok = false; print("    ✗ Sefa não construída")
	if not g_ok: ok = false; print("    ✗ Garrafa ausente/!=future_exit")
	if not no_reward: ok = false; print("    ✗ micro-história tem recompensa (deveria ser só mundo)")
	if not alem: ok = false; print("    ✗ marco de curiosidade da Costa sumiu")

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
