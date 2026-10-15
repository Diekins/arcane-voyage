class_name MobEligibility extends RefCounted
## FATIA A18.11 — ELEGIBILIDADE de mob por ATIVIDADE (§8/§A18.20). Nenhum mob nasce numa missão só por existir no
## catálogo: precisa de autorização EXPLÍCITA. Data-driven; sem global-random pool. Puro/testável.

# family/regions/maps/missions/hunts autorizados por mob. Mission_001..006 e o farm/hunt de lobo usam SÓ young_wolf
# (e a variante elite dele). Ampliar = adicionar dado aqui, nunca hardcode em Main.
const MOBS := {
	"young_wolf": {
		"family": "wolf", "combat_role": "melee", "visual_id": "young_wolf",
		"allowed_regions": ["plains"], "allowed_maps": ["MAP_PLAINS"],
		"allowed_missions": ["MISSION_001", "MISSION_002", "MISSION_003", "MISSION_004", "MISSION_005", "MISSION_006", "REPEATABLE_WOLF"],
		"allowed_hunts": ["HG_PLAINS_LOW", "HG_PLAINS_HIGH"],
		"spawn_profile": {"base_hp": 32, "base_dmg": 6, "attack_interval": 1.5},
		"loot_profile": {"gold": [3, 6], "material": {"name": "Presa de Lobo", "chance": 0.5, "qty": 1}, "gear_chance": 0.12, "gear_pool": ["dagger_rusty", "armor_simple", "boots_simple", "potion_minor"]},
		"xp_profile": {"base": 12},
		"audio_profile": {"aggro": "wolf_aggro", "attack": "wolf_attack", "hit": "wolf_hit", "death": "wolf_death"},
	},
	# A20 CHAPTER 2 — família CRISTAL (sprites reais: mobs/crystal_bat, mobs/living_shard; boss bosses/crystal_golem;
	# MAP_CAVE já existe no HuntingGround HG_CAVE). Conteúdo por DADO — nenhum asset novo.
	"crystal_bat": {
		"family": "crystal", "combat_role": "ranged", "visual_id": "crystal_bat",
		"allowed_regions": ["cave"], "allowed_maps": ["MAP_CAVE"],
		"allowed_missions": ["C2_M001", "C2_M002", "C2_M004", "C2_M006", "C2_M007", "C2_M008", "REPEATABLE_CRYSTAL"],
		"allowed_hunts": ["HG_CAVE"],
		"spawn_profile": {"base_hp": 40, "base_dmg": 8, "attack_interval": 1.3},
		"loot_profile": {"gold": [5, 9], "material": {"name": "Estilhaço de Cristal", "chance": 0.5, "qty": 1}, "gear_chance": 0.12, "gear_pool": ["staff_simple", "amulet_simple", "potion_mana", "boots_simple"]},
		"xp_profile": {"base": 22},
		"audio_profile": {"aggro": "bat_aggro", "attack": "bat_attack", "hit": "bat_hit", "death": "bat_death"},
	},
	"living_shard": {
		"family": "crystal", "combat_role": "melee", "visual_id": "living_shard",
		"allowed_regions": ["cave"], "allowed_maps": ["MAP_CAVE"],
		"allowed_missions": ["C2_M003", "C2_M005", "C2_M006", "C2_M008", "REPEATABLE_CRYSTAL"],
		"allowed_hunts": ["HG_CAVE"],
		"spawn_profile": {"base_hp": 60, "base_dmg": 11, "attack_interval": 1.6},
		"loot_profile": {"gold": [7, 12], "material": {"name": "Núcleo de Cristal", "chance": 0.45, "qty": 1}, "gear_chance": 0.14, "gear_pool": ["armor_reinforced", "ring_reinforced", "shield_simple", "potion_minor"]},
		"xp_profile": {"base": 30},
		"audio_profile": {"aggro": "shard_aggro", "attack": "shard_attack", "hit": "shard_hit", "death": "shard_death"},
	},
	# A26 CHAPTER 3 — família ARANHA (sprites reais: mobs/grove_spider, mobs/veil_spider; 3 direções). MAP_PLAINS
	# REUSADO (só existem MAP_PLAINS/MAP_CAVE — sem mapa inventado; background por-mapa = dívida Codex). Só DADO,
	# nenhum engine/ObjectiveType novo. Stats sobem (pós-Refine do Ch2). Boss #3 = contrato Codex (sprite não existe).
	"grove_spider": {
		"family": "spider", "combat_role": "melee", "visual_id": "grove_spider",
		"allowed_regions": ["grove"], "allowed_maps": ["MAP_PLAINS"],
		"allowed_missions": ["C3_M001", "C3_M002", "C3_M003", "C3_M005", "C3_M006", "C3_M008", "REPEATABLE_SPIDER"],
		"allowed_hunts": ["HG_GROVE"],
		"spawn_profile": {"base_hp": 90, "base_dmg": 16, "attack_interval": 1.4},
		"loot_profile": {"gold": [9, 15], "material": {"name": "Seda de Aranha", "chance": 0.5, "qty": 1}, "gear_chance": 0.13, "gear_pool": ["dagger_rusty", "boots_simple", "armor_simple", "potion_minor"]},
		"xp_profile": {"base": 40},
		"audio_profile": {"aggro": "spider_aggro", "attack": "spider_attack", "hit": "spider_hit", "death": "spider_death"},
	},
	"veil_spider": {
		"family": "spider", "combat_role": "ranged", "visual_id": "veil_spider",
		"allowed_regions": ["grove"], "allowed_maps": ["MAP_PLAINS"],
		"allowed_missions": ["C3_M004", "C3_M005", "C3_M006", "C3_M007", "C3_M008", "REPEATABLE_SPIDER"],
		"allowed_hunts": ["HG_GROVE"],
		"spawn_profile": {"base_hp": 120, "base_dmg": 20, "attack_interval": 1.7},
		"loot_profile": {"gold": [12, 20], "material": {"name": "Glândula de Veneno", "chance": 0.45, "qty": 1}, "gear_chance": 0.15, "gear_pool": ["amulet_simple", "ring_reinforced", "shield_simple", "potion_mana"]},
		"xp_profile": {"base": 52},
		"audio_profile": {"aggro": "veil_aggro", "attack": "veil_attack", "hit": "veil_hit", "death": "veil_death"},
	},
	# A29 CHAPTER 4 — COSTA DO SAL-VENTO (Region Pack 01). Sprites reais: mobs/dune_skitter(64²)/salt_husk(96²)/
	# tide_warden(96²). MAP_SALT_COAST (região nova, ground saltwind_shore/ground_painted). Elites = variantes (is_elite),
	# sem sprite dedicado. Stats sobem (pós-Ch3). Boss = candidate (salt_split_warden/carniceiro_areias, sem sprite). Só DADO.
	"dune_skitter": {
		"family": "saltwind", "combat_role": "ranged", "visual_id": "dune_skitter",
		"allowed_regions": ["salt_coast"], "allowed_maps": ["MAP_SALT_COAST"],
		"allowed_missions": ["C4_M001", "C4_M002", "C4_M003", "C4_M006", "C4_M008", "REPEATABLE_SALTWIND"],
		"allowed_hunts": ["HG_SALT_WIND_COAST"],
		"spawn_profile": {"base_hp": 140, "base_dmg": 24, "attack_interval": 1.3},
		"loot_profile": {"gold": [14, 22], "material": {"name": "Areia Vítrea", "chance": 0.5, "qty": 1}, "gear_chance": 0.13, "gear_pool": ["dagger_rusty", "boots_simple", "amulet_simple", "potion_minor"]},
		"xp_profile": {"base": 60},
		"audio_profile": {"aggro": "skitter_aggro", "attack": "skitter_attack", "hit": "skitter_hit", "death": "skitter_death"},
	},
	"salt_husk": {
		"family": "saltwind", "combat_role": "melee", "visual_id": "salt_husk",
		"allowed_regions": ["salt_coast"], "allowed_maps": ["MAP_SALT_COAST"],
		"allowed_missions": ["C4_M004", "C4_M005", "C4_M006", "C4_M007", "C4_M008", "REPEATABLE_SALTWIND"],
		"allowed_hunts": ["HG_SALT_WIND_COAST"],
		"spawn_profile": {"base_hp": 220, "base_dmg": 30, "attack_interval": 1.6},
		"loot_profile": {"gold": [18, 28], "material": {"name": "Casca de Sal", "chance": 0.45, "qty": 1}, "gear_chance": 0.15, "gear_pool": ["armor_reinforced", "shield_simple", "ring_reinforced", "potion_minor"]},
		"xp_profile": {"base": 78},
		"audio_profile": {"aggro": "husk_aggro", "attack": "husk_attack", "hit": "husk_hit", "death": "husk_death"},
	},
	"tide_warden": {
		"family": "saltwind", "combat_role": "ranged", "visual_id": "tide_warden",
		"allowed_regions": ["salt_coast"], "allowed_maps": ["MAP_SALT_COAST"],
		"allowed_missions": ["C4_M005", "C4_M006", "C4_M007", "C4_M008", "REPEATABLE_SALTWIND"],
		"allowed_hunts": ["HG_SALT_WIND_COAST"],
		"spawn_profile": {"base_hp": 260, "base_dmg": 34, "attack_interval": 1.8},
		"loot_profile": {"gold": [22, 34], "material": {"name": "Concha da Maré", "chance": 0.42, "qty": 1}, "gear_chance": 0.16, "gear_pool": ["staff_reinforced", "amulet_simple", "ring_reinforced", "potion_mana"]},
		"xp_profile": {"base": 96},
		"audio_profile": {"aggro": "tide_aggro", "attack": "tide_attack", "hit": "tide_hit", "death": "tide_death"},
	},
	# ═══ A42 CHAPTER 5 — família RAIZ (NINHO DAS RAÍZES ANTIGAS). Sprites reais (BASE/SIDE/UP validados): mobs/
	# hungry_root/root_spider/sap_eye/shadow_sprout/musgo_voraz. MAP_ROOT_NEST (tileset ancient_root_nest). Boss futuro
	# = MATRIARCA DAS RAÍZES (root_matriarch, A44) — NÃO implementado aqui. Material temático "Seiva Ancestral" (§21,
	# 1 só). Gear = reinforced EXISTENTE (§20 sem tier novo). Gradação de pressão (§18): sprout<spider<sap<hungry<musgo.
	"shadow_sprout": {   # light/fast pressure (§9)
		"family": "root", "combat_role": "melee", "visual_id": "shadow_sprout",
		"allowed_regions": ["root_nest"], "allowed_maps": ["MAP_ROOT_NEST"], "allowed_missions": ["C5_M001"],
		"allowed_hunts": ["HG_ROOT_NEST"],
		"spawn_profile": {"base_hp": 240, "base_dmg": 30, "attack_interval": 1.1},
		"loot_profile": {"gold": [26, 40], "material": {"name": "Seiva Ancestral", "chance": 0.40, "qty": 1}, "gear_chance": 0.15, "gear_pool": ["boots_reinforced", "ring_reinforced", "potion_minor"]},
		"xp_profile": {"base": 120},
		"audio_profile": {"aggro": "root_aggro", "attack": "root_attack", "hit": "root_hit", "death": "root_death"},
	},
	"root_spider": {   # fast melee (§9) — raiz, NÃO confundir com a família aranha do Ch3
		"family": "root", "combat_role": "melee", "visual_id": "root_spider",
		"allowed_regions": ["root_nest"], "allowed_maps": ["MAP_ROOT_NEST"], "allowed_missions": ["C5_M002"],
		"allowed_hunts": ["HG_ROOT_NEST"],
		"spawn_profile": {"base_hp": 300, "base_dmg": 40, "attack_interval": 1.2},
		"loot_profile": {"gold": [28, 44], "material": {"name": "Seiva Ancestral", "chance": 0.42, "qty": 1}, "gear_chance": 0.16, "gear_pool": ["armor_reinforced", "boots_reinforced", "potion_minor"]},
		"xp_profile": {"base": 138},
		"audio_profile": {"aggro": "root_aggro", "attack": "root_attack", "hit": "root_hit", "death": "root_death"},
	},
	"sap_eye": {   # ranged / caster-like pressure (§9)
		"family": "root", "combat_role": "ranged", "visual_id": "sap_eye",
		"allowed_regions": ["root_nest"], "allowed_maps": ["MAP_ROOT_NEST"], "allowed_missions": ["C5_M003"],
		"allowed_hunts": ["HG_ROOT_NEST"],
		"spawn_profile": {"base_hp": 320, "base_dmg": 46, "attack_interval": 1.6},
		"loot_profile": {"gold": [30, 46], "material": {"name": "Seiva Ancestral", "chance": 0.44, "qty": 1}, "gear_chance": 0.16, "gear_pool": ["staff_reinforced", "book_reinforced", "amulet_simple", "potion_mana"]},
		"xp_profile": {"base": 150},
		"audio_profile": {"aggro": "root_aggro", "attack": "root_attack", "hit": "root_hit", "death": "root_death"},
	},
	"hungry_root": {   # bruiser / melee (§9)
		"family": "root", "combat_role": "melee", "visual_id": "hungry_root",
		"allowed_regions": ["root_nest"], "allowed_maps": ["MAP_ROOT_NEST"], "allowed_missions": ["C5_M004", "C5_M006", "REPEATABLE_ROOT_NEST"],
		"allowed_hunts": ["HG_ROOT_NEST"],
		"spawn_profile": {"base_hp": 420, "base_dmg": 52, "attack_interval": 1.7},
		"loot_profile": {"gold": [34, 52], "material": {"name": "Seiva Ancestral", "chance": 0.46, "qty": 1}, "gear_chance": 0.17, "gear_pool": ["sword_reinforced", "spear_reinforced", "armor_reinforced", "ring_reinforced"]},
		"xp_profile": {"base": 168},
		"audio_profile": {"aggro": "root_aggro", "attack": "root_attack", "hit": "root_hit", "death": "root_death"},
	},
	"musgo_voraz": {   # tankier sustain/body (§9) — maior sprite (384×96)
		"family": "root", "combat_role": "melee", "visual_id": "musgo_voraz",
		"allowed_regions": ["root_nest"], "allowed_maps": ["MAP_ROOT_NEST"], "allowed_missions": ["C5_M005", "C5_M007"],
		"allowed_hunts": ["HG_ROOT_NEST"],
		"spawn_profile": {"base_hp": 560, "base_dmg": 44, "attack_interval": 2.0},
		"loot_profile": {"gold": [40, 60], "material": {"name": "Seiva Ancestral", "chance": 0.50, "qty": 1}, "gear_chance": 0.18, "gear_pool": ["armor_reinforced", "helmet_reinforced", "amulet_simple", "potion_minor"]},
		"xp_profile": {"base": 190},
		"audio_profile": {"aggro": "root_aggro", "attack": "root_attack", "hit": "root_hit", "death": "root_death"},
	},
	# A43 — ELITE do Ch5 (checkpoint C5_M008). ancient_root_heart (512×128, BASE/SIDE/UP validados). ELITE = HP/dano
	# altos (parede), NÃO boss (§21/§22 — sem BossRuntime; é mob de stats elevados). NÃO confundir com MATRIARCA DAS
	# RAÍZES (root_matriarch, boss A44). NÃO caçável na Hunt (allowed_hunts vazio) — só no checkpoint da missão.
	"ancient_root_heart": {
		"family": "root", "combat_role": "melee", "visual_id": "ancient_root_heart",
		"allowed_regions": ["root_nest"], "allowed_maps": ["MAP_ROOT_NEST"], "allowed_missions": ["C5_M008"],
		"allowed_hunts": [],
		"spawn_profile": {"base_hp": 6200, "base_dmg": 140, "attack_interval": 1.9},
		"loot_profile": {"gold": [400, 700], "material": {"name": "Seiva Ancestral", "chance": 0.9, "qty": 3}, "gear_chance": 0.5, "gear_pool": ["armor_reinforced", "helmet_reinforced", "ring_reinforced", "amulet_simple"]},
		"xp_profile": {"base": 4000},
		"audio_profile": {"aggro": "root_aggro", "attack": "root_heavy", "hit": "root_hit", "death": "root_death"},
	},
}

