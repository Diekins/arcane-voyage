class_name BossAbilityLibrary
## FATIA A7.4 — BIBLIOTECA de habilidades REUTILIZÁVEIS (presets nomeados). As BossDefinition compõem por
## NOME (preset "..."), então a mesma mecânica (ex.: "meteor_hazard", "phase_enrage") é declarada UMA vez e
## reusada em vários bosses — sem clonar lógica. Cada preset retorna um Dictionary NOVO (via BossAbility).
## `dmg` é a magnitude BASE da habilidade; o BossController escala pelo dano do boss na fase (ProgressionMath).

## Presets → builder. Mantém o catálogo num só lugar (fonte única de mecânicas nomeadas).
static func preset(name: String) -> Dictionary:
	match name:
		# — reutilizadas (formas já existentes no jogo) —
		"bite_cone":        return BossAbility.cone("bite_cone", 14, 156.0, 82.0, 0.45, 2.0)
		"lunge_line":       return BossAbility.line("lunge_line", 16, 235.0, 0.5, 2.4)
		"slam_circle":      return BossAbility.circle("slam_circle", 18, 150.0, 0.6, 3.2)
		"crystal_wave":     return BossAbility.ground_aoe("crystal_wave", 20, 116.0, 0.95, 7.0)
		"gap_close":        return BossAbility.charge("gap_close", 18, 320.0, 0.5, 5.0)
		"bolt":             return BossAbility.projectile("bolt", 12, 620.0, 0.4, 2.5)
		# — NOVA #6 volley —
		"triple_bolt":      return BossAbility.volley("triple_bolt", 11, 3, 620.0, 0.55, 4.0)
		"fan_of_five":      return BossAbility.volley("fan_of_five", 10, 5, 640.0, 0.6, 5.0)
		# — NOVA #1 shield —
		"aegis":            return BossAbility.shield("aegis", 3.0, 12.0, 1.0)
		"partial_ward":     return BossAbility.shield("partial_ward", 2.5, 10.0, 0.6)
		# — NOVA #2 enrage —
		"phase_enrage":     return BossAbility.enrage("phase_enrage", 0.4, 1.5, 1.25)
		"last_stand":       return BossAbility.enrage("last_stand", 0.25, 1.8, 1.4)
		# — NOVA #3 summon —
		"call_pack":        return BossAbility.summon("call_pack", "young_wolf", 2, 4, 10.0)
		"raise_husks":      return BossAbility.summon("raise_husks", "hollow_husk", 2, 3, 12.0)
		# — NOVA #4 teleport —
		"blink":            return BossAbility.teleport("blink", 380.0, 8.0)
		"phase_shift":      return BossAbility.teleport("phase_shift", 460.0, 6.0)
		# — NOVA #5 heal —
		"mend":             return BossAbility.heal("mend", 0.12, 9.0, 3)
		"siphon":           return BossAbility.heal("siphon", 0.08, 7.0, 5)
		# — NOVA #7 hazard —
		"lava_pool":        return BossAbility.hazard("lava_pool", 10, 130.0, 6.0, 8.0, 3)
		"time_rift":        return BossAbility.hazard("time_rift", 9, 120.0, 5.0, 7.0, 3)
		"holy_ground":      return BossAbility.hazard("holy_ground", 11, 110.0, 5.0, 9.0, 2)
		_:
			push_warning("BossAbilityLibrary: preset desconhecido '%s'" % name)
			return {}

## Compõe uma lista de abilities a partir de nomes de preset (ignora inválidos, avisando).
static func compose(names: Array) -> Array:
	var out: Array = []
	for n in names:
		var a := preset(str(n))
		if not a.is_empty():
			out.append(a)
	return out

## Todos os nomes de preset conhecidos (p/ validação/censo).
static func preset_names() -> Array:
	return [
		"bite_cone", "lunge_line", "slam_circle", "crystal_wave", "gap_close", "bolt",
		"triple_bolt", "fan_of_five", "aegis", "partial_ward", "phase_enrage", "last_stand",
		"call_pack", "raise_husks", "blink", "phase_shift", "mend", "siphon",
		"lava_pool", "time_rift", "holy_ground",
	]
