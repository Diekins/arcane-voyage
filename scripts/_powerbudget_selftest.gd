extends SceneTree
## Self-test FATIA A3 — PowerBudget + ProgressionMath. Prova CP-T01..T10, DIFF-T01..T07 e a tabela de CP
## requerido. Snapshot/restore de GameState + save. Rodar:
##   godot --headless --path godot -s res://scripts/_powerbudget_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1

func _initialize() -> void:
	var gs = root.get_node_or_null("GameState")
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()
	var mem: Dictionary = gs.to_dict()

	# ── FIXTURE DETERMINÍSTICA: personagem inicial/default REAL (Nv1, desarmado, 100 HP, sem bônus) ──
	gs.hero_level = 1
	gs.hero_hp_max = 100
	gs.equipment = {}
	gs.proficiency = {}
	gs.class_mastery = {}

	# ── CP-T01 / CP-T02: CP positivo e no benchmark ~1000 ──
	var cp0 := PowerBudget.cp()
	var bd: Dictionary = PowerBudget.breakdown()
	print("  [benchmark] default: expected=%.2f aps=%.3f offense=%.2f maxhp=%d mitig=%.3f ehp=%.2f raw=%.2f CP=%d" % [
		bd["expected_damage"], bd["attacks_per_second"], bd["offense_dps"], bd["max_hp"], bd["mitigation_factor"], bd["effective_hp"], bd["raw_power"], bd["cp"]])
	_chk("CP-T01 CP default > 0", cp0 > 0)
	_chk("CP-T02 benchmark 900..1100 (obtido %d)" % cp0, cp0 >= 900 and cp0 <= 1100)

	# ── CP-T09: determinístico (mesmo estado → mesmo CP) ──
	_chk("CP-T09 determinístico (2 chamadas iguais)", PowerBudget.cp() == cp0)

	# ── CP-T03: aumentar ATAQUE real aumenta CP (equipa arma) ──
	var sword := _find_weapon("sword")
	gs.equipment = {"weapon": sword}
	var cp_sword := PowerBudget.cp()
	_chk("CP-T03 equipar espada (ataque real ↑) aumenta CP (%d → %d)" % [cp0, cp_sword], cp_sword > cp0)

	# ── CP-T07: arquétipo por definição real (weapon_kind), não nome ──
	_chk("CP-T07 arquétipo via ItemDB (espada → melee)", gs.current_combat_archetype() == "melee")
	var bow := _find_weapon("bow")
	gs.equipment = {"weapon": bow}
	_chk("CP-T07b arco → ranged (definição, não nome)", gs.current_combat_archetype() == "ranged")
	gs.equipment = {}

	# ── CP-T04: aumentar HP real aumenta CP ──
	var cp_hp0 := PowerBudget.cp()
	gs.hero_hp_max = 200
	var cp_hp1 := PowerBudget.cp()
	gs.hero_hp_max = 100
	_chk("CP-T04 +HP real aumenta CP (%d → %d)" % [cp_hp0, cp_hp1], cp_hp1 > cp_hp0)

	# ── CP-T05: aumentar MITIGAÇÃO real (defesa via item) aumenta CP ──
	var shield := _find_item_with_stat("defense")
	if shield != "":
		var cp_def0 := PowerBudget.cp()
		gs.equipment = {shield_slot(shield): shield}
		var cp_def1 := PowerBudget.cp()
		gs.equipment = {}
		_chk("CP-T05 +defesa real (mitigação ↑) aumenta CP (%d → %d)" % [cp_def0, cp_def1], cp_def1 > cp_def0)
	else:
		_chk("CP-T05 (sem item de defesa no ItemDB — pulado)", true)

	# ── CP-T06: média geométrica — dobrar SÓ ofensa NÃO dobra o CP ──
	# base equilibrado
	gs.equipment = {}; gs.hero_hp_max = 100
	var cp_base := PowerBudget.raw_power()
	# dobra a ofensa artificialmente via arma de muito ataque, defesa miserável (sem HP extra)
	var strong := _find_weapon("hammer")   # martelo: +16 ataque
	gs.equipment = {"weapon": strong}
	var raw_offheavy := PowerBudget.raw_power()
	var off_ratio := PowerBudget.offense() / maxf(0.001, _offense_base())
	gs.equipment = {}
	# o RAW não cresce proporcional à ofensa (média geométrica segura)
	_chk("CP-T06 dobrar ofensa não dobra o poder (raw %.1f→%.1f, offense ×%.2f)" % [cp_base, raw_offheavy, off_ratio], raw_offheavy < cp_base * off_ratio)

	# ── CP-T08: expected damage não usa RNG ──
	seed(77); var a := randi()
	seed(77); for i in range(500): PowerBudget.expected_damage_per_attack()
	var b := randi()
	_chk("CP-T08 expected_damage não consome RNG", a == b)

	# ── CP-T10: breakdown coerente (raw = sqrt(offense×ehp), cp = round(raw×scale)) ──
	gs.equipment = {}; gs.hero_hp_max = 100
	var bd2: Dictionary = PowerBudget.breakdown()
	var raw_check: float = sqrt(float(bd2["offense_dps"]) * float(bd2["effective_hp"]))
	var cp_check := int(round(raw_check * PowerBudget.CP_DISPLAY_SCALE))
	_chk("CP-T10 breakdown fecha (raw e cp derivados)", abs(raw_check - float(bd2["raw_power"])) < 0.01 and cp_check == int(bd2["cp"]))

	# ══════════ ProgressionMath — DIFF + curva ══════════
	# ── DIFF-T01: stage 1 scale ~1 ──
	_chk("DIFF-T01 stage 1 scale ≈ 1.0", abs(ProgressionMath.stage_scale(1) - 1.0) < 0.0001)
	# ── DIFF-T02: stage 26 contém wall multiplier (×1.12) ──
	var w1 := ProgressionMath.wall_multiplier(25); var w26 := ProgressionMath.wall_multiplier(26)
	_chk("DIFF-T02 wall 25→26 aplica ×1.12 (%.4f → %.4f)" % [w1, w26], abs(w1 - 1.0) < 0.0001 and abs(w26 - 1.12) < 0.0001)
	# ── DIFF-T03/T04: HP e dano normais escalam ──
	var s20 := ProgressionMath.scale_mob_stats(100, 10, 20, 20, "normal")
	_chk("DIFF-T03 HP normal escala (100 → %d)" % int(s20["max_hp"]), int(s20["max_hp"]) > 100)
	_chk("DIFF-T04 dano normal escala (10/20 → %d/%d)" % [int(s20["damage_min"]), int(s20["damage_max"])], int(s20["damage_min"]) > 10 and int(s20["damage_max"]) > 20)
	# ── DIFF-T05: mini-boss ×2.2 HP / ×1.15 dano (base grande p/ o ruído de arredondamento sumir) ──
	var n5 := ProgressionMath.scale_mob_stats(100000, 50000, 100000, 5, "normal")
	var mb5 := ProgressionMath.scale_mob_stats(100000, 50000, 100000, 5, "miniboss")
	_chk("DIFF-T05 mini-boss HP ×2.2 e dano ×1.15", abs(float(mb5["max_hp"]) / float(n5["max_hp"]) - 2.2) < 0.001 and abs(float(mb5["damage_max"]) / float(n5["damage_max"]) - 1.15) < 0.001)
	# ── DIFF-T06: boss ×4 HP / ×1.30 dano ──
	var n10 := ProgressionMath.scale_mob_stats(100000, 50000, 100000, 10, "normal")
	var b10 := ProgressionMath.scale_mob_stats(100000, 50000, 100000, 10, "boss")
	_chk("DIFF-T06 boss HP ×4 e dano ×1.30", abs(float(b10["max_hp"]) / float(n10["max_hp"]) - 4.0) < 0.001 and abs(float(b10["damage_max"]) / float(n10["damage_max"]) - 1.30) < 0.001)
	# ── DIFF-T07: config base imutável / scaling não acumula ──
	var base_hp := 100
	var at20a := ProgressionMath.scale_mob_stats(base_hp, 10, 20, 20, "normal")
	var at30 := ProgressionMath.scale_mob_stats(base_hp, 10, 20, 30, "normal")
	var at20b := ProgressionMath.scale_mob_stats(base_hp, 10, 20, 20, "normal")   # re-deriva do MESMO base
	_chk("DIFF-T07 scaling não acumula (stage20 igual antes/depois do stage30)", int(at20a["max_hp"]) == int(at20b["max_hp"]) and int(at20a["max_hp"]) != int(at30["max_hp"]))

	# ── TABELA de CP requerido (relatório) + monotonicidade + mini/boss > normal ──
	print("  [tabela required CP]")
	var last := -1
	var mono := true
	for n in [1, 10, 25, 26, 50, 51, 100, 150, 200, 250, 300]:
		var rn := ProgressionMath.required_cp(n, "normal")
		if rn <= last: mono = false
		last = rn
		print("    n=%-4d normal=%-12d mini=%-12d boss=%-12d" % [n, rn, ProgressionMath.required_cp(n, "miniboss"), ProgressionMath.required_cp(n, "boss")])
	_chk("CURVE required CP cresce sempre (monotônica)", mono)
	_chk("CURVE mini > normal e boss > mini (n=100)", ProgressionMath.required_cp(100, "miniboss") > ProgressionMath.required_cp(100, "normal") and ProgressionMath.required_cp(100, "boss") > ProgressionMath.required_cp(100, "miniboss"))
	_chk("CURVE valores dentro de int seguro (n=300)", ProgressionMath.required_cp(300, "boss") < 9223372036854775807)

	# ── ratio bands + speed/cph (funções puras) ──
	_chk("BAND R=0.5→MUITO FRACO", ProgressionMath.ratio_band(0.5) == "MUITO FRACO")
	_chk("BAND R=1.1→ADEQUADO", ProgressionMath.ratio_band(1.1) == "ADEQUADO")
	_chk("BAND R=2.5→DOMINANDO", ProgressionMath.ratio_band(2.5) == "DOMINANDO")
	_chk("SPEED clamp [0.75,2.5]", ProgressionMath.speed_factor(0.01) == 0.75 and ProgressionMath.speed_factor(100.0) == 2.5)
	_chk("CPH pura > 0", ProgressionMath.cycles_per_hour("normal", 1.0) > 0.0)

	# ══════════ PowerAdvisor — infra de delta (§29) + sugestões honestas (§28/§30) ══════════
	gs.equipment = {}; gs.hero_hp_max = 100
	# project_level_up: +10 HP máx → delta > 0
	var plu: Dictionary = PowerAdvisor.project_level_up()
	_chk("ADVISOR project_level_up expõe current/projected/delta > 0", plu.has("current_cp") and plu.has("projected_cp") and int(plu["delta_cp"]) > 0)
	# project_equipment: equipar espada projeta CP maior SEM tocar o save real
	var sword2 := _find_weapon("sword")
	var cp_now := PowerBudget.cp()
	var pe: Dictionary = PowerAdvisor.project_equipment({"weapon": sword2})
	_chk("ADVISOR project_equipment não muta o real (CP inalterado após)", PowerBudget.cp() == cp_now and int(pe["delta_cp"]) > 0)
	# suggest com uma arma melhor na mochila → sugere equipá-la (ganho > 0)
	gs.backpack = [{"id": sword2, "qty": 1}]
	var sug: Array = PowerAdvisor.suggest(3)
	var has_equip := false
	for s in sug:
		if str(s.get("kind", "")) == "equip" and int(s.get("estimated_cp_gain", 0)) > 0:
			has_equip = true
	_chk("ADVISOR suggest recomenda equipar a arma melhor da mochila", has_equip)
	# fallback honesto: sem mochila e (forçando) sem ganho de nível não deve inventar sistema inexistente
	gs.backpack = []
	var sug2: Array = PowerAdvisor.suggest(3)
	_chk("ADVISOR suggest sempre devolve algo (fallback honesto ou nível)", sug2.size() >= 1)

	# restaura
	gs.apply_dict(mem)
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

func _offense_base() -> float:
	# ofensa do estado base (desarmado) — recomputa desarmado
	var gs = root.get_node_or_null("GameState")
	var orig = gs.equipment
	gs.equipment = {}
	var o = PowerBudget.offense()
	gs.equipment = orig
	return o

func _find_weapon(kind: String) -> String:
	for id in ItemDB.ITEMS.keys():
		if str(ItemDB.ITEMS[id].get("weapon_kind", "")) == kind:
			return str(id)
	return ""

func _find_item_with_stat(stat: String) -> String:
	for id in ItemDB.ITEMS.keys():
		var it: Dictionary = ItemDB.ITEMS[id]
		if str(it.get("slot", "")) != "" and str(it.get("slot", "")) != "weapon" and int(it.get(stat, 0)) > 0:
			return str(id)
	return ""

func shield_slot(id: String) -> String:
	return str(ItemDB.ITEMS[id].get("slot", "offhand"))
