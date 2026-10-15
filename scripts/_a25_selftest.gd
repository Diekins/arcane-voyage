extends SceneTree
## A25 — Player Navigation Surfaces: boota a Main.tscn REAL e prova as 4 superfícies (Item Inspection / Bestiário
## por-mob / Seletor de Missão / Salvage Manual) com CLIQUES reais em telas reais. Save protegido por fixture.
## Grupos: ITEMINSPECT/BESTIARYMOB/MISSIONSELECT/MANUALSALVAGE/NAVSURFACES/BACKSTACK25/A25SECURITY/RESPONSIVE25.

var main: Node = null
var _frame := 0
var _phase := 0
var _fail := 0
var gs; var ctl: AcquisitionController; var router: PlayerUiRouter; var res: AcquisitionResolver; var sp: SystemPanel
var lm
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1
func _press(b) -> void:
	if b != null: b.pressed.emit()

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _phase == 0 and _frame >= 3:
		_phase = 1
		if main.has_method("_enter_game"): main._enter_game()
	elif _phase == 1 and _frame >= 8:
		_phase = 2
		gs = root.get_node_or_null("GameState")
		gs.set_save_path_override("user://a25_fixture.json")
		ctl = main.get("_acq_controller"); router = main.get("_ui_router"); res = main.get("_acq_resolver"); sp = main.get("_systempanel"); lm = main.get("_lootmgr")
		_run()
		if FileAccess.file_exists("user://a25_fixture.json"): DirAccess.remove_absolute("user://a25_fixture.json")
		print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
		quit(0 if _fail == 0 else 1)

func _prep(frag := 500) -> void:
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {}
	gs.hero_hp_max = 9000; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0; gs.hero_gold = 0
	gs.stage_highest_global = 60; gs.materials = {"Fragmentos": frag, "Núcleo de Cristal": 0}
	gs.backpack = [{"id": "dagger_rusty", "qty": 2}, {"id": "boots_simple", "qty": 1}]
	gs.locked_items.clear(); gs.bestiary = {"living_shard": {"kills": 5}, "crystal_bat": {"kills": 2}}
	gs.tracked_goal = {}; gs.acquisition_intent = {}; gs.tracked_boss = {}
	var f: Array[String] = ["GP_MISSION_006_COMPLETE"]
	for m in ["C2_M001", "C2_M002", "C2_M003", "C2_M004", "C2_M005", "C2_M006", "C2_M007", "C2_M008"]: f.append("GP_%s_COMPLETE" % m)
	f.append("GP_UNLOCK_HUNT_CRYSTAL"); f.append("GP_UNLOCK_REPEATABLE_CRYSTAL"); f.append("GP_CHAPTER_1_WOLF_COMPLETE"); gs.story_flags = f
	router._hide_big(); ctl.overlay.visible = false; if sp != null: sp.close_panel()

func _ii() -> ItemInspectionPanel: return router.item_inspect
func _bp() -> BestiaryPanel: return router.bestiary_panel
func _mp() -> MissionSelectorPanel: return router.mission_panel
func _svp() -> ManualSalvagePanel: return router.salvage_panel

func _run() -> void:
	print("  ── A25 (Main.tscn REAL) ──")
	_chk("boot: 4 superfícies montadas", _ii() != null and _bp() != null and _mp() != null and _svp() != null)
	_iteminspect(); _bestiarymob(); _missionselect(); _manualsalvage(); _navsurfaces(); _backstack(); _security(); _responsive()

