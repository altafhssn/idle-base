extends Node3D
## Core-and-feel C2.2: the SEATS board at the gate (a world object, not
## tappable). W1-ART1's `seats_board` glb (a 1.0 x 0.6 m chalk board on a
## short post, tilted back 25 deg, faces +Z; nodes `board`, `full_plate` and
## the empty `text_socket` at the face centre) stands at Layout3.GATE_BOARD on
## the low front-wall cap right of the door, yawed 45 deg to face the camera.
## Label3Ds on the socket: a small bilingual "SEATS · सीटें" line and, biggest,
## the live count "{in use}/{total}" (glyphs >= 0.25 m tall: ~24 px at the
## home zoom). When every seat is taken the red `full_plate` shows over the
## number area with "FULL · भरा" in white (colour plus a word). Refreshed every
## REFRESH_S s from sim.seats_in_use() / sim.seats_total(). Board text is
## fixed bilingual art (build plan 5.5): never auto-translated.
## Without the glb a code board of the same size stands in (same node names).
##
## W2-WORLD adds it to the Sim: `load("res://scripts/v3/world/gate_board.gd")
## .new()`, add_child, then setup(sim). No class_name (build plan 2.3).

const REFRESH_S := 0.25
const FONT_PATH := "res://ui/main_font.tres"
## Board face (m) and the tilt baked in the model (top leans away from the road).
const BOARD_SIZE := Vector2(1.0, 0.6)
const TILT := 0.4363323   # 25 deg
## Fallback board: post height under the board's bottom edge.
const POST_H := 0.12
const FONT_SIZE := 128
## Cap height / em of the project font (Baloo 2; = Main3.SIGN_CAP_EM).
const CAP_EM := 0.68
## Big number: cap height (m) and the widest it may get (m) on the 1.0 m face.
const NUMBER_CAP := 0.27
const NUMBER_MAX_W := 0.9
const NUMBER_Y := -0.07
## Small "SEATS · सीटें" line over it.
const LABEL_TEXT := "SEATS · सीटें"
const LABEL_CAP := 0.07
const LABEL_MAX_W := 0.86
const LABEL_Y := 0.2
## Full: white words on the red plate (over the number area).
const FULL_TEXT := "FULL · भरा"
const FULL_CAP := 0.16
const FULL_MAX_W := 0.86
## Lift off the face (no z-fighting).
const TEXT_DZ := 0.012
const CHALK := Color(0.98, 0.96, 0.86)
const CHALK_OUTLINE := Color(0.08, 0.16, 0.1)
const LABEL_COL := Color(1.0, 0.84, 0.3)
const FULL_COL := Color(1.0, 1.0, 1.0)
const FULL_OUTLINE := Color(0.45, 0.04, 0.04)
const BOARD_GREEN := Color(0.11, 0.3, 0.2)
const FRAME_WOOD := Color(0.5, 0.32, 0.17)
const PLATE_RED := Color(0.82, 0.12, 0.1)

var _sim: Node = null
var _model: Node3D = null
var _socket: Node3D = null
var _full_plate: Node3D = null
var _label: Label3D = null
var _number: Label3D = null
var _full: Label3D = null
var _font: Font = null
var _t: float = 0.0
var _used: int = -1
var _total: int = -1
var _is_full: bool = false


func setup(sim: Node) -> void:
	_sim = sim
	name = "GateBoard"
	position = Layout3.GATE_BOARD
	rotation.y = Layout3.GATE_BOARD_YAW
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as Font
	if Models.exists("seats_board"):
		_model = Models.make("seats_board")
	else:
		_model = _make_fallback()
	_model.name = "SeatsBoard"
	add_child(_model)
	_no_shadows(_model)
	_full_plate = _model.find_child("full_plate", true, false) as Node3D
	if _full_plate != null:
		_full_plate.visible = false
	var sock: Node3D = _model.find_child("text_socket", true, false) as Node3D
	if sock == null:
		sock = Node3D.new()
		sock.name = "text_socket"
		sock.position = Vector3(0.0, POST_H + BOARD_SIZE.y * 0.5 * cos(TILT), -BOARD_SIZE.y * 0.5 * sin(TILT))
		_model.add_child(sock)
	_socket = sock
	# The text lies on the tilted face: if the socket carries no tilt of its
	# own (an empty exported upright), tilt a child frame back by TILT.
	var up: Vector3 = (_model.transform.basis.inverse() * _socket_basis_in_model()).y.normalized()
	if up.dot(Vector3.UP) > 0.99:
		var tilt := Node3D.new()
		tilt.name = "TextFrame"
		tilt.rotation.x = -TILT
		_socket.add_child(tilt)
		_socket = tilt
	_label = _make_label("Label", LABEL_TEXT, LABEL_CAP, LABEL_MAX_W, LABEL_Y, LABEL_COL, CHALK_OUTLINE)
	_number = _make_label("Number", "0/0", NUMBER_CAP, NUMBER_MAX_W, NUMBER_Y, CHALK, CHALK_OUTLINE)
	_full = _make_label("Full", FULL_TEXT, FULL_CAP, FULL_MAX_W, NUMBER_Y, FULL_COL, FULL_OUTLINE)
	_full.visible = false
	_refresh(true)


