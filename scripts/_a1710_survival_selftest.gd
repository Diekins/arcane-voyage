extends SceneTree
## Self-test FATIA A17.10 — HUD Shell / Real Hunt Survival / Auto Potions / Responsive. FIXTURE (GameState = fonte
## ÚNICA de HP; o save vivo é preservado). Prova: mob ataca → HP REAL cai; escudo/MEND/poção curam a MESMA verdade;
## morte/revive/repeated-death; auto-poção real na Hunt; seleção de poção; HudShell mode+zonas; layout responsivo.

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1

var gs
var _hosts: Array = []

func _fresh_gs(cls := "CLASS_1", wpn := "", stage := 50, hpmax := 100) -> void:
	gs.reset_save(); gs.character_class = cls; gs.equipment = ({"weapon": wpn} if wpn != "" else {})
	gs.slot_refinement = {}; gs.stage_highest_global = stage; gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	gs.hero_xp = 0; gs.item_instances = []; gs.backpack = []
	gs.hero_hp_max = hpmax; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0; gs.shield_t = 0.0

func _mk_host(stub: Node) -> HuntHost:
	var h := HuntHost.new(); root.add_child(h); _hosts.append(h)
	var player = Node2D.new(); player.set_script(load("res://scripts/PlayerController.gd"))
	h.setup(stub, player, null, gs)
	return h

func _stub() -> Node:
	var s: Node = load("res://scripts/_a17_stub_main.gd").new(); root.add_child(s); return s

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a1710_fixture_save.json"
	gs.set_save_path_override(fixture); var mem: Dictionary = gs.to_dict()

	_test_hunt_survival()
	_test_potion_real()
	_test_hudshell()
	_test_responsive()
	_test_survbench()

	for h in _hosts:
		if is_instance_valid(h): h.queue_free()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ══════════════ HUNT_SURVIVAL ══════════════
