extends SceneTree
## Self-test REGIONAL_GEAR_F5 — a 1ª peça HORIZONTAL (Gume de Cristal Frio). Prova que é uma ESCOLHA, não um upgrade
## disfarçado (save-safe): (1) existe (sword/rare); (2) SIDEGRADE genuíno vs a liga (sword_memoria): MESMO atk, mas
## nenhuma domina — o Gume tem +velocidade que a liga não tem, a liga tem +HP que o Gume não tem; (3) SEM números
## maiores (atk == o teto atual, não o ultrapassa); (4) mesma BANDA (rare); (5) REGIONAL de UMA terra (receita só de
## assinaturas da Catedral/cristal, NÃO cross-spine); (6) sink (custo > revenda); (7) na forja; (8) MECÂNICO — o
## trade-off é REAL: equipar aplica +24 vel e +14 atk (equip_sum), não é cosmético. Rodar:
##   godot --headless --path godot -s res://scripts/_regional_gear_selftest.gd

func _loot_of(main, regions: Array) -> Dictionary:
	var s := {}
	for rg in regions:
		for _i in range(3):
			for c in main._mob_configs(rg):
				for e in (c.get("loot", []) as Array):
					s[str((e as Dictionary).get("name", ""))] = true
	return s

func _initialize() -> void:
	seed(20260610)
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()
	var gs = root.get_node_or_null("GameState")
	var had_weapon: String = str(gs.equipment.get("weapon", ""))

	var ID := "sword_crystal"
	var it: Dictionary = ItemDB.ITEMS.get(ID, {})
	var liga: Dictionary = ItemDB.ITEMS.get("sword_memoria", {})   # a referência do mesmo patamar
	var rec: Dictionary = ItemDB.recipe(ID)

	# ── (1) existe ──
	var exist_ok: bool = not it.is_empty() and str(it.get("weapon_kind", "")) == "sword" and str(it.get("rarity", "")) == "rare"
	print("  (1) existe: %s (sword/rare)  %s" % [str(it.get("name", "?")), ("OK" if exist_ok else "✗")])
	if not exist_ok: ok = false

	# ── (2) SIDEGRADE genuíno vs a liga (nenhuma domina) ──
	var a_eq: bool = int(it.get("attack", 0)) == int(liga.get("attack", -1))
	var crys_faster: bool = int(it.get("speed", 0)) > int(liga.get("speed", 0))
	var liga_tougher: bool = int(it.get("max_hp", 0)) < int(liga.get("max_hp", 0))
	var side_ok: bool = a_eq and crys_faster and liga_tougher   # cada uma tem algo que a outra não tem → troca real
	print("  (2) sidegrade: atk igual=%s · Gume +vel (%d>%d)=%s · liga +HP (%d<%d)=%s  %s" % [str(a_eq), int(it.get("speed", 0)), int(liga.get("speed", 0)), str(crys_faster), int(it.get("max_hp", 0)), int(liga.get("max_hp", 0)), str(liga_tougher), ("OK" if side_ok else "✗")])
	if not side_ok: ok = false

	# ── (3) SEM números maiores (atk == o maior atk de arma que já existia; não eleva o teto) ──
	var max_atk := 0
	for iid in ItemDB.ITEMS:
		var w: Dictionary = ItemDB.ITEMS[iid]
		if iid == ID: continue
		if str(w.get("cat", "")) == "weapon": max_atk = maxi(max_atk, int(w.get("attack", 0)))
	var no_creep: bool = int(it.get("attack", 0)) <= max_atk
	print("  (3) sem número maior: atk=%d ≤ teto existente=%d  %s" % [int(it.get("attack", 0)), max_atk, ("OK" if no_creep else "✗")])
	if not no_creep: ok = false

	# ── (4) mesma BANDA (rare, como a liga) ──
	var band_ok: bool = str(it.get("rarity", "")) == str(liga.get("rarity", ""))
	print("  (4) mesma banda (rare): %s  %s" % [str(band_ok), ("OK" if band_ok else "✗")])
	if not band_ok: ok = false

	# ── (5) REGIONAL de UMA terra (receita só de assinaturas Catedral/cristal; NÃO cross-spine) ──
	var mats: Dictionary = rec.get("materials", {})
	var main = load("res://scripts/Main.gd").new()
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host); main.set("_services", []); main.set("_portals", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_mobs", []); main.set("_chests", [])
	var crystal := _loot_of(main, ["cave", "cathedral_of_crystal", "veins"])
	var iron := _loot_of(main, ["iron_channels", "swamp"])
	var all_crystal := true; var any_iron := false
	for m in mats:
		if not crystal.has(str(m)): all_crystal = false
		if iron.has(str(m)): any_iron = true   # se algum material também cai na espinha-ferro, não é "de uma terra só"
	var no_xspine: bool = not mats.has("Limo de Ferro")
	var regional_ok: bool = all_crystal and no_xspine and not any_iron
	print("  (5) regional (só cristal/Catedral, não cross-spine): %s  %s" % [str(mats.keys()), ("OK" if regional_ok else "✗")])
	if not regional_ok: ok = false

	# ── (6) sink (custo > revenda) ──
	var mat_value := 0
	for m in mats: mat_value += ItemDB.material_value(str(m)) * int(mats[m])
	var sink_ok: bool = (mat_value + int(rec.get("gold", 0))) > ItemDB.sell_value(ID)
	print("  (6) sink: custo=%d > revenda=%d  %s" % [mat_value + int(rec.get("gold", 0)), ItemDB.sell_value(ID), ("OK" if sink_ok else "✗")])
	if not sink_ok: ok = false

	# ── (7) na forja ──
	var forge_ok: bool = ID in ItemDB.RECIPE_ORDER
	print("  (7) na forja (RECIPE_ORDER): %s  %s" % [str(forge_ok), ("OK" if forge_ok else "✗")])
	if not forge_ok: ok = false

	# ── (8) MECÂNICO: o trade-off é REAL (equipar aplica +vel e +atk; não cosmético) ──
	gs.equipment["weapon"] = ID
	var spd: int = gs.equip_sum("speed"); var atk: int = gs.equip_sum("attack")
	var mech_ok: bool = spd >= 24 and atk >= 14
	print("  (8) mecânico: equipado → +vel %d (≥24) +atk %d (≥14)  %s" % [spd, atk, ("OK" if mech_ok else "✗")])
	if not mech_ok: ok = false

	# restaura a arma equipada real
	if had_weapon == "": gs.equipment.erase("weapon")
	else: gs.equipment["weapon"] = had_weapon
	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
