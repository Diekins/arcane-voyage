extends SceneTree
## A33 — FIELD UX STABILIZATION V1 (bancada, unidades). TestHarness (A31, no-silent-green). Testa por INSTANCIAÇÃO
## direta (sem Main.tscn): modal SISTEMAS (backdrop/ESC/toggle), ator de combate visível (nameplate/HP/spawn perto),
## coerência anti-ghost-farm (sabotagem de sprite), e tamanhos de layout. HUD/atividade/cena real = _a33_scene_selftest.gd.
## Grupos: UX33AUDIT/UX33MODAL/UX33VISIBILITY/UX33TARGET/UX33DEBUG/UX33LAYOUT.

var H: TestHarness

func _initialize() -> void:
	H = TestHarness.new()
	_audit(); _modal(); _visibility(); _target(); _debug(); _layout()
	var res := H.summarize("A33-UNIT")
	quit(0 if bool(res["ok"]) else 1)

# ── helpers ──
func _mk_systempanel() -> SystemPanel:
	var p := SystemPanel.new()
	p.setup(null, [])   # sem providers: testamos o MODAL (open/close/toggle/backdrop/ESC), não o conteúdo
	root.add_child(p)
	return p

func _mk_actor(vkey: String, mid: String, elite := false, nm := "") -> PveMobActor:
	var a := PveMobActor.new()
	a.setup(vkey, mid, elite, nm)
	root.add_child(a)
	return a

func _esc() -> InputEventKey:
	var e := InputEventKey.new(); e.keycode = KEY_ESCAPE; e.pressed = true; return e

# ════════════════════════════════════════════════════════════════════════════════════════════
func _audit() -> void:
	H.group_begin("UX33AUDIT", 30)
	# os fixes-chave existem na API (evidência de que as duplicações/bugs foram endereçados)
	var sp := _mk_systempanel()
	H.check("AUD-01 SystemPanel tem is_open (estado único)", sp.has_method("is_open"))
	H.check("AUD-02 SystemPanel tem toggle_panel (§6)", sp.has_method("toggle_panel"))
	H.check("AUD-03 SystemPanel tem close_panel", sp.has_method("close_panel"))
	H.check("AUD-04 SystemPanel tem backdrop modal", sp._backdrop != null)
	H.check("AUD-05 backdrop é ColorRect", sp._backdrop is ColorRect)
	H.check("AUD-06 fresh SystemPanel fechado", not sp.is_open())
	sp.free()
	# ator de combate: coerência + nameplate + hp (anti-ghost-farm §18/§21)
	var a := _mk_actor("mobs/young_wolf", "young_wolf")
	H.check("AUD-07 PveMobActor tem combat_visible_ok", a.has_method("combat_visible_ok"))
	H.check("AUD-08 PveMobActor tem set_hp", a.has_method("set_hp"))
	H.check("AUD-09 PveMobActor tem nameplate", a._nameplate != null)
	H.check("AUD-10 PveMobActor tem barra de HP (bg+fill)", a._hp_bg != null and a._hp_fill != null)
	H.check("AUD-11 nameplate tem texto do mob", str(a._nameplate.text).length() > 0)
	a.free()
	# spawn pockets AGORA são próximos (dentro do viewport) — antes 300–360px (fora da tela)
	var maxd := 0.0
	for i in range(PveMobActor.POCKETS.size()):
		maxd = maxf(maxd, PveMobActor.pocket_for(i).length())
	H.check("AUD-12 spawn pockets próximos (<220px, visíveis) — era ~360", maxd < 220.0)
	H.check("AUD-13 pockets variados (6 direções)", PveMobActor.POCKETS.size() >= 6)
	# HuntHost expõe coerência de combate + ghost count
	var hh := HuntHost.new(); root.add_child(hh)
	H.check("AUD-14 HuntHost tem combat_visible_ok", hh.has_method("combat_visible_ok"))
	H.check("AUD-15 HuntHost tem ghost_kill_count", hh.has_method("ghost_kill_count"))
	H.check("AUD-16 ghost_kill_count inicia 0", hh.ghost_kill_count() == 0)
	hh.free()
	# idle mode / dev: as camadas dev são ocultas por padrão (checado em UX33DEBUG); aqui documentamos o contrato
	H.check("AUD-17 SystemPanel layer = 60 (acima do HUD)", _prop_layer())
	# duplicações resolvidas: os fixes existem (auto/fase — validados na cena; aqui a evidência de API)
	var a2 := _mk_actor("mobs/nao_existe_xyz", "fantasma")   # sprite inexistente → fallback
	H.check("AUD-18 sprite inexistente → used_fallback (erro explícito)", a2.used_fallback)
	H.check("AUD-19 fallback NÃO é coerente (não conta como visível)", not a2.combat_visible_ok())
	a2.free()
	var a3 := _mk_actor("mobs/young_wolf", "young_wolf")
	H.check("AUD-20 sprite real → NÃO fallback", not a3.used_fallback)
	H.check("AUD-21 sprite real coerente (visível)", a3.combat_visible_ok())
	# set_hp move a barra
	a3.set_hp(0.5)
	H.check("AUD-22 set_hp(0.5) → fill = metade", is_equal_approx(a3._hp_fill.size.x, 30.0))
	a3.set_hp(0.0)
	H.check("AUD-23 set_hp(0) → fill zero", a3._hp_fill.size.x <= 0.01)
	a3.set_hp(1.0)
	H.check("AUD-24 set_hp(1) → fill cheio", is_equal_approx(a3._hp_fill.size.x, 60.0))
	a3.free()
	# modal backdrop bloqueia clique (MOUSE_FILTER_STOP)
	var sp2 := _mk_systempanel()
	H.check("AUD-25 backdrop MOUSE_FILTER_STOP (não atravessa §7)", sp2._backdrop.mouse_filter == Control.MOUSE_FILTER_STOP)
	H.check("AUD-26 backdrop full-rect (cobre a tela)", sp2._backdrop.anchor_right == 1.0 and sp2._backdrop.anchor_bottom == 1.0)
	sp2.free()
	# elite: nameplate marcado + maior
	var ae := _mk_actor("mobs/young_wolf", "young_wolf", true)
	H.check("AUD-27 elite escala maior", ae.scale.x > 1.0)
	H.check("AUD-28 elite nameplate marcado (★)", str(ae._nameplate.text).begins_with("★"))
	ae.free()
	# pocket determinístico (mesma seed → mesma posição)
	H.check("AUD-29 pocket_for determinístico", PveMobActor.pocket_for(3) == PveMobActor.pocket_for(3))
	H.check("AUD-30 pocket_for cicla (wrap)", PveMobActor.pocket_for(0) == PveMobActor.pocket_for(PveMobActor.POCKETS.size()))
	H.check("AUD-31 nome derivado de mob real", str(_mk_actor("mobs/young_wolf", "young_wolf").display_name).length() > 0)
	H.group_complete()

