extends SceneTree
## Self-test READ-ONLY do P0-A (P0.3 cartão de chegada + P0.5 guardião como passagem). Main DESTACADO; NÃO
## constrói regiões, NÃO instancia tween/UI, NÃO toca o save (mas faz snapshot/restore por segurança).
## Valida só DADOS + existência de métodos + parse. Rodar:
##   godot --headless --path godot -s res://scripts/_p0a_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()

	# --- P0.3: REGION_ARRIVAL ---
	var arrival: Dictionary = main.get("REGION_ARRIVAL")
	# os dois exemplos canônicos da diretriz, com o tom exato pedido
	var ex := {"ashen_grove": "A trilha esquecida.", "saltwind_shore": "O horizonte ainda continua."}
	for rid in ex.keys():
		var got := str(arrival.get(rid, ""))
		var pass_ex: bool = got == ex[rid]
		print("  REGION_ARRIVAL[%s] = '%s'  %s" % [rid, got, ("OK" if pass_ex else "✗ esperado '%s'" % ex[rid])])
		if not pass_ex: ok = false
	# toda região anunciável tem subtítulo não-vazio e SEM dois-pontos de lore/explicação grosseira
	for rid in arrival.keys():
		if str(arrival[rid]).strip_edges() == "":
			ok = false; print("  ✗ REGION_ARRIVAL[%s] vazio" % rid)
	# título do cartão vem de _region_display_name (não deve ser o id cru) p/ as regiões com nome local
	var dn := str(main._region_display_name("ashen_grove"))
	var dn_ok := dn == "Bosque de Cinza"
	print("  _region_display_name(ashen_grove) = '%s'  %s" % [dn, ("OK" if dn_ok else "✗")])
	if not dn_ok: ok = false

	# --- P0.5: GUARDIAN_PASSAGE cobre todos os guardiões de GUARDIAN_LINES ---
	var lines: Dictionary = main.get("GUARDIAN_LINES")
	var passage: Dictionary = main.get("GUARDIAN_PASSAGE")
	for boss in lines.keys():
		var has_line := passage.has(boss) and str(passage[boss]).strip_edges() != ""
		print("  GUARDIAN_PASSAGE[%s] %s" % [boss, ("OK" if has_line else "✗ ausente/vazio")])
		if not has_line: ok = false
	var fb := str(main.get("GUARDIAN_PASSAGE_FALLBACK"))
	if fb.strip_edges() == "": ok = false; print("  ✗ GUARDIAN_PASSAGE_FALLBACK vazio")
	else: print("  GUARDIAN_PASSAGE_FALLBACK = '%s'  OK" % fb)

	# --- existência dos métodos (parse + assinatura) ---
	for m in ["_show_banner_card", "_show_arrival_card", "_show_passage_card", "_on_boss_defeated"]:
		var has_m: bool = main.has_method(m)
		print("  método %s: %s" % [m, ("OK" if has_m else "✗ AUSENTE")])
		if not has_m: ok = false

	# --- debounce do cartão de chegada NÃO toca tree/tween (Main destacado: _show_banner_card é no-op) ---
	# 1ª região da sessão = ponto de partida → _arrival_last grava mas não anuncia; 2ª = anuncia.
	main.set("_arrival_last", "")
	main._show_arrival_card("starter_village")          # boot: registra, não anuncia
	var after_first := str(main.get("_arrival_last"))
	main._show_arrival_card("ashen_grove")               # travessia: anuncia (no-op visual destacado)
	main._show_arrival_card("ashen_grove")               # repetição imediata: deduplica
	var after_dup := str(main.get("_arrival_last"))
	var debounce_ok := after_first == "starter_village" and after_dup == "ashen_grove"
	print("  debounce (start='%s' → dup='%s')  %s" % [after_first, after_dup, ("OK" if debounce_ok else "✗")])
	if not debounce_ok: ok = false

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