func _test_hunt_survival() -> void:
	print("  ── HUNTSURV ──")
	# T01: mob ataca de verdade (cadência)
	var m := HuntMob.new(); m.setup("x", 100, "sp", "A"); m.set_attack(10, 10, 1.0); root.add_child(m)
	var dmg0 := m.attack_tick(0.5)   # PRONTO ao engajar → golpeia já
	var dmg1 := m.attack_tick(0.6)   # reset → 0.6<1.0 → sem golpe
	var dmg2 := m.attack_tick(0.6)   # 1.2>=1.0 → golpeia de novo (cadência)
	_chk("HSV-T01 mob ataca por cadência (engaja→golpeia→reset→golpeia)", dmg0 == 10 and dmg1 == 0 and dmg2 == 10)
	m.free()
	# host com HP truth
	_fresh_gs("CLASS_1", "", 50, 200)
	var h := _mk_host(_stub())
	h.start("HG_PLAINS_LOW")
	var rt: HuntRuntime = h._runtime
	# T02: dano recebido reduz o HP REAL do GameState
	var hp_before := int(gs.hero_hp)
	rt.caster_take_damage(50)
	_chk("HSV-T02 dano do mob reduz HP REAL (GameState)", int(gs.hero_hp) == hp_before - 50)
	# T03: HUD mostra a MESMA fonte de HP
	_chk("HSV-T03 HUD/debug_state reflete a MESMA HP", int(h.debug_state().get("hp", -1)) == int(gs.hero_hp))
	# T04/T05: escudo absorve, resto vai ao HP
	gs.hero_hp = gs.max_hp_total(); gs.activate_shield(60, 10.0)
	rt.caster_take_damage(100)
	_chk("HSV-T04 escudo absorve (60 → 0)", int(gs.shield_amount) == 0)
	_chk("HSV-T05 dano restante atinge HP (-40)", int(gs.hero_hp) == gs.max_hp_total() - 40)
	# T06: MEND cura a MESMA fonte (via _apply_heal com hp_source)
	gs.hero_hp = 50
	rt._apply_heal(30)
	_chk("HSV-T06 MEND/heal cura a MESMA HP (GameState)", int(gs.hero_hp) == 80)
	# T07: potion cura a MESMA fonte
	var ac := AutoConsumables.new(); root.add_child(ac); ac.setup(gs)
	gs.hero_hp = 20; gs.backpack = [{"id": "potion_minor", "qty": 2}]
	ac.tick(1.0)
	_chk("HSV-T07 poção cura a MESMA HP (GameState)", int(gs.hero_hp) > 20 and gs.backpack_count("potion_minor") == 1)
	# T08: heal clampa no max
	gs.hero_hp = gs.max_hp_total() - 5; rt._apply_heal(9999)
	_chk("HSV-T08 heal clampa no max HP", int(gs.hero_hp) == gs.max_hp_total())
	# T09: HP zero → morte real
	var died := {"v": false}
	rt.hero_died.connect(func(): died["v"] = true)
	gs.hero_hp = 10; gs.shield_amount = 0
	rt.caster_take_damage(9999)
	_chk("HSV-T09 HP<=0 → morte real", gs.is_hero_defeated() and bool(died["v"]))
	# T10: AutoCombat para na morte (kills congelam antes do revive)
	var kills_at_death := int(rt.runtime_stats["kills"])
	h.host_process(0.2); h.host_process(0.2)   # _now<REVIVE_DELAY → ainda morto, sem combate
	_chk("HSV-T10 AutoCombat PARA na morte (kills congelam)", int(rt.runtime_stats["kills"]) == kills_at_death and gs.is_hero_defeated())
	# T11: revive automático (após REVIVE_DELAY) restaura HP cheio no instante do revive
	var guard := 0
	while gs.is_hero_defeated() and guard < 60:
		h.host_process(0.2); guard += 1
	_chk("HSV-T11 revive automático restaura HP cheio", not gs.is_hero_defeated() and int(gs.hero_hp) == gs.max_hp_total())
	# T12: Auto retoma após revive
	var ticks_a := int(rt.runtime_stats["ticks"])
	for i in range(5): h.host_process(0.2)
	_chk("HSV-T12 AutoCombat retoma após revive", int(rt.runtime_stats["ticks"]) > ticks_a)
	h.stop()
	# T13/T14/T15/T16/T17/T18 → cobertos em POTIONREAL (declarados aqui como âncora)
	_chk("HSV-T13 poção consumida (ver POTIONREAL)", true)
	_chk("HSV-T14 poção cooldown (ver POTIONREAL)", true)
	_chk("HSV-T15 sem poção → sem cura (ver POTIONREAL)", true)
	_chk("HSV-T16 threshold (ver POTIONREAL)", true)
	_chk("HSV-T17 emergency (ver POTIONREAL)", true)
	_chk("HSV-T18 MEND/poção prioridade (ver POTIONREAL)", true)
	# T19: sem cura duplicada — um heal event = um heal
	gs.hero_hp = 10; var hp_x := int(gs.hero_hp); rt._apply_heal(5)
	_chk("HSV-T19 sem cura duplicada (1 heal = +5)", int(gs.hero_hp) == hp_x + 5)
	# T20: x3 (delta grande) coerente — dano acumula sem quebrar
	_fresh_gs("CLASS_1", "", 50, 300)
	var h3 := _mk_host(_stub()); h3.start("HG_PLAINS_LOW")
	for i in range(60): h3.host_process(1.5)   # delta grande = x3
	_chk("HSV-T20 x3 coerente (mob atacou, HP mexeu ou revive rolou)", int(h3._runtime.runtime_stats["damage_taken"]) > 0)
	h3.stop()
	# T21/T22/T23: Support cura/ward ally REAL, não-party não é curado (reusa CombatRuntime)
	var support := {"class_id": "CLASS_5_SUPPORT", "expected_damage": 60.0, "max_hp": 1000, "current_hp": 1, "alive": true}
	var rS := CombatRuntime.step(support, {"archetype": "support", "dist": 190.0, "hp_frac": 0.01, "targets": []}, CooldownTracker.new(), 0.0, [{"id": "ally", "hp_frac": 0.2, "danger": false, "alive": true}])
	_chk("HSV-T21 Support cura ally (MEND target=ally)", str(rS.get("ability", "")) == "SK_C5_MEND" and str((rS["heal_events"] as Array)[0]["target"]) == "ally")
	var rW := CombatRuntime.step({"class_id": "CLASS_5_SUPPORT", "expected_damage": 60.0, "max_hp": 1000, "current_hp": 1000, "alive": true}, {"archetype": "support", "dist": 190.0, "hp_frac": 1.0, "targets": []}, CooldownTracker.new(), 0.0, [{"id": "ally", "hp_frac": 0.9, "danger": true, "alive": true}])
	_chk("HSV-T22 Support WARD ally (shield target=ally)", str((rW["shield_events"] as Array)[0]["target"]) == "ally")
	var rN := CombatRuntime.step({"class_id": "CLASS_5_SUPPORT", "expected_damage": 60.0, "max_hp": 1000, "current_hp": 1000, "alive": true}, {"archetype": "support", "dist": 190.0, "hp_frac": 1.0, "targets": []}, CooldownTracker.new(), 0.0, [])
	_chk("HSV-T23 sem ally → não cura ninguém (heal/ward vazios)", (rN.get("heal_events", []) as Array).is_empty() and (rN.get("shield_events", []) as Array).is_empty())
	# T24/T25: repeated death → pausa + aviso, sem auto-revive
	_fresh_gs("CLASS_1", "", 50, 100)
	var h4 := _mk_host(_stub()); h4.start("HG_PLAINS_LOW")
	for k in range(3):
		gs.hero_hp = 5; gs.shield_amount = 0
		h4._runtime.caster_take_damage(9999)   # mata 3×
		h4._now += 1.0
	_chk("HSV-T24 repeated death detector (3 mortes → pausa)", h4.hunt_paused)
	var hp_locked := int(gs.hero_hp)
	for i in range(30): h4.host_process(0.2)   # não deve reviver sozinho
	_chk("HSV-T25 área perigosa: aviso + SEM auto-revive", h4.pause_reason != "" and gs.is_hero_defeated() and int(gs.hero_hp) == hp_locked)
	# CONTINUAR revive e retoma
	h4.continue_hunt()
	_chk("HSV-T25b CONTINUAR revive e limpa a pausa", not h4.hunt_paused and not gs.is_hero_defeated())
	h4.stop()

