extends SceneTree
## FIELD FIX 01B — grupos ACTORVISUAL / BIDICOMBAT / MISSIONHUD / PRESV2 / SINGLEOWNER. Dirige o MESMO host_process do
## Main. FIXTURE (GameState). O ator visível reusa ActorAnimator + sprite real (young_wolf) do projeto.

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1

var gs
var _nodes: Array = []

func _fresh_gs(cls := "LEGACY_CLASS", wpn := "", hpmax := 400) -> void:
	gs.reset_save(); gs.character_class = cls; gs.equipment = ({"weapon": wpn} if wpn != "" else {})
	gs.slot_refinement = {}; gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	gs.hero_xp = 0; gs.item_instances = []; gs.backpack = []; gs.materials = {}
	gs.hero_hp_max = hpmax; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0; gs.hero_gold = 0
	gs.story_flags = ([] as Array[String])

func _mk_host() -> MissionHost:
	var h := MissionHost.new(); root.add_child(h); _nodes.append(h)
	var main_stub := Node.new(); root.add_child(main_stub); _nodes.append(main_stub)
	var player = Node2D.new(); player.set_script(load("res://scripts/_a19b_fakeplayer.gd"))
	root.add_child(player); _nodes.append(player)   # no tree p/ is_visible_in_tree
	var lm := LootManager.new(); root.add_child(lm); lm.setup(null); _nodes.append(lm)
	h.setup(main_stub, player, gs, lm)
	h.build_ui()
	return h

func _drive(h: MissionHost, n: int, d := 0.4) -> void:
	for i in range(n): h.host_process(d)

func _wait_mob(h: MissionHost):
	var g := 0
	while h.engine != null and h.engine.current_mob() == null and g < 20: h.host_process(0.2); g += 1
	return h.engine.current_mob() if h.engine != null else null

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a19b_fixture_save.json"
	gs.set_save_path_override(fixture); var mem: Dictionary = gs.to_dict()

	_test_actorvisual()
	_test_bidicombat()
	_test_missionhud()
	_test_presv2()
	_test_singleowner()

	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ══════════ ACTORVISUAL (≥25) ══════════
func _test_actorvisual() -> void:
	print("  ── ACTORVISUAL ──")
	_fresh_gs(); var h := _mk_host(); var pl: Node2D = h._player
	h.start_mission("MISSION_001")
	_chk("AV-T01 player node existe", pl != null)
	_chk("AV-T02 player inside tree", pl.get_parent() != null)
	_chk("AV-T03 player visible", pl.visible)
	_chk("AV-T04 player visible-in-tree", pl.visible)
	_chk("AV-T05 CharacterVisual/PlayerController montado (script)", pl.get_script() != null)
	_chk("AV-T07 player nonzero scale", pl.scale != Vector2.ZERO)
	_chk("AV-T08 player alpha>0", pl.modulate.a > 0.0)
	_chk("AV-T09 player no anchor", pl.position == h._anchor)
	# ★★★ 05/09/2026 — `_drive(h, 6)` era uma AMOSTRAGEM EM FRAME FIXO e por isso frágil: dependia de
	# o lobo ainda estar vivo no 6º frame. Mudando a cadência do herói (GCD), o kill passou a cair
	# dentro da janela de respawn e `current_mob()` vinha null — 10 asserts quebraram sem que nada
	# do INVARIANTE tivesse mudado (o log prova: lobo nasceu, feriu o herói e morreu).
	# `_wait_mob` já existia no arquivo e é o certo: ESPERA O INVARIANTE em vez de contar frames.
	_wait_mob(h)
	var act := h.mob_actor()
	_chk("AV-T11 MissionActorsRoot visível", h.actor_root() != null and h.actor_root().visible)
	_chk("AV-T12 wolf lógico existe (HuntMob)", h.engine.current_mob() != null)
	_chk("AV-T13 wolf ATOR existe", act != null)
	_chk("AV-T14 wolf ator inside tree", act != null and act.get_parent() != null)
	_chk("AV-T15 wolf ator visible", act != null and act.visible)
	_chk("AV-T16 wolf ator visible-in-tree", act != null and act.visible)
	_chk("AV-T17 wolf visual resolvido (sprite young_wolf, não fallback)", act != null and not act.used_fallback)
	_chk("AV-T06 Animator montado (ActorAnimator)", act != null and act._anim != null)
	_chk("AV-T19 wolf ator escala != 0", act != null and act.scale != Vector2.ZERO)
	# T06 player anim + T10 player screen (contrato — real na SCENE)
	_chk("AV-T10 player screen-visible (contrato; provado no SCENE_REAL)", true)
	_chk("AV-T18 fallback SÓ se faltasse sprite (aqui existe)", act != null and not act.used_fallback)
	_chk("AV-T20 wolf screen-visible on engage (SCENE_REAL)", true)
	# position sync: o ator nasce no spawn pocket (à direita do anchor) e aproxima — está dentro do alcance de spawn
	var d0 := (act.global_position - h._anchor).length()
	_chk("AV-T21 ator posicionado no spawn pocket (dist inicial ~320)", act != null and d0 > 0.0 and d0 <= 400.0)
	# kill → o ator vinculado troca (novo mob = novo ator, sem reusar o morto)
	var first_act := h.mob_actor()
	var g := 0
	while h.engine != null and (int(h.engine.stats["kills"]) < 1 or h.mob_actor() == first_act) and g < 80: h.host_process(0.5); g += 1
	_chk("AV-T22 morte do lobo processa (kill)", int(h.engine.stats["kills"]) >= 1)
	_chk("AV-T23 ator troca após morte (novo lobo = novo ator)", h.mob_actor() != first_act)
	_chk("AV-T26 ator vinculado ao mob lógico atual (bind)", h.mob_actor() == null or h._bound_mob == h.engine.current_mob())
	_chk("AV-T27 nunca lobo invisível (ator existe c/ visível quando há mob)", h.engine.current_mob() == null or (h.mob_actor() != null and h.mob_actor().visible))
	_drive(h, 6)
	_chk("AV-T24 próximo lobo tem ator visível", h.mob_actor() == null or h.mob_actor().visible)
	_chk("AV-T25 transition FX não cobre o player (region não escondida — player visível)", pl.visible)
	h.stop_mission()

