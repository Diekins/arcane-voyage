class_name AutoPlay extends Node
## AutoPlay — CAÇA AUTOMÁTICA INFINITA (FATIA A1 do pivô idle-first).
##
## O ELO QUE FALTAVA: o jogo já sabe perseguir + atacar + soltar UM alvo (o auto-attack legado, em
## Main._auto_attack_tick). O que faltava era, AO ACABAR UM ALVO, ESCOLHER O PRÓXIMO SOZINHO e continuar
## PARA SEMPRE. Este nó é essa camada de AQUISIÇÃO + ARBITRAGEM — ele NÃO reimplementa combate/movimento/
## dano/pathfinding: só ORQUESTRA, mandando o host (Main) usar as APIs que já existem.
##
## ARQUITETURA (superfície mínima): o AutoPlay conversa com o host SÓ por um punhado de métodos `autoplay_*`
## (o "adapter"). Ele não conhece _mobs, dano, inventário, quests, drops nem animação. Isso mantém o
## Main.gd (monólito ~16k linhas) praticamente intocado e este sistema testável de forma isolada (mock host).
##
## ESCOPO A1 (deliberado): SÓ o laço de caça. NADA de fases/CP/muro/offline/prestígio/loja/UI de sistemas.
##
## MÁQUINA DE ESTADOS:
##   DISABLED     — Auto desligado (override do jogador / toggle). Não faz nada.
##   SEARCHING    — Auto ligado, sem alvo válido → tenta adquirir o inimigo vivo mais próximo.
##   APPROACHING  — tem alvo, fora de alcance → o host (auto-attack legado) caminha até ele.
##   FIGHTING     — tem alvo, em alcance → o host golpeia no cooldown existente.
##   RECOVERING   — não pode/não deve caçar agora (herói abatido, menu aberto, OU presença manual ativa).
##                  Cede o controle limpo e re-arma sozinho quando a condição passa.

signal state_changed(new_state: int)   # p/ HUD/telemetria (opcional; ninguém é obrigado a ouvir)

enum St { DISABLED, SEARCHING, APPROACHING, FIGHTING, RECOVERING }

## Liga logs de debug (Auto on/off, alvo adquirido/perdido/morto, sem alvo, troca de contexto). Nunca por frame.
const AUTO_PLAY_DEBUG := true
## Cadência da BUSCA de alvo (s). Não precisamos varrer a cada frame — algumas vezes por segundo basta e é
## barato. O COMBATE/movimento seguem no tick cheio do host (auto-attack legado), independentes disto.
const SEARCH_INTERVAL := 0.2
## Grace após a presença manual cessar antes de o Auto retomar (evita "arrancar o volante" a cada micro-toque).
const MANUAL_RESUME_GRACE := 0.45
## Auto-revive (A1.5): com o Auto LIGADO, herói abatido revive sozinho após este atraso (reusa o
## _recover_hero existente via adapter). SÓ com Auto ON — Auto OFF mantém o revive manual ([R]) puro.
const AUTO_REVIVE_DELAY := 2.0
## Log de progresso da sessão bate neste alvo (só instrumentação do field test dos 50 kills). NÃO é gate de jogo.
const SESSION_LOG_TARGET := 50

var enabled := true                 # idle-first: LIGADO por padrão (o jogo se joga sozinho)
var _state: int = St.SEARCHING
var _host = null                    # Main (duck-typed via métodos autoplay_*)
var _search_t := 0.0                # acumulador da cadência de busca
var _manual_grace := 0.0            # tempo restante de grace pós-presença manual
var _no_target_logged := false      # anti-spam do log "nenhum alvo"
var _revive_pending := false        # há um auto-revive armado aguardando o atraso?
var _revive_t := 0.0                # tempo restante até o auto-revive disparar

# Instrumentação do field test (NÃO persiste, NÃO entra no save): conta kills da sessão de Auto atual.
var session_kills := 0

func setup(host) -> void:
	_host = host
	_set_state(St.SEARCHING if enabled else St.DISABLED)

