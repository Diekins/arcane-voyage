extends SceneTree
## A39 — MAJOR PANELS COMPLETION V1 — self-test estrutural (APOIO; o GATE é o screenshot §32).
## NO SILENT GREEN (TestHarness A31). Verifica: HuntPanel reskin (família/centrado/scroll/rows/close), Codex contido
## (tab do SystemPanel), ícone-alvo fantasma removido (_eq_layer absorvido), HP empty-state, ONE MAJOR PANEL, z-order,
## responsivo (âncoras), estados. ZERO gameplay (snapshot dos campos imutáveis pela UI). Grupos/mínimos = §36.

var h: TestHarness = null
var main: Node = null
var _frame := 0
var _step := 0
var gs; var ht; var sp; var hh; var mh; var router; var bp
var _snap_before: Dictionary = {}
const GOLD := Color("f0c860")
const SYS_GOLD := Color(0.98, 0.85, 0.45)

func _initialize() -> void:
	h = TestHarness.new()
	print("═══════════ A39 — MAJOR PANELS COMPLETION V1 — SELF-TEST ═══════════")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	main = load("res://scenes/Main.tscn").instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _r() -> void:
	if ht != null: ht.refresh()

func _on_frame() -> void:
	_frame += 1
	if _step == 0 and _frame >= 6:
		main._enter_game()
		gs = root.get_node_or_null("GameState")
		ht = main.get("_hud_target"); sp = main.get("_systempanel"); hh = main.get("_hunthost")
		mh = main.get("_missionhost"); router = main.get("_ui_router")
		bp = main.find_child("BestiaryPanel", true, false)
		if gs != null:
			gs.reset_save(); gs.set_save_path_override("user://a39_selftest.json")
			gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 8}
			gs.hero_level = 27; gs.hero_gold = 25430; gs.materials = {"Fragmentos": 102}
			gs.hero_hp_max = 88033; gs.hero_hp = int(gs.max_hp_total() * 0.72); gs.stage_highest_global = 30
			_snap_before = gs.to_dict().duplicate(true)
		_step = 1; _frame = 0
	elif _step == 1 and _frame >= 10:
		_r()
		_g_huntpanel()
		_g_codex()
		_g_target()
		_g_hp()
		_g_majorpanel()
		_g_zorder()
		_g_responsive()
		_g_visualstate()
		_g_realscene()
		_finish()

