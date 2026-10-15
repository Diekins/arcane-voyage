extends Node2D
class_name WorldLifeCaravan
## ─────────────────────────────────────────────────────────────────────────────
## WORLD LIFE — piloto: uma caravana atravessa os Areais (khet_sar_sands), OESTE → LESTE.
## Ver godot/docs/WORLD_LIFE_CARAVAN_PILOT_DESIGN.md.
##
## ★ A caravana pertence ao MUNDO, não ao jogador: não espera, não reage, não conversa,
##   não vende, não luta, não colide. Apenas atravessa. Pode ser perdida pelo jogador.
##
## ★ MMO-first: o movimento é função DETERMINÍSTICA do tempo do mundo
##   (Time.get_unix_time_from_system) → vários clientes veriam a MESMA caravana no mesmo
##   trecho do ciclo. Nada de randf por sessão, nada disparado pela chegada do jogador.
##
## SEM Area2D / colisão / interação / prompt / texto / UI / save / IA / recompensa.
## 3 entidades visuais (1 carga + 2 viajantes) — silhuetas indiferentes (estilo _dca_crosser).
## ─────────────────────────────────────────────────────────────────────────────

# Ciclo de mundo: cruza por CROSS_DURATION s, some o resto (intervalo frouxo → às vezes vazio).
const CYCLE := 240.0            # período do mundo (s)
const CROSS_DURATION := 96.0    # tempo p/ cruzar O→L (lento; ~½ da velocidade do jogador)
const ENTER_PAD := 150.0        # entra/sai ALÉM das bordas (já em movimento ao surgir; some na oposta)
const ROUTE_Y_FRAC := 0.52      # faixa da trilha (meio dos Areais)
const SWAY_AMP := 26.0          # leve desvio orgânico (rota discreta, não-trilho)
const SIL_COLOR := Color(0.16, 0.13, 0.11, 0.64)   # silhueta indiferente (anonimato), como o _dca_crosser (notável)

var _size := Vector2(2000, 1300)
var _members: Array = []        # [{node, offset}] — carga + viajantes
var _time_override := -1.0      # self-test: tempo de mundo fixo (>=0 ativa; -1 = relógio real)
var _phase_offset := 0.0        # PRODUÇÃO = 0 (puro/MMO). Só o botão DEV desloca p/ alinhar a travessia ao teste.
var _route_y := -1.0            # y da rota; default = size.y*ROUTE_Y_FRAC. Main passa o y do SPAWN p/ cruzar na vista.
var _setup_done := false

## Setup é EXPLÍCITO (Main chama c.setup(size, route_y) após add_child; self-test idem). Idempotente.
## route_y = faixa por onde a caravana cruza; Main passa o y do spawn do jogador p/ ela passar no enquadramento.
func setup(size: Vector2, route_y: float = -1.0) -> void:
	if _setup_done:
		return
	_setup_done = true
	_size = size
	_route_y = route_y if route_y >= 0.0 else size.y * ROUTE_Y_FRAC
	_build_members()
	set_process(true)
	_apply_for_time(_world_time())

func _process(_delta: float) -> void:
	_apply_for_time(_world_time())   # posição = função do tempo do mundo (ignora delta → determinístico/resume-safe)

# ─── Tempo do mundo (determinístico, compartilhável) ─────────────────────────
func _world_time() -> float:
	if _time_override >= 0.0:
		return _time_override
	return Time.get_unix_time_from_system() + _phase_offset   # relógio do MUNDO (offset=0 em produção)

## DEV-only: desloca o ciclo p/ a caravana ESTAR ENTRANDO agora (teste imediato). Produção nunca chama
## (offset fica 0 = puro/MMO). Não toca o save; não afeta a pureza de progress_at/anchor_at (essas são do arg).
func align_now() -> void:
	var phase := fmod(Time.get_unix_time_from_system(), CYCLE)
	_phase_offset = 2.0 - phase   # → fmod(now+offset, CYCLE) ≈ 2s: a caravana acabou de entrar a oeste

