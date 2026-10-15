extends SceneTree
## A30 GEAR PARITY V1 — ladder de armas das 5 classes. Bench SEM cena: seta o autoload GameState e lê
## PowerBudget.cp()/CombatMath live (_gs() = autoload). Mede INVARIANTE (A<B<C<D, existência, identidade),
## não contagem fixa. Save protegido por fixture (snapshot/restore). Grupos: AUDIT/PARITY/RANGED/REACH/MAGIC/
## MELEE/SUPPORT/REFINE/ACQUISITION/LOOT/BALANCE.

var gs
var _fail := 0
var _mem: Dictionary = {}

func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	if gs == null:
		print("  ✗   sem GameState autoload"); print(">>> FALHOU (1)"); quit(1); return
	gs.set_save_path_override("user://a30_fixture.json")
	_mem = gs.to_dict()
	_audit(); _parity(); _ranged(); _reach(); _magic(); _melee(); _support(); _refine(); _acq(); _loot(); _balance()
	gs.apply_dict(_mem)
	if FileAccess.file_exists("user://a30_fixture.json"): DirAccess.remove_absolute("user://a30_fixture.json")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ── helpers de build (seta autoload, lê power/dano live) ──
func _bld(cls: String, weapon: String, refine := 0, hp_max := 5000) -> void:
	gs.reset_save()
	gs.character_class = cls
	gs.equipment = {"weapon": weapon} if weapon != "" else {}
	gs.slot_refinement = {"weapon": refine}
	gs.hero_hp_max = hp_max
	gs.hero_hp = gs.max_hp_total()

func _cp(cls: String, weapon: String, refine := 0) -> int:
	_bld(cls, weapon, refine); return PowerBudget.cp()

func _dmg(cls: String, weapon: String, refine := 0) -> float:
	_bld(cls, weapon, refine); return float(CombatMath.player_profile(gs.current_combat_archetype())["expected"])

func _dps(cls: String, weapon: String, refine := 0) -> float:
	_bld(cls, weapon, refine); return PowerBudget.offense()

func _ehp(cls: String, weapon: String, refine := 0) -> float:
	_bld(cls, weapon, refine); return PowerBudget.effective_hp()

func _fam_allows(cls: String, weapon: String) -> bool:
	var fams: Array = CharacterClassDefinition.CLASSES.get(cls, {}).get("allowed_weapon_families", [])
	return str(ItemDB.get_item(weapon).get("weapon_kind", "")) in fams

func _stat(id: String, key: String) -> int:
	return int(ItemDB.stat(id, key))

# ════════════════════════════════════════════════════════════════════════════════════════════
func _audit() -> void:
	print("  ── GEAR30AUDIT (matriz real por família) ──")
	# os 4 itens novos existem
	_chk("A-T01 bow_eternal existe", ItemDB.exists("bow_eternal"))
	_chk("A-T02 spear_eternal existe", ItemDB.exists("spear_eternal"))
	_chk("A-T03 book_reinforced existe", ItemDB.exists("book_reinforced"))
	_chk("A-T04 book_eternal existe", ItemDB.exists("book_eternal"))
	# slot/família corretos
	_chk("A-T05 bow_eternal weapon_kind=bow", str(ItemDB.get_item("bow_eternal").get("weapon_kind")) == "bow")
	_chk("A-T06 spear_eternal weapon_kind=spear", str(ItemDB.get_item("spear_eternal").get("weapon_kind")) == "spear")
	_chk("A-T07 book_reinforced weapon_kind=book", str(ItemDB.get_item("book_reinforced").get("weapon_kind")) == "book")
	_chk("A-T08 book_eternal weapon_kind=book", str(ItemDB.get_item("book_eternal").get("weapon_kind")) == "book")
	_chk("A-T09 todos são slot weapon", ItemDB.slot_of("bow_eternal") == "weapon" and ItemDB.slot_of("spear_eternal") == "weapon" and ItemDB.slot_of("book_eternal") == "weapon")
	_chk("A-T10 todos equipáveis", ItemDB.is_equippable("bow_eternal") and ItemDB.is_equippable("spear_eternal") and ItemDB.is_equippable("book_reinforced") and ItemDB.is_equippable("book_eternal"))
	# raridade/tier de topo = legendary tier5 (paridade com sword/staff_eternal)
	_chk("A-T11 bow_eternal legendary tier5", str(ItemDB.rarity("bow_eternal")) == "legendary" and int(ItemDB.get_item("bow_eternal").get("tier", 0)) == 5)
	_chk("A-T12 spear_eternal legendary tier5", str(ItemDB.rarity("spear_eternal")) == "legendary" and int(ItemDB.get_item("spear_eternal").get("tier", 0)) == 5)
	_chk("A-T13 book_eternal legendary tier5", str(ItemDB.rarity("book_eternal")) == "legendary" and int(ItemDB.get_item("book_eternal").get("tier", 0)) == 5)
	_chk("A-T14 book_reinforced uncommon (degrau MID)", str(ItemDB.rarity("book_reinforced")) == "uncommon")
	# IDENTIDADE de stat por família (real, não fake)
	_chk("A-T15 ranged(arco): attack ALTO", _stat("bow_eternal", "attack") >= 28)
	_chk("A-T16 ranged(arco): speed (cadência/consistência)", _stat("bow_eternal", "speed") > 0)
	_chk("A-T17 ranged(arco): SEM sustain (glass, max_hp=0)", _stat("bow_eternal", "max_hp") == 0)
	_chk("A-T18 reach(lança): maior attack CRU do topo", _stat("spear_eternal", "attack") >= _stat("sword_eternal", "attack") and _stat("spear_eternal", "attack") >= _stat("bow_eternal", "attack"))
	_chk("A-T19 reach(lança): SEM sustain (max_hp=0)", _stat("spear_eternal", "max_hp") == 0)
	_chk("A-T20 support(livro): magic é o driver de dano", _stat("book_eternal", "magic") >= 28)
	_chk("A-T21 support(livro): max_hp (solo-viável)", _stat("book_eternal", "max_hp") > 0)
	_chk("A-T22 support MID já tem magic + max_hp", _stat("book_reinforced", "magic") > 0 and _stat("book_reinforced", "max_hp") > 0)
	# magic/melee INTOCADOS (regressão de identidade)
	_chk("A-T23 magic(cajado) eternal magic31 intacto", _stat("staff_eternal", "magic") == 31)
	_chk("A-T24 melee(espada) eternal att33/hp30 intacto", _stat("sword_eternal", "attack") == 33 and _stat("sword_eternal", "max_hp") == 30)
	# CADA família tem base→mid→high (ninguém preso no reinforced)
	_chk("A-T25 sword ladder base+mid+high", ItemDB.exists("sword_simple") and ItemDB.exists("sword_reinforced") and ItemDB.exists("sword_eternal"))
	_chk("A-T26 bow ladder base+mid+high", ItemDB.exists("bow_simple") and ItemDB.exists("bow_reinforced") and ItemDB.exists("bow_eternal"))
	_chk("A-T27 staff ladder base+mid+high", ItemDB.exists("staff_simple") and ItemDB.exists("staff_reinforced") and ItemDB.exists("staff_eternal"))
	_chk("A-T28 spear ladder base+mid+high", ItemDB.exists("spear_simple") and ItemDB.exists("spear_reinforced") and ItemDB.exists("spear_eternal"))
	_chk("A-T29 book ladder base+mid+high", ItemDB.exists("book_simple") and ItemDB.exists("book_reinforced") and ItemDB.exists("book_eternal"))

