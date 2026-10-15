class_name IdleHud extends CanvasLayer
## IdleHud — a CASCA VISUAL IDLE (FATIA A4). "O jogo precisa PARECER um idle assim que abre."
##
## O combate fica no CENTRO (mundo já existente); a atenção interativa migra para as BORDAS: PODER, FASE,
## progresso, AUTO, velocidade, sistemas, loot, muro, objetivo. IdleHud é ORQUESTRADOR — NÃO reimplementa
## os painéis existentes (inventário/equip/maestria/loja): ele os ABRE. NÃO reimplementa a regra do muro:
## reflete e chama a API (StageDirector/AutoPlay/PowerBudget/PowerAdvisor/LootManager/GameSpeedController).
##
## Não captura input sobre a viewport (mouse_filter): WASD e o clique no mundo seguem funcionando. Refresh
## é THROTTLED (~8Hz) — não atualiza texto a cada frame.

const REFRESH_HZ := 8.0
const CPDELTA_HOLD := 1.6      # s (tempo real) que o "+N PODER" fica visível
const TOAST_HOLD := 1.8        # s que o toast de transição/marco fica visível

var _host = null               # Main (abre painéis)
var _sd = null                 # StageDirector
var _ap = null                 # AutoPlay
var _lm = null                 # LootManager
var _speed = null              # GameSpeedController
var _ir = null                 # IdleRewards (FATIA A5)
var _pm = null                 # PrestigeManager (FATIA A6)
var _chest_panel: PanelContainer
var _chest_lbl: Label
var _claim_btn: Button
# FATIA A6 — painel de Prestígio + confirmação in-game
var _prestige_panel: PanelContainer
var _prestige_lbl: Label
var _prestige_btn: Button
var _master_lbl: Label         # placar discreto MESTRE/PRESTÍGIO (§61)
var _confirm_armed := false    # 1º clique arma a confirmação; 2º executa (§31)

func set_idlerewards(ir) -> void:
	_ir = ir
	if _booted:
		# abre o baú automaticamente no retorno se houver pending (§45)
		if _ir != null and _ir.has_pending():
			_chest_panel.visible = true
			_update_chest_text()
		refresh(true)

## FATIA A6 — liga o PrestigeManager (painel/▸IR/badge). Chamado pelo Main após criar os subsistemas.
func set_prestige(pm) -> void:
	_pm = pm
	if _booted:
		refresh(true)

# ── nós de UI ──
var _root: Control
var _power_lbl: Label
var _res_lbl: Label
var _topstage_lbl: Label
var _auto_top_lbl: Label
var _stage_lbl: Label
var _progress: ProgressBar
var _progress_lbl: Label
var _speed_btns: Array = []
var _auto_btn: Button
var _ir_btn: Button
var _wall_panel: PanelContainer
var _wall_lbl: Label
var _retry_btn: Button
var _sys_btns: Dictionary = {}     # id -> {btn, badge}
var _cpdelta_lbl: Label
var _toast_lbl: Label

# ── estado de refresh ──
var _refresh_t := 0.0
var _last_cp := -1
var _cpdelta_t := 0.0
var _toast_t := 0.0
var _last_stage_label := ""
var _booted := false

func setup(host, sd, ap, lm, speed) -> void:
	_host = host; _sd = sd; _ap = ap; _lm = lm; _speed = speed
	layer = 45
	_build_ui()
	_last_cp = _cp()   # baseline: não mostrar "+CP" no boot (§42)
	_last_stage_label = _sd.stage_label() if _sd != null else ""
	_booted = true
	refresh(true)

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# CONSTRUÇÃO DA UI (bordas; centro livre). Cores/tipografia coerentes com a fantasia sombria existente.
# ══════════════════════════════════════════════════════════════════════════════════════════════════
const COL_GOLD := Color(0.98, 0.85, 0.45)
const COL_TEXT := Color(0.90, 0.92, 0.97)
const COL_DIM := Color(0.62, 0.66, 0.74)
const COL_WALL := Color(1.0, 0.5, 0.45)
const COL_PANEL := Color(0.06, 0.06, 0.09, 0.82)

