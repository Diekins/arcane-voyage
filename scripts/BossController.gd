class_name BossController extends Node2D
## FATIA A7.4 — RUNTIME GENÉRICO de boss dirigido por BossDefinition. Executa a COMPOSIÇÃO de habilidades
## (scheduler windup→fire→cooldown) e é o encontro de gameplay dos 8 bosses sem script dedicado. Espelha o
## contrato duck-typed de Wolf.gd/Golem.gd (defeated/hp_changed/attack_hero; take_damage/is_alive/set_player/
## set_blockers/force_defeated_state/revive; base imutável has_base_stats/base_max_hp/base_damage_*). SEM
## dependência de física: `tick(delta, dist)` é a entrada pura (self-tests chamam direto); `_process` só a
## reusa quando em cena com player. Summons/hazards são registros INTERNOS (sem node leak) com teto e cleanup.

signal defeated(boss_name: String)
signal hp_changed(hp: int, hp_max: int)
signal attack_hero(amount: int)
# FATIA A8 — feedback (o render/HUD escuta; não altera combate). telegraph_started = aviso ANTES do dano (§10);
# phase_changed = ESCUDO/ENFURECIDO/INVOCANDO/CURA/SALTO (§11).
signal telegraph_started(shape: String, seconds: float, ability_id: String)
signal phase_changed(label: String)

const REF_DMG := 20.0                     # dano de referência p/ escalar a magnitude das abilities pelo dano do boss

var boss_id := ""
var boss_name := ""
var hp_max := 300
var hp := 300
var damage_min := 10
var damage_max := 16
# base imutável (p/ o restat da fase pelo Main, igual Wolf/Golem)
var has_base_stats := false
var base_max_hp := 300
var base_damage_min := 10
var base_damage_max := 16

var _abilities: Array = []                # abilities compostas (Dictionaries)
var _order: Dictionary = {}               # id → índice estável (desempate determinístico do scheduler)
var _cd: Dictionary = {}                  # id → cooldown restante (s)
var _casting: Dictionary = {}             # ability em windup ({} = nenhuma)
var _windup_t := 0.0
var _dmg_scale := 1.0
var _tempo := 1.0                         # FATIA A8: ritmo por boss (§12/§13) — escala windup/cooldown; 1.0 = padrão
# FATIA A10.1 — geometria de hit: quando há POSIÇÃO do player, o dano respeita o TELEGRAPH (line/cone/circle/...),
# não só a distância. `_cur_offset` = player relativo ao boss; `_cast_aim`/`_cast_center` capturados no CAST.
var _cur_offset := Vector2.ZERO
var _has_pos := false
var _cast_aim := Vector2.RIGHT
var _cast_center := Vector2.ZERO
var _alive := true
var _defeated_emitted := false
var _cast_count := 0                      # p/ posições determinísticas (sem Math.random)

# estado das mecânicas novas
var shield_active := false
var _shield_t := 0.0
var enraged := false
var _enrage_dmg_mult := 1.0
var _enrage_speed_mult := 1.0
var _heals_done := 0
var _summons: Array = []                  # cada: {id, minion} — teto por ability.cap; limpo na morte/reset
var _hazards: Array = []                  # cada: {radius, damage, life, tick_t}
var _arena_center := Vector2.ZERO
var _arena_radius := 900.0
var _player = null

# ── Configuração ──
func configure(p_boss_id: String, p_hp_max: int, p_dmg_min: int, p_dmg_max: int) -> void:
	boss_id = p_boss_id
	boss_name = BossDefinition.display_name(p_boss_id)
	hp_max = maxi(1, p_hp_max)
	hp = hp_max
	damage_min = maxi(1, p_dmg_min)
	damage_max = maxi(damage_min, p_dmg_max)
	base_max_hp = hp_max
	base_damage_min = damage_min
	base_damage_max = damage_max
	has_base_stats = true
	_dmg_scale = maxf(0.1, float(damage_max) / REF_DMG)
	_tempo = BossFeedback.tempo(p_boss_id)   # FATIA A8: ritmo distinto por boss (identidade §12)
	_abilities = BossDefinition.abilities_of(p_boss_id)
	var i := 0
	for a in _abilities:
		var aid := BossAbility.id(a)
		_order[aid] = i
		_cd[aid] = float(i) * 0.35   # stagger inicial determinístico (evita disparo simultâneo no t=0)
		i += 1
	emit_signal("hp_changed", hp, hp_max)

func set_arena(center: Vector2, radius: float) -> void:
	_arena_center = center
	_arena_radius = maxf(50.0, radius)

func set_player(p) -> void:
	_player = p

func set_blockers(_b) -> void:
	pass   # BossController valida teleport por bounds/raio de arena (não precisa da lista de blockers)

func is_alive() -> bool:
	return _alive

func summon_count() -> int:
	return _summons.size()

func hazard_count() -> int:
	return _hazards.size()

func is_shielded() -> bool:
	return shield_active

func is_enraged() -> bool:
	return enraged

func heals_done() -> int:
	return _heals_done

