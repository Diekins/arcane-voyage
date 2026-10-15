class_name BestiaryPanel extends PanelContainer
## A25.2 — Bestiário REAL por-mob. Reusa MobEligibility (família/habitat/drops) + gs.bestiary (kills) + resolver
## (discovery). Lista lateral + detalhe; drops KNOWN clicáveis → Item Inspection; [CAÇAR] → Targeted Hunt.
## A32 — categoria BOSSES: Encounter Intelligence (status/região/disponibilidade/drops/first-clear/LUTAR), enumerada
## do registry via BossBestiary (deriva do save, zero backend novo). spider_matriarch É boss; root_matriarch NÃO aparece.

signal inspect_requested(item_key: String)
signal hunt_requested(ground_id: String, mob_id: String, difficulty: String)
signal boss_fight_requested(boss_id: String)
signal back_requested()

var _resolver: AcquisitionResolver = null
var gs = null
var _golden: GoldenPath = null
var selected_mob := ""
var selected_boss := ""
var _category := "MOBS"          # "MOBS" | "BOSSES"
var _list: VBoxContainer = null
var _detail: VBoxContainer = null
var _pres := "desktop"
var mob_buttons: Array = []      # [{mob, btn}]
var boss_buttons: Array = []     # [{boss_id, btn}]
var drop_buttons: Array = []     # [{item_key, btn}]
var cat_mobs_btn: Button = null
var cat_bosses_btn: Button = null
var hunt_btn: Button = null
var fight_btn: Button = null
var boss_locked_lbl: Label = null
var back_btn: Button = null

# A42 §8/§24 — REGISTRY-DRIVEN: os mobs caçáveis derivam de MobEligibility (allowed_hunts não-vazio), NÃO uma lista
# hard-coded. Adicionar mob com Targeted Hunt (ex.: família RAIZ do Ch5) ⇒ aparece automaticamente no Bestiário.
static func huntable() -> Array:
	return MobEligibility.huntable_ids()

func open(resolver: AcquisitionResolver, p_gs, select_mob := "", presentation := "desktop") -> void:
	_resolver = resolver; gs = p_gs; _pres = presentation
	_golden = GoldenPath.new(); _golden.setup(gs)
	_category = "MOBS"; selected_boss = ""
	for c in get_children(): remove_child(c); c.free()
	# A36 §5/§6 — mesma FAMÍLIA VISUAL dos painéis (só visual; A32 intacto)
	var _sbt := HudArtPack.panel_stylebox("panels/panel_frame.png")
	if _sbt != null: add_theme_stylebox_override("panel", _sbt)
	custom_minimum_size = Vector2(520, 360)
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 12); add_child(hb)
	_list = VBoxContainer.new(); _list.custom_minimum_size = Vector2(190, 0); hb.add_child(_list)
	_detail = VBoxContainer.new(); _detail.custom_minimum_size = Vector2(300, 0); hb.add_child(_detail)
	_rebuild_list()
	select(select_mob if select_mob != "" else huntable()[0])

## Abre já na categoria BOSSES com um boss selecionado (navegação a partir de "COMO OBTER → Boss X").
func open_boss(resolver: AcquisitionResolver, p_gs, boss_id: String, presentation := "desktop") -> void:
	open(resolver, p_gs, "", presentation)
	_set_category("BOSSES")
	if boss_id != "" and BossActivityDefinition.exists(boss_id): _select_boss(boss_id)

func _set_category(cat: String) -> void:
	if _category == cat: return
	_category = cat
	_rebuild_list()
	if cat == "BOSSES":
		var ids := BossBestiary.boss_ids()
		if not ids.is_empty(): _select_boss(str(ids[0]))
	else:
		select(huntable()[0])

