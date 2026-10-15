class_name HuntingGround extends RefCounted
## FATIA A16.2 — HuntingGroundDefinition (§33/§34). ★ WORLD CONTENT RULE: STAGE ≠ MAP. Uma ground = ambiente + perfil
## de dificuldade/mob/loot; VÁRIAS grounds podem reutilizar o MESMO map_id (§34). Mob table WEIGHTED data-driven
## (§39, sem if gigante). Elite/Apex são ARQUITETURA config-driven; a AUTORIDADE decide o roll (§40) — taxas finais
## = HUNT_*_CALIBRATION_REQUIRED. Não coloca imagem (§33). Puro/data.

const GROUNDS := {
	"HG_PLAINS_LOW": {
		"display_name_key": "CANON_REVIEW_REQUIRED", "map_id": "MAP_PLAINS",
		"unlock_rule": {"min_cp": 0, "min_stage": 1}, "recommended_cp": 1500,
		"mob_table": [
			{"mob_id": "young_wolf", "weight": 50, "base_xp": 12, "base_gold": 4},
			{"mob_id": "wild_boar", "weight": 35, "base_xp": 14, "base_gold": 5},
			{"mob_id": "road_bandit", "weight": 15, "base_xp": 20, "base_gold": 8},
		],
		"difficulty_profile": {"hp_mult": 1.0, "dmg_mult": 1.0}, "xp_profile": {"mult": 1.0},
		"loot_profile": {"drop_chance": 0.20, "pool": ["sword_simple", "shield_simple", "potion_minor"]},
		"elite_profile": {"chance": 0.04, "hp_mult": 2.2, "dmg_mult": 1.15, "xp_mult": 3.0, "drop_mult": 2.0},
		"apex_profile": {"chance": 0.004, "cap": 1, "hp_mult": 4.0, "xp_mult": 8.0, "pool": ["sword_eternal"]},
		"offline_profile": {"kills_per_hour": 600}, "enabled": true,
	},
	"HG_PLAINS_HIGH": {   # MESMO map, perfil mais difícil (§34)
		"display_name_key": "CANON_REVIEW_REQUIRED", "map_id": "MAP_PLAINS",
		"unlock_rule": {"min_cp": 8000, "min_stage": 30}, "recommended_cp": 12000,
		"mob_table": [
			{"mob_id": "road_bandit", "weight": 60, "base_xp": 40, "base_gold": 16},
			{"mob_id": "wild_boar", "weight": 40, "base_xp": 36, "base_gold": 14},
		],
		"difficulty_profile": {"hp_mult": 3.0, "dmg_mult": 2.0}, "xp_profile": {"mult": 3.0},
		"loot_profile": {"drop_chance": 0.25, "pool": ["chest_eternal", "sword_eternal", "potion_mana"]},
		"elite_profile": {"chance": 0.05, "hp_mult": 2.4, "dmg_mult": 1.2, "xp_mult": 3.2, "drop_mult": 2.0},
		"apex_profile": {"chance": 0.005, "cap": 1, "hp_mult": 4.5, "xp_mult": 9.0, "pool": ["staff_eternal"]},
		"offline_profile": {"kills_per_hour": 500}, "enabled": true,
	},
	"HG_CAVE": {
		"display_name_key": "CANON_REVIEW_REQUIRED", "map_id": "MAP_CAVE",
		"unlock_rule": {"min_cp": 3000, "min_stage": 11}, "recommended_cp": 5000,
		"mob_table": [
			{"mob_id": "crystal_bat", "weight": 55, "base_xp": 22, "base_gold": 9},
			{"mob_id": "living_shard", "weight": 45, "base_xp": 26, "base_gold": 11},
		],
		"difficulty_profile": {"hp_mult": 1.8, "dmg_mult": 1.4}, "xp_profile": {"mult": 1.8},
		"loot_profile": {"drop_chance": 0.22, "pool": ["staff_simple", "book_simple", "potion_minor"]},
		"elite_profile": {"chance": 0.045, "hp_mult": 2.3, "dmg_mult": 1.18, "xp_mult": 3.1, "drop_mult": 2.0},
		"apex_profile": {"chance": 0.004, "cap": 1, "hp_mult": 4.2, "xp_mult": 8.5, "pool": ["chest_eternal"]},
		"offline_profile": {"kills_per_hour": 450}, "enabled": true,
	},
	# A26 CHAPTER 3 — caça da MATA (spiders). MAP_PLAINS REUSADO (sem mapa novo). Alvo específico via Targeted Hunt.
	"HG_GROVE": {
		"display_name_key": "CANON_REVIEW_REQUIRED", "map_id": "MAP_PLAINS",
		"unlock_rule": {"min_cp": 12000, "min_stage": 20}, "recommended_cp": 18000,
		"mob_table": [
			{"mob_id": "grove_spider", "weight": 55, "base_xp": 40, "base_gold": 12},
			{"mob_id": "veil_spider", "weight": 45, "base_xp": 52, "base_gold": 16},
		],
		"difficulty_profile": {"hp_mult": 2.6, "dmg_mult": 1.7}, "xp_profile": {"mult": 2.6},
		"loot_profile": {"drop_chance": 0.22, "pool": ["dagger_rusty", "amulet_simple", "potion_minor"]},
		"elite_profile": {"chance": 0.045, "hp_mult": 2.4, "dmg_mult": 1.2, "xp_mult": 3.2, "drop_mult": 2.0},
		"apex_profile": {"chance": 0.004, "cap": 1, "hp_mult": 4.4, "xp_mult": 9.0, "pool": ["chest_eternal"]},
		"offline_profile": {"kills_per_hour": 380}, "enabled": true,
	},
	# A29 CHAPTER 4 — caça da COSTA DO SAL-VENTO (dune_skitter/salt_husk/tide_warden). MAP_SALT_COAST (região nova).
	"HG_SALT_WIND_COAST": {
		"display_name_key": "CANON_REVIEW_REQUIRED", "map_id": "MAP_SALT_COAST",
		"unlock_rule": {"min_cp": 30000, "min_stage": 30}, "recommended_cp": 45000,
		"mob_table": [
			{"mob_id": "dune_skitter", "weight": 45, "base_xp": 60, "base_gold": 16},
			{"mob_id": "salt_husk", "weight": 35, "base_xp": 78, "base_gold": 22},
			{"mob_id": "tide_warden", "weight": 20, "base_xp": 96, "base_gold": 28},
		],
		"difficulty_profile": {"hp_mult": 3.4, "dmg_mult": 2.1}, "xp_profile": {"mult": 3.4},
		"loot_profile": {"drop_chance": 0.22, "pool": ["staff_reinforced", "amulet_simple", "potion_minor"]},
		"elite_profile": {"chance": 0.05, "hp_mult": 2.5, "dmg_mult": 1.2, "xp_mult": 3.4, "drop_mult": 2.0},
		# A30 — apex costeiro (Ch4-gated por min_cp 30000) dá o tier5 de TODA família: paridade real de oportunidade.
		# ranged/reach/support tinham teto no reinforced; agora bow/spear/book_eternal saem daqui como sword/staff_eternal saem dos grounds antigos.
		"apex_profile": {"chance": 0.004, "cap": 1, "hp_mult": 4.6, "xp_mult": 9.5, "pool": ["chest_eternal", "bow_eternal", "spear_eternal", "book_eternal"]},
		"offline_profile": {"kills_per_hour": 320}, "enabled": true,
	},
	# A42 CHAPTER 5 — caça do NINHO DAS RAÍZES ANTIGAS (família RAIZ). MAP_ROOT_NEST (região nova, tileset real).
	# GATE por completion do Ch4 (§29): requires_flag GP_CHAPTER_4_SALTWIND_COMPLETE (o gate técnico existe mesmo com o
	# boss visual do Ch4 chegando). Pesos variados (§15). NORMAL/VETERAN via HuntHost.start(difficulty). Boss (MATRIARCA
	# DAS RAÍZES) = A44, NÃO aqui. Apex costeiro-equivalente dá tier5 (paridade de família §30, como HG_SALT_WIND_COAST).
	"HG_ROOT_NEST": {
		"display_name_key": "CANON_REVIEW_REQUIRED", "map_id": "MAP_ROOT_NEST",
		"unlock_rule": {"min_cp": 60000, "min_stage": 30, "requires_flag": "GP_CHAPTER_4_SALTWIND_COMPLETE"},
		"recommended_cp": 90000,
		"mob_table": [
			{"mob_id": "shadow_sprout", "weight": 30, "base_xp": 120, "base_gold": 32},
			{"mob_id": "root_spider", "weight": 28, "base_xp": 138, "base_gold": 36},
			{"mob_id": "sap_eye", "weight": 22, "base_xp": 150, "base_gold": 40},
			{"mob_id": "hungry_root", "weight": 14, "base_xp": 168, "base_gold": 46},
			{"mob_id": "musgo_voraz", "weight": 6, "base_xp": 190, "base_gold": 54},
		],
		"difficulty_profile": {"hp_mult": 4.0, "dmg_mult": 2.4}, "xp_profile": {"mult": 4.0},
		"loot_profile": {"drop_chance": 0.22, "pool": ["armor_reinforced", "boots_reinforced", "ring_reinforced", "potion_minor"]},
		"elite_profile": {"chance": 0.05, "hp_mult": 2.6, "dmg_mult": 1.22, "xp_mult": 3.5, "drop_mult": 2.0},
		"apex_profile": {"chance": 0.004, "cap": 1, "hp_mult": 4.8, "xp_mult": 10.0, "pool": ["chest_eternal", "sword_eternal", "staff_eternal", "spear_eternal"]},
		"offline_profile": {"kills_per_hour": 280}, "enabled": true,
	},
}