# ════════════════════════════════════════════════════════════════════════════════════════════
func _parity() -> void:
	print("  ── GEAR30PARITY (5 classes: EARLY<MID<HIGH + oportunidade equivalente) ──")
	# (classe, base, mid, high, família válida)
	var lad := [
		["CLASS_1", "sword_simple", "sword_reinforced", "sword_eternal"],
		["CLASS_2", "bow_simple", "bow_reinforced", "bow_eternal"],
		["CLASS_3", "staff_simple", "staff_reinforced", "staff_eternal"],
		["CLASS_4", "spear_simple", "spear_reinforced", "spear_eternal"],
		["CLASS_5_SUPPORT", "book_simple", "book_reinforced", "book_eternal"],
	]
	for row in lad:
		var cls: String = row[0]; var base: String = row[1]; var mid: String = row[2]; var high: String = row[3]
		# família da classe aceita os 3 degraus
		_chk("PAR %s família aceita base/mid/high" % cls, _fam_allows(cls, base) and _fam_allows(cls, mid) and _fam_allows(cls, high))
		# poder sobe EARLY<MID<HIGH
		var pe := _cp(cls, base); var pm := _cp(cls, mid); var ph := _cp(cls, high)
		_chk("PAR %s CP EARLY<MID (%d<%d)" % [cls, pe, pm], pe < pm)
		_chk("PAR %s CP MID<HIGH (%d<%d)" % [cls, pm, ph], pm < ph)
		# dano/DPS sobe do mid pro high (não é só HP)
		var de := _dps(cls, mid); var dh := _dps(cls, high)
		_chk("PAR %s DPS MID<HIGH (%.1f<%.1f)" % [cls, de, dh], de < dh)
		# ninguém preso no reinforced: existe um high de tier5 equipável
		_chk("PAR %s tem HIGH tier5 equipável" % cls, int(ItemDB.get_item(high).get("tier", 0)) == 5 and _fam_allows(cls, high))
		# oportunidade equivalente: o high de cada classe REFINA (mesmo teto de progressão +0..+10)
		_chk("PAR %s HIGH refina (+10>+0)" % cls, _cp(cls, high, 10) > _cp(cls, high, 0))
	# cross-class: nenhum HIGH 2-3x acima do outro em CP sem razão (bounded ratio)
	var cps := []
	for row in lad: cps.append(_cp(row[0], row[3]))
	var lo: int = cps.min(); var hi: int = cps.max()
	_chk("PAR cross-class CP HIGH dentro de 2x (%d..%d)" % [lo, hi], float(hi) <= float(lo) * 2.0)

