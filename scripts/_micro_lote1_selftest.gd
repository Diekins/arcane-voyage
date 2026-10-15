extends SceneTree
## Self-test READ-ONLY do LOTE 1 de micro-histórias (GODOT-MICRO-STORY-LOTE1). Main DESTACADO + snapshot/restore do
## user://save (builders podem chamar set_story_flag→save_game). Confirma, ao construir cada região, que existe o
## objeto [E] da micro-história como future_exit SEM reward, e que o marco de curiosidade da região coexiste.
## Rodar:  godot --headless --path godot -s res://scripts/_micro_lote1_selftest.gd

# region : {micro_id, curio_id}
const CASES := {
	"plains":      {"micro": "curio_página_do_andarilho", "curio": "curio_marco_de_pedras"},
	"swamp":       {"micro": "curio_o_esquema_de_halda",  "curio": "curio_engrenagem_parada"},
	"ashen_grove": {"micro": "curio_a_foice_do_zelador",  "curio": "curio_sob_as_folhas"},
}

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

	for region in CASES.keys():
		var host := Node2D.new()
		root.add_child(host)
		main.set("_region_node", host)
		main.set("_services", [])
		main.set("_npcs", [])
		main.set("_blockers", [])
		var blk_before: int = (main.get("_blockers") as Array).size()
		main._dispatch_region_builder(region, main._region_world_size(region))
		var micro := {}
		var curio := false
		for s in (main.get("_services") as Array):
			var id := str(s.get("id", ""))
			if id == CASES[region]["micro"]: micro = s
			if id == CASES[region]["curio"]: curio = true
		var micro_ok := not micro.is_empty() and str(micro.get("kind", "")) == "future_exit"
		var no_reward := not micro.has("reward")
		var blk_added: int = (main.get("_blockers") as Array).size() - blk_before
		print("  %-12s micro(future_exit)=%s sem-reward=%s | curio-coexiste=%s | blockers do lote=? (info)" % [region, str(micro_ok), str(no_reward), str(curio)])
		if not micro_ok: ok = false; print("    ✗ %s: micro-história ausente/!=future_exit" % region)
		if not no_reward: ok = false; print("    ✗ %s: micro-história tem recompensa" % region)
		if not curio: ok = false; print("    ✗ %s: marco de curiosidade sumiu" % region)

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
