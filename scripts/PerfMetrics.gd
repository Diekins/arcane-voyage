class_name PerfMetrics extends RefCounted
## FATIA A14 (Parte 4) — INSTRUMENTAÇÃO de performance (§90-94). ★ Não inventa números: usa Performance.get_monitor
## e Time; onde o monitor não existe (headless), retorna -1 em vez de chutar. Mede duração de save. Contratos de
## QUALITY (§92) e BATTERY (§94) — sem autodetecção complexa; nunca degradam telegraph de gameplay (§93) nem a
## matemática de offline (§94).

const QUALITY_LOW := "LOW"
const QUALITY_MEDIUM := "MEDIUM"
const QUALITY_HIGH := "HIGH"
# o que cada nível PODE reduzir (§92/§93) — SÓ polish, NUNCA informação de perigo/zona/alvo/interação
const QUALITY_REDUCES := {
	QUALITY_LOW: ["cosmetic_density", "vfx_density", "shadows", "high_res_effects"],
	QUALITY_MEDIUM: ["vfx_density", "high_res_effects"],
	QUALITY_HIGH: [],
}
const GAMEPLAY_TELEGRAPH_PROTECTED := ["danger", "attack_zone", "target", "interaction"]   # §93 nunca removidos

const BATTERY_SAVER_REDUCES := ["target_fps", "cosmetic_update", "nonessential_animation", "vfx"]   # §94 — NÃO toca offline math

static func _mon(m: int) -> float:
	var v := Performance.get_monitor(m)
	return v if v != null else -1.0

static func fps() -> float: return _mon(Performance.TIME_FPS)
static func frame_time_ms() -> float: return _mon(Performance.TIME_PROCESS) * 1000.0
static func node_count() -> int: return int(_mon(Performance.OBJECT_NODE_COUNT))
static func object_count() -> int: return int(_mon(Performance.OBJECT_COUNT))
static func draw_calls() -> int: return int(_mon(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
static func texture_mem() -> int: return int(_mon(Performance.RENDER_TEXTURE_MEM_USED))

## Mede a duração (ms) de uma operação (ex.: save). Usa Time.get_ticks_usec (real, não escalado).
static func measure_ms(op: Callable) -> float:
	var t0 := Time.get_ticks_usec()
	op.call()
	return float(Time.get_ticks_usec() - t0) / 1000.0

static func snapshot(label: String = "") -> Dictionary:
	return {
		"label": label, "fps": fps(), "frame_time_ms": frame_time_ms(),
		"node_count": node_count(), "object_count": object_count(),
		"draw_calls": draw_calls(), "texture_mem": texture_mem(),
	}

## Quality LOW nunca remove informação de gameplay (§93). Retorna true se a política é segura.
static func quality_protects_gameplay(level: String) -> bool:
	var reduces: Array = QUALITY_REDUCES.get(level, [])
	for p in GAMEPLAY_TELEGRAPH_PROTECTED:
		if reduces.has(p):
			return false
	return true

## Battery saver NÃO toca offline math (§94).
static func battery_touches_offline() -> bool:
	return BATTERY_SAVER_REDUCES.has("offline") or BATTERY_SAVER_REDUCES.has("offline_math")

# HD MAP runtime policy (§95): MASTER ART ≠ RUNTIME TEXTURE; teto razoável de textura runtime (§96).
const MAX_RUNTIME_TEXTURE_PX := 2048
static func texture_within_runtime_budget(px: int) -> bool:
	return px <= MAX_RUNTIME_TEXTURE_PX
