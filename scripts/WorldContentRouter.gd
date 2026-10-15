class_name WorldContentRouter extends Node
## FATIA A7.4.1 — ROTEADOR DE MUNDO data-driven. O elo que faltava: StageDirector escolhe a fase → ContentManifest
## escolhe o conteúdo → o Main carrega a REGIÃO REAL e spawna o encontro. NÃO é sistema novo: é uma fina camada
## que traduz (capítulo/fase) → world_context e aciona o loader REAL do Main (`world_route_enter` + `ensure_stage_boss`),
## sem inflar o Main.gd nem criar if chapter==1/elif==2.
##
## FONTE ÚNICA: `ContentManifest.region_for_stage(global)` decide a região; o cleanup/player-spawn/notify já são
## do `load_region` (Main). Conecta-se a `StageDirector.stage_changed`. Guardas: (a) só carrega quando o
## world_context MUDA (bounded: no máx. 1 troca por bloco de contexto); (b) re-entrância barrada pelo Main
## (`_world_routing`); (c) `_route_enter` do Main já respeita macro-cluster contínuo (não força mundo linear onde
## há cluster). Ligado DEPOIS do boot (a 1ª carga de região usa o save; a partir daí, a PROGRESSÃO dirige o mundo).

var _host = null
var _sd: StageDirector = null
var _active := false

func setup(host, stagedirector: StageDirector) -> void:
	_host = host
	_sd = stagedirector
	if _sd != null and not _sd.stage_changed.is_connected(_on_stage_changed):
		_sd.stage_changed.connect(_on_stage_changed)
	_active = true

## Desliga o roteamento automático (o mundo não segue a progressão). Não desconecta — só ignora.
func set_active(v: bool) -> void:
	_active = v

func is_active() -> bool:
	return _active

## StageDirector entrou numa fase nova. Resolve a região do capítulo/fase e, se mudou, carrega-a; garante o boss.
func _on_stage_changed(_chapter: int, _stage: int) -> void:
	if not _active or _host == null or _sd == null:
		return
	sync_now()

## Sincroniza o mundo com a fase corrente do StageDirector (idempotente). Também usável direto (teste/▸IR).
func sync_now() -> void:
	if _host == null or _sd == null:
		return
	if _host.get("_world_routing"):
		return   # há uma carga de região em progresso → não reage (o boss é spawnado ao fim dela)
	var target := ContentManifest.region_for_stage(_sd.global_stage())
	if target != "" and _host.has_method("world_route_enter"):
		_host.world_route_enter(target)          # no-op se já for a região corrente (guarda no Main)
	if _host.has_method("ensure_stage_boss"):
		_host.ensure_stage_boss()                # spawna o boss do manifesto na fase 10 (se ainda não há)
