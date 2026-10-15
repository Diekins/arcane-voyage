extends SceneTree
## Self-test READ-ONLY da LAYER DE CURIOSIDADE (GODOT-WORLD-CURIOSITY-LAYER-1). Main DESTACADO; não grava save.
## Confirma que CADA uma das 9 regiões principais recebe 1 marco ambiental (future_exit "curio_*", só texto, sem
## transporte/flag/save) ao ser construída — ponto de interesse + objeto de história anterior + gancho/curiosidade.
## Rodar:  godot --headless --path godot -s res://scripts/_curiosity_layer_selftest.gd

const REGIONS := ["starter_village", "plains", "cave", "swamp", "old_road", "ashen_grove", "deep_grove", "ancient_root_nest", "saltwind_shore"]

func _initialize() -> void:
	var ok := true
	# ⚠️ SAVE-SAFE: alguns builders (ex.: _build_saltwind_shore) chamam GameState.set_story_flag → save_game, o que
	# gravaria o GameState DEFAULT por cima do save real. Snapshot do user://save ANTES e restauro no fim (byte a byte).
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had_save := FileAccess.file_exists(save_path)
	if had_save:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null:
			snapshot = rf.get_as_text(); rf.close()
	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_sandbox", false)   # builders procedurais normais (bosses presentes; inofensivo no detached)
	for id in REGIONS:
		var host := Node2D.new()
		root.add_child(host)
		main.set("_region_node", host)
		main.set("_services", [])
		main.set("_blockers", [])
		var blk_before: int = (main.get("_blockers") as Array).size()
		main._dispatch_region_builder(id, main._region_world_size(id))
		# procura 1 marco de curiosidade
		var curio := ""
		for s in (main.get("_services") as Array):
			if str(s.get("id", "")).begins_with("curio_") and str(s.get("kind", "")) == "future_exit":
				curio = str(s.get("title", "?"))
		var blk_added: int = (main.get("_blockers") as Array).size() - blk_before
		print("  %-20s marco='%s' | blockers do marco=%d (esperado 0)" % [id, curio, 0])
		if curio == "":
			ok = false; print("    ✗ %s sem marco de curiosidade" % id)
	# RESTAURA o save real (desfaz qualquer save_game disparado por builder)
	if had_save:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null:
			wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado do snapshot")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
