class_name TradeService extends RefCounted
## FATIA A11.2 — TRADE P2P SEGURO (backend/authority §8). ★ TRADE É SERVER-AUTHORITATIVE (§5): o cliente oferece
## iid/gold/accept; o servidor resolve o item pelo iid, move para ESCROW real (§26), versiona a oferta (§19), reseta
## a confirmação a cada mudança (§20 anti bait-and-switch) e faz UM commit ATÔMICO multi-character (§42). Escrow e
## revisions vivem no TradeRepository/CharacterRepository (fora do save §113). Idempotência por command_id (§62-65).
## GOLD ONLY como moeda (§33 — Fragmentos/materiais NÃO viajam). Slot-refine/Master/Bestiário/Códice NÃO viajam
## (§7/§37): só a INSTÂNCIA (iid/quality/rolls/affixes). Não é Marketplace/Auction/PvP (§90).

const INVITED := "INVITED"
const NEGOTIATING := "NEGOTIATING"
const COMMITTING := "COMMITTING"
const COMPLETED := "COMPLETED"
const DECLINED := "DECLINED"
const CANCELLED := "CANCELLED"
const EXPIRED := "EXPIRED"
const FAILED := "FAILED"
const TERMINAL := [COMPLETED, DECLINED, CANCELLED, EXPIRED, FAILED]

const MAX_ITEMS_PER_SIDE := 8       # §18 — limite pequeno V1
const RECIPIENT_ITEM_CAP := 30      # §47 — espelha BACKPACK_CAPACITY (item_instances = bolsa de equipáveis)
const INVITE_TTL := 60              # §15 — janela do convite (ServerClock)
const NEGOTIATE_TTL := 300          # §37 — janela de negociação sem atividade

var repo: CharacterRepository
var items: ItemRegistry
var trades: TradeRepository
var clock: ServerClock
var _journal: Dictionary = {}       # command_id → resultado (idempotência §62-65)
var audit_log: Array = []
var _fault := ""                    # injeção de falha p/ testes de crash-during (§67)

func setup(p_repo: CharacterRepository, p_items: ItemRegistry, p_trades: TradeRepository, p_clock: ServerClock) -> void:
	repo = p_repo; items = p_items; trades = p_trades; clock = p_clock

func set_fault(f: String) -> void: _fault = f   # só testes

func _dup(cid: String) -> Dictionary:
	if cid != "" and _journal.has(cid):
		var r: Dictionary = (_journal[cid] as Dictionary).duplicate(true)
		r["duplicate"] = true
		return r
	return {}

func _remember(cid: String, res: Dictionary) -> Dictionary:
	if cid != "" and bool(res.get("ok", false)):
		_journal[cid] = res.duplicate(true)
	return res

## ItemRegistry chaveia posse por CONTA (§A11); trade opera por CHARACTER. Converte aqui (1 conta↔1 char no harness).
func _acct(character: String) -> String:
	return repo.owner_of(character)

func _side_of(trade: Dictionary, actor: String) -> String:
	if str(trade["a"]) == actor: return "a"
	if str(trade["b"]) == actor: return "b"
	return ""

func _other(side: String) -> String:
	return "b" if side == "a" else "a"

func _now() -> int: return clock.now()

# ══════════════ INVITE (§14) ══════════════
func invite(actor: String, command_id: String, target: String) -> Dictionary:
	var dup := _dup(command_id)
	if not dup.is_empty(): return dup
	if target == "" or not repo._store.has(target):
		return {"ok": false, "reason": "TARGET_NOT_FOUND"}
	if target == actor:
		return {"ok": false, "reason": "SELF_TRADE"}                 # §12
	if trades.active_trade_of(actor) != "" or trades.active_trade_of(target) != "":
		return {"ok": false, "reason": "ALREADY_IN_TRADE"}          # §17
	var tid := trades.new_trade_id()                                 # §10 server-side
	var rec := {
		"trade_id": tid, "a": actor, "b": target, "state": INVITED, "offer_version": 1,
		"offers": {"a": {"items": [], "gold": 0}, "b": {"items": [], "gold": 0}},
		"escrow_instances": {}, "escrow_gold": {"a": 0, "b": 0},
		"accept": {"a": -1, "b": -1}, "created_at": _now(), "updated_at": _now(),
		"expires_at": _now() + INVITE_TTL,
	}
	trades.put(rec); trades.set_active(actor, tid); trades.set_active(target, tid)
	return _remember(command_id, {"ok": true, "trade_id": tid, "view": view_for(tid, actor)})

