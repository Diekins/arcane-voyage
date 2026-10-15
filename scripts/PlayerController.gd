extends Node2D
## PlayerController — movimento TOP-DOWN do Errante. A APRESENTAÇÃO (idle/walk/attack/hit/downed
## + flip) é delegada ao ActorAnimator (GODOT-ANIMATION-PIPELINE-1); aqui fica só a física simples
## (accel/atrito) e o clamp aos limites do MAPA. `hit_recoil()`/`attack()`/`set_downed()` são a ponte.

@export var speed: float = 300.0
@export var accel: float = 2200.0
@export var friction: float = 2600.0
var locked := false

## Visual por arquétipo de arma (GODOT-PLAYER-ARCHETYPE-SPRITES-1) → chave do ActorAnimator
## (res://assets/actors/<chave>.png + _side/_up). Sem arma / desconhecida → Errante padrão.
const ARCHETYPE_VISUALS := {
	"sword": "hero/player_wanderer_sword",
	"bow":   "hero/player_wanderer_archer",
	"staff": "hero/player_wanderer_mage",
	"spear": "hero/player_wanderer_spearman",
	"book":  "hero/player_wanderer_oracle",   # Oráculo (GODOT-ORACLE-SPRITE-PLUG-1)
	# Machado/Martelo (GODOT-WARRIOR-WEAPONS-AXE-HAMMER-1): SEM sprite própria ainda → reusam o visual do
	# Guerreiro (espada) p/ não cair no Errante desarmado. Sprites dedicadas de machado/martelo virão depois.
	"axe":   "hero/player_wanderer_sword",
	"hammer": "hero/player_wanderer_sword",
}
const DEFAULT_VISUAL := "hero/errante"

var _bounds_min := Vector2.ZERO
var _bounds_max := Vector2(100000, 100000)
var _blockers: Array = []        # Rect2 de obstáculos (árvores/pedras/paredes) — bloqueiam o pé
var floor_level: int = 0         # VERTICALITY F1: andar ativo (runtime; Main troca via _set_floor_level). Default 0 = legado.
const FEET_Y := 14.0             # ponto de colisão = pés (abaixo do centro)
var _vel := Vector2.ZERO
var _sprite: Sprite2D
var _anim: ActorAnimator
var facing := Vector2.DOWN          # última direção encarada (p/ disparo à distância sem alvo travado)
# Auto-approach (GODOT-BATTLE-UI-MOUSE-3): caminhar até um alvo clicado quando não há WASD. QUALQUER
# WASD assume o controle e cancela (sinaliza `_manual_cancel` p/ o Main soltar a perseguição).
var move_target: Vector2 = Vector2.INF   # ponto-destino do auto-walk; INF = sem destino
var move_stop: float = 0.0               # para de andar a esta distância do destino (≈ alcance da arma)
var _manual_cancel := false              # houve WASD desde a última leitura (o Main consome)

# ── ESQUIVA / "O SEGUNDO VERBO" (COMBAT_FEEL_BUILD_01) — prova de conceito ────────────────────────────────────
# Dash curto + i-frames curtos + cooldown simples. Atrás de DODGE_ENABLED (off = comportamento LEGADO idêntico:
# nenhum dash/i-frame). SEM stamina, atributo, árvore de talento ou equipamento — é um experimento de FEEL.
const DODGE_ENABLED := true
const DODGE_SPEED := 900.0      # velocidade do dash (×DODGE_TIME ≈ 144px de deslocamento)
const DODGE_TIME := 0.16        # duração do deslocamento
const DODGE_IFRAMES := 0.22     # janela de invulnerabilidade (cobre o instante do golpe telegrafado)
const DODGE_COOLDOWN := 0.85    # recarga simples (anti-spam; não trivializa)
const DODGE_KEY := KEY_SPACE    # botão DEDICADO
var _dodge_t := 0.0             # tempo restante de dash (>0 = está esquivando)
var _iframe_t := 0.0           # tempo restante de i-frames
var _dodge_cd := 0.0           # recarga restante
var _dodge_dir := Vector2.DOWN
var _dodge_was_pressed := false # edge-detection da tecla dedicada
var _iframe_vis := false        # o tint azul de "intangível" está ativo?

