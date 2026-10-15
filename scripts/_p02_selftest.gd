extends SceneTree
## Self-test do P0.2 (HUD quieto fora de combate). Main DESTACADO + snapshot/restore do user://save. Testa a
## LÓGICA de decisão (calma→atenua após o atraso; combate/dano/menu→restaura imediato) sem depender de tween/árvore
## (o fade visual é coberto no F5). Rodar:  godot --headless --path godot -s res://scripts/_p02_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	for m in ["_hud_explore_tick", "_set_hud_dim", "_hud_menu_open", "_hud_combat_active"]:
		var has_m: bool = main.has_method(m)
		print("  método %s: %s" % [m, ("OK" if has_m else "✗ AUSENTE")])
		if not has_m: ok = false

	# estado base: HUD presente, sem combate/menu/dano
	main.set("_hud_layer", CanvasLayer.new())
	main.set("_battle_panel", null)
	main.set("_auto_target", null)
	for f in ["_inv_open", "_shop_open", "_mastery_open", "_title_open"]:
		main.set(f, false)
	main.set("_hud_dmg_hold", 0.0)
	main.set("_hud_idle_t", 0.0)
	main.set("_hud_dimmed", false)
	var DELAY: float = main.get("HUD_DIM_DELAY")

	# 1) EXPLORAÇÃO CALMA acumula e ATENUA após o atraso
	main._hud_explore_tick(DELAY - 1.0, false)   # ainda abaixo do limiar
	var dim_before: bool = main.get("_hud_dimmed")
	main._hud_explore_tick(1.0, false)           # cruza o limiar
	var dim_after: bool = main.get("_hud_dimmed")
	var t1 := (not dim_before) and dim_after
	print("  [1] calma: antes=%s depois=%s  %s" % [str(dim_before), str(dim_after), ("OK" if t1 else "✗")])
	if not t1: ok = false

	# 2) MENU restaura imediato
	main.set("_inv_open", true)
	main._hud_explore_tick(0.1, false)
	var t2 := not bool(main.get("_hud_dimmed")) and float(main.get("_hud_idle_t")) == 0.0
	print("  [2] menu→restaura: dimmed=%s idle=%s  %s" % [str(main.get("_hud_dimmed")), str(main.get("_hud_idle_t")), ("OK" if t2 else "✗")])
	if not t2: ok = false
	main.set("_inv_open", false)

	# 3) COMBATE (inimigo próximo via painel de batalha visível) restaura imediato
	main.set("_hud_dimmed", true); main.set("_hud_idle_t", 99.0)
	var panel := Panel.new(); panel.visible = true
	main.set("_battle_panel", panel)
	main._hud_explore_tick(0.1, false)
	var t3 := not bool(main.get("_hud_dimmed"))
	print("  [3] combate→restaura: dimmed=%s  %s" % [str(main.get("_hud_dimmed")), ("OK" if t3 else "✗")])
	if not t3: ok = false
	main.set("_battle_panel", null)

	# 4) DANO mantém cheia (hold>0 = tático) e restaura imediato
	main.set("_hud_dimmed", true); main.set("_hud_idle_t", 99.0)
	main.set("_hud_dmg_hold", float(main.get("HUD_DMG_HOLD")))
	main._hud_explore_tick(0.1, false)
	var t4 := not bool(main.get("_hud_dimmed"))
	print("  [4] dano→restaura: dimmed=%s hold=%.2f  %s" % [str(main.get("_hud_dimmed")), float(main.get("_hud_dmg_hold")), ("OK" if t4 else "✗")])
	if not t4: ok = false

	# 5) atenua só PARCIAL (nunca some): 0 < alpha < 1
	var a: float = main.get("HUD_DIM_ALPHA")
	var t5 := a > 0.0 and a < 1.0
	print("  [5] HUD_DIM_ALPHA=%.2f (legível, não some)  %s" % [a, ("OK" if t5 else "✗")])
	if not t5: ok = false

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
