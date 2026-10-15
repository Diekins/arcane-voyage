class_name ActorAnimator extends Node
## ActorAnimator — camada de ANIMAÇÃO top-down reutilizável (GODOT-ANIMATION-PIPELINE-1;
## spritesheets reais plugados em GODOT-MOB-SPRITES-PLUG-1).
##
## Controla ESTADO (idle/walk/attack/hit/death) + DIREÇÃO (down/up/side + flip) de um nó visual.
## Se existir uma SPRITESHEET em `res://assets/actors/<actor_key>.png` (strip de quadros 64×64),
## monta um AnimatedSprite2D real (anim "move" em loop) e o usa como visual; os ESTADOS
## transitórios (attack=lunge, hit=flash+recoil, death=fade+sink) continuam sendo procedurais
## POR CIMA do sprite animado. SEM sheet, usa fallback 100% procedural (bob/respiração).

enum State { IDLE, WALK, ATTACK, HIT, DEATH }
enum Dir { DOWN, UP, SIDE }

signal death_finished

const FALLBACK_FRAME := 64   # quadros das strips são quadrados (altura = lado)

var actor_key: String = ""
var bob_amplitude: float = 3.0
# orientação do asset lateral (GODOT-4DIR-ACTOR-DIRECTION-FIX-1): `side_faces_left` = a arte lateral
# já encara a ESQUERDA (Errante/lobos), senão encara a direita (Aldric). `can_flip` = false p/ atores
# frontais/simétricos (Golem/Morcego) que NÃO devem espelhar (evita "virar p/ o lado oposto").
var side_faces_left := false
var can_flip := true
# pula a strip de COSTAS (<key>_up.png) — usado p/ NPCs da vila cujo sheet de costas tem a cabeça
# achatada/cortada na arte (GODOT-WORLD-LIFE-AMBIENT-1 fix): ao olhar p/ cima, cai na vista de FRENTE.
var skip_back := false
# omnidirectional (GODOT-FIX-GOLEM-4DIR-ONLY-1): ator SEM arte de lado/costas que NÃO deve nem FINGIR
# direção (sem lean/scale/flip). Fica estável de frente até existir um sheet 4-dir real
# (`<key>_side.png`/`<key>_up.png`) — quando esse chegar, o ActorAnimator passa a virar de verdade.
var omnidirectional := false

var state: int = State.IDLE
var dir: int = Dir.DOWN
var facing_left := false
# Mobs/bosses NÃO devem dar as costas (GODOT-GROVE-MOB-FACING-FIX-1): ao mirar p/ cima usam o PERFIL
# lateral em vez de `move_up` — leem como "encarando você". O Errante (controlável) mantém 4-dir.
var suppress_back := false

var _visual: Node2D               # nó animado (AnimatedSprite2D real OU o shape/sprite placeholder)
var _sprite_for_flip: Node        # nó com flip_h (Sprite2D/AnimatedSprite2D); senão null
var _anim: AnimatedSprite2D       # presente quando há spritesheet real
var _placeholder: Node2D          # visual de fallback (escondido quando há sheet)
var _base_scale := Vector2.ONE
var _base_pos := Vector2.ZERO
var _aim := Vector2.DOWN
var _bob_t := 0.0
var _busy_t := 0.0
var _dead := false

func setup(visual: Node2D, key: String = "", bob_amp: float = 3.0, p_side_faces_left: bool = false, p_can_flip: bool = true, p_skip_back: bool = false) -> void:
	_placeholder = visual
	actor_key = key
	bob_amplitude = bob_amp
	side_faces_left = p_side_faces_left
	can_flip = p_can_flip
	skip_back = p_skip_back
	var sheet := _build_spritesheet(key)
	if sheet != null:
		_anim = sheet
		visual.get_parent().add_child(_anim)
		visual.visible = false              # esconde o placeholder; usa a sheet real
		_visual = _anim
		_sprite_for_flip = _anim
		_anim.play("move")
		print("[ActorAnimator] spritesheet real plugada: %s (%d frames)" % [key, _anim.sprite_frames.get_frame_count("move")])
	else:
		_visual = visual
		if visual is Sprite2D:
			_sprite_for_flip = visual
	if _visual != null:
		_base_scale = _visual.scale
		_base_pos = _visual.position