func set_move_target(p: Vector2, stop_dist: float) -> void:
	move_target = p
	move_stop = stop_dist

func clear_move_target() -> void:
	move_target = Vector2.INF

## Consome (e zera) o flag de "o jogador mexeu no WASD" — usado pelo Main p/ cancelar a perseguição.
func take_manual_cancel() -> bool:
	var v := _manual_cancel
	_manual_cancel = false
	return v

## O jogador está dirigindo o movimento AGORA (WASD pressionado ou esquiva em curso)? Leitura pura,
## NÃO consome o flag (≠ take_manual_cancel). Usado pelo AutoPlay (A1) p/ ceder o controle na hora —
## o piloto automático não deve disputar posição enquanto a presença manual está ativa.
func is_manual_moving() -> bool:
	if locked:
		return false
	return _dodge_t > 0.0 or _read_move_dir() != Vector2.ZERO

## i-frames ativos? O Main checa isto no ÚNICO ponto de dano (_on_enemy_attack) p/ ANULAR o golpe (melee/projétil/
## spell — todos passam por lá). DODGE off → _iframe_t nunca sobe → sempre false → comportamento legado.
func is_invulnerable() -> bool:
	return _iframe_t > 0.0

## Elegível p/ esquivar? (não-locked, fora de dash, fora de cooldown). Off → nunca.
func can_dodge() -> bool:
	return DODGE_ENABLED and not locked and _dodge_t <= 0.0 and _dodge_cd <= 0.0

## Inicia a esquiva se elegível. Direção = WASD atual; se parado, usa o facing. Retorna se DISPAROU.
## Público p/ ser testável headless (o _process chama no edge da tecla dedicada).
func try_dodge() -> bool:
	if not can_dodge():
		return false
	var dir := _read_move_dir()
	if dir == Vector2.ZERO:
		dir = facing
	_dodge_dir = dir.normalized()
	facing = _dodge_dir
	_dodge_t = DODGE_TIME
	_iframe_t = DODGE_IFRAMES
	_dodge_cd = DODGE_COOLDOWN
	move_target = Vector2.INF      # cancela auto-walk
	_manual_cancel = true          # o Main solta a perseguição
	_begin_iframe_visual()
	if _anim != null:
		_anim.play_walk(_dodge_dir)
	return true

func _read_move_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		d.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		d.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		d.y += 1.0
	return d

## tint azulado translúcido durante os i-frames = leitura clara de "estou intangível" (legibilidade).
func _begin_iframe_visual() -> void:
	if _sprite != null:
		_sprite.modulate = Color(0.62, 0.86, 1.0, 0.6)
		_iframe_vis = true

func _end_iframe_visual() -> void:
	if _iframe_vis and _sprite != null:
		_sprite.modulate = Color(1, 1, 1, 1)
	_iframe_vis = false

## movimento por eixo (desliza nas paredes): testa o PÉ contra blockers + limites. Reusado pelo dash e pelo andar.
func _move_with_collision(delta: float) -> void:
	if _vel == Vector2.ZERO:
		return
	var feet := Vector2(0, FEET_Y)
	var nx := clampf(position.x + _vel.x * delta, _bounds_min.x, _bounds_max.x)
	if not _blocked(Vector2(nx, position.y) + feet):
		position.x = nx
	var ny := clampf(position.y + _vel.y * delta, _bounds_min.y, _bounds_max.y)
	if not _blocked(Vector2(position.x, ny) + feet):
		position.y = ny

func _ready() -> void:
	for c in get_children():
		if c is Sprite2D:
			_sprite = c
			break
	_anim = ActorAnimator.new()
	add_child(_anim)
	_anim.setup(_sprite, "hero/errante", 3.0, true)   # arte lateral encara a esquerda
	set_weapon_visual(GameState.current_weapon_type())   # aplica o visual do arquétipo já no spawn