func accept_invite(actor: String, command_id: String, trade_id: String) -> Dictionary:
	var dup := _dup(command_id)
	if not dup.is_empty(): return dup
	var g := _guard(trade_id, actor, [INVITED])
	if not bool(g["ok"]): return g
	var t: Dictionary = g["trade"]
	if actor != str(t["b"]):
		return {"ok": false, "reason": "NOT_TARGET"}                 # §16 só o alvo aceita
	t["state"] = NEGOTIATING; t["expires_at"] = _now() + NEGOTIATE_TTL; t["updated_at"] = _now()
	trades.put(t)
	return _remember(command_id, {"ok": true, "view": view_for(trade_id, actor)})

func decline(actor: String, command_id: String, trade_id: String) -> Dictionary:
	var dup := _dup(command_id)
	if not dup.is_empty(): return dup
	var g := _guard(trade_id, actor, [INVITED, NEGOTIATING])
	if not bool(g["ok"]): return g
	var t: Dictionary = g["trade"]
	_refund_all(t)                                                   # nada em escrow no INVITED; seguro se houver
	t["state"] = DECLINED; t["updated_at"] = _now()
	_terminate(t)
	return _remember(command_id, {"ok": true, "view": view_for(trade_id, actor)})

# ══════════════ OFERTA — ITEM (§23-29) ══════════════
func add_item(actor: String, command_id: String, trade_id: String, iid: String) -> Dictionary:
	var dup := _dup(command_id)
	if not dup.is_empty(): return dup
	var g := _guard(trade_id, actor, [NEGOTIATING])
	if not bool(g["ok"]): return g
	var t: Dictionary = g["trade"]
	var side := _side_of(t, actor)
	if (t["offers"][side]["items"] as Array).size() >= MAX_ITEMS_PER_SIDE:
		return {"ok": false, "reason": "OFFER_FULL"}                 # §18
	if items.exists(iid) and items.is_in_escrow(iid):
		return {"ok": false, "reason": "ALREADY_IN_ESCROW"}         # §59 — já travado (nesta ou outra trade)
	# resolve o estado do personagem e a instância
	var ld := repo.load(actor)
	var state: Dictionary = ld["state"]
	var idx := _find_instance(state, iid)
	if idx < 0:
		return {"ok": false, "reason": "ITEM_NOT_FOUND"}            # não está na bolsa do jogador (equipado? §24)
	var inst: Dictionary = (state["item_instances"] as Array)[idx]
	var acct := _acct(actor)
	# elegibilidade (§23): tradeable, não bound, não em escrow, não destruído
	if not ItemInstance.is_tradeable(inst):
		return {"ok": false, "reason": "NOT_TRADEABLE"}            # §72/§73 bound/tradeable=false
	# materialização de legado server-side, uma vez (§25) — nunca aceita iid do cliente como novo
	if not items.exists(iid):
		items.register(iid, acct, str(inst.get("item_id", "")), ItemRegistry.LOC_PLAYER)
	if items.is_in_escrow(iid):
		return {"ok": false, "reason": "ALREADY_IN_ESCROW"}        # §59 double-trade
	if not items.is_owned_by(iid, acct) or items.location_of(iid) != ItemRegistry.LOC_PLAYER:
		return {"ok": false, "reason": "ITEM_NOT_ELIGIBLE"}
	# MOVE para escrow (§26): sai da bolsa do jogador; guarda a instância exata (§28)
	if not items.to_escrow(iid, trade_id, acct):
		return {"ok": false, "reason": "ESCROW_FAILED"}
	(state["item_instances"] as Array).remove_at(idx)
	t["escrow_instances"][iid] = inst.duplicate(true)
	(t["offers"][side]["items"] as Array).append(iid)
	var sv := repo.save(actor, int(ld["revision"]), state)
	if not bool(sv["ok"]):
		# reverte o escrow se o save falhar (nada fica pela metade)
		items.from_escrow(iid, acct); (t["offers"][side]["items"] as Array).erase(iid); t["escrow_instances"].erase(iid)
		return {"ok": false, "reason": "STALE"}
	_bump_offer(t)                                                   # §19 version++ + §20 reset accept
	return _remember(command_id, {"ok": true, "view": view_for(trade_id, actor)})

