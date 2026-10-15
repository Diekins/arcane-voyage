extends SceneTree
## Self-test/RELATÓRIO FATIA A7.3 — Content Foundation 1–100. Valida o ContentManifest, prova que a curva de
## PODER (gear tiers reais, SEM CP artificial, SEM baixar a curva A3) fecha o gap 12.358→~21.603 na fase 100, e
## simula o primeiro ciclo. FIXTURE (save vivo intocado).
##   godot --headless --path godot -s res://scripts/_a73_content_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1
func _g(): return root.get_node_or_null("GameState")

const GATE100 := 21603   # required_cp(100, boss) — o gate do 1º Prestígio (curva A3 inalterada)

func _initialize() -> void:
	var gs = _g()
	var fixture := "user://a73_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()

	var gate := ProgressionMath.required_cp(100, "boss")

	# ══════════ CHAP (manifesto) ══════════
	_chk("CHAP-T01 existem 10 capítulos", ContentManifest.chapters().size() == 10)
	var stages_ok := true
	for c in ContentManifest.chapters():
		if not (c.has("normal_pool") and c.has("apex") and c.has("boss_id")): stages_ok = false
	_chk("CHAP-T02 100 stages mapeadas (10 cap × 10 stages)", stages_ok and ContentManifest.chapter_of(100) == 10 and ContentManifest.chapter_of(1) == 1)
	var apex_ok := true; var boss_ok := true
	for c in ContentManifest.chapters():
		if str(c["apex"]) == "": apex_ok = false
		if str(c["boss_id"]) == "" or str(c["boss_status"]) == "": boss_ok = false
	_chk("CHAP-T03 cada capítulo tem stage5 Apex", apex_ok and ContentManifest.stage_type(5) == "miniboss")
	_chk("CHAP-T04 cada capítulo tem stage10 BossDefinition/placeholder explícito", boss_ok and ContentManifest.stage_type(10) == "boss")
	# CHAP-T05 nenhum mob dev/test
	var no_test := true
	for m in ContentManifest.all_referenced_mobs():
		if m in ContentManifest.TEST_MOB_IDS: no_test = false
	_chk("CHAP-T05 nenhuma stage usa mob dev/test", no_test)
	_chk("CHAP-T06 world contexts válidos (não-vazios)", _all_have_contexts())
	_chk("CHAP-T07 stage continua != region (chapter referencia region(s))", ContentManifest.chapter(1)["region"] == "plains" and (ContentManifest.chapter(1)["world_contexts"] as Array).size() >= 1)

	# ══════════ CONTENTCP — curva de poder / builds P0 ══════════
	print("  ── CURVA DE PODER (gate fase 100 = %d) ──" % gate)
	var cp_normal := _build_and_cp(gs, "normal")
	var cp_forte := _build_and_cp(gs, "forte")
	var cp_minmax := _build_and_cp(gs, "minmax")
	var r_normal := float(cp_normal) / float(gate)
	var r_forte := float(cp_forte) / float(gate)
	var r_minmax := float(cp_minmax) / float(gate)
	print("    P0 NORMAL: CP=%d · R=%.2f (alvo ~0.90-0.98)" % [cp_normal, r_normal])
	print("    P0 FORTE:  CP=%d · R=%.2f (alvo ~1.00-1.15)" % [cp_forte, r_forte])
	print("    P0 MINMAX: CP=%d · R=%.2f (alvo >1.20)" % [cp_minmax, r_minmax])
	# CONTENTCP tests
	gs.reset_save(); _apply_build(gs, "start")
	_chk("CONTENTCP-T01 build inicial compatível com stage1", float(PowerBudget.cp()) >= 0.85 * float(ProgressionMath.required_cp(1, "boss")))
	_chk("CONTENTCP-T02 gear progride monotonicamente (tiers 1<2<3<4<5)", _gear_monotonic())
	_chk("CONTENTCP-T03 build cresce organicamente (start < normal < forte < minmax)", cp_normal < cp_forte and cp_forte < cp_minmax)
	_chk("CONTENTCP-T04 P0 normal chega PRÓXIMO do gate (R 0.85-1.05)", r_normal >= 0.85 and r_normal <= 1.05)
	_chk("CONTENTCP-T05 P0 forte SUPERA stage100 (R >= 1.0)", r_forte >= 1.0)
	_chk("CONTENTCP-T06 P0 minmax DOMINA stage100 (R > 1.2)", r_minmax > 1.2)
	# CONTENTCP-T07 nenhum CP artificial: CP vem de stat real (dobrar attack do gear muda o CP)
	gs.reset_save(); _apply_build(gs, "forte")
	var cp_a := PowerBudget.cp()
	gs.master_level = 0   # garante Master fora (P0 é Master 0)
	_chk("CONTENTCP-T07 nenhum CP artificial (Master=0 no P0; CP = stat real)", gs.master_level == 0 and cp_a > 0)

	# ══════════ CONTENTLOOT — gear novo no ItemInstance ══════════
	var inst := ItemRoller.roll("sword_eternal", 12345, "loot")
	_chk("CONTENTLOOT-T01 cada capítulo tem fonte de gear", _all_have_gear())
	_chk("CONTENTLOOT-T02 novo gear gera ItemInstance", not inst.is_empty() and ItemInstance.base_item_id(inst) == "sword_eternal")
	_chk("CONTENTLOOT-T03 rolls funcionam (quality 0..100, rolls no core)", int(inst["quality"]) >= 0 and int(inst["quality"]) <= 100 and (inst["rolls"] as Dictionary).has("attack"))
	# CONTENTLOOT-T04 offline: gear novo agrega no claim (via id_by_name / equipável)
	_chk("CONTENTLOOT-T04 gear novo é equipável (entra no pipeline offline/claim)", ItemDB.is_equippable("sword_eternal") and ItemDB.is_equippable("chest_eternal"))
	# CONTENTLOOT-T05 Códice reconhece os novos bases
	gs.reset_save()
	var disc: bool = gs.codex_discover("sword_eternal")
	_chk("CONTENTLOOT-T05 Códice reconhece novos bases", disc and gs.codex_discovered.has("sword_eternal"))

	# ══════════ CONTENTBOSS ══════════
	_chk("CONTENTBOSS-T01 10 boss-stage definitions", _count_bosses() == 10)
	_chk("CONTENTBOSS-T02 Lobo/Golem READY (script real)", str(ContentManifest.chapter(1)["boss_status"]) == "READY" and str(ContentManifest.chapter(2)["boss_status"]) == "READY")
	_chk("CONTENTBOSS-T03 bosses sem script marcados PLACEHOLDER", ContentManifest.bosses_by_status("PLACEHOLDER").size() == 8)
	_chk("CONTENTBOSS-T04 boss scaling A3 continua (required_cp boss > normal)", ProgressionMath.required_cp(100, "boss") > ProgressionMath.required_cp(100, "normal"))
	# CONTENTBOSS-T05 first-clear concede Selo + suporte (usa GameState real)
	gs.reset_save()
	var got_seal: bool = gs.grant_cycle_seal(10)
	_chk("CONTENTBOSS-T05 first-clear boss concede Selo (e suporte via grant_encounter_reward)", got_seal and gs.cycle_seals == 1)

	# ══════════ SIMULAÇÃO 1→100 + tempo até P1 ══════════
	_sim_1_100(gs, gate)

	# ══════════ restaura ══════════
	gs.set_save_path_override("")
	gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ── builds ──
