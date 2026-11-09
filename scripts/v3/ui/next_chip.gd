class_name NextChip
extends Control
## NEXT chip (UX fix A7 / D10, mockups 01 and 04): one always-visible line
## of guidance in the freed Sikke slot, right of the money pill. It names the
## next goal ("NEXT: LASSI COUNTER" / "Save 1,500 / 3,000") or, as a red
## pulsing PROBLEM chip, the current problem and its fix ("PROBLEM · 3
## WAITING" / "Seats full · Build a table"). A tap emits `tapped(hint)`; UiRoot
## opens the panel and puts the coach hand on the button that fixes it.
##
## evaluate() (every EVAL_EVERY s and on the Game signals): the first match
## of seats (door line for SEATS_PROBLEM_AFTER s, tables left, seats the
## readout's limit) -> waiter
## gate (next build waits on waiters) -> food wait (tone "bad", waiters are
## the bottleneck) -> cashier line (gallas are the bottleneck, line >= 3) ->
## build ready -> save up (with a progress bar) -> once every counter is
## built, an endless goal (soft launch polish: next table, hire, dish
## milestone, speed, level milestone; see _endless()). Hint shape:
## {id, problem, line1, line2, icon, panel, coach, progress, station}
## (+ "bar": draw the progress bar, "role": the hire's STAFF role).
## Visible only in free play with the full HUD, no Director chain, no
## dialogue, no panel or popup and the HUD in "gameplay" mode. The first
## time it shows it plays the gold reveal burst (note "next_chip_revealed").
##
## Round 2 step 1 (docs/round2/ui-proposal.md §3.8 / §4):
##  - Also shown in the tutorial whenever Refs.director.allows_next_chip()
##    says so (its free step, no line or gate up), from about 1:30, so the
##    player always has a goal. In the tutorial it shows the goal only
##    ("NEXT: TANDOOR" / "Save 198 / 2,000", or BUILD once affordable), never
##    a PROBLEM chip: the Director teaches those beats itself.
##  - Copy with the three verbs and role numbers: "Hire waiter 3", "Hire
##    cashier 2", "PROBLEM · FOOD WAITING", "PROBLEM · LONG BILL LINE",
##    "Seats full · Build a table".
##
## Round 2 step 2 (docs/round2/ui-proposal.md §3.8):
##  - Routing: the waiter gate and the food wait open STAFF › WAITERS (hint
##    panel "staff:waiters", coach "staff_hire_waiters"), the bill line STAFF
##    › CASHIERS ("staff:cashiers"), the seats the ghost table's 2-tap card or
##    BUILD › TABLES ("tables", coach "seating_add_button").
##  - Copy: "PROBLEM · FOOD WAITING / Hire a waiter", "NEXT: KADAI / Hire
##    waiter 3", "PROBLEM · 3 WAITING / Seats full · Build a table",
##    "PROBLEM · LONG BILL LINE / Upgrade a cashier".
##  - target(): what the hint points at in the world ("build:<id>",
##    "waiters", "tables", "cashiers" or ""). UiRoot shows only that world tag
##    (the one-tag rule); the chip computes it even while it is hidden.
##
## Soft launch FLOW track (2026-10-26, first-10-minutes check):
##  - Interim LEVEL UP goal: while the next counter costs more than
##    SAVE_MINUTES (4) minutes of takings (Game.rate_per_min(); the pacing
##    bot's rule in docs/round2/economy-proposal.md §1: save for a counter
##    once it costs <= 4 min of income, else buy upgrades), the chip names
##    the cheapest next milestone of a built counter instead of a long
##    "Save x / y" stretch: "NEXT: COFFEE / LEVEL UP CHAI · 12/25" (the dish
##    that milestone adds, else "NEXT: CHAI Lv 150"), tap = the counter's
##    sheet with the hand on LEVEL UP. It keeps that counter until the
##    milestone is reached; only milestones costing at most
##    INTERIM_MAX_SHARE of the counter's build price qualify (never for the
##    lassi, the goal Munshi-ji names as the tutorial ends). Without one,
##    or once the counter is within 4 minutes or the cash covers it, the
##    save / build goal shows.
##    (After the kadai, _endless() as before.)
##  - Waiter gate: while the waiter hire is not affordable the chip saves
##    for it ("NEXT: HIRE WAITER 3 / Save 67 / 1,200" with the bar) instead
##    of "Hire waiter 3", which opened STAFF on a grey HIRE button.
##  - Save hints carry "saving": UiRoot puts no coach hand on a button the
##    player cannot pay for yet.
##
## Core and feel (W2-HUD; C2.5, C2.6, C3.1, C5.2, C5.3, C6.1, C6.3):
##  - Waiter hire hints (waiter gate, food waiting, the endless hire of a
##    waiter) open the in-world 2-tap card: panel "quick:waiters", coach
##    "quick_buy_button" (UiRoot routes it, W2-ROOT). "Upgrade your waiters"
##    stays STAFF › WAITERS.
##  - One source: the PROBLEM stage test reads Game.bottleneck_state().limit
##    (the readout module, the same numbers as the HUD meter and the sheet);
##    problem_stage() tells the meter which row is the PROBLEM.
##  - The seats PROBLEM's line 2 is "+{money}/min with one more table"
##    (Game.preview_table()).
##  - After the problems, before the counters and the endless ladder: the
##    Family Dhaba (ready, or saving once unlocked; panel "promo:renovation"),
##    the next highway (panel "promo:move", hint "target" = its id) and the
##    signboard (only while Game.signboard_offer().offer; panel
##    "daftar:signboard").
##  - The endless ladder never names SPEED or a cook on a counter where
##    Game.station_help(id, kind).helps is false.
##  - Debug print "[chip] <id> panel=<panel>" when a new hint shows.

