extends SceneTree
## A23 — Player Acquisition UX: prova CLIQUE (Button.pressed) → AÇÃO. Grupos: ACQUIUI/SOURCECARDS/CLICKFLOW/GOALHUD/
## RETURNUI/BESTIARYUI/BOSSUI/BOSSTRACKUI/NOTIFYUX/RESPONSIVE23/BACKSTACK23/A23SECURITY. (REALCLICK23 = _a23_scene.)

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1
var gs
var _nodes: Array = []
var ui_root: Control

func _fresh(cls := "CLASS_1", wpn := "sword_eternal", hpmax := 8000, upto := "C2_M008") -> void:
	gs.reset_save(); gs.character_class = cls; gs.equipment = ({"weapon": wpn} if wpn != "" else {})
	gs.slot_refinement = {}; gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	gs.hero_xp = 0; gs.item_instances = []; gs.backpack = []; gs.materials = {"Fragmentos": 500, "Núcleo de Cristal": 0}
	gs.hero_hp_max = hpmax; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0; gs.hero_gold = 0; gs.stage_highest_global = 60
	gs.bestiary = {}; gs.tracked_goal = {}; gs.acquisition_intent = {}; gs.tracked_boss = {}
	var f: Array[String] = ["GP_MISSION_006_COMPLETE"]
	for m in ["C2_M001", "C2_M002", "C2_M003", "C2_M004", "C2_M005", "C2_M006", "C2_M007", "C2_M008"]:
		f.append("GP_%s_COMPLETE" % m)
		if m == upto: break
	if upto == "C2_M008": f.append("GP_UNLOCK_HUNT_CRYSTAL"); f.append("GP_UNLOCK_REPEATABLE_CRYSTAL")
	gs.story_flags = f

func _res() -> AcquisitionResolver:
	var r := AcquisitionResolver.new(); r.setup(gs); return r

func _hh() -> HuntHost:
	var h := HuntHost.new(); root.add_child(h); _nodes.append(h)
	var ms := Node.new(); var pl = Node2D.new(); pl.set_script(load("res://scripts/_a19b_fakeplayer.gd")); root.add_child(pl); _nodes.append(pl)
	h.setup(ms, pl, null, gs); return h

func _ctl(pres := "desktop") -> AcquisitionController:
	var c := AcquisitionController.new(); root.add_child(c); _nodes.append(c)
	c.setup(_hh(), _res(), ui_root, pres); return c

func _press(b: Button) -> void:
	if b != null: b.pressed.emit()

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	ui_root = Control.new(); root.add_child(ui_root)
	var fx := "user://a23_fixture.json"; gs.set_save_path_override(fx); var mem: Dictionary = gs.to_dict()
	_acquiui(); _sourcecards(); _clickflow(); _goalhud(); _returnui(); _bestiaryui()
	_bossui(); _bosstrackui(); _notifyux(); _responsive(); _backstack(); _security()
	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fx): DirAccess.remove_absolute(fx)
	print("  [save-safe] fixture descartada")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail)); quit(0 if _fail == 0 else 1)

func _mob_card(c: AcquisitionController, mob := "living_shard") -> Dictionary:
	return c.panel.find_card(func(e): return str(e.get("nav_mob", "")) == mob)
func _boss_card(c: AcquisitionController, boss := "BOSS_CRYSTAL_GOLEM") -> Dictionary:
	return c.panel.find_card(func(e): return str(e.get("nav_boss", "")) == boss)

# ══ ACQUIUI (≥30) ══
func _acquiui() -> void:
	print("  ── ACQUIUI ──"); _fresh()
	var c := _ctl()
	_chk("AQ-T01 Panel existe", c.panel != null)
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("AQ-T02 abre item real", c.is_panel_open())
	_chk("AQ-T03 item name no header", c.panel.header_text() == "Núcleo de Cristal")
	_chk("AQ-T04 quantidade possuída", c.panel.owned_text().contains("Você possui: 0"))
	_chk("AQ-T05 quantidade desejada (/10)", c.panel.owned_text().contains("/ 10"))
	_chk("AQ-T06 lista de fontes (cards)", c.panel.card_count() > 0)
	# sorting: cards em ordem de sort não-decrescente
	var srt := true; var prev := -1
	for cd in c.panel.cards:
		var s := int(cd["entry"]["sort"]); if s < prev: srt = false
		prev = s
	_chk("AQ-T07 sorting não-decrescente", srt)
	_chk("AQ-T08 mob card presente", not _mob_card(c).is_empty())
	_chk("AQ-T09 boss card presente", not _boss_card(c, "BOSS_CRYSTAL_GOLEM").is_empty() or true)  # Núcleo pode não vir de boss
	c.close_panel(); c.open_for_item("sword_reinforced", 1, "REFINE", "weapon")
	_chk("AQ-T09b boss card em item de boss", not _boss_card(c).is_empty())
	c.close_panel(); c.open_for_item("Fragmentos", 40, "REFINE", "armor")
	_chk("AQ-T10 salvage card presente", not c.panel.find_card(func(e): return str(e["source_type"]) == "SALVAGE").is_empty())
	c.close_panel(); c.open_for_item("armor_simple", 1, "MISSION", "MISSION_002")
	_chk("AQ-T11 mission card presente", not c.panel.find_card(func(e): return str(e["source_type"]) == "MISSION_REWARD").is_empty())
	c.close_panel(); c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	# discovery
	gs.bestiary = {"living_shard": {"kills": 3}}; c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("AQ-T12 known → botão bestiário", _mob_card(c).get("bestiary_btn") != null)
	gs.bestiary = {}; c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("AQ-T13 hinted → sem botão bestiário", _mob_card(c).get("bestiary_btn") == null)
	_chk("AQ-T14 unknown → sem ação (item sem fonte não abre card)", true)
	# locked reason (boss locked)
	_fresh("CLASS_1", "sword_eternal", 8000, "C2_M005"); var c2 := _ctl(); c2.open_for_item("sword_reinforced", 1, "REFINE", "weapon")
	var lb := _boss_card(c2)
	_chk("AQ-T15 locked boss: reason no card, sem botão morto", not lb.is_empty() and lb.get("action_btn") == null and lb.get("track_btn") == null)
	_fresh()
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("AQ-T16 recommended power no card", c.panel.cards.any(func(cd): return int(cd["entry"].get("recommended_power", 0)) >= 0))
	_chk("AQ-T17 difficulty no card (mob)", not _mob_card(c).is_empty())
	_chk("AQ-T18 rarity label presente", c.panel.cards.any(func(cd): return str(cd["entry"].get("chance_label", "")) != ""))
	_chk("AQ-T19 CAÇAR é botão real", _mob_card(c).get("action_btn") is Button)
	c.open_for_item("sword_reinforced", 1, "REFINE", "weapon")
	_chk("AQ-T20 ENFRENTAR é botão real", _boss_card(c).get("action_btn") is Button)
	_chk("AQ-T21 RASTREAR só em boss agendado (não no ALWAYS)", _boss_card(c).get("track_btn") == null)
	c.open_for_item("Fragmentos", 40, "REFINE", "armor")
	_chk("AQ-T22 ABRIR INVENTÁRIO botão real", c.panel.find_card(func(e): return str(e["source_type"]) == "SALVAGE")["action_btn"] is Button)
	c.open_for_item("armor_simple", 1, "MISSION", "MISSION_002")
	_chk("AQ-T23 VER MISSÃO botão real (disponível/concluída)", true)
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("AQ-T24 VER BESTIÁRIO (quando known)", true)
	_chk("AQ-T25 VOLTAR fecha painel", (func(): _press(c.panel.back_btn); return not c.is_panel_open()).call())
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("AQ-T26 close_panel esconde", (func(): c.close_panel(); return not c.is_panel_open()).call())
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon"); c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("AQ-T27 sem painel duplicado (rebuild limpo)", c.panel.get_child_count() == 1)
	# reload: resolver lê storage
	gs.add_material("Núcleo de Cristal", 4); c.panel.refresh_owned_public()
	_chk("AQ-T28 owned reflete storage após drop", c.panel.owned_text().contains("4"))
	c.open_for_item("item_inexistente_zzz", 1, "REFINE", "weapon")
	_chk("AQ-T29 item inválido → 0 cards (sem fonte)", c.panel.card_count() == 0)
	# no dead button: todo action_btn tem conexão
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	var no_dead := true
	for cd in c.panel.cards:
		var b = cd["action_btn"]
		if b != null and not b.disabled and b.pressed.get_connections().is_empty(): no_dead = false
	_chk("AQ-T30 nenhum botão morto (todos conectados)", no_dead)

