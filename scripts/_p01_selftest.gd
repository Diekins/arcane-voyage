extends SceneTree
## Self-test do P0.1 (descoberta = RASTRO, não prêmio). Main DESTACADO + snapshot/restore do user://save. Constrói
## uma região com marco, captura o serviço curio_*, chama _mark_discovery_seen e confirma que o marco ASSENTA:
## pulso morto, prompt sem ✦ (relegível), halo em cor de repouso, idempotência por nó — SEM tocar save/recompensa.
## Rodar:  godot --headless --path godot -s res://scripts/_p01_selftest.gd

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
	var has_m: bool = main.has_method("_mark_discovery_seen")
	print("  método _mark_discovery_seen: %s" % ("OK" if has_m else "✗ AUSENTE"))
	if not has_m: ok = false

	var host := Node2D.new()
	root.add_child(host)
	main.set("_region_node", host)
	main.set("_services", [])
	main.set("_npcs", [])
	main._dispatch_region_builder("cave", main._region_world_size("cave"))

	# pega o 1º serviço curio_* (marco/micro-história)
	var svc := {}
	for s in (main.get("_services") as Array):
		if str(s.get("id", "")).begins_with("curio_"): svc = s; break
	if svc.is_empty():
		print("  ✗ nenhum marco curio_* na cave"); ok = false
	else:
		var prompt = svc.get("prompt")
		var halo = svc.get("halo")
		var pulse = svc.get("pulse")
		var text_before := str(prompt.text)
		var calls_before: bool = text_before.begins_with("✦ [E] ")
		var pulse_live_before: bool = pulse != null and pulse is Tween and pulse.is_valid()
		print("  antes: prompt='%s' (chama=%s) | pulso-vivo=%s" % [text_before, str(calls_before), str(pulse_live_before)])
		if not calls_before: ok = false; print("    ✗ prompt não começa com '✦ [E] '")

		main._mark_discovery_seen(svc)

		var node = svc.get("node")
		var seen_ok: bool = node.has_meta("av_seen")
		var text_after := str(prompt.text)
		var no_call_ok: bool = text_after.begins_with("[E] ") and not text_after.contains("✦")
		var pulse_dead_ok: bool = pulse == null or not (pulse is Tween) or not pulse.is_valid()
		var rest_color_ok: bool = is_instance_valid(halo) and abs(halo.color.r - 0.85) < 0.01 and abs(halo.color.a - 0.10) < 0.01
		print("  depois: meta_seen=%s | prompt='%s' (sem-chamado=%s) | pulso-morto=%s | halo-repouso=%s" % [
			str(seen_ok), text_after, str(no_call_ok), str(pulse_dead_ok), str(rest_color_ok)])
		if not seen_ok: ok = false; print("    ✗ meta av_seen não setado")
		if not no_call_ok: ok = false; print("    ✗ prompt ainda 'chama' (✦) / não relegível")
		if not pulse_dead_ok: ok = false; print("    ✗ pulso de respiração não foi parado")
		if not rest_color_ok: ok = false; print("    ✗ halo não assentou na cor de repouso")

		# idempotência: 2ª chamada não quebra e mantém o estado
		main._mark_discovery_seen(svc)
		var still_ok: bool = node.has_meta("av_seen") and str(prompt.text).begins_with("[E] ")
		print("  idempotência (2ª chamada): %s" % ("OK" if still_ok else "✗"))
		if not still_ok: ok = false

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
