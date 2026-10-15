extends Node
## GameState (autoload) — estado da campanha EM MEMÓRIA + SAVE LOCAL (GODOT-SAVE-1).
##
## Espelha `CampaignProgress` do protótipo web + o nível do herói. Persiste o progresso do
## slice em `user://arcane_voyage_save.json` (autosave a cada mutação; tolerante a arquivo/
## campos ausentes). Emite `state_changed` a cada mutação p/ a HUD se atualizar.
## NÃO é o MasterSave da campanha inteira — só o necessário pro vertical slice.

signal state_changed
signal item_granted(item_id: String, item_name: String)   # só em concessão NOVA (p/ popup)
signal leveled_up(level: int)                              # subiu de nível (p/ popup)
signal vocation_leveled(key: String, level: int)          # proficiência subiu (GODOT-VOCATION-PROFICIENCY-MVP-1)
signal mastery_leveled(key: String, level: int)           # maestria exclusiva subiu (GODOT-ORACLE-PRESAGE-MASTERY-MVP-1)

const SAVE_PATH := "user://arcane_voyage_save.json"
# FATIA A7 (REGRA DE TESTES) — override de caminho de save p/ FIXTURE DESCARTÁVEL. Default "" ⇒ usa SAVE_PATH
# (comportamento de produção idêntico). Self-tests que MUTAM save DEVEM chamar set_save_path_override() p/ NUNCA
# escrever sobre o save vivo do dono. Um self-test de A6 chegou a contaminar o save real — proibido reincidir.
var _save_path_override := ""
func set_save_path_override(p: String) -> void:
	_save_path_override = p
func _save_path() -> String:
	return _save_path_override if _save_path_override != "" else SAVE_PATH
const SAVE_SCHEMA := 10   # v9→v10 (FATIA A13): character_class + appearance + display_name + loadouts + active_loadout. Migração via SaveMigration.
# PROFICIÊNCIA POR VOCAÇÃO (GODOT-VOCATION-PROFICIENCY-MVP-1) — data-driven, conservador. A proficiência
# é da ARMA/ESTILO ATIVO (afinidade): o bônus só vale enquanto a arma daquele arquétipo está equipada
# (ver vocation_bonus). Guerreiro que treinou cajado antes NÃO leva poder mágico ao empunhar espada.
# FUTURO (não nesta tarefa): domínios mágicos transversais + poder efetivo dependente da afinidade da
# arma atual; Oráculo/support/book; árvore de skills; buffs/debuffs. Aqui: só XP/level + bônus capado.
const VOCATION_DEFS := {
	"melee":  {"name": "Guerreiro", "xp_base": 40, "growth": 1.35, "bonus_stat": "attack", "per": 1, "every": 3, "cap": 5},
	"reach":  {"name": "Lanceiro",  "xp_base": 40, "growth": 1.35, "bonus_stat": "attack", "per": 1, "every": 3, "cap": 5},
	"ranged": {"name": "Arqueiro",  "xp_base": 40, "growth": 1.35, "bonus_stat": "attack", "per": 1, "every": 3, "cap": 5},
	"magic":  {"name": "Mago",      "xp_base": 40, "growth": 1.35, "bonus_stat": "magic",  "per": 1, "every": 3, "cap": 5},
	# Oráculo (GODOT-ORACLE-WEAPON-BOOK-1): suporte. Sem stat "support" próprio ainda → bônus em `magic`,
	# porém MAIS LENTO e MENOR teto que o Mago (xp_base/growth/every maiores, cap 4) → Oráculo evolui e
	# escala devagar (mata mais devagar; identidade = sustain/controle, que virão em GODOT-ORACLE-SUPPORT-KIT-1).
	"support": {"name": "Oráculo", "xp_base": 48, "growth": 1.40, "bonus_stat": "magic", "per": 1, "every": 4, "cap": 4},
}
# MAESTRIA EXCLUSIVA DE CLASSE (GODOT-ORACLE-PRESAGE-MASTERY-MVP-1) — camada SEPARADA da proficiência:
# só sobe por EFEITO REAL do kit da classe e melhora SÓ aquele kit (não o dano geral). Curva mais lenta e
# cap MENOR que a proficiência → especialista de verdade leva tempo. MVP: só "presage" (Oráculo).
const CLASS_MASTERY_DEFS := {
	"presage": {"name": "Maestria de Presságio", "xp_base": 60, "growth": 1.45, "per": 1, "every": 3, "cap": 3},
	"guard":   {"name": "Maestria de Guarda",    "xp_base": 60, "growth": 1.45, "per": 1, "every": 3, "cap": 3},
	"arcane":  {"name": "Maestria Arcana",       "xp_base": 64, "growth": 1.50, "per": 1, "every": 3, "cap": 3},
	"precision": {"name": "Maestria de Precisão", "xp_base": 60, "growth": 1.45, "per": 1, "every": 3, "cap": 3},
	"stance":  {"name": "Maestria de Postura",   "xp_base": 60, "growth": 1.45, "per": 1, "every": 3, "cap": 3},
}
const DEFAULT_QUEST := "ch1-awakening"   # quest ativa do vertical slice
const DEFAULT_REGION := "starter_village"   # região inicial = Vila dos Novatos (hub seguro); Planície vira área de hunt
# tutorial/onboarding client-side (GODOT-VILLAGE-TUTORIAL-QUEST-1): 1 string persistida = próxima
# meta. START em save novo/F12; DONE = encerrado. Etapas intermediárias são geridas por Main.gd.
const TUTORIAL_START := "talk_elder"
const TUTORIAL_DONE := "done"

## Nível inicial do slice = 1 (a 1ª cena de nível, intro-mentor, é @2 — use F7 p/ subir).
var hero_level: int = 1
var seen_dialogues: Array[String] = []
var completed_quests: Array[String] = []
var defeated_bosses: Array[String] = []   # nomes de boss em minúsculas (match case-insensitive)
var choices: Dictionary = {}              # sceneId -> choiceId
var inventory_items: Array[String] = []   # ids de relíquias/itens narrativos concedidos
var hero_hp: int = 100                     # HP atual do Errante (combate mínimo)
var hero_hp_max: int = 100
var hero_xp: int = 0                        # XP do loop de hunt (mobs comuns)
var hero_xp_to_next: int = 100
var hero_gold: int = 0
# RECURSOS DE CLASSE (GODOT-CLASS-RESOURCES-MVP-1): munição do arco + mana do cajado. Persistidos,
# com defaults seguros p/ saves antigos (ver apply_dict). NÃO afetam quem usa espada/lança.
# FLECHAS = munição comprável em LOTES (GODOT-ARROWS-SHOP-AMMO-1): stack até 500, comprada de 100 em 100
# na loja da Sila. Cada disparo do arco gasta 1. NÃO regenera nem entra no refill grátis (só mana regenera).
const ARROWS_STACK_MAX := 500     # teto do stack de flechas
const ARROWS_BUNDLE := 100        # lote de compra (100 em 100)
var arrows_current: int = 100     # começa com 1 lote
var arrows_max: int = ARROWS_STACK_MAX
var mana_current: int = 50
var mana_max: int = 50
# PROFICIÊNCIA por arquétipo ativo (GODOT-VOCATION-PROFICIENCY-MVP-1): {key: {"xp":int, "level":int}}.
# Vazio em save novo/antigo; entradas criadas sob demanda (_ensure_voc). Chaves válidas = VOCATION_DEFS.
var proficiency: Dictionary = {}
# MAESTRIA EXCLUSIVA (GODOT-ORACLE-PRESAGE-MASTERY-MVP-1): {key: {"xp":int,"level":int}}. Vazio em save
# novo/antigo; entradas sob demanda. Chaves válidas = CLASS_MASTERY_DEFS.
var class_mastery: Dictionary = {}
var materials: Dictionary = {}             # nome do material -> quantidade (drops comuns)
# mochila/equipamentos (GODOT-EQUIPMENT-INVENTORY-FOUNDATION-1): itens do ItemDB
var backpack: Array = []                    # [{"id": String, "qty": int}] — equipáveis/consumíveis
# BAÚ DA VILA / DEPÓSITO DO ERRANTE (GODOT-VILLAGE-STASH-MVP-1): depósito permanente, sem limite no MVP.
# Guarda MATERIAIS (nome->qtd) e ITENS EMPILHÁVEIS (id->qtd). Equipamento NÃO-empilhável fica de fora do
# MVP (próximo passo). Persistido; save antigo sem o campo -> vazio.
var player_stash: Dictionary = {"materials": {}, "items": {}}
var equipment: Dictionary = {}             # slot -> item_id (ItemDB)
var active_quest_id: String = DEFAULT_QUEST   # quest exibida no tracker
var current_region_id: String = DEFAULT_REGION   # região atual (Planície/Caverna…)
# MUNDO CONTÍNUO graduado (GODOT-CONTINUOUS-WORLD-GRADUATION-1): posição GLOBAL do Errante dentro de um cluster
# canônico + id do cluster. Vazio = sem posição (boot usa o spawn da região salva). Campo NOVO (save antigo tolera).
var cluster_pos: Array = []        # [x, y] em px-mundo (coords globais do cluster) ou [] = ausente
var cluster_id: String = ""        # cluster canônico atual ("" = não está num cluster graduado)
var tutorial_step: String = TUTORIAL_START   # etapa do onboarding da Vila (persistida; Main avança)
var side_quests: Dictionary = {}   # side-quests da Vila (GODOT-VILLAGE-SIDEQUESTS-CHAIN-1): id → "active"/"done"
var side_quest_progress: Dictionary = {}   # progresso numérico de side-quest (GODOT-SIDEQUEST-KILLCOUNT-1): id → int (ex.: kill-count)
var board_rotation: int = 0   # rotação dos contratos repetíveis do mural (GODOT-BOUNTY-REPEATABLE-ROTATION-1); avança no "🔄 Atualizar"
var bounty_completed_count: int = 0   # total de contratos do mural ENTREGUES (GODOT-BOUNTY-BOARD-POLISH-1); repetível conta a cada entrega; base da reputação cosmética
var opened_chests: Array[String] = []   # ids de baús one-time já abertos (GODOT-CHESTS-LOOT-RUNTIME-1); persistido; tolera saves antigos (→ [])
var story_flags: Array[String] = []     # marcos narrativos one-time (GODOT-ROOT-ARC-CLOSURE-1), ex.: "black_roots_arc_cleared"; persistido; tolera saves antigos (→ [])
# ★ LEGADO (PEDRA_LEGACY_F5) — os NOMES que o Errante carregou na Vigília. PERSISTE (salva), deduplicado, SÓ cresce.
# NÃO é poder/moeda/conquista/placar — é a MARCA da passagem: a parede de nomes da Pedra cresce com isto. Tolera
# saves antigos (→ []). O Errante não constrói nada; o mundo passa a guardar os nomes que ele se dispôs a carregar.
var carried_names: Array[String] = []   # nomes carregados na Pedra (Carregar um Nome); ordem de chegada; dedup
# FATIA A9 (NarrativeDirector) — estado do diretor narrativo (v9). NÃO duplica quests/seen_dialogues/choices: o
# SEEN de um beat também é inferido de `seen_dialogues` (§53). `narrative_seen` = beats abertos pelo jogador;
# `narrative_choices` = beat_id→choice_id (exato-uma-vez). Tolera saves antigos (→ []/{}). NÃO gateia gameplay.
var narrative_seen: Array[String] = []
var narrative_choices: Dictionary = {}
# PROGRESSÃO POR FASES (FATIA A2 — StageDirector). Persistido de forma ADITIVA (saves antigos sem estes campos
# → defaults 1/1/0/1, começam em 1-1 SEM tocar região/quest/inventário). NÃO é gate de poder (isso é A3+).
var stage_chapter: int = 1
var stage_index: int = 1
var stage_kills: int = 0
var stage_highest_global: int = 1
# MURO DE PROGRESSÃO (FATIA A3 — StageDirector). Persistido p/ o muro sobreviver ao relog (evita loops
# ruins). Schema bump 1→2 (via SaveMigration). Defaults = sem muro, modo AVANÇO.
var stage_mode: String = "advance"          # "advance" | "farm"
var stage_wall_active: bool = false
var stage_fails: int = 0                     # derrotas consecutivas na frontier atual
var stage_frontier_chapter: int = 1          # fase que não conseguiu passar (quando em muro)
var stage_frontier_stage: int = 1
var stage_farm_chapter: int = 1              # última fase dominada (onde farma durante o muro)
var stage_farm_stage: int = 1
# LOOT SUSTENTÁVEL (FATIA A3.5 — LootManager). Persistidos (schema bump 2→3).
# locked_items = ids protegidos manualmente (nunca auto-salvage). loot_overflow = buffer de segurança
# [{id, qty}] p/ itens que não couberam (protegidos/upgrade). O recurso de salvage ("Fragmentos") vive no
# dict `materials` existente (NÃO cria estrutura paralela).
var locked_items: Array[String] = []
var loot_overflow: Array = []                # [{id: String, qty: int}]
# PROGRESSÃO OFFLINE / BAÚ AFK (FATIA A5 — IdleRewards). Persistidos (schema bump 3→4).
var last_seen_at: int = 0                     # unix timestamp da última gravação de sessão ativa (0 = 1º run)
var offline_pending: Dictionary = {}         # baú AFK: {seconds,stages_advanced,...,gold,xp,items,materials}
var offline_remainder_seconds: float = 0.0   # tempo offline não convertido em ciclo (carrega p/ a próxima)
# PRESTÍGIO / MASTER LEVEL / SELOS DE CICLO (FATIA A6 — PrestigeManager). Persistidos (schema bump 4→5).
# prestige_count/master_level = VIDA INTEIRA (permanentes, nunca resetam). cycle_seals = Selos ganhos NESTE
# ciclo (resetam no Prestígio); cycle_seal_high = watermark do maior boss-global já creditado no ciclo (anti-
# duplicata de Selo — §9/§41). lifetime_highest_stage = recorde vitalício de fase (≥ maior do ciclo, §16/§17).
var prestige_count: int = 0
var master_level: int = 0
# A13 (v10) — identidade do personagem (0 poder de combate na aparência; classe define combate)
var character_class: String = "LEGACY_CLASS"
var appearance: Dictionary = {}          # CharacterAppearance dict (default = DEFAULT_LEGACY na migração/reset)
var display_name: String = "Errante"
var loadouts: Array = []                 # [BuildLoadout dict]
var active_loadout: int = 0
var cycle_seals: int = 0
var cycle_seal_high: int = 0
var lifetime_highest_stage: int = 1
# SISTEMAS DE PODER A7 (SystemPanel/Refino/Joias/Bestiário/Códice). Persistidos (schema bump 5→6). Todos são
# LIFETIME (Prestígio NÃO reseta; §22/§40/§49). ★ Efeito via STAT REAL, nunca CP artificial (§1/§28/§39).
var slot_refinement: Dictionary = {}         # {slot_id: nível 0..20} — Refino POR SLOT (§11); vazio = tudo +0
var jewel_levels: Dictionary = {}            # {jewel_type: nível 0..10} — Joias POR TIPO (ruby/sapphire/emerald)
var bestiary: Dictionary = {}                # {mob_id: {"kills": int, "claimed": int}} — Bestiário LIFETIME
var codex_discovered: Array[String] = []     # ids de item já DESCOBERTOS (recebido/equipado/claim offline)
# A22 — ACQUISITION & INTENT (persistidos, opcionais, retrocompatíveis — default {} ⇒ SEM schema bump).
var acquisition_intent: Dictionary = {}       # ReturnContext: {origin_system, origin_context_id, item_id, ...} de onde o jogador veio
var tracked_goal: Dictionary = {}             # TrackedAcquisitionGoal OWN_QUANTITY: {item_id, desired, start, origin, source, status}
var tracked_boss: Dictionary = {}             # watch de disponibilidade de boss: {boss_id, since, notified}
var codex_claimed: int = 0                   # nº de MARCOS de coleção já reivindicados (0..N)
# contador denormalizado MEMÓRIA-ONLY (recomputado no load; hot-path do CombatMath não soma ~60 mobs por hit)
var _bestiary_claimed_total: int = 0
# ITEM INSTANCE / ROLLS / VALOR COMERCIAL (FATIA A7.1). Persistidos (schema bump 6→7). ★ equipment[slot]
# CONTINUA guardando o item_id BASE (compat total com toda a UI/lógica existente); `equipped_instances` é um
# OVERLAY que carrega os ROLLS da cópia equipada (quando é instância). `item_instances` = bolsa de instâncias
# NÃO-equipadas (equipáveis com rolls); stackáveis/materiais seguem em `backpack`/`materials` (§2). Refino/pity
# são do SLOT (não viajam com o item, §36).
var equipped_instances: Dictionary = {}      # {slot: instance-dict} — overlay de rolls do equipado
var item_instances: Array = []               # [instance-dict] — bolsa de instâncias equipáveis não equipadas
var overflow_instances: Array = []           # [instance-dict] — buffer de segurança de instâncias (§29)
var locked_instances: Array[String] = []     # iids protegidos (lock por INSTÂNCIA, §28)
var refine_pity_by_slot: Dictionary = {}     # {slot: pity_bonus 0..0.20} — pity POR SLOT, persistente (§44/§45)
var cycle_encounter_high: int = 0            # watermark do maior encontro (APEX/BOSS) já premiado com SUPORTE no CICLO
                                             # (§55 anti-farm; reset no Prestígio, novo ciclo devolve first-clears)
