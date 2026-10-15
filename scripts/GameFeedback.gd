class_name GameFeedback extends Node
## FATIA A8 — COORDENADOR CENTRAL DE FEEDBACK. Um só lugar recebe TODO evento de "algo aconteceu" (dano, cura,
## loot, +PODER, transição, aviso de boss, refino, prestígio, baú offline, muro) e decide: AGREGAR, PRIORIZAR,
## LIMITAR (pooling), e EMITIR para o renderizador. NÃO desenha nada e NÃO muda matemática de combate — só
## COORDENA (evita espalhar efeito novo em dezenas de call-sites, §3/§7/§21/§45/§46/§54). O RENDER (floating text,
## HUD, telegraph, áudio) é FIELD DEFERIDO: consome os sinais/`drain_*` daqui. Toda a lógica é síncrona e testável.

## Tipos de evento (o render decide o visual; aqui é só identidade + prioridade).
const K_DAMAGE_DEALT := "damage_dealt"     # dano DO jogador em inimigo (número no alvo)
const K_DAMAGE_TAKEN := "damage_taken"     # dano RECEBIDO pelo herói
const K_HEAL := "heal"                      # cura do herói
const K_SHIELD := "shield"                  # absorção/escudo
const K_CP_GAIN := "cp_gain"                # +PODER (agregado)
const K_LOOT := "loot"                      # item comum/incomum/raro caiu
const K_LOOT_EXCEPTIONAL := "loot_exceptional"  # quality alta / lendário (momento especial)
const K_SALVAGE := "salvage"                # auto-salvage (≠ novo equipamento, §26)
const K_STAGE_CLEAR := "stage_clear"
const K_CHAPTER_CLEAR := "chapter_clear"
const K_BOSS_WARNING := "boss_warning"      # telegraph/aviso de habilidade perigosa
const K_BOSS_PHASE := "boss_phase"          # ESCUDO/ENFURECIDO/INVOCANDO/CURA/MUDANÇA DE FASE
const K_WALL := "wall"                      # PODER INSUFICIENTE
const K_REFINE := "refine"                  # sucesso/falha/protegido/absoluto
const K_PRESTIGE := "prestige"
const K_OFFLINE_CLAIM := "offline_claim"
const K_AUTOPLAY := "autoplay"
const K_SYSTEM := "system"                  # FATIA A8.1: canal genérico p/ os _show_reward_popup migrados
const K_BOSS_INTRO := "boss_intro"          # banner "BOSS <nome>" (§14)
const K_APEX_INTRO := "apex_intro"          # banner "APEX <nome>" (§15)
const K_STORY := "story"                     # FATIA A9: "HISTÓRIA DISPONÍVEL" (abaixo de rewards/prestígio §27/§47)

## Prioridade de TOAST (§54): menor = mais importante (aparece primeiro / não é escondido por lixo comum).
const PRIORITY := {
	K_LOOT_EXCEPTIONAL: 1,
	K_PRESTIGE: 2,
	K_CHAPTER_CLEAR: 3,
	K_STAGE_CLEAR: 4,
	K_BOSS_PHASE: 4,
	K_OFFLINE_CLAIM: 3,
	K_REFINE: 5,
	K_WALL: 5,
	K_CP_GAIN: 6,
	K_SYSTEM: 6,
	K_STORY: 7,
	K_LOOT: 7,
	K_SALVAGE: 8,
	K_AUTOPLAY: 9,
	K_BOSS_INTRO: 3,
	K_APEX_INTRO: 4,
}
const DEFAULT_PRIORITY := 6

## Limites de pooling (§45/§46): nada cresce sem teto. O render lê via drain_* e limpa.
const MAX_TOASTS := 12                      # fila de toasts; excedente evicta o de MENOR prioridade
const MAX_FLOAT_PER_FLUSH := 8              # nº máx. de números flutuantes por flush (o resto vira 1 agregado)

signal feedback(entry: Dictionary)          # evento individual (o render desenha)
signal toast_ready(entry: Dictionary)       # toast priorizado pronto p/ exibir
signal banner_ready(entry: Dictionary)      # FATIA A8.1: banner grande/breve (intro de boss/apex, capítulo)
signal audio_event(event_id: String)        # FATIA A8.1/§36: hook de áudio (assets futuros)

# ── acumuladores de dano por FONTE (agrega hits do MESMO alvo num flush → sem 30 números, §7) ──
var _dmg_accum: Dictionary = {}             # source_id → {total, hits, kind, pos}
# ── acumulador de CP (batch, §21) ──
var _cp_accum := 0
var _cp_pending := false
# ── fila de toasts priorizada ──
var _toasts: Array = []
# ── contadores (detecção de leak em teste/telemetria) ──
var total_events := 0
var total_toasts := 0
var dropped_toasts := 0

