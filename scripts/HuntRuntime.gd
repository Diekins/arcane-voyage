class_name HuntRuntime extends Node
## FATIA A16.1A/D — LOOP REAL da Hunt no runtime (§1-10,20). ★ NÃO é service.call(): é um Node vivo que spawna HuntMob
## REAIS, tica AutoCombatBrain via CombatRuntime (§1, caminho REAL das 5 classes — não bypass legacy §2), aplica DANO
## REAL ao mob (take_damage), CURA/ESCUDO reais ao caster, resolve MORTE real, credita reward via HuntService (XP/loot
## reais §22/§23) e RESPAWNA (§20). NO STAGE ADVANCE (§21). x1/x2/x3 pelo delta escalado (§10). Movement lock (§16 —
## o node não move o player). Feedback via hooks (§8). Cooldown real (§3). Sem 2ª fonte de verdade.

var hs: HuntService
var character := ""
var ground_id := ""
var target_mob_id := ""     # A22 — "" = pool normal do ground; senão SÓ este mob nasce (Targeted Hunt)
var difficulty := "NORMAL"  # A22.6 — dificuldade da Targeted Hunt (escala hp/dmg via MissionDifficulty)
var _spot := ""
var _cds := CooldownTracker.new()
var _caster: Dictionary = {}          # estado de combate REAL do caster {class_id, expected_damage, max_hp, current_hp, shield, alive}
var _mob: HuntMob = null   # PRIMARY (alvo corrente do herói) — ver `current_mob()`

# ══════════════════════════════════════════════════════════════════════════════════════════════
# ★★★ GROUP COMBAT MIGRATION — STAGE 1/3/5 (05/09/2026)
# Contrato: `_mob` CONTINUA sendo o primário e a autoridade de combate. `_active_mobs` é o
# container do grupo, mantido em sincronia. Com `_max_active = 1` o comportamento é IDÊNTICO ao
# runtime antigo — este é o interruptor de segurança da migração (parity gate).
# ⛔ NÃO subir `_max_active` antes do SINGLE_COMPATIBILITY_PASS.
# ══════════════════════════════════════════════════════════════════════════════════════════════
var _active_mobs: Array = []          # membros vivos desta activity (bounded)
## ★★★ ATIVAÇÃO EARLY NORMAL (05/09/2026) — 2 mobs simultâneos na Hunt.
## Conservador de propósito (o contrato pede 2–3; começando em 2). Só foi ligado DEPOIS de:
## grupo formado pelo caminho de produção · 2 atores reais · pockets/HP/feedback independentes ·
## crédito exact-once · SAIR limpo · 12 suítes verdes.
## ⛔ `set_max_active(1)` continua sendo o INTERRUPTOR DE SEGURANÇA e recria o comportamento antigo.
var _max_active: int = 2
var _instance_seq: int = 0            # gerador de identidade por instância (Stage 3)
## ★★★ LEDGER DE CRÉDITO (Stage 5) — `instance_id` → true quando JÁ creditou.
## Invariante: morte de instância ⇒ 0 ou 1 crédito, NUNCA 2. Com N mortes na mesma janela, é
## aqui que o double-credit seria criado; o ledger é o que impede.
var _credited_deaths: Dictionary = {}
## Contadores de telemetria do invariante (Stage 6): crédito negado por duplicidade / morte sem crédito.
var group_stats := {"credit_granted": 0, "credit_blocked_dup": 0, "death_without_credit": 0,
	"initial_fill_spawns": 0, "replacement_spawns": 0, "group_formed_count": 0, "max_simultaneous_alive": 0}
