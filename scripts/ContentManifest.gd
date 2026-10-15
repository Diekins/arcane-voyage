class_name ContentManifest
## ContentManifest — FONTE DE PRODUÇÃO do PRIMEIRO CICLO 1–100 (FATIA A7.3). Data-driven, consumido por testes,
## simulação e (futuramente) pelo StageDirector. Organiza o conteúdo REAL já existente (auditado do disco: 10
## regiões canônicas + ~24 regiões jogáveis + 104 mob-ids + 2 bosses com script + 8 bosses canônicos sem script)
## na estrutura 10 capítulos × 10 stages = 100 fases. NÃO cria narrativa (A9 reconcilia). Display names = regiões
## reais/funcionais. `boss_status`: READY (script Godot) · PLACEHOLDER (definição canônica, sem combate) ·
## CONTENT_REQUIRED (nem definição). ★ stage 10 de cada capítulo = BOSS que concede Selo (regra A6 preservada).
##
## STAGE ≠ REGION (§3): um capítulo referencia region(s) reais; não há 100 mapas.
##
## GEAR TIER por capítulo — FONTE CANÔNICA ÚNICA (FATIA A7.4 §0). Reconciliado: a distribuição de design
## venceu (t1 cap1-2 · t2 cap3-4 · t3 cap5-6 · t4 cap7-8 · t5 cap9-10), pois a divergente (front-load t4 no cap6)
## dava R absurdo (3.37). `GEAR_TIER_BY_CHAPTER` é a ÚNICA verdade; `gear_tier(n)` a lê; o campo `gear_tier` de
## cada capítulo é MANTIDO EM SINCRONIA e o teste MANIFEST-T03 falha se divergir. cp_boss = ProgressionMath.
## required_cp(chapter×10, boss). §35: o tier aparece ANTES do muro que o exige.

## Layout de fase dentro do capítulo (§2): 1-4 NORMAL · 5 APEX · 6-9 NORMAL · 10 BOSS.
const APEX_STAGE := 5
const BOSS_STAGE := 10

## ★ FONTE CANÔNICA de tier por capítulo (índice 0 = cap1). Nenhuma outra tabela de tier pode divergir desta.
const GEAR_TIER_BY_CHAPTER := [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]

