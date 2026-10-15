class_name HuntHost extends Node
## FATIA A16.2 — COSTURA final: liga o runtime da Hunt (A16.1) ao GAME LOOP REAL do Main. NÃO é sistema novo — é o
## ADAPTADOR que o Main possui e chama de `_process`. É o ÚNICO tick owner do HuntRuntime (o HuntRuntime não tem
## `_process`; só avança quando este host o avança). Monta HuntPanel + HuntPresenceView no tree do Main. No START:
## espelha o GameState do jogador → repositório autoritativo, aloca spot, cria HuntRuntime, trava o player, DESLIGA o
## AutoPlay de Progressão (exclusão §97). A cada tick: avança o runtime, sincroniza reward (XP/loot) repo→GameState
## por DELTA ABSOLUTO (idempotente ⇒ background/resume não duplica), atualiza a presença. No STOP: sync final, encerra
## a sessão, libera spot, destrói o runtime, destrava o player, RELIGA o AutoPlay se estava ligado.

const LOCAL_ACCOUNT := "local"
const LOCAL_CHAR := "local_hero"

var _main: Node = null
var _player: Node2D = null
# stack autoritativo LOCAL do jogador (mesma classe usada no servidor; aqui roda in-process p/ o single player)
var repo: CharacterRepository
var items: ItemRegistry
var authority: AuthorityServer
var clock: ServerClock
var hunt: HuntService
var panel: HuntPanel
var session_hud: HuntSessionHud
var _entry_layer: CanvasLayer = null
var presence_view: HuntPresenceView
var _runtime: HuntRuntime = null
var _target_mob_id := ""     # A22 — alvo da Targeted Hunt ("" = ground normal)
var _difficulty := "NORMAL"
var online: OnlineClient = null   # opcional: quando online, a presença vem da rede

var game_state = null            # referência ao autoload GameState (injetada/resolvida — não usa o global p/ ser testável)
var _synced_xp := 0
var _synced_items := 0
var _total_granted := 0          # XP total concedido ao GameState nesta sessão (prova de "sem double reward")
var _autoplay_was_on := false
var _anchor := Vector2.ZERO
## ★★★ FIELD FIX 05/09/2026 (relato de campo).
## `_actor_engaged`: o mob ATOR já chegou? Fecha/abre o portão de combate do HuntRuntime — sem isso
## o bicho morria em dados a caminho e nunca atacava o Errante.
## COLEIRA do Errante: ele era recolado em `_anchor` a CADA frame (`position = _anchor`), por isso
## parecia estático no abate. Agora anda dentro da coleira, indo ao encontro do mob.
var _actor_engaged := false
const MOB_APPROACH_SPEED := 150.0   # era 240 — mais lento = dá pra ver o bicho vindo
const PLAYER_LEASH := 90.0          # quanto o Errante pode sair do anchor
const PLAYER_SPEED := 120.0
var _pre_hunt_pos := Vector2.ZERO
# A17.10B — morte/revive/repeated-death (§20/§21). Janela em TEMPO DE JOGO (delta acumulado; sem wall-clock).
var _now := 0.0
var _revive_at := -1.0
var _death_times: Array = []
var hunt_paused := false
var pause_reason := ""
const REVIVE_DELAY := 2.0
const DEATH_WINDOW := 45.0        # janela de contagem de mortes
const DEATH_LIMIT := 3            # N mortes na janela → área perigosa (pausa)
var last_reward: Dictionary = {}
signal hunting_changed(active: bool)

func setup(main: Node, player: Node2D, online_client: OnlineClient = null, gs = null) -> void:
	_main = main; _player = player; online = online_client
	game_state = gs if gs != null else get_tree().root.get_node_or_null("GameState")
	repo = CharacterRepository.new(); items = ItemRegistry.new(); clock = ServerClock.fixed(0)
	authority = AuthorityServer.new(); authority.setup(repo, items, clock, 20260903)
	hunt = HuntService.new(); hunt.setup(repo, items, authority, clock, 20260903)
	# UI e presença entram no TREE do host real (não do selftest)
	panel = HuntPanel.new(); panel.name = "HuntPanel"
	session_hud = HuntSessionHud.new(); session_hud.name = "HuntSessionHud"
	presence_view = HuntPresenceView.new(); presence_view.name = "HuntPresenceView"
	add_child(panel); add_child(session_hud); add_child(presence_view)
	_mirror_character()   # garante o character local no repo já na entrada
	panel.setup(hunt, authority, LOCAL_ACCOUNT, LOCAL_CHAR)
	panel.bind_host(self)
	session_hud.bind_host(self)
	panel.visible = false          # o jogador abre a lista pela tecla/botão CAÇAR
	session_hud.visible = false     # só aparece enquanto caçando
	_build_hunt_entry_button()      # A17.3: entrada descobrível (não depende de saber a tecla [H])

