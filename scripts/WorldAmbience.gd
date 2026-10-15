extends Node
class_name WorldAmbience
## ─────────────────────────────────────────────────────────────────────────────
## WorldAmbience — fundação de áudio ambiente MMO-first de Arcane Voyage.
## Ver godot/docs/AMBIENT_AUDIO_FOUNDATION_AUDIT.md (o projeto) e
##     godot/docs/AMBIENT_AUDIO_FOUNDATION_BUILD.md (este build + como testar).
##
## ★ PRINCÍPIO: o áudio pertence ao MUNDO, não ao jogador.
##   Não há trilha que segue a câmera. O som é propriedade de LUGARES e de COISAS;
##   os respiros são pontos FIXOS no mundo pela duração do som (vêm de uma direção),
##   nunca um leito estéreo colado no ouvido nem reativos ao que o jogador faz.
##
## ★ PADRÃO DORMENTE (generaliza o _dca_murmur da Cidade do Deserto):
##   cada camada tem um nó FIADO e um caminho de asset OPCIONAL. Se o .ogg não
##   existe, a camada fica SILENCIOSA e NÃO gera erro. Um drop-in de .ogg no
##   caminho-convenção ACENDE a camada sem novo código.
##
## Com ZERO assets: o jogo é idêntico e mudo — nenhuma dependência obrigatória de
## áudio. NÃO toca save / combate / economia / progressão / quest / UI / Desert
## City Atmo (este controlador é puramente aditivo e isolado).
## ─────────────────────────────────────────────────────────────────────────────

# --- Caminhos-convenção (drop-in acende; ausência = dormente) ---
const AMBIENT_DIR := "res://assets/audio/ambient/"
const GLOBAL_BED_PATH := AMBIENT_DIR + "global_bed.ogg"   # CAMADA 1 — leito global quase-mudo
const REGION_BED_PREFIX := AMBIENT_DIR + "region_"        # CAMADA 2 — region_<key>.ogg (por família/lugar)
const BREATHS_DIR := AMBIENT_DIR + "breaths/"            # CAMADA 3 — breaths/<chave>_N.ogg (respiros POR FAMÍLIA)
const BREATH_SLOTS := 4

# --- Volumes (quase-mudo POR DESIGN; placeholders, sem asset não soam) ---
const GLOBAL_BED_DB := -22.0   # quase-mudo, mas presente (o leito é ruído de ar; -22 dB = "sopro", não trilha)
const REGION_BED_DB := -20.0
const BREATH_DB := -14.0   # nunca chamar atenção
const BED_FADE := 1.2   # s — fade in/out do leito regional na troca de região

# --- Respiros do mundo: RAROS (intervalo longo e aleatório), espaciais, NÃO-loop ("algo aconteceu") ---
const BREATH_MIN_GAP := 24.0
const BREATH_MAX_GAP := 58.0
const BREATH_RADIUS_MIN := 220.0
const BREATH_RADIUS_MAX := 560.0

## region_id -> chave de leito regional (família ou lugar). Regiões NÃO mapeadas =
## só o leito global (correto p/ genéricas: profundidade>largura). Famílias dividem
## o mesmo .ogg (region_<key>.ogg). Ver seção 3 do AUDIT.
const REGION_BED := {
	# PEDRA / SUBTERRA
	"cave": "cave_stone", "swamp_pit": "cave_stone",
	# COSTA / LIMIAR
	"saltwind_shore": "coast", "castaway_sandbar": "coast", "salt_split_isle": "coast",
	# HUB
	"starter_village": "village",
	# CIDADE VIVA (distinto do _dca_murmur p/ não chocar; aquele continua dono do murmúrio próprio)
	"khet_sar_city": "desert_city",
	# REPOUSO
	"swamp": "swamp",
	# FLORESTA
	"ashen_grove": "forest", "deep_grove": "forest", "ancient_root_nest": "forest",
	# DESERTO ABERTO
	"khet_sar_sands": "desert", "khet_oasis": "desert", "khet_caravan_camp": "desert", "deep_dunes": "desert",
}