## Progresso 0..1 no ciclo; -1 quando a caravana está AUSENTE (gap entre travessias = trânsito, não loop).
func progress_at(t: float) -> float:
	var phase := fmod(t, CYCLE)
	if phase < 0.0:
		phase += CYCLE
	if phase >= CROSS_DURATION:
		return -1.0
	return phase / CROSS_DURATION

## Âncora (centro do grupo) p/ um progresso 0..1. PURA função do tempo → determinística (MMO-first).
func anchor_at(p: float) -> Vector2:
	var x := lerpf(-ENTER_PAD, _size.x + ENTER_PAD, p)
	var y := _route_y + sin(p * TAU) * SWAY_AMP
	return Vector2(x, y)

func _apply_for_time(t: float) -> void:
	var p := progress_at(t)
	if p < 0.0:
		visible = false        # ausente: o areal fica vazio (real) — sem caravana neste trecho do ciclo
		return
	visible = true
	var base := anchor_at(p)
	for m in _members:
		var node: Node2D = m["node"]
		node.position = base + (m["offset"] as Vector2)
		node.z_index = int(node.position.y)   # y-sort (« 4095 → CombatVfx intacto)

# ─── As 3 entidades (1 carga + 2 viajantes), silhuetas indiferentes ──────────
func _build_members() -> void:
	# move +x (leste) = frente. Espaçamento IRREGULAR → lê como gente, não formação.
	_add_member(_make_traveler(0.95, "caravan_traveler"), Vector2(38, -10))     # viajante à frente
	_add_member(_make_cargo(), Vector2(-2, 4))                                  # carga no meio
	_add_member(_make_traveler(1.05, "caravan_traveler_b"), Vector2(-40, 9))    # viajante atrás (variante B)

func _add_member(node: Node2D, offset: Vector2) -> void:
	node.set_meta("av_worldlife", true)
	add_child(node)
	_members.append({"node": node, "offset": offset})

## Viajante: sprite real (WORLDLIFE_PACK_03B; key = caravan_traveler/_b) se existir; senão a silhueta Polygon2D
## (fallback, mesmo polígono do _dca_crosser). Pés na origem; escala por scl. Retorna Node2D (Sprite ou Polygon).
func _make_traveler(scl: float, key: String = "caravan_traveler") -> Node2D:
	var path := "res://assets/tilesets/desert/props/%s.png" % key
	if ResourceLoader.exists(path):
		var s := Sprite2D.new()
		s.texture = load(path)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(scl, scl)
		s.offset = Vector2(0.0, -24.0)   # pés na origem (figura 32x48 sobe acima)
		return s
	var sil := Polygon2D.new()
	sil.polygon = PackedVector2Array([
		Vector2(-5, -2), Vector2(-4, -20), Vector2(-2, -27), Vector2(2, -27),
		Vector2(4, -20), Vector2(5, -2), Vector2(2, 0), Vector2(-2, 0),
	])
	sil.scale = Vector2(scl, scl)
	sil.color = SIL_COLOR
	return sil

## Carga: sprite real (WORLDLIFE_PACK_03B) se existir; senão carroça/fardo Polygon2D (fallback). Sem blocker/Area2D.
func _make_cargo() -> Node2D:
	var cargo := Node2D.new()
	var cpath := "res://assets/tilesets/desert/props/caravan_pack_beast.png"
	if ResourceLoader.exists(cpath):
		var s := Sprite2D.new()
		s.texture = load(cpath)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.offset = Vector2(0.0, -24.0)   # base (rodas/patas) na origem
		cargo.add_child(s)
		return cargo
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-24, 0), Vector2(-21, -20), Vector2(-6, -28), Vector2(14, -27),
		Vector2(22, -16), Vector2(24, 0),
	])
	body.color = SIL_COLOR
	cargo.add_child(body)
	for wx in [-13.0, 12.0]:
		var wheel := Polygon2D.new()
		wheel.polygon = _circle_poly(5.0, 10)
		wheel.position = Vector2(wx, 1.0)
		wheel.color = SIL_COLOR
		cargo.add_child(wheel)
	return cargo

func _circle_poly(r: float, seg: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

# ─── Introspecção (p/ self-test; sem efeito colateral) ───────────────────────
func member_count() -> int:
	return _members.size()
func is_present_at(t: float) -> bool:
	return progress_at(t) >= 0.0
