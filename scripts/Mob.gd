extends Node2D
## Mob.gd — mob COMUM top-down (GODOT-REGION-MOBS-1; animação GODOT-ANIMATION-PIPELINE-1).
## Persegue/ataca o Errante, dá XP/gold/loot ao morrer e RESPAWNA. A apresentação (idle/walk/
## attack/hit/death) é delegada ao ActorAnimator — com death ANTES de sumir/respawnar.

signal died(mob: Node)
signal attack_hero(amount: int)

const BAR_W := 56.0

@export var mob_id: String = ""
## Chave de sprite (GODOT-HUNTS-WAVE-2): reusa a arte de OUTRO mob sem duplicar PNG. Vazio = usa o
## próprio mob_id (comportamento original). Ex.: "starving_wolf" com visual_key "young_wolf" anima
## com a sheet do lobo. Não afeta mob_id (quest-targeting/identidade seguem pelo mob_id).
@export var visual_key: String = ""
@export var mob_name: String = "Mob"
@export var max_hp: int = 30
@export var xp_reward: int = 10
@export var gold_reward: int = 3
@export var damage_min: int = 3
@export var damage_max: int = 6
@export var aggro_range: float = 320.0
@export var attack_range: float = 90.0
@export var attack_cooldown: float = 1.4
@export var windup_time: float = 0.4    # telegraph: aviso ANTES do golpe (GODOT-MOB-AI-TELEGRAPH-1)
@export var recover_time: float = 0.25  # recuperação curta DEPOIS do golpe
# LINGUAGEM DOS GUARDIÕES (GODOT-GUARDIAN-LANGUAGE-1): tematiza o telegraph JÁ EXISTENTE (cor/raio) p/ comunicar o
# conceito do guardião. Defaults = comportamento atual (mobs comuns inalterados). Setados antes do add_child (lidos no _ready).
@export var telegraph_color: Color = Color(0.96, 0.42, 0.22)
@export var telegraph_scale: float = 1.0
# ★ FORMA DO TELEGRAPH (TELEGRAPH_SHAPES_PASS_01) — a LINGUAGEM do inimigo. Default "circle" = comportamento LEGADO
# IDÊNTICO (anel + acerto por distância). "line" = investida (faixa estreita + avanço rápido na direção travada;
# reação: sair da trajetória). "cone" = leque frontal (reação: não ficar na frente). Só afeta MELEE; ranged ignora.
@export var telegraph_shape: String = "circle"
@export var telegraph_reach: float = 220.0     # alcance da forma (comprimento da investida / raio do cone)
@export var telegraph_half_width: float = 36.0 # meia-largura da faixa (line)
@export var cone_degrees: float = 70.0         # abertura do leque (cone)
@export var lunge_speed: float = 1180.0        # velocidade do avanço da investida (line) — rápido = "investida"
@export var lunge_time: float = 0.18           # duração do avanço da investida
# ★ FRASE DE BOSS (BOSS_IDENTITY_PASS_01) — sequência de formas que a criatura cicla a cada golpe (ex.:
# [{"shape":"cone","reach":150},{"shape":"circle"}]). Default VAZIO = um único telegraph_shape (mobs comuns
# inalterados). Cada entrada pode trazer reach/cone/half próprios; ausentes caem nos campos estáticos acima.
@export var telegraph_cycle: Array = []
@export var speed: float = 110.0
@export var respawn_seconds: float = 6.0
@export var body_color: Color = Color("8a6d54")
@export var body_radius: float = 22.0
@export var shape: String = "circle"   # "circle" (Lobo Jovem) | "diamond" (Morcego Cristalino)
@export var side_faces_left: bool = false   # arte lateral encara a esquerda (lobo); orientação do flip
@export var can_flip: bool = true           # false p/ mob frontal/simétrico (morcego) — não espelha
@export var show_back: bool = false         # true = mostra a arte de COSTAS (move_up) ao subir; default false = perfil lateral (mobs)
# RANGED (GODOT-RANGED-COMBAT-MVP-1): mob que ataca à distância via projétil. Tudo opcional/data-driven;
# default false → mobs melee existentes intactos. attack_range maior é setado na config do mob.
@export var ranged: bool = false
@export var projectile_speed: float = 420.0
@export var projectile_color: Color = Color(0.86, 0.93, 0.97)   # estilhaço de sal (pálido)
@export var projectile_impact_vfx: String = "impact_blue_magic"
@export var projectile_hit_radius: float = 70.0                 # raio de acerto no ponto de impacto (dodge)
# wander leve (GODOT-IDLE-MOTION-FIX-AND-MOB-WANDER-1): passeio perto do spawn quando SEM alvo
@export var can_wander: bool = true
@export var wander_radius: float = 120.0    # raio do passeio ao redor do spawn
@export var leash_radius: float = 230.0     # afastou demais → prioriza voltar p/ a origem
@export var wander_speed: float = 52.0      # passo de passeio (mais lento que a perseguição)
@export var idle_pause_min: float = 1.0     # parada entre passeios
@export var idle_pause_max: float = 3.0
# IA de chase refinada (GODOT-MOB-COMBAT-BEHAVIOR-2): anti-stuck + leash de perseguição
@export var stuck_timeout: float = 0.5      # tempo travado antes de alternar o lado do desvio
@export var sidestep_strength: float = 0.9  # quanto do passo vira desvio perpendicular ao bater
@export var give_up_time: float = 1.8       # travado tempo demais → desiste e volta pro spawn
@export var chase_leash: float = 560.0      # longe DEMAIS do spawn perseguindo → solta e volta a passear