var _bus := "Master"
var _global_player: AudioStreamPlayer = null
var _region_player: AudioStreamPlayer = null
var _region_key := ""
var _breath_timer: Timer = null
var _breath_streams: Array = []   # só os respiros que de fato existem (dormente = vazio)
var _setup_done := false

func _ready() -> void:
	setup()

## Monta as 3 camadas. Idempotente (guard) — _ready chama no jogo; self-test pode chamar
## explicitamente (não depende do timing de _ready no SceneTree).
func setup() -> void:
	if _setup_done:
		return
	_setup_done = true
	_bus = _ensure_bus()
	_setup_global_bed()
	_setup_region_player()
	_setup_breaths()

# ─── CAMADA 1: leito global ──────────────────────────────────────────────────
func _setup_global_bed() -> void:
	_global_player = AudioStreamPlayer.new()
	_global_player.name = "GlobalBed"
	_global_player.bus = _bus
	_global_player.volume_db = GLOBAL_BED_DB
	add_child(_global_player)
	var st := _try_load(GLOBAL_BED_PATH)
	if st != null:
		_loopify(st)
		_global_player.stream = st
		if _global_player.is_inside_tree():   # padrão do _dca_murmur: só toca se na árvore (robusto a setup pré-tree)
			_global_player.play()   # contínuo, nunca reinicia na troca de região (sem costura)

# ─── CAMADA 2: leito regional (acende/troca via set_region) ───────────────────
func _setup_region_player() -> void:
	_region_player = AudioStreamPlayer.new()
	_region_player.name = "RegionBed"
	_region_player.bus = _bus
	_region_player.volume_db = REGION_BED_DB
	add_child(_region_player)

## API pública: chamada quando a região muda (Main escuta GameState.state_changed).
## No-op se a chave de leito não mudou. Dormente se o asset da chave não existe.
func set_region(region_id: String) -> void:
	var key: String = REGION_BED.get(region_id, "")
	if key == _region_key:
		return
	_region_key = key
	_apply_region_bed(key)
	_reload_breaths(key)   # CAMADA 3: respiros da FAMÍLIA da região atual (dormente se ausente)

func _apply_region_bed(key: String) -> void:
	if _region_player == null:
		return
	if _region_player.playing:
		_fade_out_and_swap(key)
	else:
		_swap_region_bed(key)

func _swap_region_bed(key: String) -> void:
	_region_player.stop()
	_region_player.stream = null
	if key == "":
		return
	var st := _try_load(REGION_BED_PREFIX + key + ".ogg")
	if st == null:
		return   # dormente: família/lugar sem asset → silêncio (sem erro)
	_loopify(st)
	_region_player.stream = st
	_region_player.volume_db = REGION_BED_DB
	if not _region_player.is_inside_tree():
		return   # setup pré-tree (ex.: self-test): stream pronto; play/fade só na árvore real
	_region_player.play()
	# fade-in (limiar audível ao cruzar o portal)
	var from_db := REGION_BED_DB - 24.0
	_region_player.volume_db = from_db
	var tw := create_tween()
	tw.tween_property(_region_player, "volume_db", REGION_BED_DB, BED_FADE)

func _fade_out_and_swap(next_key: String) -> void:
	if not _region_player.is_inside_tree():
		_swap_region_bed(next_key)   # sem árvore (self-test): troca direta, sem tween
		return
	var tw := create_tween()
	tw.tween_property(_region_player, "volume_db", REGION_BED_DB - 24.0, BED_FADE * 0.6)
	tw.tween_callback(_swap_region_bed.bind(next_key))