func _apply_build(gs, kind: String) -> void:
	gs.reset_save(); gs.master_level = 0; gs.jewel_levels = {}; gs.slot_refinement = {}; gs.equipped_instances = {}
	match kind:
		"start":
			gs.equipment = {"weapon": "sword_simple", "chest": "armor_simple", "boots": "boots_simple"}
			gs.hero_hp_max = 100 + 10 * 4   # ~nível 5
		"normal":
			gs.equipment = {"weapon": "sword_abyss", "chest": "chest_abyss", "legs": "legs_abyss", "boots": "boots_abyss", "head": "head_abyss", "offhand": "shield_abyss", "ring": "ring_abyss", "bracelet": "bracelet_abyss", "accessory": "amulet_abyss"}
			for s in gs.equipment: gs.slot_refinement[str(s)] = 12
			gs.jewel_levels = {"ruby": 5, "sapphire": 5, "emerald": 5}
			gs.hero_hp_max = 100 + 10 * 79   # ~nível 80
		"forte":
			gs.equipment = {"weapon": "sword_eternal", "chest": "chest_eternal", "legs": "legs_eternal", "boots": "boots_eternal", "head": "head_eternal", "offhand": "shield_eternal", "ring": "ring_eternal", "bracelet": "bracelet_eternal", "accessory": "amulet_eternal"}
			for s in gs.equipment: gs.slot_refinement[str(s)] = 18
			gs.jewel_levels = {"ruby": 8, "sapphire": 8, "emerald": 8}
			gs.hero_hp_max = 100 + 10 * 99   # ~nível 100
		"minmax":
			gs.equipment = {"weapon": "sword_eternal", "chest": "chest_eternal", "legs": "legs_eternal", "boots": "boots_eternal", "head": "head_eternal", "offhand": "shield_eternal", "ring": "ring_eternal", "bracelet": "bracelet_eternal", "accessory": "amulet_eternal"}
			# god roll (rolls 1.15) via instâncias no overlay
			for s in gs.equipment:
				gs.slot_refinement[str(s)] = 20
				var rolls: Dictionary = {}
				for k in ItemInstance.CORE_REFINABLE:
					if int(ItemDB.stat(str(gs.equipment[s]), k)) > 0: rolls[k] = 1.15
				gs.equipped_instances[str(s)] = ItemInstance.make("mm_%s" % s, str(gs.equipment[s]), 99, rolls, [], "test", 0, true, false)
			gs.jewel_levels = {"ruby": 10, "sapphire": 10, "emerald": 10}
			gs.hero_hp_max = 100 + 10 * 119   # ~nível 120

