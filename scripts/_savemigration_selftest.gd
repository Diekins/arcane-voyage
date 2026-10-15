extends SceneTree
## Self-test FATIA A1.5 — SaveMigration. Prova SAVE-T01..T06 usando ARQUIVOS TEMPORÁRIOS (user://_sm_test_*)
## e passos/versões INJETADOS — o save real do dono NUNCA é tocado. Rodar:
##   godot --headless --path godot -s res://scripts/_savemigration_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1

## passo de migração fake v1→v2: adiciona um campo, PRESERVANDO o resto.
static func _mig_1_to_2(d: Dictionary) -> Dictionary:
	d["added_in_v2"] = "b"
	return d
## passo fake v2→v3.
static func _mig_2_to_3(d: Dictionary) -> Dictionary:
	d["added_in_v3"] = "c"
	return d

func _rm(p: String) -> void:
	if FileAccess.file_exists(p): DirAccess.remove_absolute(p)

func _write(p: String, s: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_string(s); f.close()

func _initialize() -> void:
	var SM := load("res://scripts/SaveMigration.gd")
	var base := "user://_sm_test_save.json"
	# limpa artefatos de rodadas anteriores
	for tag in ["", ".corrupt.bak", ".premigrate_v1.bak", ".newer_v9.bak"]:
		_rm(base + tag)

	var steps := {1: Callable(self, "_mig_1_to_2"), 2: Callable(self, "_mig_2_to_3")}

	# ── SAVE-T01: save na versão atual carrega (status current, dados intactos) ──
	_write(base, JSON.stringify({"schemaVersion": 1, "hero_level": 7}))
	var r1: Dictionary = SM.prepare_versioned(FileAccess.open(base, FileAccess.READ).get_as_text(), base, 1, {})
	_chk("T01 save atual → status current, ok, level preservado", r1["ok"] and r1["status"] == "current" and int(r1["data"]["hero_level"]) == 7)

	# ── SAVE-T02 + T03: save legado (v1) migra v1→v3, PRESERVANDO campos existentes ──
	_rm(base + ".premigrate_v1.bak")
	_write(base, JSON.stringify({"schemaVersion": 1, "hero_level": 29, "current_region_id": "deep_dunes"}))
	var raw := FileAccess.open(base, FileAccess.READ).get_as_text()
	var r2: Dictionary = SM.prepare_versioned(raw, base, 3, steps)   # cliente "v3", save v1 → migra
	var d2: Dictionary = r2["data"]
	_chk("T02 legado migra v1→v3 (status migrated, versão final 3)", r2["ok"] and r2["migrated"] and r2["status"] == "migrated" and int(d2["schemaVersion"]) == 3)
	_chk("T02b passos aplicados em ordem (added_in_v2, added_in_v3)", d2.get("added_in_v2", "") == "b" and d2.get("added_in_v3", "") == "c")
	_chk("T03 campos existentes preservados (level 29, deep_dunes)", int(d2["hero_level"]) == 29 and str(d2["current_region_id"]) == "deep_dunes")

	# ── SAVE-T04: backup pré-migração é criado (e não sobrescreve se já existe) ──
	var bpath := base + ".premigrate_v1.bak"
	_chk("T04 backup pré-migração existe", FileAccess.file_exists(bpath))
	var b_txt := FileAccess.open(bpath, FileAccess.READ).get_as_text()
	_chk("T04b backup contém o ORIGINAL v1 (level 29, sem campos novos)", ("\"hero_level\"" in b_txt) and not ("added_in_v2" in b_txt))
	# chamar de novo NÃO sobrescreve o backup
	var made_again: bool = SM.backup_once(base, "premigrate_v1")
	_chk("T04c backup_once não sobrescreve backup existente", made_again == false)

	# ── SAVE-T05: save migrado RECARREGA (aplicável na versão atual → status current) ──
	# grava o migrado como se fosse o novo save; relê com cliente v3 → current
	_write(base, JSON.stringify(d2))
	var r5: Dictionary = SM.prepare_versioned(FileAccess.open(base, FileAccess.READ).get_as_text(), base, 3, steps)
	_chk("T05 save migrado recarrega (status current, level intacto)", r5["ok"] and r5["status"] == "current" and int(r5["data"]["hero_level"]) == 29)

	# ── SAVE-T06: JSON inválido NÃO é destruído silenciosamente (backup .corrupt.bak + não aplica) ──
	_rm(base + ".corrupt.bak")
	_write(base, "{ isto não é json válido , , ")
	var corrupt_raw := FileAccess.open(base, FileAccess.READ).get_as_text()
	var r6: Dictionary = SM.prepare_versioned(corrupt_raw, base, 1, {})
	_chk("T06 JSON inválido → ok=false, status corrupt", r6["ok"] == false and r6["status"] == "corrupt")
	_chk("T06b arquivo corrompido copiado p/ .corrupt.bak (não perdido)", FileAccess.file_exists(base + ".corrupt.bak"))
	var corrupt_bak := FileAccess.open(base + ".corrupt.bak", FileAccess.READ).get_as_text()
	_chk("T06c backup preserva o conteúdo corrompido original", corrupt_bak == corrupt_raw)

	# ── extra: save mais NOVO que o cliente → não faz downgrade, não aplica, faz backup ──
	_rm(base + ".newer_v9.bak")
	_write(base, JSON.stringify({"schemaVersion": 9, "hero_level": 1}))
	var r7: Dictionary = SM.prepare_versioned(FileAccess.open(base, FileAccess.READ).get_as_text(), base, 1, {})
	_chk("EXTRA save mais novo (v9) → status newer, não aplicado, backup feito", r7["ok"] == false and r7["status"] == "newer" and FileAccess.file_exists(base + ".newer_v9.bak"))

	# limpeza dos temporários
	for tag in ["", ".corrupt.bak", ".premigrate_v1.bak", ".newer_v9.bak"]:
		_rm(base + tag)

	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)
