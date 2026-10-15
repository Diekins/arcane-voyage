class_name HuntPanel extends CanvasLayer
## FATIA A16.1B/J + A39 RESKIN — "ÁREAS DE CAÇA" como MAJOR PANEL da família visual (panel_frame/header/close/dim,
## centralizado, ScrollContainer, rows em CARD). Lista as Hunting Grounds (LOCKED/AVAILABLE por CP+stage), INICIAR só
## quando disponível, BLOQUEADO não-clicável + "Requer Stage X". Server-authoritative (chama HuntService via host).
## ★ A39 é só APRESENTAÇÃO: grounds_list/start/stop/session_info INTACTOS (mesma lógica da A16). Fecha ao INICIAR.

var hunt: HuntService
var account := ""
var character := ""
var authority: AuthorityServer
var _root: Control
var _backdrop: ColorRect
var host = null                       # HuntHost (quando ligado, START passa pelo host: mirror+lock+exclusão)
var _list_box: VBoxContainer = null
var _scroll: ScrollContainer = null
var _status_lbl: Label = null

const GOLD := Color("f0c860")
const TEXT := Color("d9ddea")
const DIM := Color("9aa0b0")
const GREEN := Color("7ede97")
const LOCKED := Color("c98a86")

func setup(p_hunt: HuntService, p_authority: AuthorityServer, p_account: String, p_character: String) -> void:
	hunt = p_hunt; authority = p_authority; account = p_account; character = p_character
	layer = 60   # A39 — família dos major panels (mesmo nível do SystemPanel); ONE MAJOR PANEL garante 1 por vez
	_build_ui()

func bind_host(h) -> void:
	host = h
	refresh()

# ── UI (A39 major-panel family) ──────────────────────────────────────────────────────────────
func _mk(txt: String, size: int, col: Color) -> Label:
	var l := Label.new(); l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _skin_close_button() -> TextureButton:
	var tn := HudArtPack.tex("panels/close_button_normal.png")
	if tn == null: return null
	var b := TextureButton.new(); b.texture_normal = tn
	var th := HudArtPack.tex("panels/close_button_hover.png"); if th != null: b.texture_hover = th
	var tp := HudArtPack.tex("panels/close_button_pressed.png"); if tp != null: b.texture_pressed = tp
	b.ignore_texture_size = true; b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(34, 34)
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = -44; b.offset_top = 8; b.offset_right = -10; b.offset_bottom = 42
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(close_panel)
	return b

func _build_ui() -> void:
	# BACKDROP modal (dim + click-away), igual ao SystemPanel (A33/A38)
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.5)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: close_panel())
	add_child(_backdrop)
	# _root centralizado (760×540 cabe em 1366×768 e ≤75% de 1080)
	_root = Control.new(); _root.set_anchors_preset(Control.PRESET_CENTER)
	_root.offset_left = -380; _root.offset_top = -270; _root.offset_right = 380; _root.offset_bottom = 270
	add_child(_root)
	var frame := HudArtPack.nine("panels/panel_frame.png")
	var skinned := frame != null
	if skinned:
		frame.set_anchors_preset(Control.PRESET_FULL_RECT); _root.add_child(frame)
	var pc := PanelContainer.new(); pc.set_anchors_preset(Control.PRESET_FULL_RECT)
	pc.clip_contents = true   # A39 §13 — nada escapa
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0) if skinned else Color(0.05, 0.05, 0.08, 0.96)
	sb.set_corner_radius_all(8)
	if not skinned: sb.set_border_width_all(2); sb.border_color = GOLD
	# ★ A39 — PanelContainer insere pelo CONTENT_MARGIN do STYLEBOX (não por theme const "margin_*", que é do
	# MarginContainer). O topo (64) libera a altura do header p/ o 1º card não ficar cortado.
	sb.content_margin_left = 22 if skinned else 6
	sb.content_margin_top = 64 if skinned else 6
	sb.content_margin_right = 22 if skinned else 6
	sb.content_margin_bottom = 22 if skinned else 6
	pc.add_theme_stylebox_override("panel", sb)
	_root.add_child(pc)
	# header + título + close
	if skinned:
		var header := HudArtPack.nine("panels/panel_header.png")
		if header != null:
			header.set_anchors_preset(Control.PRESET_TOP_WIDE)
			header.offset_left = 10; header.offset_right = -10; header.offset_top = 6; header.offset_bottom = 48
			_root.add_child(header)
	var htitle := _mk("ÁREAS DE CAÇA", 18, GOLD); htitle.position = Vector2(28, 14); _root.add_child(htitle)
	var cx := _skin_close_button()
	if cx != null: _root.add_child(cx)
	else:
		var cb := Button.new(); cb.text = "X"; cb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		cb.offset_left = -44; cb.offset_top = 8; cb.focus_mode = Control.FOCUS_NONE
		cb.pressed.connect(close_panel); _root.add_child(cb)
	# corpo: scroll + lista de cards
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation", 8); pc.add_child(body)
	_scroll = ScrollContainer.new(); _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; _scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_scroll)
	_list_box = VBoxContainer.new(); _list_box.add_theme_constant_override("separation", 10)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list_box)
	_status_lbl = _mk("—", 12, DIM); body.add_child(_status_lbl)
	refresh()

