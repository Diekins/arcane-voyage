class_name EnvironmentWindProfile extends RefCounted
## A28 — VENTO. Perfis data-driven + FASE determinística por prop (nada de grama toda balançando igual §24). Direção/
## força-base/rajada/frequência/ruído (§25). O shader real aplica UV-vertical (base parada, pontas movem §22) — aqui
## ficam os PARÂMETROS e a matemática determinística (testável headless; o shader é a camada visual/FIELD).

const PROFILES := {
	"PLAINS_BREEZE": {"direction": 20.0, "base_strength": 0.6, "gust_strength": 0.9, "gust_frequency": 0.12, "noise_scale": 0.8, "speed": 1.0},
	"GROVE_STILL": {"direction": -10.0, "base_strength": 0.35, "gust_strength": 0.7, "gust_frequency": 0.08, "noise_scale": 1.1, "speed": 0.8},
	"SALT_WIND_NORMAL": {"direction": 35.0, "base_strength": 0.85, "gust_strength": 1.1, "gust_frequency": 0.16, "noise_scale": 0.7, "speed": 1.2},   # A29 — costa mais ventosa (legível)
	"WIND_OFF": {"direction": 0.0, "base_strength": 0.0, "gust_strength": 0.0, "gust_frequency": 0.0, "noise_scale": 1.0, "speed": 0.0},
}

# força relativa por perfil de vento do prop (§23)
const PROP_WIND_MULT := {"WIND_NONE": 0.0, "WIND_LIGHT": 0.4, "WIND_NORMAL": 0.75, "WIND_FULL": 1.0}

static func exists(id: String) -> bool: return PROFILES.has(id)
static func get_profile(id: String) -> Dictionary: return PROFILES.get(id, PROFILES["WIND_OFF"]).duplicate(true)

## Fase/variância DETERMINÍSTICA de um prop (seed + índice) — sem RNG global (reload = mesmo balanço §24).
static func phase_for(seed_val: int, index: int) -> Dictionary:
	var h := int(abs((seed_val * 2654435761 + index * 40503 + 12345)))
	var phase := float(h % 6283) / 1000.0                    # 0..2π
	var strength_var := 0.8 + float((h / 6283) % 40) / 100.0  # 0.8..1.2
	var speed_var := 0.85 + float((h / 251) % 30) / 100.0     # 0.85..1.15
	return {"phase": phase, "strength_var": strength_var, "speed_var": speed_var}

## Deslocamento de balanço no tempo t (para prop com wind_profile `prop_wind`), sob o perfil `wind_id`. Base≈0, ponta
## móvel. Determinístico. Retorna o offset horizontal normalizado (-1..1 aprox) na PONTA (o shader pesa por UV.y).
static func sway_tip(wind_id: String, prop_wind: String, seed_val: int, index: int, t: float) -> float:
	var wp := get_profile(wind_id)
	var mult := float(PROP_WIND_MULT.get(prop_wind, 0.0))
	if mult <= 0.0: return 0.0
	var ph := phase_for(seed_val, index)
	var base := float(wp["base_strength"]) * float(ph["strength_var"])
	var speed := float(wp["speed"]) * float(ph["speed_var"])
	var main := sin(t * speed + float(ph["phase"]))
	var gust := float(wp["gust_strength"]) * float(wp["gust_frequency"]) * sin(t * float(wp["gust_frequency"]) * TAU + float(ph["phase"]) * 0.5)
	return clampf((base * main + gust) * mult, -1.5, 1.5)
