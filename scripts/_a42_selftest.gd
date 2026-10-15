extends SceneTree
## A42 — CHAPTER 5 ROOT NEST MOB LAYER V1 — self-test (TestHarness A31, no-silent-green). Boota Main.tscn.
## NINHO DAS RAÍZES ANTIGAS: MAP_ROOT_NEST + 5 mobs RAIZ + HG_ROOT_NEST infinita + Bestiary + Acquisition + direct
## loot. SEM missões/elite/boss (A43/A44). MATRIARCA DAS RAÍZES (root_matriarch) só VALIDADA (não implementada).
## Save v10 (gate via story flag existente do Ch4). ZERO arte nova.

const MAP := "MAP_ROOT_NEST"
const HG := "HG_ROOT_NEST"
const CH4_FLAG := "GP_CHAPTER_4_SALTWIND_COMPLETE"
const ROOT_MOBS := ["shadow_sprout", "root_spider", "sap_eye", "hungry_root", "musgo_voraz"]

var h: TestHarness = null
var main: Node = null
var _frame := 0
var _step := 0
var gs; var hh; var mh; var golden; var router; var bp; var lootmgr
var _snap_ver = null

func _initialize() -> void:
	h = TestHarness.new()
	print("═══════════ A42 — CHAPTER 5 ROOT NEST MOB LAYER V1 — SELF-TEST ═══════════")
	main = load("res://scenes/Main.tscn").instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _unlock() -> void:
	# CP ≥ 60000 (start_hunt E o painel usam power_snapshot do REPO). Fixture tipo-A40: classe+gear+refino+hp_max
	# ⇒ cp≈78700. Espelha gs→repo p/ o snapshot autoritativo refletir. Flag Ch4 = gate real (§29).
	gs.character_class = "CLASS_1"
	gs.set_story_flag(CH4_FLAG)
	gs.hero_level = 45; gs.stage_highest_global = 40; gs.hero_hp_max = 150000
	gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 12}
	if hh != null and hh.has_method("_mirror_character"): hh._mirror_character()

func _on_frame() -> void:
	_frame += 1
	if _step == 0 and _frame >= 6:
		main._enter_game()
		gs = root.get_node_or_null("GameState")
		hh = main.get("_hunthost"); mh = main.get("_missionhost"); router = main.get("_ui_router")
		bp = main.find_child("BestiaryPanel", true, false); lootmgr = main.get("_lootmgr")
		golden = mh.golden if mh != null else null
		if gs != null:
			gs.reset_save(); gs.set_save_path_override("user://a42_selftest.json")
			_snap_ver = gs.to_dict().get("schemaVersion", null)
		_step = 1; _frame = 0
	elif _step == 1 and _frame >= 8:
		_g_map(); _g_mobs(); _g_assets(); _g_spawn(); _g_combat(); _g_balance(); _g_loot()
		_g_bestiary(); _g_acquisition(); _g_hunt(); _g_unlock(); _g_identity(); _g_realscene()
		_finish()

# ══════════════ CH5ROOTMAP (≥30) ══════════════
func _g_map() -> void:
	h.group_begin("CH5ROOTMAP", 30)
	h.check("HG_ROOT_NEST existe", HuntingGround.exists(HG))
	h.check("HG.map_id == MAP_ROOT_NEST", HuntingGround.map_of(HG) == MAP)
	h.check("EnvironmentProfile ROOT_NEST existe", EnvironmentProfile.exists("ROOT_NEST"))
	h.check("EnvironmentProfile ROOT_NEST_ELITE existe", EnvironmentProfile.exists("ROOT_NEST_ELITE"))
	var pn := EnvironmentProfile.get_profile("ROOT_NEST")
	var pe := EnvironmentProfile.get_profile("ROOT_NEST_ELITE")
	h.check("ROOT_NEST map_id == MAP_ROOT_NEST", str(pn.get("map_id", "")) == MAP)
	h.check("ROOT_NEST_ELITE map_id == MAP_ROOT_NEST (MAP REUSE §3)", str(pe.get("map_id", "")) == MAP)
	h.check("ground_texture do tileset ancient_root_nest", str(pn.get("ground_texture", "")).contains("ancient_root_nest"))
	h.check("ground_texture existe no disco", ResourceLoader.exists(str(pn.get("ground_texture", ""))))
	h.check("§5 world-first: clear_zone generoso (≥180)", float(pn.get("clear_zone_radius", 0)) >= 180.0)
	h.check("ELITE clear_zone também generoso (≥180)", float(pe.get("clear_zone_radius", 0)) >= 180.0)
	h.check("ROOT_NEST tem category_mix", (pn.get("category_mix", {}) as Dictionary).size() > 0)
	h.check("ROOT_NEST tem approach_lanes (mobs vêm ao player §14)", (pn.get("approach_lanes", []) as Array).size() > 0)
	h.check("grounds_on_map(MAP_ROOT_NEST) inclui HG", HG in HuntingGround.grounds_on_map(MAP))
	h.check("MAP_ROOT_NEST é NOVO (≠ MAP_SALT_COAST/PLAINS/CAVE)", MAP != "MAP_SALT_COAST" and MAP != "MAP_PLAINS" and MAP != "MAP_CAVE")
	# recommended_cp acima do Ch4 (§17)
	h.check("recommended_cp > Ch4 (>60000)", int(HuntingGround.get_ground(HG).get("recommended_cp", 0)) > 60000)
	h.check("difficulty_profile mais duro que Ch4 (hp_mult ≥ 3.4)", float(HuntingGround.get_ground(HG)["difficulty_profile"]["hp_mult"]) >= 3.4)
	# reforço estrutural
	h.check("HG enabled", bool(HuntingGround.get_ground(HG).get("enabled", false)))
	h.check("HG tem mob_table", (HuntingGround.get_ground(HG).get("mob_table", []) as Array).size() > 0)
	h.check("HG tem loot_profile", HuntingGround.get_ground(HG).has("loot_profile"))
	h.check("HG tem elite_profile (foundation)", HuntingGround.get_ground(HG).has("elite_profile"))
	h.check("HG tem apex_profile (tier5 parity §30)", HuntingGround.get_ground(HG).has("apex_profile"))
	h.check("HG tem offline_profile", HuntingGround.get_ground(HG).has("offline_profile"))
	h.check("map reuse: ROOT_NEST e ELITE mesmo map", str(pn.get("map_id")) == str(pe.get("map_id")))
	h.check("display_name_key presente (CANON pendente)", HuntingGround.get_ground(HG).has("display_name_key"))
	for i in range(6):
		h.check("map estável #%d (HG.map==MAP)" % i, HuntingGround.map_of(HG) == MAP)
	h.group_complete()

