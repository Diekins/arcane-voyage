class_name StageDirector extends Node
## StageDirector — PROGRESSÃO AUTOMÁTICA POR FASES (FATIA A2 do pivô idle-first).
##
## A1 fez a caça infinita (matar → próximo → matar…). A2 dá ESTRUTURA a essa caça: a jornada avança sozinha
## por FASES numeradas `capítulo-fase` (1-1, 1-2, … 1-10, 2-1, …). Fases normais fecham por COTA de kills;
## a fase 5 é MINI-BOSS; a fase 10 é BOSS de capítulo (fecha o capítulo → começa o próximo).
##
## SEPARAÇÃO DE RESPONSABILIDADES (obrigatória):
##   AutoPlay.gd      → EXECUTA o combate (procura/aproxima/luta/mata).
##   StageDirector.gd → DECIDE qual é a fase, quando termina, qual vem depois, e QUAIS inimigos contam/valem.
##   Main.gd          → host: adapters mínimos + alimenta o evento de morte + persiste.
## O StageDirector NÃO spawna mob, NÃO calcula dano, NÃO toca combate. O AutoPlay NÃO conhece fases.
##
## ESCOPO A2 (deliberado): SÓ progressão ESTRUTURAL. NADA de CP/PowerBudget/muro/dificuldade/recompensa-de-
## fase/offline/prestígio. O jogador SEMPRE avança ao cumprir o objetivo (sem gate de poder — isso é A3+).
##
## MODELO NUMÉRICO: global = (chapter-1)*STAGES_PER_CHAPTER + stage. A string "1-5" é só rótulo — a lógica usa
## chapter/stage/global inteiros.
##
## DATA-DRIVEN (FATIA A7.4): a FONTE DE VERDADE do conteúdo é o `ContentManifest`, chaveado por CAPÍTULO
## (1-10). O StageDirector resolve chapter/local/global/tipo/world_context/normal_pool/apex/boss/gear_tier
## via manifesto. `REGION_CONTENT` (plains/cave) permanece só como FALLBACK LEGADO para o filtro de kill quando
## a REGIÃO FÍSICA diverge do capítulo (jogador que voltou a um mapa antigo não trava). Quando a região casa
## com o capítulo (o fluxo normal 1-1→10-10), o conteúdo vem do manifesto. Cap 1-2 = plains/cave: manifesto e
## legado são IDÊNTICOS (regressão preservada); cap 3-10 passam a existir pela primeira vez.

signal state_changed(new_state: int)
signal stage_changed(chapter: int, stage: int)   # p/ HUD/telemetria

enum St { INACTIVE, PREPARING, RUNNING, TRANSITIONING, BOSS_STAGE, COMPLETED }

const STAGE_DIRECTOR_DEBUG := true
const LOG_EACH_KILL := true               # se true, loga "kill N/cota" (desligável p/ não poluir)

const STAGES_PER_CHAPTER := 10
const MINIBOSS_STAGE := 5
const BOSS_STAGE := 10
const NORMAL_STAGE_DEFAULT_QUOTA := 30
const ENCOUNTER_QUOTA := 1                 # mini-boss/boss fecham com 1 morte do encounter
const TRANSITION_DELAY := 0.6              # s entre fases (evita morte antiga contar na fase nova)
const DEDUP_WINDOW := 96                   # nº de mortes recentes lembradas p/ anti-dupla-contagem

# ── MURO DE PROGRESSÃO (FATIA A3) ──────────────────────────────────────────────────────────────────
const MAX_FAILS := 3                       # 3 derrotas consecutivas na frontier → muro
const AUTO_EXIT_RATIO := 0.95              # CP >= required×0.95 → libera nova tentativa automática
const MODE_ADVANCE := "advance"            # avança fases
const MODE_FARM := "farm"                  # muro ativo: farma a última fase dominada, sem avançar
## Mobs de TESTE/DEV (auditados: comentário "MONSTRO DE TESTE" no _mob_configs, stats fora da curva). NÃO
## contam nem viram alvo no idle (evita contaminar cota/CP/calibração — §17). NÃO deletados, NÃO alteram lore.
const TEST_MOB_IDS := ["mage_of_heaven", "musgo_voraz"]

