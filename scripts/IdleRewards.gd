class_name IdleRewards extends Node
## IdleRewards — PROGRESSÃO OFFLINE / BAÚ AFK / TAXAS POR HORA (FATIA A5). Fecha o 1º loop idle: o jogador
## fecha, o tempo passa, e o Arcane calcula o avanço SEM simular combate.
##
## ★★★ REGRA ABSOLUTA (§2): offline é MATEMÁTICA. NUNCA spawna mob, roda IA/_process, move o herói, cria
## projétil, resolve telegraph nem itera dezenas de milhares de hits. O custo é O(stages atravessadas +
## entradas de loot), NÃO O(kills).
##
## SNAPSHOT (§10): o avanço offline usa o CP do personagem AO CARREGAR (fixo p/ toda a ausência) → matemática
## fechada. XP/itens só alteram o personagem no CLAIM (não re-alimentam o CP durante o cálculo).
##
## FONTE ECONÔMICA ÚNICA: RewardMath (ouro/XP/ciclo) + ProgressionMath (tempo/required). Offline SEMPRE usa
## tempo REAL e velocidade base (x1) — game_speed salvo NÃO multiplica ausência (§43/§44).

const OFFLINE_CAP_SECONDS := 8 * 60 * 60   # 8h (§5)
const MIN_OFFLINE_SECONDS := 60            # abaixo disto acumula no remainder, sem gerar baú (§6)
const R_ADVANCE := 0.95                    # limiar determinístico de avanço offline (§12/§13)
const STAGES_PER_CHAPTER := 10

var _host = null
var _sd = null
var _lm = null

func setup(host, sd, lm) -> void:
	_host = host; _sd = sd; _lm = lm

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# HELPERS de fase — FATIA A7.4.1: DELEGAM ao ContentManifest (fonte canônica ÚNICA §14). Antes espelhavam
# a math de fase aqui (tabela paralela); agora `stage_in_chapter`/`type_of`/`chapter`/`gear_tier`/`boss_id`/
# `apex_id` vêm do manifesto. Offline continua MATEMÁTICO (não instancia mundo) — só a FONTE do conteúdo mudou.
# (ContentManifest.stage_type ≡ a regra antiga 5→miniboss/10→boss; local_of ≡ stage_in_chapter ⇒ zero regressão.)
# ══════════════════════════════════════════════════════════════════════════════════════════════════
static func stage_in_chapter(global: int) -> int:
	return ContentManifest.local_of(global)

static func type_of(global: int) -> String:
	return ContentManifest.stage_type(global)

## Capítulo (1-based) da fase global — via manifesto.
static func chapter_of(global: int) -> int:
	return ContentManifest.chapter_of(global)

## Tier de gear canônico da fase (do capítulo) — via manifesto.
static func gear_tier_of(global: int) -> int:
	return ContentManifest.gear_tier(ContentManifest.chapter_of(global))

## boss_id do capítulo da fase — via manifesto (identidade de first-clear igual ao runtime).
static func boss_id_of(global: int) -> String:
	return str(ContentManifest.chapter(ContentManifest.chapter_of(global)).get("boss_id", ""))

## apex (mob_id da fase 5) do capítulo — via manifesto.
static func apex_id_of(global: int) -> String:
	return str(ContentManifest.chapter(ContentManifest.chapter_of(global)).get("apex", ""))

## Cota de kills de uma fase (espelha StageDirector.NORMAL_QUOTA_OVERRIDE + ENCOUNTER_QUOTA=1).
static func quota_of(global: int) -> int:
	var t := type_of(global)
	if t != "normal":
		return 1
	var s := stage_in_chapter(global)
	match s:
		1: return 20
		2: return 24
		3: return 26
		4: return 30
		_: return 30