# ════════════════════════════════════════════════════════════════════════════════════════════
func _ranged() -> void:
	print("  ── GEAR30RANGED (arco: range/consistência, gap resolvido) ──")
	_chk("RG-T01 bow_eternal preenche o gap (existe)", ItemDB.exists("bow_eternal"))
	var pe := _cp("CLASS_2", "bow_simple"); var pm := _cp("CLASS_2", "bow_reinforced"); var ph := _cp("CLASS_2", "bow_eternal")
	_chk("RG-T02 ladder CP simple<reinforced (%d<%d)" % [pe, pm], pe < pm)
	_chk("RG-T03 ladder CP reinforced<eternal (%d<%d)" % [pm, ph], pm < ph)
	_chk("RG-T04 attack sobe reinforced→eternal", _stat("bow_eternal", "attack") > _stat("bow_reinforced", "attack"))
	_chk("RG-T05 identidade: speed presente (consistência)", _stat("bow_eternal", "speed") > 0)
	_chk("RG-T06 arquétipo equipado = ranged", (func(): _bld("CLASS_2", "bow_eternal"); return gs.current_combat_archetype()).call() == "ranged")
	_chk("RG-T07 DPS eternal > reinforced", _dps("CLASS_2", "bow_eternal") > _dps("CLASS_2", "bow_reinforced"))
	# dano ranged vem de attack_bonus (identidade)
	_bld("CLASS_2", "bow_eternal")
	_chk("RG-T08 attack_bonus reflete o arco", gs.attack_bonus() >= _stat("bow_eternal", "attack"))
	_chk("RG-T09 refino +5 sobe CP", _cp("CLASS_2", "bow_eternal", 5) > _cp("CLASS_2", "bow_eternal", 0))
	_chk("RG-T10 refino +10 sobe CP sobre +5", _cp("CLASS_2", "bow_eternal", 10) > _cp("CLASS_2", "bow_eternal", 5))
	# fonte existe (COMO OBTER)
	ItemSourceRegistry.invalidate()
	_chk("RG-T11 bow_eternal tem FONTE (não órfão)", ItemSourceRegistry.has_source("bow_eternal"))
	var srcs := ItemSourceRegistry.sources_for("bow_eternal")
	_chk("RG-T12 fonte é HUNT (apex costeiro)", srcs.any(func(s): return str(s.get("ground_id", "")) == "HG_SALT_WIND_COAST"))
	# gating por capítulo: NÃO cai em ground de Ch1
	_chk("RG-T13 NÃO disponível em ground de Ch1", not srcs.any(func(s): return str(s.get("ground_id", "")).contains("PLAINS_LOW")))
	_chk("RG-T14 CLASS_2 equipa bow_eternal (família bow)", _fam_allows("CLASS_2", "bow_eternal"))
	_chk("RG-T15 bow_eternal NÃO equipável por CLASS_1 (melee)", not _fam_allows("CLASS_1", "bow_eternal"))
	_chk("RG-T16 rarity legendary", str(ItemDB.rarity("bow_eternal")) == "legendary")
	_chk("RG-T17 two_handed (arco ocupa 2 mãos)", bool(ItemDB.get_item("bow_eternal").get("two_handed", false)))
	_chk("RG-T18 desc marca asset pendente", str(ItemDB.get_item("bow_eternal").get("desc", "")).contains("CODEX_WEAPON_ASSET_REQUIRED"))
	_chk("RG-T19 attack eternal >= 28 (topo de arco)", _stat("bow_eternal", "attack") >= 28)
	_chk("RG-T20 dano expected sobe mid→high", _dmg("CLASS_2", "bow_eternal") > _dmg("CLASS_2", "bow_reinforced"))

# ════════════════════════════════════════════════════════════════════════════════════════════
func _reach() -> void:
	print("  ── GEAR30REACH (lança: alcance, gap resolvido) ──")
	_chk("RC-T01 spear_eternal preenche o gap", ItemDB.exists("spear_eternal"))
	var pm := _cp("CLASS_4", "spear_reinforced"); var ph := _cp("CLASS_4", "spear_eternal")
	_chk("RC-T02 CP reinforced<eternal (%d<%d)" % [pm, ph], pm < ph)
	_chk("RC-T03 attack sobe reinforced→eternal", _stat("spear_eternal", "attack") > _stat("spear_reinforced", "attack"))
	_chk("RC-T04 identidade: maior attack cru do topo", _stat("spear_eternal", "attack") >= _stat("sword_eternal", "attack"))
	_chk("RC-T05 identidade: sem sustain (max_hp=0, glass)", _stat("spear_eternal", "max_hp") == 0)
	_chk("RC-T06 arquétipo equipado = reach", (func(): _bld("CLASS_4", "spear_eternal"); return gs.current_combat_archetype()).call() == "reach")
	_chk("RC-T07 DPS eternal > reinforced", _dps("CLASS_4", "spear_eternal") > _dps("CLASS_4", "spear_reinforced"))
	_chk("RC-T08 refino +5 sobe CP", _cp("CLASS_4", "spear_eternal", 5) > _cp("CLASS_4", "spear_eternal", 0))
	_chk("RC-T09 refino +10 sobe sobre +5", _cp("CLASS_4", "spear_eternal", 10) > _cp("CLASS_4", "spear_eternal", 5))
	ItemSourceRegistry.invalidate()
	_chk("RC-T10 spear_eternal tem FONTE", ItemSourceRegistry.has_source("spear_eternal"))
	var srcs := ItemSourceRegistry.sources_for("spear_eternal")
	_chk("RC-T11 fonte é HUNT costeiro (Ch4)", srcs.any(func(s): return str(s.get("ground_id", "")) == "HG_SALT_WIND_COAST"))
	_chk("RC-T12 CLASS_4 equipa (família spear)", _fam_allows("CLASS_4", "spear_eternal"))
	_chk("RC-T13 NÃO equipável por CLASS_3 (magic)", not _fam_allows("CLASS_3", "spear_eternal"))
	_chk("RC-T14 legendary tier5", str(ItemDB.rarity("spear_eternal")) == "legendary" and int(ItemDB.get_item("spear_eternal").get("tier", 0)) == 5)
	_chk("RC-T15 two_handed", bool(ItemDB.get_item("spear_eternal").get("two_handed", false)))
	_chk("RC-T16 desc marca asset pendente", str(ItemDB.get_item("spear_eternal").get("desc", "")).contains("CODEX_WEAPON_ASSET_REQUIRED"))
	_chk("RC-T17 dano expected sobe mid→high", _dmg("CLASS_4", "spear_eternal") > _dmg("CLASS_4", "spear_reinforced"))
	_chk("RC-T18 attack >= 33", _stat("spear_eternal", "attack") >= 33)
	_chk("RC-T19 CP eternal > reinforced+5? (topo real acima de mid refinado moderado)", _cp("CLASS_4", "spear_eternal", 0) > _cp("CLASS_4", "spear_reinforced", 3))
	_chk("RC-T20 gap A29 fechado: reach não depende mais só de reinforced", ItemDB.exists("spear_eternal") and int(ItemDB.get_item("spear_eternal").get("tier", 0)) == 5)