## Tipos de fase.
const T_NORMAL := "normal"
const T_MINIBOSS := "miniboss"
const T_BOSS := "boss"

## Cota por fase normal (override do default). Exemplo do briefing (1-1..1-4 mais curtas); demais = default.
## Chave = stage index (1..10). Ausente = NORMAL_STAGE_DEFAULT_QUOTA.
const NORMAL_QUOTA_OVERRIDE := {
	1: 20, 2: 24, 3: 26, 4: 30,
}

## CONTEÚDO REAL POR REGIÃO (auditado em _build_mobs/_build_wolf/_build_golem). `boss_name` em minúsculas
## (casa com _on_boss_defeated → mark_boss_defeated, que usa .to_lower()). `miniboss_id` = mob_id de um ELITE
## real do pool (marcado PROVISÓRIO onde não há mini-boss dedicado — escolha TÉCNICA, sem inventar lore).
const REGION_CONTENT := {
	"plains": {
		"display": "Planície dos Novatos",
		"normal_pool": ["young_wolf", "wild_boar", "road_bandit"],
		"miniboss_id": "road_bandit",          # PROVISÓRIO: mob raro/perigoso do pool (sem mini-boss dedicado)
		"boss_name": "lobo alfa",
	},
	"cave": {
		"display": "Caverna Esquecida",
		"normal_pool": ["crystal_bat", "living_shard", "crawling_shade", "grove_spider", "green_slime", "dusk_bat"],
		"miniboss_id": "stone_sentinel",       # elite REAL (tank pesado) do pool da Caverna
		"boss_name": "golem de cristal",
	},
}

## Ordem canônica dos capítulos com conteúdo REAL (provada pelo grafo de portais: Planície → Caverna).
## Além disto, um capítulo cai no fallback genérico da região corrente (documentado).
const CHAPTER_ORDER := ["plains", "cave"]

var _host = null
var _state: int = St.INACTIVE
var chapter := 1
var stage := 1
var stage_kills := 0
var highest_global := 1
var _transition_t := 0.0
var _dedup: Array = []                     # dedup_keys recentes (fila circular)
var _dedup_set: Dictionary = {}            # lookup O(1)
var _region_id := ""
# MURO (A3)
var mode := MODE_ADVANCE
var wall_active := false
var consecutive_fails := 0
var frontier_chapter := 1                  # fase travada (quando em muro)
var frontier_stage := 1
var farm_chapter := 1                       # última fase dominada (onde farma no muro)
var farm_stage := 1

func setup(host) -> void:
	_host = host
	_region_id = _host.stagedirector_region_id() if _host != null else ""
	var saved: Dictionary = _host.stagedirector_load() if _host != null else {}
	chapter = maxi(1, int(saved.get("chapter", 1)))
	stage = clampi(int(saved.get("stage", 1)), 1, STAGES_PER_CHAPTER)
	stage_kills = maxi(0, int(saved.get("stage_kills", 0)))
	highest_global = maxi(1, int(saved.get("highest_global", global_stage())))
	# MURO (A3): restaura o estado do muro/farm (defaults = sem muro, avanço).
	mode = MODE_FARM if str(saved.get("mode", MODE_ADVANCE)) == MODE_FARM else MODE_ADVANCE
	wall_active = bool(saved.get("wall_active", false))
	consecutive_fails = maxi(0, int(saved.get("fails", 0)))
	frontier_chapter = maxi(1, int(saved.get("frontier_chapter", chapter)))
	frontier_stage = clampi(int(saved.get("frontier_stage", stage)), 1, STAGES_PER_CHAPTER)
	farm_chapter = maxi(1, int(saved.get("farm_chapter", 1)))
	farm_stage = clampi(int(saved.get("farm_stage", 1)), 1, STAGES_PER_CHAPTER)
	_enter_stage(false)   # começa a fase carregada (sem persistir de novo)