static func stage_time(global: int, cp: int) -> float:
	var t := type_of(global)
	var req := ProgressionMath.required_cp(global, t)
	var r := float(cp) / maxf(float(req), 1.0)
	return ProgressionMath.estimated_time(t, r) + ProgressionMath.TRANSITION_OVERHEAD

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# NÚCLEO PURO — progressão de stage por EVENTOS (não frames). Testável com primitivos.
# Retorna {seconds, stages_advanced, start_global, end_global, walled, frontier_global, farm_global,
#          farm_cycles, gold, xp, kills, remainder}.
# ══════════════════════════════════════════════════════════════════════════════════════════════════
static func calc_offline(elapsed_s: float, start_global: int, wall_active: bool, frontier_global: int, farm_global: int, cp: int) -> Dictionary:
	var remaining := clampf(elapsed_s, 0.0, float(OFFLINE_CAP_SECONDS))
	var seconds := remaining
	var gold := 0.0
	var xp := 0.0
	var frag := 0.0                              # FATIA A7.2: Fragmentos offline (renda de ciclo escalada com a fase)
	var kills := 0
	var stages_adv := 0

	# ── ponto de partida ──
	var cur := maxi(1, start_global)
	var walled := false
	var out_frontier := frontier_global
	var out_farm := farm_global
	var forced_farm := false
	if wall_active:
		var fr_req := ProgressionMath.required_cp(frontier_global, type_of(frontier_global))
		if float(cp) >= R_ADVANCE * float(fr_req):
			cur = frontier_global                       # CP subiu o bastante → retoma o avanço (§17)
		else:
			forced_farm = true                          # segue preso → ausência inteira vira farm (§18)
			out_farm = maxi(1, farm_global)

	# ── FASE 1: AVANÇO (só se não forçado ao farm) ──
	if not forced_farm:
		while remaining > 0.0:
			var t := type_of(cur)
			var req := ProgressionMath.required_cp(cur, t)
			var r := float(cp) / maxf(float(req), 1.0)
			if r < R_ADVANCE:
				walled = true                            # muro offline: não atravessa por fórmula
				out_frontier = cur
				out_farm = maxi(1, cur - 1)
				break
			var st := stage_time(cur, cp)
			if remaining < st:
				break                                    # acabou o tempo no meio de uma fase (sem crédito parcial)
			gold += float(RewardMath.gold_for(cur, t, true))   # 1ª conclusão em avanço → mult APEX/BOSS
			xp += float(RewardMath.xp_for(cur, t, true))
			frag += float(RewardMath.fragments_cycle(cur))
			kills += quota_of(cur)
			remaining -= st
			stages_adv += 1
			cur += 1

	# ── FASE 2: FARM (fórmula fechada) — só quando há muro/forçado ──
	var farm_cycles := 0
	if walled or forced_farm:
		var fg := out_farm
		var ft := type_of(fg)
		var fcycle := stage_time(fg, cp)
		if fcycle > 0.0:
			farm_cycles = int(floor(remaining / fcycle))
			gold += float(farm_cycles) * float(RewardMath.gold_for(fg, ft, false))   # FARM = NORMAL (sem ×4, §26)
			xp += float(farm_cycles) * float(RewardMath.xp_for(fg, ft, false))
			frag += float(farm_cycles) * float(RewardMath.fragments_cycle(fg))
			kills += farm_cycles * quota_of(fg)
			remaining -= float(farm_cycles) * fcycle

	return {
		"seconds": seconds,
		"stages_advanced": stages_adv,
		"start_global": start_global,
		"end_global": cur,
		"walled": walled or forced_farm,
		"frontier_global": out_frontier,
		"farm_global": out_farm,
		"farm_cycles": farm_cycles,
		"gold": int(min(gold, 9.0e15)),
		"xp": int(min(xp, 9.0e15)),
		"frag": int(min(frag, 9.0e15)),
		"kills": kills,
		"remainder": maxf(0.0, remaining),
	}

func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null

func _global_of(ch: int, st: int) -> int:
	return (ch - 1) * STAGES_PER_CHAPTER + st