## A42 §29 — flag de story exigida p/ desbloquear (além de cp/stage). "" = sem requisito. O caller (gs-aware) confere.
static func required_flag(ground_id: String) -> String:
	return str(GROUNDS.get(ground_id, {}).get("unlock_rule", {}).get("requires_flag", ""))

static func exists(ground_id: String) -> bool: return GROUNDS.has(ground_id)
static func get_ground(ground_id: String) -> Dictionary: return GROUNDS.get(ground_id, {}).duplicate(true)
static func map_of(ground_id: String) -> String: return str(GROUNDS.get(ground_id, {}).get("map_id", ""))
static func all_ids() -> Array: return GROUNDS.keys()

## Grounds que reutilizam um map_id (prova STAGE≠MAP §34).
static func grounds_on_map(map_id: String) -> Array:
	var out: Array = []
	for gid in GROUNDS:
		if str(GROUNDS[gid]["map_id"]) == map_id: out.append(gid)
	return out

## Unlock por CP + stage (§33 unlock_rule). Server-authoritative.
static func is_unlocked(ground_id: String, cp: int, highest_stage: int) -> bool:
	if not exists(ground_id): return false
	var u: Dictionary = GROUNDS[ground_id]["unlock_rule"]
	return bool(GROUNDS[ground_id]["enabled"]) and cp >= int(u.get("min_cp", 0)) and highest_stage >= int(u.get("min_stage", 1))

## Seleção de mob por peso (§39), com um roll determinístico 0..1.
static func roll_mob(ground_id: String, roll01: float) -> Dictionary:
	var table: Array = GROUNDS.get(ground_id, {}).get("mob_table", [])
	if table.is_empty(): return {}
	var total := 0.0
	for e in table: total += float(e["weight"])
	var pick := clampf(roll01, 0.0, 0.999999) * total
	var acc := 0.0
	for e in table:
		acc += float(e["weight"])
		if pick < acc: return (e as Dictionary).duplicate(true)
	return (table[-1] as Dictionary).duplicate(true)

## Recomenda uma ground p/ um CP (§105) — a mais difícil DESBLOQUEADA cujo recommended_cp ≤ cp*1.2 (não a mais difícil sempre).
static func recommend_for(cp: int, highest_stage: int) -> String:
	var best := ""
	var best_rec := -1
	for gid in GROUNDS:
		if not is_unlocked(gid, cp, highest_stage): continue
		var rec := int(GROUNDS[gid]["recommended_cp"])
		if rec <= int(float(cp) * 1.2) and rec > best_rec:
			best_rec = rec; best = gid
	return best
