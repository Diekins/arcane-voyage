class_name NarrativeManifest
## FATIA A9 — MANIFESTO NARRATIVO (beats). SEPARADO do ContentManifest (§13): referencia chapter/boss mas o
## StageDirector NÃO depende disto. Cada beat vem SÓ do canon (source_ref → cena/quest canônica); onde não há
## beat canônico apropriado ⇒ registrado como NO_CANON_BEAT (nada de fanfic §12/§49). Triggers ROBUSTOS
## (first-clear de boss / capítulo alcançado), NUNCA player_level (offline pode ultrapassar níveis §17). Beats de
## revelação respeitam o timing da regra de ouro (NarrativeCanon.FORBIDDEN_EARLY). Rewards NÃO são concedidos
## aqui (o caminho exato-uma-vez existente `complete_quest` continua dono — §38/§39; evita double-grant).
##
## Campos por beat: beat_id, title, chapter(gameplay), type, unlock{kind,value}, source_ref, replayable,
## choice_ids[], reward_ref (quest id — só rastreio), reveals[], status.
## unlock.kind ∈ "chapter_reached" (value=capítulo) | "boss_cleared" (value=boss_id).
## type ∈ INTRO | BOSS | CHARACTER | CHOICE | ENDING.

const BEATS := [
	{
		"beat_id": "b-intro-awakening", "title": "I — O Despertar do Errante", "chapter": 1, "type": "INTRO",
		"unlock": {"kind": "chapter_reached", "value": 1}, "source_ref": "campaign_acts:act-1;scene:intro-mentor",
		"replayable": true, "choice_ids": [], "reward_ref": "", "reveals": [], "status": "INTEGRATED",
	},
	{
		"beat_id": "b-wolf-alpha", "title": "O Guardião do Primeiro Medo", "chapter": 1, "type": "BOSS",
		"unlock": {"kind": "boss_cleared", "value": "wolf-alpha"}, "source_ref": "quest:ch1-awakening;scene:guardian-felled",
		"replayable": true, "choice_ids": [], "reward_ref": "ch1-awakening", "reveals": [], "status": "INTEGRATED",
	},
	{
		"beat_id": "b-crystal-golem", "title": "O Coração de Cristal", "chapter": 2, "type": "BOSS",
		"unlock": {"kind": "boss_cleared", "value": "crystal-golem"}, "source_ref": "quest:ch2-crystal-heart;scene:golem-felled",
		"replayable": true, "choice_ids": [], "reward_ref": "ch2-crystal-heart", "reveals": [], "status": "INTEGRATED",
	},
	{
		"beat_id": "b-magma-dragon", "title": "O Pacto Magmático", "chapter": 3, "type": "BOSS",
		"unlock": {"kind": "boss_cleared", "value": "magma-dragon"}, "source_ref": "quest:ch3-magma-pact;scene:drago-felled",
		"replayable": true, "choice_ids": [], "reward_ref": "ch3-magma-pact", "reveals": [], "status": "INTEGRATED",
	},
	{
		"beat_id": "b-time-devourer", "title": "A Hora Devorada", "chapter": 4, "type": "BOSS",
		"unlock": {"kind": "boss_cleared", "value": "time-devourer"}, "source_ref": "quest:ch4-time-eater;scene:devourer-felled",
		"replayable": true, "choice_ids": [], "reward_ref": "ch4-time-eater", "reveals": [], "status": "INTEGRATED",
	},
	{
		"beat_id": "b-faceless-archivist", "title": "O Arquivista Sem Rosto", "chapter": 5, "type": "CHARACTER",
		"unlock": {"kind": "boss_cleared", "value": "faceless-archivist"}, "source_ref": "quest:ch6-archivist;scene:archivist-felled",
		"replayable": true, "choice_ids": [], "reward_ref": "ch6-archivist", "reveals": ["arquivo_vazio", "aethelgard_city"], "status": "INTEGRATED",
	},
	{
		"beat_id": "b-broken-oath", "title": "O Juramento Partido", "chapter": 6, "type": "CHOICE",
		"unlock": {"kind": "boss_cleared", "value": "broken-oath"}, "source_ref": "quest:ch7-broken-oath;scene:oath-parted-felled",
		"replayable": true, "choice_ids": ["reveal", "seal", "dissolve", "reforge"], "reward_ref": "ch7-broken-oath", "reveals": [], "status": "INTEGRATED",
	},
	{
		"beat_id": "b-nameless-saint", "title": "O Santo Sem Memória", "chapter": 7, "type": "CHOICE",
		"unlock": {"kind": "boss_cleared", "value": "nameless-saint"}, "source_ref": "quest:ch8-nameless-saint;scene:saint-felled",
		"replayable": true, "choice_ids": ["accept", "refuse", "name_self"], "reward_ref": "ch8-nameless-saint", "reveals": ["errante_nature", "panteao"], "status": "INTEGRATED",
	},
	{
		"beat_id": "b-threshold-guardian", "title": "O Guardião do Limiar", "chapter": 8, "type": "BOSS",
		"unlock": {"kind": "boss_cleared", "value": "threshold-guardian"}, "source_ref": "quest:ch9-last-trail;scene:threshold-felled",
		"replayable": true, "choice_ids": [], "reward_ref": "ch9-last-trail", "reveals": [], "status": "INTEGRATED",
	},
	{
		# ★ FINALE canônico: A Última Escolha (5 finais). Ancorado no first-clear da SOMBRA = capítulo de GAMEPLAY 9
		# (NÃO no cap 10/aethelgard). AVAILABLE, nunca forçado; NUNCA bloqueia Prestígio (§44).
		"beat_id": "b-shadow-final", "title": "A Última Escolha", "chapter": 9, "type": "ENDING",
		"unlock": {"kind": "boss_cleared", "value": "shadow-between-worlds"}, "source_ref": "quest:ch10-true-name;scene:shadow-final;endings.json",
		"replayable": true, "choice_ids": ["cycle", "rupture", "preservation", "new_name", "last_trail"], "reward_ref": "ch10-true-name",
		"reveals": ["sombra", "nome_verdadeiro", "elyra"], "status": "INTEGRATED",
	},
]