## Botão "⚔ CAÇAR" discreto (canto), que abre a lista de grounds. Some enquanto caçando (o SessionHud assume).
func _build_hunt_entry_button() -> void:
	_entry_layer = CanvasLayer.new(); _entry_layer.layer = 46; _entry_layer.name = "HuntEntryLayer"
	add_child(_entry_layer)
	var b := Button.new(); b.text = "⚔ CAÇAR"; b.name = "HuntEntryBtn"
	b.anchor_left = 0.0; b.anchor_top = 1.0; b.anchor_bottom = 1.0
	b.offset_left = 14; b.offset_top = -92; b.offset_bottom = -56; b.offset_right = 130
	b.pressed.connect(toggle_panel)
	_entry_layer.add_child(b)

## Abre/fecha a HuntPanel (o Main liga a uma tecla). Refresca a lista ao abrir.
func toggle_panel() -> void:
	if panel == null: return
	if is_hunting():
		return   # durante a caça a lista não abre (o HUD compacto já mostra o essencial)
	panel.visible = not panel.visible
	if panel.visible: panel.refresh()

## Espelha o GameState vivo → repositório autoritativo (upsert idempotente). O repo é a autoridade da Hunt; o
## GameState continua a verdade voltada-ao-jogador (o reward volta por sync).
func _mirror_character() -> void:
	var state: Dictionary = game_state.to_dict().duplicate(true)
	var cur := repo.load(LOCAL_CHAR)
	if cur.is_empty() or not bool(cur.get("ok", true)) or int(cur.get("revision", -1)) < 0:
		var res := repo.create_character(LOCAL_ACCOUNT, LOCAL_CHAR, state)
		if not bool(res.get("ok", false)):
			# já existe → sobrescreve preservando revisão
			var ld := repo.load(LOCAL_CHAR)
			repo.save(LOCAL_CHAR, int(ld.get("revision", 0)), state)
	else:
		repo.save(LOCAL_CHAR, int(cur.get("revision", 0)), state)

func is_hunting() -> bool:
	return _runtime != null and hunt.is_hunting(LOCAL_CHAR)

## ★ ENTRYPOINT único do game loop (o Main._process delega AQUI). Retorna se a PROGRESSÃO deve rodar neste frame
## (false enquanto em Hunt ⇒ exclusão §97). Avança o HuntRuntime SOMENTE quando caçando.
func host_process(delta: float) -> bool:
	if not is_hunting():
		return true   # Progression livre
	_now += delta
	# MORTO: AutoCombat parado (§19). Se não está em pausa por perigo, agenda/executa o revive (§20).
	if game_state != null and game_state.is_hero_defeated():
		if not hunt_paused and _revive_at >= 0.0 and _now >= _revive_at:
			_revive_at = -1.0; _runtime.revive()
		if session_hud != null and session_hud.visible: session_hud.refresh()
		return false   # continua em Hunt (exclusão), mas sem combate enquanto morto/pausado
	# A20.9 — AUTO OFF pausa o encontro (herói E mob), mas mantém o movement lock (§A20.9). Não morre parado no menu.
	if not hunt_auto:
		if _player != null: _player.locked = true; _player.position = _anchor
		return false
	# ★★★ FIELD FIX 05/09/2026 — o combate só corre com o mob JÁ ENGAJADO (medido no frame anterior
	# pelo `approach`). Antes o dano resolvia enquanto o sprite ainda vinha, e o bicho morria a
	# caminho sem nunca atacar o Errante.
	_runtime.combat_enabled = _actor_engaged
	_runtime.tick(delta)          # ÚNICO ponto que avança o runtime
	_sync_rewards()               # repo → GameState (idempotente)
	_refresh_presence()
	_sync_mob_actor(delta)        # A20 — ATOR VISÍVEL do mob de Hunt (spawn pocket → approach)
	if panel != null and panel.visible: panel.tick_ui()
	if session_hud != null and session_hud.visible: session_hud.refresh()
	_drive_player(delta)          # ★ movement lock CONTINUA; o que saiu foi o pin por frame
	return false                  # Progression NÃO roda junto (exclusão)

## ★★★ FIELD FIX 05/09/2026 — O ERRANTE ESTAVA ESTÁTICO PORQUE ERA RECOLADO NO ANCHOR.
## O código antigo fazia `_player.position = _anchor` a cada frame: qualquer passo era desfeito no
## frame seguinte. Não era falta de animação — era reposicionamento forçado.
## Agora o lock de INPUT continua (§16: o jogador não dirige na Hunt), mas o Errante ANDA: avança
## na direção do mob enquanto ele se aproxima e volta ao anchor quando não há alvo — sempre preso
## à coleira, então ele nunca sai do spot (a exclusão Hunt/Progression segue intacta).
func _drive_player(delta: float) -> void:
	if _player == null: return
	_player.locked = true
	# ⛔ SEM ator de mob em cena → comportamento ORIGINAL, snap seco no anchor. Isto preserva o
	# contrato §16 de movement lock exatamente como está testado (ML-T05/T06/T07, AV-T09:
	# "deslocamento ZERO", "host recola no anchor"). O input NUNCA move o Errante — nem antes, nem
	# agora. O que mudou é só a encenação do abate, e só quando há um bicho para encenar.
	if _mob_actor == null or not is_instance_valid(_mob_actor):
		_player.position = _anchor
		return
	var to_mob: Vector2 = _mob_actor.global_position - _anchor
	var target := _anchor
	if to_mob.length() > 1.0:
		target = _anchor + to_mob.normalized() * minf(to_mob.length() * 0.45, PLAYER_LEASH)
	var d := target - _player.position
	if d.length() <= 2.0: return
	_player.position += d.normalized() * minf(PLAYER_SPEED * delta, d.length())

