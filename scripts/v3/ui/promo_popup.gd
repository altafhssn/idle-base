extends Control
## Core and feel (W2-ROOT, build plan C5.2 / C6.1 / C6.3): the carry-over
## popup of a promotion, shown before the player commits. UiRoot creates it on
## the popup layer (loaded by path, no class_name), opens it with
## open_promo(kind, target) as popup "promo" and owns the 50 % dim.
##  kind "renovation" (FAMILY DHABA · Renovate the dhaba) or "move" (NH 48 ·
##  RAJASTHAN · Open a new dhaba on a new highway; target = the location id).
##  - Locked (renovation_state() / location_state(target) not unlocked): the
##    picture (reno_before -> reno_after, or nh48_preview; a coloured panel
##    when a texture is missing), "PRICES ×{a} → ×{b} FOREVER", the lock
##    reason and a grey LOCKED button.
##  - Unlocked: "PRICES ×{a} → ×{b} FOREVER", KEEPS / RESETS / ADDS from
##    Game.renovation_preview() / move_preview(target) (msgids, {mult} filled
##    with mult_after), the honest takings line (renovation), "Save {money}"
##    while the cash is short, and the primary button RENOVATE / MOVE TO NH 48
##    with the price (grey and a deny shake while unaffordable).
## Signals: close_pressed (X), action(id) "promo_renovate" / "promo_move" when
## the primary button is pressed on a ready, affordable promotion (UiRoot
## closes everything, then calls Game.renovate() / Game.move_highway(id)).
## Gate ids: "promo_button" (the primary button), "panel_close" (the X).
## Anchor: primary_button ("promo_button").

signal close_pressed
signal action(id: String)

const W := 690.0
const HEAD_H := 96.0
const PIC_SIZE := Vector2(300, 200)
const PIC_ONE := Vector2(420, 280)
const BTN_SIZE := Vector2(420, 92)
const ITEM_PX := 18
const ITEM_H := 30.0
static var RENO_BEFORE: String = ThemePack.textures_dir() + "reno_before.png"
static var RENO_AFTER: String = ThemePack.textures_dir() + "reno_after.png"
static var NH48_PREVIEW: String = ThemePack.textures_dir() + "nh48_preview.png"

var gate: Callable = Callable()
## "renovation" | "move".
var kind: String = "renovation"
## The location id of a move ("nh48").
var target: String = ""
var close_button: UiButton
var primary_button: UiButton
## The last open() found the promotion unlocked (KEEPS / RESETS / ADDS shown)
## and affordable.
var unlocked_now: bool = false
var affordable_now: bool = false

var _body: Control
var _title: Label
var _paper: Panel
var _content: Control
var _design: Vector2 = Vector2(W, 900)
## The "Save {money}" / lock reason Label of the last _fill() (null when none).
var _reason_label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	get_viewport().size_changed.connect(_layout)
	Game.cash_changed.connect(_on_cash_changed)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		_fill()


func open(p_kind: String, p_target: String = "") -> void:
	kind = "move" if p_kind == "move" else "renovation"
	target = p_target
	_fill()
	visible = true
	modulate.a = 1.0
	UiKit.kill_fade(self)


func close() -> void:
	if visible:
		UiKit.fade(self, 0.0, 0.1)


func is_open() -> bool:
	return visible and modulate.a > 0.5


## {unlocked, affordable, cost, reason_text, short, ...} of this promotion.
func state() -> Dictionary:
	return Game.renovation_state() if kind == "renovation" else Game.location_state(target)


func preview() -> Dictionary:
	return Game.renovation_preview() if kind == "renovation" else Game.move_preview(target)


# ================================================================ build
func _build() -> void:
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_body)
	_paper = Panel.new()
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb: StyleBoxFlat = UiKit.box(UiKit.PAPER, 0.0)
	psb.corner_radius_bottom_left = 24
	psb.corner_radius_bottom_right = 24
	_paper.add_theme_stylebox_override("panel", psb)
	_body.add_child(_paper)
	var head := Panel.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hsb: StyleBoxFlat = UiKit.box(UiKit.MAROON, 0.0)
	hsb.corner_radius_top_left = 24
	hsb.corner_radius_top_right = 24
	hsb.border_width_bottom = 5
	hsb.border_color = UiKit.MARIGOLD
	head.add_theme_stylebox_override("panel", hsb)
	_body.add_child(head)
	UiKit.place(head, Vector2.ZERO, Vector2(W, HEAD_H))
	_title = UiKit.label_in(head, "", Vector2(30, 16), Vector2(W - 120.0, 64), 34, Color.WHITE,
			HORIZONTAL_ALIGNMENT_LEFT, 6, UiKit.MAROON_DARK)
	close_button = UiKit.close_button(54.0)
	close_button.position = Vector2(W - 72.0, 20.0)
	close_button.tapped.connect(_on_close)
	head.add_child(close_button)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_content)
	UiKit.place(_content, Vector2(0, HEAD_H), Vector2(W, 10))


