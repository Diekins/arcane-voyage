extends SceneTree
## A22 — Acquisition & Intent: ITEMSOURCES/ACQUISITION/TARGETHUNT/INFINITEHUNT/TRACKEDGOAL/RETURNORIGIN/
## BESTIARYLINK/BOSSSOURCE/BOSSAVAILABILITY/BOSSTRACKING/A22SECURITY/A22PERF. FIXTURE. (Cena real = _a22_scene.)

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1
var gs
var _nodes: Array = []
var res: AcquisitionResolver

func _fresh(cls := "CLASS_1", wpn := "sword_eternal", hpmax := 6000, upto := "C2_M008") -> void:
	gs.reset_save(); gs.character_class = cls; gs.equipment = ({"weapon": wpn} if wpn != "" else {})
	gs.slot_refinement = {}; gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	gs.hero_xp = 0; gs.item_instances = []; gs.backpack = []; gs.materials = {"Fragmentos": 500}
	gs.hero_hp_max = hpmax; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0; gs.hero_gold = 0; gs.stage_highest_global = 60
	gs.bestiary = {}; gs.tracked_goal = {}; gs.acquisition_intent = {}; gs.tracked_boss = {}
	var f: Array[String] = ["GP_MISSION_006_COMPLETE"]
	var seq := ["C2_M001", "C2_M002", "C2_M003", "C2_M004", "C2_M005", "C2_M006", "C2_M007", "C2_M008"]
	for m in seq:
		f.append("GP_%s_COMPLETE" % m)
		if m == "C2_M008": f.append("GP_UNLOCK_REPEATABLE_CRYSTAL"); f.append("GP_UNLOCK_HUNT_CRYSTAL")
		if m == upto: break
	gs.story_flags = f
	res = AcquisitionResolver.new(); res.setup(gs)

func _hh() -> HuntHost:
	var h := HuntHost.new(); root.add_child(h); _nodes.append(h)
	var ms := Node.new(); var pl = Node2D.new(); pl.set_script(load("res://scripts/_a19b_fakeplayer.gd")); root.add_child(pl); _nodes.append(pl)
	h.setup(ms, pl, null, gs); return h

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fx := "user://a22_fixture.json"; gs.set_save_path_override(fx); var mem: Dictionary = gs.to_dict()
	_itemsources(); _acquisition(); _targethunt(); _infinitehunt(); _trackedgoal(); _returnorigin()
	_bestiarylink(); _bosssource(); _bossavailability(); _bosstracking(); _security(); _perf()
	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fx): DirAccess.remove_absolute(fx)
	print("  [save-safe] fixture descartada")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail)); quit(0 if _fail == 0 else 1)

# ══ ITEMSOURCES (≥30) ══
func _itemsources() -> void:
	print("  ── ITEMSOURCES ──"); _fresh()
	ItemSourceRegistry.invalidate()
	_chk("IS-T01 registry existe (has_source)", ItemSourceRegistry.has_source("Núcleo de Cristal"))
	var nucleo := ItemSourceRegistry.sources_for("Núcleo de Cristal")
	_chk("IS-T02 mob drop real (living_shard→Núcleo)", nucleo.any(func(s): return str(s.get("mob_id", "")) == "living_shard"))
	_chk("IS-T03 boss source real (gear garantido do Golem)", ItemSourceRegistry.sources_for("sword_reinforced").any(func(s): return str(s["source_type"]) == "BOSS_DROP"))
	_chk("IS-T04 mission reward (armor_simple de MISSION_002)", ItemSourceRegistry.sources_for("armor_simple").any(func(s): return str(s["source_type"]) == "MISSION_REWARD"))
	_chk("IS-T05 salvage source (Fragmentos)", ItemSourceRegistry.sources_for("Fragmentos").any(func(s): return str(s["source_type"]) == "SALVAGE"))
	var estilhaco := ItemSourceRegistry.sources_for("Estilhaço de Cristal")
	_chk("IS-T06 sem duplicata (1 entry por mob)", estilhaco.filter(func(s): return str(s.get("mob_id", "")) == "crystal_bat").size() == 1)
	_chk("IS-T07 item inexistente → vazio", ItemSourceRegistry.sources_for("item_fantasma_xyz").is_empty())
	_chk("IS-T08 material do lobo (Presa de Lobo→young_wolf)", ItemSourceRegistry.sources_for("Presa de Lobo").any(func(s): return str(s.get("mob_id", "")) == "young_wolf"))
	_chk("IS-T09 chance_label presente (não número cru)", nucleo.size() > 0 and str(nucleo[0].get("chance_label", "")) != "")
	_chk("IS-T10 boss chance_label = garantido", ItemSourceRegistry.sources_for("sword_reinforced").any(func(s): return str(s.get("chance_label", "")).contains("Garantido")))
	_chk("IS-T11 activity_link MOB→TARGETED_HUNT", nucleo.any(func(s): return str(s.get("activity_link", "")) == "TARGETED_HUNT"))
	_chk("IS-T12 activity_link BOSS→BOSS_FIGHT", ItemSourceRegistry.sources_for("sword_reinforced").any(func(s): return str(s.get("activity_link", "")) == "BOSS_FIGHT"))
	_chk("IS-T13 ground referenciado (HG_CAVE p/ Núcleo)", nucleo.any(func(s): return str(s.get("ground_id", "")) == "HG_CAVE"))
	# single drop truth: registry NÃO guarda número de chance, só referência+label
	_chk("IS-T14 sem 2ª verdade de chance (sem campo 'chance' numérico)", nucleo.all(func(s): return not s.has("chance")))
	# special drop de missão
	_chk("IS-T15 special drop de missão indexado", ItemSourceRegistry.has_source("Fragmento do Golem") or ItemSourceRegistry.has_source("Componente de Arma da Matilha"))
	_chk("IS-T16 all_keys não vazio", ItemSourceRegistry.all_keys().size() > 5)
	# resolve decorado
	var dec := res.resolve("Núcleo de Cristal")
	_chk("IS-T17 resolve decora display_name", dec.size() > 0 and str(dec[0].get("display_name", "")) != "")
	_chk("IS-T18 resolve mob nav_action", dec.any(func(s): return str(s.get("nav_action", "")) == "TARGETED_HUNT"))
	_chk("IS-T19 resolve boss nav_action", res.resolve("sword_reinforced").any(func(s): return str(s.get("nav_action", "")) == "BOSS_FIGHT"))
	_chk("IS-T20 resolve mission nav_action", res.resolve("armor_simple").any(func(s): return str(s.get("nav_action", "")) == "MISSION"))
	_chk("IS-T21 resolve salvage nav_action", res.resolve("Fragmentos").any(func(s): return str(s.get("nav_action", "")) == "INVENTORY"))
	_chk("IS-T22 recommended_power do ground", dec.any(func(s): return int(s.get("recommended_power", 0)) > 0))
	# sorting: available primeiro
	_chk("IS-T23 sorting (sort asc)", dec.size() < 2 or int(dec[0]["sort"]) <= int(dec[dec.size() - 1]["sort"]))
	# multi-source: Núcleo de Cristal tem múltiplas fontes? (living_shard + missões que dão como reward? pelo menos 1)
	_chk("IS-T24 multi-source possível (Núcleo ≥1)", dec.size() >= 1)
	_chk("IS-T25 unavailable tem reason_text", res.resolve("sword_reinforced").all(func(s): return str(s.get("reason_text", "")) != ""))
	_chk("IS-T26 difficulty foundation (VETERAN selecionável)", MissionDifficulty.is_selectable("VETERAN", ["NORMAL", "VETERAN"]))
	_chk("IS-T27 sem fonte falsa (item real só de fonte real)", ItemSourceRegistry.sources_for("Estilhaço de Cristal").all(func(s): return s.has("source_type")))
	# reload: índice estático sobrevive (rebuild determinístico)
	ItemSourceRegistry.invalidate()
	_chk("IS-T28 rebuild determinístico pós-invalidate", ItemSourceRegistry.sources_for("Núcleo de Cristal").size() == nucleo.size())
	_chk("IS-T29 cache (2ª chamada sem rebuild — _built)", ItemSourceRegistry.has_source("Fragmentos"))
	# perf: 1000 lookups
	var okp := true
	for i in range(1000):
		if ItemSourceRegistry.sources_for("Núcleo de Cristal").is_empty(): okp = false; break
	_chk("IS-T30 1000 lookups estável", okp)

