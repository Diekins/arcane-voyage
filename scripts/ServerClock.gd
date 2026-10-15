class_name ServerClock
## FATIA A11 — RELÓGIO AUTORITATIVO. Operações online (offline/cooldown persistente/lease/transação) NUNCA confiam
## no relógio do CLIENTE (§59/§60): o SERVIDOR carimba o tempo. Em modo LOCAL segue o relógio do PC (regra
## existente §61); em modo SERVER/TESTE é controlável (fixture). Instância leve (RefCounted) — o AuthorityServer
## possui a sua e passa aos comandos. NÃO é singleton global (evita relógio compartilhado escondido).

var _mode := "system"     # "system" (relógio real) | "fixed" (controlado por teste/fixture)
var _fixed := 0

## Relógio real (produção LOCAL) — usa Time do sistema.
static func system() -> ServerClock:
	var c := ServerClock.new()
	c._mode = "system"
	return c

## Relógio FIXO controlável (server/teste). Cliente não pode adiantar isto.
static func fixed(t0: int) -> ServerClock:
	var c := ServerClock.new()
	c._mode = "fixed"
	c._fixed = maxi(0, t0)
	return c

## Segundos unix "agora" segundo o SERVIDOR. Cliente jamais fornece este valor.
func now() -> int:
	if _mode == "fixed":
		return _fixed
	return int(Time.get_unix_time_from_system())

## Avança o relógio fixo (teste: simular ausência offline, expiry de lease, cooldown). No-op no modo system.
func advance(seconds: int) -> void:
	if _mode == "fixed":
		_fixed = maxi(0, _fixed + seconds)

func set_now(t: int) -> void:
	if _mode == "fixed":
		_fixed = maxi(0, t)

func is_authoritative_fixed() -> bool:
	return _mode == "fixed"