var hp: int = 30
var alive: bool = true
var combat_enabled: bool = true
# Serial de MORTE (FATIA A2): incrementa a cada _die(). Usado só para a chave de anti-dupla-contagem do
# StageDirector ("instanceId:deaths") — a MESMA morte reporta a mesma chave; respawn+morte = serial novo =
# conta de novo. NÃO persiste, NÃO afeta combate/loot/XP.
var deaths: int = 0
# STATS-BASE IMUTÁVEIS (FATIA A3): a config ORIGINAL do mob, gravada uma vez no spawn. O stage scaling do
# StageDirector deriva SEMPRE daqui (nunca do já-escalado) → sem acúmulo entre fases. `respawn()` também
# reescala a partir daqui via o Main (o mob volta com o stat da fase corrente, não o base cru).
var has_base_stats: bool = false
var base_max_hp: int = 0
var base_damage_min: int = 0
var base_damage_max: int = 0
var floor_level: int = 0   # VERTICALITY F2: andar do mob; só detecta/ataca o Errante no MESMO andar. Default 0 = legado.
var spawn_position: Vector2 = Vector2.ZERO
var loot_table: Array = []   # [{ "name": String, "chance": float }]
var _player: Node2D
var _body: Node2D            # forma da criatura (animada pelo ActorAnimator)
var _overlay: Node2D         # nome + barra de HP (some na morte, volta no respawn)
var _bar_fill: ColorRect
var _anim: ActorAnimator
var _attack_cd: float = 0.0
var _respawn_t: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _wander_pause: float = 0.0
# IA leve + telegraph (GODOT-MOB-AI-TELEGRAPH-1)
var _winding: bool = false       # em preparação de ataque (telegraph aceso, parado)
var _recover_t: float = 0.0      # recuperação após o golpe
var _tele: AttackTelegraph
# FORMAS (TELEGRAPH_SHAPES_PASS_01): mira TRAVADA no início do windup (o que torna a forma legível/desviável — o
# golpe NÃO re-mira no disparo) + estado da INVESTIDA (line: avança na direção travada como follow-through visual).
var _aim_dir: Vector2 = Vector2.DOWN
var _lunging: bool = false
var _lunge_t: float = 0.0
var _lunge_dir: Vector2 = Vector2.DOWN
# BEAT ATUAL (BOSS_IDENTITY_PASS_01): a forma deste golpe específico. Sem ciclo = igual aos campos estáticos.
var _cur_shape: String = "circle"
var _cur_reach: float = 220.0
var _cur_cone: float = 70.0
var _cur_half: float = 36.0
var _cycle_idx: int = 0
# colisão com props/blockers (GODOT-MOB-COLLISION-BLOCKERS-1): reaproveita os Rect2 da região
var _blockers: Array = []
var _stuck_t: float = 0.0        # tempo acumulado preso ao perseguir (anti-stuck)
var _returning: bool = false     # desistiu da perseguição → voltando ao spawn

## Pé da criatura (ponto testado contra os blockers — abaixo do centro, ~base do sprite).
func _feet() -> Vector2:
	return Vector2(0, body_radius * 0.5)