## global ↔ chapter/stage
func global_stage() -> int:
	return (chapter - 1) * STAGES_PER_CHAPTER + stage

func stage_type() -> String:
	if stage == BOSS_STAGE: return T_BOSS
	if stage == MINIBOSS_STAGE: return T_MINIBOSS
	return T_NORMAL

func stage_quota() -> int:
	match stage_type():
		T_BOSS, T_MINIBOSS: return ENCOUNTER_QUOTA
		_: return int(NORMAL_QUOTA_OVERRIDE.get(stage, NORMAL_STAGE_DEFAULT_QUOTA))

## Tipo de uma fase pelo índice (1..10). Usado p/ frontier/farm que não são a fase corrente.
func _type_of(st: int) -> String:
	if st == BOSS_STAGE: return T_BOSS
	if st == MINIBOSS_STAGE: return T_MINIBOSS
	return T_NORMAL

func _global_of(ch: int, st: int) -> int:
	return (ch - 1) * STAGES_PER_CHAPTER + st

func _ch_st_of_global(g: int) -> Array:
	g = maxi(1, g)
	return [(g - 1) / STAGES_PER_CHAPTER + 1, (g - 1) % STAGES_PER_CHAPTER + 1]

# ── CP recomendado / razão de poder (via ProgressionMath + PowerBudget do host) ──
func required_cp() -> int:
	return ProgressionMath.required_cp(global_stage(), stage_type())

func frontier_global() -> int:
	return _global_of(frontier_chapter, frontier_stage)

func frontier_required_cp() -> int:
	return ProgressionMath.required_cp(frontier_global(), _type_of(frontier_stage))

func _player_cp() -> int:
	if _host != null and _host.has_method("stagedirector_player_cp"):
		return int(_host.stagedirector_player_cp())
	return 0

func power_ratio() -> float:
	return ProgressionMath.power_ratio(_player_cp(), required_cp())

func ratio_band() -> String:
	return ProgressionMath.ratio_band(power_ratio())

## Escala os stats-base de UM mob p/ a fase CORRENTE (deriva do base imutável → sem acúmulo). Usado pelo Main
## no spawn e no restat de troca de fase.
func scale_for_current(base_max_hp: int, base_dmg_min: int, base_dmg_max: int) -> Dictionary:
	return ProgressionMath.scale_mob_stats(base_max_hp, base_dmg_min, base_dmg_max, global_stage(), stage_type())

## FATIA A3.75 — escala os stats-base do BOSS DE REGIÃO (Lobo/Golem) p/ a fase corrente. O boss é SEMPRE
## um encontro de BOSS (mult ×4 HP / ×1.3 dano), independentemente do índice da fase corrente — deriva do
## base imutável → sem acúmulo.
func scale_boss_for_current(base_max_hp: int, base_dmg_min: int, base_dmg_max: int) -> Dictionary:
	return ProgressionMath.scale_mob_stats(base_max_hp, base_dmg_min, base_dmg_max, global_stage(), T_BOSS)

func is_wall_active() -> bool:
	return wall_active

func frontier_label() -> String:
	return "%d-%d" % [frontier_chapter, frontier_stage]

## ── A7.4: RESOLUÇÃO PELO MANIFESTO (chaveada por CAPÍTULO) ──
## Capítulo do manifesto para a fase corrente ({} se fora de 1-10).
func _manifest_chapter() -> Dictionary:
	return ContentManifest.chapter(chapter)