## A39 — cada área é um CARD contido (nome/tier/CP/mobs/status/ação). BLOQUEADO não parece botão.
func _row_card(g: Dictionary) -> void:
	var avail := str(g["state"]) == "AVAILABLE"
	var card := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.09, 0.085, 0.11, 0.85) if avail else Color(0.06, 0.055, 0.07, 0.8)
	csb.border_color = Color(0.5, 0.42, 0.25, 0.55) if avail else Color(0.3, 0.28, 0.32, 0.5)
	csb.set_border_width_all(1); csb.set_corner_radius_all(8)
	csb.content_margin_left = 14; csb.content_margin_right = 14; csb.content_margin_top = 10; csb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", csb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 3); card.add_child(vb)
	vb.add_child(_mk(str(g["friendly"]), 16, GOLD if avail else DIM))
	vb.add_child(_mk("CP recomendado: %s" % _fmt(int(g["recommended_cp"])), 13, TEXT))
	var mobs_txt := ", ".join((g["mobs"] as Array).slice(0, 3))
	if mobs_txt != "": vb.add_child(_mk("Mobs: %s" % mobs_txt, 12, DIM))
	# linha de status + ação
	var srow := HBoxContainer.new(); srow.add_theme_constant_override("separation", 10); vb.add_child(srow)
	if avail:
		var st := _mk("DISPONÍVEL", 13, GREEN); st.size_flags_horizontal = Control.SIZE_EXPAND_FILL; srow.add_child(st)
		var b := Button.new(); b.text = "INICIAR CAÇA"; b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, UiMetrics.min_touch_target("desktop", "TT_B"))
		var gid := str(g["ground_id"])
		b.pressed.connect(func(): _on_start_pressed(gid))
		srow.add_child(b)
	else:
		var st := _mk("BLOQUEADO", 13, LOCKED); st.size_flags_horizontal = Control.SIZE_EXPAND_FILL; srow.add_child(st)
		# "Requer Stage X" DISCRETO (label, não botão §7)
		srow.add_child(_mk(str(g["lock_reason"]), 12, DIM))
	_list_box.add_child(card)

func refresh() -> void:
	if _list_box == null: return
	for c in _list_box.get_children(): _list_box.remove_child(c); c.free()   # free imediato (count determinístico)
	var spacer := Control.new(); spacer.custom_minimum_size = Vector2(0, 6)   # A39 — o 1º card não encosta no header
	_list_box.add_child(spacer)
	for g in grounds_list():
		_row_card(g)
	_update_status()
	if _scroll != null: _scroll.set_deferred("scroll_vertical", 0)   # A39 — sempre abre no TOPO (1º card inteiro visível)

# ── estado do painel (A39) ───────────────────────────────────────────────────────────────────
func is_open() -> bool: return visible
func close_panel() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_panel()
		var vp := get_viewport()
		if vp != null: vp.set_input_as_handled()