func remove_item(actor: String, command_id: String, trade_id: String, iid: String) -> Dictionary:
	var dup := _dup(command_id)
	if not dup.is_empty(): return dup
	var g := _guard(trade_id, actor, [NEGOTIATING])
	if not bool(g["ok"]): return g
	var t: Dictionary = g["trade"]
	var side := _side_of(t, actor)
	if not (t["offers"][side]["items"] as Array).has(iid):
		return {"ok": false, "reason": "NOT_IN_OFFER"}
	# devolve à bolsa do dono (§29) atomicamente
	var ld := repo.load(actor)
	var state: Dictionary = ld["state"]
	if not items.from_escrow(iid, _acct(actor)):
		return {"ok": false, "reason": "ESCROW_RETURN_FAILED"}
	(state["item_instances"] as Array).append((t["escrow_instances"][iid] as Dictionary).duplicate(true))
	t["escrow_instances"].erase(iid)
	(t["offers"][side]["items"] as Array).erase(iid)
	var sv := repo.save(actor, int(ld["revision"]), state)
	if not bool(sv["ok"]):
		return {"ok": false, "reason": "STALE"}
	_bump_offer(t)
	return _remember(command_id, {"ok": true, "view": view_for(trade_id, actor)})

# ══════════════ OFERTA — OURO (§30-33) ══════════════
func set_gold(actor: String, command_id: String, trade_id: String, amount: int) -> Dictionary:
	var dup := _dup(command_id)
	if not dup.is_empty(): return dup
	var g := _guard(trade_id, actor, [NEGOTIATING])
	if not bool(g["ok"]): return g
	var t: Dictionary = g["trade"]
	if amount < 0:
		return {"ok": false, "reason": "GOLD_NEGATIVE"}            # §32
	var side := _side_of(t, actor)
	var cur_escrow := int(t["escrow_gold"][side])
	var delta := amount - cur_escrow                                # §31 ajusta o delta
	var ld := repo.load(actor)
	var state: Dictionary = ld["state"]
	var hero_gold := int(state.get("hero_gold", 0))
	if delta > 0 and hero_gold < delta:
		return {"ok": false, "reason": "GOLD_INSUFFICIENT"}       # §32 acima do disponível
	state["hero_gold"] = hero_gold - delta                          # >0 sai da carteira; <0 volta (§30)
	t["escrow_gold"][side] = amount
	(t["offers"][side] as Dictionary)["gold"] = amount
	var sv := repo.save(actor, int(ld["revision"]), state)
	if not bool(sv["ok"]):
		return {"ok": false, "reason": "STALE"}
	_bump_offer(t)
	return _remember(command_id, {"ok": true, "view": view_for(trade_id, actor)})

