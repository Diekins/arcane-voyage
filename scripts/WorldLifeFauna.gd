extends Node2D
class_name WorldLifeFauna
## ─────────────────────────────────────────────────────────────────────────────
## WORLD LIFE — 2º piloto: AVES COSTEIRAS rondam a Costa do Sal-Vento.
## Ver godot/docs/WORLD_LIFE_FAUNA_PILOT_DESIGN.md + WORLD_LIFE_FAUNA_COAST_BIRDS_BUILD.
##
## ★ A fauna pertence ao MUNDO. Não reage, não espera, não existe PARA o jogador. Apenas vive.
##   Pode ser ignorada, perdida. Sem recompensa/progresso/conteúdo/interação.
##
## ★ MMO-first: posição = função DETERMINÍSTICA do tempo do mundo (Time.get_unix_time_from_system)
##   → vários clientes veriam as MESMAS aves no mesmo momento do ciclo. Sem randf por sessão.
##
## Prova MORADIA (a outra metade da caravana=TRÂNSITO): vida que FICA e te IGNORA.
## SEM Area2D / colisão / interação / prompt / texto / UI / save / IA / pet / recurso.
## 2–3 aves: silhuetas que rondam sobre a água/horizonte (faixa superior), longe do jogador,
## com curvas lentas + sumir/reaparecer além do horizonte (sem POUSAR perto do jogador).
## ─────────────────────────────────────────────────────────────────────────────

const SIL_COLOR := Color(0.18, 0.16, 0.14, 0.62)   # silhueta distante (indiferente, notável mas não chamativa)
const FADE := 4.0                                  # s de fade ao surgir/sumir no horizonte (sem "pop")

# Cada ave: tudo FRAÇÃO do tamanho da região. ★ Céu SOBRE A PRAIA (cy≈0.27–0.31 → y~350–400, ACIMA do Errante
# que anda em y~650 mas DENTRO da câmera 1280×720 = ±360 em y), espalhadas pela orla (cx 0.22/0.52/0.83) p/ pelo
# menos uma estar sempre no enquadramento de quem caminha a Costa. Params fixos distintos → não-sincronizadas.
const BIRDS := [
	{ "cx": 0.22, "cy": 0.30, "rx": 230.0, "ry": 72.0, "w": 0.22,  "ph": 0.0, "cycle": 76.0,  "vis": 64.0, "off": 0.0,  "flap": 7.0 },
	{ "cx": 0.52, "cy": 0.27, "rx": 200.0, "ry": 92.0, "w": -0.17, "ph": 1.7, "cycle": 94.0,  "vis": 78.0, "off": 24.0, "flap": 6.3 },
	{ "cx": 0.83, "cy": 0.31, "rx": 300.0, "ry": 60.0, "w": 0.13,  "ph": 3.0, "cycle": 110.0, "vis": 96.0, "off": 50.0, "flap": 7.6 },  # elipse larga = cruzamento suave
]

var _size := Vector2(2200, 1300)
var _birds: Array = []           # [{node, lwing, rwing, p}]
var _time_override := -1.0       # self-test: tempo fixo (>=0 ativa)
var _phase_offset := 0.0         # PRODUÇÃO = 0 (puro/MMO). Só o botão DEV desloca (ver align_now).
var _setup_done := false

## Setup EXPLÍCITO (Main chama após add_child; self-test idem). Idempotente.
func setup(size: Vector2) -> void:
	if _setup_done:
		return
	_setup_done = true
	_size = size
	_build_birds()
	set_process(true)
	_apply_for_time(_world_time())

func _process(_delta: float) -> void:
	_apply_for_time(_world_time())

func _world_time() -> float:
	if _time_override >= 0.0:
		return _time_override
	return Time.get_unix_time_from_system() + _phase_offset

## DEV-only: desloca o tempo p/ as aves estarem VISÍVEIS agora (teste imediato). Produção nunca chama (offset=0).
func align_now() -> void:
	_phase_offset = -Time.get_unix_time_from_system()   # _world_time ≈ 0 → todas as aves no início da janela visível