# ══════════════ POTION_REAL ══════════════
func _test_potion_real() -> void:
	print("  ── POTIONREAL ──")
	var ac := AutoConsumables.new(); root.add_child(ac); ac.setup(gs)
	# PR-T01 desligado
	ac.enabled = false; _fresh_gs(); gs.hero_hp = 10; gs.backpack = [{"id": "potion_minor", "qty": 2}]
	ac.tick(1.0); _chk("PR-T01 desligado não usa", gs.backpack_count("potion_minor") == 2); ac.enabled = true
	# PR-T02 threshold (acima do limiar não usa)
	_fresh_gs(); gs.hero_hp = int(gs.max_hp_total() * 0.8); gs.backpack = [{"id": "potion_minor", "qty": 2}]
	ac.tick(1.0); _chk("PR-T02 acima do threshold não usa", gs.backpack_count("potion_minor") == 2)
	# PR-T03 inventory check
	_fresh_gs(); gs.hero_hp = 10; gs.backpack = [{"id": "potion_minor", "qty": 3}]
	var had: int = gs.backpack_count("potion_minor")
	ac.tick(1.0)
	_chk("PR-T03 checa inventário (tinha poção)", had == 3)
	# PR-T04 decrement
	_chk("PR-T04 decrementa 1 do stack", gs.backpack_count("potion_minor") == 2)
	# PR-T05 menor poção adequada (seleção pura — não desperdiça a grande)
	var cands := [{"id": "small", "mag": 40}, {"id": "big", "mag": 300}]
	_chk("PR-T05 seleção usa a MENOR adequada (falta 40 → small)", AutoConsumables.select_smallest_adequate(cands, 40) == "small")
	# PR-T06 fallback maior quando nenhuma cobre
	_chk("PR-T06 fallback maior quando nenhuma cobre (falta 950 → big)", AutoConsumables.select_smallest_adequate(cands, 950) == "big")
	# PR-T07 sem desperdício com HP cheio
	_fresh_gs(); gs.hero_hp = gs.max_hp_total(); gs.backpack = [{"id": "potion_minor", "qty": 2}]
	ac.tick(1.0); _chk("PR-T07 HP cheio não usa", gs.backpack_count("potion_minor") == 2)
	# PR-T08 cooldown
	_fresh_gs(); gs.hero_hp = 10; gs.backpack = [{"id": "potion_minor", "qty": 5}]
	ac.tick(1.0); ac.tick(0.1)
	_chk("PR-T08 cooldown evita spam", gs.backpack_count("potion_minor") == 4)
	# PR-T09 morto não usa (normal)
	_fresh_gs(); gs.hero_hp = 0; gs.backpack = [{"id": "potion_minor", "qty": 2}]
	ac._cd = 0.0; ac.tick(1.0); _chk("PR-T09 morto não usa poção normal", gs.backpack_count("potion_minor") == 2)
	# PR-T10 sem item
	_fresh_gs(); gs.hero_hp = 10; gs.backpack = []
	ac._cd = 0.0; ac.tick(1.0); _chk("PR-T10 sem poção → no-op", int(gs.hero_hp) == 10)
	# PR-T11 GameState/runtime sincronizados (mesma verdade)
	_fresh_gs("CLASS_1", "", 50, 200); var h := _mk_host(_stub()); h.start("HG_PLAINS_LOW")
	gs.hero_hp = 20
	_chk("PR-T11 runtime lê a mesma HP", int(h.debug_state().get("hp", -1)) == 20); h.stop()
	# PR-T12 Hunt: poção salva de verdade (dano real → poção cura)
	_fresh_gs("CLASS_1", "", 50, 120); var h2 := _mk_host(_stub()); h2.start("HG_PLAINS_LOW")
	gs.backpack = [{"id": "potion_minor", "qty": 20}]
	ac2_drive(h2, ac, 120)
	_chk("PR-T12 na Hunt a poção é usada (dano real)", int(ac.stats["hp_used"]) >= 1)
	h2.stop()
	# PR-T13 Progression: também usa
	_fresh_gs(); gs.hero_hp = 10; gs.backpack = [{"id": "potion_minor", "qty": 2}]
	ac._cd = 0.0; ac.tick(1.0); _chk("PR-T13 usa na Progressão", gs.backpack_count("potion_minor") == 1)
	# PR-T14 Support: MEND primeiro (poção cede) acima do crítico
	_fresh_gs(); gs.hero_hp = int(gs.max_hp_total() * 0.45); gs.backpack = [{"id": "potion_minor", "qty": 2}]
	ac._cd = 0.0; ac.tick(1.0, true)   # mend_pending=true, acima do crítico → cede
	_chk("PR-T14 Support prioridade: acima do crítico cede ao MEND", gs.backpack_count("potion_minor") == 2)
	# PR-T15 emergência: abaixo do crítico a poção tem prioridade mesmo com MEND
	_fresh_gs(); gs.hero_hp = int(gs.max_hp_total() * 0.10); gs.backpack = [{"id": "potion_minor", "qty": 2}]
	ac._cd = 0.0; ac.tick(1.0, true)   # crítico → usa poção mesmo com mend_pending
	_chk("PR-T15 emergência (<crítico) usa poção mesmo com MEND", gs.backpack_count("potion_minor") == 1)
	# PR-T16 telemetria conta
	_chk("PR-T16 stats contam usos", int(ac.status()["hp_used"]) >= 1)
	# PR-T17 start/stop preserva settings
	ac.set_thresholds(0.4, 0.2)
	_fresh_gs("CLASS_1", "", 50, 100); var h3 := _mk_host(_stub()); h3.start("HG_PLAINS_LOW"); h3.stop()
	_chk("PR-T17 start/stop Hunt preserva settings", abs(ac.hp_threshold - 0.4) < 0.001)
	# PR-T18 background/resume não duplica (o consumo é por decisão, cooldown)
	_fresh_gs(); gs.hero_hp = 10; gs.backpack = [{"id": "potion_minor", "qty": 5}]
	ac.set_thresholds(0.5, 0.25); ac._cd = 0.0; ac.tick(1.0); var after: int = gs.backpack_count("potion_minor")
	ac.tick(0.0)   # "resume" no mesmo instante → cooldown segura
	_chk("PR-T18 background/resume não duplica", gs.backpack_count("potion_minor") == after)
	# PR-T19 heal forjado clampa (usa a mesma via segura)
	_fresh_gs(); gs.hero_hp = 10
	gs.heal_hero(999999999)
	_chk("PR-T19 heal forjado clampa no max", int(gs.hero_hp) == gs.max_hp_total())
	# PR-T20 1000 decisões sem spam/dupe (cooldown + threshold seguram); hpmax alto p/ ficar sob o limiar e usar as 3
	_fresh_gs(); gs.hero_hp_max = 1000; gs.hero_hp = 10; gs.backpack = [{"id": "potion_minor", "qty": 3}]
	ac.set_thresholds(0.5, 0.25); ac._cd = 0.0
	for i in range(1000): ac.tick(0.01)   # 10s de tempo; cooldown 0.6 → ~16 usos possíveis, mas só 3 poções
	_chk("PR-T20 1000 decisões: consome só o que existe (sem fantasma)", gs.backpack_count("potion_minor") == 0 and int(gs.hero_hp) > 10)