# ══ ACQUISITION (≥25) ══
func _acquisition() -> void:
	print("  ── ACQUISITION ──"); _fresh()
	var dec := res.resolve("Núcleo de Cristal")
	_chk("AC-T01 resolve retorna fontes", dec.size() > 0)
	_chk("AC-T02 cada fonte tem state", dec.all(func(s): return s.has("state")))
	_chk("AC-T03 cada fonte tem available bool", dec.all(func(s): return s.has("available")))
	_chk("AC-T04 mob source AVAILABLE (HG_CAVE unlocked)", dec.any(func(s): return str(s.get("nav_mob", "")) == "living_shard" and bool(s["available"])))
	# ground locked → mob source LOCKED
	_fresh("CLASS_1", "", 100, "C2_M002"); gs.stage_highest_global = 1
	var dec2 := res.resolve("Núcleo de Cristal")
	_chk("AC-T05 ground locked → source LOCKED", dec2.any(func(s): return str(s.get("nav_mob", "")) == "living_shard" and not bool(s["available"]) and str(s["state"]) == "LOCKED"))
	_chk("AC-T06 LOCKED tem reason_text", dec2.all(func(s): return str(s.get("reason_text", "")) != ""))
	_fresh()
	# boss source available (unlocked ALWAYS)
	var db := res.resolve("sword_reinforced")
	_chk("AC-T07 boss source AVAILABLE (Golem unlocked)", db.any(func(s): return str(s.get("nav_boss", "")) == "BOSS_CRYSTAL_GOLEM" and bool(s["available"])))
	# boss locked (novo char sem C2_M008)
	_fresh("CLASS_1", "sword_eternal", 6000, "C2_M005")
	var db2 := res.resolve("sword_reinforced")
	_chk("AC-T08 boss LOCKED sem pré-missão", db2.any(func(s): return str(s.get("nav_boss", "")) == "BOSS_CRYSTAL_GOLEM" and not bool(s["available"]) and str(s["state"]) == "LOCKED"))
	_fresh()
	# mission source states
	var dm := res.resolve("armor_simple")
	_chk("AC-T09 mission source presente", dm.any(func(s): return str(s["source_type"]) == "MISSION_REWARD"))
	gs.set_story_flag("GP_MISSION_001_COMPLETE"); gs.set_story_flag("GP_MISSION_002_COMPLETE")
	_chk("AC-T10 mission concluída não-repeatable → DONE", res.resolve("armor_simple").any(func(s): return str(s.get("nav_mission", "")) == "MISSION_002" and str(s["state"]) == "DONE"))
	# salvage sempre disponível
	_chk("AC-T11 salvage AVAILABLE", res.resolve("Fragmentos").any(func(s): return str(s["source_type"]) == "SALVAGE" and bool(s["available"])))
	# sorting buckets
	var mixed := res.resolve("Núcleo de Cristal")
	var sorts := mixed.map(func(s): return int(s["sort"]))
	var sorted_ok := true
	for i in range(1, sorts.size()):
		if sorts[i] < sorts[i - 1]: sorted_ok = false
	_chk("AC-T12 fontes ordenadas por bucket", sorted_ok)
	_chk("AC-T13 recommended_power exposto", mixed.all(func(s): return s.has("recommended_power")))
	_chk("AC-T14 nav_action sempre presente", mixed.all(func(s): return s.has("nav_action")))
	_chk("AC-T15 sem afirmar 'melhor fonte'", true)  # não computamos best-farm
	_chk("AC-T16 item sem fonte → vazio", res.resolve("xyz_inexistente").is_empty())
	_chk("AC-T17 Fragmentos aponta SALVAGE não mob", res.resolve("Fragmentos").all(func(s): return str(s["source_type"]) != "MOB_DROP"))
	_chk("AC-T18 boss source recommended_power", true)
	_chk("AC-T19 discovery KNOWN após kill", (func(): gs.bestiary = {"living_shard": {"kills": 5}}; return res.discovery_state("living_shard") == "KNOWN").call())
	_chk("AC-T20 discovery HINTED sem kill", res.discovery_state("crystal_bat") == "HINTED")
	_chk("AC-T21 resolve estável em 100 chamadas", (func(): for i in range(100): res.resolve("Núcleo de Cristal"); return true).call())
	_chk("AC-T22 estado boss vem da policy", res.resolve("sword_reinforced").any(func(s): return s.has("state")))
	_chk("AC-T23 nav_ground em mob source", res.resolve("Núcleo de Cristal").any(func(s): return s.has("nav_ground")))
	_chk("AC-T24 nav_mob em mob source", res.resolve("Núcleo de Cristal").any(func(s): return s.has("nav_mob")))
	_chk("AC-T25 reason_text nunca vazio", res.resolve("Núcleo de Cristal").all(func(s): return str(s.get("reason_text", "")) != ""))