func set_blockers(rects: Array) -> void:
	_blockers = rects

func _blocked(p: Vector2) -> bool:
	for r in _blockers:
		if r.has_point(p):
			return true
	return false

## Move com SLIDE por eixo (igual ao Errante): desliza na parede em vez de atravessar/grudar.
func _move_by(disp: Vector2) -> void:
	var feet := _feet()
	var nx := position.x + disp.x
	if not _blocked(Vector2(nx, position.y) + feet):
		position.x = nx
	var ny := position.y + disp.y
	if not _blocked(Vector2(position.x, ny) + feet):
		position.y = ny

func _ready() -> void:
	hp = max_hp
	spawn_position = position
	_wander_target = spawn_position
	_wander_pause = randf_range(idle_pause_min, idle_pause_max)   # começa parado (escalonado)
	_build_visual()
	_anim = ActorAnimator.new()
	add_child(_anim)
	var _vkey := visual_key if visual_key != "" else mob_id   # reuso de arte sem duplicar PNG (WAVE-2)
	_anim.setup(_body, "mobs/" + _vkey, 3.0, side_faces_left, can_flip)
	_anim.suppress_back = not show_back   # mobs nunca dão as costas (perfil ao subir); show_back=true reativa move_up (Coloso 4-dir)
	_tele = AttackTelegraph.new()
	_tele.radius = (body_radius + 10.0) * telegraph_scale   # guardião = aviso maior (GUARDIAN-LANGUAGE-1)
	_tele.warn_color = telegraph_color                       # guardião = cor temática do conceito
	add_child(_tele)
	_tele.fired.connect(_on_tele_fired)

func set_player(p: Node2D) -> void:
	_player = p

func is_alive() -> bool:
	return alive

## VERTICALITY F2: o Errante está no MESMO andar que este mob? (sem o campo no player → 0 = legado)
func _player_same_floor() -> bool:
	if _player == null:
		return false
	var pv = _player.get("floor_level")
	return (int(pv) if pv != null else 0) == floor_level

func _build_visual() -> void:
	_add_shadow()
	_body = Node2D.new()
	add_child(_body)
	var shp := Polygon2D.new()
	var pts := PackedVector2Array()
	if shape == "diamond":
		pts = PackedVector2Array([Vector2(0, -body_radius), Vector2(body_radius * 0.7, 0), Vector2(0, body_radius), Vector2(-body_radius * 0.7, 0)])
	else:
		for i in range(14):
			var a := TAU * i / 14.0
			pts.append(Vector2(cos(a) * body_radius, sin(a) * body_radius * 0.9))
	shp.polygon = pts
	shp.color = body_color
	_body.add_child(shp)

	_overlay = Node2D.new()
	_overlay.z_as_relative = false   # nome+barra SEMPRE por cima dos props (y-sort não os esconde)
	_overlay.z_index = 4000
	add_child(_overlay)
	var name_label := Label.new()
	name_label.text = mob_name
	name_label.position = Vector2(-30, -body_radius - 42)   # nameplate: nome no topo (acima da barra)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.modulate = Color(1, 1, 1, 0.85)
	_overlay.add_child(name_label)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.6)
	bar_bg.size = Vector2(BAR_W, 6)
	bar_bg.position = Vector2(-BAR_W / 2.0, -body_radius - 24)   # barra acima do sprite, sob o nome
	_overlay.add_child(bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color("c8553d")
	_bar_fill.size = Vector2(BAR_W, 6)
	_bar_fill.position = Vector2(-BAR_W / 2.0, -body_radius - 24)
	_overlay.add_child(_bar_fill)

func _add_shadow() -> void:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * body_radius * 0.8, sin(a) * body_radius * 0.3 + body_radius * 0.7))
	poly.polygon = pts
	poly.color = Color(0, 0, 0, 0.22)
	poly.z_index = -1
	add_child(poly)