## A região FÍSICA corrente casa com o capítulo (region ou world_contexts do manifesto)? Vazio = casa.
func _region_aligned() -> bool:
	if _region_id == "":
		return true
	var mc := _manifest_chapter()
	if mc.is_empty():
		return true
	if str(mc.get("region", "")) == _region_id:
		return true
	return (mc.get("world_contexts", []) as Array).has(_region_id)

## Conteúdo p/ o FILTRO DE KILL: manifesto quando a região casa com o capítulo; senão, região física (legado).
## Isto garante que um jogador que voltou a um mapa antigo feche a fase no boss/pool DAQUELE mapa (sem travar).
func _content() -> Dictionary:
	if _region_aligned():
		var mc := _manifest_chapter()
		if not mc.is_empty():
			return {
				"display": str(mc.get("display", "")),
				"normal_pool": mc.get("normal_pool", []),
				"miniboss_id": str(mc.get("apex", "")),
				"boss_name": str(mc.get("boss_name", "")),
			}
	return REGION_CONTENT.get(_region_id, {})

func _normal_pool() -> Array:
	return _content().get("normal_pool", [])   # vazio = fallback: qualquer hostil não-boss conta

func _miniboss_id() -> String:
	return str(_content().get("miniboss_id", ""))

func _boss_name() -> String:
	return str(_content().get("boss_name", ""))

## ── A7.4: ACESSORES DE RUNTIME (leem o MANIFESTO direto pelo capítulo — independem da região física) ──
## Nome de exibição do capítulo corrente (ex.: "Pântano de Ferro").
func chapter_display() -> String:
	return str(_manifest_chapter().get("display", ""))

## world_context (region_id) desta fase, distribuído data-driven entre os world_contexts do capítulo (§4).
func world_context() -> String:
	return ContentManifest.region_for_stage(global_stage())

## Tier de gear canônico do capítulo (fonte única no ContentManifest).
func gear_tier() -> int:
	return ContentManifest.gear_tier(chapter)

## boss_id (slug) do capítulo — p/ spawn data-driven do boss (Main mapeia id → script/controller).
func boss_id() -> String:
	return str(_manifest_chapter().get("boss_id", ""))

func boss_status() -> String:
	return str(_manifest_chapter().get("boss_status", ""))

## apex (mob_id do encontro da fase 5) do capítulo.
func apex_id() -> String:
	return str(_manifest_chapter().get("apex", ""))

## normal_pool do MANIFESTO (independe da região física; p/ HUD/telemetria/loot).
func manifest_pool() -> Array:
	return _manifest_chapter().get("normal_pool", [])

## Rótulo curto p/ a HUD provisória.
func stage_label() -> String:
	return "%d-%d" % [chapter, stage]

func stage_hud_text() -> String:
	match stage_type():
		T_BOSS:
			return "FASE %s\nBOSS" % stage_label()
		T_MINIBOSS:
			return "FASE %s\nMINI-BOSS" % stage_label()
		_:
			return "FASE %s\n%d / %d" % [stage_label(), stage_kills, stage_quota()]

func get_state() -> int:
	return _state

## ── EVENTO DE MORTE (alimentado pelo Main: _on_mob_died p/ mobs, _on_boss_defeated p/ boss) ──
## `dedup_key` deve ser ÚNICO por MORTE (ex.: "instanceId:deathSerial"); mortes repetidas do mesmo evento
## são ignoradas (anti-dupla-contagem, §11). Respawn depois = nova morte (deathSerial novo) = conta de novo.
func notify_kill(kill_id: String, is_boss: bool, dedup_key: String = "") -> void:
	if _state != St.RUNNING and _state != St.BOSS_STAGE:
		return   # PREPARING/TRANSITIONING/INACTIVE/COMPLETED: morte não conta (evita vazar p/ a fase nova)
	if dedup_key != "":
		if _dedup_set.has(dedup_key):
			return
		_remember_dedup(dedup_key)
	if not _kill_counts(kill_id, is_boss):
		return
	stage_kills += 1
	if LOG_EACH_KILL:
		_dbg("kill %d/%d (%s) fase %s" % [stage_kills, stage_quota(), kill_id, stage_label()])
	if stage_kills >= stage_quota():
		_complete_stage()