## Monta um AnimatedSprite2D: anim "move" da strip `<key>.png` (+ "talk" de `<key>_talk.png` se
## existir, p/ NPCs). null se não houver a strip principal.
func _build_spritesheet(key: String) -> AnimatedSprite2D:
	if key == "":
		return null
	var path := "res://assets/actors/%s.png" % key
	if not ResourceLoader.exists(path):
		return null
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	if not _add_strip(frames, "move", path, 8.0):
		return null
	var talk_path := "res://assets/actors/%s_talk.png" % key
	if ResourceLoader.exists(talk_path):
		_add_strip(frames, "talk", talk_path, 6.0)
	# direções extras (futuro): <key>_up.png / <key>_side.png → anims "move_up"/"move_side".
	var dirs := ["side"] if skip_back else ["up", "side"]   # skip_back: sem costas (cabeça cortada nos NPCs)
	for d in dirs:
		var dp := "res://assets/actors/%s_%s.png" % [key, d]
		if ResourceLoader.exists(dp):
			_add_strip(frames, "move_" + d, dp, 8.0)
	var asp := AnimatedSprite2D.new()
	asp.sprite_frames = frames
	asp.animation = "move"
	# ergue o sprite proporcional ao tamanho do quadro (pés na sombra) — 64px≈-10, bosses maiores ↑
	var fh := 64
	if frames.get_frame_count("move") > 0:
		var ft := frames.get_frame_texture("move", 0)
		if ft != null:
			fh = ft.get_height()
	asp.position = Vector2(0, -fh * 0.16)
	return asp

## Fatia uma strip 64×64 (lado=altura) em N quadros e adiciona como animação `name`.
func _add_strip(frames: SpriteFrames, name: String, path: String, speed: float) -> bool:
	var tex := load(path) as Texture2D
	if tex == null:
		return false
	var fh := tex.get_height()
	var fw := fh
	var cols := int(tex.get_width() / fw)
	if cols < 1:
		return false
	frames.add_animation(name)
	frames.set_animation_loop(name, true)
	frames.set_animation_speed(name, speed)
	for i in range(cols):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		frames.add_frame(name, at)
	return true

func has_spritesheet() -> bool:
	return _anim != null

## Troca o spritesheet em RUNTIME (GODOT-PLAYER-ARCHETYPE-SPRITES-1) — usado pelo player ao mudar de
## arma. Reconstrói o AnimatedSprite a partir do novo `key`, preservando direção/estado. Retorna
## false e NÃO altera nada se o asset não existir (fallback seguro = mantém o visual atual).
func set_actor_key(key: String, p_side_faces_left: bool = false, p_can_flip: bool = true) -> bool:
	if key == actor_key:
		return true
	var sheet := _build_spritesheet(key)
	if sheet == null:
		return false   # sem <key>.png → mantém o sprite atual (não quebra)
	var old := _anim
	actor_key = key
	# orientação do novo asset (Errante encara a esquerda; arquétipos têm row2=right → encaram a direita)
	side_faces_left = p_side_faces_left
	can_flip = p_can_flip
	_anim = sheet
	_placeholder.get_parent().add_child(_anim)
	_placeholder.visible = false
	_visual = _anim
	_sprite_for_flip = _anim
	_base_scale = _visual.scale
	_base_pos = _visual.position
	_dead = false
	if old != null and is_instance_valid(old):
		old.queue_free()
	# reaplica a pose corrente p/ a troca de arma não "resetar" direção/movimento
	if state == State.WALK:
		play_walk(_aim)
	else:
		set_direction(_aim)
		play_idle()
	print("[ActorAnimator] visual trocado em runtime: %s (%d frames)" % [key, _anim.sprite_frames.get_frame_count("move")])
	return true

## --- API ---

func set_direction(v: Vector2) -> void:
	if v.length() < 0.01:
		return
	_aim = v.normalized()
	if absf(v.x) >= absf(v.y):
		dir = Dir.SIDE
	elif v.y < 0.0:
		dir = Dir.SIDE if suppress_back else Dir.UP   # mobs nunca dão as costas → perfil
	else:
		dir = Dir.DOWN
	if not can_flip or _sprite_for_flip == null:
		return
	if _has_directional():
		# ator com strips REAIS (Errante): espelha só no perfil; frente/costas têm sprite próprio → não espelha.
		if dir == Dir.SIDE:
			facing_left = v.x < 0.0
			_sprite_for_flip.flip_h = (facing_left != side_faces_left)
		else:
			_sprite_for_flip.flip_h = false
	else:
		# ator SÓ-LATERAL (mobs/bosses): NÃO há arte de frente/costas, então SEMPRE encara o lado
		# horizontal do alvo — mesmo perseguindo/atacando p/ cima/baixo (evita ficar "de costas").
		# Quando o alvo está ~na vertical (v.x≈0), mantém o último lado (não há resposta melhor).
		if absf(v.x) > 0.001:
			facing_left = v.x < 0.0
			_sprite_for_flip.flip_h = (facing_left != side_faces_left)