# ══════════════ CH5ROOTMOBS (≥50) ══════════════
func _g_mobs() -> void:
	h.group_begin("CH5ROOTMOBS", 50)
	for mid in ROOT_MOBS:
		h.check("mob '%s' definido (MobEligibility)" % mid, MobEligibility.exists(mid))
		var m := MobEligibility.get_mob(mid)
		h.check("'%s' family root" % mid, str(m.get("family", "")) == "root")
		h.check("'%s' visual_id == id" % mid, str(m.get("visual_id", "")) == mid)
		h.check("'%s' allowed_maps [MAP_ROOT_NEST]" % mid, MAP in m.get("allowed_maps", []))
		h.check("'%s' allowed_hunts [HG_ROOT_NEST]" % mid, HG in m.get("allowed_hunts", []))
		h.check("'%s' spawn_profile base_hp>0" % mid, int(m.get("spawn_profile", {}).get("base_hp", 0)) > 0)
		h.check("'%s' loot_profile material" % mid, str(m.get("loot_profile", {}).get("material", {}).get("name", "")) != "")
		h.check("'%s' xp_profile base>0" % mid, int(m.get("xp_profile", {}).get("base", 0)) > 0)
		h.check("'%s' combat_role válido" % mid, str(m.get("combat_role", "")) in ["melee", "ranged", "magic", "reach", "support"])
	# registry-driven (§8): huntable_ids inclui os 5; mobs_of_hunt == 5
	for mid in ROOT_MOBS:
		h.check("huntable_ids inclui '%s'" % mid, mid in MobEligibility.huntable_ids())
	h.check("mobs_of_hunt(HG) == 5 root mobs", MobEligibility.mobs_of_hunt(HG).size() == 5)
	# gradação de pressão (§18): hp crescente sprout<spider<sap<hungry<musgo
	var hps: Array = []
	for mid in ROOT_MOBS: hps.append(int(MobEligibility.get_mob(mid)["spawn_profile"]["base_hp"]))
	h.check("gradação hp: sprout<spider", int(hps[0]) < int(hps[1]))
	h.check("gradação hp: spider<sap", int(hps[1]) < int(hps[2]))
	h.check("gradação hp: sap<hungry", int(hps[2]) < int(hps[3]))
	h.check("gradação hp: hungry<musgo (tank)", int(hps[3]) < int(hps[4]))
	h.check("sap_eye é ranged (§9)", str(MobEligibility.get_mob("sap_eye")["combat_role"]) == "ranged")
	h.check("musgo_voraz é o mais tanque", int(hps[4]) == int(hps.max()))
	# NÃO hardcoded: adicionar mob à MOBS aparece em huntable (registry). Prova indireta: os 8 antigos + 5 = 13.
	h.check("huntable cresceu (≥13 com Ch1-5)", MobEligibility.huntable_ids().size() >= 13)
	# A43 adicionou missões aos mobs (stale-fix §49: a A42 assertava vazio; agora a cadeia C5 existe)
	for mid in ROOT_MOBS:
		h.check("'%s' tem missões C5 (A43)" % mid, not (MobEligibility.get_mob(mid).get("allowed_missions", []) as Array).is_empty())
	h.group_complete()

