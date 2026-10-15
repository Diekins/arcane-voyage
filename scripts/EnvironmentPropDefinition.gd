class_name EnvironmentPropDefinition extends RefCounted
## A28 — LIVING WORLD: catálogo DATA-DRIVEN de props de ambiente (a partir dos assets REAIS de tilesets/plains).
## Nada de `if rock_03`. Cada prop declara categoria/textura/escala/âncora-de-chão/colisão(footprint)/oclusão/vento/
## qualidade/peso-de-densidade/perfis. Colisão = pegada FÍSICA no chão, NUNCA a bbox do PNG.

# categorias (§4)
const GRASS_SMALL := "GRASS_SMALL"
const GRASS_MEDIUM := "GRASS_MEDIUM"
const GRASS_TALL := "GRASS_TALL"
const WILD_PLANT := "WILD_PLANT"
const BUSH := "BUSH"
const ROCK := "ROCK"
const TREE := "TREE"
const GROUND_DECAL := "GROUND_DECAL"
const FOREGROUND := "FOREGROUND"
const AMBIENT_LEAF := "AMBIENT_LEAF"
const CONTACT_SHADOW := "CONTACT_SHADOW"

# perfis de colisão (§12) — footprint, não a imagem inteira
const COL_NONE := "NONE"
const COL_SMALL_BASE := "SMALL_BASE"
const COL_TRUNK_BASE := "TRUNK_BASE"
const COL_ROCK_FOOTPRINT := "ROCK_FOOTPRINT"

# perfis de vento (§23)
const WIND_NONE := "WIND_NONE"
const WIND_LIGHT := "WIND_LIGHT"
const WIND_NORMAL := "WIND_NORMAL"
const WIND_FULL := "WIND_FULL"

const AP := "res://assets/actors/"   # não usado; props vivem em tilesets/plains
const PLAINS := "res://assets/tilesets/plains/"
const COAST := "res://assets/tilesets/eastern_sea/props/"   # A29 — props costeiros (Region Pack 01)
const SHORE := "res://assets/tilesets/saltwind_shore/props/"

