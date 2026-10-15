class_name CooldownTracker extends RefCounted
## FATIA A15/§23 — cooldowns CENTRALIZADOS e coerentes com o tempo de simulação. x2/x3 continua coerente (o tempo de
## jogo já é escalado a montante; aqui só comparamos now vs ready_at). Offline NÃO roda cooldown frame-a-frame (§31)
## — o offline é agregado (A5). Puro/testável.

var _ready_at: Dictionary = {}   # ability_id → tempo em que fica pronto

func is_ready(ability_id: String, now: float) -> bool:
	return now >= float(_ready_at.get(ability_id, -1.0))

## Marca o uso: fica pronto de novo em now + cooldown.
func trigger(ability_id: String, now: float, cooldown: float) -> void:
	_ready_at[ability_id] = now + maxf(0.0, cooldown)

func remaining(ability_id: String, now: float) -> float:
	return maxf(0.0, float(_ready_at.get(ability_id, now)) - now)

func reset() -> void:
	_ready_at.clear()