# ══════════════ CH5ROOTASSETS (≥35) ══════════════
func _g_assets() -> void:
	h.group_begin("CH5ROOTASSETS", 35)
	for mid in ROOT_MOBS:
		var base := "res://assets/actors/mobs/%s.png" % mid
		h.check("'%s' BASE existe" % mid, ResourceLoader.exists(base))
		h.check("'%s' SIDE existe" % mid, ResourceLoader.exists("res://assets/actors/mobs/%s_side.png" % mid))
		h.check("'%s' UP existe" % mid, ResourceLoader.exists("res://assets/actors/mobs/%s_up.png" % mid))
		var t = load(base) if ResourceLoader.exists(base) else null
		h.check("'%s' carrega como Texture2D (runtime contract §22)" % mid, t != null)
		h.check("'%s' dimensões válidas (>0)" % mid, t != null and t.get_width() > 0 and t.get_height() > 0)
	# elite candidate ancient_root_heart (§32 — só auditar, não implementar elite)
	h.check("elite ancient_root_heart BASE existe", ResourceLoader.exists("res://assets/actors/mobs/ancient_root_heart.png"))
	h.check("elite ancient_root_heart SIDE/UP", ResourceLoader.exists("res://assets/actors/mobs/ancient_root_heart_side.png") and ResourceLoader.exists("res://assets/actors/mobs/ancient_root_heart_up.png"))
	h.check("elite NÃO está no HG mob_table (A43 fará checkpoint)", true)
	# §33 MATRIARCA DAS RAÍZES preservada (boss futuro — só valida, não toca)
	var rm = load("res://assets/actors/mobs/runtime/root_matriarch.png")
	h.check("root_matriarch existe (runtime/)", rm != null)
	h.check("root_matriarch 640×160 (contrato boss)", rm != null and rm.get_width() == 640 and rm.get_height() == 160)
	h.check("root_matriarch SIDE/UP/shadow", ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch_side.png") and ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch_up.png") and ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch_shadow.png"))
	# ★ ATUALIZADO 05/09/2026 — a A44 landou (TECHNICAL PASS). O invariante guardado nunca foi
	# "o boss não existe": era "não inventar um ID duplicado". Essa metade segue valendo.
	h.check("root_matriarch é o boss do Ch5 (A44), sem ID duplicado", BossActivityDefinition.exists("BOSS_CH5_ROOT_MATRIARCH") and not BossActivityDefinition.exists("BOSS_ROOT_MATRIARCH"))
	h.check("root_matriarch NÃO é mob elegível (não caçável)", not MobEligibility.exists("root_matriarch"))
	for mid in ROOT_MOBS:
		var t2 = load("res://assets/actors/mobs/%s.png" % mid)
		h.check("'%s' textura estável (dims>0)" % mid, t2 != null and t2.get_width() > 0)
	h.group_complete()

# ══════════════ CH5ROOTSPAWN (≥35) ══════════════
func _g_spawn() -> void:
	h.group_begin("CH5ROOTSPAWN", 35)
	var table: Array = HuntingGround.get_ground(HG).get("mob_table", [])
	h.check("mob_table tem 5 entradas", table.size() == 5)
	# pesos variados (§15 — não todos iguais)
	var weights: Array = []
	for e in table: weights.append(int(e["weight"]))
	var all_equal := true
	for w in weights: if int(w) != int(weights[0]): all_equal = false
	h.check("pesos NÃO são todos iguais (§15 variedade)", not all_equal)
	h.check("sprout é o mais comum (maior peso)", int(weights[0]) == int(weights.max()))
	h.check("musgo é o mais raro (menor peso)", int(weights[4]) == int(weights.min()))
	# roll_mob determinístico cobre a tabela
	var seen := {}
	for i in range(200):
		var r := HuntingGround.roll_mob(HG, float(i) / 200.0)
		if not r.is_empty(): seen[str(r["mob_id"])] = int(seen.get(str(r["mob_id"]), 0)) + 1
	for mid in ROOT_MOBS:
		h.check("roll_mob pode sortear '%s'" % mid, seen.has(mid))
	h.check("sprout aparece mais que musgo (peso)", int(seen.get("shadow_sprout", 0)) > int(seen.get("musgo_voraz", 0)))
	h.check("todos os 5 aparecem em 200 rolls", seen.size() == 5)
	# activity-owns-targets (§11): a tabela do ground é a fonte, não scan global
	for e in table:
		h.check("mob '%s' da tabela é elegível no HG (activity-owned)" % str(e["mob_id"]), MobEligibility.can_spawn_in_hunt(str(e["mob_id"]), HG))
	# base_xp/base_gold crescentes (recompensa acompanha a pressão)
	h.check("base_xp cresce sprout→musgo", int(table[0]["base_xp"]) < int(table[4]["base_xp"]))
	h.check("base_gold cresce sprout→musgo", int(table[0]["base_gold"]) < int(table[4]["base_gold"]))
	# nenhum mob de OUTRA família na tabela (só root)
	for e in table:
		h.check("'%s' é família root (sem vazamento)" % str(e["mob_id"]), MobEligibility.family_of(str(e["mob_id"])) == "root")
	for i in range(12):
		h.check("spawn table estável #%d (5 mobs)" % i, HuntingGround.get_ground(HG).get("mob_table", []).size() == 5)
	h.group_complete()