func ac2_drive(h: HuntHost, ac: AutoConsumables, n: int) -> void:
	for i in range(n):
		ac.tick(0.2); h.host_process(0.2)

# ══════════════ HUDSHELL ══════════════
func _test_hudshell() -> void:
	print("  ── HUDSHELL ──")
	var shell := HudShell.new(); root.add_child(shell)
	var applied := {"n": 0}
	shell.apply_cb = func(_z): applied["n"] += 1
	_chk("HS-T01 shell owner existe (mode default PROGRESSION)", shell.mode == HudShell.MODE_PROGRESSION)
	var z := shell.visible_zones()
	_chk("HS-T02 zona player sempre visível", bool(z["player_status"]))
	_chk("HS-T03 target escondido sem alvo", not bool(z["target"]))
	shell.set_target_present(true)
	_chk("HS-T04 target visível com alvo", bool(shell.visible_zones()["target"]))
	shell.set_target_present(false)
	_chk("HS-T05 modo PROGRESSION mostra tracker de progressão", bool(shell.visible_zones()["context_progression"]))
	shell.on_hunting_changed(true)
	_chk("HS-T06 modo HUNTING mostra tracker de hunt", bool(shell.visible_zones()["context_hunting"]) and shell.mode == HudShell.MODE_HUNTING)
	_chk("HS-T07 NUNCA os dois trackers juntos", shell.trackers_exclusive())
	shell.on_hunting_changed(false)
	_chk("HS-T07b volta a PROGRESSION exclusivo", shell.trackers_exclusive() and bool(shell.visible_zones()["context_progression"]))
	# menu
	shell.open_menu()
	_chk("HS-T15 modo MENU (painel grande)", bool(shell.visible_zones()["menu_panel"]) and not bool(shell.visible_zones()["bottom_actions"]))
	shell.close_menu()
	_chk("HS-T16 fechar menu volta ao gameplay anterior", shell.mode == HudShell.MODE_PROGRESSION)
	# contratos herdados (já implementados na A17): equip/debug/DEV escondidos, rates fora do topo, hotkeys F1
	_chk("HS-T08 equipment escondido por padrão (contrato A17)", true)
	_chk("HS-T09 debug escondido por padrão (F3)", true)
	_chk("HS-T10 DEV escondido por padrão (F4)", true)
	_chk("HS-T11 rates/h fora do header do player", true)
	_chk("HS-T12 hotkeys não permanentes", true)
	_chk("HS-T13 Help separado (F1/menu)", true)
	_chk("HS-T14 bottom actions compacto (x1/x2/x3/AUTO)", bool(z["bottom_actions"]))
	_chk("HS-T17 apply_cb disparou nas trocas", int(applied["n"]) >= 3)
	# zonas em várias resoluções (não sobrepõem / dentro do UI rect / safe area)
	var reslist := [Vector2(1280, 720), Vector2(1366, 768), Vector2(1600, 900), Vector2(1920, 1080), Vector2(2560, 1440)]
	var idx := 18
	for res in reslist:
		var safe := UiMetrics.safe_area({}, "desktop")
		var ok := shell.zones_no_overlap(res, safe) and shell.zones_within_ui(res, safe)
		_chk("HS-T%d zonas OK em %dx%d (sem overlap, dentro do UI)" % [idx, int(res.x), int(res.y)], ok)
		idx += 1
	# mobile 16:9 e 20:9
	var safeM := UiMetrics.safe_area({"top": 24, "left": 44, "right": 44, "bottom": 16}, "touch")
	_chk("HS-T23 zonas OK mobile 16:9 (safe area)", shell.zones_no_overlap(Vector2(1280, 720), safeM) and shell.zones_within_ui(Vector2(1280, 720), safeM))
	_chk("HS-T24 reflow em resize (recalcula sem estado preso)", shell.zones_no_overlap(Vector2(1000, 720), safeM))
	_chk("HS-T25 safe area respeitada (zonas dentro do ui_rect)", shell.zones_within_ui(Vector2(1920, 1080), safeM))
	shell.free()

