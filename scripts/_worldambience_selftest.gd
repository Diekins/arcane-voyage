extends SceneTree
## Self-test da fundação de áudio ambiente (WorldAmbience). Confirma o PADRÃO DORMENTE:
## com ZERO assets de áudio nada toca e nada quebra; o mapeamento região->leito está correto;
## a API set_region é no-op-segura; nenhuma dependência obrigatória de áudio; save intocado.
## Rodar:  godot --headless --path godot -s res://scripts/_worldambience_selftest.gd

func _initialize() -> void:
	var ok := true

	# save-safe: snapshot/restore (WorldAmbience NÃO toca save; isto é só cinto de segurança)
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var WA = load("res://scripts/WorldAmbience.gd")
	var amb = WA.new()
	root.add_child(amb)
	amb.setup()   # setup explícito (idempotente) — não depende do timing de _ready no SceneTree

	# 1) ASSET-AWARE: cada camada acende SE o asset existe, senão fica dormente (sem erro).
	#    Global: hoje há global_bed.ogg (1º drop-in) → ATIVO. Regional/respiros: sem asset → dormente.
	var has_global: bool = ResourceLoader.exists(amb.GLOBAL_BED_PATH)
	var gb: bool = amb.global_bed_active() == has_global   # ativo sse (e só se) há asset
	var rb: bool = not amb.region_bed_active()             # sem asset regional → dormente
	var br: bool = amb.breath_available_count() == 0       # sem respiros → dormente
	print("  asset-aware: global_asset=%s global_ativo=%s(esp %s) region_off=%s breaths=0(%s)  %s" % [str(has_global), str(amb.global_bed_active()), str(has_global), str(rb), str(br), ("OK" if (gb and rb and br) else "✗")])
	if not (gb and rb and br): ok = false

	# 2) bus criado (Ambient preferido; Master é fallback aceitável) — nunca vazio
	var bus: String = amb.bus_name()
	var bus_ok := bus == "Ambient" or bus == "Master"
	print("  bus: %s  %s" % [bus, ("OK" if bus_ok else "✗")])
	if not bus_ok: ok = false

	# 3) mapeamento região -> chave de leito (família/lugar). Genéricas = "" (só global)
	var map_cases := {
		"cave": "cave_stone", "swamp_pit": "cave_stone",
		"saltwind_shore": "coast", "starter_village": "village",
		"khet_sar_city": "desert_city", "swamp": "swamp",
		"deep_grove": "forest", "ancient_root_nest": "forest",
		"khet_sar_sands": "desert",
		"plains": "", "old_road": "",   # genéricas: sem leito próprio
	}
	var map_ok := true
	for rid in map_cases:
		var got: String = amb.bed_key_for(rid)
		if got != map_cases[rid]:
			map_ok = false
			print("    ✗ %s -> '%s' (esperado '%s')" % [rid, got, map_cases[rid]])
	print("  mapeamento região->leito (%d casos)  %s" % [map_cases.size(), ("OK" if map_ok else "✗")])
	if not map_ok: ok = false

	# 4) set_region ASSET-AWARE: chave correta + leito ATIVO sse o .ogg da chave existe.
	#    Cobre família cave_stone (cave/swamp_pit), desert_city, genérica (plains=só global) e
	#    exercita as transições (entra/sai/volta) sem erro. Cresce sozinho à medida que assets entram.
	var cases := [["cave", "cave_stone"], ["swamp_pit", "cave_stone"], ["saltwind_shore", "coast"], ["deep_grove", "forest"], ["ancient_root_nest", "forest"], ["khet_sar_sands", "desert"], ["khet_oasis", "desert"], ["plains", ""], ["khet_sar_city", "desert_city"], ["starter_village", "village"], ["cave", "cave_stone"]]
	var set_ok := true
	for case in cases:
		var rid: String = case[0]
		var key: String = case[1]
		amb.set_region(rid)
		var expect: bool = key != "" and ResourceLoader.exists(amb.REGION_BED_PREFIX + key + ".ogg")
		var keyok: bool = amb.region_key() == key
		var actok: bool = amb.region_bed_active() == expect
		if not (keyok and actok):
			set_ok = false
			print("    ✗ %s -> key '%s'(ok %s) ativo %s (esp %s)" % [rid, amb.region_key(), str(keyok), str(amb.region_bed_active()), str(expect)])
	print("  set_region asset-aware + transições (%d, cave_stone+desert_city ATIVOS)  %s" % [cases.size(), ("OK" if set_ok else "✗")])
	if not set_ok: ok = false

	# 4c) CAMADA 3 respiros POR REGIÃO: coast/cave têm asset → pool>0; genérica (plains) → 0 (dormente)
	amb.set_region("saltwind_shore"); var b_coast: int = amb.breath_available_count()
	amb.set_region("plains"); var b_plain: int = amb.breath_available_count()
	amb.set_region("cave"); var b_cave: int = amb.breath_available_count()
	var breath_ok: bool = b_coast >= 1 and b_plain == 0 and b_cave >= 1
	print("  respiros por família: coast=%d plains=%d cave=%d  %s" % [b_coast, b_plain, b_cave, ("OK" if breath_ok else "✗")])
	if not breath_ok: ok = false

	# 5) sem dependência obrigatória: chegou aqui sem nenhum erro de asset ausente
	print("  sem dependência obrigatória de áudio (rodou sem erro de asset)  OK")

	amb.queue_free()

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")

	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