# A20 — ATORES VISÍVEIS do Hunt (fecha HUNT_VISIBLE_ACTORS_PENDING). Mesmo padrão de PveMobActor da missão.
var hunt_auto := true
var suppress_session_hud := false   # A35 — a HUD alvo (HudTargetV1) absorve a atividade ⇒ o HUD de sessão legado não aparece
func toggle_auto() -> void: hunt_auto = not hunt_auto
func set_auto(v: bool) -> void: hunt_auto = v
var _actors_root: Node2D = null
## ★ COMPAT: ator/mob do PRIMÁRIO. `_bound_mob` NÃO representa o grupo — só o membro primário.
var _mob_actor: PveMobActor = null
var _bound_mob = null
## ★★★ REGISTRO DE ATORES (fonte da verdade = `instance_id` do runtime, nunca índice de array).
var _mob_actors_by_instance: Dictionary = {}   # instance_id → PveMobActor
var _pocket_by_instance: Dictionary = {}       # instance_id → índice de POCKET (estável na vida do membro)
## ★ Fase 19 — evento chegando para instância já removida: descarta com segurança e CONTA.
var host_group_stats := {"late_feedback_dropped": 0, "actors_created": 0}
var _hunt_kill_ct := 0
var _ghost_kill_ct := 0            # A33 — kills contabilizados SEM ator visível/coerente (anti-ghost-farm §21)
var _last_actor_coherent := false  # o ator do alvo atual está representando a criatura (visível + sprite real)?
func actor_root() -> Node2D: return _actors_root
## ★ COMPATIBILIDADE LEGADA — 32 suítes consomem isto. Devolve o ator do mob PRIMÁRIO.
func mob_actor() -> PveMobActor: return _mob_actor

## ★★★ APIs DE GRUPO (Stage 1). Com `_max_active = 1` devolvem no máximo 1 elemento ⇒ paridade.
func active_mobs() -> Array:
	return _runtime.active_mobs() if _runtime != null else []

func mob_actors() -> Array:
	# STAGE 1: o host ainda mantém UM ator (paridade). Vira mapa instance_id→ator no Stage 10.
	# ★ agora é REAL (era sintético): todos os atores vivos do registro.
	var out: Array = []
	for iid in _mob_actors_by_instance.keys():
		var a: PveMobActor = _mob_actors_by_instance[iid]
		if a != null and is_instance_valid(a): out.append(a)
	return out

func active_mob_count() -> int:
	return _runtime.active_count() if _runtime != null else 0
## A33 §18/§21 — o combate atual está VISÍVEL? (há um alvo lógico E um ator coerente na cena). AFK ≠ invisível.
func combat_visible_ok() -> bool:
	var lm = _runtime.current_mob() if _runtime != null else null
	if lm == null: return true   # sem alvo agora (entre spawns) — não é incoerência
	return _mob_actor != null and is_instance_valid(_mob_actor) and _mob_actor.combat_visible_ok()
## A33 — quantos kills ocorreram sem um ator coerente (deveria ser 0 em field com assets válidos). >0 = ghost farm.
func ghost_kill_count() -> int: return _ghost_kill_ct
func target_mob_id() -> String: return _target_mob_id
## A22 — chave de perfil para packing social (ground + alvo + dificuldade). Grounds com pool normal usam só o ground.
func profile_key() -> String:
	return "%s|%s|%s" % [_runtime.ground_id if _runtime != null else "", _target_mob_id, _difficulty]
func _ensure_actors_root() -> void:
	if _actors_root != null and is_instance_valid(_actors_root): return
	_actors_root = Node2D.new(); _actors_root.name = "HuntActorsRoot"; _actors_root.z_index = 50
	if _main != null and _main.is_inside_tree(): _main.add_child(_actors_root)
	else: add_child(_actors_root)