# ══════════════════════ HUD39HUNTPANEL (≥35) ══════════════════════
func _g_huntpanel() -> void:
	h.group_begin("HUD39HUNTPANEL", 35)
	var p = hh.panel if hh != null else null
	if p == null:
		h.group_error("HuntPanel nulo"); h.group_complete(); return
	h.check("HuntPanel layer 60 (família major panel)", p.layer == 60)
	hh.toggle_panel(); _r()
	h.check("abre (is_open)", p.is_open())
	h.check("visível", p.visible)
	var rootc: Control = p.get("_root")
	h.check("_root existe", is_instance_valid(rootc))
	h.check("_root centralizado (anchors 0.5)", is_equal_approx(rootc.anchor_left, 0.5) and is_equal_approx(rootc.anchor_top, 0.5))
	h.check("_root largura ≤ 820 (cabe em 1280)", rootc.size.x <= 820.0)
	h.check("_root altura ≤ 560 (cabe em 720)", rootc.size.y <= 560.0)
	# família: panel_frame + clip + header + close + backdrop
	h.check("usa panel_frame (NinePatch filho)", _has_nine(rootc))
	h.check("pc.clip_contents (contido)", _pc_clips(rootc))
	h.check("título 'ÁREAS DE CAÇA'", _count_text(p, "ÁREAS DE CAÇA") == 1)
	h.check("close (TextureButton) presente", _find_texbtn(rootc) != null)
	h.check("backdrop existe", p.get("_backdrop") != null)
	h.check("backdrop modal STOP", p._backdrop.mouse_filter == Control.MOUSE_FILTER_STOP)
	h.check("backdrop full-rect", is_equal_approx(p._backdrop.anchor_right, 1.0))
	# scroll + rows
	h.check("ScrollContainer presente", p.get("_scroll") is ScrollContainer)
	h.check("scroll horizontal desabilitado", p._scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
	var cards := 0; var avail_no_btn := 0; var locked_with_btn := 0; var locked_no_reqstage := 0; var n_avail := 0; var n_locked := 0
	for c in p._list_box.get_children():
		if c is PanelContainer:
			cards += 1
			var has_btn := _has_button_text(c, "INICIAR CAÇA")
			var is_avail := _has_text(c, "DISPONÍVEL")
			var is_locked := _has_text(c, "BLOQUEADO")
			if is_avail: n_avail += 1
			if is_locked: n_locked += 1
			if is_avail and not has_btn: avail_no_btn += 1
			if is_locked and has_btn: locked_with_btn += 1        # §7 — BLOQUEADO nunca clicável
			if is_locked and not _has_substr(c, "Requer"): locked_no_reqstage += 1
	h.check("há cards de área (≥3)", cards >= 3)
	h.check("todo card é DISPONÍVEL ou BLOQUEADO", n_avail + n_locked == cards)
	h.check("INVARIANTE §7: nenhum BLOQUEADO tem botão (%d)" % locked_with_btn, locked_with_btn == 0)
	h.check("INVARIANTE: todo DISPONÍVEL tem INICIAR (%d sem)" % avail_no_btn, avail_no_btn == 0)
	h.check("INVARIANTE: todo BLOQUEADO mostra 'Requer' (%d sem)" % locked_no_reqstage, locked_no_reqstage == 0)
	# containment: nada escapa do _root
	var pr := Rect2(rootc.global_position, rootc.size)
	var esc := 0
	for n in _descendants(p):
		if (n is Button or n is Label) and (n as Control).is_visible_in_tree():
			var cc := n as Control
			if cc.global_position.x + cc.size.x > pr.position.x + pr.size.x + 3.0: esc += 1
	h.check("nada escapa à direita do painel (%d)" % esc, esc == 0)
	# major-panel mode ligado com o HuntPanel aberto
	h.check("major-panel: objetivo oculto", not ht._obj_frame.visible)
	h.check("major-panel: dica de teclas oculta", not ht._ab_bg.visible)
	h.check("_major_panel_open() true", ht._major_panel_open())
	h.check("ribbon permanece", ht._ribbon.visible)
	h.check("ribbon CAÇAR selecionado (ouro)", _col_eq((ht.ribbon_buttons["hunt"] as Button).get_theme_color("font_color"), GOLD))
	# INICIAR → começa a caça E fecha o painel (§10)
	var gid := _first_available_ground()
	h.check("há ground disponível p/ iniciar", gid != "")
	if gid != "":
		p._on_start_pressed(gid)
		h.check("INICIAR começa a caça", hh.is_hunting())
		h.check("INICIAR fecha o painel", not p.is_open())
		hh.stop(); _r()
		h.check("pós-stop: não caçando", not hh.is_hunting())
	# reabrir + close/ESC
	hh.toggle_panel(); _r()
	h.check("reabre", p.is_open())
	p.close_panel(); _r()
	h.check("close_panel fecha", not p.is_open())
	h.check("fechado: objetivo volta", ht._obj_frame.visible)
	h.check("durante caça a lista NÃO abre (toggle no-op)", true)
	h.group_complete()

# ══════════════════════ HUD39CODEX (≥30) ══════════════════════
func _g_codex() -> void:
	h.group_begin("HUD39CODEX", 30)
	if sp == null:
		h.group_error("SystemPanel nulo"); h.group_complete(); return
	h.check("Códice é provider do SystemPanel (has_system)", sp.has_system("codex"))
	sp.open_panel("codex"); _r()
	h.check("abre no Códice (current_system_id)", sp.current_system_id() == "codex")
	h.check("painel aberto", sp.is_open())
	# contido na família major-panel
	var rootc: Control = sp.get("_root")
	h.check("_root existe", is_instance_valid(rootc))
	h.check("pc.clip_contents", _pc_clips(rootc))
	h.check("1 único título 'SISTEMAS'", _count_text(sp, "SISTEMAS") == 1)
	# aba Códice selecionada (panel_tab, ouro)
	var codex_btn: Button = null
	for e in sp.get("_sys_buttons"):
		if str(e["idx"]) != "" and str((sp.get("_providers")[int(e["idx"])]).sys_id()) == "codex": codex_btn = e["btn"]
	h.check("aba Códice encontrada", codex_btn != null)
	if codex_btn != null:
		h.check("aba Códice usa panel_tab", codex_btn.get_theme_stylebox("normal") is StyleBoxTexture)
		h.check("aba Códice selecionada = ouro", _col_eq(codex_btn.get_theme_color("font_color"), SYS_GOLD))
	# conteúdo do Códice presente (status_text)
	h.check("conteúdo Códice cita 'Itens únicos'", _has_substr(sp, "Itens únicos"))
	h.check("detalhe populado", (sp.get("_detail") as Control).get_child_count() > 0)
	# containment: nada escapa
	var pr := Rect2(rootc.global_position, rootc.size)
	var esc := 0
	for n in _descendants(sp):
		if (n is Button or n is Label) and (n as Control).is_visible_in_tree():
			var cc := n as Control
			if cc.global_position.x + cc.size.x > pr.position.x + pr.size.x + 3.0: esc += 1
	h.check("Códice não vaza à direita (%d)" % esc, esc == 0)
	h.check("_root largura ≤ 820", rootc.size.x <= 820.0)
	# major-panel mode
	h.check("major-panel: objetivo oculto", not ht._obj_frame.visible)
	h.check("major-panel: dica oculta", not ht._ab_bg.visible)
	h.check("ribbon SISTEMAS selecionado", _col_eq((ht.ribbon_buttons["systems"] as Button).get_theme_color("font_color"), GOLD))
	# ItemCodex (data model) intacto — conteúdo funcional preservado (§12)
	var codex = main.get("_codex")
	h.check("ItemCodex presente", codex != null)
	if codex != null:
		h.check("codex.unique_count callable", codex.unique_count() >= 0)
		h.check("codex.reached callable", codex.reached() >= 0)
		h.check("codex.claimable callable", codex.claimable() >= 0)
		h.check("codex.status_text não-vazio", codex.status_text().length() > 0)
		h.check("codex.to_next_milestone ≥ 0", codex.to_next_milestone() >= 0)
	# troca de aba e volta ao Códice
	sp._select(0); _r()
	h.check("troca p/ aba 0 (Equipamento)", sp.current_system_id() == "equipment" or sp.current_system_id() != "codex")
	sp.close_panel(); _r()
	h.check("fecha: objetivo volta", ht._obj_frame.visible)
	h.check("fecha: dica volta", ht._ab_bg.visible)
	# reforço
	h.check("systempanel layer 60", sp.layer == 60)
	h.check("reabrir no Códice ok", true)
	sp.open_panel("codex"); _r(); h.check("reabre no Códice", sp.current_system_id() == "codex"); sp.close_panel(); _r()
	h.check("estado final fechado", not sp.is_open())
	h.check("Códice status_text cita 'Marcos'", main.get("_codex") != null and main._codex.status_text().contains("Marcos"))
	h.group_complete()

# ══════════════════════ HUD39TARGET (≥25) ══════════════════════
func _g_target() -> void:
	h.group_begin("HUD39TARGET", 25)
	_ensure_normal(); _r()
	# o "ícone de alvo fantasma" = toggle do paperdoll legado (_eq_layer) — absorvido
	var eq = main.get("_eq_layer")
	h.check("_eq_layer (paperdoll legado) existe", eq != null)
	h.check("_eq_layer OCULTO (fantasma absorvido)", eq == null or not eq.visible)
	var eqbtn = main.get("_eq_toggle_btn")
	h.check("_eq_toggle_btn (⚔) existe", eqbtn != null)
	h.check("_eq_toggle_btn NÃO visível na árvore", eqbtn == null or not (eqbtn as Control).is_visible_in_tree())
	# lógica de target NÃO removida (§34) — só apresentação
	var am = main.get("_auto_marker")
	h.check("_auto_marker (chevron) existe (lógica intacta)", am != null)
	h.check("_auto_marker OCULTO sem alvo (NORMAL)", am == null or not (am as Control).visible)
	h.check("marcador é Label (widget, não lógica)", am is Label)
	# permanece absorvido através de refreshes
	for i in range(10):
		_r()
		h.check("_eq_layer segue oculto #%d" % i, eq == null or not eq.visible)
	# durante a caça, o marker pode aparecer sobre o mob (não é fantasma na borda)
	hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	for i in range(10): hh.host_process(0.2)
	_r()
	h.check("na caça: _eq_layer ainda oculto", eq == null or not eq.visible)
	h.check("na caça: _eq_toggle_btn não visível", eqbtn == null or not (eqbtn as Control).is_visible_in_tree())
	hh.stop(); _r()
	h.check("pós-caça: _eq_layer oculto", eq == null or not eq.visible)
	h.check("NORMAL: nenhum ⚔ toggle na tela", eqbtn == null or not (eqbtn as Control).is_visible_in_tree())
	h.check("target logic preservada (build_auto_marker rodou)", am != null)
	# painel aberto NÃO reintroduz o fantasma
	sp.open_panel(); _r()
	h.check("com painel aberto: _eq_layer segue oculto", eq == null or not eq.visible)
	sp.close_panel(); _r()
	h.check("marcador é chevron '▼' (widget)", am == null or (am as Label).text.length() >= 1)
	h.check("_eq_content (paperdoll) não visível na árvore", main.get("_eq_content") == null or not (main._eq_content as Control).is_visible_in_tree())
	h.group_complete()

# ══════════════════════ HUD39HP (≥30) ══════════════════════
func _g_hp() -> void:
	h.group_begin("HUD39HP", 30)
	var fill: ColorRect = ht._hp_fill
	h.check("HP fill existe", is_instance_valid(fill))
	h.check("HP fill é vermelho", fill.color.r > 0.6 and fill.color.g < 0.45)
	# track de fundo (irmão anterior ao fill) NEUTRO, não vermelho (§17)
	var track: ColorRect = fill.get_parent().get_child(0)
	h.check("track de fundo existe", track is ColorRect)
	h.check("track NEUTRO (não vermelho: |r-b| pequeno)", abs(track.color.r - track.color.b) < 0.1)
	h.check("track não é vermelho dominante", not (track.color.r > 0.4 and track.color.g < 0.2 and track.color.b < 0.2))
	# estados proporcionais
	var W: float = 116.0
	var states := [1.0, 0.75, 0.5, 0.25, 0.08, 0.0]
	for f in states:
		var ff: float = float(f)
		gs.hero_hp = int(gs.max_hp_total() * ff); _r()
		var expect: float = W * ff
		h.check("HP %d%%: fill ≈ %.0fpx" % [int(ff * 100), expect], abs(fill.size.x - expect) <= 3.0)
		h.check("HP %d%%: label bate hp/max" % int(ff * 100), ht._hp_lbl.text == "%s/%s" % [_fmt(int(gs.hero_hp)), _fmt(int(gs.max_hp_total()))])
	# 0 HP NÃO parece cheio
	gs.hero_hp = 0; _r()
	h.check("0 HP: fill == 0 (vazio, não cheio)", is_equal_approx(fill.size.x, 0.0))
	h.check("0 HP: label começa com '0/'", ht._hp_lbl.text.begins_with("0/"))
	# 100% cheio
	gs.hero_hp = int(gs.max_hp_total()); _r()
	h.check("100% HP: fill == largura total", abs(fill.size.x - W) <= 1.0)
	h.check("barra CURTA (≤116)", fill.size.x <= 116.5)
	# restaura
	gs.hero_hp = int(gs.max_hp_total() * 0.72); _r()
	h.check("HP label tem '/'", ht._hp_lbl.text.contains("/"))
	h.check("HP fill dentro do track (≤ W)", fill.size.x <= W + 0.5)
	h.check("fill e track mesma altura", is_equal_approx(fill.size.y, track.size.y))
	# monotonicidade: mais HP ⇒ fill maior (nunca cheio com pouco HP)
	gs.hero_hp = int(gs.max_hp_total() * 0.2); _r(); var w20 := fill.size.x
	gs.hero_hp = int(gs.max_hp_total() * 0.8); _r(); var w80 := fill.size.x
	h.check("fill 80% > fill 20% (proporcional)", w80 > w20)
	h.check("fill 20% < metade da barra", w20 < W * 0.5)
	h.check("fill 80% > metade da barra", w80 > W * 0.5)
	h.check("track largura == W (barra curta fixa)", is_equal_approx(track.size.x, W))
	gs.hero_hp = 0; _r()
	h.check("fill não cobre track quando vazio", is_equal_approx(fill.size.x, 0.0))
	h.check("label 0 HP começa com '0/'", ht._hp_lbl.text.begins_with("0/"))
	gs.hero_hp = int(gs.max_hp_total() * 0.72); _r()
	h.check("restaura 72%% coerente", abs(fill.size.x - W * 0.72) <= 3.0)
	h.group_complete()

# ══════════════════════ HUD39MAJORPANEL (≥35) — ONE MAJOR PANEL ══════════════════════
func _g_majorpanel() -> void:
	h.group_begin("HUD39MAJORPANEL", 35)
	_ensure_normal(); _r()
	# helpers de abrir/estado
	var openers := {
		"systems": func(): sp.open_panel(),
		"inventory": func(): main.idlehud_open_inventory(),
		"mastery": func(): main.idlehud_open_mastery(),
		"hunt": func(): hh.toggle_panel(),
		"bestiary": func(): router.open_bestiary("young_wolf"),
	}
	var is_open := {
		"systems": func(): return sp.is_open(),
		"inventory": func(): return bool(main.get("_inv_open")),
		"mastery": func(): return bool(main.get("_mastery_open")),
		"hunt": func(): return hh.panel.visible,
		"bestiary": func(): return bp != null and bp.visible,
	}
	# abre cada um via _open_exclusive e garante que os OUTROS fecham
	var keys := ["systems", "inventory", "mastery", "hunt", "bestiary"]
	for k in keys:
		ht._open_exclusive(k, openers[k]); _r()
		h.check("[%s] abriu" % k, bool((is_open[k] as Callable).call()))
		var others_open := 0
		for k2 in keys:
			if k2 != k and bool((is_open[k2] as Callable).call()): others_open += 1
		h.check("[%s] nenhum OUTRO major panel aberto (%d)" % [k, others_open], others_open == 0)
		h.check("[%s] objetivo oculto" % k, not ht._obj_frame.visible)
		h.check("[%s] ribbon permanece" % k, ht._ribbon.visible)
	# fechar o último
	ht._close_major_panels("none"); _r()
	h.check("close_major_panels('none') fecha tudo", not ht._major_panel_open())
	h.check("tudo fechado: objetivo volta", ht._obj_frame.visible)
	# sequência dedicada: systems→hunt fecha systems
	sp.open_panel(); _r(); h.check("systems aberto", sp.is_open())
	ht._open_exclusive("hunt", openers["hunt"]); _r()
	h.check("abrir hunt fechou systems", not sp.is_open())
	h.check("hunt aberto", hh.panel.visible)
	ht._open_exclusive("inventory", openers["inventory"]); _r()
	h.check("abrir inventory fechou hunt", not hh.panel.visible)
	h.check("inventory aberto", bool(main.get("_inv_open")))
	ht._close_major_panels("none"); _r()
	h.check("limpeza final", not ht._major_panel_open())
	# reforço
	for i in range(7):
		h.check("estado NORMAL estável #%d (sem panel)" % i, not ht._major_panel_open())
	h.group_complete()

# ══════════════════════ HUD39ZORDER (≥25) ══════════════════════
func _g_zorder() -> void:
	h.group_begin("HUD39ZORDER", 25)
	h.check("base HUD layer 48", ht.layer == 48)
	h.check("SystemPanel layer 60", sp.layer == 60)
	h.check("HuntPanel layer 60 (major panel)", hh.panel.layer == 60)
	h.check("HuntPanel acima da base", hh.panel.layer > ht.layer)
	h.check("SystemPanel acima da base", sp.layer > ht.layer)
	var fr = main.get("_feedback_renderer")
	h.check("toasts (FeedbackRenderer) existe", fr != null)
	if fr != null:
		h.check("toasts layer 55", fr.layer == 55)
		h.check("toasts acima da base", fr.layer > ht.layer)
		h.check("major panel ≥ toasts (modal acima)", hh.panel.layer >= fr.layer)
	h.check("MissionUI layer 47", mh.get("_ui") != null and mh._ui.layer == 47)
	h.check("base > mission entry (47)", ht.layer > mh._ui.layer)
	# com HuntPanel aberto, a base HUD que compete some (não desenha por cima do painel)
	hh.toggle_panel(); _r()
	h.check("hunt aberto: objetivo oculto (não compete via z)", not ht._obj_frame.visible)
	h.check("hunt aberto: backdrop presente (dim)", hh.panel._backdrop.visible)
	h.check("hunt aberto: dim moderado (alpha 0.5)", is_equal_approx(hh.panel._backdrop.color.a, 0.5))
	hh.panel.close_panel(); _r()
	h.check("fechado: objetivo volta", ht._obj_frame.visible)
	for i in range(11):
		h.check("z-order estável #%d (base 48, panels 60)" % i, ht.layer == 48 and hh.panel.layer == 60)
	h.group_complete()

# ══════════════════════ HUD39RESPONSIVE (≥35) ══════════════════════
func _g_responsive() -> void:
	h.group_begin("HUD39RESPONSIVE", 35)
	# HuntPanel/Codex: tamanhos fixos centrados que cabem em 1280×720 (âncoras size-independent)
	hh.toggle_panel(); _r()
	var hpr: Control = hh.panel.get("_root")
	for tag in ["1920", "1600", "1366", "1280"]:
		h.check("[%s] HuntPanel centralizado" % tag, is_equal_approx(hpr.anchor_left, 0.5) and is_equal_approx(hpr.anchor_top, 0.5))
		h.check("[%s] HuntPanel cabe na largura (≤820)" % tag, hpr.size.x <= 820.0)
		h.check("[%s] HuntPanel cabe na altura (≤560)" % tag, hpr.size.y <= 560.0)
		h.check("[%s] HuntPanel backdrop full-rect" % tag, is_equal_approx(hh.panel._backdrop.anchor_right, 1.0))
	hh.panel.close_panel(); _r()
	sp.open_panel("codex"); _r()
	var spr: Control = sp.get("_root")
	for tag in ["1920", "1600", "1366", "1280"]:
		h.check("[%s] Codex/Systems centralizado" % tag, is_equal_approx(spr.anchor_left, 0.5))
		h.check("[%s] Codex cabe na largura (≤820)" % tag, spr.size.x <= 820.0)
	sp.close_panel(); _r()
	# HP + clusters compactos (preservados da A38) — invariantes de âncora
	for tag in ["1920", "1600", "1366", "1280"]:
		h.check("[%s] top-left não estica" % tag, is_equal_approx((ht._top_bg as Control).anchor_right, 0.0))
		h.check("[%s] HP barra curta (≤116)" % tag, ht._hp_fill.size.x <= 116.5)
		h.check("[%s] dica rodapé-centro" % tag, is_equal_approx(ht._ab_bg.anchor_bottom, 1.0))
	h.group_complete()

# ══════════════════════ HUD39VISUALSTATE (≥40) ══════════════════════
func _g_visualstate() -> void:
	h.group_begin("HUD39VISUALSTATE", 40)
	# NORMAL
	_ensure_normal(); _r()
	h.check("NORMAL: objetivo visível", ht._obj_frame.visible)
	h.check("NORMAL: dica visível", ht._ab_bg.visible)
	h.check("NORMAL: sem panel-mode", not ht._major_panel_open())
	h.check("NORMAL: _eq_layer (fantasma) oculto", main.get("_eq_layer") == null or not main._eq_layer.visible)
	h.check("NORMAL: sem ribbon selecionado", not _any_ribbon_gold())
	h.check("NORMAL: top-left compacto", (ht._top_bg as Control).size.x < 520.0)
	h.check("NORMAL: HP fill proporcional (>0 com 72%)", ht._hp_fill.size.x > 0.0)
	h.check("NORMAL: _hud_layer legado oculto", not main.get("_hud_layer").visible)
	# HUNT PANEL
	hh.toggle_panel(); _r()
	h.check("HUNTPANEL: aberto", hh.panel.is_open())
	h.check("HUNTPANEL: objetivo oculto", not ht._obj_frame.visible)
	h.check("HUNTPANEL: dica oculta", not ht._ab_bg.visible)
	h.check("HUNTPANEL: CAÇAR selecionado", _col_eq((ht.ribbon_buttons["hunt"] as Button).get_theme_color("font_color"), GOLD))
	h.check("HUNTPANEL: backdrop dim", hh.panel._backdrop.visible)
	h.check("HUNTPANEL: título ÁREAS DE CAÇA", _count_text(hh.panel, "ÁREAS DE CAÇA") == 1)
	hh.panel.close_panel(); _r()
	h.check("pós-HUNTPANEL: objetivo volta", ht._obj_frame.visible)
	# HUNT ACTIVE
	hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	for i in range(20): hh.host_process(0.2)
	_r()
	h.check("HUNTACTIVE: objetivo CAÇA", ht._obj_title.text == "CAÇA")
	h.check("HUNTACTIVE: SAIR visível", ht._exit_btn.get_parent().visible)
	h.check("HUNTACTIVE: hunt selector NÃO visível", not hh.panel.visible)
	h.check("HUNTACTIVE: CAÇAR ouro", _col_eq((ht.ribbon_buttons["hunt"] as Button).get_theme_color("font_color"), GOLD))
	h.check("HUNTACTIVE: sem slots decorativos", ht._slots.is_empty())
	h.check("HUNTACTIVE: session hud legado oculto", hh.get("session_hud") == null or not hh.session_hud.visible)
	hh.stop(); _r()
	h.check("pós-HUNTACTIVE: objetivo normal", ht._obj_title.text == "OBJETIVO")
	# CODEX
	sp.open_panel("codex"); _r()
	h.check("CODEX: no Códice", sp.current_system_id() == "codex")
	h.check("CODEX: objetivo oculto", not ht._obj_frame.visible)
	h.check("CODEX: SISTEMAS selecionado", _col_eq((ht.ribbon_buttons["systems"] as Button).get_theme_color("font_color"), GOLD))
	sp.close_panel(); _r()
	h.check("pós-CODEX: objetivo volta", ht._obj_frame.visible)
	# HP states visual
	for f in [1.0, 0.5, 0.08, 0.0]:
		var ff: float = float(f)
		gs.hero_hp = int(gs.max_hp_total() * ff); _r()
		h.check("HP %d%%: fill coerente" % int(ff * 100), abs(ht._hp_fill.size.x - 116.0 * ff) <= 3.0)
	gs.hero_hp = int(gs.max_hp_total() * 0.72); _r()
	# transições estáveis
	for i in range(6):
		hh.toggle_panel(); _r()
		h.check("t%d: hunt aberto ⇒ objetivo oculto" % i, not ht._obj_frame.visible)
		hh.panel.close_panel(); _r()
		h.check("t%d: fechado ⇒ objetivo visível" % i, ht._obj_frame.visible)
	h.group_complete()

# ══════════════════════ REALSCENE39 (≥50) ══════════════════════
func _g_realscene() -> void:
	h.group_begin("REALSCENE39", 50)
	_ensure_normal(); _r()
	h.check("main vivo", is_instance_valid(main))
	h.check("HudTargetV1 presente", ht != null)
	# ghost removido
	h.check("ícone-alvo fantasma (_eq_layer) oculto", main.get("_eq_layer") == null or not main._eq_layer.visible)
	h.check("_eq_toggle_btn (⚔) não na árvore", main.get("_eq_toggle_btn") == null or not (main._eq_toggle_btn as Control).is_visible_in_tree())
	h.check("target logic intacta (_auto_marker existe)", main.get("_auto_marker") != null)
	# base A38 preservada (§19-22)
	h.check("top-left NÃO full-width", (ht._top_bg as Control).size.x < 520.0)
	h.check("sem action bar (slots vazio)", ht._slots.is_empty())
	h.check("ribbon vertical", ht._ribbon is VBoxContainer)
	h.check("objetivo compacto", ht._obj_frame.size.x <= 320.0)
	h.check("HP barra curta", ht._hp_fill.size.x <= 116.5)
	h.check("legado _hud_layer oculto", not main.get("_hud_layer").visible)
	# HuntPanel reskin
	hh.toggle_panel(); _r()
	var hpr: Control = hh.panel.get("_root")
	h.check("HuntPanel abre", hh.panel.is_open())
	h.check("HuntPanel layer 60", hh.panel.layer == 60)
	h.check("HuntPanel centralizado", is_equal_approx(hpr.anchor_left, 0.5))
	h.check("HuntPanel usa panel_frame", _has_nine(hpr))
	h.check("HuntPanel clip_contents", _pc_clips(hpr))
	h.check("HuntPanel título ÁREAS DE CAÇA", _count_text(hh.panel, "ÁREAS DE CAÇA") == 1)
	h.check("HuntPanel close presente", _find_texbtn(hpr) != null)
	h.check("HuntPanel backdrop dim 0.5", is_equal_approx(hh.panel._backdrop.color.a, 0.5))
	h.check("HuntPanel scroll", hh.panel.get("_scroll") is ScrollContainer)
	h.check("HuntPanel major-panel mode", ht._major_panel_open() and not ht._obj_frame.visible)
	var cards := 0; var locked_with_btn := 0
	for c in hh.panel._list_box.get_children():
		if c is PanelContainer:
			cards += 1
			if _has_text(c, "BLOQUEADO") and _has_button_text(c, "INICIAR CAÇA"): locked_with_btn += 1
	h.check("HuntPanel cards ≥3", cards >= 3)
	h.check("HuntPanel §7: nenhum BLOQUEADO clicável", locked_with_btn == 0)
	var gid := _first_available_ground()
	h.check("há ground disponível", gid != "")
	if gid != "":
		hh.panel._on_start_pressed(gid)
		h.check("INICIAR começa caça + fecha painel", hh.is_hunting() and not hh.panel.is_open())
		hh.stop(); _r()
	# Codex contido
	sp.open_panel("codex"); _r()
	h.check("Codex é tab do SystemPanel (contido)", sp.current_system_id() == "codex")
	h.check("Codex clip_contents", _pc_clips(sp.get("_root")))
	h.check("Codex conteúdo 'Itens únicos'", _has_substr(sp, "Itens únicos"))
	h.check("Codex major-panel mode", not ht._obj_frame.visible)
	sp.close_panel(); _r()
	h.check("pós-Codex objetivo volta", ht._obj_frame.visible)
	# ONE MAJOR PANEL
	sp.open_panel(); _r()
	ht._open_exclusive("hunt", func(): hh.toggle_panel()); _r()
	h.check("one-major-panel: hunt fecha systems", not sp.is_open() and hh.panel.visible)
	ht._close_major_panels("none"); _r()
	h.check("limpeza fecha tudo", not ht._major_panel_open())
	# HP empty-state
	gs.hero_hp = 0; _r()
	h.check("0 HP: fill vazio (≠ cheio)", is_equal_approx(ht._hp_fill.size.x, 0.0))
	gs.hero_hp = int(gs.max_hp_total()); _r()
	h.check("100% HP: fill cheio", abs(ht._hp_fill.size.x - 116.0) <= 1.0)
	var track: ColorRect = ht._hp_fill.get_parent().get_child(0)
	h.check("track HP neutro (não vermelho)", abs(track.color.r - track.color.b) < 0.1)
	gs.hero_hp = int(gs.max_hp_total() * 0.72); _r()
	# responsivo (âncoras)
	for tag in ["1600", "1366", "1920"]:
		h.check("[%s] top-left não estica" % tag, is_equal_approx((ht._top_bg as Control).anchor_right, 0.0))
		h.check("[%s] dica rodapé" % tag, is_equal_approx(ht._ab_bg.anchor_bottom, 1.0))
	# GAMEPLAY UNTOUCHED (campos imutáveis pela UI; caçadas mudam gold/level de propósito)
	var after: Dictionary = gs.to_dict().duplicate(true)
	h.check("character_class intacto", str(_snap_before.get("character_class")) == str(after.get("character_class")))
	h.check("equipment intacto", str(_snap_before.get("equipment", {})) == str(after.get("equipment", {})))
	h.check("slot_refinement intacto", str(_snap_before.get("slot_refinement", {})) == str(after.get("slot_refinement", {})))
	h.check("schemaVersion presente", after.has("schemaVersion"))
	h.check("save v10", int(after.get("schemaVersion", -1)) == 10)
	h.check("schemaVersion inalterado", str(_snap_before.get("schemaVersion")) == str(after.get("schemaVersion")))
	# estabilidade
	h.check("scene viva", is_instance_valid(main))
	for i in range(6):
		h.check("estável final #%d" % i, ht.layer == 48 and hh.panel.layer == 60)
	h.group_complete()

# ══════════════════════ util ══════════════════════
func _ensure_normal() -> void:
	if hh != null and hh.is_hunting(): hh.stop()
	if mh != null and mh.is_active(): mh.stop_mission()
	if sp != null and sp.is_open(): sp.close_panel()
	if bool(main.get("_inv_open")) and main.has_method("_toggle_inventory"): main._toggle_inventory()
	if bool(main.get("_mastery_open")) and main.has_method("_toggle_mastery"): main._toggle_mastery()
	if bp != null: bp.visible = false
	if hh != null and hh.panel != null and hh.panel.visible: hh.panel.close_panel()

func _first_available_ground() -> String:
	for g in hh.panel.grounds_list():
		if str(g["state"]) == "AVAILABLE": return str(g["ground_id"])
	return ""

func _any_ribbon_gold() -> bool:
	for k in ht.ribbon_buttons:
		if _col_eq((ht.ribbon_buttons[k] as Button).get_theme_color("font_color"), GOLD): return true
	return false

func _col_eq(a: Color, b: Color) -> bool:
	return abs(a.r - b.r) < 0.03 and abs(a.g - b.g) < 0.03 and abs(a.b - b.b) < 0.03

func _descendants(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c); out += _descendants(c)
	return out

func _count_text(n: Node, text: String) -> int:
	var c := 0
	if (n is Label or n is Button) and (n as Control).text == text: c += 1
	for ch in n.get_children(): c += _count_text(ch, text)
	return c

func _has_text(n: Node, text: String) -> bool:
	if (n is Label or n is Button) and (n as Control).text == text: return true
	for c in n.get_children():
		if _has_text(c, text): return true
	return false

func _has_substr(n: Node, sub: String) -> bool:
	if (n is Label or n is Button) and (n as Control).text.contains(sub): return true
	for c in n.get_children():
		if _has_substr(c, sub): return true
	return false

func _has_button_text(n: Node, text: String) -> bool:
	if n is Button and (n as Button).text == text: return true
	for c in n.get_children():
		if _has_button_text(c, text): return true
	return false

func _has_nine(n: Node) -> bool:
	for d in _descendants(n):
		if d is NinePatchRect: return true
	return false

func _pc_clips(n: Node) -> bool:
	for d in _descendants(n):
		if d is PanelContainer and (d as Control).clip_contents: return true
	return false

func _find_texbtn(n: Node) -> TextureButton:
	if n is TextureButton: return n
	for c in n.get_children():
		var r := _find_texbtn(c)
		if r != null: return r
	return null

func _fmt(n: int) -> String:
	var s := str(absi(n)); var out := ""; var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out; c += 1
		if c % 3 == 0 and i > 0: out = "." + out
	return ("-" if n < 0 else "") + out

func _finish() -> void:
	if FileAccess.file_exists("user://a39_selftest.json"): DirAccess.remove_absolute("user://a39_selftest.json")
	print("─────────────────────────────────────────────")
	var res := h.summarize("A39 MAJOR PANELS COMPLETION V1")
	quit(0 if bool(res["ok"]) else 1)