## ★ INITIAL_FILL × STEADY_STATE. Começa em preenchimento; ao completar o grupo vira regime
## permanente (reposição 1 a 1, na cadência normal). ⛔ Sem isto o grupo nunca se forma.
var _in_initial_fill := true
var _now := 0.0
var _respawn_at := -1.0
var _engage_dist := 60.0
## ★ FIELD FIX 05/09/2026 — 0.4 s não dava tempo de VER a morte nem separar um mob do próximo:
## o ator morria, sumia e o seguinte já estava na tela. Com a animação de morte (0.5 s) agora
## visível em `PveMobActor.die_and_free`, o respawn precisa vir DEPOIS dela, com uma batida.
const RESPAWN_DELAY := 1.6
var _rng := RandomNumberGenerator.new()
# hooks de feedback (§8) — o host liga; sem arte nova. Assinatura: func(kind:String, data:Dictionary)
var feedback: Callable = Callable()
# stats de runtime (espelham a session; a autoridade é a HuntService)
var runtime_stats := {"cycles": 0, "kills": 0, "damage_dealt": 0, "heals": 0, "shields": 0, "revives": 0, "ticks": 0, "damage_taken": 0, "deaths": 0}
## ★ FIELD FIX 05/09/2026 — portão de engajamento (ver `tick`). Default TRUE para não mudar nada em
## teste puro de lógica (a161/a162 não têm ator); só o HuntHost, que TEM ator, fecha o portão.
var combat_enabled := true
# A17.10B — FONTE ÚNICA DE HP: quando injetado (GameState), o caster NÃO tem HP próprio — lê/escreve no hp_source
# (adapter, não cópia). Sem hp_source (testes a161/a162) usa o caster dict (compat). Interface esperada do hp_source:
# hero_hp, max_hp_total(), shield_amount, is_hero_defeated(), heal_hero(a), activate_shield(a,d), shield_absorb(r),
# damage_hero(a), reset_hero_hp().
var hp_source = null
const HUNT_SHIELD_DUR := 6.0
signal hero_died()
signal hero_revived()

func setup(p_hs: HuntService, p_character: String, p_ground: String, caster_state: Dictionary, rng_seed: int = 7) -> void:
	hs = p_hs; character = p_character; ground_id = p_ground
	_caster = caster_state.duplicate(true)
	if not _caster.has("current_hp"): _caster["current_hp"] = int(_caster.get("max_hp", 1000))
	if not _caster.has("alive"): _caster["alive"] = true
	if not _caster.has("shield"): _caster["shield"] = 0
	var sp := hs.world.spot_of(character)
	_spot = str(sp.get("spot_id", ""))
	_rng.seed = rng_seed
	_engage_dist = _compute_engage_dist(str(_caster.get("class_id", "LEGACY_CLASS")))

## distância de ENGAJAMENTO: o mob aproxima até onde a classe REALMENTE acerta (§17,leash). Usa a faixa preferida do
## arquétipo, mas nunca além do alcance do ataque confiável (condition "always") — resolve reach (pref>alcance básico).
func _compute_engage_dist(class_id: String) -> float:
	var arch := CharacterClassDefinition.archetype_of(class_id)
	var pref := float(AutoCombatBrain.PREFERRED.get(arch, 60.0))
	var reliable := 0.0
	for aid in ClassAbilityLibrary.abilities_of(class_id):
		var ab := ClassAbilityLibrary.get_ability(aid)
		if str(ab.get("role", "")) == ClassAbilityLibrary.ROLE_OFFENSE and str(ab.get("ai", {}).get("condition", "always")) == "always":
			reliable = maxf(reliable, float(ab.get("range", 0.0)))
	if reliable <= 0.0: return pref
	return minf(pref, reliable * 0.95)

func _emit_fb(kind: String, data: Dictionary) -> void:
	if feedback.is_valid(): feedback.call(kind, data)

## Entrada de spawn para o mob-alvo: usa o perfil do mob_table do ground; se ausente, sintetiza de MobEligibility.
func _target_mob_entry(g: Dictionary) -> Dictionary:
	for e in g.get("mob_table", []):
		if str(e.get("mob_id", "")) == target_mob_id:
			return (e as Dictionary).duplicate(true)
	var m := MobEligibility.get_mob(target_mob_id)
	var lp: Dictionary = m.get("loot_profile", {})
	var gold: Array = lp.get("gold", [4, 8])
	return {"mob_id": target_mob_id, "base_xp": maxi(10, int(m.get("hp", 40)) / 2), "base_gold": int(gold[0]) if gold.size() > 0 else 5}