# FATIA A7.2 (BALANCEAMENTO). refine_high_by_slot = maior nível JÁ atingido por slot → o pity zera SÓ ao bater
# novo recorde (persistente no re-climb, §19). lifetime_encounter_high = maior encontro já premiado NA VIDA
# INTEIRA → gate dos raros (Preservação/Absoluto) só em profundidade NOVA, sem farm por prestígio rápido (§25/§27).
var refine_high_by_slot: Dictionary = {}
var lifetime_encounter_high: int = 0

## true enquanto aplicamos um save carregado — bloqueia o autosave p/ não re-salvar em loop.
var _loading := false

# ── SAVE DIRTY / DEBOUNCE (FATIA A3.75) ── Escrever o JSON inteiro a cada hit/HP era I/O demais p/ sessões
# AFK longas. Agora `save_game()` só MARCA sujo; a escrita real é debounced (autosave) OU forçada
# (flush_save) em eventos importantes / no quit. Toda escrita continua passando por _write_save_now
# (mesmo writer seguro; NÃO cria writer paralelo — SaveMigration intacta).
const AUTOSAVE_INTERVAL := 5.0     # s entre gravações quando há estado sujo (3–10s; conservador)
var _dirty := false
var _autosave_t := 0.0             # (legado; o autosave agora usa _last_write_ms em tempo real)
var _last_write_ms := 0            # Time.get_ticks_msec() da última escrita (tempo REAL, imune a time_scale)
var _session_started := false      # true após o boot_reconcile do IdleRewards → aí os writes viram HEARTBEAT
                                   # (carimbam last_seen_at). Antes disso (load/migração) NÃO carimba (§7/§8).
# VELOCIDADE DE JOGO (FATIA A4): x1/x2/x3 persistida (campo opcional; default 1.0 → saves antigos ignoram,
# sem bump de schema). O GameSpeedController é a ÚNICA autoridade que escreve Engine.time_scale.
var game_speed: float = 1.0
# instrumentação runtime (debug; não persiste) — prova a redução de escritas
var save_write_count := 0
var dirty_mark_count := 0
var forced_flush_count := 0

func _ready() -> void:
	load_game()
	_dirty = false   # o load não conta como sujo

## Autosave debounced em TEMPO REAL (FATIA A4/§24): usa Time.get_ticks_msec() — NÃO o `delta` (que é
## escalado por Engine.time_scale em x2/x3). Garante ~1 write / AUTOSAVE_INTERVAL segundos REAIS mesmo em x3.
func _process(_delta: float) -> void:
	if not _dirty:
		return
	var now := Time.get_ticks_msec()
	if _last_write_ms == 0:
		_last_write_ms = now
	if float(now - _last_write_ms) / 1000.0 >= AUTOSAVE_INTERVAL:
		_write_save_now()

## Quit / fechamento da janela / destruição → garante que o estado sujo seja gravado (§14).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		if _dirty:
			_write_save_now()

func has_seen_dialogue(scene_id: String) -> bool:
	return seen_dialogues.has(scene_id)

func mark_dialogue_seen(scene_id: String, choice_id: String = "") -> void:
	if not seen_dialogues.has(scene_id):
		seen_dialogues.append(scene_id)
	if choice_id != "":
		choices[scene_id] = choice_id
	var suffix := (" | escolha: " + choice_id) if choice_id != "" else ""
	print("[GameState] cena vista: %s%s" % [scene_id, suffix])
	state_changed.emit()
	save_game()

func complete_quest(quest_id: String) -> void:
	if not completed_quests.has(quest_id):
		completed_quests.append(quest_id)
	print("[GameState] quest concluída: %s" % quest_id)
	state_changed.emit()
	save_game()
	# concede o reward narrativo da quest (uma única vez), por QUALQUER caminho que a complete.
	grant_narrative_reward_for_quest(quest_id)

## --- INVENTÁRIO / REWARD NARRATIVO ---

func has_item(item_id: String) -> bool:
	return inventory_items.has(item_id)

## Adiciona um item (id) ao inventário se ainda não tiver. Retorna true se concedeu agora.
func add_item(item_id: String) -> bool:
	if item_id == "" or inventory_items.has(item_id):
		return false
	inventory_items.append(item_id)
	var item_name := str(DataLoader.relic(item_id).get("name", item_id))
	print("[GameState] item recebido: %s (%s)" % [item_name, item_id])
	state_changed.emit()
	save_game()
	item_granted.emit(item_id, item_name)
	return true

## Concede o reward narrativo do capítulo cuja quest casa (resolve ref→relíquia). "" se nenhum.
func grant_narrative_reward_for_quest(quest_id: String) -> String:
	var reward := DataLoader.narrative_reward_for_quest(quest_id)
	if reward.is_empty():
		return ""
	var item_id := DataLoader.relic_id_for_reward(reward)
	if item_id == "":
		return ""  # ref não casou com relíquia (fallback: não concede; ver README)
	add_item(item_id)   # idempotente: emite item_granted só se for novo
	return item_id

func mark_boss_defeated(boss_name: String) -> void:
	var key := boss_name.to_lower()
	if not defeated_bosses.has(key):
		defeated_bosses.append(key)
	print("[GameState] boss derrotado: %s" % boss_name)
	state_changed.emit()
	save_game()

func has_defeated_boss(boss_name: String) -> bool:
	return defeated_bosses.has(boss_name.to_lower())

func is_quest_completed(quest_id: String) -> bool:
	return completed_quests.has(quest_id)

func set_active_quest(quest_id: String) -> void:
	active_quest_id = quest_id
	state_changed.emit()
	save_game()

func is_current_region(region_id: String) -> bool:
	return current_region_id == region_id

func set_current_region(region_id: String) -> void:
	current_region_id = region_id
	print("[GameState] região atual: %s" % region_id)
	state_changed.emit()
	save_game()

## Define a etapa do tutorial (no-op se igual). Persiste + emite p/ a HUD atualizar a dica.
func set_tutorial_step(step: String) -> void:
	if step == tutorial_step:
		return
	tutorial_step = step
	print("[GameState] tutorial: %s" % step)
	state_changed.emit()
	save_game()

func is_tutorial_done() -> bool:
	return tutorial_step == TUTORIAL_DONE

func set_level(level: int) -> void:
	hero_level = maxi(1, level)
	print("[GameState] level = %d" % hero_level)
	state_changed.emit()
	save_game()

## --- HP DO HERÓI (combate mínimo) ---

## A44-FIX (passo 2) — chave do LOG por-evento de combate (dano e level-up). Default TRUE: o JOGO NÃO MUDA.
## Só self-test desliga. Motivo: o _a44_selftest.gd emitia 41.406 prints num único frame (29.124 de dano +
## 12.282 de LEVEL UP), com flush em disco por linha. Não prova nada e é I/O contínuo durante o travamento.
var verbose_combat_log := true

func damage_hero(amount: int) -> void:
	if amount <= 0 or is_hero_defeated():
		return
	hero_hp = maxi(0, hero_hp - amount)
	if verbose_combat_log: print("[GameState] herói tomou %d de dano → HP %d/%d" % [amount, hero_hp, hero_hp_max])
	if hero_hp == 0:
		print("[GameState] o Errante caiu.")
	state_changed.emit()
	save_game()

func heal_hero(amount: int) -> void:
	hero_hp = clampi(hero_hp + amount, 0, max_hp_total())
	state_changed.emit()
	save_game()

func reset_hero_hp() -> void:
	hero_hp = max_hp_total()
	print("[GameState] HP do herói restaurado (%d/%d)." % [hero_hp, max_hp_total()])
	state_changed.emit()
	save_game()

func is_hero_defeated() -> bool:
	return hero_hp <= 0

## --- PROGRESSÃO POR FASES (FATIA A2) --- Persiste o ponteiro de fase do StageDirector. Só grava se algo
## mudou (evita thrash de save a cada kill contado o StageDirector chama isto só na TROCA de fase).
func set_stage_progress(p_chapter: int, p_stage: int, p_kills: int, p_highest_global: int) -> void:
	var ch := maxi(1, p_chapter)
	var st := maxi(1, p_stage)
	var kl := maxi(0, p_kills)
	var hg := maxi(1, p_highest_global)
	if ch == stage_chapter and st == stage_index and kl == stage_kills and hg == stage_highest_global:
		return
	stage_chapter = ch
	stage_index = st
	stage_kills = kl
	stage_highest_global = hg
	lifetime_highest_stage = maxi(lifetime_highest_stage, hg)   # A6: recorde vitalício acompana o do ciclo (§17)
	save_game(); flush_save()   # A3.75: progresso de fase = importante → grava JÁ (§13)

## MURO (A3): persiste o estado do muro/farm. Só grava se algo mudou (o StageDirector chama na transição
## de estado, não a cada kill). NÃO toca inventário/quest/level/região.
func set_wall_state(p_mode: String, p_wall_active: bool, p_fails: int, p_front_ch: int, p_front_st: int, p_farm_ch: int, p_farm_st: int) -> void:
	var mode := "farm" if p_mode == "farm" else "advance"
	if mode == stage_mode and p_wall_active == stage_wall_active and p_fails == stage_fails \
			and p_front_ch == stage_frontier_chapter and p_front_st == stage_frontier_stage \
			and p_farm_ch == stage_farm_chapter and p_farm_st == stage_farm_stage:
		return
	stage_mode = mode
	stage_wall_active = p_wall_active
	stage_fails = maxi(0, p_fails)
	stage_frontier_chapter = maxi(1, p_front_ch)
	stage_frontier_stage = clampi(p_front_st, 1, 10)
	stage_farm_chapter = maxi(1, p_farm_ch)
	stage_farm_stage = clampi(p_farm_st, 1, 10)
	save_game(); flush_save()   # A3.75: estado do muro = importante → grava JÁ (§13)

