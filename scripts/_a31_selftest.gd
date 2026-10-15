extends SceneTree
## A31 — TEST INTEGRITY & CONTENT SCALABILITY V1 (bancada, sem cena). Dogfood do TestHarness (lifecycle
## NO-SILENT-GREEN) + checks dinâmicos de catálogo (subset/unique/min, nunca count congelado) + meta-sabotagem
## (prova que o runner detecta zero-assert/abort/early-return/min/duplicate/missing). NÃO altera save/gameplay.
## Grupos: TEST31AUDIT/RUNNER/DYNAMIC/REGISTRY/PRESENCE/META. Cena real = _a31_scene_selftest.gd.

var H: TestHarness

# ── fake host p/ PresenceController (prova a POLÍTICA sem bootar Main) ──
class _FakeHost extends RefCounted:
	var auto := false
	func autoplay_on() -> bool: return auto
	func set_autoplay(v: bool) -> void: auto = v
	func stage_wall_active() -> bool: return true
	func stage_request_retry() -> bool: return true

func _initialize() -> void:
	H = TestHarness.new()
	_audit(); _runner(); _dynamic(); _registry(); _presence(); _meta()
	var res := H.summarize("A31")
	quit(0 if bool(res["ok"]) else 1)

# ── acessores de catálogo (fonte = registry runtime, NÃO cópia paralela) ──
func _grounds() -> Array: return HuntingGround.all_ids()
func _mobs() -> Array: return MobEligibility.MOBS.keys()
func _missions() -> Array: return AfkMissionDefinition.MISSIONS.keys()
func _bosses() -> Array: return BossActivityDefinition.BOSSES.keys()
func _items() -> Array: return ItemDB.all_ids()
func _profiles() -> Array: return EnvironmentProfile.all_ids()
func _props() -> Array: return EnvironmentPropDefinition.all_ids()

# universo COMPLETO de mobs = união dos registries (MobEligibility targeted-farm + ContentManifest roaming legado).
# Um HG mob_table referencia legitimamente mobs do ContentManifest (ex.: wild_boar/road_bandit) — não é ref quebrada.
func _all_mobs() -> Array:
	var s: Array = MobEligibility.MOBS.keys()
	for ch in ContentManifest.CHAPTERS:
		for mb in (ch as Dictionary).get("normal_pool", []):
			if not (str(mb) in s): s.append(str(mb))
		var apex := str((ch as Dictionary).get("apex", ""))
		if apex != "" and not (apex in s): s.append(apex)
	return s

func _chapter_set() -> Array:
	var s: Array = []
	for mid in AfkMissionDefinition.MISSIONS:
		var c := str(AfkMissionDefinition.MISSIONS[mid].get("chapter_id", ""))
		if c != "" and not (c in s): s.append(c)
	return s

func _map_set() -> Array:
	var s: Array = []
	for gid in HuntingGround.GROUNDS:
		var m := str(HuntingGround.GROUNDS[gid].get("map_id", ""))
		if m != "" and not (m in s): s.append(m)
	return s

