class_name NarrativeDirector extends Node
## FATIA A9 — DIRETOR NARRATIVO. Avalia condições, desbloqueia beats (AVAILABLE), rastreia SEEN/choices, replay,
## e integra com a UI/feedback. ★ NÃO controla progressão de stage (§14): o StageDirector nunca consulta isto.
## Idle-first: um jogador que ignora tudo joga 1→100→Prestígio normalmente. Unlock por FIRST-CLEAR de boss /
## capítulo alcançado (lifetime), NUNCA por nível. unlock ≠ seen (§16): offline desbloqueia mas NÃO marca seen /
## NÃO resolve choice / NÃO pausa (§23/§33). Rewards ficam no caminho exato-uma-vez existente (complete_quest) —
## o diretor NÃO concede reward (§38/§39, evita double-grant). Estado novo persistido: narrative_seen +
## narrative_choices (v9); SEEN também é inferido de `seen_dialogues` existente (§53, sem duplicar flags).

const ST_LOCKED := "LOCKED"
const ST_AVAILABLE := "AVAILABLE"
const ST_SEEN := "SEEN"

var _host = null

func setup(host) -> void:
	_host = host

func _gs():
	if _host != null and _host.has_method("get") and _host.get("_gs_ref") != null:
		return _host._gs_ref
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null

# ── extração de source_ref ──
static func _scene_id_of(beat: Dictionary) -> String:
	var ref := str(beat.get("source_ref", ""))
	for part in ref.split(";"):
		if part.begins_with("scene:"):
			return part.substr(6)
	return ""

# ── condição de unlock (robusta, idle-first) ──
func _reached_chapter(gs) -> int:
	var hi := int(gs.lifetime_highest_stage) if gs.get("lifetime_highest_stage") != null else 1
	hi = maxi(hi, int(gs.stage_highest_global))
	hi = maxi(hi, (int(gs.stage_chapter) - 1) * 10 + int(gs.stage_index))
	return ContentManifest.chapter_of(hi)

func unlock_met(beat: Dictionary, gs) -> bool:
	var u: Dictionary = beat.get("unlock", {})
	match str(u.get("kind", "")):
		"chapter_reached":
			return _reached_chapter(gs) >= int(u.get("value", 99))
		"boss_cleared":
			var bid := str(u.get("value", ""))
			return gs.has_defeated_boss(BossDefinition.display_name(bid))
		_:
			return false

# ── SEEN (persistido OU inferido de seen_dialogues existente, §53) ──
func is_seen(beat: Dictionary, gs) -> bool:
	var bid := str(beat.get("beat_id", ""))
	var seen_list: Array = gs.narrative_seen if gs.get("narrative_seen") != null else []
	if seen_list.has(bid):
		return true
	var scene := _scene_id_of(beat)
	if scene != "" and gs.has_seen_dialogue(scene):
		return true
	return false

func beat_state(beat: Dictionary, gs = null) -> String:
	if gs == null: gs = _gs()
	if gs == null: return ST_LOCKED
	if is_seen(beat, gs):
		return ST_SEEN
	if unlock_met(beat, gs):
		return ST_AVAILABLE
	return ST_LOCKED

# ── consultas ──
func available_unseen(gs = null) -> Array:
	if gs == null: gs = _gs()
	var out: Array = []
	if gs == null: return out
	for b in NarrativeManifest.beats():
		if beat_state(b, gs) == ST_AVAILABLE:
			out.append(b)
	return out

func seen_beats(gs = null) -> Array:
	if gs == null: gs = _gs()
	var out: Array = []
	if gs == null: return out
	for b in NarrativeManifest.beats():
		if beat_state(b, gs) == ST_SEEN:
			out.append(b)
	return out

## Badge só quando há disponível-não-visto (§26).
func pending_count(gs = null) -> int:
	return available_unseen(gs).size()

func has_badge(gs = null) -> bool:
	return pending_count(gs) > 0