## FATIA A6 — credita 1 SELO DE CICLO se `boss_global` é uma boss-stage (múltiplo de 10) AINDA não creditada
## neste ciclo. Idempotente por WATERMARK (cycle_seal_high): farm/retry/reload/segundo boot NUNCA duplicam
## (§9/§41). Chamado ONLINE (StageDirector→host→PrestigeManager) e OFFLINE (IdleRewards). NÃO persiste aqui —
## o chamador grava (online: save_game; offline: flush da transação de boot). Retorna true se creditou agora.
func grant_cycle_seal(boss_global: int) -> bool:
	if boss_global < 10 or (boss_global % 10) != 0:
		return false          # não é boss-stage → nunca gera Selo (§8)
	if boss_global <= cycle_seal_high:
		return false          # já creditada neste ciclo → sem duplicata (§9)
	cycle_seal_high = boss_global
	cycle_seals += 1
	return true

## --- RECURSOS DE CLASSE (GODOT-CLASS-RESOURCES-MVP-1) ---
## Flechas (arco) e mana (cajado). spend_* e restore_mana (tick) só emitem state_changed (HUD) e NÃO
## salvam a cada chamada (evita thrash de save em tiro rápido); persistem no próximo save natural
## (dano/cura/loot/troca de região). restore_*_full (Vila) é deliberado → salva.
func can_spend_arrow() -> bool:
	return arrows_current > 0

func spend_arrow() -> void:
	if arrows_current <= 0:
		return
	arrows_current = maxi(0, arrows_current - 1)
	state_changed.emit()

func restore_arrows_full() -> void:
	arrows_current = arrows_max
	state_changed.emit()

## Compra de FLECHAS na loja em LOTE de 100 (GODOT-ARROWS-SHOP-AMMO-1): munição INDEPENDENTE (não é mana).
## Adiciona até ARROWS_BUNDLE flechas, limitado pelo teto do stack (500); cobra `price_per` por flecha
## EFETIVAMENTE adicionada (perto do teto, compra só o resto — sem cobrar a mais). false se cheio ou sem ouro.
func buy_arrows_bundle(price_per: int) -> bool:
	if arrows_current >= arrows_max:
		return false
	var qty := mini(ARROWS_BUNDLE, arrows_max - arrows_current)   # 100, ou o que faltar p/ o teto
	var cost := qty * maxi(0, price_per)
	if hero_gold < cost:
		return false
	hero_gold -= cost
	arrows_current += qty
	_touch()   # emite state_changed + salva
	return true
	save_game()

func can_spend_mana(cost: int) -> bool:
	return mana_current >= cost

func spend_mana(cost: int) -> void:
	if cost <= 0:
		return
	mana_current = maxi(0, mana_current - cost)
	state_changed.emit()

## Regen lento/tick de mana (conservador): clampa e NÃO salva. No-op quando já está cheio.
func restore_mana(amount: int) -> void:
	if amount <= 0 or mana_current >= mana_max:
		return
	mana_current = clampi(mana_current + amount, 0, mana_max)
	state_changed.emit()

func restore_mana_full() -> void:
	mana_current = mana_max
	state_changed.emit()

## PROGRESSÃO DE MANA MÁXIMA por NÍVEL (GODOT-MANA-MAX-SCALING-1, Modelo A): mana_max = 50 + (lvl-1)*3.
## Estável (NÃO depende de equipamento/Mág/arquétipo) → não flutua ao trocar de arma. mana_max é DERIVADO do
## nível (recomputado no level-up e no load) → migra saves antigos sem campo novo. Custos de magia inalterados.
const MANA_BASE := 50
const MANA_PER_LEVEL := 3
func mana_max_for_level(lvl: int) -> int:
	return MANA_BASE + maxi(0, lvl - 1) * MANA_PER_LEVEL

## Recomputa mana_max pelo nível atual e clampa mana_current (nunca > max). Só apresentação de teto — não
## refila (quem refila é o level-up). Idempotente.
func _recompute_mana_max() -> void:
	mana_max = mana_max_for_level(hero_level)
	mana_current = clampi(mana_current, 0, mana_max)
	save_game()

## --- PROFICIÊNCIA POR USO (GODOT-VOCATION-PROFICIENCY-MVP-1) ---
## Garante a entrada da vocação (cria {xp:0, level:1} sob demanda). Retorna o dict POR REFERÊNCIA.
func _ensure_voc(key: String) -> Dictionary:
	if not proficiency.has(key):
		proficiency[key] = {"xp": 0, "level": 1}
	return proficiency[key]

## XP necessário do nível ATUAL p/ o próximo (curva: xp_base * growth^(level-1)).
func xp_to_next(key: String) -> int:
	if not VOCATION_DEFS.has(key):
		return 999999
	var d: Dictionary = VOCATION_DEFS[key]
	var lv := int(_ensure_voc(key)["level"])
	return maxi(1, int(round(float(d["xp_base"]) * pow(float(d["growth"]), float(lv - 1)))))

func vocation_level(key: String) -> int:
	if not VOCATION_DEFS.has(key):
		return 1
	return int(_ensure_voc(key)["level"])

## Bônus pequeno e CAPADO do arquétipo ATIVO (afinidade): só conta se a arma equipada bate com `stat`.
## floor(level/every)*per, teto `cap`. Aditivo (nunca multiplicador) → dano não explode.
func vocation_bonus(stat: String) -> int:
	var key := current_combat_archetype()
	if not VOCATION_DEFS.has(key):
		return 0
	var d: Dictionary = VOCATION_DEFS[key]
	if str(d["bonus_stat"]) != stat:
		return 0
	var lv := int(_ensure_voc(key)["level"])
	return mini(int(d["cap"]), int(lv / int(d["every"])) * int(d["per"]))

## Ganha proficiência (chamado por _juice_hit = SÓ em acerto real). amount>0. Level-up emite
## vocation_leveled + salva (marco); XP incremental por hit NÃO salva (anti-thrash; persiste no
## próximo save natural). Sem entrada inválida (key precisa estar em VOCATION_DEFS).
func gain_proficiency(key: String, amount: int) -> void:
	if not VOCATION_DEFS.has(key) or amount <= 0:
		return
	var e := _ensure_voc(key)
	e["xp"] = int(e["xp"]) + amount
	var leveled := false
	while int(e["xp"]) >= xp_to_next(key):
		e["xp"] = int(e["xp"]) - xp_to_next(key)
		e["level"] = int(e["level"]) + 1
		leveled = true
		vocation_leveled.emit(key, int(e["level"]))
	if leveled:
		state_changed.emit()
		save_game()

## --- MAESTRIA EXCLUSIVA (GODOT-ORACLE-PRESAGE-MASTERY-MVP-1) — espelha a proficiência, mas é camada
## separada: só sobe por efeito real do kit e só beneficia aquele kit (mastery_bonus). ---
func _ensure_mastery(key: String) -> Dictionary:
	if not class_mastery.has(key):
		class_mastery[key] = {"xp": 0, "level": 1}
	return class_mastery[key]

func xp_to_next_mastery(key: String) -> int:
	if not CLASS_MASTERY_DEFS.has(key):
		return 999999
	var d: Dictionary = CLASS_MASTERY_DEFS[key]
	var lv := int(_ensure_mastery(key)["level"])
	return maxi(1, int(round(float(d["xp_base"]) * pow(float(d["growth"]), float(lv - 1)))))

func mastery_level(key: String) -> int:
	if not CLASS_MASTERY_DEFS.has(key):
		return 1
	return int(_ensure_mastery(key)["level"])

## Bônus PEQUENO/CAPADO da maestria (floor(level/every)*per, teto cap). NÃO depende de stat — o efeito é
## aplicado pelo kit da classe (ver Main). Aditivo, nunca multiplicador.
func mastery_bonus(key: String) -> int:
	if not CLASS_MASTERY_DEFS.has(key):
		return 0
	var d: Dictionary = CLASS_MASTERY_DEFS[key]
	var lv := int(_ensure_mastery(key)["level"])
	return mini(int(d["cap"]), int(lv / int(d["every"])) * int(d["per"]))

## Ganha maestria (chamado SÓ por efeito real do kit). Level-up emite mastery_leveled + salva.
func gain_mastery(key: String, amount: int) -> void:
	if not CLASS_MASTERY_DEFS.has(key) or amount <= 0:
		return
	var e := _ensure_mastery(key)
	e["xp"] = int(e["xp"]) + amount
	var leveled := false
	while int(e["xp"]) >= xp_to_next_mastery(key):
		e["xp"] = int(e["xp"]) - xp_to_next_mastery(key)
		e["level"] = int(e["level"]) + 1
		leveled = true
		mastery_leveled.emit(key, int(e["level"]))
	if leveled:
		state_changed.emit()
		save_game()

## --- PÁGINA DE GUARDA / ESCUDO (GODOT-ORACLE-SUPPORT-KIT-1) ---
## Escudo TRANSIENTE (buff de combate, NÃO persiste no save → saves intactos). Absorve dano antes do HP.
var shield_amount: int = 0
var shield_t: float = 0.0

## Ativa/renova o escudo (NÃO stacka além de `amount` — recast só renova valor+duração).
func activate_shield(amount: int, dur: float) -> void:
	shield_amount = maxi(0, amount)
	shield_t = maxf(0.0, dur)
	state_changed.emit()

func shield_active() -> bool:
	return shield_amount > 0 and shield_t > 0.0

## Absorve até `raw`; reduz o escudo; retorna quanto foi absorvido (0 se sem escudo).
func shield_absorb(raw: int) -> int:
	if not shield_active() or raw <= 0:
		return 0
	var ab := mini(shield_amount, raw)
	shield_amount -= ab
	state_changed.emit()
	return ab

## Decai a duração (chamado por Main._process). Limpa ao expirar/zerar.
func tick_shield(delta: float) -> void:
	if shield_t <= 0.0:
		return
	shield_t -= delta
	if shield_t <= 0.0 or shield_amount <= 0:
		shield_t = 0.0
		shield_amount = 0
		state_changed.emit()

## --- XP / LEVEL / GOLD / MATERIAIS (loop de hunt — GODOT-REGION-MOBS-1) ---

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	hero_xp += amount
	while hero_xp >= hero_xp_to_next:
		hero_xp -= hero_xp_to_next
		hero_level += 1
		hero_xp_to_next = 80 + hero_level * 40   # curva simples
		hero_hp_max += 10                        # cada nível: +10 HP máx (base) e cura cheia
		hero_hp = max_hp_total()
		# MANA por nível (GODOT-MANA-MAX-SCALING-1): recomputa o teto e REFILA cheio no nível (sensação RPG)
		_recompute_mana_max()
		mana_current = mana_max
		if verbose_combat_log: print("[GameState] LEVEL UP → %d (HP máx %d)" % [hero_level, max_hp_total()])
		leveled_up.emit(hero_level)
	state_changed.emit()
	save_game()

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	hero_gold += amount
	state_changed.emit()
	save_game()

func add_material(mat_name: String, qty: int = 1) -> void:
	if mat_name == "" or qty <= 0:
		return
	materials[mat_name] = int(materials.get(mat_name, 0)) + qty
	print("[GameState] material: %s x%d (total %d)" % [mat_name, qty, materials[mat_name]])
	state_changed.emit()
	save_game()

func materials_summary() -> String:
	if materials.is_empty():
		return "—"
	var parts := PackedStringArray()
	for k in materials:
		parts.append("%s x%d" % [k, materials[k]])
	return ", ".join(parts)

## --- MOCHILA / EQUIPAMENTOS (GODOT-EQUIPMENT-INVENTORY-FOUNDATION-1) ---

## FATIA A5 — sanitiza um baú offline vindo do save (nunca negativo/nulo/lixo; §53). Descarta ids inválidos.
func _sanitize_pending(p: Dictionary) -> Dictionary:
	var items: Dictionary = {}
	var pit: Variant = p.get("items", {})
	if pit is Dictionary:
		for k in pit:
			if ItemDB.exists(str(k)):
				var q := int(pit[k])
				if q > 0: items[str(k)] = q
	var mats: Dictionary = {}
	var pmt: Variant = p.get("materials", {})
	if pmt is Dictionary:
		for k in pmt:
			var q2 := int(pmt[k])
			if str(k) != "" and q2 > 0: mats[str(k)] = q2
	var g := maxi(0, int(p.get("gold", 0)))
	var x := maxi(0, int(p.get("xp", 0)))
	if g == 0 and x == 0 and items.is_empty() and mats.is_empty():
		return {}   # baú vazio → sem pending
	return {
		"seconds": maxi(0, int(p.get("seconds", 0))),
		"stages_advanced": maxi(0, int(p.get("stages_advanced", 0))),
		"start_global": maxi(1, int(p.get("start_global", 1))),
		"end_global": maxi(1, int(p.get("end_global", 1))),
		"farm_global": maxi(1, int(p.get("farm_global", 1))),
		"farm_cycles": maxi(0, int(p.get("farm_cycles", 0))),
		"gold": g, "xp": x, "items": items, "materials": mats,
	}

func _touch() -> void:
	state_changed.emit()
	save_game()

