class_name CombatAnimationRegistry
extends RefCounted
## REGISTRO DE ANIMAÇÃO DE COMBATE — REAL COMBAT ANIMATION INTEGRATION PREP V1.
##
## Busca genérica `(quem, ação, direção) → strip`, com PORTÃO DE PRONTIDÃO explícito.
##
## ★★★ REGRA CENTRAL: **"o arquivo existe" NÃO é "o arquivo está pronto".** O portão só abre quando
## `data/combat_animation_ready.json` — importado do handoff reconciliado do Codex — diz `ready: true`
## PARA AQUELA ENTIDADE, **e** o arquivo passa no contrato de strip. Faltando qualquer um dos dois, a
## resposta é "não pronto" e o chamador cai no transitório PROCEDURAL. Combate nunca falha por arte.
##
## ⛔ Sem `ash_wolf` (nem qualquer id) escrito no código: quem decide é o dado.
##
## Partes cobertas: 1 (lookup jogador) · 2 (lookup mob) · 4 (portão) · 6 (contact frame) ·
## 13 (cache) · 14 (aviso uma vez + fallback).

const READY_PATH := "res://data/combat_animation_ready.json"

const ACTIONS := ["ATTACK_BASIC", "ATTACK_HEAVY", "HIT", "DEATH"]
const DIRECTIONS := ["BASE", "SIDE", "UP"]

## Contrato do strip de combate (o mesmo que o manifesto declara: `256x64 class strips, 4x64x64 RGBA`).
const FRAME_SIZE := 64
const FRAME_COUNT := 4

# ── estado estático (o registro é um singleton preguiçoso; nada de autoload novo) ──
static var _data: Dictionary = {}
static var _loaded := false
static var _frames_cache: Dictionary = {}   # "kind/id/ACTION/DIR" → SpriteFrames
static var _warned: Dictionary = {}         # mesma chave → true (Parte 14: avisa UMA vez)

## Recarrega o dado do disco. Chamado sozinho no primeiro uso; exposto para o self-test.
static func reload() -> void:
	_data = {}
	_loaded = true
	_frames_cache.clear()
	_warned.clear()
	if not FileAccess.file_exists(READY_PATH):
		push_warning("[CombatAnimationRegistry] %s ausente — TUDO cai no procedural." % READY_PATH)
		return
	var txt := FileAccess.get_file_as_string(READY_PATH)
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[CombatAnimationRegistry] %s ilegível — TUDO cai no procedural." % READY_PATH)
		return
	_data = parsed

## ─────────────── SOBREPOSIÇÃO SÓ-DE-TESTE (ONDA 2) ───────────────
## ⛔ NÃO É UM BACKDOOR DE PRODUÇÃO. Nenhum código de jogo chama isto — só as suítes.
## Existe por um motivo concreto: o handoff reconciliado deixou ZERO entidades prontas, e sem isto
## seria impossível PROVAR que o caminho real funciona quando o portão abrir. Provar a mecânica não
## pode depender do humor do manifesto do Codex.
## ★★★ A suíte que usa isto é obrigada a checar, ANTES, que o portão de PRODUÇÃO está fechado.
static var _overlay: Dictionary = {}

static func apply_test_overlay(d: Dictionary) -> void:
	_ensure()
	_overlay = d
	_frames_cache.clear()
	_warned.clear()

static func clear_test_overlay() -> void:
	_overlay = {}
	_frames_cache.clear()
	_warned.clear()

static func test_overlay_active() -> bool:
	return not _overlay.is_empty()

## Travas de PRODUTO (morte/pesado do jogador, prioridade de transitório, interrupção).
## Independem do handoff: valem mesmo que o Codex marque tudo pronto.
static func policy() -> Dictionary:
	_ensure()
	var p = _data.get("policy", null)
	return p if typeof(p) == TYPE_DICTIONARY else {}

static func policy_flag(nome: String, padrao := false) -> bool:
	return bool(policy().get(nome, padrao))

## Prioridade de um transitório. Maior vence; igual substitui. Ver `policy.transient_priority`.
static func priority_of(action: String) -> int:
	var pr: Dictionary = policy().get("transient_priority", {})
	if action == "HIT":
		return int(pr.get("HIT", 2))
	if action == "DEATH":
		return int(pr.get("DOWNED_DEATH", 3))
	return int(pr.get("ATTACK", 1))

static func _ensure() -> void:
	if not _loaded:
		reload()

static func loaded() -> bool:
	_ensure()
	return not _data.is_empty()

## Entrada bruta de uma entidade. `kind` = "player" | "mobs".
static func entry(kind: String, id: String) -> Dictionary:
	_ensure()
	# a sobreposição de teste vence quando presente; em produção ela está sempre vazia
	if not _overlay.is_empty():
		var ob: Dictionary = _overlay.get(kind, {})
		var oe = ob.get(id, null)
		if typeof(oe) == TYPE_DICTIONARY:
			return oe
	var bucket: Dictionary = _data.get(kind, {})
	var e = bucket.get(id, null)
	return e if typeof(e) == TYPE_DICTIONARY else {}

## Status declarado (string do manifesto) ou "" se a entidade nem é conhecida.
static func status_of(kind: String, id: String) -> String:
	return str(entry(kind, id).get("status", ""))

