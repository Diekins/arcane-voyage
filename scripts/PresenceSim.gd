class_name PresenceSim
## FATIA A10 — SIMULADOR (puro) Auto × Presença. Responde "onde a HABILIDADE faz diferença, SEM buff?". ★ MODELO
## DECLARADO (não é replay de skill humano, §47): política determinística de desvio como PROXY. A tese honesta: o
## DANO CAUSADO é IGUAL (CombatMath intocado ⇒ mesmo TTK Auto/manual); a única diferença é o DANO RECEBIDO — o
## dano ofensivo do boss é TODO telegrafado e evitável (por dodge/i-frames em TODOS os casos; por posição/forma
## em Wolf/Golem+mobs; por distância/kite nos 8 do BossController), então quem desvia mais SOBREVIVE a um R menor
## e vence antes. NENHUM multiplier de dano/reward manual (§3/§43/§44).
##
## Modelo normalizado por R = CP_do_jogador / CP_recomendado (fonte: ProgressionMath). Poder do jogador escala
## com R (dano ∝ R, HP-efetivo ∝ R); o boss é fixo. Calibrado p/ o Auto clarear ~no limiar 0.95 (= AUTO_EXIT_RATIO
## do muro). `avoid` = fração do dano telegrafado que a POLÍTICA evita mantendo uptime.

const TTK0 := 20.0    # tempo-p/-matar de referência a R=1 (s) — calibra Auto marginal em 0.95
const TTD0 := 20.0    # tempo-p/-morrer de referência a R=1, avoid=0 (s)

## Frações de desvio POR POLÍTICA (proxies declarados). Auto tem algum desvio incidental; manual competente desvia
## a maioria dos telegraphs mantendo ataque; ideal = teto de teste (não é "player real", §47).
const AVOID := {"auto": 0.10, "competent": 0.55, "ideal": 0.85}

## Resolve um encontro a um dado R e política. Retorna {ttk, ttd, win, margin_s, dmg_taken_frac}.
static func encounter(r: float, avoid: float) -> Dictionary:
	r = maxf(0.01, r)
	var ttk := TTK0 / r
	var ttd := TTD0 * r / maxf(0.01, 1.0 - avoid)   # menos dano recebido → morre mais devagar
	var win := ttk < ttd
	return {
		"ttk": ttk, "ttd": ttd, "win": win,
		"margin_s": ttd - ttk,
		"dmg_taken_frac": clampf(ttk / ttd, 0.0, 1.0),   # fração do HP-efetivo consumida até o kill
	}

static func avoid_of(policy: String) -> float:
	return float(AVOID.get(policy, 0.0))

## O R mínimo em que a política ainda VENCE (win enquanto ttk<ttd → TTK0/R < TTD0·R/(1-avoid) → R > √((TTK0(1-avoid))/TTD0)).
static func win_floor(policy: String) -> float:
	var av := avoid_of(policy)
	return sqrt((TTK0 * (1.0 - av)) / TTD0)

## Banda de decisão (§21/§22/§48): até onde o Auto clareia; até onde o manual competente ainda vence; abaixo = extremo.
static func band() -> Dictionary:
	return {
		"auto_clear_floor": win_floor("auto"),        # ~0.95: Auto clareia acima disto
		"skill_floor": win_floor("competent"),        # ~0.67: manual competente vence acima disto
		"extreme_below": win_floor("competent"),       # abaixo: DESAFIO EXTREMO (nem skill resolve) → não recomendar
	}

## Tabela por ratio × política (para o relatório). ratios padrão: 1.00..0.80.
static func ratios_table(ratios: Array = [1.0, 0.95, 0.90, 0.85, 0.80]) -> Array:
	var out: Array = []
	for r in ratios:
		var row := {"R": r}
		for p in ["auto", "competent", "ideal"]:
			row[p] = encounter(float(r), avoid_of(p))
		# a HABILIDADE decide aqui? (Auto perde, competente vence) — a "banda de skill"
		row["skill_matters"] = (not row["auto"]["win"]) and bool(row["competent"]["win"])
		out.append(row)
	return out

## Sessão de ~30 min (1800 s): quantas fases uma política avança dado o gargalo do MURO. Auto trava no muro (R<0.95);
## manual competente pode CLAREAR a fase-muro e avançar ~1 capítulo antes — a vantagem nasce de vencer o que o Auto
## não vence, NÃO de reward maior por kill (per-kill é idêntico). Modelo declarado.
static func session_30min(policy: String, wall_r: float = 0.90) -> Dictionary:
	var seconds := 1800.0
	var avoid := avoid_of(policy)
	# fase de farm até o muro: kills a R~1.05 (dominado), rápido; ~stage a cada TTK0/1.05 + overhead
	var stage_t := (TTK0 / 1.05) + 6.0
	var pre_wall_stages := 12                       # atravessa ~12 fases até o gargalo (comum ao Auto e manual)
	var t := float(pre_wall_stages) * stage_t
	var deaths := 0
	var advanced := pre_wall_stages
	# no muro (R=wall_r): Auto NÃO clareia (farma, 0 avanço); manual competente pode clarear e seguir.
	# per-kill reward é IDÊNTICO; só o AVANÇO muda (nasce de vencer o que o Auto não vence).
	var wall_win: bool = bool(encounter(wall_r, avoid)["win"])
	while t < seconds:
		if wall_win:
			t += (TTK0 / wall_r) + 6.0
			advanced += 1
		else:
			# Auto: tentativa falha custa recover (~morte) e volta ao farm; sem avanço
			t += stage_t
			deaths += 1
			if deaths > 40: break
	return {"policy": policy, "stages_advanced": advanced, "deaths": deaths, "cleared_wall": wall_win}