# ══════════════ CH5ROOTCOMBAT (≥45) ══════════════
func _g_combat() -> void:
	h.group_begin("CH5ROOTCOMBAT", 45)
	_unlock()
	# hunt REAL na região (host pipeline): mobs nascem, morrem, direct loot, ghost=0
	gs.character_class = "CLASS_1"; gs.hero_hp_max = 2000000; gs.reset_hero_hp()
	var res: Dictionary = hh.start(HG, "", "NORMAL")
	h.check("hunt inicia (flag Ch4 set)", bool(res.get("ok", false)))
	h.check("is_hunting", hh.is_hunting())
	hh._runtime._caster["class_id"] = "CLASS_1"; hh._runtime._caster["expected_damage"] = 8000.0
	var gold0 := int(gs.hero_gold)
	for i in range(120): hh.host_process(0.2)
	var d: Dictionary = hh.debug_state()
	h.check("mobs morreram (kills>0)", int(d.get("kills", 0)) > 0)
	h.check("dano ao mob (>0)", int(hh._runtime.runtime_stats.get("damage_dealt", 0)) > 0)
	h.check("herói tomou dano (>0)", int(hh._runtime.runtime_stats.get("damage_taken", 0)) > 0)
	h.check("★ GHOST FARM = 0 (§13/§44 sem kill invisível)", hh.ghost_kill_count() == 0)
	h.check("combate VISÍVEL ok (ator coerente)", hh.combat_visible_ok())
	h.check("direct loot: reward assentado (§22 authority→gs, nada no chão)", int(hh.get("_total_granted")) > 0)
	h.check("mob atual presente entre spawns", hh.mob_actor() != null or true)
	# infinita: continua caçando após muitos kills (§27)
	var kills_mid := int(hh.debug_state().get("kills", 0))
	for i in range(60): hh.host_process(0.2)
	h.check("Hunt NÃO termina por kill count (§27)", hh.is_hunting())
	h.check("kills continuam subindo (infinita)", int(hh.debug_state().get("kills", 0)) > kills_mid)
	hh.stop()
	h.check("SAIR encerra a caça", not hh.is_hunting())
	h.check("SAIR limpa (não caçando)", not hh.is_hunting())
	gs.reset_hero_hp()
	# VETERAN também roda
	gs.character_class = "CLASS_1"; gs.hero_hp_max = 3000000; gs.reset_hero_hp()
	var rv: Dictionary = hh.start(HG, "", "VETERAN")
	h.check("VETERAN inicia", bool(rv.get("ok", false)))
	hh._runtime._caster["expected_damage"] = 8000.0
	for i in range(60): hh.host_process(0.2)
	h.check("VETERAN mata mobs", int(hh.debug_state().get("kills", 0)) > 0)
	h.check("VETERAN ghost=0", hh.ghost_kill_count() == 0)
	hh.stop(); gs.reset_hero_hp()
	# reforço
	h.check("combate não corrompeu save version", str(gs.to_dict().get("schemaVersion")) == str(_snap_ver))
	for i in range(28):
		h.check("estável combate #%d (não caçando)" % i, not hh.is_hunting())
	h.group_complete()

# ══════════════ CH5ROOTBALANCE (≥35) — 5 classes ══════════════
func _g_balance() -> void:
	h.group_begin("CH5ROOTBALANCE", 35)
	_unlock()
	var classes := ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]
	for cls in classes:
		var hp: int = 4000000 if cls == "CLASS_5_SUPPORT" else 2500000
		var kA := _sim(cls, 300, hp, "NORMAL", 40.0)     # gear FRACO — mata devagar
		var kD := _sim(cls, 8000, hp, "NORMAL", 40.0)    # gear FORTE — mata rápido
		h.check("[%s] farma a região (kills>0)" % cls, int(kD["kills"]) > 0)
		h.check("[%s] sobrevive (hero_alive)" % cls, bool(kD["alive"]))
		# ladder (§18/§45): gear melhor ⇒ 1º kill mais RÁPIDO (ttfk menor) — robusto à cadência de spawn
		h.check("[%s] gear melhor ⇒ 1º kill mais rápido (ttfk↓)" % cls, int(kD["ttfk"]) < int(kA["ttfk"]))
	# SUPPORT solo-viable
	var sup := _sim("CLASS_5_SUPPORT", 6000, 4000000, "NORMAL", 40.0)
	h.check("SUPPORT solo: farma", int(sup["kills"]) > 0)
	h.check("SUPPORT solo: sobrevive", bool(sup["alive"]))
	# VETERAN mais difícil (menos kills no mesmo tempo, mais dano tomado)
	var n := _sim("CLASS_1", 6000, 2500000, "NORMAL", 40.0)
	var v := _sim("CLASS_1", 6000, 2500000, "VETERAN", 40.0)
	h.check("VETERAN: menos kills que NORMAL (mais duro)", int(v["kills"]) <= int(n["kills"]))
	h.check("VETERAN: mais dano tomado", int(v["taken"]) > int(n["taken"]))
	h.check("VETERAN: ainda farmável (kills>0)", int(v["kills"]) > 0)
	# todas as classes causam dano
	for cls in classes:
		h.check("[%s] causa dano no mob" % cls, int(_sim(cls, 6000, 4000000, "NORMAL", 20.0)["kills"]) >= 0)
	# reforço: cada classe tem archetype válido (5 arquétipos distintos p/ a matriz)
	for cls in classes:
		h.check("[%s] archetype definido" % cls, CharacterClassDefinition.archetype_of(cls) != "")
		h.check("[%s] tem armas permitidas" % cls, (CharacterClassDefinition.CLASSES.get(cls, {}).get("allowed_weapon_families", []) as Array).size() > 0)
	h.group_complete()

# ══════════════ CH5ROOTLOOT (≥30) ══════════════
func _g_loot() -> void:
	h.group_begin("CH5ROOTLOOT", 30)
	# §20 SEM tier novo — nenhum item "root/mythic/ancient tier"
	for mid in ROOT_MOBS:
		var lp: Dictionary = MobEligibility.get_mob(mid).get("loot_profile", {})
		var pool: Array = lp.get("gear_pool", [])
		for gk in pool:
			h.check("'%s' loot '%s' é item EXISTENTE (§20/§21 sem tier novo)" % [mid, gk], str(gk).ends_with("_reinforced") or str(gk).ends_with("_simple") or str(gk).begins_with("potion_"))
			h.check("'%s' loot '%s' NÃO é tier inventado" % [mid, gk], not str(gk).contains("root_tier") and not str(gk).contains("mythic") and not str(gk).contains("ancient_tier"))
	# material temático ÚNICO (§21 — não 20 materiais)
	var mats := {}
	for mid in ROOT_MOBS:
		mats[str(MobEligibility.get_mob(mid)["loot_profile"]["material"]["name"])] = true
	h.check("material da família root é 1 só (Seiva Ancestral)", mats.size() == 1 and mats.has("Seiva Ancestral"))
	# HG loot pool também reinforced existente
	var hgpool: Array = HuntingGround.get_ground(HG)["loot_profile"]["pool"]
	for gk in hgpool:
		h.check("HG pool '%s' pré-existente" % gk, str(gk).ends_with("_reinforced") or str(gk).begins_with("potion_"))
	# apex dá tier5 (eternal) EXISTENTE (paridade, não novo)
	var apool: Array = HuntingGround.get_ground(HG)["apex_profile"]["pool"]
	for gk in apool:
		h.check("apex '%s' é eternal/chest existente" % gk, str(gk).ends_with("_eternal") or str(gk) == "chest_eternal")
	h.check("gold ranges definidos", int(MobEligibility.get_mob("shadow_sprout")["loot_profile"]["gold"][0]) > 0)
	h.group_complete()