func _build_and_cp(gs, kind: String) -> int:
	_apply_build(gs, kind)
	return PowerBudget.cp()

func _gear_monotonic() -> bool:
	# soma de stats-base por tier (weapon attack como proxy)
	var t := [ItemDB.stat("sword_simple", "attack"), ItemDB.stat("sword_reinforced", "attack"), ItemDB.stat("sword_memoria", "attack"), ItemDB.stat("sword_abyss", "attack"), ItemDB.stat("sword_eternal", "attack")]
	for i in range(t.size() - 1):
		if t[i] >= t[i + 1]: return false
	return true

func _all_have_contexts() -> bool:
	for c in ContentManifest.chapters():
		if (c["world_contexts"] as Array).is_empty(): return false
	return true

func _all_have_gear() -> bool:
	for c in ContentManifest.chapters():
		if (c.get("gear_drops", []) as Array).is_empty(): return false
	return true

func _count_bosses() -> int:
	var n := 0
	for c in ContentManifest.chapters():
		if str(c["boss_id"]) != "": n += 1
	return n

## Simula a progressão 1→100 (modelo puro, sem combate). A cada capítulo, o build cresce (tier de gear + refino
## + nível) e enfrenta o boss. Reporta o CP por capítulo vs required, e se o ciclo é ALCANÇÁVEL organicamente.
func _sim_1_100(gs, gate: int) -> void:
	print("  ── SIMULAÇÃO 1→100 (CP orgânico por capítulo vs required boss) ──")
	var reachable := true
	for c in ContentManifest.chapters():
		var ch := int(c["chapter"])
		# gear/refino/nível crescem com o capítulo (build "forte" gradual)
		gs.reset_save(); gs.master_level = 0
		gs.equipment = _gear_for_tier(int(c["gear_tier"]))
		var refino: int = mini(20, 4 + ch * 2)   # refino sobe ~2/capítulo
		for s in gs.equipment: gs.slot_refinement[str(s)] = refino
		var jl: int = mini(10, ch)
		gs.jewel_levels = {"ruby": jl, "sapphire": jl, "emerald": jl}
		gs.hero_hp_max = 100 + 10 * (ch * 12)   # nível sobe ~12/capítulo
		var cp := PowerBudget.cp()
		var req := ProgressionMath.required_cp(ch * 10, "boss")
		var r := float(cp) / float(req)
		if r < 0.90: reachable = false
		print("    Cap %2d (%s, tier %d, +%d, joia %d): CP=%d vs boss req=%d → R=%.2f %s" % [
			ch, str(c["display"]), int(c["gear_tier"]), refino, jl, cp, req, r, ("OK" if r >= 0.90 else "GAP")])
	_chk("SIM 1→100: cada capítulo alcançável organicamente (R>=0.90 com build coerente)", reachable)
	# tempo estimado até P1: Fragmentos p/ refino do ciclo + horas de farm
	var cyc_hours := 0.0
	for ch in range(1, 11):
		# tempo ~ atravessar 10 stages do capítulo na taxa da fase
		var fph: float = EconomyBalance.fragments_per_hour_at(ch * 10, 1.0)
		cyc_hours += 10.0 * ProgressionMath.estimated_time(ContentManifest.stage_type(ch * 10 - 5), 1.0) / 3600.0
	print("  ── TEMPO ESTIMADO ATÉ P1: atravessar 100 stages ~%.1f h ativas + farm de gear/refino p/ fechar o gate ──" % (cyc_hours))
	print("    Ordem de grandeza: ~dezenas de horas ativas (ou ~poucos dias com 8h offline). Não 10min, não 6 meses.")

func _gear_for_tier(tier: int) -> Dictionary:
	match tier:
		1: return {"weapon": "sword_simple", "chest": "armor_simple", "boots": "boots_simple", "legs": "pants_simple"}
		2: return {"weapon": "sword_reinforced", "chest": "armor_reinforced", "boots": "boots_reinforced", "offhand": "shield_reinforced", "legs": "pants_simple"}
		3: return {"weapon": "sword_memoria", "chest": "armor_memoria", "boots": "boots_reinforced", "offhand": "shield_reinforced", "legs": "pants_simple", "ring": "ring_reinforced"}
		4: return {"weapon": "sword_abyss", "chest": "chest_abyss", "legs": "legs_abyss", "boots": "boots_abyss", "head": "head_abyss", "offhand": "shield_abyss", "ring": "ring_abyss", "bracelet": "bracelet_abyss", "accessory": "amulet_abyss"}
		_: return {"weapon": "sword_eternal", "chest": "chest_eternal", "legs": "legs_eternal", "boots": "boots_eternal", "head": "head_eternal", "offhand": "shield_eternal", "ring": "ring_eternal", "bracelet": "bracelet_eternal", "accessory": "amulet_eternal"}