## Total de unidades de um item na mochila = SOMA de TODAS as entradas com esse id (GODOT-BACKPACK-
## COUNT-DUPLICATES-FIX-1). Antes retornava só a 1ª entrada → subcontava não-stackable DUPLICADO (cada
## um vira uma entrada própria). Entrada sem `qty` explícito conta como 1. Ausente → 0.
func backpack_count(id: String) -> int:
	var total := 0
	for e in backpack:
		if str(e.get("id", "")) == id:
			total += int(e.get("qty", 1))
	return total

## Adiciona à mochila (empilha se stackable). Ignora ids desconhecidos.
func backpack_add(id: String, qty: int = 1) -> void:
	if not ItemDB.exists(id) or qty <= 0:
		return
	if ItemDB.is_stackable(id):
		for e in backpack:
			if str(e.get("id", "")) == id:
				e["qty"] = int(e["qty"]) + qty
				_touch()
				return
	backpack.append({"id": id, "qty": qty})
	_touch()

## ── FATIA A3.5 — mutadores SILENCIOSOS (NÃO salvam a cada drop; §27). O LootManager usa estes no caminho
## quente do loot; a persistência acontece no ciclo natural (troca de região/fase) via persist_loot_state().
func backpack_add_silent(id: String, qty: int = 1) -> void:
	if not ItemDB.exists(id) or qty <= 0:
		return
	if ItemDB.is_stackable(id):
		for e in backpack:
			if str(e.get("id", "")) == id:
				e["qty"] = int(e["qty"]) + qty
				state_changed.emit()
				return
	backpack.append({"id": id, "qty": qty})
	state_changed.emit()

## Remove UMA unidade (qty 1) de um id da mochila (silencioso). Retorna true se removeu.
func backpack_remove_one_silent(id: String) -> bool:
	for i in range(backpack.size()):
		if str(backpack[i].get("id", "")) == id:
			var q := int(backpack[i].get("qty", 1)) - 1
			if q <= 0:
				backpack.remove_at(i)
			else:
				backpack[i]["qty"] = q
			state_changed.emit()
			return true
	return false

func add_material_silent(mat_name: String, qty: int = 1) -> void:
	if mat_name == "" or qty <= 0:
		return
	materials[mat_name] = int(materials.get(mat_name, 0)) + qty
	state_changed.emit()

## Nº de SLOTS ocupados na mochila = nº de ENTRADAS (stack = 1 slot). Materiais NÃO ocupam slot.
func backpack_slots_used() -> int:
	return backpack.size()

## O item está equipado em algum slot?
func is_item_equipped(id: String) -> bool:
	for slot in equipment:
		if str(equipment[slot]) == id:
			return true
	return false

## ── LOCK / FAVORITO (A3.5) — proteção manual persistente contra auto-salvage ──
func is_item_locked(id: String) -> bool:
	return locked_items.has(id)

func set_item_locked(id: String, on: bool) -> void:
	if on and not locked_items.has(id):
		locked_items.append(id)
	elif not on:
		locked_items.erase(id)
	state_changed.emit()

## ── OVERFLOW (A3.5) — buffer de segurança ──
func overflow_count() -> int:
	return loot_overflow.size()

func overflow_push(id: String, qty: int = 1) -> void:
	for e in loot_overflow:
		if str(e.get("id", "")) == id:
			e["qty"] = int(e.get("qty", 1)) + qty
			state_changed.emit()
			return
	loot_overflow.append({"id": id, "qty": qty})
	state_changed.emit()

## Remove e devolve UM {id,qty} do overflow (FIFO), ou {} se vazio.
func overflow_pop() -> Dictionary:
	if loot_overflow.is_empty():
		return {}
	var e: Dictionary = loot_overflow.pop_front()
	state_changed.emit()
	return e

## Persiste o estado de loot no ciclo NATURAL (não por drop). Chamado em pontos coarse (região/fase).
func persist_loot_state() -> void:
	save_game()

## Remove qty da mochila (some a stack ao zerar). Retorna true se removeu.
func backpack_remove(id: String, qty: int = 1) -> bool:
	for i in range(backpack.size()):
		if str(backpack[i].get("id", "")) == id:
			backpack[i]["qty"] = int(backpack[i]["qty"]) - qty
			if int(backpack[i]["qty"]) <= 0:
				backpack.remove_at(i)
			_touch()
			return true
	return false

## Equipa um item da mochila no seu slot. Desequipa o que estiver lá (volta p/ a mochila).
## Regra das 2 mãos: arma two_handed limpa o offhand; offhand é bloqueado se a arma for two_handed.
func equip(id: String) -> bool:
	if not ItemDB.is_equippable(id) or backpack_count(id) <= 0:
		return false
	var slot := ItemDB.slot_of(id)
	if slot == "offhand":
		var w := str(equipment.get("weapon", ""))
		if w != "" and ItemDB.is_two_handed(w):
			return false   # arma de 2 mãos ocupa o offhand
	if equipment.has(slot):
		unequip(slot)   # devolve o atual à mochila
	if slot == "weapon" and ItemDB.is_two_handed(id) and equipment.has("offhand"):
		unequip("offhand")
	backpack_remove(id, 1)
	equipment[slot] = id
	hero_hp = mini(hero_hp, max_hp_total())   # reclamp se o max mudou
	_touch()
	flush_save()   # A3.75: equipamento = mudança estrutural importante → grava JÁ (§13)
	return true

## Desequipa o slot (item volta p/ a mochila). Retorna true se havia algo.
func unequip(slot: String) -> bool:
	if not equipment.has(slot):
		return false
	var id := str(equipment[slot])
	equipment.erase(slot)
	backpack_add(id, 1)
	hero_hp = mini(hero_hp, max_hp_total())
	_touch()
	flush_save()   # A3.75: equipamento = mudança estrutural importante → grava JÁ (§13)
	return true

## Usa um consumível da mochila (ex.: poção cura). Retorna true se usou.
func use_consumable(id: String) -> bool:
	var it := ItemDB.get_item(id)
	if str(it.get("cat", "")) != "consumable" or backpack_count(id) <= 0:
		return false
	var heal := int(it.get("heal", 0))
	if heal > 0:
		hero_hp = clampi(hero_hp + heal, 0, max_hp_total())
	# POÇÃO DE MANA (GODOT-MANA-POTION-SHOP-1): restaura mana, capado em mana_max (mesmo padrão do heal).
	var mana := int(it.get("mana", 0))
	if mana > 0:
		mana_current = clampi(mana_current + mana, 0, mana_max)
	backpack_remove(id, 1)
	return true   # backpack_remove já fez _touch()

## --- ARQUÉTIPO DE COMBATE PELA ARMA (GODOT-WEAPON-ARCHETYPE-1) ---

## Tipo da arma equipada: "sword"/"bow"/"staff"/"spear" (do ItemDB.weapon_kind) ou "unarmed".
func current_weapon_type() -> String:
	var w := str(equipment.get("weapon", ""))
	if w == "":
		return "unarmed"
	return str(ItemDB.get_item(w).get("weapon_kind", "sword"))

## Arquétipo de combate derivado da arma: melee (curto), reach (lança), ranged (arco),
## magic (cajado). Unarmed cai em melee. É a chave que o Main usa p/ escolher o ataque.
func current_combat_archetype() -> String:
	match current_weapon_type():
		"bow": return "ranged"
		"staff": return "magic"
		"spear": return "reach"
		"book": return "support"   # Oráculo (GODOT-ORACLE-WEAPON-BOOK-1)
		"axe": return "melee"      # Guerreiro (GODOT-WARRIOR-WEAPONS-AXE-HAMMER-1)
		"hammer": return "melee"   # Guerreiro (idem) — NÃO são classe nova, só armas melee
		_: return "melee"   # sword / unarmed / desconhecido → corpo-a-corpo seguro

## Soma de um stat sobre TODOS os itens equipados. FATIA A7: aplica o REFINO POR SLOT (§18/§19/§20) — o
## multiplicador do slot escala SÓ o stat do item DAQUELE slot (nunca base do personagem, Master ou outro slot).
## Chokepoint ÚNICO: PowerBudget/CombatMath/max_hp leem daqui ⇒ refino entra no CP naturalmente, sem CP artificial.
func equip_sum(key: String) -> int:
	var s := 0.0
	for slot in equipment:
		var lvl := int(slot_refinement.get(str(slot), 0))
		if equipped_instances.has(slot):
			# FATIA A7.1: a cópia equipada tem ROLLS próprios → stat efetivo da INSTÂNCIA (core refinado + afixos).
			s += ItemInstance.effective_stat(equipped_instances[slot], key, lvl)
		else:
			# LEGADO/simples: item-base do ItemDB × Refino do slot (comportamento A7 preservado).
			var raw := ItemDB.stat(str(equipment[slot]), key)
			if raw != 0:
				s += float(raw) * RefineMath.mult(lvl)
	return int(round(s))

## FATIA A6 — Master multiplier PERMANENTE (1.08^master_level). Mantido p/ compat (PlayerPowerModifiers o usa).
func master_multiplier() -> float:
	return PrestigeMath.master_multiplier(master_level)

## HP máx REAL: (base do herói + equip[+refino] + JOIAS) × mult GLOBAL (Master × Coleção). Chokepoint DEFENSIVO
## único (combate/cura/HUD/CP). FATIA A7: joias somam flat (§27); PlayerPowerModifiers agrega Master+Bestiário+
## Códice em UM ponto (§52) ⇒ sem double-count.
func max_hp_total() -> int:
	var flat := hero_hp_max + equip_sum("max_hp") + JewelMath.flat_for_stat("max_hp", jewel_levels)
	return int(round(float(flat) * PlayerPowerModifiers.hp_mult()))
func attack_bonus() -> int: return equip_sum("attack") + JewelMath.flat_for_stat("attack", jewel_levels)
func defense_bonus() -> int: return equip_sum("defense") + JewelMath.flat_for_stat("defense", jewel_levels)
func speed_bonus() -> int: return equip_sum("speed")
func magic_bonus() -> int: return equip_sum("magic")

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# FATIA A7 — SISTEMAS DE PODER: estado + ações (Refino/Joias/Bestiário/Códice). Recurso comum = FRAGMENTOS
# (dict `materials`, desde A3.5). Ações gastam Fragmentos e MELHORAM STAT REAL ⇒ CP sobe via PowerBudget.
# ══════════════════════════════════════════════════════════════════════════════════════════════════
const FRAGMENT_KEY := "Fragmentos"
func fragments() -> int:
	return int(materials.get(FRAGMENT_KEY, 0))

## Gasta n Fragmentos se houver. true se gastou. NÃO cria recurso; nunca deixa negativo.
func spend_fragments(n: int) -> bool:
	if n <= 0:
		return true
	if fragments() < n:
		return false
	var left := fragments() - n
	if left <= 0:
		materials.erase(FRAGMENT_KEY)
	else:
		materials[FRAGMENT_KEY] = left
	return true

# ── REFINO (por slot) ──
func refine_level(slot: String) -> int:
	return clampi(int(slot_refinement.get(slot, 0)), 0, RefineMath.REFINE_MAX_LEVEL)

func refine_cost_next(slot: String) -> int:
	return RefineMath.cost(refine_level(slot))

## Pode refinar AGORA? (slot equipável real, abaixo do cap, Fragmentos suficientes). §16/§17.
func refine_can(slot: String) -> bool:
	if not ItemDB.SLOT_ORDER.has(slot):
		return false
	if RefineMath.is_max(refine_level(slot)):
		return false
	return fragments() >= refine_cost_next(slot)

## Refina +1 nível (100% garantido, §17). Gasta Fragmentos UMA vez. true se aplicou. Persiste (importante).
func refine_do(slot: String) -> bool:
	if not refine_can(slot):
		return false
	if not spend_fragments(refine_cost_next(slot)):
		return false
	slot_refinement[slot] = refine_level(slot) + 1
	save_game(); flush_save()
	return true

# ── JOIAS (por tipo) ──
func jewel_level(jewel_type: String) -> int:
	return clampi(int(jewel_levels.get(jewel_type, 0)), 0, JewelMath.JEWEL_MAX_LEVEL)

func jewel_cost_next(jewel_type: String) -> int:
	return JewelMath.cost(jewel_level(jewel_type))

func jewel_can(jewel_type: String) -> bool:
	if not JewelMath.exists(jewel_type):
		return false
	if JewelMath.is_max(jewel_level(jewel_type)):
		return false
	return fragments() >= jewel_cost_next(jewel_type)

func jewel_do(jewel_type: String) -> bool:
	if not jewel_can(jewel_type):
		return false
	if not spend_fragments(jewel_cost_next(jewel_type)):
		return false
	jewel_levels[jewel_type] = jewel_level(jewel_type) + 1
	save_game(); flush_save()
	return true

# ── BESTIÁRIO (kills lifetime por mob; tiers reivindicáveis) ──
## Entrada normalizada {kills, claimed} do mob (cria vazia se ausente, sem persistir).
func bestiary_entry(mob_id: String) -> Dictionary:
	var e: Variant = bestiary.get(mob_id, null)
	if e is Dictionary:
		return {"kills": maxi(0, int(e.get("kills", 0))), "claimed": maxi(0, int(e.get("claimed", 0)))}
	return {"kills": 0, "claimed": 0}

