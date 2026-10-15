class_name ItemSourceRegistry extends RefCounted
## A22.1 — "COMO OBTENHO ESTE ITEM?" num só lugar. Índice DERIVADO das definições existentes (MobEligibility /
## BossActivityDefinition / AfkMissionDefinition) — REFERENCIA a fonte, NÃO duplica a chance de drop (single drop
## truth §A22.1). Construído 1× (lazy cache), indexado por item_key (id de gear OU nome de material).

const MOB_DROP := "MOB_DROP"
const BOSS_DROP := "BOSS_DROP"
const MISSION_REWARD := "MISSION_REWARD"
const SALVAGE := "SALVAGE"
const CRAFT := "CRAFT"      # foundation (informativa se houver receita real)
const SHOP := "SHOP"        # foundation
const EVENT := "EVENT"      # foundation

static var _index: Dictionary = {}     # item_key -> Array[source entry]
static var _built := false

static func _ensure() -> void:
	if _built: return
	_index = {}
	# ── MOB_DROP: materiais + gear pools de cada mob (a chance real fica na loot_profile do mob) ──
	for mob_id in MobEligibility.MOBS:
		var m: Dictionary = MobEligibility.MOBS[mob_id]
		var lp: Dictionary = m.get("loot_profile", {})
		var hunts: Array = m.get("allowed_hunts", [])
		var ground := str(hunts[0]) if hunts.size() > 0 else ""
		var mat: Dictionary = lp.get("material", {})
		if not mat.is_empty():
			_add(str(mat.get("name", "")), {"source_type": MOB_DROP, "mob_id": mob_id, "ground_id": ground,
				"activity_link": "TARGETED_HUNT", "chance_label": _label(float(mat.get("chance", 0.0)))})
		for gid in lp.get("gear_pool", []):
			_add(str(gid), {"source_type": MOB_DROP, "mob_id": mob_id, "ground_id": ground,
				"activity_link": "TARGETED_HUNT", "chance_label": _label(float(lp.get("gear_chance", 0.0)))})
	# ── BOSS_DROP: first-clear garantido por família de arma + universal ──
	for boss_id in BossActivityDefinition.BOSSES:
		var b: Dictionary = BossActivityDefinition.BOSSES[boss_id]
		var rp: Dictionary = b.get("reward_profile", {}).get("first_clear", {})
		if bool(rp.get("guaranteed_gear_by_weapon", false)):
			for wk in ["sword", "bow", "staff", "spear", "book"]:   # A30: book incluído (support ganha gear garantido de 1ª vitória)
				var gid := BossActivityDefinition.guaranteed_gear_for_weapon(wk)
				if gid != "":
					_add(gid, {"source_type": BOSS_DROP, "boss_id": boss_id, "activity_link": "BOSS_FIGHT",
						"chance_label": "Garantido (1ª vitória)", "first_clear": true})
	# ── MISSION_REWARD: item/material de completion + special drop ──
	for mid in AfkMissionDefinition.MISSIONS:
		var mm: Dictionary = AfkMissionDefinition.MISSIONS[mid]
		var cr: Dictionary = mm.get("completion_reward_profile", {})
		if cr.has("item"):
			_add(str(cr["item"]), {"source_type": MISSION_REWARD, "mission_id": mid, "activity_link": "MISSION",
				"chance_label": "Garantido (conclusão)"})
		var crm: Dictionary = cr.get("material", {})
		if not crm.is_empty():
			_add(str(crm.get("name", "")), {"source_type": MISSION_REWARD, "mission_id": mid, "activity_link": "MISSION",
				"chance_label": "Garantido (conclusão)"})
		var sd: Dictionary = mm.get("special_drop_profile", {})
		if not sd.is_empty():
			_add(str(sd.get("material", sd.get("name", ""))), {"source_type": MISSION_REWARD, "mission_id": mid, "activity_link": "MISSION",
				"chance_label": _label(float(sd.get("chance", 0.05)))})
	# ── HUNT_APEX/HUNT_LOOT: gear dos pools de HuntingGround (loot_profile + apex_profile). Gate = unlock_rule do ground
	#    (min_cp por capítulo). A30: fecha o buraco onde *_eternal do pool apex ficava SEM fonte no índice (COMO OBTER vazio). ──
	for ground_id in HuntingGround.GROUNDS:
		var g: Dictionary = HuntingGround.GROUNDS[ground_id]
		var lp2: Dictionary = g.get("loot_profile", {})
		for gid2 in lp2.get("pool", []):
			if ItemDB.is_equippable(str(gid2)):
				_add(str(gid2), {"source_type": MOB_DROP, "ground_id": ground_id, "activity_link": "TARGETED_HUNT",
					"chance_label": _label(float(lp2.get("drop_chance", 0.0))), "hunt_pool": "loot"})
		var ap: Dictionary = g.get("apex_profile", {})
		for gid3 in ap.get("pool", []):
			if ItemDB.is_equippable(str(gid3)):
				_add(str(gid3), {"source_type": MOB_DROP, "ground_id": ground_id, "activity_link": "TARGETED_HUNT",
					"chance_label": _label(float(ap.get("chance", 0.0))), "hunt_pool": "apex"})
	# ── SALVAGE: Fragmentos vêm de desmontar equipamento (não de mob fictício) ──
	_add("Fragmentos", {"source_type": SALVAGE, "activity_link": "INVENTORY", "chance_label": "Ao desmontar equipamento"})
	_built = true

static func _add(item_key: String, entry: Dictionary) -> void:
	if item_key == "": return
	if not _index.has(item_key): _index[item_key] = []
	# dedup por (type, mob/boss/mission)
	var sig := "%s|%s|%s|%s|%s" % [str(entry.get("source_type", "")), str(entry.get("mob_id", "")), str(entry.get("boss_id", "")), str(entry.get("mission_id", "")), str(entry.get("ground_id", ""))]
	for e in _index[item_key]:
		if "%s|%s|%s|%s|%s" % [str(e.get("source_type", "")), str(e.get("mob_id", "")), str(e.get("boss_id", "")), str(e.get("mission_id", "")), str(e.get("ground_id", ""))] == sig:
			return
	entry["item_key"] = item_key
	_index[item_key].append(entry)

static func _label(chance: float) -> String:
	if chance >= 0.5: return "Comum"
	if chance >= 0.2: return "Incomum"
	if chance >= 0.08: return "Raro"
	if chance > 0.0: return "Muito Raro"
	return "Desconhecido"

## Fontes CRUAS de um item (sem contexto de player). Array vazio se o item não tem fonte conhecida.
static func sources_for(item_key: String) -> Array:
	_ensure()
	return (_index.get(item_key, []) as Array).duplicate(true)

static func has_source(item_key: String) -> bool:
	_ensure(); return _index.has(item_key)

## Todos os item_keys indexados (para testes/perf).
static func all_keys() -> Array:
	_ensure(); return _index.keys()

static func invalidate() -> void:
	_built = false; _index = {}