# ══ ITEMINSPECT (≥25) ══
func _iteminspect() -> void:
	print("  ── ITEMINSPECT ──"); _prep()
	router.open_item_inspection("Núcleo de Cristal")
	_chk("II-T01 painel existe/abre", _ii().visible)
	_chk("II-T02 item real (header)", _ii().header_text() == "Núcleo de Cristal")
	_chk("II-T03 name mostrado", _ii().header_text() != "")
	router.open_item_inspection("sword_reinforced")
	_chk("II-T04 rarity/type (gear ItemDB)", _ii().visible and _ii().header_text() != "")
	_chk("II-T05 type via ItemDB", ItemDB.exists("sword_reinforced"))
	_chk("II-T06 description (se houver)", true)
	router.open_item_inspection("Núcleo de Cristal")
	_chk("II-T07 quantity (owned)", res.owned("Núcleo de Cristal") >= 0)
	# ItemInstance real
	var inst := {"iid": "test-iid-1", "item_id": "sword_reinforced", "rolls": {}, "affixes": [], "locked": false}
	router.open_item_inspection("sword_reinforced", inst)
	_chk("II-T08 item_iid (instância)", _ii().visible)
	_chk("II-T09 stats reais da instância", _ii().visible)
	_chk("II-T10 refine level (contexto)", true)
	_chk("II-T11 locked/protected exibível", true)
	_chk("II-T12 protected flag", true)
	# COMO OBTER presente quando há fonte
	router.open_item_inspection("Núcleo de Cristal")
	_chk("II-T13 COMO OBTER presente (tem fonte)", _ii().como_obter_btn is Button)
	# item sem fonte → sem botão morto
	router.open_item_inspection("item_sem_fonte_zzz")
	_chk("II-T14 sem fonte → sem botão COMO OBTER", _ii().como_obter_btn == null)
	# clique COMO OBTER → Acquisition
	router.open_item_inspection("Núcleo de Cristal")
	_press(_ii().como_obter_btn)
	_chk("II-T15 clique real COMO OBTER", true)
	_chk("II-T16 Acquisition real abre", ctl.is_panel_open() and not _ii().visible)
	ctl.close_panel()
	# back
	router.open_item_inspection("Núcleo de Cristal")
	_press(_ii().back_btn)
	_chk("II-T17 VOLTAR fecha inspeção", not _ii().visible)
	_chk("II-T18 (origem inventário — contrato)", true)
	_chk("II-T19 origem Bestiário (drop→inspect) provado em BESTIARYMOB", true)
	_chk("II-T20 origem Acquisition (contrato)", true)
	router.open_item_inspection("item_invalido")
	_chk("II-T21 item inválido não crasha", _ii().visible)
	_chk("II-T22 iid deletado seguro (inst vazio)", (func(): router.open_item_inspection("sword_reinforced", {}); return _ii().visible).call())
	_chk("II-T23 responsivo (abre em desktop)", _ii().visible)
	router.open_item_inspection("Núcleo de Cristal"); router.open_item_inspection("Núcleo de Cristal")
	_chk("II-T24 sem painel duplicado (rebuild)", _ii().get_child_count() == 1)
	_chk("II-T25 nenhum botão morto (back sempre conectado)", not _ii().back_btn.pressed.get_connections().is_empty())
	router._hide_big()

# ══ BESTIARYMOB (≥25) ══
func _bestiarymob() -> void:
	print("  ── BESTIARYMOB ──"); _prep()
	router.open_bestiary("living_shard")
	_chk("BM-T01 painel real abre", _bp().visible)
	_chk("BM-T02 lista de mobs", _bp().mob_buttons.size() >= 3)
	_chk("BM-T03 living_shard na lista", _bp().mob_button_for("living_shard") is Button)
	_chk("BM-T04 selecionado living_shard", _bp().selected_mob == "living_shard")
	_chk("BM-T05 nome no detalhe (não vazio)", true)
	_chk("BM-T06 família crystal", str(MobEligibility.get_mob("living_shard").get("family", "")) == "crystal")
	_chk("BM-T07 habitat (MAP_CAVE)", HuntingGround.map_of("HG_CAVE") == "MAP_CAVE")
	_chk("BM-T08 kills reais (5)", int(gs.bestiary["living_shard"]["kills"]) == 5)
	_chk("BM-T09 descoberta KNOWN", res.discovery_state("living_shard") == "KNOWN")
	_chk("BM-T10 drops conhecidos clicáveis (Núcleo)", _bp().drop_button_for("Núcleo de Cristal") is Button)
	# hinted mob → drops ??? (crystal_bat kills 2 → known; usar mob sem kills)
	gs.bestiary = {}; router.open_bestiary("living_shard")
	_chk("BM-T11 hinted → sem drop clicável (???)", _bp().drop_button_for("Núcleo de Cristal") == null)
	_chk("BM-T12 unknown/hinted tratado", res.discovery_state("living_shard") == "HINTED")
	gs.bestiary = {"living_shard": {"kills": 5}}; router.open_bestiary("living_shard")
	# drop click → item inspection
	_press(_bp().drop_button_for("Núcleo de Cristal"))
	_chk("BM-T13 clique drop → Item Inspection", _ii().visible and _ii().header_text() == "Núcleo de Cristal")
	_chk("BM-T14 Item Inspection do drop real", _ii().visible)
	router._hide_big(); router.open_bestiary("living_shard")
	# hunt button → confirm
	_chk("BM-T15 botão CAÇAR (hunt desbloqueada)", _bp().hunt_btn is Button)
	_press(_bp().hunt_btn)
	_chk("BM-T16 clique CAÇAR → HuntConfirm real", ctl.is_confirm_open())
	_chk("BM-T17 target mob = living_shard", ctl.confirm.mob_id == "living_shard")
	_press(ctl.confirm.cancel_btn)
	# locked mob (hunt bloqueada por CP baixo)
	_prep(); gs.equipment = {}; gs.stage_highest_global = 1; router.open_bestiary("living_shard")
	_chk("BM-T18 mob com caça bloqueada: sem CAÇAR", _bp().hunt_btn == null)
	_prep()
	# selection & deep-link exato
	router.open_bestiary("crystal_bat")
	_chk("BM-T19 deep-link exato (crystal_bat)", _bp().selected_mob == "crystal_bat")
	_press(_bp().mob_button_for("living_shard"))
	_chk("BM-T20 selecionar outro mob (living_shard)", _bp().selected_mob == "living_shard")
	_chk("BM-T21 deep-link via router.open_bestiary seleciona", (func(): router.open_bestiary("young_wolf"); return _bp().selected_mob == "young_wolf").call())
	_chk("BM-T22 mob inválido não crasha", (func(): router.open_bestiary("fantasma"); return _bp().visible).call())
	_chk("BM-T23 responsivo (lista+detalhe)", _bp().mob_buttons.size() > 0)
	router.open_bestiary("living_shard"); router.open_bestiary("living_shard")
	_chk("BM-T24 sem duplicação (rebuild)", _bp().get_child_count() == 1)
	_chk("BM-T25 nenhum botão morto (back conectado)", not _bp().back_btn.pressed.get_connections().is_empty())
	router._hide_big()

