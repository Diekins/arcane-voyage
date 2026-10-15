extends SceneTree
## A37 — HUD POLISH CLOSEOUT — self-test NO-SILENT-GREEN (TestHarness A31).
## 9 grupos: HUD37SYSTEMS·HUD37TABS·HUD37OFFLINE·HUD37TRANSIENT·HUD37TYPO·HUD37LAYOUT·HUD37RESPONSIVE·HUD37SCREEN·REALSCENE37.
## PUROS rodam em _initialize; os de CENA bootam Main.tscn por frames. NÃO altera gameplay (prova por snapshot).
## Screenshots: passe --shot-dir=<abs>; default = user:// (pasta de dados do Godot). Faltando ⇒ FAIL honesto (sem verde silencioso).

const SHOT_DEFAULT := "user://"
const GOLD := Color(0.98, 0.85, 0.45)

var h: TestHarness = null
var _dir := SHOT_DEFAULT
var main: Node = null
var _frame := 0
var _step := 0
var gs = null
var ht = null
var sp: SystemPanel = null
var bp: BestiaryPanel = null
var fr: FeedbackRenderer = null
var router = null
var _snap_before: Dictionary = {}

# ── bus falso p/ exercitar o card de toast de forma determinística (sem depender do scene bus) ──
class FakeBus:
	var remaining := 0
	var color := ""
	var kind := ""
	func next_toast() -> Dictionary:
		if remaining <= 0: return {}
		remaining -= 1
		return {"text": "MENSAGEM", "kind": kind, "color": color}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="): _dir = a.substr("--shot-dir=".length())
	h = TestHarness.new()
	print("═══════════ A37 — HUD POLISH CLOSEOUT — SELF-TEST ═══════════")
	# ---- grupos PUROS (sem cena) ----
	_g_offline()
	_g_tabs()
	_g_transient()
	_g_typo()
	_g_layout()
	_g_screen()
	# ---- grupos de CENA ----
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	process_frame.connect(_on_frame)

# ════════════════════════ HUD37OFFLINE (≥25) ════════════════════════
func _g_offline() -> void:
	h.group_begin("HUD37OFFLINE", 25)
	var cases := [
		{"seconds": 3600, "gold": 1200, "xp": 400, "items": 0, "materials": 0, "exceptional_name": ""},
		{"seconds": 7200, "gold": 55000, "xp": 9000, "items": 3, "materials": 12, "exceptional_name": ""},
		{"seconds": 120, "gold": 40, "xp": 8, "items": 0, "materials": 2, "exceptional_name": ""},
		{"seconds": 86400, "gold": 2400000, "xp": 990000, "items": 7, "materials": 40, "exceptional_name": ""},
		{"seconds": 5400, "gold": 8000, "xp": 3000, "items": 1, "materials": 0, "exceptional_name": "Lâmina Eterna"},
		{"seconds": 60, "gold": 10, "xp": 2, "items": 0, "materials": 0, "exceptional_name": "Elmo Rúnico"},
	]
	for s in cases:
		var out := FeedbackFormat.offline(s)
		var lines := out.split("\n")
		var exc := str(s["exceptional_name"]) != ""
		var has_extra := int(s["items"]) > 0 or int(s["materials"]) > 0
		h.check("offline compacto ≤2 linhas (%ds)" % int(s["seconds"]), lines.size() <= 2)
		h.check("offline tem 'Ausente' (%ds)" % int(s["seconds"]), out.contains("Ausente"))
		h.check("offline tem 'ouro' (%ds)" % int(s["seconds"]), out.contains("ouro"))
		h.check("offline tem 'XP' (%ds)" % int(s["seconds"]), out.contains("XP"))
		if exc:
			h.check("excepcional ⇒ 2 linhas", lines.size() == 2)
			h.check("excepcional cita o nome", out.contains(str(s["exceptional_name"])))
			h.check("excepcional marca 'EXCEPCIONAL'", out.contains("EXCEPCIONAL"))
		else:
			h.check("sem excepcional ⇒ 1 linha", lines.size() == 1)
			if has_extra:
				h.check("com itens/mat cita 'itens'", out.contains("itens"))
	h.group_complete()