## ★★★ HOST MULTI-ACTOR (05/09/2026) — RECONCILIAÇÃO instance_id → ATOR.
## Antes: 1 mob lógico ↔ 1 ator (`_bound_mob`/`_mob_actor`). Com grupo, dois mobs lógicos
## dividiriam/sobrescreveriam o MESMO ator — FIELD FAIL. Agora o host mantém um REGISTRO por
## instância e reconcilia contra `runtime.active_mobs()`:
##   faltando → cria · sobrando → limpa · existente → sincroniza.
## ⛔ Não recria ator todo frame (sem churn): a chave é o `instance_id`, não o índice do array.
func _sync_mob_actor(delta: float) -> void:
	_ensure_actors_root()
	var live: Array = _runtime.active_mobs() if _runtime != null else []
	var seen := {}
	for lm in live:
		if lm == null or not is_instance_valid(lm): continue
		var iid := int(lm.instance_id)
		seen[iid] = true
		var act: PveMobActor = _mob_actors_by_instance.get(iid, null)
		if act == null or not is_instance_valid(act):
			act = _create_actor_for(lm, iid)
		# aproximação/facing POR ATOR (cada um faz o próprio caminho)
		var engaged: bool = act.approach(_anchor, MOB_APPROACH_SPEED, delta)
		act.face(_anchor)   # ★ B3 — encara o Errante mesmo parado/engajado
		var mhp := float(lm.max_hp) if float(lm.max_hp) > 0.0 else 1.0
		act.set_hp(float(lm.hp) / mhp)   # HP local do ator — nunca cruza instâncias
		if act.combat_visible_ok(): _last_actor_coherent = true
		# o PORTÃO DE COMBATE segue o PRIMÁRIO (semântica preservada do single-actor)
		if _runtime != null and _runtime.primary_mob() == lm:
			_actor_engaged = engaged
			_mob_actor = act        # compat: `mob_actor()` = ator do primário
			_bound_mob = lm         # compat: PRIMÁRIO ligado, nunca "o grupo"
	# ── atores órfãos: a instância sumiu do runtime ⇒ encena a morte e desregistra ──
	for iid in _mob_actors_by_instance.keys():
		if seen.has(iid): continue
		var dead: PveMobActor = _mob_actors_by_instance[iid]
		# A33 GHOST KILL (§21) preservado: ator que NUNCA foi coerente não premia em silêncio.
		if not _last_actor_coherent: _ghost_kill_ct += 1
		if dead != null and is_instance_valid(dead): dead.die_and_free()
		_mob_actors_by_instance.erase(iid)
		_pocket_by_instance.erase(iid)
	if _runtime == null or _runtime.primary_mob() == null:
		_mob_actor = null; _bound_mob = null

## Cria EXATAMENTE um ator por instância, num pocket ESTÁVEL (não muda a cada reconciliação).
func _create_actor_for(lm, iid: int) -> PveMobActor:
	_hunt_kill_ct += 1
	var mid := str(lm.mob_id)
	var vkey := "mobs/%s" % str(MobEligibility.get_mob(mid).get("visual_id", mid)) if MobEligibility.exists(mid) else "mobs/%s" % mid
	var nm := str(MobEligibility.get_mob(mid).get("visual_id", mid)) if MobEligibility.exists(mid) else mid
	var act := PveMobActor.new()
	act.setup(vkey, mid, lm.is_elite, nm)
	_actors_root.add_child(act)
	# ★ POCKET ESTÁVEL POR INSTÂNCIA: membros simultâneos ocupam pockets DISTINTOS e não
	# teleportam entre eles. Sem isso dois lobos nasceriam no mesmo ponto.
	if not _pocket_by_instance.has(iid):
		_pocket_by_instance[iid] = _next_free_pocket()
	act.global_position = _anchor + PveMobActor.pocket_for(int(_pocket_by_instance[iid]))
	_mob_actors_by_instance[iid] = act
	_last_actor_coherent = false
	if _runtime != null and _runtime.primary_mob() == lm:
		_actor_engaged = false   # ★ mob novo nasce LONGE: combate fechado até ele chegar
	return act

## Menor índice de pocket ainda não ocupado por instância viva (determinístico, sem sorteio).
func _next_free_pocket() -> int:
	var used := {}
	for v in _pocket_by_instance.values(): used[int(v)] = true
	for i in range(PveMobActor.POCKETS.size()):
		if not used.has(i): return i
	return _pocket_by_instance.size() % PveMobActor.POCKETS.size()

## Ator de uma instância — base do roteamento de feedback. null = já removida (late feedback).
func _actor_for_instance(iid: int) -> PveMobActor:
	var a: PveMobActor = _mob_actors_by_instance.get(iid, null)
	return a if a != null and is_instance_valid(a) else null

func _free_actors() -> void:
	for iid in _mob_actors_by_instance.keys():
		var a: PveMobActor = _mob_actors_by_instance[iid]
		if a != null and is_instance_valid(a): a.queue_free()
	_mob_actors_by_instance.clear()
	_pocket_by_instance.clear()
	if _mob_actor != null and is_instance_valid(_mob_actor): _mob_actor.queue_free()
	_mob_actor = null; _bound_mob = null
	if _actors_root != null and is_instance_valid(_actors_root):
		if _actors_root.get_parent() != null: _actors_root.get_parent().remove_child(_actors_root)   # remoção imediata (child_count determinístico)
		_actors_root.queue_free()
	_actors_root = null

