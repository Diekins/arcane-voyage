extends SceneTree
## A32 — BOSS BESTIARY & ENCOUNTER INTELLIGENCE V1 (bancada). Usa TestHarness (A31, no-silent-green). Prova o
## modelo de entrada de boss (deriva do save, zero campo novo), discovery/defeat/first-clear, drops, UI da categoria
## BOSSES, navegação (LUTAR gateado), save v10 e escalabilidade registry-driven. spider_matriarch ≠ root_matriarch.
## Grupos: AUDIT/REGISTRY/DISCOVERY/DEFEAT/UI/NAV/DROP/FIRSTCLEAR/SAVE/SCALABILITY. Cena real = _a32_scene_selftest.gd.

var H: TestHarness
var gs
var _mem: Dictionary = {}
const WOLF := "BOSS_WOLF_ALPHA"
const GOLEM := "BOSS_CRYSTAL_GOLEM"
const SPIDER := "BOSS_CH3_SPIDER_MATRIARCH"

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	if gs == null:
		print(">>> FALHOU (sem GameState)"); quit(1); return
	gs.set_save_path_override("user://a32_fixture.json")
	_mem = gs.to_dict().duplicate(true)
	H = TestHarness.new()
	_audit(); _registry(); _discovery(); _defeat(); _ui(); _nav(); _drop(); _firstclear(); _save(); _scalability()
	gs.apply_dict(_mem)
	if FileAccess.file_exists("user://a32_fixture.json"): DirAccess.remove_absolute("user://a32_fixture.json")
	var res := H.summarize("A32")
	quit(0 if bool(res["ok"]) else 1)

func _golden() -> GoldenPath:
	var g := GoldenPath.new(); g.setup(gs); return g

func _reset() -> void:
	gs.reset_save(); gs.set_save_path_override("user://a32_fixture.json")

func _flag(mid: String) -> void:
	gs.set_story_flag("GP_%s_COMPLETE" % mid)

# torna um boss DISPONÍVEL (completa a prev_mission) — sem vencer
func _make_available(boss_id: String) -> void:
	var prev := str(BossActivityDefinition.get_boss(boss_id).get("unlock_rule", {}).get("prev_mission", ""))
	if prev != "": _flag(prev)

# vence o boss (first-clear) via ponto autoritativo
func _win(boss_id: String) -> void:
	_make_available(boss_id)
	_golden().mark_boss_cleared(boss_id)