## The text the board shows now: "6/8", or "FULL · भरा" while every seat is taken.
func board_text() -> String:
	return FULL_TEXT if _is_full else ("%d/%d" % [maxi(_used, 0), maxi(_total, 0)])


func is_full() -> bool:
	return _is_full


## The big number's Label3D (the glyph-height check projects it).
func number_label() -> Label3D:
	return _number


## World height (m) of a capital / digit of the big number.
func number_cap_m() -> float:
	if _number == null:
		return 0.0
	return CAP_EM * float(_number.font_size) * _number.pixel_size


func _process(delta: float) -> void:
	_t += delta
	if _t < REFRESH_S:
		return
	_t = 0.0
	_refresh(false)


func _refresh(force: bool) -> void:
	if _sim == null or not is_instance_valid(_sim):
		return
	var used: int = int(_sim.call("seats_in_use")) if _sim.has_method("seats_in_use") else 0
	var total: int = int(_sim.call("seats_total")) if _sim.has_method("seats_total") else 0
	if not force and used == _used and total == _total:
		return
	_used = used
	_total = total
	_is_full = total > 0 and used >= total
	if _number != null:
		_number.text = "%d/%d" % [used, total]
		_fit(_number, NUMBER_CAP, NUMBER_MAX_W)
		_number.visible = not _is_full
	if _full != null:
		_full.visible = _is_full
	if _full_plate != null:
		_full_plate.visible = _is_full


func _socket_basis_in_model() -> Basis:
	var b := Basis.IDENTITY
	var n: Node = _socket
	while n != null and n != self:
		if n is Node3D:
			b = (n as Node3D).transform.basis * b
		n = n.get_parent()
	return b


func _make_label(n: String, text: String, cap: float, max_w: float, y: float, col: Color, outline: Color) -> Label3D:
	var l := Label3D.new()
	l.name = n
	# Fixed bilingual board art (build plan 5.5): never translated.
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	if _font != null:
		l.font = _font
	l.font_size = FONT_SIZE
	l.outline_size = 14
	l.modulate = col
	l.outline_modulate = outline
	l.shaded = false
	l.double_sided = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.position = Vector3(0.0, y, TEXT_DZ)
	_fit(l, cap, max_w)
	_socket.add_child(l)
	return l


## Cap height `cap` (m), shrunk so the text stays within `max_w` (m).
func _fit(l: Label3D, cap: float, max_w: float) -> void:
	var px: float = cap / (CAP_EM * float(FONT_SIZE))
	if _font != null:
		var w: float = _font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		if w > 0.0:
			px = minf(px, max_w / w)
	l.pixel_size = px


## A code board of the glb's size and node names (no glb yet): post, frame,
## chalk face tilted back TILT, a hidden red full_plate and the text_socket.
func _make_fallback() -> Node3D:
	var root := Node3D.new()
	var post := _box(Vector3(0.08, POST_H + 0.1, 0.08), FRAME_WOOD)
	post.position = Vector3(0.0, (POST_H + 0.1) * 0.5, 0.0)
	root.add_child(post)
	var face := Node3D.new()
	face.name = "board"
	face.position = Vector3(0.0, POST_H, 0.0)
	face.rotation.x = -TILT
	root.add_child(face)
	var frame := _box(Vector3(BOARD_SIZE.x + 0.06, BOARD_SIZE.y + 0.06, 0.04), FRAME_WOOD)
	frame.position = Vector3(0.0, BOARD_SIZE.y * 0.5, -0.025)
	face.add_child(frame)
	var chalk := _box(Vector3(BOARD_SIZE.x, BOARD_SIZE.y, 0.02), BOARD_GREEN)
	chalk.position = Vector3(0.0, BOARD_SIZE.y * 0.5, 0.0)
	face.add_child(chalk)
	var plate := _box(Vector3(BOARD_SIZE.x - 0.08, 0.34, 0.01), PLATE_RED)
	plate.name = "full_plate"
	plate.position = Vector3(0.0, BOARD_SIZE.y * 0.5 + NUMBER_Y, 0.012)
	plate.visible = false
	face.add_child(plate)
	var sock := Node3D.new()
	sock.name = "text_socket"
	sock.position = Vector3(0.0, BOARD_SIZE.y * 0.5, 0.0)
	face.add_child(sock)
	return root


func _box(size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	bm.material = m
	mi.mesh = bm
	return mi


static func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadows(c)
