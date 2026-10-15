class_name EnvironmentProfile extends RefCounted
## A28 — PERFIL de ambiente. ★★★ MAP ≠ ENVIRONMENT PROFILE: PLAINS_WOLF e PLAINS_SPIDER_GROVE compartilham a base
## (MAP_PLAINS) mas COMPÕEM diferente. Congela a densidade/mistura/vento/clear-zone/approach-lanes — o Assembler só lê.

## ★★★ CAUSA RAIZ REAL DO "MAPA AINDA É O DE TILES" (05/09/2026).
## O chão que o jogador vê NA CAÇA não é o da região — é o overlay `LivingWorld` que o
## `EnvironmentAssembler` desenha a partir DESTE `ground_texture`. Ch4 e Ch5 já apontavam para
## chão PINTADO (`GROUND_COAST`, `GROUND_ROOT`); só Ch1/Ch3 seguiam no tile 64×64 `grass.png`,
## repetido por cima de tudo. Por isso o resolvedor de região resolvia PAINTED e a tela continuava
## quadriculada: são DOIS chãos diferentes, e eu tinha consertado o outro.
## ★★★ Lição: o chão da REGIÃO ≠ o chão da ATIVIDADE.
const GROUND_PLAINS_PAINTED := "res://assets/tilesets/plains/ground_painted.png"
const GROUND_CAVE_PAINTED := "res://assets/tilesets/cave/ground_painted.png"
const GROUND_GRASS := "res://assets/tilesets/plains/grass.png"      # legado (fallback histórico)
const GROUND_GRASS2 := "res://assets/tilesets/plains/grass2.png"    # legado
const GROUND_COAST := "res://assets/tilesets/saltwind_shore/ground_painted.png"   # A29 — ground pintado da costa
const GROUND_ROOT := "res://assets/tilesets/ancient_root_nest/ground_painted.png"  # A42 — ground do Ninho das Raízes

