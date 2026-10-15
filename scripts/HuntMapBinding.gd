class_name HuntMapBinding extends RefCounted
## ★★★ FIELD FIX 05/09/2026 — PONTE `map_id` ↔ REGIÃO DO MUNDO. **Antes NÃO EXISTIA.**
##
## O defeito de campo ("a caça automática está mandando pro lugar errado") tem uma causa exata:
## `HuntWorld._anchor(cluster_i, spot_i)` devolve `Vector2(200 + cluster*600 + …, 200 + …)` — uma
## coordenada de **SLOT DE SERVIDOR** (grade de empacotamento social, §51), e o `HuntHost` usava
## esse número diretamente como coordenada de **MUNDO**.
##
## São dois espaços diferentes:
##   SLOT  = quem divide o ponto de caça com quem (lógico, sem mapa)
##   MUNDO = onde aquilo fica de fato no mundo contínuo (macro_clusters.json)
##
## Resultado: qualquer ground escolhido teleportava o jogador para ~(200,200) — o canto da Vila
## inicial — e o `on_hunt_enter` só vestia um `LivingWorld` genérico por cima. O `map_id` do ground
## existia no shard (`HuntWorld._new_shard`) mas nunca era consultado para viajar.
##
## Aqui o slot vira **offset LOCAL dentro da região** que hospeda o `map_id` do ground — o
## empacotamento social é preservado, mas agora dentro do mapa certo.
##
## ⚠️⚠️ **CANON_REVIEW_REQUIRED** — QUEM hospeda cada `map_id` é DECISÃO DE DESIGN, não de código.
## A tabela abaixo é a leitura óbvia cruzando `HuntingGround.map_of()` com as regiões de
## `data/macro_clusters.json`. **Precisa do aval do arquiteto**; não é canonização.

## map_id (lógico, de HuntingGround/AfkMissionDefinition) → region_id (mundo, macro_clusters.json)
## ⚠️ AUDITADO 05/09/2026 (PVE_FIELD_RECOVERY_V2 §5). O que cada linha REALMENTE entrega hoje:
const MAP_TO_REGION := {
	# 🔴 chão de TILE legado — `plains` NÃO tem `ground_painted.png`. Não é o pipeline preferindo o
	# mapa velho: não existe mapa novo para o Ch1/Ch3. ⇒ MAP_ASSET_REQUIRED (Codex).
	"MAP_PLAINS":     "plains",              # cluster `starter`, offset (2200, 0)
	# 🔴 idem: `cave` só tem `cave_floor.png` tileado. ⇒ MAP_ASSET_REQUIRED (Codex).
	"MAP_CAVE":       "cave",                # cluster `starter`, offset (4600, 0)
	# ✅ ÚNICO capítulo que fecha o contrato "mapa novo real": região existe, chão pintado existe,
	# e `Main.gd:8419` já despacha `_build_grove_painted_map`.
	"MAP_ROOT_NEST":  "ancient_root_nest",   # cluster `forest`,  world_pos (0, -3800)
	# ⛔ `MAP_SALT_COAST` REMOVIDO DE PROPÓSITO — ver `unresolved_map_reason()`.
}

## ⛔ A7 "NO LEGACY TILE FALLBACK: FAIL LOUD". Mapas que NÃO podem resolver, com o motivo exato.
## Antes eu havia apontado MAP_SALT_COAST → `khet_salt_scrub`: ERRADO. `khet_salt_scrub` é outra
## região; a Costa do Sal-Vento pintada é `saltwind_shore`, que **não existe em macro_clusters.json**.
## Apontar para o vizinho seria trocar um destino errado por outro destino errado, em silêncio.
const UNRESOLVED := {
	"MAP_SALT_COAST": "WORLD_REGION_REQUIRED: 'saltwind_shore' tem ground_painted.png e builder, mas NAO e regiao do mundo (macro_clusters.json). Decisao de layout = arquiteto.",
}

static func unresolved_map_reason(map_id: String) -> String:
	return str(UNRESOLVED.get(map_id, ""))

## ★★★ PONTO DE COMBATE NO MUNDO (05/09/2026) — FONTE ÚNICA para Hunt E Mission.
## O mundo é um MACRO-ZONE CONTÍNUO: as regiões coexistem lado a lado por design. Colocar a
## atividade perto de uma borda faz a REGIÃO VIZINHA aparecer em cena — foi o "bloco verde com
## casas da Vila" do field. `MissionHost` fixava `Vector2(200,200)`, que cai dentro da
## `starter_village`; `HuntHost` usava `origin + slot`, o canto da região.
## ⇒ Aqui o combate vai para o CENTRO da região do `map_id`, com o slot virando um espalhamento
## de no máximo ±20% (mantém o empacotamento social §51 sem encostar em fronteira).
## Devolve `Vector2.INF` quando não dá para resolver — o chamador decide o fallback e GRITA.
static func world_combat_anchor(main, map_id: String, slot_off := Vector2.ZERO) -> Vector2:
	var region := region_of(map_id)
	if region == "" or main == null or not main.has_method("region_world_origin"):
		return Vector2.INF
	var origin: Vector2 = main.region_world_origin(region)
	if origin == Vector2.INF:
		return Vector2.INF
	var rsize := Vector2(2400, 1600)
	if main.has_method("_region_world_size"):
		rsize = main._region_world_size(region)
	var spread := Vector2(
		fposmod(slot_off.x, rsize.x * 0.4) - rsize.x * 0.2,
		fposmod(slot_off.y, rsize.y * 0.4) - rsize.y * 0.2)
	return origin + rsize * 0.5 + spread

## "" = sem ligação declarada. O chamador DEVE gritar, nunca chutar (0,0).
static func region_of(map_id: String) -> String:
	return str(MAP_TO_REGION.get(map_id, ""))

static func region_of_ground(ground_id: String) -> String:
	return region_of(HuntingGround.map_of(ground_id))

## map_ids declarados em HuntingGround que ainda NÃO têm região ligada (base de assert em teste).
static func unbound_maps() -> Array:
	var out: Array = []
	for gid in HuntingGround.all_ids():
		var m := HuntingGround.map_of(gid)
		if m != "" and not MAP_TO_REGION.has(m) and not (m in out):
			out.append(m)
	return out