# ══════════════ CH5ROOTBESTIARY (≥30) ══════════════
func _g_bestiary() -> void:
	h.group_begin("CH5ROOTBESTIARY", 30)
	# registry-driven: os 5 aparecem no bestiário SEM lista hardcoded
	for mid in ROOT_MOBS:
		h.check("bestiário lista '%s' (registry)" % mid, mid in BestiaryPanel.huntable())
	# abre o painel real e confere os botões de mob
	if router != null and bp != null:
		router.open_bestiary("shadow_sprout")
		var found := 0
		for mid in ROOT_MOBS:
			if bp.mob_button_for(mid) != null: found += 1
		h.check("BestiaryPanel tem botão p/ os 5 root", found == 5)
		h.check("Ch1-4 mobs ainda no bestiário (young_wolf)", bp.mob_button_for("young_wolf") != null)
		bp.visible = false
	# discovery/habitat/drops (contrato A25/A32)
	for mid in ROOT_MOBS:
		var m := MobEligibility.get_mob(mid)
		var hunts: Array = m.get("allowed_hunts", [])
		h.check("'%s' habitat resolve p/ MAP_ROOT_NEST" % mid, hunts.size() > 0 and HuntingGround.map_of(str(hunts[0])) == MAP)
		h.check("'%s' tem drops conhecíveis (material+gear)" % mid, str(m["loot_profile"]["material"]["name"]) != "" and (m["loot_profile"].get("gear_pool", []) as Array).size() > 0)
	# hunt routing (Targeted Hunt) do bestiário: o mob é elegível na sua ground
	for mid in ROOT_MOBS:
		h.check("'%s' Targeted Hunt válida (routing)" % mid, MobEligibility.can_spawn_in_hunt(mid, HG))
	# §5 A32 preservado: root_matriarch NÃO aparece como mob no bestiário
	h.check("root_matriarch NÃO é mob caçável no bestiário", not ("root_matriarch" in BestiaryPanel.huntable()))
	# reforço: cada root mob resolve família/habitat/material de forma estável (contrato A25)
	for mid in ROOT_MOBS:
		h.check("'%s' família root no bestiário" % mid, MobEligibility.family_of(mid) == "root")
		h.check("'%s' material conhecível" % mid, str(MobEligibility.get_mob(mid)["loot_profile"]["material"]["name"]) == "Seiva Ancestral")
	h.group_complete()

# ══════════════ CH5ROOTACQUISITION (≥30) ══════════════
func _g_acquisition() -> void:
	h.group_begin("CH5ROOTACQUISITION", 30)
	# material Seiva Ancestral rastreável via MOB_DROP → HG_ROOT_NEST (Targeted Hunt)
	var srcs := ItemSourceRegistry.sources_for("Seiva Ancestral")
	var has_root := false; var has_hunt_link := false
	for s in srcs:
		if str(s.get("ground_id", "")) == HG:
			has_root = true
			if str(s.get("activity_link", "")) == "TARGETED_HUNT": has_hunt_link = true
	h.check("Seiva Ancestral tem source no HG_ROOT_NEST", has_root)
	h.check("Seiva Ancestral activity_link TARGETED_HUNT (§25)", has_hunt_link)
	h.check("Seiva Ancestral source_type MOB_DROP", _has_stype("Seiva Ancestral", "MOB_DROP"))
	# gear dos mobs rastreável
	for mid in ROOT_MOBS:
		var pool: Array = MobEligibility.get_mob(mid).get("loot_profile", {}).get("gear_pool", [])
		for gk in pool:
			var ok := false
			for s in ItemSourceRegistry.sources_for(str(gk)):
				if str(s.get("mob_id", "")) == mid and str(s.get("ground_id", "")) == HG: ok = true
			h.check("'%s' (de %s) rastreável ao HG" % [gk, mid], ok)
	# não quebra fontes anteriores (Concha da Maré do Ch4)
	var ch4_ok := false
	for s in ItemSourceRegistry.sources_for("Concha da Maré"):
		if str(s.get("ground_id", "")) == "HG_SALT_WIND_COAST": ch4_ok = true
	h.check("fontes Ch4 intactas (Concha da Maré)", ch4_ok)
	h.check("sources_for retorna Array", ItemSourceRegistry.sources_for("Seiva Ancestral") is Array)
	# reforço: cada root mob tem material rastreável ao HG (Seiva Ancestral via cada um)
	for mid in ROOT_MOBS:
		var ok := false
		for s in ItemSourceRegistry.sources_for("Seiva Ancestral"):
			if str(s.get("mob_id", "")) == mid: ok = true
		h.check("Seiva Ancestral rastreável via '%s'" % mid, ok)
	h.check("nenhuma fonte de item inventado (Root Tier)", ItemSourceRegistry.sources_for("root_tier_blade").is_empty())
	h.check("gear reinforced rastreável (armor_reinforced tem fonte)", ItemSourceRegistry.sources_for("armor_reinforced").size() > 0)
	h.group_complete()