func _process(delta: float) -> void:
	if not alive:
		_respawn_t -= delta
		if _respawn_t <= 0.0:
			respawn()
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if _kb.length() > 1.0:                       # empurrão do hit (game-feel) tem prioridade e decai
		_move_by(_kb * delta)
		_kb = _kb.move_toward(Vector2.ZERO, KB_DECAY * delta)
	# INVESTIDA (line, TELEGRAPH_SHAPES_PASS_01): avança RÁPIDO na direção travada (follow-through visual da faixa;
	# o dano já foi resolvido no disparo). Desliza nos blockers via _move_by. Tem prioridade sobre o recover.
	if _lunging:
		_lunge_t -= delta
		_move_by(_lunge_dir * lunge_speed * delta)
		if _anim != null:
			_anim.play_attack(_lunge_dir)
		if _lunge_t <= 0.0:
			_lunging = false
		return
	# RECUPERAÇÃO pós-golpe: para um instante (não anda nem ataca)
	if _recover_t > 0.0:
		_recover_t -= delta
		if _anim != null:
			_anim.play_idle()
		return
	# WINDUP (telegraph aceso): fica parado encarando o alvo até o AttackTelegraph disparar
	if _winding:
		if _player != null and _anim != null:
			_anim.set_direction(_player.position - position)
			_anim.play_idle()
		return
	# DESISTIU (preso tempo demais) → volta ao spawn, ignorando o alvo até chegar.
	if _returning:
		_return_tick(delta)
		return
	# COM alvo no aggro E dentro do leash de perseguição → persegue/ataca. Senão → passeia (que já
	# prioriza voltar ao spawn quando passa do leash_radius do wander).
	if _player != null and _player_same_floor() and position.distance_to(_player.position) <= aggro_range \
			and position.distance_to(spawn_position) <= chase_leash:   # VERTICALITY F2: detecção/perseguição só same-level
		_combat_tick(delta)
	else:
		_wander_tick(delta)

## Perseguição + ataque com ANTI-STUCK: no alcance → encara/golpeia; longe → anda; se BATER numa
## parede, tenta desvio perpendicular (alternando o lado); se ficar preso tempo demais, DESISTE.
func _combat_tick(delta: float) -> void:
	var d := position.distance_to(_player.position)
	var to_player := _player.position - position
	if d <= attack_range:
		_stuck_t = 0.0
		if _anim != null:
			_anim.play_idle()
			_anim.set_direction(to_player)
		if combat_enabled and _attack_cd <= 0.0:
			_attack_cd = attack_cooldown
			_begin_windup(to_player)
		return
	# perseguir: tenta ir direto; mede o quanto andou de fato
	var step := to_player.normalized() * speed * delta
	var before := position
	_move_by(step)
	if (position - before).length() >= step.length() * 0.5:
		_stuck_t = 0.0
		if _anim != null:
			_anim.play_walk(to_player)
		return
	# bateu na parede → desvio PERPENDICULAR (alterna de lado a cada stuck_timeout)
	_stuck_t += delta
	var sgn := 1.0 if (int(_stuck_t / maxf(0.05, stuck_timeout)) % 2 == 0) else -1.0
	var perp := Vector2(-to_player.y, to_player.x).normalized() * sgn * sidestep_strength
	_move_by(perp * speed * delta)
	if _anim != null:
		_anim.play_walk(perp)
	if _stuck_t > give_up_time:   # preso demais → desiste e volta pro spawn
		_returning = true
		_stuck_t = 0.0

## Retorno ao spawn após desistir; ao chegar (ou travar de novo) volta ao comportamento normal.
func _return_tick(delta: float) -> void:
	var to := spawn_position - position
	if to.length() <= 40.0:
		_returning = false
		_wander_pause = randf_range(idle_pause_min, idle_pause_max)
		if _anim != null:
			_anim.play_idle()
		return
	var step := to.normalized() * speed * delta
	var before := position
	_move_by(step)
	if (position - before).length() < step.length() * 0.5:   # travou até no retorno (relativo ao passo) → solta como wander
		_returning = false
		_pick_wander_target()
		return
	if _anim != null:
		_anim.play_walk(to)