## START pelo jogo real (o botão da UI chama isto). ground_id vem da lista da HuntPanel.
func start(ground_id: String, target_mob_id: String = "", difficulty: String = "NORMAL") -> Dictionary:
	if is_hunting():
		return {"ok": true, "duplicate": true}
	# A42 §29 — GATE por completion do capítulo (flag). Só afeta grounds que declaram requires_flag (ex.: HG_ROOT_NEST
	# exige GP_CHAPTER_4_SALTWIND_COMPLETE). Grounds sem flag ("") passam direto — inalterados.
	var _rf := HuntingGround.required_flag(ground_id)
	if _rf != "" and (game_state == null or not game_state.is_story_flag(_rf)):
		return {"ok": false, "reason": "chapter_gate", "requires_flag": _rf}
	# A22.4/A22.7 — Targeted Hunt: o alvo tem de ser elegível NAQUELE ground e a dificuldade selecionável (authority).
	if target_mob_id != "":
		if not MobEligibility.can_spawn_in_hunt(target_mob_id, ground_id):
			return {"ok": false, "reason": "target_nao_elegivel"}
		if difficulty != "NORMAL" and not MissionDifficulty.is_selectable(difficulty, ["NORMAL", "VETERAN"]):
			return {"ok": false, "reason": "dificuldade_locked"}
	_mirror_character()
	var res := hunt.start_hunt(LOCAL_ACCOUNT, LOCAL_CHAR, ground_id)
	if not bool(res.get("ok", false)):
		return res
	_target_mob_id = target_mob_id; _difficulty = difficulty
	# caster REAL a partir do snapshot autoritativo (a tendência de stat da classe se aplica)
	var ps: Dictionary = authority.power_snapshot(LOCAL_CHAR)
	var st: Dictionary = repo.load(LOCAL_CHAR)["state"]
	var mhp := maxi(100, int(ps.get("effective_hp", 1000)))
	var caster := {"class_id": str(st.get("character_class", "LEGACY_CLASS")), "expected_damage": float(ps.get("offense", 50.0)),
		"max_hp": mhp, "current_hp": mhp, "shield": 0, "alive": true}
	_runtime = HuntRuntime.new(); _runtime.name = "HuntRuntime"
	_runtime.setup(hunt, LOCAL_CHAR, ground_id, caster, 20260903)
	_runtime.target_mob_id = target_mob_id; _runtime.difficulty = difficulty
	# A17.10B — FONTE ÚNICA DE HP: o runtime da Hunt lê/escreve o HP REAL do jogador (GameState). O herói começa
	# inteiro (§13) e pode MORRER de verdade na caça (§19). Morte/revive/repeated-death ficam no host.
	_runtime.hp_source = game_state
	if game_state != null and game_state.is_hero_defeated():
		game_state.reset_hero_hp()
	_runtime.hero_died.connect(_on_hero_died)
	# ★★★ FIELD FIX 05/09/2026 (A7/A8) — LIGA COMBATE → APRESENTAÇÃO.
	# `PveMobActor.play_hit/play_attack` e o `GameFeedback` (floating damage) já existiam e nunca
	# eram chamados no PvE. Este é o fio que faltava: sem ele o combate é um contador silencioso.
	_runtime.feedback = _on_combat_feedback
	_death_times = []; _revive_at = -1.0; hunt_paused = false; pause_reason = ""
	add_child(_runtime)           # node no tree; SEM _process próprio (este host é o owner)
	# baselines de reward (idempotência)
	_synced_xp = int(repo.load(LOCAL_CHAR)["state"].get("hero_xp", 0))
	_synced_items = (repo.load(LOCAL_CHAR)["state"].get("item_instances", []) as Array).size()
	_total_granted = 0
	# VIAGEM REAL (A17.4): reposiciona o player no anchor do SPOT do servidor (≠ posição atual) + movement lock.
	var sp := hunt.world.spot_of(LOCAL_CHAR)
	_pre_hunt_pos = _player.position if _player != null else Vector2.ZERO
	# ★★★ FIELD FIX 05/09/2026 — o `anchor` do spot é OFFSET LOCAL (slot social), NÃO posição de
	# mundo. Usá-lo cru jogava o jogador em ~(200,200) — o canto da Vila — em qualquer ground.
	_anchor = _world_anchor_for(ground_id, sp.get("anchor", Vector2.ZERO))
	if _player != null:
		_player.position = _anchor
		_player.locked = true
	# hooks VISUAIS do host real (fade / esconder cenário de progressão / câmera / banner de chegada). Desacoplado:
	# se o Main não implementa (ex.: no self-test), é no-op — a lógica de viagem/estado já aconteceu acima.
	if _main != null and _main.has_method("on_hunt_enter"):
		_main.on_hunt_enter(ground_id, _friendly_name(ground_id), _anchor)
	_autoplay_was_on = _main != null and _main.get("_autoplay") != null and bool(_main._autoplay.enabled)
	if _autoplay_was_on: _main._autoplay.set_enabled(false)
	# UX A17.5: fecha a lista inteira de grounds e mostra o HUD compacto da sessão; some o botão CAÇAR
	if panel != null: panel.visible = false
	if session_hud != null and not suppress_session_hud: session_hud.visible = true; session_hud.refresh()   # A35: se a HUD alvo absorve a atividade, o HUD de sessão legado fica suprimido
	if _entry_layer != null: _entry_layer.visible = false
	hunting_changed.emit(true)
	return {"ok": true, "session": res.get("session", {})}

