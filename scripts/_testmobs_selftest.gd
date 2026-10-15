extends SceneTree
## Verifica os 2 monstros de teste (Musgo Voraz + Mage Of Heaven): parse de Main.gd, configs em plains, e
## que o ActorAnimator carrega as artes REAIS (mobs/musgo_voraz 3-dir 4-frames; mobs/mage_of_heaven 1-frame).
## Save-safe (snapshot/restore; não muta GameState). Rodar:
##   godot --headless --path godot -s res://scripts/_testmobs_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	# parse + configs
	var main = load("res://scripts/Main.gd").new()
	var cfgs: Array = main._mob_configs("plains")
	var ids := {}
	for c in cfgs: ids[str(c.get("id",""))] = c
	for want in ["musgo_voraz", "mage_of_heaven"]:
		var present: bool = ids.has(want)
		print("  config '%s' em plains: %s" % [want, ("OK" if present else "✗ AUSENTE")])
		if not present: ok = false

	# arte existe no disco
	for p in ["res://assets/actors/mobs/musgo_voraz.png", "res://assets/actors/mobs/musgo_voraz_side.png",
			  "res://assets/actors/mobs/musgo_voraz_up.png", "res://assets/actors/mobs/mage_of_heaven.png"]:
		var ex := ResourceLoader.exists(p)
		print("  asset %s: %s" % [p.get_file(), ("OK" if ex else "✗ FALTA")])
		if not ex: ok = false

	# ActorAnimator carrega as sheets reais (move + direções)
	var checks := {"mobs/musgo_voraz": 4, "mobs/mage_of_heaven": 1}
	for key in checks.keys():
		var host := Node2D.new(); root.add_child(host)
		var vis := Node2D.new(); host.add_child(vis)
		var a := ActorAnimator.new()
		a.setup(vis, key)
		var has: bool = a.has_spritesheet()
		var frames := 0
		var dirs := []
		if has and a._anim != null and a._anim.sprite_frames != null:
			frames = a._anim.sprite_frames.get_frame_count("move")
			if a._anim.sprite_frames.has_animation("move_side"): dirs.append("side")
			if a._anim.sprite_frames.has_animation("move_up"): dirs.append("up")
		print("  ActorAnimator '%s': sheet=%s frames(move)=%d dirs=%s" % [key, str(has), frames, str(dirs)])
		if not has: ok = false; print("    ✗ %s: sem spritesheet real" % key)
		if frames != int(checks[key]): ok = false; print("    ✗ %s: frames=%d (esperado %d)" % [key, frames, int(checks[key])])
		host.queue_free()

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
