extends SceneTree
## Compõe uma contact sheet dos estados de HP (recorta a região top-left de cada A39_HP_*.png e empilha).
func _initialize() -> void:
	# Pasta dos PNGs: --shot-dir=<abs> (mesmo argumento do _a39_screenshot.gd); default = user://
	var dir := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="): dir = a.substr("--shot-dir=".length())
	if not dir.ends_with("/"): dir += "/"
	var states := ["A39_HP_FULL.png", "A39_HP_HALF.png", "A39_HP_LOW.png", "A39_HP_ZERO.png"]
	var crop := Rect2i(0, 24, 440, 56)   # região do cluster top-left (medalhão + poder + HP)
	var pad := 8
	var sheet := Image.create(crop.size.x, (crop.size.y + pad) * states.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.06, 0.06, 0.08, 1))
	var y := 0
	for f in states:
		var img := Image.load_from_file(dir + f)
		if img == null: continue
		var sub := img.get_region(crop)
		sheet.blit_rect(sub, Rect2i(Vector2i.ZERO, crop.size), Vector2i(0, y))
		y += crop.size.y + pad
	sheet.save_png(dir + "A39_HP_CONTACT.png")
	print("[sheet] A39_HP_CONTACT.png %dx%d" % [sheet.get_width(), sheet.get_height()])
	quit(0)
