extends SceneTree
## A40 — PROVA DE ASSET do boss do Chapter 4 (salt_split_warden). NÃO boota cena, NÃO roda combate.
## Só responde, com evidência: o asset EXISTE, CARREGA e PASSA no ActorAssetValidator?
##
## ★★★ Roda ANTES do closeout de dados. Se isto reprovar, NÃO se toca em BossActivityDefinition:
## editar o dado com o contrato falhando faz o grupo A40CLOSEOUT cair no ramo `else` e o assert
## "visual_id ainda tide_warden" passa a FALHAR — erro falso.
##
## Uso: --headless --path <proj> --script res://scripts/_a40_assetproof.gd
## Exit 0 = contrato OK · 1 = contrato falhou.

const KEY := "bosses/salt_split_warden"
const FRAME := 160
const COUNT := 4
const BOSS := "BOSS_CH4_SALT_WARDEN"

func _initialize() -> void:
	var out := {}
	print("═══════════ A40 — PROVA DE ASSET (salt_split_warden) ═══════════")

	# ── 1. existência + load, arquivo a arquivo (paths resolvidos registrados) ──
	var files := {"BASE": KEY, "SIDE": "%s_side" % KEY, "UP": "%s_up" % KEY, "SHADOW(fora do contrato)": "%s_shadow" % KEY}
	var loaded := {}
	for role in files:
		var path := "res://assets/actors/%s.png" % str(files[role])
		var exists := ResourceLoader.exists(path)
		var tex := (load(path) as Texture2D) if exists else null
		var dim := ("%dx%d" % [tex.get_width(), tex.get_height()]) if tex != null else "-"
		loaded[role] = {"path": path, "exists": exists, "loaded": tex != null, "dim": dim}
		print("  %-26s exists=%-5s load=%-5s %-10s %s" % [role, str(exists), str(tex != null), dim, path])
	out["files"] = loaded

	# ── 2. ActorAssetValidator: o contrato de verdade ──
	var v := ActorAssetValidator.validate_actor(KEY, FRAME, COUNT)
	print("─────────────────────────────────────────────")
	print("  validate_actor(\"%s\", %d, %d)" % [KEY, FRAME, COUNT])
	print("    ok           = %s" % str(v.get("ok", false)))
	var base_d: Dictionary = v.get("base", {})
	print("    base         = %dx%d  frame_size=%d  frame_count=%d" % [int(base_d.get("width", 0)), int(base_d.get("height", 0)), int(base_d.get("frame_size", 0)), int(base_d.get("frame_count", 0))])
	for d in ["side", "up"]:
		if v.has(d):
			var dd: Dictionary = v[d]
			print("    %-12s = %dx%d  frame_size=%d  frame_count=%d  ok=%s" % [d, int(dd.get("width", 0)), int(dd.get("height", 0)), int(dd.get("frame_size", 0)), int(dd.get("frame_count", 0)), str(dd.get("ok", false))])
	var errs: Array = v.get("errors", [])
	print("    errors(%d)    = %s" % [errs.size(), str(errs)])
	out["validator"] = v

	# ── 3. estado ATUAL da definição do boss (o "antes" do closeout) ──
	var b := BossActivityDefinition.get_boss(BOSS)
	var before := {
		"visual_id": str(b.get("visual_id", "")),
		"visual_key_declarado": b.has("visual_key"),
		"boss_asset_required": BossActivityDefinition.asset_required(BOSS),
		"asset_status": BossActivityDefinition.asset_status(BOSS),
		"asset_candidate": str(b.get("asset_candidate", "")),
	}
	print("─────────────────────────────────────────────")
	print("  %s ANTES: visual_id=%s | asset_required=%s | asset_status=%s | asset_candidate=%s | visual_key declarado=%s" % [BOSS, before["visual_id"], str(before["boss_asset_required"]), before["asset_status"], before["asset_candidate"], str(before["visual_key_declarado"])])
	# resolução real usada pelo MissionHost:127 quando NÃO há visual_key
	print("  resolucao MissionHost (sem visual_key) => bosses/%s" % before["visual_id"])
	out["boss_before"] = before

	# ── 4. veredito ──
	var contract_ok: bool = ResourceLoader.exists("res://assets/actors/%s.png" % KEY) and bool(v.get("ok", false))
	out["contract_ok"] = contract_ok
	print("─────────────────────────────────────────────")
	print(">>> A40 ASSET CONTRACT: %s" % ("PASS" if contract_ok else "FAIL"))

	var f := FileAccess.open("user://a40_assetproof.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "\t")); f.close()
		print("    artefato: user://a40_assetproof.json")
	quit(0 if contract_ok else 1)