## A42 §8/§39 — mobs com Targeted Hunt (allowed_hunts não-vazio). Registry-driven: o Bestiário/UI derivam DAQUI,
## sem lista hard-coded. Adicionar mob com allowed_hunts ⇒ aparece automaticamente. Ordem estável (ordem de inserção).
static func huntable_ids() -> Array:
	var out: Array = []
	for mid in MOBS:
		if (MOBS[mid].get("allowed_hunts", []) as Array).size() > 0: out.append(mid)
	return out

## Mobs de um ground (para Bestiário/Targeted Hunt data-driven).
static func mobs_of_hunt(ground_id: String) -> Array:
	var out: Array = []
	for mid in MOBS:
		if (MOBS[mid].get("allowed_hunts", []) as Array).has(ground_id): out.append(mid)
	return out

static func get_mob(mob_id: String) -> Dictionary:
	return MOBS.get(mob_id, {}).duplicate(true)

static func exists(mob_id: String) -> bool:
	return MOBS.has(mob_id)

## O mob pode nascer nesta missão? (§8: exige elegibilidade explícita)
static func can_spawn_in_mission(mob_id: String, mission_id: String) -> bool:
	var m: Dictionary = MOBS.get(mob_id, {})
	return not m.is_empty() and (m.get("allowed_missions", []) as Array).has(mission_id)

static func can_spawn_in_hunt(mob_id: String, ground_id: String) -> bool:
	var m: Dictionary = MOBS.get(mob_id, {})
	return not m.is_empty() and (m.get("allowed_hunts", []) as Array).has(ground_id)

static func can_spawn_on_map(mob_id: String, map_id: String) -> bool:
	var m: Dictionary = MOBS.get(mob_id, {})
	return not m.is_empty() and (m.get("allowed_maps", []) as Array).has(map_id)

static func family_of(mob_id: String) -> String:
	return str(MOBS.get(mob_id, {}).get("family", ""))
