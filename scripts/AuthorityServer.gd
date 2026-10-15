class_name AuthorityServer extends RefCounted
## FATIA A11 — SERVIDOR AUTORITATIVO (headless, sem UI §89). ★ REGRA: o CLIENTE manda INTENÇÃO; o SERVIDOR VALIDA,
## EXECUTA (uma vez), PERSISTE e responde (§1/§13). Cliente NUNCA é autoridade de economia (§9): não escolhe
## gold/XP/Frag/loot/quality/rolls/refino-success/pity/Selo/Prestige/iid. Reusa a economia CONGELADA (A7.2) via o
## GameState como MOTOR de cálculo sobre o dict autoritativo por-character (mesma regra do single-player §55).
## Sessão única por character (§17), concorrência otimista por revision (§16), idempotência por command_id (§30),
## RNG do SERVIDOR (§33/§38), ServerClock (§59). Metadados (revision/lease/journal/iid) vivem fora do save (§63).

var _repo: CharacterRepository
var _items: ItemRegistry
var _clock: ServerClock
var _sessions: Dictionary = {}     # session_id → {account, character, acquired_at, last_heartbeat}
var _leases: Dictionary = {}       # character_id → session_id (SINGLE-SESSION §17)
var _journal: Dictionary = {}      # command_id → {status, result, revision}
var _journal_order: Array = []     # FIFO p/ retenção limitada (§79)
var _rate: Dictionary = {}         # account → Array[timestamp] (rate limit §58)
var _rng := RandomNumberGenerator.new()
var _sid_counter := 0

# ── A11.1: instrumentação de SERIALIZAÇÃO do motor GameState (§11/§15/§16/§66) ──
var _gs_active := 0              # nº de _with_gs em execução — INVARIANTE: nunca > 1 (interleave sentinel §66)
var _gs_active_peak := 0         # pico observado (teste prova == 1)
var _gs_events: Array = []       # log ordenado ENTER:<char>/EXIT:<char> — bem-aninhado prova não-interleave

const LEASE_TTL := 30              # s de lease sem heartbeat → expira (§18/§53)
const JOURNAL_CAP := 4096         # retenção do journal (§79) — não cresce infinito
const RATE_MAX := 100             # comandos por janela
const RATE_WINDOW := 1            # s (§58: não aceitar 500 refines/s)

func setup(repo: CharacterRepository, items: ItemRegistry, clock: ServerClock, rng_seed: int = 20260903) -> void:
	_repo = repo
	_items = items
	_clock = clock
	_rng.seed = rng_seed   # RNG do SERVIDOR, seedável em teste (§38); NUNCA fornecido pelo cliente (§33)

func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null

# ══════════════ AUTH (DEV_ONLY — NOT_PRODUCTION_AUTH §6/§7) ══════════════
## Stub de autenticação local/dev. Produção futura usará AuthProvider real; aqui a "credencial" JÁ é a conta.
func authenticate(account_id: String) -> Dictionary:
	if account_id == "":
		return {"ok": false, "reason": "NO_ACCOUNT"}
	return {"ok": true, "account_id": account_id, "dev_only": true}

# ══════════════ SESSÃO (single-session lease + heartbeat + expiry) ══════════════
func open_session(account_id: String, character_id: String) -> Dictionary:
	# §50 hijack: a conta é DONA do character?
	if not _repo.owns(account_id, character_id):
		return {"ok": false, "reason": "NOT_OWNER"}
	# §17/§52: 1 character = 1 sessão ativa. Se há lease VIVO de OUTRA sessão → recusa.
	if _leases.has(character_id):
		var holder := str(_leases[character_id])
		if _sessions.has(holder) and not _is_expired(holder):
			return {"ok": false, "reason": "SESSION_IN_USE"}
		# lease expirado (crash §53) → pode assumir; libera o velho
		_release_session(holder)
	_sid_counter += 1
	var sid := "sess_%d" % _sid_counter
	var now := _clock.now()
	_sessions[sid] = {"account": account_id, "character": character_id, "acquired_at": now, "last_heartbeat": now}
	_leases[character_id] = sid
	return {"ok": true, "session_id": sid, "revision": _repo.revision_of(character_id)}

func heartbeat(session_id: String) -> bool:
	if not _sessions.has(session_id) or _is_expired(session_id):
		return false
	_sessions[session_id]["last_heartbeat"] = _clock.now()
	return true