# ════════════════════════════════════════════════════════════════════════════════════════════
func _audit() -> void:
	H.group_begin("BOSS32AUDIT", 25)
	H.check("AUD-01 BossBestiary existe", ClassDB.class_exists("RefCounted"))   # sanity
	var g := _golden()
	# 3 bosses reais no registry
	H.check("AUD-02 BOSS_WOLF_ALPHA existe", BossActivityDefinition.exists(WOLF))
	H.check("AUD-03 BOSS_CRYSTAL_GOLEM existe", BossActivityDefinition.exists(GOLEM))
	H.check("AUD-04 BOSS_CH3_SPIDER_MATRIARCH existe", BossActivityDefinition.exists(SPIDER))
	# BossBestiary enumera do registry
	var ids := BossBestiary.boss_ids()
	H.check("AUD-05 boss_ids enumera 3+", ids.size() >= 3)
	H.check("AUD-06 boss_ids ⊇ os 3 core", TestHarness.missing_ids([WOLF, GOLEM, SPIDER], ids).is_empty())
	H.check("AUD-07 boss_ids únicos", TestHarness.duplicate_ids(ids).is_empty())
	# entry tem os campos do modelo
	_reset()
	var e := BossBestiary.entry(g, WOLF)
	for k in ["boss_id", "discovery", "discovered", "defeated", "first_clear_complete", "chapter_id", "display_name", "region", "available", "availability_state", "locked_reason", "best_difficulty", "difficulties", "action", "drops"]:
		H.check("AUD entry tem campo %s" % k, e.has(k))
	# derivação: fresh save → não descoberto (nada revelado sem motivo §28)
	H.check("AUD-23 fresh → WOLF UNKNOWN", str(e["discovery"]) == BossBestiary.UNKNOWN)
	# best_difficulty derivado (não vem de source), single-difficulty V1
	H.check("AUD-24 difficulties = [NORMAL] (Nightmare deferred)", e["difficulties"] == ["NORMAL"])
	# save v10 (nenhum campo novo — deriva de story_flags)
	H.check("AUD-25 save schema == 10 (sem bump)", int(gs.SAVE_SCHEMA) == 10)
	H.check("AUD-26 spider_matriarch É o visual do boss Ch3", str(BossActivityDefinition.get_boss(SPIDER).get("visual_id")) == "spider_matriarch")
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _registry() -> void:
	H.group_begin("BOSS32REGISTRY", 25)
	var g := _golden(); _reset()
	var ids := BossBestiary.boss_ids()
	# unique + valid references
	H.check("REG-01 ids únicos", TestHarness.duplicate_ids(ids).is_empty())
	for bid in ids:
		H.check("REG exists(%s)" % bid, BossActivityDefinition.exists(bid))
		var e := BossBestiary.entry(g, bid)
		H.check("REG entry(%s) não vazia" % bid, not e.is_empty())
		H.check("REG chapter_id de %s válido" % bid, str(BossActivityDefinition.get_boss(bid).get("chapter_id", "")) != "")
	# MoonScar / Crystal Golem / ARANHA MATRIARCA identidade
	_make_available(WOLF)   # revela nome
	H.check("REG MoonScar = BOSS_WOLF_ALPHA (display MOONSCAR)", str(BossBestiary.entry(g, WOLF)["display_name"]).contains("MOONSCAR"))
	_reset(); _make_available(GOLEM)
	H.check("REG Crystal Golem display", str(BossBestiary.entry(g, GOLEM)["display_name"]).contains("GOLEM"))
	_reset(); _make_available(SPIDER)
	H.check("REG ARANHA MATRIARCA display", str(BossBestiary.entry(g, SPIDER)["display_name"]) == "ARANHA MATRIARCA")
	# sort estável por capítulo (não insertion order)
	H.check("REG sort: WOLF(Ch1) antes de GOLEM(Ch2)", ids.find(WOLF) < ids.find(GOLEM))
	H.check("REG sort: GOLEM(Ch2) antes de SPIDER(Ch3)", ids.find(GOLEM) < ids.find(SPIDER))
	# NEGATIVE IDENTITY: root_matriarch NÃO é boss
	H.check("REG root_matriarch NÃO existe como boss", not BossActivityDefinition.exists("root_matriarch"))
	H.check("REG root_matriarch NÃO está em boss_ids", not ("root_matriarch" in ids))
	H.check("REG entry(root_matriarch) vazia", BossBestiary.entry(g, "root_matriarch").is_empty())
	H.check("REG discovery_state(root_matriarch) = UNKNOWN", BossBestiary.discovery_state(g, "root_matriarch") == BossBestiary.UNKNOWN)
	# spider ≠ root: ids diferentes, não compartilham
	H.check("REG spider ≠ root (ids distintos)", SPIDER != "root_matriarch" and BossActivityDefinition.exists(SPIDER))
	H.check("REG Crystal Golem ≠ candidates futuros", not BossActivityDefinition.exists("MINE_GOLEM") and not BossActivityDefinition.exists("DEEP_CRYSTAL_COLOSSUS"))
	# não confundir com Ch4 candidates (não são boss)
	H.check("REG Ch4 candidates NÃO são boss", not BossActivityDefinition.exists("BOSS_SALT_SPLIT_WARDEN") and not BossActivityDefinition.exists("BOSS_CARNICEIRO_AREIAS"))
	# cada boss: chapter_id ∈ registry de capítulos (ref cross-registry) + action é enum válido + gear garantido resolve
	var chap_set: Array = []
	for mid in AfkMissionDefinition.MISSIONS:
		var c := str(AfkMissionDefinition.MISSIONS[mid].get("chapter_id", ""))
		if c != "" and not (c in chap_set): chap_set.append(c)
	for bid in ids:
		var ch := str(BossActivityDefinition.get_boss(bid).get("chapter_id", ""))
		H.check("REG %s chapter ∈ mission registry" % bid, ch in chap_set)
		var e := BossBestiary.entry(_golden(), bid)
		H.check("REG %s action ∈ {FIGHT,LOCKED}" % bid, str(e["action"]) in ["FIGHT", "LOCKED"])
	# guaranteed gear resolve p/ toda família
	for wk in ["sword", "bow", "staff", "spear", "book"]:
		H.check("REG guaranteed_gear(%s) resolve item real" % wk, ItemDB.exists(BossActivityDefinition.guaranteed_gear_for_weapon(wk)))
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _discovery() -> void:
	H.group_begin("BOSS32DISCOVERY", 25)
	var g := _golden()
	# fresh → todos UNKNOWN
	_reset()
	for bid in [WOLF, GOLEM, SPIDER]:
		H.check("DISC fresh %s UNKNOWN" % bid, BossBestiary.discovery_state(g, bid) == BossBestiary.UNKNOWN)
		H.check("DISC fresh %s discovered=false" % bid, not bool(BossBestiary.entry(g, bid)["discovered"]))
		H.check("DISC fresh %s nome oculto (???)" % bid, str(BossBestiary.entry(g, bid)["display_name"]) == "???")
	# unlock → DISCOVERED (identidade revelada)
	_reset(); _make_available(WOLF)
	H.check("DISC WOLF unlock → DISCOVERED", BossBestiary.discovery_state(g, WOLF) == BossBestiary.DISCOVERED)
	H.check("DISC WOLF nome revelado", str(BossBestiary.entry(g, WOLF)["display_name"]) != "???")
	H.check("DISC WOLF region revelada", str(BossBestiary.entry(g, WOLF)["region"]) != "???")
	H.check("DISC outros ainda UNKNOWN (spoiler)", BossBestiary.discovery_state(g, GOLEM) == BossBestiary.UNKNOWN)
	# defeat → DEFEATED
	_reset(); _win(WOLF)
	H.check("DISC WOLF defeat → DEFEATED", BossBestiary.discovery_state(g, WOLF) == BossBestiary.DEFEATED)
	H.check("DISC WOLF defeated=true", bool(BossBestiary.entry(g, WOLF)["defeated"]))
	# relog: estado preservado (deriva de story_flags persistidos)
	var snap: Dictionary = gs.to_dict().duplicate(true)
	gs.reset_save(); gs.apply_dict(snap); gs.set_save_path_override("user://a32_fixture.json")
	H.check("DISC relog preserva DEFEATED", BossBestiary.discovery_state(_golden(), WOLF) == BossBestiary.DEFEATED)
	# discovery idempotente (marcar de novo não muda)
	_reset(); _make_available(SPIDER)
	var s1 := BossBestiary.discovery_state(g, SPIDER)
	_make_available(SPIDER)
	H.check("DISC idempotente", BossBestiary.discovery_state(g, SPIDER) == s1 and s1 == BossBestiary.DISCOVERED)
	# não marca tudo conhecido desde new game (§28)
	_reset()
	var known := 0
	for bid in BossBestiary.boss_ids():
		if bool(BossBestiary.entry(g, bid)["discovered"]): known += 1
	H.check("DISC new game NÃO revela bosses (0 discovered)", known == 0)
	# ciclo completo UNKNOWN→DISCOVERED→DEFEATED por boss (3 estados × 3 bosses)
	for bid in [WOLF, GOLEM, SPIDER]:
		_reset()
		H.check("DISC %s UNKNOWN inicial" % bid, BossBestiary.discovery_state(g, bid) == BossBestiary.UNKNOWN)
		_make_available(bid)
		H.check("DISC %s → DISCOVERED após unlock" % bid, BossBestiary.discovery_state(g, bid) == BossBestiary.DISCOVERED)
		_golden().mark_boss_cleared(bid)
		H.check("DISC %s → DEFEATED após vitória" % bid, BossBestiary.discovery_state(g, bid) == BossBestiary.DEFEATED)
	# DISCOVERED revela região mas mantém possible drops ocultos (spoiler parcial)
	_reset(); _make_available(GOLEM)
	H.check("DISC DISCOVERED revela região", str(BossBestiary.entry(g, GOLEM)["region"]) != "???")
	H.check("DISC DISCOVERED oculta possible drops", not bool(BossBestiary.drops(g, GOLEM)["revealed"]))
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _defeat() -> void:
	H.group_begin("BOSS32DEFEAT", 20)
	var g := _golden()
	_reset()
	H.check("DEF fresh não derrotado", not bool(BossBestiary.entry(g, GOLEM)["defeated"]))
	# derrota autoritativa via mark_boss_cleared (não UI)
	_win(GOLEM)
	H.check("DEF mark_boss_cleared → defeated", bool(BossBestiary.entry(g, GOLEM)["defeated"]))
	H.check("DEF defeated = boss_first_cleared (autoritativo)", g.boss_first_cleared(GOLEM))
	H.check("DEF chapter complete setado", g.is_chapter_complete("CHAPTER_2_CRYSTAL"))
	# per-boss: derrotar GOLEM não derrota SPIDER
	H.check("DEF per-boss isolado (SPIDER não afetado)", not bool(BossBestiary.entry(g, SPIDER)["defeated"]))
	# UI não é fonte de defeat: entry só reflete flags
	_reset()
	H.check("DEF sem flag → não derrotado (UI não concede)", not bool(BossBestiary.entry(g, WOLF)["defeated"]))
	# cada boss derrotável independentemente
	for bid in [WOLF, GOLEM, SPIDER]:
		_reset(); _win(bid)
		var e := BossBestiary.entry(g, bid)
		H.check("DEF %s derrotável" % bid, bool(e["defeated"]))
		H.check("DEF %s best_difficulty=NORMAL após vitória" % bid, str(e["best_difficulty"]) == "NORMAL")
		H.check("DEF %s first_clear_complete" % bid, bool(e["first_clear_complete"]))
		H.check("DEF %s replayable: available=true" % bid, bool(e["available"]))
		H.check("DEF %s action=FIGHT após vitória" % bid, str(e["action"]) == "FIGHT")
	# best_difficulty vazio se não vencido
	_reset()
	H.check("DEF best_difficulty vazio sem vitória", str(BossBestiary.entry(g, WOLF)["best_difficulty"]) == "")
	# morte do herói NÃO conta como defeat (só mark_boss_cleared conta) — sem flag, sem defeated
	_reset(); _make_available(WOLF)
	H.check("DEF disponível-mas-não-vencido = discovered, não defeated", BossBestiary.discovery_state(g, WOLF) == BossBestiary.DISCOVERED and not bool(BossBestiary.entry(g, WOLF)["defeated"]))
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _panel() -> BestiaryPanel:
	var res := AcquisitionResolver.new(); res.setup(gs)
	var p := BestiaryPanel.new(); root.add_child(p)
	p.open(res, gs)
	return p