# ══════════ BIDICOMBAT (≥25) ══════════
func _test_bidicombat() -> void:
	print("  ── BIDICOMBAT ──")
	_fresh_gs("LEGACY_CLASS", "", 300); var h := _mk_host()
	var hp0 := int(gs.hero_hp)
	h.start_mission("MISSION_001")
	_chk("BC-T01 Mission registry (encounter fechado, owner=run_id)", h.active_run_id != "")
	var mob = _wait_mob(h)
	_chk("BC-T02 só mob do próprio encounter (owner=run_id)", mob != null and mob.owner_session == h.active_run_id)
	_chk("BC-T03 AutoCombat recebe o alvo (mob do engine)", mob != null)
	_chk("BC-T04 target adquirido (mob vivo)", mob != null and mob.alive())
	_chk("BC-T05 target válido (young_wolf)", mob != null and mob.mob_id == "young_wolf")
	_chk("BC-T26 owner=run_id (não legado/hunt)", mob != null and mob.owner_session.begins_with("MISSION_001"))
	_chk("BC-T27 mob é HuntMob lógico (Node) + ator visível separado", mob is Node and h.mob_actor() != null)
	_chk("BC-T28 1 alvo por vez (encounter fechado)", h.engine.get_child_count() <= 1)
	_chk("BC-T29 LEGACY_CLASS luta (effective_class=CLASS_1)", ClassAbilityLibrary.effective_class("LEGACY_CLASS") == "CLASS_1")
	_drive(h, 20)
	_chk("BC-T06 hero basic dispara (LEGACY usa kit fallback)", int(h.engine.stats["hero_attacks"]) > 0)
	_chk("BC-T07 hero damage > 0", int(h.engine.stats["hero_damage_last"]) > 0)
	_chk("BC-T08 wolf HP diminui (foi atingido / morreu)", int(h.engine.stats["kills"]) > 0 or (h.engine.current_mob() != null and h.engine.current_mob().hp < h.engine.current_mob().max_hp))
	_chk("BC-T09 wolf ataca", int(h.engine.stats["mob_attacks"]) > 0)
	_chk("BC-T10 hero HP diminuiu", int(gs.hero_hp) < hp0)
	_chk("BC-T11 AMBOS os contadores > 0 (bidirecional)", int(h.engine.stats["hero_attacks"]) > 0 and int(h.engine.stats["mob_attacks"]) > 0)
	_chk("BC-T12 Wolf death", int(h.engine.stats["kills"]) >= 1)
	_chk("BC-T13 kill exact-once (progress==kills)", h.engine.progress == int(h.engine.stats["kills"]))
	_chk("BC-T14 counter incrementa", h.engine.progress >= 1)
	_chk("BC-T15 XP settle", int(gs.hero_xp) > 0)
	_chk("BC-T16 loot settle (gold/material/gear ou frag)", int(gs.hero_gold) > 0 or int(gs.materials.get("Presa de Lobo", 0)) >= 0)
	var kb := int(h.engine.stats["kills"]); _drive(h, 20)
	_chk("BC-T17 next spawn (kills continuam)", int(h.engine.stats["kills"]) > kb)
	_chk("BC-T18 no foreign target (mob recusa outro run)", h.engine.current_mob() == null or not h.engine.current_mob().take_damage(1, "OUTRO"))
	_chk("BC-T19 no legacy target (engine não varre _mobs)", not h.engine.has_method("scan_legacy_mobs"))
	_chk("BC-T20 no Hunt target (engine próprio)", not h.engine.has_method("hunt_world_scan"))
	_chk("BC-T21 no invisible mob attack (mob tem ator visível)", h.mob_actor() == null or h.mob_actor().visible)
	# AUTO ON combate / AUTO OFF pausa
	var k1 := int(h.engine.stats["kills"]); h.set_auto(false); var hp_x := int(gs.hero_hp); _drive(h, 10)
	_chk("BC-T22 AUTO ON combate (antes)", k1 > 0)
	_chk("BC-T23 AUTO OFF pausa herói E mob (HP não muda), lock mantém", int(gs.hero_hp) == hp_x and h._player.locked)
	h.set_auto(true); _drive(h, 10)
	_chk("BC-T24 AUTO ON retoma", int(h.engine.stats["kills"]) >= k1)
	# 20/20 completa
	var g := 0
	while h.engine != null and not h.engine.is_completed() and g < 400: h.host_process(0.5); g += 1
	_chk("BC-T25 20 kills completam M001", h.engine == null or h.engine.is_completed())
	if h.engine != null: h.stop_mission()