## Chamado pelo host todo frame (depois do auto-attack legado). `delta` em segundos.
func tick(delta: float) -> void:
	if _host == null:
		return
	if not enabled:
		if _state != St.DISABLED:
			_set_state(St.DISABLED)
		return

	# 1) PRESENÇA MANUAL — o jogador assumiu o movimento (WASD/esquiva). CEDER na hora: soltar a perseguição
	#    e NÃO adquirir/remirar nada (nada de "puxar de volta"). Re-arma sozinho após um grace curto.
	if _host.autoplay_manual_active():
		_manual_grace = MANUAL_RESUME_GRACE
		if _host.autoplay_has_target():
			_host.autoplay_release()   # solta p/ o auto-attack legado não reemitir move_target
		_set_state(St.RECOVERING)
		return
	if _manual_grace > 0.0:
		_manual_grace = maxf(0.0, _manual_grace - delta)
		_set_state(St.RECOVERING)
		return

	# 2) NÃO PODE COMBATER (herói abatido / menu / diálogo / travado): esperar sem erro, sem adquirir.
	if not _host.autoplay_can_fight():
		if _host.autoplay_has_target():
			_host.autoplay_release()
		# AUTO-REVIVE (A1.5): SÓ com Auto ON (já garantido acima) e SÓ se ABATIDO (≠ menu/diálogo). Após o
		# atraso, chama o revive EXISTENTE via adapter. Um único timer por episódio (guard _revive_pending);
		# _recover_hero é idempotente (no-op se já vivo) → sem double-revive; [R] manual, ao curar, faz o
		# herói deixar de estar abatido → o timer é cancelado no `else` no frame seguinte.
		if _host.has_method("autoplay_hero_defeated") and _host.autoplay_hero_defeated():
			if not _revive_pending:
				_revive_pending = true
				_revive_t = AUTO_REVIVE_DELAY
				_dbg("herói abatido — auto-revive em %.1fs" % AUTO_REVIVE_DELAY)
			else:
				_revive_t -= delta
				if _revive_t <= 0.0:
					_revive_pending = false
					if _host.has_method("autoplay_request_revive"):
						_host.autoplay_request_revive()
						_dbg("auto-revive disparado")
		else:
			_cancel_revive()   # não é morte (menu/diálogo) OU já reviveu → cancela pendência
		_set_state(St.RECOVERING)
		return

	# Passou do gate de "não pode combater" → o herói ESTÁ apto (vivo, sem menu). Garante que nenhum
	# auto-revive fique armado à toa (ex.: [R] manual curou antes do timer disparar).
	_cancel_revive()

	# 3) JÁ TEM ALVO VÁLIDO: mantém (sem target-switching nervoso). Só reflete APPROACHING/FIGHTING p/ a HUD;
	#    o host faz o caminhar/golpear. A perda de alvo (morte/despawn/fora-de-alcance) é do auto-attack legado.
	if _host.autoplay_has_target():
		_no_target_logged = false
		_set_state(St.FIGHTING if _host.autoplay_target_in_range() else St.APPROACHING)
		return

	# 4) SEM ALVO: procurar, na cadência de busca (não a cada frame).
	_set_state(St.SEARCHING)
	_search_t += delta
	if _search_t < SEARCH_INTERVAL:
		return
	_search_t = 0.0
	if _host.autoplay_acquire_nearest():
		_no_target_logged = false
		_dbg("alvo adquirido")
	else:
		# Nenhum candidato agora (todos mortos/em respawn, ou nenhum na região). Espera BARATO — não desliga,
		# não erra, não spama. Quando um mob (re)surgir, a próxima busca o pega. Log só na 1ª vez.
		if not _no_target_logged:
			_dbg("nenhum alvo disponível — aguardando respawn")
			_no_target_logged = true

## O host chama isto quando um mob MORRE (via _on_mob_died). Conta 1 kill da sessão SE o Auto estava
## conduzindo (ligado e não cedendo p/ presença manual). O sinal `died` do mob dispara UMA vez por morte
## (guarda `alive` no Mob), então não há dupla contagem — e o mob respawna e pode contar de novo (nova morte).
func notify_kill(_mob) -> void:
	if not enabled:
		return
	if _state == St.RECOVERING:
		return   # kill durante presença manual/abatido não conta como "sessão automática"
	session_kills += 1
	if AUTO_PLAY_DEBUG:
		print("[AutoPlay] sessão: %d/%d" % [session_kills, SESSION_LOG_TARGET])

## O host chama isto ao trocar de região/contexto (load_region). Descarta qualquer estado preso ao mapa
## anterior e recomeça limpo (o host já zerou o _auto_target no load). NÃO zera session_kills (a caça
## continua a mesma sessão ao atravessar mapas — some só ao (re)ligar o Auto).
func notify_region_changed() -> void:
	_search_t = 0.0
	_no_target_logged = false
	_manual_grace = 0.0
	_cancel_revive()   # contexto mudou (nova região) → descarta revive pendente do mapa antigo
	_set_state(St.SEARCHING if enabled else St.DISABLED)
	_dbg("troca de contexto — busca reconciliada")

## Liga/desliga o Auto (botão da HUD / hotkey). (Re)ligar SEMPRE começa uma sessão limpa: solta alvo velho,
## zera o contador e o estado, procura de novo. Desligar cede o controle ao jogador.
func set_enabled(v: bool) -> void:
	if v == enabled:
		return
	enabled = v
	if enabled:
		session_kills = 0
		_search_t = 0.0
		_manual_grace = 0.0
		_no_target_logged = false
		if _host != null and _host.autoplay_has_target():
			_host.autoplay_release()   # começa do zero (nova busca limpa)
		_set_state(St.SEARCHING)
		_dbg("Auto LIGADO (sessão nova)")
	else:
		if _host != null and _host.autoplay_has_target():
			_host.autoplay_release()
		_cancel_revive()   # Auto OFF → nada de auto-revive pendente (revive volta a ser manual/[R])
		_set_state(St.DISABLED)
		_dbg("Auto DESLIGADO (controle cedido ao jogador)")

func toggle() -> void:
	set_enabled(not enabled)

func get_state() -> int:
	return _state

## Rótulo curto do estado (HUD/log).
func state_label() -> String:
	match _state:
		St.DISABLED: return "OFF"
		St.SEARCHING: return "busca"
		St.APPROACHING: return "indo"
		St.FIGHTING: return "luta"
		St.RECOVERING: return "espera"
		_: return "?"

## Cancela um auto-revive pendente (contexto mudou / não é mais morte / Auto desligado).
func _cancel_revive() -> void:
	_revive_pending = false
	_revive_t = 0.0

func _set_state(s: int) -> void:
	if s == _state:
		return
	_state = s
	state_changed.emit(s)

func _dbg(msg: String) -> void:
	if AUTO_PLAY_DEBUG:
		print("[AutoPlay] %s" % msg)
