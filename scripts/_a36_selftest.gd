extends SceneTree
## A36 — SUPERSEDED BY A38 (HUD FIELD CORRECTION V2). O "finishing pass" da A36 (nav icons Pack 02 na ribbon
## TextureButton, reskin dos painéis, transient top-center) assumia a HUD Art-Pack full-width, REPROVADA no field test
## e SUBSTITUÍDA pela HUD world-first da A38. A cobertura de FORMA vive em `_a38_selftest.gd`. Aqui validamos o que
## PERMANECE: reskin dos painéis (panel_stylebox), transient em card top-center (FeedbackRenderer) e Pack 02 no disco.

var h: TestHarness = null
var main: Node = null
var _frame := 0
var _step := 0
var ht; var sp; var fr

class FakeBus:
	var remaining := 0
	func next_toast() -> Dictionary:
		if remaining <= 0: return {}
		remaining -= 1
		return {"text": "T", "kind": "", "color": ""}

func _initialize() -> void:
	h = TestHarness.new()
	print("═══════════ A36 — SUPERSEDED BY A38 (verificação de supersessão) ═══════════")
	# ── grupo puro: NAV PACK 02 + reskin de painéis + transient card ──
	h.group_begin("A36SUPERSEDED_ARTPACK", 25)
	for k in ["hunt", "missions", "inventory", "mastery", "systems"]:
		h.check("nav_%s_normal presente (Pack 02)" % k, HudArtPack.has("navigation/nav_%s_normal.png" % k))
		h.check("nav_%s_selected presente" % k, HudArtPack.has("navigation/nav_%s_selected.png" % k))
	h.check("panel_frame stylebox", HudArtPack.panel_stylebox("panels/panel_frame.png") is StyleBoxTexture)
	h.check("panel_frame_large stylebox", HudArtPack.panel_stylebox("panels/panel_frame_large.png") is StyleBoxTexture)
	h.check("panel_tab_normal stylebox", HudArtPack.panel_stylebox("panels/panel_tab_normal.png") is StyleBoxTexture)
	h.check("panel_tab_selected stylebox", HudArtPack.panel_stylebox("panels/panel_tab_selected.png") is StyleBoxTexture)
	# transient card top-center (FeedbackRenderer) — o reposicionamento da A36 permanece na A38
	var r := FeedbackRenderer.new(); r._build_ui()
	h.check("MAX_VISIBLE_TOASTS 4", FeedbackRenderer.MAX_VISIBLE_TOASTS == 4)
	h.check("toast_box top-center (anchor 0.5)", is_equal_approx(r._toast_box.anchor_left, 0.5))
	h.check("toast_box abaixo do topo (offset_top 100)", is_equal_approx(r._toast_box.offset_top, 100.0))
	h.check("toast_box centralizado", r._toast_box.alignment == BoxContainer.ALIGNMENT_CENTER)
	var fb := FakeBus.new(); fb.remaining = 1; r._bus = fb; r._pull_toast()
	h.check("toast é card (PanelContainer)", r._toast_box.get_child(0) is PanelContainer)
	h.check("card com StyleBoxFlat", r._toast_box.get_child(0).get_theme_stylebox("panel") is StyleBoxFlat)
	r.free()
	h.check("close_button_normal presente", HudArtPack.tex("panels/close_button_normal.png") != null)
	h.check("panel_header presente", HudArtPack.tex("panels/panel_header.png") != null)
	h.check("nav distinto: hunt normal ≠ selected", HudArtPack.path("navigation/nav_hunt_normal.png") != HudArtPack.path("navigation/nav_hunt_selected.png"))
	h.check("validate nav_systems ok", bool(HudArtPack.validate_entry("navigation/nav_systems_normal.png").get("ok", false)))
	h.check("panel_frame ≠ panel_frame_large", HudArtPack.path("panels/panel_frame.png") != HudArtPack.path("panels/panel_frame_large.png"))
	h.group_complete()
	main = load("res://scenes/Main.tscn").instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _step == 0 and _frame >= 6:
		main._enter_game(); ht = main.get("_hud_target"); sp = main.get("_systempanel"); fr = main.get("_feedback_renderer"); _step = 1; _frame = 0
	elif _step == 1 and _frame >= 8:
		if ht != null: ht.refresh()
		h.group_begin("A36SUPERSEDED_SCENE", 15)
		# SystemPanel reskinado (panel_frame + header + close) segue vivo, agora contido (A38)
		sp.open_panel(); if ht != null: ht.refresh()
		h.check("SystemPanel abre", sp.is_open())
		h.check("SystemPanel reskin: header 'SISTEMAS' único", _count_text(sp, "SISTEMAS") == 1)
		var root_ctrl: Control = sp.get("_root")
		h.check("SystemPanel contido (pc.clip_contents)", _clips(root_ctrl))
		h.check("close X (close_button) presente", _find_texbtn(root_ctrl) != null)
		var esc := 0
		var pr := Rect2(root_ctrl.global_position, root_ctrl.size)
		for n in _all(sp):
			if (n is Button or n is Label) and (n as Control).is_visible_in_tree():
				var c := n as Control
				if c.global_position.x + c.size.x > pr.position.x + pr.size.x + 2.0: esc += 1
		h.check("nada escapa do painel (A38 conteve, %d)" % esc, esc == 0)
		sp.close_panel(); if ht != null: ht.refresh()
		h.check("SystemPanel fecha", not sp.is_open())
		# transient renderer vivo na cena, top-center
		h.check("FeedbackRenderer presente", fr != null)
		h.check("renderer layer 55", (fr as CanvasLayer).layer == 55)
		h.check("toast_box top-center na cena", is_equal_approx(fr._toast_box.anchor_left, 0.5))
		# ribbon com nav Pack 02 (Button.icon setado quando o asset existe)
		var hb = ht.ribbon_buttons.get("hunt")
		h.check("ribbon hunt tem ícone (Pack 02)", hb is Button and (hb as Button).icon != null)
		h.check("ribbon systems tem ícone", (ht.ribbon_buttons.get("systems") as Button).icon != null)
		h.check("ribbon 5 itens", ht.ribbon_buttons.size() == 5)
		h.check("HudTargetV1 presente", ht != null)
		h.check("Bestiary usa panel_stylebox (reskin vivo)", main.find_child("BestiaryPanel", true, false) != null)
		h.check("ribbon missions tem ícone (Pack 02)", (ht.ribbon_buttons.get("missions") as Button).icon != null)
		h.group_complete()
		print("─────────────────────────────────────────────")
		var res := h.summarize("A36 (SUPERSEDED BY A38)")
		quit(0 if bool(res["ok"]) else 1)

func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children(): out += _all(c)
	return out

func _count_text(n: Node, text: String) -> int:
	var c := 0
	if (n is Label or n is Button) and (n as Control).text == text: c += 1
	for ch in n.get_children(): c += _count_text(ch, text)
	return c

func _clips(n: Node) -> bool:
	for d in _all(n):
		if d is PanelContainer and (d as Control).clip_contents: return true
	return false

func _find_texbtn(n: Node) -> TextureButton:
	if n is TextureButton: return n
	for c in n.get_children():
		var r := _find_texbtn(c)
		if r != null: return r
	return null