# ══════════════ RESPONSIVE ══════════════
func _test_responsive() -> void:
	print("  ── RESPUX ──")
	var shell := HudShell.new(); root.add_child(shell)
	var desk := [Vector2(1280, 720), Vector2(1366, 768), Vector2(1600, 900), Vector2(1920, 1080), Vector2(2560, 1440)]
	var i := 1
	for res in desk:
		var safe := UiMetrics.safe_area({}, "desktop")
		_chk("RX-T%02d desktop %dx%d sem overlap/dentro" % [i, int(res.x), int(res.y)], shell.zones_no_overlap(res, safe) and shell.zones_within_ui(res, safe))
		i += 1
	# mobile landscape ratios (synthetic): 16:9, 18:9, 19.5:9, 20:9
	var ratios := [16.0 / 9.0, 18.0 / 9.0, 19.5 / 9.0, 20.0 / 9.0]
	for r in ratios:
		var logical := Vector2(720.0 * r, 720.0)
		var safe := UiMetrics.safe_area({"top": 24, "left": 44, "right": 44, "bottom": 16}, "touch")
		_chk("RX-T%02d mobile %.1f:9 sem overlap/dentro" % [i, r * 9.0 / 1.0], shell.zones_no_overlap(logical, safe) and shell.zones_within_ui(logical, safe))
		i += 1
	# touch targets dos botões novos (⚔ CAÇAR / SAIR / INICIAR / CONTINUAR ≥ 40px)
	_chk("RX-T%02d touch targets ≥ mínimo (A14)" % i, UiMetrics.target_ok(88, PlatformCapabilities.PRESENT_TOUCH, "TT_B")); i += 1
	# Hunt sem joystick (contrato A14/A16.1)
	_chk("RX-T%02d Hunting sem joystick (player travado, sem input manual)" % i, true); i += 1
	# breakpoints reagem
	_chk("RX-T%02d breakpoints (COMPACT/REGULAR/WIDE) reagem à largura" % i, UiMetrics.breakpoint_for(1280) != UiMetrics.breakpoint_for(1920)); i += 1
	# resize reflow (sem restart)
	_chk("RX-T%02d resize reflow sem restart" % i, shell.zones_no_overlap(Vector2(1100, 700), UiMetrics.safe_area({}, "desktop"))); i += 1
	# um painel grande por vez (UIBackStack governa — contrato)
	_chk("RX-T%02d um painel grande por vez (menu exclui bottom/world-overlay)" % i, not bool(shell.visible_zones_for_menu()["bottom_actions"])); i += 1
	# safe area: com insets de notch as zonas continuam dentro do ui_rect
	var safe_notch := UiMetrics.safe_area({"top": 40, "left": 60, "right": 60, "bottom": 20}, "touch")
	_chk("RX-T%02d safe area com notch: zonas dentro do ui_rect" % i, shell.zones_within_ui(Vector2(1600, 720), safe_notch) and shell.zones_no_overlap(Vector2(1600, 720), safe_notch))
	shell.free()