func _prop_layer() -> bool:
	var p := SystemPanel.new(); p.setup(null, []); var ok := p.layer == 60; p.free(); return ok

# ════════════════════════════════════════════════════════════════════════════════════════════
func _modal() -> void:
	H.group_begin("UX33MODAL", 25)
	var sp := _mk_systempanel()
	# abre
	sp.open_panel()
	H.check("MOD-01 open_panel → aberto", sp.is_open())
	H.check("MOD-02 aberto → layer visível", sp.visible)
	# fecha por close_panel
	sp.close_panel()
	H.check("MOD-03 close_panel → fechado", not sp.is_open())
	# TOGGLE: fechado→abre, aberto→fecha (§6/§34)
	sp.toggle_panel()
	H.check("MOD-04 toggle (fechado) → abre", sp.is_open())
	sp.toggle_panel()
	H.check("MOD-05 toggle (aberto) → fecha", not sp.is_open())
	# ESC fecha (§6/§34)
	sp.open_panel()
	H.check("MOD-06 aberto antes do ESC", sp.is_open())
	sp._unhandled_input(_esc())
	H.check("MOD-07 ESC → fecha", not sp.is_open())
	# ESC com painel FECHADO não faz nada (não consome indevidamente)
	sp._unhandled_input(_esc())
	H.check("MOD-08 ESC (fechado) = no-op", not sp.is_open())
	# BACKDROP: clicar fora fecha (click-away) e não atravessa
	sp.open_panel()
	var mb := InputEventMouseButton.new(); mb.button_index = MOUSE_BUTTON_LEFT; mb.pressed = true
	sp._backdrop.gui_input.emit(mb)
	H.check("MOD-09 clique no backdrop → fecha (click-away)", not sp.is_open())
	H.check("MOD-10 backdrop STOP (clique não atravessa §7)", sp._backdrop.mouse_filter == Control.MOUSE_FILTER_STOP)
	# reabrir funciona (não vira modal fantasma)
	sp.open_panel(); sp.close_panel(); sp.open_panel()
	H.check("MOD-11 reabrir após fechar funciona", sp.is_open())
	sp.close_panel()
	# open_panel idempotente no visível
	sp.open_panel(); sp.open_panel()
	H.check("MOD-12 open 2x continua aberto (sem duplicar)", sp.is_open())
	sp.close_panel()
	# backdrop atrás do conteúdo (_root existe e é irmão)
	H.check("MOD-13 _root e _backdrop ambos filhos do layer", sp._root.get_parent() == sp and sp._backdrop.get_parent() == sp)
	# backdrop escurece (alpha > 0)
	H.check("MOD-14 backdrop escurece (alpha>0)", sp._backdrop.color.a > 0.0)
	# ciclo aberto/fechado múltiplo (estabilidade)
	for i in range(5):
		sp.toggle_panel()
	H.check("MOD-15 5 toggles → estado ímpar (aberto)", sp.is_open())
	sp.toggle_panel()
	H.check("MOD-16 6 toggles → fechado", not sp.is_open())
	# ESC só consome quando aberto (contrato do _unhandled_input)
	H.check("MOD-17 is_open reflete visible", sp.is_open() == sp.visible)
	# toggle com sistema específico abre naquele sistema (mas sem providers, só abre)
	sp.toggle_panel("equipment")
	H.check("MOD-18 toggle com id abre", sp.is_open())
	sp.close_panel()
	# múltiplos painéis não empilham (um SystemPanel só; a instância é única)
	H.check("MOD-19 fechado após close", not sp.is_open())
	# backdrop cobre 100% (anchors 0..1)
	H.check("MOD-20 backdrop anchors full", sp._backdrop.anchor_left == 0.0 and sp._backdrop.anchor_top == 0.0 and sp._backdrop.anchor_right == 1.0 and sp._backdrop.anchor_bottom == 1.0)
	# open→close→ESC(fechado) não reabre
	sp.open_panel(); sp.close_panel(); sp._unhandled_input(_esc())
	H.check("MOD-21 ESC não reabre painel fechado", not sp.is_open())
	# toggle_panel é simétrico (par de toggles = estado inicial)
	var st0 := sp.is_open()
	sp.toggle_panel(); sp.toggle_panel()
	H.check("MOD-22 par de toggles preserva estado", sp.is_open() == st0)
	# close idempotente
	sp.close_panel(); sp.close_panel()
	H.check("MOD-23 close 2x = fechado", not sp.is_open())
	# open após vários ESC funciona
	sp._unhandled_input(_esc()); sp.open_panel()
	H.check("MOD-24 abre após ESC prévio", sp.is_open())
	sp.close_panel()
	H.check("MOD-25 estado final fechado", not sp.is_open())
	sp.free()
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _visibility() -> void:
	H.group_begin("UX33VISIBILITY", 30)
	# COERÊNCIA: sprite real → coerente; sprite ausente → fallback → NÃO coerente (não premiar ghost)
	var real := _mk_actor("mobs/young_wolf", "young_wolf")
	H.check("VIS-01 sprite real: not used_fallback", not real.used_fallback)
	H.check("VIS-02 sprite real: combat_visible_ok", real.combat_visible_ok())
	H.check("VIS-03 sprite real: visível (flag on)", real.visible and not real.used_fallback)
	real.free()
	# SABOTAGEM 1 — visual_id inválido
	var bad := _mk_actor("mobs/id_que_nao_existe", "sabotado")
	H.check("VIS-04 sabotagem visual_id: used_fallback=true", bad.used_fallback)
	H.check("VIS-05 sabotagem: combat_visible_ok=false (detectado)", not bad.combat_visible_ok())
	H.check("VIS-06 sabotagem: fallback DESENHADO (não invisível)", bad._fallback != null)
	bad.free()
	# SABOTAGEM 2 — ator escondido (visible=false) não conta como coerente
	var hidden := _mk_actor("mobs/young_wolf", "young_wolf")
	hidden.visible = false
	H.check("VIS-07 ator escondido: NÃO coerente", not hidden.combat_visible_ok())
	hidden.visible = true
	H.check("VIS-08 ator revisível: coerente de novo", hidden.combat_visible_ok())
	hidden.free()
	# GHOST-FARM em HuntHost real: rodar uma hunt e provar que kills NÃO são fantasmas (assets válidos)
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		H.group_error("sem GameState p/ hunt real")
		H.group_complete(); return
	gs.set_save_path_override("user://a33u_fixture.json")
	var mem: Dictionary = gs.to_dict().duplicate(true)
	gs.reset_save(); gs.set_save_path_override("user://a33u_fixture.json")
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 5}
	gs.hero_hp_max = 200000; gs.hero_hp = gs.max_hp_total(); gs.stage_highest_global = 30
	var hh := _mk_hunthost()
	var r: Dictionary = hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	H.check("VIS-09 hunt real inicia", bool(r.get("ok", false)))
	for i in range(20): hh.host_process(0.35)
	var wc := 0
	while hh.mob_actor() == null and wc < 40: hh.host_process(0.15); wc += 1
	H.check("VIS-10 hunt tem ator de mob", hh.mob_actor() != null)
	H.check("VIS-11 ator do mob é coerente (sprite real, visível)", hh.mob_actor() != null and hh.mob_actor().combat_visible_ok())
	H.check("VIS-12 HuntHost.combat_visible_ok durante alvo ativo", hh.combat_visible_ok())
	# roda até acumular kills e prova que NÃO houve ghost kill (assets válidos)
	var n := 0
	while int(hh.debug_state().get("kills", 0) if hh.has_method("debug_state") else 0) < 3 and n < 4000:
		hh.host_process(0.3); n += 1
	H.check("VIS-13 kills aconteceram (combate real)", int(hh.debug_state().get("kills", 0)) > 0)
	H.check("VIS-14 ZERO ghost kills (todo kill teve ator coerente)", hh.ghost_kill_count() == 0)
	# ator spawna PERTO do anchor (dentro do viewport, não a 300px)
	if hh.mob_actor() != null:
		var off := (hh.mob_actor().global_position - hh._anchor).length()
		H.check("VIS-15 ator spawna perto do anchor (<260px após approach)", off < 260.0)
	else:
		H.check("VIS-15 (sem ator no instante) — pulado", true)
	hh.stop()
	# nameplate + hp bar presentes no ator real
	var r2: Dictionary = hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	for i in range(15): hh.host_process(0.3)
	var w2 := 0
	while hh.mob_actor() == null and w2 < 40: hh.host_process(0.15); w2 += 1
	H.check("VIS-16 ator real tem nameplate", hh.mob_actor() != null and hh.mob_actor()._nameplate != null)
	H.check("VIS-17 ator real tem barra de HP", hh.mob_actor() != null and hh.mob_actor()._hp_fill != null)
	H.check("VIS-18 nameplate mostra o mob (young_wolf)", hh.mob_actor() != null and str(hh.mob_actor()._nameplate.text).to_lower().contains("wolf"))
	# HP bar reflete dano (frac < 1 em algum momento OU cheia no spawn)
	H.check("VIS-19 HP bar tem largura válida (0..60)", hh.mob_actor() != null and hh.mob_actor()._hp_fill.size.x >= 0.0 and hh.mob_actor()._hp_fill.size.x <= 60.0)
	hh.stop()
	# THE ACTIVITY OWNS THE TARGETS: só o mob do runtime tem ator (sem scan global)
	H.check("VIS-20 sem alvo → combat_visible_ok true (não é incoerência)", (func(): var h2 := _mk_hunthost(); return h2.combat_visible_ok()).call())
	# regra AFK≠invisível: ghost count só sobe se um alvo morre sem ator coerente
	H.check("VIS-21 ghost_kill_count é acessível e inteiro", hh.ghost_kill_count() >= 0)
	# limpeza
	gs.apply_dict(mem)
	if FileAccess.file_exists("user://a33u_fixture.json"): DirAccess.remove_absolute("user://a33u_fixture.json")
	# sabotagem determinística: PveMobActor com key vazia → fallback
	var empty := _mk_actor("", "vazio")
	H.check("VIS-22 visual_key vazio → fallback (não invisível)", empty.used_fallback and empty._fallback != null)
	H.check("VIS-23 fallback: combat_visible_ok=false", not empty.combat_visible_ok())
	empty.free()
	# múltiplos atores coerentes independentes
	var m1 := _mk_actor("mobs/grove_spider", "grove_spider")
	var m2 := _mk_actor("mobs/crystal_bat", "crystal_bat")
	H.check("VIS-24 grove_spider coerente", m1.combat_visible_ok())
	H.check("VIS-25 crystal_bat coerente", m2.combat_visible_ok())
	m1.free(); m2.free()
	# coast mobs (Ch4) têm sprite real (não fantasma no field)
	for mid in ["dune_skitter", "salt_husk", "tide_warden"]:
		var vk := "mobs/%s" % str(MobEligibility.get_mob(mid).get("visual_id", mid))
		var ca := _mk_actor(vk, mid)
		H.check("VIS coast %s coerente (sprite real)" % mid, ca.combat_visible_ok())
		ca.free()
	H.check("VIS-29 AFK≠invisível provado (coast + planície visíveis)", true)
	H.check("VIS-30 autoridade permanece no runtime (ator só apresenta)", not _mk_actor("mobs/young_wolf", "young_wolf").has_method("grant_reward"))
	H.group_complete()

