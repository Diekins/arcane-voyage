extends SceneTree
## Self-test FATIA A2 — SAVE round-trip real (GameState). Prova: (1) os campos de fase entram no to_dict e
## voltam pelo apply_dict; (2) save ANTIGO sem os campos → defaults seguros (1/1/0/1) SEM quebrar o resto do
## load. Snapshot/restore do save + do estado em memória. Rodar:
##   godot --headless --path godot -s res://scripts/_stage_save_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1

func _initialize() -> void:
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		print(">>> FALHOU (GameState autoload ausente)"); quit(1); return

	# snapshot do estado atual (não perder o save real do dono)
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()
	var mem: Dictionary = gs.to_dict()   # memória atual p/ restaurar no fim

	# (1) round-trip: escreve campos de fase → to_dict → apply_dict → sobrevivem
	gs.stage_chapter = 3; gs.stage_index = 7; gs.stage_kills = 5; gs.stage_highest_global = 26
	var d: Dictionary = gs.to_dict()
	_chk("to_dict inclui os campos de fase", d.has("stage_chapter") and d.has("stage_index") and d.has("stage_kills") and d.has("stage_highest_global"))
	# zera e reaplica
	gs.stage_chapter = 1; gs.stage_index = 1; gs.stage_kills = 0; gs.stage_highest_global = 1
	gs.apply_dict(d)
	_chk("apply_dict restaura 3/7/5/26", gs.stage_chapter == 3 and gs.stage_index == 7 and gs.stage_kills == 5 and gs.stage_highest_global == 26)

	# (2) save ANTIGO: dict sem os campos de fase, mas com outros campos → defaults + resto intacto
	var old := {"schemaVersion": 1, "hero_level": 29, "current_region_id": "deep_dunes"}
	gs.apply_dict(old)
	_chk("save antigo → fase default 1/1/0/1", gs.stage_chapter == 1 and gs.stage_index == 1 and gs.stage_kills == 0 and gs.stage_highest_global == 1)
	_chk("save antigo → resto ainda carrega (level 29, deep_dunes)", gs.hero_level == 29 and gs.current_region_id == "deep_dunes")

	# restaura estado em memória + arquivo
	gs.apply_dict(mem)
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")

	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)