func _spawn_mob() -> void:
	var g := HuntingGround.get_ground(ground_id)
	# A22.4/A22.5 — TARGETED HUNT: se um target_mob_id foi escolhido, SÓ ele nasce (nunca a família aleatória).
	var mob: Dictionary
	if target_mob_id != "":
		mob = _target_mob_entry(g)
	else:
		mob = HuntingGround.roll_mob(ground_id, _rng.randf())
	var dp: Dictionary = g.get("difficulty_profile", {})
	# A22.6 — dificuldade da Targeted Hunt multiplica hp/dmg por cima do perfil do ground (foundation MissionDifficulty).
	var tier: Dictionary = MissionDifficulty.get_tier(difficulty)
	var thp := float(tier.get("hp_mult", 1.0)); var tdmg := float(tier.get("dmg_mult", 1.0))
	var base_hp := 20 + int(mob.get("base_xp", 10))   # HP simples derivado do perfil
	var hp := int(round(float(base_hp) * float(dp.get("hp_mult", 1.0)) * thp))
	var m := HuntMob.new()
	m.setup(str(mob.get("mob_id", "mob")), hp, _spot, character)
	# A17.10B §14/§15 — AMEAÇA data-driven: dano do mob escala pelo difficulty_profile.dmg_mult sobre o base do mob.
	var base_dmg := 3 + int(mob.get("base_xp", 10)) / 4
	var dmgm := float(dp.get("dmg_mult", 1.0)) * tdmg
	var dmin := int(round(float(base_dmg) * dmgm * 0.8))
	var dmax := int(round(float(base_dmg) * dmgm * 1.2))
	# ★★★ FIELD FIX 05/09/2026 — CADÊNCIA DE ATAQUE DO MOB ESCALA COM O TAMANHO DO GRUPO.
	# 1.5 s por mob era calibrado para UM inimigo. Com 2 no grupo o jogador leva uma pancada a
	# cada 0.75 s; com 3, a cada 0.5 s — foi o "os bichos atacam rápido demais" do field.
	# Aqui o intervalo INDIVIDUAL cresce junto com o grupo, então a pressão TOTAL sobe de forma
	# legível em vez de virar metralhadora. ⛔ Não mexe em dano, só em ritmo.
	m.set_attack(dmin, dmax, 1.5 * maxf(1.0, float(_max_active)))
	add_child(m)   # node REAL no tree
	# ★ STAGE 3 — identidade ÚNICA por instância (não por definição): 3 lobos vivos são 3 ids.
	_instance_seq += 1
	m.instance_id = _instance_seq
	_mob = m                       # PRIMARY
	# ★ STAGE 1 — registra no container do grupo. Com `_max_active = 1` o array tem sempre ≤1
	# elemento, logo o comportamento é idêntico ao antigo; a estrutura é que passa a existir.
	_register_member(m)
	# ★ telemetria medida AQUI (e não só no topo do tick): senão o pico fica um tick atrasado e
	# nunca registra o grupo completo, porque o laço de teste para assim que o cap é atingido.
	group_stats["max_simultaneous_alive"] = maxi(int(group_stats.get("max_simultaneous_alive", 0)), active_mobs().size())
	_emit_fb("spawn", {"mob_id": m.mob_id, "instance_id": m.instance_id, "hp": hp})

# ══════════════════ GROUP CONTAINER (Stage 1) ══════════════════

func _register_member(m: HuntMob) -> void:
	if m == null or _active_mobs.has(m): return
	_active_mobs.append(m)

## Remove o membro do container e conserta o ponteiro PRIMÁRIO (Stage 14 em miniatura: nunca deixar
## `current_mob()` apontando para um morto — é o que causaria dano/HUD no alvo errado).
func _unregister_member(m: HuntMob) -> void:
	_active_mobs.erase(m)
	if _mob == m:
		_mob = null
		for cand in _active_mobs:
			if cand != null and is_instance_valid(cand) and cand.alive():
				_mob = cand; break

## ★★★ STAGE 5 — CRÉDITO EXACT-ONCE por instância.
## Invariante: morte de instância ⇒ 0 ou 1 crédito, NUNCA 2. Retorna true se ESTE chamador tem
## direito de creditar. Com N mortes na mesma janela é aqui que o double-credit seria criado.
func _claim_kill_credit(m: HuntMob) -> bool:
	if m == null: return false
	var iid := int(m.instance_id)
	if iid <= 0:
		# instância sem id (caminho legado/avulso): mantém o comportamento antigo, sem ledger.
		group_stats["credit_granted"] = int(group_stats["credit_granted"]) + 1
		return true
	if _credited_deaths.has(iid):
		group_stats["credit_blocked_dup"] = int(group_stats["credit_blocked_dup"]) + 1
		push_error("[HuntRuntime] DOUBLE-CREDIT BLOQUEADO: instancia %d (%s) tentou creditar 2x" % [iid, m.mob_id])
		return false
	_credited_deaths[iid] = true
	group_stats["credit_granted"] = int(group_stats["credit_granted"]) + 1
	return true