## true quando há strips direcionais reais plugadas (move_up/move_side) — então usamos sprites de
## verdade e DESLIGAMOS o fallback de lean/scale do _apply_walk_pose.
func _has_directional() -> bool:
	return _anim != null and _anim.sprite_frames != null and (_anim.sprite_frames.has_animation("move_up") or _anim.sprite_frames.has_animation("move_side"))

## Escolhe a anim conforme a direção atual: move_up / move_side (se existirem) senão "move".
func _anim_for_dir() -> String:
	if _anim == null or _anim.sprite_frames == null:
		return "move"
	if dir == Dir.UP and _anim.sprite_frames.has_animation("move_up"):
		return "move_up"
	if dir == Dir.SIDE and _anim.sprite_frames.has_animation("move_side"):
		return "move_side"
	return "move"

func play_idle() -> void:
	if _dead:
		return
	# 🔴🔴 O TRANSITÓRIO REAL É DONO DO SPRITE ATÉ ACABAR.
	# `play_idle`/`play_walk` são chamados A CADA FRAME pelo jogo. Sem esta guarda eles trocavam
	# `_anim.animation` no meio do gesto ⇒ `animation_finished` NUNCA disparava para a anim do
	# transitório ⇒ `_transient_anim` ficava setado para sempre e o ator TRAVAVA no primeiro golpe.
	# ⚠️ O teste isolado não pegava isso: lá ninguém dirige o animator por frame. Quem pegou foi a
	# cena real. Guardar só `_busy_t` no _apply_walk_pose não bastava — o `_anim.play()` é aqui.
	if _transient_anim != "":
		_transient_restore = State.IDLE   # a intenção mais recente vira o destino da volta
		return
	state = State.IDLE
	_clear_walk_pose()
	if _anim != null:
		# PARADO de verdade (GODOT-IDLE-MOTION-FIX): pose de descanso = 1º quadro da direção,
		# PAUSADO — antes tocava o ciclo de "move" a 0.45x, o que parecia "andar parado".
		var a := _anim_for_dir()
		if _anim.animation != a:
			_anim.animation = a
		_anim.frame = 0
		_anim.pause()

func play_walk(v: Vector2) -> void:
	if _dead:
		return
	set_direction(v)          # a direção PODE mudar durante o gesto (o alvo se move) — isso é ok
	# 🔴🔴 mesma guarda do play_idle: o corpo real manda até terminar. Ver comentário lá.
	if _transient_anim != "":
		_transient_restore = State.WALK
		return
	state = State.WALK
	_apply_walk_pose()
	if _anim != null:
		_anim.speed_scale = 1.15
		var a := _anim_for_dir()
		if _anim.animation != a or not _anim.is_playing():
			_anim.play(a)

## Orientação ao ANDAR (GODOT-STARTER-MAPS-POLISH-1): mesmo com sheet front-facing (down) + flip
## lateral, dá leitura de direção — inclina o corpo ao ir p/ os lados e encolhe um tico ao "subir"
## (pista de costas/afastamento). Down = neutro. Não cria sprites 4-dir; complementa o flip existente.
func _apply_walk_pose() -> void:
	if _visual == null:
		return
	if _busy_t > 0.0:
		return   # um gesto transitório (ataque/hit) está no controle do visual — não pisar por cima
	if omnidirectional:
		# honesto: sem arte direcional → NÃO finge (sem lean/scale). Fica estável de frente.
		_visual.rotation = 0.0
		_visual.scale = _base_scale
		return
	if _has_directional():
		# sprites direcionais reais → orientação de verdade (anim por dir + flip lateral); sem hacks.
		_visual.rotation = 0.0
		_visual.scale = _base_scale
		return
	# FALLBACK (sem strips direcionais): inclina ao ir p/ os lados + encolhe um tico ao "subir".
	var lean := 0.0
	if dir == Dir.SIDE:
		lean = -0.10 if facing_left else 0.10
	_visual.rotation = lean
	if _anim != null:
		var k := 0.93 if dir == Dir.UP else 1.0
		_visual.scale = Vector2(_base_scale.x * k, _base_scale.y * k)

