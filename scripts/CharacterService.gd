class_name CharacterService extends RefCounted
## FATIA A13 — ORQUESTRADOR de identidade/roster/loadouts/aparência. ★ APPEARANCE ≠ CLASS ≠ BUILD ≠ COSMETIC (decisão
## de produto). Server-authoritative (§74): cliente manda só display_name/class_id/IDs de opção; o servidor valida e
## cria o estado inicial (§33-36). Regras críticas: 1 progression character ativo por conta (§26) e slot pago ≠ farm
## AFK extra (§25/§29). Create é ATÔMICO (§84/§85). Legacy migra sem quebrar (§68-72). Save do jogador (por-character)
## já é v10 (class/appearance/loadouts). Metadata de conta (roster/active/entitlements/cosmetics) vive fora do save.

var char_repo: CharacterRepository
var items: ItemRegistry
var roster: AccountRosterRepository
var cosmetics: CosmeticEntitlementRepository
var authority: AuthorityServer          # opcional, p/ CP nos DTOs
var _clock: ServerClock
var _cid_counter := 0
var _rng := RandomNumberGenerator.new()
var _fault := ""

func setup(p_char_repo: CharacterRepository, p_items: ItemRegistry, p_roster: AccountRosterRepository, p_cosmetics: CosmeticEntitlementRepository, p_clock: ServerClock, p_authority: AuthorityServer = null, rng_seed: int = 24680) -> void:
	char_repo = p_char_repo; items = p_items; roster = p_roster; cosmetics = p_cosmetics
	_clock = p_clock; authority = p_authority; _rng.seed = rng_seed

func set_fault(f: String) -> void: _fault = f

func _gs():
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("GameState") if loop is SceneTree else null

func _new_cid() -> String:
	_cid_counter += 1
	return "char_%d_%08x" % [_cid_counter, _rng.randi()]