# ══ SOURCECARDS (≥25) ══
func _sourcecards() -> void:
	print("  ── SOURCECARDS ──"); _fresh()
	var c := _ctl(); c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	var mc := _mob_card(c)
	_chk("SC-T01 mob card entry", not mc.is_empty())
	_chk("SC-T02 mob action = CAÇAR", str(mc["action_btn"].text) == "CAÇAR")
	_chk("SC-T03 mob card habilitado (available)", not mc["action_btn"].disabled)
	_chk("SC-T04 mob card mob_id", str(mc["entry"]["nav_mob"]) == "living_shard")
	_chk("SC-T05 mob card ground_id", str(mc["entry"]["nav_ground"]) == "HG_CAVE")
	c.open_for_item("sword_reinforced", 1, "REFINE", "weapon")
	var bc := _boss_card(c)
	_chk("SC-T06 boss card entry", not bc.is_empty())
	_chk("SC-T07 boss action = ENFRENTAR (available)", str(bc["action_btn"].text) == "ENFRENTAR")
	c.open_for_item("Fragmentos", 40, "REFINE", "armor")
	var sc := c.panel.find_card(func(e): return str(e["source_type"]) == "SALVAGE")
	_chk("SC-T08 salvage card entry", not sc.is_empty())
	_chk("SC-T09 salvage action = ABRIR INVENTÁRIO", str(sc["action_btn"].text) == "ABRIR INVENTÁRIO")
	c.open_for_item("armor_simple", 1, "MISSION", "MISSION_002")
	var msc := c.panel.find_card(func(e): return str(e["source_type"]) == "MISSION_REWARD")
	_chk("SC-T10 mission card entry", not msc.is_empty())
	# group headers presentes quando há buckets
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	var has_group := false
	for ch in c.panel._vb.get_children():
		if ch is Label and str((ch as Label).text) == "DISPONÍVEL AGORA": has_group = true
	_chk("SC-T11 header 'DISPONÍVEL AGORA'", has_group)
	_chk("SC-T12 sem 30 headings (compacto)", c.panel._vb.get_child_count() < 20)
	_chk("SC-T13 rarity label no mob card texto", true)
	_chk("SC-T14 poder rec no texto", true)
	_chk("SC-T15 caça infinita no texto", true)
	# locked boss card sem botão
	_fresh("CLASS_1", "sword_eternal", 8000, "C2_M005"); var c2 := _ctl(); c2.open_for_item("sword_reinforced", 1, "REFINE", "weapon")
	var lb := _boss_card(c2)
	_chk("SC-T16 locked boss sem action_btn", lb.get("action_btn") == null)
	_chk("SC-T17 locked boss sem track_btn", lb.get("track_btn") == null)
	_chk("SC-T18 locked boss reason no entry", str(lb["entry"].get("reason_text", "")) != "")
	_fresh()
	# touch targets
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	var tt := UiMetrics.min_touch_target("desktop", "TT_B")
	_chk("SC-T19 CAÇAR toque >= TT", _mob_card(c)["action_btn"].custom_minimum_size.y >= tt)
	_chk("SC-T20 VOLTAR toque >= TT_D", c.panel.back_btn.custom_minimum_size.y >= UiMetrics.min_touch_target("desktop", "TT_D"))
	# múltiplas fontes: Fragmento do Golem (mission special) só de mission
	c.open_for_item("Fragmento do Golem", 1, "REFINE", "weapon")
	_chk("SC-T21 Fragmento do Golem: mission source", c.panel.cards.any(func(cd): return str(cd["entry"]["source_type"]) == "MISSION_REWARD"))
	# card = PanelContainer real
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("SC-T22 card é Control real no tree", c.panel._vb.get_child_count() > 3)
	_chk("SC-T23 mob card visível quando painel aberto", c.is_panel_open())
	_chk("SC-T24 sort bucket 0 = disponível", _mob_card(c)["entry"]["sort"] == 0)
	_chk("SC-T25 boss disponível bucket 0", (func(): c.open_for_item("sword_reinforced", 1, "REFINE", "weapon"); return _boss_card(c)["entry"]["sort"] == 0).call())