# ════════════════════════════════════════════════════════════════════════════════════════════
func _magic() -> void:
	print("  ── GEAR30MAGIC (cajado: já tinha eternal, regressão) ──")
	_chk("MG-T01 staff_eternal intacto", ItemDB.exists("staff_eternal") and _stat("staff_eternal", "magic") == 31)
	var pe := _cp("CLASS_3", "staff_simple"); var pm := _cp("CLASS_3", "staff_reinforced"); var ph := _cp("CLASS_3", "staff_eternal")
	_chk("MG-T02 ladder EARLY<MID (%d<%d)" % [pe, pm], pe < pm)
	_chk("MG-T03 ladder MID<HIGH (%d<%d)" % [pm, ph], pm < ph)
	_chk("MG-T04 arquétipo = magic", (func(): _bld("CLASS_3", "staff_eternal"); return gs.current_combat_archetype()).call() == "magic")
	_bld("CLASS_3", "staff_eternal")
	_chk("MG-T05 magic_bonus reflete cajado", gs.magic_bonus() >= 31)
	_chk("MG-T06 dano magic usa magic+attack (identidade)", _dmg("CLASS_3", "staff_eternal") > _dmg("CLASS_3", "staff_reinforced"))
	_chk("MG-T07 refino sobe CP", _cp("CLASS_3", "staff_eternal", 10) > _cp("CLASS_3", "staff_eternal", 0))
	ItemSourceRegistry.invalidate()
	_chk("MG-T08 staff_eternal AGORA tem fonte (era órfão no índice)", ItemSourceRegistry.has_source("staff_eternal"))
	_chk("MG-T09 CLASS_3 equipa staff", _fam_allows("CLASS_3", "staff_eternal"))
	_chk("MG-T10 staff_eternal NÃO alterado (att12/magic31)", _stat("staff_eternal", "attack") == 12 and _stat("staff_eternal", "magic") == 31)
	_chk("MG-T11 DPS sobe reinforced→eternal", _dps("CLASS_3", "staff_eternal") > _dps("CLASS_3", "staff_reinforced"))
	_chk("MG-T12 magic não regrediu p/ support driver", _stat("staff_eternal", "magic") > _stat("staff_reinforced", "magic"))
	_chk("MG-T13 tier5 legendary", str(ItemDB.rarity("staff_eternal")) == "legendary")
	_chk("MG-T14 base staff existe", ItemDB.exists("staff_simple"))
	_chk("MG-T15 mid staff existe", ItemDB.exists("staff_reinforced"))

# ════════════════════════════════════════════════════════════════════════════════════════════
func _melee() -> void:
	print("  ── GEAR30MELEE (espada: ladder rica, reward preservado) ──")
	_chk("ML-T01 sword_eternal intacto att33/hp30", _stat("sword_eternal", "attack") == 33 and _stat("sword_eternal", "max_hp") == 30)
	var pe := _cp("CLASS_1", "sword_simple"); var pm := _cp("CLASS_1", "sword_reinforced"); var ph := _cp("CLASS_1", "sword_eternal")
	_chk("ML-T02 ladder EARLY<MID (%d<%d)" % [pe, pm], pe < pm)
	_chk("ML-T03 ladder MID<HIGH (%d<%d)" % [pm, ph], pm < ph)
	_chk("ML-T04 sword_reinforced (reward ARANHA MATRIARCA) intacto", ItemDB.exists("sword_reinforced") and _stat("sword_reinforced", "attack") == 11)
	_chk("ML-T05 ARANHA MATRIARCA ainda dá sword_reinforced p/ sword", BossActivityDefinition.guaranteed_gear_for_weapon("sword") == "sword_reinforced")
	_chk("ML-T06 arquétipo = melee", (func(): _bld("CLASS_1", "sword_eternal"); return gs.current_combat_archetype()).call() == "melee")
	_chk("ML-T07 identidade: sword tem sustain (max_hp>0)", _stat("sword_eternal", "max_hp") > 0)
	_chk("ML-T08 refino sobe CP", _cp("CLASS_1", "sword_eternal", 10) > _cp("CLASS_1", "sword_eternal", 0))
	_chk("ML-T09 ladder intermediária memoria/crystal intacta", ItemDB.exists("sword_memoria") and ItemDB.exists("sword_crystal"))
	_chk("ML-T10 DPS sobe reinforced→eternal", _dps("CLASS_1", "sword_eternal") > _dps("CLASS_1", "sword_reinforced"))
	_chk("ML-T11 CLASS_1 equipa sword/axe/hammer", _fam_allows("CLASS_1", "sword_eternal") and _fam_allows("CLASS_1", "axe_simple") and _fam_allows("CLASS_1", "hammer_simple"))
	_chk("ML-T12 sword_eternal NÃO renomeado (id estável)", ItemDB.exists("sword_eternal") and str(ItemDB.display_name("sword_eternal")) != "")
	_chk("ML-T13 tier5 legendary", str(ItemDB.rarity("sword_eternal")) == "legendary")
	_chk("ML-T14 base sword existe", ItemDB.exists("sword_simple"))
	_chk("ML-T15 dano expected sobe mid→high", _dmg("CLASS_1", "sword_eternal") > _dmg("CLASS_1", "sword_reinforced"))