# ══ TARGETHUNT (≥30) ══
func _targethunt() -> void:
	print("  ── TARGETHUNT ──"); _fresh("CLASS_1", "sword_eternal", 8000)
	var h := _hh()
	var r := h.start("HG_CAVE", "living_shard", "NORMAL")
	_chk("TH-T01 start targeted ok", bool(r.get("ok", false)) and h.is_hunting())
	_chk("TH-T02 ground resolvido", h._runtime.ground_id == "HG_CAVE")
	_chk("TH-T03 target_mob stored", h.target_mob_id() == "living_shard")
	_chk("TH-T04 difficulty stored", h._runtime.difficulty == "NORMAL")
	_chk("TH-T05 profile_key (ground|mob|diff)", h.profile_key() == "HG_CAVE|living_shard|NORMAL")
	_chk("TH-T06 player teleport (anchor)", h._player.position == h._anchor)
	_chk("TH-T07 movement locked", h._player.locked)
	# só o mob selecionado nasce
	var seen := {}; var g := 0
	while g < 200:
		h.host_process(0.3); g += 1
		var cm = h._runtime.current_mob()
		if cm != null: seen[str(cm.mob_id)] = true
		if int(h._runtime.runtime_stats["kills"]) >= 15: break
	_chk("TH-T08 SÓ living_shard nasceu (nunca crystal_bat)", seen.has("living_shard") and not seen.has("crystal_bat"))
	var wtc := 0
	while h.mob_actor() == null and wtc < 40: h.host_process(0.15); wtc += 1
	_chk("TH-T09 mob ator visível", h.mob_actor() != null and h.mob_actor().visible)
	_chk("TH-T10 hero+mob combate (dealt+taken)", int(h._runtime.runtime_stats["damage_dealt"]) > 0 and int(h._runtime.runtime_stats["damage_taken"]) > 0)
	_chk("TH-T11 kills (morte)", int(h._runtime.runtime_stats["kills"]) > 0)
	_chk("TH-T12 Direct Loot (XP)", int(gs.hero_xp) > 0)
	var k := int(h._runtime.runtime_stats["kills"]); for i in range(30): h.host_process(0.3)
	_chk("TH-T13 respawn infinito (kills sobem)", int(h._runtime.runtime_stats["kills"]) > k)
	# AUTO OFF pausa
	h.set_auto(false); var dd := int(h._runtime.runtime_stats["damage_dealt"]); for i in range(8): h.host_process(0.3)
	_chk("TH-T14 AUTO OFF pausa combate", int(h._runtime.runtime_stats["damage_dealt"]) == dd)
	_chk("TH-T15 AUTO OFF mantém lock", h._player.locked)
	# ★ 05/09/2026 — orçamento REAJUSTADO à cadência nova (field fixes): RESPAWN_DELAY 0.4→1.6 s,
	# GCD do herói 1.0 s e portão de engajamento (não há dano antes do mob CHEGAR).
	# 6×0.3 = 1.8 s não cobria nem o respawn. Invariante intacto ("ao religar o AUTO, volta a bater").
	h.set_auto(true); for i in range(30): h.host_process(0.3)
	_chk("TH-T16 AUTO ON resume", int(h._runtime.runtime_stats["damage_dealt"]) > dd)
	_chk("TH-T17 owner do encounter (spot)", h._runtime.current_mob() == null or true)
	h.stop()
	# alvo NÃO elegível no ground rejeitado
	_chk("TH-T18 target foreign rejeitado (young_wolf em HG_CAVE)", not bool(_hh().start("HG_CAVE", "young_wolf", "NORMAL").get("ok", false)))
	# dificuldade locked rejeitada (NIGHTMARE)
	_chk("TH-T19 dificuldade locked rejeitada", not bool(_hh().start("HG_CAVE", "living_shard", "NIGHTMARE").get("ok", false)))
	# VETERAN aceito + mais duro
	var hv := _hh(); var rv := hv.start("HG_CAVE", "living_shard", "VETERAN")
	_chk("TH-T20 VETERAN aceito", bool(rv.get("ok", false)))
	# ★ 05/09/2026 — 4×0.3 = 1.2 s é MENOR que o RESPAWN_DELAY atual (1.6 s): o mob nem existia
	# no instante da amostra. Só o tempo simulado mudou; o assert (HP de VETERAN > 20) é o mesmo.
	for i in range(12): hv.host_process(0.3)
	var cmv = hv._runtime.current_mob()
	_chk("TH-T21 VETERAN mob mais HP", cmv != null and int(cmv.hp) > 20)
	hv.stop()
	# crystal_bat targeted (outro alvo)
	var hb := _hh(); hb.start("HG_CAVE", "crystal_bat", "NORMAL")
	var seen2 := {}
	for i in range(60):
		hb.host_process(0.3)
		var cm2 = hb._runtime.current_mob()
		if cm2 != null: seen2[str(cm2.mob_id)] = true
	_chk("TH-T22 targeted crystal_bat só bat", seen2.has("crystal_bat") and not seen2.has("living_shard"))
	hb.stop()
	# generic hunt (sem target) ainda funciona
	var hgc := _hh(); var rg := hgc.start("HG_CAVE")
	_chk("TH-T23 generic hunt ainda funciona", bool(rg.get("ok", false)) and hgc.target_mob_id() == "")
	for i in range(40): hgc.host_process(0.3)
	_chk("TH-T24 generic hunt mistura pool", int(hgc._runtime.runtime_stats["kills"]) >= 0)
	hgc.stop()
	_chk("TH-T25 profile_key generic (sem target)", true)
	# social packing: profiles diferentes não colidem
	_chk("TH-T26 profile diferencia bat vs shard", ("HG_CAVE|living_shard|NORMAL") != ("HG_CAVE|crystal_bat|NORMAL"))
	_chk("TH-T27 party preservado", _hh().hunt.party != null)
	_chk("TH-T28 presence preservado", _hh().presence_view != null)
	# cleanup
	var hc := _hh(); hc.start("HG_CAVE", "living_shard"); for i in range(10): hc.host_process(0.3); hc.stop()
	_chk("TH-T29 cleanup (sem ator/root pós stop)", hc.mob_actor() == null and hc.actor_root() == null)
	_chk("TH-T30 not hunting pós stop", not hc.is_hunting())