func _mk_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## A34 — uma atividade (Hunt/Mission/Boss) está com HUD próprio no ar? (o Activity HUD tem prioridade §3/§7).
func _activity_active() -> bool:
	return _host != null and _host.has_method("hud_activity_active") and _host.hud_activity_active()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # a casca NÃO captura input do mundo
	add_child(_root)

	# ── BARRA SUPERIOR ── (esquerda: PODER + recursos · direita: FASE + AUTO)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# A34 §6 — a faixa de status começa DEPOIS do medalhão de vitals (crest 6..328) p/ não colidir (referência: medalhão → PODER à direita).
	top.offset_left = 342; top.offset_top = 14; top.offset_right = -12
	top.add_theme_constant_override("separation", 18)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	_power_lbl = _mk_label("PODER —", 22, COL_GOLD)
	top.add_child(_power_lbl)
	_res_lbl = _mk_label("", 15, COL_TEXT)
	top.add_child(_res_lbl)
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	_topstage_lbl = _mk_label("FASE —", 18, COL_TEXT)
	_topstage_lbl.visible = false   # A33 §14 — FASE/APEX em UM lugar: a linha de progresso do rodapé (com a barra). O rótulo do topo duplicava.
	top.add_child(_topstage_lbl)
	_auto_top_lbl = _mk_label("AUTO", 15, COL_DIM)
	_auto_top_lbl.visible = false   # A33 §5 — UM só controle de AUTO: o botão interativo do rodapé (_auto_btn). O rótulo do topo duplicava o estado.
	top.add_child(_auto_top_lbl)
	# FATIA A6 — placar DISCRETO de Mestre/Prestígio (§61). Não compete com PODER; oculto até o 1º Prestígio.
	_master_lbl = _mk_label("", 14, Color(0.72, 0.62, 0.95))
	_master_lbl.visible = false
	top.add_child(_master_lbl)

	# ── COLUNA DE SISTEMAS (esquerda) ── atalhos p/ painéis EXISTENTES (só navegação; SystemPanel é A7)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	col.offset_left = 10; col.offset_top = -120
	col.add_theme_constant_override("separation", 6)
	_root.add_child(col)
	for spec in [
		{"id": "systems", "label": "⚙ Sistemas"},
		{"id": "inventory", "label": "🎒 Inventário"},
		{"id": "equip", "label": "⚔ Equip."},
		{"id": "mastery", "label": "✦ Maestria"},
		{"id": "shop", "label": "🛒 Loja"},
	]:
		var row := Control.new()
		row.custom_minimum_size = Vector2(128, 30)
		var b := Button.new()
		b.text = str(spec["label"])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(128, 30)
		b.pressed.connect(_on_system_pressed.bind(str(spec["id"])))
		row.add_child(b)
		var badge := _mk_label("●", 14, COL_WALL)
		badge.position = Vector2(116, -2)
		badge.visible = false
		row.add_child(badge)
		col.add_child(row)
		_sys_btns[str(spec["id"])] = {"btn": b, "badge": badge}

	# ── BARRA INFERIOR ── (fase + progresso · x1/x2/x3 · AUTO · ▸IR)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12; bottom.offset_top = -70; bottom.offset_right = -12; bottom.offset_bottom = -8
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	# linha de fase/progresso
	var pr_row := HBoxContainer.new(); pr_row.add_theme_constant_override("separation", 12)
	pr_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(pr_row)
	_stage_lbl = _mk_label("FASE —", 18, COL_TEXT); pr_row.add_child(_stage_lbl)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(280, 16)
	_progress.max_value = 100; _progress.value = 0; _progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pr_row.add_child(_progress)
	_progress_lbl = _mk_label("0/0", 14, COL_DIM); pr_row.add_child(_progress_lbl)
	# linha de controles
	var ctl_row := HBoxContainer.new(); ctl_row.add_theme_constant_override("separation", 8)
	bottom.add_child(ctl_row)
	for mult in [1, 2, 3]:
		var sb := Button.new()
		sb.text = "x%d" % mult
		sb.focus_mode = Control.FOCUS_NONE
		sb.toggle_mode = true
		sb.custom_minimum_size = Vector2(40, 28)
		sb.pressed.connect(_on_speed_pressed.bind(float(mult)))
		ctl_row.add_child(sb)
		_speed_btns.append(sb)
	_auto_btn = Button.new(); _auto_btn.text = "AUTO"; _auto_btn.focus_mode = Control.FOCUS_NONE
	_auto_btn.custom_minimum_size = Vector2(90, 28)
	_auto_btn.pressed.connect(_on_auto_pressed)
	ctl_row.add_child(_auto_btn)
	_ir_btn = Button.new(); _ir_btn.text = "▸ IR"; _ir_btn.focus_mode = Control.FOCUS_NONE
	_ir_btn.custom_minimum_size = Vector2(160, 28)
	_ir_btn.pressed.connect(_on_ir_pressed)
	ctl_row.add_child(_ir_btn)

	# ── PAINEL DO MURO (centro-direita; oculto fora do muro) ──
	_wall_panel = PanelContainer.new()
	_wall_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_wall_panel.offset_left = -240; _wall_panel.offset_top = -70
	_wall_panel.visible = false
	var wsb := StyleBoxFlat.new(); wsb.bg_color = COL_PANEL; wsb.set_corner_radius_all(6)
	wsb.set_border_width_all(1); wsb.border_color = COL_WALL
	_wall_panel.add_theme_stylebox_override("panel", wsb)
	_root.add_child(_wall_panel)
	var wv := VBoxContainer.new(); _wall_panel.add_child(wv)
	_wall_lbl = _mk_label("", 14, COL_WALL); wv.add_child(_wall_lbl)
	_retry_btn = Button.new(); _retry_btn.text = "TENTAR NOVAMENTE  [T]"; _retry_btn.focus_mode = Control.FOCUS_NONE
	_retry_btn.pressed.connect(_on_retry_pressed)
	wv.add_child(_retry_btn)

	# ── BAÚ AFK (FATIA A5) — painel central que aparece no retorno se houver pending ──
	_chest_panel = PanelContainer.new()
	_chest_panel.set_anchors_preset(Control.PRESET_CENTER)
	_chest_panel.offset_left = -190; _chest_panel.offset_top = -130
	_chest_panel.offset_right = 190; _chest_panel.offset_bottom = 130
	_chest_panel.visible = false
	var csb := StyleBoxFlat.new(); csb.bg_color = Color(0.05, 0.05, 0.08, 0.94); csb.set_corner_radius_all(8)
	csb.set_border_width_all(2); csb.border_color = COL_GOLD
	_chest_panel.add_theme_stylebox_override("panel", csb)
	_root.add_child(_chest_panel)
	var cv := VBoxContainer.new(); cv.add_theme_constant_override("separation", 8); _chest_panel.add_child(cv)
	var ctitle := _mk_label("ENQUANTO VOCÊ ESTEVE FORA", 18, COL_GOLD); cv.add_child(ctitle)
	_chest_lbl = _mk_label("", 15, COL_TEXT); cv.add_child(_chest_lbl)
	_claim_btn = Button.new(); _claim_btn.text = "COLETAR"; _claim_btn.focus_mode = Control.FOCUS_NONE
	_claim_btn.custom_minimum_size = Vector2(140, 34)
	_claim_btn.pressed.connect(_on_claim_pressed)
	cv.add_child(_claim_btn)

	# ── PAINEL DE PRESTÍGIO (FATIA A6) — central; oculto até ser aberto pelo ▸IR/badge (§30/§62) ──
	_prestige_panel = PanelContainer.new()
	_prestige_panel.set_anchors_preset(Control.PRESET_CENTER)
	_prestige_panel.offset_left = -210; _prestige_panel.offset_top = -160
	_prestige_panel.offset_right = 210; _prestige_panel.offset_bottom = 160
	_prestige_panel.visible = false
	var psb := StyleBoxFlat.new(); psb.bg_color = Color(0.05, 0.04, 0.09, 0.95); psb.set_corner_radius_all(8)
	psb.set_border_width_all(2); psb.border_color = Color(0.72, 0.62, 0.95)
	_prestige_panel.add_theme_stylebox_override("panel", psb)
	_root.add_child(_prestige_panel)
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 8); _prestige_panel.add_child(pv)
	var ptitle := _mk_label("PRESTÍGIO", 20, Color(0.82, 0.74, 1.0)); pv.add_child(ptitle)
	_prestige_lbl = _mk_label("", 15, COL_TEXT); pv.add_child(_prestige_lbl)
	var prow := HBoxContainer.new(); prow.add_theme_constant_override("separation", 10); pv.add_child(prow)
	_prestige_btn = Button.new(); _prestige_btn.text = "PRESTIGIAR"; _prestige_btn.focus_mode = Control.FOCUS_NONE
	_prestige_btn.custom_minimum_size = Vector2(160, 34)
	_prestige_btn.pressed.connect(_on_prestige_pressed)
	prow.add_child(_prestige_btn)
	var pclose := Button.new(); pclose.text = "Fechar"; pclose.focus_mode = Control.FOCUS_NONE
	pclose.custom_minimum_size = Vector2(90, 34)
	pclose.pressed.connect(_on_prestige_close)
	prow.add_child(pclose)

	# ── FEEDBACK: +CP e toast de transição/marco (topo-centro, tempo real) ──
	_cpdelta_lbl = _mk_label("", 18, Color(0.6, 1.0, 0.7)); _cpdelta_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_cpdelta_lbl.position = Vector2(-40, 40); _cpdelta_lbl.visible = false
	_root.add_child(_cpdelta_lbl)
	_toast_lbl = _mk_label("", 20, COL_GOLD); _toast_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_lbl.position = Vector2(-60, 66); _toast_lbl.visible = false
	_root.add_child(_toast_lbl)

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# DADOS (delegam às APIs reais)
# ══════════════════════════════════════════════════════════════════════════════════════════════════
func _cp() -> int:
	return PowerBudget.cp()