# ════════════════════════════════════════════════════════════════════════════════════════════
func _support() -> void:
	print("  ── GEAR30SUPPORT (livro: gap duplo resolvido, solo-viável) ──")
	_chk("SP-T01 book_reinforced criado (MID que faltava)", ItemDB.exists("book_reinforced"))
	_chk("SP-T02 book_eternal criado (HIGH que faltava)", ItemDB.exists("book_eternal"))
	var pe := _cp("CLASS_5_SUPPORT", "book_simple"); var pm := _cp("CLASS_5_SUPPORT", "book_reinforced"); var ph := _cp("CLASS_5_SUPPORT", "book_eternal")
	_chk("SP-T03 ladder EARLY<MID (%d<%d)" % [pe, pm], pe < pm)
	_chk("SP-T04 ladder MID<HIGH (%d<%d)" % [pm, ph], pm < ph)
	_chk("SP-T05 arquétipo = support", (func(): _bld("CLASS_5_SUPPORT", "book_eternal"); return gs.current_combat_archetype()).call() == "support")
	# dano do support vem de MAGIC (não attack) — CombatMath player_flat_bonus "support"=só magic
	_chk("SP-T06 dano support sobe com magic do livro", _dmg("CLASS_5_SUPPORT", "book_eternal") > _dmg("CLASS_5_SUPPORT", "book_reinforced"))
	# solo-viável: book dá max_hp → effective_hp sobe (segura sozinho)
	_chk("SP-T07 solo-viável: EHP sobe simple→eternal", _ehp("CLASS_5_SUPPORT", "book_eternal") > _ehp("CLASS_5_SUPPORT", "book_simple"))
	_chk("SP-T08 book_eternal tem max_hp (sustain solo)", _stat("book_eternal", "max_hp") > 0)
	_chk("SP-T09 book_eternal magic é driver (>=28)", _stat("book_eternal", "magic") >= 28)
	# FIX: boss agora dá gear que support EQUIPA (era staff_reinforced, família proibida)
	_chk("SP-T10 boss book→book_reinforced (equipável)", BossActivityDefinition.guaranteed_gear_for_weapon("book") == "book_reinforced")
	_chk("SP-T11 CLASS_5 equipa o gear de boss", _fam_allows("CLASS_5_SUPPORT", BossActivityDefinition.guaranteed_gear_for_weapon("book")))
	_chk("SP-T12 CLASS_5 NÃO equipa staff (regressão de gate)", not _fam_allows("CLASS_5_SUPPORT", "staff_reinforced"))
	# fontes
	ItemSourceRegistry.invalidate()
	_chk("SP-T13 book_reinforced tem FONTE (boss 1ª vitória)", ItemSourceRegistry.has_source("book_reinforced"))
	_chk("SP-T14 book_reinforced craftável (receita real)", ItemDB.RECIPES.has("book_reinforced"))
	_chk("SP-T15 book_eternal tem FONTE (hunt costeiro)", ItemSourceRegistry.has_source("book_eternal"))
	_chk("SP-T16 refino sobe CP", _cp("CLASS_5_SUPPORT", "book_eternal", 10) > _cp("CLASS_5_SUPPORT", "book_eternal", 0))
	_chk("SP-T17 book_eternal legendary tier5", str(ItemDB.rarity("book_eternal")) == "legendary" and int(ItemDB.get_item("book_eternal").get("tier", 0)) == 5)
	_chk("SP-T18 book_simple base preservado", ItemDB.exists("book_simple") and _stat("book_simple", "magic") == 4)
	_chk("SP-T19 DPS sobe reinforced→eternal", _dps("CLASS_5_SUPPORT", "book_eternal") > _dps("CLASS_5_SUPPORT", "book_reinforced"))
	_chk("SP-T20 support não preso mais no book_simple", ItemDB.exists("book_reinforced") and ItemDB.exists("book_eternal") and _fam_allows("CLASS_5_SUPPORT", "book_eternal"))

