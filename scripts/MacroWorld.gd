class_name MacroWorld
extends RefCounted
## Lógica PURA de world-layout do mundo contínuo, extraída do Main.gd (GODOT-CONTINUOUS-WORLD-EXTRACT-1 / início da
## redução do monolito, domínio macrozone/world-layout). SEM dependências de cena/estado do Main → segura e testável
## isolada. Funções ESTÁTICAS; o Main mantém wrappers finos que delegam aqui (call-sites e self-tests inalterados).

## Clusters GRADUADOS a partir do contrato (campo `graduated:true`); `fallback` se NENHUM cluster declarar o campo.
static func graduated_clusters(data: Dictionary, fallback: Array) -> Array:
	var out := []
	for cid in data.keys():
		if typeof(data[cid]) == TYPE_DICTIONARY and bool(data[cid].get("graduated", false)):
			out.append(str(cid))
	return out if not out.is_empty() else fallback

## `world_pos` de um cluster (onde o (0,0) LOCAL do cluster cai no MUNDO). (0,0) se ausente/inválido.
static func cluster_world_pos(data: Dictionary, cluster_id: String) -> Vector2:
	if data.has(cluster_id) and typeof(data[cluster_id]) == TYPE_DICTIONARY:
		var wp = data[cluster_id].get("world_pos", [0, 0])
		if typeof(wp) == TYPE_ARRAY and wp.size() >= 2:
			return Vector2(float(wp[0]), float(wp[1]))
	return Vector2.ZERO

## Região cuja zona contém o ponto p (""=nenhuma). zone_rects = [{region:String, rect:Rect2}]. Base do region-by-position.
static func region_at(zone_rects: Array, p: Vector2) -> String:
	for z in zone_rects:
		if (z["rect"] as Rect2).has_point(p):
			return str(z["region"])
	return ""

## Distância de um ponto ao rect (0 se dentro; senão até a borda mais próxima). Base do cull por proximidade (Fase D).
static func zone_dist_to(p: Vector2, r: Rect2) -> float:
	var cx := clampf(p.x, r.position.x, r.position.x + r.size.x)
	var cy := clampf(p.y, r.position.y, r.position.y + r.size.y)
	return p.distance_to(Vector2(cx, cy))
