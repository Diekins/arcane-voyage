class_name BossAbility
## FATIA A7.4 — DESCRITOR + LÓGICA determinística de UMA habilidade de boss. SEM dependência de cena/física:
## o BossController usa estes helpers e os self-tests chamam direto (fixture headless). Uma habilidade é um
## Dictionary de dados. Reutiliza as formas que já existem em Wolf.gd/Golem.gd (line/cone/circle/ground_aoe/
## charge/projectile) e ADICIONA as 7 novas do briefing (shield/enrage/summon/teleport/heal/hazard). NÃO duplica
## a lógica de combate do jogo — modela o CONTRATO (windup/cooldown/dano/efeito) de forma composável e testável.

## Formas OFENSIVAS já existentes no jogo (telegrafadas) + volley (leque de projéteis).
const OFFENSIVE_KINDS := ["line", "cone", "circle", "ground_aoe", "charge", "projectile", "volley"]
## Mecânicas NOVAS (utilitárias/estado).
const UTILITY_KINDS := ["shield", "enrage", "summon", "teleport", "heal", "hazard"]

static func kinds() -> Array:
	return OFFENSIVE_KINDS + UTILITY_KINDS

# ── Construtores (cada um retorna um Dictionary-habilidade novo) ──
# Reutilizadas (ofensivas telegrafadas):
static func line(id: String, damage: int, reach: float = 235.0, windup: float = 0.5, cooldown: float = 2.2) -> Dictionary:
	return {"kind": "line", "id": id, "damage": damage, "reach": reach, "windup": windup, "cooldown": cooldown}

static func cone(id: String, damage: int, reach: float = 156.0, deg: float = 82.0, windup: float = 0.45, cooldown: float = 2.0) -> Dictionary:
	return {"kind": "cone", "id": id, "damage": damage, "reach": reach, "deg": deg, "windup": windup, "cooldown": cooldown}

static func circle(id: String, damage: int, radius: float = 140.0, windup: float = 0.6, cooldown: float = 3.0) -> Dictionary:
	return {"kind": "circle", "id": id, "damage": damage, "radius": radius, "windup": windup, "cooldown": cooldown}

static func ground_aoe(id: String, damage: int, radius: float = 116.0, windup: float = 0.95, cooldown: float = 7.0) -> Dictionary:
	return {"kind": "ground_aoe", "id": id, "damage": damage, "radius": radius, "windup": windup, "cooldown": cooldown}

static func charge(id: String, damage: int, reach: float = 300.0, windup: float = 0.5, cooldown: float = 5.0) -> Dictionary:
	return {"kind": "charge", "id": id, "damage": damage, "reach": reach, "windup": windup, "cooldown": cooldown}

static func projectile(id: String, damage: int, reach: float = 600.0, windup: float = 0.4, cooldown: float = 2.5) -> Dictionary:
	return {"kind": "projectile", "id": id, "damage": damage, "reach": reach, "windup": windup, "cooldown": cooldown}

# NOVA #6 — volley: N projéteis num único disparo (reusa a forma projectile).
static func volley(id: String, damage: int, count: int = 3, reach: float = 600.0, windup: float = 0.55, cooldown: float = 4.0) -> Dictionary:
	return {"kind": "volley", "id": id, "damage": damage, "count": maxi(1, count), "reach": reach, "windup": windup, "cooldown": cooldown}

# NOVA #1 — shield/invulnerabilidade por janela: absorve dano por `duration`s. absorb 1.0 = imune; 0.5 = -50%.
static func shield(id: String, duration: float = 3.0, cooldown: float = 12.0, absorb: float = 1.0) -> Dictionary:
	return {"kind": "shield", "id": id, "duration": maxf(0.1, duration), "cooldown": cooldown, "absorb": clampf(absorb, 0.0, 1.0), "windup": 0.0}

# NOVA #2 — enrage/fase por HP: ao cruzar hp_frac (0..1), ativa UMA vez (dmg_mult / speed_mult).
static func enrage(id: String, hp_frac: float = 0.4, dmg_mult: float = 1.5, speed_mult: float = 1.25) -> Dictionary:
	return {"kind": "enrage", "id": id, "hp_frac": clampf(hp_frac, 0.05, 0.95), "dmg_mult": maxf(1.0, dmg_mult), "speed_mult": maxf(1.0, speed_mult), "windup": 0.0, "cooldown": 0.0}

# NOVA #3 — summon: invoca `count` lacaios por disparo; total vivo teto `cap`. Não persiste/não dá reward.
static func summon(id: String, minion: String, count: int = 2, cap: int = 4, cooldown: float = 10.0) -> Dictionary:
	return {"kind": "summon", "id": id, "minion": minion, "count": maxi(1, count), "cap": maxi(1, cap), "cooldown": maxf(1.0, cooldown), "windup": 0.6}

# NOVA #4 — teleport: reposiciona o boss dentro de bounds válidos; fallback seguro se alvo inválido.
static func teleport(id: String, reach: float = 380.0, cooldown: float = 8.0) -> Dictionary:
	return {"kind": "teleport", "id": id, "reach": reach, "cooldown": maxf(1.0, cooldown), "windup": 0.3}

# NOVA #5 — heal: cura hp_frac do máximo; teto de curas por encontro (não cria combate infinito).
static func heal(id: String, heal_frac: float = 0.12, cooldown: float = 9.0, max_heals: int = 3) -> Dictionary:
	return {"kind": "heal", "id": id, "heal_frac": clampf(heal_frac, 0.01, 0.5), "cooldown": maxf(1.0, cooldown), "max_heals": maxi(1, max_heals), "windup": 0.5}

# NOVA #7 — hazard: zona persistente por `lifetime`s; dano enquanto o player está dentro; teto de zonas `cap`.
static func hazard(id: String, damage: int, radius: float = 120.0, lifetime: float = 5.0, cooldown: float = 8.0, cap: int = 3) -> Dictionary:
	return {"kind": "hazard", "id": id, "damage": damage, "radius": radius, "lifetime": maxf(0.5, lifetime), "cooldown": maxf(1.0, cooldown), "cap": maxi(1, cap), "windup": 0.7}

# ── Acessores ──
static func kind(a: Dictionary) -> String:
	return str(a.get("kind", ""))

static func id(a: Dictionary) -> String:
	return str(a.get("id", ""))

static func windup(a: Dictionary) -> float:
	return float(a.get("windup", 0.0))

static func cooldown(a: Dictionary) -> float:
	return float(a.get("cooldown", 0.0))

static func damage(a: Dictionary) -> int:
	return int(a.get("damage", 0))

static func is_offensive(a: Dictionary) -> bool:
	return OFFENSIVE_KINDS.has(kind(a))

static func is_valid(a: Dictionary) -> bool:
	return a.has("kind") and a.has("id") and kinds().has(kind(a))

## Habilidade OFENSIVA acerta o player a `dist` do boss? (geometria simplificada — telegrafada, sem física).
## Para cone/line/charge/projectile: dentro do alcance. Para circle/ground_aoe/hazard: dentro do raio.
static func hits_at(a: Dictionary, dist: float) -> bool:
	var k := kind(a)
	match k:
		"cone", "line", "charge", "projectile", "volley":
			return dist <= float(a.get("reach", 0.0))
		"circle", "ground_aoe", "hazard":
			return dist <= float(a.get("radius", 0.0))
		_:
			return false

## Nº de "acertos" que a habilidade resolve num disparo (volley = count; demais ofensivas = 1).
static func hit_count(a: Dictionary) -> int:
	if kind(a) == "volley":
		return int(a.get("count", 1))
	return 1