## STOP pelo jogo real (botão SAIR). Sync final, encerra, limpa tudo, destrava o player, religa a Progressão.
func stop() -> Dictionary:
	if not is_hunting():
		return {"ok": true, "already": true}
	_sync_rewards()               # não perde reward pendente
	_free_actors()                # A20 — limpa o ator visível do Hunt
	if _runtime != null:
		_runtime.stop()
		remove_child(_runtime)    # remoção IMEDIATA do tree (child_count reflete já); queue_free só libera memória
		_runtime.queue_free(); _runtime = null
	var res := hunt.stop_hunt(LOCAL_CHAR)
	_refresh_presence()
	if _player != null:
		_player.locked = false
		_player.position = _pre_hunt_pos   # volta de onde saiu (A17.4)
	if session_hud != null: session_hud.visible = false
	if _entry_layer != null: _entry_layer.visible = true
	if _main != null and _main.has_method("on_hunt_exit"):
		_main.on_hunt_exit()
	if _autoplay_was_on and _main != null and _main.get("_autoplay") != null:
		_main._autoplay.set_enabled(true)
	_autoplay_was_on = false
	hunting_changed.emit(false)
	return res

## Sincroniza reward do repo → GameState por DELTA ABSOLUTO (idempotente: nunca credita 2×, mesmo em resume).
func _sync_rewards() -> void:
	var st: Dictionary = repo.load(LOCAL_CHAR)["state"]
	var cur_xp := int(st.get("hero_xp", 0))
	if cur_xp > _synced_xp:
		var grant := cur_xp - _synced_xp
		game_state.add_xp(grant)   # o GameState pode transformar XP em NÍVEL (hero_xp deixa de ser total); por isso
		_total_granted += grant    # a prova de "sem double" é este contador == delta absoluto do repo, não gs.hero_xp
		_synced_xp = cur_xp
	var insts: Array = st.get("item_instances", [])
	if insts.size() > _synced_items:
		for i in range(_synced_items, insts.size()):
			game_state.instance_add(insts[i])
		_synced_items = insts.size()
	if _runtime != null:
		last_reward = {"kills": int(_runtime.runtime_stats["kills"]), "xp_synced": _synced_xp, "items_synced": _synced_items}

func _refresh_presence() -> void:
	# online: a presença vem da rede; offline single-player: ninguém remoto (lista vazia é válida)
	if online != null and online.has_method("hunt_presence"):
		var pr: Dictionary = online.hunt_presence()
		presence_view.apply_presence(pr.get("presence", []))
	else:
		presence_view.apply_presence(hunt.presence_for(LOCAL_CHAR))

## Morte do herói na Hunt (§19/§21): registra na janela; se exceder o limite, PAUSA a área (perigo) e NÃO revive
## sozinho — o jogador escolhe CONTINUAR ou SAIR. Senão, agenda o revive automático.
func _on_hero_died() -> void:
	_death_times.append(_now)
	var cutoff := _now - DEATH_WINDOW
	var recent: Array = []
	for t in _death_times:
		if float(t) >= cutoff: recent.append(t)
	_death_times = recent
	if _death_times.size() >= DEATH_LIMIT:
		hunt_paused = true
		pause_reason = "Esta área está perigosa para seu Poder atual."
		_revive_at = -1.0
	else:
		_revive_at = _now + REVIVE_DELAY

## CONTINUAR após a pausa de perigo (§21): limpa a janela, revive e retoma. (SAIR = stop.)
func continue_hunt() -> void:
	if not hunt_paused: return
	hunt_paused = false; pause_reason = ""; _death_times = []
	if _runtime != null: _runtime.revive()

## Poção de auto-cura deve CEDER ao MEND? (§26) — só para SUPPORT com MEND pronto e HP acima do crítico.
func support_self_heal_ready() -> bool:
	if _runtime == null: return false
	return str(_caster_class()) == "CLASS_5_SUPPORT"

func _caster_class() -> String:
	if game_state == null: return "LEGACY_CLASS"
	return str(repo.load(LOCAL_CHAR).get("state", {}).get("character_class", "LEGACY_CLASS"))