# ─── Construção (2–3 aves silhueta, asas que batem) ──────────────────────────
func _build_birds() -> void:
	var idx := 0
	for p in BIRDS:
		var bird := Node2D.new()
		bird.set_meta("av_worldlife", true)
		# WORLDLIFE_PACK_03B: sprite real (alterna gaivota A/B p/ variedade) se existir; senão as 2 asas Polygon2D
		# (fallback). O flip e o voo determinístico ficam no nó-pai (intactos). Sem sprite, o bater de asas segue por código.
		var lwing: Polygon2D = null
		var rwing: Polygon2D = null
		var gull := "coast_gull" if idx % 2 == 0 else "coast_gull_b"
		var path := "res://assets/tilesets/saltwind_shore/props/%s.png" % gull
		if ResourceLoader.exists(path):
			var s := Sprite2D.new()
			s.texture = load(path)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			bird.add_child(s)
		else:
			lwing = _make_wing(true)
			rwing = _make_wing(false)
			bird.add_child(lwing)
			bird.add_child(rwing)
		add_child(bird)
		_birds.append({"node": bird, "lwing": lwing, "rwing": rwing, "p": p})
		idx += 1

func _make_wing(left: bool) -> Polygon2D:
	var w := Polygon2D.new()
	var s := -1.0 if left else 1.0
	w.polygon = PackedVector2Array([Vector2(0, 0), Vector2(13 * s, -4), Vector2(3 * s, 1)])  # asa fina varrida (maior = visível)
	w.color = SIL_COLOR
	return w

# ─── Tick determinístico (posição = função do tempo) ─────────────────────────
func _apply_for_time(t: float) -> void:
	for b in _birds:
		var p: Dictionary = b["p"]
		var node: Node2D = b["node"]
		var phase: float = fmod(t + float(p["off"]), float(p["cycle"]))
		if phase < 0.0:
			phase += float(p["cycle"])
		var vis: float = float(p["vis"])
		if phase >= vis:
			node.visible = false        # voou além do horizonte (sumiu) — reaparece no próximo ciclo
			continue
		node.visible = true
		# voo em elipse lenta sobre a água (curva/cruzamento); ângulo contínuo pelo tempo do mundo
		var a: float = float(p["w"]) * t + float(p["ph"])
		var cx: float = _size.x * float(p["cx"])
		var cy: float = _size.y * float(p["cy"])
		node.position = Vector2(cx + float(p["rx"]) * cos(a), cy + float(p["ry"]) * sin(a))
		node.z_index = int(node.position.y)
		# vira na direção do voo (dx = -rx*w*sin(a)); flip só do eixo X
		var dx: float = -float(p["rx"]) * float(p["w"]) * sin(a)
		node.scale.x = (1.0 if dx >= 0.0 else -1.0)
		# fade ao surgir/sumir (sem pop)
		var alpha := 1.0
		if phase < FADE:
			alpha = phase / FADE
		elif phase > vis - FADE:
			alpha = (vis - phase) / FADE
		node.modulate.a = clampf(alpha, 0.0, 1.0)
		# bater de asas (sutil, distante) — pura função do tempo. SÓ no fallback procedural (sprite real não tem asas).
		if b["lwing"] != null:
			var flap: float = 0.5 * sin(t * float(p["flap"]) + float(p["ph"]))
			(b["lwing"] as Node2D).rotation = -flap
			(b["rwing"] as Node2D).rotation = flap

# ─── Introspecção (p/ self-test; sem efeito colateral) ───────────────────────
func bird_count() -> int:
	return _birds.size()
func any_visible_at(t: float) -> bool:
	for b in _birds:
		var p: Dictionary = b["p"]
		var phase: float = fmod(t + float(p["off"]), float(p["cycle"]))
		if phase < 0.0: phase += float(p["cycle"])
		if phase < float(p["vis"]): return true
	return false
func horizon_band_max_y() -> float:
	return _size.y * 0.45   # aves no céu, acima do Errante (y~650), mas dentro da câmera
