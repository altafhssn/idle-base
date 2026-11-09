class_name UiKit
extends RefCounted
## Static builders, palette and juice helpers for the v0.3 dhaba UI.
## Spec: docs/reference-match-spec.md section 4 (positions are on the 576-wide
## reference canvas; ours is 720 wide, so x1.25), juice J5-J8 and J14.
## Skin follows the critic: saffron, marigold, peacock teal and maroon,
## painted-tin / truck-art trims, khata paper cards and ORIGINAL procedural
## icons (UiIcon) - nothing is copied from the reference's art.
## UX fix (docs/ux_audit/build-contract.md 4.1, D1): station unit nouns
## (station_unit / station_unit_plural: cup, roti, glass, plate), ordinals
## ("2ND") and TitleGroup, the panel title with its small Hindi subtitle
## ("BUILD  daftar"), centred as one group with the baselines aligned.
## Language (launch blockers track B, scripts/autoload/loc.gd): t() / is_hindi()
## for static code; English literals given to a Label are msgids that Godot
## auto-translates (res://i18n/hi.po); in Hindi the "English + Hindi subtitle"
## pairs show the Hindi alone as the main label.

const REF_SCALE := 1.25          # 576 -> 720
const DESIGN_W := 720.0
const MAX_EMPLOYEES_DEFAULT := 3

# ---------------------------------------------------------------- palette
const INK := Color(0.23, 0.14, 0.08)            # brown ink (body text)
const INK_SOFT := Color(0.43, 0.34, 0.28)
const PILL_BG := Color(0.2, 0.07, 0.1, 0.9)     # kohl-maroon HUD pills
const SAFFRON := Color(0.95, 0.55, 0.16)        # primary action face
const MARIGOLD := Color(1.0, 0.71, 0.15)
const MARIGOLD_PALE := Color(1.0, 0.86, 0.5)
const TEAL := Color(0.05, 0.49, 0.53)           # peacock teal
const TEAL_DARK := Color(0.03, 0.33, 0.37)
const TEAL_LIGHT := Color(0.56, 0.85, 0.86)
const MAROON := Color(0.56, 0.11, 0.23)
const MAROON_DARK := Color(0.36, 0.06, 0.14)
const GAIN := Color(0.24, 0.62, 0.29)           # income / gain text
const GAIN_LIGHT := Color(0.58, 0.9, 0.5)
const WARN := Color(0.94, 0.53, 0.12)
const BAD := Color(0.85, 0.24, 0.18)
const FINE := Color(0.1, 0.55, 0.62)            # "ok" rows
const PAPER := Color(1.0, 0.965, 0.89)          # khata paper
const CARD := Color(1.0, 0.99, 0.97)
const BODY := Color(0.94, 0.9, 0.83)            # panel body / below the sheet
const GREY_FACE := Color(0.72, 0.69, 0.64)
const GREY_LIP := Color(0.55, 0.52, 0.48)
const BADGE_RED := Color(0.89, 0.23, 0.18)
const NOTE_GREEN := Color(0.49, 0.78, 0.5)      # matches the ART banknote
const NOTE_DARK := Color(0.12, 0.37, 0.29)
const CLAIM := Color(1.0, 0.68, 0.23)           # KAAM claim card
const CLAIM_DARK := Color(0.9, 0.5, 0.13)
const CLAIM_TEXT := Color(0.47, 0.19, 0.05)
const CREAM_BTN := Color(1.0, 0.95, 0.84)       # HUD square buttons
const SETTINGS_BG := Color(0.17, 0.13, 0.12, 0.88)
const MEHNDI := Color(0.33, 0.5, 0.17)          # CHARPAI SEATING header
const MEHNDI_DARK := Color(0.2, 0.33, 0.09)
const MEHNDI_LIGHT := Color(0.78, 0.89, 0.6)
const GHOST_CYAN := Color(0.36, 0.93, 1.0)      # ghost table / its price tag
const GHOST_BG := Color(0.02, 0.18, 0.22, 0.84)
const SEATS_PER_TABLE := 4                      # one table + two charpais

## UI-only station extras come from the pack: each station's economy entry
## "ui" = {icon, menu_icon, doodles, info} ("info" is an English msgid shown
## through t()); "unit" / "units" name one sale (Idle Business Kit phase 3).
const STATION_UI_DEFAULT := {"icon": "kulhad", "doodles": ["leaf", "steam"], "info": ""}