# ══════════════ ACCEPT / COMMIT (§21/§42) ══════════════
func accept_offer(actor: String, command_id: String, trade_id: String, offer_version: int) -> Dictionary:
	var dup := _dup(command_id)
	if not dup.is_empty(): return dup
	var g := _guard(trade_id, actor, [NEGOTIATING])
	if not bool(g["ok"]): return g
	var t: Dictionary = g["trade"]
	if offer_version != int(t["offer_version"]):
		return {"ok": false, "reason": "OFFER_CHANGED", "view": view_for(trade_id, actor)}  # §21 versão velha
	var side := _side_of(t, actor)
	t["accept"][side] = int(t["offer_version"])
	trades.put(t)
	# ambos aceitaram a versão ATUAL? → commit atômico (§64 apenas UM)
	if int(t["accept"]["a"]) == int(t["offer_version"]) and int(t["accept"]["b"]) == int(t["offer_version"]):
		var commit_res := _commit_atomic(t)
		return _remember(command_id, commit_res)
	return _remember(command_id, {"ok": true, "accepted": true, "view": view_for(trade_id, actor)})

func cancel(actor: String, command_id: String, trade_id: String) -> Dictionary:
	var dup := _dup(command_id)
	if not dup.is_empty(): return dup
	var g := _guard(trade_id, actor, [INVITED, NEGOTIATING, COMMITTING])
	if not bool(g["ok"]): return g
	var t: Dictionary = g["trade"]
	_refund_all(t)                                                  # §38/§39 exact-once
	t["state"] = CANCELLED; t["updated_at"] = _now()
	_terminate(t)
	return _remember(command_id, {"ok": true, "view": view_for(trade_id, actor)})

# ── COMMIT ATÔMICO (§42-51) ──
func _commit_atomic(t: Dictionary) -> Dictionary:
	t["state"] = COMMITTING
	var a := str(t["a"]); var b := str(t["b"])
	var items_a: Array = t["offers"]["a"]["items"]      # itens que A ofereceu → vão p/ B
	var items_b: Array = t["offers"]["b"]["items"]      # itens que B ofereceu → vão p/ A
	var gold_a := int(t["escrow_gold"]["a"])
	var gold_b := int(t["escrow_gold"]["b"])
	# capacidade dos recipientes (§47/§48)
	var lda := repo.load(a); var ldb := repo.load(b)
	var state_a: Dictionary = lda["state"]; var state_b: Dictionary = ldb["state"]
	var rev_a := int(lda["revision"]); var rev_b := int(ldb["revision"])
	if (state_b["item_instances"] as Array).size() + items_a.size() > RECIPIENT_ITEM_CAP:
		t["state"] = NEGOTIATING; _reset_accept(t); trades.put(t)
		return {"ok": false, "reason": "RECIPIENT_NO_CAPACITY", "view": view_for(t["trade_id"], a)}
	if (state_a["item_instances"] as Array).size() + items_b.size() > RECIPIENT_ITEM_CAP:
		t["state"] = NEGOTIATING; _reset_accept(t); trades.put(t)
		return {"ok": false, "reason": "RECIPIENT_NO_CAPACITY", "view": view_for(t["trade_id"], a)}
	# monta os estados novos: A recebe itens/ouro de B; B recebe de A (§50/§51)
	var new_a := state_a.duplicate(true); var new_b := state_b.duplicate(true)
	for iid in items_b:
		(new_a["item_instances"] as Array).append((t["escrow_instances"][iid] as Dictionary).duplicate(true))
	for iid in items_a:
		(new_b["item_instances"] as Array).append((t["escrow_instances"][iid] as Dictionary).duplicate(true))
	new_a["hero_gold"] = int(new_a.get("hero_gold", 0)) + gold_b
	new_b["hero_gold"] = int(new_b.get("hero_gold", 0)) + gold_a
	# ATÔMICO: snapshot do registry → move iids escrow→recipiente → commit_many dos estados. Falhou? restaura tudo.
	var reg_snap := items.snapshot()
	for iid in items_a: items.from_escrow(iid, _acct(b))   # itens de A → B
	for iid in items_b: items.from_escrow(iid, _acct(a))   # itens de B → A
	# ponto de falha simulada (crash-during §67): registry já movido, estados ainda NÃO → deve reverter p/ before
	if _fault == "AFTER_REGISTRY":
		items.restore(reg_snap)
		t["state"] = NEGOTIATING; _reset_accept(t); trades.put(t)
		return {"ok": false, "reason": "FAULT_ROLLED_BACK", "view": view_for(t["trade_id"], a)}
	var cm := repo.commit_many({a: rev_a, b: rev_b}, {a: new_a, b: new_b})
	if not bool(cm["ok"]):
		items.restore(reg_snap)                       # §46 STALE → zero commit; registry volta
		t["state"] = NEGOTIATING; _reset_accept(t); trades.put(t)
		return {"ok": false, "reason": "STALE_TRADE_STATE", "view": view_for(t["trade_id"], a)}
	# sucesso — trade terminal COMPLETED (§10 ATOM-T10)
	t["state"] = COMPLETED; t["updated_at"] = _now()
	t["result_revisions"] = cm["revisions"]
	_audit(t, gold_a, gold_b, items_a, items_b)
	_terminate(t)
	return {"ok": true, "completed": true, "trade_id": t["trade_id"], "revisions": cm["revisions"], "view": view_for(t["trade_id"], a)}

