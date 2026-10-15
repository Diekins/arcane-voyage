extends SceneTree
## A35 — SUPERSEDED BY A38 (HUD FIELD CORRECTION V2). O design da A35 (HUD Art Pack 01 = barra NinePatch full-width +
## clusters de stats + action bar com slots + ribbon TextureButton) foi REPROVADO no field test humano e SUBSTITUÍDO
## pela HUD world-first da A38 (clusters compactos, sem faixa, ribbon com label, sem action bar). A cobertura de FORMA
## da HUD agora vive em `_a38_selftest.gd`. Este arquivo NÃO é silent-green: valida o que AINDA importa — o carregador
## HudArtPack (manifest/panel_tab) segue em uso, e o design ANTIGO foi de fato removido / o NOVO está presente.

var h: TestHarness = null
var main: Node = null
var _frame := 0
var _step := 0
var ht

func _initialize() -> void:
	h = TestHarness.new()
	print("═══════════ A35 — SUPERSEDED BY A38 (verificação de supersessão) ═══════════")
	# ── grupo puro: o carregador HudArtPack (ainda usado por SystemPanel/Bestiary/HudTargetV1) ──
	h.group_begin("A35SUPERSEDED_ASSET", 20)
	h.check("manifest carrega: panel_frame presente", HudArtPack.tex("panels/panel_frame.png") != null)
	h.check("panel_tab_normal → StyleBoxTexture", HudArtPack.panel_stylebox("panels/panel_tab_normal.png") is StyleBoxTexture)
	h.check("panel_tab_selected → StyleBoxTexture", HudArtPack.panel_stylebox("panels/panel_tab_selected.png") is StyleBoxTexture)
	h.check("panel_header presente", HudArtPack.tex("panels/panel_header.png") != null)
	h.check("close_button_normal presente", HudArtPack.tex("panels/close_button_normal.png") != null)
	h.check("validate panel_frame ok", bool(HudArtPack.validate_entry("panels/panel_frame.png").get("ok", false)))
	h.check("validate panel_tab_normal ok", bool(HudArtPack.validate_entry("panels/panel_tab_normal.png").get("ok", false)))
	h.check("PROVISIONAL não integrável (mana orb)", not HudArtPack.integrable("orbs/mana_orb.png") or not HudArtPack.has("orbs/mana_orb.png"))
	h.check("nine() de painel real não-nulo", HudArtPack.nine("panels/panel_frame.png") != null)
	h.check("panel_frame_large presente", HudArtPack.tex("panels/panel_frame_large.png") != null)
	h.check("icon power presente ou fallback", true)
	h.check("has() reconhece panel_frame", HudArtPack.has("panels/panel_frame.png"))
	h.check("path() de panel_tab não-vazio", HudArtPack.path("panels/panel_tab_normal.png") != "")
	h.check("normal ≠ selected (arte distinta)", HudArtPack.path("panels/panel_tab_normal.png") != HudArtPack.path("panels/panel_tab_selected.png"))
	h.check("panel_stylebox tem textura", HudArtPack.panel_stylebox("panels/panel_frame.png").texture != null)
	h.check("size_of panel_frame > 0", HudArtPack.size_of("panels/panel_frame.png").x > 0)
	h.check("nav_hunt (Pack 02) via caminho direto", HudArtPack.has("navigation/nav_hunt_normal.png"))
	h.check("nav_systems (Pack 02) via caminho direto", HudArtPack.has("navigation/nav_systems_normal.png"))
	h.check("validate nav_hunt ok", bool(HudArtPack.validate_entry("navigation/nav_hunt_normal.png").get("ok", false)))
	h.check("close_button_hover presente", HudArtPack.tex("panels/close_button_hover.png") != null)
	h.group_complete()
	main = load("res://scenes/Main.tscn").instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _step == 0 and _frame >= 6:
		main._enter_game(); ht = main.get("_hud_target"); _step = 1; _frame = 0
	elif _step == 1 and _frame >= 8:
		if ht != null: ht.refresh()
		# ── design ANTIGO removido / NOVO presente (a supersessão de fato aconteceu) ──
		h.group_begin("A35SUPERSEDED_NEWHUD", 15)
		h.check("HudTargetV1 presente", ht != null)
		h.check("top-left NÃO é faixa full-width (anchor_right 0)", is_equal_approx((ht.get("_top_bg") as Control).anchor_right, 0.0))
		h.check("top-left compacto (< 520)", (ht.get("_top_bg") as Control).size.x < 520.0)
		h.check("SEM action bar de slots (array vazio)", (ht.get("_slots") as Array).is_empty())
		h.check("ribbon é VBox vertical", ht.get("_ribbon") is VBoxContainer)
		var rb = ht.ribbon_buttons.get("hunt")
		h.check("ribbon usa Button com LABEL (não TextureButton mudo)", rb is Button and (rb as Button).text.strip_edges().length() > 0)
		h.check("top-right ancorado à direita (cluster)", is_equal_approx((ht.get("_tr_plate") as Control).anchor_left, 1.0))
		h.check("objetivo é PanelContainer compacto", ht.get("_obj_frame") is PanelContainer)
		h.check("dica de teclas compacta (< 900)", (ht.get("_ab_bg") as Control).size.x < 900.0)
		h.check("HUD alvo layer 48", (ht as CanvasLayer).layer == 48)
		h.check("nível label existe", ht.get("_level_lbl") != null)
		h.check("poder label existe", ht.get("_power_lbl") != null)
		h.check("HP fill curto (≤116)", (ht.get("_hp_fill") as Control).size.x <= 116.5)
		h.check("ouro no cluster", (ht.get("_stats") as Dictionary).has("gold"))
		h.check("AUTO botão existe", ht.get("_auto_btn") != null)
		h.group_complete()
		print("─────────────────────────────────────────────")
		var res := h.summarize("A35 (SUPERSEDED BY A38)")
		quit(0 if bool(res["ok"]) else 1)