# ════════════════════════ HUD37TABS (≥25) ════════════════════════
func _g_tabs() -> void:
	h.group_begin("HUD37TABS", 25)
	# 1) família de painéis + abas REAIS no manifest
	var sb_norm := HudArtPack.panel_stylebox("panels/panel_tab_normal.png")
	var sb_sel := HudArtPack.panel_stylebox("panels/panel_tab_selected.png")
	h.check("panel_tab_normal → StyleBoxTexture", sb_norm is StyleBoxTexture)
	h.check("panel_tab_selected → StyleBoxTexture", sb_sel is StyleBoxTexture)
	h.check("panel_tab_normal integrável", HudArtPack.integrable("panels/panel_tab_normal.png"))
	h.check("panel_tab_selected integrável", HudArtPack.integrable("panels/panel_tab_selected.png"))
	h.check("validate panel_tab_normal ok", bool(HudArtPack.validate_entry("panels/panel_tab_normal.png").get("ok", false)))
	h.check("validate panel_tab_selected ok", bool(HudArtPack.validate_entry("panels/panel_tab_selected.png").get("ok", false)))
	h.check("panel_frame presente", HudArtPack.tex("panels/panel_frame.png") != null)
	h.check("panel_header presente", HudArtPack.tex("panels/panel_header.png") != null)
	h.check("close_button_normal presente", HudArtPack.tex("panels/close_button_normal.png") != null)
	h.check("panel_tab_normal ≠ panel_tab_selected (arte distinta)", HudArtPack.path("panels/panel_tab_normal.png") != HudArtPack.path("panels/panel_tab_selected.png"))
	# 2) SystemPanel._apply_tab_style — aba real + font que reflete o estado
	var spx := SystemPanel.new()
	var b_sel := Button.new(); spx._apply_tab_style(b_sel, true)
	var b_norm := Button.new(); spx._apply_tab_style(b_norm, false)
	h.check("sys aba selecionada tem override 'normal'", b_sel.has_theme_stylebox_override("normal"))
	h.check("sys aba selecionada é StyleBoxTexture", b_sel.get_theme_stylebox("normal") is StyleBoxTexture)
	h.check("sys aba selecionada tem 'hover'", b_sel.has_theme_stylebox_override("hover"))
	h.check("sys aba selecionada tem 'pressed'", b_sel.has_theme_stylebox_override("pressed"))
	h.check("sys aba selecionada font = ouro", _col_eq(b_sel.get_theme_color("font_color"), GOLD))
	h.check("sys aba normal tem override 'normal'", b_norm.has_theme_stylebox_override("normal"))
	h.check("sys aba normal é StyleBoxTexture", b_norm.get_theme_stylebox("normal") is StyleBoxTexture)
	h.check("sys aba normal font ≠ ouro", not _col_eq(b_norm.get_theme_color("font_color"), GOLD))
	b_sel.free(); b_norm.free(); spx.free()
	# 3) BestiaryPanel._apply_tab — mesma regra
	var bpx := BestiaryPanel.new()
	var c_sel := Button.new(); bpx._apply_tab(c_sel, true)
	var c_norm := Button.new(); bpx._apply_tab(c_norm, false)
	h.check("bestiary aba selecionada override 'normal'", c_sel.has_theme_stylebox_override("normal"))
	h.check("bestiary aba selecionada é StyleBoxTexture", c_sel.get_theme_stylebox("normal") is StyleBoxTexture)
	h.check("bestiary aba selecionada 'hover'/'pressed'", c_sel.has_theme_stylebox_override("hover") and c_sel.has_theme_stylebox_override("pressed"))
	h.check("bestiary aba selecionada font dourada", _col_eq(c_sel.get_theme_color("font_color"), Color("f0c860")))
	h.check("bestiary aba normal override 'normal'", c_norm.has_theme_stylebox_override("normal"))
	h.check("bestiary aba normal font clara", _col_eq(c_norm.get_theme_color("font_color"), Color("cdd2dc")))
	h.check("bestiary aba normal focus NONE", c_norm.focus_mode == Control.FOCUS_NONE)
	c_sel.free(); c_norm.free(); bpx.free()
	h.group_complete()