# ═══════════════ DANO / CURA (agregado por fonte, esvaziado por flush do render) ═══════════════
## Registra dano num alvo. `source_id` = id do alvo (agrega vários hits no mesmo alvo/frame num só número).
func push_damage(amount: int, source_id: String, kind: String = K_DAMAGE_DEALT, pos: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0:
		return
	total_events += 1
	var e: Dictionary = _dmg_accum.get(source_id, {"total": 0, "hits": 0, "kind": kind, "pos": pos})
	e["total"] = int(e["total"]) + amount
	e["hits"] = int(e["hits"]) + 1
	e["kind"] = kind
	e["pos"] = pos
	_dmg_accum[source_id] = e

func push_damage_taken(amount: int, pos: Vector2 = Vector2.ZERO) -> void:
	push_damage(amount, "hero", K_DAMAGE_TAKEN, pos)

func push_heal(amount: int, pos: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0:
		return
	total_events += 1
	emit_signal("feedback", {"kind": K_HEAL, "amount": amount, "pos": pos})

func push_shield(amount: int, pos: Vector2 = Vector2.ZERO) -> void:
	total_events += 1
	emit_signal("feedback", {"kind": K_SHIELD, "amount": maxi(0, amount), "pos": pos})

## Esvazia os acumuladores de dano → lista de números a desenhar (merge por fonte; teto MAX_FLOAT_PER_FLUSH).
## O RENDER chama isto a cada frame. Depois do flush, os acumuladores zeram (sem leak).
func flush_damage() -> Array:
	if _dmg_accum.is_empty():
		return []
	var out: Array = []
	for sid in _dmg_accum:
		var e: Dictionary = _dmg_accum[sid]
		out.append({"kind": str(e["kind"]), "amount": int(e["total"]), "hits": int(e["hits"]), "pos": e["pos"], "source": sid})
	_dmg_accum.clear()
	# teto de números simultâneos: se passar do limite, mantém os MAIORES e soma o resto num agregado
	if out.size() > MAX_FLOAT_PER_FLUSH:
		out.sort_custom(func(a, b): return int(a["amount"]) > int(b["amount"]))
		var kept := out.slice(0, MAX_FLOAT_PER_FLUSH - 1)
		var rest := out.slice(MAX_FLOAT_PER_FLUSH - 1)
		var agg := 0; var hits := 0
		for r in rest:
			agg += int(r["amount"]); hits += int(r["hits"])
		kept.append({"kind": K_DAMAGE_DEALT, "amount": agg, "hits": hits, "pos": Vector2.ZERO, "source": "_merged", "merged": rest.size()})
		return kept
	return out

# ═══════════════ +PODER (batch, §21) ═══════════════
## Acumula ganho de CP (equip/refino/joia/bestiário/códice/prestígio/offline). Vários numa batch → UM toast.
func push_cp(delta: int) -> void:
	if delta == 0:
		return
	total_events += 1
	_cp_accum += delta
	_cp_pending = true

## Esvazia o CP acumulado num único toast "+N PODER". Chamado ao fim de uma batch (claim/tela fechada/idle tick).
func flush_cp() -> void:
	if not _cp_pending:
		return
	var d := _cp_accum
	_cp_accum = 0
	_cp_pending = false
	if d != 0:
		_enqueue_toast({"kind": K_CP_GAIN, "delta": d, "text": _cp_text(d)})

func _cp_text(d: int) -> String:
	return ("%+d PODER" % d)

func pending_cp() -> int:
	return _cp_accum

# ═══════════════ TOASTS (priorizados, com teto) ═══════════════
## Enfileira um toast genérico (kind decide prioridade). `data` carrega o payload p/ o render.
func push_toast(kind: String, text: String, data: Dictionary = {}) -> void:
	total_events += 1
	var entry := {"kind": kind, "text": text}
	for k in data:
		entry[k] = data[k]
	_enqueue_toast(entry)

func _enqueue_toast(entry: Dictionary) -> void:
	entry["priority"] = int(PRIORITY.get(str(entry.get("kind", "")), DEFAULT_PRIORITY))
	_toasts.append(entry)
	# ordena por prioridade (estável: menor prioridade-num primeiro)
	_toasts.sort_custom(func(a, b): return int(a["priority"]) < int(b["priority"]))
	# teto: descarta o de MENOR importância (fim da fila) — nunca esconde o importante (§54)
	while _toasts.size() > MAX_TOASTS:
		_toasts.pop_back()
		dropped_toasts += 1
	total_toasts += 1
	# §36 — hook de áudio p/ eventos notáveis (assets futuros); comuns/salvage/cp ficam mudos p/ não poluir.
	var k := str(entry.get("kind", ""))
	if k == K_LOOT_EXCEPTIONAL or k == K_REFINE or k == K_PRESTIGE or k == K_BOSS_PHASE or k == K_OFFLINE_CLAIM:
		emit_signal("audio_event", k)
	emit_signal("toast_ready", entry)

## O render consome o próximo toast (mais importante). {} se vazio.
func next_toast() -> Dictionary:
	if _toasts.is_empty():
		return {}
	return _toasts.pop_front()

## Drena todos os toasts na ordem de prioridade (render/teste).
func drain_toasts() -> Array:
	var out := _toasts.duplicate()
	_toasts.clear()
	return out

func toast_count() -> int:
	return _toasts.size()

# ═══════════════ ATALHOS SEMÂNTICOS (cada sistema chama 1 método; o A8 formata via FeedbackFormat) ═══════════════
func push_loot(instance: Dictionary) -> void:
	var f := FeedbackFormat.loot(instance)
	push_toast(str(f["kind"]), str(f["text"]), f)

## §16 — salvage AGREGA (não 1 toast por item): acumula count+Frag; flush_salvage emite UM toast "N reciclados".
var _salvage_count := 0
var _salvage_frag := 0
func push_salvage(_instance_or_id, frag: int) -> void:
	total_events += 1
	_salvage_count += 1
	_salvage_frag += maxi(0, frag)

func flush_salvage() -> void:
	if _salvage_count <= 0:
		return
	var txt := ("%d reciclados · +%d Frag" % [_salvage_count, _salvage_frag]) if _salvage_count > 1 else ("Reciclado · +%d Frag" % _salvage_frag)
	push_toast(K_SALVAGE, txt, {"count": _salvage_count, "frag": _salvage_frag})
	_salvage_count = 0
	_salvage_frag = 0

func pending_salvage() -> int:
	return _salvage_count

func push_stage_clear(chapter: int, stage: int, next_type: String) -> void:
	push_toast(K_STAGE_CLEAR, FeedbackFormat.stage_clear(chapter, stage, next_type), {"chapter": chapter, "stage": stage, "next_type": next_type})

func push_chapter_clear(chapter: int, display: String) -> void:
	push_banner(K_CHAPTER_CLEAR, FeedbackFormat.chapter_clear(chapter, display), {"chapter": chapter})

## FATIA A8.1 — BANNERS (grandes/breves; intro de boss/apex, capítulo). Emite banner_ready + hook de áudio.
func push_banner(kind: String, text: String, data: Dictionary = {}) -> void:
	total_events += 1
	var entry := {"kind": kind, "text": text}
	for k in data: entry[k] = data[k]
	emit_signal("audio_event", kind)
	emit_signal("banner_ready", entry)

func push_boss_intro(boss_name: String) -> void:
	push_banner(K_BOSS_INTRO, "BOSS\n%s" % boss_name, {"boss": boss_name})

func push_apex_intro(apex_name: String) -> void:
	push_banner(K_APEX_INTRO, "APEX\n%s" % apex_name, {"apex": apex_name})

## Canal genérico p/ os _show_reward_popup migrados (§33/§34).
func push_system(text: String, color: String = "") -> void:
	push_toast(K_SYSTEM, text, {"color": color} if color != "" else {})

## FATIA A9 — história disponível (batch se vários §24/§48). count=1 → "HISTÓRIA DISPONÍVEL\n<title>".
func push_story(count: int, title: String = "") -> void:
	if count <= 0:
		return
	var txt := "HISTÓRIA DISPONÍVEL\n%s" % title if count == 1 else "%d HISTÓRIAS DISPONÍVEIS" % count
	push_toast(K_STORY, txt, {"count": count})

func push_boss_warning(boss_name: String, ability_kind: String) -> void:
	# aviso de telegraph: identidade da habilidade (o render desenha a forma; aqui é o rótulo/áudio hook)
	total_events += 1
	emit_signal("feedback", {"kind": K_BOSS_WARNING, "boss": boss_name, "ability": ability_kind, "telegraph": BossFeedback.telegraph_kind(ability_kind)})

func push_boss_phase(boss_name: String, phase_kind: String) -> void:
	var label := BossFeedback.phase_label(phase_kind)
	if label == "":
		return
	push_toast(K_BOSS_PHASE, label, {"boss": boss_name, "phase": phase_kind})

func push_wall(cp_now: int, cp_need: int, farm_label: String, advice: String) -> void:
	push_toast(K_WALL, FeedbackFormat.wall(cp_now, cp_need), {"cp": cp_now, "need": cp_need, "farm": farm_label, "advice": advice})

func push_refine(result: Dictionary) -> void:
	push_toast(K_REFINE, FeedbackFormat.refine(result), result)

func push_prestige(prestige: int, master: int, cp_before: int, cp_after: int) -> void:
	push_toast(K_PRESTIGE, FeedbackFormat.prestige(prestige, master, cp_before, cp_after), {"prestige": prestige, "master": master, "cp_before": cp_before, "cp_after": cp_after})

func push_offline_claim(summary: Dictionary) -> void:
	push_toast(K_OFFLINE_CLAIM, FeedbackFormat.offline(summary), summary)

# ═══════════════ LIMPEZA (troca de região/prestígio/reset — evita ref/estado stale) ═══════════════
func clear_transient() -> void:
	_dmg_accum.clear()
	# CP e toasts NÃO são zerados aqui (podem ser marcos legítimos a exibir); só o dano flutuante da cena velha.

func reset() -> void:
	_dmg_accum.clear()
	_toasts.clear()
	_cp_accum = 0
	_cp_pending = false
	_salvage_count = 0
	_salvage_frag = 0