## APIs de grupo (novas) — a compatibilidade legada (`current_mob`) permanece intacta.
## ★★★ STAGE 9 — CLEANUP DO GRUPO. Antes havia 3 caminhos soltos repetindo
## `if _mob != null: _mob.queue_free(); _mob = null`. Agora todos passam por aqui — é o que evita
## ator órfão e ponteiro primário morto quando houver 2–5 membros.
## ⛔ NÃO credita nada: saída/morte do herói NÃO é kill (§19 "encounter encerra sem kill falsa").
func _clear_group() -> void:
	for m in _active_mobs:
		if m != null and is_instance_valid(m):
			if m.get_parent() == self: remove_child(m)
			m.queue_free()
	_active_mobs.clear()
	_mob = null
	# ⛔ NÃO mexer em `_respawn_at` aqui. Eu havia zerado ("sem farm após SAIR") e o PORTÃO DE
	# PARIDADE pegou: o código antigo preservava o timer na morte do herói, e zerá-lo quebrou
	# `TH-T16 AUTO ON resume` (a cadência recomeçava do zero após o revive).
	# "Sem farm após SAIR" é responsabilidade do HOST, que libera o runtime — não deste cleanup.
	# ★★★ Stage 1 é PARIDADE: nenhuma mudança de timing entra aqui.

## ★★★ STAGE 17A — TETO RÍGIDO. Mesmo com config inválida/corrompida o grupo não pode explodir:
## N mobs = N atores + N sinais + N labels de dano. 6 é o número de POCKETS existentes.
const GROUP_HARD_CAP := 6

func set_max_active(v: int) -> void:
	_max_active = clampi(v, 1, GROUP_HARD_CAP)

## ★★★ STAGE 11B — CRÉDITO PERDIDO. O inverso do double-credit: um membro MORTO que continua
## registrado significa que o caminho de morte não rodou ⇒ o jogador matou e não recebeu.
## ⛔ NÃO conserta em silêncio: grita e conta. "Nunca credita a mais, nunca perde calado."
func _sweep_unsettled() -> void:
	for m in _active_mobs.duplicate():
		if m == null or not is_instance_valid(m): continue
		if m.alive(): continue
		var iid := int(m.instance_id)
		if iid > 0 and not _credited_deaths.has(iid):
			group_stats["death_without_credit"] = int(group_stats["death_without_credit"]) + 1
			push_error("[HuntRuntime] CREDITO PERDIDO: instancia %d (%s) morreu sem settlement" % [iid, m.mob_id])
		_unregister_member(m)

func active_mobs() -> Array:
	var out: Array = []
	for m in _active_mobs:
		if m != null and is_instance_valid(m) and m.alive(): out.append(m)
	return out

func active_count() -> int: return active_mobs().size()
func max_active() -> int: return _max_active
func primary_mob() -> HuntMob: return _mob