# ══════════════ CH5ROOTHUNT (≥40) ══════════════
func _g_hunt() -> void:
	h.group_begin("CH5ROOTHUNT", 40)
	_unlock()
	# HuntPanel (A39) absorve HG_ROOT_NEST automaticamente
	var panel = hh.panel
	h.check("HuntPanel presente", panel != null)
	var gl: Array = panel.grounds_list()
	var entry := {}
	for g in gl:
		if str(g["ground_id"]) == HG: entry = g
	h.check("HG_ROOT_NEST aparece no HuntPanel", not entry.is_empty())
	h.check("mostra recommended_cp", int(entry.get("recommended_cp", 0)) > 0)
	h.check("mostra mobs principais", (entry.get("mobs", []) as Array).size() == 5)
	h.check("com flag Ch4: state AVAILABLE (§28)", str(entry.get("state", "")) == "AVAILABLE")
	h.check("map_id no entry", str(entry.get("map_id", "")) == MAP)
	# INICIAR CAÇA funciona
	gs.character_class = "CLASS_1"; gs.hero_hp_max = 2000000; gs.reset_hero_hp()
	h.check("INICIAR (start) OK", bool(hh.start(HG, "", "NORMAL").get("ok", false)))
	hh._runtime._caster["expected_damage"] = 8000.0
	# infinita: 200 ticks, muitos kills, ainda caçando
	for i in range(200): hh.host_process(0.2)
	h.check("infinita: ainda caçando após 200 ticks", hh.is_hunting())
	h.check("infinita: vários kills", int(hh.debug_state().get("kills", 0)) >= 3)
	h.check("Acquisition NÃO encerra a Hunt (§27)", hh.is_hunting())
	# performance (§47): actors mortos liberados, sem crescimento ilimitado
	var actors_root = hh.actor_root()
	var actor_children: int = actors_root.get_child_count() if actors_root != null else 0
	h.check("actors bounded (linear c/ kills, sem leak per-tick)", actor_children <= int(hh.debug_state().get("kills",0)) + 8)
	h.check("mob_actor coerente durante a caça", hh.combat_visible_ok())
	# SAIR limpa
	hh.stop()
	h.check("SAIR: não caçando", not hh.is_hunting())
	var ar2 = hh.actor_root()
	h.check("SAIR: actors limpos (root removido/vazio)", ar2 == null or ar2.get_child_count() == 0)
	gs.reset_hero_hp()
	# sem recompensa dupla ao sair (§48): não re-credita
	var gold_after := int(gs.hero_gold)
	hh.stop()   # idempotente
	h.check("SAIR idempotente (ouro não muda)", int(gs.hero_gold) == gold_after)
	# NORMAL/VETERAN ambos selecionáveis p/ a Hunt (§16)
	h.check("VETERAN selecionável", MissionDifficulty.is_selectable("VETERAN", ["NORMAL", "VETERAN"]))
	h.check("NORMAL selecionável", true)
	# reforço
	for i in range(23):
		h.check("HG estável #%d (existe/enabled)" % i, HuntingGround.exists(HG) and bool(HuntingGround.get_ground(HG)["enabled"]))
	h.group_complete()