func _friendly(gid: String) -> String:
	match gid:
		"HG_PLAINS_LOW": return "PLANÍCIE (Iniciante)"
		"HG_PLAINS_HIGH": return "PLANÍCIE (Avançada)"
		"HG_CAVE": return "CAVERNA"
		_: return gid

## INICIAR (§10) — server-authoritative; ao começar, o painel FECHA (volta à composição HUNT ATIVO da A38).
func _on_start_pressed(ground_id: String) -> void:
	if host != null: host.start(ground_id)
	else: start(ground_id)
	if host != null and host.is_hunting(): close_panel()
	else: refresh()

func _update_status() -> void:
	if _status_lbl == null: return
	var info := session_info()
	if bool(info.get("active", false)):
		_status_lbl.text = "Caçando %s · abates %d" % [str(info["ground_id"]), int(info["kills"])]
	else:
		_status_lbl.text = "Escolha uma área para começar a caçar."

func tick_ui() -> void:
	_update_status()

func _fmt(n: int) -> String:
	var s := str(absi(n)); var out := ""; var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out; c += 1
		if c % 3 == 0 and i > 0: out = "." + out
	return ("-" if n < 0 else "") + out

# ── LÓGICA A16 INTACTA (server-authoritative) ────────────────────────────────────────────────
func grounds_list() -> Array:
	var ps := authority.power_snapshot(character)
	var cp := int(ps.get("cp", 0)); var stage := int(ps.get("highest_stage", 1))
	var out: Array = []
	for gid in HuntingGround.all_ids():
		var g := HuntingGround.get_ground(gid)
		var unlocked := HuntingGround.is_unlocked(gid, cp, stage)
		# A42 §29 — gate por completion do capítulo (flag). O host tem o GameState com as story flags.
		var req_flag := HuntingGround.required_flag(gid)
		var flag_ok: bool = true
		if req_flag != "":
			var gsx = host.get("game_state") if host != null else null
			flag_ok = gsx != null and bool(gsx.is_story_flag(req_flag))
		var mobs: Array = []
		for e in g.get("mob_table", []): mobs.append(str(e["mob_id"]))
		var u: Dictionary = g.get("unlock_rule", {})
		var reason := ""
		if not unlocked or not flag_ok:
			if not flag_ok: reason = "Requer concluir o Chapter 4"
			elif stage < int(u.get("min_stage", 1)): reason = "Requer Stage %d" % int(u.get("min_stage", 1))
			elif cp < int(u.get("min_cp", 0)): reason = "Requer Poder %d" % int(u.get("min_cp", 0))
			else: reason = "Indisponível"
		unlocked = unlocked and flag_ok
		out.append({
			"ground_id": gid, "display_name": str(g.get("display_name_key", "")), "friendly": _friendly(gid),
			"recommended_cp": int(g.get("recommended_cp", 0)), "map_id": str(g.get("map_id", "")),
			"mobs": mobs, "state": ("AVAILABLE" if unlocked else "LOCKED"), "lock_reason": reason,
		})
	out.sort_custom(func(a, b): return int(a["recommended_cp"]) < int(b["recommended_cp"]))
	return out

func start(ground_id: String) -> Dictionary:
	return hunt.start_hunt(account, character, ground_id)

func stop() -> Dictionary:
	return hunt.stop_hunt(character)

func session_info() -> Dictionary:
	var s := hunt.get_hunt_state(character)
	if not bool(s.get("ok", false)): return {"active": false}
	var st: Dictionary = s["session"]["stats"]
	return {"active": true, "ground_id": str(s["session"]["ground_id"]), "spot_id": str(s["session"]["spot_id"]),
		"kills": int(st["kills"]), "xp": int(st["xp"]), "items": int(st["items"]), "elite": int(st["elite"]), "apex": int(st["apex"])}

func touch_targets_ok() -> bool:
	return UiMetrics.target_ok(88, PlatformCapabilities.PRESENT_TOUCH, "TT_B")