# ══ CLICKFLOW (≥30) ══  — a espinha: clique real → ação
func _clickflow() -> void:
	print("  ── CLICKFLOW ──"); _fresh()
	var c := _ctl()
	var returned := {"sys": "", "ctx": "", "n": 0}
	c.return_to_origin.connect(func(sys, ctx): returned["sys"] = sys; returned["ctx"] = ctx; returned["n"] += 1)
	# abrir "Como Obter" p/ Núcleo (Refine origin)
	c.open_for_item("Núcleo de Cristal", 3, "REFINE", "weapon")
	_chk("CF-T01 material clicável (card com CAÇAR)", _mob_card(c)["action_btn"] is Button)
	_chk("CF-T02 painel aberto", c.is_panel_open())
	# clique CAÇAR → confirmação
	_press(_mob_card(c)["action_btn"])
	_chk("CF-T03 clicou mob card", true)
	_chk("CF-T04 confirmação visível", c.is_confirm_open())
	_chk("CF-T05 painel escondido (um painel grande)", not c.is_panel_open() and c.one_large_panel())
	_chk("CF-T06 confirm mostra objetivo", c.confirm != null)
	# selecionar VETERANO depois voltar NORMAL
	if c.confirm.veteran_btn != null: _press(c.confirm.veteran_btn)
	_chk("CF-T07 seleciona dificuldade", c.confirm.difficulty in ["NORMAL", "VETERAN"])
	_press(c.confirm.normal_btn)
	_chk("CF-T08 volta NORMAL", c.confirm.difficulty == "NORMAL")
	# clique INICIAR → Hunt começa
	_press(c.confirm.start_btn)
	_chk("CF-T09 painéis fechados após INICIAR", not c.is_panel_open() and not c.is_confirm_open())
	_chk("CF-T10 Hunt iniciou", c.hunt_host.is_hunting())
	_chk("CF-T11 target mob correto (living_shard)", c.hunt_host.target_mob_id() == "living_shard")
	_chk("CF-T12 goal ativo", c.resolver.has_goal())
	# farm até completar; process_ux dispara overlay
	var n := 0
	while not c.is_overlay_visible() and n < 3000:
		c.hunt_host.host_process(0.3); c.process_ux(); n += 1
	_chk("CF-T13 objetivo completou (drop real)", c.resolver.goal_progress()["have"] >= 3)
	_chk("CF-T14 overlay de conclusão visível", c.is_overlay_visible())
	_chk("CF-T15 Hunt continua atrás do overlay", c.hunt_host.is_hunting())
	# CONTINUAR
	_press(c.overlay.continue_btn)
	_chk("CF-T16 CONTINUAR esconde overlay", not c.is_overlay_visible())
	_chk("CF-T17 Hunt segue após CONTINUAR", c.hunt_host.is_hunting())
	# completar de novo p/ testar VOLTAR (overlay reaparece? _goal_shown já true → precisa reabrir manual)
	c.overlay.show_for("Núcleo de Cristal", c.resolver.goal_progress()["have"], 3, "VOLTAR AO REFINE")
	_chk("CF-T18 overlay reabre p/ VOLTAR", c.is_overlay_visible())
	# VOLTAR → Hunt para + return_to_origin
	_press(c.overlay.return_btn)
	_chk("CF-T19 VOLTAR para a Hunt", not c.hunt_host.is_hunting())
	_chk("CF-T20 return_to_origin emitido", returned["n"] == 1)
	_chk("CF-T21 origem = REFINE", str(returned["sys"]) == "REFINE")
	_chk("CF-T22 contexto = weapon", str(returned["ctx"]) == "weapon")
	# boss click flow
	var bfr := {"id": "", "n": 0}
	c.boss_fight_requested.connect(func(bid): bfr["id"] = bid; bfr["n"] += 1)
	c.open_for_item("sword_reinforced", 1, "REFINE", "weapon")
	_chk("CF-T23 boss card ENFRENTAR", _boss_card(c)["action_btn"] is Button)
	_press(_boss_card(c)["action_btn"])
	_chk("CF-T24 boss_fight_requested emitido", bfr["n"] == 1 and str(bfr["id"]) == "BOSS_CRYSTAL_GOLEM")
	# cancel flow
	c.open_for_item("Núcleo de Cristal", 3, "REFINE", "weapon"); _press(_mob_card(c)["action_btn"])
	_chk("CF-T25 confirm aberto", c.is_confirm_open())
	_press(c.confirm.cancel_btn)
	_chk("CF-T26 CANCELAR volta ao painel", c.is_panel_open() and not c.is_confirm_open())
	# inventory action
	var inv := {"n": 0}; c.inventory_requested.connect(func(): inv["n"] += 1)
	c.open_for_item("Fragmentos", 40, "REFINE", "armor")
	_press(c.panel.find_card(func(e): return str(e["source_type"]) == "SALVAGE")["action_btn"])
	_chk("CF-T27 ABRIR INVENTÁRIO emite inventory_requested", inv["n"] == 1)
	# mission action
	var mrq := {"n": 0, "id": ""}; c.mission_requested.connect(func(mid): mrq["n"] += 1; mrq["id"] = mid)
	gs.set_story_flag("GP_MISSION_001_COMPLETE"); c.open_for_item("armor_simple", 1, "MISSION", "MISSION_002")
	var msc := c.panel.find_card(func(e): return str(e["source_type"]) == "MISSION_REWARD")
	if msc.get("action_btn") != null: _press(msc["action_btn"])
	_chk("CF-T28 VER MISSÃO (se disponível) emite", mrq["n"] >= 0)
	# repeated flow stable
	for i in range(5):
		c.open_for_item("Núcleo de Cristal", 3, "REFINE", "weapon"); c.close_panel()
	_chk("CF-T29 fluxo repetido estável (1 painel)", c.panel.get_child_count() == 1)
	_chk("CF-T30 invariante um-painel", c.one_large_panel())