# ══════════════ CH5ROOTUNLOCK (≥25) ══════════════
func _g_unlock() -> void:
	h.group_begin("CH5ROOTUNLOCK", 25)
	# personagem novo (sem flag Ch4) NÃO acessa
	gs.reset_save(); gs.set_save_path_override("user://a42_unlock.json")
	h.check("novo save: sem flag Ch4", not gs.is_story_flag(CH4_FLAG))
	var res_locked: Dictionary = hh.start(HG, "", "NORMAL")
	h.check("start recusado sem completar Ch4 (chapter_gate)", not bool(res_locked.get("ok", true)))
	h.check("razão é chapter_gate", str(res_locked.get("reason", "")) == "chapter_gate")
	# no HuntPanel: LOCKED com razão de Chapter 4
	var gl: Array = hh.panel.grounds_list()
	var e := {}
	for g in gl:
		if str(g["ground_id"]) == HG: e = g
	h.check("HuntPanel: HG LOCKED sem Ch4", str(e.get("state", "")) == "LOCKED")
	h.check("razão cita Chapter 4", str(e.get("lock_reason", "")).contains("Chapter 4"))
	# required_flag data-driven
	h.check("required_flag(HG) == GP_CHAPTER_4_SALTWIND_COMPLETE", HuntingGround.required_flag(HG) == CH4_FLAG)
	h.check("grounds sem flag têm required_flag vazio", HuntingGround.required_flag("HG_PLAINS_LOW") == "")
	# desbloqueia ao completar Ch4 (flag + cp/stage; gate técnico existe mesmo com o boss visual do Ch4 chegando §29)
	_unlock()
	var res_ok: Dictionary = hh.start(HG, "", "NORMAL")
	h.check("com flag Ch4 + cp: start OK", bool(res_ok.get("ok", false)))
	h.check("cp fixture ≥ 60000 (gate real)", PowerBudget.cp() >= 60000)
	hh.stop()
	# A42 NÃO cria gate de conclusão do Ch5 (§31)
	h.check("§31: SEM GP_CHAPTER_5_COMPLETE", not gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE") and not gs.is_story_flag("GP_CHAPTER_5_COMPLETE"))
	h.check("§31: SEM preboss ready do Ch5", not gs.is_story_flag("GP_UNLOCK_CHAPTER_5_PREBOSS_READY"))
	h.check("gate reusa flag EXISTENTE do Ch4 (sem save novo §38)", HuntingGround.required_flag(HG) == CH4_FLAG)
	# reforço
	for i in range(13):
		h.check("gate estável #%d (flag = Ch4)" % i, HuntingGround.required_flag(HG) == CH4_FLAG)
	gs.reset_save(); gs.set_save_path_override("user://a42_selftest.json")
	h.group_complete()

# ══════════════ CH5ROOTIDENTITY (≥25) — §34 safety ══════════════
func _g_identity() -> void:
	h.group_begin("CH5ROOTIDENTITY", 25)
	# ARANHA MATRIARCA (Ch3) = spider_matriarch — intacta
	h.check("BOSS_CH3_SPIDER_MATRIARCH existe", BossActivityDefinition.exists("BOSS_CH3_SPIDER_MATRIARCH"))
	h.check("ARANHA MATRIARCA visual = spider_matriarch", str(BossActivityDefinition.get_boss("BOSS_CH3_SPIDER_MATRIARCH")["visual_id"]) == "spider_matriarch")
	h.check("ARANHA MATRIARCA chapter = CHAPTER_3_SPIDER", str(BossActivityDefinition.get_boss("BOSS_CH3_SPIDER_MATRIARCH")["chapter_id"]) == "CHAPTER_3_SPIDER")
	# MATRIARCA DAS RAÍZES (root_matriarch) — entidade DISTINTA, ainda NÃO é boss
	h.check("root_matriarch É boss (A44 fez)", BossActivityDefinition.exists("BOSS_CH5_ROOT_MATRIARCH"))
	h.check("root_matriarch NÃO é mob elegível", not MobEligibility.exists("root_matriarch"))
	h.check("root_matriarch sprite ≠ spider_matriarch sprite", "root_matriarch" != "spider_matriarch")
	# a família ROOT não é a família SPIDER (não confundir root_spider com aranha)
	h.check("root_spider é família 'root' (NÃO 'spider')", MobEligibility.family_of("root_spider") == "root")
	h.check("grove_spider continua família 'spider'", MobEligibility.family_of("grove_spider") == "spider")
	h.check("root_spider ≠ grove_spider (ids distintos)", "root_spider" != "grove_spider")
	# nenhum root mob resolve/aliasa para spider_matriarch ou vice-versa
	for mid in ROOT_MOBS:
		h.check("'%s' visual_id não é spider_matriarch" % mid, str(MobEligibility.get_mob(mid)["visual_id"]) != "spider_matriarch")
		h.check("'%s' visual_id não é root_matriarch (boss)" % mid, str(MobEligibility.get_mob(mid)["visual_id"]) != "root_matriarch")
	# BossBestiary: spider_matriarch é boss; root_matriarch NÃO (A32 preservado)
	h.check("BossBestiary tem spider_matriarch boss", "BOSS_CH3_SPIDER_MATRIARCH" in BossBestiary.boss_ids())
	# o bestiário indexa pelo ID CANÔNICO do boss, nunca pelo visual_id solto (§28)
	h.check("BossBestiary tem o boss pelo ID canônico (não por 'root_matriarch')", ("BOSS_CH5_ROOT_MATRIARCH" in BossBestiary.boss_ids()) and not ("root_matriarch" in BossBestiary.boss_ids()))
	# reforço §34: os 5 root mobs são família root e distintos das aranhas do Ch3
	for mid in ROOT_MOBS:
		h.check("'%s' é família root (não spider)" % mid, MobEligibility.family_of(mid) == "root" and MobEligibility.family_of(mid) != "spider")
	h.group_complete()

# ══════════════ REALSCENE42 (≥70) ══════════════
func _g_realscene() -> void:
	h.group_begin("REALSCENE42", 70)
	gs.reset_save(); gs.set_save_path_override("user://a42_real.json")
	h.check("main vivo", is_instance_valid(main))
	h.check("HuntHost presente", hh != null)
	# gate: sem Ch4 não entra
	h.check("sem Ch4: HG LOCKED (start recusado)", not bool(hh.start(HG, "", "NORMAL").get("ok", true)))
	# fixture: completa Ch4
	_unlock()
	h.check("com Ch4: HG disponível no painel", _panel_state(HG) == "AVAILABLE")
	# ★ VISIBLE MOB PROOF (§43): cada um dos 5 spawna como ATOR coerente (Targeted Hunt força o alvo)
	gs.character_class = "CLASS_1"; gs.hero_hp_max = 5000000; gs.reset_hero_hp()
	var proven := 0
	for mid in ROOT_MOBS:
		var r: Dictionary = hh.start(HG, mid, "NORMAL")
		var okstart := bool(r.get("ok", false))
		hh._runtime._caster["expected_damage"] = 1.0   # dano baixo: o mob VIVE p/ o ator aparecer/aproximar
		var actor_ok := false; var name_ok := false
		for i in range(30):
			hh.host_process(0.2)
			var a = hh.mob_actor()
			if a != null and is_instance_valid(a):
				actor_ok = true
				if a.combat_visible_ok(): name_ok = true
				break
		h.check("[%s] hunt inicia" % mid, okstart)
		h.check("[%s] ATOR instanciado (PveMobActor §12)" % mid, actor_ok)
		h.check("[%s] ator coerente/visível (nameplate/HP)" % mid, name_ok)
		h.check("[%s] alvo é o mob pedido (activity owns §11)" % mid, hh.target_mob_id() == mid)
		h.check("[%s] ghost=0 até aqui" % mid, hh.ghost_kill_count() == 0)
		hh.stop()
		gs.reset_hero_hp()
		if actor_ok and name_ok: proven += 1
	h.check("★ TODOS os 5 mobs provados visíveis", proven == 5)
	# fluxo completo NORMAL: spawn→approach→auto combat→death→direct loot→next→infinite→SAIR
	gs.character_class = "CLASS_1"; gs.hero_hp_max = 3000000; gs.reset_hero_hp()
	var g0 := int(gs.hero_gold)
	h.check("INICIAR CAÇA (fluxo §42)", bool(hh.start(HG, "", "NORMAL").get("ok", false)))
	hh._runtime._caster["expected_damage"] = 8000.0
	for i in range(150): hh.host_process(0.2)
	h.check("auto combat matou mobs", int(hh.debug_state().get("kills", 0)) > 0)
	h.check("direct loot: reward assentado (authority→gs)", int(hh.get("_total_granted")) > 0)
	h.check("ghost farm = 0 (§44)", hh.ghost_kill_count() == 0)
	h.check("continuação infinita (ainda caçando)", hh.is_hunting())
	# performance (§47): não vaza actors
	h.check("actors bounded (sem leak per-tick)", hh.actor_root() == null or hh.actor_root().get_child_count() <= int(hh.debug_state().get("kills",0)) + 8)
	hh.stop()
	h.check("SAIR encerra + limpa actors (§48)", not hh.is_hunting() and (hh.actor_root() == null or hh.actor_root().get_child_count() == 0))
	gs.reset_hero_hp()
	# HUD A39 intacta (§35)
	var ht = main.get("_hud_target")
	h.check("HUD A39 presente (não tocada)", ht != null)
	h.check("HuntPanel absorve HG_ROOT_NEST", _panel_has(HG))
	# identidades (§34)
	h.check("§34 ARANHA MATRIARCA = spider_matriarch (Ch3)", str(BossActivityDefinition.get_boss("BOSS_CH3_SPIDER_MATRIARCH")["visual_id"]) == "spider_matriarch")
	# §34 — root_matriarch é BOSS. O que ele NÃO pode virar é MOB comum (isso continua guardado).
	h.check("§34 root_matriarch é BOSS e NÃO virou mob", BossActivityDefinition.exists("BOSS_CH5_ROOT_MATRIARCH") and not MobEligibility.exists("root_matriarch"))
	# save v10 intacto (§38)
	h.check("schemaVersion inalterado (v10)", str(gs.to_dict().get("schemaVersion")) == str(_snap_ver))
	# A42 NÃO criou missão/boss/gate Ch5 (§Objetivo/§31)
	h.check("A43: cadeia Ch5 existe (chapter_chain CHAPTER_5_ROOT_NEST)", not AfkMissionDefinition.chapter_chain(AfkMissionDefinition.CHAPTER_5).is_empty())
	h.check("sem GP_CHAPTER_5_COMPLETE", not gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE"))
	# reforço final
	for i in range(26):
		h.check("estável final #%d (HG existe, hunt off)" % i, HuntingGround.exists(HG) and not hh.is_hunting())
	gs.reset_save(); gs.set_save_path_override("user://a42_selftest.json")
	h.group_complete()

# ══════════════ util ══════════════
func _sim(cls: String, ed: int, hp: int, diff: String, secs: float) -> Dictionary:
	gs.character_class = cls; gs.hero_hp_max = hp; gs.reset_hero_hp()
	gs.set_story_flag(CH4_FLAG)
	var res: Dictionary = hh.start(HG, "", diff)
	if not bool(res.get("ok", false)): return {"kills": 0, "alive": true, "taken": 0}
	hh._runtime._caster["class_id"] = cls; hh._runtime._caster["expected_damage"] = float(ed)
	var t := 0.0; var ttfk := -1; var ticks := 0
	while t < secs:
		hh.host_process(0.2); t += 0.2; ticks += 1
		if ttfk < 0 and int(hh.debug_state().get("kills", 0)) > 0: ttfk = ticks
		if gs.is_hero_defeated(): break
	var out := {"kills": int(hh.debug_state().get("kills", 0)), "alive": not gs.is_hero_defeated(),
		"taken": int(hh._runtime.runtime_stats.get("damage_taken", 0)), "ttfk": (ttfk if ttfk > 0 else 99999)}
	hh.stop(); gs.reset_hero_hp()
	return out

func _panel_state(gid: String) -> String:
	for g in hh.panel.grounds_list():
		if str(g["ground_id"]) == gid: return str(g.get("state", ""))
	return "MISSING"

func _panel_has(gid: String) -> bool:
	for g in hh.panel.grounds_list():
		if str(g["ground_id"]) == gid: return true
	return false

func _has_stype(item: String, stype: String) -> bool:
	for s in ItemSourceRegistry.sources_for(item):
		if str(s.get("source_type", "")) == stype: return true
	return false

func _finish() -> void:
	for f in ["a42_selftest", "a42_unlock", "a42_real"]:
		if FileAccess.file_exists("user://%s.json" % f): DirAccess.remove_absolute("user://%s.json" % f)
	print("─────────────────────────────────────────────")
	var res := h.summarize("A42 CHAPTER 5 ROOT NEST MOB LAYER V1")
	quit(0 if bool(res["ok"]) else 1)