# ── refund exact-once (cancel/expiry §37/§38/§39) ──
func _refund_all(t: Dictionary) -> void:
	for side in ["a", "b"]:
		var owner := str(t[side])
		# itens: escrow → dono original (1×)
		var its: Array = (t["offers"][side]["items"] as Array).duplicate()
		for iid in its:
			if items.is_in_escrow(iid) and items.escrow_trade_of(iid) == str(t["trade_id"]):
				var ld := repo.load(owner)
				var state: Dictionary = ld["state"]
				items.from_escrow(iid, _acct(owner))
				if t["escrow_instances"].has(iid):
					(state["item_instances"] as Array).append((t["escrow_instances"][iid] as Dictionary).duplicate(true))
				repo.save(owner, int(ld["revision"]), state)
			(t["offers"][side]["items"] as Array).erase(iid)
			t["escrow_instances"].erase(iid)
		# ouro: escrow → dono original (1×)
		var g := int(t["escrow_gold"][side])
		if g > 0:
			var ld2 := repo.load(owner)
			var state2: Dictionary = ld2["state"]
			state2["hero_gold"] = int(state2.get("hero_gold", 0)) + g
			repo.save(owner, int(ld2["revision"]), state2)
			t["escrow_gold"][side] = 0
			(t["offers"][side] as Dictionary)["gold"] = 0

func _bump_offer(t: Dictionary) -> void:
	t["offer_version"] = int(t["offer_version"]) + 1   # §19
	_reset_accept(t)                                    # §20 qualquer mudança invalida confirmação
	t["updated_at"] = _now()
	trades.put(t)

func _reset_accept(t: Dictionary) -> void:
	t["accept"] = {"a": -1, "b": -1}

func _terminate(t: Dictionary) -> void:
	trades.clear_active(str(t["a"])); trades.clear_active(str(t["b"]))
	trades.put(t)

func _guard(trade_id: String, actor: String, allowed_states: Array) -> Dictionary:
	if not trades.has(trade_id):
		return {"ok": false, "reason": "NO_TRADE"}
	var t: Dictionary = trades.get_trade(trade_id)
	if _side_of(t, actor) == "":
		return {"ok": false, "reason": "NOT_PARTICIPANT"}          # §57 terceiro não toca
	if not allowed_states.has(str(t["state"])):
		return {"ok": false, "reason": "BAD_STATE", "state": str(t["state"])}
	return {"ok": true, "trade": t}

func _find_instance(state: Dictionary, iid: String) -> int:
	var arr: Array = state.get("item_instances", [])
	for i in range(arr.size()):
		if str((arr[i] as Dictionary).get("iid", "")) == iid:
			return i
	return -1

