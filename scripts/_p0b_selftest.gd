extends SceneTree
## Self-test do P0-B (P0.4 level-up reenquadrado + P0.6 marcos mais legíveis). Main DESTACADO + snapshot/restore do
## user://save. P0.4: métodos/assinatura não quebram (texto é revisado no código + F5). P0.6: cada marco/micro-
## história ganha halo (Polygon2D z=-1) e prompt legível ("✦ [E] " + contorno). Rodar:
##   godot --headless --path godot -s res://scripts/_p0b_selftest.gd

const REGIONS := ["cave", "starter_village", "saltwind_shore"]   # têm marco de curiosidade e/ou micro-história

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

	# --- P0.4: assinatura/no-crash (popup_layer null no destacado → no-op seguro) ---
	for m in ["_on_leveled_up", "_show_reward_popup"]:
		var has_m: bool = main.has_method(m)
		print("  método %s: %s" % [m, ("OK" if has_m else "✗ AUSENTE")])
		if not has_m: ok = false
	main.set("_popup_layer", null)
	main._on_leveled_up(7)                       # caminho sem popup_layer: não pode crashar
	main._show_reward_popup("teste", Color("ffe6b0"))   # 2 args (cor opcional)
	print("  P0.4 level-up: chamada segura (sem crash, sem popup_layer)  OK")

	# --- P0.6: halo + prompt legível em todo marco/micro-história ---
	var total := 0
	for region in REGIONS:
		var host := Node2D.new()
		root.add_child(host)
		main.set("_region_node", host)
		main.set("_services", [])
		main.set("_npcs", [])
		main._dispatch_region_builder(region, main._region_world_size(region))
		var markers := 0
		for s in (main.get("_services") as Array):
			if str(s.get("kind", "")) != "future_exit": continue
			if not str(s.get("id", "")).begins_with("curio_"): continue   # marcos/micro via _add_lore_marker
			markers += 1; total += 1
			var node: Node2D = s.get("node")
			var prompt = s.get("prompt")
			# halo: algum Polygon2D filho com z_index -1
			var has_halo := false
			if node != null:
				for c in node.get_children():
					if c is Polygon2D and c.z_index == -1: has_halo = true
			var text_ok: bool = prompt != null and str(prompt.text).begins_with("✦ [E] ")
			var outline_ok: bool = prompt != null and prompt.has_theme_constant_override("outline_size") and prompt.get_theme_constant("outline_size") > 0
			if not has_halo: ok = false; print("    ✗ %s/%s: sem halo" % [region, s.get("id")])
			if not text_ok: ok = false; print("    ✗ %s/%s: prompt sem '✦ [E] '" % [region, s.get("id")])
			if not outline_ok: ok = false; print("    ✗ %s/%s: prompt sem contorno" % [region, s.get("id")])
		print("  %-16s marcos/micro com halo+prompt-legível: %d" % [region, markers])
		if markers == 0: ok = false; print("    ✗ %s: nenhum marco encontrado" % region)
	print("  total de marcos/micro verificados: %d" % total)

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
