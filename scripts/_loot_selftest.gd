extends SceneTree
## Self-test FATIA A3.5 — LootManager. Prova LOOT-T01..T14, SALV-T01..T05, SAVE35-T01..T05, o stress de
## 1.000 drops (0 protegido/upgrade perdido, sem estourar capacidade) e a projeção 8h. Snapshot/restore de
## GameState + save. Rodar:
##   godot --headless --path godot -s res://scripts/_loot_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1

func _new_lm():
	var lm = load("res://scripts/LootManager.gd").new()
	root.add_child(lm)
	lm.setup(null)
	return lm

func _count_in_backpack(id: String) -> int:
	var n := 0
	for e in _g().backpack:
		if str(e.get("id","")) == id:
			n += int(e.get("qty", 1))
	return n

func _count_in_overflow(id: String) -> int:
	var n := 0
	for e in _g().loot_overflow:
		if str(e.get("id","")) == id:
			n += int(e.get("qty", 1))
	return n

func _reset_inv(gs) -> void:
	gs.backpack.clear(); gs.loot_overflow.clear(); gs.locked_items.clear()
	gs.materials.erase("Fragmentos")
	gs.equipment = {}
	gs.hero_hp_max = 100; gs.hero_level = 1

func _initialize() -> void:
	var gs = root.get_node_or_null("GameState")
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()
	var mem: Dictionary = gs.to_dict()

	var lm = _new_lm()

	# ══════════ CLASSIFICAÇÃO ══════════
	_reset_inv(gs)
	gs.equipment = {"weapon": "sword_reinforced"}   # arma forte equipada (attack 11)
	_chk("LOOT-T01 quest/desconhecido → PROTECTED/UNKNOWN (não salvage)", lm.classify("zzz_inexistente") == lm.Cls.UNKNOWN and not lm.is_salvageable("zzz_inexistente"))
	gs.set_item_locked("dagger_rusty", true)
	_chk("LOOT-T02 locked → PROTECTED", lm.classify("dagger_rusty") == lm.Cls.PROTECTED and not lm.is_salvageable("dagger_rusty"))
	gs.set_item_locked("dagger_rusty", false)
	_chk("LOOT-T03 unknown → não auto-salvage (is_salvageable=false)", not lm.is_salvageable("zzz_inexistente"))
	# slot vazio (head) → item preservado (é upgrade)
	_chk("LOOT-T04 slot vazio → equipamento preservado (UPGRADE)", lm.classify("helmet_simple") == lm.Cls.UPGRADE)
	# projected maior → UPGRADE ; projected menor → SALVAGEABLE
	_chk("LOOT-T05 projected CP maior → UPGRADE (sword_memoria rare > reinforced)", lm.classify("sword_memoria") == lm.Cls.UPGRADE)
	_chk("LOOT-T06 projected CP menor + seguro → SALVAGEABLE (dagger < reinforced)", lm.classify("dagger_rusty") == lm.Cls.SALVAGEABLE)
	_chk("LOOT-T07 stackável → STACKABLE (poção)", lm.classify("potion_minor") == lm.Cls.STACKABLE)
	_chk("LOOT-T08 equipado nunca é salvaged", lm.classify("sword_reinforced") == lm.Cls.PROTECTED and not lm.is_salvageable("sword_reinforced"))

	# ══════════ INVENTÁRIO CHEIO ══════════
	# T09: cheio + lixo novo → salvage direto (não ocupa slot)
	_reset_inv(gs); gs.equipment = {"weapon": "sword_reinforced"}
	for i in range(lm.BACKPACK_CAPACITY):
		gs.backpack.append({"id": "armor_simple", "qty": 1})   # enche com itens quaisquer
	var frag0: int = int(gs.materials.get("Fragmentos", 0))
	var slots0: int = gs.backpack_slots_used()
	lm.receive_loot("dagger_rusty", 1)   # dagger é inferior → salvage direto
	_chk("LOOT-T09 cheio + lixo → salvage direto (slots inalterados, Fragmentos↑)", gs.backpack_slots_used() == slots0 and int(gs.materials.get("Fragmentos",0)) > frag0)

	# T10: cheio + UPGRADE novo → salva um candidato inferior e guarda o upgrade
	_reset_inv(gs); gs.equipment = {"weapon": "sword_simple"}   # arma MÉDIA equipada (≠ do lixo do backpack)
	for i in range(lm.BACKPACK_CAPACITY):
		gs.backpack.append({"id": "dagger_rusty", "qty": 1})    # 30 daggers (inferiores/salvageable; ≠ equipado)
	lm.receive_loot("sword_reinforced", 1)   # upgrade forte
	_chk("LOOT-T10 cheio + upgrade → salva inferior e guarda upgrade", _count_in_backpack("sword_reinforced") == 1 and gs.backpack_slots_used() <= lm.BACKPACK_CAPACITY)

	# T11: sem candidato seguro → overflow ; T12: overflow recebe protegido
	_reset_inv(gs); gs.equipment = {"weapon": "dagger_rusty"}
	gs.set_item_locked("ring_simple", true)
	for i in range(lm.BACKPACK_CAPACITY):
		gs.backpack.append({"id": "ring_simple", "qty": 1})    # 30 protegidos (locked) → make_room falha
	lm.receive_loot("sword_reinforced", 1)   # upgrade, mas nada salvageable p/ liberar
	_chk("LOOT-T11 sem candidato seguro → vai p/ overflow", _count_in_overflow("sword_reinforced") == 1)
	_chk("LOOT-T12 overflow recebe item protegido (upgrade)", gs.overflow_count() == 1)

	# T13: overflow nunca excede o cap silenciosamente
	_reset_inv(gs); gs.equipment = {"weapon": "dagger_rusty"}
	gs.set_item_locked("amulet_simple", true)
	for i in range(lm.OVERFLOW_CAP + 5):
		lm._to_overflow("amulet_simple", 1)   # protegido; overflow deve saturar em cap, sem crash
	_chk("LOOT-T13 overflow <= cap (%d)" % lm.OVERFLOW_CAP, gs.overflow_count() <= lm.OVERFLOW_CAP)

	# T14: espaço liberou → overflow drena
	_reset_inv(gs); gs.equipment = {}
	gs.overflow_push("helmet_simple", 1); gs.overflow_push("boots_simple", 1)
	lm.drain_overflow()
	_chk("LOOT-T14 espaço livre → overflow drena p/ mochila", gs.overflow_count() == 0 and gs.backpack_slots_used() == 2)

	# ══════════ SALVAGE ══════════
	_reset_inv(gs); gs.equipment = {"weapon": "sword_reinforced"}
	_chk("SALV-T01 salvage_value > 0 p/ equipamento elegível", lm.salvage_value("dagger_rusty") > 0)
	_chk("SALV-T02 raridade superior não vale menos (rare ≥ common)", lm.salvage_value("sword_memoria") >= lm.salvage_value("sword_simple"))
	_chk("SALV-T03 quest/locked/equipado → não salvageable", (not lm.is_salvageable("sword_reinforced")) and (func():gs.set_item_locked("dagger_rusty",true); var r=not lm.is_salvageable("dagger_rusty"); gs.set_item_locked("dagger_rusty",false); return r).call())
	# SALV-T04: salvage incrementa recurso EXATAMENTE uma vez pelo valor
	var f_before: int = int(gs.materials.get("Fragmentos", 0))
	var sv: int = lm.salvage_value("dagger_rusty")
	var kills0: int = lm.loot_salvaged
	lm._salvage_new("dagger_rusty")
	_chk("SALV-T04 salvage credita Fragmentos exatamente 1× (+%d)" % sv, int(gs.materials.get("Fragmentos",0)) == f_before + sv and lm.loot_salvaged == kills0 + 1)
	# SALV-T05: sem dup — receber 1 drop salvageable conta 1 salvage (não 2)
	var s_before: int = lm.loot_salvaged
	lm.receive_loot("dagger_rusty", 1)
	_chk("SALV-T05 1 drop salvageable = 1 salvage (sem dup)", lm.loot_salvaged == s_before + 1)

	# ══════════ SAVE35 (roundtrip + migração) ══════════
	_reset_inv(gs)
	gs.set_item_locked("sword_memoria", true)
	gs.overflow_push("helmet_reinforced", 2)
	gs.add_material_silent("Fragmentos", 123)
	var d: Dictionary = gs.to_dict().duplicate(true)   # deep copy (o save real faz round-trip JSON = deep copy)
	# zera e reaplica
	gs.locked_items.clear(); gs.loot_overflow.clear(); gs.materials.erase("Fragmentos")
	gs.apply_dict(d)
	_chk("SAVE35-T01 roundtrip lock preservado", gs.is_item_locked("sword_memoria"))
	_chk("SAVE35-T02 roundtrip overflow preservado", _count_in_overflow("helmet_reinforced") == 2)
	_chk("SAVE35-T03 roundtrip recurso salvage (Fragmentos) preservado", int(gs.materials.get("Fragmentos",0)) == 123)
	# T04/T05: migração v2 (sem loot) → v3 preserva tudo + adiciona vazios
	var SM := load("res://scripts/SaveMigration.gd")
	var v2 := {"schemaVersion": 2, "hero_level": 29, "current_region_id": "deep_dunes", "stage_mode": "farm"}
	var mig: Dictionary = SM.migrate_with(v2, 2, 3, SM._steps())
	_chk("SAVE35-T04 migração v2→v3 adiciona loot vazio, preserva campos", int(mig["schemaVersion"]) == 3 and mig.has("locked_items") and mig.has("loot_overflow") and int(mig["hero_level"]) == 29 and str(mig["stage_mode"]) == "farm")
	# aplica o migrado — não remove/altera campos antigos
	gs.apply_dict(mig)
	_chk("SAVE35-T05 save antigo migrado carrega sem perder campos (level 29, deep_dunes)", gs.hero_level == 29 and gs.current_region_id == "deep_dunes" and gs.locked_items.is_empty())

	# ══════════ STRESS 1.000 DROPS (farm contínuo) ══════════
	_reset_inv(gs); gs.equipment = {"weapon": "sword_simple"}   # arma MÉDIA equipada (≠ do lixo; upgrade = reinforced)
	gs.set_item_locked("amulet_simple", true)                    # item PROTEGIDO (locked)
	var lm2 = _new_lm()
	# mistura: 850 lixo (dagger, inferior) · 100 poção (stack) · 40 upgrade (sword_reinforced) · 10 protegido (amulet)
	var plan := []
	for i in range(850): plan.append("dagger_rusty")
	for i in range(100): plan.append("potion_minor")
	for i in range(40): plan.append("sword_reinforced")
	for i in range(10): plan.append("amulet_simple")
	# permutação determinística (sem RNG): stride 7 é coprimo com 1000 → bijeção (cobre todos os índices 1×).
	var order := []
	for i in range(plan.size()):
		order.append(plan[(i * 7) % plan.size()])
	var crashed := false
	var max_slots := 0
	var max_over := 0
	for id in order:
		lm2.receive_loot(id, 1)
		max_slots = maxi(max_slots, gs.backpack_slots_used())
		max_over = maxi(max_over, gs.overflow_count())
	var tel: Dictionary = lm2.telemetry()
	print("  [stress] recebidos=%d kept=%d salvaged=%d upgrades=%d overflow_add=%d rejeitados=%d fragmentos=%d" % [
		tel["loot_received"], tel["loot_kept"], tel["loot_salvaged"], tel["loot_upgrades"], tel["overflow_added"], tel["loot_rejected"], int(gs.materials.get("Fragmentos",0))])
	print("  [stress] pico mochila=%d/%d · pico overflow=%d/%d" % [max_slots, lm2.BACKPACK_CAPACITY, max_over, lm2.OVERFLOW_CAP])
	var amulet_total := _count_in_backpack("amulet_simple") + _count_in_overflow("amulet_simple")
	var sword_total := _count_in_backpack("sword_reinforced") + _count_in_overflow("sword_reinforced")
	_chk("STRESS 1000 drops processados (received=1000)", int(tel["loot_received"]) == 1000)
	_chk("STRESS 0 protegido perdido (amulet locked: %d/10)" % amulet_total, amulet_total == 10)
	_chk("STRESS 0 upgrade (melhor) perdido (sword_reinforced kept: %d)" % sword_total, sword_total >= 1)
	_chk("STRESS mochila nunca acima da capacidade (%d)" % max_slots, max_slots <= lm2.BACKPACK_CAPACITY)
	_chk("STRESS overflow <= cap (%d)" % max_over, max_over <= lm2.OVERFLOW_CAP)
	_chk("STRESS 0 rejeição / sem crash", int(tel["loot_rejected"]) == 0 and not crashed)
	_chk("STRESS pipeline continua (poções empilhadas=%d)" % _count_in_backpack("potion_minor"), _count_in_backpack("potion_minor") == 100)

	# ══════════ PROJEÇÃO 8H (economia) ══════════
	# taxa razoável: ~1 kill/2s no farm → ~1800 kills/h; ~40% dropam equipamento salvageable comum.
	var kills_h := 1800.0
	var junk_frac := 0.40
	var avg_frag := float(lm.salvage_value("dagger_rusty"))   # ~valor de um comum inferior
	var frag_h := kills_h * junk_frac * avg_frag
	print("  [projeção 8h] junk/h=%.0f · frag médio/item=%.0f · Fragmentos/h=%.0f · /8h=%.0f" % [kills_h*junk_frac, avg_frag, frag_h, frag_h*8.0])
	_chk("PROJ 8h plausível (< 10 milhões de Fragmentos, sem impressora)", frag_h * 8.0 < 10000000.0)

	# restaura
	gs.apply_dict(mem)
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

func _g():
	return root.get_node_or_null("GameState")
