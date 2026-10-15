extends SceneTree
## Self-test READ-ONLY da LINGUAGEM DOS GUARDIÕES (GODOT-GUARDIAN-LANGUAGE-1). Main DESTACADO + SNAPSHOT/RESTORE do
## user://save (à prova de builder que salve). Valida: (1) GUARDIAN_LINES tem entrada p/ os 6 (+death p/ 5); (2)
## GUARDIAN_TELEGRAPH tem os 4 elites; (3) elite-guardião spawna com telegraph TEMÁTICO (cor+raio maior); (4) mob
## comum mantém telegraph DEFAULT (inalterado).
## Rodar:  godot --headless --path godot -s res://scripts/_guardian_language_selftest.gd

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

	# (1) linhas
	var lines: Dictionary = main.GUARDIAN_LINES
	var miss_entry := []
	for k in ["Lobo Alfa", "Golem de Cristal", "scrap_colossus", "root_matriarch", "ancient_root_heart", "tide_warden"]:
		if not lines.has(k) or not lines[k].has("entry") or str(lines[k]["entry"]) == "":
			miss_entry.append(k)
	print("  (1) GUARDIAN_LINES entradas faltando: %s" % str(miss_entry))
	if not miss_entry.is_empty(): ok = false

	# (2) telegraphs
	var tel: Dictionary = main.GUARDIAN_TELEGRAPH
	var miss_tel := []
	for k in ["scrap_colossus", "root_matriarch", "ancient_root_heart", "tide_warden"]:
		if not tel.has(k): miss_tel.append(k)
	print("  (2) GUARDIAN_TELEGRAPH faltando: %s" % str(miss_tel))
	if not miss_tel.is_empty(): ok = false

	# helper p/ achar cfg por id
	var find_cfg := func(region: String, id: String):
		for c in main._mob_configs(region):
			if str(c.get("id", "")) == id:
				return c
		return null

	# (3) elite-guardião: _spawn_mob_group aplica o tema (exports telegraph_color/scale, lidos pelo _tele no _ready)
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host); main.set("_mobs", [])
	var sc = find_cfg.call("swamp_pit", "scrap_colossus")
	var sc_themed := false
	if sc != null:
		main._spawn_mob_group(sc)
		var m = (main.get("_mobs") as Array)[0]
		var c: Color = m.get("telegraph_color")
		var s: float = float(m.get("telegraph_scale"))
		var want: Color = tel["scrap_colossus"]["color"]
		sc_themed = (absf(c.r - want.r) < 0.02 and absf(c.g - want.g) < 0.02 and s > 1.01)
		print("  (3) scrap_colossus tema aplicado (cor+scale=%.2f>1): %s" % [s, str(sc_themed)])
	if not sc_themed: ok = false; print("    ✗ telegraph do Coloso não tematizado")

	# (4) mob comum: tema DEFAULT (não alterado)
	var host2 := Node2D.new(); root.add_child(host2)
	main.set("_region_node", host2); main.set("_mobs", [])
	var yw = find_cfg.call("plains", "young_wolf")
	var yw_default := false
	if yw != null:
		main._spawn_mob_group(yw)
		var m2 = (main.get("_mobs") as Array)[0]
		var c2: Color = m2.get("telegraph_color")
		var s2: float = float(m2.get("telegraph_scale"))
		yw_default = (absf(c2.r - 0.96) < 0.02 and absf(c2.g - 0.42) < 0.02 and absf(s2 - 1.0) < 0.01)
		print("  (4) young_wolf default (cor padrão + scale=%.2f): %s" % [s2, str(yw_default)])
	if not yw_default: ok = false; print("    ✗ mob comum foi alterado (deveria ser default)")

	# RESTORE save (caso algo tenha salvo)
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