func set_bounds(mn: Vector2, mx: Vector2) -> void:
	_bounds_min = mn
	_bounds_max = mx

func set_blockers(rects: Array) -> void:
	_blockers = rects

func _blocked(p: Vector2) -> bool:
	for r in _blockers:
		if r.has_point(p):
			return true
	return false

func _process(delta: float) -> void:
	# ESQUIVA: recargas/i-frames correm sempre (o tint volta ao normal quando a janela fecha).
	if _dodge_cd > 0.0:
		_dodge_cd -= delta
	if _iframe_t > 0.0:
		_iframe_t -= delta
		if _iframe_t <= 0.0:
			_end_iframe_visual()
	if locked:
		_vel = Vector2.ZERO
		_dodge_t = 0.0   # cancela um dash em curso se algo travou o herói (fala/loja)
		if _anim != null:
			_anim.play_idle()
		return
	# ESQUIVA: dispara no EDGE da tecla dedicada (uma esquiva por toque, não segurar).
	var dodge_now := DODGE_ENABLED and Input.is_key_pressed(DODGE_KEY)
	if dodge_now and not _dodge_was_pressed:
		try_dodge()
	_dodge_was_pressed = dodge_now
	# Durante o dash: movimento COMPROMETIDO na direção escolhida (ignora steering normal). Desliza nas paredes.
	if _dodge_t > 0.0:
		_dodge_t -= delta
		_vel = _dodge_dir * DODGE_SPEED
		_move_with_collision(delta)
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		dir.y += 1.0
	# WASD assume o controle e cancela o auto-walk; senão, caminha até o alvo clicado (se houver).
	if dir != Vector2.ZERO:
		move_target = Vector2.INF
		_manual_cancel = true
	elif move_target != Vector2.INF:
		var to: Vector2 = move_target - position
		if to.length() > move_stop:
			dir = to
		else:
			move_target = Vector2.INF   # chegou ao alcance
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		facing = dir
		_vel = _vel.move_toward(dir * speed, accel * delta)
		if _anim != null:
			_anim.play_walk(dir)
	else:
		_vel = _vel.move_toward(Vector2.ZERO, friction * delta)
		if _anim != null:
			_anim.play_idle()
	_move_with_collision(delta)

## estilo de ataque procedural por arma (GODOT-PLAYER-ARCHETYPE-ATTACK-ANIM-1)
const ATTACK_STYLES := {"sword": "swing", "spear": "thrust", "bow": "shot", "staff": "cast"}

## chamado pelo Main quando o Errante desfere um golpe ([J]); `dir` aponta p/ o alvo. O GESTO varia
## conforme a arma equipada (corte/estocada/tiro/conjurar); desarmado cai no lunge curto ("melee").
func attack(dir: Vector2 = Vector2.ZERO) -> void:
	if dir.length() > 0.01:
		facing = dir.normalized()
	if _anim != null:
		_anim.play_attack(dir, ATTACK_STYLES.get(GameState.current_weapon_type(), "melee"))

## Direção encarada (normalizada); usada p/ mirar disparos quando não há alvo travado.
func get_facing() -> Vector2:
	return facing

## Troca o visual do Errante conforme a arma equipada (sword/bow/staff/spear) — chamado no spawn e a
## cada mudança de estado. Asset do arquétipo ausente ou arma desconhecida/nenhuma → Errante padrão.
func set_weapon_visual(weapon_kind: String) -> void:
	if _anim == null:
		return
	var key: String = ARCHETYPE_VISUALS.get(weapon_kind, DEFAULT_VISUAL)
	# Errante: arte lateral encara a ESQUERDA; arquétipos (row2=right) encaram a DIREITA.
	var faces_left := (key == DEFAULT_VISUAL)
	if not _anim.set_actor_key(key, faces_left, true):
		_anim.set_actor_key(DEFAULT_VISUAL, true, true)   # strip do arquétipo faltando → cai no Errante
	# ★ Identidade para o REGISTRO de animação real (Parte 1). O arquétipo vem do SLOT da arma, nunca
	# de nome textual — e é reavaliado a cada troca, que é exatamente quando o corpo pode mudar.
	# ⛔ Só liga o registro; se a classe não estiver marcada PRONTA, tudo segue procedural.
	_anim.combat_kind = "player"
	_anim.combat_id = GameState.current_combat_archetype().to_upper()