## Este kill conta para a fase ATUAL?
func _kill_counts(kill_id: String, is_boss: bool) -> bool:
	match stage_type():
		T_BOSS:
			# fecha só com o BOSS da região (ou, em fallback sem boss_name, qualquer is_boss).
			var bn := _boss_name()
			if bn == "":
				return is_boss
			return is_boss and kill_id.to_lower() == bn
		T_MINIBOSS:
			# fecha só com o ELITE designado (mob comum específico); mobs normais NÃO fecham (§7/T07).
			var mid := _miniboss_id()
			if mid == "":
				return is_boss   # fallback genérico: sem elite designado → trata como encontro de boss
			return (not is_boss) and kill_id == mid
		_:
			# NORMAL: qualquer hostil NÃO-boss (nunca mob de teste/dev). Se há pool declarado, restringe a ele.
			if is_boss or TEST_MOB_IDS.has(kill_id):
				return false
			var pool := _normal_pool()
			return pool.is_empty() or pool.has(kill_id)

## ── FILTRO DE CANDIDATO p/ o AutoPlay (via adapter do Main). "Este inimigo é alvo válido AGORA?" ──
## Normal: só mobs não-boss (o BOSS fica FORA de mira até a fase 10 → não dispara narrativa cedo).
## Mini-boss: só o elite designado. Boss: só o boss. Fallback documentado quando faltar id.
func candidate_ok(kill_id: String, is_boss: bool) -> bool:
	match stage_type():
		T_BOSS:
			if _boss_name() == "":
				return true   # fallback: sem boss designado → não filtra (deixa caçar)
			return is_boss
		T_MINIBOSS:
			var mid := _miniboss_id()
			if mid == "":
				return true
			return (not is_boss) and kill_id == mid
		_:
			return (not is_boss) and not TEST_MOB_IDS.has(kill_id)   # normal: nunca mira o boss nem mob de teste

## ── TRANSIÇÕES ──
func _complete_stage() -> void:
	# FATIA A7.2: cada ciclo concluído (avanço OU farm) rende Fragmentos escalados com a fase (sink-feeder do Refino).
	if _host != null and _host.has_method("stagedirector_cycle_reward"):
		_host.stagedirector_cycle_reward(global_stage())
	if mode == MODE_ADVANCE:
		consecutive_fails = 0   # completar uma fase = vitória → zera a série de falhas (WALL-T12)
		_dbg("complete %s" % stage_label())
		if stage_type() == T_BOSS:
			_dbg("chapter complete %d" % chapter)
			# FATIA A6: boss-stage (fase 10) concluída EM AVANÇO → +1 SELO DE CICLO (1ª vez no ciclo; dedup por
			# watermark no host/GameState — farm/retry não passam por aqui em MODE_ADVANCE, §8/§9).
			if _host != null and _host.has_method("stagedirector_boss_cleared"):
				_host.stagedirector_boss_cleared(global_stage())
		# FATIA A7.1: encontro (APEX fase-5 / BOSS fase-10) concluído EM AVANÇO → drops de suporte de refino
		# (first-clear do ciclo; dedup no host/GameState — farm não repete, §55).
		if (stage_type() == T_MINIBOSS or stage_type() == T_BOSS) and _host != null and _host.has_method("stagedirector_encounter_cleared"):
			_host.stagedirector_encounter_cleared(global_stage())
		_persist_wall()
	else:
		_dbg("farm round complete %s" % stage_label())   # muro: rodada de farm concluída (não avança)
	_set_state(St.TRANSITIONING)
	_transition_t = TRANSITION_DELAY

## Avança o cronômetro de transição. Chamado pelo Main no _process.
func tick(delta: float) -> void:
	if _state != St.TRANSITIONING:
		return
	_transition_t -= delta
	if _transition_t <= 0.0:
		_advance_stage()

