extends UiFullPanel
## Owner decision 5 Nov: the MENU panel, every counter's dish upgrades in one
## place, reachable from anywhere (the HUD's MENU button; UiRoot loads this by
## path and opens it as panel "menu" with open_menu()). A full-screen panel
## like STAFF: a maroon header "MENU", then one row per counter
## (Game.station_ids()):
##  - built: the counter's icon, name and "Lv n", the next level's gain
##    ("+{money}/min next level", or "MAX" when maxed), the next dish with a
##    bar to its level ("Next dish at Lv 50: Mango Lassi"; "Every dish is on
##    the menu" once all are), a LEVEL UP button with its price
##    (Game.buy_level, like the counter sheet's), and MORE › (the counter's
##    own sheet: cooks, speed, every dish);
##  - not built: greyed, "Build it in BUILD".
## Actions: "menu_level_<id>" after a level is bought, "menu_open_<id>" for
## MORE › (UiRoot closes MENU and opens that counter's sheet). Gate ids: the
## same, and "panel_close". Refreshed every POLL s while open and on cash.

const ROWS_TOP := 200.0
const ROW_H := 176.0
const MENU_GAP := 16.0
const BAR_SIZE := Vector2(300, 18)
const MORE_SIZE := Vector2(120, 48)

var _rows: Dictionary = {}     # station id -> {card, name, lvl, gain, dish, bar, btn, more, locked}
var _sig: String = ""


func _configure() -> void:
	title_text = "MENU"
	header_color = UiKit.MAROON
	header_dark = UiKit.MAROON_DARK
	tile_color = UiKit.MARIGOLD_PALE
	doodles = PackedStringArray(["kulhad", "steam", "flower"])


func _build_body() -> void:
	pass


func _connect_game() -> void:
	UiKit.gconnect("station_changed", _on_station_changed)


func _before_open() -> void:
	_rebuild()


func _staged_controls() -> Array:
	var out: Array = []
	for id in _ids():
		if _rows.has(id):
			out.append((_rows[id] as Dictionary)["card"])
	return out


func _on_poll() -> void:
	refresh()


func _on_station_changed(_id: String = "") -> void:
	if visible:
		refresh()


static func _ids() -> Array:
	var out: Array = []
	for v in Game.station_ids():
		out.append(str(v))
	return out


func _rebuild() -> void:
	for id in _rows.keys():
		((_rows[id] as Dictionary)["card"] as Node).queue_free()
	_rows.clear()
	var ids: Array = _ids()
	var y: float = ROWS_TOP
	for id: String in ids:
		_rows[id] = _make_row(id, y)
		y += ROW_H + MENU_GAP
	_sig = ",".join(PackedStringArray(ids))
	refresh()


func _make_row(id: String, y: float) -> Dictionary:
	var card: Panel = _row_card(y, ROW_H)
	card.name = "Menu_" + id
	var ic := UiIcon.new(str(UiKit.station_ui(id).get("menu_icon", "bowl")), Vector2(84, 84), Color.WHITE, UiKit.MARIGOLD_PALE)
	ic.pad = 0.1
	ic.position = Vector2(16, 20)
	card.add_child(ic)
	var name_l: Label = UiKit.label_in(card, "", Vector2(116, 10), Vector2(330, 40), 26, UiKit.MAROON, HORIZONTAL_ALIGNMENT_LEFT)
	name_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var lvl: Label = UiKit.label_in(card, "", Vector2(116, 48), Vector2(330, 30), 20, UiKit.TEAL_DARK, HORIZONTAL_ALIGNMENT_LEFT)
	lvl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var gain: Label = UiKit.label_in(card, "", Vector2(116, 78), Vector2(330, 28), 19, UiKit.GAIN, HORIZONTAL_ALIGNMENT_LEFT,
			0, UiKit.INK, "body")
	gain.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var dish: Label = UiKit.label_in(card, "", Vector2(20, 112), Vector2(430, 28), 18, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT,
			0, UiKit.INK, "body")
	dish.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	dish.clip_text = true
	var bar: UiLevelBar = UiKit.level_bar(BAR_SIZE)
	bar.set_colors(Color(0.98, 0.9, 0.8), UiKit.SAFFRON)
	card.add_child(bar)
	bar.position = Vector2(20, 144)
	var btn: UiButton = _row_button(card, "LEVEL UP", 20.0)
	btn.name = "Level_" + id
	btn.tapped.connect(_on_level.bind(id))
	var more := UiButton.new("MORE ›", UiKit.CREAM_BTN, MORE_SIZE)
	more.name = "More_" + id
	more.set_font_sizes(19)
	more.set_caption_color(UiKit.TEAL_DARK, Color(0, 0, 0, 0), 0)
	card.add_child(more)
	more.position = Vector2(690.0 - BTN_SIZE.x - 18.0 + (BTN_SIZE.x - MORE_SIZE.x) * 0.5, 108.0)
	more.tapped.connect(_on_more.bind(id))
	var locked: Label = UiKit.label_in(card, "Build it in BUILD", Vector2(460, 50), Vector2(210, 60), 20, UiKit.INK_SOFT)
	locked.visible = false
	return {"card": card, "name": name_l, "lvl": lvl, "gain": gain, "dish": dish, "bar": bar, "btn": btn, "more": more,
			"locked": locked}


