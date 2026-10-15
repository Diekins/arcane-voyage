class_name PveActivityDefinition extends RefCounted
## FATIA A18.1 — CONTRATO fino de ATIVIDADE PvE. Tipos preparados: MISSION/HUNT/BOSS/DUNGEON. Nesta fase só MISSION
## (gameplay) + ponte para o HUNT existente (A16). Não é framework gigante: delega às definições de dados existentes.

const TYPE_MISSION := "MISSION"
const TYPE_HUNT := "HUNT"
const TYPE_BOSS := "BOSS"      # PREPARADO, não implementado (intro_profile fica pronto no boss futuro)
const TYPE_DUNGEON := "DUNGEON"

## Resolve uma atividade unificada por id (missão OU hunting ground). Retorna {activity_id, activity_type, map_id, ...}.
static func resolve(activity_id: String) -> Dictionary:
	if AfkMissionDefinition.exists(activity_id):
		var m := AfkMissionDefinition.get_mission(activity_id)
		return {"activity_id": activity_id, "activity_type": TYPE_MISSION, "map_id": str(m.get("map_id", "")),
			"spot_profile": str(m.get("spot_profile", "")), "recommended_cp": int(m.get("recommended_cp", 0)),
			"difficulty_options": m.get("available_difficulties", ["NORMAL"]), "intro_profile": m.get("intro_profile", {}),
			"completion_rule": {"type": str(m.get("objective_type", "")), "count": int(m.get("required_count", 1))},
			"enabled": true, "mission": m}
	if HuntingGround.exists(activity_id):
		var g := HuntingGround.get_ground(activity_id)
		return {"activity_id": activity_id, "activity_type": TYPE_HUNT, "map_id": str(g.get("map_id", "")),
			"recommended_cp": int(g.get("recommended_cp", 0)), "difficulty_options": ["NORMAL"],
			"completion_rule": {"type": "INFINITE"}, "enabled": bool(g.get("enabled", true)), "ground": g}
	return {}

static func is_mission(activity_id: String) -> bool:
	return AfkMissionDefinition.exists(activity_id)
