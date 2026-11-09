class_name StationNode
extends Node3D
## One kitchen station (Chai Counter, Tandoor ...) in the seated dhaba (user
## change 2026-10-19): counter prop, one Staff per employee (max 3, side by
## side), a FIFO of order TICKETS and the PASS (a few pickup slots on the
## counter's customer-side ledge, Layout3.PASS_POINTS).
##
## Cooking: a free cook takes the next ticket 0.15 s after it arrives (or
## after their last one), cooks for Game.processing_time(id) under their own
## world RadialTimer (Fx, reused; frozen while Game.sim_paused). On
## completion the timer shrinks out, the cook turns ~90 deg and back, the
## ticket's price is LOCKED (Game.price(id)) and the item (a kulhad / roti
## plate) pops onto a free pass slot -> item_ready. With the pass full the
## cook holds the finished item until a waiter clears a slot (or a waiter
## waiting for it at the pass takes it from the cook's hands, hand_over).
## Travellers never come to the counter; waiters lift items off the pass
## (take_from_pass / hand_over) and Sim reports "served" when they reach the
## table. ticket_eta() tells Sim's whole-order dispatch when an item will be
## ready.
##
## Children use WORLD coordinates (Layout3); keep this node at the origin.
##
## Menu expansion (docs/v3-menu-expansion.md, 2026-10-20): LASSI and the
## KADAI use per-station cook offsets (Layout3.station_staff), a free-play
## tap area of world AABBs (make_tap_boxes, Layout3.station_tap_boxes), a
## prop animator for the glb's named parts while a cook is cooking (lassi
## "madhani" spins, kadai "karchhi" stirs; the old bhurji heap / handi lid
## lookups stay harmless), steam puffs from "steam_socket" (kadai) and a cook
## sound when a ticket starts on screen. A station added from a ghost pad
## starts hidden (begin_hidden: reveal_pending, no ticket is cooked) until
## the Sim calls reveal() (prop and cooks pop in).
##
## Station menus (docs/v3-station-menus.md, 2026-10-21): a Ticket carries
## its dish_id (rolled by the Sim); the brew time, the locked price, the
## item model on the pass and the cook sound are per dish (Game.dish_*). A
## small unlock prop per unlocked dish 2-4 stands on the station
## (_sync_unlock_props: instant on setup / load, a pop with sparkles 0.4 s
## after a live Game.menu_unlocked).
##
## Core-and-feel C2.3 (plates visibly stack when the waiters cannot keep
## up): when the pass is full, a finished item no longer vanishes into its
## cook's hands. It goes at once onto the steel tray of a small PLATE STOOL
## beside the pass (Layout3.stool_pos / stool_points: side by side, up to 3,
## one per holding cook): the ticket is READY (ready_at = now, held = true,
## pass_slot -1, in held_tickets) and item_ready fires once, so the plate
## counts as waiting and gets its orange wait ring after 6 s (Sim). The cook
## keeps holding as before (no throughput change): when a pass slot frees,
## the oldest plate no waiter is coming for slides from the stool onto it
## (same item, same ready_at; _release_holds); a waiter at the pass takes a
## stool plate straight away (hand_over), which frees its cook. The stool
## (`plate_stool` glb, or a code
## stool) shows only while it holds a plate. C8.1: the tandoor's cook plays
## the "slap" pose while cooking.

signal ticket_started(station: StationNode, ticket: RefCounted)
signal item_ready(station: StationNode, ticket: RefCounted)
## Compatibility (Director wires these on the chai node): a cook started /
## finished the ticket of traveller `t`.
signal service_started(station: StationNode, t: Traveller)
signal service_done(station: StationNode, t: Traveller)

enum P { IDLE, DELAY, RUN, HOLD }
## Ticket states.
enum TK { QUEUED, COOKING, READY, ASSIGNED, CARRIED, SERVED, CANCELLED }

const NEXT_DELAY := 0.15
const ITEM_POP := 0.2


## One ordered item: created by Sim when a traveller sits down.
class Ticket:
	extends RefCounted
	var traveller: Traveller = null
	var station_id: String = ""
	## Full dish id ("tandoor.naan"; station menus). Set by the Sim when the
	## ticket is created; enqueue_ticket fills dish 1 in when it is empty.
	var dish_id: String = ""
	var station: StationNode = null
	var seat: int = -1
	var state: int = 0
	## Locked when the cook finishes (paid at the galla, before VIP).
	var price: float = 0.0
	var pass_slot: int = -1
	## The kulhad / plate (on the pass, the tray, then the table).
	var item: Node3D = null
	var waiter: Node3D = null
	var created_at: float = 0.0
	var ready_at: float = 0.0
	## Core-and-feel C2.3: cooked while the pass was full; the item waits on
	## the plate stool (its cook holds until a pass slot frees).
	var held: bool = false


## One employee position at the counter.
class Slot:
	var index: int = 0
	var staff: Staff = null
	var anchor: Node3D = null
	var timer: RadialTimer = null
	var ticket: Ticket = null
	var phase: int = 0
	var delay: float = 0.0
	var elapsed: float = 0.0
	var duration: float = 2.0


var id: String = ""
var prop: Node3D = null
var tap_area: Area3D = null
## Tickets waiting for a cook (index 0 = next).
var queue: Array[Ticket] = []
var slots: Array = []             # of Slot
## Pass slot -> Ticket on it (null = free).
var pass_items: Array = []
## Core-and-feel C2.3: tickets whose item waits on the plate stool (pass
## full), oldest first; item k stands on Layout3.stool_points(id)[k].
var held_tickets: Array = []
var cooked_count: int = 0

