class_name PhonePopup
extends Control
## Story (owner's design, 4 Nov 2026): the PHONE popup, Simran's chat. UiRoot
## creates it on the popup layer and opens it with open_phone() as popup
## "phone" (50 % dim; an outside tap or the X closes it).
##  - Header (teal): Simran's round picture (AVATAR_PATH when it exists, else
##    a pink disc with an "S"), "SIMRAN" and a small "online" line.
##  - Under it the story card: "IMPRESS HER FATHER" with three hearts, one
##    filled per visit of her father (Game.story_visits()).
##  - Her messages, oldest first, as white bubbles on the left with their
##    time (Game.phone_inbox()), scrolled to the newest; "No messages yet."
##    while there are none. A message with a reply (Story.REPLIES) gets the
##    player's answer under it: a green bubble on the right, typed in
##    REPLY_DELAY s after the popup opens while the message is new.
## Opening it reads everything (Game.phone_read_all()).
## Signal: close_pressed (X). Captions and messages are English msgids the
## labels auto-translate.

signal close_pressed

const DESIGN := Vector2(600, 900)
const HEAD_H := 112.0
const CARD_H := 72.0
const PAD := 24.0
const BUBBLE_W := 430.0
const AVATAR := 72.0
static var AVATAR_PATH: String = ThemePack.textures_dir() + "story/simran_avatar.png"
const HEART_PINK := Color(0.93, 0.3, 0.45)
const BUBBLE_INK := Color(0.2, 0.15, 0.13)
const MINE_FILL := Color(0.86, 0.96, 0.82)
const MINE_EDGE := Color(0.55, 0.78, 0.5)
const REPLY_DELAY := 0.9

var close_button: UiButton
var _body: Control
var _scroll: ScrollContainer
var _list: VBoxContainer
var _empty: Label
var _hearts: _Hearts


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func open() -> void:
	_refresh()
	UiKit.kill_fade(self)
	visible = true
	modulate.a = 1.0
	UiKit.gcall("phone_read_all", [])
	_scroll_to_end.call_deferred()


func close() -> void:
	if visible:
		UiKit.fade(self, 0.0, 0.1)


func is_open() -> bool:
	return visible and modulate.a > 0.0


## Tests: the bubbles' texts, top to bottom.
func bubble_texts() -> Array:
	var out: Array = []
	for c in _list.get_children():
		var l: Variant = (c as Node).get_meta("text", null)
		if l != null:
			out.append(str(l))
	return out


func _build() -> void:
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.size = DESIGN
	add_child(_body)
	var card: Panel = UiKit.panel(UiKit.PAPER, 26.0, 4, UiKit.TEAL_DARK)
	_body.add_child(card)
	UiKit.place(card, Vector2.ZERO, DESIGN)

	var head := Panel.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hsb: StyleBoxFlat = UiKit.box(UiKit.TEAL_DARK, 0.0)
	hsb.corner_radius_top_left = 26
	hsb.corner_radius_top_right = 26
	hsb.border_width_bottom = 5
	hsb.border_color = HEART_PINK
	head.add_theme_stylebox_override("panel", hsb)
	_body.add_child(head)
	UiKit.place(head, Vector2.ZERO, Vector2(DESIGN.x, HEAD_H))
	head.add_child(_avatar())
	UiKit.label_in(head, "SIMRAN", Vector2(PAD + AVATAR + 18.0, 18), Vector2(320, 46), 34, Color.WHITE,
			HORIZONTAL_ALIGNMENT_LEFT, 5, UiKit.TEAL_DARK)
	UiKit.label_in(head, "online", Vector2(PAD + AVATAR + 20.0, 62), Vector2(320, 30), 21, UiKit.TEAL_LIGHT,
			HORIZONTAL_ALIGNMENT_LEFT)
	close_button = UiKit.close_button(52.0)
	close_button.position = Vector2(DESIGN.x - 68.0, (HEAD_H - 52.0) * 0.5)
	close_button.tapped.connect(_on_close)
	head.add_child(close_button)

	# The story card: her father, won over one visit at a time.
	var sc: Panel = UiKit.panel(Color(1.0, 0.92, 0.93), 16.0, 2, Color(0.93, 0.6, 0.68))
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(sc)
	UiKit.place(sc, Vector2(PAD, HEAD_H + 16.0), Vector2(DESIGN.x - PAD * 2.0, CARD_H))
	UiKit.label_in(sc, "IMPRESS HER FATHER", Vector2(20, 0), Vector2(330, CARD_H), 25, UiKit.MAROON,
			HORIZONTAL_ALIGNMENT_LEFT)
	_hearts = _Hearts.new()
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(_hearts)
	UiKit.place(_hearts, Vector2(sc.size.x - 172.0, 12), Vector2(152, CARD_H - 24.0))

	var top: float = HEAD_H + 16.0 + CARD_H + 14.0
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.add_child(_scroll)
	UiKit.place(_scroll, Vector2(PAD, top), Vector2(DESIGN.x - PAD * 2.0, DESIGN.y - top - PAD))
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	_scroll.add_child(_list)
	_empty = UiKit.label_in(_body, "No messages yet.", Vector2(0, top + 40.0), Vector2(DESIGN.x, 40), 24,
			UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)


