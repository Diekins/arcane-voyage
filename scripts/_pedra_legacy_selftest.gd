extends SceneTree
## Self-test PEDRA_LEGACY_F5 — o ritual "Carregar um Nome" virou LEGADO persistente. Verifica: (1) PERSISTÊNCIA +
## dedup (carry_name acumula, salva, não repete); (2) NÃO É PODER (carregar não toca ouro/xp/nível — permanência, não
## recompensa); (3) a PAREDE cresce (1 corda por nome; mais nomes = mais cordas = crescimento perceptível); (4) a
## RELEITURA é DIÁLOGO (future_exit com os nomes), não placar/pop-up; (5) round-trip do save (to_dict→apply_dict
## preserva os nomes). Save-safe (snapshot/restore + o teste limpa/restaura carried_names). Rodar:
##   godot --headless --path godot -s res://scripts/_pedra_legacy_selftest.gd

func _cords(host: Node) -> int:
	var n := 0
	for c in host.get_children():
		if c is Line2D and c.has_meta("av_stone_archive"): n += 1
	return n

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()
	var gs = root.get_node_or_null("GameState")
	var saved_names: Array = []
	if gs != null:
		for x in gs.carried_names: saved_names.append(str(x))   # guarda os nomes reais p/ restaurar

	# ── (1) PERSISTÊNCIA + dedup ──
	gs.carried_names.clear()
	var a1: bool = gs.carry_name("Imen")
	var a2: bool = gs.carry_name("Imen")   # dedup → false
	var a3: bool = gs.carry_name("Sela")
	var persist_ok: bool = a1 and not a2 and a3 and gs.carried_names.size() == 2 and gs.carried_names[0] == "Imen" and gs.carried_names[1] == "Sela"
	print("  (1) persistência+dedup: novo=%s repete=%s novo2=%s lista=%s  %s" % [str(a1), str(not a2), str(a3), str(gs.carried_names), ("OK" if persist_ok else "✗")])
	if not persist_ok: ok = false

	# ── (2) NÃO É PODER (carregar não muda ouro/xp/nível) ──
	var g0 := int(gs.hero_gold); var x0 := int(gs.hero_xp); var l0 := int(gs.hero_level)
	gs.carry_name("Davi")
	var no_power: bool = int(gs.hero_gold) == g0 and int(gs.hero_xp) == x0 and int(gs.hero_level) == l0
	print("  (2) não é poder: ouro/xp/nível intactos=%s  %s" % [str(no_power), ("OK" if no_power else "✗")])
	if not no_power: ok = false

	# ── (3) a PAREDE CRESCE (1 corda por nome; mais nomes = mais cordas) ──
	var main = load("res://scripts/Main.gd").new()
	gs.carried_names.clear()
	for nm in ["Neri", "Sael", "Ona", "Yelu", "Lira"]: gs.carry_name(nm)   # 5
	var h5 := Node2D.new(); root.add_child(h5); main.set("_region_node", h5); main.set("_services", [])
	main._stone_carried_wall(Vector2(2000.0, 640.0))
	var c5 := _cords(h5)
	for nm in ["Davi", "Imen", "Sela"]: gs.carry_name(nm)   # +3 = 8
	var h8 := Node2D.new(); root.add_child(h8); main.set("_region_node", h8); main.set("_services", [])
	main._stone_carried_wall(Vector2(2000.0, 640.0))
	var c8 := _cords(h8)
	var grow_ok: bool = c5 == 5 and c8 == 8 and c8 > c5
	print("  (3) parede cresce: 5 nomes→%d cordas · 8 nomes→%d cordas (cresceu=%s)  %s" % [c5, c8, str(c8 > c5), ("OK" if grow_ok else "✗")])
	if not grow_ok: ok = false

	# ── (4) a RELEITURA é DIÁLOGO (future_exit com os nomes), não placar/recompensa ──
	var svcs: Array = main.get("_services")
	var reread := {}
	for s in svcs:
		if str((s as Dictionary).get("id", "")) == "stone_carried": reread = s
	var msg_txt := ""
	for line in (reread.get("msg", []) as Array): msg_txt += str(line) + " "
	var reread_ok: bool = not reread.is_empty() and str(reread.get("kind", "")) == "future_exit" \
		and msg_txt.contains("Imen") and msg_txt.contains("Sela") and not reread.has("reward") and not reread.has("gold")
	print("  (4) releitura = diálogo (future_exit) c/ os nomes, sem placar/recompensa=%s  %s" % [str(reread_ok), ("OK" if reread_ok else "✗")])
	if not reread_ok: ok = false

	# ── (5) round-trip REAL do save preserva os nomes (to_dict → JSON.stringify → parse → apply_dict) ──
	var before: Array = []
	for x in gs.carried_names: before.append(str(x))
	var json := JSON.stringify(gs.to_dict())   # como o save real (stringify captura os VALORES, não a referência)
	gs.carried_names.clear()
	gs.apply_dict(JSON.parse_string(json))
	var rt_ok: bool = gs.carried_names.size() == before.size() and (before.is_empty() or gs.carried_names[0] == before[0])
	print("  (5) round-trip save (to_dict→apply_dict) preserva %d nomes=%s  %s" % [before.size(), str(rt_ok), ("OK" if rt_ok else "✗")])
	if not rt_ok: ok = false

	# restaura carried_names reais (em memória) + o save em disco
	gs.carried_names.clear()
	for nm in saved_names: gs.carried_names.append(str(nm))
	h5.free(); h8.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