signal tapped(hint: Dictionary)

const H := 76.0
const MIN_X := 304.0
const RIGHT := 708.0
const TOP := 112.0
const EVAL_EVERY := 0.5
const SEATS_PROBLEM_AFTER := 4.0
const LIP := 4.0
const RADIUS := 20.0
const ICON_AT := Vector2(8, 9)
const ICON_D := 58.0
const GLYPH_D := 40.0
const LINE1_AT := Vector2(78, 11)
const LINE2_AT := Vector2(78, 33)
const LINE2_PX := [25, 24, 23, 22, 21, 20]
const BAR_AT := Vector2(78, 64)
const FADE := 0.15
const PULSE_HZ := 1.2
const GLOW_PX := 7.0
const REVEAL_NOTE := "next_chip_revealed"
## Core and feel C3.1: waiter hire hints open the in-world 2-tap card.
const WAITER_PANEL := "quick:waiters"
const WAITER_COACH := "quick_buy_button"
## PROBLEM hint id -> the readout row it names (problem_stage()).
const PROBLEM_STAGE := {"food": "waiters", "seats": "seats", "cashier": "cashiers"}

## () -> String, set by Hud: the shown mode ("gameplay", "sheet", ...).
var mode_fn: Callable = Callable()
## () -> float, set by Hud: the cash the pill shows (rewards held back).
var cash_fn: Callable = Callable()
var hint: Dictionary = {}

var _icon: UiIcon
var _l1: Label
var _l2: Label
var _content: Control
var _sb_face: StyleBoxFlat
var _sb_lip: StyleBoxFlat
var _sb_glow: StyleBoxFlat
var _eval_t: float = 0.0
var _clock: float = 0.0
var _door_t0: float = -1.0
var _shown: bool = false
var _shown_id: String = ""
var _text_key: String = ""
var _fade_tw: Tween
var _swap_tw: Tween
var _pulse_t: float = 0.0
var _dirty: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	modulate.a = 0.0
	position = Vector2(MIN_X, TOP)
	size = Vector2(RIGHT - MIN_X, H)
	pivot_offset = size * 0.5
	set_meta("ui_radius", RADIUS)
	_sb_face = UiKit.box(UiKit.CREAM_BTN, RADIUS, 3, UiKit.TEAL)
	_sb_lip = UiKit.box(UiKit.TEAL_DARK, RADIUS)
	_sb_glow = UiKit.box(Color(UiKit.BAD, 0.0), RADIUS + GLOW_PX)
	_sb_glow.shadow_color = Color(UiKit.BAD, 0.55)
	_sb_glow.shadow_size = int(GLOW_PX)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon = UiIcon.new("waiter", Vector2(ICON_D, ICON_D), Color.WHITE, UiKit.TEAL_LIGHT)
	_icon.pad = (ICON_D - GLYPH_D) / ICON_D
	_icon.position = ICON_AT
	_content.add_child(_icon)
	_l1 = UiKit.label("", 16, UiKit.TEAL_DARK)
	_l1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_l1.clip_text = true
	_content.add_child(_l1)
	_l2 = UiKit.label("", 25, UiKit.INK)
	_l2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_l2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_l2.clip_text = true
	_content.add_child(_l2)
	_relayout()


func _ready() -> void:
	for sig in ["cash_changed", "waiter_changed", "seating_changed", "station_changed", "building_built"]:
		UiKit.gconnect(sig, _mark_dirty)
	set_process(true)


# ================================================================ public API
## Hud: x = maxf(MIN_X, money pill right + 12).
func set_left(x: float) -> void:
	var l: float = maxf(MIN_X, x)
	if absf(l - position.x) < 0.5:
		return
	position = Vector2(l, TOP)
	size = Vector2(maxf(RIGHT - l, 160.0), H)
	pivot_offset = size * 0.5
	_relayout()
	_fit_line2()
	queue_redraw()


func is_problem() -> bool:
	return bool(hint.get("problem", false))


## One-tag rule: the world thing this hint points at - "build:<id>" (the
## next build pad), "waiters" (the ghost waiter), "tables" (the ghost table),
## "cashiers" (no tag) or "".
func target() -> String:
	match str(hint.get("id", "")):
		"waiter_gate", "food":
			return "waiters"
		"seats":
			return "tables"
		"cashier":
			return "cashiers"
		"build", "save":
			var sid: String = str(hint.get("station", ""))
			return "build:" + sid if sid != "" else ""
		"table":
			return "tables"
		"dish", "level":
			# FLOW interim goal: the counter being saved for keeps its pad tag.
			var bt: String = str(hint.get("build_target", ""))
			return "build:" + bt if bt != "" else ""
		"hire":
			match str(hint.get("role", "")):
				"waiters":
					return "waiters"
				"cashiers":
					return "cashiers"
	return ""


