class_name PrestigeManager extends Node
## PrestigeManager — PRESTÍGIO REAL / RESET DE CICLO / MASTER LEVEL (FATIA A6). Fecha a espinha de longo prazo:
## o Errante zera a JORNADA IDLE (stage/frontier/farm/muro/progresso), NUNCA o PERSONAGEM (nível/XP/itens/ouro/
## Fragmentos/maestria/quests/narrativa/game_speed permanecem). Em troca: +1 Prestígio, +1 Master Level, e um
## bônus PERMANENTE de poder (MASTER_MULTIPLIER = 1.08^M) que faz o conteúdo antigo ser atravessado mais rápido.
##
## ★ REGRA DE PODER (§22/§23/§26): o Master multiplier é a ÚNICA fonte de bônus permanente de reset e é aplicado
## ao RESULTADO REAL (dano do jogador via CombatMath, HP máx via GameState.max_hp_total). O PowerBudget lê esses
## resultados → o CP sobe NATURALMENTE. NUNCA somamos CP artificial. Sem multiplicador do ascension.ts junto.
##
## ★ SELOS DE CICLO (§7/§8): moeda ESTRUTURAL (não compra, não dropa de mob comum, não vende, não gera offline
## fora da progressão real). +1 Selo na PRIMEIRA conclusão EM AVANÇO de cada boss-stage (stage terminada em 10)
## NAQUELE ciclo. Dedup por watermark (GameState.grant_cycle_seal) — farm/retry/reload nunca duplicam (§9/§41).
##
## SEPARAÇÃO: este nó é ESTADO + ELIGIBILITY + TRANSAÇÃO. A matemática pura vive em PrestigeMath. O reset da
## jornada IDLE mora aqui (mutação direta do GameState, como o IdleRewards faz); a reconciliação do mundo VIVO
## (StageDirector/AutoPlay) é delegada ao host via prestige_apply_reset() (nulo/ausente nos self-tests).

signal prestige_done(new_prestige: int, new_master: int)

var _host = null

func setup(host) -> void:
	_host = host

func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# ESTADO / REQUISITOS (lê GameState; delega os números ao PrestigeMath)
# ══════════════════════════════════════════════════════════════════════════════════════════════════
func prestige_count() -> int:
	var gs = _gs()
	return int(gs.prestige_count) if gs != null else 0

func master_level() -> int:
	var gs = _gs()
	return int(gs.master_level) if gs != null else 0

## Maior stage DO CICLO atual (= stage_highest_global; reseta no Prestígio). §17.
func cycle_highest() -> int:
	var gs = _gs()
	return int(gs.stage_highest_global) if gs != null else 1

func cycle_seals() -> int:
	var gs = _gs()
	return int(gs.cycle_seals) if gs != null else 0

func required_stage() -> int:
	return PrestigeMath.required_stage(prestige_count())

func required_seals() -> int:
	return PrestigeMath.required_seals(prestige_count())

func master_multiplier() -> float:
	return PrestigeMath.master_multiplier(master_level())

## Há baú AFK pendente com recompensa? (§13) — checa direto no GameState (sem depender do IdleRewards).
func has_offline_pending() -> bool:
	var gs = _gs()
	if gs == null or not (gs.offline_pending is Dictionary):
		return false
	var p: Dictionary = gs.offline_pending
	return int(p.get("gold", 0)) > 0 or int(p.get("xp", 0)) > 0 \
		or not (p.get("items", {}) as Dictionary).is_empty() \
		or not (p.get("materials", {}) as Dictionary).is_empty()

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# ELIGIBILITY (§12) — só stage E selos; NUNCA por CP alto/ouro/Fragmentos.
# ══════════════════════════════════════════════════════════════════════════════════════════════════
func is_eligible() -> bool:
	return cycle_highest() >= required_stage() and cycle_seals() >= required_seals()

## Pode EXECUTAR agora? Além da eligibility, bloqueia se houver baú pendente (§13). Retorna {ok, reason}.
func can_execute() -> Dictionary:
	# FATIA A9.1 (§33): proteção transacional de UI — não prestigiar enquanto uma cena está aberta (viewing).
	# host-guarded (A6/testes sem host não são afetados); ao fechar a cena, o Prestígio volta a estar disponível.
	if _host != null and _host.has_method("narrative_viewing") and _host.narrative_viewing():
		return {"ok": false, "reason": "Feche a história antes de prestigiar"}
	if has_offline_pending():
		return {"ok": false, "reason": "COLETE SEU BAÚ AFK ANTES DE PRESTIGIAR"}
	if not is_eligible():
		var falta_stage: int = maxi(0, required_stage() - cycle_highest())
		var falta_selo: int = maxi(0, required_seals() - cycle_seals())
		return {"ok": false, "reason": "Requisito incompleto (faltam %d fase(s) / %d selo(s))" % [falta_stage, falta_selo]}
	return {"ok": true, "reason": ""}

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# SELOS — creditados na PRIMEIRA conclusão em AVANÇO de cada boss-stage (online E offline). Dedup por
# watermark no GameState (idempotente). §8/§9/§40/§41.
# ══════════════════════════════════════════════════════════════════════════════════════════════════
## ONLINE: chamado pelo host quando o StageDirector conclui uma boss-stage EM AVANÇO. Persiste se creditou.
func notify_boss_cleared(global_stage: int) -> void:
	var gs = _gs()
	if gs == null:
		return
	if gs.grant_cycle_seal(global_stage):
		gs.save_game()   # debounced; o próximo autosave/flush grava

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# PROJEÇÃO (§28/§29) — PURA, não muta save, não executa. {current_cp, projected_cp, delta, cur/next mult}.
# ══════════════════════════════════════════════════════════════════════════════════════════════════
func projection() -> Dictionary:
	var cp: int = PowerBudget.cp()
	var m := master_level()
	var proj := PrestigeMath.projected_cp(cp, m)
	return {
		"current_cp": cp,
		"projected_cp": proj,
		"delta": proj - cp,
		"cur_mult": PrestigeMath.master_multiplier(m),
		"next_mult": PrestigeMath.master_multiplier(m + 1),
		"master_from": m,
		"master_to": m + 1,
	}