# ── Dano recebido (respeita escudo) ──
func take_damage(amount: int) -> void:
	if not _alive:
		return
	var dmg := amount
	if shield_active:
		# absorve conforme a ability de escudo ativa (default: imune enquanto durar)
		dmg = int(round(float(amount) * (1.0 - _active_shield_absorb())))
	hp = maxi(0, hp - maxi(0, dmg))
	emit_signal("hp_changed", hp, hp_max)
	_maybe_enrage()
	if hp <= 0:
		_die()

func apply_knockback(_dir: Vector2, _force: float) -> void:
	pass   # sem física no controller genérico (placeholder de arte)

func force_defeated_state() -> void:
	_alive = false
	hp = 0
	_clear_spawns()

func revive() -> void:
	_alive = true
	_defeated_emitted = false
	hp = hp_max
	enraged = false
	shield_active = false
	_shield_t = 0.0
	_heals_done = 0
	_casting = {}
	_windup_t = 0.0
	_clear_spawns()
	emit_signal("hp_changed", hp, hp_max)

# ── Scheduler (entrada pura, host-driven) ──
## `dist` = distância boss→player (px). SEM posição → hit por DISTÂNCIA (unit tests A7.4 + proxy de kite).
func tick(delta: float, dist: float) -> void:
	_has_pos = false
	_cur_offset = Vector2(dist, 0.0)
	_advance(delta, dist)

## FATIA A10.1 — tick GEOMÉTRICO: recebe a posição do player relativa ao boss → o dano respeita o TELEGRAPH.
func tick_at(delta: float, player_offset: Vector2) -> void:
	_has_pos = true
	_cur_offset = player_offset
	_advance(delta, player_offset.length())

## Avança cooldowns, hazards, escudo, windup e dispara a próxima ability. Compartilhado por tick()/tick_at().
func _advance(delta: float, dist: float) -> void:
	if not _alive:
		return
	# escudo
	if shield_active:
		_shield_t -= delta
		if _shield_t <= 0.0:
			shield_active = false
	# hazards (lifetime + dano periódico enquanto o player está dentro DA ZONA telegrafada)
	_tick_hazards(delta, dist)
	# cooldowns
	for k in _cd:
		_cd[k] = maxf(0.0, float(_cd[k]) - delta)
	# enrage reativo por HP
	_maybe_enrage()
	# cast em andamento?
	if not _casting.is_empty():
		_windup_t -= delta
		if _windup_t <= 0.0:
			var a := _casting
			_casting = {}
			_fire(a, dist)
		return
	# escolhe a próxima ability pronta (menor índice estável = determinístico)
	var pick := _pick_ready()
	if pick.is_empty():
		return
	_casting = pick
	_windup_t = BossAbility.windup(pick) * _tempo / maxf(1.0, _enrage_speed_mult if enraged else 1.0)
	# ★ FATIA A10.1: captura a DIREÇÃO e o CENTRO telegrafados NO CAST (o telegraph "trava" aqui, não no fire §7).
	_cast_aim = _cur_offset.normalized() if _cur_offset.length() > 0.01 else Vector2.RIGHT
	_cast_center = _cur_offset
	# FATIA A8 (§10): habilidade PERIGOSA anuncia o telegraph ANTES do dano (o render desenha a forma).
	var pk := BossAbility.kind(pick)
	if BossFeedback.is_dangerous(pk):
		emit_signal("telegraph_started", BossFeedback.telegraph_kind(pk), _windup_t, BossAbility.id(pick))
	if _windup_t <= 0.0:
		_casting = {}
		_fire(pick, dist)

func _process(delta: float) -> void:
	# só no jogo real (em cena, com player). Nos self-tests o BossController fica fora da árvore → tick()/tick_at().
	if not _alive or not is_inside_tree() or _player == null:
		return
	# ★ A10.1: passa a POSIÇÃO relativa → o dano respeita o telegraph (não só a distância).
	tick_at(delta, _player.global_position - global_position)

# ── internos ──
func _pick_ready() -> Dictionary:
	var best := {}
	var best_idx := 1 << 30
	for a in _abilities:
		var aid := BossAbility.id(a)
		if float(_cd.get(aid, 0.0)) > 0.0:
			continue
		# enrage/shield/heal são reativos: enrage não é "disparado" aqui; heal só quando ferido; escudo quando ferido
		var k := BossAbility.kind(a)
		if k == "enrage":
			continue
		if k == "heal" and hp >= hp_max:
			continue
		if k == "heal" and _heals_done >= int(a.get("max_heals", 1)):
			continue
		var idx := int(_order.get(aid, 1 << 29))
		if idx < best_idx:
			best_idx = idx
			best = a
	return best

