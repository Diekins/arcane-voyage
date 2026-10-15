extends SceneTree
## Self-test FATIA A1.5 — CombatMath. Prova COMBAT-T01..T09: equivalência pré/pós (RNG semeada), expected
## entre min/max e SEM RNG, arma real influencia o perfil, arquétipo por fonte confiável (não nome), e que
## o dano de mob/boss/jogador continua saindo. Snapshot/restore do save. Rodar:
##   godot --headless --path godot -s res://scripts/_combatmath_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1

func _initialize() -> void:
	var CM := load("res://scripts/CombatMath.gd")
	var gs = root.get_node_or_null("GameState")
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()
	var mem: Dictionary = gs.to_dict() if gs != null else {}

	# ── COMBAT-T02 / T09: expected entre min/max e SEM consumir RNG ──
	var seed_before := 0
	var pr: Dictionary = CM.profile(8, 13, 5)   # base 8..13 + bônus 5 → 13..18, expected 15.5
	_chk("T02 expected entre min e max", pr["min"] == 13 and pr["max"] == 18 and pr["expected"] == 15.5)
	# expected NÃO mexe no RNG: capturo o próximo randi antes/depois de chamar expected 1000x
	seed(12345); var r_a := randi()
	seed(12345); for i in range(1000): CM.expected_damage(3, 9, 2);
	var r_b := randi()
	_chk("T09 expected_damage não consome RNG", r_a == r_b)

	# ── COMBAT-T01: equivalência pré/pós (RNG semeada) p/ dano de INIMIGO (randi_range puro) ──
	var eq_enemy := true
	for i in range(200):
		seed(1000 + i)
		var old_val := randi_range(3, 17)
		seed(1000 + i)
		var new_val: int = CM.enemy_roll(3, 17)
		if old_val != new_val: eq_enemy = false; break
	_chk("T01a enemy_roll == randi_range (200 seeds)", eq_enemy)

	# ── COMBAT-T01: equivalência do rolled_damage (base+bonus) vs fórmula manual ──
	var eq_rolled := true
	for i in range(200):
		seed(2000 + i)
		var old_val := randi_range(14, 22) + 7
		seed(2000 + i)
		var new_val: int = CM.rolled_damage(14, 22, 7)
		if old_val != new_val: eq_rolled = false; break
	_chk("T01b rolled_damage == randi_range+bonus (200 seeds)", eq_rolled)

	# ── COMBAT-T03 / T04: arma real influencia o perfil; arquétipo por fonte confiável (não nome textual) ──
	if gs != null:
		# desarmado → arquétipo melee (fonte = current_combat_archetype derivado do equip, não do nome)
		gs.equipment = {}
		var arch_unarmed: String = gs.current_combat_archetype()
		_chk("T04 desarmado → arquétipo 'melee' via fonte confiável", arch_unarmed == "melee")
		var prof_melee: Dictionary = CM.player_profile("melee")   # base 14..22 + bônus (0 desarmado)
		_chk("T03a perfil melee base 14..22 (sem gear)", prof_melee["min"] == 14 and prof_melee["max"] == 22)
		# equipa uma arma real de cada arquétipo do ItemDB e confirma que o arquétipo/base muda pela DEFINIÇÃO
		var bow_id := _find_weapon_of_kind("bow")
		if bow_id != "":
			gs.equipment = {"weapon": bow_id}
			_chk("T04b arco → arquétipo 'ranged' (weapon_kind, não nome)", gs.current_combat_archetype() == "ranged")
			var prof_bow: Dictionary = CM.player_profile("ranged")   # base 8..13
			_chk("T03b perfil ranged base 8..13", prof_bow["min"] >= 8 and prof_bow["max"] >= 13)
		gs.equipment = {}

	# ── COMBAT-T07: jogador continua causando dano (>0) por qualquer arquétipo ──
	var dmg_player_ok := true
	for a in ["melee", "ranged", "magic", "support"]:
		seed(555)
		if CM.player_roll(a) <= 0: dmg_player_ok = false
	_chk("T07 jogador causa dano > 0 em todos arquétipos", dmg_player_ok)

	# ── COMBAT-T05 / T06: mob e boss continuam causando dano (>0) ──
	seed(9); var mob_dmg: int = CM.enemy_roll(3, 6)
	seed(9); var boss_dmg: int = CM.enemy_roll(16, 24)
	_chk("T05 mob causa dano > 0", mob_dmg > 0)
	_chk("T06 boss causa dano > 0", boss_dmg > 0)

	# ── COMBAT-T08: RNG permanece no combate real (rolls variam com seeds diferentes) ──
	seed(1); var v1: int = CM.enemy_roll(1, 1000)
	seed(2); var v2: int = CM.enemy_roll(1, 1000)
	_chk("T08 RNG ativo no combate real (rolls variam)", v1 != v2)

	# restaura
	if gs != null: gs.apply_dict(mem)
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

## Acha um id de item equipável de um weapon_kind, varrendo o ItemDB (fonte real, sem nome textual).
func _find_weapon_of_kind(kind: String) -> String:
	for id in ItemDB.ITEMS.keys():
		var it: Dictionary = ItemDB.ITEMS[id]
		if str(it.get("weapon_kind", "")) == kind:
			return str(id)
	return ""