## Capítulos de gameplay SEM beat canônico (§12) — registrado, não preenchido com fanfic.
const NO_CANON_BEAT_CHAPTERS := [10]   # cap 10 = aethelgard (boss órfão/placeholder; ver NarrativeCanon UNRESOLVED)

## Conteúdo canônico que existe em DADOS mas falta produzir/reconciliar no runtime (§49/§53-relatório).
const CANON_CONTENT_REQUIRED := [
	"Ato 6 'Devorador do Tempo' (bíblia PARCIAL, fora da cadeia de dados) — não integrado",
	"Coroação/'Ancestrais' (Ato V after-throne) — CONFLITO temático com anti-coroação do runtime (UNRESOLVED)",
	"Reflexão dinâmica de escolhas no final (hook futuro na web, não implementado)",
	"Cap 10 (aethelgard): sem beat canônico — divergência cidade-vs-boss a reconciliar",
]

# ── API ──
static func beats() -> Array:
	return BEATS

static func beat(beat_id: String) -> Dictionary:
	for b in BEATS:
		if str(b["beat_id"]) == beat_id:
			return b
	return {}

static func beats_for_chapter(ch: int) -> Array:
	var out: Array = []
	for b in BEATS:
		if int(b["chapter"]) == ch:
			out.append(b)
	return out

## Todo beat integrado tem source_ref? (CANON-T01)
static func all_have_source() -> bool:
	for b in BEATS:
		if str(b["status"]) == "INTEGRATED" and str(b.get("source_ref", "")) == "":
			return false
	return true

## Nenhum beat integrado usa gatilho por nível? (§17)
static func no_level_triggers() -> bool:
	for b in BEATS:
		if str(b["unlock"]["kind"]) == "player_level":
			return false
	return true

static func choice_beats() -> Array:
	var out: Array = []
	for b in BEATS:
		if not (b.get("choice_ids", []) as Array).is_empty():
			out.append(b)
	return out
