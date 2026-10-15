extends SceneTree
## Self-test FATIA A17.6 — Auto Consumables / Auto Potions. FIXTURE: usa o GameState vivo com save override e restaura.

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1

var gs
func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a176_fixture_save.json"
	gs.set_save_path_override(fixture); var mem: Dictionary = gs.to_dict()

	var ac := AutoConsumables.new(); root.add_child(ac); ac.setup(gs)
	print("  ── AUTO_CONSUMABLES ──")
	# T01: HP baixo + poção → cura e consome
	gs.reset_save(); gs.hero_hp = 20; gs.hero_hp_max = 200; gs.backpack = [{"id": "potion_minor", "qty": 3}]
	var hp0 := int(gs.hero_hp)
	ac.tick(1.0)
	_chk("ACON-T01 HP baixo + poção → cura", int(gs.hero_hp) > hp0)
	_chk("ACON-T02 poção consumida (qty caiu)", gs.backpack_count("potion_minor") == 2)
	# T03: cooldown impede double no mesmo instante
	ac.tick(0.1)
	_chk("ACON-T03 cooldown evita spam (não consome de novo)", gs.backpack_count("potion_minor") == 2)
	# T04: HP cheio → não usa
	gs.reset_save(); gs.hero_hp = 200; gs.hero_hp_max = 200; gs.backpack = [{"id": "potion_minor", "qty": 2}]
	ac.tick(2.0)
	_chk("ACON-T04 HP cheio → não usa poção", gs.backpack_count("potion_minor") == 2)
	# T05: sem poção → no-op (sem crash)
	gs.reset_save(); gs.hero_hp = 10; gs.hero_hp_max = 200; gs.backpack = []
	ac.tick(2.0)
	_chk("ACON-T05 sem poção → no-op seguro", int(gs.hero_hp) == 10)
	# T06: herói morto (HP 0) → NÃO revive com poção
	gs.reset_save(); gs.hero_hp = 0; gs.hero_hp_max = 200; gs.backpack = [{"id": "potion_minor", "qty": 2}]
	ac.tick(2.0)
	_chk("ACON-T06 morto (HP 0) → poção NÃO revive", int(gs.hero_hp) == 0 and gs.backpack_count("potion_minor") == 2)
	# T07: escolhe a MAIOR cura disponível
	gs.reset_save(); gs.hero_hp = 20; gs.hero_hp_max = 500
	gs.backpack = [{"id": "potion_minor", "qty": 1}]   # só a menor existe
	ac.tick(2.0)
	_chk("ACON-T07 usa a cura disponível (potion_minor)", gs.backpack_count("potion_minor") == 0 and int(gs.hero_hp) > 20)
	# T08: mana baixa (classe de mana) → usa poção de mana
	gs.reset_save(); gs.mana_current = 5; gs.mana_max = 100; gs.hero_hp = 500; gs.hero_hp_max = 500
	gs.backpack = [{"id": "potion_mana", "qty": 2}]
	ac.tick(2.0)
	_chk("ACON-T08 mana baixa → usa poção de mana", int(gs.mana_current) > 5 and gs.backpack_count("potion_mana") == 1)
	# T09: mana cheia → não usa
	gs.reset_save(); gs.mana_current = 100; gs.mana_max = 100; gs.hero_hp = 500; gs.hero_hp_max = 500
	gs.backpack = [{"id": "potion_mana", "qty": 2}]
	ac.tick(2.0)
	_chk("ACON-T09 mana cheia → não usa", gs.backpack_count("potion_mana") == 2)
	# T10: desligado → não age
	ac.enabled = false
	gs.reset_save(); gs.hero_hp = 10; gs.hero_hp_max = 200; gs.backpack = [{"id": "potion_minor", "qty": 2}]
	ac.tick(2.0)
	_chk("ACON-T10 desligado → não usa nada", gs.backpack_count("potion_minor") == 2)
	ac.enabled = true
	# T11: telemetria (status)
	var st := ac.status()
	_chk("ACON-T11 status/telemetria expõe uso", int(st["hp_used"]) >= 1 and st.has("enabled"))
	# T12: só consumível (não usa item equipável por engano)
	gs.reset_save(); gs.hero_hp = 10; gs.hero_hp_max = 200; gs.backpack = [{"id": "sword_simple", "qty": 1}]
	ac.tick(2.0)
	_chk("ACON-T12 não usa item não-consumível", gs.backpack_count("sword_simple") == 1)

	ac.queue_free()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)
