extends SceneTree
## Self-test BUILD_FENDAS_PROFUNDAS_F5 — As Fendas Profundas (L4, "o Silêncio"). Verifica: (1) constrói (volta→Catedral
## + as 3 insinuações como marcas: fim-do-cristal / pegadas / algo-lá-embaixo); (2) o NEGATIVO: chão quase-preto +
## ZERO combate (silêncio deliberado) + biome caverna; (3) a CONTENÇÃO: fendas sem fundo (voids/blockers) cercam o
## caminho e o brinque ao sul (não se passa); (4) O Que Dorme no Fundo só INSINUADO (a silhueta existe, mas é
## inalcançável — atrás do void sul); (5) a cadeia: Catedral→Fendas (portal atrás do Coração) + Fendas→Catedral; (6)
## Entrada sem perigo (zero mob); (7) fiação (size pequena/spawn/biome/cor quase-preta). Save-safe. Rodar:
##   godot --headless --path godot -s res://scripts/_fendas_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host); main.set("_services", []); main.set("_portals", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_mobs", []); main.set("_chests", [])
	main._build_fendas(Vector2(1400, 1100))
	var blk: Array = main.get("_blockers_by_level").get(0, [])

	# ── (1) construiu: volta→Catedral + as 3 insinuações (marcas) ──
	var up_ok := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "cathedral_of_crystal": up_ok = true
	var marks := {}
	for s in (main.get("_services") as Array):
		if str((s as Dictionary).get("kind", "")) == "future_exit": marks[str((s as Dictionary).get("id", ""))] = true
	var ins_ok: bool = marks.has("fendas_top") and marks.has("fendas_steps") and marks.has("fendas_sleeper")
	var build_ok: bool = up_ok and ins_ok
	print("  (1) construiu: volta→Catedral=%s + insinuações(fim-cristal/pegadas/sleeper)=%s  %s" % [str(up_ok), str(ins_ok), ("OK" if build_ok else "✗")])
	if not build_ok: ok = false

	# ── (2) o NEGATIVO: chão quase-preto + ZERO combate + biome caverna ──
	var ground: Color = main._ground_base_color("fendas")
	var dark: bool = ground.r < 0.12 and ground.g < 0.12 and ground.b < 0.14
	var no_combat: bool = (main._mob_configs("fendas") as Array).size() == 0
	var biome: String = main._region_biome("fendas")
	var neg_ok: bool = dark and no_combat and biome == "caverna"
	print("  (2) negativo: chão quase-preto=%s (%s) · ZERO combate=%s · biome=%s  %s" % [str(dark), str(ground), str(no_combat), biome, ("OK" if neg_ok else "✗")])
	if not neg_ok: ok = false

	# ── (3) CONTENÇÃO: fendas sem fundo / paredes cercam (blockers ≥ alguns) + o brinque ao sul (blocker largo perto de y900) ──
	var south_brink := false
	for r in blk:
		var rr := r as Rect2
		if rr.size.x >= 600.0 and rr.position.y >= 870.0 and rr.position.y <= 920.0: south_brink = true
	var contain_ok: bool = blk.size() >= 5 and south_brink
	print("  (3) contenção: blockers=%d + brinque sul (não se passa)=%s  %s" % [blk.size(), str(south_brink), ("OK" if contain_ok else "✗")])
	if not contain_ok: ok = false

	# ── (4) O Que Dorme no Fundo: INSINUADO e INALCANÇÁVEL — a marca sleeper existe e a silhueta fica ALÉM do void sul
	#        (ao sul do brinque y~898, dentro da grande fenda) → não há chão andável até lá ──
	var sleeper_marked := marks.has("fendas_sleeper")
	# o void sul cobre y940..1100 (a silhueta em ~y1046 está dentro dele = inalcançável)
	var void_seals_south := false
	for r in blk:
		var rr := r as Rect2
		if rr.size.x >= 600.0 and rr.position.y >= 930.0 and (rr.position.y + rr.size.y) >= 1050.0: void_seals_south = true
	var sleeper_ok: bool = sleeper_marked and void_seals_south
	print("  (4) O Que Dorme: insinuado=%s + inalcançável (void sela o sul)=%s  %s" % [str(sleeper_marked), str(void_seals_south), ("OK" if sleeper_ok else "✗")])
	if not sleeper_ok: ok = false

	# ── (5) cadeia: Catedral→Fendas (portal atrás do Coração) + Fendas→Catedral ──
	main.set("_region_node", Node2D.new()); root.add_child(main.get("_region_node"))
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {})
	main._build_cathedral_of_crystal(Vector2(2200, 1500))
	var cath_to_fendas := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "fendas": cath_to_fendas = true
	var chain_ok: bool = up_ok and cath_to_fendas
	print("  (5) cadeia: Catedral→Fendas=%s · Fendas→Catedral=%s  %s" % [str(cath_to_fendas), str(up_ok), ("OK" if chain_ok else "✗")])
	if not chain_ok: ok = false

	# ── (6) Entrada sem perigo (zero mob = nada aggra) ──
	var safe_ok: bool = (main._mob_configs("fendas") as Array).size() == 0
	print("  (6) Entrada sem perigo (zero mob)=%s  %s" % [str(safe_ok), ("OK" if safe_ok else "✗")])
	if not safe_ok: ok = false

	# ── (7) fiação: PEQUENA + spawn + biome ──
	var sz: Vector2 = main._region_world_size("fendas")
	var spawn: Vector2 = main._region_spawn("fendas")
	var wire_ok: bool = sz == Vector2(1400, 1100) and spawn == Vector2(700, 180) and sz.x < 1900 and sz.y < 1300
	print("  (7) fiação: size=%s (pequena) spawn=%s  %s" % [str(sz), str(spawn), ("OK" if wire_ok else "✗")])
	if not wire_ok: ok = false

	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