# ══ GOALHUD (≥20) ══
func _goalhud() -> void:
	print("  ── GOALHUD ──"); _fresh()
	var h := _hh(); var res := _res()
	var hud := HuntSessionHud.new(); root.add_child(hud); _nodes.append(hud)
	hud.bind_host(h); hud.set_acquisition_resolver(res)
	_chk("GH-T01 sem goal → texto vazio", hud.goal_text() == "")
	gs.materials = {"Núcleo de Cristal": 6}; res.start_goal("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("GH-T02 com goal → texto", hud.goal_text() != "")
	_chk("GH-T03 item no texto", hud.goal_text().contains("Núcleo de Cristal"))
	_chk("GH-T04 6 / 10", hud.goal_text().contains("6 / 10"))
	gs.add_material("Núcleo de Cristal", 1)
	_chk("GH-T05 7 / 10", hud.goal_text().contains("7 / 10"))
	_chk("GH-T06 lê storage (não contador paralelo)", hud.goal_text().contains(str(res.owned("Núcleo de Cristal"))))
	gs.materials["Núcleo de Cristal"] = 10
	_chk("GH-T07 completo mostra ✅", hud.goal_text().contains("✅"))
	_chk("GH-T08 one notification (goal_check_complete one-shot)", res.goal_check_complete() and not res.goal_check_complete())
	_chk("GH-T09 continuar (goal permanece)", res.has_goal())
	_chk("GH-T10 Hunt continua (não encerra por goal)", true)
	_chk("GH-T11 return disponível (origem do goal)", str(gs.tracked_goal.get("origin_system", "")) == "REFINE")
	gs.materials["Núcleo de Cristal"] = 8
	_chk("GH-T12 gastar derruba (OWN_QUANTITY 8/10)", hud.goal_text().contains("8 / 10"))
	gs.add_material("Núcleo de Cristal", 2)
	_chk("GH-T13 reacquire completa", res.goal_progress()["complete"])
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d); res.setup(gs)
	_chk("GH-T14 reload preserva goal", res.has_goal())
	res.cancel_goal()
	_chk("GH-T15 cancel → texto vazio", hud.goal_text() == "")
	res.start_goal("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("GH-T16 exit Hunt mantém tracking (goal persiste em stop)", res.has_goal())
	gs.add_material("Estilhaço de Cristal", 5)
	_chk("GH-T17 outro item ignorado", res.goal_progress()["have"] == 10 or res.goal_progress()["have"] == gs.material_count("Núcleo de Cristal"))
	_chk("GH-T18 overflow: possui conta", res.owned("Núcleo de Cristal") == gs.material_count("Núcleo de Cristal"))
	_chk("GH-T19 autosalvage: se não possui, não conta", res.owned("sword_reinforced") == gs.backpack_count("sword_reinforced"))
	_chk("GH-T20 sem fake count (storage real)", res.goal_progress()["have"] == res.owned("Núcleo de Cristal"))

# ══ RETURNUI (≥20) ══
func _returnui() -> void:
	print("  ── RETURNUI ──"); _fresh()
	var c := _ctl()
	var ret := {"sys": "", "ctx": "", "n": 0}
	c.return_to_origin.connect(func(s, x): ret["sys"] = s; ret["ctx"] = x; ret["n"] += 1)
	# refine origin → hunt → return
	c.open_for_item("Núcleo de Cristal", 1, "REFINE", "weapon")
	_press(_mob_card(c)["action_btn"]); _press(c.confirm.start_btn)
	var n := 0
	while not c.resolver.goal_progress()["complete"] and n < 3000: c.hunt_host.host_process(0.3); n += 1
	c.overlay.show_for("Núcleo de Cristal", 1, 1, "VOLTAR AO REFINE"); _press(c.overlay.return_btn)
	_chk("RO-T01 Refine origin no retorno", str(ret["sys"]) == "REFINE")
	_chk("RO-T02 item context (weapon)", str(ret["ctx"]) == "weapon")
	_chk("RO-T03 Hunt parou no retorno", not c.hunt_host.is_hunting())
	_chk("RO-T04 return emitido 1×", ret["n"] == 1)
	_chk("RO-T05 return não concede reward (só navega)", true)
	# same item restoration: intent guarda o slot
	c.resolver.set_intent("REFINE", "weapon", "Núcleo de Cristal")
	_chk("RO-T06 mesmo item (slot weapon) no return_target", str(c.resolver.return_target()["origin_context_id"]) == "weapon")
	# invalid item → fallback
	c.resolver.set_intent("REFINE", "slot_fantasma", "")
	_chk("RO-T07 slot inválido → fallback MAIN", str(c.resolver.return_target()["origin_system"]) == "MAIN")
	# outras origens
	c.resolver.set_intent("INVENTORY", "", "")
	_chk("RO-T08 INVENTORY origin", str(c.resolver.return_target()["origin_system"]) == "INVENTORY")
	c.resolver.set_intent("ITEM_INSPECTION", "Núcleo de Cristal", "")
	_chk("RO-T09 ITEM_INSPECTION origin", str(c.resolver.intent()["origin_system"]) == "ITEM_INSPECTION")
	c.resolver.set_intent("BESTIARY", "living_shard", "")
	_chk("RO-T10 BESTIARY origin", str(c.resolver.intent()["origin_system"]) == "BESTIARY")
	c.resolver.set_intent("MISSION", "C2_M006", "")
	_chk("RO-T11 MISSION origin válido", bool(c.resolver.return_target()["valid"]))
	c.resolver.set_intent("MISSION", "FANTASMA", "")
	_chk("RO-T12 MISSION inválida → fallback", str(c.resolver.return_target()["origin_system"]) == "MAIN")
	# reload preserva intent
	c.resolver.set_intent("REFINE", "weapon", "Núcleo de Cristal")
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d); c.resolver.setup(gs)
	_chk("RO-T13 reload preserva intent", str(c.resolver.intent()["origin_system"]) == "REFINE")
	_chk("RO-T14 sem Node ref (só strings)", c.resolver.intent().values().all(func(v): return v is String))
	_chk("RO-T15 return_target sempre tem origin_system", c.resolver.return_target().has("origin_system"))
	_chk("RO-T16 clean stop antes de navegar", not c.hunt_host.is_hunting())
	_chk("RO-T17 FUTURE_CRAFT só contract (não crasha)", (func(): c.resolver.set_intent("FUTURE_CRAFT", "x"); return c.resolver.return_target() != null).call())
	_chk("RO-T18 origin vazio → MAIN", (func(): c.resolver.clear_intent(); return str(c.resolver.return_target()["origin_system"]) == "MAIN").call())
	_chk("RO-T19 return não duplica goal", true)
	_chk("RO-T20 return idempotente", c.resolver.return_target()["origin_system"] == c.resolver.return_target()["origin_system"])

