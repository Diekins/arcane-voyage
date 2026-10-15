class_name PveMobActor extends Node2D
## FATIA A20 — ATOR VISÍVEL COMPARTILHADO de PvE (Mission / Hunt / Boss-add / Dungeon futuro). Liga o mob LÓGICO
## (HuntMob, extends Node, sem visual) a um Node2D de apresentação. Reusa ActorAnimator + spritesheet real (ex.:
## "mobs/young_wolf"). Fallback VISÍVEL se o sprite faltar (nunca mob invisível). Nasce num SPAWN POCKET (direção
## variada §A20.10) e APROXIMA o player. NÃO concede recompensa (autoridade = runtime lógico).
## A33 — legibilidade de field: spawn PRÓXIMO (dentro do viewport, não a 300px), + NAMEPLATE e BARRA DE HP no ator
## (antes o HP/nome só existiam no HUD, com o sprite longe/invisível). `combat_visible_ok()` = coerência p/ anti-ghost-farm.

var _anim: ActorAnimator = null
var _fallback: Polygon2D = null
var _nameplate: Label = null
var _hp_bg: ColorRect = null
var _hp_fill: ColorRect = null
var visual_key := ""
var mob_id := ""
var display_name := ""
var used_fallback := false
var is_elite := false

# A33 — SPAWN POCKETS PRÓXIMOS (§23/§24): o mob chega de direções variadas, mas DENTRO do viewport, perto do spot
# do player — para o jogador VER a criatura chegar e morrer (antes eram 300–360px, fora da tela na maioria das res).
const POCKETS := [Vector2(150, -10), Vector2(-150, -10), Vector2(130, -90), Vector2(-130, -90), Vector2(0, -150), Vector2(160, 70)]
static func pocket_for(index: int) -> Vector2:
	return POCKETS[abs(index) % POCKETS.size()]

func setup(p_visual_key: String, p_mob_id: String, p_is_elite := false, p_name := "") -> void:
	visual_key = p_visual_key; mob_id = p_mob_id; is_elite = p_is_elite
	display_name = p_name if p_name != "" else _derive_name(p_mob_id)
	var body := Node2D.new(); body.name = "Body"; add_child(body)
	_anim = ActorAnimator.new(); add_child(_anim)
	_anim.setup(body, visual_key)
	if not _anim.has_spritesheet():
		used_fallback = true
		_fallback = Polygon2D.new()
		_fallback.polygon = PackedVector2Array([Vector2(-16, 0), Vector2(0, -20), Vector2(16, 0), Vector2(0, 20)])
		_fallback.color = Color(0.55, 0.55, 0.62) if not is_elite else Color(0.85, 0.5, 0.35)
		body.add_child(_fallback)
		if OS.is_debug_build(): print("[PveMobActor] PVE_VISUAL_FALLBACK: %s (sem spritesheet '%s')" % [mob_id, visual_key])
	else:
		# ★★★ FIELD FIX 05/09/2026 (A2) — MOB DE COSTAS.
		# `suppress_back` só era ligado em `Mob.gd:152` (mobs do mundo aberto); o ator de PvE nascia
		# com ele FALSE. Resultado: mob vindo de baixo (`to.y < 0`) caía em `Dir.UP` e mostrava a
		# strip de COSTAS enquanto perseguia — 1 a cada 6 pockets nasce abaixo do Errante.
		# Regra do projeto (ActorAnimator:174): "mobs nunca dão as costas → perfil".
		_anim.suppress_back = true
		# ★ Identidade para o REGISTRO de animação real (Parte 2/10). Genérico: quem decide se este
		# mob tem corpo real é `data/combat_animation_ready.json`, não um `if mob_id == ...` aqui.
		_anim.combat_kind = "mobs"
		_anim.combat_id = mob_id
		_anim.play_idle()
	if is_elite: scale = Vector2(1.3, 1.3)   # elite ligeiramente maior (leitura visual)
	_build_plate()

func _derive_name(id: String) -> String:
	if MobEligibility.exists(id):
		return str(MobEligibility.get_mob(id).get("visual_id", id))
	return id

## A33 — NAMEPLATE + BARRA DE HP anexados AO ATOR (não ao HUD): o nome e a vida seguem a criatura na tela.
func _build_plate() -> void:
	_nameplate = Label.new()
	_nameplate.text = ("★ " if is_elite else "") + str(display_name).to_upper()
	_nameplate.add_theme_font_size_override("font_size", 12)
	_nameplate.add_theme_color_override("font_color", Color(1, 0.86, 0.5) if is_elite else Color(0.92, 0.94, 0.98))
	_nameplate.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_nameplate.add_theme_constant_override("outline_size", 4)
	_nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nameplate.position = Vector2(-60, -58); _nameplate.size = Vector2(120, 16)
	_nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_nameplate)
	_hp_bg = ColorRect.new()
	_hp_bg.color = Color(0.1, 0.05, 0.06, 0.9)
	_hp_bg.position = Vector2(-30, -40); _hp_bg.size = Vector2(60, 6)
	_hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.85, 0.25, 0.28)
	_hp_fill.position = Vector2(-30, -40); _hp_fill.size = Vector2(60, 6)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_fill)