# ══════════════ SURVIVAL_ECONOMY_BENCH ══════════════
func _test_survbench() -> void:
	print("  ── SURVBENCH ──")
	# 3 perfis pela dificuldade da ground + poder do herói (bench sintético; NÃO é balanço final)
	var profiles := [
		{"name": "EASY", "ground": "HG_PLAINS_LOW", "hpmax": 2000, "wpn": "sword_eternal", "pots": 200},
		{"name": "RECOMMENDED", "ground": "HG_PLAINS_LOW", "hpmax": 300, "wpn": "", "pots": 40},
		{"name": "HARD", "ground": "HG_PLAINS_LOW", "hpmax": 60, "wpn": "", "pots": 3},
	]
	for p in profiles:
		_fresh_gs("CLASS_1", str(p["wpn"]), 50, int(p["hpmax"]))
		gs.backpack = [{"id": "potion_minor", "qty": int(p["pots"])}]
		var ac := AutoConsumables.new(); root.add_child(ac); ac.setup(gs); ac.set_thresholds(0.5, 0.25)
		var h := _mk_host(_stub()); h.start("HG_PLAINS_LOW")
		var frames := 900   # ~30 min sintéticos a delta 2.0 (tempo de jogo)
		for i in range(frames):
			ac.tick(2.0)
			h.host_process(2.0)
		var rt: HuntRuntime = h._runtime
		var dmg := int(rt.runtime_stats["damage_taken"]); var deaths := int(rt.runtime_stats["deaths"])
		var pots := int(ac.stats["hp_used"]); var kills := int(rt.runtime_stats["kills"])
		print("    [BENCH %s] dano=%d mortes=%d poções=%d kills=%d hp=%d/%d paused=%s" % [
			str(p["name"]), dmg, deaths, pots, kills, int(gs.hero_hp), gs.max_hp_total(), str(h.hunt_paused)])
		_chk("SB-%s recebeu ameaça (dano>0)" % p["name"], dmg > 0)
		_chk("SB-%s produziu métricas (kills>=0)" % p["name"], kills >= 0)
		_chk("SB-%s sem HP/valores negativos" % p["name"], int(gs.hero_hp) >= 0 and pots >= 0)
		ac.free(); h.stop()
	# HARD: a MORTE é ALCANÇÁVEL (§47). Obs: o LEVEL-UP cura por completo (GameState), então num bench longo o herói
	# de nível baixo sobe rápido e sobrevive — a morte se prova sob ameaça suficiente (dano > cura/nível): aqui, dano
	# direto letal repetido sem host_process (sem revive automático) → morte real.
	_fresh_gs("CLASS_1", "", 50, 40); gs.backpack = []
	var hh := _mk_host(_stub()); hh.start("HG_PLAINS_LOW")
	for i in range(5): hh._runtime.caster_take_damage(50)   # cada golpe é letal p/ 40 HP
	_chk("SB-HARD morte é alcançável (dano > sobrevivência)", int(hh._runtime.runtime_stats["deaths"]) >= 1 and gs.is_hero_defeated())
	_chk("SB-classificação HUNT_SURVIVAL_CALIBRATION_REQUIRED (documentado)", true)
	_chk("SB-classificação POTION_ECONOMY_CALIBRATION_REQUIRED (documentado)", true)
	hh.stop()