## Volta à postura neutra no idle (corpo ereto; escala base com sheet).
func _clear_walk_pose() -> void:
	if _visual == null:
		return
	if _busy_t > 0.0:
		return   # idem: durante ataque/hit o gesto procedural manda no rotation/scale
	_visual.rotation = 0.0
	if _anim != null:
		_visual.scale = _base_scale

## Gesto de fala (NPC). Toca a anim "talk" da sheet se existir; senão um pulso procedural leve.
func play_talk() -> void:
	if _dead:
		return
	state = State.IDLE
	if _anim != null and _anim.sprite_frames != null and _anim.sprite_frames.has_animation("talk"):
		_anim.speed_scale = 1.0
		_anim.play("talk")
	elif _visual != null:
		_visual.scale = _base_scale * Vector2(1.06, 1.06)
		var tw := create_tween()
		tw.tween_property(_visual, "scale", _base_scale, 0.3)

## Gesto de ataque PROCEDURAL por estilo de arma (GODOT-PLAYER-ARCHETYPE-ATTACK-ANIM-1) — feito SÓ
## com posição/rotação/escala sobre o sprite atual (sem frames de ataque novos). `style`:
##   "swing" (espada: lunge + giro de corte) · "thrust" (lança: estocada longa e seca) ·
##   "shot" (arco: recuo de puxar a corda) · "cast" (cajado: erguer + pulso de escala) ·
##   "melee" (padrão/desarmado e inimigos: lunge curto — comportamento original).
## Os guards em _apply_/_clear_walk_pose seguram o pose de andar/parar durante o _busy_t (não pisa).
func play_attack(v: Vector2 = Vector2.ZERO, style: String = "melee") -> void:
	if _dead:
		return
	if v.length() > 0.01:
		set_direction(v)
	state = State.ATTACK
	if _visual == null:
		_busy_t = 0.22
		return
	var tw := create_tween()
	match style:
		"thrust":   # lança: avança fundo na direção e volta seco
			_busy_t = 0.28
			_visual.position = _base_pos + _aim * 22.0
			tw.tween_property(_visual, "position", _base_pos, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"shot":     # arco: recua um tico (puxar a corda) e reassenta
			_busy_t = 0.24
			_visual.position = _base_pos - _aim * 8.0
			tw.tween_property(_visual, "position", _base_pos, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		"cast":     # cajado: ergue + pulso de escala (conjurar)
			_busy_t = 0.32
			_visual.scale = _base_scale * 1.16
			_visual.position = _base_pos + Vector2(0, -7)
			tw.set_parallel(true)
			tw.tween_property(_visual, "scale", _base_scale, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(_visual, "position", _base_pos, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		"swing":    # espada: lunge curto + giro rápido de corte (lado conforme a mira)
			_busy_t = 0.26
			var s := -1.0 if _aim.x < -0.05 else 1.0
			_visual.position = _base_pos + _aim * 11.0
			_visual.rotation = 0.26 * s
			tw.set_parallel(true)
			tw.tween_property(_visual, "position", _base_pos, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(_visual, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_:          # melee padrão (desarmado + inimigos): lunge curto original
			_busy_t = 0.22
			_visual.position = _base_pos + _aim * 11.0
			tw.tween_property(_visual, "position", _base_pos, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ─────────────── ANIMAÇÃO REAL DE COMBATE (REAL COMBAT ANIMATION PREP V1) ───────────────
## Corpo REAL por cima do mesmo AnimatedSprite2D: toca a strip uma vez e DEVOLVE a locomoção.
## ★★★ Preserva facing/HFLIP/estado/alvo por CONSTRUÇÃO: o transitório roda no MESMO nó, então
## `flip_h`, posição e `_aim` não são tocados. O que se guarda é só o ESTADO lógico para restaurar.
## ⛔ Se a strip real não estiver PRONTA, este caminho não roda e o chamador usa o gesto procedural
## que já existia — combate nunca falha por falta de arte (Parte 3/14).

## Identidade para o registro. Vazias = ator sem animação real (todo mundo, até ser marcado pronto).
var combat_kind := ""     # "player" | "mobs"
var combat_id := ""

var _transient_anim := ""       # anim em curso; "" = nenhum
var _transient_restore := -1    # State a restaurar quando acabar
var _transient_is_death := false
var _transient_priority := 0    # prioridade do gesto em curso (ver policy.transient_priority)

## Direção corrente traduzida para o vocabulário do registro (BASE/SIDE/UP).
func combat_direction() -> String:
	if dir == Dir.SIDE:
		return "SIDE"
	if dir == Dir.UP:
		return "UP"
	return "BASE"

## Existe strip real PRONTA para esta ação, nesta direção (com queda para BASE)?
func has_real_combat(action: String) -> bool:
	if combat_kind == "" or combat_id == "" or _anim == null:
		return false
	return CombatAnimationRegistry.resolve_direction(combat_kind, combat_id, action, combat_direction()) != ""

## Quadro de contato sugerido (só apresentação; NUNCA move o dano). -1 = sem sugestão.
func combat_contact_frame(action: String) -> int:
	if combat_kind == "" or combat_id == "":
		return -1
	return CombatAnimationRegistry.contact_frame(combat_kind, combat_id, action)

## Toca a strip REAL de `action` uma vez. Retorna false quando não há arte pronta — e aí o chamador
## faz o gesto procedural. `true` significa "o corpo real assumiu"; a locomoção volta sozinha.
func play_real_transient(action: String, v: Vector2 = Vector2.ZERO, fps := 12.0) -> bool:
	if _dead or _anim == null or combat_kind == "" or combat_id == "":
		return false
	if v.length() > 0.01:
		set_direction(v)
	var d := CombatAnimationRegistry.resolve_direction(combat_kind, combat_id, action, combat_direction())
	if d == "":
		return false
	# ★★★ PRIORIDADE DETERMINÍSTICA (Onda 2, Partes 16/17): downed/morte > HIT > ATTACK > locomoção.
	# Maior vence; IGUAL substitui (dois golpes seguidos reiniciam o gesto, que é o esperado).
	# ⇒ tomar dano INTERROMPE o golpe; o golpe NÃO cancela o flinch — esconder o dano do jogador seria
	# pior que perder o fim de uma animação de ataque. ⛔ Sem fila: fila deixa ator parado esperando vez.
	if _transient_anim != "" and CombatAnimationRegistry.priority_of(action) < _transient_priority:
		return true                       # já há gesto MAIS importante em cena — e ele encena por nós
	var sf := CombatAnimationRegistry.frames(combat_kind, combat_id, action, d, fps)
	if sf == null:
		return false                      # aviso já saiu (uma vez) no registro
	var key := CombatAnimationRegistry.anim_name(combat_kind, combat_id, action, d)
	if not _anim.sprite_frames.has_animation(key):
		# ★ copia os quadros UMA vez por ator (o SpriteFrames do registro é compartilhado e não
		# pode ser mutado; os AtlasTexture sim são reaproveitados — não há recorte novo por golpe).
		_anim.sprite_frames.add_animation(key)
		_anim.sprite_frames.set_animation_loop(key, false)
		_anim.sprite_frames.set_animation_speed(key, fps)
		for i in range(sf.get_frame_count("p")):
			_anim.sprite_frames.add_frame(key, sf.get_frame_texture("p", i))
	# guarda o estado LÓGICO (o visual não precisa ser guardado: é o mesmo nó)
	if _transient_anim == "":
		_transient_restore = state
	_transient_anim = key
	_transient_priority = CombatAnimationRegistry.priority_of(action)
	_transient_is_death = (action == "DEATH")
	state = State.DEATH if _transient_is_death else (State.HIT if action == "HIT" else State.ATTACK)
	# segura os poses procedurais de andar/parar enquanto o corpo real manda
	_busy_t = float(_anim.sprite_frames.get_frame_count(key)) / maxf(1.0, fps) + 0.02
	if _anim.animation_finished.is_connected(_on_transient_finished):
		_anim.animation_finished.disconnect(_on_transient_finished)
	_anim.animation_finished.connect(_on_transient_finished, CONNECT_ONE_SHOT)
	_anim.speed_scale = 1.0
	_anim.play(key)
	return true

## Fim do transitório real: devolve a locomoção exatamente como estava (Parte 5).
func _on_transient_finished() -> void:
	if _transient_anim == "":
		return
	_transient_anim = ""
	_transient_priority = 0
	_busy_t = 0.0
	if _transient_is_death:
		_transient_is_death = false
		_dead = true
		state = State.DEATH
		_busy_t = 1000.0
		if _anim != null:
			_anim.pause()
		death_finished.emit()
		return
	var restore := _transient_restore
	_transient_restore = -1
	if _dead:
		return
	if restore == State.WALK:
		play_walk(_aim)      # preserva alvo/direção: _aim não foi tocado
	else:
		play_idle()

## true enquanto um corpo real está no controle (usado pelo self-test e por guardas de estado).
func real_transient_active() -> bool:
	return _transient_anim != ""

## 🔴🔴 CANCELA um gesto real em voo. A MORTE é autoritária sobre qualquer gesto.
## Sem isto: morrer no meio de um golpe chamava `_anim.pause()`, `animation_finished` NUNCA disparava,
## `_transient_anim` ficava setado para sempre — e como `play_idle`/`play_walk` agora respeitam o
## transitório, o ator NUNCA MAIS animava, nem depois de reviver. Ator preso permanente.
## ⚠️ Pego na cena real (o Errante morreu no meio da fatia); no teste isolado ninguém morre.
func _cancel_real_transient() -> void:
	if _transient_anim == "":
		return
	if _anim != null and _anim.animation_finished.is_connected(_on_transient_finished):
		_anim.animation_finished.disconnect(_on_transient_finished)
	_transient_anim = ""
	_transient_restore = -1
	_transient_is_death = false
	_transient_priority = 0

func play_hit() -> void:
	if _dead:
		return
	state = State.HIT
	_busy_t = 0.24
	if _visual == null:
		return
	_visual.modulate = Color(2.1, 1.5, 1.5)
	var tw := create_tween()
	tw.tween_property(_visual, "modulate", Color(1, 1, 1, 1), 0.2)
	_visual.position = _base_pos - _aim * 9.0    # recoil oposto à mira
	var tw2 := create_tween()
	tw2.tween_property(_visual, "position", _base_pos, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func play_death() -> void:
	if _dead:
		return
	_cancel_real_transient()   # a morte vence o gesto em voo (ver _cancel_real_transient)
	_dead = true
	state = State.DEATH
	_busy_t = 1000.0
	if _anim != null:
		_anim.pause()
	if _visual == null:
		death_finished.emit()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "modulate:a", 0.22, 0.5)
	tw.tween_property(_visual, "position:y", _base_pos.y + 13.0, 0.5)
	tw.tween_property(_visual, "scale", Vector2(_base_scale.x * 1.12, _base_scale.y * 0.5), 0.5)
	tw.chain().tween_callback(func(): death_finished.emit())

func play_downed() -> void:
	if _dead:
		return
	_cancel_real_transient()   # idem: abatido também congela o sprite e mataria o `animation_finished`
	_dead = true
	state = State.DEATH
	_busy_t = 1000.0
	if _anim != null:
		_anim.pause()
	if _visual == null:
		return
	var tw := create_tween()
	tw.tween_property(_visual, "modulate", Color(0.6, 0.6, 0.72, 0.6), 0.2)
	tw.parallel().tween_property(_visual, "rotation", 1.1, 0.2)

func snap_dead() -> void:
	_cancel_real_transient()   # idem
	_dead = true
	state = State.DEATH
	_busy_t = 1000.0
	if _anim != null:
		_anim.pause()
	if _visual != null:
		_visual.modulate = Color(1, 1, 1, 0.3)
		_visual.scale = Vector2(_base_scale.x * 1.1, _base_scale.y * 0.55)

func reset() -> void:
	_dead = false
	state = State.IDLE
	_busy_t = 0.0
	_bob_t = 0.0
	# o transitório real não sobrevive a um reset (ator reciclado do pool volta limpo)
	_transient_anim = ""
	_transient_restore = -1
	_transient_is_death = false
	_transient_priority = 0
	if _visual != null:
		_visual.visible = true
		_visual.position = _base_pos
		_visual.scale = _base_scale
		_visual.rotation = 0.0
		_visual.modulate = Color(1, 1, 1, 1)
	if _anim != null:
		_anim.play("move")

func _process(delta: float) -> void:
	if _visual == null or _dead:
		return
	if _busy_t > 0.0:
		_busy_t = maxf(0.0, _busy_t - delta)
		return
	if _anim != null:
		return   # a spritesheet real já dá o movimento visual (sem bob procedural)
	if state == State.WALK:
		_bob_t += delta * 13.0
		_visual.position.y = _base_pos.y - absf(sin(_bob_t)) * bob_amplitude
		_visual.scale = _base_scale
	else:
		_bob_t += delta * 3.0
		_visual.position.y = lerpf(_visual.position.y, _base_pos.y, clampf(delta * 10.0, 0.0, 1.0))
		var s := 1.0 + sin(_bob_t) * 0.015
		_visual.scale = Vector2(_base_scale.x, _base_scale.y * s)