## Disconnect (§19): encerra a sessão, libera o lease. Flush é implícito (estado já persistido por comando).
func close_session(session_id: String) -> void:
	_release_session(session_id)

func _release_session(session_id: String) -> void:
	if not _sessions.has(session_id):
		return
	var cid := str(_sessions[session_id]["character"])
	if _leases.get(cid, "") == session_id:
		_leases.erase(cid)
	_sessions.erase(session_id)

func _is_expired(session_id: String) -> bool:
	if not _sessions.has(session_id):
		return true
	return _clock.now() > int(_sessions[session_id]["last_heartbeat"]) + LEASE_TTL

func session_active(session_id: String) -> bool:
	return _sessions.has(session_id) and not _is_expired(session_id)

# ══════════════ COMANDO CRÍTICO (valida → executa 1× → persiste → journal) ══════════════
func submit(session_id: String, command: Dictionary) -> Dictionary:
	# 1) sessão válida e não expirada
	if not session_active(session_id):
		return {"ok": false, "reason": "NO_SESSION"}
	var sess: Dictionary = _sessions[session_id]
	return _submit_core(str(sess["character"]), str(sess["account"]), command, false)

## A11.1 — caminho INTERNO/ADMIN (§57/§58): GRANT_LOOT/CLEAR_BOSS server-side. SEM sessão, SEM rate limit; ainda
## idempotente por command_id. NUNCA alcançável pelo caminho COMMAND de um cliente comum (o parser nega, §59).
func submit_internal(character_id: String, command: Dictionary) -> Dictionary:
	var account := _repo.owner_of(character_id)
	if account == "":
		return {"ok": false, "reason": "NO_CHARACTER"}
	return _submit_core(character_id, account, command, true)

## Núcleo compartilhado (idempotência → rate → load → dispatch → persist otimista → journal). `internal` pula rate.
func _submit_core(character: String, account: String, command: Dictionary, internal: bool) -> Dictionary:
	# 2) command_id obrigatório em operação crítica (§29/CMD-T01)
	var cid := str(command.get("command_id", ""))
	if cid == "":
		return {"ok": false, "reason": "NO_COMMAND_ID"}
	# 3) idempotência (§30): já aplicado? devolve o resultado anterior, NÃO re-executa (§34/§75)
	if _journal.has(cid):
		var j: Dictionary = _journal[cid]
		return {"ok": bool(j["status"] == "ok"), "result": j.get("result", {}), "revision": int(j.get("revision", -1)), "duplicate": true}
	# 4) rate limit (§58) — só no caminho de rede/sessão
	if not internal and not _rate_ok(account):
		return {"ok": false, "reason": "RATE_LIMITED"}
	# 5) carrega estado autoritativo
	var ld := _repo.load(character)
	if not bool(ld["ok"]):
		return {"ok": false, "reason": "NO_CHARACTER"}
	var state: Dictionary = ld["state"]
	var rev := int(ld["revision"])
	# 6) executa o comando (transação em CÓPIA; só persiste no commit §28/§76)
	var tx := _dispatch(str(command.get("type", "")), command, state, account, cid)
	if not bool(tx.get("ok", false)):
		return {"ok": false, "reason": str(tx.get("reason", "REJECTED"))}   # inválido → NÃO persiste, NÃO journaliza
	# 7) persiste com concorrência otimista (§16). STALE → NÃO commita, NÃO journaliza (retry pode reexecutar §76)
	var sv := _repo.save(character, rev, tx["state"])
	if not bool(sv["ok"]):
		return {"ok": false, "reason": str(sv.get("reason", "STALE")), "current_revision": int(sv.get("current_revision", rev))}
	# 8) SÓ agora (após commit) registra no journal → idempotência de retry (§31/§75)
	_journal_record(cid, "ok", tx.get("result", {}), int(sv["revision"]))
	return {"ok": true, "result": tx.get("result", {}), "revision": int(sv["revision"]), "view": client_view(character)}

## Dispatch por tipo. Cada comando roda a economia CONGELADA sobre a cópia do estado; devolve {ok, state, result}.
func _dispatch(t: String, cmd: Dictionary, state: Dictionary, account: String, cid: String) -> Dictionary:
	match t:
		"REFINE_SLOT": return _cmd_refine(cmd, state, cid)
		"CLAIM_OFFLINE": return _cmd_claim_offline(cmd, state)
		"PRESTIGE": return _cmd_prestige(cmd, state)
		"GRANT_LOOT": return _cmd_grant_loot(cmd, state, account, cid)
		"EQUIP_INSTANCE": return _cmd_equip(cmd, state, account)
		"CLEAR_BOSS": return _cmd_clear_boss(cmd, state)
		_: return {"ok": false, "reason": "UNKNOWN_COMMAND"}