## prop_id → definição. `ground_anchor`=fração da ALTURA onde o prop toca o chão (1.0=base do PNG). `canopy_frac`=fração
## superior que é COPA (só TREE; oclui/some). `footprint`=tamanho relativo da pegada (fração da largura/altura da base).
const PROPS := {
	# ── GRAMA (decais 48×48; sem colisão; vento forte nas pontas) ──
	"grass_small": {"category": GRASS_SMALL, "texture": PLAINS + "overlays/tuft0.png", "display_scale": 0.7, "ground_anchor": 1.0, "y_sort_offset": 0.0, "collision": COL_NONE, "wind": WIND_FULL, "quality_min": "LOW", "density_weight": 5.0, "profiles": ["PLAINS_WOLF", "PLAINS_SPIDER_GROVE", "SALT_WIND_COAST"]},
	"grass_medium": {"category": GRASS_MEDIUM, "texture": PLAINS + "overlays/tuft1.png", "display_scale": 1.0, "ground_anchor": 1.0, "y_sort_offset": 0.0, "collision": COL_NONE, "wind": WIND_FULL, "quality_min": "LOW", "density_weight": 4.0, "profiles": ["PLAINS_WOLF", "PLAINS_SPIDER_GROVE", "SALT_WIND_COAST"]},
	"grass_tall": {"category": GRASS_TALL, "texture": PLAINS + "overlays/tuft2.png", "display_scale": 1.3, "ground_anchor": 1.0, "y_sort_offset": 6.0, "collision": COL_NONE, "wind": WIND_NORMAL, "quality_min": "LOW", "density_weight": 3.0, "profiles": ["PLAINS_WOLF", "PLAINS_SPIDER_GROVE", "SALT_WIND_COAST"]},
	# ── PLANTAS/FLORES (sem colisão) ──
	"wild_flowers": {"category": WILD_PLANT, "texture": PLAINS + "props/flowers.png", "display_scale": 1.0, "ground_anchor": 1.0, "y_sort_offset": 0.0, "collision": COL_NONE, "wind": WIND_NORMAL, "quality_min": "MEDIUM", "density_weight": 1.5, "profiles": ["PLAINS_WOLF", "PLAINS_SPIDER_GROVE", "SALT_WIND_COAST"]},
	# ── ARBUSTO (base pequena; vento leve) ──
	"bush": {"category": BUSH, "texture": PLAINS + "props/bush.png", "display_scale": 1.0, "ground_anchor": 0.92, "y_sort_offset": 0.0, "collision": COL_SMALL_BASE, "footprint": {"w": 0.5, "h": 0.22}, "wind": WIND_LIGHT, "quality_min": "LOW", "density_weight": 1.6, "profiles": ["PLAINS_WOLF", "PLAINS_SPIDER_GROVE", "SALT_WIND_COAST"]},
	# ── PEDRA (footprint físico; sem vento) ──
	"rock": {"category": ROCK, "texture": PLAINS + "props/rock.png", "display_scale": 1.0, "ground_anchor": 0.9, "y_sort_offset": 0.0, "collision": COL_ROCK_FOOTPRINT, "footprint": {"w": 0.7, "h": 0.3}, "wind": WIND_NONE, "quality_min": "LOW", "density_weight": 1.2, "profiles": ["PLAINS_WOLF", "PLAINS_SPIDER_GROVE", "SALT_WIND_COAST"]},
	# ── ÁRVORES (colisão SÓ no tronco; copa oclui/some; vento leve na copa) ──
	"tree": {"category": TREE, "texture": PLAINS + "props/tree.png", "display_scale": 1.4, "ground_anchor": 0.97, "y_sort_offset": 0.0, "collision": COL_TRUNK_BASE, "footprint": {"w": 0.22, "h": 0.14}, "canopy_frac": 0.62, "wind": WIND_LIGHT, "quality_min": "LOW", "density_weight": 0.7, "profiles": ["PLAINS_WOLF", "PLAINS_SPIDER_GROVE", "SALT_WIND_COAST"]},
	"tree2": {"category": TREE, "texture": PLAINS + "props/tree2.png", "display_scale": 1.25, "ground_anchor": 0.97, "y_sort_offset": 0.0, "collision": COL_TRUNK_BASE, "footprint": {"w": 0.2, "h": 0.13}, "canopy_frac": 0.6, "wind": WIND_LIGHT, "quality_min": "LOW", "density_weight": 0.9, "profiles": ["PLAINS_WOLF", "PLAINS_SPIDER_GROVE", "SALT_WIND_COAST"]},
	# ── DECAL/FOREGROUND (tronco caído; sem colisão) ──
	"log_decal": {"category": GROUND_DECAL, "texture": PLAINS + "props/log.png", "display_scale": 0.8, "ground_anchor": 1.0, "y_sort_offset": 0.0, "collision": COL_NONE, "wind": WIND_NONE, "quality_min": "MEDIUM", "density_weight": 0.4, "profiles": ["PLAINS_WOLF", "PLAINS_SPIDER_GROVE", "SALT_WIND_COAST"]},
	"foreground_grass": {"category": FOREGROUND, "texture": PLAINS + "overlays/tuft2.png", "display_scale": 1.6, "ground_anchor": 1.0, "y_sort_offset": 0.0, "collision": COL_NONE, "wind": WIND_FULL, "quality_min": "HIGH", "density_weight": 1.0, "profiles": ["PLAINS_SPIDER_GROVE", "PLAINS_WOLF", "SALT_WIND_COAST"]},
	# ── A29 COSTA DO SAL-VENTO (Region Pack 01): tidepool_rocks(ROCK), skiff_wreck/coral/net(decais), anchor/shrine/
	# lantern(props com base), coast_gull(pássaro=ambient), horizon_sail(fundo). Assets reais de saltwind_shore/eastern_sea.
	"tidepool_rocks": {"category": ROCK, "texture": COAST + "eastern_tidepool_rocks.png", "display_scale": 1.0, "ground_anchor": 0.9, "y_sort_offset": 0.0, "collision": COL_ROCK_FOOTPRINT, "footprint": {"w": 0.72, "h": 0.28}, "wind": WIND_NONE, "quality_min": "LOW", "density_weight": 1.3, "profiles": ["SALT_WIND_COAST", "SALT_WIND_COAST_ELITE"]},
	"rusted_anchor": {"category": ROCK, "texture": COAST + "eastern_rusted_anchor.png", "display_scale": 0.9, "ground_anchor": 0.92, "y_sort_offset": 0.0, "collision": COL_ROCK_FOOTPRINT, "footprint": {"w": 0.5, "h": 0.22}, "wind": WIND_NONE, "quality_min": "MEDIUM", "density_weight": 0.5, "profiles": ["SALT_WIND_COAST", "SALT_WIND_COAST_ELITE"]},
	"sea_shrine": {"category": ROCK, "texture": COAST + "eastern_sea_stone_shrine.png", "display_scale": 1.0, "ground_anchor": 0.94, "y_sort_offset": 0.0, "collision": COL_ROCK_FOOTPRINT, "footprint": {"w": 0.55, "h": 0.22}, "wind": WIND_NONE, "quality_min": "HIGH", "density_weight": 0.3, "profiles": ["SALT_WIND_COAST", "SALT_WIND_COAST_ELITE"]},
	"signal_lantern": {"category": BUSH, "texture": COAST + "eastern_signal_lantern.png", "display_scale": 0.9, "ground_anchor": 0.95, "y_sort_offset": 0.0, "collision": COL_SMALL_BASE, "footprint": {"w": 0.3, "h": 0.16}, "wind": WIND_NONE, "quality_min": "HIGH", "density_weight": 0.3, "profiles": ["SALT_WIND_COAST", "SALT_WIND_COAST_ELITE"]},
	"skiff_wreck": {"category": GROUND_DECAL, "texture": COAST + "eastern_skiff_wreck.png", "display_scale": 1.0, "ground_anchor": 0.95, "y_sort_offset": 0.0, "collision": COL_NONE, "wind": WIND_NONE, "quality_min": "MEDIUM", "density_weight": 0.35, "profiles": ["SALT_WIND_COAST", "SALT_WIND_COAST_ELITE"]},
	"coral_shells": {"category": GROUND_DECAL, "texture": COAST + "eastern_coral_shell_scatter.png", "display_scale": 1.0, "ground_anchor": 1.0, "y_sort_offset": 0.0, "collision": COL_NONE, "wind": WIND_NONE, "quality_min": "LOW", "density_weight": 1.4, "profiles": ["SALT_WIND_COAST", "SALT_WIND_COAST_ELITE"]},
	"fishing_net": {"category": GROUND_DECAL, "texture": COAST + "eastern_fishing_net.png", "display_scale": 1.0, "ground_anchor": 1.0, "y_sort_offset": 0.0, "collision": COL_NONE, "wind": WIND_LIGHT, "quality_min": "MEDIUM", "density_weight": 0.5, "profiles": ["SALT_WIND_COAST", "SALT_WIND_COAST_ELITE"]},
	"coast_gull": {"category": AMBIENT_LEAF, "texture": SHORE + "coast_gull.png", "display_scale": 1.0, "ground_anchor": 0.0, "y_sort_offset": 0.0, "collision": COL_NONE, "wind": WIND_FULL, "quality_min": "MEDIUM", "density_weight": 0.6, "profiles": ["SALT_WIND_COAST", "SALT_WIND_COAST_ELITE"]},
	"horizon_sail": {"category": FOREGROUND, "texture": SHORE + "horizon_sail.png", "display_scale": 1.0, "ground_anchor": 0.0, "y_sort_offset": 0.0, "collision": COL_NONE, "wind": WIND_LIGHT, "quality_min": "HIGH", "density_weight": 0.2, "profiles": ["SALT_WIND_COAST", "SALT_WIND_COAST_ELITE"]},
}