## True while the station waits for its build reveal: cooks take no tickets.
var reveal_pending: bool = false

var _sim: Sim = null
var _paused: bool = false
# ---- prop animator (menu-expansion glbs; null when the part is missing)
const STEAM_POOL := 4
const STEAM_EVERY := 0.45
const STEAM_LIFE := 1.1
## Integration (2026-10-20): the spec's 0.55 alpha and 0.12 -> 0.42 m size
## were invisible over the light annex floor at game zoom (the glow texture
## is a soft smoothstep blob), so the puffs are a little denser and larger.
const STEAM_ALPHA := 0.8
const STEAM_SIZE0 := 0.16
const STEAM_SIZE1 := 0.5
const ANIM_EASE := 0.3            # s to ease a part back to rest when idle
## Per-station effects come from the pack (Idle Business Kit phase 3): the
## station's economy entry "fx" =
##   cook_sound   sound when a ticket starts (if the station is on screen)
##   dish_sounds  {dish: sound}, looked up first (station menus §9)
##   cook_pose    the cook's pose while a timer runs (default "serve")
##   steam_local  [x, y, z] station-local steam point; the station steams
##                only when it has one (a glb steam_socket wins over it)
##   parts        {spin, stir, heap, lid: glb node name} animated while cooking
##   board_text   painted-board lines (below)
##   fires        night fire glows (DayNight)
## Unlock props (station menus §7.4): scale and pop timing.
const PROP_SCALE := Vector3(0.14, 0.14, 0.14)
const PROP_POP_DELAY := 0.4
const PROP_POP := 0.35
## Painted text on a station glb's own board (QA round 2: the LASSI board on
## the wall behind the lassi counter; Blender cannot shape Devanagari, so the
## words are Label3Ds): [text, prop-local centre, max width, cap height,
## colour] per line. Faces the prop's +Z like the board (ART: v3_props.py
## LASSI_BOARD_C, face plane local z -1.5415). Polish round (2026-10-20): the
## board hangs lower and larger (face local x 0.27..1.23, y 0.43..0.99, clear
## of the window sill) and the words fill it right of the painted glass, so
## both read at home zoom (caps 0.2 / 0.15 m; were 0.115 / 0.075 m).
## Polish round 2 (2026-10-21): the board moved 1.42 m along the wall (local
## -X = world +Z) and 0.17 m down (face local x -1.15..-0.19, y 0.26..0.82),
## off the lassi cooks' radial timers (Bittu's covered "ल" / "LA"): at the
## home view it hangs left of Bittu under the medal button; the words move
## with it. Polish round 3 (2026-10-21, QA: in extreme close-up the marigold
## string along the board's top edge sat on the top bar of "लस्सी"): both
## words 3.5 / 1 cm lower (were y 0.645 / 0.415).
## Lines: [text, [x, y, z] prop-local centre, max width, cap height, [r, g, b]]
## in the station's fx.board_text.
const BOARD_FONT_SIZE := 96
## Cap height / em of the project font (Baloo 2; = Main3.SIGN_CAP_EM).
const BOARD_CAP_EM := 0.68
var _madhani: Node3D = null
var _madhani_rest: float = 0.0
var _heap: Node3D = null
var _heap_rest_rot: float = 0.0
var _heap_rest_scale: Vector3 = Vector3.ONE
var _lid: Node3D = null
var _lid_rest: float = 0.0
var _karchhi: Node3D = null
var _karchhi_rest: Vector3 = Vector3.ZERO
## Unlock props added so far, by dish index - 1 (k = 0 for dish 2).
var _props: Array = []
var _anim_t: float = 0.0
var _anim_amt: float = 0.0
var _at_rest: bool = false        # parts written at their rest pose (idle early-out)
var _steam_live: int = 0          # puffs in the air
var _steam_at: Node3D = null
var _steam_local: Vector3 = Vector3.ZERO
var _steam: Array = []            # of MeshInstance3D (pooled)
var _steam_t: Array = []          # age per puff (s; < 0 = idle)
var _steam_v: Array = []          # velocity per puff
var _steam_mats: Array = []
var _steam_next: float = 0.0
var _steam_i: int = 0
var _steam_col: Color = Color.WHITE
## The plate stool (built on the first held plate; hidden while empty).
var _stool: Node3D = null
## Last held count printed ([station] <id> held <n>, debug builds).
var _held_printed: int = 0
## Most plates held at once (debug / --stats).
var held_max: int = 0
## Ticket -> the Tween sliding its item (stool -> pass, or closing up on the
## stool): killed when a waiter lifts the item, so it never drifts on his tray.
var _slide_tw: Dictionary = {}
## The station's "fx" block from the pack ({} when none).
func _fx() -> Dictionary:
	var f: Variant = Game.station_def(id).get("fx", {})
	return f if f is Dictionary else {}


static func _v3(a: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


## Area3D tap target with meta tap_id (WorldInput raycasts these).
static func make_tap_area(size: Vector3, tap_id: String) -> Area3D:
	var a := Area3D.new()
	a.name = "Tap_" + tap_id.replace(":", "_")
	a.input_ray_pickable = true
	a.monitoring = false
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0.0, size.y * 0.5, 0.0)
	a.add_child(cs)
	a.set_meta("tap_id", tap_id)
	return a