## profile_id → perfil.
const PROFILES := {
	# PLAINS_WOLF — aberto, centro de combate MUITO legível, vegetação moderada, poucas árvores (Preview B).
	"PLAINS_WOLF": {
		"map_id": "MAP_PLAINS", "ground_texture": GROUND_PLAINS_PAINTED, "ground_variant": GROUND_PLAINS_PAINTED,
		"display_name_key": "CANON_REVIEW_REQUIRED", "direction": "PREVIEW_B",
		"base_density": 0.55,                # densidade global (0..1); WOLF é mais aberto
		"clear_zone_radius": 220.0,          # nada bloqueante sobre player/boss anchor (§10)
		"approach_lanes": [0.0, 90.0, 180.0, 270.0],  # corredores de chegada dos mobs (graus) — não bloquear (§11)
		"lane_half_width": 46.0,
		# peso por categoria (mistura); TREE baixo (aberto)
		"category_mix": {"GRASS_SMALL": 5.0, "GRASS_MEDIUM": 4.0, "GRASS_TALL": 2.0, "WILD_PLANT": 1.5, "BUSH": 1.4, "ROCK": 1.2, "TREE": 0.5, "GROUND_DECAL": 0.4},
		"wind_profile": "PLAINS_BREEZE", "ambient_leaf_rate": 0.4, "edge_richness": 1.6,
	},
	# PLAINS_SPIDER_GROVE — mesma base, mais FECHADO/rico: tall grass, bushes, árvores emoldurando, foreground.
	"PLAINS_SPIDER_GROVE": {
		"map_id": "MAP_PLAINS", "ground_texture": GROUND_PLAINS_PAINTED, "ground_variant": GROUND_PLAINS_PAINTED,
		"display_name_key": "CANON_REVIEW_REQUIRED", "direction": "PREVIEW_C",
		"base_density": 0.85,                # mais denso
		"clear_zone_radius": 200.0,
		"approach_lanes": [45.0, 135.0, 225.0, 315.0],
		"lane_half_width": 42.0,
		"category_mix": {"GRASS_SMALL": 5.0, "GRASS_MEDIUM": 5.0, "GRASS_TALL": 4.5, "WILD_PLANT": 2.0, "BUSH": 3.0, "ROCK": 1.2, "TREE": 2.2, "GROUND_DECAL": 0.6, "FOREGROUND": 2.0},
		"wind_profile": "GROVE_STILL", "ambient_leaf_rate": 0.8, "edge_richness": 2.2,
	},
	# A29 — COSTA DO SAL-VENTO (Region Pack 01). MAP_SALT_COAST (região nova, ground pintado real). Mais ventoso.
	"SALT_WIND_COAST": {
		"map_id": "MAP_SALT_COAST", "ground_texture": GROUND_COAST, "ground_variant": GROUND_COAST,
		"display_name_key": "CANON_REVIEW_REQUIRED", "direction": "PREVIEW_BALANCED",
		"base_density": 0.7, "clear_zone_radius": 220.0,
		"approach_lanes": [0.0, 90.0, 180.0, 270.0], "lane_half_width": 46.0,
		"category_mix": {"GRASS_SMALL": 4.0, "GRASS_MEDIUM": 3.0, "GRASS_TALL": 2.5, "ROCK": 3.0, "BUSH": 1.5, "GROUND_DECAL": 2.5, "TREE": 0.8, "AMBIENT_LEAF": 1.2, "FOREGROUND": 1.5},
		"wind_profile": "SALT_WIND_NORMAL", "ambient_leaf_rate": 1.0, "edge_richness": 1.8,
	},
	# variação de ELITE (mesmo mapa-base, composição mais fechada/pesada) — prova MAP REUSE (§34).
	"SALT_WIND_COAST_ELITE": {
		"map_id": "MAP_SALT_COAST", "ground_texture": GROUND_COAST, "ground_variant": GROUND_COAST,
		"display_name_key": "CANON_REVIEW_REQUIRED", "direction": "PREVIEW_RICH",
		"base_density": 0.95, "clear_zone_radius": 200.0,
		"approach_lanes": [45.0, 135.0, 225.0, 315.0], "lane_half_width": 42.0,
		"category_mix": {"GRASS_SMALL": 4.0, "GRASS_MEDIUM": 3.5, "GRASS_TALL": 4.5, "ROCK": 4.0, "BUSH": 2.5, "GROUND_DECAL": 3.0, "TREE": 1.8, "AMBIENT_LEAF": 1.5, "FOREGROUND": 2.5},
		"wind_profile": "SALT_WIND_NORMAL", "ambient_leaf_rate": 1.2, "edge_richness": 2.4,
	},
	# A42 — NINHO DAS RAÍZES ANTIGAS. MAP_ROOT_NEST (tileset ancient_root_nest, ground pintado real). Raízes/musgo.
	# §5 WORLD FIRST: clear_zone generoso (o ambiente ENQUADRA a luta, não cobre o centro). Só DADO.
	"ROOT_NEST": {
		"map_id": "MAP_ROOT_NEST", "ground_texture": GROUND_ROOT, "ground_variant": GROUND_ROOT,
		"display_name_key": "CANON_REVIEW_REQUIRED", "direction": "PREVIEW_BALANCED",
		"base_density": 0.72, "clear_zone_radius": 220.0,
		"approach_lanes": [0.0, 90.0, 180.0, 270.0], "lane_half_width": 46.0,
		"category_mix": {"GRASS_SMALL": 3.5, "GRASS_MEDIUM": 3.0, "GRASS_TALL": 3.0, "ROCK": 2.0, "BUSH": 3.5, "GROUND_DECAL": 2.5, "TREE": 2.5, "AMBIENT_LEAF": 1.4, "FOREGROUND": 2.0},
		"wind_profile": "SALT_WIND_NORMAL", "ambient_leaf_rate": 0.9, "edge_richness": 2.0,
	},
	"ROOT_NEST_ELITE": {   # mesmo mapa-base, composição mais fechada (prova MAP REUSE §3/§34)
		"map_id": "MAP_ROOT_NEST", "ground_texture": GROUND_ROOT, "ground_variant": GROUND_ROOT,
		"display_name_key": "CANON_REVIEW_REQUIRED", "direction": "PREVIEW_RICH",
		"base_density": 0.95, "clear_zone_radius": 200.0,
		"approach_lanes": [45.0, 135.0, 225.0, 315.0], "lane_half_width": 42.0,
		"category_mix": {"GRASS_SMALL": 3.5, "GRASS_MEDIUM": 3.5, "GRASS_TALL": 4.5, "ROCK": 2.5, "BUSH": 4.5, "GROUND_DECAL": 3.0, "TREE": 3.5, "AMBIENT_LEAF": 1.6, "FOREGROUND": 3.0},
		"wind_profile": "SALT_WIND_NORMAL", "ambient_leaf_rate": 1.1, "edge_richness": 2.6,
	},
}

static func exists(profile_id: String) -> bool: return PROFILES.has(profile_id)
static func get_profile(profile_id: String) -> Dictionary: return PROFILES.get(profile_id, {}).duplicate(true)
static func all_ids() -> Array: return PROFILES.keys()

## Perfil recomendado por ground/atividade (o conteúdo pode declarar explicitamente; senão deriva).
static func for_activity(ground_or_map: String) -> String:
	if ground_or_map.contains("SALT") or ground_or_map.contains("COAST") or ground_or_map.contains("C4") or ground_or_map.contains("CHAPTER_4") or ground_or_map.contains("SALTWIND"):
		return "SALT_WIND_COAST"
	if ground_or_map.contains("GROVE") or ground_or_map.contains("SPIDER") or ground_or_map.contains("C3") or ground_or_map.contains("CHAPTER_3"):
		return "PLAINS_SPIDER_GROVE"
	return "PLAINS_WOLF"
