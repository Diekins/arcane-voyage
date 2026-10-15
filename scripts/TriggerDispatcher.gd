extends Node
## TriggerDispatcher (autoload) — GODOT-TRIGGER-1.
##
## Porta FIEL de `evaluateCampaignTrigger` (src/lib/campaign.ts): itera as cenas de
## `DataLoader.scenes_ordered` **na ordem do JSON**, pula as já vistas (`GameState`), e
## devolve a PRIMEIRA cena cujo trigger casa com o estado/evento:
##   • level          → dispara se `nível_atual >= trigger.level`
##   • quest_complete → dispara se `trigger.questId == quest concluída`
##   • boss_defeated  → dispara se `trigger.bossName`/`bossId` casa o boss derrotado
##   • manual/direct  → por id (dispatch_scene), IGNORA "já visto" (p/ re-testar)
##
## Não abre a UI diretamente: emite `request_scene(scene)` e o Main mostra no DialoguePanel.

signal request_scene(scene: Dictionary)

func find_scene_by_id(scene_id: String) -> Dictionary:
	return DataLoader.scene(scene_id)

## 1ª cena de nível NÃO vista cujo `trigger.level <= level`.
func find_for_level(level: int) -> Dictionary:
	for s in DataLoader.scenes_ordered:
		if GameState.has_seen_dialogue(str(s.get("id", ""))):
			continue
		var t: Dictionary = s.get("trigger", {})
		if str(t.get("kind", "")) == "level" and level >= int(t.get("level", 1 << 30)):
			return s
	return {}

## 1ª cena quest_complete NÃO vista que casa o quest_id.
func find_for_quest(quest_id: String) -> Dictionary:
	for s in DataLoader.scenes_ordered:
		if GameState.has_seen_dialogue(str(s.get("id", ""))):
			continue
		var t: Dictionary = s.get("trigger", {})
		if str(t.get("kind", "")) == "quest_complete" and str(t.get("questId", "")) == quest_id:
			return s
	return {}

## 1ª cena boss_defeated NÃO vista que casa o boss (por bossName case-insensitive OU bossId).
func find_for_boss(boss: String) -> Dictionary:
	var b := boss.to_lower()
	for s in DataLoader.scenes_ordered:
		if GameState.has_seen_dialogue(str(s.get("id", ""))):
			continue
		var t: Dictionary = s.get("trigger", {})
		if str(t.get("kind", "")) != "boss_defeated":
			continue
		var by_name := str(t.get("bossName", "")).to_lower() == b
		var bid := str(t.get("bossId", ""))
		var by_id := bid != "" and bid == boss
		if by_name or by_id:
			return s
	return {}

## "O que dispara agora?" — usa o nível atual do herói.
func find_next_scene_for_state() -> Dictionary:
	return find_for_level(GameState.hero_level)

## --- dispatchers (emitem request_scene) ---

func dispatch_scene(scene_id: String) -> bool:
	var s := find_scene_by_id(scene_id)
	if s.is_empty():
		push_error("[Dispatcher] cena '%s' não existe no export." % scene_id)
		return false
	request_scene.emit(s)
	return true

func dispatch_next() -> bool:
	var s := find_next_scene_for_state()
	if s.is_empty():
		print("[Dispatcher] nenhuma cena de nível pendente para level %d." % GameState.hero_level)
		return false
	request_scene.emit(s)
	return true

func dispatch_event(event_type: String, payload) -> bool:
	var s: Dictionary = {}
	match event_type:
		"level":
			var lvl: int = int(payload) if payload != null else GameState.hero_level
			s = find_for_level(lvl)
		"quest_complete":
			s = find_for_quest(str(payload))
		"boss_defeated":
			s = find_for_boss(str(payload))
		_:
			push_error("[Dispatcher] event_type desconhecido: %s" % event_type)
			return false
	if s.is_empty():
		print("[Dispatcher] nenhuma cena pendente para %s = %s." % [event_type, str(payload)])
		return false
	request_scene.emit(s)
	return true