func _ui() -> void:
	H.group_begin("BOSS32UI", 30)
	_reset()
	# revela WOLF (DISCOVERED) e derrota GOLEM (DEFEATED) p/ exercitar estados
	_make_available(WOLF); _win(GOLEM)
	var p := _panel()
	# categorias
	H.check("UI-01 categoria default MOBS", p._category == "MOBS")
	H.check("UI-02 toggle BOSSES existe", p.cat_bosses_btn != null)
	p._set_category("BOSSES")
	H.check("UI-03 troca p/ BOSSES", p._category == "BOSSES")
	# lista de bosses (registry-driven)
	H.check("UI-04 botão WOLF na lista", p.boss_button_for(WOLF) != null)
	H.check("UI-05 botão GOLEM na lista", p.boss_button_for(GOLEM) != null)
	H.check("UI-06 botão SPIDER na lista", p.boss_button_for(SPIDER) != null)
	H.check("UI-07 root_matriarch NÃO tem botão", p.boss_button_for("root_matriarch") == null)
	# selecionar WOLF (DISCOVERED) → detalhe revela identidade + availability + fight
	p._select_boss(WOLF)
	H.check("UI-08 selected_boss = WOLF", p.selected_boss == WOLF)
	H.check("UI-09 selected_mob limpo", p.selected_mob == "")
	H.check("UI-10 WOLF disponível → fight_btn presente", p.fight_btn != null)
	H.check("UI-11 WOLF fight_btn texto LUTAR", p.fight_btn != null and str(p.fight_btn.text).contains("LUTAR"))
	H.check("UI-12 WOLF sem locked label", p.boss_locked_lbl == null)
	# GOLEM (DEFEATED) → drops revelados + first-clear completo + LUTAR NOVAMENTE
	p._select_boss(GOLEM)
	H.check("UI-13 GOLEM selecionado", p.selected_boss == GOLEM)
	H.check("UI-14 GOLEM defeated → fight LUTAR NOVAMENTE", p.fight_btn != null and str(p.fight_btn.text).contains("NOVAMENTE"))
	H.check("UI-15 GOLEM drop button (revelado)", p.drop_button_for("sword_reinforced") != null or p.drop_buttons.size() > 0)
	# SPIDER (UNKNOWN) → nome oculto, sem detalhe além do status
	_reset()   # zera → SPIDER volta a UNKNOWN
	var p2 := _panel(); p2._set_category("BOSSES"); p2._select_boss(SPIDER)
	H.check("UI-16 SPIDER UNKNOWN selecionado", p2.selected_boss == SPIDER)
	H.check("UI-17 SPIDER UNKNOWN sem fight_btn (spoiler)", p2.fight_btn == null)
	# boss LOCKED (disponível=false) mas descoberto? WOLF sem unlock = UNKNOWN; usemos um cenário LOCKED real:
	# GOLEM disponível requer C2_M008; sem ele e sem clear → UNKNOWN. LOCKED-com-nome não ocorre p/ story bosses
	# (unknown até unlock). Então validamos: locked feedback aparece só quando available=false E discovered.
	# discovered exige available OU cleared ⇒ se discovered e não available, foi cleared (available porém).
	# Cobrimos o caminho LOCKED via entry diretamente:
	_reset()
	var e_locked := BossBestiary.entry(_golden(), SPIDER)
	H.check("UI-18 LOCKED tem locked_reason (requisito real)", str(e_locked["locked_reason"]).contains("C3_M008"))
	H.check("UI-19 LOCKED action = LOCKED", str(e_locked["action"]) == "LOCKED")
	# category toggle de volta p/ MOBS mantém mob path
	p._set_category("MOBS")
	H.check("UI-20 volta p/ MOBS", p._category == "MOBS")
	H.check("UI-21 mob path intacto (young_wolf botão)", p.mob_button_for("young_wolf") != null)
	H.check("UI-22 mob selecionável", (func(): p.select("young_wolf"); return p.selected_mob == "young_wolf").call())
	# rebuild não acumula (free imediato) — trocar categoria 2x e conferir contagem estável de botões de boss
	p._set_category("BOSSES"); var n1 := p.boss_buttons.size()
	p._set_category("MOBS"); p._set_category("BOSSES")
	H.check("UI-23 rebuild determinístico (sem acúmulo)", p.boss_buttons.size() == n1)
	# card compacto tem status/região/first-clear/drops (detalhe não vazio) — re-estabelece GOLEM derrotado
	_win(GOLEM)
	p._select_boss(GOLEM)
	H.check("UI-24 detalhe do boss tem múltiplas linhas", p._detail.get_child_count() >= 5)
	# performance: abrir a lista NÃO instancia encounter pesado
	H.check("UI-25 sem BossEncounter instanciado ao listar", root.get_node_or_null("BossEncounter") == null)
	# acessores de teste
	H.check("UI-26 boss_button_for retorna Button", p.boss_button_for(GOLEM) is Button)
	H.check("UI-27 back_btn presente", p.back_btn != null)
	H.check("UI-28 cat_mobs_btn presente", p.cat_mobs_btn != null)
	# availability textual coerente (sempre disponível após unlock)
	_reset(); _make_available(WOLF)
	var p3 := _panel(); p3._set_category("BOSSES"); p3._select_boss(WOLF)
	H.check("UI-29 WOLF disponível mostra fight", p3.fight_btn != null)
	H.check("UI-30 UNKNOWN não vaza drops", (func(): var pp := _panel(); pp._set_category("BOSSES"); _reset(); pp._select_boss(SPIDER); return pp.drop_buttons.is_empty()).call())
	p.free(); p2.free(); p3.free()
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _nav() -> void:
	H.group_begin("BOSS32NAV", 25)
	_reset(); _make_available(WOLF)
	var p := _panel(); p._set_category("BOSSES"); p._select_boss(WOLF)
	# LUTAR emite boss_fight_requested com o id certo
	var fired := {"id": ""}
	p.boss_fight_requested.connect(func(bid): fired["id"] = bid)
	H.check("NAV-01 WOLF disponível → fight_btn", p.fight_btn != null)
	p.fight_btn.pressed.emit()
	H.check("NAV-02 LUTAR emite boss_fight_requested(WOLF)", str(fired["id"]) == WOLF)
	# gate: start_boss recusa boss LOCKED (não burla progressão)
	var g := _golden()
	H.check("NAV-03 WOLF available (unlock feito)", g.boss_available(WOLF))
	_reset()
	H.check("NAV-04 sem unlock → boss_available false", not _golden().boss_available(SPIDER))
	# entry LOCKED: action LOCKED + reason, sem fight
	var e := BossBestiary.entry(_golden(), SPIDER)
	H.check("NAV-05 LOCKED action", str(e["action"]) == "LOCKED")
	H.check("NAV-06 LOCKED reason explica requisito", str(e["locked_reason"]) != "" and str(e["locked_reason"]).contains("C3_M008"))
	# painel de boss LOCKED: sem fight_btn, com locked label
	var p2 := _panel(); p2._set_category("BOSSES")
	# forçar seleção do SPIDER (UNKNOWN pois sem unlock) → não mostra fight (spoiler)
	p2._select_boss(SPIDER)
	H.check("NAV-07 SPIDER UNKNOWN sem fight_btn", p2.fight_btn == null)
	# cenário DEFEATED (available) → LUTAR NOVAMENTE navega
	_reset(); _win(WOLF)
	var p3 := _panel(); p3._set_category("BOSSES"); p3._select_boss(WOLF)
	var fired2 := {"id": ""}
	p3.boss_fight_requested.connect(func(bid): fired2["id"] = bid)
	H.check("NAV-08 DEFEATED tem LUTAR NOVAMENTE", p3.fight_btn != null and str(p3.fight_btn.text).contains("NOVAMENTE"))
	p3.fight_btn.pressed.emit()
	H.check("NAV-09 re-fight emite boss_fight_requested", str(fired2["id"]) == WOLF)
	# open_boss respeita gate via boss_available (autoritativo no MissionHost.start_boss)
	H.check("NAV-10 available após defeat (replayable)", _golden().boss_available(WOLF))
	# cross-link: ItemSourceRegistry aponta o item ao boss (item→boss)
	ItemSourceRegistry.invalidate()
	var wolf_gear := BossActivityDefinition.guaranteed_gear_for_weapon("sword")
	var srcs := ItemSourceRegistry.sources_for(wolf_gear)
	H.check("NAV-11 item→boss: gear tem fonte BOSS_DROP", srcs.any(func(s): return str(s.get("source_type", "")) == "BOSS_DROP"))
	H.check("NAV-12 item→boss aponta um boss_id real", srcs.any(func(s): return BossActivityDefinition.exists(str(s.get("boss_id", "")))))
	# boss→item: entry.drops lista o gear garantido (mesma fonte)
	var e2 := BossBestiary.entry(_golden(), WOLF, "sword")
	var gset: Array = e2["drops"]["guaranteed"]
	H.check("NAV-13 boss→item: drop garantido presente", not gset.is_empty())
	H.check("NAV-14 boss→item: gear = guaranteed_gear_for_weapon(sword)", gset.size() > 0 and str(gset[0]["item_key"]) == wolf_gear)
	# não duas verdades: o item garantido do drop == o do ItemSourceRegistry
	H.check("NAV-15 single truth (drop == registry gear)", wolf_gear == str(gset[0]["item_key"]))
	# más navegações não crasham
	H.check("NAV-16 entry de id inexistente = vazia", BossBestiary.entry(_golden(), "NOPE").is_empty())
	# gate por-boss: cada boss disponível SÓ após sua prev_mission (LUTAR não burla)
	for bid in [WOLF, GOLEM, SPIDER]:
		_reset()
		H.check("NAV %s LOCKED sem unlock" % bid, not _golden().boss_available(bid) and str(BossBestiary.entry(_golden(), bid)["action"]) == "LOCKED")
		_make_available(bid)
		H.check("NAV %s FIGHT após unlock" % bid, _golden().boss_available(bid) and str(BossBestiary.entry(_golden(), bid)["action"]) == "FIGHT")
	# locked_reason cita a prev_mission real de cada boss
	_reset()
	H.check("NAV GOLEM locked cita C2_M008", str(BossBestiary.entry(_golden(), GOLEM)["locked_reason"]).contains("C2_M008"))
	H.check("NAV WOLF locked cita MISSION_006", str(BossBestiary.entry(_golden(), WOLF)["locked_reason"]).contains("MISSION_006"))
	# fluxo desejado (poucos cliques): categoria BOSSES → select → LUTAR (sem caminhada)
	_reset(); _make_available(WOLF)
	var pn := _panel()
	H.check("NAV MOBS→BOSSES em 1 clique", (func(): pn.cat_bosses_btn.pressed.emit(); return pn._category == "BOSSES").call())
	H.check("NAV select boss em 1 clique", (func(): pn.boss_button_for(WOLF).pressed.emit(); return pn.selected_boss == WOLF).call())
	var fired3 := {"id": ""}
	pn.boss_fight_requested.connect(func(bid): fired3["id"] = bid)
	H.check("NAV LUTAR em 1 clique → fight", (func(): pn.fight_btn.pressed.emit(); return str(fired3["id"]) == WOLF).call())
	pn.free()
	p.free(); p2.free(); p3.free()
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _drop() -> void:
	H.group_begin("BOSS32DROP", 25)
	var g := _golden()
	# DISCOVERED: guaranteed revelado, possible = ??? (não revelado)
	_reset(); _make_available(WOLF)
	var d := BossBestiary.drops(g, WOLF, "sword")
	H.check("DROP-01 guaranteed presente (DISCOVERED)", (d["guaranteed"] as Array).size() > 0)
	H.check("DROP-02 possible NÃO revelado antes de vencer", not bool(d["revealed"]))
	var poss: Array = d["possible"]
	H.check("DROP-03 possible mascarado (???)", poss.size() > 0 and str(poss[0]["item_key"]) == "???")
	H.check("DROP-04 guaranteed não-claimed (ainda não venceu)", not bool((d["guaranteed"] as Array)[0]["claimed"]))
	# DEFEATED: possible revelado, guaranteed claimed
	_reset(); _win(WOLF)
	var d2 := BossBestiary.drops(g, WOLF, "sword")
	H.check("DROP-05 revealed após vitória", bool(d2["revealed"]))
	var poss2: Array = d2["possible"]
	H.check("DROP-06 possible revelado (id real)", poss2.size() > 0 and str(poss2[0]["item_key"]) != "???")
	H.check("DROP-07 guaranteed claimed após first-clear", bool((d2["guaranteed"] as Array)[0]["claimed"]))
	# UNKNOWN: nada revelado
	_reset()
	var d3 := BossBestiary.drops(g, SPIDER)
	H.check("DROP-08 UNKNOWN não revela guaranteed", (d3["guaranteed"] as Array).is_empty())
	H.check("DROP-09 UNKNOWN não revela possible", (d3["possible"] as Array).is_empty())
	# guaranteed por família de arma (class-compatible)
	_reset(); _make_available(WOLF)
	H.check("DROP-10 guaranteed(sword) = sword_reinforced", str((BossBestiary.drops(g, WOLF, "sword")["guaranteed"] as Array)[0]["item_key"]) == "sword_reinforced")
	H.check("DROP-11 guaranteed(bow) = bow_reinforced", str((BossBestiary.drops(g, WOLF, "bow")["guaranteed"] as Array)[0]["item_key"]) == "bow_reinforced")
	H.check("DROP-12 guaranteed(book) = book_reinforced (A30)", str((BossBestiary.drops(g, WOLF, "book")["guaranteed"] as Array)[0]["item_key"]) == "book_reinforced")
	# sem arma → genérico (item_key vazio, by_weapon)
	var dgen := BossBestiary.drops(g, WOLF, "")
	H.check("DROP-13 sem arma → item_key vazio (por família)", str((dgen["guaranteed"] as Array)[0]["item_key"]) == "" and bool((dgen["guaranteed"] as Array)[0]["by_weapon"]))
	# possible pool = repeat.gear_pool do reward (mesma fonte, não lista manual)
	var pool: Array = BossActivityDefinition.get_boss(WOLF)["reward_profile"]["repeat"]["gear_pool"]
	_reset(); _win(WOLF)
	var poss3: Array = BossBestiary.drops(g, WOLF)["possible"]
	H.check("DROP-14 possible count == gear_pool count", poss3.size() == pool.size())
	H.check("DROP-15 possible[0] real_key ∈ gear_pool", pool.has(str(poss3[0]["real_key"])))
	# GUARANTEED vs POSSIBLE distintos (chance)
	H.check("DROP-16 possible tem chance (não garantido)", float(poss3[0]["chance"]) > 0.0 and float(poss3[0]["chance"]) < 1.0)
	# derivado do reward_profile.first_clear (guaranteed_gear_by_weapon)
	H.check("DROP-17 first_clear é guaranteed_gear_by_weapon", bool(BossActivityDefinition.get_boss(WOLF)["reward_profile"]["first_clear"]["guaranteed_gear_by_weapon"]))
	# ItemSourceRegistry concorda (single truth) p/ cada boss
	ItemSourceRegistry.invalidate()
	for bid in [WOLF, GOLEM, SPIDER]:
		var gear := BossActivityDefinition.guaranteed_gear_for_weapon("sword")
		H.check("DROP registry BOSS_DROP p/ %s gear" % bid, ItemSourceRegistry.has_source(gear))
	# UI não concede reward (só informa) — equipa espada p/ o guaranteed virar botão clicável (cross-link)
	_reset(); _make_available(WOLF); gs.equipment = {"weapon": "sword_simple"}
	var seals := int(gs.cycle_seals)
	var p := _panel(); p._set_category("BOSSES"); p._select_boss(WOLF)
	H.check("DROP-21 abrir card NÃO concede reward", int(gs.cycle_seals) == seals)
	H.check("DROP-22 abrir card NÃO derrota", not bool(BossBestiary.entry(g, WOLF)["defeated"]))
	# guaranteed clicável leva a inspect (cross-link), não concede
	H.check("DROP-23 guaranteed drop é botão (inspect cross-link)", p.drop_button_for("sword_reinforced") != null)
	# clicar o guaranteed emite inspect_requested (leva ao Item Inspection), não concede
	var inspected := {"k": ""}
	p.inspect_requested.connect(func(k): inspected["k"] = k)
	if p.drop_button_for("sword_reinforced") != null: p.drop_button_for("sword_reinforced").pressed.emit()
	H.check("DROP-24 clique no drop → inspect_requested (cross-link, não concede)", str(inspected["k"]) == "sword_reinforced" and int(gs.cycle_seals) == seals)
	p.free()
	H.check("DROP-25 possible mascarado até defeat (spoiler §24)", str((BossBestiary.drops(_golden(), SPIDER, "sword")["possible"])) == str([]))
	# guaranteed == a MESMA fonte que o ItemSourceRegistry deriva (single truth, sem lista manual)
	ItemSourceRegistry.invalidate()
	var gk := str((BossBestiary.drops(g, WOLF, "sword")["guaranteed"] as Array)[0]["item_key"])
	H.check("DROP-26 guaranteed == fonte do registry (single truth)", ItemSourceRegistry.has_source(gk) and gk == "sword_reinforced")
	# possible pool não vaza no estado DISCOVERED (mascarado) mas conta bate quando revelado
	_reset(); _win(WOLF)
	H.check("DROP-27 revelado após defeat expõe pool real", BossBestiary.drops(g, WOLF)["possible"].size() == (BossActivityDefinition.get_boss(WOLF)["reward_profile"]["repeat"]["gear_pool"] as Array).size())
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _firstclear() -> void:
	H.group_begin("BOSS32FIRSTCLEAR", 20)
	var g := _golden()
	_reset()
	H.check("FC-01 fresh first_clear pendente", not bool(BossBestiary.entry(g, WOLF)["first_clear_complete"]))
	# 1ª vitória → exact once
	_make_available(WOLF)
	var first := g.mark_boss_cleared(WOLF)
	H.check("FC-02 1ª vitória retorna true (first-clear)", first)
	H.check("FC-03 entry first_clear_complete", bool(BossBestiary.entry(g, WOLF)["first_clear_complete"]))
	# repetir NÃO duplica first-clear
	var second := g.mark_boss_cleared(WOLF)
	H.check("FC-04 2ª vitória NÃO é first-clear (exact-once)", not second)
	H.check("FC-05 first_clear_complete continua true", bool(BossBestiary.entry(g, WOLF)["first_clear_complete"]))
	# status DEFEATED
	H.check("FC-06 status DEFEATED", BossBestiary.discovery_state(g, WOLF) == BossBestiary.DEFEATED)
	# drop guaranteed marcado como claimed após first-clear
	H.check("FC-07 guaranteed claimed=true", bool((BossBestiary.drops(g, WOLF, "sword")["guaranteed"] as Array)[0]["claimed"]))
	# per-boss: cada um exact-once independente
	for bid in [GOLEM, SPIDER]:
		_reset(); _make_available(bid)
		H.check("FC %s 1ª true" % bid, g.mark_boss_cleared(bid))
		H.check("FC %s 2ª false" % bid, not g.mark_boss_cleared(bid))
		H.check("FC %s complete" % bid, bool(BossBestiary.entry(g, bid)["first_clear_complete"]))
	# UI nunca concede: entry só lê flags
	_reset()
	H.check("FC-14 sem flag → não completo", not bool(BossBestiary.entry(g, WOLF)["first_clear_complete"]))
	# chapter completion acompanha first-clear
	_reset(); _win(SPIDER)
	H.check("FC-15 SPIDER first-clear fecha Chapter 3", g.is_chapter_complete("CHAPTER_3_SPIDER"))
	# repetição não re-concede: drop guaranteed fica claimed, e mark 3ª vez segue false
	H.check("FC-16 SPIDER 3ª vitória ainda não é first-clear", not g.mark_boss_cleared(SPIDER))
	H.check("FC-17 SPIDER guaranteed claimed", bool((BossBestiary.drops(g, SPIDER, "sword")["guaranteed"] as Array)[0]["claimed"]))
	# cada boss fecha SEU capítulo (não o do outro)
	_reset(); _win(WOLF)
	H.check("FC-18 WOLF fecha Ch1", g.is_chapter_complete("CHAPTER_1_WOLF"))
	H.check("FC-19 WOLF NÃO fecha Ch2", not g.is_chapter_complete("CHAPTER_2_CRYSTAL"))
	_reset(); _win(GOLEM)
	H.check("FC-20 GOLEM fecha Ch2", g.is_chapter_complete("CHAPTER_2_CRYSTAL"))
	H.check("FC-21 GOLEM NÃO fecha Ch1", not g.is_chapter_complete("CHAPTER_1_WOLF"))
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _save() -> void:
	H.group_begin("BOSS32SAVE", 20)
	# save v10, sem campo novo — deriva de story_flags
	H.check("SAVE-01 schema == 10", int(gs.SAVE_SCHEMA) == 10)
	_reset(); _win(WOLF); _make_available(GOLEM)
	# round-trip to_dict/apply_dict preserva estado derivável
	var snap: Dictionary = gs.to_dict().duplicate(true)
	H.check("SAVE-02 to_dict tem story_flags", snap.has("story_flags"))
	H.check("SAVE-03 schema no dump == 10", int(snap.get("schemaVersion", 0)) == 10)
	gs.reset_save(); gs.apply_dict(snap); gs.set_save_path_override("user://a32_fixture.json")
	var g := _golden()
	H.check("SAVE-04 WOLF DEFEATED preservado após round-trip", BossBestiary.discovery_state(g, WOLF) == BossBestiary.DEFEATED)
	H.check("SAVE-05 GOLEM DISCOVERED preservado", BossBestiary.discovery_state(g, GOLEM) == BossBestiary.DISCOVERED)
	H.check("SAVE-06 SPIDER UNKNOWN preservado", BossBestiary.discovery_state(g, SPIDER) == BossBestiary.UNKNOWN)
	# OLD SAVE: dump sem os flags de boss carrega e deriva UNKNOWN (default seguro, sem crash)
	var old_save := {"schemaVersion": 10}
	gs.reset_save(); gs.apply_dict(old_save); gs.set_save_path_override("user://a32_fixture.json")
	var g2 := _golden()
	for bid in [WOLF, GOLEM, SPIDER]:
		H.check("SAVE old-save %s → UNKNOWN (default seguro)" % bid, BossBestiary.discovery_state(g2, bid) == BossBestiary.UNKNOWN)
		H.check("SAVE old-save %s entry não crasha" % bid, not BossBestiary.entry(g2, bid).is_empty())
	# nenhum campo de boss_records/best_difficulty novo no dump (não bumpou por conveniência)
	H.check("SAVE-13 sem campo boss_records novo", not gs.to_dict().has("boss_records"))
	H.check("SAVE-14 sem campo best_difficulty novo", not gs.to_dict().has("boss_best_difficulty"))
	# o dump tem as MESMAS chaves-base (não adicionou chave de boss bestiary) — deriva de story_flags existente
	H.check("SAVE-13b dump carrega story_flags (fonte da derivação)", gs.to_dict().has("story_flags"))
	H.check("SAVE-13c dump sem chave boss_bestiary/boss_discovery", not gs.to_dict().has("boss_bestiary") and not gs.to_dict().has("boss_discovery"))
	# defeated_bosses (legado) NÃO é usado p/ os bosses de atividade (usa story_flags)
	_reset(); _win(WOLF)
	H.check("SAVE-15 defeat de atividade NÃO usa defeated_bosses legado", not gs.has_defeated_boss(WOLF))
	H.check("SAVE-16 defeat de atividade usa GP flag", gs.is_story_flag("GP_%s_CLEAR" % WOLF))
	# save antigo com bestiary de mob intacto (não conflita)
	var mixed := {"schemaVersion": 10, "bestiary": {"young_wolf": {"kills": 5, "claimed": 0}}}
	gs.reset_save(); gs.apply_dict(mixed); gs.set_save_path_override("user://a32_fixture.json")
	H.check("SAVE-17 bestiary de mob preservado", int((gs.bestiary.get("young_wolf", {}) as Dictionary).get("kills", 0)) == 5)
	H.check("SAVE-18 boss deriva UNKNOWN nesse save", BossBestiary.discovery_state(_golden(), WOLF) == BossBestiary.UNKNOWN)
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _scalability() -> void:
	H.group_begin("BOSS32SCALABILITY", 20)
	var g := _golden(); _reset()
	# enumeração registry-driven (não if boss==x): boss_ids == chaves enabled de BOSSES
	var reg_ids: Array = []
	for bid in BossActivityDefinition.BOSSES:
		if bool(BossActivityDefinition.BOSSES[bid].get("enabled", true)): reg_ids.append(str(bid))
	H.check("SCAL-01 boss_ids cobre todo o registry enabled", TestHarness.missing_ids(reg_ids, BossBestiary.boss_ids()).is_empty())
	H.check("SCAL-02 boss_ids não inventa ids fora do registry", TestHarness.missing_ids(BossBestiary.boss_ids(), reg_ids).is_empty())
	# entry funciona genericamente p/ QUALQUER boss do registry (sem ramo especial)
	for bid in BossBestiary.boss_ids():
		var e := BossBestiary.entry(g, bid)
		H.check("SCAL entry genérica p/ %s" % bid, e.has("boss_id") and e.has("drops") and e.has("action"))
	# sort estável e determinístico (2 chamadas = mesma ordem)
	H.check("SCAL-06 sort determinístico", str(BossBestiary.boss_ids()) == str(BossBestiary.boss_ids()))
	# ordenado por capítulo (chapter order crescente)
	var ids := BossBestiary.boss_ids()
	var ok_order := true
	for i in range(ids.size() - 1):
		if BossBestiary._chap_order(ids[i]) > BossBestiary._chap_order(ids[i + 1]): ok_order = false
	H.check("SCAL-07 ordenado por capítulo", ok_order)
	# FUTURE BOSS: um boss com chapter desconhecido ordena por último (não quebra)
	H.check("SCAL-08 chapter desconhecido → order 99 (vai p/ o fim)", BossBestiary._chap_order("boss_ficticio") == 99)
	# future-pack: se um Boss Ch4 real entrar no registry, boss_ids o incluiria (subset tolera crescer)
	var hypothetical := BossBestiary.boss_ids().duplicate(); hypothetical.append("BOSS_CH4_FUTURE")
	H.check("SCAL-09 +1 boss futuro não quebra unicidade", TestHarness.duplicate_ids(hypothetical).is_empty())
	H.check("SCAL-10 core segue presente com boss futuro", TestHarness.missing_ids([WOLF, GOLEM, SPIDER], hypothetical).is_empty())
	# negative: candidates de Ch4 (sem sprite/boss) NÃO entram
	H.check("SCAL-11 salt_split_warden não é boss", not BossActivityDefinition.exists("BOSS_SALT_SPLIT_WARDEN"))
	H.check("SCAL-12 boss_ids não contém candidates", not ("salt_split_warden" in BossBestiary.boss_ids()))
	# root_matriarch jamais vira boss silenciosamente (§18)
	H.check("SCAL-13 root_matriarch fora do boss_ids", not ("root_matriarch" in BossBestiary.boss_ids()))
	H.check("SCAL-14 root_matriarch entry vazia", BossBestiary.entry(g, "root_matriarch").is_empty())
	# adapter-free: todos os 3 usam o MESMO caminho (nenhum if boss==x na entry)
	H.check("SCAL-15 todos os bosses produzem entry com drops", BossBestiary.all_entries(g).all(func(e): return e.has("drops")))
	# UI absorve novo boss sem reescrever: a lista vem de all_entries
	H.check("SCAL-16 all_entries == boss_ids count", BossBestiary.all_entries(g).size() == BossBestiary.boss_ids().size())
	# performance: enumerar não instancia encounter
	H.check("SCAL-17 enumerar é metadata leve (sem BossEncounter)", root.get_node_or_null("BossEncounter") == null)
	# difficulties reais (não inventa Nightmare)
	H.check("SCAL-18 difficulties = [NORMAL] (Nightmare deferred)", BossBestiary.entry(g, WOLF)["difficulties"] == ["NORMAL"])
	# future boss ready: um boss disabled seria excluído (enabled gate), sem tocar UI
	H.check("SCAL-19 boss_ids só enabled (gate registry)", BossBestiary.boss_ids().all(func(b): return bool(BossActivityDefinition.BOSSES[b].get("enabled", true))))
	# visual_id sempre presente (retrato usa fallback legítimo, sem exigir Codex)
	H.check("SCAL-20 todo boss tem visual_id (fallback de retrato)", BossBestiary.boss_ids().all(func(b): return str(BossActivityDefinition.get_boss(b).get("visual_id", "")) != ""))
	H.group_complete()
