extends SceneTree
## Self-test CONTRACT_POOL_EXPANSION_F5 — o mural passou a representar o mundo ATUAL. Verifica (dados + rotação, sem
## tocar save): (1) o pool repetível CRESCEU (3→≥10); (2) cobre as 4 CATEGORIAS (espinha/apex/raro/cross-spine) com
## alvos REUSADOS do mundo novo; (3) cobre as REGIÕES novas (Canais/Catedral/Pântano), não só o início; (4) a ROTAÇÃO
## superficie variedade (todo repetível aparece ao deslizar a janela — nada fica preso fora); (5) entradas novas bem-
## formadas; (6) ZERO sistema novo (BOUNTY_ROTATION_SIZE intacto = só ampliou o pool); (7) economia sã (rewards
## moderados). Save-safe. Rodar:  godot --headless --path godot -s res://scripts/_contract_pool_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var pool: Array = main._repeatable_bounty_pool()
	var B: Dictionary = main.BOUNTIES

	# helpers: targets e regiões do pool repetível
	var targets := {}; var mats := {}; var regions := {}
	for bid in pool:
		var b: Dictionary = B[bid]
		if b.has("target"): targets[str(b["target"])] = true
		if b.has("mat"): mats[str(b["mat"])] = true
		regions[str(b.get("region", ""))] = true

	# ── (1) o pool cresceu (3 → ≥10) ──
	var grew: bool = pool.size() >= 10
	print("  (1) pool repetível cresceu: %d alvos (≥10)  %s" % [pool.size(), ("OK" if grew else "✗")])
	if not grew: ok = false

	# ── (2) as 4 categorias (alvos REUSADOS do mundo novo) ──
	var apex: bool = targets.has("coracao_de_cristal") and targets.has("scrap_colossus")
	var raro: bool = targets.has("ferro_errante") and targets.has("besta_geodo")
	var espinha: bool = targets.has("iron_leech") and targets.has("living_shard")
	var xspine: bool = mats.has("Limo de Ferro")   # collect do OUTRO lado do mundo (travessia)
	var cats_ok: bool = apex and raro and espinha and xspine
	print("  (2) categorias: apex=%s raro=%s espinha=%s cross-spine=%s  %s" % [str(apex), str(raro), str(espinha), str(xspine), ("OK" if cats_ok else "✗")])
	if not cats_ok: ok = false

	# ── (3) cobre as REGIÕES novas (não só o início) ──
	var reg_ok: bool = regions.has("Os Canais de Ferro") and regions.has("A Catedral de Cristal") and regions.has("Pântano de Ferro")
	print("  (3) regiões novas no pool: Canais=%s Catedral=%s Pântano=%s  %s" % [str(regions.has("Os Canais de Ferro")), str(regions.has("A Catedral de Cristal")), str(regions.has("Pântano de Ferro")), ("OK" if reg_ok else "✗")])
	if not reg_ok: ok = false

	# ── (4) a ROTAÇÃO superficie TUDO (deslizando a janela por todo o pool, nada fica preso fora) ──
	var gs = root.get_node_or_null("GameState")
	var rot0 := int(gs.board_rotation)
	var surfaced := {}
	for r in range(pool.size()):
		gs.board_rotation = r
		for bid in main._board_visible_bounties():
			if pool.has(str(bid)): surfaced[str(bid)] = true
	gs.board_rotation = rot0   # restaura (em memória; sem save)
	var rot_ok: bool = surfaced.size() == pool.size()
	print("  (4) rotação superficie todos os %d repetíveis (nada preso fora): %d  %s" % [pool.size(), surfaced.size(), ("OK" if rot_ok else "✗")])
	if not rot_ok: ok = false

	# ── (5) entradas novas bem-formadas ──
	var news := ["bounty_canais_activity", "bounty_cathedral_stir", "bounty_apex_heart", "bounty_apex_colossus", "bounty_rare_errante", "bounty_rare_geodo", "bounty_xspine_iron"]
	var bad := []
	for bid in news:
		var b: Dictionary = B.get(bid, {})
		var well: bool = not b.is_empty() and bool(b.get("repeatable", false)) and int(b.get("need", 0)) >= 1 \
			and int(b.get("gold", 0)) > 0 and str(b.get("title", "")) != "" and str(b.get("region", "")) != "" and str(b.get("desc", "")) != "" \
			and (b.has("target") or b.has("mat"))
		if not well: bad.append(bid)
	print("  (5) %d entradas novas bem-formadas: %s  %s" % [news.size(), ("todas" if bad.is_empty() else str(bad)), ("OK" if bad.is_empty() else "✗")])
	if not bad.is_empty(): ok = false

	# ── (6) ZERO sistema novo: BOUNTY_ROTATION_SIZE intacto (só o pool cresceu) ──
	var sys_ok: bool = int(main.BOUNTY_ROTATION_SIZE) == 2
	print("  (6) sem sistema novo: BOUNTY_ROTATION_SIZE=%d (intacto)  %s" % [int(main.BOUNTY_ROTATION_SIZE), ("OK" if sys_ok else "✗")])
	if not sys_ok: ok = false

	# ── (7) economia sã: rewards moderados (apex ≤ 160; kill sem custo de material) ──
	var econ_ok := true
	for bid in news:
		var b: Dictionary = B[bid]
		if int(b.get("gold", 0)) > 160: econ_ok = false
	print("  (7) economia sã (rewards ≤ 160 ouro)=%s  %s" % [str(econ_ok), ("OK" if econ_ok else "✗")])
	if not econ_ok: ok = false

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