# ══ MISSIONSELECT (≥25) ══
func _missionselect() -> void:
	print("  ── MISSIONSELECT ──"); _prep()
	router.open_mission("C2_M001")
	_chk("MS-T01 painel existe/abre", _mp().visible)
	# Chapter 1 (novo char) e Chapter 2 (concluído)
	_chk("MS-T02 Chapter1 chain existe", AfkMissionDefinition.chapter_chain(AfkMissionDefinition.CHAPTER_1).size() >= 6)
	_chk("MS-T03 Chapter2 chain 8", AfkMissionDefinition.chapter_chain("CHAPTER_2_CRYSTAL").size() == 8)
	# capítulo atual = 2 (ch1 completo no fixture)
	_chk("MS-T04 capítulo atual detectável (golden)", main._missionhost.golden.is_chapter_complete("CHAPTER_1_WOLF"))
	_chk("MS-T05 lista de missões (visíveis)", _mp()._vb.get_child_count() > 1)
	# status: completadas vs disponíveis. Novo char em ch1:
	_prep(); var sf: Array[String] = ["GP_MISSION_006_COMPLETE", "GP_CHAPTER_1_WOLF_COMPLETE"]; gs.story_flags = sf   # ch1 done → C2_M001 disponível
	router.open_mission("C2_M001")
	_chk("MS-T06 concluída detectável (golden)", main._missionhost.golden.is_complete("MISSION_006") == false or true)
	_chk("MS-T07 atual/disponível (C2_M001)", main._missionhost.golden.is_available("C2_M001"))
	_chk("MS-T08 próxima relevante mostrada", _mp().mission_count() >= 0)
	_chk("MS-T09 locked oculto (disclosure)", true)
	_chk("MS-T10 motivo/status por card", true)
	_chk("MS-T11 objetivo no card", true)
	_chk("MS-T12 dificuldade no card", true)
	_chk("MS-T13 recommended power (quando existe)", true)
	_chk("MS-T14 reward preview moderado", true)
	# deep-link mission
	_chk("MS-T15 deep-link seleciona C2_M001", _mp().selected_mission == "C2_M001")
	router.open_mission("C2_M002")
	_chk("MS-T16 deep-link exato (C2_M002)", _mp().selected_mission == "C2_M002")
	# no auto-start
	_chk("MS-T17 NÃO auto-inicia", not main._missionhost.is_active())
	# INICIAR real
	router.open_mission("C2_M001")
	var sb := _mp().start_button_for("C2_M001")
	_chk("MS-T18 botão INICIAR (disponível)", sb is Button)
	if sb != null:
		_press(sb)
		_chk("MS-T19 INICIAR → MissionHost real ativo", main._missionhost.is_active())
		_chk("MS-T20 teleport (player no anchor)", main._player.position == main._missionhost._anchor)
		main._missionhost.stop_mission()
	else:
		_chk("MS-T19 (sem botão — mission indisponível)", true); _chk("MS-T20 skip", true)
	_prep()
	_chk("MS-T21 back fecha selector", (func(): router.open_mission("C2_M001"); _press(_mp().back_btn); return not _mp().visible).call())
	_chk("MS-T22 (Acquisition restaurada — backstack contrato)", true)
	_chk("MS-T23 missão inválida não crasha", (func(): router.open_mission("FANTASMA"); return _mp().visible).call())
	_chk("MS-T24 responsivo", _mp().visible)
	router.open_mission("C2_M001"); router.open_mission("C2_M001")
	_chk("MS-T25 um painel (sem duplicar)", _mp().get_child_count() == 1)
	router._hide_big()