func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null

## Nº com separador de milhar (ex.: 48210 → "48.210").
func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + out

## Rótulo do tipo de fase (real, do StageDirector — sem inventar lore).
func stage_kind_label() -> String:
	if _sd == null:
		return ""
	if _sd.is_wall_active():
		return "MURO"
	match _sd.stage_type():
		"boss": return "BOSS"
		"miniboss": return "APEX"
		_: return "AVANÇANDO" if _sd.mode == _sd.MODE_ADVANCE else "FARM"

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# ▸ IR — a DIREÇÃO CENTRAL. get_primary_action() é a fonte ÚNICA (sem espalhar ifs por callbacks).
# ══════════════════════════════════════════════════════════════════════════════════════════════════
## Retorna {action_id, label, description, target_panel, priority}.
func get_primary_action() -> Dictionary:
	# 0) BAÚ AFK pendente → COLETAR (prioridade máxima; recompensa esperando, §47). Integridade primeiro.
	if _ir != null and _ir.has_pending():
		var p: Dictionary = _ir.pending()
		return {"action_id": "claim_chest", "label": "▸ COLETAR (%s ouro)" % _fmt(int(p.get("gold", 0))),
			"description": "Recompensa AFK aguardando.", "target_panel": "chest", "priority": 6}
	# 0.5) PRESTÍGIO DISPONÍVEL → abre o painel (§43/§44). Fica logo abaixo do baú (integridade) e ACIMA do muro:
	# é o marco de longo prazo mais valioso quando alcançado; o baú (que bloqueia o Prestígio) já foi tratado em
	# (0). Overflow é buffer PROTEGIDO (nunca perde item) → ranqueia abaixo deste prompt. Desvio documentado do §44.
	if _pm != null and _pm.is_eligible() and not (_ir != null and _ir.has_pending()):
		return {"action_id": "open_prestige", "label": "▸ PRESTÍGIO DISPONÍVEL",
			"description": "Reinicie a jornada e suba de Mestre.", "target_panel": "prestige", "priority": 5}
	# 1) MURO: leva à MELHORIA recomendada. EQUIPAR mantém o contrato A4 (open_inventory / "Melhorar"); as
	# fontes A7 (refino/joia/claim) abrem o SystemPanel (PowerAdvisor 2.0, §58). "level"/"fallback" → FARM.
	if _sd != null and _sd.is_wall_active():
		var sug: Array = PowerAdvisor.suggest(1)
		if not sug.is_empty() and str(sug[0].get("kind", "")) == "equip":
			return {"action_id": "open_inventory", "label": "▸ Melhorar: %s" % str(sug[0].get("label", "")),
				"description": "+%d Poder" % int(sug[0].get("estimated_cp_gain", 0)), "target_panel": "inventory", "priority": 3}
		if not sug.is_empty() and str(sug[0].get("system_id", "")) != "" and int(sug[0].get("estimated_cp_gain", 0)) > 0 \
				and str(sug[0].get("kind", "")) in ["refine", "jewel", "bestiary", "codex"]:
			return {"action_id": "open_system", "label": "▸ %s" % str(sug[0].get("label", "Melhorar")),
				"description": "+%d Poder" % int(sug[0].get("estimated_cp_gain", 0)), "target_panel": "inventory", "system_id": str(sug[0].get("system_id", "")), "priority": 3}
		return {"action_id": "farm", "label": "▸ Fortaleça-se (FARM)", "description": "Continue farmando para subir de nível ou achar equipamento.", "target_panel": "", "priority": 2}
	# 2) OVERFLOW relevante → inventário
	if _lm != null and _gs() != null and _gs().overflow_count() > 0:
		return {"action_id": "open_inventory", "label": "▸ Coletar itens", "description": "Overflow: %d" % _gs().overflow_count(), "target_panel": "inventory", "priority": 2}
	# 3) AUTO OFF (avanço) → ligar a caça
	if _ap != null and not _ap.enabled:
		return {"action_id": "enable_auto", "label": "▸ Iniciar caça", "description": "Liga o modo automático.", "target_panel": "", "priority": 1}
	# 4) AVANÇANDO com Auto ON → só indica a progressão
	return {"action_id": "advancing", "label": "▸ Avançando — Fase %s" % (_sd.stage_label() if _sd != null else "—"), "description": "O Errante segue sozinho.", "target_panel": "", "priority": 0}