## Tick real (chamado pelo _process do host OU pelo harness). delta já escalado por game_speed (§10).
func tick(delta: float) -> void:
	_now += delta
	runtime_stats["ticks"] = int(runtime_stats["ticks"]) + 1
	_sync_caster_from_hp()   # A17.10B: FONTE ÚNICA — o caster reflete o HP real do jogador (GameState) quando injetado
	if not bool(_caster.get("alive", true)):
		return   # morto: aguarda revive externo (A1.5) — ver revive()
	# ★★★ STAGE 10 — PREENCHIMENTO DE SLOTS. Com `_max_active = 1` isto é literalmente o código
	# antigo (só nasce quando não há ninguém vivo). Com 2–3, repõe até o cap, uma por janela de
	# respawn — nunca "todos de uma vez", para o jogador VER cada um chegando.
	_sweep_unsettled()   # ★ STAGE 11B — detecta morte sem crédito ANTES de repor slots
	var live := active_mobs()
	group_stats["max_simultaneous_alive"] = maxi(int(group_stats.get("max_simultaneous_alive", 0)), live.size())
	if live.size() < _max_active:
		# ★★★ INITIAL FILL (05/09/2026) — POR QUE ISTO EXISTE:
		# medido no caminho de produção: **104 spawns, 0 grupos**. O TTK do lobo é MENOR que o
		# RESPAWN_DELAY (1.6 s), então o 1º morria antes do 2º nascer e a população oscilava em 1.
		# ⇒ Subir `max_active` sozinho NÃO forma grupo. O grupo precisa NASCER formado.
		# ★ O PRIMEIRO membro segue a cadência normal — isso preserva paridade EXATA com
		#   `max_active = 1` (nesse caso `live` está sempre vazio aqui e este ramo nunca roda).
		# ★ Do 2º em diante, durante o preenchimento inicial, entra um POR TICK (rápido).
		#   Continua valendo SPAWN TICK != COMBAT TICK: cada `_spawn_mob()` retorna sem combater.
		if _in_initial_fill and not live.is_empty():
			_spawn_mob()
			group_stats["initial_fill_spawns"] = int(group_stats.get("initial_fill_spawns", 0)) + 1
			if active_mobs().size() >= _max_active:
				_in_initial_fill = false
				group_stats["group_formed_count"] = int(group_stats.get("group_formed_count", 0)) + 1
			return
		if _respawn_at < 0.0:
			_respawn_at = _now + RESPAWN_DELAY
		elif _now >= _respawn_at:
			_respawn_at = -1.0
			_spawn_mob()
			if not _in_initial_fill:
				group_stats["replacement_spawns"] = int(group_stats.get("replacement_spawns", 0)) + 1
			# ⛔ RETORNA no tick do spawn — o código antigo fazia isso e eu tinha removido.
			# Sem este `return` o combate resolve no MESMO tick em que o mob nasce, antes de
			# `_sync_mob_actor` criar o ator: o bicho podia morrer sem nunca ter existido em tela
			# (quebrou SH-T04/SH-T05/TH-T09 — "mob ator visível"). Nascer é um tick; lutar é o próximo.
			return
	elif _in_initial_fill:
		# grupo completo ⇒ sai do preenchimento e entra em regime permanente (reposição 1 a 1)
		_in_initial_fill = false
		group_stats["group_formed_count"] = int(group_stats.get("group_formed_count", 0)) + 1
	if live.is_empty():
		return   # ninguém vivo ainda: nada de combate neste tick (paridade com o antigo)
	# o PRIMÁRIO precisa ser um membro vivo (promoção já acontece no _unregister_member)
	if _mob == null or not _mob.alive():
		_mob = live[0]
	# ★★★ FIELD FIX 05/09/2026 — PORTÃO DE ENGAJAMENTO VISUAL.
	# O combate resolvia ANTES de o ator chegar: o mob morria em dados enquanto o sprite ainda estava
	# a caminho, e o jogador nunca via o bicho atacar. Relatado em campo como "sincronização ruim".
	# O host liga isto quando o ator do mob REALMENTE engajou. Spawn/respawn ficam ACIMA deste ponto
	# de propósito — senão nada nasceria enquanto o portão estivesse fechado.
	if not combat_enabled:
		return
	# contexto de combate REAL (só o mob DESTE spot §19). O mob APROXIMA até a faixa de engajamento da classe (§17,leash):
	# a distância apresentada é a PREFERIDA do arquétipo, então cada classe joga na sua faixa (melee cola, ranged mantém).
	# AMEAÇA PRIMEIRO (§14): o mob golpeia ao engajar → dano na MESMA fonte de HP (escudo→HP). Pode MATAR o herói (§19).
	# Vem ANTES do dano do herói: senão heróis fortes matam o mob antes de ele atacar (ameaça vira teórica). Só no modo
	# de sobrevivência REAL (hp_source injetado); nos testes puros de lógica (a161/a162) não há ameaça.
	# ★★★ STAGE 10 — TODOS os membros vivos atacam, não só o primário. É daqui que vem a PRESSÃO:
	# com 1 mob o herói apanhava de um; com 2–3 apanha de 2–3, sem tocar em nenhum stat de dano.
	# ★ o evento carrega `instance_id` do ATACANTE (Stage 12A) — o host precisa saber QUEM bateu.
	if hp_source != null:
		for atk in live:
			if atk == null or not is_instance_valid(atk) or not atk.alive(): continue
			var incoming: int = atk.attack_tick(delta)   # `atk` vem de Array untyped ⇒ tipo explícito
			if incoming <= 0: continue
			runtime_stats["mob_attacks"] = int(runtime_stats.get("mob_attacks", 0)) + 1
			_emit_fb("mob_attack", {"instance_id": int(atk.instance_id), "mob_id": atk.mob_id, "amount": incoming})
			if caster_take_damage(incoming):
				return   # morreu neste golpe → sem combate do herói neste tick
	var arch := CharacterClassDefinition.archetype_of(str(_caster.get("class_id", "LEGACY_CLASS")))
	var ctx := {
		"class_id": str(_caster.get("class_id", "melee")),
		"archetype": arch,
		"dist": _engage_dist,
		"target_count": 1, "hp_frac": float(_caster.get("current_hp", 1)) / float(maxi(1, _caster.get("max_hp", 1))),
		"targets": [{"id": _mob.mob_id, "hp": _mob.hp}], "is_boss": false,
	}
	var r := CombatRuntime.step(_caster, ctx, _cds, _now)
	# aplica DANO REAL ao mob
	for d in r.get("damage_events", []):
		# ★★★ FIELD FIX 05/09/2026 (A8) — o dano ao mob agora SAI pelo canal de feedback.
		# `PveMobActor.play_hit()` e o `GameFeedback` (floating damage) existiam há tempo e NUNCA
		# eram chamados por ninguém no PvE: a apresentação estava construída e desconectada.
		# Emitido ANTES do take_damage p/ o número aparecer mesmo no golpe que mata.
		# ★ STAGE 4 — o evento carrega a IDENTIDADE DE INSTÂNCIA. Com grupo, o host precisa saber
		# QUAL ator foi atingido; sem isto o número de dano sobe sempre no primário (alvo errado).
		_emit_fb("hit", {"amount": int(d["amount"]), "mob_id": (_mob.mob_id if _mob != null else ""),
			"instance_id": (int(_mob.instance_id) if _mob != null else 0)})
		var victim := _mob
		if _mob != null and _mob.take_damage(int(d["amount"]), character):
			_on_mob_death(victim)
		runtime_stats["damage_dealt"] = int(runtime_stats["damage_dealt"]) + int(d["amount"])
	# CURA/ESCUDO REAIS — na MESMA fonte de HP (§18: MEND e poção curam o MESMO HP). Sem hp_source, no caster dict (compat).
	for _h in r.get("heal_events", []):
		_apply_heal(int(_h["amount"])); runtime_stats["heals"] = int(runtime_stats["heals"]) + 1; _emit_fb("heal", {})
	for _s in r.get("shield_events", []):
		_apply_shield(int(_s["amount"])); runtime_stats["shields"] = int(runtime_stats["shields"]) + 1; _emit_fb("shield", {})
	if str(r.get("action", "")) == "CAST":
		_emit_fb("cast", {"ability": str(r.get("ability", ""))})