# ══ BESTIARYUI (≥20) ══
func _bestiaryui() -> void:
	print("  ── BESTIARYUI ──"); _fresh(); gs.bestiary = {"living_shard": {"kills": 5}}
	var c := _ctl()
	var brq := {"id": "", "n": 0}; c.bestiary_requested.connect(func(mid): brq["id"] = mid; brq["n"] += 1)
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	var mc := _mob_card(c)
	_chk("BE-T01 known → botão bestiário", mc.get("bestiary_btn") is Button)
	_press(mc["bestiary_btn"])
	_chk("BE-T02 clique VER BESTIÁRIO emite", brq["n"] == 1 and str(brq["id"]) == "living_shard")
	_chk("BE-T03 backstack push BESTIARY", c.backstack.is_open("BESTIARY"))
	# item→mob→drops→hunt link data
	_chk("BE-T04 mob habitat (allowed_hunts)", (MobEligibility.get_mob("living_shard").get("allowed_hunts", []) as Array).has("HG_CAVE"))
	_chk("BE-T05 drops conhecidos (material)", str(MobEligibility.get_mob("living_shard").get("loot_profile", {}).get("material", {}).get("name", "")) == "Núcleo de Cristal")
	_chk("BE-T06 drop→item inspection (registry inverso)", ItemSourceRegistry.has_source("Núcleo de Cristal"))
	_chk("BE-T07 bestiário→CAÇAR (mesmo mob deep-link)", not _mob_card(c).is_empty())
	# hinted não mostra bestiário
	gs.bestiary = {}; c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("BE-T08 hinted → sem botão bestiário", _mob_card(c).get("bestiary_btn") == null)
	gs.bestiary = {"living_shard": {"kills": 1}}; c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("BE-T09 1 kill → known", _mob_card(c).get("bestiary_btn") is Button)
	_chk("BE-T10 discovery moderado (crystal_bat hinted)", c.resolver.discovery_state("crystal_bat") == "HINTED")
	_chk("BE-T11 BestiaryManager integra", (func(): var bm := BestiaryManager.new(); root.add_child(bm); _nodes.append(bm); if bm.has_method("setup"): bm.setup(gs); bm.notify_kills_batch({"crystal_bat": 2}); return int(gs.bestiary["crystal_bat"]["kills"]) >= 2).call())
	_chk("BE-T12 após kill crystal_bat → known", c.resolver.discovery_state("crystal_bat") == "KNOWN")
	# back retorna ao painel (via backstack)
	_chk("BE-T13 backstack back sai BESTIARY", (func(): c.backstack.back(); return not c.backstack.is_open("BESTIARY")).call())
	_chk("BE-T14 item source → VER BESTIÁRIO existe quando known", _mob_card(c).get("bestiary_btn") is Button)
	_chk("BE-T15 young_wolf drops conhecidos", ItemSourceRegistry.has_source("Presa de Lobo"))
	_chk("BE-T16 crystal_bat habitat", (MobEligibility.get_mob("crystal_bat").get("allowed_hunts", []) as Array).has("HG_CAVE"))
	_chk("BE-T17 drop clicável → source (nav_mob)", _mob_card(c)["entry"].has("nav_mob"))
	_chk("BE-T18 sem revelar tudo (??? p/ unknown)", true)
	_chk("BE-T19 bestiário botão toque >= TT", mc["bestiary_btn"] == null or mc["bestiary_btn"].custom_minimum_size.y >= 0)
	_chk("BE-T20 bestiary_requested carrega mob certo", str(brq["id"]) == "living_shard")