## Simran's picture in a circle; a pink disc with an "S" until the art lands.
func _avatar() -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(holder, Vector2(PAD, (HEAD_H - AVATAR) * 0.5), Vector2(AVATAR, AVATAR))
	var disc: Panel = UiKit.panel(HEART_PINK, AVATAR * 0.5, 3, Color.WHITE)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	holder.add_child(disc)
	UiKit.place(disc, Vector2.ZERO, Vector2(AVATAR, AVATAR))
	if ResourceLoader.exists(AVATAR_PATH):
		var pic := TextureRect.new()
		pic.texture = load(AVATAR_PATH) as Texture2D
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.add_child(pic)
		UiKit.place(pic, Vector2.ZERO, Vector2(AVATAR, AVATAR))
	else:
		UiKit.label_in(disc, "S", Vector2.ZERO, Vector2(AVATAR, AVATAR - 4.0), 40, Color.WHITE,
				HORIZONTAL_ALIGNMENT_CENTER, 4, Color(0.7, 0.18, 0.3))
	return holder


func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var s: float = UiKit.fit_scale(get_viewport(), DESIGN, Vector2(40, 80))
	_body.scale = Vector2(s, s)
	_body.position = ((vp - DESIGN * s) * 0.5).round()


func _refresh() -> void:
	_hearts.filled = int(UiKit.gcall("story_visits", [], 0))
	_hearts.queue_redraw()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var inbox: Variant = UiKit.gcall("phone_inbox", [], [])
	var msgs: Array = inbox if inbox is Array else []
	_empty.visible = msgs.is_empty()
	for mv in msgs:
		var m: Dictionary = mv
		var fresh: bool = not bool(m.get("read", true))
		_list.add_child(_bubble(str(m.get("text", "")), float(m.get("unix", 0.0)), fresh))
		var reply: String = str(m.get("reply", ""))
		if reply != "":
			var mine: Control = _bubble(reply, float(m.get("unix", 0.0)), false, true)
			_list.add_child(mine)
			if fresh:
				mine.modulate.a = 0.0
				var tw := mine.create_tween()
				tw.tween_interval(REPLY_DELAY)
				tw.tween_property(mine, "modulate:a", 1.0, 0.2)
				tw.tween_callback(_scroll_to_end)


## One message: a white bubble (pale pink while new) and its time under it;
## `mine`: the player's reply, a green bubble on the right.
func _bubble(text: String, unix: float, fresh: bool, mine: bool = false) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.set_meta("text", text)
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
	var fill: Color = MINE_FILL if mine else (Color(1.0, 0.94, 0.95) if fresh else UiKit.CARD)
	var edge: Color = MINE_EDGE if mine else (Color(0.93, 0.6, 0.68) if fresh else Color(0.86, 0.8, 0.72))
	var sb: StyleBoxFlat = UiKit.box(fill, 20.0, 2, edge)
	if mine:
		sb.corner_radius_top_right = 6
	else:
		sb.corner_radius_top_left = 6
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	pc.add_theme_stylebox_override("panel", sb)
	var l: Label = UiKit.label(text, 25, BUBBLE_INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(BUBBLE_W - 40.0, 0)
	pc.add_child(l)
	row.add_child(pc)
	var t: Label = UiKit.label(_clock(unix), 18, UiKit.INK_SOFT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mine else HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(t)
	# A short message gets a narrower bubble (the label's minimum width is
	# its one-line width when that is smaller).
	var one_line: float = l.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			l.get_theme_font_size("font_size")).x
	if one_line < BUBBLE_W - 40.0:
		l.custom_minimum_size = Vector2(one_line + 2.0, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return row


## "14:05" in the phone's own time zone.
static func _clock(unix: float) -> String:
	if unix <= 0.0:
		return ""
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(int(unix) + bias * 60)
	return "%02d:%02d" % [int(d.get("hour", 0)), int(d.get("minute", 0))]


func _scroll_to_end() -> void:
	if _scroll == null:
		return
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _on_close() -> void:
	close_button.juice()
	close_pressed.emit()


## Three hearts, `filled` of them pink, the rest outlined.
class _Hearts:
	extends Control
	var filled: int = 0

	func _draw() -> void:
		var r: float = minf(size.y * 0.5, size.x / 6.0)
		for i in 3:
			var c := Vector2(size.x * (float(i) + 0.5) / 3.0, size.y * 0.5)
			_heart(c, r * 0.95, i < filled)

	func _heart(c: Vector2, r: float, on: bool) -> void:
		var pts := PackedVector2Array()
		for k in 48:
			var t: float = TAU * float(k) / 48.0
			# The classic heart curve, scaled to radius r.
			var x: float = 16.0 * pow(sin(t), 3)
			var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
			pts.append(c + Vector2(x, y) * (r / 17.0))
		if on:
			draw_colored_polygon(pts, PhonePopup.HEART_PINK)
		pts.append(pts[0])
		draw_polyline(pts, PhonePopup.HEART_PINK.darkened(0.2) if on else Color(0.85, 0.62, 0.68), 3.0, true)