# ── motor: aplica uma operação econômica no GameState scratch sobre `state`, captura o novo estado ──
func _with_gs(state: Dictionary, op: Callable, label: String = "") -> Dictionary:
	var gs = _gs()
	if gs == null:
		return {"ok": false, "reason": "NO_ENGINE"}
	# §16/§66: NUNCA reentrar. Só UMA operação econômica pode estar dentro do GameState singleton por vez. Se algo
	# tentar iniciar B enquanto A ainda não restaurou, recusa — a fila (AuthorityCommandQueue) é quem serializa.
	if _gs_active != 0:
		return {"ok": false, "reason": "REENTRANT_GS"}
	_gs_active += 1
	_gs_active_peak = maxi(_gs_active_peak, _gs_active)
	_gs_events.append("ENTER:" + label)
	# duplicate(true): to_dict devolve arrays por REFERÊNCIA; apply_dict os limpa → sem cópia profunda, corromperia.
	var backup: Dictionary = gs.to_dict().duplicate(true)
	gs.apply_dict(state)
	var result = op.call(gs)   # roda refine_attempt/grant_cycle_seal/etc. — a MESMA economia do single-player
	var new_state: Dictionary = gs.to_dict().duplicate(true)
	gs.apply_dict(backup)      # restaura o singleton (o autoritativo vive no repo) — SEMPRE executa (§15)
	_gs_events.append("EXIT:" + label)
	_gs_active -= 1
	return {"ok": true, "state": new_state, "result": result}

# ── instrumentação p/ os testes de concorrência (§66/CONC-T01..T04) ──
func gs_active() -> int: return _gs_active
func gs_active_peak() -> int: return _gs_active_peak
func gs_events() -> Array: return _gs_events.duplicate()
func gs_events_well_nested() -> bool:
	# bem-aninhado = cada ENTER é imediatamente seguido do seu EXIT (nunca ENTER,ENTER): prova ZERO interleave.
	var depth := 0
	for e in _gs_events:
		if str(e).begins_with("ENTER:"):
			depth += 1
			if depth > 1: return false
		else:
			depth -= 1
	return depth == 0

# ── COMANDOS ──
## REFINO: o SERVIDOR decide RNG (roll01), lê Fragmentos/pity/suporte do estado. Cliente NÃO manda roll01 (§33).
func _cmd_refine(cmd: Dictionary, state: Dictionary, cid: String) -> Dictionary:
	var slot := str(cmd.get("slot", ""))
	var catalyst := str(cmd.get("catalyst", ""))
	var preserve := bool(cmd.get("preserve", false))
	var absolute := bool(cmd.get("absolute", false))
	var roll := _server_roll()   # RNG do SERVIDOR (§32/§38) — determinístico por seed, opaco ao cliente
	var r := _with_gs(state, func(gs): return gs.refine_attempt(slot, catalyst, preserve, absolute, roll))
	if not bool(r["ok"]):
		return r
	return {"ok": true, "state": r["state"], "result": r["result"]}

## OFFLINE CLAIM: SERVIDOR lê o pending AUTORITATIVO; cliente NÃO informa duração (§35). Aplica ouro/XP e limpa.
func _cmd_claim_offline(_cmd: Dictionary, state: Dictionary) -> Dictionary:
	var pend: Dictionary = state.get("offline_pending", {}) if state.get("offline_pending", {}) is Dictionary else {}
	if pend.is_empty():
		return {"ok": true, "state": state, "result": {"claimed": false}}
	var r := _with_gs(state, func(gs):
		var g := int(pend.get("gold", 0)); var x := int(pend.get("xp", 0))
		if g > 0: gs.add_gold(g)
		if x > 0: gs.add_xp(x)
		var mats: Dictionary = pend.get("materials", {}) if pend.get("materials", {}) is Dictionary else {}
		for nm in mats: gs.add_material_silent(str(nm), int(mats[nm]))
		gs.offline_pending = {}
		return {"claimed": true, "gold": g, "xp": x})
	return {"ok": true, "state": r["state"], "result": r["result"]}