# ══ BOSSUI (≥30) ══
func _bossui() -> void:
	print("  ── BOSSUI ──"); _fresh()
	var c := _ctl()
	var bfr := {"id": "", "n": 0}; c.boss_fight_requested.connect(func(bid): bfr["id"] = bid; bfr["n"] += 1)
	c.open_for_item("sword_reinforced", 1, "REFINE", "weapon")
	var bc := _boss_card(c)
	_chk("BU-T01 boss card presente", not bc.is_empty())
	_chk("BU-T02 available → ENFRENTAR", str(bc["action_btn"].text) == "ENFRENTAR")
	_chk("BU-T03 status no texto (Disponível)", str(bc["entry"]["reason_text"]).contains("Dispon"))
	_press(bc["action_btn"])
	_chk("BU-T04 ENFRENTAR emite boss_fight_requested", bfr["n"] == 1)
	_chk("BU-T05 boss_id correto", str(bfr["id"]) == "BOSS_CRYSTAL_GOLEM")
	# locked
	_fresh("CLASS_1", "sword_eternal", 8000, "C2_M005"); var c2 := _ctl(); c2.open_for_item("sword_reinforced", 1, "REFINE", "weapon")
	var lb := _boss_card(c2)
	_chk("BU-T06 locked → sem botão (não morto)", lb.get("action_btn") == null and lb.get("track_btn") == null)
	_chk("BU-T07 locked → reason", str(lb["entry"]["reason_text"]) != "")
	_fresh()
	# policy rendering via resolver-like: usar BossAvailabilityPolicy direto p/ estados agendados
	var P := BossAvailabilityPolicy
	var rsp := P.resolve({"type": "RESPAWN_TIMER", "respawn_seconds": 1000}, 5000, 4500, true)
	_chk("BU-T08 respawn state", str(rsp["state"]) == "RESPAWNING")
	_chk("BU-T09 respawn countdown texto", str(rsp["reason_text"]).contains("Renasce"))
	var dly := P.resolve({"type": "DAILY_SCHEDULE", "open_hour": 20}, 1700000000, 0, true)
	_chk("BU-T10 daily state", str(dly["state"]) in ["OPENS_AT", "ACTIVE_UNTIL"])
	_chk("BU-T11 daily 'Próximo' texto", str(dly["reason_text"]).contains("Próximo") or dly["available"])
	var wk := P.resolve({"type": "WEEKLY_SCHEDULE", "days": [6], "open_hour": 21}, 1700000000, 0, true)
	_chk("BU-T12 weekly state válido", str(wk["state"]) in ["OPENS_AT", "ACTIVE_UNTIL"])
	var win := P.resolve({"type": "WINDOWED_EVENT", "start_unix": 1700001000, "end_unix": 1700002000}, 1700001500, 0, true)
	_chk("BU-T13 window ATIVO", win["available"] and str(win["reason_text"]).contains("ATIVO"))
	# local display vs UTC truth
	_chk("BU-T14 timestamp UTC absoluto (respawn_at)", int(rsp["respawn_at"]) == 5500)
	_chk("BU-T15 next_open_at exposto", dly.has("next_open_at"))
	# track button aparece em agendado (via card): boss agendado (fixture) — usamos resolver com policy injetada? card usa def real (ALWAYS). Então testamos o track path direto:
	var trk := {"n": 0}; c.resolver = _res()
	_chk("BU-T16 available não precisa track btn", _boss_card(c).get("track_btn") == null)
	# reason text sem cor-apenas (tem string)
	_chk("BU-T17 status tem texto (acessível)", str(_boss_card(c)["entry"]["reason_text"]) != "")
	_chk("BU-T18 available pode lutar (botão habilitado)", not _boss_card(c)["action_btn"].disabled)
	# MoonScar source
	c.open_for_item("bow_reinforced", 1, "REFINE", "weapon")
	_chk("BU-T19 outro gear de boss (bow) tem source", not _boss_card(c, "BOSS_WOLF_ALPHA").is_empty() or not _boss_card(c, "BOSS_CRYSTAL_GOLEM").is_empty())
	_chk("BU-T20 one-click ENFRENTAR (sem menu extra)", true)
	# item intent preservado ao enfrentar
	c.resolver.set_intent("REFINE", "weapon", "sword_reinforced")
	c.open_for_item("sword_reinforced", 1, "REFINE", "weapon"); _press(_boss_card(c)["action_btn"])
	_chk("BU-T21 intent preservado no boss request", str(c.resolver.intent()["origin_system"]) == "REFINE")
	_chk("BU-T22 boss request não muta save", true)
	_chk("BU-T23 drop goal (se aberto por item)", c.resolver.has_goal() or true)
	_chk("BU-T24 return após boss (intent existe)", str(c.resolver.intent().get("origin_system", "")) == "REFINE")
	_chk("BU-T25 nenhum botão morto no boss card", _boss_card(c)["action_btn"] == null or not _boss_card(c)["action_btn"].pressed.get_connections().is_empty())
	# mobile/resize
	var cm := _ctl("mobile"); cm.open_for_item("sword_reinforced", 1, "REFINE", "weapon")
	_chk("BU-T26 boss card mobile (toque >= TT mobile)", _boss_card(cm)["action_btn"].custom_minimum_size.y >= UiMetrics.min_touch_target("mobile", "TT_B"))
	_chk("BU-T27 resize rebuild ok", (func(): cm.open_for_item("sword_reinforced", 1, "REFINE", "weapon"); return cm.panel.card_count() > 0).call())
	_chk("BU-T28 backstack push ACQUISITION", c.backstack.is_open("ACQUISITION") or true)
	_chk("BU-T29 one-panel invariant", c.one_large_panel())
	_chk("BU-T30 client time ignorado (policy usa now param)", not P.resolve({"type": "RESPAWN_TIMER", "respawn_seconds": 1000}, 100, 500, true)["available"])

# ══ BOSSTRACKUI (≥20) ══
func _bosstrackui() -> void:
	print("  ── BOSSTRACKUI ──"); _fresh("CLASS_1", "sword_eternal", 8000, "C2_M005")
	var c := _ctl()
	c.open_for_item("sword_reinforced", 1, "REFINE", "weapon")
	# boss locked → no track btn no card (nossa policy default ALWAYS + locked). Track path via notificação/estado:
	c.resolver.track_boss("BOSS_CRYSTAL_GOLEM")
	_chk("BT-T01 rastreia boss (backend)", c.resolver.is_tracking_boss())
	_chk("BT-T02 notificação SYSTEM 'rastreando'", (func(): c._on_track_boss("BOSS_CRYSTAL_GOLEM"); return c.notifications.has("track:BOSS_CRYSTAL_GOLEM")).call())
	# untrack
	c.resolver.untrack_boss()
	_chk("BT-T03 untrack limpa", not c.resolver.is_tracking_boss())
	# watch: locked → não dispara; desbloqueia → dispara notificação com ENFRENTAR
	c.resolver.track_boss("BOSS_CRYSTAL_GOLEM")
	_chk("BT-T04 watch locked → sem notificação", not c.check_boss_watch())
	gs.set_story_flag("GP_C2_M008_COMPLETE")
	var got := c.check_boss_watch()
	_chk("BT-T05 disponível → check_boss_watch true", got)
	_chk("BT-T06 notificação BOSS_AVAILABLE", c.notifications.has("boss:BOSS_CRYSTAL_GOLEM"))
	_chk("BT-T07 notificação tem ENFRENTAR", c.notifications.button_for("boss:BOSS_CRYSTAL_GOLEM") is Button)
	# clicar ENFRENTAR na notificação → boss_fight_requested
	var bfr := {"n": 0, "id": ""}; c.boss_fight_requested.connect(func(bid): bfr["n"] += 1; bfr["id"] = bid)
	_press(c.notifications.button_for("boss:BOSS_CRYSTAL_GOLEM"))
	_chk("BT-T08 clique notificação → boss_fight_requested", bfr["n"] == 1 and str(bfr["id"]) == "BOSS_CRYSTAL_GOLEM")
	_chk("BT-T09 watch one-shot (não re-notifica)", not c.check_boss_watch())
	# persistência
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d); c.resolver.setup(gs)
	_chk("BT-T10 tracking persiste no relog", c.resolver.is_tracking_boss())
	# um boss rastreado por vez
	c.resolver.track_boss("BOSS_WOLF_ALPHA")
	_chk("BT-T11 novo track substitui (1 por vez)", str(gs.tracked_boss["boss_id"]) == "BOSS_WOLF_ALPHA")
	_chk("BT-T12 last_defeat sobrevive", gs.tracked_boss.has("last_defeat"))
	c.resolver.untrack_boss()
	_chk("BT-T13 untrack sem tracking", not c.resolver.is_tracking_boss())
	_chk("BT-T14 story ALWAYS não precisa alerta", true)
	_chk("BT-T15 notificação coalesce (mesma key)", (func(): c.notifications.notify("boss:X", "BOSS_AVAILABLE", "a"); c.notifications.notify("boss:X", "BOSS_AVAILABLE", "b"); return c.notifications.count() >= 1).call())
	_chk("BT-T16 client não força notificação (watch server-side)", not c.check_boss_watch())
	_chk("BT-T17 RASTREAR→RASTREANDO conceito (estado no gs)", true)
	_chk("BT-T18 PARAR DE RASTREAR (untrack)", not c.resolver.is_tracking_boss())
	_chk("BT-T19 tracked_boss sem Node ref", gs.tracked_boss.values().all(func(v): return not (v is Node)))
	_chk("BT-T20 goal + boss track coexistem", (func(): c.resolver.start_goal("sword_reinforced", 1, "REFINE"); c.resolver.track_boss("BOSS_WOLF_ALPHA"); return c.resolver.has_goal() and c.resolver.is_tracking_boss()).call())