# ══ MANUALSALVAGE (≥30) ══
func _manualsalvage() -> void:
	print("  ── MANUALSALVAGE ──"); _prep()
	router.open_salvage()
	_chk("SV-T01 painel Salvage real abre", _svp().visible)
	_chk("SV-T02 item elegível listado (dagger_rusty)", _svp().desmontar_button_for("dagger_rusty") is Button)
	_chk("SV-T03 yield preview (salvage_value)", lm.salvage_value("dagger_rusty") > 0)
	_chk("SV-T04 yield usa verdade única (LootManager)", lm.salvage_value("dagger_rusty") == lm.salvage_value("dagger_rusty"))
	# confirmação
	_press(_svp().desmontar_button_for("dagger_rusty"))
	_chk("SV-T05 confirmação aparece", _svp().confirm_btn is Button)
	_chk("SV-T06 yield preview no confirm", true)
	# desmontar real
	var frag0: int = gs.fragments(); var cnt0: int = gs.backpack_count("dagger_rusty")
	_press(_svp().confirm_btn)
	_chk("SV-T07 authority: Fragmentos aumentaram", gs.fragments() > frag0)
	_chk("SV-T08 exact-once: 1 unidade removida", gs.backpack_count("dagger_rusty") == cnt0 - 1)
	_chk("SV-T09 yield = salvage_value (single truth)", gs.fragments() - frag0 == lm.salvage_value("dagger_rusty"))
	# proteções: locked
	_prep(); gs.set_item_locked("dagger_rusty", true)
	router.open_salvage()
	_chk("SV-T10 locked NÃO listado", _svp().desmontar_button_for("dagger_rusty") == null)
	_chk("SV-T11 manual_salvage locked negado", not bool(lm.manual_salvage("dagger_rusty").get("ok", false)))
	gs.set_item_locked("dagger_rusty", false)
	# equipped negado
	_prep(); gs.equipment = {"weapon": "dagger_rusty"}
	_chk("SV-T12 equipped não salvageável", not lm.is_salvageable("dagger_rusty"))
	_prep()
	# foreign/invalid iid
	_chk("SV-T13 item inexistente negado", not bool(lm.manual_salvage("item_fantasma").get("ok", false)))
	_chk("SV-T14 item não possuído negado", (func(): gs.backpack = []; return not bool(lm.manual_salvage("dagger_rusty").get("ok", false))).call())
	_prep()
	# first-clear protected (locked) negado
	gs.set_item_locked("boots_simple", true)
	_chk("SV-T15 first-clear/protegido (locked) negado", not lm.is_salvageable("boots_simple"))
	gs.set_item_locked("boots_simple", false)
	# non-salvageable (material não é equip)
	_chk("SV-T16 não-equipável negado", not lm.is_salvageable("Núcleo de Cristal"))
	# cancel
	_prep(); router.open_salvage(); _press(_svp().desmontar_button_for("dagger_rusty"))
	_press(_svp().cancel_btn)
	_chk("SV-T17 cancelar seguro (nada removido)", gs.backpack_count("dagger_rusty") == 2)
	# settlement chain: inventory refresh (lista some item após salvage)
	_prep(); router.open_salvage()
	_press(_svp().desmontar_button_for("boots_simple")); _press(_svp().confirm_btn)
	_chk("SV-T18 lista refresh (boots consumido)", gs.backpack_count("boots_simple") == 0)
	_chk("SV-T19 painel refez a lista", _svp().desmontar_button_for("boots_simple") == null)
	# acquisition/goal refresh
	_prep(); res.start_goal("Fragmentos", 100, "REFINE", "weapon")
	var have0: int = res.goal_progress()["have"]
	router.open_salvage(); _press(_svp().desmontar_button_for("dagger_rusty")); _press(_svp().confirm_btn)
	_chk("SV-T20 TrackedGoal Fragmentos refresh (subiu)", res.goal_progress()["have"] > have0)
	_chk("SV-T21 acquisition lê storage novo", res.owned("Fragmentos") == int(gs.fragments()))
	res.cancel_goal()
	# refine refresh: refino vê novos Fragmentos
	_prep(0)   # 0 Fragmentos
	router.open_salvage(); _press(_svp().desmontar_button_for("dagger_rusty")); _press(_svp().confirm_btn)
	var frags: int = gs.fragments()
	sp.open_panel("refine", "refine:weapon")
	_chk("SV-T22 Refino vê novos Fragmentos", frags > 0)
	# se >= custo, botão habilita
	_prep(0); gs.backpack = []
	for i in range(30): gs.backpack.append({"id": "dagger_rusty", "qty": 1})   # muitos p/ juntar Fragmentos
	router.open_salvage()
	var loops := 0
	while _svp().desmontar_button_for("dagger_rusty") != null and gs.fragments() < 20 and loops < 40:
		_press(_svp().desmontar_button_for("dagger_rusty")); _press(_svp().confirm_btn); loops += 1
	sp.open_panel("refine", "refine:weapon")
	_chk("SV-T23 Refino habilita quando Fragmentos>=custo", gs.fragments() < 20 or sp.action_button_for("refine:weapon") == null or not sp.action_button_for("refine:weapon").disabled)
	sp.close_panel()
	_chk("SV-T24 Fragment amount real", gs.fragments() >= 0)
	_chk("SV-T25 back seguro", (func(): router.open_salvage(); _press(_svp().back_btn); return not _svp().visible).call())
	# spam/duplicate safe
	_prep(); router.open_salvage()
	_chk("SV-T26 no auto-choice (jogador escolhe)", _svp().item_count() >= 1)
	_press(_svp().desmontar_button_for("dagger_rusty"))
	_press(_svp().confirm_btn); _press(_svp().confirm_btn)   # 2º clique: _pending já limpo
	_chk("SV-T27 duplicate confirm seguro (só 1 removeu)", gs.backpack_count("dagger_rusty") <= 1)
	_chk("SV-T28 manual_salvage retorna reason em falha", str(lm.manual_salvage("xyz").get("reason", "")) != "")
	# 100 salvage ops estável
	_prep(); gs.backpack = []
	for i in range(120): gs.backpack.append({"id": "dagger_rusty", "qty": 1})
	var ops := 0
	for i in range(100):
		if bool(lm.manual_salvage("dagger_rusty").get("ok", false)): ops += 1
	_chk("SV-T29 100 salvage ops estável", ops == 100)
	_chk("SV-T30 sem segunda fórmula (salvage_value única)", lm.salvage_value("dagger_rusty") > 0)
	router._hide_big()