## Registra 1 kill de um mob real (ignora ids de teste/vazios). Debounced (§ TESTE 1000 KILLS: sem write storm).
func bestiary_add_kill(mob_id: String) -> void:
	if mob_id == "" or mob_id in ["mage_of_heaven", "musgo_voraz"]:
		return
	var e := bestiary_entry(mob_id)
	e["kills"] = int(e["kills"]) + 1
	bestiary[mob_id] = e
	save_game()

## BATCH (§41) — soma kills agregadas (offline) sem loop por kill; UM save. dict = {mob_id: count}.
func bestiary_add_kills_batch(kills_by_mob: Dictionary) -> void:
	var touched := false
	for mid in kills_by_mob:
		var m := str(mid)
		if m == "" or m in ["mage_of_heaven", "musgo_voraz"]:
			continue
		var n := int(kills_by_mob[mid])
		if n <= 0:
			continue
		var e := bestiary_entry(m)
		e["kills"] = int(e["kills"]) + n
		bestiary[m] = e
		touched = true
	if touched:
		save_game()

## Grava o nº de tiers reivindicados de um mob (usado pelo BestiaryManager.claim) e recomputa o total.
func bestiary_set_claimed(mob_id: String, claimed: int) -> void:
	var e := bestiary_entry(mob_id)
	e["claimed"] = maxi(0, claimed)
	bestiary[mob_id] = e
	_recompute_bestiary_total()
	save_game(); flush_save()

## Total de tiers reivindicados (MEMÓRIA — hot-path). Lido pelo PlayerPowerModifiers a cada golpe.
func bestiary_claimed_tiers_total() -> int:
	return _bestiary_claimed_total

func _recompute_bestiary_total() -> void:
	var t := 0
	for m in bestiary:
		if bestiary[m] is Dictionary:
			t += maxi(0, int((bestiary[m] as Dictionary).get("claimed", 0)))
	_bestiary_claimed_total = t

# ── CÓDICE DE ITENS (descoberta por id; marcos reivindicáveis) ──
## Marca um item real do catálogo como descoberto. Retorna true se é NOVO (a coleção cresceu). §43/§44.
func codex_discover(id: String) -> bool:
	if id == "" or not ItemDB.exists(id) or not ItemDB.is_equippable(id):
		return false   # coleção principal = catálogo equipável confiável (§45); materiais/genéricos fora
	if codex_discovered.has(id):
		return false
	codex_discovered.append(id)
	save_game()
	return true

func codex_unique_count() -> int:
	return codex_discovered.size()

func codex_claimed_count() -> int:
	return codex_claimed

## Grava o nº de marcos reivindicados (usado pelo ItemCodex.claim). Persiste.
func codex_set_claimed(n: int) -> void:
	codex_claimed = maxi(0, n)
	save_game(); flush_save()

## FATIA A7.1 — dá os DROPS de suporte de refino na PRIMEIRA conclusão em avanço de um encontro APEX(5)/BOSS(10)
## do ciclo (anti-farm §55: watermark; farm/reload/2º-boot não repetem). `seed_val` >=0 = determinístico (offline);
## <0 = RNG online. Retorna os item_ids concedidos (stackáveis, na mochila). NÃO persiste aqui (o chamador grava).
func grant_encounter_reward(global_stage: int, seed_val: int = -1) -> Array:
	var s := ((global_stage - 1) % 10) + 1
	var is_boss := (s == 10)
	var is_apex := (s == 5)
	if not (is_boss or is_apex):
		return []
	var drops: Array = []
	# COMUNS (Catalisador/Superior): first-clear do CICLO — voltam a cada Prestígio (§55).
	if global_stage > cycle_encounter_high:
		cycle_encounter_high = global_stage
		drops.append_array(SupportDrops.roll_cycle(is_boss, seed_val))
	# RAROS (Preservação/Absoluto): first-clear VITALÍCIO — só em profundidade nova (§25/§27 anti-farm).
	if global_stage > lifetime_encounter_high:
		lifetime_encounter_high = global_stage
		drops.append_array(SupportDrops.roll_lifetime(is_boss, seed_val if seed_val < 0 else seed_val ^ 0x2A17))
	for item_id in drops:
		backpack_add_silent(str(item_id), 1)
	return drops

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# FATIA A7.1 — ITEM INSTANCE (bolsa/equipado/overflow/lock) + REFINO ENDGAME (chance/pity/downgrade/suportes).
# ══════════════════════════════════════════════════════════════════════════════════════════════════
## FATIA A7.2 — MATERIALIZA o item LEGADO equipado no slot como ItemInstance neutra (LAZY, §30/§31): só quando
## precisa de identidade individual (trade/lock/comparação). IDEMPOTENTE (§32): se já é instância, devolve-a;
## senão cria uma neutra com iid ESTÁVEL e a instala no overlay SEM mudar stats (rolls 1.0). Retorna a instância.
func materialize_legacy_slot(slot: String) -> Dictionary:
	if equipped_instances.has(slot):
		return equipped_instances[slot]      # já materializado → mesma identidade (§32)
	if not equipment.has(slot):
		return {}
	var item_id := str(equipment[slot])
	if not ItemDB.exists(item_id):
		return {}
	var iid := "legacy#%s#%s" % [slot, item_id]   # ESTÁVEL: mesmo slot+item → mesmo iid (idempotente)
	var inst := ItemInstance.make_legacy(item_id, iid)
	equipped_instances[slot] = inst
	save_game()
	return inst

## Instância equipada no slot (overlay), ou {} se o slot usa item-base legado / está vazio.
func equipped_instance(slot: String) -> Dictionary:
	var e: Variant = equipped_instances.get(slot, null)
	return e if e is Dictionary else {}

## Adiciona uma instância à BOLSA (não-equipada). Silencioso (não salva por drop; o LootManager controla).
func instance_add(inst: Dictionary) -> void:
	if inst is Dictionary and ItemDB.exists(ItemInstance.base_item_id(inst)):
		item_instances.append(inst)

## Remove e devolve a instância `iid` da bolsa ({} se ausente).
func instance_remove(iid: String) -> Dictionary:
	for i in range(item_instances.size()):
		if str(item_instances[i].get("iid", "")) == iid:
			var e: Dictionary = item_instances[i]
			item_instances.remove_at(i)
			return e
	return {}

func instance_find(iid: String) -> Dictionary:
	for e in item_instances:
		if str(e.get("iid", "")) == iid:
			return e
	return {}

func is_instance_locked(iid: String) -> bool:
	return locked_instances.has(iid)

func set_instance_locked(iid: String, on: bool) -> void:
	if on and not locked_instances.has(iid):
		locked_instances.append(iid)
	elif not on:
		locked_instances.erase(iid)
	state_changed.emit()

## Equipa uma INSTÂNCIA (da bolsa) no seu slot. O item atual (instância OU base) volta p/ a bolsa/mochila.
## equipment[slot] recebe o item_id BASE (compat com toda a UI); equipped_instances[slot] recebe os rolls.
func equip_instance(inst: Dictionary) -> bool:
	var item_id := ItemInstance.base_item_id(inst)
	if not ItemDB.is_equippable(item_id):
		return false
	var slot := ItemDB.slot_of(item_id)
	if slot == "offhand":
		var w := str(equipment.get("weapon", ""))
		if w != "" and ItemDB.is_two_handed(w):
			return false
	# devolve o que estava equipado no slot (instância → bolsa; base → mochila)
	_unequip_to_storage(slot)
	if slot == "weapon" and ItemDB.is_two_handed(item_id):
		_unequip_to_storage("offhand")
	# tira a instância da bolsa e equipa
	instance_remove(str(inst.get("iid", "")))
	equipment[slot] = item_id
	equipped_instances[slot] = inst
	hero_hp = mini(hero_hp, max_hp_total())
	_touch(); flush_save()
	return true

## Desequipa o slot p/ o armazenamento correto: instância → bolsa; item-base → mochila. Não persiste (helper).
func _unequip_to_storage(slot: String) -> void:
	if not equipment.has(slot):
		return
	if equipped_instances.has(slot):
		item_instances.append(equipped_instances[slot])
		equipped_instances.erase(slot)
		equipment.erase(slot)
	else:
		var id := str(equipment[slot])
		equipment.erase(slot)
		backpack_add(id, 1)

# ── REFINO ENDGAME (§39-51) ──
func refine_pity(slot: String) -> float:
	return clampf(float(refine_pity_by_slot.get(slot, 0.0)), 0.0, RefineMath.PITY_MAX_BONUS)

## Info TRANSPARENTE da próxima tentativa (§57/§58): base/pity/catalisador/final + custo + consequência da falha.
## `catalyst_id` "" = nenhum; `use_absolute` força 100%.
func refine_attempt_info(slot: String, catalyst_id: String = "", use_absolute: bool = false) -> Dictionary:
	var lvl := refine_level(slot)
	var cat_pp := 0.0
	if catalyst_id != "" and str(ItemDB.get_item(catalyst_id).get("refine_role", "")) == "catalyst":
		cat_pp = float(ItemDB.get_item(catalyst_id).get("catalyst_pp", 0.0))
	var abs_ok := use_absolute and backpack_count("seal_absolute") > 0
	var pity := refine_pity(slot)
	var final := 1.0 if abs_ok else RefineMath.final_chance(lvl, pity, cat_pp)
	return {
		"level": lvl, "at_max": RefineMath.is_max(lvl), "cost": refine_cost_next(slot),
		"base_chance": RefineMath.base_chance(lvl), "pity": pity, "catalyst_pp": cat_pp,
		"absolute": abs_ok, "final_chance": final, "fails_downgrade": RefineMath.fails_downgrade(lvl),
	}

## Executa UMA tentativa de refino (§40-51). Só consome quando EXECUTA (§48). Retorna resultado detalhado.
## `roll01` >= 0 injeta o sorteio (determinismo em teste); < 0 usa randf() (online). Selo Absoluto → 100%.
func refine_attempt(slot: String, catalyst_id: String = "", use_preserve: bool = false, use_absolute: bool = false, roll01: float = -1.0) -> Dictionary:
	if not ItemDB.SLOT_ORDER.has(slot):
		return {"ok": false, "reason": "slot inválido"}
	var lvl := refine_level(slot)
	if RefineMath.is_max(lvl):
		return {"ok": false, "reason": "no teto (+%d)" % RefineMath.REFINE_MAX_LEVEL}
	var cost := refine_cost_next(slot)
	if fragments() < cost:
		return {"ok": false, "reason": "Fragmentos insuficientes"}
	# suportes disponíveis?
	var cat_pp := 0.0
	var has_cat := catalyst_id != "" and backpack_count(catalyst_id) > 0 and str(ItemDB.get_item(catalyst_id).get("refine_role", "")) == "catalyst"
	if has_cat:
		cat_pp = float(ItemDB.get_item(catalyst_id).get("catalyst_pp", 0.0))
	var abs_ok := use_absolute and backpack_count("seal_absolute") > 0
	var preserve_ok := use_preserve and backpack_count("seal_preservation") > 0
	var pity := refine_pity(slot)
	var chance := 1.0 if abs_ok else RefineMath.final_chance(lvl, pity, cat_pp)
	# EXECUTA: gasta Fragmentos SEMPRE (§41/§50); consome catalisador e Selo Absoluto (§47/§49).
	spend_fragments(cost)
	if has_cat:
		backpack_remove_one_silent(catalyst_id)
	if abs_ok:
		backpack_remove_one_silent("seal_absolute")
	var draw := roll01 if roll01 >= 0.0 else randf()
	var success := draw < chance
	var downgraded := false
	var preserved := false
	var prev_high := int(refine_high_by_slot.get(slot, lvl))
	if success:
		slot_refinement[slot] = lvl + 1
		# FATIA A7.2 (§19): pity PERSISTENTE — zera SÓ ao atingir NOVO RECORDE do slot; re-climb mantém o pity.
		if lvl + 1 > prev_high:
			refine_high_by_slot[slot] = lvl + 1
			refine_pity_by_slot[slot] = 0.0        # novo recorde → pity fresco (REND-T11: 8→9 é recorde ⇒ zera)
	else:
		refine_pity_by_slot[slot] = RefineMath.pity_after_fail(pity)   # falha aumenta o pity (§44/§SUPPORT-T06)
		if RefineMath.fails_downgrade(lvl):
			if preserve_ok:
				backpack_remove_one_silent("seal_preservation")   # protege → consome o Selo (§50)
				preserved = true
			else:
				# -1 nível, mas NUNCA abaixo do piso de segurança (§20/§43): +18→20 cai no máx até +15.
				slot_refinement[slot] = maxi(RefineMath.downgrade_floor(lvl), lvl - 1)
				downgraded = slot_refinement[slot] < lvl
	save_game(); flush_save()
	return {
		"ok": true, "success": success, "from": lvl, "to": refine_level(slot),
		"downgraded": downgraded, "preserved": preserved, "chance": chance,
		"pity_before": pity, "pity_after": refine_pity(slot),
	}

## --- MITIGAÇÃO DE DANO (GODOT-DEFENSE-SCALING-PASS-1) ---
## Defesa com RETORNOS DECRESCENTES (substitui a subtração flat, que zerava mobs com gear reforçado).
## taken = ceil(raw * 100 / (100 + def*K)). Cada ponto de defesa vale menos que o anterior →
## defesa ajuda MUITO, mas NUNCA torna o golpe irrelevante (mín 1). K calibrado p/ o gear atual:
##   def 10 (gear simples) ≈ -33% | def 19 (reforçado+escudo) ≈ -49% | 2-mãos sem escudo (def 11) ≈ -36%.
const DEFENSE_K := 5.0