## Nome amigável da ground (o display_name_key é CANON_REVIEW_REQUIRED).
## ★★★ FIELD FIX 05/09/2026 — traduz SLOT DE SERVIDOR → POSIÇÃO DE MUNDO.
## O `anchor` que o `HuntWorld` aloca é uma grade de empacotamento social (§51) que começa em
## ~(200,200); usá-lo cru como posição levava o jogador ao canto da Vila inicial em QUALQUER
## ground. Aqui ele vira offset LOCAL dentro da região que hospeda o `map_id` do ground.
## ⛔ Se a ligação não existir, NÃO chuta: mantém o comportamento antigo e GRITA no log
## (ausência de ligação é dado faltando, não motivo para teleportar errado em silêncio).
## ★★★ FIELD FIX 05/09/2026 (A7/A8/G3) — APRESENTAÇÃO DO COMBATE.
## Traduz os eventos do runtime em leitura de tela, usando SÓ o que já existe no projeto:
##   "hit"  → o Errante encena o golpe, o mob reage (`play_hit`) e sobe o número de dano pelo
##            `GameFeedback` (floating damage do `FeedbackRenderer`).
##   "hurt" → dano ENTRANTE: número no Errante + reação de hit dele.
## ⛔ Nada de arte nova. Frames reais de ataque seguem como PLAYER_ATTACK_ANIMATION_ASSET_REQUIRED.
func _on_combat_feedback(kind: String, data: Dictionary) -> void:
	var fb = (_main.get("_feedback") if _main != null else null)
	# ★★★ FASE 15/16 — ROTEAMENTO POR INSTÂNCIA. O evento diz QUEM foi atingido; o ator sai do
	# registro. ⛔ NUNCA cair no primário quando o alvo é outro membro: era esse o bug latente
	# ("mostrar o dano de B em cima de A"). Só usa o primário se o evento não trouxer instância.
	var iid := int(data.get("instance_id", 0))
	var target: PveMobActor = _actor_for_instance(iid) if iid > 0 else null
	if target == null and iid > 0:
		# ★ FASE 19 — evento tardio de instância já removida: descarta com segurança e CONTA.
		# Não roteia para o primário, não recria ator, não estoura.
		host_group_stats["late_feedback_dropped"] = int(host_group_stats["late_feedback_dropped"]) + 1
		return
	if target == null:
		target = _mob_actor if _mob_actor != null and is_instance_valid(_mob_actor) else null
	var has_actor := target != null
	if kind == "hit":
		var amt := int(data.get("amount", 0))
		if has_actor:
			target.play_hit()
			if fb != null and amt > 0:
				fb.push_damage(amt, str(data.get("mob_id", "")), GameFeedback.K_DAMAGE_DEALT, target.global_position)
			_vfx_impact(target.global_position, amt, bool(data.get("crit", false)))
		if _player != null and _player.has_method("play_attack"):
			var aim := (target.global_position - _player.position) if has_actor else Vector2.ZERO
			_player.play_attack(aim)
			_vfx_swing(aim)
	elif kind == "mob_attack":
		# ★★★ FASE 17 — só QUEM atacou encena. Nada de animar o grupo inteiro.
		if has_actor: target.play_attack(_player.position - target.global_position if _player != null else Vector2.ZERO)
	elif kind == "hurt":
		var amt2 := int(data.get("amount", 0))
		if fb != null and amt2 > 0:
			fb.push_damage_taken(amt2, (_player.position if _player != null else _anchor))
		# `hit_recoil` é o método público que JÁ existia no PlayerController (flash + recoil).
		if _player != null and _player.has_method("hit_recoil"):
			_player.hit_recoil(target.global_position if has_actor else _anchor)
		# Impacto SOFRIDO: sempre físico e pequeno — quem apanha não muda de arquétipo.
		if amt2 > 0:
			CombatVfx.spawn(_vfx_parent(), "physical_hit_small", (_player.position if _player != null else _anchor), Vector2.RIGHT, 0.85)

# ─────────────── VFX DE COMBATE DA CAÇA (VISUAL ASSET INTEGRATION WAVE 1) ───────────────
## ⛔ Só APRESENTAÇÃO: nada aqui lê ou escreve dano, cooldown, credit ou HP. Se o VFX faltar, `spawn`
## devolve null e o combate segue idêntico — é por isso que estes três métodos não têm valor de retorno.
## ★★★ O arquétipo vem do GameState (derivado do SLOT da arma), NUNCA de nome textual.

## Pai em espaço de MUNDO. `_actors_root` é onde os atores da caça vivem; usar `self` poria o efeito
## no espaço do host (HUD) e ele apareceria colado na tela, não sobre o bicho.
## ⛔ NÃO exigir `is_inside_tree()` aqui: a primeira versão exigia, e isso DESLIGAVA o VFX em silêncio —
## parentear num nó fora da árvore é legítimo em Godot (o filho entra junto quando o pai entrar).
## `is_instance_valid` já cobre o caso que importa: raiz liberada entre o evento e o desenho.
func _vfx_parent() -> Node:
	if _actors_root != null and is_instance_valid(_actors_root):
		return _actors_root
	return null    # sem raiz de atores (host ainda não iniciou) → spawn vira no-op

func _vfx_archetype() -> String:
	if game_state != null and game_state.has_method("current_combat_archetype"):
		return str(game_state.current_combat_archetype())
	return "melee"

## Acento da CLASSE saindo do jogador na direção do alvo — é o que dá identidade visual à classe.
func _vfx_swing(aim: Vector2) -> void:
	var p := _vfx_parent()
	if p == null or _player == null:
		return
	var d := aim if aim.length() > 0.01 else Vector2.RIGHT
	var eff := CombatVfx.class_effect(_vfx_archetype(), "basic")
	CombatVfx.spawn(p, eff, _player.position + d.normalized() * 34.0, d, 0.9)

## Impacto no ALVO. `heavy` é relativo ao próprio golpe do jogador, não a um número mágico fixo:
## guarda-se o maior dano visto na sessão e chama-se de pesado o que passa de 70% dele.
var _vfx_peak_hit := 0
func _vfx_impact(pos: Vector2, amount: int, crit: bool) -> void:
	var p := _vfx_parent()
	if p == null or amount <= 0:
		return
	_vfx_peak_hit = maxi(_vfx_peak_hit, amount)
	var heavy := _vfx_peak_hit > 0 and float(amount) >= float(_vfx_peak_hit) * 0.7
	CombatVfx.spawn(p, CombatVfx.hit_effect(_vfx_archetype(), heavy, crit), pos, Vector2.RIGHT, 0.9)