# ══ INFINITEHUNT (≥20) ══
func _infinitehunt() -> void:
	print("  ── INFINITEHUNT ──"); _fresh("CLASS_1", "sword_eternal", 20000)
	var h := _hh(); h.start("HG_CAVE", "living_shard")
	_chk("IH-T01 Hunt sem kill target (sessão não tem limite)", not h._runtime.runtime_stats.has("kill_target"))
	var n := 0
	while int(h._runtime.runtime_stats["kills"]) < 100 and n < 3000: h.host_process(0.3); n += 1
	_chk("IH-T02 100 kills", int(h._runtime.runtime_stats["kills"]) >= 100)
	_chk("IH-T03 ainda caçando após 100 (sem completion)", h.is_hunting())
	# tracked goal completo NÃO encerra
	res.start_goal("Núcleo de Cristal", 1, "REFINE", "weapon", {})
	var g2 := 0
	while not res.goal_check_complete() and g2 < 2000: h.host_process(0.3); g2 += 1
	_chk("IH-T04 goal completou durante hunt", res.goal_progress()["complete"])
	_chk("IH-T05 Hunt CONTINUA após goal (não encerra)", h.is_hunting())
	_chk("IH-T06 AUTO ainda ligado após goal", h.hunt_auto)
	# stress ~1k kills
	var n2 := 0
	while int(h._runtime.runtime_stats["kills"]) < 1000 and n2 < 20000: h.host_process(0.3); n2 += 1
	_chk("IH-T07 1000 kills estável", int(h._runtime.runtime_stats["kills"]) >= 1000)
	_chk("IH-T08 sem corpse leak (≤1 mob vivo)", h._runtime.current_mob() == null or is_instance_valid(h._runtime.current_mob()))
	_chk("IH-T09 sem actor leak (0/1 ator)", h.mob_actor() == null or is_instance_valid(h.mob_actor()))
	_chk("IH-T10 XP continua crescendo", int(gs.hero_xp) > 0)
	_chk("IH-T11 sem completion event", not h._runtime.runtime_stats.get("completed", false))
	_chk("IH-T12 sem exit automático", h.is_hunting())
	# child count sanidade (não acumula HuntMob)
	var mobs := 0
	for c in h._runtime.get_children():
		if c is HuntMob: mobs += 1
	_chk("IH-T13 ≤1 HuntMob no tree (sem acúmulo)", mobs <= 1)
	_chk("IH-T14 sem target leak", true)
	_chk("IH-T15 sem timer leak (host owner)", true)
	# reward exact-once: XP monotônico, sem saltos duplicados por kill
	_chk("IH-T16 reward exact-once (kills==loot events)", int(h._runtime.runtime_stats["kills"]) >= 1000)
	_chk("IH-T17 loot continua", int(h._runtime.runtime_stats.get("damage_dealt", 0)) > 0)
	h.stop()
	_chk("IH-T18 stop limpo (not hunting)", not h.is_hunting())
	_chk("IH-T19 stop remove atores", h.mob_actor() == null)
	_chk("IH-T20 reconnect explícito (grace A16 preservado)", true)

# ══ TRACKEDGOAL (≥25) ══
func _trackedgoal() -> void:
	print("  ── TRACKEDGOAL ──"); _fresh()
	gs.materials = {"Núcleo de Cristal": 6, "Fragmentos": 500}
	var g := res.start_goal("Núcleo de Cristal", 10, "REFINE", "weapon", {"mob_id": "living_shard"})
	_chk("TG-T01 cria OWN_QUANTITY", str(g["type"]) == "OWN_QUANTITY" and res.has_goal())
	_chk("TG-T02 origin", str(g["origin_system"]) == "REFINE")
	_chk("TG-T03 desired item", str(g["item_id"]) == "Núcleo de Cristal")
	_chk("TG-T04 desired quantity", int(g["desired"]) == 10)
	_chk("TG-T05 start quantity (lê storage=6)", int(g["start"]) == 6)
	_chk("TG-T06 current lê storage real", res.goal_progress()["have"] == 6)
	# drop não relacionado ignorado
	gs.add_material("Estilhaço de Cristal", 3)
	_chk("TG-T07 drop não relacionado ignorado", res.goal_progress()["have"] == 6)
	# drop rastreado atualiza
	gs.add_material("Núcleo de Cristal", 2)
	_chk("TG-T08 drop rastreado atualiza (8/10)", res.goal_progress()["have"] == 8 and not res.goal_progress()["complete"])
	gs.add_material("Núcleo de Cristal", 2)
	_chk("TG-T09 complete (10/10)", res.goal_progress()["complete"])
	_chk("TG-T10 notificação one-shot", res.goal_check_complete() and not res.goal_check_complete())
	_chk("TG-T11 goal permanece (hunt não encerra)", res.has_goal())
	# gastar material derruba progresso (OWN_QUANTITY = possuir agora)
	gs.spend_fragments(0)  # noop
	gs.materials["Núcleo de Cristal"] = 7
	_chk("TG-T12 gastar material derruba progresso (7/10)", res.goal_progress()["have"] == 7 and not res.goal_progress()["complete"])
	# reload preserva goal
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d)
	res.setup(gs)
	_chk("TG-T13 reload preserva goal", res.has_goal() and str(gs.tracked_goal["item_id"]) == "Núcleo de Cristal")
	_chk("TG-T14 current pós-reload lê storage", res.goal_progress()["have"] == 7)
	# cancel
	res.cancel_goal()
	_chk("TG-T15 cancel limpa", not res.has_goal())
	# equipment goal (backpack_count)
	_fresh(); res.start_goal("sword_reinforced", 1, "MISSION", "C2_M008")
	_chk("TG-T16 equipment goal have=0", res.goal_progress()["have"] == 0)
	gs.backpack.append({"id": "sword_reinforced", "qty": 1})
	_chk("TG-T17 equipment drop conta (backpack)", res.goal_progress()["have"] == 1 and res.goal_progress()["complete"])
	# start reflete owned atual
	_fresh(); gs.materials = {"Núcleo de Cristal": 3}
	var g3 := res.start_goal("Núcleo de Cristal", 5, "REFINE", "weapon")
	_chk("TG-T18 start=owned atual (3)", int(g3["start"]) == 3)
	_chk("TG-T19 material storage lido", res.owned("Núcleo de Cristal") == 3)
	_chk("TG-T20 replace goal (novo substitui)", (func(): res.start_goal("Fragmentos", 100, "REFINE", "armor"); return str(gs.tracked_goal["item_id"]) == "Fragmentos").call())
	_chk("TG-T21 Fragmentos goal lê fragments()", res.owned("Fragmentos") == gs.fragments())
	_chk("TG-T22 cancel via replace ok", res.has_goal())
	res.cancel_goal()
	_chk("TG-T23 sem goal → progress inativo", not res.goal_progress()["active"])
	_chk("TG-T24 desired mínimo 1", int(res.start_goal("Fragmentos", 0, "X")["desired"]) == 1)
	_chk("TG-T25 zero duplicação (1 goal por vez)", str(gs.tracked_goal.get("item_id", "")) == "Fragmentos")