## PRESTÍGIO: SERVIDOR valida elegibilidade (stage/selos + sem baú pendente) e executa 1×. Cliente não força (§40).
func _cmd_prestige(_cmd: Dictionary, state: Dictionary) -> Dictionary:
	var p := int(state.get("prestige_count", 0))
	var seals := int(state.get("cycle_seals", 0))
	var hi := int(state.get("cycle_seal_high", 0))
	var chapter := int(state.get("stage_chapter", 1)); var idx := int(state.get("stage_index", 1))
	var highest := maxi(int(state.get("stage_highest_global", (chapter - 1) * 10 + idx)), (chapter - 1) * 10 + idx)
	var need_stage := PrestigeMath.required_stage(p)
	var need_seals := PrestigeMath.required_seals(p)
	var pend: Dictionary = state.get("offline_pending", {}) if state.get("offline_pending", {}) is Dictionary else {}
	if not pend.is_empty():
		return {"ok": false, "reason": "OFFLINE_PENDING"}
	if highest < need_stage or seals < need_seals:
		return {"ok": false, "reason": "NOT_ELIGIBLE"}
	# executa via GameState (reset de ciclo idêntico à regra A6, sem tocar nível/equip/lifetime)
	var r := _with_gs(state, func(gs):
		gs.prestige_count = p + 1
		gs.master_level = int(gs.master_level) + 1
		gs.lifetime_highest_stage = maxi(int(gs.lifetime_highest_stage), highest)
		gs.cycle_seals = 0; gs.cycle_seal_high = 0
		gs.stage_chapter = 1; gs.stage_index = 1; gs.stage_kills = 0; gs.stage_highest_global = 1
		gs.stage_mode = "advance"; gs.stage_wall_active = false; gs.stage_fails = 0
		gs.cycle_encounter_high = 0
		return {"prestige": p + 1, "master": int(gs.master_level)})
	return {"ok": true, "state": r["state"], "result": r["result"]}

## LOOT: o SERVIDOR gera o iid e ROLA a instância (seed do servidor). Cliente não injeta iid/quality/rolls (§37).
func _cmd_grant_loot(cmd: Dictionary, state: Dictionary, account: String, cid: String) -> Dictionary:
	var item_id := str(cmd.get("item_id", ""))
	if not ItemDB.exists(item_id) or not ItemDB.is_equippable(item_id):
		return {"ok": false, "reason": "INVALID_ITEM"}
	var iid := _items.next_iid()                 # iid AUTORITATIVO do servidor (§23)
	var seed := int(_rng.randi())                # seed do SERVIDOR (§38), opaco ao cliente
	var inst: Dictionary = ItemRoller.roll(item_id, seed, "online", 0)
	inst["iid"] = iid                            # sobrescreve com o iid do servidor
	var new_state := state.duplicate(true)
	var arr: Array = new_state.get("item_instances", [])
	arr = arr.duplicate(); arr.append(inst); new_state["item_instances"] = arr
	_items.register(iid, account, item_id, ItemRegistry.LOC_PLAYER)   # dono ÚNICO (§24/§25)
	return {"ok": true, "state": new_state, "result": {"iid": iid, "item_id": item_id, "quality": int(inst.get("quality", 0))}}

## EQUIP: valida DONO do iid (§42/§43) + não destruído; move p/ EQUIPPED. Rejeita item de outro player.
func _cmd_equip(cmd: Dictionary, state: Dictionary, account: String) -> Dictionary:
	var iid := str(cmd.get("iid", ""))
	if not _items.exists(iid):
		return {"ok": false, "reason": "NO_ITEM"}
	if not _items.is_owned_by(iid, account):
		return {"ok": false, "reason": "NOT_OWNER"}   # §43: não equipa item de outro player
	if _items.location_of(iid) == ItemRegistry.LOC_DESTROYED:
		return {"ok": false, "reason": "DESTROYED"}
	_items.move(iid, ItemRegistry.LOC_EQUIPPED)
	# reflete no estado (equipped_instances por slot do item)
	var slot := ItemDB.slot_of(_items.item_id_of(iid))
	var new_state := state.duplicate(true)
	var eq: Dictionary = (new_state.get("equipped_instances", {}) as Dictionary).duplicate()
	eq[slot] = iid; new_state["equipped_instances"] = eq
	return {"ok": true, "state": new_state, "result": {"equipped": iid, "slot": slot}}

