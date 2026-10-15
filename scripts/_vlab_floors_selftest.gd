extends SceneTree
## Self-test VERTICALITY FASE 2 — convivência vertical de entidades vivas/sistêmicas no `vlab`. Main DESTACADO +
## snapshot/restore do user://save + restauro de GameState.hero_hp. Prova os 8 critérios obrigatórios. Rodar:
##   godot --headless --path godot -s res://scripts/_vlab_floors_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()
	var GS = root.get_node_or_null("GameState")   # autoload via árvore (não é global de compile-time num script -s)
	if GS == null:
		print(">>> FALHOU (GameState autoload ausente)")
		quit(1); return
	var hp_save: int = int(GS.get("hero_hp"))
	var hpmax_save: int = int(GS.get("hero_hp_max"))

	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_sandbox", true)
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host)
	main.set("_services", []); main.set("_npcs", []); main.set("_portals", [])
	main.set("_chests", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_stair_zones", []); main.set("_floor_containers", {})
	var player := Node2D.new()
	player.set_script(load("res://scripts/PlayerController.gd"))
	player.position = Vector2(150, 620)
	root.add_child(player)
	main.set("_player", player)

	main._build_vlab(main._region_world_size("vlab"))

	# coleta atores
	var mobs: Array = main.get("_mobs")
	var mob0 = null
	var mob1 = null
	for m in mobs:
		if int(m.get("floor_level")) == 0: mob0 = m
		elif int(m.get("floor_level")) == 1: mob1 = m
	var have_mobs: bool = mob0 != null and mob1 != null
	print("  atores: mob nv0=%s mob nv1=%s  %s" % [str(mob0 != null), str(mob1 != null), ("OK" if have_mobs else "✗")])
	if not have_mobs: ok = false

	GS.set("hero_hp_max", 1000); GS.set("hero_hp", 1000)

	# (1) mob nv0 NÃO atinge player nv1
	main.set("_floor_level", 1); GS.set("hero_hp", 1000)
	main._on_enemy_attack(80, mob0)
	var c1ok: bool = int(GS.get("hero_hp")) == 1000
	print("  (1) mob nv0 NÃO atinge player nv1 (hp intacto): %s  %s" % [str(c1ok), ("OK" if c1ok else "✗")])
	if not c1ok: ok = false

	# (2) mob nv1 NÃO atinge player nv0
	main.set("_floor_level", 0); GS.set("hero_hp", 1000)
	main._on_enemy_attack(80, mob1)
	var c2ok: bool = int(GS.get("hero_hp")) == 1000
	print("  (2) mob nv1 NÃO atinge player nv0 (hp intacto): %s  %s" % [str(c2ok), ("OK" if c2ok else "✗")])
	if not c2ok: ok = false

	# (3) projétil não atravessa nível (o hit do MobProjectile re-emite attack_hero → MESMO chokepoint _on_enemy_attack)
	main.set("_floor_level", 1); GS.set("hero_hp", 1000)
	main._on_enemy_attack(80, mob0)   # projétil do mob nv0 chegando com player no nv1
	var c3ok: bool = int(GS.get("hero_hp")) == 1000
	print("  (3) projétil do nv0 NÃO fere player nv1: %s  %s" % [str(c3ok), ("OK" if c3ok else "✗")])
	if not c3ok: ok = false
	# CONTROLE: same-level FERE (prova que o gate não é "sempre bloqueia")
	main.set("_floor_level", 0); GS.set("hero_hp", 1000)
	main._on_enemy_attack(80, mob0)
	var ctrl: bool = int(GS.get("hero_hp")) < 1000
	print("  (controle) mob nv0 FERE player nv0 (hp caiu p/ %d): %s  %s" % [int(GS.get("hero_hp")), str(ctrl), ("OK" if ctrl else "✗")])
	if not ctrl: ok = false

	# detecção: mob só "vê" o Errante no mesmo andar
	player.set("floor_level", 0)
	var det0: bool = (not mob1._player_same_floor()) and mob0._player_same_floor()
	player.set("floor_level", 1)
	var det1: bool = mob1._player_same_floor() and (not mob0._player_same_floor())
	print("  detecção same-level (mob ignora outro andar): %s  %s" % [str(det0 and det1), ("OK" if (det0 and det1) else "✗")])
	if not (det0 and det1): ok = false

	# (4) NPC só interage same-level
	player.position = Vector2(900, 210)
	main.set("_floor_level", 1)
	var i_npc1: Dictionary = main._nearest_interaction()
	main.set("_floor_level", 0)
	var i_npc0: Dictionary = main._nearest_interaction()
	var c4ok: bool = str(i_npc1.get("kind", "")) == "npc" and str(i_npc0.get("kind", "")) != "npc"
	print("  (4) NPC só interage same-level (nv1=npc, nv0=não): %s  %s" % [str(c4ok), ("OK" if c4ok else "✗")])
	if not c4ok: ok = false

	# (5) trigger/(6) serviço só responde same-level — marco nv0 e marco nv1
	player.position = Vector2(700, 560)   # sobre o marco nv0
	main.set("_floor_level", 0)
	var s0_same: Dictionary = main._nearest_interaction()
	main.set("_floor_level", 1)
	var s0_cross: Dictionary = main._nearest_interaction()
	var c5ok: bool = str(s0_same.get("kind", "")) == "service" and str((s0_same.get("ref", {}) as Dictionary).get("id", "")) == "vlab_marker_0" and str(s0_cross.get("kind", "")) != "service"
	print("  (5) trigger/marco nv0 só same-level: %s  %s" % [str(c5ok), ("OK" if c5ok else "✗")])
	if not c5ok: ok = false

	player.position = Vector2(1050, 300)  # sobre o marco nv1
	main.set("_floor_level", 1)
	var s1_same: Dictionary = main._nearest_interaction()
	main.set("_floor_level", 0)
	var s1_cross: Dictionary = main._nearest_interaction()
	var c6ok: bool = str(s1_same.get("kind", "")) == "service" and str((s1_same.get("ref", {}) as Dictionary).get("id", "")) == "vlab_marker_1" and str(s1_cross.get("kind", "")) != "service"
	print("  (6) serviço/marco nv1 só same-level: %s  %s" % [str(c6ok), ("OK" if c6ok else "✗")])
	if not c6ok: ok = false

	# (7) default 0 = legado: entidade SEM "level" responde no nível 0
	main.set("_floor_level", 0)
	var c7ok: bool = main._on_floor({}) and not main._on_floor({"level": 1})
	print("  (7) default-0 legado (entidade sem 'level' = nível 0): %s  %s" % [str(c7ok), ("OK" if c7ok else "✗")])
	if not c7ok: ok = false

	# teardown imediato + restauro
	GS.set("hero_hp", hp_save); GS.set("hero_hp_max", hpmax_save)
	if player.get_parent() != null: player.get_parent().remove_child(player)
	player.free(); host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
