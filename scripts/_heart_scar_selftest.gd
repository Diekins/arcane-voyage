extends SceneTree
## Self-test HEART_SCAR_F5 — a 1ª cicatriz persistente (Coração/Catedral). Verifica (save-safe): (1) o flag
## `heart_scarred` PERSISTE (set_story_flag salva + idempotente) e sobrevive ao round-trip do save; (2) SEM o flag, a
## Catedral monta SEM cicatriz (0 nós av_heart_scar); (3) COM o flag, a Catedral monta COM cicatriz (cristal rachado +
## fenda fria + boca escancarada); (4) RECORRÊNCIA preservada (o Coração ainda spawna com o flag — a fera volta); (5)
## é SÓ um flag (não contador/coleção) e NÃO dá recompensa (ouro/xp intactos); (6) a cicatriz é só do Coração (gate
## específico, não framework). Rodar:  godot --headless --path godot -s res://scripts/_heart_scar_selftest.gd

func _scar_nodes(host: Node) -> int:
	return _scar_nodes_meta(host, "av_heart_scar")

func _scar_nodes_meta(host: Node, meta: String) -> int:
	var n := 0
	for c in host.get_children():
		if c.has_meta(meta): n += 1
	return n

func _build_cath(main, scarred: bool) -> Node2D:
	var h := Node2D.new(); root.add_child(h)
	main.set("_region_node", h); main.set("_services", []); main.set("_portals", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_mobs", []); main.set("_chests", [])
	main._build_cathedral_of_crystal(Vector2(2200, 1500))
	return h

func _initialize() -> void:
	seed(20260610)
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()
	var gs = root.get_node_or_null("GameState")
	var had_flag: bool = gs.is_story_flag("heart_scarred")
	var had_coloso: bool = gs.is_story_flag("colossus_scarred")
	var g0 := int(gs.hero_gold); var x0 := int(gs.hero_xp)
	var main = load("res://scripts/Main.gd").new()

	# ── (1) persistência + idempotência + round-trip ──
	gs.story_flags.erase("heart_scarred")
	var s1: bool = gs.set_story_flag("heart_scarred")   # 1ª vez → true
	var s2: bool = gs.set_story_flag("heart_scarred")   # idempotente → false
	var json := JSON.stringify(gs.to_dict()); gs.story_flags.erase("heart_scarred"); gs.apply_dict(JSON.parse_string(json))
	var persist_ok: bool = s1 and not s2 and gs.is_story_flag("heart_scarred")
	print("  (1) persistência: 1ª=%s idempotente=%s round-trip mantém=%s  %s" % [str(s1), str(not s2), str(gs.is_story_flag("heart_scarred")), ("OK" if persist_ok else "✗")])
	if not persist_ok: ok = false

	# ── (2) SEM o flag → SEM cicatriz ──
	gs.story_flags.erase("heart_scarred")
	var h_clean := _build_cath(main, false)
	var clean := _scar_nodes(h_clean)
	print("  (2) sem flag → Catedral sem cicatriz (0 nós): %d  %s" % [clean, ("OK" if clean == 0 else "✗")])
	if clean != 0: ok = false

	# ── (3) COM o flag → COM cicatriz ──
	gs.set_story_flag("heart_scarred")
	var h_scar := _build_cath(main, true)
	var scar := _scar_nodes(h_scar)
	print("  (3) com flag → Catedral COM cicatriz (>0 nós): %d  %s" % [scar, ("OK" if scar >= 6 else "✗")])
	if scar < 6: ok = false

	# ── (4) RECORRÊNCIA preservada (o Coração ainda spawna com o flag) ──
	var heart := false
	for c in main._mob_configs("cathedral_of_crystal"):
		if str(c.get("id", "")) == "coracao_de_cristal": heart = true
	print("  (4) recorrência: o Coração ainda spawna mesmo com a cicatriz=%s  %s" % [str(heart), ("OK" if heart else "✗")])
	if not heart: ok = false

	# ── (5) é SÓ um flag (não contador/coleção) + sem recompensa ──
	var n_hs := 0
	for f in gs.story_flags:
		if str(f) == "heart_scarred": n_hs += 1
	var no_reward: bool = int(gs.hero_gold) == g0 and int(gs.hero_xp) == x0 and n_hs == 1
	print("  (5) só 1 flag (não contador) + ouro/xp intactos: flags=%d  %s" % [n_hs, ("OK" if no_reward else "✗")])
	if not no_reward: ok = false

	# ── (6) específico do Coração (gate por is_story_flag no build, não framework genérico) ──
	#   prova indireta: sem o flag a Catedral fica limpa (já visto em §2) e nenhuma OUTRA região ganha nós av_heart_scar
	gs.story_flags.erase("heart_scarred"); gs.set_story_flag("heart_scarred")
	var h_other := Node2D.new(); root.add_child(h_other)
	main.set("_region_node", h_other); main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {})
	main._build_veins(Vector2(1900, 1300))   # outra região da espinha — NÃO deve ter cicatriz
	var other := _scar_nodes(h_other)
	print("  (6) específico: outra região (Veios) com o flag NÃO ganha cicatriz: %d  %s" % [other, ("OK" if other == 0 else "✗")])
	if other != 0: ok = false

	# ── (7) ★ A CICATRIZ DO COLOSO (mesmo padrão, no Pântano/Poço): gated pelo flag + recorrência preservada ──
	gs.story_flags.erase("colossus_scarred")
	var hp_clean := Node2D.new(); root.add_child(hp_clean)
	main.set("_region_node", hp_clean); main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {})
	main._build_swamp_pit(Vector2(1000, 800))
	var pit_clean := _scar_nodes_meta(hp_clean, "av_colossus_scar")
	gs.set_story_flag("colossus_scarred")
	var hp_scar := Node2D.new(); root.add_child(hp_scar)
	main.set("_region_node", hp_scar); main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {})
	main._build_swamp_pit(Vector2(1000, 800))
	var pit_scar := _scar_nodes_meta(hp_scar, "av_colossus_scar")
	var coloso_spawns := false
	for c in main._mob_configs("swamp_pit"):
		if str(c.get("id", "")) == "scrap_colossus": coloso_spawns = true
	var coloso_ok: bool = pit_clean == 0 and pit_scar >= 5 and coloso_spawns
	print("  (7) Coloso: sem flag→%d nós · com flag→%d nós · ainda spawna=%s  %s" % [pit_clean, pit_scar, str(coloso_spawns), ("OK" if coloso_ok else "✗")])
	if not coloso_ok: ok = false

	h_clean.free(); h_scar.free(); h_other.free(); hp_clean.free(); hp_scar.free()
	# restaura o estado real dos flags + o save
	gs.story_flags.erase("heart_scarred"); gs.story_flags.erase("colossus_scarred")
	if had_flag: gs.story_flags.append("heart_scarred")
	if had_coloso: gs.story_flags.append("colossus_scarred")
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