func _fire(a: Dictionary, dist: float) -> void:
	_cast_count += 1
	var k := BossAbility.kind(a)
	var aid := BossAbility.id(a)
	_cd[aid] = BossAbility.cooldown(a) * _tempo   # FATIA A8: ritmo por boss (§13)
	# FATIA A8 (§11): habilidade de FASE anuncia o estado (ESCUDO/INVOCANDO/CURA/SALTO).
	if BossFeedback.is_phase(k):
		emit_signal("phase_changed", BossFeedback.phase_label(k))
	match k:
		"line", "cone", "circle", "ground_aoe", "charge", "projectile", "volley":
			# ★ A10.1: com posição → o dano respeita a GEOMETRIA telegrafada; sem posição → distância (A7.4/kite).
			var hit := BossHitGeometry.hits(a, _cur_offset, _cast_aim, _cast_center) if _has_pos else BossAbility.hits_at(a, dist)
			if hit:
				var per := int(round(float(BossAbility.damage(a)) * _dmg_scale * (_enrage_dmg_mult if enraged else 1.0)))
				var total := per * BossAbility.hit_count(a)
				if total > 0:
					emit_signal("attack_hero", total)
		"shield":
			shield_active = true
			_shield_t = float(a.get("duration", 1.0))
		"summon":
			_do_summon(a)
		"teleport":
			_do_teleport(a)
		"heal":
			_do_heal(a)
		"hazard":
			_do_hazard(a)
		_:
			pass

func _do_summon(a: Dictionary) -> void:
	var cap := int(a.get("cap", 1))
	var want := int(a.get("count", 1))
	var minion := str(a.get("minion", ""))
	var n := 0
	while n < want and _summons.size() < cap:
		_summons.append({"minion": minion, "serial": _cast_count * 100 + n})
		n += 1
	# §26: teto respeitado (nunca > cap); sem loop infinito (while limitado por want e cap).

func _do_teleport(a: Dictionary) -> void:
	# §28: alvo dentro do raio da arena; fallback = fica onde está se o alvo sair dos bounds.
	var reach := float(a.get("reach", 0.0))
	var ang := float(_cast_count) * 2.399963   # ângulo áureo (determinístico, bem distribuído)
	var target := global_position + Vector2(cos(ang), sin(ang)) * reach
	if _arena_center.distance_to(target) <= _arena_radius:
		global_position = target
	# senão: mantém a posição (fallback seguro)

func _do_heal(a: Dictionary) -> void:
	# §29: teto de curas por encontro → não cria combate infinito.
	if _heals_done >= int(a.get("max_heals", 1)):
		return
	if hp >= hp_max:
		return
	var amt := int(round(float(a.get("heal_frac", 0.1)) * float(hp_max)))
	hp = mini(hp_max, hp + maxi(1, amt))
	_heals_done += 1
	emit_signal("hp_changed", hp, hp_max)

func _do_hazard(a: Dictionary) -> void:
	# §27: teto de zonas; lifetime finito; cleanup na morte/reset.
	var cap := int(a.get("cap", 1))
	if _hazards.size() >= cap:
		return
	_hazards.append({
		"radius": float(a.get("radius", 100.0)),
		"damage": int(a.get("damage", 0)),
		"life": float(a.get("lifetime", 1.0)),
		"tick_t": 1.0,
		"center": _cast_center,   # ★ A10.1: cada hazard guarda seu CENTRO telegrafado (§8) — dano só DENTRO da zona
	})

func _tick_hazards(delta: float, dist: float) -> void:
	var keep: Array = []
	for hz in _hazards:
		hz["life"] = float(hz["life"]) - delta
		hz["tick_t"] = float(hz["tick_t"]) - delta
		if float(hz["tick_t"]) <= 0.0:
			hz["tick_t"] = 1.0
			# ★ A10.1: com posição → dentro da ZONA telegrafada (center+radius); sem posição → distância (A7.4).
			var inside := (_cur_offset.distance_to(hz.get("center", Vector2.ZERO)) <= float(hz["radius"])) if _has_pos else (dist <= float(hz["radius"]))
			if inside:
				var d := int(round(float(hz["damage"]) * _dmg_scale * (_enrage_dmg_mult if enraged else 1.0)))
				if d > 0:
					emit_signal("attack_hero", d)
		if float(hz["life"]) > 0.0:
			keep.append(hz)
	_hazards = keep   # expiradas são descartadas (sem leak)

func _maybe_enrage() -> void:
	if enraged:
		return
	for a in _abilities:
		if BossAbility.kind(a) != "enrage":
			continue
		if float(hp) <= float(a.get("hp_frac", 0.4)) * float(hp_max):
			enraged = true
			_enrage_dmg_mult = float(a.get("dmg_mult", 1.5))
			_enrage_speed_mult = float(a.get("speed_mult", 1.25))
			emit_signal("phase_changed", BossFeedback.phase_label("enrage"))   # FATIA A8: "ENFURECIDO" (§11)
			return

func _active_shield_absorb() -> float:
	for a in _abilities:
		if BossAbility.kind(a) == "shield":
			return float(a.get("absorb", 1.0))
	return 1.0

func _clear_spawns() -> void:
	# §26/§27: summons e hazards NÃO persistem para a próxima fase / morte / reset.
	_summons.clear()
	_hazards.clear()

func _die() -> void:
	if _defeated_emitted:
		return
	_alive = false
	_defeated_emitted = true
	_clear_spawns()
	emit_signal("defeated", boss_name)