## Area3D tap target made of world AABBs (menu expansion §2.7): at the world
## origin, no rotation, the same flags and meta as make_tap_area, one
## CollisionShape3D (BoxShape3D of `size`) per [centre at y 0, size] box.
static func make_tap_boxes(boxes: Array, tap_id: String) -> Area3D:
	var a := Area3D.new()
	a.name = "Tap_" + tap_id.replace(":", "_")
	a.input_ray_pickable = true
	a.monitoring = false
	a.monitorable = false
	for v in boxes:
		var b: Array = v
		var c: Vector3 = b[0]
		var sz: Vector3 = b[1]
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		cs.shape = bs
		cs.position = c + Vector3(0.0, sz.y * 0.5, 0.0)
		a.add_child(cs)
	a.set_meta("tap_id", tap_id)
	return a


## Replaces an existing tap area's boxes with world AABBs `boxes` (its metas,
## e.g. tap_id / galla_index, stay). The area must be inside the tree.
static func set_tap_boxes(area: Area3D, boxes: Array) -> void:
	if area == null or not is_instance_valid(area):
		return
	for c in area.get_children():
		if c is CollisionShape3D:
			area.remove_child(c)
			c.queue_free()
	var inv: Transform3D = area.global_transform.affine_inverse() if area.is_inside_tree() else Transform3D.IDENTITY
	for v in boxes:
		var b: Array = v
		var ctr: Vector3 = b[0]
		var sz: Vector3 = b[1]
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		cs.shape = bs
		cs.position = inv * (ctr + Vector3(0.0, sz.y * 0.5, 0.0))
		area.add_child(cs)


func setup(p_id: String, p_sim: Sim = null) -> void:
	id = p_id
	_sim = p_sim
	name = "Station_" + id
	var yaw: float = Layout3.station_yaw(id)
	prop = Models.make(Layout3.station_model(id), Layout3.station_fallback_size(id), Layout3.station_fallback_color(id))
	prop.position = Layout3.station_pos(id)
	prop.rotation.y = yaw
	add_child(prop)
	_add_board_text()
	var boxes: Array = Layout3.station_tap_boxes(id)
	if not boxes.is_empty():
		tap_area = make_tap_boxes(boxes, "station:" + id)
	else:
		tap_area = make_tap_area(Layout3.station_tap_size(id), "station:" + id)
		tap_area.position = Layout3.station_tap_center(id)
		tap_area.rotation.y = yaw
	add_child(tap_area)
	pass_items.resize(Layout3.pass_count(id))
	pass_items.fill(null)
	_setup_animator()
	sync_staff()
	_sync_unlock_props(false)
	if not Game.menu_unlocked.is_connected(_on_menu_unlocked):
		Game.menu_unlocked.connect(_on_menu_unlocked)


## BOARD_TEXT lines as Label3Ds on the prop (only over the real glb: the
## fallback box has no board).
func _add_board_text() -> void:
	var lines: Variant = _fx().get("board_text", [])
	if not (lines is Array) or (lines as Array).is_empty() or not Models.exists(Layout3.station_model(id)):
		return
	var font: Font = load("res://ui/main_font.tres") as Font
	for v in lines:
		var e: Array = v
		var text: String = e[0]
		var l := Label3D.new()
		l.name = "BoardText"
		# Painted board art: both words stay as painted in every language
		# ("LASSI" is also a UI msgid, which Label3D would auto-translate).
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.text = text
		l.font = font
		l.font_size = BOARD_FONT_SIZE
		var px: float = float(e[3]) / (BOARD_CAP_EM * float(BOARD_FONT_SIZE))
		if font != null:
			var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BOARD_FONT_SIZE).x
			if w > 0.0:
				px = minf(px, float(e[2]) / w)
		l.pixel_size = px
		l.outline_size = 12
		var col: Array = e[4]
		l.modulate = Color(float(col[0]), float(col[1]), float(col[2]))
		l.outline_modulate = Color(1.0, 0.97, 0.88)
		l.position = _v3(e[1])
		l.shaded = false
		l.double_sided = false
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		prop.add_child(l)


## Hidden until the build reveal (menu expansion §6): prop and cooks at
## scale 0.01, tickets queue but nobody cooks.
func begin_hidden() -> void:
	reveal_pending = true
	if prop != null:
		prop.scale = Vector3.ONE * 0.01
	for v in slots:
		var s: Slot = v
		if s.staff != null:
			s.staff.scale = Vector3.ONE * 0.01


