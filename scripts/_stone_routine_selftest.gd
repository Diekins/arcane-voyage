extends SceneTree
## Self-test THE_STONE_BUILD_05 — a Testemunha ANDANTE ("a Ronda") na PEDRA: a VERTICALITY F4 (waypoint-stair) aplicada
## a CONTEÚDO REAL (não mais só o vlab). Constrói a SUBIDA real da Pedra (_build_stone_ascent), acha o NPC roteirizado
## e prova: começa no terraço (nv1) → DESCE a escada física → anda na trilha (nv0) → SOBE de volta; a interação
## same-level com o NPC EM MOVIMENTO; e o z CIENTE-DO-PAI (terraço=contêiner y_sort → z relativo 0; base=plano legado
## → z=int(y), senão a figura desenharia ATRÁS do chão). Main DESTACADO + snapshot/restore do save. Rodar:
##   godot --headless --path godot -s res://scripts/_stone_routine_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_sandbox", true)
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host)
	main.set("_services", []); main.set("_npcs", []); main.set("_portals", [])
	main.set("_chests", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_stair_zones", []); main.set("_floor_containers", {}); main.set("_routine_npcs", [])
	var player := Node2D.new()
	player.set_script(load("res://scripts/PlayerController.gd"))
	player.position = Vector2(1770, 600)
	root.add_child(player)
	main.set("_player", player)

	# Constrói a SUBIDA REAL da Pedra (mesmos parâmetros do _build_stone_arrival: foot_y=360, west=1600, east=2400)
	main._build_stone_ascent(360.0, 1600.0, 2400.0)

	# acha o NPC roteirizado "a Ronda" (há 4 Testemunhas estáticas como _services + esta como _routine_npcs)
	var rns: Array = main.get("_routine_npcs")
	var rn: Dictionary = {}
	for r in rns:
		if str((r["npcs"] as Dictionary).get("name", "")) == "a Ronda":
			rn = r; break
	var have_rn: bool = not rn.is_empty()
	print("  Testemunha andante 'a Ronda' registrada: %s  %s" % [str(have_rn), ("OK" if have_rn else "✗")])
	if not have_rn:
		print(">>> FALHOU"); quit(1); return
	var node: Node2D = rn["node"]

	# (1) começa no TERRAÇO (nível 1), z relativo (dentro do contêiner y_sort)
	var start1: bool = int(rn["floor_level"]) == 1
	var zterr_ok: bool = node.z_as_relative == true
	print("  (1) começa no terraço (nv1) + z relativo no contêiner: nv1=%s z_rel=%s  %s" % [str(start1), str(zterr_ok), ("OK" if (start1 and zterr_ok) else "✗")])
	if not (start1 and zterr_ok): ok = false

	# simula a rotina e captura a sequência: desce → trilha nv0 → sobe de volta
	var went_down := false; var base_wp := false; var z_legacy_ok := false
	var gate_down_npc := false; var gate_up_blocked := false
	var came_up := false; var terr_wp := false
	for k in range(2400):
		main._stair_npc_tick(0.1)
		var lvl := int(rn["floor_level"])
		var npos: Vector2 = node.position
		if lvl == 0: went_down = true
		if went_down and lvl == 0 and npos.distance_to(Vector2(1770, 292)) < 20.0 and not base_wp:
			base_wp = true
			# (z) no plano legado: z ABSOLUTO = int(y) (senão desenharia atrás do chão da trilha)
			z_legacy_ok = (node.z_as_relative == false) and (node.z_index == int(npos.y))
			# (interação) só same-level com o NPC EM MOVIMENTO na trilha: player na pos do NPC
			player.position = npos
			main.set("_floor_level", 0)
			var i0: Dictionary = main._nearest_interaction()
			main.set("_floor_level", 1)
			var i1: Dictionary = main._nearest_interaction()
			gate_down_npc = str(i0.get("kind", "")) == "npc" and str((i0.get("ref", {}) as Dictionary).get("name", "")) == "a Ronda"
			gate_up_blocked = str(i1.get("kind", "")) != "npc"
		if base_wp and lvl == 1: came_up = true
		if came_up and (node.position.distance_to(Vector2(1880, 142)) < 22.0 or node.position.distance_to(Vector2(1986, 140)) < 22.0):
			terr_wp = true

	# (2) desceu / (3) alcançou a trilha nv0 / (z) z legado correto
	print("  (2) DESCE a escada → nível 0: %s  %s" % [str(went_down), ("OK" if went_down else "✗")])
	if not went_down: ok = false
	print("  (3) alcança o waypoint da trilha (nv0): %s  %s" % [str(base_wp), ("OK" if base_wp else "✗")])
	if not base_wp: ok = false
	print("  (z) na BASE legada usa z=int(y) (não fica atrás do chão): %s  %s" % [str(z_legacy_ok), ("OK" if z_legacy_ok else "✗")])
	if not z_legacy_ok: ok = false
	# (4) interação same-level com o NPC em trânsito
	print("  (4) player nv0 FALA c/ 'a Ronda'; nv1 NÃO (NPC em trânsito): nv0=%s nv1-bloqueado=%s  %s" % [str(gate_down_npc), str(gate_up_blocked), ("OK" if (gate_down_npc and gate_up_blocked) else "✗")])
	if not (gate_down_npc and gate_up_blocked): ok = false
	# (5) subiu de volta / (6) voltou ao terraço
	print("  (5) SOBE de volta → nível 1: %s  %s" % [str(came_up), ("OK" if came_up else "✗")])
	if not came_up: ok = false
	print("  (6) retorna a um waypoint do terraço: %s  %s" % [str(terr_wp), ("OK" if terr_wp else "✗")])
	if not terr_wp: ok = false

	# (7) as 4 Testemunhas ESTÁTICAS + a Vigia seguem intactas (serviços nv1) — a andante não as quebra
	var svcs: Array = main.get("_services")
	var static_witnesses := 0
	for s in svcs:
		var sid := str((s as Dictionary).get("id", ""))
		if sid in ["stone_obs", "stone_rep", "stone_jov", "stone_sil", "stone_vigia"]:
			static_witnesses += 1
	var community_ok: bool = static_witnesses == 5
	print("  (7) comunidade estática intacta (4 Testemunhas + Vigia = 5 serviços): %d  %s" % [static_witnesses, ("OK" if community_ok else "✗")])
	if not community_ok: ok = false

	if player.get_parent() != null: player.get_parent().remove_child(player)
	player.free(); host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