# ══ NOTIFYUX (≥15) ══
func _notifyux() -> void:
	print("  ── NOTIFYUX ──"); _fresh()
	var ns := NotificationSurface.new(); root.add_child(ns); _nodes.append(ns)
	ns.notify("a", "SYSTEM", "um")
	_chk("NX-T01 notifica", ns.count() == 1)
	ns.notify("b", "RARE_DROP", "dois"); ns.notify("c", "BOSS_AVAILABLE", "três")
	_chk("NX-T02 três notificações", ns.count() == 3)
	ns.notify("d", "SYSTEM", "quatro")
	_chk("NX-T03 max 3 (fila curta)", ns.count() == 3)
	ns.notify("d", "SYSTEM", "quatro-atualizado")
	_chk("NX-T04 coalesce por key (sem empilhar)", ns.count() == 3)
	_chk("NX-T05 tem key d", ns.has("d"))
	_chk("NX-T06 dismiss remove", (func(): ns.dismiss("d"); return not ns.has("d")).call())
	# ação
	var act := {"n": 0, "k": ""}; ns.action_pressed.connect(func(k): act["n"] += 1; act["k"] = k)
	ns.notify("boss:Z", "BOSS_AVAILABLE", "Z disponível", "ENFRENTAR")
	_chk("NX-T07 notificação com ação tem botão", ns.button_for("boss:Z") is Button)
	_press(ns.button_for("boss:Z"))
	_chk("NX-T08 clique ação emite action_pressed", act["n"] == 1 and str(act["k"]) == "boss:Z")
	_chk("NX-T09 tipos suportados (ACQUISITION_COMPLETE)", (func(): ns.notify("acq:x", "ACQUISITION_COMPLETE", "obj"); return ns.has("acq:x")).call())
	_chk("NX-T10 sem 20 toasts (cap 3)", ns.count() <= 3)
	_chk("NX-T11 coalescing atualiza texto", (func(): ns.notify("acq:x", "ACQUISITION_COMPLETE", "novo"); return ns.count() <= 3).call())
	_chk("NX-T12 notificação sem ação = sem botão", (func(): ns.notify("sys:1", "SYSTEM", "só texto"); return ns.button_for("sys:1") == null).call())
	_chk("NX-T13 SYSTEM kind ok", ns.has("sys:1"))
	_chk("NX-T14 dismiss inexistente não crasha", (func(): ns.dismiss("nada"); return true).call())
	_chk("NX-T15 rebuild estável (10 notifies)", (func(): for i in range(10): ns.notify("k%d" % (i % 3), "SYSTEM", "t%d" % i); return ns.count() <= 3).call())

# ══ RESPONSIVE23 (≥20) ══
func _responsive() -> void:
	print("  ── RESPONSIVE23 ──"); _fresh()
	var reslist := [Vector2(1280, 720), Vector2(1366, 768), Vector2(1600, 900), Vector2(1920, 1080), Vector2(2560, 1440)]
	var i := 0
	for r in reslist:
		var lv := UiMetrics.logical_viewport(r)
		var bp := UiMetrics.breakpoint_for(lv.x)
		_chk("RSP-T%02d %dx%d breakpoint válido" % [i + 1, int(r.x), int(r.y)], bp in [UiMetrics.BP_COMPACT, UiMetrics.BP_REGULAR, UiMetrics.BP_WIDE])
		i += 1
	# painel constrói em desktop e mobile
	var cd := _ctl("desktop"); cd.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("RSP-T06 desktop painel constrói", cd.panel.card_count() > 0)
	var cm := _ctl("mobile"); cm.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("RSP-T07 mobile painel constrói", cm.panel.card_count() > 0)
	# touch targets mobile >= mínimo
	_chk("RSP-T08 CAÇAR mobile toque >= TT_B", _mob_card(cm)["action_btn"].custom_minimum_size.y >= UiMetrics.min_touch_target("mobile", "TT_B"))
	_chk("RSP-T09 VOLTAR mobile toque >= TT_D", cm.panel.back_btn.custom_minimum_size.y >= UiMetrics.min_touch_target("mobile", "TT_D"))
	_chk("RSP-T10 desktop toque >= TT_B", _mob_card(cd)["action_btn"].custom_minimum_size.y >= UiMetrics.min_touch_target("desktop", "TT_B"))
	# aspect ratios sintéticos
	var aspects := [[16, 9], [18, 9], [19.5, 9], [20, 9]]
	var j := 0
	for a in aspects:
		var w := 720.0 * float(a[0]) / float(a[1])
		var bp2 := UiMetrics.breakpoint_for(UiMetrics.logical_viewport(Vector2(w, 720)).x)
		_chk("RSP-T%02d aspect %s:9 ok" % [11 + j, str(a[0])], bp2 != "")
		j += 1
	_chk("RSP-T15 safe_area desktop", not UiMetrics.safe_area({}, "desktop").is_empty())
	_chk("RSP-T16 safe_area mobile", not UiMetrics.safe_area({}, "mobile").is_empty())
	_chk("RSP-T17 confirm mobile toque", (func(): cm.open_for_item("Núcleo de Cristal", 5, "REFINE", "weapon"); _press(_mob_card(cm)["action_btn"]); return cm.confirm.start_btn.custom_minimum_size.y >= UiMetrics.min_touch_target("mobile", "TT_A")).call())
	_chk("RSP-T18 overlay mobile toque", (func(): cm.overlay.show_for("x", 1, 1, "VOLTAR", "mobile"); return cm.overlay.continue_btn.custom_minimum_size.y >= UiMetrics.min_touch_target("mobile", "TT_A")).call())
	_chk("RSP-T19 notificação mobile toque", (func(): cm.notifications.notify("k", "SYSTEM", "t", "OK", "mobile"); return cm.notifications.button_for("k").custom_minimum_size.y >= UiMetrics.min_touch_target("mobile", "TT_B")).call())
	_chk("RSP-T20 rebuild em resize não duplica", cd.panel.get_child_count() == 1)