func is_showing() -> bool:
	return _shown


## Core and feel C2.6: the readout row of the current PROBLEM hint
## ("waiters" | "seats" | "cashiers"), "" when the hint is not a PROBLEM.
## The HUD meter turns that row red (one source with the chip).
func problem_stage() -> String:
	if not is_problem():
		return ""
	return str(PROBLEM_STAGE.get(str(hint.get("id", "")), ""))


## Picks the hint (first match wins; {"id": ""} = nothing to show).
func evaluate() -> Dictionary:
	var nb: String = Game.next_build_id()
	var noun: String = tr(Game.station_noun(nb)).to_upper() if nb != "" else ""
	var door: int = _door_waiting()
	# In the tutorial (round 2: the chip shows in its free step) only the goal.
	var free_play: bool = Game.is_tutorial_done()
	# One source (C2.6): the readout's limit, "" while the road is the limit.
	var stage: String = str(Game.bottleneck_state().get("limit", "")) if free_play else ""
	# 1 seats: a door line for SEATS_PROBLEM_AFTER s, tables left to buy and
	# the seats are the readout's limit (a bunched bus while another stage is
	# the limit falls through to that stage's PROBLEM or the goal).
	if free_play and stage == "seats" and door > 0 and _door_t0 >= 0.0 and _clock - _door_t0 >= SEATS_PROBLEM_AFTER \
			and UiKit.gint("table_count", [], 0) < UiKit.gint("table_max", [], 0):
		return _hint("seats", true, tr("PROBLEM · %d WAITING") % door, _seats_line2(), "charpai",
				"tables", "seating_add_button")
	# FLOW: the next counter costs more than SAVE_MINUTES of takings (and the
	# cash does not cover it yet: an affordable counter is always the goal).
	var far: bool = free_play and nb != "" and _build_far(nb) and not Game.can_afford(Game.build_cost(nb))
	# The level goal for it ({} when no milestone qualifies: then the counter
	# counts as within reach, waiter gate first).
	var interim: Dictionary = _interim(nb) if far else {}
	if interim.is_empty():
		far = false
		_interim_sid = ""
	# 2 the next build (within reach) waits on waiters.
	if free_play and nb != "" and not far and Game.build_block_reason(nb).begins_with("waiters:"):
		var wn: int = Game.waiter_count() + 1
		var wc: float = Game.waiter_hire_cost()
		if Game.can_afford(wc):
			return _hint("waiter_gate", false, tr("NEXT: %s") % noun, tr("Hire waiter %d") % wn,
					"waiter", WAITER_PANEL, WAITER_COACH, 0.0, nb)
		var wcash: float = float(cash_fn.call()) if cash_fn.is_valid() else Game.cash
		return _save_hint("waiter_gate", tr("NEXT: %s") % (tr("Hire waiter %d") % wn).to_upper(), wcash, wc, "waiter",
				WAITER_PANEL, WAITER_COACH, nb)
	if stage == "waiters" or stage == "cashiers":
		var st: Dictionary = Game.stats()
		var tones: Dictionary = st.get("tones", {}) if st.get("tones", {}) is Dictionary else {}
		# 3 food waits too long and the waiters are the limit.
		if stage == "waiters" and str(tones.get("avg_food_wait", "")) == "bad":
			if Game.can_hire_waiter():
				return _hint("food", true, tr("PROBLEM · FOOD WAITING"), tr("Hire a waiter"), "waiter", WAITER_PANEL,
						WAITER_COACH)
			return _hint("food", true, tr("PROBLEM · FOOD WAITING"), tr("Upgrade your waiters"), "waiter", "staff:waiters",
					"staff_upgrade_waiters_%d" % Game.waiter_pick())
		# 4 a long bill line and the cashiers are the limit.
		var line: float = float(st.get("avg_galla_line", 0.0))
		if stage == "cashiers" and line >= 3.0:
			var l1: String = tr("PROBLEM · LONG BILL LINE")
			if Game.can_hire_galla():
				return _hint("cashier", true, l1, tr("Hire cashier %d") % (Game.galla_count() + 1), "galla", "staff:cashiers",
						"staff_hire_cashiers")
			return _hint("cashier", true, l1, tr("Upgrade a cashier"), "galla", "staff:cashiers",
					"staff_upgrade_cashiers_%d" % _lowest_galla())
	# Core and feel: the Family Dhaba, the next highway, the signboard.
	if free_play:
		var ph: Dictionary = _promo_hint()
		if not ph.is_empty():
			return ph
	if nb == "":
		# 7 every counter is built: an endless goal (soft launch polish).
		return _endless() if free_play else {"id": ""}
	# FLOW: a far-off counter: level a counter up to its next milestone first.
	if far:
		return interim
	var cost: float = Game.build_cost(nb)
	# 5 the next build is affordable.
	if Game.build_affordable(nb):
		return _hint("build", false, tr("NEXT: %s") % noun, tr("BUILD {name} · {cost}").format(
				{"name": UiKit.station_name(nb), "cost": Fmt.price(cost)}),
				"hammer", "daftar", "daftar_build_" + nb, 0.0, nb)
	# 6 save up for it.
	var cash: float = float(cash_fn.call()) if cash_fn.is_valid() else Game.cash
	var icon: String = str(UiKit.station_ui(nb).get("icon", "hammer"))
	return _hint("save", false, tr("NEXT: %s") % noun, tr("Save %s / %s") % [_save_money(cash), Fmt.price(cost)], icon,
			"daftar", "", clampf(cash / maxf(cost, 0.0001), 0.0, 1.0), nb)