## MAESTRIA DE GUARDA (GODOT-WARRIOR-GUARD-MASTERY-MVP-1): true se há OFFHAND DEFENSIVO equipado (escudo
## = item de offhand com defense>0). É a regra exata p/ "Guerreiro com escudo".
func has_defensive_offhand() -> bool:
	var off := str(equipment.get("offhand", ""))
	return off != "" and ItemDB.stat(off, "defense") > 0

## Bônus de defesa EXCLUSIVO da Maestria de Guarda — só conta no cálculo DEFENSIVO e SÓ p/ melee+escudo
## (Guerreiro). 0 p/ qualquer outra classe/sem escudo → não beneficia Mago/Arqueiro/Lanceiro/Oráculo.
## Aditivo e CAPADO (mastery_bonus 0..cap) * 2 → no máx +6 de defesa efetiva (não cria tank imortal).
func guard_defense_bonus() -> int:
	if current_combat_archetype() != "melee" or not has_defensive_offhand():
		return 0
	return mastery_bonus("guard") * 2

## MAESTRIA ARCANA (GODOT-MAGE-ARCANE-MASTERY-MVP-1): bônus de dano EXCLUSIVO do Mago (cajado). Só conta
## com arquétipo "magic" → 0 p/ Oráculo(book)/Arqueiro/Lanceiro/Guerreiro → NÃO toca cura/escudo/debuff do
## Oráculo nem o dano do livro. Aditivo e CAPADO (mastery_bonus 0..cap)*2 → no máx +6 de dano de spell.
func arcane_damage_bonus() -> int:
	if current_combat_archetype() != "magic":
		return 0
	return mastery_bonus("arcane") * 2

## MAESTRIA DE PRECISÃO (GODOT-ARCHER-PRECISION-MASTERY-MVP-1): bônus de dano EXCLUSIVO do Arqueiro (arco).
## Só conta com arquétipo "ranged" → 0 p/ cajado/livro/lança/espada/machado/martelo → NÃO toca dano do
## Mago/Oráculo nem melee. Aditivo e CAPADO (mastery_bonus 0..cap)*2 → no máx +6 de dano de flecha.
func precision_damage_bonus() -> int:
	if current_combat_archetype() != "ranged":
		return 0
	return mastery_bonus("precision") * 2

## MAESTRIA DE POSTURA (GODOT-SPEARMAN-STANCE-MASTERY-MVP-1): bônus de dano EXCLUSIVO do Lanceiro (lança).
## Só conta com arquétipo "reach" → 0 p/ espada/machado/martelo(melee)/arco/cajado/livro → NÃO toca o dano
## de nenhuma outra arma. Aditivo e CAPADO (mastery_bonus 0..cap)*2 → no máx +6 de dano de estocada.
func stance_damage_bonus() -> int:
	if current_combat_archetype() != "reach":
		return 0
	return mastery_bonus("stance") * 2

func mitigated_damage(raw: int) -> int:
	if raw <= 0:
		return 0
	var def := defense_bonus() + guard_defense_bonus()   # +Maestria de Guarda (só melee+escudo; 0 p/ o resto)
	return maxi(1, int(ceil(float(raw) * 100.0 / (100.0 + float(def) * DEFENSE_K))))

## % de redução de dano da defesa atual (p/ exibir no inventário).
func defense_mitigation_pct() -> int:
	return int(round((1.0 - 100.0 / (100.0 + float(defense_bonus()) * DEFENSE_K)) * 100.0))

## --- SIDE-QUEST (GODOT-CONTENT-QUEST-HUNT-2) — estado simples persistido; conteúdo fica no Main ---
func material_count(name: String) -> int:
	return int(materials.get(name, 0))

## Remove n de um material (p/ entrega de quest). true se tinha o suficiente.
func consume_material(name: String, n: int) -> bool:
	if material_count(name) < n:
		return false
	var left := material_count(name) - n
	if left <= 0:
		materials.erase(name)
	else:
		materials[name] = left
	save_game()
	state_changed.emit()
	return true

## --- BAÚ / DEPÓSITO DO ERRANTE (GODOT-VILLAGE-STASH-MVP-1) ---
## Move entre mochila/materiais e o stash. Tudo bounded (sem negativo, sem dup; Dictionaries somam).
## Reusa add_material/consume_material/backpack_add/backpack_remove (zero refactor de inventário).
func _stash_mats() -> Dictionary:
	return player_stash.get("materials", {})

func _stash_its() -> Dictionary:
	return player_stash.get("items", {})

func stash_material_count(name: String) -> int:
	return int(_stash_mats().get(name, 0))

func stash_item_count(id: String) -> int:
	return int(_stash_its().get(id, 0))

## Guarda `qty` de um material (mochila/materials -> stash). false se não tiver o suficiente.
func stash_deposit_material(name: String, qty: int) -> bool:
	if qty <= 0 or material_count(name) < qty:
		return false
	consume_material(name, qty)
	var mats := _stash_mats()
	mats[name] = int(mats.get(name, 0)) + qty
	player_stash["materials"] = mats
	state_changed.emit()
	save_game()
	return true

## Retira `qty` de um material (stash -> materials). false se não tiver no baú.
func stash_withdraw_material(name: String, qty: int) -> bool:
	var mats := _stash_mats()
	if qty <= 0 or int(mats.get(name, 0)) < qty:
		return false
	mats[name] = int(mats[name]) - qty
	if int(mats[name]) <= 0:
		mats.erase(name)
	player_stash["materials"] = mats
	add_material(name, qty)
	state_changed.emit()
	save_game()
	return true

## Guarda `qty` de um item EMPILHÁVEL (mochila -> stash). Só stackable (equipamento fica de fora do MVP).
func stash_deposit_item(id: String, qty: int) -> bool:
	if qty <= 0 or not ItemDB.is_stackable(id) or backpack_count(id) < qty:
		return false
	backpack_remove(id, qty)
	var its := _stash_its()
	its[id] = int(its.get(id, 0)) + qty
	player_stash["items"] = its
	state_changed.emit()
	save_game()
	return true

## Retira `qty` de um item (stash -> mochila).
func stash_withdraw_item(id: String, qty: int) -> bool:
	var its := _stash_its()
	if qty <= 0 or int(its.get(id, 0)) < qty:
		return false
	its[id] = int(its[id]) - qty
	if int(its[id]) <= 0:
		its.erase(id)
	player_stash["items"] = its
	backpack_add(id, qty)
	state_changed.emit()
	save_game()
	return true

## Estado de uma side-quest por id: ""(não iniciada) / "active" / "done".
func sq_state(id: String) -> String:
	return str(side_quests.get(id, ""))

func sq_set(id: String, state: String) -> void:
	side_quests[id] = state
	save_game()
	state_changed.emit()

## Progresso numérico de uma side-quest (kill-count etc.). 0 se inexistente.
func sq_progress(id: String) -> int:
	return int(side_quest_progress.get(id, 0))

## Incrementa o progresso de uma side-quest em n (>=1). Persiste + emite. Genérico:
## quem chama (Main) decide QUANDO contar (só com quest ativa, sem ultrapassar a meta).
func sq_add_progress(id: String, n: int = 1) -> void:
	if n <= 0:
		return
	side_quest_progress[id] = sq_progress(id) + n
	save_game()
	state_changed.emit()

## Zera o progresso de uma side-quest (p/ repetir um bounty repetível). Persiste + emite.
func sq_reset_progress(id: String) -> void:
	side_quest_progress.erase(id)
	save_game()
	state_changed.emit()

## Avança a rotação dos contratos repetíveis do mural (botão "🔄 Atualizar"). Persiste + emite.
func bump_board_rotation() -> void:
	board_rotation += 1
	save_game()
	state_changed.emit()

## Debita `amount` de ouro se houver saldo. Retorna true se debitou (false = sem ouro, NADA muda).
## Helper genérico de gasto (add_gold ignora valores <=0, então não serve p/ debitar).
func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if hero_gold < amount:
		return false
	hero_gold -= amount
	state_changed.emit()
	save_game()
	return true

## Soma 1 ao total de contratos do mural concluídos (GODOT-BOUNTY-BOARD-POLISH-1). Chamado só na
## ENTREGA real de um bounty (dentro do guard de pagamento) → nunca sobe sem recompensa. Persiste + emite.
func add_bounty_completed() -> void:
	bounty_completed_count += 1
	save_game()
	state_changed.emit()

## --- BAÚS / RECOMPENSA ONE-TIME (GODOT-CHESTS-LOOT-RUNTIME-1) ---
## Estado mínimo persistido: só a lista de ids abertos. O CONTEÚDO/posição do baú vive no Main
## (config/fallback) ou num export do Studio — aqui só guardamos "já foi aberto" p/ não repetir.

func is_chest_opened(id: String) -> bool:
	return opened_chests.has(id)

## Marca um baú como aberto (idempotente). Retorna true se mudou (1ª vez) — o Main entrega o loot só nesse caso.
func open_chest(id: String) -> bool:
	if id == "" or opened_chests.has(id):
		return false
	opened_chests.append(id)
	print("[GameState] baú aberto: %s" % id)
	state_changed.emit()
	save_game()
	return true

## Marco narrativo one-time (GODOT-ROOT-ARC-CLOSURE-1). is_story_flag = já aconteceu?
func is_story_flag(id: String) -> bool:
	return story_flags.has(id)

## Marca um marco (idempotente). Retorna true só na 1ª vez — o Main mostra o fechamento só então. Persiste.
func set_story_flag(id: String) -> bool:
	if id == "" or story_flags.has(id):
		return false
	story_flags.append(id)
	print("[GameState] marco narrativo: %s" % id)
	state_changed.emit()
	save_game()
	return true

## Dev/test: dá o kit inicial à mochila (cada equipamento só se ainda não tiver; +2 poções).
func grant_test_items() -> void:
	var kit := ["sword_simple", "axe_simple", "hammer_simple", "shield_simple", "bow_simple", "staff_simple", "spear_simple", "book_simple", "armor_simple", "boots_simple"]
	for id in kit:
		var equipped := equipment.values().has(id)
		if backpack_count(id) <= 0 and not equipped:
			backpack_add(id, 1)
	backpack_add("potion_minor", 2)

## --- ECONOMIA: LOJA & FORJA (GODOT-VILLAGE-SERVICES-SHOP-1) ---
## Transações sobre gold/backpack/materials (que esta classe já possui). Preços/receitas vêm do
## ItemDB. Cada mutação persiste via os helpers existentes (backpack_add/_touch → save_game).

## Compra 1 unidade de um item da loja: debita o preço e empilha na mochila. Retorna true se comprou.
func buy_item(id: String) -> bool:
	var cost := ItemDB.price(id)
	if cost <= 0 or not ItemDB.exists(id) or hero_gold < cost:
		return false
	hero_gold -= cost
	backpack_add(id, 1)   # backpack_add já chama _touch() (emite + salva)
	return true

## Vende 1 unidade de um item da mochila pelo valor de revenda. Retorna true se vendeu.
func sell_item(id: String) -> bool:
	if backpack_count(id) <= 0:
		return false
	var value := ItemDB.sell_value(id)
	if not backpack_remove(id, 1):
		return false
	hero_gold += value
	_touch()
	return true

## Vende 1 unidade de um material pelo seu valor. Retorna true se vendeu.
func sell_material(mat_name: String) -> bool:
	var have := int(materials.get(mat_name, 0))
	if have <= 0:
		return false
	if have - 1 <= 0:
		materials.erase(mat_name)
	else:
		materials[mat_name] = have - 1
	hero_gold += ItemDB.material_value(mat_name)
	_touch()
	return true

## true se há materiais + gold suficientes p/ forjar a receita.
func can_craft(recipe_id: String) -> bool:
	var r := ItemDB.recipe(recipe_id)
	if r.is_empty() or hero_gold < int(r.get("gold", 0)):
		return false
	var mats: Dictionary = r.get("materials", {})
	for m in mats:
		if int(materials.get(m, 0)) < int(mats[m]):
			return false
	return true

## Forja: consome materiais + gold e entrega o item na mochila. Retorna true se forjou.
func craft(recipe_id: String) -> bool:
	if not can_craft(recipe_id):
		return false
	var r := ItemDB.recipe(recipe_id)
	var mats: Dictionary = r.get("materials", {})
	for m in mats:
		var left := int(materials.get(m, 0)) - int(mats[m])
		if left <= 0:
			materials.erase(m)
		else:
			materials[m] = left
	hero_gold -= int(r.get("gold", 0))
	backpack_add(str(recipe_id), 1)   # a chave da receita É o id do item produzido (_touch via backpack_add)
	print("[GameState] forjado: %s" % recipe_id)
	return true

## --- SAVE LOCAL (user://) ---

