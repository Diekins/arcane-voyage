extends SceneTree
## Self-test THE_STONE_BUILD_07 — o ritual "CARREGAR UM NOME" da Guardiã dos Nomes. Constrói a Pedra REAL
## (_build_stone_arrival), acha a Guardiã (stone_guard) e exercita a máquina de 3 estados (intro→repeat→done):
## dá UM nome curado, o jogador repete, ela RECUSA um segundo. Prova que NADA de sistema é criado (sem item/marcador/
## serviço novo/recompensa) — só muda meta no node + texto do prompt. Main DESTACADO + snapshot/restore do save. Rodar:
##   godot --headless --path godot -s res://scripts/_stone_ritual_selftest.gd

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
	main.set("_dialog", null)   # headless: _show_local_dialogue é no-op; as transições de estado ocorrem ANTES da fala

	main._build_stone_arrival(main._region_world_size("deep_dunes"))

	var svcs: Array = main.get("_services")
	var guard: Dictionary = {}
	for s in svcs:
		if str((s as Dictionary).get("id", "")) == "stone_guard": guard = s
	if guard.is_empty():
		print("  Guardiã (stone_guard) encontrada: false  ✗"); print(">>> FALHOU"); quit(1); return
	var node: Node2D = guard.get("node")
	var pr: Label = guard.get("prompt")

	# (1) estado inicial: sem ritual_state (intro) + prompt "[E] falar"
	var start_ok: bool = (not node.has_meta("av_ritual_state")) and pr != null and pr.text == "[E] falar"
	print("  (1) estado inicial intro + prompt '[E] falar': %s  %s" % [str(start_ok), ("OK" if start_ok else "✗")])
	if not start_ok: ok = false

	# snapshot do "mundo" ANTES do ritual (provar que NADA de sistema/conteúdo é criado)
	var n_svcs := svcs.size()
	var n_npcs := (main.get("_npcs") as Array).size()
	var n_chests := (main.get("_chests") as Array).size()
	var n_portals := (main.get("_portals") as Array).size()
	var n_bl := (main.get("_blockers") as Array).size()
	var gs = root.get_node_or_null("GameState")
	var gold0 = gs.get("gold") if gs != null else null
	var level0 = gs.get("level") if gs != null else null

	# (2) ENTREGA: 1ª interação → dá um nome de STONE_NAMES + estado "repeat" + prompt "[E] repetir «nome»"
	main._stone_carry_a_name(guard)
	var nm := str(node.get_meta("av_ritual_name")) if node.has_meta("av_ritual_name") else ""
	var names: Array = main.STONE_NAMES
	var give_ok: bool = str(node.get_meta("av_ritual_state")) == "repeat" and nm in names and pr.text == ("[E] repetir «%s»" % nm)
	print("  (2) ENTREGA: nome curado «%s» + estado repeat + prompt repetir: %s  %s" % [nm, str(give_ok), ("OK" if give_ok else "✗")])
	if not give_ok: ok = false

	# (3) PARTICIPAÇÃO: 2ª interação → repete → estado "done" + prompt muda; o nome carregado é o MESMO
	main._stone_carry_a_name(guard)
	var rep_ok: bool = str(node.get_meta("av_ritual_state")) == "done" and pr.text == "[E] a Guardiã dos Nomes" and str(node.get_meta("av_ritual_name")) == nm
	print("  (3) PARTICIPAÇÃO: repetiu → estado done + prompt muda + nome igual: %s  %s" % [str(rep_ok), ("OK" if rep_ok else "✗")])
	if not rep_ok: ok = false

	# (4) ENCERRAMENTO: 3ª interação → RECUSA um segundo (estado segue done, nome NÃO troca)
	main._stone_carry_a_name(guard)
	var refuse_ok: bool = str(node.get_meta("av_ritual_state")) == "done" and str(node.get_meta("av_ritual_name")) == nm
	print("  (4) ENCERRAMENTO: recusa 2º nome (done, nome inalterado): %s  %s" % [str(refuse_ok), ("OK" if refuse_ok else "✗")])
	if not refuse_ok: ok = false

	# (5) SEM sistema/recompensa escondida: nenhum serviço/npc/baú/portal/blocker novo; gold/level intactos
	var gold1 = gs.get("gold") if gs != null else null
	var level1 = gs.get("level") if gs != null else null
	var no_sys: bool = svcs.size() == n_svcs and (main.get("_npcs") as Array).size() == n_npcs \
		and (main.get("_chests") as Array).size() == n_chests and (main.get("_portals") as Array).size() == n_portals \
		and (main.get("_blockers") as Array).size() == n_bl and gold1 == gold0 and level1 == level0
	print("  (5) sem item/marcador/serviço novo + gold/level intactos: %s  %s" % [str(no_sys), ("OK" if no_sys else "✗")])
	if not no_sys: ok = false

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	host.free()
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
