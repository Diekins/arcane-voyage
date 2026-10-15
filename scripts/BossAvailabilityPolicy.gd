class_name BossAvailabilityPolicy extends RefCounted
## A22.13/A22.14/A22.15 — POLÍTICA de disponibilidade de boss, DATA-DRIVEN e AUTHORITY-SIDE.
## Nunca depende da hora enviada pelo client: `resolve()` recebe `now_unix` (em produção = relógio do servidor UTC)
## e timestamps ABSOLUTOS. Story bosses = ALWAYS_AVAILABLE. Scheduled/event usam fixtures (produção global = débito).
## Estados: AVAILABLE / RESPAWNING / OPENS_AT / ACTIVE_UNTIL / LOCKED. Botão nunca fica cinza sem `reason_text`.

const ALWAYS := "ALWAYS_AVAILABLE"
const RESPAWN := "RESPAWN_TIMER"
const DAILY := "DAILY_SCHEDULE"
const WEEKLY := "WEEKLY_SCHEDULE"
const WINDOW := "WINDOWED_EVENT"

## Relógio "do servidor" (em headless/single-player usamos o do SO; produção substitui por serviço global).
static func server_now() -> int:
	return int(Time.get_unix_time_from_system())

## policy: {"type": ..., ...campos...}. now_unix: relógio autoritativo. last_defeat_unix: último kill (0 = nunca).
## unlocked: se o boss já foi liberado pela história. Retorna dict de status pronto p/ UI.
static func resolve(policy: Dictionary, now_unix: int, last_defeat_unix: int = 0, unlocked: bool = true) -> Dictionary:
	var out := {"state": "LOCKED", "available": false, "next_open_at": 0, "available_until": 0, "respawn_at": 0, "reason_text": "Bloqueado."}
	if not unlocked:
		out["reason_text"] = str(policy.get("locked_reason", "Requer progresso da história."))
		return out
	var t := str(policy.get("type", ALWAYS))
	match t:
		ALWAYS:
			out["state"] = "AVAILABLE"; out["available"] = true; out["reason_text"] = "Disponível."
		RESPAWN:
			var secs := int(policy.get("respawn_seconds", 0))
			if last_defeat_unix <= 0:
				out["state"] = "AVAILABLE"; out["available"] = true; out["reason_text"] = "Disponível."
			else:
				var ra := last_defeat_unix + secs
				# resistência a rollback: respawn_at é ABSOLUTO (derivado do kill), imune a mudar o relógio p/ trás.
				if now_unix >= ra:
					out["state"] = "AVAILABLE"; out["available"] = true; out["reason_text"] = "Disponível."
				else:
					out["state"] = "RESPAWNING"; out["respawn_at"] = ra; out["next_open_at"] = ra
					out["reason_text"] = "Renasce em %s." % _fmt_delta(ra - now_unix)
		DAILY:
			var win := _daily_window(policy, now_unix)
			_apply_window(out, win, now_unix, "Próximo: %s.")
		WEEKLY:
			var win2 := _weekly_window(policy, now_unix)
			_apply_window(out, win2, now_unix, "Próximo: %s.")
		WINDOW:
			var s := int(policy.get("start_unix", 0)); var e := int(policy.get("end_unix", 0))
			_apply_window(out, {"open": s, "close": e}, now_unix, "Abre em %s.")
		_:
			out["state"] = "AVAILABLE"; out["available"] = true; out["reason_text"] = "Disponível."
	return out

static func _apply_window(out: Dictionary, win: Dictionary, now: int, opens_fmt: String) -> void:
	var op := int(win.get("open", 0)); var cl := int(win.get("close", 0))
	if now >= op and now < cl:
		out["state"] = "ACTIVE_UNTIL"; out["available"] = true; out["available_until"] = cl
		out["reason_text"] = "ATIVO — restam %s." % _fmt_delta(cl - now)
	else:
		out["state"] = "OPENS_AT"; out["available"] = false; out["next_open_at"] = op
		out["reason_text"] = opens_fmt % _fmt_clock(op)

## Próxima janela DIÁRIA (UTC): open_hour/open_minute + duration_seconds. Se hoje já passou, pega amanhã.
static func _daily_window(policy: Dictionary, now: int) -> Dictionary:
	var oh := int(policy.get("open_hour", 20)); var om := int(policy.get("open_minute", 0))
	var dur := int(policy.get("duration_seconds", 3600))
	for day_off in range(0, 2):
		var base := _midnight_utc(now + day_off * 86400)
		var open_t := base + oh * 3600 + om * 60
		var close_t := open_t + dur
		if now < close_t:
			return {"open": open_t, "close": close_t}
	var b2 := _midnight_utc(now + 86400); return {"open": b2 + oh * 3600 + om * 60, "close": b2 + oh * 3600 + om * 60 + dur}

## Próxima janela SEMANAL (UTC): days = lista de weekdays (0=Dom..6=Sáb, padrão Godot), open_hour + duration.
static func _weekly_window(policy: Dictionary, now: int) -> Dictionary:
	var days: Array = policy.get("days", [6])   # padrão sábado
	var oh := int(policy.get("open_hour", 21)); var dur := int(policy.get("duration_seconds", 3600))
	for day_off in range(0, 8):
		var probe := now + day_off * 86400
		var dt := Time.get_datetime_dict_from_unix_time(probe)
		if int(dt["weekday"]) in days:
			var base := _midnight_utc(probe)
			var open_t := base + oh * 3600
			var close_t := open_t + dur
			if now < close_t:
				return {"open": open_t, "close": close_t}
	return {"open": now + 604800, "close": now + 604800 + dur}

static func _midnight_utc(unix: int) -> int:
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return unix - (int(dt["hour"]) * 3600 + int(dt["minute"]) * 60 + int(dt["second"]))

static func _fmt_delta(secs: int) -> String:
	secs = maxi(0, secs)
	if secs >= 86400: return "%dd %dh" % [secs / 86400, (secs % 86400) / 3600]
	if secs >= 3600: return "%dh %dm" % [secs / 3600, (secs % 3600) / 60]
	if secs >= 60: return "%dm %02ds" % [secs / 60, secs % 60]
	return "%ds" % secs

static func _fmt_clock(unix: int) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	var wd: String = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"][int(dt["weekday"])]
	return "%s %02d:%02d" % [wd, int(dt["hour"]), int(dt["minute"])]