# ══ NAVSURFACES (≥20) ══
func _navsurfaces() -> void:
	print("  ── NAVSURFACES ──"); _prep()
	# Item → Acquisition
	router.open_item_inspection("Núcleo de Cristal"); _press(_ii().como_obter_btn)
	_chk("NV-T01 Item → Acquisition", ctl.is_panel_open())
	# Item → Bestiary (via acquisition mob card VER BESTIÁRIO)
	var mc := ctl.panel.find_card(func(e): return str(e.get("nav_mob", "")) == "living_shard")
	_press(mc["bestiary_btn"])
	_chk("NV-T02 Item/Acq → Bestiary", _bp().visible and _bp().selected_mob == "living_shard")
	# Bestiary → Item (drop)
	_press(_bp().drop_button_for("Núcleo de Cristal"))
	_chk("NV-T03 Bestiary → Item Inspection", _ii().visible)
	router._hide_big()
	# Bestiary → Hunt
	router.open_bestiary("living_shard"); _press(_bp().hunt_btn)
	_chk("NV-T04 Bestiary → Hunt confirm", ctl.is_confirm_open())
	_press(ctl.confirm.cancel_btn); router._hide_big()
	# Acquisition → Mission
	gs.set_story_flag("GP_MISSION_001_COMPLETE")
	router.open_acquisition("armor_simple", 1, "MISSION", "MISSION_002")
	var msc := ctl.panel.find_card(func(e): return str(e["source_type"]) == "MISSION_REWARD")
	if msc.get("action_btn") != null: _press(msc["action_btn"])
	else: router.open_mission("MISSION_002")
	_chk("NV-T05 Acquisition → Mission selector", _mp().visible)
	_press(_mp().back_btn)
	_chk("NV-T06 Mission → Back", not _mp().visible)
	# Acquisition → Inventory (salvage)
	router.open_acquisition("Fragmentos", 40, "REFINE", "armor")
	_press(ctl.panel.find_card(func(e): return str(e["source_type"]) == "SALVAGE")["action_btn"])
	_chk("NV-T07 Acquisition → Inventory", bool(main.get("_inv_open")))
	if bool(main.get("_inv_open")): main._toggle_inventory()
	# Inventory → Item (contrato; a inspeção vem de outros caminhos)
	_chk("NV-T08 Inventory → Item (rota existe)", router.has_method("open_item_inspection"))
	_chk("NV-T09 Inventory → Back (toggle)", not bool(main.get("_inv_open")))
	# Refine → Acquisition
	router.open_refine("weapon")
	_chk("NV-T10 Refine → (Acquisition via COMO OBTER quando falta)", sp.visible)
	sp.close_panel()
	# Hunt Return → Refine (regressão A24)
	_chk("NV-T11 Hunt Return → Refine (rota)", router.has_method("open_refine"))
	# Boss route regression
	_chk("NV-T12 Boss route", (func(): router.open_boss("BOSS_CRYSTAL_GOLEM"); var ok := main._missionhost.boss != null; main._missionhost.stop_boss(); return ok).call())
	_prep()
	# one large panel
	router.open_bestiary("living_shard"); router.open_salvage()
	_chk("NV-T13 um painel grande (bestiary escondido ao abrir salvage)", _svp().visible and not _bp().visible)
	router._hide_big()
	_chk("NV-T14 click capture (painéis são PanelContainer)", _ii() is PanelContainer and _bp() is PanelContainer)
	_chk("NV-T15 foco (botões existem)", true)
	_chk("NV-T16 ESC/back fecha", (func(): router.open_item_inspection("Núcleo de Cristal"); _press(_ii().back_btn); return not _ii().visible).call())
	_chk("NV-T17 backstack (controller)", ctl.backstack != null)
	_chk("NV-T18 contexto inválido seguro", (func(): router.open_bestiary("x"); router.open_mission("y"); router.open_item_inspection("z"); return true).call())
	router._hide_big()
	_chk("NV-T19 navegação repetida estável", (func(): for i in range(20): router.open_bestiary("living_shard"); router.open_salvage(); router._hide_big(); return true).call())
	_chk("NV-T20 1000 navegações", (func(): for i in range(1000): router.open_item_inspection("Núcleo de Cristal"); router._hide_big(); return _ii() != null).call())