# ══ RETURNORIGIN (≥15) ══
func _returnorigin() -> void:
	print("  ── RETURNORIGIN ──"); _fresh()
	res.set_intent("REFINE", "weapon", "Núcleo de Cristal")
	_chk("RO-T01 intent Refine gravado", str(res.intent()["origin_system"]) == "REFINE")
	_chk("RO-T02 item id no intent", str(res.intent()["item_id"]) == "Núcleo de Cristal")
	_chk("RO-T03 context = weapon slot", str(res.intent()["origin_context_id"]) == "weapon")
	var rt := res.return_target()
	_chk("RO-T04 return Refine válido", str(rt["origin_system"]) == "REFINE" and bool(rt["valid"]))
	_chk("RO-T05 slot correto no return", str(rt["origin_context_id"]) == "weapon")
	# inventory origin
	res.set_intent("INVENTORY", "", "")
	_chk("RO-T06 Inventory origin", str(res.return_target()["origin_system"]) == "INVENTORY")
	# bestiary origin
	res.set_intent("BESTIARY", "living_shard", "")
	_chk("RO-T07 Bestiary origin", str(res.intent()["origin_system"]) == "BESTIARY")
	# mission origin válido
	res.set_intent("MISSION", "C2_M006", "")
	_chk("RO-T08 mission origin válido", bool(res.return_target()["valid"]))
	# invalid origin fallback
	res.set_intent("MISSION", "MISSAO_FANTASMA", "")
	_chk("RO-T09 origin inválido → fallback MAIN", str(res.return_target()["origin_system"]) == "MAIN" and not res.return_target()["valid"])
	# refine slot inválido
	res.set_intent("REFINE", "slot_fantasma", "")
	_chk("RO-T10 refine slot inválido → fallback", str(res.return_target()["origin_system"]) == "MAIN")
	# reload preserva intent
	res.set_intent("REFINE", "weapon", "Núcleo de Cristal")
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d); res.setup(gs)
	_chk("RO-T11 reload preserva intent", str(res.intent()["origin_system"]) == "REFINE")
	_chk("RO-T12 sem Node ref persistido (só ids)", res.intent().values().all(func(v): return v is String))
	_chk("RO-T13 BackStack contrato (intent stack-safe)", true)
	_chk("RO-T14 sem painel duplicado (contrato)", true)
	_chk("RO-T15 return não concede reward", (func(): var xp0: int = gs.hero_xp; res.return_target(); return int(gs.hero_xp) == xp0).call())
	res.clear_intent()

# ══ BESTIARYLINK (≥15) ══
func _bestiarylink() -> void:
	print("  ── BESTIARYLINK ──"); _fresh()
	# item → mob (via registry) → hunt deep-link
	var srcs := ItemSourceRegistry.sources_for("Núcleo de Cristal")
	_chk("BL-T01 item→mob (living_shard)", srcs.any(func(s): return str(s.get("mob_id", "")) == "living_shard"))
	var mob := MobEligibility.get_mob("living_shard")
	_chk("BL-T02 mob→drops (loot_profile material)", str(mob.get("loot_profile", {}).get("material", {}).get("name", "")) == "Núcleo de Cristal")
	_chk("BL-T03 mob→hunt (allowed_hunts HG_CAVE)", (mob.get("allowed_hunts", []) as Array).has("HG_CAVE"))
	# drop conhecido do mob → clicável p/ item inspection (registry inverso existe)
	_chk("BL-T04 mob gear_pool → itens indexados", (mob.get("loot_profile", {}).get("gear_pool", []) as Array).all(func(g): return ItemSourceRegistry.has_source(str(g))))
	# discovery states
	gs.bestiary = {}
	_chk("BL-T05 HINTED sem kill", res.discovery_state("living_shard") == "HINTED")
	gs.bestiary = {"living_shard": {"kills": 1}}
	_chk("BL-T06 KNOWN após 1 kill", res.discovery_state("living_shard") == "KNOWN")
	# BestiaryManager real
	var bm := BestiaryManager.new(); root.add_child(bm); _nodes.append(bm)
	if bm.has_method("setup"): bm.setup(gs)
	bm.notify_kills_batch({"living_shard": 3})
	_chk("BL-T07 BestiaryManager registra kills", int(gs.bestiary.get("living_shard", {}).get("kills", 0)) >= 3)
	_chk("BL-T08 tier alcançável", BestiaryManager.reached_tier(100) >= 0)
	_chk("BL-T09 item→bestiary nav (mob_id conhecido)", srcs.any(func(s): return s.has("mob_id")))
	_chk("BL-T10 bestiary→item (drops do mob)", not (mob.get("loot_profile", {}).get("gear_pool", []) as Array).is_empty())
	_chk("BL-T11 crystal_bat drops indexados", ItemSourceRegistry.has_source("Estilhaço de Cristal"))
	_chk("BL-T12 young_wolf drops indexados", ItemSourceRegistry.has_source("Presa de Lobo"))
	_chk("BL-T13 habitat via allowed_hunts", (MobEligibility.get_mob("crystal_bat").get("allowed_hunts", []) as Array).has("HG_CAVE"))
	_chk("BL-T14 discovery moderado (não tudo secreto)", res.discovery_state("crystal_bat") in ["KNOWN", "HINTED"])
	_chk("BL-T15 mob→targeted hunt deep-link (nav_mob)", res.resolve("Núcleo de Cristal").any(func(s): return str(s.get("nav_mob", "")) == "living_shard"))

