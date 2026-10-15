class_name AppLifecycle extends RefCounted
## FATIA A14.1 — ciclo de vida do app (§13-24). ★ SEPARAÇÃO: AppLifecycle DETECTA o evento; a reconciliação de
## offline continua no IdleRewards/A5 (§14). Background carimba um timestamp seguro (§15); foreground reconcilia UMA
## vez (§16/§17) — boot+resume não creditam duas vezes (watermark por EPOCH). Background curto = sem reward (§18).
## Offline SEMPRE x1 (§19) — background nunca herda x3. ONLINE: o cliente só SINALIZA o evento; o servidor decide a
## duração (§20). Um Node real conecta os `_notification`; aqui a LÓGICA é pura/testável sem aparelho.

const MIN_OFFLINE_SECONDS := 60   # §18 — abaixo disto, background curto NÃO gera reward

var _last_background_at := -1
var _pending_epoch := 0          # incrementa a cada background (novo período a reconciliar)
var _reconciled_epoch := 0       # último epoch já creditado (watermark §17)
var reconcile_fn: Callable = Callable()   # injetado: func(elapsed_seconds:int) -> void  (A5 IdleRewards)
var background_count := 0
var reconcile_count := 0

## App vai para background / perde foco de gameplay (§15). `now` = ServerClock (online) ou relógio local (offline).
func on_background(now: int) -> void:
	_last_background_at = now
	_pending_epoch += 1           # novo período pendente de reconciliação
	background_count += 1

## App volta (§16). Reconcilia o período pendente EXATAMENTE UMA VEZ (§17). Retorna {reconciled, elapsed, reason}.
func on_foreground(now: int) -> Dictionary:
	if _pending_epoch <= _reconciled_epoch:
		return {"reconciled": false, "reason": "NO_PENDING"}   # boot+resume não duplicam
	var elapsed := maxi(0, now - _last_background_at) if _last_background_at >= 0 else 0
	if elapsed < MIN_OFFLINE_SECONDS:
		_reconciled_epoch = _pending_epoch   # consome o epoch (background curto não reabre)
		return {"reconciled": false, "reason": "SHORT_BACKGROUND", "elapsed": elapsed}   # §18
	_reconciled_epoch = _pending_epoch
	reconcile_count += 1
	if reconcile_fn.is_valid():
		reconcile_fn.call(elapsed)   # A5 calcula o reward em x1 (§19) — AppLifecycle NUNCA aplica multiplicador
	return {"reconciled": true, "elapsed": elapsed}

## Boot também usa o mesmo watermark (§17): se um resume já foi reconciliado, o boot não credita de novo.
func on_boot(now: int, last_seen: int) -> Dictionary:
	if last_seen < 0:
		return {"reconciled": false, "reason": "FIRST_RUN"}
	_last_background_at = last_seen
	_pending_epoch += 1
	return on_foreground(now)

## Guarda contra relógio recuado (§LIFE-T07): elapsed nunca negativo (já garantido por maxi acima). Exposto p/ teste.
func safe_elapsed(now: int, last_seen: int) -> int:
	if last_seen < 0 or now < last_seen:
		return 0   # relógio recuado / first-run → 0 (nunca credita tempo negativo)
	return now - last_seen

func pending_epoch() -> int: return _pending_epoch
func reconciled_epoch() -> int: return _reconciled_epoch