## Executa a ação primária (§14). Nunca força quest/narrativa (§54-T06) nem retry automático (§16).
func do_primary_action() -> void:
	var a := get_primary_action()
	match str(a["action_id"]):
		"claim_chest":
			if _chest_panel != null:
				_update_chest_text()
				_chest_panel.visible = true   # ▸IR abre o baú; o COLETAR aplica (não coleta sozinho)
		"open_prestige":
			_open_prestige_panel()   # ▸IR abre o painel; PRESTIGIAR (com confirmação) executa (não prestigia sozinho)
		"enable_auto":
			if _ap != null: _ap.set_enabled(true)
		"open_system":
			if _host != null and _host.has_method("idlehud_open_system"):
				_host.idlehud_open_system(str(a.get("system_id", "")))   # ▸IR abre o sistema recomendado (§7/§58)
		"open_inventory":
			_open_panel(str(a.get("target_panel", "inventory")))
		_:
			pass   # farm/advancing → apenas indicativo (foco)
	refresh(true)

# ── BADGES (V1) — só condição REAL, some quando a condição some (§32/§33) ──
func badge_inventory() -> bool:
	if _gs() != null and _gs().overflow_count() > 0:
		return true
	return _has_equip_upgrade()

func badge_equip() -> bool:
	return _has_equip_upgrade()

