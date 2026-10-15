class_name HudShell extends Node
## FATIA A17.10A — DONO DO ESTADO DE UI (§9/§10). Uma única autoridade decide o MODE do HUD e o LAYOUT das 5 zonas.
## Evita 30 nós decidindo `visible` sozinhos e criando sobreposição. Node puro/testável: calcula zonas e visibilidade;
## o Main aplica (esconde tracker de Progressão na Hunt, mostra Hunt HUD, etc). Reage ao PveMode (hunting_changed).

const MODE_PROGRESSION := "HUD_MODE_PROGRESSION"
const MODE_HUNTING := "HUD_MODE_HUNTING"
const MODE_MISSION := "HUD_MODE_MISSION"   # FIELD FIX 01B — modo próprio da MISSÃO (não mapear p/ HUNTING)
const MODE_MENU := "HUD_MODE_MENU"

signal mode_changed(mode: String)

var mode := MODE_PROGRESSION
var _prev_gameplay_mode := MODE_PROGRESSION   # p/ voltar do MENU ao modo de gameplay anterior
var target_present := false
# ganchos que o Main liga p/ aplicar as decisões (mantém o HudShell desacoplado/testável)
var apply_cb: Callable = Callable()

func set_target_present(v: bool) -> void:
	if target_present == v: return
	target_present = v
	_apply()

## Troca de modo idempotente. MENU guarda o modo de gameplay anterior p/ restaurar ao fechar.
func set_mode(m: String) -> void:
	if m == mode: return
	if m == MODE_MENU and mode != MODE_MENU:
		_prev_gameplay_mode = mode
	mode = m
	_apply()
	mode_changed.emit(mode)

func open_menu() -> void: set_mode(MODE_MENU)
func close_menu() -> void: set_mode(_prev_gameplay_mode)
func on_hunting_changed(active: bool) -> void:
	set_mode(MODE_HUNTING if active else MODE_PROGRESSION)
func on_mission_changed(active: bool) -> void:
	set_mode(MODE_MISSION if active else MODE_PROGRESSION)

func _apply() -> void:
	if apply_cb.is_valid(): apply_cb.call(visible_zones())

## Quais zonas aparecem no modo atual. ★ Progression-tracker e Hunt-HUD são MUTUAMENTE EXCLUSIVOS (§HS-T07):
## a zona TOP_RIGHT (context) mostra UM conteúdo por modo, nunca os dois.
func visible_zones() -> Dictionary:
	var menu := mode == MODE_MENU
	var hunting := mode == MODE_HUNTING
	var mission := mode == MODE_MISSION
	return {
		"player_status": true,                      # TOP LEFT sempre
		"target": target_present and not menu,      # TOP CENTER só com alvo
		"context_progression": (not hunting) and (not mission) and (not menu),  # tracker de Progressão
		"context_hunting": hunting and (not menu),  # Hunt Session HUD (só HUNTING)
		"context_mission": mission and (not menu),  # Mission HUD (só MISSION) — FIELD FIX 01B
		"bottom_actions": not menu,                 # x1/x2/x3/AUTO
		"menu_panel": menu,
	}

## Zonas como estariam no MENU (um painel grande domina; gameplay compacto) — §44 exclusividade de painel grande.
func visible_zones_for_menu() -> Dictionary:
	var saved := mode; mode = MODE_MENU
	var z := visible_zones(); mode = saved
	return z

## Nunca mostra os dois trackers ao mesmo tempo (invariante testável §HS-T07).
func trackers_exclusive() -> bool:
	var z := visible_zones()
	var n := (1 if bool(z["context_progression"]) else 0) + (1 if bool(z["context_hunting"]) else 0) + (1 if bool(z.get("context_mission", false)) else 0)
	return n <= 1   # no máximo UM tracker (Progressão XOR Hunt XOR Mission)

## 5 ZONAS responsivas, NÃO sobrepostas, dentro do retângulo de UI (respeita safe area §37, UiMetrics §38).
## As larguras são FRAÇÕES do ui_rect (garante não-overlap em qualquer largura/breakpoint). Retorna Rect2 por zona.
func zones_for(logical: Vector2, safe: Dictionary) -> Dictionary:
	var ui := UiMetrics.ui_rect(logical, safe)
	var pad := 12.0
	var top := ui.position.y + pad
	var pw := ui.size.x * 0.28
	var tw := ui.size.x * 0.30
	var cw := ui.size.x * 0.26
	var bw := ui.size.x * 0.44
	var player_status := Rect2(ui.position.x + pad, top, pw, 110)
	var target := Rect2(ui.position.x + ui.size.x * 0.5 - tw * 0.5, top, tw, 44)
	var context := Rect2(ui.position.x + ui.size.x - pad - cw, top, cw, 160)
	var bottom := Rect2(ui.position.x + ui.size.x * 0.5 - bw * 0.5, ui.position.y + ui.size.y - pad - 56.0, bw, 56)
	return {"player_status": player_status, "target": target, "context": context, "bottom_actions": bottom,
		"world": ui, "ui_rect": ui, "breakpoint": UiMetrics.breakpoint_for(logical.x)}

## Verdadeiro se as 4 zonas de painel (TL/TC/TR/BC) NÃO se sobrepõem (contrato responsivo §39).
func zones_no_overlap(logical: Vector2, safe: Dictionary) -> bool:
	var z := zones_for(logical, safe)
	var panels := [z["player_status"], z["target"], z["context"], z["bottom_actions"]]
	for i in range(panels.size()):
		for j in range(i + 1, panels.size()):
			if (panels[i] as Rect2).intersects(panels[j] as Rect2):
				return false
	return true

## Todas as zonas cabem dentro do ui_rect (não cortam / não invadem fora do retângulo seguro §39).
func zones_within_ui(logical: Vector2, safe: Dictionary) -> bool:
	var z := zones_for(logical, safe)
	var ui: Rect2 = z["ui_rect"]
	for k in ["player_status", "target", "context", "bottom_actions"]:
		if not ui.encloses(z[k] as Rect2):
			return false
	return true