# ================================================================ interim goal (FLOW)
## The pacing bot saves for a counter once it costs at most this many
## minutes of takings; before that it buys upgrades.
const SAVE_MINUTES := 4.0
## A milestone qualifies as the interim goal only if reaching it costs at
## most this share of the counter being saved for.
const INTERIM_MAX_SHARE := 0.5

## The counter whose next milestone the chip names (kept until reached).
var _interim_sid: String = ""
var _interim_target: int = 0


## Counters the chip always saves for (economy station "next_chip_skip"):
## the tutorial's last line (l17) names the dhaba's lassi as the next goal,
## so the chip agrees with Munshi-ji.


## The counter `nb` costs more than SAVE_MINUTES of takings.
func _build_far(nb: String) -> bool:
	if bool(Game.station_def(nb).get("next_chip_skip", false)):
		return false
	var rate: float = Game.rate_per_min()
	return rate > 0.0 and Game.build_cost(nb) > SAVE_MINUTES * rate


## Cash to level `sid` from its level to `target` (level costs grow by
## level_cost_growth a level; no milestone lies in between).
static func _cost_to_level(sid: String, target: int) -> float:
	var n: int = target - Game.station_level(sid)
	if n <= 0:
		return 0.0
	var g: float = float(Game.station_def(sid).get("level_cost_growth", 1.02))
	var first: float = Game.level_cost(sid)
	if absf(g - 1.0) < 0.0001:
		return first * n
	return first * (pow(g, float(n)) - 1.0) / (g - 1.0)


## "NEXT: COFFEE / LEVEL UP CHAI · 12/25" for the built counter whose next
## milestone is cheapest to reach (at most INTERIM_MAX_SHARE of the build
## being saved for); the same counter until its milestone is reached. {}
## when none qualifies.
func _interim(nb: String) -> Dictionary:
	var cap: float = Game.build_cost(nb) * INTERIM_MAX_SHARE
	var sid: String = _interim_sid
	if sid != "" and (not Game.is_built(sid) or Game.level_maxed(sid) or Game.station_level(sid) >= _interim_target):
		sid = ""
	if sid == "":
		var best: float = INF
		for s2: String in Game.built_station_ids():
			if Game.level_maxed(s2):
				continue
			var c: float = _cost_to_level(s2, Game.level_milestone(s2))
			if c <= cap and c < best:
				best = c
				sid = s2
		if sid == "":
			_interim_sid = ""
			return {}
		_interim_sid = sid
		_interim_target = Game.level_milestone(sid)
	var h: Dictionary = _milestone_hint(sid, _interim_target)
	h["build_target"] = nb
	return h


## The goal "reach level `target` at `sid`": the dish that opens there
## ("NEXT: COFFEE"), else the level ("NEXT: CHAI Lv 150"); line 2 "LEVEL UP
## CHAI · 12/25", the bar = the level progress since the last milestone.
func _milestone_hint(sid: String, target: int) -> Dictionary:
	var lv: int = Game.station_level(sid)
	var dkey: String = ""
	for e: Variant in Game.menu(sid):
		if e is Dictionary and int((e as Dictionary).get("from_level", 1)) == target:
			dkey = str((e as Dictionary).get("key", ""))
			break
	var prev: int = mini(Game.level_milestone_prev(sid), lv)
	var l1: String = tr("NEXT: %s") % (tr(Game.dish_name(sid, dkey)) if dkey != "" else "%s %s" % [_short(sid), Fmt.level(target)])
	var h: Dictionary = _hint("dish" if dkey != "" else "level", false, l1, _level_line(sid, lv, target),
			str(UiKit.station_ui(sid).get("icon", "hammer")), "station:" + sid, "level_up_button",
			clampf(float(lv - prev) / maxf(1.0, float(target - prev)), 0.0, 1.0), sid)
	h["bar"] = true
	h["saving"] = not Game.can_afford(Game.level_cost(sid))
	return h


# ================================================================ endless goals
## Soft launch polish: once every counter is built (after the kadai) the chip
## still names a goal, so the player always has one. Candidates (hint ids):
##   table  the next table set: "NEXT: TABLE 4 / BUILD TABLE 4 · 1,800" or
##          "Save 900 / 1,800" (BUILD › TABLES or the ghost table's card)
##   hire   Game.best_hire() (the STAFF badge's pick): "NEXT: HIRE WAITER 4 /
##          HIRE · 1,200" (STAFF on that tab, hand on its HIRE)
##   dish   the nearest dish still locked on a built counter (menus open at
##          L25 / L50 / L100): "NEXT: DAL MAKHANI / LEVEL UP KADAI · 18/25"
##          (the counter's sheet, hand on LEVEL UP)
##   speed  the cheapest SPEED upgrade left (once every dish is out)
##   level  the next level milestone (150, 200 ...) of the lowest counter
## Ladder: table, hire (only while affordable), dish, hire, speed, level. A
## goal stays up at least ENDLESS_HOLD s while it is still a candidate, so
## the chip does not flip between two goals as the cash goes up and down.
const ENDLESS_HOLD := 15.0
## Short counter names for the chip's 25 px line ("CHAI", not "CHAI
## COUNTER"); each is already a msgid (the station / first dish name).