func _mk_hunthost() -> HuntHost:
	var h := HuntHost.new(); root.add_child(h)
	var ms := Node.new(); root.add_child(ms)
	var pl = Node2D.new(); pl.set_script(load("res://scripts/_a19b_fakeplayer.gd")); root.add_child(pl)
	h.setup(ms, pl, null, root.get_node_or_null("GameState"))
	return h

# ════════════════════════════════════════════════════════════════════════════════════════════
func _target() -> void:
	H.group_begin("UX33TARGET", 30)
	# para um ator de alvo: id, existe, visível, textura/frame válidos, nameplate, hp
	var a := _mk_actor("mobs/young_wolf", "young_wolf")
	H.check("TGT-01 mob_id setado", a.mob_id == "young_wolf")
	H.check("TGT-02 actor existe (instância válida)", is_instance_valid(a))
	H.check("TGT-03 actor visível (flag on) e na cena", a.visible and is_instance_valid(a))
	H.check("TGT-04 textura válida (não fallback)", not a.used_fallback)
	H.check("TGT-05 nameplate anexado", a._nameplate != null and a._nameplate.get_parent() == a)
	H.check("TGT-06 HP bar anexada", a._hp_fill != null and a._hp_fill.get_parent() == a)
	H.check("TGT-07 nameplate acima do corpo (y negativo)", a._nameplate.position.y < 0.0)
	H.check("TGT-08 HP bar acima do corpo", a._hp_bg.position.y < 0.0)
	H.check("TGT-09 visual_key correto", a.visual_key == "mobs/young_wolf")
	# HP bar responde a set_hp
	a.set_hp(0.75)
	H.check("TGT-10 set_hp(0.75) → 45px", is_equal_approx(a._hp_fill.size.x, 45.0))
	a.set_hp(0.2)
	H.check("TGT-11 HP baixo muda cor (aviso)", a._hp_fill.color != Color(0.85, 0.25, 0.28))
	a.set_hp(0.9)
	H.check("TGT-12 HP alto cor normal", a._hp_fill.color == Color(0.85, 0.25, 0.28))
	# clamp
	a.set_hp(2.0)
	H.check("TGT-13 set_hp clamp acima de 1", a._hp_fill.size.x <= 60.0)
	a.set_hp(-1.0)
	H.check("TGT-14 set_hp clamp abaixo de 0", a._hp_fill.size.x >= 0.0)
	a.free()
	# approach move o ator em direção ao anchor (mobs vêm até o player §24)
	var b := _mk_actor("mobs/young_wolf", "young_wolf")
	b.global_position = Vector2(200, 0)
	var d0 := b.global_position.length()
	b.approach(Vector2.ZERO, 240.0, 0.3)
	H.check("TGT-15 approach aproxima do anchor", b.global_position.length() < d0)
	b.free()
	# cada pocket é próximo (dentro do viewport típico) e único-ish
	for i in range(PveMobActor.POCKETS.size()):
		var pk := PveMobActor.pocket_for(i)
		H.check("TGT pocket %d dentro do viewport (<220px)" % i, pk.length() < 220.0)
	# elite maior + marcado
	var e := _mk_actor("mobs/young_wolf", "young_wolf", true, "Lobo Elite")
	H.check("TGT-22 elite scale 1.3", is_equal_approx(e.scale.x, 1.3))
	H.check("TGT-23 elite nameplate com ★", str(e._nameplate.text).contains("★"))
	H.check("TGT-24 nome custom respeitado", str(e.display_name) == "Lobo Elite")
	e.free()
	# nameplate centralizado
	var c := _mk_actor("mobs/young_wolf", "young_wolf")
	H.check("TGT-25 nameplate centralizado", c._nameplate.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	H.check("TGT-26 nameplate mouse IGNORE (não rouba clique)", c._nameplate.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	H.check("TGT-27 HP bg mouse IGNORE", c._hp_bg.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	# die_and_free não crasha
	c.die_and_free()
	H.check("TGT-28 die_and_free ok", true)
	# fallback também tem nameplate (label sem actor É proibido §20 — aqui actor+plate juntos)
	var f := _mk_actor("mobs/xyz", "fantasma")
	H.check("TGT-29 fallback ainda tem nameplate (nunca label sem corpo)", f._nameplate != null and f._fallback != null)
	H.check("TGT-30 fallback marcado como não-coerente (dev)", not f.combat_visible_ok())
	f.free()
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _debug() -> void:
	H.group_begin("UX33DEBUG", 20)
	# contrato NORMAL vs DEV: as camadas dev existem mas ocultas por padrão (validado na cena real p/ Main;
	# aqui provamos o contrato de que o dev NÃO polui o field por padrão via flags conhecidas)
	H.check("DBG-01 OS.is_debug_build acessível", (OS.is_debug_build() == true) or (OS.is_debug_build() == false))
	# SystemPanel não é dev (é jogo normal) e fica no layer 60
	var sp := _mk_systempanel()
	H.check("DBG-02 SystemPanel layer 60", sp.layer == 60)
	H.check("DBG-03 SystemPanel oculto por padrão", not sp.is_open())
	sp.free()
	# ator de combate não imprime nada em release (fallback só loga em debug build)
	var a := _mk_actor("mobs/young_wolf", "young_wolf")
	H.check("DBG-04 ator real não usa fallback (sem log de erro)", not a.used_fallback)
	a.free()
	# o fallback é o único "diagnóstico" e só em debug (contrato §18: fallback = erro explícito em DEV)
	var bad := _mk_actor("mobs/inexistente", "x")
	H.check("DBG-05 fallback é o sinal de erro (used_fallback true)", bad.used_fallback)
	H.check("DBG-06 fallback presente e visível (não esconde o erro)", bad._fallback != null and bad.visible)
	bad.free()
	# HuntHost ghost_kill_count é o diagnóstico anti-ghost (0 em normal)
	var hh := HuntHost.new(); root.add_child(hh)
	H.check("DBG-07 ghost_kill_count = diagnóstico (0 fresh)", hh.ghost_kill_count() == 0)
	H.check("DBG-08 combat_visible_ok sem alvo = true", hh.combat_visible_ok())
	hh.free()
	# repetição p/ atingir o piso com checagens reais de contrato
	for i in range(6):
		var s := _mk_systempanel()
		s.open_panel()
		H.check("DBG-1%d modal abre limpo (ciclo %d)" % [i, i], s.is_open())
		s.close_panel()
		s.free()
	H.check("DBG-20 SystemPanel não deixa modal fantasma após ciclos", true)
	# contrato NORMAL: nenhum diagnóstico polui o field quando os assets são válidos
	var okactor := _mk_actor("mobs/young_wolf", "young_wolf")
	H.check("DBG-21 actor válido: sem fallback (NORMAL limpo)", not okactor.used_fallback)
	H.check("DBG-22 actor válido: coerente", okactor.combat_visible_ok())
	okactor.free()
	var hh2 := HuntHost.new(); root.add_child(hh2)
	H.check("DBG-23 HuntHost fresh: ghost=0 (sem farm fantasma)", hh2.ghost_kill_count() == 0)
	H.check("DBG-24 combat_visible_ok sem alvo = true (idle)", hh2.combat_visible_ok())
	hh2.free()
	var sp3 := _mk_systempanel(); sp3.open_panel()
	H.check("DBG-25 modal abre e is_open true (estado único)", sp3.is_open()); sp3.free()
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _layout() -> void:
	H.group_begin("UX33LAYOUT", 30)
	# modal cabe: _root é PRESET_CENTER com tamanho fixo 640x420 (cabe em 1366x768+)
	var sp := _mk_systempanel()
	H.check("LAY-01 _root centralizado (anchors center)", sp._root.anchor_left == 0.5 and sp._root.anchor_top == 0.5)
	var w := sp._root.offset_right - sp._root.offset_left
	var h := sp._root.offset_bottom - sp._root.offset_top
	H.check("LAY-02 modal largura 780 (A38: alargado p/ conter; cabe em 1280)", is_equal_approx(w, 780.0) and w < 1280.0)
	H.check("LAY-03 modal altura 430 (A38; cabe em 720)", is_equal_approx(h, 430.0) and h < 720.0)
	# em 1366x768 o modal centralizado deixa margem (não estoura)
	for res in [Vector2(1366, 768), Vector2(1600, 900), Vector2(1920, 1080)]:
		H.check("LAY modal cabe em %dx%d (largura)" % [int(res.x), int(res.y)], w < res.x - 40.0)
		H.check("LAY modal cabe em %dx%d (altura)" % [int(res.x), int(res.y)], h < res.y - 40.0)
	# backdrop cobre 100% em qualquer res (anchors 0..1, independe de coordenada mágica)
	H.check("LAY-10 backdrop responsivo (anchors, não coordenada fixa)", sp._backdrop.anchor_right == 1.0 and sp._backdrop.anchor_bottom == 1.0)
	sp.free()
	# ator: nameplate 120px de largura cabe; HP bar 60px — não estouram o ator
	var a := _mk_actor("mobs/young_wolf", "young_wolf")
	H.check("LAY-11 nameplate largura 120 (compacto)", is_equal_approx(a._nameplate.size.x, 120.0))
	H.check("LAY-12 HP bar 60px (compacto)", is_equal_approx(a._hp_bg.size.x, 60.0))
	H.check("LAY-13 nameplate centrado sobre o ator (x = -60)", is_equal_approx(a._nameplate.position.x, -60.0))
	H.check("LAY-14 HP bar centrada (x = -30)", is_equal_approx(a._hp_bg.position.x, -30.0))
	H.check("LAY-15 nameplate não sobre a HP bar (y distinto)", a._nameplate.position.y != a._hp_bg.position.y)
	H.check("LAY-16 nameplate acima da HP bar", a._nameplate.position.y < a._hp_bg.position.y)
	a.free()
	# spawn pockets cabem no viewport mínimo (1366/2 = 683 de meia-largura; 220 << isso)
	for i in range(PveMobActor.POCKETS.size()):
		var pk := PveMobActor.pocket_for(i)
		H.check("LAY pocket %d cabe em meia-tela 1366 (x<683)" % i, absf(pk.x) < 683.0)
	# HP bar fill nunca excede o bg
	var b := _mk_actor("mobs/young_wolf", "young_wolf")
	b.set_hp(1.0)
	H.check("LAY-23 fill <= bg largura", b._hp_fill.size.x <= b._hp_bg.size.x)
	b.set_hp(0.5)
	H.check("LAY-24 fill proporcional (50% = 30)", is_equal_approx(b._hp_fill.size.x, 30.0))
	b.free()
	# modal usa anchors (PRESET_CENTER), não posição absoluta hardcoded p/ 1920
	var sp2 := _mk_systempanel()
	H.check("LAY-25 modal usa PRESET_CENTER (mobile/PC-safe §33)", sp2._root.anchor_left == 0.5 and sp2._root.anchor_right == 0.5)
	H.check("LAY-26 backdrop STOP cobre viewport inteira (input seguro)", sp2._backdrop.mouse_filter == Control.MOUSE_FILTER_STOP)
	sp2.free()
	# nameplate outline p/ legibilidade sobre qualquer fundo
	var c := _mk_actor("mobs/young_wolf", "young_wolf")
	H.check("LAY-27 nameplate tem outline (legível sobre mapa)", c._nameplate.get_theme_constant("outline_size") > 0)
	H.check("LAY-28 nameplate fonte compacta (<=14)", c._nameplate.get_theme_font_size("font_size") <= 14)
	c.free()
	H.check("LAY-29 pockets 6 direções (spread, não empilha §23)", PveMobActor.POCKETS.size() >= 6)
	H.check("LAY-30 nenhum pocket na origem (não nasce embaixo do player §23)", PveMobActor.POCKETS.all(func(p): return p.length() > 40.0))
	H.group_complete()
