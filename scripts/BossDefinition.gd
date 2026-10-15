class_name BossDefinition
## FATIA A7.4 — DEFINIÇÃO DATA-DRIVEN dos 10 bosses do 1º ciclo. Cada boss é: nome + hp_mult + COMPOSIÇÃO de
## 3–5 habilidades (por nome de preset da BossAbilityLibrary) + timings + status. NÃO cria lore (A9 reconcilia);
## os nomes são PISTA FUNCIONAL de identidade mecânica (§12), não história.
##
## STATUS separado (§10/§24):
##   gameplay: "READY" — o encontro EXECUTA (Wolf/Golem por script próprio; os 8 via BossController genérico).
##   art:      "PRESENT" (Lobo/Golem têm arte) · "REQUIRED" (usa visual placeholder; sprite final falta).
##
## `script` != "" ⇒ o boss tem script de combate DEDICADO (Wolf.gd/Golem.gd) — PRESERVADOS, não reescritos.
## `script` == "" ⇒ o encontro roda no BossController genérico consumindo estas abilities.
##
## `identity` = tag curta do sabor de gameplay (composição-assinatura). Cada boss é mecanicamente distinto
## (§11: nada de clone só-HP): a lista de abilities de cada um difere em pelo menos uma mecânica.

const DEFS := {
	# ── READY + ARTE (scripts dedicados preservados; abilities listadas p/ referência/migração futura) ──
	"wolf-alpha": {
		"name": "Lobo Alfa", "gameplay": "READY", "art": "PRESENT", "script": "Wolf.gd",
		"hp_mult": 1.0, "identity": "investida + mordida (frase de 2 golpes)",
		"abilities": ["lunge_line", "bite_cone"],
	},
	"crystal-golem": {
		"name": "Golem de Cristal", "gameplay": "READY", "art": "PRESENT", "script": "Golem.gd",
		"hp_mult": 1.15, "identity": "esmagamento em cone + onda de cristal no chão",
		"abilities": ["bite_cone", "crystal_wave"],
	},
	# ── GAMEPLAY_READY + ART_REQUIRED (8 canônicos, encontro no BossController) ──
	"magma-dragon": {
		"name": "Drago Magmático", "gameplay": "READY", "art": "REQUIRED", "script": "",
		"hp_mult": 1.2, "identity": "área + projétil + poça de lava, enfurece em 40% HP",
		"abilities": ["slam_circle", "bolt", "lava_pool", "phase_enrage"],
	},
	"time-devourer": {
		"name": "Devorador do Tempo", "gameplay": "READY", "art": "REQUIRED", "script": "",
		"hp_mult": 1.25, "identity": "teleporta, abre fenda temporal (hazard), enfurece",
		"abilities": ["phase_shift", "time_rift", "bolt", "phase_enrage"],
	},
	"faceless-archivist": {
		"name": "Arquivista sem Rosto", "gameplay": "READY", "art": "REQUIRED", "script": "",
		"hp_mult": 1.2, "identity": "invoca cascas, leque de 5 projéteis, escudo parcial",
		"abilities": ["raise_husks", "fan_of_five", "partial_ward"],
	},
	"broken-oath": {
		"name": "O Juramento Partido", "gameplay": "READY", "art": "REQUIRED", "script": "",
		"hp_mult": 1.3, "identity": "fecha distância (charge), corta em cone, último fôlego a 25% HP",
		"abilities": ["gap_close", "bite_cone", "slam_circle", "last_stand"],
	},
	"nameless-saint": {
		"name": "O Santo sem Memória", "gameplay": "READY", "art": "REQUIRED", "script": "",
		"hp_mult": 1.25, "identity": "cura-se, consagra o chão (hazard), ergue égide (escudo)",
		"abilities": ["mend", "holy_ground", "aegis", "bolt"],
	},
	"threshold-guardian": {
		"name": "O Guardião do Limiar", "gameplay": "READY", "art": "REQUIRED", "script": "",
		"hp_mult": 1.35, "identity": "escudo + esmagamento + convoca guarda + investida",
		"abilities": ["aegis", "slam_circle", "call_pack", "gap_close"],
	},
	"shadow-between-worlds": {
		"name": "A Sombra entre Mundos", "gameplay": "READY", "art": "REQUIRED", "script": "",
		"hp_mult": 1.4, "identity": "salta (teleport), rajada tripla, invoca, enfurece",
		"abilities": ["phase_shift", "triple_bolt", "raise_husks", "phase_enrage"],
	},
	"aethelgard": {
		"name": "Aethelgard", "gameplay": "READY", "art": "REQUIRED", "script": "",
		"hp_mult": 1.6, "identity": "boss final: égide + salto + leque + lava + último fôlego (5 mecânicas)",
		"abilities": ["aegis", "phase_shift", "fan_of_five", "lava_pool", "last_stand"],
	},
}

static func get_def(boss_id: String) -> Dictionary:
	return DEFS.get(boss_id, {})

static func exists(boss_id: String) -> bool:
	return DEFS.has(boss_id)

static func all_ids() -> Array:
	return DEFS.keys()

## Nome de exibição do boss.
static func display_name(boss_id: String) -> String:
	return str(get_def(boss_id).get("name", boss_id))

## Lista de abilities COMPOSTAS (Dictionaries prontos) do boss.
static func abilities_of(boss_id: String) -> Array:
	return BossAbilityLibrary.compose(get_def(boss_id).get("abilities", []))

## Nomes de preset das abilities (sem compor).
static func ability_names(boss_id: String) -> Array:
	return get_def(boss_id).get("abilities", [])

static func gameplay_status(boss_id: String) -> String:
	return str(get_def(boss_id).get("gameplay", ""))

static func art_status(boss_id: String) -> String:
	return str(get_def(boss_id).get("art", ""))

## Script dedicado ("" se roda no BossController genérico).
static func script_of(boss_id: String) -> String:
	return str(get_def(boss_id).get("script", ""))

static func hp_mult(boss_id: String) -> float:
	return float(get_def(boss_id).get("hp_mult", 1.0))

static func identity(boss_id: String) -> String:
	return str(get_def(boss_id).get("identity", ""))

## Bosses por status de arte ("PRESENT"/"REQUIRED").
static func by_art(status: String) -> Array:
	var out: Array = []
	for k in DEFS:
		if str(DEFS[k].get("art", "")) == status:
			out.append(str(k))
	return out
