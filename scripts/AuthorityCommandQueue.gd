class_name AuthorityCommandQueue extends RefCounted
## FATIA A11.1 — SERIALIZAÇÃO GLOBAL V1 (§11/§12). ★ Enquanto o AuthorityServer reutiliza UM GameState singleton
## como motor, só UMA operação econômica pode executar por vez. Esta fila FORMALIZA a invariante (§66): commands de
## A e B entram em ordem e cada um roda INTEIRO (submit→_with_gs→commit→restore) antes do próximo — nenhum
## interleave. NÃO otimiza concorrência por-character ainda (§13): o singleton compartilhado impede, primeiro
## segurança. Backpressure global (§43): fila cheia → SERVER_BUSY, o command NÃO é aceito (nada commitado é dropado,
## §44). Ordem por sessão preservada (§17). `submit` é síncrono ⇒ num loop single-thread não há corrida; a fila
## torna isso explícito e mensurável (throughput/pico §82). FUTURO (§14): motor de estado isolado + fila
## por-character, se a escala exigir — NÃO nesta fatia.

var _server: AuthorityServer
var _pending: Array = []          # FIFO de jobs {session_id, command, cb}
var _busy := false                # single-flight: um job por vez
var _committed := 0
var _rejected_busy := 0
var _peak_depth := 0

const MAX_PENDING := 256          # §43 — teto da fila global; acima disso = SERVER_BUSY

func setup(server: AuthorityServer) -> void:
	_server = server

## Enfileira uma EXECUÇÃO (Callable → Dictionary) + callback do resultado. `exec` encapsula a chamada à Authority
## (submit por sessão OU submit_internal), mantendo a fila agnóstica (§3). Backpressure ANTES de aceitar (§43/§44).
func enqueue(exec: Callable, cb: Callable = Callable()) -> Dictionary:
	if not exec.is_valid():
		return {"ok": false, "reason": "BAD_EXEC"}
	if _pending.size() >= MAX_PENDING:
		_rejected_busy += 1
		return {"ok": false, "reason": "SERVER_BUSY"}       # §43 — recusa ANTES de executar; nada commitado se perde
	_pending.append({"exec": exec, "cb": cb})
	_peak_depth = maxi(_peak_depth, _pending.size())
	return {"ok": true, "queued": true, "depth": _pending.size()}

## Processa UM job (se houver e não estiver ocupado). exec é síncrono → roda inteiro antes de liberar (§12).
func pump_one() -> bool:
	if _busy or _pending.is_empty():
		return false
	_busy = true
	var job: Dictionary = _pending.pop_front()
	var exec: Callable = job["exec"]
	var res: Dictionary = exec.call()
	_committed += 1
	_busy = false   # libera SÓ após o exec inteiro (commit+restore do GameState já ocorreram)
	var cb: Callable = job["cb"]
	if cb.is_valid():
		cb.call(res)
	return true

## Drena a fila até esvaziar (ou max_steps). Retorna quantos jobs processou.
func pump_all(max_steps: int = 1000000) -> int:
	var n := 0
	while n < max_steps and pump_one():
		n += 1
	return n

func pending_count() -> int: return _pending.size()
func is_busy() -> bool: return _busy
func committed() -> int: return _committed
func rejected_busy() -> int: return _rejected_busy
func peak_depth() -> int: return _peak_depth