## Há upgrade guardado (item na mochila que sobe o CP)? Reusa o PowerAdvisor (SIM PURA).
func _has_equip_upgrade() -> bool:
	var sug: Array = PowerAdvisor.suggest(1)
	return not sug.is_empty() and str(sug[0].get("kind", "")) == "equip" and int(sug[0].get("estimated_cp_gain", 0)) > 0

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# AÇÕES DE UI
# ══════════════════════════════════════════════════════════════════════════════════════════════════
func _on_speed_pressed(mult: float) -> void:
	if _speed != null: _speed.apply_speed(mult)
	refresh(true)

func _on_auto_pressed() -> void:
	if _host != null and _host.has_method("_toggle_autoplay"):
		_host._toggle_autoplay()   # canal ÚNICO (mantém [P] e a UI sincronizados)
	elif _ap != null:
		_ap.toggle()
	refresh(true)

func _on_ir_pressed() -> void:
	do_primary_action()

func _on_retry_pressed() -> void:
	if _sd != null: _sd.request_retry()
	refresh(true)

## FATIA A5 — COLETAR o baú AFK (claim atômico via IdleRewards → LootManager). Fecha o painel.
func _on_claim_pressed() -> void:
	if _ir != null: _ir.claim()
	_chest_panel.visible = false
	refresh(true)