## Serializa o estado do slice. JSON.stringify lida com Array[String]/Dictionary nativamente.
func to_dict() -> Dictionary:
	return {
		"schemaVersion": SAVE_SCHEMA,
		"hero_level": hero_level,
		"seen_dialogues": seen_dialogues,
		"choices": choices,
		"completed_quests": completed_quests,
		"defeated_bosses": defeated_bosses,
		"inventory_items": inventory_items,
		"hero_hp": hero_hp,
		"hero_hp_max": hero_hp_max,
		"hero_xp": hero_xp,
		"hero_xp_to_next": hero_xp_to_next,
		"hero_gold": hero_gold,
		"arrows_current": arrows_current,
		"arrows_max": arrows_max,
		"mana_current": mana_current,
		"mana_max": mana_max,
		"proficiency": proficiency,
		"class_mastery": class_mastery,
		"player_stash": player_stash,
		"materials": materials,
		"backpack": backpack,
		"equipment": equipment,
		"active_quest_id": active_quest_id,
		"current_region_id": current_region_id,
		"cluster_pos": cluster_pos,
		"cluster_id": cluster_id,
		"tutorial_step": tutorial_step,
		"side_quests": side_quests,
		"side_quest_progress": side_quest_progress,
		"board_rotation": board_rotation,
		"bounty_completed_count": bounty_completed_count,
		"opened_chests": opened_chests,
		"story_flags": story_flags,
		"carried_names": carried_names,
		"stage_chapter": stage_chapter,
		"stage_index": stage_index,
		"stage_kills": stage_kills,
		"stage_highest_global": stage_highest_global,
		"stage_mode": stage_mode,
		"stage_wall_active": stage_wall_active,
		"stage_fails": stage_fails,
		"stage_frontier_chapter": stage_frontier_chapter,
		"stage_frontier_stage": stage_frontier_stage,
		"stage_farm_chapter": stage_farm_chapter,
		"stage_farm_stage": stage_farm_stage,
		"locked_items": locked_items,
		"loot_overflow": loot_overflow,
		"game_speed": game_speed,
		"last_seen_at": last_seen_at,
		"offline_pending": offline_pending,
		"offline_remainder_seconds": offline_remainder_seconds,
		"prestige_count": prestige_count,
		"master_level": master_level,
		"cycle_seals": cycle_seals,
		"cycle_seal_high": cycle_seal_high,
		"lifetime_highest_stage": lifetime_highest_stage,
		"slot_refinement": slot_refinement,
		"jewel_levels": jewel_levels,
		"bestiary": bestiary,
		"codex_discovered": codex_discovered,
		"codex_claimed": codex_claimed,
		"equipped_instances": equipped_instances,
		"item_instances": item_instances,
		"overflow_instances": overflow_instances,
		"locked_instances": locked_instances,
		"refine_pity_by_slot": refine_pity_by_slot,
		"cycle_encounter_high": cycle_encounter_high,
		"refine_high_by_slot": refine_high_by_slot,
		"lifetime_encounter_high": lifetime_encounter_high,
		"narrative_seen": narrative_seen,
		"narrative_choices": narrative_choices,
		"character_class": character_class,
		"appearance": appearance,
		"display_name": display_name,
		"loadouts": loadouts,
		"active_loadout": active_loadout,
		"acquisition_intent": acquisition_intent,
		"tracked_goal": tracked_goal,
		"tracked_boss": tracked_boss,
	}

## Aplica um dicionário (de save) ao estado, tolerando campos ausentes (defaults) e
## reconstruindo os Array[String] tipados a partir do Array genérico do JSON.
func apply_dict(data: Dictionary) -> void:
	acquisition_intent = (data.get("acquisition_intent", {}) as Dictionary).duplicate(true)
	tracked_goal = (data.get("tracked_goal", {}) as Dictionary).duplicate(true)
	tracked_boss = (data.get("tracked_boss", {}) as Dictionary).duplicate(true)
	hero_level = maxi(1, int(data.get("hero_level", 1)))
	seen_dialogues.clear()
	for s in data.get("seen_dialogues", []):
		seen_dialogues.append(str(s))
	completed_quests.clear()
	for q in data.get("completed_quests", []):
		completed_quests.append(str(q))
	defeated_bosses.clear()
	for b in data.get("defeated_bosses", []):
		defeated_bosses.append(str(b).to_lower())
	choices.clear()
	var ch: Variant = data.get("choices", {})
	if ch is Dictionary:
		for k in ch:
			choices[str(k)] = str(ch[k])
	inventory_items.clear()   # tolera saves antigos sem o campo (default [])
	for it in data.get("inventory_items", []):
		inventory_items.append(str(it))
	# progressão de hunt (tolera saves antigos sem os campos)
	hero_hp_max = maxi(100, int(data.get("hero_hp_max", 100)))
	hero_xp = maxi(0, int(data.get("hero_xp", 0)))
	hero_xp_to_next = maxi(1, int(data.get("hero_xp_to_next", 100)))
	hero_gold = maxi(0, int(data.get("hero_gold", 0)))
	# PRESTÍGIO / MASTER (A6): lidos CEDO — o max_hp_total() do clamp de hero_hp (abaixo) já usa o Master
	# multiplier. Permanentes; default 0 (save antigo/v4 sem Prestígio => mult 1.0 => zero impacto no CP).
	prestige_count = maxi(0, int(data.get("prestige_count", 0)))
	master_level = maxi(0, int(data.get("master_level", 0)))
	# RECURSOS DE CLASSE (GODOT-CLASS-RESOURCES-MVP-1): saves antigos SEM os campos → defaults seguros
	# (cheios); clamp 0..max. arrows_current/mana_current default = max quando ausentes.
	arrows_max = ARROWS_STACK_MAX   # teto fixo (migra saves antigos que tinham 30 → 500)
	arrows_current = clampi(int(data.get("arrows_current", arrows_max)), 0, arrows_max)
	# MANA: teto DERIVADO do nível (GODOT-MANA-MAX-SCALING-1) → IGNORA o mana_max salvo e recomputa pelo
	# hero_level (já lido acima) → migra saves antigos (ex.: Nv24 com 50 → 119) SEM campo novo. current clampado.
	mana_max = mana_max_for_level(hero_level)
	mana_current = clampi(int(data.get("mana_current", mana_max)), 0, mana_max)
	# PROFICIÊNCIA (GODOT-VOCATION-PROFICIENCY-MVP-1): save antigo SEM o campo → {} (entradas sob demanda).
	# Tolerante: só chaves de VOCATION_DEFS; normaliza level>=1 / xp>=0 (descarta lixo).
	proficiency.clear()
	var pr: Variant = data.get("proficiency", {})
	if pr is Dictionary:
		for k in pr:
			if VOCATION_DEFS.has(k) and pr[k] is Dictionary:
				proficiency[str(k)] = {
					"xp": maxi(0, int((pr[k] as Dictionary).get("xp", 0))),
					"level": maxi(1, int((pr[k] as Dictionary).get("level", 1))),
				}
	# MAESTRIA (GODOT-ORACLE-PRESAGE-MASTERY-MVP-1): save antigo sem o campo -> {}; só chaves de
	# CLASS_MASTERY_DEFS; normaliza level>=1/xp>=0 (descarta lixo).
	class_mastery.clear()
	var cm: Variant = data.get("class_mastery", {})
	if cm is Dictionary:
		for k in cm:
			if CLASS_MASTERY_DEFS.has(k) and cm[k] is Dictionary:
				class_mastery[str(k)] = {
					"xp": maxi(0, int((cm[k] as Dictionary).get("xp", 0))),
					"level": maxi(1, int((cm[k] as Dictionary).get("level", 1))),
				}
	materials.clear()
	var mats: Variant = data.get("materials", {})
	if mats is Dictionary:
		for k in mats:
			materials[str(k)] = int(mats[k])
	# BAÚ (GODOT-VILLAGE-STASH-MVP-1): save antigo SEM o campo -> {materials:{}, items:{}}. Normaliza:
	# materiais (nome->int>0); itens só ids válidos do ItemDB (id->int>0). Descarta lixo/negativos.
	player_stash = {"materials": {}, "items": {}}
	var ps: Variant = data.get("player_stash", {})
	if ps is Dictionary:
		var pm: Variant = (ps as Dictionary).get("materials", {})
		if pm is Dictionary:
			for k in pm:
				var q := int(pm[k])
				if q > 0:
					player_stash["materials"][str(k)] = q
		var pi: Variant = (ps as Dictionary).get("items", {})
		if pi is Dictionary:
			for k in pi:
				var q2 := int(pi[k])
				if q2 > 0 and ItemDB.exists(str(k)):
					player_stash["items"][str(k)] = q2
	# mochila/equipamentos: tolera saves antigos (campos ausentes → vazios); valida ids no ItemDB.
	backpack.clear()
	for e in data.get("backpack", []):
		if e is Dictionary and ItemDB.exists(str(e.get("id", ""))):
			backpack.append({"id": str(e["id"]), "qty": maxi(1, int(e.get("qty", 1)))})
	equipment.clear()
	var eq: Variant = data.get("equipment", {})
	if eq is Dictionary:
		for slot in eq:
			var iid := str(eq[slot])
			if ItemDB.exists(iid):
				equipment[str(slot)] = iid
	# HP do herói: tolera ausência (default = cheio). Se o save estava derrotado (≤0),
	# o herói ACORDA com HP cheio no boot — evita iniciar travado num estado de morte.
	hero_hp = clampi(int(data.get("hero_hp", hero_hp_max)), 0, max_hp_total())
	if hero_hp <= 0:
		hero_hp = max_hp_total()
	active_quest_id = str(data.get("active_quest_id", DEFAULT_QUEST))   # tolera save antigo
	current_region_id = str(data.get("current_region_id", DEFAULT_REGION))   # tolera save antigo
	cluster_pos = data.get("cluster_pos", [])   # GRADUATION-1: posição global no cluster (ausente = [])
	cluster_id = str(data.get("cluster_id", ""))
	# tutorial: saves SEM o campo (anteriores a este pacote) não são arrastados ao onboarding —
	# veteranos que já fecharam o ch1 entram como DONE; o resto começa do início.
	if data.has("tutorial_step"):
		tutorial_step = str(data["tutorial_step"])
	else:
		var ch1_done := completed_quests.has("ch1-awakening") or defeated_bosses.has("lobo alfa")
		tutorial_step = TUTORIAL_DONE if ch1_done else TUTORIAL_START
	# side-quests (GODOT-VILLAGE-SIDEQUESTS-CHAIN-1): carrega o map; MIGRA o campo antigo single-string.
	side_quests.clear()
	var sq: Variant = data.get("side_quests", {})
	if sq is Dictionary:
		for k in sq:
			side_quests[str(k)] = str(sq[k])
	if data.has("side_quest") and not side_quests.has("tomas_couro"):   # save da QUEST-HUNT-2
		var old := str(data["side_quest"])
		if old == "active" or old == "done":
			side_quests["tomas_couro"] = old
	# progresso de kill-count (GODOT-SIDEQUEST-KILLCOUNT-1): tolera saves antigos sem o campo (→ {}).
	side_quest_progress.clear()
	var sqp: Variant = data.get("side_quest_progress", {})
	if sqp is Dictionary:
		for k in sqp:
			side_quest_progress[str(k)] = int(sqp[k])
	board_rotation = maxi(0, int(data.get("board_rotation", 0)))   # tolera saves antigos sem o campo (→ 0)
	bounty_completed_count = maxi(0, int(data.get("bounty_completed_count", 0)))   # idem (→ 0)
	# baús abertos (GODOT-CHESTS-LOOT-RUNTIME-1): tolera saves antigos sem o campo (→ []); reconstrói Array[String]
	opened_chests.clear()
	for c in data.get("opened_chests", []):
		opened_chests.append(str(c))
	story_flags.clear()   # marcos narrativos (GODOT-ROOT-ARC-CLOSURE-1): tolera saves antigos (→ [])
	for fl in data.get("story_flags", []):
		story_flags.append(str(fl))
	carried_names.clear()   # LEGADO (PEDRA_LEGACY_F5): nomes carregados na Pedra; tolera saves antigos (→ [])
	for nm in data.get("carried_names", []):
		carried_names.append(str(nm))
	# FATIA A9 (NarrativeDirector): tolera saves antigos (→ []/{}). SEEN de beat também é inferido de seen_dialogues.
	narrative_seen.clear()
	for bid in data.get("narrative_seen", []):
		narrative_seen.append(str(bid))
	narrative_choices = {}
	var _nc: Dictionary = data.get("narrative_choices", {}) if data.get("narrative_choices", {}) is Dictionary else {}
	for k in _nc:
		narrative_choices[str(k)] = str(_nc[k])
	# A13 (v10) — identidade. Tolera saves antigos (defaults legacy). Aparência sanitizada (nunca path injection).
	character_class = str(data.get("character_class", "LEGACY_CLASS"))
	appearance = CharacterAppearance.sanitize(data.get("appearance", {}))
	display_name = str(data.get("display_name", "Errante"))
	loadouts = (data.get("loadouts", []) as Array).duplicate(true) if data.get("loadouts", []) is Array else []
	active_loadout = maxi(0, int(data.get("active_loadout", 0)))
	# PROGRESSÃO POR FASES (FATIA A2): tolera saves antigos SEM os campos → começa em 1-1 (default seguro),
	# SEM tocar região/quest/inventário/level. Clamps defensivos contra lixo.
	stage_chapter = maxi(1, int(data.get("stage_chapter", 1)))
	stage_index = clampi(int(data.get("stage_index", 1)), 1, 10)
	stage_kills = maxi(0, int(data.get("stage_kills", 0)))
	stage_highest_global = maxi(1, int(data.get("stage_highest_global", (stage_chapter - 1) * 10 + stage_index)))
	# MURO (A3): tolera saves sem os campos (v1 migrado / defaults) → sem muro, modo avanço.
	stage_mode = str(data.get("stage_mode", "advance"))
	if stage_mode != "farm": stage_mode = "advance"
	stage_wall_active = bool(data.get("stage_wall_active", false))
	stage_fails = maxi(0, int(data.get("stage_fails", 0)))
	stage_frontier_chapter = maxi(1, int(data.get("stage_frontier_chapter", stage_chapter)))
	stage_frontier_stage = clampi(int(data.get("stage_frontier_stage", stage_index)), 1, 10)
	stage_farm_chapter = maxi(1, int(data.get("stage_farm_chapter", 1)))
	stage_farm_stage = clampi(int(data.get("stage_farm_stage", 1)), 1, 10)
	# LOOT (A3.5): tolera saves v1/v2 sem os campos → vazios. Valida ids/qty (descarta lixo, nunca quebra).
	locked_items.clear()
	for lid in data.get("locked_items", []):
		if str(lid) != "" and not locked_items.has(str(lid)):
			locked_items.append(str(lid))
	loot_overflow.clear()
	for e in data.get("loot_overflow", []):
		if e is Dictionary and ItemDB.exists(str(e.get("id", ""))):
			loot_overflow.append({"id": str(e["id"]), "qty": maxi(1, int(e.get("qty", 1)))})
	# VELOCIDADE (A4): tolera save sem o campo (→ 1.0); valor inválido/fora do conjunto → x1 seguro (§28/§52-T10).
	var gsp := float(data.get("game_speed", 1.0))
	game_speed = gsp if gsp == 1.0 or gsp == 2.0 or gsp == 3.0 else 1.0
	# OFFLINE (A5): tolera saves v1..v3 sem os campos; sanitiza (nunca negativo/NaN/inf; pending inválido → {}).
	last_seen_at = maxi(0, int(data.get("last_seen_at", 0)))
	var rem := float(data.get("offline_remainder_seconds", 0.0))
	offline_remainder_seconds = rem if (rem == rem and rem >= 0.0 and rem < 1.0e12) else 0.0   # NaN-safe
	offline_pending = {}
	var op: Variant = data.get("offline_pending", {})
	if op is Dictionary:
		offline_pending = _sanitize_pending(op)
	# SELOS / LIFETIME (A6): MIGRAÇÃO CONSERVADORA (§47). Selos ausentes -> DERIVA do maior global do ciclo:
	# chegar a highest exigiu concluir as boss-stages 10,20,... em avanço = floor((highest-1)/10) Selos REAIS
	# (nao e Prestigio gratis — Prestigio ainda exige stage>=100 E selos). Save v5 traz os campos explicitos
	# -> o valor salvo VENCE a derivacao. lifetime_highest >= maior do ciclo (nunca regride, §17).
	var _cyc_hi := stage_highest_global
	cycle_seal_high = maxi(0, int(data.get("cycle_seal_high", PrestigeMath.seal_high_from_highest(_cyc_hi))))
	cycle_seals = maxi(0, int(data.get("cycle_seals", PrestigeMath.seals_from_highest(_cyc_hi))))
	lifetime_highest_stage = maxi(_cyc_hi, int(data.get("lifetime_highest_stage", _cyc_hi)))
	# SISTEMAS A7 (schema 6): tolera saves v1..v5 sem os campos. Valida chaves/limites (descarta lixo).
	slot_refinement.clear()
	var sr: Variant = data.get("slot_refinement", {})
	if sr is Dictionary:
		for slot in sr:
			if ItemDB.SLOT_ORDER.has(str(slot)):
				slot_refinement[str(slot)] = clampi(int(sr[slot]), 0, RefineMath.REFINE_MAX_LEVEL)
	jewel_levels.clear()
	var jl: Variant = data.get("jewel_levels", {})
	if jl is Dictionary:
		for jt in jl:
			if JewelMath.exists(str(jt)):
				jewel_levels[str(jt)] = clampi(int(jl[jt]), 0, JewelMath.JEWEL_MAX_LEVEL)
	bestiary.clear()
	var bs: Variant = data.get("bestiary", {})
	if bs is Dictionary:
		for mid in bs:
			if bs[mid] is Dictionary:
				bestiary[str(mid)] = {
					"kills": maxi(0, int((bs[mid] as Dictionary).get("kills", 0))),
					"claimed": maxi(0, int((bs[mid] as Dictionary).get("claimed", 0))),
				}
	_recompute_bestiary_total()
	codex_discovered.clear()
	for cid in data.get("codex_discovered", []):
		if ItemDB.exists(str(cid)) and not codex_discovered.has(str(cid)):
			codex_discovered.append(str(cid))
	# MIGRACAO CONSERVADORA do Codice (§61): save sem o campo NAO marca todo o catalogo; infere so o que o
	# jogador comprovadamente teve (equipado + mochila). Nunca inventa itens que ele nunca possuiu.
	if not data.has("codex_discovered"):
		for slot2 in equipment:
			var eid := str(equipment[slot2])
			if ItemDB.exists(eid) and not codex_discovered.has(eid):
				codex_discovered.append(eid)
		for e2 in backpack:
			if e2 is Dictionary:
				var bid := str(e2.get("id", ""))
				if ItemDB.exists(bid) and ItemDB.is_equippable(bid) and not codex_discovered.has(bid):
					codex_discovered.append(bid)
	codex_claimed = maxi(0, int(data.get("codex_claimed", 0)))
	# ITEM INSTANCES (A7.1, schema 7): tolera saves v1..v6 sem os campos → vazios. Sanitiza cada instância
	# (descarta lixo/ids inválidos; nunca perde silenciosamente um item válido).
	equipped_instances.clear()
	var ei: Variant = data.get("equipped_instances", {})
	if ei is Dictionary:
		for slot in ei:
			var inst := ItemInstance.sanitize(ei[slot])
			if not inst.is_empty() and ItemDB.slot_of(ItemInstance.base_item_id(inst)) == str(slot):
				equipped_instances[str(slot)] = inst
	item_instances.clear()
	for raw in data.get("item_instances", []):
		var it := ItemInstance.sanitize(raw)
		if not it.is_empty():
			item_instances.append(it)
	overflow_instances.clear()
	for raw2 in data.get("overflow_instances", []):
		var it2 := ItemInstance.sanitize(raw2)
		if not it2.is_empty():
			overflow_instances.append(it2)
	locked_instances.clear()
	for lid in data.get("locked_instances", []):
		if str(lid) != "" and not locked_instances.has(str(lid)):
			locked_instances.append(str(lid))
	refine_pity_by_slot.clear()
	var rp: Variant = data.get("refine_pity_by_slot", {})
	if rp is Dictionary:
		for slot2 in rp:
			if ItemDB.SLOT_ORDER.has(str(slot2)):
				refine_pity_by_slot[str(slot2)] = clampf(float(rp[slot2]), 0.0, RefineMath.PITY_MAX_BONUS)
	cycle_encounter_high = maxi(0, int(data.get("cycle_encounter_high", 0)))
	refine_high_by_slot.clear()
	var rh: Variant = data.get("refine_high_by_slot", {})
	if rh is Dictionary:
		for slot3 in rh:
			if ItemDB.SLOT_ORDER.has(str(slot3)):
				refine_high_by_slot[str(slot3)] = clampi(int(rh[slot3]), 0, RefineMath.REFINE_MAX_LEVEL)
	lifetime_encounter_high = maxi(0, int(data.get("lifetime_encounter_high", 0)))