# ════════════════════════ HUD37TRANSIENT (≥20) ════════════════════════
func _g_transient() -> void:
	h.group_begin("HUD37TRANSIENT", 20)
	h.check("MAX_VISIBLE_TOASTS == 4", FeedbackRenderer.MAX_VISIBLE_TOASTS == 4)
	h.check("TOAST_LIFE == 2.4", is_equal_approx(FeedbackRenderer.TOAST_LIFE, 2.4))
	h.check("MAX_FLOATS == 24", FeedbackRenderer.MAX_FLOATS == 24)
	var r := FeedbackRenderer.new()
	r._build_ui()
	var tb: VBoxContainer = r._toast_box
	h.check("toast_box existe", tb != null)
	h.check("toast_box anchor_left 0.5 (top-center)", is_equal_approx(tb.anchor_left, 0.5))
	h.check("toast_box anchor_right 0.5", is_equal_approx(tb.anchor_right, 0.5))
	h.check("toast_box anchor_top 0.0 (topo)", is_equal_approx(tb.anchor_top, 0.0))
	h.check("toast_box offset_top 100 (abaixo da top bar)", is_equal_approx(tb.offset_top, 100.0))
	h.check("toast_box centralizado (ALIGN_CENTER)", tb.alignment == BoxContainer.ALIGNMENT_CENTER)
	h.check("toast_box não captura mouse", tb.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	h.check("banner criado e invisível", r._banner != null and not r._banner.visible)
	h.check("warn criado e invisível", r._warn != null and not r._warn.visible)
	# card de toast: um pull → PanelContainer com StyleBoxFlat (borda/canto), texto em Label
	var fb := FakeBus.new(); fb.remaining = 1; r._bus = fb
	r._pull_toast()
	h.check("1 toast ativo após pull", r.active_toast_count() == 1)
	var card = tb.get_child(tb.get_child_count() - 1)
	h.check("toast é PanelContainer (card)", card is PanelContainer)
	var csb = card.get_theme_stylebox("panel") if card is PanelContainer else null
	h.check("card usa StyleBoxFlat", csb is StyleBoxFlat)
	if csb is StyleBoxFlat:
		h.check("card borda 1px", csb.border_width_left == 1)
		h.check("card canto arredondado 6", csb.corner_radius_top_left == 6)
	h.check("card contém Label", card.get_child_count() >= 1 and card.get_child(0) is Label)
	# cor: color explícito domina
	var fb2 := FakeBus.new(); fb2.remaining = 1; fb2.color = "ff0000"; r._bus = fb2
	r._pull_toast()
	var card2 = tb.get_child(tb.get_child_count() - 1)
	h.check("cor explícita aplicada no label", _col_eq(card2.get_child(0).modulate, Color("ff0000")))
	# cap: nunca passa de MAX_VISIBLE_TOASTS
	var fb3 := FakeBus.new(); fb3.remaining = 20; r._bus = fb3
	for i in range(20): r._pull_toast()
	h.check("cap respeita MAX_VISIBLE_TOASTS (≤4)", r.active_toast_count() <= FeedbackRenderer.MAX_VISIBLE_TOASTS)
	r.free()
	h.group_complete()

# ════════════════════════ HUD37TYPO (≥20) ════════════════════════
func _g_typo() -> void:
	h.group_begin("HUD37TYPO", 20)
	# tempos/ritmo do feedback (consistência tipográfica de duração)
	h.check("BANNER_LIFE 1.6", is_equal_approx(FeedbackRenderer.BANNER_LIFE, 1.6))
	h.check("WARN_LIFE 0.8", is_equal_approx(FeedbackRenderer.WARN_LIFE, 0.8))
	h.check("FLOAT_LIFE 0.85", is_equal_approx(FeedbackRenderer.FLOAT_LIFE, 0.85))
	h.check("TOAST_PERIOD 0.125 (~8Hz)", is_equal_approx(FeedbackRenderer.TOAST_PERIOD, 0.125))
	# card: margens de conteúdo compactas e legíveis (14/6)
	var r := FeedbackRenderer.new(); r._build_ui()
	var fb := FakeBus.new(); fb.remaining = 1; r._bus = fb; r._pull_toast()
	var card = r._toast_box.get_child(0)
	var csb = card.get_theme_stylebox("panel")
	h.check("card content_margin_left 14", is_equal_approx(csb.content_margin_left, 14.0))
	h.check("card content_margin_right 14", is_equal_approx(csb.content_margin_right, 14.0))
	h.check("card content_margin_top 6", is_equal_approx(csb.content_margin_top, 6.0))
	h.check("card content_margin_bottom 6", is_equal_approx(csb.content_margin_bottom, 6.0))
	h.check("label do card font 15", card.get_child(0).get_theme_font_size("font_size") == 15)
	h.check("label do card centralizado", card.get_child(0).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	r.free()
	# SystemPanel: caixa central de tamanho consistente (640x420) + separação
	var spx := SystemPanel.new(); spx.setup(null, [])
	h.check("painel largura consistente (780, A38)", spx._root.offset_right - spx._root.offset_left == 780)
	h.check("painel altura consistente (430, A38)", spx._root.offset_bottom - spx._root.offset_top == 430)
	h.check("lista de sistemas min-width 180", int(spx._list.custom_minimum_size.x) == 180)
	h.check("detalhe min-width 560 (A38)", int(spx._detail.custom_minimum_size.x) == 560)
	# offline default: 1 linha (tipografia compacta)
	var one := FeedbackFormat.offline({"seconds": 3600, "gold": 100, "xp": 10, "items": 0, "materials": 0, "exceptional_name": ""})
	h.check("offline padrão 1 linha", one.split("\n").size() == 1)
	h.check("offline usa separador '·'", one.contains("·"))
	# offline com drop excepcional cresce p/ exatamente 2 linhas (nunca parede de texto)
	var two := FeedbackFormat.offline({"seconds": 3600, "gold": 100, "xp": 10, "items": 1, "materials": 1, "exceptional_name": "Relíquia"})
	h.check("offline+excepcional 2 linhas", two.split("\n").size() == 2)
	var r2 := FeedbackRenderer.new(); r2._build_ui()
	h.check("toast_box separação constante 4", r2._toast_box.get_theme_constant("separation") == 4)
	# números grandes legíveis (tipografia PT-BR consistente na HUD)
	h.check("big(1234) → milhar com ponto", FeedbackFormat.big(1234) == "1.234")
	h.check("big(1500000) → sufixo M", FeedbackFormat.big(1500000).contains("M"))
	h.check("big usa vírgula decimal (PT-BR)", not FeedbackFormat.big(12300).contains("."))
	spx.free(); r2.free()
	h.group_complete()

# ════════════════════════ HUD37LAYOUT (≥25) ════════════════════════
func _g_layout() -> void:
	h.group_begin("HUD37LAYOUT", 25)
	var spx := SystemPanel.new(); spx.setup(null, [])
	# A33 preservado: backdrop modal STOP full-rect + layer
	h.check("layer do painel 60", spx.layer == 60)
	h.check("backdrop existe", spx._backdrop != null)
	h.check("backdrop captura o clique (STOP)", spx._backdrop.mouse_filter == Control.MOUSE_FILTER_STOP)
	h.check("backdrop full-rect (anchor_right 1)", is_equal_approx(spx._backdrop.anchor_right, 1.0))
	h.check("backdrop full-rect (anchor_bottom 1)", is_equal_approx(spx._backdrop.anchor_bottom, 1.0))
	h.check("backdrop escurece (alpha 0.5)", is_equal_approx(spx._backdrop.color.a, 0.5))
	# _root centralizado com offsets simétricos
	h.check("_root existe", spx._root != null)
	h.check("_root offset_left -390 (A38)", is_equal_approx(spx._root.offset_left, -390.0))
	h.check("_root offset_top -215 (A38)", is_equal_approx(spx._root.offset_top, -215.0))
	h.check("_root offset_right 390 (A38)", is_equal_approx(spx._root.offset_right, 390.0))
	h.check("_root offset_bottom 215 (A38)", is_equal_approx(spx._root.offset_bottom, 215.0))
	# header + título único + close (skin)
	var titles := _count_labels(spx, "SISTEMAS")
	h.check("exatamente 1 título 'SISTEMAS' (dedup §1)", titles == 1)
	h.check("lista NÃO repete título 'SISTEMAS'", _count_labels_in(spx._list, "SISTEMAS") == 0)
	var closebtn := _find_close_button(spx._root)
	h.check("botão fechar (X) presente", closebtn != null)
	if closebtn != null:
		h.check("X ancorado no topo-direito (offset_left -44)", is_equal_approx(closebtn.offset_left, -44.0))
		h.check("X tamanho mínimo 34x34", int(closebtn.custom_minimum_size.x) == 34)
	# colunas
	h.check("lista min-size (180,380)", spx._list.custom_minimum_size == Vector2(180, 380))
	h.check("detalhe min-size (560,380) (A38)", spx._detail.custom_minimum_size == Vector2(560, 380))
	spx.free()
	# FeedbackRenderer: banners/labels no eixo central
	var r := FeedbackRenderer.new(); r._build_ui()
	h.check("banner ancorado ao centro (anchor_left 0.5)", is_equal_approx(r._banner.anchor_left, 0.5))
	h.check("warn ancorado ao centro (anchor_left 0.5)", is_equal_approx(r._warn.anchor_left, 0.5))
	h.check("banner acima do centro (offset_top -140)", is_equal_approx(r._banner.offset_top, -140.0))
	h.check("warn acima do centro (offset_top -80)", is_equal_approx(r._warn.offset_top, -80.0))
	h.check("toast_box offset_left -300 (largura de card)", is_equal_approx(r._toast_box.offset_left, -300.0))
	h.check("toast_box offset_right 300", is_equal_approx(r._toast_box.offset_right, 300.0))
	h.check("warn com cor de perigo", _col_eq(r._warn.modulate, Color(1.0, 0.5, 0.45)))
	h.check("banner centralizado (horizontal)", r._banner.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	r.free()
	h.group_complete()

# ════════════════════════ HUD37SCREEN (≥20) ════════════════════════
func _g_screen() -> void:
	h.group_begin("HUD37SCREEN", 20)
	var files := [
		"A37_IDLE_1920.png", "A37_HUNT_1920.png", "A37_HUNT_1366.png", "A37_HUNT_1600.png",
		"A37_SYSTEMS_1920.png", "A37_INVENTORY_1920.png", "A37_BESTIARY_1920.png", "A37_OFFLINE_1920.png",
	]
	for f in files:
		var p := _dir.path_join(f)
		var exists := FileAccess.file_exists(p)
		h.check("screenshot existe: %s" % f, exists)
		if exists:
			var fa := FileAccess.open(p, FileAccess.READ)
			var sz := fa.get_length() if fa != null else 0
			if fa != null: fa.close()
			h.check("%s > 20KB (não vazio)" % f, sz > 20000)
			var img := Image.load_from_file(p)
			h.check("%s carrega e tem largura > 0" % f, img != null and img.get_width() > 0)
		else:
			h.check("%s sem bytes (arquivo ausente)" % f, false)
			h.check("%s sem imagem (arquivo ausente)" % f, false)
	h.group_complete()

# ════════════════════════ CENA: boot Main.tscn ════════════════════════
func _on_frame() -> void:
	_frame += 1
	if _step == 0 and _frame >= 6:
		main._enter_game()
		gs = root.get_node_or_null("GameState")
		if gs != null and gs.has_method("set_save_path_override"):
			gs.set_save_path_override("user://a37_selftest_fixture.json")   # blinda o save real
		ht = main.get("_hud_target")
		sp = main.get("_systempanel")
		fr = main.get("_feedback_renderer")
		router = main.get("_ui_router")
		bp = main.find_child("BestiaryPanel", true, false)
		if gs != null: _snap_before = gs.to_dict().duplicate(true)
		_step = 1; _frame = 0
	elif _step == 1 and _frame >= 10:
		_g_systems_scene()
		_g_responsive_scene()
		_g_realscene()
		_finish()

# ════════════════════════ HUD37SYSTEMS (≥20) — painel REAL ════════════════════════
func _g_systems_scene() -> void:
	h.group_begin("HUD37SYSTEMS", 20)
	if sp == null:
		h.group_error("SystemPanel nulo no scene")
		h.group_complete(); return
	sp.open_panel()
	h.check("painel abre (is_open)", sp.is_open())
	h.check("dedup: 1 único 'SISTEMAS'", _count_labels(sp, "SISTEMAS") == 1)
	h.check("lista não repete 'SISTEMAS'", _count_labels_in(sp._list, "SISTEMAS") == 0)
	var btns: Array = sp._sys_buttons
	h.check("há providers/abas", btns.size() >= 1)
	h.check("catálogo de sistemas ≥5 (Equip/Refino/Joias/Maestria/Bestiário/Códice)", btns.size() >= 5)
	var all_tab := true
	var all_h40 := true
	var all_badge := true
	for e in btns:
		var b: Button = e["btn"]
		if not (b.has_theme_stylebox_override("normal") and b.get_theme_stylebox("normal") is StyleBoxTexture):
			all_tab = false
		if int(b.custom_minimum_size.y) != 40: all_h40 = false
		if e.get("badge", null) == null: all_badge = false
	h.check("toda aba usa panel_tab (StyleBoxTexture)", all_tab)
	h.check("toda aba com altura de toque 40", all_h40)
	h.check("todo sistema tem badge de ação", all_badge)
	h.check("detalhe populado após abrir", sp._detail.get_child_count() > 0)
	h.check("sistema atual definido (current_system_id)", sp.current_system_id() != "")
	h.check("botão 'Fechar' na lista (A33 preservado)", _has_button_text(sp._list, "Fechar"))
	# a aba 0 está selecionada (open_panel abre no idx 0) → ouro; as demais, claras
	if btns.size() >= 1:
		h.check("aba ativa (0) com font ouro", _col_eq((btns[0]["btn"] as Button).get_theme_color("font_color"), GOLD))
	if btns.size() >= 2:
		h.check("aba inativa (1) font ≠ ouro", not _col_eq((btns[1]["btn"] as Button).get_theme_color("font_color"), GOLD))
		# troca de seleção reflete no estado
		sp._select(1)
		h.check("após _select(1): aba 1 vira ouro", _col_eq((btns[1]["btn"] as Button).get_theme_color("font_color"), GOLD))
		h.check("após _select(1): aba 0 deixa de ser ouro", not _col_eq((btns[0]["btn"] as Button).get_theme_color("font_color"), GOLD))
	# header com título dourado tamanho 18 (tipografia §4)
	var htitle := _find_label(sp._root, "SISTEMAS")
	h.check("título 'SISTEMAS' no header", htitle != null)
	if htitle != null:
		h.check("título font 18", htitle.get_theme_font_size("font_size") == 18)
		h.check("título dourado", _col_eq(htitle.get_theme_color("font_color"), GOLD))
	# close volta a fechar (A33 intacto)
	sp.close_panel()
	h.check("painel fecha", not sp.is_open())
	# reabrir não deixa lixo/duplicata
	sp.open_panel()
	h.check("reabrir mantém 1 'SISTEMAS'", _count_labels(sp, "SISTEMAS") == 1)
	sp.close_panel()
	h.check("estado final fechado", not sp.is_open())
	h.group_complete()

# ════════════════════════ HUD37RESPONSIVE (≥25) ════════════════════════
## Headless não redimensiona a janela real (a prova de PIXEL são os screenshots 1366/1600/1920). Aqui provamos a
## RESPONSIVIDADE ESTRUTURAL: os elementos usam ANCHORS de borda/stretch ⇒ reflowam com QUALQUER largura, e
## sobrevivem a refresh() repetido (sem recriar/vazar). Este é o invariante que faz o HUD se adaptar.
func _g_responsive_scene() -> void:
	h.group_begin("HUD37RESPONSIVE", 25)
	if ht == null:
		h.group_error("HudTargetV1 nulo no scene")
		h.group_complete(); return
	var top: Control = ht.get("_top_bg")
	var obj: Control = ht.get("_obj_frame")
	var ab: Control = ht.get("_ab_bg")
	var rib: Control = ht.get("_ribbon")
	# ★ A38 SUPERSEDE: a barra full-width foi REMOVIDA. _top_bg agora é a PLACA COMPACTA top-LEFT (não estica).
	h.check("top-left existe", is_instance_valid(top))
	h.check("top-left anchor_left 0", is_equal_approx(top.anchor_left, 0.0))
	h.check("top-left NÃO estica (anchor_right 0)", is_equal_approx(top.anchor_right, 0.0))
	h.check("top-left anchor_top 0", is_equal_approx(top.anchor_top, 0.0))
	h.check("top-left compacto (< 520px)", top.size.x < 520.0)
	h.check("top-left offset_left ~16", is_equal_approx(top.offset_left, 16.0))
	h.check("top-left é PanelContainer (cluster)", top is PanelContainer)
	# OBJETIVO — segue a borda direita (anchor_left/right 1) ⇒ acompanha a largura
	h.check("objetivo existe", is_instance_valid(obj))
	h.check("objetivo anchor_left 1 (borda direita)", is_equal_approx(obj.anchor_left, 1.0))
	h.check("objetivo anchor_right 1", is_equal_approx(obj.anchor_right, 1.0))
	h.check("objetivo compacto (≤ 320)", obj.size.x <= 320.0)
	h.check("objetivo é PanelContainer (auto-size)", obj is PanelContainer)
	# DICA DE TECLAS (ex-action bar) — CENTER_BOTTOM: recentra e cola no rodapé, SEM ser faixa gigante
	h.check("dica de teclas existe", is_instance_valid(ab))
	h.check("dica anchor_left 0.5 (recentra)", is_equal_approx(ab.anchor_left, 0.5))
	h.check("dica anchor_right 0.5", is_equal_approx(ab.anchor_right, 0.5))
	h.check("dica anchor_bottom 1 (rodapé)", is_equal_approx(ab.anchor_bottom, 1.0))
	h.check("dica NÃO é action bar gigante (< 900)", ab.size.x < 900.0)
	# RIBBON — CENTER_LEFT: colado à esquerda, centralizado na vertical
	h.check("ribbon existe", is_instance_valid(rib))
	h.check("ribbon anchor_top 0.5 (centro vertical)", is_equal_approx(rib.anchor_top, 0.5))
	h.check("ribbon anchor_bottom 0.5", is_equal_approx(rib.anchor_bottom, 0.5))
	h.check("ribbon anchor_left 0 (borda esquerda)", is_equal_approx(rib.anchor_left, 0.0))
	# ESTABILIDADE: refresh repetido não recria/derruba os nós (mesma instância)
	var id_top := top.get_instance_id()
	var id_ab := ab.get_instance_id()
	for i in range(5):
		if ht.has_method("refresh"): ht.refresh()
	h.check("top bar sobrevive a 5x refresh (mesma instância)", is_instance_valid(top) and top.get_instance_id() == id_top)
	h.check("action bar sobrevive a 5x refresh (mesma instância)", is_instance_valid(ab) and ab.get_instance_id() == id_ab)
	h.check("objetivo válido pós-refresh", is_instance_valid(obj))
	h.check("ribbon válido pós-refresh", is_instance_valid(rib))
	h.group_complete()

# ════════════════════════ REALSCENE37 (≥35) ════════════════════════
func _g_realscene() -> void:
	h.group_begin("REALSCENE37", 35)
	h.check("main vivo", main != null)
	h.check("GameState vivo", gs != null)
	h.check("HudTargetV1 presente", ht != null)
	h.check("legacy HUD absorvido (hud_target ativo)", ht != null and ht is CanvasLayer)
	# SystemPanel real
	h.check("SystemPanel presente", sp != null)
	if sp != null:
		sp.open_panel(); h.check("SystemPanel abre", sp.is_open())
		h.check("dedup mantido no scene", _count_labels(sp, "SISTEMAS") == 1)
		sp.close_panel(); h.check("SystemPanel fecha", not sp.is_open())
	# Bestiário real: abas MOBS/BOSSES
	h.check("BestiaryPanel encontrado", bp != null)
	if bp != null and router != null and router.has_method("open_bestiary"):
		router.open_bestiary("young_wolf")
		h.check("cat MOBS presente", bp.cat_mobs_btn != null)
		h.check("cat BOSSES presente", bp.cat_bosses_btn != null)
		if bp.cat_mobs_btn != null:
			h.check("MOBS usa panel_tab", bp.cat_mobs_btn.get_theme_stylebox("normal") is StyleBoxTexture)
			h.check("MOBS ativo = ouro", _col_eq(bp.cat_mobs_btn.get_theme_color("font_color"), Color("f0c860")))
		if bp.cat_bosses_btn != null:
			h.check("BOSSES usa panel_tab", bp.cat_bosses_btn.get_theme_stylebox("normal") is StyleBoxTexture)
			h.check("BOSSES inativo = claro", _col_eq(bp.cat_bosses_btn.get_theme_color("font_color"), Color("cdd2dc")))
		h.check("lista de mobs não-vazia", bp.mob_buttons.size() >= 1)
		bp._set_category("BOSSES")
		h.check("troca p/ BOSSES rebuild", bp._category == "BOSSES")
		h.check("BOSSES agora ativo = ouro", bp.cat_bosses_btn != null and _col_eq(bp.cat_bosses_btn.get_theme_color("font_color"), Color("f0c860")))
		bp.visible = false
	# FeedbackRenderer real
	h.check("FeedbackRenderer presente", fr != null)
	if fr != null:
		h.check("toast_box top-center", is_equal_approx(fr._toast_box.anchor_left, 0.5) and is_equal_approx(fr._toast_box.offset_top, 100.0))
		h.check("MAX_VISIBLE_TOASTS 4 no scene", FeedbackRenderer.MAX_VISIBLE_TOASTS == 4)
	# HuntHost intacto
	var hh = main.get("_hunthost")
	h.check("HuntHost presente", hh != null)
	h.check("HuntHost não está caçando (idle)", hh != null and not hh.is_hunting())
	# ---- GAMEPLAY UNTOUCHED: snapshot antes×depois das operações de UI ----
	var after: Dictionary = gs.to_dict().duplicate(true) if gs != null else {}
	var keys := ["hero_level", "hero_gold", "character_class", "stage_highest_global"]
	for k in keys:
		h.check("gameplay intacto: %s inalterado" % k, str(_snap_before.get(k, "∅A")) == str(after.get(k, "∅B")))
	h.check("equipment inalterado", str(_snap_before.get("equipment", {})) == str(after.get("equipment", {})))
	var vb: Variant = _snap_before.get("schemaVersion", null)
	var va: Variant = after.get("schemaVersion", null)
	h.check("schemaVersion presente no save", vb != null)
	h.check("schemaVersion inalterado pela UI", str(vb) == str(va))
	h.check("materials inalterado", str(_snap_before.get("materials", {})) == str(after.get("materials", {})))
	h.check("bestiary lifetime inalterado", str(_snap_before.get("bestiary", {})) == str(after.get("bestiary", {})))
	h.check("hero_hp_max inalterado", str(_snap_before.get("hero_hp_max", "")) == str(after.get("hero_hp_max", "")))
	h.check("character_class não-vazio", str(after.get("character_class", "")) != "")
	h.check("slot_refinement inalterado", str(_snap_before.get("slot_refinement", {})) == str(after.get("slot_refinement", {})))
	h.check("inventory inalterado", str(_snap_before.get("inventory", {})) == str(after.get("inventory", {})))
	# no-crash geral: ainda temos árvore viva
	h.check("scene ainda viva ao fim", is_instance_valid(main))
	h.group_complete()

# ════════════════════════ util ════════════════════════
func _col_eq(a: Color, b: Color) -> bool:
	return abs(a.r - b.r) < 0.02 and abs(a.g - b.g) < 0.02 and abs(a.b - b.b) < 0.02

func _count_labels(node: Node, text: String) -> int:
	var n := 0
	if node is Label and (node as Label).text == text: n += 1
	for c in node.get_children(): n += _count_labels(c, text)
	return n

func _count_labels_in(node: Node, text: String) -> int:
	return _count_labels(node, text) if node != null else 0

func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text: return node
	for c in node.get_children():
		var r := _find_label(c, text)
		if r != null: return r
	return null

func _has_button_text(node: Node, text: String) -> bool:
	if node is Button and (node as Button).text == text: return true
	for c in node.get_children():
		if _has_button_text(c, text): return true
	return false

func _find_close_button(node: Node) -> TextureButton:
	if node is TextureButton: return node
	for c in node.get_children():
		var r := _find_close_button(c)
		if r != null: return r
	return null

func _finish() -> void:
	if gs != null and gs.has_method("set_save_path_override"):
		gs.set_save_path_override("user://a37_selftest_fixture.json")
	if FileAccess.file_exists("user://a37_selftest_fixture.json"):
		DirAccess.remove_absolute("user://a37_selftest_fixture.json")
	print("─────────────────────────────────────────────")
	var res := h.summarize("A37 HUD POLISH CLOSEOUT")
	quit(0 if bool(res["ok"]) else 1)