static var _font_bold: Font
static var _font_body: Font
static var _font_bold_italic: Font
static var _font_body_italic: Font


# ================================================================ fonts
## Baloo 2 ExtraBold (+ Noto fallbacks) for numbers and titles.
static func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = load("res://ui/main_font.tres") as Font
		if _font_bold == null:
			_font_bold = ThemeDB.fallback_font
	return _font_bold


## Baloo 2 Medium for body text.
static func font_body() -> Font:
	if _font_body == null:
		_font_body = _variation(500, false)
	return _font_body


static func font_bold_italic() -> Font:
	if _font_bold_italic == null:
		_font_bold_italic = _variation(800, true)
	return _font_bold_italic


static func font_body_italic() -> Font:
	if _font_body_italic == null:
		_font_body_italic = _variation(400, true)
	return _font_body_italic


static func _variation(weight: int, italic: bool) -> Font:
	var main: Font = font_bold()
	var fv := FontVariation.new()
	if main is FontVariation:
		var mv := main as FontVariation
		fv.base_font = mv.base_font
		fv.fallbacks = mv.fallbacks
	else:
		fv.base_font = main
	fv.variation_opentype = {2003265652: weight}  # 'wght'
	if italic:
		# Same slant FontVariation's docs use for a fake italic.
		fv.variation_transform = Transform2D(Vector2(1.0, 0.2), Vector2(0.0, 1.0), Vector2.ZERO)
	return fv


static func font_for(weight: String) -> Font:
	match weight:
		"body":
			return font_body()
		"bold_italic":
			return font_bold_italic()
		"body_italic":
			return font_body_italic()
	return font_bold()


# ================================================================ language
## Translation of an English msgid in the current language (static code;
## nodes use tr()). `ctx` = the msgctxt when one English word needs two
## different Hindi words.
static func t(msg: String, ctx: String = "") -> String:
	return str(TranslationServer.translate(msg, ctx))


## The UI shows Hindi (Loc's language; TranslationServer locale "hi").
static func is_hindi() -> bool:
	return TranslationServer.get_locale().begins_with("hi")


# ================================================================ builders
static func label(text: String, font_size: int, color: Color = Color.WHITE, outline: int = 0,
		outline_color: Color = INK, weight: String = "bold") -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font_for(weight))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", outline_color)
		l.add_theme_constant_override("outline_size", outline)
	l.add_theme_constant_override("line_spacing", -int(font_size * 0.32))
	return l


## Positions a control absolutely inside a non-container parent.
static func place(c: Control, pos: Vector2, sz: Vector2) -> Control:
	c.position = pos
	c.size = sz
	return c


## A label centred inside a box (used for absolute layouts).
static func label_in(parent: Control, text: String, pos: Vector2, sz: Vector2, font_size: int,
		color: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER,
		outline: int = 0, outline_color: Color = INK, weight: String = "bold") -> Label:
	var l := label(text, font_size, color, outline, outline_color, weight)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	place(l, pos, sz)
	return l


## Wrapped paragraph (top-left aligned).
static func para(parent: Control, text: String, pos: Vector2, width: float, font_size: int,
		color: Color = INK_SOFT, lines: int = 3) -> Label:
	var l := label(text, font_size, color, 0, INK, "body")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = lines
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	parent.add_child(l)
	place(l, pos, Vector2(width, font_size * 1.35 * lines))
	return l