# ─── CAMADA 3: respiros do mundo (esparsos, espaciais, não-reativos) ──────────
func _setup_breaths() -> void:
	_breath_timer = Timer.new()
	_breath_timer.name = "BreathTimer"
	_breath_timer.one_shot = true
	_breath_timer.timeout.connect(_on_breath_timeout)
	add_child(_breath_timer)
	_reload_breaths(_region_key)   # pool da família atual (vazio se região genérica/sem asset)
	_schedule_breath()   # roda mesmo dormente (custo ~zero); só não toca se o pool está vazio

## Recarrega o pool de respiros p/ a FAMÍLIA da região (breaths/<chave>_N.ogg). Dormente se ausente/genérica.
func _reload_breaths(key: String) -> void:
	_breath_streams.clear()
	if key == "":
		return   # região genérica → sem respiros próprios (só os leitos)
	for i in range(1, BREATH_SLOTS + 1):
		var st := _try_load(BREATHS_DIR + key + "_" + str(i) + ".ogg")
		if st != null:
			_breath_streams.append(st)

func _schedule_breath() -> void:
	if _breath_timer == null or not _breath_timer.is_inside_tree():
		return   # sem árvore (self-test) → não agenda; em jogo o timer está na árvore
	_breath_timer.start(randf_range(BREATH_MIN_GAP, BREATH_MAX_GAP))

func _on_breath_timeout() -> void:
	_emit_breath()
	_schedule_breath()

func _emit_breath() -> void:
	if _breath_streams.is_empty():
		return   # dormente: nenhum respiro disponível → silêncio (sem erro)
	var st: AudioStream = _breath_streams[randi() % _breath_streams.size()]
	var p := AudioStreamPlayer2D.new()
	p.bus = _bus
	p.volume_db = BREATH_DB
	p.stream = st
	p.position = _breath_world_pos()
	p.finished.connect(p.queue_free)
	add_child(p)
	if p.is_inside_tree():
		p.play()

## Ponto FIXO no mundo, perto do ouvinte (Camera2D), em ângulo/distância aleatórios.
## NÃO segue o jogador: é diegético (vem de uma direção), não um leito colado na câmera.
func _breath_world_pos() -> Vector2:
	var center := Vector2.ZERO
	var vp := get_viewport()
	if vp != null:
		var cam := vp.get_camera_2d()
		if cam != null:
			center = cam.get_screen_center_position()
	var ang := randf() * TAU
	var dist := randf_range(BREATH_RADIUS_MIN, BREATH_RADIUS_MAX)
	return center + Vector2(cos(ang), sin(ang)) * dist

# ─── Infra dormente ──────────────────────────────────────────────────────────
## Carrega um AudioStream SE existir; senão null (sem erro). Coração do padrão dormente.
func _try_load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if res is AudioStream:
		return res
	return null

## Marca o stream como loop quando o formato suporta (Ogg/MP3 têm `loop`; WAV usa loop_mode).
func _loopify(st: AudioStream) -> void:
	if st == null:
		return
	if "loop" in st:
		st.set("loop", true)
	elif "loop_mode" in st:
		st.set("loop_mode", 1)   # AudioStreamWAV.LOOP_FORWARD

## Bus dedicado "Ambient" (prepara ducking/slider futuros), criado em runtime.
## Falha graciosa: qualquer problema → cai no Master (nunca quebra).
func _ensure_bus() -> String:
	if AudioServer.get_bus_index("Ambient") != -1:
		return "Ambient"
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	if idx <= 0:
		return "Master"
	AudioServer.set_bus_name(idx, "Ambient")
	AudioServer.set_bus_send(idx, "Master")
	return "Ambient"

# ─── Introspecção (p/ self-test; sem efeito colateral) ───────────────────────
func global_bed_active() -> bool:
	return _global_player != null and _global_player.stream != null
func region_key() -> String:
	return _region_key
func region_bed_active() -> bool:
	return _region_player != null and _region_player.stream != null
func breath_available_count() -> int:
	return _breath_streams.size()
func bus_name() -> String:
	return _bus
func bed_key_for(region_id: String) -> String:
	return REGION_BED.get(region_id, "")