## Monta o texto do baú a partir do pending real.
func _update_chest_text() -> void:
	if _ir == null or _chest_lbl == null:
		return
	var p: Dictionary = _ir.pending()
	if p.is_empty():
		_chest_lbl.text = "—"
		return
	var n_items := 0
	for k in p.get("items", {}): n_items += int(p["items"][k])
	var n_mats := 0
	for k in p.get("materials", {}): n_mats += int(p["materials"][k])
	var end_lbl := _global_to_label(int(p.get("end_global", 1)))
	var farm_lbl := _global_to_label(int(p.get("farm_global", 1)))
	_chest_lbl.text = "Ausente: %s\n\nFases avançadas: %d\nAgora: %s\nFarm: %s · Ciclos: %d\n\n+ %s Ouro\n+ %s XP\n+ %d Equipamentos\n+ %d Materiais" % [
		_fmt_dur(int(p.get("seconds", 0))), int(p.get("stages_advanced", 0)), end_lbl, farm_lbl,
		int(p.get("farm_cycles", 0)), _fmt(int(p.get("gold", 0))), _fmt(int(p.get("xp", 0))), n_items, n_mats]

func _fmt_dur(seconds: int) -> String:
	seconds = maxi(0, seconds)
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	if h > 0: return "%dh %02dm" % [h, m]
	if m > 0: return "%dm" % m
	return "%ds" % seconds

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# PRESTÍGIO (FATIA A6) — abrir painel, confirmação in-game (§31), executar via PrestigeManager.
# ══════════════════════════════════════════════════════════════════════════════════════════════════
func _open_prestige_panel() -> void:
	if _prestige_panel == null:
		return
	_confirm_armed = false
	_update_prestige_text()
	_prestige_panel.visible = true

func _on_prestige_close() -> void:
	_confirm_armed = false
	if _prestige_panel != null:
		_prestige_panel.visible = false
	refresh(true)

## PRESTIGIAR: 1º clique ARMA a confirmação (troca o texto do botão); 2º clique EXECUTA (§31/§32). Ação
## destrutiva intencional → exige confirmação explícita in-game (não é "pedir autorização ao dono").
func _on_prestige_pressed() -> void:
	if _pm == null:
		return
	var gate: Dictionary = _pm.can_execute()
	if not bool(gate.get("ok", false)):
		# indisponível (ex.: baú pendente / requisito) → mostra o motivo, não executa.
		if _prestige_lbl != null:
			_prestige_lbl.text = str(gate.get("reason", "Prestígio indisponível."))
		_confirm_armed = false
		_prestige_btn.text = "PRESTIGIAR"
		return
	if not _confirm_armed:
		_confirm_armed = true
		_prestige_btn.text = "CONFIRMAR PRESTÍGIO"
		if _prestige_lbl != null:
			_prestige_lbl.text = "Confirmar Prestígio?\nA jornada idle retornará à fase 1-1.\nSeu personagem, itens e progresso narrativo\nserão PRESERVADOS."
		return
	# 2º clique confirmado → executa a transação atômica.
	var res: Dictionary = _pm.execute_prestige(int(Time.get_unix_time_from_system()))
	_confirm_armed = false
	_prestige_btn.text = "PRESTIGIAR"
	_prestige_panel.visible = false
	if bool(res.get("ok", false)) and _toast_lbl != null:
		_toast_lbl.text = "★ PRESTÍGIO %d · MESTRE %d" % [int(res.get("prestige_count", 0)), int(res.get("master_level", 0))]
		_toast_lbl.visible = true
		_toast_t = TOAST_HOLD
	refresh(true)