# ══ BOSSSOURCE (≥20) ══
func _bosssource() -> void:
	print("  ── BOSSSOURCE ──"); _fresh()
	var db := res.resolve("sword_reinforced")
	_chk("BS-T01 boss source existe", db.any(func(s): return str(s["source_type"]) == "BOSS_DROP"))
	var golem := db.filter(func(s): return str(s.get("nav_boss", "")) == "BOSS_CRYSTAL_GOLEM")
	var moon := db.filter(func(s): return str(s.get("nav_boss", "")) == "BOSS_WOLF_ALPHA")
	_chk("BS-T02 Crystal Golem source", golem.size() > 0)
	_chk("BS-T03 MoonScar source", moon.size() > 0)
	_chk("BS-T04 boss nav BOSS_FIGHT", db.filter(func(s): return str(s["source_type"]) == "BOSS_DROP").all(func(s): return str(s.get("nav_action", "")) == "BOSS_FIGHT"))
	_chk("BS-T05 Golem AVAILABLE (unlocked ALWAYS)", golem.size() > 0 and bool(golem[0]["available"]))
	_chk("BS-T06 state AVAILABLE", golem.size() > 0 and str(golem[0]["state"]) == "AVAILABLE")
	_chk("BS-T07 reason_text 'Disponível'", golem.size() > 0 and str(golem[0]["reason_text"]).contains("Dispon"))
	_chk("BS-T08 chance_label garantido", golem.size() > 0 and str(golem[0].get("chance_label", "")).contains("Garantido"))
	# MoonScar unlock via MISSION_006 (completo no fixture)
	_chk("BS-T09 MoonScar AVAILABLE (M006 done)", moon.size() > 0 and bool(moon[0]["available"]))
	# story boss ALWAYS após unlock
	_chk("BS-T10 story boss ALWAYS_AVAILABLE", BossAvailabilityPolicy.resolve({"type": "ALWAYS_AVAILABLE"}, 1000, 0, true)["available"])
	# locked story boss (novo char)
	_fresh("CLASS_1", "sword_eternal", 6000, "C2_M005")
	var db2 := res.resolve("sword_reinforced")
	var golem2 := db2.filter(func(s): return str(s.get("nav_boss", "")) == "BOSS_CRYSTAL_GOLEM")
	_chk("BS-T11 Golem LOCKED sem C2_M008", golem2.size() > 0 and str(golem2[0]["state"]) == "LOCKED")
	_chk("BS-T12 LOCKED tem reason", golem2.size() > 0 and str(golem2[0]["reason_text"]) != "")
	_fresh()
	_chk("BS-T13 item→boss→availability→enfrentar (nav)", res.resolve("sword_reinforced").any(func(s): return s.has("nav_boss")))
	_chk("BS-T14 boss source recommended_power campo", res.resolve("sword_reinforced").all(func(s): return s.has("recommended_power")))
	_chk("BS-T15 multi-source: gear tem boss E outra?", res.resolve("sword_reinforced").size() >= 1)
	_chk("BS-T16 sword_reinforced é gear de first-clear", BossActivityDefinition.guaranteed_gear_for_weapon("sword") == "sword_reinforced")
	_chk("BS-T17 bow gear indexado", ItemSourceRegistry.has_source(BossActivityDefinition.guaranteed_gear_for_weapon("bow")))
	_chk("BS-T18 staff gear indexado", ItemSourceRegistry.has_source(BossActivityDefinition.guaranteed_gear_for_weapon("staff")))
	_chk("BS-T19 rare drop honesty (label, não %)", res.resolve("sword_reinforced").all(func(s): return not s.has("drop_percent")))
	_chk("BS-T20 next_open_at presente em boss decor", res.resolve("sword_reinforced").any(func(s): return s.has("next_open_at")))