## Painel/HUD: tudo que o PrestigePanel precisa (§62). Sem mutação.
func status() -> Dictionary:
	var proj := projection()
	return {
		"prestige_count": prestige_count(),
		"master_level": master_level(),
		"master_title": PrestigeMath.master_title(master_level()),
		"cur_mult": proj["cur_mult"],
		"next_mult": proj["next_mult"],
		"cycle_highest": cycle_highest(),
		"required_stage": required_stage(),
		"cycle_seals": cycle_seals(),
		"required_seals": required_seals(),
		"current_cp": proj["current_cp"],
		"projected_cp": proj["projected_cp"],
		"delta_cp": proj["delta"],
		"eligible": is_eligible(),
		"can_execute": can_execute(),
	}

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# EXECUÇÃO ATÔMICA (§32) — valida → snapshot → incrementa → lifetime → reseta ciclo → recalcula HP →
# reconcilia mundo → 1 flush. Nada de meio-Prestígio: as mutações são operações de int/dict puras (não podem
# falhar no meio); ainda assim guardamos snapshot p/ rollback defensivo.
# ══════════════════════════════════════════════════════════════════════════════════════════════════
func execute_prestige(now_unix: int) -> Dictionary:
	var gs = _gs()
	if gs == null:
		return {"ok": false, "reason": "sem GameState"}
	var gate := can_execute()
	if not bool(gate.get("ok", false)):
		return {"ok": false, "reason": str(gate.get("reason", "indisponível"))}

	# SNAPSHOT de segurança (rollback defensivo).
	var snap: Dictionary = gs.to_dict()

	# 1) lifetime record ANTES de resetar o ciclo (§17).
	gs.lifetime_highest_stage = maxi(int(gs.lifetime_highest_stage), int(gs.stage_highest_global))
	# 2) incrementa Prestígio + Master (persistem separados p/ espaço futuro de Master XP — §21).
	gs.prestige_count = int(gs.prestige_count) + 1
	gs.master_level = int(gs.master_level) + 1
	# 3) RESET EXATO do domínio idle do ciclo (§18) — NADA de personagem/itens/narrativa (§19).
	gs.stage_chapter = 1
	gs.stage_index = 1
	gs.stage_kills = 0
	gs.stage_highest_global = 1
	gs.stage_mode = "advance"
	gs.stage_wall_active = false
	gs.stage_fails = 0
	gs.stage_frontier_chapter = 1
	gs.stage_frontier_stage = 1
	gs.stage_farm_chapter = 1
	gs.stage_farm_stage = 1
	gs.cycle_seals = 0
	gs.cycle_seal_high = 0
	gs.cycle_encounter_high = 0            # A7.1: novo ciclo devolve os first-clears de suporte (§55)
	gs.offline_remainder_seconds = 0.0   # remainder ligado à stage antiga não sobrevive ao novo ciclo (§18)
	gs.offline_pending = {}              # já validado vazio no gate; garante limpo
	# 4) OFFLINE: novo ciclo começa AGORA — segundos do ciclo anterior não podem ser pagos de novo (§20).
	gs.last_seen_at = now_unix
	# 5) RECALCULA HP real com o novo Master multiplier: começa o ciclo saudável (§25).
	gs.hero_hp = gs.max_hp_total()

	# 6) reconcilia o mundo VIVO (StageDirector volta p/ 1-1; AutoPlay não briga com o reset — §33/§60).
	if _host != null and _host.has_method("prestige_apply_reset"):
		_host.prestige_apply_reset()

	# 7) TRANSAÇÃO: uma escrita com o estado final (§32). save_game() marca sujo (as mutações acima foram diretas,
	# sem passar pelos setters que marcam) e flush_save() grava JÁ. Se algo acima tivesse falhado, restauraríamos snap.
	gs.save_game()
	gs.flush_save()

	prestige_done.emit(int(gs.prestige_count), int(gs.master_level))
	print("[PrestigeManager] PRESTÍGIO %d · Master %d (ciclo → 1-1; personagem preservado)" % [int(gs.prestige_count), int(gs.master_level)])
	return {
		"ok": true,
		"reason": "",
		"prestige_count": int(gs.prestige_count),
		"master_level": int(gs.master_level),
		"snapshot": snap,   # p/ auditoria/rollback externo se necessário
	}
