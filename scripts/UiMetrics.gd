class_name UiMetrics extends RefCounted
## FATIA A14.2 — MÉTRICAS de UI centralizadas (§34-38). ★ Nada de "88" mágico espalhado. Uma fonte para: retângulo
## lógico (sob stretch=expand §3.3), safe area (§8/§36), alvo de toque mínimo em UL (§12/§35), densidade/breakpoint
## (§38) e o retângulo de UI centrado (§7.3/§R10). Puro/determinístico → a matriz de aspect (§62) é testável sem
## renderizar. 1 UL = 1 px do canvas base 1280×720.

const BASE_W := 1280.0
const BASE_H := 720.0

# alvos de toque em UL (§12.2). No POINTER (mouse) o mínimo cai (cursor é preciso, §42).
const TT_A := 100   # ação primária (▸IR/COLETAR/PRESTIGIAR/ataque Arena)
const TT_B := 88    # ação padrão (mínimo 7,5 mm) — botões/tabs/célula/escolha/x1x2x3/AUTO
const TT_C := 72    # secundário denso (linha de lista) — só com ≥8 UL de espaçamento
const TT_D := 100   # fechar/destrutivo
const TT_SPACING := 12
const TT_POINTER := 40   # desktop/mouse

# breakpoints por largura lógica (§38)
const BP_COMPACT := "COMPACT"   # ≤ 1300 (telefone 16:9/tablet 4:3 estreito)
const BP_REGULAR := "REGULAR"   # 1300..1560
const BP_WIDE := "WIDE"         # > 1560 (20:9+, ultrawide)

# piso de safe area em UL quando o SO não informa (SA-3, §8.3) — só em TOUCH
const SAFE_FLOOR_H := 44
const SAFE_FLOOR_TOP := 16
const SAFE_FLOOR_BOTTOM := 32

const UI_MAX_WIDTH := 1440.0   # §R10 — retângulo de UI centrado; excedente ultrawide = moldura do mundo

## Retângulo LÓGICO sob stretch=expand: escala = min(pw/1280, ph/720); lógico = físico/escala.
static func logical_viewport(physical: Vector2) -> Vector2:
	if physical.x <= 0 or physical.y <= 0:
		return Vector2(BASE_W, BASE_H)
	var scale := minf(physical.x / BASE_W, physical.y / BASE_H)
	if scale <= 0.0: scale = 1.0
	return Vector2(round(physical.x / scale), round(physical.y / scale))

static func breakpoint_for(logical_w: float) -> String:
	if logical_w > 1560.0: return BP_WIDE
	if logical_w >= 1300.0: return BP_REGULAR
	return BP_COMPACT

## Alvo de toque mínimo (UL) por classe e apresentação. TOUCH usa o padrão §12; POINTER cai p/ 40 UL.
static func min_touch_target(presentation: String, tt_class: String = "TT_B") -> int:
	if presentation == PlatformCapabilities.PRESENT_POINTER:
		return TT_POINTER
	match tt_class:
		"TT_A", "TT_D": return TT_A
		"TT_C": return TT_C
		_: return TT_B

## Safe area em UL. `raw_insets` = {left,top,right,bottom} do SO (0 se não informado). TOUCH aplica o PISO (§8.3);
## POINTER/desktop = 0 (§8.3 SA-4). Valores malformados/negativos → 0 (§112).
static func safe_area(raw_insets: Dictionary, presentation: String) -> Dictionary:
	var l := maxf(0.0, float(raw_insets.get("left", 0)))
	var t := maxf(0.0, float(raw_insets.get("top", 0)))
	var r := maxf(0.0, float(raw_insets.get("right", 0)))
	var b := maxf(0.0, float(raw_insets.get("bottom", 0)))
	if presentation == PlatformCapabilities.PRESENT_TOUCH:
		l = maxf(l, SAFE_FLOOR_H); r = maxf(r, SAFE_FLOOR_H)
		t = maxf(t, SAFE_FLOOR_TOP); b = maxf(b, SAFE_FLOOR_BOTTOM)
	return {"left": l, "top": t, "right": r, "bottom": b}

## Retângulo SEGURO (onde vive UI interativa): lógico menos a safe area. Só UI, nunca o mundo (§37).
static func safe_rect(logical: Vector2, safe: Dictionary) -> Rect2:
	var pos := Vector2(float(safe["left"]), float(safe["top"]))
	var size := Vector2(logical.x - float(safe["left"]) - float(safe["right"]), logical.y - float(safe["top"]) - float(safe["bottom"]))
	return Rect2(pos, size)

## Retângulo de UI CENTRADO limitado a UI_MAX_WIDTH (§R10) — o excedente ultrawide vira moldura do mundo.
static func ui_rect(logical: Vector2, safe: Dictionary) -> Rect2:
	var sr := safe_rect(logical, safe)
	var w := minf(sr.size.x, UI_MAX_WIDTH)
	var x := sr.position.x + (sr.size.x - w) * 0.5
	return Rect2(Vector2(x, sr.position.y), Vector2(w, sr.size.y))

## Um alvo (UL) atende o mínimo da classe na apresentação?
static func target_ok(size_ul: float, presentation: String, tt_class: String = "TT_B") -> bool:
	return size_ul >= float(min_touch_target(presentation, tt_class))

## Densidade (fator de espaçamento/tipografia por apresentação §R6) — MESMA árvore de UI, só a densidade muda.
static func density(presentation: String) -> float:
	return 1.0 if presentation == PlatformCapabilities.PRESENT_POINTER else 1.6