## Atualiza a barra de HP do ator (frac 0..1). Alimentado pelo host a cada tick (a autoridade do HP é do runtime).
func set_hp(frac: float) -> void:
	if _hp_fill == null: return
	var f := clampf(frac, 0.0, 1.0)
	_hp_fill.size = Vector2(60.0 * f, 6.0)
	_hp_fill.color = Color(0.85, 0.25, 0.28) if f > 0.35 else Color(0.95, 0.55, 0.2)

## A33 — COERÊNCIA anti-ghost-farm (§18/§21): o ator está REALMENTE representando a criatura na cena?
## (na árvore, com o próprio flag de visibilidade ligado, e com sprite REAL — não o losango de fallback).
## Fallback conta como NÃO-coerente. Usa `visible`+`is_inside_tree` (robusto em cena e em teste de unidade).
func combat_visible_ok() -> bool:
	return visible and not used_fallback

## Move o ator até o alvo (o player), simulando o approach do spawn pocket (§A20.10). Retorna se entrou em faixa.
func approach(target: Vector2, speed: float, delta: float) -> bool:
	var to := target - global_position
	var d := to.length()
	if d <= 4.0: return true
	global_position += to.normalized() * minf(speed * delta, d)
	if _anim != null and _anim.has_spritesheet(): _anim.play_walk(to)
	return (target - global_position).length() <= 40.0

## ★★★ FIELD FIX 05/09/2026 (A2/B3) — ENCARAR O ALVO MESMO PARADO.
## `approach()` só atualiza a direção enquanto ANDA, e retorna cedo em `d <= 4.0` sem tocar no
## animator. Ao engajar, o facing CONGELAVA no último rumo do caminho — o mob ficava lutando
## virado para o lado errado. Isto mantém a orientação enquanto ENGAJADO, sem mover o ator.
func face(target: Vector2) -> void:
	if _anim == null or not _anim.has_spritesheet(): return
	var to := target - global_position
	if to.length() > 0.01: _anim.set_direction(to)

## ★★★ Corpo REAL primeiro, procedural depois. A ordem é sempre esta e o `or` não é preguiça:
## `play_real_transient` devolve false quando não há arte PRONTA — e aí o gesto de sempre acontece.
## Nenhum caminho deixa o mob sem encenação (Parte 3/14).
func play_attack(dir: Vector2 = Vector2.ZERO) -> void:
	if _anim == null or not _anim.has_spritesheet(): return
	if _anim.play_real_transient("ATTACK_BASIC", dir): return
	_anim.play_attack(dir, "melee")

func play_hit() -> void:
	if _anim == null or not _anim.has_spritesheet(): return
	if _anim.play_real_transient("HIT"): return
	_anim.play_hit()

## ★★★ FIELD FIX 05/09/2026 — A MORTE ERA INVISÍVEL.
## `play_death()` inicia um tween de 0.5 s (fade + queda + achatamento) e o `queue_free()` que vinha
## na linha seguinte matava o nó no MESMO frame ⇒ **nenhum quadro da morte chegava à tela**.
## Era exatamente o "o lobo pisca e some" relatado em campo.
## Agora o ator é liberado só quando a morte TERMINA (sinal `death_finished`), com um timer de
## segurança para nunca vazar o nó se o sinal não vier (ator sem visual).
const DEATH_LINGER := 0.75   # > 0.5 s do tween; rede de segurança, não a duração da animação

var _dying := false

func die_and_free() -> void:
	if _dying: return
	_dying = true
	# ⛔ DEFEITO CORRIGIDO 05/09 — `_sync_mob_actor` chama isto com o ator JÁ FORA DA ÁRVORE em
	# alguns caminhos; ali `get_tree()` é null e o `create_timer` estourava (2058 erros na _a22),
	# deixando a morte pela metade. Sem árvore não há o que animar: libera direto.
	if _anim == null or not _anim.has_spritesheet() or not is_inside_tree():
		queue_free(); return
	_anim.death_finished.connect(_on_death_finished, CONNECT_ONE_SHOT)
	# Morte real quando houver; senão o tween de sempre. Os DOIS emitem `death_finished`, então o
	# ciclo de vida (esperar a morte terminar antes do queue_free) é o MESMO nos dois caminhos —
	# é isso que torna seguro trocar a arte sem mexer no lifecycle (Parte 9).
	if not _anim.play_real_transient("DEATH"):
		_anim.play_death()
	var t := get_tree()
	if t != null:
		t.create_timer(DEATH_LINGER).timeout.connect(_on_death_finished, CONNECT_ONE_SHOT)

func _on_death_finished() -> void:
	if is_instance_valid(self) and not is_queued_for_deletion(): queue_free()