## Rebuilds the content for kind / target in the current state.
func _fill() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	primary_button = null
	_reason_label = null
	var st: Dictionary = state()
	var pv: Dictionary = preview()
	unlocked_now = bool(st.get("unlocked", false))
	affordable_now = bool(st.get("affordable", false))
	var unlocked: bool = unlocked_now
	var affordable: bool = affordable_now
	var reno: bool = kind == "renovation"
	_title.text = "FAMILY DHABA" if reno else "NH 48 · RAJASTHAN"
	var y: float = 14.0
	UiKit.label_in(_content, "Renovate the dhaba" if reno else "Open a new dhaba on a new highway", Vector2(20, y),
			Vector2(W - 40.0, 34), 22, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, 0, UiKit.INK, "body")
	y += 46.0
	if not unlocked:
		y = _picture(y) + 16.0
	y = _prices_banner(y, float(pv.get("mult_before", 1.0)), float(pv.get("mult_after", 2.0))) + 14.0
	if unlocked:
		var mult: String = _mult_text(float(pv.get("mult_after", 2.0)))
		y = _section(y, "KEEPS", pv.get("keeps", []), "check", UiKit.GAIN, mult)
		y = _section(y, "RESETS", pv.get("resets", []), "excl", UiKit.WARN, mult)
		y = _section(y, "ADDS", pv.get("adds", []), "plus", UiKit.TEAL, mult)
		var honest: String = str(pv.get("honest", ""))
		if honest != "":
			var hl: Label = UiKit.label_in(_content, honest, Vector2(30, y), Vector2(W - 60.0, 56), 19, UiKit.INK_SOFT,
					HORIZONTAL_ALIGNMENT_CENTER, 0, UiKit.INK, "body_italic")
			hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			y += 62.0
		if not affordable:
			y = _reason(y, st) + 4.0
	else:
		y = _reason(y, st) + 6.0
	y += 6.0
	var caption: String = "LOCKED"
	if unlocked:
		caption = "RENOVATE" if reno else "MOVE TO NH 48"
	var face: Color = UiKit.SAFFRON if unlocked else UiKit.GREY_FACE
	var b := UiButton.new(caption, face, BTN_SIZE)
	b.name = "PromoButton"
	b.set_font_sizes(30, 24)
	b.big_ring = true
	b.press_sound = "build_done" if unlocked else "tap"
	_content.add_child(b)
	b.position = Vector2((W - BTN_SIZE.x) * 0.5, y)
	if unlocked:
		b.set_cost(Fmt.price(float(st.get("cost", 0.0))))
		b.set_affordable(affordable)
	else:
		b.set_affordable(false)
	b.tapped.connect(_on_primary)
	primary_button = b
	y += BTN_SIZE.y + 24.0
	_content.size = Vector2(W, y)
	_design = Vector2(W, HEAD_H + y)
	UiKit.place(_paper, Vector2(0, HEAD_H), Vector2(W, y))
	_body.size = _design
	_layout()


## The before -> after picture (renovation) or the NH 48 preview (move).
func _picture(y: float) -> float:
	if kind == "renovation":
		var gap: float = W - 2.0 * PIC_SIZE.x - 40.0
		_pic(RENO_BEFORE, Vector2(20, y), PIC_SIZE, UiKit.MEHNDI_LIGHT, "house")
		_pic(RENO_AFTER, Vector2(W - 20.0 - PIC_SIZE.x, y), PIC_SIZE, UiKit.TEAL_LIGHT, "family_hall")
		var arrow := UiIcon.new("arrow_up", Vector2(gap, gap), UiKit.MAROON)
		arrow.rotation = PI * 0.5
		arrow.pivot_offset = Vector2(gap, gap) * 0.5
		arrow.position = Vector2(20.0 + PIC_SIZE.x, y + (PIC_SIZE.y - gap) * 0.5)
		_content.add_child(arrow)
		return y + PIC_SIZE.y
	_pic(NH48_PREVIEW, Vector2((W - PIC_ONE.x) * 0.5, y), PIC_ONE, UiKit.MARIGOLD_PALE, "highway")
	return y + PIC_ONE.y


func _pic(path: String, pos: Vector2, sz: Vector2, fallback: Color, glyph: String) -> void:
	var frame: Panel = UiKit.panel(fallback, 14.0, 3, UiKit.MAROON)
	frame.clip_contents = true
	_content.add_child(frame)
	UiKit.place(frame, pos, sz)
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var r: Resource = load(path)
		if r is Texture2D:
			tex = r
	if tex != null:
		var tr_: TextureRect = TextureRect.new()
		tr_.texture = tex
		tr_.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame.add_child(tr_)
		UiKit.place(tr_, Vector2(3, 3), sz - Vector2(6, 6))
	else:
		var isz := Vector2(sz.y * 0.6, sz.y * 0.6)
		var ic := UiIcon.new(glyph, isz, Color.WHITE)
		ic.position = (sz - isz) * 0.5
		frame.add_child(ic)


