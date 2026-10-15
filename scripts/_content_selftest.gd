extends SceneTree
## Self-test READ-ONLY do CONTENT-1 (mobs+loot save-safe na macro). Main DESTACADO; NÃO instancia/muta o GameState
## real, NÃO simula kills (que gravariam). Cobre só o que é seguro em headless:
##  (1) GATE puro: _campaign_progress_locked() == _macro_mode (liga/desliga);
##  (2) SPAWN offset-aware: _build_mobs por zona posiciona mobs em coords GLOBAIS dentro da faixa da zona, z=0,
##      blockers GLOBAIS; (3) SUPRESSÃO: boss/mini-boss (MACRO_SUPPRESSED_MOBS) não spawnam na macro.
## Combate real (kills/XP/loot/“campanha não avança”) = validação manual do autor no F5 (com backup do save).
## Rodar:  godot --headless --path godot -s res://scripts/_content_selftest.gd

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()
	main.set("_suppress_internal_borders", true)

	# (1) GATE puro (GRADUATION-1: gate = _macro_sandbox, não mais _macro_mode)
	main.set("_macro_sandbox", true)
	var locked_on: bool = main._campaign_progress_locked()
	main.set("_macro_sandbox", false)
	var locked_off: bool = main._campaign_progress_locked()
	main.set("_macro_mode", true)
	main.set("_macro_sandbox", true)   # CONTENT-1 testa o comportamento SANDBOX (gate on, boss suprimido)
	print("  GATE: _macro_sandbox=true→locked=%s | false→locked=%s" % [str(locked_on), str(locked_off)])
	if not (locked_on and not locked_off):
		ok = false; print("  ✗ gate não reflete _macro_sandbox")

	# build FOREST (ground+props p/ popular blockers globais) + mobs offset-aware
	var macro := Node2D.new()
	macro.y_sort_enabled = true
	root.add_child(macro)
	var members := []
	for entry in main._macro_cluster_layout("forest"):
		var id: String = str(entry["id"])
		var off: Vector2 = entry["offset"]
		var sz: Vector2 = main._region_world_size(id)
		var zone := Node2D.new()
		zone.position = off
		zone.y_sort_enabled = true
		macro.add_child(zone)
		main.set("_region_node", zone)
		var blk_before: int = (main.get("_blockers") as Array).size()
		main._build_topdown_map(id, sz)
		main._dispatch_region_builder(id, sz)
		var blk: Array = main.get("_blockers")
		for i in range(blk_before, blk.size()):
			var r: Rect2 = blk[i]
			blk[i] = Rect2(r.position + off, r.size)
		members.append({"id": id, "off": off, "sz": sz})
	main.set("_region_node", macro)

	var global_blk: int = (main.get("_blockers") as Array).size()
	var all_ids := []
	var bad_pos := 0
	var bad_z := 0
	var bad_blk := 0
	var total := 0
	for m in members:
		var off: Vector2 = m["off"]
		var sz: Vector2 = m["sz"]
		main.set("_mob_build_offset", off)
		var before: int = (main.get("_mobs") as Array).size()
		main._build_mobs(str(m["id"]))
		var mobs: Array = main.get("_mobs")
		var n := mobs.size() - before
		total += n
		for i in range(before, mobs.size()):
			var mob = mobs[i]
			var gp: Vector2 = mob.position
			all_ids.append(str(mob.get("mob_id")))
			# posição GLOBAL dentro da faixa da zona (folga p/ spawns nas bordas)
			if gp.x < off.x - 60 or gp.x > off.x + sz.x + 60 or gp.y < off.y - 60 or gp.y > off.y + sz.y + 60:
				bad_pos += 1
			if int(mob.z_index) != 0:
				bad_z += 1
			if (mob.get("_blockers") as Array).size() != global_blk:
				bad_blk += 1
		print("  zona %s off=%s: %d mobs" % [m["id"], str(off), n])
	main.set("_mob_build_offset", Vector2.ZERO)

	print("  total mobs=%d | fora-da-faixa=%d | z!=0=%d | blockers!=global(%d)=%d" % [total, bad_pos, bad_z, global_blk, bad_blk])
	if total <= 0: ok = false; print("  ✗ nenhum mob spawnou")
	if bad_pos > 0: ok = false; print("  ✗ mobs fora da faixa global da zona")
	if bad_z > 0: ok = false; print("  ✗ mobs com z!=0 (quebra y-sort)")
	if bad_blk > 0: ok = false; print("  ✗ mobs sem blockers globais")

	# (3) SUPRESSÃO: nenhum boss/mini-boss de campanha entre os spawnados
	var leaked := []
	for sid in main.MACRO_SUPPRESSED_MOBS:
		if str(sid) in all_ids:
			leaked.append(str(sid))
	print("  supressão: ids spawnados=%d | vazaram boss/mini-boss=%s" % [all_ids.size(), str(leaked)])
	if not leaked.is_empty(): ok = false; print("  ✗ boss/mini-boss vazou na macro")

	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