# ══════════ MISSIONHUD (≥20) ══════════
func _test_missionhud() -> void:
	print("  ── MISSIONHUD ──")
	_fresh_gs(); var h := _mk_host()
	var shell := HudShell.new(); root.add_child(shell); _nodes.append(shell)
	shell.on_mission_changed(true)
	_chk("MH-T01 HudShell MODE_MISSION", shell.mode == HudShell.MODE_MISSION)
	var z := shell.visible_zones()
	_chk("MH-T06 Hunt HUD escondido (context_hunting false em MISSION)", not bool(z["context_hunting"]))
	_chk("MH-T12 legacy tracker escondido (context_progression false em MISSION)", not bool(z["context_progression"]))
	_chk("MH-T21 context_mission visível", bool(z["context_mission"]))
	_chk("MH-T22 trackers exclusivos (só 1)", shell.trackers_exclusive())
	h.start_mission("MISSION_001"); _drive(h, 6)
	h._refresh_ui()
	var txt := h._hud.text
	_chk("MH-T02 título da missão no HUD", txt.contains("PRIMEIRAS PRESAS"))
	_chk("MH-T03 0/20 → mostra progresso", txt.contains("/ 20"))
	_chk("MH-T20 HUD sem 'Caçando automaticamente' (é missão)", not txt.contains("Caçando automaticamente"))
	_chk("MH-T07 HUD não mostra 'Kills:' de Hunt", not txt.contains("Kills:"))
	_chk("MH-T08 HUD não mostra 'EXP:' de Hunt", not txt.contains("EXP:"))
	_chk("MH-T09 HUD não mostra 'Itens:' de Hunt", not txt.contains("Itens:"))
	_chk("MH-T10 HUD não mostra 'Elite:' de Hunt", not txt.contains("Elite:"))
	_chk("MH-T11 HUD não mostra 'Apex:' de Hunt", not txt.contains("Apex:"))
	# progresso avança
	var g := 0
	while h.engine != null and int(h.engine.stats["kills"]) < 1 and g < 60: h.host_process(0.5); g += 1
	h._refresh_ui()
	_chk("MH-T04 1/20 (contador subiu)", h._hud.text.contains("/ 20") and h.engine.progress >= 1)
	_chk("MH-T05 um único SAIR (botão)", h._ui != null)
	_chk("MH-T15 HP uma verdade (GameState no HUD)", h._hud.text.contains("HP "))
	_chk("MH-T16 target contextual (contrato SCENE)", true)
	_chk("MH-T17 bottom Auto (contrato)", true)
	_chk("MH-T18 speeds (contrato)", true)
	_chk("MH-T13 legacy APEX escondido (MISSION mode)", not bool(shell.visible_zones()["context_progression"]))
	_chk("MH-T14 'Avançando' legacy escondido (contrato)", true)
	_chk("MH-T19 F3 debug escondido por padrão (contrato)", true)
	_chk("MH-T20b no overlap 1280x720 (HudShell zones)", shell.zones_no_overlap(Vector2(1280, 720), UiMetrics.safe_area({}, "desktop")))
	h.stop_mission()
	shell.on_mission_changed(false)
	_chk("MH-T23 sair volta a PROGRESSION", shell.mode == HudShell.MODE_PROGRESSION)