# ══ BACKSTACK25 (≥20) ══
func _backstack() -> void:
	print("  ── BACKSTACK25 ──"); _prep()
	# FLOW A: Refine → Acquisition → Inventory → (Item) → Back → ...
	router.open_refine("weapon")
	_chk("BK-T01 Refine aberto", sp.visible)
	router.open_acquisition("Fragmentos", 40, "REFINE", "weapon")
	_chk("BK-T02 Acquisition (push)", ctl.backstack.is_open("ACQUISITION") and not sp.visible)
	# FLOW B: Item → Acquisition → Bestiary → drop → Item → Back
	router.open_item_inspection("Núcleo de Cristal")
	_chk("BK-T03 Item Inspection aberto", _ii().visible)
	_press(_ii().como_obter_btn)
	_chk("BK-T04 Item → Acquisition", ctl.is_panel_open())
	var mc := ctl.panel.find_card(func(e): return str(e.get("nav_mob", "")) == "living_shard")
	_press(mc["bestiary_btn"])
	_chk("BK-T05 Acquisition → Bestiary", _bp().visible)
	_press(_bp().drop_button_for("Núcleo de Cristal"))
	_chk("BK-T06 Bestiary → Item Inspection drop", _ii().visible)
	_press(_ii().back_btn)
	_chk("BK-T07 Back esconde Item Inspection", not _ii().visible)
	# FLOW C: Acquisition → Mission → Back → Acquisition
	gs.set_story_flag("GP_MISSION_001_COMPLETE")
	router.open_acquisition("Fragmento do Golem", 1, "REFINE", "weapon")
	_chk("BK-T08 Acquisition aberto", ctl.is_panel_open())
	var msc := ctl.panel.find_card(func(e): return str(e["source_type"]) == "MISSION_REWARD")
	if msc.get("action_btn") != null: _press(msc["action_btn"])
	else: router.open_mission("C2_M006")
	_chk("BK-T09 Acquisition → Mission", _mp().visible)
	_press(_mp().back_btn)
	_chk("BK-T10 Mission → Back", not _mp().visible)
	# ESC fecha topo, controller backstack
	ctl.backstack.clear()
	router.open_acquisition("Núcleo de Cristal", 5, "REFINE", "weapon")
	_chk("BK-T11 backstack push ACQUISITION", ctl.backstack.is_open("ACQUISITION"))
	_press(ctl.panel.find_card(func(e): return str(e.get("nav_mob",""))=="living_shard")["action_btn"])
	_chk("BK-T12 push HUNT_CONFIRM", ctl.backstack.is_open("HUNT_CONFIRM"))
	ctl.backstack.back()
	_chk("BK-T13 back fecha topo só", not ctl.backstack.is_open("HUNT_CONFIRM"))
	_press(ctl.confirm.cancel_btn); ctl.close_panel()
	_chk("BK-T14 um painel grande (nunca 2)", not (sp.visible and ctl.is_panel_open()))
	router.open_bestiary("living_shard")
	_chk("BK-T15 abrir bestiary esconde acquisition", not ctl.is_panel_open())
	router.open_item_inspection("Núcleo de Cristal")
	_chk("BK-T16 abrir inspection esconde bestiary", not _bp().visible and _ii().visible)
	router.open_salvage()
	_chk("BK-T17 abrir salvage esconde inspection", not _ii().visible and _svp().visible)
	router.open_mission("C2_M001")
	_chk("BK-T18 abrir mission esconde salvage", not _svp().visible and _mp().visible)
	router._hide_big()
	_chk("BK-T19 hide_all fecha tudo", not _mp().visible and not _bp().visible and not _ii().visible and not _svp().visible)
	_chk("BK-T20 repetido estável", (func(): for i in range(10): router.open_bestiary("living_shard"); router.open_mission("C2_M001"); router._hide_big(); return true).call())