func _advance_stage() -> void:
	if mode == MODE_FARM:
		# MURO ATIVO: repete a MESMA fase de farm (NÃO avança, NÃO mexe em highest_global). Idle não para.
		stage_kills = 0
		_dbg("farm repete %s (highest intacto %d)" % [stage_label(), highest_global])
		_enter_stage(false)
		_maybe_auto_exit_wall()   # na fronteira segura do ciclo, tenta liberar o muro se o CP já basta
		return
	# MODO AVANÇO: progressão normal.
	var prev := stage_label()
	if stage >= STAGES_PER_CHAPTER:
		chapter += 1
		stage = 1
	else:
		stage += 1
	stage_kills = 0
	highest_global = maxi(highest_global, global_stage())
	_dbg("transition %s -> %s" % [prev, stage_label()])
	_enter_stage(true)

## ── MURO: derrota do jogador durante a tentativa/rodada ──
## Chamado pelo Main quando o herói é abatido em combate ativo. Reseta o progresso da tentativa (§20) e,
## no modo avanço, conta a falha; 3 falhas consecutivas ⇒ MURO (§21).
func notify_player_defeated() -> void:
	if _state != St.RUNNING and _state != St.BOSS_STAGE:
		return
	stage_kills = 0   # morte reseta o progresso da tentativa/rodada atual (WALL-T02)
	# A3.75: a tentativa reinicia → o encounter (boss/apex/mobs) volta ao estado inicial ESCALADO da fase
	# (boss não carrega o dano da tentativa anterior — §26). Deriva do base imutável, sem acúmulo.
	if _host != null and _host.has_method("stagedirector_restat_mobs"):
		_host.stagedirector_restat_mobs()
	if mode == MODE_ADVANCE and not wall_active:
		consecutive_fails += 1
		_dbg("tentativa falhou %d/%d em %s" % [consecutive_fails, MAX_FAILS, stage_label()])
		if consecutive_fails >= MAX_FAILS:
			_enter_wall()
		else:
			_persist_wall()
	_persist()

## Entra no MURO: fixa a frontier (fase travada), farma a última fase DOMINADA (frontier_global-1, ≥1).
func _enter_wall() -> void:
	wall_active = true
	mode = MODE_FARM
	frontier_chapter = chapter
	frontier_stage = stage
	var cs := _ch_st_of_global(maxi(1, frontier_global() - 1))   # última fase dominada
	farm_chapter = cs[0]
	farm_stage = cs[1]
	chapter = farm_chapter
	stage = farm_stage
	stage_kills = 0
	_dbg("★ MURO ATIVO — frontier %d-%d · farm %d-%d (3 falhas)" % [frontier_chapter, frontier_stage, farm_chapter, farm_stage])
	_persist_wall()
	_enter_stage(false)   # entra na fase de farm

## Sai do MURO: retoma a frontier em modo avanço, zera a série de falhas.
func _exit_wall(reason: String) -> void:
	wall_active = false
	mode = MODE_ADVANCE
	consecutive_fails = 0
	chapter = frontier_chapter
	stage = frontier_stage
	stage_kills = 0
	_dbg("★ MURO LIBERADO (%s) — retoma %d-%d" % [reason, chapter, stage])
	_persist_wall()
	_enter_stage(true)

## Saída AUTOMÁTICA: CP >= frontier_required × 0.95 → programa nova tentativa (na fronteira segura de ciclo).
func _maybe_auto_exit_wall() -> void:
	if not wall_active:
		return
	var pcp := _player_cp()
	var need := int(round(float(frontier_required_cp()) * AUTO_EXIT_RATIO))
	if pcp >= need:
		_exit_wall("cp %d ≥ %d" % [pcp, need])

