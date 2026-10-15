extends SceneTree
## Self-test READ-ONLY do LOTE 2 (Ecos de Ausência). Main DESTACADO + snapshot/restore do user://save. Confirma:
## cada região gera o objeto [E] da micro-história como future_exit SEM reward, e o marco de curiosidade coexiste.
## Rodar:  godot --headless --path godot -s res://scripts/_micro_lote2_selftest.gd

const CASES := {
	"cave":              {"micro": "curio_a_contagem_na_pedra", "curio": "curio_marca_na_pedra"},
	"old_road":          {"micro": "curio_o_livro_de_hóspedes", "curio": "curio_marco_da_estrada"},
	"deep_grove":        {"micro": "curio_o_rastro_da_colhedora", "curio": "curio_raiz_que_pulsa"},
	"ancient_root_nest": {"micro": "curio_o_último_a_entrar", "curio": "curio_algo_antigo"},
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
		main._dispatch_region_builder(region, main._region_world_size(region))
		var micro := {}
		var curio := false
		for s in (main.get("_services") as Array):
			var id := str(s.get("id", ""))
			if id == CASES[region]["micro"]: micro = s
			if id == CASES[region]["curio"]: curio = true
		var micro_ok := not micro.is_empty() and str(micro.get("kind", "")) == "future_exit"
		var no_reward := not micro.has("reward")
		print("  %-18s micro(future_exit)=%s sem-reward=%s | curio-coexiste=%s" % [region, str(micro_ok), str(no_reward), str(curio)])
		if not micro_ok: ok = false; print("    ✗ %s: micro-história ausente/!=future_exit" % region)
		if not no_reward: ok = false; print("    ✗ %s: micro-história tem recompensa" % region)
		if not curio: ok = false; print("    ✗ %s: marco de curiosidade sumiu" % region)

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