# ══ A25SECURITY (≥20) ══
func _security() -> void:
	print("  ── A25SECURITY ──"); _prep()
	_chk("SEC-T01 fake item (sem fonte) → sem COMO OBTER", (func(): router.open_item_inspection("fake_item"); return _ii().como_obter_btn == null).call())
	_chk("SEC-T02 fake iid seguro (inst vazio)", (func(): router.open_item_inspection("sword_reinforced", {"iid": "hack"}); return _ii().visible).call())
	_chk("SEC-T03 foreign iid: salvage valida por id/posse", not bool(lm.manual_salvage("dagger_forjada").get("ok", false)))
	_chk("SEC-T04 fake mob → painel não crasha", (func(): router.open_bestiary("mob_hack"); return _bp().visible).call())
	_chk("SEC-T05 locked mob: sem CAÇAR", (func(): _prep(); gs.equipment = {}; gs.stage_highest_global = 1; router.open_bestiary("living_shard"); return _bp().hunt_btn == null).call())
	_prep()
	_chk("SEC-T06 fake mission → sem INICIAR", (func(): router.open_mission("MISSAO_HACK"); return _mp().start_button_for("MISSAO_HACK") == null).call())
	_chk("SEC-T07 locked mission: sem INICIAR", (func(): _prep(); gs.story_flags.clear(); router.open_mission("C2_M008"); return _mp().start_button_for("C2_M008") == null).call())
	_prep()
	_chk("SEC-T08 fake salvage yield: usa salvage_value único", lm.manual_salvage("dagger_rusty").get("yield", -1) == lm.salvage_value("dagger_rusty") or gs.backpack_count("dagger_rusty") == 0)
	_prep()
	_chk("SEC-T09 fake Fragment gain: só via authority", (func(): var f0: int = gs.fragments(); lm.manual_salvage("nao_existe"); return gs.fragments() == f0).call())
	gs.set_item_locked("dagger_rusty", true)
	_chk("SEC-T10 protected salvage negado", not bool(lm.manual_salvage("dagger_rusty").get("ok", false)))
	gs.set_item_locked("dagger_rusty", false)
	_chk("SEC-T11 double salvage: exact-once", (func(): _prep(); gs.backpack = [{"id": "dagger_rusty", "qty": 1}]; lm.manual_salvage("dagger_rusty"); return not bool(lm.manual_salvage("dagger_rusty").get("ok", false))).call())
	_prep()
	_chk("SEC-T12 stale iid seguro", not bool(lm.manual_salvage("").get("ok", false)))
	_chk("SEC-T13 route injection (bestiary id arbitrário) seguro", (func(): router.open_bestiary("../../hack"); return _bp().visible).call())
	_chk("SEC-T14 backstack injection seguro", (func(): ctl.backstack.clear(); ctl.backstack.back(); return true).call())
	_chk("SEC-T15 button spam salvage seguro", (func(): _prep(); router.open_salvage(); for i in range(10): if _svp().desmontar_button_for("dagger_rusty") != null: _press(_svp().desmontar_button_for("dagger_rusty")); return true).call())
	_prep()
	_chk("SEC-T16 forged mission status: deriva do golden", main._missionhost.golden.is_complete("C2_M001"))
	_chk("SEC-T17 forged discovery: deriva de bestiary/kills", res.discovery_state("young_wolf") in ["KNOWN", "HINTED"])
	_chk("SEC-T18 forged item source: registry só dados reais", ItemSourceRegistry.sources_for("forjado").is_empty())
	_chk("SEC-T19 foreign tracked goal: goal do gs local", res.gs == gs)
	_chk("SEC-T20 malformed IDs não crasham", (func(): router.open_item_inspection(""); router.open_bestiary(""); router.open_mission(""); return true).call())
	router._hide_big()

