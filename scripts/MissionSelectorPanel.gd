class_name MissionSelectorPanel extends PanelContainer
## A25.3 — Seletor de missão REAL. Reusa GoldenPath (status) + AfkMissionDefinition (dados). Disclosure progressivo:
## capítulo atual + concluídas/atual/próxima. [INICIAR] usa o MissionHost existente (via sinal). Sem quest engine novo.

signal start_requested(mission_id: String)
signal back_requested()

var golden: GoldenPath = null
var selected_mission := ""
var _vb: VBoxContainer = null
var _pres := "desktop"
var start_buttons: Array = []   # [{mid, btn}]
var back_btn: Button = null

func open(p_golden: GoldenPath, select_mission := "", presentation := "desktop") -> void:
	golden = p_golden; _pres = presentation; selected_mission = select_mission
	for c in get_children(): remove_child(c); c.free()
	start_buttons.clear()
	custom_minimum_size = Vector2(420, 0)
	_vb = VBoxContainer.new(); _vb.add_theme_constant_override("separation", 6); add_child(_vb)
	# capítulo atual (progressão por conclusão de capítulo). Chapter 3 só aparece após Chapter 2 completo.
	var ch1_done := golden.is_chapter_complete("CHAPTER_1_WOLF")
	var ch2_done := golden.is_chapter_complete("CHAPTER_2_CRYSTAL")
	var ch3_done := golden.is_chapter_complete("CHAPTER_3_SPIDER")
	var ch4_done := golden.is_chapter_complete("CHAPTER_4_SALTWIND")
	var chapter_id := AfkMissionDefinition.CHAPTER_1
	var chapter_name := "CAPÍTULO 1 — A MATILHA"
	if ch4_done:
		chapter_id = AfkMissionDefinition.CHAPTER_5; chapter_name = "CAPÍTULO 5 — NINHO DAS RAÍZES ANTIGAS"
	elif ch3_done:
		chapter_id = AfkMissionDefinition.CHAPTER_4; chapter_name = "CAPÍTULO 4 — COSTA DO SAL-VENTO"
	elif ch2_done:
		chapter_id = AfkMissionDefinition.CHAPTER_3; chapter_name = "CAPÍTULO 3 — NINHO NA MATA"
	elif ch1_done:
		chapter_id = "CHAPTER_2_CRYSTAL"; chapter_name = "CAPÍTULO 2 — CAVERNA DE CRISTAL"
	_lbl(chapter_name, 16)
	# A26/A29 — estado PRÉ-BOSS: última missão concluída → o Boss ainda não existe (candidate/contrato).
	if chapter_id == AfkMissionDefinition.CHAPTER_3 and golden.chapter3_preboss_ready():
		_lbl("PREPARAÇÃO PARA O BOSS — uma presença domina o ninho. (Chefe em breve.)", 12)
	elif chapter_id == AfkMissionDefinition.CHAPTER_4 and golden.chapter4_preboss_ready():
		_lbl("PREPARAÇÃO PARA O BOSS — uma tempestade se agita na maré. (Chefe em breve.)", 12)
	elif chapter_id == AfkMissionDefinition.CHAPTER_5 and golden.chapter5_preboss_ready():
		_lbl("PREPARAÇÃO PARA O BOSS — as raízes se contorcem; a Matriarca desperta. (Chefe em breve.)", 12)
	var tt := UiMetrics.min_touch_target(_pres, "TT_B")
	var chain: Array = AfkMissionDefinition.chapter_chain(chapter_id)
	for mid in chain:
		var complete := golden.is_complete(mid)
		var available := golden.is_available(mid)
		# disclosure: mostra concluídas + disponíveis; oculta locked distantes
		if not complete and not available: continue
		var m: Dictionary = AfkMissionDefinition.get_mission(mid)
		var status := "CONCLUÍDA" if complete else ("DISPONÍVEL" if available else "BLOQUEADA")
		var focus := "▶ " if mid == selected_mission else ""
		var pc := PanelContainer.new(); var row := VBoxContainer.new(); pc.add_child(row)
		_lbl_to(row, "%s%s  [%s]" % [focus, str(m.get("intro_profile", {}).get("title", mid)), status], 13)
		_lbl_to(row, "Objetivo: %s x%d" % [str(m.get("objective_type", "")), int(m.get("required_count", 0))], 11)
		var diffs: Array = m.get("available_difficulties", ["NORMAL"])
		_lbl_to(row, "Dificuldade: %s" % ", ".join(diffs), 11)
		if available and not complete:
			var b := Button.new(); b.text = "INICIAR"; b.custom_minimum_size = Vector2(0, tt)
			b.pressed.connect(func(): start_requested.emit(mid))
			row.add_child(b); start_buttons.append({"mid": mid, "btn": b})
		_vb.add_child(pc)
	back_btn = Button.new(); back_btn.text = "VOLTAR"; back_btn.custom_minimum_size = Vector2(0, UiMetrics.min_touch_target(_pres, "TT_D"))
	back_btn.pressed.connect(func(): back_requested.emit())
	_vb.add_child(back_btn)

func select(mission_id: String) -> void:
	open(golden, mission_id, _pres)

func _lbl(txt: String, size: int) -> void: _lbl_to(_vb, txt, size)
func _lbl_to(parent: Node, txt: String, size: int) -> void:
	var l := Label.new(); l.text = txt; l.add_theme_font_size_override("font_size", size); parent.add_child(l)
func start_button_for(mid: String) -> Button:
	for e in start_buttons:
		if str(e["mid"]) == mid: return e["btn"]
	return null
func mission_count() -> int: return start_buttons.size()
