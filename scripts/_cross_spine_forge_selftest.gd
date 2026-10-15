extends SceneTree
## Self-test CROSS_SPINE_FORGE_F5 — as LIGAS entre espinhas (Lâmina Temperada na Memória + Malha de Ferro-Memória).
## Verifica (dados puros + loot tables — save-safe): (1) cada liga existe (item rare, upgrade modesto in-band); (2)
## cada receita mistura 1 assinatura da Caverna + 1 do Pântano + ouro; (3) materiais EXISTENTES (nada novo); (4) ★
## CROSS-SPINE de verdade: as assinaturas-Caverna (Fragmento de Cristal, Pó Luminescente) só caem na espinha-Caverna
## e a do Pântano (Limo de Ferro) só na espinha-Pântano → cada receita OBRIGA AS DUAS; (5) anti-exploit (custo >
## revenda = sink) em cada liga; (6) ambas na forja (RECIPE_ORDER); (7) não quebram a progressão. Save-safe. Rodar:
##   godot --headless --path godot -s res://scripts/_cross_spine_forge_selftest.gd

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

	# espinhas (p/ provar o cross-spine pela ORIGEM dos materiais)
	var main = load("res://scripts/Main.gd").new()
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host); main.set("_services", []); main.set("_portals", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_mobs", []); main.set("_chests", [])
	var crystal := _loot_of(main, ["cave", "cathedral_of_crystal", "veins"])   # espinha-Caverna
	var iron := _loot_of(main, ["iron_channels", "swamp"])                      # espinha-Pântano

	# as ligas (id, categoria, assinatura-Caverna, assinatura-Pântano)
	var ligas := [
		{"id": "sword_memoria", "cat": "weapon", "cris": "Fragmento de Cristal", "ferro": "Limo de Ferro"},
		{"id": "armor_memoria", "cat": "chest",  "cris": "Pó Luminescente",      "ferro": "Limo de Ferro"},
	]

	# maior atk/def reforçado (uncommon) por categoria, p/ o teste in-band
	var max_w := 0; var max_c := 0
	for iid in ItemDB.ITEMS:
		var it: Dictionary = ItemDB.ITEMS[iid]
		if str(it.get("rarity", "")) != "uncommon": continue
		if str(it.get("cat", "")) == "weapon": max_w = maxi(max_w, int(it.get("attack", 0)))
		if str(it.get("cat", "")) == "chest": max_c = maxi(max_c, int(it.get("defense", 0)))

	for L in ligas:
		var ID := str(L["id"])
		var item: Dictionary = ItemDB.ITEMS.get(ID, {})
		var rec: Dictionary = ItemDB.recipe(ID)
		var mats: Dictionary = rec.get("materials", {})
		var cris := str(L["cris"]); var ferro := str(L["ferro"])

		var exist_ok: bool = not item.is_empty() and str(item.get("rarity", "")) == "rare" and str(item.get("cat", "")) == str(L["cat"])
		var rec_ok: bool = mats.has(cris) and mats.has(ferro) and int(rec.get("gold", 0)) > 0
		var mat_exist: bool = ItemDB.MATERIAL_VALUE.has(cris) and ItemDB.MATERIAL_VALUE.has(ferro)
		var cross_ok: bool = crystal.has(cris) and not iron.has(cris) and iron.has(ferro) and not crystal.has(ferro)
		var mat_value := 0
		for m in mats: mat_value += ItemDB.material_value(str(m)) * int(mats[m])
		var sink_ok: bool = (mat_value + int(rec.get("gold", 0))) > ItemDB.sell_value(ID)
		var forge_ok: bool = ID in ItemDB.RECIPE_ORDER
		var band := 0
		if str(L["cat"]) == "weapon": band = int(item.get("attack", 0))
		else: band = int(item.get("defense", 0))
		var ref := max_w if str(L["cat"]) == "weapon" else max_c
		var band_ok: bool = band >= ref and band <= ref + 4

		var all_ok: bool = exist_ok and rec_ok and mat_exist and cross_ok and sink_ok and forge_ok and band_ok
		print("  %s: existe=%s receita(%s+%s+ouro)=%s mat-exist=%s CROSS-SPINE=%s sink=%s forja=%s in-band(%d/%d)=%s  %s" % [
			str(item.get("name", ID)), str(exist_ok), cris, ferro, str(rec_ok), str(mat_exist), str(cross_ok), str(sink_ok), str(forge_ok), band, ref, str(band_ok), ("OK" if all_ok else "✗")])
		if not all_ok: ok = false

	# resumo do cross-spine (as 3 assinaturas, claras)
	print("  [assinaturas] Caverna: Fragmento de Cristal=%s Pó Luminescente=%s · Pântano: Limo de Ferro=%s" % [
		str(crystal.has("Fragmento de Cristal") and not iron.has("Fragmento de Cristal")),
		str(crystal.has("Pó Luminescente") and not iron.has("Pó Luminescente")),
		str(iron.has("Limo de Ferro") and not crystal.has("Limo de Ferro"))])

	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