## `victim` = a instância que morreu. Default null = caminho legado (o primário), preservado.
func _on_mob_death(victim: HuntMob = null) -> void:
	var who := victim if victim != null else _mob
	# ★★★ STAGE 5 — PORTÃO DE CRÉDITO. Antes daqui não havia como uma morte creditar 2×, porque
	# só existia uma morte possível. Com grupo isso deixa de ser verdade.
	if not _claim_kill_credit(who):
		return   # já creditado: NÃO credita de novo (o erro já foi gritado no ledger)
	# reward REAL via HuntService (XP/loot no estado do character §22/§23) — autoridade única
	var reward := hs.tick_kill(character)
	runtime_stats["kills"] = int(runtime_stats["kills"]) + 1
	runtime_stats["cycles"] = int(runtime_stats["cycles"]) + 1
	_emit_fb("death", {"mob": str(reward.get("mob", "")), "drops": reward.get("drops", []), "xp": reward.get("kill_xp", 0)})
	# A22 — DROP DE MATERIAL DO MOB (paridade com Mission §Direct Loot): a caça de um mob DEVE dropar o material dele,
	# senão a Targeted Hunt não farmaria o material escolhido. Chance real vem da loot_profile do mob (single truth).
	var dead_id := str(who.mob_id) if who != null else ""
	if hp_source != null and hp_source.has_method("add_material") and dead_id != "":
		var mprof: Dictionary = MobEligibility.get_mob(dead_id).get("loot_profile", {}).get("material", {})
		if not mprof.is_empty() and _rng.randf() < float(mprof.get("chance", 0.0)):
			hp_source.add_material(str(mprof.get("name", "")), int(mprof.get("qty", 1)))
			runtime_stats["materials"] = int(runtime_stats.get("materials", 0)) + 1
	# ★ STAGE 8 — cleanup do MEMBRO (não "do mob atual"): tira do container, conserta o primário e
	# libera o node. Com `_max_active = 1` isto é exatamente o que o código antigo fazia.
	if who != null:
		_unregister_member(who)
		if who.get_parent() == self: remove_child(who)   # remoção determinística (sem acúmulo em -s)
		who.queue_free()   # corpse cleanup REAL
	_respawn_at = _now + RESPAWN_DELAY