func _world_anchor_for(gid: String, slot_off: Vector2) -> Vector2:
	var map_id := HuntingGround.map_of(gid)
	var region := HuntMapBinding.region_of_ground(gid)
	if region == "":
		# ⛔ A7 — FAIL LOUD, com o motivo EXATO quando ele é conhecido. Nada de cair calado.
		var why := HuntMapBinding.unresolved_map_reason(map_id)
		if why != "":
			push_error("[HuntHost] MAPA NAO RESOLVIDO p/ ground '%s' (map '%s'): %s" % [gid, map_id, why])
		else:
			push_error("[HuntHost] ground '%s' (map '%s') SEM regiao ligada — ver HuntMapBinding" % [gid, map_id])
		return slot_off
	if _main == null or not _main.has_method("region_world_origin"):
		return slot_off   # sem Main real (self-test): mantém o slot puro
	var origin: Vector2 = _main.region_world_origin(region)
	if origin == Vector2.INF:
		push_warning("[HuntHost] região '%s' (map '%s') fora do mundo mesclado — viagem não resolvida" % [region, map_id])
		return slot_off
	# ★★★ FIELD FIX 05/09/2026 — A "VILA DENTRO DA CAÇA" ERA POSICIONAMENTO, NÃO VAZAMENTO.
	# O mundo é um MACRO-ZONE CONTÍNUO: `starter_village` (x 0–2200), `plains` (2200–4600) e `cave`
	# coexistem por DESIGN, lado a lado. `origin + slot_off` punha o combate em ~(2400, 200) — o
	# CANTO da região, a 200px da divisa. Com meia-largura de câmera ~640 ela enxergava ~440px de
	# vila no terço esquerdo: casas, árvores, flores. Nada estava "vivo indevidamente".
	# ⇒ O combate passa a acontecer no CENTRO da região. O slot vira um espalhamento pequeno em
	# volta do centro, preservando o empacotamento social (§51) sem colar em fronteira nenhuma.
	# ★ FONTE ÚNICA com o MissionHost — o cálculo vive em `HuntMapBinding.world_combat_anchor`.
	var world := HuntMapBinding.world_combat_anchor(_main, map_id, slot_off)
	if world == Vector2.INF:
		push_warning("[HuntHost] mapa '%s' não resolveu âncora — usando slot puro" % map_id)
		return slot_off
	print("[HuntHost] viagem: ground=%s map=%s regiao=%s origem=%s slot=%s => mundo=%s (centro+spread)" % [gid, map_id, region, str(origin), str(slot_off), str(world)])
	return world

func _friendly_name(gid: String) -> String:
	match gid:
		"HG_PLAINS_LOW": return "PLANÍCIE (Iniciante)"
		"HG_PLAINS_HIGH": return "PLANÍCIE (Avançada)"
		"HG_CAVE": return "CAVERNA"
		_: return gid

## Overlay DEBUG/DEV — nunca em release. Devolve o estado inteiro do host p/ o field test.
func debug_state() -> Dictionary:
	var d := {"mode": ("HUNTING" if is_hunting() else "PROGRESSION"), "tick_owner": "HuntHost(single)",
		"account": LOCAL_ACCOUNT, "character": LOCAL_CHAR, "xp_synced": _synced_xp, "items_synced": _synced_items,
		"remote_hunters": presence_view.avatar_count() if presence_view != null else 0}
	if is_hunting():
		var s := hunt.get_hunt_state(LOCAL_CHAR)
		if bool(s.get("ok", false)):
			var sess: Dictionary = s["session"]; var stt: Dictionary = sess["stats"]
			d["ground_id"] = str(sess["ground_id"]); d["shard_id"] = str(sess.get("shard_key", "")); d["spot_id"] = str(sess["spot_id"])
			d["kills"] = int(stt["kills"]); d["xp"] = int(stt["xp"]); d["items"] = int(stt["items"])
			d["elite"] = int(stt["elite"]); d["apex"] = int(stt["apex"])
		var mob := _runtime.current_mob()
		d["mob_alive"] = mob != null and mob.alive()
		d["mob_hp"] = (mob.hp if mob != null else 0)
		d["ticks"] = int(_runtime.runtime_stats["ticks"])
		d["cycles"] = int(_runtime.runtime_stats["cycles"])
		d["party_id"] = str(hunt.party.party_of(LOCAL_CHAR)) if hunt.party.has_method("party_of") else ""
		# A17.10B — HP truth único + sobrevivência
		if game_state != null:
			d["hp"] = int(game_state.hero_hp); d["max_hp"] = int(game_state.max_hp_total()); d["shield"] = int(game_state.shield_amount)
			d["dead"] = game_state.is_hero_defeated()
		d["deaths"] = int(_runtime.runtime_stats["deaths"]); d["damage_taken"] = int(_runtime.runtime_stats["damage_taken"])
		d["paused"] = hunt_paused; d["pause_reason"] = pause_reason
	return d