## Os 10 capítulos. Todos os mob-ids/regiões abaixo EXISTEM no projeto (auditados). apex/boss reais quando há;
## placeholders marcados. gear_tier = raridade-alvo do drop do capítulo.
const CHAPTERS := [
	{
		"chapter": 1, "display": "Planície dos Novatos", "region": "plains",
		"world_contexts": ["plains"],
		"normal_pool": ["young_wolf", "wild_boar", "road_bandit"],
		"apex": "road_bandit", "apex_status": "READY",
		"boss_id": "wolf-alpha", "boss_name": "lobo alfa", "boss_status": "READY",
		"gear_tier": 1, "gear_drops": ["sword_simple", "armor_simple", "boots_simple", "helmet_simple"],
	},
	{
		"chapter": 2, "display": "Caverna Esquecida", "region": "cave",
		"world_contexts": ["cave"],
		"normal_pool": ["crystal_bat", "living_shard", "crawling_shade", "grove_spider", "green_slime", "dusk_bat"],
		"apex": "stone_sentinel", "apex_status": "READY",
		"boss_id": "crystal-golem", "boss_name": "golem de cristal", "boss_status": "READY",
		"gear_tier": 1, "gear_drops": ["shield_simple", "pants_simple", "ring_simple", "amulet_simple", "dagger_rusty"],
	},
	{
		"chapter": 3, "display": "Pântano de Ferro", "region": "swamp",
		"world_contexts": ["swamp", "iron_channels"],
		"normal_pool": ["bog_crawler", "iron_leech", "root_spider", "hollow_husk"],
		"apex": "moss_warden", "apex_status": "READY",
		"boss_id": "magma-dragon", "boss_name": "drago magmático", "boss_status": "PLACEHOLDER",
		"gear_tier": 2, "gear_drops": ["sword_reinforced", "armor_reinforced", "boots_reinforced", "shield_reinforced"],
	},
	{
		"chapter": 4, "display": "Bosque de Cinzas", "region": "ashen_grove",
		"world_contexts": ["ashen_grove", "deep_grove"],
		"normal_pool": ["ash_wolf", "veil_spider", "hollow_watcher", "dark_sprout"],
		"apex": "root_matriarch", "apex_status": "READY",
		"boss_id": "time-devourer", "boss_name": "devorador do tempo", "boss_status": "PLACEHOLDER",
		"gear_tier": 2, "gear_drops": ["bow_reinforced", "staff_reinforced", "spear_reinforced", "helmet_reinforced", "ring_reinforced", "amulet_reinforced"],
	},
	{
		"chapter": 5, "display": "Costa do Sal", "region": "saltwind_shore",
		"world_contexts": ["saltwind_shore", "castaway_sandbar", "salt_split_isle"],
		"normal_pool": ["salt_husk", "tide_warden", "marujo_afogado", "caranguejo_ferrugem"],
		"apex": "salt_split_warden", "apex_status": "READY",
		"boss_id": "faceless-archivist", "boss_name": "arquivista sem rosto", "boss_status": "PLACEHOLDER",
		"gear_tier": 3, "gear_drops": ["sword_memoria", "armor_memoria", "sword_crystal"],
	},
	{
		"chapter": 6, "display": "Areias de Khet", "region": "khet_sar_sands",
		"world_contexts": ["khet_sar_sands", "khet_oasis", "khet_sand_maw"],
		"normal_pool": ["dune_skitter", "chacal_das_dunas", "carniceiro_areias", "salt_husk"],
		"apex": "carniceiro_areias", "apex_status": "READY",
		"boss_id": "broken-oath", "boss_name": "o juramento partido", "boss_status": "PLACEHOLDER",
		"gear_tier": 3, "gear_drops": ["sword_crystal", "sword_memoria", "armor_memoria"],
	},
	{
		"chapter": 7, "display": "Colunata de Khet", "region": "khet_colonnade",
		"world_contexts": ["khet_colonnade"],
		"normal_pool": ["guardiao_coluna", "ruin_raider", "fallen_sentry"],
		"apex": "colonnade_apex", "apex_status": "READY",
		"boss_id": "nameless-saint", "boss_name": "o santo sem memória", "boss_status": "PLACEHOLDER",
		"gear_tier": 4, "gear_drops": ["sword_abyss", "chest_abyss", "boots_abyss", "head_abyss", "staff_abyss"],
	},
	{
		"chapter": 8, "display": "Cidadela de Khet", "region": "khet_citadel",
		"world_contexts": ["khet_citadel"],
		"normal_pool": ["citadel_raider", "citadel_warden", "citadel_eye"],
		"apex": "citadel_apex", "apex_status": "READY",
		"boss_id": "threshold-guardian", "boss_name": "o guardião do limiar", "boss_status": "PLACEHOLDER",
		"gear_tier": 4, "gear_drops": ["legs_abyss", "shield_abyss", "ring_abyss", "bracelet_abyss", "amulet_abyss"],
	},
	{
		"chapter": 9, "display": "Catedral de Cristal", "region": "cathedral_of_crystal",
		"world_contexts": ["cathedral_of_crystal", "veins"],
		"normal_pool": ["veio_sentinel", "crystal_bat", "living_shard", "crescido_na_parede"],
		"apex": "coracao_de_cristal", "apex_status": "READY",
		"boss_id": "shadow-between-worlds", "boss_name": "a sombra entre mundos", "boss_status": "PLACEHOLDER",
		"gear_tier": 5, "gear_drops": ["sword_eternal", "chest_eternal", "staff_eternal", "head_eternal", "legs_eternal"],
	},
	{
		"chapter": 10, "display": "O Limiar", "region": "cais_dos_ausentes",
		"world_contexts": ["cais_dos_ausentes", "ancient_root_nest"],
		"normal_pool": ["root_matriarch", "scrap_colossus", "veio_sentinel", "hollow_watcher"],
		"apex": "maw_apex_jackal", "apex_status": "READY",
		"boss_id": "aethelgard", "boss_name": "aethelgard", "boss_status": "PLACEHOLDER",
		"gear_tier": 5, "gear_drops": ["boots_eternal", "shield_eternal", "ring_eternal", "bracelet_eternal", "amulet_eternal"],
	},
]

## Mobs de TESTE/DEV que NUNCA podem aparecer numa stage (§CHAP-T05).
const TEST_MOB_IDS := ["mage_of_heaven", "musgo_voraz"]

static func chapters() -> Array:
	return CHAPTERS

static func chapter(n: int) -> Dictionary:
	for c in CHAPTERS:
		if int(c["chapter"]) == n:
			return c
	return {}

## Tipo da stage global (1-100). 5→apex, 10→boss, resto normal.
static func stage_type(global_stage: int) -> String:
	var s := ((global_stage - 1) % 10) + 1
	if s == BOSS_STAGE: return "boss"
	if s == APEX_STAGE: return "miniboss"
	return "normal"

## Capítulo de uma stage global.
static func chapter_of(global_stage: int) -> int:
	return (maxi(1, global_stage) - 1) / 10 + 1

## CP recomendado no BOSS do capítulo (referência; usa a curva A3 INALTERADA, §18).
static func chapter_boss_cp(n: int) -> int:
	return ProgressionMath.required_cp(n * 10, "boss")