func _rebuild_list() -> void:
	for c in _list.get_children(): _list.remove_child(c); c.free()
	mob_buttons.clear(); boss_buttons.clear()
	_list.add_child(_lbl("BESTIÁRIO", 16))
	# ── seletor de categoria (MOBS / BOSSES) ──
	var cat := HBoxContainer.new(); _list.add_child(cat)
	cat_mobs_btn = Button.new(); cat_mobs_btn.text = "MOBS"
	cat_mobs_btn.custom_minimum_size = Vector2(100, UiMetrics.min_touch_target(_pres, "TT_D"))
	_apply_tab(cat_mobs_btn, _category == "MOBS")   # A37 §2/§3 — ABA real; selected = categoria ativa
	cat_mobs_btn.pressed.connect(func(): _set_category("MOBS")); cat.add_child(cat_mobs_btn)
	cat_bosses_btn = Button.new(); cat_bosses_btn.text = "BOSSES"
	cat_bosses_btn.custom_minimum_size = Vector2(100, UiMetrics.min_touch_target(_pres, "TT_D"))
	_apply_tab(cat_bosses_btn, _category == "BOSSES")
	cat_bosses_btn.pressed.connect(func(): _set_category("BOSSES")); cat.add_child(cat_bosses_btn)
	var tt := UiMetrics.min_touch_target(_pres, "TT_B")
	if _category == "MOBS":
		for mob in huntable():
			var m := MobEligibility.get_mob(mob)
			if m.is_empty(): continue
			var b := Button.new(); b.text = str(m.get("visual_id", mob)); b.custom_minimum_size = Vector2(186, tt)
			b.pressed.connect(func(): select(mob))
			_list.add_child(b); mob_buttons.append({"mob": mob, "btn": b})
	else:
		var wk := _weapon_kind()
		for e in BossBestiary.all_entries(_golden, wk):
			var bid := str(e["boss_id"])
			var mark := "✓" if bool(e["defeated"]) else ("•" if bool(e["discovered"]) else "?")
			var nm := str(e["display_name"])
			var b := Button.new(); b.text = "%s %s" % [mark, nm]; b.custom_minimum_size = Vector2(186, tt)
			b.pressed.connect(func(): _select_boss(bid))
			_list.add_child(b); boss_buttons.append({"boss_id": bid, "btn": b})
	back_btn = Button.new(); back_btn.text = "VOLTAR"; back_btn.custom_minimum_size = Vector2(186, UiMetrics.min_touch_target(_pres, "TT_D"))
	back_btn.pressed.connect(func(): back_requested.emit()); _list.add_child(back_btn)

## A37 — ABA real (panel_tab) para os toggles MOBS/BOSSES; selected reflete a categoria ativa (não decorativo).
func _apply_tab(b: Button, selected: bool) -> void:
	var base := HudArtPack.panel_stylebox("panels/panel_tab_selected.png" if selected else "panels/panel_tab_normal.png")
	if base == null: return
	b.add_theme_stylebox_override("normal", base)
	var sel := HudArtPack.panel_stylebox("panels/panel_tab_selected.png")
	if sel != null: b.add_theme_stylebox_override("hover", sel); b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_color_override("font_color", Color("f0c860") if selected else Color("cdd2dc"))
	b.focus_mode = Control.FOCUS_NONE

func _weapon_kind() -> String:
	if gs != null and gs.has_method("current_weapon_type"):
		var wk := str(gs.current_weapon_type())
		return "" if wk == "unarmed" else wk
	return ""

# ══════════════════════════════════ MOB DETAIL (inalterado A25) ══════════════════════════════════
func select(mob_id: String) -> void:
	selected_mob = mob_id; selected_boss = ""
	for c in _detail.get_children(): _detail.remove_child(c); c.free()
	drop_buttons.clear(); hunt_btn = null; fight_btn = null; boss_locked_lbl = null
	var m := MobEligibility.get_mob(mob_id)
	if m.is_empty(): _lbl_to(_detail, "—", 14); return
	var tt := UiMetrics.min_touch_target(_pres, "TT_B")
	_lbl_to(_detail, str(m.get("visual_id", mob_id)).to_upper(), 18)
	_lbl_to(_detail, "Família: %s" % str(m.get("family", "—")), 12)
	var hunts: Array = m.get("allowed_hunts", [])
	var ground := str(hunts[0]) if hunts.size() > 0 else ""
	_lbl_to(_detail, "Habitat: %s" % (HuntingGround.map_of(ground) if ground != "" else "—"), 12)
	var kills := int((gs.bestiary.get(mob_id, {}) as Dictionary).get("kills", 0)) if gs != null else 0
	_lbl_to(_detail, "Abates: %d" % kills, 12)
	var disc := _resolver.discovery_state(mob_id) if _resolver != null else "HINTED"
	_lbl_to(_detail, "Descoberta: %s" % disc, 12)
	_detail.add_child(HSeparator.new())
	_lbl_to(_detail, "Drops conhecidos:", 13)
	var lp: Dictionary = m.get("loot_profile", {})
	var drops: Array = []
	var mat: Dictionary = lp.get("material", {})
	if not mat.is_empty(): drops.append(str(mat.get("name", "")))
	for g in lp.get("gear_pool", []): drops.append(str(g))
	for item_key in drops:
		if disc == "KNOWN":
			var db := Button.new(); db.text = item_key; db.custom_minimum_size = Vector2(0, tt)
			db.pressed.connect(func(): inspect_requested.emit(item_key))
			_detail.add_child(db); drop_buttons.append({"item_key": item_key, "btn": db})
		else:
			_lbl_to(_detail, "???", 12)
	if ground != "" and HuntingGround.is_unlocked(ground, PowerBudget.cp(), int(gs.stage_highest_global) if gs != null else 0):
		hunt_btn = Button.new(); hunt_btn.text = "CAÇAR"; hunt_btn.custom_minimum_size = Vector2(0, tt)
		hunt_btn.pressed.connect(func(): hunt_requested.emit(ground, mob_id, "NORMAL"))
		_detail.add_child(hunt_btn)
	else:
		_lbl_to(_detail, "Caça bloqueada (requer progresso).", 11)

