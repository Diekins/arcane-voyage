class_name GoldenPath extends RefCounted
## FATIA A18.15 — ESTADO da cadeia (Chapter 1). Persiste em v10 REUSANDO `story_flags` (unlock exact-once) do GameState
## — SEM schema bump. Regras: uma missão só abre se a anterior concluiu; conclusão/unlock idempotentes; sobrevive ao
## relog. Não é campaign engine gigante — é a lógica mínima de porta. Injeta o GameState (testável).

var gs = null

func setup(p_gs) -> void:
	gs = p_gs

func _flag(mission_id: String) -> String: return "GP_%s_COMPLETE" % mission_id

## A missão está DISPONÍVEL? (anterior concluída ou sem anterior). O repetível/hunt exigem M006 concluída.
func is_available(mission_id: String) -> bool:
	if gs == null or not AfkMissionDefinition.exists(mission_id): return false
	var m := AfkMissionDefinition.get_mission(mission_id)
	var prev := str(m.get("unlock_rule", {}).get("prev", ""))
	if prev == "": return true
	return gs.is_story_flag(_flag(prev))

func is_complete(mission_id: String) -> bool:
	return gs != null and gs.is_story_flag(_flag(mission_id))

## Marca a missão como concluída (idempotente) e destrava o que ela abre (§EXACTLY ONCE). Retorna true na 1ª vez.
func complete(mission_id: String) -> bool:
	if gs == null or not AfkMissionDefinition.exists(mission_id): return false
	if gs.is_story_flag(_flag(mission_id)): return false   # já concluída → sem duplicar reward/unlock
	gs.set_story_flag(_flag(mission_id))
	# desbloqueios explícitos ao concluir (ex.: M006 abre farm + hunt)
	var m := AfkMissionDefinition.get_mission(mission_id)
	for u in m.get("unlocks_on_complete", []):
		gs.set_story_flag("GP_UNLOCK_%s" % str(u))
	return true

func is_unlocked(unlock_id: String) -> bool:
	return gs != null and gs.is_story_flag("GP_UNLOCK_%s" % unlock_id)

## A21.3 — REFINE progressive disclosure: apresentado após C2_M003 (jogador já tem material de cristal). Antes disso
## o Refine NÃO aparece (§A21.3). Reusa o sistema de Refine existente (Fragmentos) — nenhum crafting novo.
func refine_available() -> bool:
	return gs != null and is_complete("C2_M003")

## A19/A20 — BOSS por-id (default wolf p/ compat). Disponível só após a missão pré-boss do arco (§BF-T02/T03).
func boss_available(boss_id := "BOSS_WOLF_ALPHA") -> bool:
	if gs == null or not BossActivityDefinition.exists(boss_id): return false
	var prev := str(BossActivityDefinition.get_boss(boss_id).get("unlock_rule", {}).get("prev_mission", ""))
	return prev == "" or is_complete(prev)

func boss_first_cleared(boss_id := "BOSS_WOLF_ALPHA") -> bool:
	return gs != null and gs.is_story_flag("GP_%s_CLEAR" % boss_id)

## Marca a 1ª vitória do boss (exact-once → first-clear reward) + fecha o capítulo do arco. Retorna true na 1ª vez.
func mark_boss_cleared(boss_id := "BOSS_WOLF_ALPHA") -> bool:
	if gs == null or not BossActivityDefinition.exists(boss_id): return false
	if gs.is_story_flag("GP_%s_CLEAR" % boss_id): return false
	gs.set_story_flag("GP_%s_CLEAR" % boss_id)
	var chap := str(BossActivityDefinition.get_boss(boss_id).get("chapter_id", "CHAPTER_1_WOLF"))
	gs.set_story_flag("GP_%s_COMPLETE" % chap)
	return true

func is_chapter_complete(chapter_id := "CHAPTER_1_WOLF") -> bool:
	return gs != null and gs.is_story_flag("GP_%s_COMPLETE" % chapter_id)

## A26 — Chapter 3 chega ao PRÉ-BOSS (última missão concluída destrava isto). NÃO é "complete" (o Boss #3 não existe;
## o capítulo só fecha quando houver Boss). Enquanto isso, farm/hunt/repeatable ficam abertos.
func chapter3_preboss_ready() -> bool:
	return gs != null and is_unlocked("CHAPTER_3_PREBOSS_READY")

## A29 — Chapter 4 (COSTA DO SAL-VENTO) chega ao PRÉ-BOSS. NÃO é "complete" (Boss = candidate sem sprite).
func chapter4_preboss_ready() -> bool:
	return gs != null and is_unlocked("CHAPTER_4_PREBOSS_READY")

## A43 — Chapter 5 (NINHO DAS RAÍZES) chega ao PRÉ-BOSS após C5_M008 (elite ancient_root_heart). NÃO é "complete"
## (o Boss MATRIARCA DAS RAÍZES = root_matriarch é A44). Exact-once (unlock idempotente do GameState). A44 exigirá isto.
func chapter5_preboss_ready() -> bool:
	return gs != null and is_unlocked("CHAPTER_5_PREBOSS_READY")

## Missão atual (a 1ª da cadeia ainda não concluída) — o que a UI mostra como "próximo passo".
func current_mission() -> String:
	for mid in AfkMissionDefinition.chapter_chain(AfkMissionDefinition.CHAPTER_1):
		if not is_complete(mid): return mid
	return ""   # capítulo concluído

## Estado macro p/ HUD/telemetria.
func state() -> String:
	if gs == null: return "NOT_STARTED"
	var cur := current_mission()
	if cur == "": return "CHAPTER_1_COMPLETE"
	if cur == "MISSION_001" and not is_complete("MISSION_001"): return "CHAPTER_1_M001_AVAILABLE"
	return "CHAPTER_1_IN_PROGRESS"

## Missões que a UI deve LISTAR (§A18.19): a atual + as já concluídas; NÃO despeja futuras locked distantes.
func visible_missions() -> Array:
	var out: Array = []
	for mid in AfkMissionDefinition.chapter_chain(AfkMissionDefinition.CHAPTER_1):
		if is_complete(mid) or is_available(mid):
			out.append({"mission_id": mid, "complete": is_complete(mid), "available": is_available(mid)})
	if is_unlocked("REPEATABLE_WOLF"):
		out.append({"mission_id": "REPEATABLE_WOLF", "complete": false, "available": true, "repeatable": true})
	return out