## ★ LEGADO (PEDRA_LEGACY_F5) — carregar um nome na Vigília: ACUMULA (dedup) e PERSISTE. Retorna true se o nome é
## NOVO (a parede cresceu); false se já estava lá. SEM poder/recompensa/moeda — só permanência. O Errante não constrói.
func carry_name(nm: String) -> bool:
	nm = nm.strip_edges()
	if nm == "" or carried_names.has(nm):
		return false
	carried_names.append(nm)
	save_game()
	return true

## API PÚBLICA (A3.75): agora DEBOUNCED — marca sujo e deixa o autosave/flush gravar. Os ~38 call-sites
## (dano/HP/proficiência/XP/ouro/…) passam a NÃO escrever o JSON a cada hit. Compatível: quem já chamava
## save_game() continua chamando; a gravação real acontece em ≤ AUTOSAVE_INTERVAL, no flush, ou no quit.
func save_game() -> void:
	if _loading:
		return
	_dirty = true
	dirty_mark_count += 1

## Grava AGORA se houver estado sujo (§13: equipamento/stage/muro/migração/quit). Idempotente.
func flush_save() -> void:
	if _loading or not _dirty:
		return
	forced_flush_count += 1
	_write_save_now()

## Escrita REAL do save (o único writer — usado pelo autosave, pelo flush e pela migração). Limpa o sujo.
func _write_save_now() -> void:
	if _loading:
		return
	# A5: HEARTBEAT — write de sessão ATIVA carimba last_seen_at (tempo real). Durante load/migração
	# (_session_started=false) NÃO carimba → o boot_reconcile lê o last_seen ANTIGO antes de qualquer write.
	if _session_started:
		last_seen_at = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	if f == null:
		push_error("[GameState] não consegui escrever o save: %s" % _save_path())
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	_dirty = false
	_autosave_t = 0.0
	_last_write_ms = Time.get_ticks_msec()
	save_write_count += 1

## Carrega o save se existir. Retorna true se aplicou algo. Tolera ausência/JSON inválido/
## schema diferente (nesses casos, mantém o estado inicial e segue em frente).
func load_game() -> bool:
	if not FileAccess.file_exists(_save_path()):
		print("[GameState] sem save prévio (%s) — começando do zero." % _save_path())
		return false
	var f := FileAccess.open(_save_path(), FileAccess.READ)
	if f == null:
		push_error("[GameState] save existe mas não abriu: %s" % _save_path())
		return false
	var text := f.get_as_text()
	f.close()
	# MIGRAÇÃO SEGURA (A1.5): a SaveMigration lê o schema, migra v-por-v preservando campos, faz BACKUP do
	# original antes de qualquer migração/sobrescrita, e diagnostica JSON inválido / save mais novo — SEM
	# apagar a única cópia (≠ do comportamento antigo, que ignorava e deixava o próximo save sobrescrever).
	var prep := SaveMigration.prepare(text, _save_path())
	if not bool(prep.get("ok", false)):
		push_warning("[GameState] save NÃO aplicado (%s): %s. Estado inicial preservado; backup feito se aplicável." % [str(prep.get("status", "?")), str(prep.get("note", ""))])
		return false
	var data: Dictionary = prep.get("data", {})
	_loading = true
	apply_dict(data)
	_loading = false
	# Se houve migração, PERSISTE JÁ (write imediato — não pode ficar debounced, senão re-migra no próximo boot).
	if bool(prep.get("migrated", false)):
		_write_save_now()
		print("[GameState] save MIGRADO e regravado (%s)." % str(prep.get("note", "")))
	state_changed.emit()
	print("[GameState] save carregado: level %d, %d cenas vistas, %d quests, %d bosses." % [
		hero_level, seen_dialogues.size(), completed_quests.size(), defeated_bosses.size()
	])
	return true

## Apaga o save e zera o estado em memória (debug, F12).
func reset_save() -> void:
	if FileAccess.file_exists(_save_path()):
		DirAccess.remove_absolute(_save_path())
	hero_level = 1
	seen_dialogues.clear()
	completed_quests.clear()
	defeated_bosses.clear()
	choices.clear()
	inventory_items.clear()
	hero_hp_max = 100
	hero_hp = hero_hp_max
	hero_xp = 0
	hero_xp_to_next = 100
	hero_gold = 0
	mana_max = MANA_BASE   # MANA-MAX-SCALING-1: Nv1 = 50 / 50 (estado inicial)
	mana_current = MANA_BASE
	materials.clear()
	backpack.clear()
	equipment.clear()
	active_quest_id = DEFAULT_QUEST
	current_region_id = DEFAULT_REGION
	cluster_pos = []
	cluster_id = ""
	tutorial_step = TUTORIAL_START   # F12/reset reinicia o onboarding na Vila
	side_quests.clear()
	side_quest_progress.clear()
	board_rotation = 0
	bounty_completed_count = 0
	opened_chests.clear()
	story_flags.clear()
	carried_names.clear()
	narrative_seen.clear()
	narrative_choices = {}
	stage_chapter = 1
	stage_index = 1
	stage_kills = 0
	stage_highest_global = 1
	stage_mode = "advance"
	stage_wall_active = false
	stage_fails = 0
	stage_frontier_chapter = 1
	stage_frontier_stage = 1
	stage_farm_chapter = 1
	stage_farm_stage = 1
	locked_items.clear()
	loot_overflow.clear()
	game_speed = 1.0
	last_seen_at = 0
	offline_pending = {}
	offline_remainder_seconds = 0.0
	prestige_count = 0            # A6: F12 = personagem novo -> zera Prestigio/Master/Selos/recorde
	master_level = 0
	cycle_seals = 0
	cycle_seal_high = 0
	lifetime_highest_stage = 1
	slot_refinement.clear()      # A7: F12 = personagem novo -> zera Refino/Joias/Bestiario/Codice
	jewel_levels.clear()
	bestiary.clear()
	_bestiary_claimed_total = 0
	codex_discovered.clear()
	codex_claimed = 0
	equipped_instances.clear()
	item_instances.clear()
	overflow_instances.clear()
	locked_instances.clear()
	refine_pity_by_slot.clear()
	cycle_encounter_high = 0
	refine_high_by_slot.clear()
	lifetime_encounter_high = 0
	character_class = "LEGACY_CLASS"   # A13 (v10): reset = personagem legado default
	appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	display_name = "Errante"
	loadouts = []
	active_loadout = 0
	print("[GameState] save resetado — estado inicial.")
	state_changed.emit()
