class_name NarrativeCanon
## FATIA A9 — FONTE EXPLÍCITA DE CANON (a "uma regra" do §71). NÃO copia a bíblia inteira: fixa a HIERARQUIA DE
## AUTORIDADE, a MATRIZ DE CONFLITOS web×Godot (com decisão por linha), a lista de REVELAÇÕES PROIBIDAS-CEDO
## (regra de ouro do WORLD_IDENTITY_BIBLE) e o MAPA boss→canon (source_ref) que o NarrativeManifest/Director usam.
## Nada aqui inventa lore. Cada fato aponta a `source_ref` (arquivo canônico). NÃO gateia gameplay.
##
## ★ AUTORIDADE (como AUDITADO no repo — inverte a suposição inicial e é DOCUMENTADA, §4/§71):
##   N1  bíblia WEB (docs/NARRATIVE_BIBLE.md & complementares) = "base oficial" / "fonte da verdade".
##   N2  data/canonical/*.json = EXPORT DERIVADO FIEL da web (o runtime lê isto). N1≡N2 por construção (pipeline
##       `npm run export:canonical`; JSON "nunca editado à mão", CANONICAL_EXPORT.md).
##   N3  runtime Godot narrativo = implementa só Atos I–II do canon + ARCOS PRÓPRIOS não-bíblia (Raízes Negras,
##       Khet) — auto-declarados NÃO-CANÔNICOS (PROJECT_HANDOFF.md / LORE_RECONCILIATION). São gameplay, não canon.
##   N4  web `src/` = a própria fonte de N1 (referência); igual a N1/N2.
##   REGRA: para NARRATIVA, CANON = N1/N2 (concordam). O runtime (N3) NÃO derruba a bíblia (nenhum doc declara
##   isso). Onde runtime-invenção conflita com a bíblia → LEGACY_NONCANON (narrativa) mas PERMANECE gameplay.

const AUTHORITY := ["web_bible(N1)", "canonical_json(N2==N1)", "godot_runtime(N3)", "web_src(N4==N1)"]

## Revelações que a regra de ouro (WORLD_IDENTITY_BIBLE.md:6-9,107) PROÍBE cedo. Cada uma só pode aparecer num
## beat cujo capítulo de GAMEPLAY ≥ `min_chapter` (o capítulo em que o canon a revela, via boss/quest). Assim o
## idle-first (unlock por first-clear tardio) já respeita o timing: nada de Sombra/Nome/Aethelgard no cap 1-4.
const FORBIDDEN_EARLY := {
	"errante_nature": 7,          # "Errante = sentença divina" — Ato V (saint-felled) ⇒ gameplay cap 7
	"nome_verdadeiro": 9,         # entregue ao Arquivo — clímax (shadow-final) ⇒ cap 9
	"sombra": 9,                  # A Sombra Entre Mundos = o Arquivo que aprendeu ⇒ cap 9
	"arquivo_vazio": 5,           # Arquivo/Aethelgard "preservada demais" — Arquivista ⇒ cap 5
	"panteao": 7,                 # Conclave/6 deuses ⇒ Ato V, cap 7
	"elyra": 9,                   # Elyra apagada, voz na Sombra ⇒ clímax cap 9
	"aethelgard_city": 5,         # Aethelgard = cidade arquivada (NÃO boss) ⇒ Arquivista cap 5
}

## MAPA boss_id → fato canônico. `chapter_gp` = capítulo de GAMEPLAY (ContentManifest) que derrota este boss;
## `quest`/`scene` = ids canônicos (source_ref); `reveals` = tópicos revelados (checados contra FORBIDDEN_EARLY);
## `status`: INTEGRATED | NO_CANON_BEAT | UNRESOLVED. NÃO reescreve o ContentManifest (gameplay §13).
const BOSS_CANON := {
	"wolf-alpha":            {"chapter_gp": 1, "quest": "ch1-awakening",     "scene": "guardian-felled",    "reveals": [],                 "status": "INTEGRATED"},
	"crystal-golem":         {"chapter_gp": 2, "quest": "ch2-crystal-heart",  "scene": "golem-felled",       "reveals": [],                 "status": "INTEGRATED"},
	"magma-dragon":          {"chapter_gp": 3, "quest": "ch3-magma-pact",     "scene": "drago-felled",       "reveals": [],                 "status": "INTEGRATED"},
	"time-devourer":         {"chapter_gp": 4, "quest": "ch4-time-eater",     "scene": "devourer-felled",    "reveals": [],                 "status": "INTEGRATED"},
	"faceless-archivist":    {"chapter_gp": 5, "quest": "ch6-archivist",      "scene": "archivist-felled",   "reveals": ["arquivo_vazio", "aethelgard_city"], "status": "INTEGRATED"},
	"broken-oath":           {"chapter_gp": 6, "quest": "ch7-broken-oath",    "scene": "oath-parted-felled", "reveals": [],                 "status": "INTEGRATED"},
	"nameless-saint":        {"chapter_gp": 7, "quest": "ch8-nameless-saint", "scene": "saint-felled",       "reveals": ["errante_nature", "panteao"], "status": "INTEGRATED"},
	"threshold-guardian":    {"chapter_gp": 8, "quest": "ch9-last-trail",     "scene": "threshold-felled",   "reveals": [],                 "status": "INTEGRATED"},
	"shadow-between-worlds": {"chapter_gp": 9, "quest": "ch10-true-name",     "scene": "shadow-final",       "reveals": ["sombra", "nome_verdadeiro", "elyra"], "status": "INTEGRATED"},
	# cap 10 gameplay = "aethelgard" (boss ÓRFÃO/PLACEHOLDER do ContentManifest, A7.3). No CANON, Aethelgard é uma
	# CIDADE (Ato III), NÃO um boss; o clímax canônico é a Sombra (cap 9). ⇒ NO_CANON_BEAT + divergência UNRESOLVED.
	"aethelgard":            {"chapter_gp": 10, "quest": "", "scene": "",     "reveals": [],                 "status": "NO_CANON_BEAT"},
}