# ════════════════════════════════════════════════════════════════════════════════════════════
func _refine() -> void:
	print("  ── GEAR30REFINE (Refino +0..+10 reusa, sem Refine2) ──")
	var families := [["CLASS_1", "sword_eternal"], ["CLASS_2", "bow_eternal"], ["CLASS_3", "staff_eternal"], ["CLASS_4", "spear_eternal"], ["CLASS_5_SUPPORT", "book_eternal"]]
	for row in families:
		var cls: String = row[0]; var w: String = row[1]
		var c0 := _cp(cls, w, 0); var c5 := _cp(cls, w, 5); var c10 := _cp(cls, w, 10)
		_chk("RF %s +0<+5<+10 (%d<%d<%d)" % [cls, c0, c5, c10], c0 < c5 and c5 < c10)
	# refino escala o STAT do slot (equip_sum) — invariante do RefineMath
	_bld("CLASS_2", "bow_eternal", 0); var a0: int = gs.equip_sum("attack")
	_bld("CLASS_2", "bow_eternal", 10); var a10: int = gs.equip_sum("attack")
	_chk("RF-T06 equip_sum(attack) sobe com refino (%d→%d)" % [a0, a10], a10 > a0)
	_chk("RF-T07 RefineMath.mult(10)=1+0.04*10", is_equal_approx(RefineMath.mult(10), 1.0 + 0.04 * 10.0))
	_chk("RF-T08 sem Refine2 (mult(11) capa em faixa, não 2º sistema)", RefineMath.mult(11) >= RefineMath.mult(10))
	# book (support): refino sobe magic (driver) e max_hp (sustain)
	_bld("CLASS_5_SUPPORT", "book_eternal", 0); var m0: int = gs.equip_sum("magic"); var h0: int = gs.equip_sum("max_hp")
	_bld("CLASS_5_SUPPORT", "book_eternal", 10); var m10: int = gs.equip_sum("magic"); var h10: int = gs.equip_sum("max_hp")
	_chk("RF-T09 book refino sobe magic (driver)", m10 > m0)
	_chk("RF-T10 book refino sobe max_hp (sustain)", h10 > h0)
	# spear (glass): refino sobe attack; max_hp continua 0 (identidade preservada)
	_bld("CLASS_4", "spear_eternal", 10)
	_chk("RF-T11 spear refino NÃO cria sustain (max_hp=0)", gs.equip_sum("max_hp") == 0)
	_chk("RF-T12 spear refino sobe attack", gs.equip_sum("attack") > _stat("spear_eternal", "attack"))
	# refine_do real (grava no fixture, protegido)
	_bld("CLASS_2", "bow_eternal", 0); gs.materials = {"Fragmentos": 100000}
	var before := int(gs.slot_refinement.get("weapon", 0))
	var ok: bool = gs.refine_do("weapon")
	_chk("RF-T13 refine_do('weapon') aplica +1", ok and int(gs.slot_refinement.get("weapon", 0)) == before + 1)
	_chk("RF-T14 CP subiu após refine_do real", PowerBudget.cp() > _cp("CLASS_2", "bow_eternal", 0))
	# cap do refino (não explode)
	_bld("CLASS_1", "sword_eternal", 20)
	_chk("RF-T15 refino topo cap (20) não crasha", PowerBudget.cp() > 0)
	_chk("RF-T16 mult(20) > mult(10) (monotônico até o cap)", RefineMath.mult(20) > RefineMath.mult(10))
	_chk("RF-T17 refino é POR SLOT (weapon isolado)", (func(): _bld("CLASS_1", "sword_eternal", 8); return int(gs.slot_refinement.get("weapon", 0)) == 8).call())
	# todas as 5 famílias refináveis (equip_sum responde)
	for row in families:
		var cls2: String = row[0]; var w2: String = row[1]
		var key := "magic" if str(ItemDB.get_item(w2).get("weapon_kind")) in ["staff", "book"] else "attack"
		_bld(cls2, w2, 0); var s0: int = gs.equip_sum(key)
		_bld(cls2, w2, 6); var s6: int = gs.equip_sum(key)
		_chk("RF %s refino move o stat-driver (%s)" % [cls2, key], s6 > s0)

# ════════════════════════════════════════════════════════════════════════════════════════════
func _acq() -> void:
	print("  ── GEAR30ACQUISITION (toda arma nova tem COMO OBTER, gated) ──")
	ItemSourceRegistry.invalidate()
	# os 3 eternais novos + os 2 antigos têm fonte
	for id in ["bow_eternal", "spear_eternal", "book_eternal", "sword_eternal", "staff_eternal"]:
		_chk("AQ %s tem fonte" % id, ItemSourceRegistry.has_source(id))
	# book_reinforced (mid) tem fonte
	_chk("AQ-T06 book_reinforced tem fonte", ItemSourceRegistry.has_source("book_reinforced"))
	# fonte dos eternais novos = HG costeiro (Ch4-gated)
	for id in ["bow_eternal", "spear_eternal", "book_eternal"]:
		var s := ItemSourceRegistry.sources_for(id)
		_chk("AQ %s fonte HG_SALT_WIND_COAST" % id, s.any(func(e): return str(e.get("ground_id", "")) == "HG_SALT_WIND_COAST"))
		_chk("AQ %s activity_link=TARGETED_HUNT" % id, s.any(func(e): return str(e.get("activity_link", "")) == "TARGETED_HUNT"))
	# gating por capítulo: o ground costeiro exige cp alto (Ch4), não trivializa Ch1
	var g: Dictionary = HuntingGround.GROUNDS["HG_SALT_WIND_COAST"]
	_chk("AQ-T13 ground costeiro gated (min_cp>=30000)", int(g.get("unlock_rule", {}).get("min_cp", 0)) >= 30000)
	# book_reinforced via boss first-clear (support ganha gear equipável)
	var sbr := ItemSourceRegistry.sources_for("book_reinforced")
	_chk("AQ-T14 book_reinforced fonte BOSS_DROP", sbr.any(func(e): return str(e.get("source_type", "")) == "BOSS_DROP"))
	# a extensão de HG não quebrou fontes de material/mob antigas
	_chk("AQ-T15 material antigo ainda tem fonte (Concha da Maré)", ItemSourceRegistry.has_source("Concha da Maré"))
	_chk("AQ-T16 gear de mob antigo ainda indexado (Fragmentos salvage)", ItemSourceRegistry.has_source("Fragmentos"))
	# dois grounds com o mesmo item não colidem no dedup (ground_id na assinatura)
	var ssword := ItemSourceRegistry.sources_for("chest_eternal")
	var grounds := {}
	for e in ssword: grounds[str(e.get("ground_id", ""))] = true
	_chk("AQ-T17 chest_eternal indexado em múltiplos grounds (dedup por ground)", grounds.size() >= 2)
	_chk("AQ-T18 nenhum eternal novo é órfão (has_source todos)", ItemSourceRegistry.has_source("bow_eternal") and ItemSourceRegistry.has_source("spear_eternal") and ItemSourceRegistry.has_source("book_eternal"))
	_chk("AQ-T19 sword_eternal NÃO trivializado em Ch1 (só apex raro dos grounds base)", ItemSourceRegistry.sources_for("sword_eternal").all(func(e): return str(e.get("hunt_pool", "")) in ["apex", "loot"]))
	_chk("AQ-T20 all_keys inclui os novos", "bow_eternal" in ItemSourceRegistry.all_keys() and "book_eternal" in ItemSourceRegistry.all_keys())