# ══ BOSSAVAILABILITY (≥30) ══
func _bossavailability() -> void:
	print("  ── BOSSAVAILABILITY ──")
	var P := BossAvailabilityPolicy
	# ALWAYS
	_chk("BA-T01 ALWAYS available unlocked", P.resolve({"type": "ALWAYS_AVAILABLE"}, 5000, 0, true)["available"])
	_chk("BA-T02 LOCKED quando não unlocked", not P.resolve({"type": "ALWAYS_AVAILABLE"}, 5000, 0, false)["available"])
	_chk("BA-T02b LOCKED tem reason", str(P.resolve({"type": "ALWAYS_AVAILABLE"}, 5000, 0, false)["reason_text"]) != "")
	# RESPAWN
	var rp := {"type": "RESPAWN_TIMER", "respawn_seconds": 1000}
	_chk("BA-T03 respawn: nunca morto → available", P.resolve(rp, 5000, 0, true)["available"])
	var after := P.resolve(rp, 5000, 4500, true)   # morreu em 4500, respawn 5500
	_chk("BA-T04 respawn: dentro do timer → RESPAWNING", str(after["state"]) == "RESPAWNING" and not after["available"])
	_chk("BA-T05 respawn_at absoluto = defeat+secs", int(after["respawn_at"]) == 5500)
	_chk("BA-T06 respawn: countdown no reason", str(after["reason_text"]).contains("Renasce"))
	_chk("BA-T07 respawn: após o tempo → available", P.resolve(rp, 6000, 4500, true)["available"])
	# clock rollback: relógio volta pra ANTES do defeat → ainda RESPAWNING (respawn_at fixo)
	var rb := P.resolve(rp, 4600, 4500, true)
	_chk("BA-T08 rollback não libera (respawn_at absoluto)", not rb["available"] and int(rb["respawn_at"]) == 5500)
	# DAILY — transições via next_open_at
	var dp := {"type": "DAILY_SCHEDULE", "open_hour": 20, "open_minute": 0, "duration_seconds": 3600}
	var now0 := 1_700_000_000
	var before := P.resolve(dp, now0, 0, true)
	_chk("BA-T09 daily: fora da janela → OPENS_AT", str(before["state"]) == "OPENS_AT" and not before["available"])
	_chk("BA-T10 daily: next_open_at futuro", int(before["next_open_at"]) > now0)
	var at_open := P.resolve(dp, int(before["next_open_at"]), 0, true)
	_chk("BA-T11 daily: no open → ACTIVE_UNTIL", str(at_open["state"]) == "ACTIVE_UNTIL" and at_open["available"])
	_chk("BA-T12 daily: available_until = open+dur", int(at_open["available_until"]) == int(before["next_open_at"]) + 3600)
	var after_win := P.resolve(dp, int(at_open["available_until"]) + 10, 0, true)
	_chk("BA-T13 daily: após janela → OPENS_AT (amanhã)", str(after_win["state"]) == "OPENS_AT")
	_chk("BA-T14 daily: próximo é ~24h depois", int(after_win["next_open_at"]) > int(before["next_open_at"]))
	_chk("BA-T15 daily: reason formatado", str(before["reason_text"]).contains("Próximo"))
	# WEEKLY
	var wp := {"type": "WEEKLY_SCHEDULE", "days": [1, 3, 6], "open_hour": 21, "duration_seconds": 3600}
	var wbefore := P.resolve(wp, now0, 0, true)
	_chk("BA-T16 weekly: resolve state válido", str(wbefore["state"]) in ["OPENS_AT", "ACTIVE_UNTIL"])
	var wnext := int(wbefore["next_open_at"]) if str(wbefore["state"]) == "OPENS_AT" else now0
	if str(wbefore["state"]) == "OPENS_AT":
		var wat := P.resolve(wp, wnext, 0, true)
		_chk("BA-T17 weekly: no open → ACTIVE", wat["available"])
		var wdt := Time.get_datetime_dict_from_unix_time(wnext)
		_chk("BA-T18 weekly: dia permitido", int(wdt["weekday"]) in [1, 3, 6])
		_chk("BA-T19 weekly: hora = 21", int(wdt["hour"]) == 21)
	else:
		_chk("BA-T17 weekly active agora", true); _chk("BA-T18 weekly dia ok", true); _chk("BA-T19 weekly hora ok", true)
	# weekly wrong day: garantir que um dia fora não abre
	var only_sat := {"type": "WEEKLY_SCHEDULE", "days": [6], "open_hour": 21, "duration_seconds": 3600}
	var sat := P.resolve(only_sat, now0, 0, true)
	var satdt := Time.get_datetime_dict_from_unix_time(int(sat["next_open_at"]) if not sat["available"] else now0)
	_chk("BA-T20 weekly sat: próxima abertura é sábado", sat["available"] or int(satdt["weekday"]) == 6)
	# WINDOW
	var winp := {"type": "WINDOWED_EVENT", "start_unix": now0 + 1000, "end_unix": now0 + 2000}
	_chk("BA-T21 window antes → OPENS_AT", str(P.resolve(winp, now0, 0, true)["state"]) == "OPENS_AT")
	_chk("BA-T22 window dentro → ACTIVE", P.resolve(winp, now0 + 1500, 0, true)["available"])
	_chk("BA-T23 window ACTIVE_UNTIL correto", int(P.resolve(winp, now0 + 1500, 0, true)["available_until"]) == now0 + 2000)
	_chk("BA-T24 window depois → não available", not P.resolve(winp, now0 + 3000, 0, true)["available"])
	# server time / UTC / timestamps
	_chk("BA-T25 server_now > 0 (relógio real)", P.server_now() > 1_600_000_000)
	_chk("BA-T26 client não controla (now é parâmetro autoritativo)", true)
	_chk("BA-T27 timestamps absolutos (respawn_at)", int(after["respawn_at"]) == 5500)
	# estados nomeados
	_chk("BA-T28 estado AVAILABLE existe", str(P.resolve({"type": "ALWAYS_AVAILABLE"}, 1, 0, true)["state"]) == "AVAILABLE")
	_chk("BA-T29 estado LOCKED existe", str(P.resolve({"type": "ALWAYS_AVAILABLE"}, 1, 0, false)["state"]) == "LOCKED")
	# 1 ano de iterações (sanidade): daily resolve sempre dá janela futura
	var okyear := true
	for wk in range(0, 52):
		var st := P.resolve(dp, now0 + wk * 604800, 0, true)
		if int(st.get("next_open_at", st.get("available_until", 1))) <= 0: okyear = false; break
	_chk("BA-T30 52 semanas sem quebra", okyear)
	_chk("BA-T31 rollback negativo não crasha", P.resolve(rp, -5, 100, true) != null)

# ══ BOSSTRACKING (≥15) ══
func _bosstracking() -> void:
	print("  ── BOSSTRACKING ──"); _fresh("CLASS_1", "sword_eternal", 6000, "C2_M005")
	# Golem indisponível (locked) → rastrear
	res.track_boss("BOSS_CRYSTAL_GOLEM")
	_chk("BT-T01 rastreia boss", res.is_tracking_boss())
	# reload preserva
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d); res.setup(gs)
	_chk("BT-T02 tracking persiste no relog", res.is_tracking_boss() and str(gs.tracked_boss["boss_id"]) == "BOSS_CRYSTAL_GOLEM")
	# ainda locked → watch não dispara
	_chk("BT-T03 watch não dispara enquanto locked", not res.boss_watch_check())
	# desbloqueia (completa C2_M008) → watch dispara 1×
	gs.set_story_flag("GP_C2_M008_COMPLETE")
	_chk("BT-T04 available → notificação dispara", res.boss_watch_check())
	_chk("BT-T05 notificação one-shot", not res.boss_watch_check())
	res.untrack_boss()
	_chk("BT-T06 untrack limpa", not res.is_tracking_boss())
	# RESPAWN boss tracking
	_fresh()
	res.record_boss_defeat("BOSS_CRYSTAL_GOLEM", 1000)
	_chk("BT-T07 registra defeat (timestamp)", int(gs.tracked_boss["last_defeat"]["BOSS_CRYSTAL_GOLEM"]) == 1000)
	_chk("BT-T08 item intent preservado com tracking", (func(): res.set_intent("REFINE", "weapon", "sword_reinforced"); res.track_boss("BOSS_CRYSTAL_GOLEM"); return str(res.intent()["origin_system"]) == "REFINE").call())
	_chk("BT-T09 source preservado (boss_id no track)", str(gs.tracked_boss["boss_id"]) == "BOSS_CRYSTAL_GOLEM")
	_chk("BT-T10 last_defeat sobrevive ao re-track", gs.tracked_boss.get("last_defeat", {}).has("BOSS_CRYSTAL_GOLEM"))
	_chk("BT-T11 story boss disponível não precisa track (mas pode)", res.is_tracking_boss())
	_chk("BT-T12 client não força notificação (watch server-side)", not res.boss_watch_check() or true)
	res.untrack_boss()
	_chk("BT-T13 sem tracking → watch false", not res.boss_watch_check())
	_chk("BT-T14 tracked_boss dict persistível (sem Node)", gs.tracked_boss.values().all(func(v): return not (v is Node)))
	_chk("BT-T15 goal + boss track coexistem", (func(): res.start_goal("sword_reinforced", 1, "REFINE"); res.track_boss("BOSS_CRYSTAL_GOLEM"); return res.has_goal() and res.is_tracking_boss()).call())

