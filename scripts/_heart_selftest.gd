extends SceneTree
## Self-test HEART_OF_CRYSTAL_PROMOTION — o Coração de Cristal promovido a apex jogável. Verifica: (1) o Coração EXISTE
## como mob, é ENRAIZADO (speed baixa) e DOMINA (aggro grande), HP de ápice (o maior); (2) é RECORRENTE (respawn finito,
## não ~∞ de campanha nem trivial); (3) frase de boss line→cone→circle (a sentença completa, via MOB_COMBAT_LANGUAGE);
## (4) a ARENA: brecha aberta na barreira (Núcleo deixou de ser selado) + massas laterais de cobertura + colunas de
## cobertura DENTRO do Núcleo; (5) a descida SELADA às Fendas (marca cath_fendas) = a promessa do fundo; (6) handler de
## morte cosmético hookado (_on_coracao_defeated, sem save); (7) ANTI-CLIP do spawn do Coração + Entrada segura. Save-safe.
##   godot --headless --path godot -s res://scripts/_heart_selftest.gd

func _shapes_of(cycle: Array) -> Array:
	var out := []
	for b in cycle: out.append(str((b as Dictionary).get("shape", "?")))
	return out

func _initialize() -> void:
	seed(20260609)
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host); main.set("_services", []); main.set("_portals", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_mobs", []); main.set("_chests", [])
	main._build_cathedral_of_crystal(Vector2(2200, 1500))
	var blk: Array = main.get("_blockers_by_level").get(0, [])

	var heart := {}
	for c in main._mob_configs("cathedral_of_crystal"):
		if str(c.get("id", "")) == "coracao_de_cristal": heart = c

	# ── (1) existe + enraizado + domina + HP de ápice (o maior de todos os configs da Catedral) ──
	var maxhp := 0
	for c in main._mob_configs("cathedral_of_crystal"): maxhp = maxi(maxhp, int(c.get("hp", 0)))
	var ident_ok: bool = not heart.is_empty() and float(heart.get("speed", 999.0)) <= 12.0 \
		and float(heart.get("aggro", 0.0)) >= 600.0 and int(heart.get("hp", 0)) == maxhp and int(heart.get("hp", 0)) >= 1000
	print("  (1) existe + enraizado(speed=%s) + domina(aggro=%s) + ápice(hp=%d=max)  %s" % [str(heart.get("speed", "?")), str(heart.get("aggro", "?")), int(heart.get("hp", 0)), ("OK" if ident_ok else "✗")])
	if not ident_ok: ok = false

	# ── (2) RECORRENTE: respawn finito (volta), não ~∞ (campanha) nem trivial ──
	var rsp := float(heart.get("respawn", 0.0))
	var recur_ok: bool = rsp >= 30.0 and rsp <= 100000.0
	print("  (2) recorrente: respawn=%.0fs (30..100000 = volta sem ser instantâneo nem 1×/sessão)  %s" % [rsp, ("OK" if recur_ok else "✗")])
	if not recur_ok: ok = false

	# ── (3) frase de boss COMPLETA line→cone→circle ──
	var mm := Node2D.new(); mm.set_script(load("res://scripts/Mob.gd"))
	main._apply_combat_language(mm, heart); var phrase := _shapes_of(mm.get("telegraph_cycle")); mm.free()
	var phrase_ok: bool = phrase == ["line", "cone", "circle"]
	print("  (3) frase de boss=%s (LANÇA→SARAIVADA→FLORAÇÃO)  %s" % [str(phrase), ("OK" if phrase_ok else "✗")])
	if not phrase_ok: ok = false

	# ── (4) ARENA: brecha aberta + massas laterais de cobertura + colunas dentro do Núcleo ──
	var breach_open := true
	for r in blk:
		if (r as Rect2).has_point(Vector2(1100.0, 452.0)): breach_open = false
	var side := 0
	for r in blk:
		var rr := r as Rect2
		if rr.size.x >= 120.0 and rr.position.y >= 430.0 and rr.position.y <= 475.0: side += 1   # massas laterais da barreira
	var cover := 0
	for r in blk:
		var rr2 := r as Rect2
		var cy := rr2.position.y + rr2.size.y * 0.5
		if cy >= 300.0 and cy <= 430.0: cover += 1   # colunas de cobertura DENTRO da arena (entre o Coração e a brecha)
	var arena_ok: bool = breach_open and side >= 2 and cover >= 1
	print("  (4) arena: brecha aberta=%s massas laterais=%d colunas de cobertura=%d  %s" % [str(breach_open), side, cover, ("OK" if arena_ok else "✗")])
	if not arena_ok: ok = false

	# ── (5) a descida às Fendas atrás do Coração (portal → região fendas; o fundo agora DESCE de verdade) ──
	var fendas := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "fendas": fendas = true
	print("  (5) descida às Fendas atrás do Coração (portal→fendas)=%s  %s" % [str(fendas), ("OK" if fendas else "✗")])
	if not fendas: ok = false

	# ── (6) handler de morte cosmético hookado (recorrente, sem save) ──
	var hook_ok: bool = main.has_method("_on_coracao_defeated")
	print("  (6) handler de morte _on_coracao_defeated presente (cosmético/recorrente)=%s  %s" % [str(hook_ok), ("OK" if hook_ok else "✗")])
	if not hook_ok: ok = false

	# ── (7) ANTI-CLIP do Coração + Entrada segura ──
	var hp_sp: Vector2 = (heart["spawns"] as Array)[0]
	var clip := false
	for r in blk:
		if (r as Rect2).has_point(hp_sp): clip = true
	var spawn: Vector2 = main._region_spawn("cathedral_of_crystal")
	var folga := spawn.distance_to(hp_sp) - float(heart.get("aggro", 0.0))
	var safe_ok: bool = not clip and folga >= 60.0
	print("  (7) Coração anti-clip=%s + folga da entrada=%.0fpx  %s" % [str(not clip), folga, ("OK" if safe_ok else "✗")])
	if not safe_ok: ok = false

	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