## BOSS CLEAR: SERVIDOR concede Selo/support/narrative unlock exato-uma-vez (watermark) — evento duplicado não duplica.
func _cmd_clear_boss(cmd: Dictionary, state: Dictionary) -> Dictionary:
	var g := int(cmd.get("global_stage", 0))
	var r := _with_gs(state, func(gs):
		var got: bool = gs.grant_cycle_seal(g)
		gs.grant_encounter_reward(g, g ^ 0x51ED)
		return {"seal_granted": got, "cycle_seals": int(gs.cycle_seals)})
	return {"ok": true, "state": r["state"], "result": r["result"]}

# ── RNG do servidor (determinístico por seed; opaco ao cliente) ──
func _server_roll() -> float:
	return _rng.randf()

# ── rate limit ──
func _rate_ok(account: String) -> bool:
	var now := _clock.now()
	var lst: Array = _rate.get(account, [])
	var keep: Array = []
	for t in lst:
		if int(t) > now - RATE_WINDOW:
			keep.append(t)
	if keep.size() >= RATE_MAX:
		_rate[account] = keep
		return false
	keep.append(now)
	_rate[account] = keep
	return true

# ── journal idempotente com retenção limitada (§31/§79) ──
func _journal_record(cid: String, status: String, result: Dictionary, revision: int) -> void:
	_journal[cid] = {"status": status, "result": result, "revision": revision}
	_journal_order.append(cid)
	while _journal_order.size() > JOURNAL_CAP:
		var old = _journal_order.pop_front()
		_journal.erase(old)

func journal_size() -> int:
	return _journal.size()

# ── snapshot/restore do servidor (RESTART §77): journal committed sobrevive → comando não reaplica ──
func snapshot() -> Dictionary:
	return {"journal": _journal.duplicate(true), "order": _journal_order.duplicate(), "sid": _sid_counter}

func restore(snap: Dictionary) -> void:
	_journal = (snap.get("journal", {}) as Dictionary)
	_journal_order = (snap.get("order", []) as Array)
	_sid_counter = int(snap.get("sid", 0))
	# leases/sessions NÃO sobrevivem ao restart (transporte é temporário §66/SESS-T08) — começam vazios.

# ══════════════ A12 — POWER SNAPSHOT (CP autoritativo via motor; §49/§50/§100) ══════════════
## Computa o CP OFICIAL (PowerBudget) do estado autoritativo de um character, via o mesmo motor _with_gs (serializado).
## NUNCA usa stats vindos do cliente (§100). Devolve cp/offense/effective_hp + prestige/highest_stage + revision.
func power_snapshot(character_id: String) -> Dictionary:
	var ld := _repo.load(character_id)
	if not bool(ld["ok"]):
		return {}
	var state: Dictionary = ld["state"]
	var r := _with_gs(state, func(gs): return {"cp": PowerBudget.cp(), "offense": PowerBudget.offense(), "effective_hp": PowerBudget.effective_hp()}, "cp")
	if not bool(r["ok"]):
		return {}
	var out: Dictionary = r["result"]
	out["prestige"] = int(state.get("prestige_count", 0))
	out["highest_stage"] = int(state.get("stage_highest_global", 1))
	out["revision"] = int(ld["revision"])
	return out

# ══════════════ CLIENT VIEW — DTO seguro (sem campos privados do servidor §20/§21) ══════════════
func client_view(character_id: String) -> Dictionary:
	var ld := _repo.load(character_id)
	if not bool(ld["ok"]):
		return {}
	var s: Dictionary = ld["state"]
	# só o que o cliente precisa p/ apresentar; NADA de rng seed/journal/revision-internals/anti-dupe/validation.
	return {
		"revision": int(ld["revision"]),
		"level": int(s.get("hero_level", 1)),
		"gold": int(s.get("hero_gold", 0)),
		"xp": int(s.get("hero_xp", 0)),
		"fragments": int((s.get("materials", {}) as Dictionary).get("Fragmentos", 0)),
		"stage_chapter": int(s.get("stage_chapter", 1)),
		"stage_index": int(s.get("stage_index", 1)),
		"cycle_seals": int(s.get("cycle_seals", 0)),
		"prestige": int(s.get("prestige_count", 0)),
		"master": int(s.get("master_level", 0)),
		"equipment": (s.get("equipment", {}) as Dictionary).duplicate(),
		"equipped_instances": (s.get("equipped_instances", {}) as Dictionary).duplicate(),
		"item_count": (s.get("item_instances", []) as Array).size(),
	}