var _endless_kind: String = ""
var _endless_t0: float = -999.0


func _endless() -> Dictionary:
	var cash: float = float(cash_fn.call()) if cash_fn.is_valid() else Game.cash
	var c: Dictionary = {}
	# table: the next table set.
	if not Game.table_maxed():
		var tname: String = tr("TABLE %d") % (Game.table_count() + 1)
		var tc: float = Game.table_cost()
		var tl1: String = tr("NEXT: %s") % tname
		if Game.can_afford(tc):
			c["table"] = _hint("table", false, tl1, tr("BUILD {name} · {cost}").format({"name": tname, "cost": Fmt.price(tc)}),
					"table_plus", "tables", "seating_add_button")
		else:
			c["table"] = _save_hint("table", tl1, cash, tc, "table_plus", "tables", "seating_add_button")
	# hire: the STAFF badge's best hire.
	var bh: Dictionary = Game.best_hire()
	var role: String = str(bh.get("role", ""))
	var hire_now: bool = false
	if role != "":
		var hc: float = float(bh.get("cost", 0.0))
		hire_now = bool(bh.get("affordable", false))
		var st: String = str(bh.get("station", ""))
		var hl1: String = ""
		var hl2: String = "%s · %s" % [tr("HIRE"), Fmt.price(hc)]
		var icon: String = "staff_plus"
		var coach: String = "staff_hire_" + role
		var panel: String = "staff:" + role
		match role:
			"waiters":
				hl1 = tr("NEXT: %s") % (tr("Hire waiter %d") % (Game.waiter_count() + 1)).to_upper()
				icon = "waiter"
				panel = WAITER_PANEL
				coach = WAITER_COACH
			"cashiers":
				hl1 = tr("NEXT: %s") % (tr("Hire cashier %d") % (Game.galla_count() + 1)).to_upper()
				icon = "galla"
			_:
				if st == "":
					st = Game.staff_cook_station()
				hl1 = tr("NEXT: %s") % tr("HIRE COOK")
				hl2 = "%s · %s" % [_short(st), Fmt.price(hc)]
				coach = "staff_hire_cooks_" + st
		# C2.5: never a cook on a counter that is not the bottleneck.
		var helps: bool = role == "waiters" or role == "cashiers" or _helps(st, "cook")
		if (st != "" or role != "cooks") and helps:
			if hire_now:
				c["hire"] = _hint("hire", false, hl1, hl2, icon, panel, coach, 0.0, st)
			else:
				c["hire"] = _save_hint("hire", hl1, cash, hc, icon, panel, coach, st)
			c["hire"]["role"] = role
		else:
			hire_now = false
	# dish: the nearest locked dish on a built counter.
	var dst: String = ""
	var dkey: String = ""
	var dfrom: int = 0
	var dleft: int = 1 << 30
	var built: Array[String] = Game.built_station_ids()
	for sid: String in built:
		if Game.level_maxed(sid):
			continue
		var lv: int = Game.station_level(sid)
		for e: Variant in Game.menu(sid):
			if not (e is Dictionary):
				continue
			var fl: int = int((e as Dictionary).get("from_level", 1))
			if fl > lv and fl - lv < dleft:
				dleft = fl - lv
				dst = sid
				dfrom = fl
				dkey = str((e as Dictionary).get("key", ""))
	if dst != "":
		var lv2: int = Game.station_level(dst)
		var prev: int = mini(Game.level_milestone_prev(dst), lv2)
		c["dish"] = _hint("dish", false, tr("NEXT: %s") % tr(Game.dish_name(dst, dkey)),
				_level_line(dst, lv2, dfrom), str(UiKit.station_ui(dst).get("icon", "hammer")), "station:" + dst,
				"level_up_button", clampf(float(lv2 - prev) / maxf(1.0, float(dfrom - prev)), 0.0, 1.0), dst)
		c["dish"]["bar"] = true
	# speed: the cheapest SPEED upgrade left (C2.5: only where it helps).
	var sst: String = ""
	for sid: String in built:
		if not Game.proc_maxed(sid) and _helps(sid, "speed") and (sst == "" or Game.proc_cost(sid) < Game.proc_cost(sst)):
			sst = sid
	if sst != "":
		var pc: float = Game.proc_cost(sst)
		var sl1: String = tr("NEXT: %s") % ("%s %s" % [_short(sst), tr("SPEED")])
		if Game.can_afford(pc):
			c["speed"] = _hint("speed", false, sl1, "%s · %s" % [tr("UPGRADE"), Fmt.price(pc)], "clock",
					"station:" + sst, "processing_button", 0.0, sst)
		else:
			c["speed"] = _save_hint("speed", sl1, cash, pc, "clock", "station:" + sst, "processing_button", sst)
	# level: the next milestone of the lowest counter.
	var lst: String = ""
	for sid: String in built:
		if not Game.level_maxed(sid) and (lst == "" or Game.station_level(sid) < Game.station_level(lst)):
			lst = sid
	if lst != "":
		var m: int = Game.level_milestone(lst)
		c["level"] = _hint("level", false, tr("NEXT: %s") % ("%s %s" % [_short(lst), Fmt.level(m)]),
				_level_line(lst, Game.station_level(lst), m), str(UiKit.station_ui(lst).get("icon", "hammer")),
				"station:" + lst, "level_up_button", Game.level_bar_fill(lst), lst)
		c["level"]["bar"] = true
	return _endless_pick(c, hire_now)


