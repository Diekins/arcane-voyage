class_name PresenceController extends Node
## FATIA A10 — AUTORIDADE DE HANDOFF (fina). Responde "QUEM controla o Errante agora?" — NÃO é sistema de
## progressão, NÃO duplica o AutoPlay (que continua decidindo COMO lutar), NÃO dá buff/reward/moeda. Só LÊ o
## estado existente (AutoPlay ligado? input manual? viewing? modal aberto?) e oferece o "TENTAR AGORA" do muro
## (reusa `request_retry`), suspendendo o Auto durante a tentativa manual. Presença = AGÊNCIA, não 2ª progressão.
##
## ★ REGRA: nenhum estado aqui gateia stage/Selo/Prestígio/loot. Tudo é transitório (NÃO persiste no save §53).

const AUTO := "AUTO"                 # AutoPlay ligado, sem input manual → o Auto joga
const MANUAL_OVERRIDE := "MANUAL_OVERRIDE"   # AutoPlay ligado, mas o jogador está mexendo (cede na hora, A1)
const MANUAL := "MANUAL"             # AutoPlay DESLIGADO deliberadamente → jogador no controle
const UI_SUSPENDED := "UI_SUSPENDED" # diálogo/história/painel aberto → combate suspenso (viewing vence, §13/§58)

var _host = null
var _challenge_active := false
var _auto_before_challenge := true

func setup(host) -> void:
	_host = host

# ── QUEM controla agora? (só leitura do estado existente) ──
func control_state() -> String:
	if _host == null:
		return AUTO
	if _host.has_method("narrative_viewing") and _host.narrative_viewing():
		return UI_SUSPENDED
	if _host.has_method("presence_modal_open") and _host.presence_modal_open():
		return UI_SUSPENDED
	if not _auto_on():
		return MANUAL
	if _host.has_method("presence_manual_input") and _host.presence_manual_input():
		return MANUAL_OVERRIDE
	return AUTO

## Rótulo compacto p/ a HUD (§11/§59): quem está no comando. Widget é field-deferido; isto é o modelo.
func control_label() -> String:
	match control_state():
		MANUAL, MANUAL_OVERRIDE: return "VOCÊ"
		UI_SUSPENDED: return "—"
		_: return "AUTO"

func is_manual() -> bool:
	var s := control_state()
	return s == MANUAL or s == MANUAL_OVERRIDE

func _auto_on() -> bool:
	return _host != null and _host.has_method("autoplay_on") and _host.autoplay_on()

# ── MANUAL CHALLENGE ("TENTAR AGORA", §15-19) — reusa o muro/retry; suspende o Auto na tentativa ──
## Pode oferecer o desafio manual? Só com MURO ativo, sem viewing, e sem desafio já em curso. NÃO é requisito.
func can_manual_challenge() -> bool:
	if _host == null or _challenge_active:
		return false
	if _host.has_method("narrative_viewing") and _host.narrative_viewing():
		return false
	return _host.has_method("stage_wall_active") and _host.stage_wall_active()

## Inicia a tentativa MANUAL da fronteira travada: guarda o estado do Auto, DESLIGA o Auto (jogador assume o
## encounter §17), e chama request_retry (sai do muro p/ a frontier em avanço). NÃO altera CP/HP/dano/reward (§16).
func begin_manual_challenge() -> bool:
	if not can_manual_challenge():
		return false
	_auto_before_challenge = _auto_on()
	if _host.has_method("set_autoplay"):
		_host.set_autoplay(false)   # jogador no controle durante a tentativa
	var ok := false
	if _host.has_method("stage_request_retry"):
		ok = bool(_host.stage_request_retry())
	if not ok:
		# nada a tentar → restaura
		if _host.has_method("set_autoplay"):
			_host.set_autoplay(_auto_before_challenge)
		return false
	_challenge_active = true
	return true

## Encerra a tentativa (chamado pelo host em vitória/derrota/troca de região): restaura o estado do Auto anterior
## (§10/§18/§19 — Auto retoma SÓ se estava ligado; se o jogador tinha desligado, permanece manual). Sem reward extra.
func end_manual_challenge() -> void:
	if not _challenge_active:
		return
	_challenge_active = false
	if _host != null and _host.has_method("set_autoplay"):
		_host.set_autoplay(_auto_before_challenge)

func challenge_active() -> bool:
	return _challenge_active

## ── CLASSIFICAÇÃO da tentativa (§13/§14/§15): rótulo por RATIO, NUNCA proíbe tentar, NUNCA promete vitória.
## Cortes são DIREÇÃO inicial (vieram de modelo, não de field §23). Reusa o power_ratio/banda do Wall quando dá.
static func challenge_label(r: float) -> String:
	if r >= 0.95: return "DESAFIO"
	if r >= 0.80: return "DESAFIO DIFÍCIL"
	return "DESAFIO EXTREMO"   # jogador PODE tentar mesmo assim (§14); só não prometemos vitória (§15)

## Rótulo da fronteira travada corrente (lê o power_ratio do StageDirector via host, se disponível).
func challenge_label_now() -> String:
	if _host != null and _host.has_method("stage_frontier_ratio"):
		return challenge_label(float(_host.stage_frontier_ratio()))
	return "DESAFIO"

## Limpeza forte (troca de região/reset §56): descarta a tentativa em curso SEM conceder nada.
func clear_transient() -> void:
	_challenge_active = false