## "PRICES ×1 → ×2 FOREVER" on a marigold band.
func _prices_banner(y: float, a: float, b: float) -> float:
	var band: Panel = UiKit.panel(UiKit.MARIGOLD, 30.0, 3, UiKit.MAROON)
	_content.add_child(band)
	UiKit.place(band, Vector2(40, y), Vector2(W - 80.0, 60))
	var txt: String = tr("PRICES ×{a} → ×{b} FOREVER").replace("{a}", _mult_text(a)).replace("{b}", _mult_text(b))
	var px: int = 28
	var f: Font = UiKit.font_bold()
	while px > 18 and f != null and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > W - 110.0:
		px -= 1
	var l: Label = UiKit.label_in(band, txt, Vector2(0, 0), Vector2(W - 80.0, 60), px, UiKit.MAROON_DARK)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return y + 60.0


## A KEEPS / RESETS / ADDS block: header, then one row per msgid with a glyph.
func _section(y: float, head: String, items: Variant, glyph: String, col: Color, mult: String) -> float:
	if not (items is Array) or (items as Array).is_empty():
		return y
	UiKit.label_in(_content, head, Vector2(36, y), Vector2(W - 72.0, 32), 21, col, HORIZONTAL_ALIGNMENT_LEFT)
	y += 34.0
	var f: Font = UiKit.font_body()
	for it in items:
		var txt: String = tr(str(it)).replace("{mult}", mult)
		var ic := UiIcon.new(glyph, Vector2(24, 24), Color.WHITE, col)
		ic.bg_shape = "rounded"
		ic.pad = 0.2
		ic.position = Vector2(40, y + 3.0)
		_content.add_child(ic)
		var lines: int = 1
		if f != null and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, ITEM_PX).x > W - 130.0:
			lines = 2
		var l: Label = UiKit.label_in(_content, txt, Vector2(76, y - 2.0), Vector2(W - 112.0, ITEM_H * float(lines)), ITEM_PX,
				UiKit.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, UiKit.INK, "body")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		y += ITEM_H * float(lines)
	return y + 10.0


## The lock reason ("Opens when all 16 dishes are on the menu", "Opens after
## the Family Dhaba, with every counter at Lv 100") or "Save {money}".
func _reason(y: float, st: Dictionary) -> float:
	var txt: String = str(st.get("reason_text", ""))
	if txt == "":
		txt = "Opens when all 16 dishes are on the menu" if kind == "renovation" \
				else "Opens after the Family Dhaba, with every counter at Lv 100"
	var shown: String = tr(txt).replace("{money}", Fmt.money(float(st.get("short", 0.0))))
	var l: Label = UiKit.label_in(_content, shown, Vector2(30, y), Vector2(W - 60.0, 58), 21,
			UiKit.BAD if str(st.get("reason", "")) == "cash" else UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_reason_label = l
	return y + 60.0


## "2", "3", "1.5" (×{mult}).
static func _mult_text(m: float) -> String:
	if absf(m - roundf(m)) < 0.01:
		return "%d" % int(roundf(m))
	return "%.1f" % m


func _layout() -> void:
	if _body == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var s: float = UiKit.fit_scale(get_viewport(), _design, Vector2(24, 60))
	_body.scale = Vector2(s, s)
	_body.position = ((vp - _design * s) * 0.5).round()


## Sales keep coming in while the popup is open: rebuild when the promotion
## turns affordable (or stops being), else keep "Save {money}" counting down.
func _on_cash_changed(_cash: float) -> void:
	if not visible or not is_node_ready():
		return
	var st: Dictionary = state()
	if bool(st.get("unlocked", false)) != unlocked_now or bool(st.get("affordable", false)) != affordable_now:
		_fill()
	elif unlocked_now and not affordable_now and is_instance_valid(_reason_label):
		var txt: String = str(st.get("reason_text", ""))
		if txt != "":
			_reason_label.text = tr(txt).replace("{money}", Fmt.money(float(st.get("short", 0.0))))


# ================================================================ actions
func _allowed(id: String) -> bool:
	return not gate.is_valid() or bool(gate.call(id))


func _on_close() -> void:
	if not _allowed("panel_close"):
		return
	close_button.juice()
	close_pressed.emit()


func _on_primary() -> void:
	if not _allowed("promo_button") or primary_button == null:
		return
	# Re-read the state: the cash may have changed since the popup opened.
	var st: Dictionary = state()
	if not bool(st.get("unlocked", false)) or not bool(st.get("affordable", false)):
		primary_button.deny()
		if bool(st.get("unlocked", false)) != unlocked_now or bool(st.get("affordable", false)) != affordable_now:
			_fill()
		return
	primary_button.juice()
	action.emit("promo_renovate" if kind == "renovation" else "promo_move")