func _ch_st_of_global(g: int) -> Array:
	g = maxi(1, g)
	return [(g - 1) / STAGES_PER_CHAPTER + 1, (g - 1) % STAGES_PER_CHAPTER + 1]

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# BOOT — reconcilia a ausência. Chamado ANTES do StageDirector.setup (p/ o stage já entrar avançado, §34).
# ══════════════════════════════════════════════════════════════════════════════════════════════════
func boot_reconcile(now_unix: int) -> void:
	var gs = _gs()
	if gs == null:
		return
	var last: int = int(gs.last_seen_at)
	gs._session_started = true   # a partir daqui, os writes viram heartbeat (carimbam last_seen_at)
	# FIRST RUN (§52): sem last_seen → marca agora, 0 reward.
	if last <= 0:
		gs.last_seen_at = now_unix
		gs.save_game()
		return
	# RELÓGIO INVÁLIDO (§9): now < last → 0.
	var elapsed := float(now_unix - last)
	if elapsed < 0.0:
		push_warning("[IdleRewards] relógio recuou (now<last) — ausência tratada como 0.")
		gs.last_seen_at = now_unix
		gs.save_game()
		return
	var effective := elapsed + float(gs.offline_remainder_seconds)
	# abaixo do mínimo → acumula no remainder, sem baú (§6).
	if effective < float(MIN_OFFLINE_SECONDS):
		gs.offline_remainder_seconds = effective
		gs.last_seen_at = now_unix
		gs.save_game()
		return

	# CP SNAPSHOT (§10) — uma vez, com o personagem carregado.
	var cp: int = PowerBudget.cp()
	var start_global := _global_of(gs.stage_chapter, gs.stage_index)
	var frontier_global := _global_of(gs.stage_frontier_chapter, gs.stage_frontier_stage)
	var farm_global := _global_of(gs.stage_farm_chapter, gs.stage_farm_stage)
	var r := calc_offline(effective, start_global, gs.stage_wall_active, frontier_global, farm_global, cp)

	# DROPS agregados (§28) — kills × loot table real da região (via host), sem RNG global (seed local, §29).
	var loot: Array = _host.idlerewards_region_loot() if _host != null and _host.has_method("idlerewards_region_loot") else []
	var seed_val := int(last) ^ int(now_unix) ^ int(r["kills"])
	var drops: Dictionary = RewardMath.aggregate_drops(int(r["kills"]), loot, seed_val)
	# separa drops em ITENS (id do catálogo) vs MATERIAIS (por nome)
	var items: Dictionary = {}
	var materials: Dictionary = {}
	for nm in drops:
		var iid := ItemDB.id_by_name(str(nm))
		if iid != "":
			items[iid] = int(drops[nm])
		else:
			materials[str(nm)] = int(drops[nm])
	# FATIA A7.2: renda de Fragmentos offline entra no baú (materiais). Salvage offline soma por cima no claim.
	if int(r["frag"]) > 0:
		materials["Fragmentos"] = int(materials.get("Fragmentos", 0)) + int(r["frag"])

	# APLICA a PROGRESSÃO DE STAGE já no boot (§34) — o baú só segura ouro/XP/itens.
	var end_cs := _ch_st_of_global(int(r["end_global"]))
	gs.stage_chapter = end_cs[0]; gs.stage_index = end_cs[1]; gs.stage_kills = 0
	gs.stage_highest_global = maxi(gs.stage_highest_global, int(r["end_global"]))
	gs.stage_wall_active = bool(r["walled"])
	if bool(r["walled"]):
		var fcs := _ch_st_of_global(int(r["frontier_global"]))
		var acs := _ch_st_of_global(int(r["farm_global"]))
		gs.stage_mode = "farm"
		gs.stage_frontier_chapter = fcs[0]; gs.stage_frontier_stage = fcs[1]
		gs.stage_farm_chapter = acs[0]; gs.stage_farm_stage = acs[1]
		# em muro, a fase "jogada" é a de farm
		gs.stage_chapter = acs[0]; gs.stage_index = acs[1]
	else:
		gs.stage_mode = "advance"

	# MESCLA no pending (§32/§33) — soma com o baú anterior (não duplica intervalo: last_seen avança).
	# FATIA A6 — SELOS DE CICLO OFFLINE (§40/§41): as boss-stages (multiplos de 10) CONCLUIDAS EM AVANCO durante
	# a ausencia creditam Selo. Completadas-em-avanco = [start_global, end_global-1] (end_global e a PROXIMA fase,
	# nunca concluida). Farm offline NAO gera Selo (so o avanco cruza boss-stages). Dedup por watermark
	# (grant_cycle_seal) => dois boots nunca duplicam o mesmo Selo. Custo O(stages_avancadas/10).
	var _seal_lo := int(r["start_global"])
	var _seal_hi := int(r["end_global"]) - 1
	var _seal_g := ((_seal_lo + 9) / 10) * 10
	while _seal_g <= _seal_hi:
		gs.grant_cycle_seal(_seal_g)
		_seal_g += 10

	# FATIA A7.1 — DROPS DE SUPORTE OFFLINE (§54/§55): first-clear de encontro (APEX fase-5 / BOSS fase-10)
	# atravessado em avanço → concede suporte (determinístico por seed; dedup por watermark). Farm não repete.
	var _enc_g := _seal_lo
	while _enc_g <= _seal_hi:
		var _s := ((_enc_g - 1) % 10) + 1
		if _s == 5 or _s == 10:
			gs.grant_encounter_reward(_enc_g, int(gs.last_seen_at) ^ _enc_g ^ 0x51ED)
		_enc_g += 1

	# FATIA A7 — BESTIARIO OFFLINE (§35/§41): distribui as kills agregadas entre os mobs REAIS da regiao (batch,
	# sem loop por kill). Estimativa data-driven (divide igualmente pelo pool); documentado. Boss e ~2/capitulo
	# (desprezivel) e o boss vivo/nome nao existe no boot (StageDirector ainda nao montado) => fora da V1 offline.
	var _tk := int(r["kills"])
	if _tk > 0 and _host != null and _host.has_method("idlerewards_region_mobs"):
		var pool: Array = _host.idlerewards_region_mobs()
		if not pool.is_empty():
			var per := _tk / pool.size()
			var rem := _tk % pool.size()
			var batch: Dictionary = {}
			for i in range(pool.size()):
				var c := per + (1 if i < rem else 0)
				if c > 0:
					batch[str(pool[i])] = c
			gs.bestiary_add_kills_batch(batch)

	var prev: Dictionary = gs.offline_pending if gs.offline_pending is Dictionary else {}
	var pend := _merge_pending(prev, {
		"seconds": int(r["seconds"]),
		"stages_advanced": int(r["stages_advanced"]),
		"start_global": int(r["start_global"]),
		"end_global": int(r["end_global"]),
		"farm_global": int(r["farm_global"]),
		"farm_cycles": int(r["farm_cycles"]),
		"gold": int(r["gold"]),
		"xp": int(r["xp"]),
		"items": items,
		"materials": materials,
		"roll_seed": seed_val,   # FATIA A7.1: seed determinística p/ rolar as instâncias no CLAIM (§32/§33)
	})
	gs.offline_pending = pend
	gs.offline_remainder_seconds = float(r["remainder"])
	gs.last_seen_at = now_unix
	gs.flush_save()   # transação: stage avançado + pending + last_seen persistidos JUNTOS
	print("[IdleRewards] offline: %ds → +%d fases, +%d ouro, +%d XP, kills=%d (baú pendente)" % [int(r["seconds"]), int(r["stages_advanced"]), int(r["gold"]), int(r["xp"]), int(r["kills"])])