func refresh() -> void:
	if not visible and modulate.a <= 0.0 and _rows.is_empty():
		return
	if ",".join(PackedStringArray(_ids())) != _sig:
		_rebuild()
		return
	for id: String in _rows.keys():
		_refresh_row(id, _rows[id])


func _refresh_buttons() -> void:
	refresh()


func _refresh_row(id: String, r: Dictionary) -> void:
	var built: bool = Game.is_built(id)
	(r["name"] as Label).text = Game.station_name(id)
	var card: Control = r["card"]
	card.modulate = Color.WHITE if built else Color(1, 1, 1, 0.55)
	var btn: UiButton = r["btn"]
	var more: UiButton = r["more"]
	var bar: UiLevelBar = r["bar"]
	(r["locked"] as Label).visible = not built
	btn.visible = built and not Game.level_maxed(id)
	more.visible = built
	bar.visible = built
	if not built:
		(r["lvl"] as Label).text = ""
		(r["gain"] as Label).text = ""
		(r["dish"] as Label).text = ""
		return
	var lv: int = Game.station_level(id)
	(r["lvl"] as Label).text = tr("Lv {n}").replace("{n}", str(lv))
	var gain: Label = r["gain"]
	if Game.level_maxed(id):
		gain.text = tr("MAX LEVEL")
		gain.add_theme_color_override("font_color", UiKit.MAROON)
	else:
		gain.text = tr("+{money}/min next level").replace("{money}", Fmt.money(Game.level_up_gain(id)))
		gain.add_theme_color_override("font_color", UiKit.GAIN)
	var nd: Dictionary = next_dish(id)
	var dish: Label = r["dish"]
	if nd.is_empty():
		dish.text = tr("Every dish is on the menu")
		bar.set_values(1, 1, 1.0)
		bar.set_labels("", "")
	else:
		var at: int = int(nd["level"])
		dish.text = tr("Next dish at Lv {n}: {dish}").replace("{n}", str(at)).replace("{dish}", str(nd["title"]))
		var from: int = int(nd["from"])
		var span: float = maxf(1.0, float(at - from))
		bar.set_values(lv, at, clampf(float(lv - from) / span, 0.0, 1.0))
		bar.set_labels("", "")
	if btn.visible:
		var c: float = Game.level_cost(id)
		btn.set_cost(Fmt.price(c))
		btn.set_affordable(Game.can_afford(c))


## The counter's next locked dish: {dish, title, level, from (the level of the
## dish before it)}; {} when every dish is unlocked.
static func next_dish(id: String) -> Dictionary:
	var from: int = 1
	for v in Game.dish_ids(id):
		var d: String = str(v)
		var at: int = Game.dish_unlock_level(id, d)
		if Game.dish_unlocked(id, d):
			from = maxi(from, at)
			continue
		return {"dish": d, "title": Game.dish_title(id, d), "level": at, "from": from}
	return {}


## Anchors (tests / a future coach hand): a counter's LEVEL UP or MORE ›.
func level_button(id: String) -> UiButton:
	return (_rows[id] as Dictionary)["btn"] if _rows.has(id) else null


func _on_level(id: String) -> void:
	var gid: String = "menu_level_" + id
	if not _allowed(gid):
		return
	var r: Dictionary = _rows.get(id, {})
	var btn: UiButton = r.get("btn", null)
	if Game.buy_level(id):
		refresh()
		if btn != null:
			btn.juice()
		_flicker(r.get("lvl", null))
		action.emit(gid)
	elif btn != null:
		btn.deny()


func _on_more(id: String) -> void:
	var gid: String = "menu_open_" + id
	if not _allowed(gid):
		return
	var more: UiButton = (_rows.get(id, {}) as Dictionary).get("more", null)
	if more != null:
		more.juice()
	action.emit(gid)