## Inicia o telegraph: encara o alvo, TRAVA a mira e acende o aviso na FORMA do inimigo; o golpe sai quando o
## AttackTelegraph disparar. A mira travada (_aim_dir) é o que torna a forma legível: o jogador lê o desenho e sai
## da zona ANTES do disparo (a forma não persegue). (TELEGRAPH_SHAPES_PASS_01)
func _begin_windup(to_player: Vector2) -> void:
	_winding = true
	_aim_dir = to_player.normalized() if to_player.length() > 0.001 else Vector2.DOWN
	# BEAT desta vez: se há FRASE (telegraph_cycle), pega o próximo beat; senão usa os campos estáticos.
	var beat := {}
	if not telegraph_cycle.is_empty():
		beat = telegraph_cycle[_cycle_idx % telegraph_cycle.size()]
		_cycle_idx += 1
	_cur_shape = str(beat.get("shape", telegraph_shape))
	_cur_reach = float(beat.get("reach", telegraph_reach))
	_cur_cone = float(beat.get("cone", cone_degrees))
	_cur_half = float(beat.get("half", telegraph_half_width))
	# CIRCLE HONESTO (COMBAT_HONESTY_PASS_01): o anel desenha o RAIO REAL de acerto (= o mesmo attack_range×1.2 que
	# _player_in_shape usa). Não toca o dano/alcance — só faz o aviso dizer a verdade.
	if _cur_shape == "circle":
		_cur_reach = attack_range * 1.2
	if _anim != null:
		_anim.set_direction(to_player)
	if _tele != null:
		_tele.configure(_cur_shape, _aim_dir, _cur_reach, _cur_half, _cur_cone)
		_tele.begin(windup_time)

## Fim do windup: SE o alvo ainda estiver na ZONA DA FORMA (travada), aplica o golpe; senão ERRA (desviou). A faixa
## "line" ainda AVANÇA (investida) tenha acertado ou não. (TELEGRAPH_SHAPES_PASS_01)
func _on_tele_fired() -> void:
	_winding = false
	_recover_t = recover_time
	if not alive or not combat_enabled or _player == null or not _player_same_floor():
		return   # VERTICALITY F2: se o Errante mudou de andar durante o windup, o golpe ERRA
	# RANGED ignora a forma (dispara projétil dodgeável ao ponto; acerto por proximidade legado).
	if ranged:
		var to_player := _player.position - position
		if to_player.length() <= attack_range * 1.2:
			if _anim != null:
				_anim.play_attack(to_player)
			_fire_projectile(_player.position)   # RANGED: dispara estilhaço (dano no impacto, dodgeável)
		return
	# MELEE: o acerto CASA com a forma travada — "saia da trajetória" (line) / "não fique na frente" (cone) /
	# "afaste-se" (circle, legado: distância ≤ attack_range*1.2).
	var hit := _player_in_shape()
	if hit:
		if _anim != null:
			_anim.play_attack(_aim_dir)
		attack_hero.emit(CombatMath.enemy_roll(damage_min, damage_max))   # A1.5: fonte central (== randi_range)
	# INVESTIDA: a faixa "line" avança na direção travada independentemente de ter acertado (carrega através).
	if _cur_shape == "line":
		_lunging = true
		_lunge_t = lunge_time
		_lunge_dir = _aim_dir

## O Errante está dentro da ZONA da forma do BEAT atual? (TELEGRAPH_SHAPES + BOSS_IDENTITY) — usa os helpers
## estáticos de AttackTelegraph (compartilhados com Wolf/Golem).
func _player_in_shape() -> bool:
	if _player == null:
		return false
	match _cur_shape:
		"line":
			return AttackTelegraph.in_line(_player.position, position, _aim_dir, _cur_reach, _cur_half)
		"cone":
			return AttackTelegraph.in_cone(_player.position, position, _aim_dir, _cur_reach, _cur_cone)
		_:        # circle (legado): proximidade
			return (_player.position - position).length() <= attack_range * 1.2