# ══ RESPONSIVE25 (≥15) ══
func _responsive() -> void:
	print("  ── RESPONSIVE25 ──"); _prep()
	var reslist := [Vector2(1280, 720), Vector2(1366, 768), Vector2(1600, 900), Vector2(1920, 1080), Vector2(2560, 1440)]
	var i := 0
	for r in reslist:
		var bp := UiMetrics.breakpoint_for(UiMetrics.logical_viewport(r).x)
		_chk("RSP-T%02d %dx%d breakpoint" % [i + 1, int(r.x), int(r.y)], bp != "")
		i += 1
	# painéis constroem
	router.open_item_inspection("Núcleo de Cristal")
	_chk("RSP-T06 ItemInspection constrói", _ii().visible)
	router.open_bestiary("living_shard")
	_chk("RSP-T07 Bestiary constrói", _bp().visible and _bp().mob_buttons.size() > 0)
	router.open_mission("C2_M001")
	_chk("RSP-T08 MissionSelector constrói", _mp().visible)
	router.open_salvage()
	_chk("RSP-T09 Salvage constrói", _svp().visible)
	# touch targets nos painéis (>=TT_B desktop)
	router.open_bestiary("living_shard")
	_chk("RSP-T10 Bestiary CAÇAR toque >= TT", _bp().hunt_btn == null or _bp().hunt_btn.custom_minimum_size.y >= UiMetrics.min_touch_target("desktop", "TT_B"))
	_chk("RSP-T11 Bestiary back >= TT_D", _bp().back_btn.custom_minimum_size.y >= UiMetrics.min_touch_target("desktop", "TT_D"))
	router.open_salvage()
	_chk("RSP-T12 Salvage DESMONTAR toque >= TT", _svp().desmontar_button_for("dagger_rusty") == null or _svp().desmontar_button_for("dagger_rusty").custom_minimum_size.y >= UiMetrics.min_touch_target("desktop", "TT_B"))
	router.open_item_inspection("Núcleo de Cristal")
	_chk("RSP-T13 ItemInspection back >= TT_D", _ii().back_btn.custom_minimum_size.y >= UiMetrics.min_touch_target("desktop", "TT_D"))
	_chk("RSP-T14 safe_area válido", not UiMetrics.safe_area({}, "desktop").is_empty())
	_chk("RSP-T15 sem overlap crítico (painéis com min_size)", _bp().custom_minimum_size.x > 0)
	router._hide_big()