## The ladder with the ENDLESS_HOLD hysteresis ({"id": ""} when nothing is
## left: every counter at its max level, speed and staff).
func _endless_pick(c: Dictionary, hire_now: bool) -> Dictionary:
	if _endless_kind != "" and c.has(_endless_kind) and _clock - _endless_t0 < ENDLESS_HOLD:
		return c[_endless_kind]
	var order: Array[String] = ["table"]
	if hire_now:
		order.append("hire")
	order.append_array(["dish", "hire", "speed", "level"])
	for k: String in order:
		if c.has(k):
			if k != _endless_kind:
				_endless_kind = k
				_endless_t0 = _clock
			return c[k]
	_endless_kind = ""
	return {"id": ""}


## C2.5: Game.station_help(id, kind).helps ("speed" | "cook"): the readout
## says this counter's SPEED / cook would raise takings now.
static func _helps(id: String, kind: String) -> bool:
	if id == "":
		return true
	return bool(Game.station_help(id, kind).get("helps", true))


# ================================================================ promotions and signboard (core and feel)
## C6.1 / C6.3 / C5.3, in this order: the Family Dhaba (ready: "Ready! Tap to
## renovate"; unlocked but short of cash: "Save {money}" with the bar), the
## next highway ("A new highway is ready", or "Save {money}"), the signboard
## (only while Game.signboard_offer().offer: the road is the limit and it
## pays back). {} when none applies.
func _promo_hint() -> Dictionary:
	var cash: float = float(cash_fn.call()) if cash_fn.is_valid() else Game.cash
	# Dhaba growth step 3 (6 Nov): the next stage first (THE SHACK / THE DHABA).
	var gs: Dictionary = Game.growth_state() if Game.has_method("growth_state") else {}
	if bool(gs.get("unlocked", false)):
		var gl1: String = tr("NEXT: %s") % tr(str(gs.get("title", "")))
		if bool(gs.get("affordable", false)):
			return _hint("grow", false, gl1, tr("Ready! Tap to build"), "blueprint", "daftar:grow", "build_row_grow")
		return _promo_save("grow", gl1, cash, float(gs.get("cost", 0.0)), float(gs.get("short", 0.0)), "blueprint",
				"daftar:grow")
	var rs: Dictionary = Game.renovation_state()
	if bool(rs.get("unlocked", false)):
		var rl1: String = tr("NEXT: %s") % tr("FAMILY DHABA")
		if bool(rs.get("affordable", false)):
			return _hint("renovate", false, rl1, tr("Ready! Tap to renovate"), "family_hall", "promo:renovation",
					"promo_button")
		return _promo_save("renovate", rl1, cash, float(rs.get("cost", 0.0)), float(rs.get("short", 0.0)),
				"family_hall", "promo:renovation")
	for lv in Game.location_ids():
		var lid: String = str(lv)
		var ls: Dictionary = Game.location_state(lid)
		if not bool(ls.get("unlocked", false)):
			continue
		var nm: String = str(Game.location_def(lid).get("name", lid.to_upper()))
		var ml1: String = tr("NEXT: %s") % tr(nm)
		var mh: Dictionary
		if bool(ls.get("affordable", false)):
			mh = _hint("move", false, ml1, tr("A new highway is ready"), "highway", "promo:move", "promo_button")
		else:
			mh = _promo_save("move", ml1, cash, float(ls.get("cost", 0.0)), float(ls.get("short", 0.0)), "highway",
					"promo:move")
		mh["target"] = lid
		return mh
	if bool(Game.signboard_offer().get("offer", false)):
		return _hint("signboard", false, tr("NEXT: %s") % tr("SIGNBOARD"), tr("The road is the limit now"), "signboard",
				"daftar:signboard", "build_row_signboard")
	return {}


## "Save {money}" (the cash still missing) with the progress bar; no coach
## hand (saving).
func _promo_save(id: String, l1: String, cash: float, cost: float, short: float, icon: String, panel: String) -> Dictionary:
	var h: Dictionary = _hint(id, false, l1, tr("Save {money}").format({"money": Fmt.money(short)}), icon, panel,
			"promo_button", clampf(cash / maxf(cost, 0.0001), 0.0, 1.0))
	h["bar"] = true
	h["saving"] = true
	return h