# ── ações do jogador (marcam seen / choice; NUNCA offline) ──
## Abrir um beat marca SEEN (no momento correto — quando o jogador realmente abre, §16/§STORYUI-T04).
func open_beat(beat_id: String, gs = null) -> bool:
	if gs == null: gs = _gs()
	if gs == null: return false
	var b := NarrativeManifest.beat(beat_id)
	if b.is_empty(): return false
	if beat_state(b, gs) == ST_LOCKED: return false   # não abre o que não desbloqueou
	if gs.get("narrative_seen") == null: gs.narrative_seen = []
	if not gs.narrative_seen.has(beat_id):
		gs.narrative_seen.append(beat_id)
		gs._dirty = true
	return true

## Registra escolha EXATO-UMA-VEZ (§34/§55): se já escolhida, mantém (replay não troca).
func record_choice(beat_id: String, choice_id: String, gs = null) -> bool:
	if gs == null: gs = _gs()
	if gs == null: return false
	var b := NarrativeManifest.beat(beat_id)
	if b.is_empty(): return false
	if not (b.get("choice_ids", []) as Array).has(choice_id): return false   # escolha inválida
	if gs.get("narrative_choices") == null: gs.narrative_choices = {}
	if gs.narrative_choices.has(beat_id):
		return false   # já consolidada — replay NÃO altera (§34)
	gs.narrative_choices[beat_id] = choice_id
	gs._dirty = true
	return true

func choice_of(beat_id: String, gs = null) -> String:
	if gs == null: gs = _gs()
	if gs == null: return ""
	if gs.get("narrative_choices") != null and gs.narrative_choices.has(beat_id):
		return str(gs.narrative_choices[beat_id])
	# fallback: escolha antiga registrada na cena (choices[sceneId]) — §53 sem duplicar
	var b := NarrativeManifest.beat(beat_id)
	var scene := _scene_id_of(b)
	if scene != "" and gs.get("choices") != null and gs.choices.has(scene):
		return str(gs.choices[scene])
	return ""

# ── OFFLINE / avaliação (desbloqueia; NÃO marca seen; NÃO resolve choice; NÃO pausa) ──
## Compara o conjunto AVAILABLE atual com um snapshot anterior de ids; retorna os ids recém-disponíveis.
func newly_available(prev_available_ids: Array, gs = null) -> Array:
	var now := available_unseen(gs)
	var out: Array = []
	for b in now:
		if not prev_available_ids.has(str(b["beat_id"])):
			out.append(str(b["beat_id"]))
	return out

func available_ids(gs = null) -> Array:
	var out: Array = []
	for b in available_unseen(gs):
		out.append(str(b["beat_id"]))
	return out

# ── canon/timing ──
## Nenhum beat integrado revela algo antes do capítulo permitido (regra de ouro, CANON-T04).
func canon_timing_ok() -> bool:
	for b in NarrativeManifest.beats():
		if str(b.get("status", "")) != "INTEGRATED":
			continue
		var ch := int(b["chapter"])
		for topic in b.get("reveals", []):
			if not NarrativeCanon.revelation_allowed_at(str(topic), ch):
				return false
	return true

## Modelo p/ o StoryPanel (sem vazar iid/flags internas §STORYUI-T06): [{beat_id,title,chapter,type,state,choice,replay}]
func panel_model(gs = null) -> Array:
	if gs == null: gs = _gs()
	var out: Array = []
	if gs == null: return out
	for b in NarrativeManifest.beats():
		var st := beat_state(b, gs)
		if st == ST_LOCKED:
			continue   # painel mostra só disponíveis/vistos (não spoila trancados)
		out.append({
			"beat_id": str(b["beat_id"]), "title": str(b["title"]), "chapter": int(b["chapter"]),
			"type": str(b["type"]), "state": st, "choice": choice_of(str(b["beat_id"]), gs),
			"replay": bool(b.get("replayable", false)) and st == ST_SEEN,
		})
	return out