## Dispara um MobProjectile ao ponto-alvo (snapshot). O dano sai no impacto via signal `hit` → reencaminhado
## p/ `attack_hero` (mesmo caminho de dano do melee). NÃO bloqueia/garante acerto: dodgeável saindo do ponto.
func _fire_projectile(target: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var muzzle := position + Vector2(0, -body_radius * 0.5)
	var dmg := CombatMath.enemy_roll(damage_min, damage_max)   # A1.5: fonte central (== randi_range)
	var proj := MobProjectile.spawn(parent, muzzle, target, projectile_speed, dmg, _player, projectile_color, projectile_impact_vfx, projectile_hit_radius)
	if proj != null:
		proj.set_blockers(_blockers)   # COBERTURA (PROJECTILE_COVER_PASS_01): pilares/rochas barram o tiro
		proj.hit.connect(func(d): if alive and combat_enabled: attack_hero.emit(d))

## Wander leve: passeia até um ponto aleatório perto do spawn, para 1–3s, repete. Se afastar
## demais (leash), prioriza voltar à origem. Sem alvo nem pathfinding — só ambiente "vivo".
func _wander_tick(delta: float) -> void:
	if _anim == null:
		return
	if not can_wander:
		_anim.play_idle()
		return
	if _wander_pause > 0.0:
		_wander_pause -= delta
		_anim.play_idle()
		return
	if position.distance_to(spawn_position) > leash_radius:
		_wander_target = spawn_position   # voltar p/ perto da origem tem prioridade
	var to := _wander_target - position
	if to.length() <= 8.0:
		# chegou → para um tempo, talvez vira p/ um lado, e escolhe o próximo destino
		_wander_pause = randf_range(idle_pause_min, idle_pause_max)
		_anim.play_idle()
		if randf() < 0.6:
			_anim.set_direction(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)))
		_pick_wander_target()
		return
	# limiar de "travado" RELATIVO ao passo (frame-rate independente): em monitor de alta taxa o passo por
	# frame é pequeno; um 0.4 ABSOLUTO disparava "travado" todo frame e o mob NUNCA passeava (GODOT-WORLD-LIFE-AMBIENT-1 fix).
	var step := to.normalized() * wander_speed * delta
	var before := position
	_move_by(step)
	if (position - before).length() < step.length() * 0.5:   # bateu num blocker de verdade → outro destino
		_pick_wander_target()
		_wander_pause = randf_range(idle_pause_min * 0.4, idle_pause_max * 0.5)
		_anim.play_idle()
		return
	_anim.play_walk(to)

func _pick_wander_target() -> void:
	# tenta alguns destinos; rejeita os que caem DENTRO de um blocker (não passeia pra dentro de pedra)
	for _i in range(6):
		var ang := randf() * TAU
		var r := randf_range(wander_radius * 0.35, wander_radius)
		var t := spawn_position + Vector2(cos(ang), sin(ang)) * r
		if not _blocked(t + _feet()):
			_wander_target = t
			return
	_wander_target = spawn_position   # fallback: volta pro spawn (presumido livre)

const KB_DECAY := 1100.0
var _kb := Vector2.ZERO

## Empurrão ao levar um golpe (GODOT-COMBAT-JUICE-1) — afasta do atacante; decai rápido no _process.
func apply_knockback(from_pos: Vector2, strength: float) -> void:
	if not alive:
		return
	var dir := position - from_pos
	if dir.length() < 0.01:
		dir = Vector2.DOWN
	_kb = dir.normalized() * strength

func take_damage(amount: int) -> void:
	if not alive:
		return
	hp = maxi(0, hp - amount)
	if _bar_fill != null:
		_bar_fill.size.x = BAR_W * (float(hp) / float(max_hp))
	_spawn_damage(amount)
	if _anim != null:
		if _player != null:
			_anim.set_direction(_player.position - position)
		_anim.play_hit()
	if hp <= 0:
		_die()

func _spawn_damage(amount: int) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.modulate = Color("ffd24a")
	lbl.position = position + Vector2(randf_range(-14.0, 14.0), -body_radius - 10.0)
	lbl.z_as_relative = false
	lbl.z_index = 4090
	get_parent().add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 40.0, 0.55)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lbl.queue_free)

func _die() -> void:
	alive = false
	deaths += 1                 # FATIA A2: serial de morte p/ a chave de dedup do StageDirector
	_winding = false
	_lunging = false
	_recover_t = 0.0
	if _tele != null:
		_tele.cancel()
	if _overlay != null:
		_overlay.visible = false
	_respawn_t = respawn_seconds
	died.emit(self)             # Main concede XP/gold/loot AGORA
	if _anim != null:
		_anim.play_death()      # fade/sink/squash (não some instantâneo)

func respawn() -> void:
	alive = true
	hp = max_hp
	position = spawn_position
	_wander_target = spawn_position
	_wander_pause = randf_range(idle_pause_min, idle_pause_max)
	_returning = false
	_lunging = false
	_cycle_idx = 0
	_stuck_t = 0.0
	if _anim != null:
		_anim.reset()
	if _overlay != null:
		_overlay.visible = true
	if _bar_fill != null:
		_bar_fill.size.x = BAR_W