## Todos os mob-ids referenciados pelo manifesto (pool + apex) — p/ validação.
static func all_referenced_mobs() -> Array:
	var out: Array = []
	for c in CHAPTERS:
		for m in c["normal_pool"]:
			if not out.has(str(m)): out.append(str(m))
		var ap := str(c["apex"])
		if not out.has(ap): out.append(ap)
	return out

## Todos os bases de gear referenciados (drops) — p/ Códice/validação.
static func all_gear_drops() -> Array:
	var out: Array = []
	for c in CHAPTERS:
		for g in c.get("gear_drops", []):
			if not out.has(str(g)): out.append(str(g))
	return out

## Bosses por status.
static func bosses_by_status(status: String) -> Array:
	var out: Array = []
	for c in CHAPTERS:
		if str(c["boss_status"]) == status:
			out.append(str(c["boss_name"]))
	return out

## ══════════════ FATIA A7.4 — API DE RUNTIME (StageDirector consome isto) ══════════════

## Tier de gear canônico do capítulo (FONTE ÚNICA — GEAR_TIER_BY_CHAPTER). n é 1-based.
static func gear_tier(n: int) -> int:
	var i := clampi(n, 1, GEAR_TIER_BY_CHAPTER.size())
	return int(GEAR_TIER_BY_CHAPTER[i - 1])

## Stage local (1-10) de uma stage global (1-100).
static func local_of(global_stage: int) -> int:
	return ((maxi(1, global_stage) - 1) % 10) + 1

## Stage global (1-100) a partir de (capítulo 1-based, stage local 1-10).
static func global_of(chapter_n: int, local_stage: int) -> int:
	return (maxi(1, chapter_n) - 1) * 10 + clampi(local_stage, 1, 10)

## ★ §4 — REGIÃO da stage, data-driven. Divide as 10 stages locais entre os world_contexts do capítulo,
## em blocos contíguos aproximadamente iguais (STAGE ≠ REGION; sem exigir 100 mapas). 1 região → todas as 10.
static func region_for_stage(global_stage: int) -> String:
	var c := chapter(chapter_of(global_stage))
	if c.is_empty(): return "plains"
	var ctx: Array = c.get("world_contexts", [c.get("region", "plains")])
	if ctx.is_empty(): return str(c.get("region", "plains"))
	var n := ctx.size()
	var local := local_of(global_stage)   # 1..10
	# bloco = teto(10/n); idx = (local-1)/bloco, saturado no último contexto.
	var block := int(ceil(10.0 / float(n)))
	var idx := mini((local - 1) / maxi(1, block), n - 1)
	return str(ctx[idx])

## ★ RESOLVER CANÔNICO — tudo que o StageDirector precisa de uma stage global (1..100), num só Dictionary.
## Nenhum consumidor deve reconstruir esses campos por conta própria (sem tabela paralela).
static func resolve(global_stage: int) -> Dictionary:
	var g := clampi(global_stage, 1, 100)
	var ch := chapter_of(g)
	var c := chapter(ch)
	var local := local_of(g)
	var st := stage_type(g)
	var d := {
		"global_stage": g,
		"chapter": ch,
		"local_stage": local,
		"stage_type": st,          # "normal" | "miniboss" | "boss"
		"display": str(c.get("display", "")),
		"region": region_for_stage(g),
		"world_contexts": c.get("world_contexts", []),
		"normal_pool": c.get("normal_pool", []),
		"apex": str(c.get("apex", "")),
		"apex_status": str(c.get("apex_status", "")),
		"boss_id": str(c.get("boss_id", "")),
		"boss_name": str(c.get("boss_name", "")),
		"boss_status": str(c.get("boss_status", "")),
		"gear_tier": gear_tier(ch),
		"gear_drops": c.get("gear_drops", []),
	}
	# Encontro efetivo desta stage: boss (10) → o boss; apex (5) → o apex; normal → pool.
	if st == "boss":
		d["encounter"] = d["boss_id"]
		d["encounter_kind"] = "boss"
	elif st == "miniboss":
		d["encounter"] = d["apex"]
		d["encounter_kind"] = "apex"
	else:
		d["encounter"] = ""       # StageDirector sorteia do normal_pool
		d["encounter_kind"] = "normal"
	return d

## Pool de mobs concreto para spawn numa stage global: [encounter] p/ apex/boss, ou o normal_pool inteiro.
static func spawn_pool(global_stage: int) -> Array:
	var r := resolve(global_stage)
	if str(r["encounter_kind"]) == "normal":
		return r["normal_pool"]
	# apex/boss: o alvo é o encounter; mantém o pool como contexto de fundo se o StageDirector quiser.
	var e := str(r["encounter"])
	return [e] if e != "" else r["normal_pool"]
