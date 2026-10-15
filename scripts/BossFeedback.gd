class_name BossFeedback
## FATIA A8 — DADOS DE FEEDBACK/IDENTIDADE de boss (puro, sem render). Mapeia cada habilidade a: um TELEGRAPH
## legível (forma consistente §9), um rótulo de FASE (ESCUDO/ENFURECIDO/... §11), e se é PERIGOSA (precisa de
## aviso antes do dano §10). Também define TEMPO por boss (§12/§13) — ritmo distinto sem script único. NÃO muda
## matemática nem cria lore.

## Formas de telegraph consistentes (§9). O render desenha; aqui é a IDENTIDADE + hook de áudio.
const TELEGRAPH := {
	"line": "LINE", "charge": "LINE",
	"cone": "CONE",
	"circle": "CIRCLE",
	"ground_aoe": "GROUND",
	"projectile": "PROJECTILE",
	"volley": "VOLLEY",
	"hazard": "HAZARD",
}

## Rótulo curto de FASE/estado (§11). Habilidades utilitárias mostram banner, não telegraph espacial.
const PHASE_LABEL := {
	"shield": "ESCUDO",
	"enrage": "ENFURECIDO",
	"summon": "INVOCANDO",
	"heal": "CURA",
	"teleport": "SALTO",
}

## Telegraph (forma) de uma habilidade; "" se não é um aviso espacial (utilitária).
static func telegraph_kind(ability_kind: String) -> String:
	return str(TELEGRAPH.get(ability_kind, ""))

## Rótulo de fase de uma habilidade utilitária; "" se não é de fase.
static func phase_label(ability_kind: String) -> String:
	return str(PHASE_LABEL.get(ability_kind, ""))

## Habilidade perigosa (causa dano direto ⇒ precisa de telegraph antes do hit, §10).
static func is_dangerous(ability_kind: String) -> bool:
	return TELEGRAPH.has(ability_kind)

## Habilidade de fase/estado (mostra banner curto, §11).
static func is_phase(ability_kind: String) -> bool:
	return PHASE_LABEL.has(ability_kind)

## ── TEMPO por boss (§12/§13): identidade de RITMO. Multiplica windup/cooldown do scheduler → cada boss "joga"
## num compasso diferente, mesmo compondo mecânicas parecidas. 1.0 = padrão; <1 mais rápido/agressivo; >1 mais
## lento/pesado. Escolhido pela FANTASIA funcional (não lore). Fonte única de tempo de boss.
const TEMPO := {
	"wolf-alpha": 0.9,            # ágil (frase rápida)
	"crystal-golem": 1.25,        # pesado, lento
	"magma-dragon": 1.0,          # equilibrado
	"time-devourer": 0.85,        # nervoso (teleporta, pressiona)
	"faceless-archivist": 1.1,    # cadenciado (invoca e atira)
	"broken-oath": 0.8,           # agressivo (charge/cleave)
	"nameless-saint": 1.2,        # ritualístico (cura, consagra — lento)
	"threshold-guardian": 1.15,   # muralha (escudo, esmaga)
	"shadow-between-worlds": 0.85,# errático
	"aethelgard": 0.95,           # final: denso mas legível
}

static func tempo(boss_id: String) -> float:
	return float(TEMPO.get(boss_id, 1.0))

## RITMO SAUDÁVEL (§13): pisos p/ o scheduler garantir counterplay — nunca spam contínuo nem chain inescapável.
const MIN_GAP_AFTER_HEAVY := 0.6   # s de folga após uma habilidade ofensiva pesada (janela de resposta)
const MAX_WINDUP := 1.4            # teto de windup (nunca "trava" o boss num aviso eterno)
const MIN_WINDUP_DANGEROUS := 0.3  # piso de aviso p/ habilidade perigosa ser LEGÍVEL (§10)

## Perfil de identidade legível (p/ teste/censo BUX): telegraph + fase por habilidade de um boss.
static func identity_profile(boss_id: String) -> Dictionary:
	var out := {"boss": BossDefinition.display_name(boss_id), "tempo": tempo(boss_id), "telegraphs": [], "phases": []}
	for a in BossDefinition.abilities_of(boss_id):
		var k := BossAbility.kind(a)
		if is_dangerous(k):
			out["telegraphs"].append(telegraph_kind(k))
		if is_phase(k):
			out["phases"].append(phase_label(k))
	return out