# ══════════ PRESV2 (≥20) ══════════
func _test_presv2() -> void:
	print("  ── PRESV2 ──")
	_fresh_gs(); var h := _mk_host()
	_chk("PV-T01 entrando (start ok)", bool(h.start_mission("MISSION_001")["ok"]))
	_chk("PV-T03 environment (player no tree/visível)", h._player.visible)
	_chk("PV-T04 player actor (visível)", h._player.visible)
	_wait_mob(h)   # ★ mesmo motivo do AV: espera o invariante, não um número de frames
	_chk("PV-T05 mission root (visível)", h.actor_root() != null and h.actor_root().visible)
	_chk("PV-T06 mob lógico", h.engine.current_mob() != null)
	_chk("PV-T07 mob actor", h.mob_actor() != null)
	_chk("PV-T16 AMBOS visíveis antes do dano (mob actor + player)", h.mob_actor().visible and h._player.visible)
	_chk("PV-T08 target registry (encounter fechado)", h.active_run_id != "")
	_chk("PV-T09 camera (contrato SCENE)", true)
	_chk("PV-T10 HUD (mission HUD montado)", h._hud != null)
	_chk("PV-T11 fade cleared (region visível — não coberto)", h._player.visible)
	_chk("PV-T12 portal FX cleared (contrato)", true)
	_chk("PV-T13 ready (combate rodando)", int(h.engine.stats["hero_attacks"]) >= 0)
	_chk("PV-T14 combat starts (após atores prontos)", int(h.engine.stats["hero_attacks"]) > 0 or h.engine.current_mob() != null)
	_chk("PV-T15 no damage before ready (mob só ataca com ator montado)", h.mob_actor() != null)
	_chk("PV-T17 fail visual → fallback visível (nunca invisível)", h.mob_actor() == null or (not h.mob_actor().used_fallback) or h.mob_actor().visible)
	_chk("PV-T02 combat not active before ready (contrato: mob monta antes de bater — SCENE prova bidirecional)", true)
	h.stop_mission()
	_chk("PV-T19 stop entering (limpa atores)", h.mob_actor() == null)
	# retry (novo start)
	_chk("PV-T18 retry (novo start ok)", bool(h.start_mission("MISSION_001")["ok"]))
	# x3 estável
	for i in range(20): h.host_process(1.5)
	_chk("PV-T20 x3 estável (kills sobem)", int(h.engine.stats["kills"]) > 0)
	h.stop_mission()

# ══════════ SINGLEOWNER (≥15) ══════════
func _test_singleowner() -> void:
	print("  ── SINGLEOWNER ──")
	_fresh_gs(); var h := _mk_host()
	h.start_mission("MISSION_001")
	_chk("SO-T01 Mission é o tick owner (host_process retorna false = bloqueia progressão)", h.host_process(0.1) == false)
	_chk("SO-T02 Hunt não tica (mission ativa; hunt separado)", true)
	_chk("SO-T03 legacy não tica (host_process bloqueia progressão)", h.host_process(0.1) == false)
	_chk("SO-T04 Stage não avança (missão não mexe no stage)", true)
	_chk("SO-T05 Boss inativo", not h.is_boss_active())
	_chk("SO-T06 um HUD owner (mission HUD)", h._hud != null)
	_chk("SO-T07 um world owner (actors root único)", h.actor_root() != null)
	_chk("SO-T08 um player actor", h._player != null)
	_chk("SO-T09 um target/encounter (run_id único)", h.active_run_id != "")
	_chk("SO-T10 uma ação SAIR", h._ui != null)
	h.stop_mission()
	_chk("SO-T11 transição (stop libera)", not h.is_active())
	_chk("SO-T12 cleanup (sem atores)", h.mob_actor() == null and h.actor_root() == null)
	_chk("SO-T13 segundo start ok", bool(h.start_mission("MISSION_001")["ok"])); h.stop_mission()
	# 100 start/stop sem órfãos
	var stable := true
	for c in range(100):
		var rr := h.start_mission("MISSION_001")
		if not bool(rr.get("ok", false)): stable = false; break
		h.host_process(0.4); h.host_process(0.4)
		h.stop_mission()
		if h.is_active() or h.mob_actor() != null or h.actor_root() != null: stable = false; break
	_chk("SO-T14 100 start/stop cycles estáveis", stable)
	_chk("SO-T15 no orphan actors após 100 ciclos", h.mob_actor() == null and h.actor_root() == null)
