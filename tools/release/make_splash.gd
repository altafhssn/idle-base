extends SceneTree
## Renders the boot splash image res://assets/splash/boot_splash.png
## (docs/launch/release.md, "Boot splash"; optimisation report item 6.10).
##
## Munshi-ji (the game's own munshi_<pose>.glb, lit like his dialogue bust)
## over the "Dhaba Rush / Highway Idle Tycoon" lockup in the game font, on the
## boot splash colour. The image is opaque and its edges are exactly the boot
## splash colour, so Godot's "Keep" stretch letterboxes it seamlessly on any
## screen shape (project.godot application/boot_splash/bg_color).
##
## Needs a GPU: run WINDOWED (not --headless) in a scratch copy of the
## project with its own HOME, never in the real project folder:
##   HOME=<scratch>/home /Applications/Godot.app/Contents/MacOS/Godot \
##       --path <scratch copy> -s res://tools/release/make_splash.gd -- \
##       --out=<scratch>/boot_splash.png [--pose=chai]
## then copy the PNG to assets/splash/boot_splash.png. Keep its .import file
## as importer="keep": Godot reads the boot splash as a raw PNG at startup and
## always packs that file, so an imported texture copy would only add size.

const W := 900
const H := 1250
## Must equal application/boot_splash/bg_color (Color(0.96, 0.63, 0.29)).
const BG := Color(0.96, 0.63, 0.29)
const INK := Color(0.23, 0.14, 0.08)
const TITLE := Color(1.0, 0.87, 0.35)
const SUB := Color(1.0, 0.965, 0.89)

## Munshi-ji's 3D view: model-space window (metres, x from the head centre,
## y up from the waist) drawn at PPM px per metre.
const PPM := 330.0
const WIN_X := Vector2(-1.15, 1.15)
const WIN_Y := Vector2(-0.05, 1.55)
const CAM_DIST := 5.5
const CAM_Y := 1.0
const TURN_YAW := -0.18
## Top of the 3D view: centres the bust + plate group above the credit line.
const BUST_TOP := 215.0

var _out: String = ""
var _pose: String = "namaste"


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--pose="):
			_pose = a.substr(7)
	if _out == "":
		push_error("make_splash: --out=<png> is required")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	var font: Font = load("res://ui/main_font.tres")
	var page := SubViewport.new()
	page.size = Vector2i(W, H)
	page.transparent_bg = false
	page.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	page.disable_3d = true
	root.add_child(page)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(W, H)
	page.add_child(bg)

	# ---- Munshi-ji in his own transparent 3D view
	var win := Vector2(WIN_X.y - WIN_X.x, WIN_Y.y - WIN_Y.x)
	var vsize := Vector2i(roundi(win.x * PPM), roundi(win.y * PPM))
	var view := SubViewport.new()
	view.size = vsize
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_8X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	page.add_child(view)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.96, 0.9)
	env.ambient_light_energy = 0.5
	var cam := Camera3D.new()
	cam.environment = env
	view.add_child(cam)
	cam.current = true
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30.0, 25.0, 0.0)
	key.light_energy = 0.85
	view.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15.0, 160.0, 0.0)
	rim.light_energy = 0.3
	view.add_child(rim)
	var pivot := Node3D.new()
	pivot.rotation = Vector3(0.0, TURN_YAW, 0.0)
	view.add_child(pivot)
	var path := "res://themes/dhaba/models/munshi_%s.glb" % _pose
	if not ResourceLoader.exists(path):
		push_error("make_splash: missing " + path)
		quit(3)
		return
	var model: Node3D = (load(path) as PackedScene).instantiate()
	pivot.add_child(model)
	var cx := 0.0
	var head := model.find_child("head", true, false) as Node3D
	if head != null:
		cx = head.global_position.x
	# Level camera; off-axis frustum showing exactly the window at z = 0.
	var near := 0.5
	var k := near / CAM_DIST
	var mid := Vector2(WIN_X.x + win.x * 0.5, WIN_Y.x + win.y * 0.5)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.set_frustum(win.y * k, Vector2(mid.x, mid.y - CAM_Y) * k, near, CAM_DIST + 4.0)
	cam.position = Vector3(cx, CAM_Y, CAM_DIST)

	var bust := TextureRect.new()
	bust.texture = view.get_texture()
	bust.size = Vector2(vsize)
	bust.position = Vector2((W - vsize.x) * 0.5, BUST_TOP)
	page.add_child(bust)
	# Cut line of the bust (the waist) hides behind the title plate.
	var cut_y: float = bust.position.y + vsize.y - (0.0 - WIN_Y.x) * PPM

	# ---- lockup
	var plate := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.56, 0.11, 0.23)          # UiKit.MAROON
	sb.border_color = INK
	sb.set_border_width_all(8)
	sb.set_corner_radius_all(36)
	plate.add_theme_stylebox_override("panel", sb)
	var plate_h := 300.0
	plate.size = Vector2(W - 90.0, plate_h)
	plate.position = Vector2(45.0, cut_y - 70.0)
	page.add_child(plate)

	var title := _label("Dhaba Rush", font, 150, TITLE, 22)
	_fit(title, font, W - 150.0)
	page.add_child(title)
	title.size = Vector2(W, 0)
	title.position = Vector2(0, plate.position.y + 18.0)
	var sub := _label("Highway Idle Tycoon", font, 62, SUB, 14)
	_fit(sub, font, W - 190.0)
	page.add_child(sub)
	sub.size = Vector2(W, 0)
	sub.position = Vector2(0, plate.position.y + 192.0)
	var credit := _label("Little Tag Art Studios", font, 30, Color(INK, 0.75), 0)
	page.add_child(credit)
	credit.size = Vector2(W, 0)
	credit.position = Vector2(0, H - 70.0)

	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = page.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var err := img.save_png(_out)
	print("[make_splash] pose %s -> %s (%dx%d) err %d" % [_pose, _out, img.get_width(), img.get_height(), err])
	quit(0 if err == OK else 1)


func _label(text: String, font: Font, px: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = px
	ls.font_color = col
	ls.outline_size = outline
	ls.outline_color = INK
	if outline > 0:
		ls.shadow_color = Color(INK, 0.45)
		ls.shadow_offset = Vector2(0, maxf(4.0, outline * 0.4))
		ls.shadow_size = outline
	l.label_settings = ls
	return l


## Shrinks the label's font until the text fits `max_w` pixels.
func _fit(l: Label, font: Font, max_w: float) -> void:
	var ls := l.label_settings
	while ls.font_size > 20 and font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ls.font_size).x + ls.outline_size > max_w:
		ls.font_size -= 2
