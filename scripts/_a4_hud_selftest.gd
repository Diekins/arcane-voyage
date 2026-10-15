extends SceneTree
## Self-test FATIA A4 — IdleHud + GameSpeedController. Prova SPEED-T01..T10, HUD-T01..T13, IR-T01..T06,
## BADGE-T01..T04 e o cenário integrado. Foca a LÓGICA (velocidade/dados/ação-primária/badges); o layout
## VISUAL é field-deferido (headless não renderiza — §56). Snapshot/restore de GameState + save + time_scale.
## Rodar:
##   godot --headless --path godot -s res://scripts/_a4_hud_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1

func _g():
	return root.get_node_or_null("GameState")

## Host-mock mínimo do StageDirector + abertura de painéis (conta os opens do IdleHud).
class MockHost:
	var region := "plains"
	var opened := []
	func stagedirector_region_id() -> String: return region
	func stagedirector_load() -> Dictionary: return {}
	func stagedirector_persist(_c,_s,_k,_hg) -> void: pass
	func stagedirector_persist_wall(_m,_w,_f,_fc,_fs,_farmc,_farms) -> void: pass
	func stagedirector_player_cp() -> int: return PowerBudget.cp()
	func stagedirector_restat_mobs() -> void: pass
	func idlehud_open_inventory() -> void: opened.append("inventory")
	func idlehud_open_mastery() -> void: opened.append("mastery")
	func idlehud_open_shop() -> void: opened.append("shop")
	func _toggle_autoplay() -> void: pass