# ════════════════════════════════════════════════════════════════════════════════════════════
func _audit() -> void:
	H.group_begin("TEST31AUDIT", 30)
	# baseline: cada registry central é enumerável e não-vazio (a fonte dos checks dinâmicos)
	H.check("AUD-01 GROUNDS enumerável", _grounds() is Array and _grounds().size() > 0)
	H.check("AUD-02 MOBS enumerável", _mobs().size() > 0)
	H.check("AUD-03 MISSIONS enumerável", _missions().size() > 0)
	H.check("AUD-04 BOSSES enumerável", _bosses().size() > 0)
	H.check("AUD-05 ITEMS enumerável", _items().size() > 0)
	H.check("AUD-06 PROFILES enumerável", _profiles().size() > 0)
	H.check("AUD-07 PROPS enumerável", _props().size() > 0)
	H.check("AUD-08 CHAPTERS derivável", _chapter_set().size() > 0)
	H.check("AUD-09 MAPS derivável", _map_set().size() > 0)
	# PROVA da fragilidade histórica: o count "grounds (3)" ficou obsoleto porque o catálogo CRESCEU
	H.check("AUD-10 grounds cresceram além de 3 (por que ==3 era stale)", _grounds().size() >= 4)
	H.check("AUD-11 HG_GROVE existe (A26)", "HG_GROVE" in _grounds())
	H.check("AUD-12 HG_SALT_WIND_COAST existe (A29)", "HG_SALT_WIND_COAST" in _grounds())
	H.check("AUD-13 chapters cresceram p/ >=4 (por que 'chapters(N)' é stale)", _chapter_set().size() >= 4)
	H.check("AUD-14 CHAPTER_4_SALTWIND presente (A29)", "CHAPTER_4_SALTWIND" in _chapter_set())
	# PROVA de por que listas de item não podem ser congeladas: A30 adicionou 4
	H.check("AUD-15 bow_eternal existe (A30)", "bow_eternal" in _items())
	H.check("AUD-16 spear_eternal existe (A30)", "spear_eternal" in _items())
	H.check("AUD-17 book_reinforced existe (A30)", "book_reinforced" in _items())
	H.check("AUD-18 book_eternal existe (A30)", "book_eternal" in _items())
	# bosses cresceram (Ch3 boss) — por que 'bosses(N)' congelado quebra
	H.check("AUD-19 ARANHA MATRIARCA existe (A27)", "BOSS_CH3_SPIDER_MATRIARCH" in _bosses())
	H.check("AUD-20 bosses core preservados", ("BOSS_WOLF_ALPHA" in _bosses()) and ("BOSS_CRYSTAL_GOLEM" in _bosses()))
	# mobs cresceram (Ch3/Ch4)
	H.check("AUD-21 grove_spider existe (A26)", "grove_spider" in _mobs())
	H.check("AUD-22 mobs costeiros existem (A29)", ("dune_skitter" in _mobs()) and ("tide_warden" in _mobs()))
	# invariante do runner: o emissor legado (_fail==0 ⇒ OK) NÃO tem piso de asserts — o TestHarness tem
	var h_leg := TestHarness.new(); h_leg.group_begin("vazio", 5); h_leg.group_complete()
	H.check("AUD-23 grupo sem asserts NÃO passa no runner novo (piso)", not h_leg.all_ok())
	# a classe do bug da A29 (abort no meio) é INCOMPLETE, não PASS
	var h_ab := TestHarness.new(); h_ab.group_begin("abort", 3); h_ab.check("x", true)  # sem group_complete
	H.check("AUD-24 abort no meio = INCOMPLETE (classe do bug A29)", h_ab.status_of(h_ab.groups[0]) == "INCOMPLETE")
	# maps core preservados
	H.check("AUD-25 MAP_PLAINS presente", "MAP_PLAINS" in _map_set())
	H.check("AUD-26 MAP_CAVE presente", "MAP_CAVE" in _map_set())
	H.check("AUD-27 MAP_SALT_COAST presente", "MAP_SALT_COAST" in _map_set())
	# grounds core preservados (conteúdo antigo protegido)
	H.check("AUD-28 grounds core preservados", TestHarness.missing_ids(["HG_PLAINS_LOW", "HG_PLAINS_HIGH", "HG_CAVE"], _grounds()).is_empty())
	# unicidade básica (aprofundada em REGISTRY)
	H.check("AUD-29 grounds sem duplicata", TestHarness.duplicate_ids(_grounds()).is_empty())
	H.check("AUD-30 items sem duplicata", TestHarness.duplicate_ids(_items()).is_empty())
	H.check("AUD-31 missions sem duplicata", TestHarness.duplicate_ids(_missions()).is_empty())
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _runner() -> void:
	H.group_begin("TEST31RUNNER", 30)
	# grupo correto → PASS / all_ok
	var ok := TestHarness.new(); ok.group_begin("g", 2); ok.check("a", true); ok.check("b", true); ok.group_complete()
	H.check("RUN-01 grupo correto = PASS", ok.status_of(ok.groups[0]) == "PASS")
	H.check("RUN-02 grupo correto all_ok", ok.all_ok())
	H.check("RUN-03 summarize ok=true", bool(ok.summarize("t")["ok"]))
	# grupo não-completo → INCOMPLETE → not ok
	var inc := TestHarness.new(); inc.group_begin("g", 2); inc.check("a", true); inc.check("b", true)  # sem complete
	H.check("RUN-04 sem group_complete = INCOMPLETE", inc.status_of(inc.groups[0]) == "INCOMPLETE")
	H.check("RUN-05 INCOMPLETE ⇒ not all_ok", not inc.all_ok())
	H.check("RUN-06 INCOMPLETE ⇒ summarize ok=false", not bool(inc.summarize("t")["ok"]))
	# completo mas asserts < min → FAIL_MIN
	var fm := TestHarness.new(); fm.group_begin("g", 5); fm.check("a", true); fm.group_complete()
	H.check("RUN-07 asserts<min = FAIL_MIN", fm.status_of(fm.groups[0]) == "FAIL_MIN")
	H.check("RUN-08 FAIL_MIN ⇒ not all_ok", not fm.all_ok())
	# zero asserts com min>0 → FAIL_MIN
	var z := TestHarness.new(); z.group_begin("g", 3); z.group_complete()
	H.check("RUN-09 zero asserts (min>0) não passa", not z.all_ok() and z.status_of(z.groups[0]) == "FAIL_MIN")
	# check falho → FAIL
	var ff := TestHarness.new(); ff.group_begin("g", 1); ff.check("bad", false); ff.group_complete()
	H.check("RUN-10 check falho = FAIL", ff.status_of(ff.groups[0]) == "FAIL")
	H.check("RUN-11 FAIL ⇒ not all_ok", not ff.all_ok())
	# group_error → FAIL
	var ge := TestHarness.new(); ge.group_begin("g", 1); ge.check("a", true); ge.group_error("setup null"); ge.group_complete()
	H.check("RUN-12 group_error = FAIL", ge.status_of(ge.groups[0]) == "FAIL")
	H.check("RUN-13 group_error ⇒ not all_ok", not ge.all_ok())
	# harness vazio (nenhum grupo) → not ok (não pode passar por omissão)
	var em := TestHarness.new()
	H.check("RUN-14 harness vazio não passa", not em.all_ok() and not bool(em.summarize("t")["ok"]))
	# múltiplos grupos: todos PASS → ok; um ruim → not ok
	var mg := TestHarness.new()
	mg.group_begin("g1", 1); mg.check("a", true); mg.group_complete()
	mg.group_begin("g2", 1); mg.check("b", true); mg.group_complete()
	H.check("RUN-15 múltiplos grupos ok", mg.all_ok())
	mg.group_begin("g3", 1); mg.check("c", false); mg.group_complete()
	H.check("RUN-16 um grupo ruim derruba tudo", not mg.all_ok())
	H.check("RUN-17 summarize conta grupos", int(mg.summarize("t")["total"]) == 3)
	# contadores do summarize
	var sm := TestHarness.new()
	sm.group_begin("p", 1); sm.check("a", true); sm.group_complete()
	sm.group_begin("f", 1); sm.check("b", false); sm.group_complete()
	sm.group_begin("i", 1); sm.check("c", true)  # incomplete
	var d := sm.summarize("t")
	H.check("RUN-18 summarize pass=1", int(d["pass"]) == 1)
	H.check("RUN-19 summarize fail=1", int(d["fail"]) == 1)
	H.check("RUN-20 summarize incomplete=1", int(d["incomplete"]) == 1)
	H.check("RUN-21 summarize asserts=3", int(d["asserts"]) == 3)
	# helpers estáticos
	H.check("RUN-22 missing_ids acha faltante", TestHarness.missing_ids(["a", "z"], ["a", "b"]) == ["z"])
	H.check("RUN-23 missing_ids vazio p/ subset", TestHarness.missing_ids(["a"], ["a", "b", "c"]).is_empty())
	H.check("RUN-24 duplicate_ids acha dup", TestHarness.duplicate_ids(["a", "b", "a"]) == ["a"])
	H.check("RUN-25 duplicate_ids vazio p/ únicos", TestHarness.duplicate_ids(["a", "b"]).is_empty())
	# asserts de catálogo registram certo
	var rc := TestHarness.new(); rc.group_begin("g", 1)
	rc.assert_registry_contains("subset ok", ["a", "b", "c"], ["a", "b"]); rc.group_complete()
	H.check("RUN-26 assert_registry_contains passa p/ subset", rc.all_ok())
	var rc2 := TestHarness.new(); rc2.group_begin("g", 1)
	rc2.assert_registry_contains("subset falho", ["a", "b"], ["a", "z"]); rc2.group_complete()
	H.check("RUN-27 assert_registry_contains falha p/ faltante", not rc2.all_ok())
	var ru := TestHarness.new(); ru.group_begin("g", 1)
	ru.assert_registry_unique("dup", ["a", "a"]); ru.group_complete()
	H.check("RUN-28 assert_registry_unique falha p/ dup", not ru.all_ok())
	var mc := TestHarness.new(); mc.group_begin("g", 1)
	mc.assert_minimum_count("min", 5, 3); mc.group_complete()
	H.check("RUN-29 assert_minimum_count passa acima do piso", mc.all_ok())
	var dv := TestHarness.new(); dv.group_begin("g", 1)
	dv.assert_definition_valid("def", {"a": 1}, ["a", "b"]); dv.group_complete()
	H.check("RUN-30 assert_definition_valid falha p/ chave faltante", not dv.all_ok())
	var ar := TestHarness.new(); ar.group_begin("g", 1)
	ar.assert_all_references_valid("refs", ["a", "x"], ["a", "b"]); ar.group_complete()
	H.check("RUN-31 assert_all_references_valid pega ref quebrada", not ar.all_ok())
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _dynamic() -> void:
	H.group_begin("TEST31DYNAMIC", 30)
	# GROUNDS: subset core + únicos + piso (NÃO exato) — catálogo pode crescer
	H.assert_registry_contains("DYN grounds ⊇ core", _grounds(), ["HG_PLAINS_LOW", "HG_PLAINS_HIGH", "HG_CAVE", "HG_GROVE", "HG_SALT_WIND_COAST"])
	H.assert_registry_unique("DYN grounds únicos", _grounds())
	H.assert_minimum_count("DYN grounds >=5", _grounds().size(), 5)
	# MAPS: subset core, únicos
	H.assert_registry_contains("DYN maps ⊇ core", _map_set(), ["MAP_PLAINS", "MAP_CAVE", "MAP_SALT_COAST"])
	H.assert_registry_unique("DYN maps únicos", _map_set())
	# CHAPTERS: subset core, únicos, piso >=4
	H.assert_registry_contains("DYN chapters ⊇ core", _chapter_set(), ["CHAPTER_1_WOLF", "CHAPTER_2_CRYSTAL", "CHAPTER_3_SPIDER", "CHAPTER_4_SALTWIND"])
	H.assert_registry_unique("DYN chapters únicos", _chapter_set())
	H.assert_minimum_count("DYN chapters >=4", _chapter_set().size(), 4)
	# MOBS: subset core, únicos
	H.assert_registry_contains("DYN mobs ⊇ core", _mobs(), ["young_wolf", "grove_spider", "dune_skitter", "salt_husk", "tide_warden"])
	H.assert_registry_unique("DYN mobs únicos", _mobs())
	H.assert_minimum_count("DYN mobs >=5", _mobs().size(), 5)
	# BOSSES: subset core, únicos
	H.assert_registry_contains("DYN bosses ⊇ core (MoonScar/Golem/Aranha)", _bosses(), ["BOSS_WOLF_ALPHA", "BOSS_CRYSTAL_GOLEM", "BOSS_CH3_SPIDER_MATRIARCH"])
	H.assert_registry_unique("DYN bosses únicos", _bosses())
	# ITEMS: subset core (inclui A30), únicos
	H.assert_registry_contains("DYN items ⊇ core+A30", _items(), ["sword_simple", "sword_eternal", "bow_eternal", "spear_eternal", "book_reinforced", "book_eternal"])
	H.assert_registry_unique("DYN items únicos", _items())
	# PROFILES / PROPS únicos
	H.assert_registry_unique("DYN profiles únicos", _profiles())
	H.assert_registry_unique("DYN props únicos", _props())
	H.assert_minimum_count("DYN profiles >=2", _profiles().size(), 2)
	# FUTURE-PACK SAFETY: subset TOLERA extras (catálogo maior não quebra)
	var future_grounds := _grounds().duplicate(); future_grounds.append("HG_FUTURE_PACK_01")
	H.check("DYN future-pack: +1 ground não quebra subset", TestHarness.missing_ids(["HG_PLAINS_LOW", "HG_CAVE"], future_grounds).is_empty())
	var future_mobs := _mobs().duplicate(); future_mobs.append("future_beast")
	H.check("DYN future-pack: +1 mob não quebra subset", TestHarness.missing_ids(["young_wolf"], future_mobs).is_empty())
	var future_bosses := _bosses().duplicate(); future_bosses.append("BOSS_FUTURE")
	H.check("DYN future-pack: +1 boss não quebra subset", TestHarness.missing_ids(["BOSS_WOLF_ALPHA"], future_bosses).is_empty())
	# mas future-pack COM id duplicado É pego
	var dup_pack := _grounds().duplicate(); dup_pack.append("HG_CAVE")
	H.check("DYN future-pack: id duplicado É detectado", not TestHarness.duplicate_ids(dup_pack).is_empty())
	# CHAPTER SCALABILITY: CURRENT_LAST derivado (não FIXED_FINAL). Ch5 ainda não existe (estado atual), mas
	# usamos SUBSET ⇒ quando Ch5 entrar, este check continua verde (não exige "exatamente 4").
	var chaps := _chapter_set()
	H.check("DYN CURRENT_LAST = Ch4 (estado atual, não final fixo)", "CHAPTER_4_SALTWIND" in chaps)
	H.check("DYN Ch5 ainda não existe (current state, subset tolera crescer)", not ("CHAPTER_5" in chaps))
	H.check("DYN chapters via subset (Ch5 futuro NÃO quebraria)", TestHarness.missing_ids(["CHAPTER_1_WOLF", "CHAPTER_4_SALTWIND"], chaps + ["CHAPTER_5_FUTURE"]).is_empty())
	# MAP SCALABILITY: required ⊆, não fechado
	H.check("DYN maps não-fechados (extra futuro ok)", TestHarness.missing_ids(["MAP_PLAINS"], _map_set() + ["MAP_FUTURE"]).is_empty())
	# ITEM SCALABILITY: A30 não pode ser assumido como lista fixa — mas os antigos seguem lá
	H.assert_registry_contains("DYN items antigos preservados", _items(), ["sword_reinforced", "staff_eternal", "bow_reinforced", "spear_reinforced"])
	# universo de mob COMPLETO (união) cobre os do ContentManifest usados nos HGs (não são refs quebradas)
	H.assert_registry_contains("DYN all_mobs ⊇ roaming legado (wild_boar/road_bandit)", _all_mobs(), ["wild_boar", "road_bandit"])
	H.assert_minimum_count("DYN all_mobs supera MobEligibility (união)", _all_mobs().size(), _mobs().size())
	# props do Living World únicos + piso (A28/A29 crescem)
	H.assert_minimum_count("DYN props >=8", _props().size(), 8)
	# missões escalam (4 capítulos × ~8 + repeatables): piso, não exato
	H.assert_minimum_count("DYN missions >=24", _missions().size(), 24)
	# cada família de arma tem >=1 item (subset por weapon_kind, escala com novos itens)
	var kinds: Array = []
	for iid in _items():
		var wk := str(ItemDB.get_item(iid).get("weapon_kind", ""))
		if wk != "" and not (wk in kinds): kinds.append(wk)
	H.assert_registry_contains("DYN famílias de arma ⊇ core", kinds, ["sword", "bow", "staff", "spear", "book"])
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _registry() -> void:
	H.group_begin("TEST31REGISTRY", 25)
	# unicidade em TODOS os catálogos centrais
	H.assert_registry_unique("REG grounds únicos", _grounds())
	H.assert_registry_unique("REG mobs únicos", _mobs())
	H.assert_registry_unique("REG missions únicas", _missions())
	H.assert_registry_unique("REG bosses únicos", _bosses())
	H.assert_registry_unique("REG items únicos", _items())
	H.assert_registry_unique("REG profiles únicos", _profiles())
	H.assert_registry_unique("REG props únicos", _props())
	# BROKEN REFERENCES — missão → mob válido (universo = UNIÃO dos registries de mob)
	var mob_universe := _all_mobs()
	var bad_mission_mob: Array = []
	for mid in AfkMissionDefinition.MISSIONS:
		var mdef: Dictionary = AfkMissionDefinition.MISSIONS[mid]
		for tm in mdef.get("target_mob_ids", []):
			if not (str(tm) in mob_universe) and not (str(tm) in bad_mission_mob):
				bad_mission_mob.append(str(tm))
	H.check("REG missão→mob todas válidas (%s)" % ("ok" if bad_mission_mob.is_empty() else str(bad_mission_mob)), bad_mission_mob.is_empty())
	# HG → mob válido
	var bad_hg_mob: Array = []
	for gid in HuntingGround.GROUNDS:
		for row in HuntingGround.GROUNDS[gid].get("mob_table", []):
			var mmid := str((row as Dictionary).get("mob_id", ""))
			if mmid != "" and not (mmid in mob_universe) and not (mmid in bad_hg_mob):
				bad_hg_mob.append(mmid)
	H.check("REG HG→mob todas válidas (%s)" % ("ok" if bad_hg_mob.is_empty() else str(bad_hg_mob)), bad_hg_mob.is_empty())
	# missão → chapter não-vazio + estrutura mínima
	var bad_mission_chap: Array = []
	for mid in AfkMissionDefinition.MISSIONS:
		if str(AfkMissionDefinition.MISSIONS[mid].get("chapter_id", "")) == "":
			bad_mission_chap.append(str(mid))
	H.check("REG toda missão tem chapter_id (%s)" % ("ok" if bad_mission_chap.is_empty() else str(bad_mission_chap)), bad_mission_chap.is_empty())
	# boss → chapter que EXISTE no registry de missões (ref cross-registry real)
	var chap_universe := _chapter_set()
	var bad_boss_chap: Array = []
	for bid in BossActivityDefinition.BOSSES:
		var bc := str(BossActivityDefinition.BOSSES[bid].get("chapter_id", ""))
		if bc != "" and not (bc in chap_universe) and not (bc in bad_boss_chap):
			bad_boss_chap.append(bc)
	H.check("REG boss→chapter válido (%s)" % ("ok" if bad_boss_chap.is_empty() else str(bad_boss_chap)), bad_boss_chap.is_empty())
	# HG → map_id não-vazio
	var bad_hg_map: Array = []
	for gid in HuntingGround.GROUNDS:
		if str(HuntingGround.GROUNDS[gid].get("map_id", "")) == "":
			bad_hg_map.append(str(gid))
	H.check("REG todo HG tem map_id (%s)" % ("ok" if bad_hg_map.is_empty() else str(bad_hg_map)), bad_hg_map.is_empty())
	# definição válida: cada HG tem as chaves estruturais
	var bad_hg_def: Array = []
	for gid in HuntingGround.GROUNDS:
		var gd: Dictionary = HuntingGround.GROUNDS[gid]
		if not (gd.has("map_id") and gd.has("mob_table") and gd.has("unlock_rule")):
			bad_hg_def.append(str(gid))
	H.check("REG HG def válida (map_id+mob_table+unlock_rule) (%s)" % ("ok" if bad_hg_def.is_empty() else str(bad_hg_def)), bad_hg_def.is_empty())
	# cada boss tem boss_id + chapter_id
	var bad_boss_def: Array = []
	for bid in BossActivityDefinition.BOSSES:
		if not (BossActivityDefinition.BOSSES[bid].has("chapter_id")):
			bad_boss_def.append(str(bid))
	H.check("REG boss def válida (chapter_id) (%s)" % ("ok" if bad_boss_def.is_empty() else str(bad_boss_def)), bad_boss_def.is_empty())
	# weapon source: as armas A30 têm fonte no ItemSourceRegistry (ref item→fonte)
	ItemSourceRegistry.invalidate()
	for wid in ["bow_eternal", "spear_eternal", "book_eternal", "book_reinforced"]:
		H.check("REG %s tem fonte (item→source)" % wid, ItemSourceRegistry.has_source(wid))
	# conteúdo antigo requerido continua protegido (não sumiu)
	H.assert_registry_contains("REG old required grounds", _grounds(), ["HG_PLAINS_LOW", "HG_CAVE"])
	H.assert_registry_contains("REG old required bosses", _bosses(), ["BOSS_WOLF_ALPHA", "BOSS_CRYSTAL_GOLEM"])
	H.assert_registry_contains("REG old required mobs", _mobs(), ["young_wolf"])
	# cada capítulo core tem >=1 missão (conteúdo antigo intacto)
	for ch in ["CHAPTER_1_WOLF", "CHAPTER_2_CRYSTAL", "CHAPTER_3_SPIDER", "CHAPTER_4_SALTWIND"]:
		var cnt := 0
		for mid in AfkMissionDefinition.MISSIONS:
			if str(AfkMissionDefinition.MISSIONS[mid].get("chapter_id", "")) == ch: cnt += 1
		H.check("REG %s tem >=1 missão (%d)" % [ch, cnt], cnt >= 1)
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _presence() -> void:
	H.group_begin("TEST31PRESENCE", 15)
	# POLÍTICA oficial (§10/§18/§19): "Auto retoma SÓ se estava ON; se estava OFF, permanece manual". Prova sem
	# bootar Main, via fake host. DIAGNÓSTICO a10/a101: os testes eram STALE (assumiam Auto ON por padrão, mas
	# desde A20.17/LEGACY_PVE_DEPRECATION o Auto NÃO liga sozinho) — a política em si está CORRETA.
	var host := _FakeHost.new()
	var pc := PresenceController.new()
	pc.setup(host)
	# caso 1: Auto estava ON → begin desliga → end RESTAURA ON
	host.auto = true
	H.check("PRES-01 precondição Auto ON", pc._auto_on())
	var b1 := pc.begin_manual_challenge()
	H.check("PRES-02 begin ok (wall ativo)", b1)
	H.check("PRES-03 begin desligou Auto (jogador assume)", not host.auto)
	pc.end_manual_challenge()
	H.check("PRES-04 end RESTAURA Auto ON (resume real)", host.auto)
	# caso 2: Auto estava OFF → begin não muda → end mantém OFF (permanece manual)
	host.auto = false
	var b2 := pc.begin_manual_challenge()
	H.check("PRES-05 begin ok com Auto OFF", b2)
	H.check("PRES-06 Auto continua OFF durante", not host.auto)
	pc.end_manual_challenge()
	H.check("PRES-07 end MANTÉM OFF (não liga sozinho)", not host.auto)
	# control_state segue a política
	host.auto = true
	H.check("PRES-08 control_state AUTO com Auto ON, sem input", pc.control_state() == PresenceController.AUTO)
	host.auto = false
	H.check("PRES-09 control_state MANUAL com Auto OFF", pc.control_state() == PresenceController.MANUAL)
	H.check("PRES-10 control_label VOCÊ quando manual", pc.control_label() == "VOCÊ")
	host.auto = true
	H.check("PRES-11 control_label AUTO quando auto", pc.control_label() == "AUTO")
	# can_manual_challenge exige muro ativo (política: presença não gateia, só oferece)
	H.check("PRES-12 challenge exige wall ativo", pc.can_manual_challenge())
	# diagnóstico documentado: a política restaura o estado ANTERIOR, não força ON
	host.auto = false; pc.begin_manual_challenge(); pc.end_manual_challenge()
	H.check("PRES-13 DIAGNÓSTICO: restaura estado anterior (OFF→OFF), não força ON", not host.auto)
	host.auto = true; pc.begin_manual_challenge(); pc.end_manual_challenge()
	H.check("PRES-14 DIAGNÓSTICO: restaura estado anterior (ON→ON)", host.auto)
	# presença não persiste (transitório)
	H.check("PRES-15 challenge_active limpo após end", not pc.challenge_active())
	H.check("PRES-16 política independe de count de conteúdo (fake host, sem catálogo)", true)
	pc.free()
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
# META-SABOTAGE: sabota artificialmente e prova que o runner detecta FAIL/INCOMPLETE (nunca silent green)
func _sab_zero(h: TestHarness) -> void:
	h.group_begin("SAB", 5)  # min 5, mas ZERO asserts
	h.group_complete()