## Soma dois pendings (mescla itens/materiais). Preserva start_global do 1º, end/farm do mais recente.
func _merge_pending(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.is_empty():
		return b
	var items: Dictionary = (a.get("items", {}) as Dictionary).duplicate()
	for k in b.get("items", {}):
		items[k] = int(items.get(k, 0)) + int(b["items"][k])
	var mats: Dictionary = (a.get("materials", {}) as Dictionary).duplicate()
	for k in b.get("materials", {}):
		mats[k] = int(mats.get(k, 0)) + int(b["materials"][k])
	return {
		"seconds": int(a.get("seconds", 0)) + int(b.get("seconds", 0)),
		"stages_advanced": int(a.get("stages_advanced", 0)) + int(b.get("stages_advanced", 0)),
		"start_global": int(a.get("start_global", b.get("start_global", 1))),
		"end_global": int(b.get("end_global", 1)),
		"farm_global": int(b.get("farm_global", 1)),
		"farm_cycles": int(a.get("farm_cycles", 0)) + int(b.get("farm_cycles", 0)),
		"gold": int(a.get("gold", 0)) + int(b.get("gold", 0)),
		"xp": int(a.get("xp", 0)) + int(b.get("xp", 0)),
		"items": items,
		"materials": mats,
		"roll_seed": int(b.get("roll_seed", a.get("roll_seed", 0))),   # A7.1: mantém a seed mais recente
	}

## Há baú pendente com recompensa?
func has_pending() -> bool:
	var gs = _gs()
	if gs == null or not (gs.offline_pending is Dictionary):
		return false
	var p: Dictionary = gs.offline_pending
	return int(p.get("gold", 0)) > 0 or int(p.get("xp", 0)) > 0 or not (p.get("items", {}) as Dictionary).is_empty() or not (p.get("materials", {}) as Dictionary).is_empty()

func pending() -> Dictionary:
	var gs = _gs()
	return gs.offline_pending if gs != null and gs.offline_pending is Dictionary else {}

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# CLAIM — ATÔMICO (§35): aplica tudo em memória e faz UM flush. Itens passam pelo LootManager (§36).
# ══════════════════════════════════════════════════════════════════════════════════════════════════
func claim() -> Dictionary:
	var gs = _gs()
	if gs == null or not has_pending():
		return {}
	var p: Dictionary = gs.offline_pending
	# ouro/XP (o add_xp real processa múltiplos level-ups; §37). Estes já são debounced (marcam sujo).
	gs.add_gold(int(p.get("gold", 0)))
	gs.add_xp(int(p.get("xp", 0)))
	# itens/materiais → LootManager (mesma política A3.5: stack/upgrade/salvage/overflow; §36)
	var roll_seed := int(p.get("roll_seed", 0))
	var items_p: Dictionary = p.get("items", {}) if p.get("items", {}) is Dictionary else {}
	var mats_p: Dictionary = p.get("materials", {}) if p.get("materials", {}) is Dictionary else {}
	var non_equip: Dictionary = {}
	var instances: Array = []
	var drop_idx := 0
	for id in items_p:
		var q := int(items_p[id])
		if ItemDB.is_equippable(str(id)):
			for k in range(q):
				var s := roll_seed ^ (hash(str(id)) * 2654435761) ^ (drop_idx * 40503)
				var inst := ItemRoller.roll(str(id), s, "offline", 0)
				if not inst.is_empty(): instances.append(inst)
				drop_idx += 1
		else:
			non_equip[str(id)] = q
	if _lm != null:
		if not instances.is_empty(): _lm.receive_instances(instances)
		_lm.receive_batch(non_equip, mats_p)
	else:
		for nm in mats_p:
			gs.add_material_silent(str(nm), int(mats_p[nm]))
	# limpa o pending + flush ÚNICO (estado final = rewards aplicados + baú vazio, na mesma escrita).
	var claimed := p.duplicate(true)
	gs.offline_pending = {}
	gs.flush_save()
	return claimed

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# TAXAS POR HORA (§39-43) — usa a fase JOGADA (farm_stage no muro; §41) e a velocidade ATIVA (x1/x2/x3).
# Offline sempre x1 (não chama isto — usa calc_offline).
# ══════════════════════════════════════════════════════════════════════════════════════════════════
func _rate_context() -> Dictionary:
	var gs = _gs()
	var g := 1
	if _sd != null:
		if _sd.is_wall_active():
			g = _global_of(_sd.farm_chapter, _sd.farm_stage)   # §41: taxa usa a fase de farm, não a frontier
		else:
			g = _sd.global_stage()
	var t := type_of(g)
	var req := ProgressionMath.required_cp(g, t)
	var cp: int = PowerBudget.cp()
	var r := float(cp) / maxf(float(req), 1.0)
	return {"global": g, "type": t, "r": r}

func gold_per_hour(speed_mult: float = 1.0) -> float:
	var c := _rate_context()
	return RewardMath.gold_per_hour(int(c["global"]), str(c["type"]), float(c["r"]), speed_mult)

func xp_per_hour(speed_mult: float = 1.0) -> float:
	var c := _rate_context()
	return RewardMath.xp_per_hour(int(c["global"]), str(c["type"]), float(c["r"]), speed_mult)

## Drops/h estimado = ciclos/h × Σ(chance) das entradas de loot × kills-por-ciclo. Probabilístico ("~").
func drops_per_hour(speed_mult: float = 1.0) -> float:
	var c := _rate_context()
	var loot: Array = _host.idlerewards_region_loot() if _host != null and _host.has_method("idlerewards_region_loot") else []
	var sum_chance := 0.0
	for e in loot:
		if e is Dictionary:
			sum_chance += float(e.get("chance", 0.0))
	var cph := ProgressionMath.cycles_per_hour(str(c["type"]), float(c["r"]))
	return cph * float(quota_of(int(c["global"]))) * sum_chance * maxf(speed_mult, 0.0)

## "7h 42m" / "1h 03m" / "12m" — helper seguro (§49).
static func fmt_duration(seconds: int) -> String:
	seconds = maxi(0, seconds)
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	if m > 0:
		return "%dm" % m
	return "%ds" % seconds