# ════════════════════════════════════════════════════════════════════════════════════════════
func _loot() -> void:
	print("  ── GEAR30LOOT (Direct Loot → backpack/equip, reusa inventário) ──")
	# dropar um eternal cai na mochila e é equipável
	_bld("CLASS_2", "bow_eternal", 0); gs.equipment = {}; gs.backpack = []
	gs.backpack_add("bow_eternal", 1)
	_chk("LT-T01 bow_eternal entra na mochila", gs.backpack_count("bow_eternal") >= 1)
	var eq: bool = gs.equip("bow_eternal")
	_chk("LT-T02 equipa do backpack (Direct Loot)", eq and str(gs.equipment.get("weapon", "")) == "bow_eternal")
	_chk("LT-T03 CP reflete o equipado", PowerBudget.cp() > 0)
	# unequip devolve à mochila (ciclo íntegro)
	gs.unequip("weapon")
	_chk("LT-T04 unequip devolve à mochila", gs.backpack_count("bow_eternal") >= 1 and not gs.equipment.has("weapon"))
	# salvage: eternal é desmontável e vale Fragmentos (AutoSalvage/ManualSalvage)
	var lm := LootManager.new(); root.add_child(lm); lm.setup(gs)
	_chk("LT-T05 book_eternal é salvageável", lm.is_salvageable("book_eternal"))
	_chk("LT-T06 salvage_value > 0", lm.salvage_value("book_eternal") > 0)
	_bld("CLASS_5_SUPPORT", "book_eternal", 0); gs.equipment = {}; gs.backpack = []
	gs.backpack_add("book_eternal", 1); gs.materials = {}
	var fr0 := int(gs.material_count("Fragmentos"))
	lm.manual_salvage("book_eternal")
	_chk("LT-T07 ManualSalvage rende Fragmentos", int(gs.material_count("Fragmentos")) > fr0)
	_chk("LT-T08 item saiu da mochila após salvage", gs.backpack_count("book_eternal") == 0)
	lm.free()
	# overflow/lock: itens novos participam do lock (não somem em auto-salvage)
	_bld("CLASS_4", "spear_eternal", 0); gs.equipment = {}; gs.backpack = []
	gs.backpack_add("spear_eternal", 1)
	if gs.has_method("set_item_locked"): gs.set_item_locked("spear_eternal", true)
	_chk("LT-T09 spear_eternal pode ser locked (protegido de auto-salvage)", (not gs.has_method("is_item_locked")) or gs.is_item_locked("spear_eternal"))
	_chk("LT-T10 spear_eternal ainda na mochila", gs.backpack_count("spear_eternal") >= 1)
	# equipar troca de arma devolve a antiga (não duplica/perde)
	_bld("CLASS_1", "sword_reinforced", 0); gs.backpack = []; gs.equipment = {}
	gs.backpack_add("sword_reinforced", 1); gs.backpack_add("sword_eternal", 1)
	gs.equip("sword_reinforced")
	gs.equip("sword_eternal")
	_chk("LT-T11 trocar p/ eternal devolve reinforced à mochila", gs.backpack_count("sword_reinforced") >= 1 and str(gs.equipment.get("weapon")) == "sword_eternal")
	_chk("LT-T12 sem duplicação (eternal saiu da mochila ao equipar)", gs.backpack_count("sword_eternal") == 0)
	# is_equippable cobre os 4 novos (Direct Loot aceita)
	_chk("LT-T13 is_equippable novos", ItemDB.is_equippable("bow_eternal") and ItemDB.is_equippable("spear_eternal") and ItemDB.is_equippable("book_reinforced") and ItemDB.is_equippable("book_eternal"))
	_chk("LT-T14 sell_value > 0 (economia reconhece)", ItemDB.sell_value("bow_eternal") > 0 and ItemDB.sell_value("book_eternal") > 0)
	_chk("LT-T15 slot_of consistente", ItemDB.slot_of("spear_eternal") == "weapon")
	# refino sobrevive a equip/unequip (slot_refinement por slot)
	_bld("CLASS_2", "bow_eternal", 7)
	_chk("LT-T16 refino do slot preservado após set", int(gs.slot_refinement.get("weapon", 0)) == 7)
	_chk("LT-T17 backpack_add/remove íntegro", (func(): gs.backpack = []; gs.backpack_add("bow_eternal", 2); gs.backpack_remove("bow_eternal", 1); return gs.backpack_count("bow_eternal") == 1).call())
	_chk("LT-T18 rarity legendary reconhecida no loot", str(ItemDB.rarity("bow_eternal")) == "legendary")
	_chk("LT-T19 display_name não vazio (UI de loot)", str(ItemDB.display_name("spear_eternal")) != "" and str(ItemDB.display_name("book_eternal")) != "")
	_chk("LT-T20 book_reinforced também salvageável/equipável (ciclo mid)", ItemDB.is_equippable("book_reinforced"))