## Texto do painel de Prestígio a partir do status REAL do PrestigeManager (§62). Disponível vs indisponível (§30).
func _update_prestige_text() -> void:
	if _pm == null or _prestige_lbl == null:
		return
	var s: Dictionary = _pm.status()
	_prestige_btn.text = "PRESTIGIAR"
	if bool(s.get("eligible", false)):
		_prestige_lbl.text = "PRESTÍGIO DISPONÍVEL\n\nFase: %d / %d\nSelos: %d / %d\n\nMaster Level  %d → %d\n+%d%% base permanente\n\nPODER  %s → %s  (+%s)\n\nSua jornada idle voltará para 1-1.\nPersonagem, itens, nível e narrativa preservados." % [
			int(s["cycle_highest"]), int(s["required_stage"]), int(s["cycle_seals"]), int(s["required_seals"]),
			int(s["master_level"]), int(s["master_level"]) + 1, int(round((float(s["next_mult"]) / maxf(float(s["cur_mult"]), 0.0001) - 1.0) * 100.0)),
			_fmt(int(s["current_cp"])), _fmt(int(s["projected_cp"])), _fmt(int(s["delta_cp"]))]
		_prestige_btn.disabled = false
	else:
		_prestige_lbl.text = "Maior fase do ciclo: %d\nNecessário: %d\n\nSelos: %d / %d\n\nPróximo Master: +%d%% base permanente\n\n(Reseta só a jornada idle; personagem preservado.)" % [
			int(s["cycle_highest"]), int(s["required_stage"]), int(s["cycle_seals"]), int(s["required_seals"]),
			int(round((float(s["next_mult"]) / maxf(float(s["cur_mult"]), 0.0001) - 1.0) * 100.0))]
		_prestige_btn.disabled = true

func _global_to_label(g: int) -> String:
	g = maxi(1, g)
	return "%d-%d" % [(g - 1) / 10 + 1, (g - 1) % 10 + 1]

func _on_system_pressed(id: String) -> void:
	_open_panel(id)