## ★★★ PORTÃO. `ready` da entidade **E** a direção declarada para a ação. Nada de inferir por arquivo.
## Não confere disco aqui de propósito: prontidão é DECLARAÇÃO; a existência é conferida em `frames()`,
## que é onde a ausência tem consequência. Assim "declarado pronto mas sumiu do disco" vira aviso
## explícito no `frames()` em vez de virar um `false` mudo aqui.
static func is_ready(kind: String, id: String, action: String, direction := "BASE") -> bool:
	if not ACTIONS.has(action) or not DIRECTIONS.has(direction):
		return false
	var e := entry(kind, id)
	if e.is_empty() or not bool(e.get("ready", false)):
		return false
	var acts: Dictionary = e.get("actions", {})
	var a = acts.get(action, null)
	if typeof(a) != TYPE_DICTIONARY:
		return false
	return bool(a.get(direction, false))

## Caminho do strip. **Não** diz nada sobre prontidão — é só a convenção de nome.
## jogador: <player_dir>/<CLASSE>_<AÇÃO>_<DIR>.png · mob: <mob_dir>/<id>_<AÇÃO>_<DIR>.png
static func strip_path(kind: String, id: String, action: String, direction := "BASE") -> String:
	_ensure()
	if not ACTIONS.has(action) or not DIRECTIONS.has(direction):
		return ""
	if kind == "player":
		return "%s/%s_%s_%s.png" % [str(_data.get("player_dir", "")), id.to_upper(), action, direction]
	return "%s/%s_%s_%s.png" % [str(_data.get("mob_dir", "")), id, action, direction]

## Direção efetiva: se a pedida não estiver pronta, cai para BASE (documentado). "" = nada pronto.
## ★ É aqui que mora a regra "UP/SIDE ausente não pode apagar a animação" — degrada, não some.
static func resolve_direction(kind: String, id: String, action: String, wanted := "BASE") -> String:
	if is_ready(kind, id, action, wanted):
		return wanted
	if wanted != "BASE" and is_ready(kind, id, action, "BASE"):
		return "BASE"
	return ""

## Quadro de contato SUGERIDO (Parte 6) — **só apresentação**. Nunca move o dano.
## -1 quando não há sugestão para aquela ação.
static func contact_frame(kind: String, id: String, action: String) -> int:
	var acts: Dictionary = entry(kind, id).get("actions", {})
	var a = acts.get(action, null)
	if typeof(a) != TYPE_DICTIONARY:
		return -1
	return int(a.get("contact_frame", -1))

## Nome canônico da animação dentro do SpriteFrames do ator (estável = cacheável).
static func anim_name(kind: String, id: String, action: String, direction: String) -> String:
	return "cb_%s_%s_%s_%s" % [kind, id, action, direction]

static func _key(kind: String, id: String, action: String, direction: String) -> String:
	return "%s/%s/%s/%s" % [kind, id, action, direction]

## Avisa UMA vez por chave (Parte 14) — sem inundar o log a cada golpe.
static func _warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(msg)

## ★★★ O QUE O JOGO CONSOME. Retorna SpriteFrames pronto (1 anim "p", sem loop) ou **null**.
## null é resposta legítima e silenciosa na maioria dos casos: significa "usa o procedural".
## Só grita (uma vez) quando o dado PROMETEU e o disco não entregou — aí é defeito, não ausência.
static func frames(kind: String, id: String, action: String, direction := "BASE", fps := 12.0) -> SpriteFrames:
	var dir_ok := resolve_direction(kind, id, action, direction)
	if dir_ok == "":
		return null
	var key := _key(kind, id, action, dir_ok)
	if _frames_cache.has(key):
		return _frames_cache[key]           # Parte 13: sem tocar disco a cada ataque
	var path := strip_path(kind, id, action, dir_ok)
	if path == "" or not ResourceLoader.exists(path):
		_warn_once(key, "[CombatAnimationRegistry] '%s' marcado PRONTO mas o strip nao esta no disco: %s — caindo no procedural." % [key, path])
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		_warn_once(key, "[CombatAnimationRegistry] '%s' falhou ao carregar: %s — caindo no procedural." % [key, path])
		return null
	var h: int = tex.get_height()
	var w: int = tex.get_width()
	if h != FRAME_SIZE or w % h != 0 or (w / h) != FRAME_COUNT:
		_warn_once(key, "[CombatAnimationRegistry] '%s' viola o contrato (esperado %dx%d em %d quadros, veio %dx%d): %s" % [key, FRAME_SIZE * FRAME_COUNT, FRAME_SIZE, FRAME_COUNT, w, h, path])
		return null
	var sf := SpriteFrames.new()
	sf.add_animation("p")
	sf.set_animation_loop("p", false)
	sf.set_animation_speed("p", fps)
	for i in range(FRAME_COUNT):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * h, 0, h, h)
		sf.add_frame("p", at)
	_frames_cache[key] = sf
	return sf

## Diagnóstico para relatório/self-test: quantas entidades prontas por tipo.
static func ready_ids(kind: String) -> Array:
	_ensure()
	var out: Array = []
	var bucket: Dictionary = _data.get(kind, {})
	for id in bucket:
		# ⚠️ passa por `entry()` de propósito: senão este diagnóstico ignoraria a sobreposição e
		# passaria a MENTIR justamente nos testes que dependem dele.
		if bool(entry(kind, str(id)).get("ready", false)):
			out.append(id)
	if not _overlay.is_empty():
		var ob: Dictionary = _overlay.get(kind, {})
		for id in ob:
			if not out.has(id) and bool((ob[id] as Dictionary).get("ready", false)):
				out.append(id)
	out.sort()
	return out

static func cache_size() -> int:
	return _frames_cache.size()
