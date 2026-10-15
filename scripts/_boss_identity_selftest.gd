extends SceneTree
## Self-test BOSS_IDENTITY_PASS_01 — bosses como FRASES da linguagem. Verifica: (1) os 5 mob-bosses recebem `cycle`
## (sequência de formas) da tabela; (2) o Mob cicla as palavras a cada golpe (ancient_root_heart = line→cone→circle);
## (3) o Lobo Alfa alterna BOTE(line)→MORDIDA(cone) e o bote dispara o lunge; (4) o Golem esmaga em CONE (frente
## acerta, lado erra). Save-safe (snapshot/restore). Rodar:
##   godot --headless --path godot -s res://scripts/_boss_identity_selftest.gd

func _shapes_of(cycle: Array) -> Array:
	var out := []
	for b in cycle: out.append(str((b as Dictionary).get("shape", "?")))
	return out

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var player := Node2D.new(); player.set_script(load("res://scripts/PlayerController.gd")); root.add_child(player)

	# ── (1) os 5 mob-bosses recebem uma FRASE (cycle) com as palavras certas ──
	var boss_region := {"scrap_colossus": "swamp_pit", "root_matriarch": "deep_grove",
		"ancient_root_heart": "ancient_root_nest", "salt_split_warden": "salt_split_isle", "khet_sar_sentinel": "khet_sar_sands"}
	var expect := {"scrap_colossus": ["cone", "circle"], "root_matriarch": ["circle", "line"],
		"ancient_root_heart": ["line", "cone", "circle"], "salt_split_warden": ["cone", "circle"], "khet_sar_sentinel": ["cone", "line"]}
	var phrase_bad := []
	for bid in boss_region.keys():
		var cfg := {}
		for c in main._mob_configs(boss_region[bid]):
			if str(c.get("id", "")) == bid: cfg = c; break
		var m := Node2D.new(); m.set_script(load("res://scripts/Mob.gd"))
		main._apply_combat_language(m, cfg)
		var got := _shapes_of(m.get("telegraph_cycle"))
		if got != expect[bid]: phrase_bad.append("%s=%s" % [bid, str(got)])
		m.free()
	print("  (1) 5 mob-bosses com FRASE correta: %s  %s" % [("todos" if phrase_bad.is_empty() else str(phrase_bad)), ("OK" if phrase_bad.is_empty() else "✗")])
	if not phrase_bad.is_empty(): ok = false

	# ── (2) o Mob CICLA as palavras (ancient_root_heart: line → cone → circle → line) ──
	var hm := Node2D.new(); hm.set_script(load("res://scripts/Mob.gd")); hm.position = Vector2.ZERO
	root.add_child(hm)
	main._apply_combat_language(hm, {"id": "ancient_root_heart"})
	hm.set("_player", player)
	var seq := []
	for i in range(4):
		hm.call("_begin_windup", Vector2(0, 1) * 100.0)
		seq.append(str(hm.get("_cur_shape")))
	var cycle_ok: bool = seq == ["line", "cone", "circle", "line"]
	print("  (2) Mob cicla a frase (heart): %s  %s" % [str(seq), ("OK" if cycle_ok else "✗")])
	if not cycle_ok: ok = false

	# ── (3) Lobo Alfa: BOTE(line) → MORDIDA(cone); o bote dispara o lunge ──
	var w := Node2D.new(); w.set_script(load("res://scripts/Wolf.gd")); w.position = Vector2.ZERO
	root.add_child(w)
	w.set("_player", player); player.position = Vector2(0, 120)
	w.call("_begin_windup", Vector2(0, 120))
	var ws1 := str(w.get("_cur_shape"))
	w.call("_on_tele_fired")
	var lunged := bool(w.get("_lunging"))
	w.set("_lunging", false)
	w.call("_begin_windup", Vector2(0, 120))
	var ws2 := str(w.get("_cur_shape"))
	var wolf_ok: bool = ws1 == "line" and lunged and ws2 == "cone"
	print("  (3) Lobo Alfa frase: 1ª=%s (lunge=%s) 2ª=%s  %s" % [ws1, str(lunged), ws2, ("OK" if wolf_ok else "✗")])
	if not wolf_ok: ok = false

	# ── (4) Golem: ESMAGAMENTO em CONE (frente acerta, lado erra) ──
	var g := Node2D.new(); g.set_script(load("res://scripts/Golem.gd")); g.position = Vector2.ZERO
	root.add_child(g)
	g.set("_player", player); g.set("_aim_dir", Vector2(0, 1))   # mira travada p/ baixo
	var hits := [0]
	g.connect("attack_hero", func(_a): hits[0] += 1)
	player.position = Vector2(0, 120); g.call("_on_tele_fired")    # FRENTE → acerta
	var front_hit: bool = hits[0] == 1
	g.set("_recover_t", 0.0)
	player.position = Vector2(130, 0); g.set("_aim_dir", Vector2(0, 1)); g.call("_on_tele_fired")   # LADO → erra
	var side_miss: bool = hits[0] == 1
	var golem_ok: bool = front_hit and side_miss
	print("  (4) Golem ESMAGAMENTO cone: frente-acerta=%s lado-erra=%s  %s" % [str(front_hit), str(side_miss), ("OK" if golem_ok else "✗")])
	if not golem_ok: ok = false

	for n in [hm, w, g, player]:
		if n.get_parent() != null: n.get_parent().remove_child(n)
		n.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