## Saída MANUAL ("TENTAR NOVAMENTE"): tenta a frontier mesmo abaixo de 95% (CP é recomendação, não prisão).
## Retorna true se havia muro p/ liberar.
func request_retry() -> bool:
	if not wall_active:
		return false
	_exit_wall("manual")
	return true

## FATIA A6 — RESET DE CICLO (Prestígio): a jornada IDLE volta p/ 1-1, sem muro/farm/falhas. NÃO toca o
## personagem (isso é do GameState/PrestigeManager). O host já zerou os campos de fase no GameState ANTES de
## chamar aqui; este método realinha o estado VIVO do StageDirector e entra limpo na fase 1-1. §18/§33.
func reset_to_new_cycle() -> void:
	chapter = 1
	stage = 1
	stage_kills = 0
	highest_global = 1
	mode = MODE_ADVANCE
	wall_active = false
	consecutive_fails = 0
	frontier_chapter = 1
	frontier_stage = 1
	farm_chapter = 1
	farm_stage = 1
	_transition_t = 0.0
	_dedup.clear(); _dedup_set.clear()   # mortes do ciclo antigo não contam no novo
	_persist_wall()
	_enter_stage(true)   # entra em 1-1 (re-escala mobs vivos p/ a fase nova) e persiste o ponteiro
	_dbg("★ RESET DE CICLO — jornada idle em 1-1 (Prestígio)")

## Entra na fase atual: define estado por tipo, reseta contagem se pedido, persiste, avisa a HUD.
func _enter_stage(persist: bool) -> void:
	stage_changed.emit(chapter, stage)
	match stage_type():
		T_BOSS:
			_dbg("boss %s (%s)" % [stage_label(), _boss_name()])
			_set_state(St.BOSS_STAGE)
		T_MINIBOSS:
			_dbg("miniboss %s (%s)" % [stage_label(), _miniboss_id()])
			_set_state(St.BOSS_STAGE)
		_:
			_dbg("start %s" % stage_label())
			_set_state(St.RUNNING)
	# A3: re-escala os mobs VIVOS p/ a fase corrente (deriva do base imutável → sem acúmulo).
	if _host != null and _host.has_method("stagedirector_restat_mobs"):
		_host.stagedirector_restat_mobs()
	if persist:
		_persist()

## ── REGIÃO / RECONCILIAÇÃO ── (Main chama em load_region). Re-resolve o conteúdo p/ a nova região;
## NÃO reseta a progressão (o número da fase é do PERSONAGEM, não do mapa). Zera dedup do mapa antigo.
func notify_region_changed() -> void:
	if _host != null:
		_region_id = _host.stagedirector_region_id()
	_dedup.clear(); _dedup_set.clear()
	_transition_t = 0.0
	# se estávamos em transição, entra limpo na fase corrente da nova região
	if _state == St.TRANSITIONING:
		_enter_stage(false)
	else:
		_enter_stage(false)
	_dbg("região reconciliada: %s (fase %s)" % [_region_id, stage_label()])

func _persist() -> void:
	if _host != null and _host.has_method("stagedirector_persist"):
		_host.stagedirector_persist(chapter, stage, stage_kills, highest_global)

## Persiste o estado do MURO (A3).
func _persist_wall() -> void:
	if _host != null and _host.has_method("stagedirector_persist_wall"):
		_host.stagedirector_persist_wall(mode, wall_active, consecutive_fails, frontier_chapter, frontier_stage, farm_chapter, farm_stage)

func _remember_dedup(key: String) -> void:
	_dedup.append(key)
	_dedup_set[key] = true
	if _dedup.size() > DEDUP_WINDOW:
		var old = _dedup.pop_front()
		_dedup_set.erase(old)

func _set_state(s: int) -> void:
	if s == _state:
		return
	_state = s
	state_changed.emit(s)

func _dbg(msg: String) -> void:
	if STAGE_DIRECTOR_DEBUG:
		print("[StageDirector] %s" % msg)