static func box(color: Color, radius: float = 16.0, border: int = 0,
		border_color: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 6
	sb.anti_aliasing = true
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	return sb


## Plain rounded panel (mouse IGNORE unless `blocks`).
static func panel(color: Color, radius: float = 16.0, border: int = 0,
		border_color: Color = Color(0, 0, 0, 0), blocks: bool = false) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", box(color, radius, border, border_color))
	p.mouse_filter = Control.MOUSE_FILTER_STOP if blocks else Control.MOUSE_FILTER_IGNORE
	p.set_meta("ui_radius", radius)
	return p


## Painted-tin card: rounded, with a darker bottom lip.
static func card(color: Color = CARD, radius: float = 14.0, lip: int = 4) -> Panel:
	var p := panel(color, radius)
	var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null and lip > 0:
		sb.border_width_bottom = lip
		sb.border_color = color.darkened(0.16)
	return p


## Fully rounded pill.
static func pill(color: Color, sz: Vector2) -> Panel:
	var p := panel(color, sz.y * 0.5)
	p.size = sz
	p.custom_minimum_size = sz
	return p


static func candy_button(text: String, color: Color = SAFFRON, sz: Vector2 = Vector2(200, 72)) -> UiButton:
	return UiButton.new(text, color, sz)


static func icon(icon_name: String, sz: Vector2 = Vector2(48, 48), tint: Color = Color.WHITE,
		bg: Color = Color(0, 0, 0, 0)) -> UiIcon:
	return UiIcon.new(icon_name, sz, tint, bg)


## Red round close button (X) used by every panel and popup.
static func close_button(sz: float = 56.0) -> UiButton:
	var b := UiButton.new("", BADGE_RED, Vector2(sz, sz))
	b.radius = sz * 0.5
	b.lip_px = 4.0
	b.big_ring = true
	b.set_glyph("close", Vector2(sz * 0.62, sz * 0.62))
	return b


## Stats-row column: caption above, round icon, value below (spec 4.3).
## The value label is the child named "Value".
static func stat_column(caption: String, caption_color: Color, icon_name: String,
		icon_bg: Color, icon_tint: Color, value: String, width: float = 150.0) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size = Vector2(width, 0)
	var cap := label(caption, 17, caption_color)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	var ic := UiIcon.new(icon_name, Vector2(58, 58), icon_tint, icon_bg)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	var val := label(value, 23, caption_color)
	val.name = "Value"
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(val)
	return col


static func level_bar(sz: Vector2 = Vector2(600, 26)) -> UiLevelBar:
	return UiLevelBar.new(sz)


# ================================================================ juice (J5-J8)
## The pooled UiJuice drawer for the CanvasLayer that holds `c`.
static func juice_for(c: Node) -> UiJuice:
	if c == null or not c.is_inside_tree():
		return null
	var layer: Node = null
	if c is CanvasItem:
		layer = (c as CanvasItem).get_canvas_layer_node()
	if layer == null:
		layer = c.get_tree().root
	var j := layer.get_node_or_null("UiJuice") as UiJuice
	if j == null:
		j = UiJuice.new()
		layer.add_child(j)
	return j


## J5 button press: white flash 0.12 s, 3-5 sparkles, a 4-point star at the
## top-right, a 2 px halo growing to 1.3x, a scale punch, plus the J8 ripple
## (and the larger faint ring when `big_ring`, for purchases / closes).
static func press_juice(c: Control, big_ring: bool = false) -> void:
	if c == null or not c.is_visible_in_tree():
		return
	var j := juice_for(c)
	var r := c.get_global_rect()
	var rad: float = float(c.get_meta("ui_radius", minf(r.size.x, r.size.y) * 0.3))
	rad *= c.get_global_transform().get_scale().x
	if j != null:
		j.flash(r, rad, 0.5, 0.12)
		j.spark(r.get_center(), r.size * 0.5, randi_range(3, 5), Vector2(4, 6), Vector2(10, 15), 0.15)
		j.star(Vector2(r.end.x - 4.0, r.position.y + 4.0), 24.0, 0.15)
		j.rring(r, rad, 1.3, 0.2, 2.0)
		ripple_at(j, r.get_center(), maxf(r.size.x, r.size.y), big_ring)
	punch(c)


## J8 tap ripple on its own (hand presses, plain taps).
static func ripple(c: Control, big_ring: bool = false) -> void:
	if c == null or not c.is_visible_in_tree():
		return
	var j := juice_for(c)
	if j == null:
		return
	var r := c.get_global_rect()
	ripple_at(j, r.get_center(), maxf(r.size.x, r.size.y), big_ring)


static func ripple_at(j: UiJuice, center: Vector2, target_size: float, big_ring: bool) -> void:
	# Spec J8 is 10 -> 50 px on the 576 reference canvas: x1.25 on our 720 one.
	j.ring(center, 12.5, 62.5, 0.45, 3.0, Color.WHITE, 0.8)
	if big_ring:
		j.ring(center, target_size * 0.5, target_size * 0.9, 0.15, 3.0, Color.WHITE, 0.4)


## J6 delta-pill shine. Uses Fx.ui_shine when the FX autoload has it (it draws
## as a child of the control, so it shows above panels); else a local sweep.
static func shine(c: Control) -> void:
	if c == null or not c.is_visible_in_tree():
		return
	if fx_call("ui_shine", [c]):
		return
	var j := juice_for(c)
	if j == null:
		return
	var r := c.get_global_rect()
	var rad: float = float(c.get_meta("ui_radius", r.size.y * 0.5))
	j.band(r, rad, 0.15)
	j.flash(r, rad, 0.3, 0.1)


## Scale punch 1.0 -> 1.08 (+0.10..+0.17 s) -> 1.0 (+0.24 s).
static func punch(c: Control, amount: float = 1.08) -> void:
	if c.has_meta("_punch"):
		var old: Variant = c.get_meta("_punch")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE
	var tw := c.create_tween()
	tw.tween_interval(0.10)
	tw.tween_property(c, "scale", Vector2.ONE * amount, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	c.set_meta("_punch", tw)


## Alpha fade with a cancellable per-node tween. to == 0 hides at the end.
static func fade(c: CanvasItem, to: float, dur: float, delay: float = 0.0) -> Tween:
	if c.has_meta("_fade"):
		var old: Variant = c.get_meta("_fade")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	if to > 0.0:
		c.visible = true
	var tw := c.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", to, maxf(dur, 0.01))
	if to <= 0.0:
		tw.tween_callback(c.hide)
	c.set_meta("_fade", tw)
	return tw


static func kill_fade(c: CanvasItem) -> void:
	if c.has_meta("_fade"):
		var old: Variant = c.get_meta("_fade")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()


# ================================================================ screen / safe area
## Safe-area insets in canvas pixels: x = top, y = bottom.
static func safe_insets(vp: Viewport) -> Vector2:
	var vis: Vector2 = vp.get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if not OS.has_feature("mobile") or win.y <= 0.0:
		return Vector2(24.0, 0.0)
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var sy: float = vis.y / win.y
	return Vector2(maxf(float(safe.position.y) * sy, 0.0), maxf((win.y - float(safe.end.y)) * sy, 0.0))


## Top of the HUD band (the money pill's top edge).
static func hud_top(vp: Viewport) -> float:
	# Reference: money pill top at 88 ref px (x1.25 = 110) on a phone with no
	# notch; a deeper safe-area inset pushes it further down.
	return maxf(safe_insets(vp).x + 24.0, 110.0)


## Bottom edge for the bottom HUD buttons.
static func hud_bottom(vp: Viewport) -> float:
	# Reference: bottom buttons end ~48 ref px (60) above the screen edge.
	return vp.get_visible_rect().size.y - maxf(safe_insets(vp).y + 16.0, 60.0)


## Scale that fits a design-size box into the viewport with a margin.
static func fit_scale(vp: Viewport, design: Vector2, margin: Vector2 = Vector2(16, 40)) -> float:
	var vis: Vector2 = vp.get_visible_rect().size
	return minf(1.0, minf((vis.x - margin.x) / design.x, (vis.y - margin.y) / design.y))


# ================================================================ autoload / FX bridges
static func autoload(n: String) -> Node:
	var ml := Engine.get_main_loop() as SceneTree
	if ml == null or ml.root == null:
		return null
	return ml.root.get_node_or_null(n)


## Calls Fx.<method>(args...) when the FX autoload has it. Extra trailing
## arguments are dropped if the method takes fewer. Returns true if called.
static func fx_call(method: String, args: Array) -> bool:
	var fx: Node = autoload("Fx")
	if fx == null or not fx.has_method(method):
		return false
	var n: int = Callable(fx, method).get_argument_count()
	if n >= 0 and n < args.size():
		fx.callv(method, args.slice(0, n))
	else:
		fx.callv(method, args)
	return true


# ================================================================ game data helpers
static func station_ui(id: String) -> Dictionary:
	var u: Variant = Game.station_def(id).get("ui", null)
	if u is Dictionary and not (u as Dictionary).is_empty():
		return u
	return STATION_UI_DEFAULT


## "NAME / name_hi" when the station has a Hindi name (the menu-expansion
## stations; Baloo 2 has Devanagari, Noto Sans Devanagari is the fallback),
## else NAME. Hindi: the Hindi name alone ("लस्सी", "चाय काउंटर").
static func station_title(id: String) -> String:
	if is_hindi():
		return t(Game.station_name(id))
	var hi: String = Game.station_name_hi(id)
	if hi != "":
		return "%s / %s" % [Game.station_name(id), hi]
	return Game.station_name(id)


## Station name in the current language ("TANDOOR" / "तंदूर").
static func station_name(id: String) -> String:
	return t(Game.station_name(id))


## Dish name for sentences and MENU lines: English title case ("Keema
## Paratha"), Hindi "कीमा पराठा" (msgid = the economy's upper-case name).
static func dish_title(id: String, dish: String) -> String:
	if is_hindi():
		return t(Game.dish_name(id, dish))
	return Game.dish_title(id, dish)


static func station_color(id: String) -> Color:
	return Game.station_color(id)


## What one sale of the station is called (A6): the station's "unit" /
## "units" in the pack (the dhaba: cup, roti, glass, plate); "item" otherwise
## (translated, msgctxt "unit").
static func station_unit(id: String) -> String:
	return t(str(Game.station_def(id).get("unit", "item")), "unit")


static func station_unit_plural(id: String) -> String:
	return t(str(Game.station_def(id).get("units", "items")), "unit")


## 1 "1ST", 2 "2ND", 3 "3RD", 4 "4TH" ... (upper case; callers lower it).
## (Unused by the UI today; English only.)
static func ordinal(n: int) -> String:
	var suffix: String = "TH"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1:
				suffix = "ST"
			2:
				suffix = "ND"
			3:
				suffix = "RD"
	return "%d%s" % [n, suffix]


static func station_build_desc(id: String) -> String:
	return t(str(Game.station_def(id).get("build_desc", "")))


static func max_employees(id: String) -> int:
	return int(Game.station_employees_max(id))


## Money shown as an integer with Indian grouping (task progress, etc.).
static func money_int(v: float) -> String:
	return Fmt.int_floor(Fmt.display(v))


# ================================================================ duck-typed Game API
## The waiter / seating API (waiter_count, buy_table, ...) is added to Game by
## CORE in parallel, so the UI calls it by name: a missing method returns
## `fallback` instead of a parse error. `args` is trimmed to the method's
## declared argument count, so `waiter_level(i)` and `waiter_level()` both work.
static func gcall(method: String, args: Array = [], fallback: Variant = null) -> Variant:
	var g: Node = autoload("Game")
	if g == null or not g.has_method(method):
		return fallback
	var n: int = Callable(g, method).get_argument_count()
	var v: Variant
	if n >= 0 and n < args.size():
		v = g.callv(method, args.slice(0, n))
	else:
		v = g.callv(method, args)
	return fallback if v == null else v


static func gint(method: String, args: Array = [], fallback: int = 0) -> int:
	var v: Variant = gcall(method, args, fallback)
	if v is int or v is float:
		return int(v)
	return fallback


static func gfloat(method: String, args: Array = [], fallback: float = 0.0) -> float:
	var v: Variant = gcall(method, args, fallback)
	if v is int or v is float:
		return float(v)
	return fallback


static func gbool(method: String, args: Array = [], fallback: bool = false) -> bool:
	var v: Variant = gcall(method, args, fallback)
	if v is bool:
		return v
	if v is int or v is float:
		return float(v) != 0.0
	return fallback


static func gstr(method: String, args: Array = [], fallback: String = "") -> String:
	var v: Variant = gcall(method, args, fallback)
	if v is String or v is StringName:
		return str(v)
	return fallback


## Connects `target` to a Game signal if it exists, whatever its argument
## count (extra arguments are dropped). Returns false when Game lacks it.
static func gconnect(sig: String, target: Callable) -> bool:
	var g: Node = autoload("Game")
	if g == null or not g.has_signal(sig):
		return false
	var n: int = 0
	for s in g.get_signal_list():
		var d: Dictionary = s
		if str(d.get("name", "")) == sig:
			var a: Variant = d.get("args", [])
			if a is Array:
				n = (a as Array).size()
			break
	g.connect(sig, target.unbind(n) if n > 0 else target)
	return true


## First present key of `keys` in a stats dictionary ("" when none).
static func stat_key(st: Dictionary, keys: Array) -> String:
	for k in keys:
		if st.has(str(k)):
			return str(k)
	return ""


## Ratio 0..1 from a stat that may be a ratio or a percentage.
static func as_ratio(v: float) -> float:
	return v / 100.0 if v > 1.0 else v


## Waiter display names: Game.waiter_staff_name(i) (economy "waiters.names":
## Raju, Shambhu, Lakhan), else Game.waiter_name(i), else a local list.
static func waiter_name(i: int) -> String:
	var n: String = gstr("waiter_staff_name", [i], "")
	if n == "":
		n = gstr("waiter_name", [i], "")
	if n != "":
		return n
	var names: Array = ["Raju", "Shambhu", "Lakhan", "Golu", "Bittu"]
	return str(names[posmod(i, names.size())])


## A staff member's name as shown (Devanagari in Hindi: "Raju" -> "राजू").
## Game's own names stay English: the world matches models by them.
static func person(n: String) -> String:
	return t(n, "name") if n != "" else n


## Seats per table set (Game.seats_per_table(), else 4).
static func seats_per_table() -> int:
	return maxi(1, gint("seats_per_table", [], SEATS_PER_TABLE))


# ================================================================ panel title (D1)
## A panel title: the English function word (bold, outlined) plus an
## optional Hindi subtitle (body italic, white at 80 %), 12 px to its right
## with the baselines aligned; the pair is centred horizontally in the
## control and the title's caps are centred vertically (as a centred Label).
## Hindi: the subtitle's Hindi word (msgctxt "title": "daftar" -> "दफ़्तर") is
## the main label and there is no subtitle; without a subtitle the title is
## translated. Redrawn live on a language change.
class TitleGroup extends Control:
	const GAP := 12.0
	var title: String = ""
	var subtitle: String = ""
	var title_px: int = 46
	var sub_px: int = 24
	var outline_px: int = 8
	var outline_color: Color = Color(0, 0, 0, 0.35)
	var title_color: Color = Color.WHITE
	var sub_color: Color = Color(1, 1, 1, 0.8)

	func _init(p_title: String = "", p_sub: String = "", p_px: int = 46, p_outline: Color = Color(0, 0, 0, 0.35)) -> void:
		title = p_title
		subtitle = p_sub
		title_px = p_px
		outline_color = p_outline
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_text(p_title: String, p_sub: String = "") -> void:
		if p_title == title and p_sub == subtitle:
			return
		title = p_title
		subtitle = p_sub
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSLATION_CHANGED:
			queue_redraw()

	## [main label, subtitle] as drawn in the current language.
	func shown() -> PackedStringArray:
		if UiKit.is_hindi():
			if subtitle != "":
				return PackedStringArray([UiKit.t(subtitle, "title"), ""])
			return PackedStringArray([UiKit.t(title, "title"), ""])
		return PackedStringArray([title, subtitle])

	## Left x of the title and right x of the group (control-local).
	func group_span() -> Vector2:
		var txt: PackedStringArray = shown()
		var tw: float = UiKit.font_bold().get_string_size(txt[0], HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x
		var total: float = tw
		if txt[1] != "":
			total += GAP + UiKit.font_body_italic().get_string_size(txt[1], HORIZONTAL_ALIGNMENT_LEFT, -1, sub_px).x
		var x0: float = (size.x - total) * 0.5
		return Vector2(x0, x0 + total)

	func _draw() -> void:
		var f: Font = UiKit.font_bold()
		var txt: PackedStringArray = shown()
		var span: Vector2 = group_span()
		var base_y: float = size.y * 0.5 + (f.get_ascent(title_px) - f.get_descent(title_px)) * 0.5
		var x: float = span.x
		if outline_px > 0:
			draw_string_outline(f, Vector2(x, base_y), txt[0], HORIZONTAL_ALIGNMENT_LEFT, -1, title_px, outline_px, outline_color)
		draw_string(f, Vector2(x, base_y), txt[0], HORIZONTAL_ALIGNMENT_LEFT, -1, title_px, title_color)
		if txt[1] == "":
			return
		x += f.get_string_size(txt[0], HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x + GAP
		var fs: Font = UiKit.font_body_italic()
		draw_string(fs, Vector2(x, base_y), txt[1], HORIZONTAL_ALIGNMENT_LEFT, -1, sub_px, sub_color)