## ★★★ FIELD FIX 05/09/2026 (A7/F4) — LEITURA DO ATAQUE DO ERRANTE.
## O field reportou "Errante estático dando dano": o PvE não tinha COMO encenar o golpe, porque
## `_anim` é privado e não havia método público de ataque (só `hit_recoil` p/ dano recebido).
## Isto expõe o que o `ActorAnimator` já sabe fazer (lunge direcional procedural).
## ⛔ NÃO é arte nova nem fake shake/zoom: é o state transition real que já existia.
## Frames de ataque de verdade seguem como PLAYER_ATTACK_ANIMATION_ASSET_REQUIRED (Codex).
## ★ ATUALIZADO (REAL COMBAT ANIMATION PREP V1): tenta o CORPO REAL primeiro; sem arte pronta, cai
## no lunge procedural que já existia. `heavy` escolhe ATTACK_HEAVY — o dano NÃO muda por isso, é só
## qual strip encena (o autoritativo continua sendo o evento de combate).
func play_attack(aim: Vector2 = Vector2.ZERO, heavy := false) -> void:
	if _anim == null:
		return
	# ⛔ PARTE 14 — o PESADO só encena se o gameplay tiver um evento autoritativo de golpe pesado.
	# Hoje não tem. Tocar a strip HEAVY seria inventar gameplay para exibir arte; a arte fica
	# REGISTRADA e o golpe pesado desenha com a strip básica até existir o evento de verdade.
	var usar_pesado := heavy and CombatAnimationRegistry.policy_flag("player_heavy_real_animation_enabled")
	if _anim.play_real_transient("ATTACK_HEAVY" if usar_pesado else "ATTACK_BASIC", aim):
		return
	_anim.play_attack(aim, "melee")

## flinch ao tomar dano (flash + recoil) — mantém o nome usado pelo Main
func hit_recoil(_from_pos: Vector2) -> void:
	if _anim == null:
		return
	if _anim.play_real_transient("HIT"):
		return
	_anim.play_hit()

## Quadro de contato sugerido do golpe corrente (Parte 6) — **só para alinhar VFX**. -1 = sem sugestão.
## ⛔ Ninguém lê isto para decidir dano: o dano já aconteceu quando o evento chegou.
func attack_contact_frame(heavy := false) -> int:
	if _anim == null:
		return -1
	return _anim.combat_contact_frame("ATTACK_HEAVY" if heavy else "ATTACK_BASIC")

## true se o Errante tem corpo real para esta ação agora (usado pelo self-test e pelo relatório).
func has_real_combat_body(action := "ATTACK_BASIC") -> bool:
	return _anim != null and _anim.has_real_combat(action)

## estado visual de "abatido" (não some; o [R] recupera)
func set_downed(downed: bool) -> void:
	if _anim == null:
		return
	if downed:
		# ⛔ PARTE 15 — MORTE REAL DO JOGADOR DESLIGADA POR POLÍTICA, não por falta de arte.
		# "Abatido" é estado RECUPERÁVEL ([R] levanta); uma strip que emite `death_finished` mexeria
		# no ciclo de vida do jogador. A trava é DADO (`policy.player_death_real_animation_enabled`),
		# então ligar exige decisão explícita — não acontece por acidente quando o Codex aprovar a arte.
		if CombatAnimationRegistry.policy_flag("player_death_real_animation_enabled"):
			if _anim.play_real_transient("DEATH"):
				return
		_anim.play_downed()
	else:
		_anim.reset()
