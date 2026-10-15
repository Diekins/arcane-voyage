class_name HuntMob extends Node
## FATIA A16.1 — mob REAL de runtime da Hunt (node vivo, HP real, morte real). Pertence a UM spot/session (§19/§59):
## outro spot NÃO targeta/atinge/recompensa. Leve (sem sprite pesado — arte final = Codex), mas é um Node de verdade
## no tree com take_damage/died — não um dicionário de teste.

signal died(mob: Node)

var mob_id := ""
## ★★★ GROUP MIGRATION STAGE 3 (05/09/2026) — IDENTIDADE POR INSTÂNCIA.
## `mob_id` é a DEFINIÇÃO (ex.: "young_wolf"), não o indivíduo. Com grupo, três lobos vivos têm o
## MESMO `mob_id` — sem isto é impossível dizer QUAL morreu, QUAL foi atingido e QUAL já creditou.
## É a base do ledger de crédito (Stage 5) e do roteamento de feedback (Stage 4/15).
## 0 = ainda não registrado num grupo (mob avulso/legado — comportamento antigo preservado).
var instance_id := 0
var hp := 30
var max_hp := 30
var owner_spot := ""          # spot dono (§59) — encounter ownership
var owner_session := ""       # character/session dono
var is_elite := false
var is_apex := false
var _dead := false
# A17.10B §14/§15 — AMEAÇA: o mob ATACA de verdade (cadência data-driven; dano rolado via CombatMath, não formula nova).
var atk_min := 0
var atk_max := 0
var attack_interval := 1.5
var _atk_t := 0.0

func setup(p_mob_id: String, p_hp: int, p_spot: String, p_session: String) -> void:
	mob_id = p_mob_id; hp = maxi(1, p_hp); max_hp = hp; owner_spot = p_spot; owner_session = p_session

## Define o perfil de ataque (dano min/max + intervalo). Vem do difficulty_profile da ground (§15).
func set_attack(p_min: int, p_max: int, p_interval: float) -> void:
	atk_min = maxi(0, p_min); atk_max = maxi(atk_min, p_max); attack_interval = maxf(0.2, p_interval)
	_atk_t = attack_interval   # PRONTO ao engajar: o mob golpeia na 1ª ação viva (senão heróis fortes o matam antes)

## Avança a cadência; quando a janela fecha, devolve o dano ROLADO (0 fora da janela / morto / sem perfil).
## Reusa CombatMath.enemy_roll (§16) — nenhuma HuntDamageFormula2.
func attack_tick(delta: float) -> int:
	if _dead or not alive() or atk_max <= 0:
		return 0
	_atk_t += delta
	if _atk_t < attack_interval:
		return 0
	_atk_t = 0.0
	return CombatMath.enemy_roll(atk_min, atk_max)

func take_damage(amount: int, from_session: String = "") -> bool:
	if _dead: return false
	# §19 — só o dono do encounter causa dano válido (evita kill-steal/cross-spot)
	if from_session != "" and from_session != owner_session:
		return false
	hp = maxi(0, hp - maxi(0, amount))
	if hp <= 0 and not _dead:
		_dead = true
		died.emit(self)
		return true
	return false

func alive() -> bool: return not _dead and hp > 0