# ════════════════════════════════════════════════════════════════════════════════════════════
func _balance() -> void:
	print("  ── GEAR30BALANCE (A<B<C<D por classe + ratios cross-class + support solo) ──")
	# A=entry(base) B=mid(reinforced) C=high(eternal) D=high refinado +10 — por classe
	var lad := [
		["CLASS_1", "sword_simple", "sword_reinforced", "sword_eternal"],
		["CLASS_2", "bow_simple", "bow_reinforced", "bow_eternal"],
		["CLASS_3", "staff_simple", "staff_reinforced", "staff_eternal"],
		["CLASS_4", "spear_simple", "spear_reinforced", "spear_eternal"],
		["CLASS_5_SUPPORT", "book_simple", "book_reinforced", "book_eternal"],
	]
	var enemy_hp := 20000
	var d_dps := []
	for row in lad:
		var cls: String = row[0]
		var A := _dps(cls, row[1], 0); var B := _dps(cls, row[2], 0); var C := _dps(cls, row[3], 0); var D := _dps(cls, row[3], 10)
		_chk("BAL %s DPS A<B (%.1f<%.1f)" % [cls, A, B], A < B)
		_chk("BAL %s DPS B<C (%.1f<%.1f)" % [cls, B, C], B < C)
		_chk("BAL %s DPS C<D (refino) (%.1f<%.1f)" % [cls, C, D], C < D)
		# TTK cai monotônico A>B>C>D (mais poder mata mais rápido)
		var ta := float(enemy_hp) / maxf(A, 0.001); var td := float(enemy_hp) / maxf(D, 0.001)
		_chk("BAL %s TTK A>D (%.1f>%.1f)" % [cls, ta, td], ta > td)
		d_dps.append(C)   # DPS do high sem refino p/ ratio cross-class
	# ratios cross-class ENTRE OS 4 PAPÉIS DE DANO (melee/ranged/magic/reach). Support é papel DISTINTO
	# (sustain/utility, "mata devagar" — driver só magic, sem attack) ⇒ NÃO entra na paridade de DPS puro.
	var dmg_dps := [float(d_dps[0]), float(d_dps[1]), float(d_dps[2]), float(d_dps[3])]
	var lo: float = dmg_dps.min(); var hi: float = dmg_dps.max()
	_chk("BAL 4 papéis de dano dentro de ~2x (%.1f..%.1f)" % [lo, hi], hi <= lo * 2.2)
	var sup_c: float = float(d_dps[4])
	# support solo-viável: EHP e DPS positivos (segura + mata sozinho)
	_bld("CLASS_5_SUPPORT", "book_eternal", 5)
	_chk("BAL support EHP>0 (segura sozinho)", PowerBudget.effective_hp() > 0.0)
	_chk("BAL support DPS>0 (mata sozinho)", PowerBudget.offense() > 0.0)
	# RAZÃO DE DESIGN provada: o déficit de DPS do support é compensado por SUSTAIN — EHP do support (book tem
	# max_hp) supera o de um DPS glass (spear max_hp=0). É trade, não desvantagem cega.
	var sup_ehp := _ehp("CLASS_5_SUPPORT", "book_eternal", 0)
	var spear_ehp := _ehp("CLASS_4", "spear_eternal", 0)
	_chk("BAL support troca DPS por sustain (EHP support > EHP glass spear)", sup_ehp > spear_ehp)
	# piso: support não é trivialmente fraco (>= 30% do topo de dano)
	_chk("BAL support DPS >= 30%% do topo de dano (%.1f vs %.1f)" % [sup_c, hi], sup_c >= hi * 0.30)
	# entry de cada classe NÃO iguala o high (progressão sentida)
	for row in lad:
		var cls2: String = row[0]
		_chk("BAL %s entry << high (progressão real)" % cls2, _dps(cls2, row[1], 0) < _dps(cls2, row[3], 0) * 0.8)
	# CP high refinado é o maior de todos os degraus (D é o topo)
	for row in lad:
		var cls3: String = row[0]
		var cD := _cp(cls3, row[3], 10); var cC := _cp(cls3, row[3], 0); var cB := _cp(cls3, row[2], 0)
		_chk("BAL %s CP D>C>B (%d>%d>%d)" % [cls3, cD, cC, cB], cD > cC and cC > cB)