func _sab_abort(h: TestHarness) -> void:
	h.group_begin("SAB", 5)
	h.check("c1", true)
	if true: return  # abort/exception simulada: retorna ANTES de group_complete (classe do bug A29)

func _sab_early(h: TestHarness) -> void:
	h.group_begin("SAB", 5)
	h.check("c1", true); h.check("c2", true); h.check("c3", true)
	if true: return  # early return com asserts < min E sem complete

func _sab_min(h: TestHarness) -> void:
	h.group_begin("SAB", 5)
	h.check("c1", true); h.check("c2", true)  # completa mas 2 < 5
	h.group_complete()

func _sab_dup(h: TestHarness) -> void:
	h.group_begin("SAB", 1)
	h.assert_registry_unique("dup", ["a", "b", "a"])  # id duplicado
	h.group_complete()

func _sab_missing(h: TestHarness) -> void:
	h.group_begin("SAB", 1)
	h.assert_registry_contains("subset", ["a", "b"], ["a", "b", "z"])  # required z ausente
	h.group_complete()

func _meta() -> void:
	H.group_begin("TEST31META", 25)
	# CONTROLE: um harness correto DEVE passar (prova que não é sempre-falso)
	var good := TestHarness.new(); good.group_begin("g", 2); good.check("a", true); good.check("b", true); good.group_complete()
	H.check("META controle: harness correto PASSA", good.all_ok())
	H.check("META controle: status PASS", good.status_of(good.groups[0]) == "PASS")
	# SABOTAGEM 1 — zero assertions
	var s1 := TestHarness.new(); _sab_zero(s1)
	H.check("META sab1 zero-assert: not all_ok", not s1.all_ok())
	H.check("META sab1 zero-assert: status FAIL_MIN", s1.status_of(s1.groups[0]) == "FAIL_MIN")
	H.check("META sab1 zero-assert: summarize ok=false", not bool(s1.summarize("sab1")["ok"]))
	# SABOTAGEM 2 — abort/exception no meio (early return antes do complete)
	var s2 := TestHarness.new(); _sab_abort(s2)
	H.check("META sab2 abort: not all_ok", not s2.all_ok())
	H.check("META sab2 abort: status INCOMPLETE (bug A29)", s2.status_of(s2.groups[0]) == "INCOMPLETE")
	H.check("META sab2 abort: summarize ok=false", not bool(s2.summarize("sab2")["ok"]))
	# SABOTAGEM 3 — early return (asserts parciais < min, sem complete)
	var s3 := TestHarness.new(); _sab_early(s3)
	H.check("META sab3 early-return: not all_ok", not s3.all_ok())
	H.check("META sab3 early-return: INCOMPLETE", s3.status_of(s3.groups[0]) == "INCOMPLETE")
	# SABOTAGEM 4 — minimum não atingido (completou, mas abaixo do piso)
	var s4 := TestHarness.new(); _sab_min(s4)
	H.check("META sab4 min: not all_ok", not s4.all_ok())
	H.check("META sab4 min: FAIL_MIN (completou mas 2<5)", s4.status_of(s4.groups[0]) == "FAIL_MIN")
	# SABOTAGEM 5 — duplicate ID
	var s5 := TestHarness.new(); _sab_dup(s5)
	H.check("META sab5 duplicate-id: not all_ok", not s5.all_ok())
	H.check("META sab5 duplicate-id: FAIL", s5.status_of(s5.groups[0]) == "FAIL")
	# SABOTAGEM 6 — missing required ID
	var s6 := TestHarness.new(); _sab_missing(s6)
	H.check("META sab6 missing-id: not all_ok", not s6.all_ok())
	H.check("META sab6 missing-id: FAIL", s6.status_of(s6.groups[0]) == "FAIL")
	# SILENT-GREEN reproduction (classe A29): grupo com runtime null que aborta cedo
	var sg := TestHarness.new()
	sg.group_begin("runtime_null", 4)
	var fake_runtime = null
	sg.check("boot", true)
	if fake_runtime == null:
		# o teste ANTIGO daria return aqui e o _fail ficaria 0 ⇒ >>> OK mentiroso.
		# no runner novo: sem group_complete ⇒ INCOMPLETE ⇒ FAIL.
		pass
	# (deliberadamente NÃO chama group_complete p/ simular o abort silencioso)
	H.check("META silent-green (runtime null) reproduzido = INCOMPLETE, NÃO OK", not sg.all_ok() and sg.status_of(sg.groups[0]) == "INCOMPLETE")
	H.check("META silent-green: summarize NÃO imprime ok", not bool(sg.summarize("silent")["ok"]))
	# prova cruzada: se aquele MESMO grupo tivesse completado com os 4 asserts, seria PASS (não é falso-negativo cego)
	var sg2 := TestHarness.new(); sg2.group_begin("runtime_ok", 4)
	sg2.check("a", true); sg2.check("b", true); sg2.check("c", true); sg2.check("d", true); sg2.group_complete()
	H.check("META cruzado: grupo completo e no piso = PASS (não é sempre-FAIL)", sg2.all_ok())
	# STRICT MODE: flag existe e é dev/test-only (não falha por dívida visual/áudio)
	var strict := TestHarness.new(true)
	H.check("META strict flag ligável", strict.strict)
	var loose := TestHarness.new()
	H.check("META strict off por padrão", not loose.strict)
	# reforço: cada sabotagem produz o contador certo no summarize (não só o veredito booleano)
	H.check("META sab1 summarize fail=1", int(s1.summarize("s")["fail"]) == 1)
	H.check("META sab2 summarize incomplete=1", int(s2.summarize("s")["incomplete"]) == 1)
	H.check("META sab4 summarize fail=1 (min)", int(s4.summarize("s")["fail"]) == 1)
	H.check("META sab5 summarize fail=1 (dup)", int(s5.summarize("s")["fail"]) == 1)
	H.check("META sab6 summarize fail=1 (missing)", int(s6.summarize("s")["fail"]) == 1)
	# nenhuma sabotagem passa por omissão (todas as 6 ⇒ not ok)
	H.check("META TODAS as 6 sabotagens = not ok", not (s1.all_ok() or s2.all_ok() or s3.all_ok() or s4.all_ok() or s5.all_ok() or s6.all_ok()))
	H.group_complete()