# ══════════════ EXPIRY / RECONNECT / RECOVERY ══════════════
## Varre trades ativas: convite/negociação expirados → cancela (refund exact-once §37). Chamar por tick do servidor.
func expiry_tick() -> int:
	var n := 0
	for tid in trades.all_ids():
		var t: Dictionary = trades.get_trade(tid)
		if TERMINAL.has(str(t["state"])):
			continue
		if _now() > int(t["expires_at"]):
			_refund_all(t)
			t["state"] = EXPIRED; t["updated_at"] = _now()
			_terminate(t)
			n += 1
	return n

## Sessão de um participante caiu de vez (lease expirou §37): cancela a trade dele, refund exact-once.
func on_session_lost(character_id: String) -> void:
	var tid := trades.active_trade_of(character_id)
	if tid == "": return
	var t: Dictionary = trades.get_trade(tid)
	if TERMINAL.has(str(t["state"])): return
	_refund_all(t); t["state"] = CANCELLED; t["updated_at"] = _now(); _terminate(t)

## Recovery de RESTART (§40): política SEGURA = trades não-completadas são CANCELADAS (refund). Completadas ficam (§41).
func recover_after_restart() -> Dictionary:
	var cancelled := 0; var kept := 0
	for tid in trades.all_ids():
		var t: Dictionary = trades.get_trade(tid)
		if str(t["state"]) == COMPLETED:
			kept += 1
			continue
		if TERMINAL.has(str(t["state"])):
			continue
		_refund_all(t); t["state"] = CANCELLED; t["updated_at"] = _now(); _terminate(t)
		cancelled += 1
	return {"cancelled": cancelled, "kept_completed": kept}

# ══════════════ TRADEVIEW — DTO seguro (§53) ══════════════
func view_for(trade_id: String, actor: String) -> Dictionary:
	if not trades.has(trade_id):
		return {}
	var t: Dictionary = trades.get_trade(trade_id)
	if _side_of(t, actor) == "":
		return {}
	return {
		"trade_id": trade_id, "state": str(t["state"]), "offer_version": int(t["offer_version"]),
		"you": _side_of(t, actor),
		"a": _side_view(t, "a"), "b": _side_view(t, "b"),
		"accept": {"a": int(t["accept"]["a"]) == int(t["offer_version"]), "b": int(t["accept"]["b"]) == int(t["offer_version"])},
	}

func _side_view(t: Dictionary, side: String) -> Dictionary:
	var out_items: Array = []
	for iid in t["offers"][side]["items"]:
		var inst: Dictionary = t["escrow_instances"].get(iid, {})
		var item_id := str(inst.get("item_id", ""))
		out_items.append({
			"iid": iid, "item_id": item_id, "quality": int(inst.get("quality", 0)),
			"rarity": ItemDB.rarity(item_id) if item_id != "" else "",
			"affixes": (inst.get("affixes", []) as Array).duplicate(true),
		})   # apresentação vem do dado SERVER-SIDE (§54/§93) — nunca de descrição do cliente
	return {"character": str(t[side]), "items": out_items, "gold": int(t["offers"][side]["gold"])}

func _audit(t: Dictionary, gold_a: int, gold_b: int, items_a: Array, items_b: Array) -> void:
	audit_log.append({
		"t": _now(), "trade_id": str(t["trade_id"]), "a": str(t["a"]), "b": str(t["b"]),
		"gold_a_to_b": gold_a, "gold_b_to_a": gold_b,
		"items_a_to_b": items_a.duplicate(), "items_b_to_a": items_b.duplicate(),
		"revisions": t.get("result_revisions", {}), "result": COMPLETED,
	})   # §87 — sem token/account privado

func get_view(actor: String, trade_id: String) -> Dictionary:
	var v := view_for(trade_id, actor)
	if v.is_empty():
		return {"ok": false, "reason": "NO_TRADE_OR_NOT_PARTICIPANT"}
	return {"ok": true, "view": v}
