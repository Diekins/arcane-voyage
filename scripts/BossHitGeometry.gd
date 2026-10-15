class_name BossHitGeometry
## FATIA A10.1 — GEOMETRIA DE HIT de boss (pura, sem cena). FONTE ÚNICA que o dano do BossController consome — a
## MESMA definição (reach/deg/radius/half_width da BossAbility) que o telegraph desenha (§3/§6/§11). O que o
## telegraph MOSTRA é o que o dano RESPEITA. NÃO altera dano/CP/HP/cooldown/CombatMath — só decide "acertou?".
## Convenção: boss na ORIGEM (0,0); `offset` = posição do player relativa ao boss; `aim` = direção telegrafada
## (capturada no início do cast). GROUND/HAZARD usam um CENTRO telegrafado próprio (não recalcula sobre a posição
## atual do player, §7). i-frames de dodge têm prioridade e são checados FORA daqui (no BossController, §12).

const HALF_WIDTH_DEFAULT := 40.0
const CONE_HALF_DEG_DEFAULT := 41.0   # ~82° de abertura total (padrão dos presets)

## LINE — faixa: dentro do comprimento [0,length] ao longo de `aim` E |perpendicular| <= half_width. Atrás = MISS.
static func in_line(offset: Vector2, aim: Vector2, length: float, half_width: float) -> bool:
	var a := aim.normalized()
	if a == Vector2.ZERO:
		return offset.length() <= half_width
	var t := offset.dot(a)                 # projeção ao longo do aim
	if t < 0.0 or t > length:              # atrás do boss ou além do alcance → MISS
		return false
	var perp := (offset - a * t).length()  # distância lateral à faixa
	return perp <= half_width

## CONE — dentro do raio E dentro do meio-ângulo em torno de `aim`. Fora do ângulo (mesmo perto) = MISS.
static func in_cone(offset: Vector2, aim: Vector2, radius: float, half_deg: float) -> bool:
	var d := offset.length()
	if d > radius or d <= 0.0001:
		return d <= 0.0001   # no centro conta como acerto
	var a := aim.normalized()
	if a == Vector2.ZERO:
		return true
	var ang := rad_to_deg(a.angle_to(offset))
	return absf(ang) <= half_deg

## CIRCLE — distância real ao centro (default = boss na origem).
static func in_circle(offset: Vector2, radius: float, center: Vector2 = Vector2.ZERO) -> bool:
	return (offset - center).distance_to(Vector2.ZERO) <= radius if center != Vector2.ZERO else offset.length() <= radius

## Distância a um centro arbitrário (GROUND/HAZARD telegrafados).
static func in_zone(offset: Vector2, center: Vector2, radius: float) -> bool:
	return offset.distance_to(center) <= radius

## ★ Resolve o HIT de uma ability (dados da BossAbility) contra o player. `offset` = player relativo ao boss;
## `aim` = direção telegrafada; `cast_center` = centro telegrafado de GROUND/HAZARD (posição do player no cast).
## Reusa EXATAMENTE reach/deg/radius/half_width da ability (uma tabela só). Retorna se o dano deve ser aplicado.
static func hits(a: Dictionary, offset: Vector2, aim: Vector2, cast_center: Vector2 = Vector2.ZERO) -> bool:
	match BossAbility.kind(a):
		"line":
			return in_line(offset, aim, float(a.get("reach", 235.0)), float(a.get("half", HALF_WIDTH_DEFAULT)))
		"charge":
			# investida: faixa mais larga ao longo da trajetória (aim), volume coerente (não AoE circular §10).
			return in_line(offset, aim, float(a.get("reach", 300.0)), float(a.get("half", 56.0)))
		"cone":
			return in_cone(offset, aim, float(a.get("reach", 156.0)), float(a.get("deg", 82.0)) * 0.5)
		"projectile":
			# projétil viaja ao longo de `aim`: faixa estreita (direção IMPORTA, §9), não distance_to(boss).
			return in_line(offset, aim, float(a.get("reach", 600.0)), float(a.get("half", 34.0)))
		"volley":
			# leque de N projéteis em torno de `aim`: cone estreito (a direção declarada importa).
			return in_cone(offset, aim, float(a.get("reach", 600.0)), 26.0)
		"circle":
			return in_circle(offset, float(a.get("radius", 140.0)))
		"ground_aoe":
			# §7: usa o CENTRO telegrafado no cast (cast_center), NÃO a posição atual do player.
			return in_zone(offset, cast_center, float(a.get("radius", 116.0)))
		"hazard":
			# a zona é checada no BossController (cada hazard guarda seu center/radius §8); helper p/ um center dado.
			return in_zone(offset, cast_center, float(a.get("radius", 120.0)))
		_:
			return false

## Contrato telegraph=hit (§11): o telegraph de uma ability usa a MESMA forma/raio/ângulo que o hit? (para teste)
static func telegraph_matches_hit(a: Dictionary) -> bool:
	var k := BossAbility.kind(a)
	if not BossFeedback.is_dangerous(k):
		return true
	# a forma do telegraph (BossFeedback) e a geometria de hit (aqui) derivam do MESMO `kind` e dos MESMOS campos.
	var shape := BossFeedback.telegraph_kind(k)
	match shape:
		"LINE": return k == "line" or k == "charge" or k == "projectile"
		"CONE": return k == "cone"
		"CIRCLE": return k == "circle"
		"GROUND": return k == "ground_aoe"
		"VOLLEY": return k == "volley"
		"HAZARD": return k == "hazard"
		"PROJECTILE": return k == "projectile"
		_: return false