## The seats PROBLEM's second line: what one more table would add
## (Game.preview_table()), else the 0.3.7 line.
func _seats_line2() -> String:
	var g: float = float(Game.preview_table().get("gain_per_min", 0.0))
	if g > 0.0:
		return tr("+{money}/min with one more table").format({"money": Fmt.money(g)})
	return tr("Seats full · Build a table")


## "LEVEL UP KADAI · 18/25".
func _level_line(sid: String, lv: int, target_lv: int) -> String:
	return tr("LEVEL UP {name} · {lv}/{target}").format({"name": _short(sid), "lv": Fmt.count(lv),
			"target": Fmt.count(target_lv)})


## The station's "short_name" from the pack ("CHAI"), translated; the full
## station name when it has none.
func _short(sid: String) -> String:
	var sn: String = str(Game.station_def(sid).get("short_name", ""))
	return tr(sn) if sn != "" else UiKit.station_name(sid)


## A goal not affordable yet: "Save 900 / 1,800" with the progress bar.
func _save_hint(id: String, l1: String, cash: float, cost: float, icon: String, panel: String, coach: String,
		station: String = "") -> Dictionary:
	var h: Dictionary = _hint(id, false, l1, tr("Save %s / %s") % [_save_money(cash), Fmt.price(cost)], icon, panel,
			coach, clampf(cash / maxf(cost, 0.0001), 0.0, 1.0), station)
	h["bar"] = true
	h["saving"] = true
	return h


# ================================================================ internals
func _hint(id: String, problem: bool, l1: String, l2: String, icon: String, panel: String, coach: String,
		progress: float = 0.0, station: String = "") -> Dictionary:
	return {"id": id, "problem": problem, "line1": l1, "line2": l2, "icon": icon, "panel": panel,
			"coach": coach, "progress": progress, "station": station}


## "Save 197 / 2,000": whole rupees below 1,000 (no paise on a goal line).
static func _save_money(cash: float) -> String:
	if Fmt.display(cash) < 1000.0:
		return Fmt.int_floor(Fmt.display(maxf(cash, 0.0)))
	return Fmt.money(cash)


func _lowest_galla() -> int:
	var best: int = 0
	for i in Game.galla_count():
		if Game.galla_level(i) < Game.galla_level(best):
			best = i
	return best


func _door_waiting() -> int:
	var ui: Variant = Refs.ui
	if ui != null and is_instance_valid(ui) and (ui as Object).has_method("door_waiting"):
		return int((ui as Object).call("door_waiting"))
	return 0


func _mark_dirty() -> void:
	_dirty = true


func _wanted() -> bool:
	if hint.is_empty() or str(hint.get("id", "")) == "":
		return false
	if not Game.is_tutorial_done():
		# Round 2: the tutorial's free step (no line or gate up) shows the goal.
		if not _director_allows():
			return false
	else:
		if Game.hud_reveal < Game.HUD_FULL:
			return false
		var d: Variant = Refs.director
		if d != null and is_instance_valid(d) and (d as Object).has_method("is_active") and bool((d as Object).call("is_active")):
			return false
	var dlg: Variant = Refs.dialogue
	if dlg != null and is_instance_valid(dlg) and (dlg as Object).has_method("is_open") and bool((dlg as Object).call("is_open")):
		return false
	var ui: Variant = Refs.ui
	if ui != null and is_instance_valid(ui):
		if str((ui as Object).get("current_panel")) != "" or str((ui as Object).get("current_popup")) != "":
			return false
	if mode_fn.is_valid() and str(mode_fn.call()) != "gameplay":
		return false
	return true


## Director.allows_next_chip(): true in the tutorial's free step with no
## dialogue up (false while there is no Director).
func _director_allows() -> bool:
	if Refs.director == null or not is_instance_valid(Refs.director):
		return false
	var d: Director = Refs.director as Director
	return d != null and d.allows_next_chip()


func _process(delta: float) -> void:
	_clock += delta
	_eval_t += delta
	if _eval_t >= EVAL_EVERY or _dirty:
		_eval_t = 0.0
		_dirty = false
		if _door_waiting() > 0:
			if _door_t0 < 0.0:
				_door_t0 = _clock
		else:
			_door_t0 = -1.0
		_apply(evaluate())
		_set_shown(_wanted())
	if _shown and is_problem():
		_pulse_t += delta
		var k: float = 0.02 * (1.0 - cos(TAU * PULSE_HZ * _pulse_t))
		scale = Vector2.ONE * (1.0 + k)
	elif scale != Vector2.ONE:
		scale = Vector2.ONE
		_pulse_t = 0.0


func _apply(h: Dictionary) -> void:
	var key: String = "%s|%s|%s|%s|%.3f" % [h.get("id", ""), h.get("line1", ""), h.get("line2", ""),
			h.get("icon", ""), float(h.get("progress", 0.0))]
	var was_problem: bool = is_problem()
	var old_id: String = str(hint.get("id", ""))
	hint = h
	if key == _text_key:
		return
	# A new hint (id or headline) cross-fades; a running count ("Save 1,523 /
	# 3,000", "3 WAITING" -> "4 WAITING" keeps the headline shape) swaps at once.
	var new_hint: bool = old_id != str(h.get("id", "")) or _l1.text.get_slice("·", 0) != str(h.get("line1", "")).get_slice("·", 0)
	_text_key = key
	if _shown and new_hint and old_id != "":
		# Cross-fade: content out, swap, back in (0.15 s in all).
		if _swap_tw != null and _swap_tw.is_valid():
			_swap_tw.kill()
		_swap_tw = create_tween()
		_swap_tw.tween_property(_content, "modulate:a", 0.0, FADE * 0.5)
		_swap_tw.tween_callback(_fill.bind(h))
		_swap_tw.tween_property(_content, "modulate:a", 1.0, FADE * 0.5)
	else:
		_fill(h)
	if was_problem != is_problem():
		queue_redraw()
	if _shown and old_id != str(h.get("id", "")):
		_log_show()