func _open_panel(id: String) -> void:
	if _host == null:
		return
	match id:
		"systems": if _host.has_method("idlehud_open_system"): _host.idlehud_open_system("")   # FATIA A7: molde genérico
		"inventory": if _host.has_method("idlehud_open_inventory"): _host.idlehud_open_inventory()
		"equip": if _host.has_method("idlehud_open_inventory"): _host.idlehud_open_inventory()
		"mastery": if _host.has_method("idlehud_open_mastery"): _host.idlehud_open_mastery()
		"shop": if _host.has_method("idlehud_open_shop"): _host.idlehud_open_shop()

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# REFRESH (throttled ~8Hz; feedbacks em tempo REAL)
# ══════════════════════════════════════════════════════════════════════════════════════════════════
## Chamado pelo Main no _process. `force` ignora o throttle.
func refresh(force: bool = false) -> void:
	if not _booted:
		return
	var dt_real := 1.0 / REFRESH_HZ
	if not force:
		_refresh_t += get_process_delta_time()
		if _refresh_t < dt_real:
			# ainda assim decai os feedbacks (tempo real) p/ não ficarem presos
			_tick_feedback()
			return
	_refresh_t = 0.0

	# PODER + delta
	var cp := _cp()
	if _last_cp >= 0 and cp != _last_cp:
		var d := cp - _last_cp
		if d > 0:
			_cpdelta_lbl.text = "+%s PODER" % _fmt(d)
			_cpdelta_lbl.visible = true
			_cpdelta_t = CPDELTA_HOLD
	_last_cp = cp
	_power_lbl.text = "PODER %s" % _fmt(cp)

	# A17.1 §1: a LINHA PRINCIPAL mostra só os recursos essenciais (Ouro/Frag./Nv). As TAXAS/h (ouro/h·XP/h·drops/h)
	# NÃO ficam mais aqui — pertencem ao painel de sessão/estatísticas (menos ruído permanente no topo).
	var gs = _gs()
	if gs != null:
		var frag := int(gs.materials.get("Fragmentos", 0))
		_res_lbl.text = "Ouro %s    Frag. %s    Nv %d" % [_fmt(gs.hero_gold), _fmt(frag), gs.hero_level]

	# FASE
	var slabel: String = _sd.stage_label() if _sd != null else "—"
	var kind := stage_kind_label()
	_topstage_lbl.text = "FASE %s · %s" % [slabel, kind]
	_stage_lbl.text = "FASE %s · %s" % [slabel, kind]
	# transição/marco (toast) quando o rótulo muda
	if slabel != _last_stage_label and _last_stage_label != "":
		var marco := ""
		if _sd != null and _sd.stage_type() == "boss": marco = "  ⚔ BOSS"
		elif _sd != null and _sd.stage_type() == "miniboss": marco = "  ✦ APEX"
		_toast_lbl.text = "FASE %s → %s%s" % [_last_stage_label, slabel, marco]
		_toast_lbl.visible = true
		_toast_t = TOAST_HOLD
	_last_stage_label = slabel

	# progresso / boss / wall
	if _sd != null and _sd.is_wall_active():
		_progress.visible = false; _progress_lbl.visible = false
	elif _sd != null and _sd.stage_type() != "normal":
		_progress.visible = true; _progress.value = 0; _progress_lbl.visible = true
		_progress_lbl.text = ("BOSS" if _sd.stage_type() == "boss" else "APEX")
	elif _sd != null:
		_progress.visible = true; _progress_lbl.visible = true
		var q: int = _sd.stage_quota()
		_progress.max_value = maxi(1, q)
		_progress.value = _sd.stage_kills
		_progress_lbl.text = "%d/%d" % [_sd.stage_kills, q]

	# AUTO sync
	var on: bool = _ap != null and _ap.enabled
	_auto_btn.text = ("AUTO ✓" if on else "AUTO ✗")
	_auto_top_lbl.text = ("AUTO ✓" if on else "AUTO ✗")
	_auto_top_lbl.add_theme_color_override("font_color", (Color(0.55, 0.95, 0.65) if on else COL_DIM))

	# SPEED sync
	var idx: int = _speed.speed_index() if _speed != null else 0
	for i in range(_speed_btns.size()):
		_speed_btns[i].button_pressed = (i == idx)

	# IR label
	_ir_btn.text = str(get_primary_action().get("label", "▸ IR"))

	# MESTRE / PRESTÍGIO (A6) — placar discreto (§61); badge REAL quando o Prestígio está disponível (§45).
	if _master_lbl != null and _pm != null:
		var pc: int = _pm.prestige_count()
		var ml: int = _pm.master_level()
		if pc > 0 or ml > 0:
			var suffix := "  ✦ PRESTÍGIO PRONTO" if _pm.is_eligible() else ""
			_master_lbl.text = "MESTRE %d · PRESTÍGIO %d%s" % [ml, pc, suffix]
			_master_lbl.visible = true
		elif _pm.is_eligible():
			_master_lbl.text = "✦ PRESTÍGIO PRONTO"
			_master_lbl.visible = true
		else:
			_master_lbl.visible = false
	# mantém o painel de Prestígio vivo enquanto aberto (não re-arma a confirmação)
	if _prestige_panel != null and _prestige_panel.visible and not _confirm_armed:
		_update_prestige_text()

	# MURO
	if _sd != null and _sd.is_wall_active() and not _activity_active():   # A34 §3/§7 — durante Hunt/Mission o Activity HUD manda; o wall recolhe (não empilha no top-right)
		_wall_panel.visible = true
		var need: int = _sd.frontier_required_cp()
		var faltam: int = maxi(0, need - cp)
		var advline := ""
		var sug: Array = PowerAdvisor.suggest(1)
		if not sug.is_empty():
			advline = "\nSugestão: %s" % str(sug[0].get("label", ""))
		_wall_lbl.text = "PODER INSUFICIENTE\nSeu Poder: %s\nRecomendado: %s\nFaltam: %s\nFARM %s · Frente %s%s" % [
			_fmt(cp), _fmt(need), _fmt(faltam), _sd.stage_label(), _sd.frontier_label(), advline]
	else:
		_wall_panel.visible = false

	# BADGES
	if _sys_btns.has("inventory"): _sys_btns["inventory"]["badge"].visible = badge_inventory()
	if _sys_btns.has("equip"): _sys_btns["equip"]["badge"].visible = badge_equip()
	# FATIA A7 — badge de Sistemas = qualquer sistema com ação REAL disponível (§6/§68); some quando some.
	if _sys_btns.has("systems") and _host != null and _host.has_method("idlehud_systems_badge"):
		_sys_btns["systems"]["badge"].visible = bool(_host.idlehud_systems_badge())

	_tick_feedback()

## Decaimento dos feedbacks (+CP / toast) em tempo REAL (imune ao time_scale).
func _tick_feedback() -> void:
	var d := get_process_delta_time()
	var scale := Engine.time_scale
	var real := d / (scale if scale > 0.0 else 1.0)   # converte delta escalado → tempo real aprox.
	if _cpdelta_t > 0.0:
		_cpdelta_t -= real
		if _cpdelta_t <= 0.0: _cpdelta_lbl.visible = false
	if _toast_t > 0.0:
		_toast_t -= real
		if _toast_t <= 0.0: _toast_lbl.visible = false