## MATRIZ DE CONFLITOS (§5) — cada linha: topic / source_a / source_b / conflict / authority / decision / impact.
## decision ∈ CANON | LEGACY_NONCANON | PRESENTATION_ONLY | UNRESOLVED. Nada "resolvido" em silêncio.
const CONFLICT_MATRIX := [
	{"topic": "Autoridade narrativa", "a": "web bible = fonte da verdade (CANONICAL_EXPORT.md)", "b": "runtime Godot divergiu (PROJECT_HANDOFF.md)",
	 "conflict": "hierarquia suposta invertida", "authority": "N1/N2", "decision": "CANON", "impact": "canon = bíblia/canonical JSON; runtime-invenção = legado"},
	{"topic": "Aethelgard", "a": "canon: CIDADE arquivada (Ato III), boss=faceless-archivist", "b": "ContentManifest cap10 boss_id='aethelgard' (órfão/placeholder)",
	 "conflict": "cidade vs boss; posição de clímax", "authority": "N1/N2 (narrativa) × gameplay", "decision": "UNRESOLVED", "impact": "cap10 boss é GAMEPLAY-only; sem beat canônico; clímax narrativo fica no cap 9 (Sombra)"},
	{"topic": "Clímax / final", "a": "canon: Sombra Entre Mundos = A Última Escolha (5 finais), ch10-true-name", "b": "gameplay: 10-10 = Aethelgard (marco mecânico)",
	 "conflict": "final narrativo ≠ boss final de gameplay", "authority": "N1/N2", "decision": "CANON", "impact": "beat de final ancorado no first-clear de shadow-between-worlds (cap 9), NÃO no cap 10; nunca bloqueia Prestígio (§44)"},
	{"topic": "Coroação", "a": "web: 'coroado pelos Ancestrais' (campaign.ts after-throne)", "b": "Godot: anti-coroação ('não te aplaude', FANTASY_OF_THE_WANDERER)",
	 "conflict": "tema oposto", "authority": "conflito de mesma autoridade", "decision": "UNRESOLVED", "impact": "NÃO integro a cena de coroação; marcado CANON_CONTENT_REQUIRED"},
	{"topic": "Arcos Raízes Negras / Khet", "a": "runtime Godot (regiões jogáveis)", "b": "ausentes na bíblia (auto-declarado)",
	 "conflict": "conteúdo runtime fora do canon", "authority": "N3", "decision": "LEGACY_NONCANON", "impact": "permanecem GAMEPLAY (ContentManifest); geram 0 beat canônico"},
	{"topic": "Nexo", "a": "web: ascensão vertical/Tier de Alma + passagem da Fenda (não personagem)", "b": "PrestigeMath usa 'Nexo'=prestígio",
	 "conflict": "nenhum", "authority": "N1==N3", "decision": "PRESENTATION_ONLY", "impact": "consistente; sem ação"},
	{"topic": "Gates de quest (requires level/nexo)", "a": "canon: campaign_quests.requires", "b": "runtime NÃO os lê (inertes)",
	 "conflict": "gate declarado mas não aplicado", "authority": "N3 (gameplay)", "decision": "PRESENTATION_ONLY", "impact": "idle-first já não depende deles; NÃO reativar (§37)"},
	{"topic": "Ato 6 'Devorador'", "a": "bíblia: Ato 6 PARCIAL/proposto (STORY_ACTS.md)", "b": "data: fora da cadeia; runtime só Atos I–II",
	 "conflict": "completude alegada", "authority": "N1/N2", "decision": "UNRESOLVED", "impact": "não integro 'Ato 6 Devorador'; Ato VI (A Última Trilha) é canon-em-dados mas CANON_CONTENT_REQUIRED no runtime"},
]

# ── API ──
static func authority() -> Array:
	return AUTHORITY

static func matrix() -> Array:
	return CONFLICT_MATRIX

static func boss_canon(boss_id: String) -> Dictionary:
	return BOSS_CANON.get(boss_id, {})

## Um beat que revela `topic` pode aparecer no capítulo de gameplay `chapter_gp`? (respeita a regra de ouro §timing)
static func revelation_allowed_at(topic: String, chapter_gp: int) -> bool:
	if not FORBIDDEN_EARLY.has(topic):
		return true
	return chapter_gp >= int(FORBIDDEN_EARLY[topic])

## Todos os `reveals` de um boss respeitam o timing no capítulo dele? (CANON-T04)
static func boss_reveals_ok(boss_id: String) -> bool:
	var bc := boss_canon(boss_id)
	if bc.is_empty():
		return true
	var ch := int(bc.get("chapter_gp", 99))
	for topic in bc.get("reveals", []):
		if not revelation_allowed_at(str(topic), ch):
			return false
	return true

## Conflitos por decisão (p/ relatório/teste).
static func by_decision(decision: String) -> Array:
	var out: Array = []
	for row in CONFLICT_MATRIX:
		if str(row["decision"]) == decision:
			out.append(row)
	return out