## The build reveal: the prop scales 0.01 -> 1 (TRANS_BACK 0.35 s), each cook
## pops 0.12 + 0.08 x k s later, sparkles + "pop"; then the cooks start.
func reveal() -> void:
	if not reveal_pending:
		return
	if prop != null:
		var tw := prop.create_tween()
		tw.tween_property(prop, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var k: int = 0
	for v in slots:
		var s: Slot = v
		if s.staff != null:
			var tws := s.staff.create_tween()
			tws.tween_interval(0.12 + 0.08 * float(k))
			tws.tween_property(s.staff, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		k += 1
	var sp: Vector2 = Fx.screen_point(Layout3.station_pos(id) + Vector3(0.0, 0.9, 0.0))
	if sp.is_finite():
		Fx.sparkles(sp, 8, 60.0)
	Sfx.play("pop")
	reveal_pending = false
	_refresh()


## Adds employee slots up to Game.station_employees(id) (instant, no animation).
func sync_staff() -> void:
	var n: int = clampi(Game.station_employees(id), 1, Layout3.MAX_STATION_STAFF)
	while slots.size() < n:
		_add_slot(slots.size())
	_refresh()


func _add_slot(k: int) -> void:
	var s := Slot.new()
	s.index = k
	s.phase = P.IDLE
	s.staff = Staff.new()
	s.staff.name = "Staff%d" % k
	add_child(s.staff)
	s.staff.position = Layout3.station_staff(id, k)
	var ids: Array = []
	var staff_name: String = Game.station_staff_name(id, k)
	if staff_name != "":
		ids.append(staff_name.to_lower())
	ids.append_array(Layout3.station_staff_models(id, k))
	s.staff.setup(ids, Layout3.station_yaw(id), staff_name)
	if reveal_pending:
		s.staff.scale = Vector3.ONE * 0.01
	s.anchor = Node3D.new()
	s.anchor.name = "TimerAnchor%d" % k
	add_child(s.anchor)
	s.anchor.position = Layout3.station_timer_anchor(id, k)
	slots.append(s)


# ================================================================ queries
## Tickets waiting for a cook.
func queue_length() -> int:
	return queue.size()


## Waiting + cooking + finished-but-held tickets.
func line_count() -> int:
	var n: int = queue.size()
	for v in slots:
		var s: Slot = v
		if s.ticket != null:
			n += 1
	return n


func is_busy() -> bool:
	for v in slots:
		var s: Slot = v
		if s.ticket != null:
			return true
	return false


## Plates waiting on the plate stool (pass full; C2.3).
func held_count() -> int:
	return held_tickets.size()


## Items waiting on the pass.
func pass_used() -> int:
	var n: int = 0
	for v in pass_items:
		if v != null:
			n += 1
	return n


func focus_point() -> Vector3:
	return Layout3.station_focus(id)


func staff_node(k: int = 0) -> Staff:
	if k < 0 or k >= slots.size():
		return null
	var s: Slot = slots[k]
	return s.staff


func pass_point(k: int) -> Vector3:
	return Layout3.pass_point(id, k)


func pickup_point(k: int) -> Vector3:
	return Layout3.pass_pickup(id, k)


# ================================================================ tickets
func enqueue_ticket(tk: Ticket) -> void:
	if tk == null or queue.has(tk):
		return
	tk.station = self
	tk.station_id = id
	if tk.dish_id == "":
		tk.dish_id = Game.dish_at(id, 0)
		if tk.dish_id == "":
			tk.dish_id = id + "." + id
	tk.state = TK.QUEUED
	queue.append(tk)
	_refresh()


## Drops a ticket that is no longer wanted (its traveller is gone).
func cancel_ticket(tk: Ticket) -> void:
	if tk == null:
		return
	var i: int = queue.find(tk)
	if i >= 0:
		queue.remove_at(i)
	tk.state = TK.CANCELLED


## Seconds until `tk`'s item can be picked up (whole-order dispatch, Sim):
## 0 on the pass or held by its cook (pass full), the rest of the brew while
## a cook has it (start delay + brew). INF while it still waits for a cook:
## Sim never sends a waiter to stand at a pass for a queued item - with the
## pass full of other orders' items its cook could be stuck holding one of
## them, and the waiter who would clear that pass would be the one waiting.
## A cooking item always ends on the pass or in its cook's hands (hand_over).
func ticket_eta(tk: Ticket) -> float:
	if tk == null or tk.state == TK.CANCELLED:
		return INF
	if tk.pass_slot >= 0 or tk.state == TK.READY or tk.state == TK.ASSIGNED:
		return 0.0
	for v in slots:
		var s: Slot = v
		if s.ticket != tk:
			continue
		match s.phase:
			P.DELAY:
				return maxf(0.0, s.delay) + maxf(0.05, Game.dish_cook_time(id, tk.dish_id))
			P.RUN:
				return maxf(0.0, s.duration - s.elapsed)
			_:
				return 0.0
	return INF


## The waiter can lift `tk`'s item now: it is on the pass, or its cook is
## holding it because the pass is full.
func is_pickable(tk: Ticket) -> bool:
	if tk == null:
		return false
	if tk.pass_slot >= 0 and tk.pass_slot < pass_items.size() and pass_items[tk.pass_slot] == tk:
		return true
	return _held_slot(tk) != null


func _held_slot(tk: Ticket) -> Slot:
	for v in slots:
		var s: Slot = v
		if s.phase == P.HOLD and s.ticket == tk:
			return s
	return null


## A waiter standing at the pass takes `tk`'s item: off its pass slot, or -
## when the pass is full - straight from the cook holding it (the item pops
## at the pass end first, item_ready fires as for a pass item). Returns the
## item node (or null when it is not ready).
func hand_over(tk: Ticket) -> Node3D:
	if tk == null:
		return null
	if tk.pass_slot >= 0:
		return take_from_pass(tk)
	var s: Slot = _held_slot(tk)
	if s == null:
		return null
	s.ticket = null
	s.phase = P.IDLE
	if tk.held:
		# C2.3: the plate is already on the stool (READY since it landed there,
		# item_ready sent then): the waiter lifts it off; its cook is free.
		_unhold(tk)
		_stop_slide(tk)
		_refresh()
		return tk.item
	tk.state = TK.READY
	tk.ready_at = Traveller.now_s()
	if _sim != null:
		tk.item = _sim.acquire_item(id, tk.dish_id)
	if tk.item != null:
		tk.item.position = pass_point(0)
		tk.item.rotation = Vector3(0.0, randf() * TAU, 0.0)
		tk.item.scale = Vector3.ONE
		tk.item.visible = true
	item_ready.emit(self, tk)
	service_done.emit(self, tk.traveller)
	_refresh()
	return tk.item


## A waiter lifts `tk`'s item off the pass: frees its slot (a held cook can
## put the next item down) and returns the item node (or null).
func take_from_pass(tk: Ticket) -> Node3D:
	if tk == null:
		return null
	var k: int = tk.pass_slot
	if k >= 0 and k < pass_items.size() and pass_items[k] == tk:
		pass_items[k] = null
	tk.pass_slot = -1
	_stop_slide(tk)
	var item: Node3D = tk.item
	_release_holds()
	return item


func _free_pass_slot() -> int:
	for k in pass_items.size():
		if pass_items[k] == null:
			return k
	return -1


func _refresh() -> void:
	if reveal_pending:
		return
	for v in slots:
		var s: Slot = v
		if s.ticket == null and s.phase == P.IDLE and not queue.is_empty():
			var tk: Ticket = queue.pop_front()
			s.ticket = tk
			tk.state = TK.COOKING
			s.phase = P.DELAY
			s.delay = NEXT_DELAY


# ================================================================ cooking
func _start(s: Slot) -> void:
	s.phase = P.RUN
	s.elapsed = 0.0
	s.duration = maxf(0.05, Game.dish_cook_time(id, s.ticket.dish_id if s.ticket != null else ""))
	if s.timer == null or not is_instance_valid(s.timer):
		s.timer = Fx.make_radial_timer(s.anchor)
	if s.timer != null:
		s.timer.auto_finish = false
		s.timer.start(0.0)
		s.timer.set_progress(0.0)
		s.timer.pause(Game.sim_paused)
	if s.staff != null:
		s.staff.serve(true, str(_fx().get("cook_pose", "serve")))
	var t: Traveller = s.ticket.traveller if s.ticket != null else null
	_cook_sound(s.ticket.dish_id if s.ticket != null else "")
	ticket_started.emit(self, s.ticket)
	service_started.emit(self, t)


## churn / egg_crack / handi_bubble / kadai_sizzle when a menu-expansion cook
## starts a ticket and the station is on screen (per dish, then per station).
func _cook_sound(dish_id: String = "") -> void:
	var fx: Dictionary = _fx()
	var snd: String = str(fx.get("cook_sound", ""))
	var dish: String = dish_id.get_slice(".", 1) if dish_id.contains(".") else dish_id
	var by_dish: Variant = fx.get("dish_sounds", {})
	if dish != "" and by_dish is Dictionary and (by_dish as Dictionary).has(dish):
		snd = str((by_dish as Dictionary)[dish])
	if snd == "":
		return
	var cam: Node = Refs.camera
	if cam == null or not cam.has_method("is_on_screen"):
		return
	if bool(cam.call("is_on_screen", Layout3.station_pos(id) + Vector3(0.0, 0.8, 0.0), 40.0)):
		Sfx.play(snd)


func _process(delta: float) -> void:
	var p: bool = Game.sim_paused
	if p != _paused:
		_paused = p
		for v in slots:
			var s: Slot = v
			if s.timer != null and is_instance_valid(s.timer):
				s.timer.pause(p)
	if p:
		return
	_animate(delta)
	for v in slots:
		var s: Slot = v
		if s.phase == P.DELAY:
			s.delay -= delta
			if s.delay <= 0.0:
				_start(s)
		elif s.phase == P.RUN:
			s.elapsed += delta
			if s.timer != null and is_instance_valid(s.timer):
				s.timer.set_progress(minf(s.elapsed / s.duration, 1.0))
			if s.elapsed >= s.duration:
				_complete(s)


func _complete(s: Slot) -> void:
	var tk: Ticket = s.ticket
	if s.timer != null and is_instance_valid(s.timer):
		s.timer.finish()
	if s.staff != null:
		s.staff.serve(false)
		s.staff.turn_back()
	cooked_count += 1
	if tk == null or tk.state == TK.CANCELLED:
		s.ticket = null
		s.phase = P.IDLE
		_refresh()
		return
	# Price locked when the item is cooked (spec 3.4); per dish (station menus).
	tk.price = Game.dish_price(id, tk.dish_id)
	if not _try_place(tk):
		s.phase = P.HOLD
		_hold_on_stool(tk)
		return
	s.ticket = null
	s.phase = P.IDLE
	_refresh()


## Puts the finished item on a free pass slot. false = pass full. A plate
## waiting on the stool (C2.3) slides over to the slot: same item, same
## ready_at, no second item_ready.
func _try_place(tk: Ticket) -> bool:
	var k: int = _free_pass_slot()
	if k < 0:
		return false
	if tk.held:
		pass_items[k] = tk
		tk.pass_slot = k
		_unhold(tk)
		if tk.state != TK.ASSIGNED:
			tk.state = TK.READY
		_slide(tk, pass_point(k), 0.18, 1.0)
		return true
	pass_items[k] = tk
	tk.pass_slot = k
	tk.state = TK.READY
	tk.ready_at = Traveller.now_s()
	if _sim != null:
		tk.item = _sim.acquire_item(id, tk.dish_id)
	if tk.item != null:
		tk.item.position = pass_point(k)
		tk.item.rotation = Vector3(0.0, randf() * TAU, 0.0)
		tk.item.scale = Vector3.ONE * 0.01
		tk.item.visible = true
		var tw := tk.item.create_tween()
		tw.tween_property(tk.item, "scale", Vector3.ONE, ITEM_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	item_ready.emit(self, tk)
	service_done.emit(self, tk.traveller)
	return true


## A pass slot was cleared: cooks holding a finished item put it down now.
## Order (W4-FIX-world; slot order let a newer plate take the pass while the
## oldest, ringed, stayed on the stool): the stool plates nobody is coming
## for yet, oldest first (C2.3: held_tickets is in ready order; only these
## get a wait ring); then the stool plates a waiter is already walking to
## (he heads for pass slot 0 and lifts a stool plate from there: moving his
## plate along the pass would only send him after it); then any holder whose
## plate is not on the stool (more holders than stool spots: he finished
## after the stool filled). One cook is freed per free pass slot either way.
func _release_holds() -> void:
	var placed: bool = false
	var order: Array = []
	for coming in [false, true]:
		for tv in held_tickets:
			var tk: Ticket = tv
			if (tk.waiter != null) != coming:
				continue
			var hs: Slot = _held_slot(tk)
			if hs != null and not order.has(hs):
				order.append(hs)
	for v in slots:
		var s0: Slot = v
		if s0.phase == P.HOLD and s0.ticket != null and not order.has(s0):
			order.append(s0)
	# (order is a list of its own: _unhold and _try_place edit held_tickets)
	for v in order:
		var s: Slot = v
		if s.phase == P.HOLD and s.ticket != null:
			if s.ticket.state == TK.CANCELLED:
				if s.ticket.held:
					_unhold(s.ticket)
					if s.ticket.item != null and is_instance_valid(s.ticket.item):
						s.ticket.item.visible = false
				s.ticket = null
				s.phase = P.IDLE
				placed = true
			elif _try_place(s.ticket):
				s.ticket = null
				s.phase = P.IDLE
				placed = true
			else:
				break
	if placed:
		_refresh()


# ================================================================ plate stool (C2.3)
## The pass is full: the finished item goes at once onto the next free spot
## of the plate stool's tray (READY, item_ready once); the cook keeps holding.
## More holders than stool spots (never with 3 cooks): the old way (the cook
## holds the plate out of sight; hand_over makes it).
func _hold_on_stool(tk: Ticket) -> void:
	if tk == null or tk.held:
		return
	var pts: Array = Layout3.stool_points(id)
	var n: int = held_tickets.size()
	if n >= pts.size():
		return
	tk.held = true
	tk.pass_slot = -1
	tk.state = TK.READY
	tk.ready_at = Traveller.now_s()
	if tk.item == null and _sim != null:
		tk.item = _sim.acquire_item(id, tk.dish_id)
	held_tickets.append(tk)
	_show_stool(true)
	if tk.item != null:
		tk.item.position = pts[n]
		tk.item.rotation = Vector3(0.0, randf() * TAU, 0.0)
		tk.item.scale = Vector3.ONE * 0.01
		tk.item.visible = true
		var tw := tk.item.create_tween()
		tw.tween_property(tk.item, "scale", Vector3.ONE * _stool_scale(tk), ITEM_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_slide_done.bind(tk))
		_slide_tw[tk] = tw
	_note_held()
	item_ready.emit(self, tk)
	service_done.emit(self, tk.traveller)


## `tk` leaves the stool (to the pass or a waiter's tray): the others close up.
func _unhold(tk: Ticket) -> void:
	tk.held = false
	var i: int = held_tickets.find(tk)
	if i < 0:
		return
	held_tickets.remove_at(i)
	var pts: Array = Layout3.stool_points(id)
	for k in held_tickets.size():
		if k < pts.size():
			_slide(held_tickets[k], pts[k], 0.15, _stool_scale(held_tickets[k]))
	if held_tickets.is_empty():
		_show_stool(false)
	_note_held()


## Slides `tk`'s item to `to` (world) over `dur` s; `to_scale` > 0 also
## scales it to that size on the way (stool scale <-> full size on the pass).
func _slide(tk: Ticket, to: Vector3, dur: float, to_scale: float = -1.0) -> void:
	_stop_slide(tk)
	if tk.item == null or not is_instance_valid(tk.item):
		return
	if tk.item.position.distance_squared_to(to) < 0.000001:
		if to_scale > 0.0:
			tk.item.scale = Vector3.ONE * to_scale
		return
	var tw := tk.item.create_tween()
	tw.tween_property(tk.item, "position", to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if to_scale > 0.0:
		tw.parallel().tween_property(tk.item, "scale", Vector3.ONE * to_scale, dur)
	tw.tween_callback(_slide_done.bind(tk))
	_slide_tw[tk] = tw


## C2.3: the size of `tk`'s item on the plate stool. Items stand
## Layout3.PLATE_STOOL_GAP (0.17 m) apart, so a plate wider than that is
## scaled until neighbours keep 1 cm between them and the outer ones stay on
## the tray (R 0.28): roti / bhurji plates (r 0.135) 0.59, katoris (0.10)
## 0.8, glasses 1.0. Full size again on the pass and on the waiter's tray.
func _stool_scale(tk: Ticket) -> float:
	var r: float = float(Waiter.ITEM_RADIUS.get(Sim.item_model_for(id, tk.dish_id), Waiter.ITEM_RADIUS_DEFAULT))
	return minf(1.0, (Layout3.PLATE_STOOL_GAP - 0.01) / (2.0 * maxf(r, 0.01)))


func _slide_done(tk: Ticket) -> void:
	_slide_tw.erase(tk)


## A waiter lifts the item: no slide may move it any more.
func _stop_slide(tk: Ticket) -> void:
	if not _slide_tw.has(tk):
		return
	var tw: Tween = _slide_tw[tk]
	if tw != null and tw.is_valid():
		tw.kill()
	_slide_tw.erase(tk)


func _note_held() -> void:
	var n: int = held_tickets.size()
	held_max = maxi(held_max, n)
	if n != _held_printed:
		_held_printed = n
		if OS.is_debug_build():
			print("[station] %s held %d" % [id, n])


## The stool appears (pop) with the first held plate and hides when empty.
func _show_stool(on: bool) -> void:
	if not on:
		if _stool != null:
			_stool.visible = false
		return
	if _stool == null:
		_stool = _make_stool()
		_stool.name = "PlateStool"
		_stool.position = Layout3.stool_pos(id)
		_stool.rotation.y = PI * 0.25
		_no_prop_shadows(_stool)
		add_child(_stool)
	elif _stool.visible:
		return
	_stool.visible = true
	_stool.scale = Vector3.ONE * 0.01
	var tw := _stool.create_tween()
	tw.tween_property(_stool, "scale", Vector3.ONE, ITEM_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## W1-ART1's `plate_stool` (a wooden stool, top y 0.62, with a round steel
## tray R 0.28); until it exists a code stool of the same size.
static func _make_stool() -> Node3D:
	if Models.exists("plate_stool"):
		return Models.make("plate_stool")
	var root := Node3D.new()
	var top: float = Layout3.PLATE_STOOL_TOP
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.36, 0.2)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.78, 0.8, 0.82)
	steel.metallic = 0.5
	steel.roughness = 0.4
	var seat := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.36, 0.04, 0.36)
	sb.material = wood
	seat.mesh = sb
	seat.position = Vector3(0.0, top - 0.02, 0.0)
	root.add_child(seat)
	for v in [Vector2(-0.14, -0.14), Vector2(0.14, -0.14), Vector2(-0.14, 0.14), Vector2(0.14, 0.14)]:
		var c: Vector2 = v
		var leg := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.04, top - 0.04, 0.04)
		lb.material = wood
		leg.mesh = lb
		leg.position = Vector3(c.x, (top - 0.04) * 0.5, c.y)
		root.add_child(leg)
	var tray := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.28
	tc.bottom_radius = 0.27
	tc.height = 0.025
	tc.radial_segments = 16
	tc.rings = 1
	tc.material = steel
	tray.mesh = tc
	tray.position = Vector3(0.0, top + 0.0125, 0.0)
	root.add_child(tray)
	return root


# ================================================================ prop animator + steam
## The glb node the station's fx.parts names for `role`, or null.
func _part(parts: Dictionary, role: String) -> Node3D:
	var n: String = str(parts.get(role, ""))
	return prop.find_child(n, true, false) as Node3D if n != "" else null


## Caches the glb's animated parts (menu expansion §13.1 node names) and
## builds the steam pool (bhurji, dal). Missing parts are simply skipped.
func _setup_animator() -> void:
	_at_rest = false
	if prop == null:
		return
	var fx: Dictionary = _fx()
	var parts: Dictionary = fx.get("parts", {}) if fx.get("parts", {}) is Dictionary else {}
	_madhani = _part(parts, "spin")
	if _madhani != null:
		_madhani_rest = _madhani.rotation.y
	_heap = _part(parts, "heap")
	if _heap != null:
		_heap_rest_rot = _heap.rotation.y
		_heap_rest_scale = _heap.scale
	_lid = _part(parts, "lid")
	if _lid != null:
		_lid_rest = _lid.rotation.x
	_karchhi = _part(parts, "stir")
	if _karchhi != null:
		_karchhi_rest = _karchhi.rotation
	if not fx.has("steam_local"):
		return
	_steam_at = prop.find_child("steam_socket", true, false) as Node3D
	_steam_local = _v3(fx["steam_local"])
	_steam_col = Color(1.0, 0.97, 0.92)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var tex: Texture2D = FxTex.glow()
	for i in STEAM_POOL:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = tex
		mat.albedo_color = Color(_steam_col.r, _steam_col.g, _steam_col.b, 0.0)
		var mi := MeshInstance3D.new()
		mi.name = "Steam%d" % i
		mi.mesh = quad
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_steam.append(mi)
		_steam_mats.append(mat)
		_steam_t.append(-1.0)
		_steam_v.append(Vector3.ZERO)


func _any_running() -> bool:
	for v in slots:
		var s: Slot = v
		if s.phase == P.RUN:
			return true
	return false


## Per frame (unpaused): parts move while a cook is cooking and ease back to
## rest over ANIM_EASE s when idle; steam puffs rise. No allocations. Idle
## with the parts already back at rest and no puff in the air, it returns at
## once (no transform writes).
func _animate(delta: float) -> void:
	var running: bool = _any_running()
	if _madhani == null and _heap == null and _lid == null and _karchhi == null and _steam.is_empty():
		return
	if not running and _at_rest and _steam_live == 0:
		return
	var want: float = 1.0 if running else 0.0
	_anim_amt = move_toward(_anim_amt, want, delta / ANIM_EASE)
	if _anim_amt > 0.0:
		_anim_t += delta
	elif _anim_t != 0.0:
		_anim_t = 0.0
	var a: float = _anim_amt
	if _madhani != null:
		_madhani.rotation.y = _madhani_rest + a * 2.2 * sin(_anim_t * TAU * 1.6)
	if _heap != null:
		_heap.rotation.y = _heap_rest_rot + a * 0.25 * sin(_anim_t * TAU * 3.0)
		var sy: float = 1.0 + a * 0.08 * sin(_anim_t * TAU * 6.0)
		_heap.scale = Vector3(_heap_rest_scale.x, _heap_rest_scale.y * sy, _heap_rest_scale.z)
	if _lid != null:
		_lid.rotation.x = _lid_rest - a * 0.06 * maxf(0.0, sin(_anim_t * TAU * 2.2))
	if _karchhi != null:
		# Station menus §11.4: the karchhi sweeps +-0.35 rad round the kadai
		# at 1.3 Hz and dips 0.08 rad twice per sweep.
		_karchhi.rotation.y = _karchhi_rest.y + a * 0.35 * sin(_anim_t * TAU * 1.3)
		_karchhi.rotation.x = _karchhi_rest.x - a * 0.08 * maxf(0.0, sin(_anim_t * TAU * 2.6))
	_at_rest = a <= 0.0
	if _steam.is_empty():
		return
	if running and not reveal_pending:
		_steam_next -= delta
		if _steam_next <= 0.0:
			_steam_next = STEAM_EVERY
			_emit_steam()
	else:
		_steam_next = 0.0
	for i in _steam.size():
		var age: float = _steam_t[i]
		if age < 0.0:
			continue
		age += delta
		var mi: MeshInstance3D = _steam[i]
		if age >= STEAM_LIFE:
			_steam_t[i] = -1.0
			_steam_live -= 1
			mi.visible = false
			continue
		_steam_t[i] = age
		var u: float = age / STEAM_LIFE
		var vel: Vector3 = _steam_v[i]
		mi.position += vel * delta
		var sz: float = lerpf(STEAM_SIZE0, STEAM_SIZE1, 1.0 - (1.0 - u) * (1.0 - u))
		mi.scale = Vector3(sz, sz, sz)
		var mat: StandardMaterial3D = _steam_mats[i]
		mat.albedo_color = Color(_steam_col.r, _steam_col.g, _steam_col.b, STEAM_ALPHA * (1.0 - u))


# ================================================================ unlock props (station menus §7.4)
func _on_menu_unlocked(station_id: String, _dish_id: String) -> void:
	if station_id == id:
		_sync_unlock_props(true)


## One prop per unlocked dish 2-4 (Game.dish_prop, Layout3.unlock_prop_point):
## instant when `live` is false (setup / load), else a 0.01 -> 1 TRANS_BACK pop
## PROP_POP_DELAY s after the unlock (the NEW ON THE MENU pop lands first)
## with sparkles at its screen point. Visual only: no tap area, no obstacle.
func _sync_unlock_props(live: bool) -> void:
	var n: int = Game.dishes_unlocked(id)
	for k in range(_props.size(), maxi(0, n - 1)):
		var model: String = Game.dish_prop(id, k + 1)
		if model == "":
			model = "prop_%s_%d" % [id, k + 2]
		var p: Node3D = Models.make(model, PROP_SCALE, Layout3.station_fallback_color(id).lerp(Game.station_color(id), 0.5))
		p.name = "UnlockProp%d" % k
		p.position = Layout3.unlock_prop_point(id, k)
		p.rotation.y = Layout3.unlock_prop_yaw(id)
		_no_prop_shadows(p)
		add_child(p)
		_props.append(p)
		if live:
			p.scale = Vector3.ONE * 0.01
			var tw := p.create_tween()
			tw.tween_interval(PROP_POP_DELAY)
			tw.tween_callback(_prop_sparkles.bind(p))
			tw.tween_property(p, "scale", Vector3.ONE, PROP_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Unlock props standing on the station (debug / --stats).
func unlock_prop_count() -> int:
	return _props.size()


func _prop_sparkles(p: Node3D) -> void:
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return
	var sp: Vector2 = Fx.screen_point(p.global_position + Vector3(0.0, 0.12, 0.0))
	if sp.is_finite():
		Fx.sparkles(sp, 6, 40.0)


static func _no_prop_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_prop_shadows(c)


func _steam_origin() -> Vector3:
	if _steam_at != null and is_instance_valid(_steam_at) and _steam_at.is_inside_tree():
		return _steam_at.global_position
	if prop != null and prop.is_inside_tree():
		return prop.global_transform * _steam_local
	return Layout3.station_pos(id) + _steam_local


func _emit_steam() -> void:
	var i: int = _steam_i
	_steam_i = (_steam_i + 1) % _steam.size()
	var mi: MeshInstance3D = _steam[i]
	var o: Vector3 = _steam_origin()
	mi.position = o + Vector3(randf_range(-0.05, 0.05), 0.0, randf_range(-0.05, 0.05))
	mi.scale = Vector3.ONE * STEAM_SIZE0
	mi.visible = true
	_steam_v[i] = Vector3(randf_range(-0.05, 0.05), 0.35, randf_range(-0.05, 0.05))
	if float(_steam_t[i]) < 0.0:
		_steam_live += 1
	_steam_t[i] = 0.0
	var mat: StandardMaterial3D = _steam_mats[i]
	mat.albedo_color = Color(_steam_col.r, _steam_col.g, _steam_col.b, STEAM_ALPHA)