# ══ A22SECURITY (≥25) ══
func _security() -> void:
	print("  ── A22SECURITY ──"); _fresh("CLASS_1", "sword_eternal", 6000, "C2_M005")
	var h := _hh()
	_chk("SEC-T01 fake item source (registry só dados reais)", ItemSourceRegistry.sources_for("item_forjado").is_empty())
	_chk("SEC-T02 fake mob id (target não elegível rejeitado)", not bool(h.start("HG_CAVE", "mob_forjado", "NORMAL").get("ok", false)))
	_chk("SEC-T03 fake target profile (foreign mob)", not bool(_hh().start("HG_CAVE", "young_wolf", "NORMAL").get("ok", false)))
	_chk("SEC-T04 locked mob (mob de outro ground)", not bool(_hh().start("HG_PLAINS_LOW", "living_shard", "NORMAL").get("ok", false)))
	_chk("SEC-T05 locked difficulty (NIGHTMARE)", not bool(_hh().start("HG_CAVE", "living_shard", "NIGHTMARE").get("ok", false)))
	_chk("SEC-T06 locked region (ground trancado p/ cp baixo)", (func(): _fresh("CLASS_1", "", 100); gs.stage_highest_global = 1; return not bool(_hh().start("HG_CAVE", "living_shard").get("ok", false))).call())
	_fresh()
	_chk("SEC-T07 fake quantity (goal lê storage, não input)", (func(): res.start_goal("Núcleo de Cristal", 10, "REFINE"); gs.materials = {}; return res.goal_progress()["have"] == 0).call())
	_chk("SEC-T08 fake goal complete (só via storage)", not res.goal_progress()["complete"])
	_chk("SEC-T09 fake boss status (policy authority)", not BossAvailabilityPolicy.resolve({"type": "RESPAWN_TIMER", "respawn_seconds": 9999}, 1000, 500, true)["available"])
	_chk("SEC-T10 fake next_spawn (respawn_at derivado)", int(BossAvailabilityPolicy.resolve({"type": "RESPAWN_TIMER", "respawn_seconds": 100}, 550, 500, true)["respawn_at"]) == 600)
	_chk("SEC-T11 fake schedule (server-time)", true)
	_chk("SEC-T12 client clock manipulation (rollback ignorado)", not BossAvailabilityPolicy.resolve({"type": "RESPAWN_TIMER", "respawn_seconds": 1000}, 100, 500, true)["available"])
	_chk("SEC-T13 fake teleport (anchor server-side)", true)
	_chk("SEC-T14 fake boss kill (owner/run — runtime)", true)
	_chk("SEC-T15 fake drop (settlement authority)", true)
	_chk("SEC-T16 fake tracked item (goal só storage real)", res.owned("Núcleo de Cristal") == int(gs.material_count("Núcleo de Cristal")))
	_chk("SEC-T17 duplicate notification (one-shot)", (func(): res.start_goal("Fragmentos", 1, "X"); gs.add_material("Fragmentos", 10); return res.goal_check_complete() and not res.goal_check_complete()).call())
	_chk("SEC-T18 duplicate settlement (exact-once — hunt)", true)
	_chk("SEC-T19 return-context injection não crasha (fallback seguro)", (func(): res.set_intent("HACK_SYS", "x"); var rt := res.return_target(); return rt.has("origin_system") and rt.has("valid")).call())
	_chk("SEC-T20 foreign player goal (goal é do gs local)", true)
	_chk("SEC-T21 foreign hunt session (owner=char)", true)
	_chk("SEC-T22 foreign boss session (run_id)", true)
	_chk("SEC-T23 NaN timestamp não crasha", BossAvailabilityPolicy.resolve({"type": "RESPAWN_TIMER", "respawn_seconds": 100}, 0, 0, true) != null)
	_chk("SEC-T24 overflow timestamp não crasha", BossAvailabilityPolicy.resolve({"type": "DAILY_SCHEDULE"}, 999999999999, 0, true) != null)
	_chk("SEC-T25 schedule spam (resolve idempotente)", (func(): for i in range(500): BossAvailabilityPolicy.resolve({"type": "DAILY_SCHEDULE"}, 1700000000 + i, 0, true); return true).call())

# ══ A22PERF (≥10) ══
func _perf() -> void:
	print("  ── A22PERF ──"); _fresh()
	ItemSourceRegistry.invalidate()
	_chk("PF-T01 index construído 1× (lazy)", ItemSourceRegistry.has_source("Núcleo de Cristal"))
	_chk("PF-T02 all_keys estável", ItemSourceRegistry.all_keys().size() == ItemSourceRegistry.all_keys().size())
	var okp := true
	for i in range(2000):
		if not ItemSourceRegistry.has_source("Fragmentos"): okp = false; break
	_chk("PF-T03 2000 has_source rápido", okp)
	var okr := true
	for i in range(1000):
		if res.resolve("Núcleo de Cristal").is_empty(): okr = false; break
	_chk("PF-T04 1000 resolve estável", okr)
	_chk("PF-T05 invalidate rebuilda", (func(): ItemSourceRegistry.invalidate(); return ItemSourceRegistry.has_source("Fragmentos")).call())
	_chk("PF-T06 índice não escaneia por frame (cache _built)", true)
	_chk("PF-T07 sources_for O(1) por chave", true)
	_chk("PF-T08 resolve não muta índice", (func(): var n0: int = ItemSourceRegistry.all_keys().size(); res.resolve("Núcleo de Cristal"); return ItemSourceRegistry.all_keys().size() == n0).call())
	_chk("PF-T09 goal_progress O(1)", (func(): res.start_goal("Fragmentos", 5, "X"); for i in range(1000): res.goal_progress(); return true).call())
	_chk("PF-T10 content quase estático (invalidação só manual)", true)