# ══════════════════════════════════ BOSS DETAIL (A32 — Encounter Intelligence) ══════════════════════════════════
func _select_boss(boss_id: String) -> void:
	selected_boss = boss_id; selected_mob = ""
	for c in _detail.get_children(): _detail.remove_child(c); c.free()
	drop_buttons.clear(); hunt_btn = null; fight_btn = null; boss_locked_lbl = null
	var e := BossBestiary.entry(_golden, boss_id, _weapon_kind())
	if e.is_empty(): _lbl_to(_detail, "—", 14); return
	var tt := UiMetrics.min_touch_target(_pres, "TT_B")
	var st := str(e["discovery"])
	# NAME + STATUS
	_lbl_to(_detail, str(e["display_name"]).to_upper(), 18)
	_lbl_to(_detail, "Status: %s" % st, 12)
	if st == BossBestiary.UNKNOWN:
		_lbl_to(_detail, "Boss ainda não descoberto — avance no capítulo para revelar.", 11)
		return   # spoiler gate: nada além da identidade oculta
	# LOCATION (região/capítulo, NÃO waypoint — PvE não tem caminhada)
	_lbl_to(_detail, "Capítulo: %s" % str(e["chapter_id"]), 12)
	_lbl_to(_detail, "Região: %s" % str(e["region"]), 12)
	# AVAILABILITY
	if bool(e["available"]):
		_lbl_to(_detail, "Disponível: SIM (sempre, após desbloqueio)", 12)
	else:
		_lbl_to(_detail, "Disponível: NÃO — %s" % str(e["locked_reason"]), 12)
	# DIFFICULTY + BEST
	_lbl_to(_detail, "Dificuldade: %s" % ", ".join(e["difficulties"]), 12)
	if bool(e["defeated"]):
		_lbl_to(_detail, "Melhor dificuldade vencida: %s" % str(e["best_difficulty"]), 12)
	_detail.add_child(HSeparator.new())
	# FIRST CLEAR
	_lbl_to(_detail, ("FIRST CLEAR: COMPLETO ✓" if bool(e["first_clear_complete"]) else "FIRST CLEAR: pendente"), 13)
	# DROPS (GUARANTEED vs POSSIBLE; ??? até derrotar)
	var d: Dictionary = e["drops"]
	_lbl_to(_detail, "Recompensas:", 13)
	for g in d.get("guaranteed", []):
		var gk := str(g.get("item_key", ""))
		var suffix := " (resgatado)" if bool(g.get("claimed", false)) else ""
		if gk != "":
			var gb := Button.new(); gb.text = "GARANTIDO (1ª vitória): %s%s" % [gk, suffix]; gb.custom_minimum_size = Vector2(0, tt)
			gb.pressed.connect(func(): inspect_requested.emit(gk))
			_detail.add_child(gb); drop_buttons.append({"item_key": gk, "btn": gb})
		else:
			_lbl_to(_detail, "GARANTIDO (1ª vitória): arma da sua classe%s" % suffix, 12)
	for p in d.get("possible", []):
		if bool(p.get("revealed", false)):
			var pk := str(p.get("real_key", ""))
			var pb := Button.new(); pb.text = "PODE DROPAR: %s" % pk; pb.custom_minimum_size = Vector2(0, tt)
			pb.pressed.connect(func(): inspect_requested.emit(pk))
			_detail.add_child(pb); drop_buttons.append({"item_key": pk, "btn": pb})
		else:
			_lbl_to(_detail, "PODE DROPAR: ??? (derrote para revelar)", 11)
	_detail.add_child(HSeparator.new())
	# FIGHT ACTION (respeita o gate: LUTAR só se disponível; senão explica o requisito)
	if bool(e["available"]):
		fight_btn = Button.new(); fight_btn.text = ("LUTAR NOVAMENTE" if bool(e["defeated"]) else "LUTAR"); fight_btn.custom_minimum_size = Vector2(0, tt)
		fight_btn.pressed.connect(func(): boss_fight_requested.emit(boss_id))
		_detail.add_child(fight_btn)
	else:
		boss_locked_lbl = _lbl("Bloqueado: %s" % str(e["locked_reason"]), 11)
		_detail.add_child(boss_locked_lbl)

func _lbl(txt: String, size: int) -> Label:
	var l := Label.new(); l.text = txt; l.add_theme_font_size_override("font_size", size); return l
func _lbl_to(parent: Node, txt: String, size: int) -> void:
	parent.add_child(_lbl(txt, size))

# acessores de teste
func mob_button_for(mob: String) -> Button:
	for e in mob_buttons:
		if str(e["mob"]) == mob: return e["btn"]
	return null
func boss_button_for(boss_id: String) -> Button:
	for e in boss_buttons:
		if str(e["boss_id"]) == boss_id: return e["btn"]
	return null
func drop_button_for(item_key: String) -> Button:
	for e in drop_buttons:
		if str(e["item_key"]) == item_key: return e["btn"]
	return null