## Validação básica de nome (§40) — tamanho/whitespace/caracteres. Sem moderação externa (§40). Unicidade = NAME_POLICY_REQUIRED (§86).
static func validate_name(name: String) -> Dictionary:
	var n := name.strip_edges()
	if n.length() < 2 or n.length() > 16:
		return {"ok": false, "reason": "NAME_LENGTH"}
	for i in range(n.length()):
		var c := n[i]
		var ok := (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == " " or c == "_" or c == "-"
		if not ok:
			return {"ok": false, "reason": "NAME_CHARS"}
	return {"ok": true, "name": n}

# ── STARTER STATE (server-side §35) ──
func _build_starter_state(class_id: String, appearance: Dictionary, display_name: String) -> Dictionary:
	var gs = _gs()
	var backup: Dictionary = gs.to_dict().duplicate(true)
	gs.reset_save()
	gs.character_class = class_id
	gs.appearance = appearance.duplicate(true)
	gs.display_name = display_name
	gs.equipment = {"weapon": CharacterClassDefinition.starter_weapon(class_id)}
	gs.loadouts = [BuildLoadout.default_for_class(class_id)]
	gs.active_loadout = 0
	gs.last_seen_at = _clock.now()
	var state: Dictionary = gs.to_dict().duplicate(true)
	gs.apply_dict(backup); gs._dirty = false
	return state

# ── CREATE (§33-36, atômico §84/§85) ──
func create_character(account_id: String, class_id: String, display_name: String, appearance: Dictionary) -> Dictionary:
	# 1) valida classe (existe, jogável, gratuita §7) — cliente não escolhe stats (§34)
	if not CharacterClassDefinition.exists(class_id) or not CharacterClassDefinition.playable_ids().has(class_id):
		return {"ok": false, "reason": "BAD_CLASS"}
	# 2) nome
	var nm := validate_name(display_name)
	if not bool(nm["ok"]): return {"ok": false, "reason": str(nm["reason"])}
	# 3) aparência (allowlist §78) + cosmético (ownership §92)
	var av := CharacterAppearance.validate(appearance)
	if not bool(av["ok"]): return {"ok": false, "reason": str(av["reason"]), "field": av.get("field", "")}
	var cos := str(appearance.get("cosmetic_skin_id", ""))
	if cos != "" and not cosmetics.owns(account_id, cos):
		return {"ok": false, "reason": "COSMETIC_NOT_OWNED"}
	# 4) slot (§24/§80)
	if roster.characters_of(account_id).size() >= roster.slot_cap(account_id):
		return {"ok": false, "reason": "NO_CHARACTER_SLOT"}
	# 5) estado inicial (server-side)
	var cid := _new_cid()
	var state := _build_starter_state(class_id, appearance, str(nm["name"]))
	# 6) fault BEFORE commit → nada criado (§85/§93)
	if _fault == "BEFORE_COMMIT":
		return {"ok": false, "reason": "FAULT_BEFORE_COMMIT"}
	char_repo.create_character(account_id, cid, state)
	# fault "durante" (após save, antes do roster) → ROLLBACK: remove o save, sem órfão (§85)
	if _fault == "AFTER_CHAR":
		char_repo.remove(cid)
		return {"ok": false, "reason": "FAULT_ROLLED_BACK"}
	var radd := roster.add_character(account_id, cid)
	if not bool(radd["ok"]):
		char_repo.remove(cid)   # rollback — nunca save sem owner
		return {"ok": false, "reason": str(radd["reason"])}
	return {"ok": true, "character_id": cid, "class_id": class_id, "active_progress": roster.active_progress_of(account_id) == cid}

# ── ACTIVE PROGRESSION (§26-30) ──
func _stamp_last_seen(cid: String, t: int) -> void:
	var ld := char_repo.load(cid)
	if not bool(ld["ok"]): return
	var st: Dictionary = ld["state"]
	st["last_seen_at"] = t
	char_repo.save(cid, int(ld["revision"]), st)

## Troca o character de progressão ativa (§28): fecha o antigo, ATIVA o novo com relógio ZERADO (§29 — descarta o
## período pausado ⇒ nenhum offline duplicado). 1 ativo por conta (§26).
func switch_active_progression(account_id: String, new_cid: String) -> Dictionary:
	if not roster.owns(account_id, new_cid):
		return {"ok": false, "reason": "NOT_OWNER"}
	var now := _clock.now()
	var old := roster.active_progress_of(account_id)
	if old != "" and old != new_cid:
		_stamp_last_seen(old, now)          # congela o antigo (settle até agora)
	_stamp_last_seen(new_cid, now)          # §29 reseta o novo p/ AGORA (0 crédito do período pausado)
	roster.set_active_progress(account_id, new_cid)
	return {"ok": true, "active_progress": new_cid}

## Segundos de offline DISPONÍVEIS p/ um character. INATIVO = 0 (§27 — não acumula 2ª progressão paralela).
func offline_available_seconds(account_id: String, cid: String) -> int:
	if roster.active_progress_of(account_id) != cid:
		return 0
	var ld := char_repo.load(cid)
	if not bool(ld["ok"]): return 0
	return maxi(0, _clock.now() - int((ld["state"] as Dictionary).get("last_seen_at", _clock.now())))

## 1 gameplay writer ativo por CONTA (§30): só o progression character ativo pode abrir gameplay normal.
func can_open_gameplay(account_id: String, cid: String) -> bool:
	return roster.owns(account_id, cid) and roster.active_progress_of(account_id) == cid

# ── LOADOUTS (§41-49) ──
func set_loadout(account_id: String, cid: String, slot_index: int, loadout: Dictionary) -> Dictionary:
	if not roster.owns(account_id, cid): return {"ok": false, "reason": "NOT_OWNER"}
	var ld := char_repo.load(cid)
	if not bool(ld["ok"]): return {"ok": false, "reason": "NO_CHARACTER"}
	var st: Dictionary = ld["state"]
	var class_id := str(st.get("character_class", ""))
	var val := BuildLoadout.validate(loadout, class_id)
	if not bool(val["ok"]): return {"ok": false, "reason": str(val["reason"])}
	var cap := BuildLoadout.slot_cap(roster.loadout_entitlements(account_id))
	if slot_index < 0 or slot_index >= cap:
		return {"ok": false, "reason": "BAD_LOADOUT_SLOT"}
	var loadouts: Array = st.get("loadouts", [])
	loadouts = loadouts.duplicate(true)
	while loadouts.size() <= slot_index: loadouts.append({})
	loadouts[slot_index] = loadout.duplicate(true)
	st["loadouts"] = loadouts
	var sv := char_repo.save(cid, int(ld["revision"]), st)
	return {"ok": bool(sv["ok"]), "slot": slot_index}

func select_loadout(account_id: String, cid: String, index: int) -> Dictionary:
	if not roster.owns(account_id, cid): return {"ok": false, "reason": "NOT_OWNER"}
	var ld := char_repo.load(cid)
	if not bool(ld["ok"]): return {"ok": false, "reason": "NO_CHARACTER"}
	var st: Dictionary = ld["state"]
	var loadouts: Array = st.get("loadouts", [])
	if index < 0 or index >= loadouts.size(): return {"ok": false, "reason": "NO_SUCH_LOADOUT"}
	st["active_loadout"] = index
	char_repo.save(cid, int(ld["revision"]), st)
	return {"ok": true, "active_loadout": index}

# ── APPEARANCE (§76) ──
func set_appearance(account_id: String, cid: String, appearance: Dictionary) -> Dictionary:
	if not roster.owns(account_id, cid): return {"ok": false, "reason": "NOT_OWNER"}
	var av := CharacterAppearance.validate(appearance)
	if not bool(av["ok"]): return {"ok": false, "reason": str(av["reason"]), "field": av.get("field", "")}
	var cos := str(appearance.get("cosmetic_skin_id", ""))
	if cos != "" and not cosmetics.owns(account_id, cos):
		return {"ok": false, "reason": "COSMETIC_NOT_OWNED"}   # §77/§92
	var ld := char_repo.load(cid)
	if not bool(ld["ok"]): return {"ok": false, "reason": "NO_CHARACTER"}
	var st: Dictionary = ld["state"]
	st["appearance"] = appearance.duplicate(true)
	char_repo.save(cid, int(ld["revision"]), st)
	return {"ok": true, "actor_key": str(CharacterAppearanceResolver.resolve(appearance)["actor_key"])}

# ── DTOs (rede §39/§75) ──
func _cp_of(cid: String) -> int:
	if authority == null: return -1
	var ps := authority.power_snapshot(cid)
	return int(ps.get("cp", -1)) if not ps.is_empty() else -1

func get_roster_dto(account_id: String) -> Dictionary:
	var out: Array = []
	var active := roster.active_progress_of(account_id)
	for cid in roster.characters_of(account_id):
		var ld := char_repo.load(cid)
		if not bool(ld["ok"]): continue
		var st: Dictionary = ld["state"]
		out.append({
			"character_id": cid, "display_name": str(st.get("display_name", "")),
			"class_id": str(st.get("character_class", "")),
			"appearance_preview": str(CharacterAppearanceResolver.resolve(st.get("appearance", {}))["actor_key"]),
			"level": int(st.get("hero_level", 1)), "cp": _cp_of(cid),
			"prestige": int(st.get("prestige_count", 0)), "last_played": int(st.get("last_seen_at", 0)),
			"active_progress": cid == active,
		})   # §39 — sem account/session/journal/inventory inteiro
	return {"ok": true, "roster": out, "slot_cap": roster.slot_cap(account_id), "active_progress": active}

func get_identity_dto(account_id: String, cid: String) -> Dictionary:
	if not roster.owns(account_id, cid): return {"ok": false, "reason": "NOT_OWNER"}
	var ld := char_repo.load(cid)
	if not bool(ld["ok"]): return {"ok": false, "reason": "NO_CHARACTER"}
	var st: Dictionary = ld["state"]
	return {"ok": true, "identity": {
		"character_id": cid, "display_name": str(st.get("display_name", "")),
		"class_id": str(st.get("character_class", "")), "class_display": CharacterClassDefinition.display_name(str(st.get("character_class", ""))),
		"appearance": (st.get("appearance", {}) as Dictionary).duplicate(true),
		"actor_key": str(CharacterAppearanceResolver.resolve(st.get("appearance", {}))["actor_key"]),
		"loadouts": (st.get("loadouts", []) as Array).duplicate(true), "active_loadout": int(st.get("active_loadout", 0)),
		"level": int(st.get("hero_level", 1)), "cp": _cp_of(cid),
	}}

# ── snapshot/restore (restart §83) — só a metadata de conta; os saves vivem no CharacterRepository ──
func snapshot() -> Dictionary:
	return {"roster": roster.snapshot(), "cosmetics": cosmetics.snapshot(), "cid_counter": _cid_counter}

func restore(snap: Dictionary) -> void:
	roster.restore(snap.get("roster", {}))
	cosmetics.restore(snap.get("cosmetics", {}))
	_cid_counter = int(snap.get("cid_counter", 0))