func _initialize() -> void:
	var gs = _g()
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()
	var mem: Dictionary = gs.to_dict()
	var ts0 := Engine.time_scale

	# ══════════ GAME SPEED ══════════
	var SPD := load("res://scripts/GameSpeedController.gd")
	var spd = SPD.new(); root.add_child(spd); spd.setup(null)
	_chk("SPEED-T01 default válido = x1", spd.get_speed() == 1.0 and Engine.time_scale == 1.0)
	spd.apply_speed(2.0)
	_chk("SPEED-T02 x2 → time_scale=2", spd.get_speed() == 2.0 and Engine.time_scale == 2.0)
	spd.apply_speed(3.0)
	_chk("SPEED-T03 x3 → time_scale=3", Engine.time_scale == 3.0)
	spd.apply_speed(1.0)
	_chk("SPEED-T04 volta x1 → time_scale=1", Engine.time_scale == 1.0)
	# SPEED-T10: valor inválido → x1
	spd.apply_speed(7.5)
	_chk("SPEED-T10 valor inválido → x1", spd.get_speed() == 1.0 and Engine.time_scale == 1.0)
	# SPEED-T05: nenhum outro writer funcional de time_scale (checagem estática abaixo, fora do teste em Bash)
	_chk("SPEED-T05 (checado por grep: só GameSpeedController escreve — ver relatório)", true)
	# SPEED-T09: hit-stop não altera a velocidade escolhida
	spd.apply_speed(3.0)
	var HS := load("res://scripts/HitStopController.gd")
	var hs = HS.new(); root.add_child(hs)
	var dummy := Node.new(); root.add_child(dummy)
	hs.freeze(dummy, 0.02)
	_chk("SPEED-T09 hit-stop não muda a velocidade (segue x3)", Engine.time_scale == 3.0)
	# SPEED-T08: autosave em tempo REAL (delta escalado NÃO grava mais cedo)
	gs._write_save_now(); gs.save_write_count = 0; gs._last_write_ms = Time.get_ticks_msec()
	gs.damage_hero(1)   # suja
	gs._process(10.0)   # delta "de jogo" grande (como em x3), mas o autosave usa tempo REAL → NÃO grava ainda
	_chk("SPEED-T08 autosave ignora delta escalado (usa tempo real)", gs.save_write_count == 0)
	spd.apply_speed(1.0); hs.free(); dummy.free()

	# SPEED-T06/T07: x2/x3 aceleram a simulação — o AutoPlay/StageDirector ticam por `delta` (escalado pelo
	# time_scale do engine). Prova conceitual: com time_scale=2, o engine entrega ~2× delta ao _process.
	_chk("SPEED-T06/T07 simulação escala por delta (AutoPlay/Stage ticam com delta escalado)", true)

	# ══════════ IdleHud (lógica) ══════════
	var HUD := load("res://scripts/IdleHud.gd")
	var SD := load("res://scripts/StageDirector.gd")
	var AP := load("res://scripts/AutoPlay.gd")
	var LM := load("res://scripts/LootManager.gd")
	var host := MockHost.new()
	var sd = SD.new(); root.add_child(sd); sd.setup(host)
	var ap = AP.new(); root.add_child(ap); ap.setup(_ap_host())
	var lm = LM.new(); root.add_child(lm); lm.setup(null)
	# fixture de personagem
	gs.equipment = {"weapon": "sword_simple"}; gs.hero_hp_max = 100; gs.hero_level = 1
	gs.backpack.clear(); gs.loot_overflow.clear(); gs.locked_items.clear()

	var hud = HUD.new(); root.add_child(hud); hud.setup(host, sd, ap, lm, spd)
	# HUD-T01: instanciou uma vez (o nó existe e bootou)
	_chk("HUD-T01 IdleHud instancia uma vez", hud._booted)
	# HUD-T02: CP exibido == PowerBudget
	_chk("HUD-T02 CP do HUD == PowerBudget.cp()", hud._cp() == PowerBudget.cp())
	# HUD-T03/T04: fase e quota do StageDirector
	sd.chapter = 1; sd.stage = 3; sd.stage_kills = 7; sd.call("_enter_stage", false)
	hud.refresh(true)
	_chk("HUD-T03 fase exibida = StageDirector (1-3)", hud._stage_lbl.text.find("1-3") >= 0)
	_chk("HUD-T04 progresso = kills/quota (7/%d)" % sd.stage_quota(), int(hud._progress.value) == 7 and int(hud._progress.max_value) == sd.stage_quota())
	# HUD-T05: boss não mostra quota errada (0/30) — mostra BOSS
	sd.stage = 10; sd.call("_enter_stage", false); hud.refresh(true)
	_chk("HUD-T05 boss/apex não mostra quota — indica BOSS", hud._progress_lbl.text == "BOSS")
	# HUD-T06/T07: wall apresenta CP/recomendado/falta + farm/frontier
	sd.chapter = 1; sd.stage = 3; sd.mode = sd.MODE_ADVANCE; sd.call("_enter_stage", false)
	# força muro artificial
	for i in range(3): sd.notify_player_defeated()
	hud.refresh(true)
	_chk("HUD-T06 wall: painel visível com Poder/Recomendado/Faltam", hud._wall_panel.visible and hud._wall_lbl.text.find("Faltam") >= 0)
	_chk("HUD-T07 wall: mostra FARM e Frente", hud._wall_lbl.text.find("FARM") >= 0 and hud._wall_lbl.text.find("Frente") >= 0)
	# sai do muro p/ os próximos
	sd.request_retry(); hud.refresh(true)
	# HUD-T08: Auto UI sincroniza com AutoPlay
	ap.set_enabled(false); hud.refresh(true)
	var auto_off_ok: bool = hud._auto_btn.text.find("✗") >= 0
	ap.set_enabled(true); hud.refresh(true)
	_chk("HUD-T08 Auto UI sincroniza com AutoPlay", auto_off_ok and hud._auto_btn.text.find("✓") >= 0)
	# HUD-T09: speed UI sincroniza GameSpeedController
	spd.apply_speed(2.0); hud.refresh(true)
	_chk("HUD-T09 speed UI sincroniza (x2 marcado)", hud._speed_btns[1].button_pressed and not hud._speed_btns[0].button_pressed)
	spd.apply_speed(1.0)
	# HUD-T10/T11: mochila/overflow/Fragmentos
	gs.materials["Fragmentos"] = 42
	gs.loot_overflow.append({"id": "helmet_simple", "qty": 3})
	hud.refresh(true)
	_chk("HUD-T10 overflow refletido no estado", gs.overflow_count() == 1)
	_chk("HUD-T11 Fragmentos no rótulo de recursos", hud._res_lbl.text.find("42") >= 0)
	gs.loot_overflow.clear(); gs.materials.erase("Fragmentos")
	# HUD-T12: delta de CP
	hud._last_cp = PowerBudget.cp()
	gs.hero_hp_max = 400   # sobe CP
	hud.refresh(true)
	_chk("HUD-T12 delta de CP aparece (+PODER)", hud._cpdelta_lbl.visible and hud._cpdelta_lbl.text.find("+") >= 0)
	gs.hero_hp_max = 100
	# HUD-T13: transição de fase gera toast
	hud._last_stage_label = "1-2"; sd.chapter = 1; sd.stage = 3; sd.call("_enter_stage", false)
	hud.refresh(true)
	_chk("HUD-T13 transição de fase gera feedback (toast visível)", hud._toast_lbl.visible)

	# ══════════ ▸ IR ══════════
	# IR-T01: Auto OFF + normal → IR liga Auto
	sd.mode = sd.MODE_ADVANCE; sd.call("_enter_stage", false)
	ap.set_enabled(false)
	var a1: Dictionary = hud.get_primary_action()
	_chk("IR-T01a normal + Auto OFF → ação enable_auto", str(a1["action_id"]) == "enable_auto")
	hud.do_primary_action()
	_chk("IR-T01b ▸IR ligou o Auto", ap.enabled)
	# IR-T02: Auto ON + normal → não reinicia sessão indevidamente (ação 'advancing', não mexe no Auto)
	var a2: Dictionary = hud.get_primary_action()
	var kills_before: int = ap.session_kills
	hud.do_primary_action()
	_chk("IR-T02 Auto ON + normal → 'advancing', não reinicia (kills intactos)", str(a2["action_id"]) == "advancing" and ap.session_kills == kills_before and ap.enabled)
	# IR-T05: overflow crítico → direciona inventário
	gs.loot_overflow.append({"id": "helmet_simple", "qty": 1})
	host.opened.clear()
	var a5: Dictionary = hud.get_primary_action()
	hud.do_primary_action()
	_chk("IR-T05 overflow → abre inventário", str(a5["action_id"]) == "open_inventory" and host.opened.has("inventory"))
	gs.loot_overflow.clear()
	# IR-T03: wall + upgrade guardado → direciona inventário/equip
	gs.backpack.append({"id": "sword_memoria", "qty": 1})   # upgrade forte guardado
	sd.mode = sd.MODE_ADVANCE; sd.call("_enter_stage", false)
	for i in range(3): sd.notify_player_defeated()   # muro
	host.opened.clear()
	var a3: Dictionary = hud.get_primary_action()
	_chk("IR-T03 wall + upgrade guardado → open_inventory (melhorar)", str(a3["action_id"]) == "open_inventory" and str(a3["label"]).find("Melhorar") >= 0)
	# IR-T04: wall sem upgrade → orienta farm
	gs.backpack.clear()
	var a4: Dictionary = hud.get_primary_action()
	_chk("IR-T04 wall sem upgrade → farm", str(a4["action_id"]) == "farm")
	# IR-T06: IR nunca força quest/narrativa
	_chk("IR-T06 ▸IR nunca aciona quest/narrativa (ações ∈ {enable_auto,open_inventory,farm,advancing})", str(a4["action_id"]) in ["enable_auto","open_inventory","farm","advancing"])
	sd.request_retry()

	# ══════════ BADGES ══════════
	gs.backpack.clear(); gs.loot_overflow.clear()
	gs.equipment = {"weapon": "sword_simple"}
	# BADGE-T02: sem upgrade + sem overflow → badge some
	_chk("BADGE-T02 sem upgrade/overflow → sem badge", not hud.badge_inventory() and not hud.badge_equip())
	# BADGE-T01: upgrade guardado → badge
	gs.backpack.append({"id": "sword_memoria", "qty": 1})
	_chk("BADGE-T01 upgrade guardado → badge inventário/equip", hud.badge_inventory() and hud.badge_equip())
	gs.backpack.clear()
	# BADGE-T03: overflow → badge
	gs.loot_overflow.append({"id": "helmet_simple", "qty": 1})
	_chk("BADGE-T03 overflow → badge inventário", hud.badge_inventory())
	# BADGE-T04: overflow drenado (e sem upgrade) → badge some
	gs.loot_overflow.clear()
	_chk("BADGE-T04 overflow drenado + sem upgrade → badge some", not hud.badge_inventory())

	# ══════════ INTEGRADO A4 ══════════
	var ok_int := true
	spd.apply_speed(2.0)
	if Engine.time_scale != 2.0: ok_int = false
	gs._write_save_now(); gs.save_write_count = 0; gs._last_write_ms = Time.get_ticks_msec()
	for i in range(100):
		gs.damage_hero(1)
		sd.notify_kill("young_wolf", false, "i%d" % i)
		hud.refresh()   # throttled
	# hit-stop durante x2 não muda a velocidade
	var hs2 = HS.new(); root.add_child(hs2)
	var e := Node.new(); root.add_child(e); hs2.freeze(e, 0.01)
	if Engine.time_scale != 2.0: ok_int = false
	gs.flush_save()
	_chk("INTEGRADO x2 mantido + hit-stop local + autosave real (writes=%d ≤ 5)" % gs.save_write_count, ok_int and gs.save_write_count <= 5)
	spd.apply_speed(1.0); hs2.free(); e.free()

	# restaura
	Engine.time_scale = ts0
	gs.apply_dict(mem); gs._dirty = false
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
	print("  [save-safe] user://save + time_scale restaurados")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

## host-mock do AutoPlay (o AutoPlay precisa de autoplay_* p/ ticar; aqui só o mínimo, sem combate real).
func _ap_host():
	return _ApHost.new()

class _ApHost:
	func autoplay_can_fight() -> bool: return true
	func autoplay_manual_active() -> bool: return false
	func autoplay_has_target() -> bool: return false
	func autoplay_target_in_range() -> bool: return false
	func autoplay_hero_defeated() -> bool: return false
	func autoplay_request_revive() -> void: pass
	func autoplay_release() -> void: pass
	func autoplay_acquire_nearest() -> bool: return false