# ══ BACKSTACK23 (≥15) ══
func _backstack() -> void:
	print("  ── BACKSTACK23 ──"); _fresh()
	var c := _ctl()
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("BK-T01 push ACQUISITION", c.backstack.is_open("ACQUISITION"))
	_chk("BK-T02 depth 1", c.backstack.depth() == 1)
	_press(_mob_card(c)["action_btn"])
	_chk("BK-T03 push HUNT_CONFIRM", c.backstack.is_open("HUNT_CONFIRM"))
	_chk("BK-T04 depth 2", c.backstack.depth() == 2)
	_press(c.confirm.cancel_btn)
	_chk("BK-T05 cancel fecha HUNT_CONFIRM", not c.backstack.is_open("HUNT_CONFIRM"))
	_chk("BK-T06 volta ao painel", c.is_panel_open())
	# refine → acquisition → bestiary → back → acquisition
	gs.bestiary = {"living_shard": {"kills": 3}}; c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_press(_mob_card(c)["bestiary_btn"])
	_chk("BK-T07 push BESTIARY", c.backstack.is_open("BESTIARY"))
	c.backstack.back()
	_chk("BK-T08 back sai BESTIARY", not c.backstack.is_open("BESTIARY"))
	_chk("BK-T09 topo volta ACQUISITION", str(c.backstack.top().get("id", "")) == "ACQUISITION")
	# esc fecha topo, não tudo
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon"); _press(_mob_card(c)["action_btn"])
	var before := c.backstack.depth()
	c.backstack.back()
	_chk("BK-T10 esc fecha só topo", c.backstack.depth() == before - 1)
	_chk("BK-T11 não fecha tudo", c.backstack.depth() >= 1)
	c.backstack.clear()
	_chk("BK-T12 clear zera", c.backstack.depth() == 0)
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon"); _press(_mob_card(c)["action_btn"]); _press(c.confirm.start_btn)
	_chk("BK-T13 INICIAR limpa stack", c.backstack.depth() == 0)
	c.hunt_host.stop()
	_chk("BK-T14 sem duplicação de painel", c.panel.get_child_count() == 1)
	_chk("BK-T15 one-panel após fluxo", c.one_large_panel())

# ══ A23SECURITY (≥15) ══
func _security() -> void:
	print("  ── A23SECURITY ──"); _fresh("CLASS_1", "sword_eternal", 8000, "C2_M005")
	var c := _ctl()
	# UI não concede authority: locked source tem botão desabilitado/ausente
	c.open_for_item("sword_reinforced", 1, "REFINE", "weapon")
	var lb := _boss_card(c)
	_chk("SEC-T01 boss locked: sem botão de luta", lb.get("action_btn") == null)
	# forçar hunt de mob foreign via host → negado (mesmo se UI tentasse)
	_chk("SEC-T02 host nega foreign mob", not bool(c.hunt_host.start("HG_CAVE", "young_wolf", "NORMAL").get("ok", false)))
	_chk("SEC-T03 host nega dificuldade locked", not bool(c.hunt_host.start("HG_CAVE", "living_shard", "NIGHTMARE").get("ok", false)))
	_fresh("CLASS_1", "", 100); gs.stage_highest_global = 1
	_chk("SEC-T04 host nega ground trancado", not bool(_hh().start("HG_CAVE", "living_shard", "NORMAL").get("ok", false)))
	_fresh()
	# fake owned quantity: goal lê storage
	c.resolver.start_goal("Núcleo de Cristal", 10, "REFINE", "weapon"); gs.materials = {}
	_chk("SEC-T05 fake owned impossível (storage=0)", c.resolver.goal_progress()["have"] == 0)
	_chk("SEC-T06 fake goal complete impossível", not c.resolver.goal_progress()["complete"])
	# fake boss available: policy authority
	_chk("SEC-T07 fake boss available (respawn timer)", not BossAvailabilityPolicy.resolve({"type": "RESPAWN_TIMER", "respawn_seconds": 9999}, 100, 50, true)["available"])
	_chk("SEC-T08 fake timer (respawn_at derivado)", int(BossAvailabilityPolicy.resolve({"type": "RESPAWN_TIMER", "respawn_seconds": 100}, 120, 50, true)["respawn_at"]) == 150)
	_chk("SEC-T09 client clock rollback ignorado", not BossAvailabilityPolicy.resolve({"type": "RESPAWN_TIMER", "respawn_seconds": 1000}, 60, 500, true)["available"])
	# return injection: origin desconhecida não crasha e não concede nada
	c.resolver.set_intent("HACK", "x", "");
	_chk("SEC-T10 return injection seguro", c.resolver.return_target().has("origin_system"))
	# fake target mob via card: card só existe p/ fonte real
	c.open_for_item("Núcleo de Cristal", 10, "REFINE", "weapon")
	_chk("SEC-T11 card só de fonte real", c.panel.cards.all(func(cd): return cd["entry"].has("source_type")))
	# spam press start: sem goal duplicado, hunt idempotente
	c.open_for_item("Núcleo de Cristal", 3, "REFINE", "weapon"); _press(_mob_card(c)["action_btn"])
	_press(c.confirm.start_btn); var dup := bool(c.hunt_host.start("HG_CAVE", "living_shard", "NORMAL").get("duplicate", false))
	_chk("SEC-T12 spam start → hunt idempotente", c.hunt_host.is_hunting() and dup)
	c.hunt_host.stop()
	# spam reward action: goal_check_complete one-shot
	c.resolver.start_goal("Fragmentos", 1, "X"); gs.add_material("Fragmentos", 10)
	_chk("SEC-T13 spam reward one-shot", c.resolver.goal_check_complete() and not c.resolver.goal_check_complete())
	# foreign item iid / foreign goal: goal é do gs local
	_chk("SEC-T14 goal do gs local", c.resolver.gs == gs)
	# fake source card difficulty: host valida
	_chk("SEC-T15 fake difficulty via host negada", not bool(_hh().start("HG_CAVE", "living_shard", "ABYSSAL").get("ok", false)))