## Dano recebido (do mob) — escudo→HP na FONTE ÚNICA (§17). Retorna se MATOU (§19).
## ★★★ FIELD FIX 05/09/2026 (A8/G3) — dano RECEBIDO também precisa de leitura: o jogador relatou
## não perceber quando apanha. Emite "hurt" para o host montar o feedback de dano entrante.
func caster_take_damage(amount: int) -> bool:
	if amount > 0: _emit_fb("hurt", {"amount": int(amount)})
	amount = maxi(0, amount)
	runtime_stats["damage_taken"] = int(runtime_stats["damage_taken"]) + amount
	if hp_source != null:
		var absorbed := int(hp_source.shield_absorb(amount))   # escudo real do GameState
		var to_hp := amount - absorbed
		if to_hp > 0: hp_source.damage_hero(to_hp)
		_sync_caster_from_hp()
		if hp_source.is_hero_defeated():
			_caster["alive"] = false; _on_hero_death(); return true
		return false
	# compat (sem fonte injetada): caster dict
	var ab := AbilityResolution.absorb(amount, int(_caster["current_hp"]), int(_caster.get("shield", 0)))
	_caster["current_hp"] = int(ab["hp"]); _caster["shield"] = int(ab["shield"])
	if int(_caster["current_hp"]) <= 0:
		_caster["current_hp"] = 0; _caster["alive"] = false
		_emit_fb("caster_death", {}); _on_hero_death()
		return true
	return false

func _on_hero_death() -> void:
	runtime_stats["deaths"] = int(runtime_stats["deaths"]) + 1
	_clear_group()   # ★ STAGE 9 — encounter encerra sem kill falsa (§19), agora varrendo o GRUPO
	_respawn_at = -1.0
	hero_died.emit()

## Revive (§20): reusa a verdade única — HP cheio no GameState (ou dict), estado limpo, Auto retoma.
func revive() -> void:
	if hp_source != null:
		hp_source.reset_hero_hp()
		_sync_caster_from_hp()
	else:
		_caster = CombatRuntime.revive(_caster)
	_cds = CooldownTracker.new()   # contexto limpo (§20)
	runtime_stats["revives"] = int(runtime_stats["revives"]) + 1
	hero_revived.emit()
	_emit_fb("revive", {})

## Reflete a fonte de HP no caster (view por-tick). Sem hp_source, no-op (usa o dict próprio — compat).
func _sync_caster_from_hp() -> void:
	if hp_source == null: return
	_caster["current_hp"] = int(hp_source.hero_hp)
	_caster["max_hp"] = maxi(1, int(hp_source.max_hp_total()))
	_caster["shield"] = int(hp_source.shield_amount)
	_caster["alive"] = not hp_source.is_hero_defeated()

func _apply_heal(amount: int) -> void:
	if amount <= 0: return
	if hp_source != null: hp_source.heal_hero(amount); _sync_caster_from_hp()
	else: _caster = AbilityResolution.apply_self_events(_caster, {"heal_events": [{"amount": amount, "target": "self"}], "shield_events": []})

func _apply_shield(amount: int) -> void:
	if amount <= 0: return
	if hp_source != null: hp_source.activate_shield(amount, HUNT_SHIELD_DUR); _sync_caster_from_hp()
	else: _caster = AbilityResolution.apply_self_events(_caster, {"heal_events": [], "shield_events": [{"amount": amount, "target": "self"}]})

func caster_state() -> Dictionary: return _caster.duplicate(true)
func current_mob() -> HuntMob: return _mob
func stop() -> void:
	_clear_group()   # ★ STAGE 9 — cleanup do grupo inteiro (era só o mob único)