static func exists(prop_id: String) -> bool: return PROPS.has(prop_id)
static func get_prop(prop_id: String) -> Dictionary: return PROPS.get(prop_id, {}).duplicate(true)
static func all_ids() -> Array: return PROPS.keys()

## Props de uma categoria.
static func by_category(cat: String) -> Array:
	var out: Array = []
	for id in PROPS:
		if str(PROPS[id]["category"]) == cat: out.append(id)
	return out

## Props elegíveis a um profile + tier de qualidade.
static func eligible(profile_id: String, quality := "HIGH") -> Array:
	var rank := {"LOW": 0, "MEDIUM": 1, "HIGH": 2}
	var q := int(rank.get(quality, 2))
	var out: Array = []
	for id in PROPS:
		var p: Dictionary = PROPS[id]
		if (p["profiles"] as Array).has(profile_id) and int(rank.get(str(p.get("quality_min", "LOW")), 0)) <= q:
			out.append(id)
	return out

## Categoria colide? (defaults §12). Grama/decal/planta/folha/foreground = NONE.
static func collides(prop_id: String) -> bool:
	return str(get_prop(prop_id).get("collision", COL_NONE)) != COL_NONE

## É árvore com copa oclusível?
static func has_canopy(prop_id: String) -> bool:
	var p := get_prop(prop_id)
	return str(p.get("category", "")) == TREE and float(p.get("canopy_frac", 0.0)) > 0.0