func _fill(h: Dictionary) -> void:
	var problem: bool = bool(h.get("problem", false))
	_l1.text = str(h.get("line1", ""))
	_l2.text = str(h.get("line2", ""))
	_l1.add_theme_color_override("font_color", Color.WHITE if problem else UiKit.TEAL_DARK)
	_l2.add_theme_color_override("font_color", Color.WHITE if problem else UiKit.INK)
	_icon.set_icon(str(h.get("icon", "hammer")))
	_icon.set_bg(Color.WHITE if problem else UiKit.TEAL_LIGHT)
	_fit_line2()
	queue_redraw()


func _relayout() -> void:
	var w: float = size.x
	UiKit.place(_l1, LINE1_AT, Vector2(w - LINE1_AT.x - 44.0, 22.0))
	UiKit.place(_l2, LINE2_AT, Vector2(w - LINE2_AT.x - 44.0, 36.0))


## Line 2 at 25 px, 1 px smaller at a time down to 20 px, then the ellipsis.
func _fit_line2() -> void:
	var f: Font = UiKit.font_bold()
	var maxw: float = size.x - LINE2_AT.x - 44.0
	var px: int = int(LINE2_PX[LINE2_PX.size() - 1])
	for v in LINE2_PX:
		if f.get_string_size(_l2.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(v)).x <= maxw:
			px = int(v)
			break
	_l2.add_theme_font_size_override("font_size", px)


func _set_shown(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = create_tween()
	if on:
		visible = true
		_fill(hint)
		_fade_tw.tween_property(self, "modulate:a", 1.0, FADE)
		_log_show()
		if not Game.note_seen(REVEAL_NOTE):
			Game.mark_note(REVEAL_NOTE)
			_reveal_burst.call_deferred()
	else:
		_fade_tw.tween_property(self, "modulate:a", 0.0, FADE)
		_fade_tw.tween_callback(_on_faded)


func _on_faded() -> void:
	if not _shown:
		visible = false


func _log_show() -> void:
	var id: String = str(hint.get("id", ""))
	if id == "" or id == _shown_id:
		return
	_shown_id = id
	Analytics.event("next_chip_show", {"id": id})
	if OS.is_debug_build():
		print("[chip] %s panel=%s" % [id, str(hint.get("panel", ""))])


func _reveal_burst() -> void:
	if UiKit.fx_call("gem_reveal", [self]):
		return
	var j: UiJuice = UiKit.juice_for(self)
	if j == null:
		return
	var c: Vector2 = get_global_rect().get_center()
	j.glow(c, 10.0, 160.0, 0.25, Color(1.0, 0.9, 0.63), 0.2)
	j.ring(c, 40.0, 220.0, 0.25, 3.0, Color(1.0, 0.8, 0.3), 0.9, 0.1)
	j.spark(c, Vector2(180, 40), 10, Vector2(4, 6), Vector2(20, 20), 0.3)


func _draw() -> void:
	var w: float = size.x
	var face := Rect2(0.0, 0.0, w, H - LIP)
	var problem: bool = is_problem()
	if problem:
		draw_style_box(_sb_glow, face)
		_sb_lip.bg_color = UiKit.BAD.darkened(0.35)
		_sb_face.bg_color = UiKit.BAD
		_sb_face.set_border_width_all(0)
	else:
		_sb_lip.bg_color = UiKit.TEAL_DARK
		_sb_face.bg_color = UiKit.CREAM_BTN
		_sb_face.set_border_width_all(3)
		_sb_face.border_color = UiKit.TEAL
	draw_style_box(_sb_lip, Rect2(0.0, LIP, w, H - LIP))
	draw_style_box(_sb_face, face)
	UiIcon.glyph(self, "›", Vector2(w - 22.0, 38.0), 30.0, Color.WHITE if problem else UiKit.TEAL_DARK)
	if str(hint.get("id", "")) == "save" or bool(hint.get("bar", false)):
		var bw: float = w - 122.0
		var track := Rect2(BAR_AT, Vector2(bw, 4.0))
		draw_rect(track, UiKit.TEAL_LIGHT)
		var p: float = clampf(float(hint.get("progress", 0.0)), 0.0, 1.0)
		if p > 0.0:
			draw_rect(Rect2(BAR_AT, Vector2(bw * p, 4.0)), UiKit.TEAL)


func _gui_input(event: InputEvent) -> void:
	if not _shown:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			UiKit.ripple(self, true)
			Sfx.play("tap", 0.02)
			tapped.emit(hint.duplicate())
