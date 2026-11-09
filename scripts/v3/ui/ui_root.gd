class_name UiRoot
extends CanvasLayer
## v0.3 UI root (architecture "UI"; spec section 4, J14). Builds and owns:
##   Hud (CanvasLayer 10, its pills on 11/22), AdBubble (layer 12) + BuildTag
##   (price tag over the next station's ghost build pad) + the two HireSlots
##   ("+ WAITER" over the ghost waiter, "+ TABLE" over the next ghost table)
##   + SeatsFullPill (over the door) (layer 9), the QuickBuy card (layer 13),
##   StationSheet / StaffPanel / Daftar (this layer, 20), VipPopup /
##   OfflinePopup / SettingsPopup + 50% dim and the non-blocking MenuPop (NEW
##   ON THE MENU, kept above the open station sheet via sheet_top()) (layer 25),
##   QuitPopup ("LEAVE THE DHABA?", Android back with nothing to close; layer 40).
## Opens sheets and panels from world taps (Refs.world_input.tapped), relays
## every UI action as button_pressed(id) and gives the tutorial anchors.
##
## Round 2 step 2 (docs/round2/ui-proposal.md §3.2-3.8, mockups 01-04; owner
## decisions 4 and 5): people vs things.
##  - STAFF (StaffPanel) is the one place for every person: tabs WAITERS /
##    CASHIERS / COOKS, the HIRE card first. open_staff(tab, opts); tab "" =
##    the tab of StaffRows.best_hire() (else the problem role, else waiters).
##    Every door leads here: the HUD STAFF button, the NEXT chip, the cash
##    counter ("galla*" taps -> CASHIERS), the tray rack and ANY waiter
##    ("waiters" / "waiter_<i>" taps -> WAITERS), the counter sheet's banner
##    and BUILD's "STAFF ›" on a waiter-blocked row. open_waiters() /
##    open_galla() are wrappers (Director, autopilot and probes keep working).
##  - From the world, 2 taps (D2-a): the ghost waiter's "+ WAITER" tag (or a
##    tap on the ghost, "ghost_waiter") and a ghost table's "+ TABLE" tag (or
##    "ghost_table") open the QuickBuy card there; one more tap buys.
##  - BUILD (Daftar) covers counters AND tables: its TABLES row. The SEATING
##    panel is retired: open_seating() -> open_tables(): the ghost table's
##    card when the ghost is on screen, else BUILD with the TABLES row
##    highlighted. A tap on a built table opens BUILD › TABLES.
##  - One world tag (§3.8): in free play the build tag, the ghost waiter, the
##    ghost table and the "Seats full!" pill show only for tag_target(), the
##    NEXT chip's target ("build:<id>", "waiters", "tables"). In the tutorial
##    the hire slots / pill show only while the Director names their tap
##    family in allowed_taps (not "*").
##
## Panel names (panel_opened / panel_closed): "station:<id>",
## "staff:<tab>" (tab = waiters / cashiers / cooks; a tab switch inside the
## panel updates current_panel and emits button_pressed("staff_tab_<tab>")),
## "quick:waiters" / "quick:tables" (the 2-tap card), "daftar", "vip",
## "offline", "settings".
## button_pressed ids (emitted AFTER the action succeeded): "level_up",
## "hire" (a cook: counter sheet or STAFF › COOKS), "processing",
## "galla_upgrade_<i>", "galla_hire", "waiter_upgrade_<i>", "waiter_hire",
## "seating_add" (a table: quick card or BUILD's TABLES row), "build_<id>",
## "task_claim_<n>", "vip_free", "vip_unlock", "panel_close" (any X /
## outside-tap close), "ad_bubble", "table_tag" / "hire_slot_waiters" (a
## hire slot tag tapped), "build_tag", "seats_full_pill", "peti",
## "daftar_build_tab", "daftar_hisaab_tab", "staff_tab_<role>",
## "open_waiters" (BUILD's STAFF ›), "quick_buy_link", "goto_limit",
## "next_chip_<hint id>", "sheet_info", and the HUD buttons "staff_button",
## "stats_button", "build_button", "settings_button", "home_button".
##
## World tap ids: "station:<id>", "galla*", "waiters" (the tray rack),
## "waiter_<i>" (a waiter), "ghost_waiter", "tables" / "table*" / "seat*" /
## "charpai*" (a built table), "ghost_table*", "ad_bubble", "*_slab",
## "build:<id>". Gating families: every waiter id gates as "waiters", every
## table id as "tables", "build:*" as "build".
##
## Tutorial gating: `allowed_taps` filters world tap ids, `allowed_buttons`
## filters button ids (plus "panel_close" for X / outside taps); "*" allows
## everything. `lock_close` keeps panels open.
##
## Anchors (anchor()): staff_button, staff_tab_<role>, staff_hire_<role>,
## staff_hire_cooks_<id>, staff_upgrade_<role>_<i>, staff_close,
## quick_buy_button, quick_buy_link, ghost_waiter (the "+ WAITER" tag),
## table_tag (the "+ TABLE" tag), daftar_build_table, sheet_limit_button,
## sheet_close, next_chip, home_button, and the step-1 names kept as aliases:
## waiter_hire_button (the quick card's HIRE on a waiter card, else STAFF ›
## WAITERS' HIRE), galla_hire_button, waiter_close / galla_close (STAFF's X),
## waiter_upgrade_<i>, galla_upgrade_<i>, seating_add_button (the quick card's
## BUILD on a table card, else BUILD's TABLES button), rack_tag (= the ghost
## waiter tag), daftar_hire_waiter_<id> (BUILD's STAFF ›).
##
## Kept from the UX fix: the coach hand (coach_hand / clear_coach, first 2
## uses per kind), the ad bubble above the HUD, HOME -> CameraRig.fly_home(),
## open_vip(reward, free_only) with the VIP offer at most once per session,
## the offline popup queue.
##
## Launch integration (SDKs, docs/launch/sdk.md):
##  - every Iap.purchase_result becomes a toast in the current language
##    (SdkNotice: payment pending, cancelled, failed, store unavailable, a
##    pending payment granted later, purchases restored at launch);
##  - interstitial call site, a "natural pause" (GDD §6): "upgrade" when a
##    counter sheet / STAFF panel closes back to the game after an upgrade or
##    hire bought in it (not builds, tables or the quick card's hire: the
##    camera flies to those / a "+1 WAITER" float plays). Never in the
##    tutorial or while anything else is open; Ads applies the caps (core and
##    feel C7.1: interstitials off for the soft launch; session 4+, 180 s
##    apart, never within 60 s of a purchase, a reward or a rewarded video,
##    Remove Ads) and config [ads] interstitial_triggers says which call
##    sites are live (none today). The WELCOME BACK popup is never a call
##    site (the return screen: hard-coded in Ads).
##
## Core and feel (W1-MONEY):
##  - C4.4, one launch pop-up budget: can_interrupt(kind) / note_interrupt(kind)
##    for the analytics consent card, WELCOME BACK and Munshi-ji's "New
##    prices!" line (at most one per launch; the count lives in Game, so a
##    scene reload keeps it). A WELCOME BACK refused by the budget is paid
##    silently with a toast; is_any_open() also counts the consent card.
##  - C7.2: the FREE / VIP popup holds the wall-ad bubble while open
##    (Game.set_ad_hold) and FREE always consumes it; a rewarded ad owed from a
##    previous run (Game.ad_pending_paid) and the starter pack
##    (Game.starter_paid) arrive as a toast plus the usual burst.
##  - C7.4: open_vip() takes the popup variant ("free" | "starter" | "vip")
##    from Game.offer_variant() and marks it shown.
##
## Story (4 Nov): popup "phone" (PhonePopup, Simran's chat), opened by the
## HUD's PHONE (open_phone(); it reads every message); an outside tap or the
## X closes it, then PHONE's unread badge refreshes.
##
## Core and feel (W2-ROOT, build plan section 1 / 2.3):
##  - One fix router, do_fix(fix): the Game.bottleneck_fix() dict (also a
##    readout row's fix) opens the card that fixes it: hire waiter -> the
##    quick waiter card, upgrade waiter / hire or upgrade cashier -> STAFF,
##    table -> open_tables("fix"), cook / speed / level -> that counter's
##    sheet, signboard -> BUILD at the signboard row (coach hand on the
##    button while affordable). Sources: the counter sheet's banner
##    (action "fix" + StationSheet.fix_target, read by name), the readout's
##    rows and caption (BottleneckMeter.row_tapped / road_tapped, connected by
##    name), the NEXT chip's new panels ("quick:waiters", "promo:renovation",
##    "promo:move", "daftar:signboard", "event").
##  - C3.1: the quick waiter card sits next to Sim.oldest_waiting_plate() when
##    that projects on screen, else at the ghost waiter; when neither is on
##    screen the camera flies to the ghost first. A STAFF › WAITERS hire
##    closes STAFF 0.3 s later and shows the new waiter (fly and return, 2.5
##    s) only when the readout's limit was "waiters" just before the hire, at
##    most once a session and never while the Director is active; the same
##    rule (limit "seats") for a table bought in BUILD in free play.
##  - Popup "promo" (PromoPopup: the carry-over card of the Family Dhaba and
##    the NH 48 move, open_promo(kind, target)) and full panel "event"
##    (EventPanel: the weekend baraat, open_event(), also from the HUD's
##    BARAAT button). Both are registered in _show_popup / _hide_popup,
##    handle_back, _close_panel and _sync_world_cover.
##  - C6.2 Aaj ka special: at launch / resume (and on Game.special_changed)
##    a special that is active and not yet announced gets the band in WELCOME
##    BACK when that opens, else MenuPop's AAJ KA SPECIAL card over its
##    counter for 4 s once nothing covers the screen; then
##    Game.mark_special_announced() (which starts its 8-ticket showcase). Not
##    a launch pop-up (no budget).
##  - World note tags (world_note_tag.gd): "NEW: {dish}" over a counter
##    from its showcase until its showcase plates are served, "AAJ KA
##    SPECIAL" over the special's counter for the
##    rest of the session, and the drive-past line at the gate for 3 s.
##  - last_press_rect(): the last pressed button's rect (W2-FX aims the spend
##    notes there while a panel covers the world).
##  - Debug prints: "[ui] quick waiters: near plates|flew to ghost|on screen",
##    "[ui] special announced: <dish> (<where>)", "[ui] promo popup <kind>
##    ready=<bool>", "[ui] staff hire: closed and flew|stayed (<why>)", "[ui]
##    build table: ...", "[ui] fix <kind> (<source>)", "[ui] build rows: ..."
##    (Daftar), "[ui] event panel: ..." (EventPanel).

signal panel_opened(name: String)
signal panel_closed(name: String)
signal button_pressed(id: String)
## The coach hand (coach_hand) went away.
signal coach_cleared

const LAYER_BUBBLE := 9
const LAYER_AD := 12
const LAYER_QUICK := 13
const COACH_MAX := 2
const COACH_DELAY := 0.35
const COACH_RESOLVE_S := 1.0
const LAYER_PANELS := 20
const LAYER_POPUP := 25
## The quit question (Android back): over everything, the dialogue box too.
const LAYER_QUIT := 40
const DOOR_WAIT_METHODS := ["seats_waiting", "door_waiting_count", "seat_wait_count",
		"waiting_for_seat", "door_queue_length", "door_waiting"]
const DOOR_WAIT_PROPS := ["door_queue", "seat_queue", "door_line", "seat_waiters"]
const GHOST_POLL := 0.2
## A ghost table counts as on screen inside these margins (px): clear of the
## HUD band at the top and the buttons at the bottom.
const ON_SCREEN_TOP := 260.0
const ON_SCREEN_BOTTOM := 200.0
const ON_SCREEN_SIDE := 40.0
## button_pressed ids that are an upgrade / hire bought in a sheet or panel
## (prefixes): the "upgrade" interstitial waits for that panel to close.
const UPGRADE_IDS := ["level_up", "hire", "processing", "galla_upgrade_", "galla_hire",
		"waiter_upgrade_", "waiter_hire"]
## Seconds after the close before an interstitial may show (close animation,
## camera restore).
const INTERSTITIAL_DELAY := 0.6
## C4.4: a WELCOME BACK held back by something open is retried this often.
const OFFLINE_POLL_S := 0.5
## C4.4: chai's level before the consent card may open (the first counter
## levelled, the change list's "none before the first counter is levelled").
const CONSENT_MIN_CHAI := 10
## Soft launch analytics: once-per-install funnel events.
const Funnel := preload("res://scripts/v3/core/funnel.gd")
## Android back's "LEAVE THE DHABA?" (FLOW track).
const QuitPopupScript := preload("res://scripts/v3/ui/quit_popup.gd")
## Core and feel (W2-ROOT): no class_name, loaded by path.
const PromoPopupScript := preload("res://scripts/v3/ui/promo_popup.gd")
const EventPanelScript := preload("res://scripts/v3/ui/event_panel.gd")
## 5 Nov (owner): MENU, every counter's dish upgrades.
const MenuPanelScript := preload("res://scripts/v3/ui/menu_panel.gd")
const WorldNoteTagScript := preload("res://scripts/v3/ui/world_note_tag.gd")
## C3.1: the quick waiter card's tip this high over the oldest waiting plate.
const PLATE_CARD_Y := 0.55
## C3.1: the longest wait for the camera's fly to the ghost waiter (s).
const QUICK_FLY_MAX_S := 2.2
## C3.1: STAFF closes this long after the hire that fixes the limit.
const STAFF_CLOSE_DELAY := 0.3
## C6.2: how often a special waiting for its announcement re-checks (s).
const SPECIAL_POLL_S := 0.5
## C6.2: how long the card waits for a WELCOME BACK still to decide (the
## band rides in it) before it shows on its own (s).
const SPECIAL_OFFLINE_WAIT_S := 3.0
## C3.1: how often the readout's limit is sampled while STAFF / BUILD is open.
const LIMIT_POLL_S := 0.25
## C3.1: the camera holds on the new waiter / table this long.
const SHOW_HOLD_S := 2.5
## Half size of the rect around a press with no button under it (px).
const PRESS_HALF := 40.0
## The readout widgets' hooks are re-checked this often (s).
const HUD_HOOK_POLL := 0.5

var hud: Hud
var station_sheet: StationSheet
## Round 2 step 2: every person (waiters, cashiers, cooks).
var staff_panel: StaffPanel
var daftar: Daftar
var vip_popup: VipPopup
var ad_bubble: AdBubble
## "+ TABLE" over the next ghost table (was the "ADD TABLE" TableTag).
var table_tag: HireSlot
## "+ WAITER" over the ghost waiter (was the "WAITERS 1/3" RackTag).
var waiter_tag: HireSlot
## Old name of waiter_tag (MunshiNotes reads it).
var rack_tag: HireSlot
var build_tag: BuildTag
var seats_pill: SeatsFullPill
## Dhaba growth step 3: the timer tag over a building site.
var build_site_tag: BuildSiteTag
## The 2-tap card on a ghost (layer 13).
var quick_buy: QuickBuy
## The old tutorial's waiter beat lets the ghost-waiter tag show before the
## tutorial is done (with "waiters" named in allowed_taps); ignored once the
## tutorial is done.
var rack_tag_unlocked: bool = false
var offline_popup: OfflinePopup
var settings_popup: SettingsPopup
var phone_popup: PhonePopup
var menu_pop: MenuPop
## "LEAVE THE DHABA?" (handle_back with nothing to close; layer LAYER_QUIT;
## scripts/v3/ui/quit_popup.gd).
var quit_popup: QuitPopupScript
## Core and feel: the promotion carry-over popup ("promo") and the weekend
## baraat panel ("event").
var promo_popup: PromoPopupScript
var event_panel: EventPanelScript
var menu_panel: MenuPanelScript
## World note tags: one per counter, then the gate tag.
var note_tags: Array = []
var gate_tag: WorldNoteTagScript

var allowed_taps: Array[String] = ["*"]
var allowed_buttons: Array[String] = ["*"]
var lock_close: bool = false
## After a table is built (quick card or BUILD): close it and fly the camera
## to the new table so the J18 pop-in is seen (skipped while `lock_close`).
var close_seating_on_add: bool = true

## "" or the open panel / popup name.
var current_panel: String = ""
var current_popup: String = ""

var _panel_root: Control
var _bubble_layer: CanvasLayer
var _quick_layer: CanvasLayer
var _popup_layer: CanvasLayer
var _popup_root: Control
var _popup_dim: ColorRect
var _dim_tw: Tween
var _world_connected: bool = false
var _queued_offline: bool = false
var _door_waiting_push: int = -1
var _ad_layer: CanvasLayer
var _ghost_t: float = 0.0
var _ghost_waiter_on: bool = false
# coach hand state (coach_hand)
var _coach_seq: int = 0
var _coach_shown: bool = false
var _coach_control: Control
var _coach_panel: String = ""
var _coach_popup: String = ""
## Fallback use counts while Game has no counter() (a session only).
var _coach_local: Dictionary = {}
## An upgrade / hire was bought in the open panel (the "upgrade" interstitial).
var _bought_in_panel: bool = false
## The 3D world is switched off under a full-screen panel (_sync_world_cover).
## True at first: the first _process writes disable_3d = false (W1-FIX-money).
var _world_covered: bool = true
## C4.4: launch pop-ups counted here only while Game has no popup budget
## (before core and feel's game.gd).
var _local_popups: int = 0
## C4.4: WELCOME BACK waits for the screen to be free (polled).
var _offline_waiting: bool = false
var _offline_poll_t: float = 0.0
## C3.1: the readout's limit just before the last "waiter_hire" / "table"
## spend (Game.cash_spent fires before the purchase changes anything).
var _limit_at_spend: Dictionary = {}
## C3.1: STAFF hire / BUILD table "closed and flew" used this session.
static var _staff_close_used: bool = false
static var _table_close_used: bool = false
## C3.1: the readout's limit sampled while STAFF or BUILD is open (copied into
## _limit_at_spend when the purchase spends; read from the cache, never from
## inside Game.spend()).
var _limit_seen: String = ""
var _limit_t: float = 0.0
## C3.1: the quick waiter card waiting for the camera's fly (its sequence).
var _quick_fly_seq: int = 0
var _quick_flying: bool = false
## [anchor, kind] of the coach hand the next quick waiter card gets.
var _quick_coach: Array = []
## upgrade_bought's source for the next quick waiter card (plan 2.8, C3.1):
## "chip" when the NEXT chip asked for it, else "world_card" (set on QuickBuy
## by name, rule 5).
var _quick_source: String = "world_card"
## C6.2: a special waits for its announcement (polled), and the one announced
## this session (its counter's tag).
var _special_wait: bool = false
var _special_poll_t: float = 0.0
var _special_wait_t: float = 0.0
static var _special_tag_dish: String = ""
## The readout widgets (W2-HUD) whose signals are connected here.
var _meter_hooked: Object = null
var _event_btn_hooked: Object = null
var _hud_hook_t: float = HUD_HOOK_POLL
## last_press_rect(): the last press (canvas px), and the rect found for it.
var _press_pos: Vector2 = Vector2.ZERO
var _press_seen: bool = false
var _press_id: int = 0
var _press_rect: Rect2 = Rect2()
var _press_rect_id: int = -1
## A debug `--open` of BUILD / STATS refused by an open popup (WELCOME BACK
## at launch): opened when the popup closes (free play only).
var _queued_daftar: String = ""


func _ready() -> void:
	layer = LAYER_PANELS
	_panel_root = Control.new()
	_panel_root.name = "Panels"
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)
	_panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiPattern.prewarm(_panel_root)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.gate = can_press
	hud.button_pressed.connect(_on_hud_button)

	_bubble_layer = CanvasLayer.new()
	_bubble_layer.name = "AdBubbleLayer"
	_bubble_layer.layer = LAYER_BUBBLE
	add_child(_bubble_layer)
	# A4.2: the ad bubble above the HUD buttons and pills, below the panels.
	_ad_layer = CanvasLayer.new()
	_ad_layer.name = "AdLayer"
	_ad_layer.layer = LAYER_AD
	add_child(_ad_layer)
	ad_bubble = AdBubble.new()
	ad_bubble.name = "AdBubble"
	_ad_layer.add_child(ad_bubble)
	ad_bubble.tapped.connect(_on_bubble_tapped)
	_ad_layer.add_child(UiJuice.new())
	table_tag = HireSlot.new()
	table_tag.kind = "tables"
	table_tag.name = "TableSlot"
	table_tag.allowed_fn = _table_tag_allowed
	_bubble_layer.add_child(table_tag)
	table_tag.tapped.connect(_on_table_tag_tapped)
	build_tag = BuildTag.new()
	build_tag.name = "BuildTag"
	build_tag.allowed_fn = _build_tag_allowed
	_bubble_layer.add_child(build_tag)
	build_tag.tapped.connect(_on_build_tag_tapped)
	seats_pill = SeatsFullPill.new()
	seats_pill.name = "SeatsFullPill"
	seats_pill.count_fn = _seats_pill_count
	_bubble_layer.add_child(seats_pill)
	seats_pill.tapped.connect(_on_seats_pill_tapped)
	waiter_tag = HireSlot.new()
	waiter_tag.kind = "waiters"
	waiter_tag.name = "WaiterSlot"
	waiter_tag.allowed_fn = _waiter_tag_allowed
	_bubble_layer.add_child(waiter_tag)
	waiter_tag.tapped.connect(_on_waiter_tag_tapped)
	rack_tag = waiter_tag
	build_site_tag = BuildSiteTag.new()
	build_site_tag.name = "BuildSiteTag"
	build_site_tag.ad_ready_fn = func() -> bool: return Ads.is_rewarded_ready("build_skip")
	build_site_tag.free_fn = func() -> bool: return Game.build_free_skip_ready()
	_bubble_layer.add_child(build_site_tag)
	build_site_tag.tapped.connect(_on_build_site_tapped)
	hud.next_chip.tapped.connect(_on_next_chip_tapped)

	_quick_layer = CanvasLayer.new()
	_quick_layer.name = "QuickLayer"
	_quick_layer.layer = LAYER_QUICK
	add_child(_quick_layer)
	quick_buy = QuickBuy.new()
	quick_buy.name = "QuickBuy"
	quick_buy.gate = can_press
	_quick_layer.add_child(quick_buy)
	quick_buy.action.connect(_on_quick_action)
	quick_buy.link.connect(_on_quick_link)
	quick_buy.outside_tapped.connect(_on_quick_outside)
	_quick_layer.add_child(UiJuice.new())

	station_sheet = StationSheet.new()
	station_sheet.name = "StationSheet"
	_panel_root.add_child(station_sheet)
	station_sheet.gate = can_press
	station_sheet.toast_fn = hud.toast
	station_sheet.outside_tapped.connect(_on_sheet_outside)
	station_sheet.close_pressed.connect(_on_sheet_x)
	station_sheet.action.connect(_on_sheet_action)

	staff_panel = StaffPanel.new()
	staff_panel.name = "StaffPanel"
	_panel_root.add_child(staff_panel)
	staff_panel.gate = can_press
	staff_panel.close_pressed.connect(_on_panel_x)
	staff_panel.action.connect(_on_staff_action)
	staff_panel.tab_changed.connect(_on_staff_tab)

	daftar = Daftar.new()
	daftar.name = "Daftar"
	_panel_root.add_child(daftar)
	daftar.gate = can_press
	daftar.close_pressed.connect(_on_panel_x)
	daftar.action.connect(_on_daftar_action)

	# C6.4: the weekend baraat panel (a full panel like STAFF).
	event_panel = EventPanelScript.new()
	event_panel.name = "EventPanel"
	_panel_root.add_child(event_panel)
	event_panel.gate = can_press
	event_panel.hud = hud
	event_panel.close_pressed.connect(_on_panel_x)
	event_panel.action.connect(_relay)
	menu_panel = MenuPanelScript.new()
	menu_panel.name = "MenuPanel"
	_panel_root.add_child(menu_panel)
	menu_panel.gate = can_press
	menu_panel.close_pressed.connect(_on_panel_x)
	menu_panel.action.connect(_on_menu_action)

	add_child(UiJuice.new())

	_popup_layer = CanvasLayer.new()
	_popup_layer.name = "Popups"
	_popup_layer.layer = LAYER_POPUP
	add_child(_popup_layer)
	_popup_root = Control.new()
	_popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.add_child(_popup_root)
	_popup_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_dim = ColorRect.new()
	_popup_dim.color = Color(0, 0, 0, 0.0)
	_popup_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_dim.visible = false
	_popup_dim.gui_input.connect(_on_dim_input)
	_popup_root.add_child(_popup_dim)
	_popup_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	vip_popup = VipPopup.new()
	vip_popup.name = "VipPopup"
	_popup_root.add_child(vip_popup)
	vip_popup.gate = can_press
	vip_popup.hud = hud
	vip_popup.close_pressed.connect(_on_popup_x)
	vip_popup.action.connect(_on_vip_action)

	offline_popup = OfflinePopup.new()
	offline_popup.name = "OfflinePopup"
	_popup_root.add_child(offline_popup)
	offline_popup.hud = hud
	offline_popup.closed.connect(_on_offline_closed)

	settings_popup = SettingsPopup.new()
	settings_popup.name = "SettingsPopup"
	_popup_root.add_child(settings_popup)
	settings_popup.close_pressed.connect(_on_popup_x)

	phone_popup = PhonePopup.new()
	phone_popup.name = "PhonePopup"
	_popup_root.add_child(phone_popup)
	phone_popup.close_pressed.connect(_on_popup_x)

	# C5.2 / C6.1 / C6.3: the promotion carry-over popup.
	promo_popup = PromoPopupScript.new()
	promo_popup.name = "PromoPopup"
	_popup_root.add_child(promo_popup)
	promo_popup.gate = can_press
	promo_popup.close_pressed.connect(_on_popup_x)
	promo_popup.action.connect(_on_promo_action)
	_popup_layer.add_child(UiJuice.new())

	# Station menus §7.2: the NEW ON THE MENU pop, over everything, non-blocking.
	menu_pop = MenuPop.new()
	menu_pop.name = "MenuPop"
	menu_pop.sheet_top_fn = sheet_top
	_popup_root.add_child(menu_pop)
	Game.menu_unlocked.connect(_on_menu_unlocked)

	# Android back with nothing to close: "LEAVE THE DHABA?", above
	# Munshi-ji's box (30) and the hand (32).
	var quit_layer := CanvasLayer.new()
	quit_layer.name = "QuitLayer"
	quit_layer.layer = LAYER_QUIT
	add_child(quit_layer)
	quit_popup = QuitPopupScript.new()
	quit_popup.name = "QuitPopup"
	quit_layer.add_child(quit_popup)
	quit_popup.answered.connect(_on_quit_answered)
	quit_layer.add_child(UiJuice.new())

	# C3.5 / C6.2 / C2.7: the world note tags (below the panels, with the
	# other world tags).
	for sid: String in Game.station_ids():
		var nt: WorldNoteTagScript = WorldNoteTagScript.new()
		nt.mode = "counter"
		nt.station_id = sid
		nt.name = "NoteTag_" + sid
		nt.allowed_fn = _note_tags_allowed
		nt.special_fn = _special_tag
		nt.busy_fn = _menu_pop_station
		_bubble_layer.add_child(nt)
		note_tags.append(nt)
	gate_tag = WorldNoteTagScript.new()
	gate_tag.mode = "gate"
	gate_tag.name = "GateTag"
	gate_tag.allowed_fn = _note_tags_allowed
	_bubble_layer.add_child(gate_tag)

	Game.offline_earnings_ready.connect(_on_offline_ready)
	if Refs.ui == null:
		Refs.ui = self
	if Refs.hud == null:
		Refs.hud = hud
	button_pressed.connect(_on_any_button_for_coach)
	# Launch integration: purchase messages and interstitial call sites.
	button_pressed.connect(_note_purchase)
	panel_closed.connect(_on_closed_for_interstitial)
	var iap: Node = UiKit.autoload("Iap")
	if iap != null and iap.has_signal("purchase_result"):
		iap.connect("purchase_result", _on_purchase_result)
	var ads: Node = UiKit.autoload("Ads")
	if ads != null and ads.has_signal("interstitial_finished"):
		ads.connect("interstitial_finished", _on_interstitial_finished)
	# C7.2 / C7.4: money that arrives on its own (core and feel's Game signals,
	# connected by name).
	if Game.has_signal("ad_pending_paid") and not Game.is_connected("ad_pending_paid", _on_ad_pending_paid):
		Game.connect("ad_pending_paid", _on_ad_pending_paid)
	if Game.has_signal("starter_paid") and not Game.is_connected("starter_paid", _on_starter_paid):
		Game.connect("starter_paid", _on_starter_paid)
	# Core and feel (wave 1 merged): the limit before a hire / table (C3.1)
	# and the special's announcement (C6.2).
	Game.cash_spent.connect(_on_cash_spent)
	Game.special_changed.connect(_on_special_changed)
	# C6.4: the weekend window closing shuts the baraat panel.
	Game.event_changed.connect(_on_event_window)
	# No popup is open in a new UI (a scene reload after a promotion keeps Game).
	_set_ad_hold(false)
	_try_connect_world.call_deferred()
	_check_pending_offline.call_deferred()
	# C6.2: after WELCOME BACK has decided (the band rides in it), else the card.
	_queue_special_check()
	set_process(true)


# ================================================================ gating
func can_press(id: String) -> bool:
	return allowed_buttons.has("*") or allowed_buttons.has(id)


func _tap_allowed(tap_id: String) -> bool:
	return allowed_taps.has("*") or allowed_taps.has(tap_id)


## The Director names this tap family on purpose (not just "*").
func _tap_named(tap_id: String) -> bool:
	return not allowed_taps.has("*") and allowed_taps.has(tap_id)


## Convenience for the tutorial: [] blocks all, ["*"] allows all.
func set_allowed_taps(ids: Array) -> void:
	allowed_taps.clear()
	for v in ids:
		allowed_taps.append(str(v))


func set_allowed_buttons(ids: Array) -> void:
	allowed_buttons.clear()
	for v in ids:
		allowed_buttons.append(str(v))


# ================================================================ panels
func open_station(id: String) -> void:
	# Core and feel: main3's --open=<name> sends unknown names here; "event"
	# and "promo:<kind>" are panels / popups, not counters.
	if id == "event":
		open_event()
		return
	if id.begins_with("promo:"):
		open_promo(id.substr(6))
		return
	if current_popup != "" or not Game.is_built(id):
		return
	var pname: String = "station:" + id
	if current_panel == pname:
		return
	if current_panel != "":
		_close_panel(false)
	station_sheet.open(id)
	hud.set_mode("sheet")
	_cam_call("panel_focus", [_station_focus(id)])
	current_panel = pname
	Sfx.play("tap", 0.02)
	panel_opened.emit(pname)


## STAFF on `tab` ("waiters", "cashiers", "cooks"; "" = the tab that needs
## it most). opts.highlight "hire": the HIRE card gets a small punch.
func open_staff(tab: String = "", opts: Dictionary = {}) -> void:
	if current_popup != "":
		return
	var t: String = tab if StaffPanel.ROLES.has(tab) else default_staff_tab()
	if current_panel.begins_with("staff:"):
		staff_panel.select_tab(t)
		return
	if current_panel != "":
		_close_panel(true)
	staff_panel.open_tab(t, opts)
	hud.set_mode("panel")
	current_panel = "staff:" + t
	_sample_limit()
	Sfx.play("tap", 0.02)
	panel_opened.emit(current_panel)


## The tab STAFF opens on by itself (Game.staff_tab(): the badge's tab, the
## best hire's role, the limiting stage's role, else WAITERS).
func default_staff_tab() -> String:
	return StaffRows.default_tab()


## Wrappers kept for the Director, the autopilot and probes.
func open_galla() -> void:
	open_staff("cashiers")


func open_waiters() -> void:
	open_staff("waiters")


## The SEATING panel is retired: tables are built from the ghost table's
## card or BUILD › TABLES (open_tables).
func open_seating() -> void:
	open_tables("seating")


## The ghost table's 2-tap card when the ghost is on screen, else BUILD with
## the TABLES row highlighted. Returns "quick", "daftar" or "".
func open_tables(source: String = "") -> String:
	if current_popup != "":
		return ""
	if _ghost_table_on_screen():
		open_quick("tables")
		return "quick"
	open_daftar("build")
	daftar.focus_tables()
	if source != "":
		Analytics.event("tables_open", {"source": source})
	return "daftar"


## The 2-tap card on a ghost: "waiters" (the ghost waiter) or "tables" (the
## next ghost table). Core and feel C3.1: the waiter card sits by the oldest
## waiting plate when that is on screen, else at the ghost waiter, and the
## camera flies to the ghost first when neither is on screen.
## `source` "tap" / "tag" (the player tapped the ghost or its tag: never a
## camera fly) or anything else ("open", "chip", "fix").
func open_quick(kind: String, source: String = "open") -> void:
	if current_popup != "":
		return
	if kind != "tables":
		_open_quick_waiters(source)
		return
	var n: int = UiKit.gint("table_count", [], 0)
	if n >= UiKit.gint("table_max", [], 0) or not TableTag.has_table_point(n):
		return
	if current_panel != "":
		_close_panel(true)
	quick_buy.set("source", "world_card")
	quick_buy.open_for("tables", TableTag.table_point(n) + Vector3(0.0, HireSlot.TABLE_TAG_Y, 0.0), n)
	current_panel = "quick:" + kind
	Sfx.play("pop", 0.02)
	panel_opened.emit(current_panel)


## C3.1: the quick waiter card. `source` "tap" / "tag" (the player tapped the
## ghost or its tag, so the ghost is on screen: never a fly) or anything else.
## `coach` / `coach_kind`: a coach hand for the card's HIRE once it shows
## (after a camera fly too). An open counter sheet closes first and its view
## comes back, so the on-screen tests see the view the card will sit in.
func _open_quick_waiters(source: String, coach: String = "", coach_kind: String = "") -> void:
	if current_popup != "":
		return
	if not StaffRows.can_hire("waiters"):
		open_staff("waiters")
		return
	_quick_fly_seq += 1
	var seq: int = _quick_fly_seq
	_quick_flying = false
	_quick_coach = [coach, coach_kind] if coach != "" else []
	_quick_source = "chip" if source == "chip" else "world_card"
	if current_panel.begins_with("station:"):
		_close_panel(true)
		await _camera_settled(seq, QUICK_FLY_MAX_S)
		if seq != _quick_fly_seq or current_panel != "" or current_popup != "" or _quit_open():
			return
	var i: int = StaffRows.count("waiters")
	var ghost: Vector3 = Layout3.waiter_home(i) + Vector3(0.0, HireSlot.WAITER_TAG_Y, 0.0)
	var plate: Vector3 = _oldest_plate()
	if plate.is_finite() and _point_on_screen(plate + Vector3(0.0, PLATE_CARD_Y, 0.0)):
		print("[ui] quick waiters: near plates")
		_show_quick_waiters(plate + Vector3(0.0, PLATE_CARD_Y, 0.0), i)
		return
	if source == "tap" or source == "tag" or _point_on_screen(ghost) or Refs.camera == null:
		print("[ui] quick waiters: on screen")
		_show_quick_waiters(ghost, i)
		return
	print("[ui] quick waiters: flew to ghost")
	if current_panel != "":
		_close_panel(false)
	_fly_then_quick(seq, ghost, i)


func _show_quick_waiters(at: Vector3, i: int) -> void:
	if current_panel != "":
		_close_panel(true)
	quick_buy.set("source", _quick_source)
	quick_buy.open_for("waiters", at, i)
	current_panel = "quick:waiters"
	Sfx.play("pop", 0.02)
	panel_opened.emit(current_panel)
	if not _quick_coach.is_empty():
		var c: Array = _quick_coach
		_quick_coach = []
		coach_hand(str(c[0]), {"kind": str(c[1]) if str(c[1]) != "" else str(c[0])})


## Flies the camera to the ghost waiter, then opens his card there (unless
## something else opened meanwhile, Android back asked to quit, or a newer
## request replaced this one).
func _fly_then_quick(seq: int, ghost: Vector3, i: int) -> void:
	_quick_flying = true
	_cam_call("fly_to", [Vector3(ghost.x, 0.0, ghost.z), -1.0])
	await _camera_settled(seq, QUICK_FLY_MAX_S)
	if seq != _quick_fly_seq:
		return
	_quick_flying = false
	if current_panel != "" or current_popup != "" or _quit_open():
		return
	_show_quick_waiters(ghost, i)


## W2-FIX-ui: the quit question ("LEAVE THE DHABA?") is up. A back press
## during a deferred quick card open (camera fly, sheet close) cancels the
## card: it is neither a panel nor a popup, so the guards ask for it.
func _quit_open() -> bool:
	return quit_popup != null and quit_popup.is_open()


## Waits (at most `max_s`) until the camera stops moving, or a newer quick
## card request replaces `seq`.
func _camera_settled(seq: int, max_s: float) -> void:
	var cam: Node = Refs.camera
	var left: float = max_s
	await get_tree().process_frame
	while left > 0.0 and seq == _quick_fly_seq:
		if cam == null or not is_instance_valid(cam) or not cam.has_method("is_busy") or not bool(cam.call("is_busy")):
			return
		await get_tree().process_frame
		left -= get_process_delta_time()


## Sim.oldest_waiting_plate() (Vector3.INF when none or no Sim).
func _oldest_plate() -> Vector3:
	var sv: Variant = Refs.sim
	if not is_instance_valid(sv) or not (sv as Object).has_method("oldest_waiting_plate"):
		return Vector3.INF
	var p: Variant = (sv as Object).call("oldest_waiting_plate")
	return p if p is Vector3 else Vector3.INF


## A world point projects inside the screen margins (a card above it fits).
func _point_on_screen(p: Vector3) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or not p.is_finite() or cam.is_position_behind(p):
		return false
	var sp: Vector2 = cam.unproject_position(p)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	return sp.x > ON_SCREEN_SIDE and sp.x < vs.x - ON_SCREEN_SIDE and sp.y > ON_SCREEN_TOP \
			and sp.y < vs.y - ON_SCREEN_BOTTOM


## BUILD (tab "build") or STATS ("hisaab"). Refused while a popup is open;
## in free play the request then waits for that popup to close (a debug
## --open=build at launch under WELCOME BACK; real taps never get here with a
## popup up), and debug builds print the BUILD rows it will show.
func open_daftar(tab: String = "build") -> void:
	if current_popup != "":
		if Game.is_tutorial_done() and not _tutorial_active():
			_queued_daftar = tab
			if tab == "build" and OS.is_debug_build():
				print("[ui] build rows: %s (opens after the %s popup)" % [daftar.build_rows_line(), current_popup])
		return
	if current_panel == "daftar":
		daftar.select_tab(tab)
		return
	if current_panel != "":
		_close_panel(true)
	daftar.open(tab)
	hud.set_mode("panel")
	current_panel = "daftar"
	_sample_limit()
	Sfx.play("tap", 0.02)
	panel_opened.emit("daftar")


## C5.2 / C6.1 / C6.3: the carry-over popup of a promotion, kind
## "renovation" or "move" (target: the location id; "" = the next highway).
## Opens over BUILD when it is open (popup "promo").
func open_promo(kind: String, target: String = "") -> void:
	if current_popup != "":
		return
	var k: String = "move" if kind == "move" else "renovation"
	var tgt: String = target
	if k == "move" and tgt == "":
		tgt = Daftar.move_target()
	if k == "move" and tgt == "":
		return
	promo_popup.open(k, tgt)
	_show_popup("promo")
	print("[ui] promo popup %s ready=%s" % [k, str(promo_popup.unlocked_now)])
	Analytics.event("renovation_preview", {"kind": k, "ready": promo_popup.unlocked_now})


## C6.4: the weekend baraat panel (full panel "event").
## 5 Nov: MENU (every counter's dish upgrades) as panel "menu".
func open_menu() -> void:
	if current_popup != "" or current_panel == "menu":
		return
	if current_panel != "":
		_close_panel(true)
	menu_panel.open()
	hud.set_mode("panel")
	current_panel = "menu"
	Sfx.play("tap", 0.02)
	panel_opened.emit("menu")
	Analytics.event("menu_open", {})


## MENU's actions: a level bought (relayed as button_pressed), or MORE ›:
## MENU closes and that counter's sheet opens.
func _on_menu_action(id: String) -> void:
	if id.begins_with("menu_open_"):
		var st: String = id.substr(10)
		_close_panel(false)
		open_station(st)
	button_pressed.emit(id)


func open_event() -> void:
	if current_popup != "":
		return
	if current_panel == "event":
		return
	if current_panel != "":
		_close_panel(true)
	event_panel.open()
	hud.set_mode("panel")
	current_panel = "event"
	Sfx.play("tap", 0.02)
	panel_opened.emit("event")


## C6.4: the weekend window closed while the baraat panel was open (the event
## module's close emits event_changed once event_active() is false): close
## the panel, so it never shows an empty event with a fresh "Ends in".
func _on_event_window() -> void:
	if current_panel == "event" and not Game.event_active():
		print("[ui] event panel closed: the weekend window ended")
		_close_panel(true)


## reward <= 0 uses the current wall-ad reward. free_only (D7): true = the
## FREE BONUS variant (no offer), false = the full VIP offer, null = the
## variant Game.offer_variant() gives (C7.4: "free" in session 1, in the
## tutorial, after any purchase and once an offer was shown this session;
## else the STARTER PACK once ever, then VIP once a session).
func open_vip(reward: float = -1.0, free_only: Variant = null) -> void:
	if current_popup != "":
		return
	var variant: String = offer_variant() if free_only == null else ("free" if bool(free_only) else "vip")
	vip_popup.open(reward if reward > 0.0 else Game.ad_bubble_reward(), variant)
	if variant != "free":
		# The offer at most once per session (Round 2; C7.4: one offer).
		if Game.has_method("mark_offer_shown"):
			Game.call("mark_offer_shown", variant)
		elif variant == "vip":
			Game.mark_vip_offer_shown()
	# C7.2: the bubble is never hidden under this popup (FREE consumes it).
	_set_ad_hold(true)
	_show_popup("vip")
	# Soft launch analytics: offers seen (the funnel's first step per placement).
	Analytics.event("ad_offer_shown", {"placement": "wall_ad", "variant": variant})
	if variant == "vip" and not Game.vip:
		Analytics.event("iap_offer_shown", {"id": "vip_x2", "source": "wall_ad"})
	elif variant == "starter":
		Analytics.event("iap_offer_shown", {"id": Iap.STARTER, "source": "wall_ad"})


## C7.4: "free" | "starter" | "vip" for the next bubble tap (Game's offer rule;
## before core and feel's game.gd, the 0.3.7 VIP rule).
func offer_variant() -> String:
	if Game.has_method("offer_variant"):
		var v: String = str(Game.call("offer_variant"))
		if v in ["free", "starter", "vip"]:
			return v
	return "vip" if Game.vip_offer_visible() else "free"


## Story: Simran's chat (reads every message).
func open_phone() -> void:
	if current_popup != "":
		return
	var unread: int = Game.phone_unread()
	phone_popup.open()
	_show_popup("phone")
	hud.refresh_phone()
	Analytics.event("phone_open", {"unread": unread, "visits": Game.story_visits()})


func open_settings() -> void:
	if current_popup != "":
		return
	settings_popup.open()
	_show_popup("settings")
	Analytics.event("settings_open", {"remove_ads_offer": not Game.remove_ads})


func open_offline(amount: float, seconds: float) -> void:
	if amount <= 0.0:
		return
	if current_popup == "offline":
		# Already showing: Game's amount is cumulative, just refresh it.
		if not offline_popup.is_busy():
			offline_popup.open(amount, seconds)
		return
	if current_popup != "":
		_queued_offline = true
		return
	# C6.2: a special waiting for its announcement rides in as the band.
	var sp: String = _special_due()
	offline_popup.set_special(_special_dish_text(sp) if sp != "" else "")
	offline_popup.open(amount, seconds)
	_show_popup("offline")
	if sp != "":
		_announce_special(sp, "welcome back")
	# Soft launch analytics: the WELCOME BACK popup (an offline return that
	# pays; under offline.min_away nothing shows and nothing is sent here).
	# C7.2: x2 is offered only while its ad is ready; `x2` here is the state
	# at the open. OfflinePopup sends ad_offer_shown {offline_double} itself
	# the first time x2 shows (often a few seconds later on a cold launch).
	var x2: bool = offline_popup.double_button.visible
	Analytics.event("offline_return", {"away_min": int(seconds / 60.0), "amount": amount, "x2": x2})


## Closes popups and panels (the tutorial uses it to reset the screen).
func close_all() -> void:
	if current_popup != "":
		_hide_popup()
	if current_panel != "":
		_close_panel(true)


## A panel or popup is open, or the analytics consent card (C4.4).
func is_any_open() -> bool:
	return current_panel != "" or current_popup != "" or Analytics.is_card_open()


## Audit fix (7 Nov): why a construction finished by the clock must wait
## before Game reloads the scene ("" = it may finish): a pop-up, the consent
## card, the quit question, a Rani line or a reward burst. Panels do not hold
## it (closing them loses nothing).
func build_finish_blocked() -> String:
	if current_popup != "":
		return "popup " + current_popup
	if Analytics.is_card_open():
		return "card"
	if is_instance_valid(quit_popup) and quit_popup.has_method("is_open") and bool(quit_popup.call("is_open")):
		return "quit question"
	var dlg: Node = Refs.dialogue
	if dlg != null and is_instance_valid(dlg) and dlg.has_method("is_open") and bool(dlg.call("is_open")):
		return "dialogue"
	if Fx.reward_playing():
		return "reward"
	return ""


# ================================================================ C4.4 launch pop-up budget
## kinds "consent" | "offline" | "eco_note": true when that launch pop-up may
## open now: none shown yet this launch (Game.popup_budget_used() < 1),
## nothing open (panel, popup, dialogue, reward burst, consent card, the quit
## question); "consent" also needs chai Lv 10+ and the tutorial done, or its
## calm free step after the seats beat (tutorial.seats_done and the Director
## in step "free"); "offline" and "eco_note" need the tutorial done.
func can_interrupt(kind: String) -> bool:
	return interrupt_block_reason(kind) == ""


## Why `kind` may not open now ("" = it may): "tutorial" (or "level" for the
## consent card under chai Lv 10), "budget" (another launch pop-up showed this
## launch, or, for "offline" / "eco_note", the consent card still wants this
## launch's pop-up: lead decision 6(c)), "open" (something is on screen).
func interrupt_block_reason(kind: String) -> String:
	if kind == "consent":
		if Game.station_level(Game.core_station()) < CONSENT_MIN_CHAI:
			return "level"
		if not Game.is_tutorial_done() and not _tutorial_calm_free():
			return "tutorial"
	elif not Game.is_tutorial_done():
		return "tutorial"
	elif _consent_card_first():
		# Lead decision 6(c): the consent card owns this launch's pop-up;
		# WELCOME BACK is paid silently with its toast.
		return "budget"
	if _popup_budget_used() >= 1:
		return "budget"
	if _screen_busy(kind != "consent"):
		return "open"
	return ""


## Lead decision 6(c): analytics consent is still unknown on a launch past
## the tutorial and the card may open here (chai Lv 10+), so WELCOME BACK and
## the eco note give way to it.
func _consent_card_first() -> bool:
	if Game.station_level(Game.core_station()) < CONSENT_MIN_CHAI:
		return false
	return Analytics.has_method("card_pending") and bool(Analytics.call("card_pending"))


## A launch pop-up of `kind` opened: Game counts it (the budget) and the
## funnel gets launch_popup {kind}.
func note_interrupt(kind: String) -> void:
	if Game.has_method("note_popup"):
		Game.call("note_popup", kind)
	else:
		_local_popups += 1
		print("[ui] launch popup %s (local count)" % kind)
	Analytics.event("launch_popup", {"kind": kind})


func _popup_budget_used() -> int:
	if Game.has_method("popup_budget_used"):
		return int(Game.call("popup_budget_used"))
	return _local_popups


## Anything on screen a launch pop-up must not cover: a panel, a popup, the
## quit question, Munshi-ji's box, a reward burst, the consent card.
func _screen_busy(count_card: bool = true) -> bool:
	if current_panel != "" or current_popup != "":
		return true
	if quit_popup != null and quit_popup.is_open():
		return true
	if count_card and Analytics.is_card_open():
		return true
	var dlg: Variant = Refs.dialogue
	if dlg != null and is_instance_valid(dlg) and (dlg as Object).has_method("is_open") \
			and bool((dlg as Object).call("is_open")):
		return true
	var fx: Node = UiKit.autoload("Fx")
	if fx != null and fx.has_method("reward_playing") and bool(fx.call("reward_playing")):
		return true
	return false


## The tutorial's calm free step after the seats beat (~1:50): the consent
## card's place in the first session.
func _tutorial_calm_free() -> bool:
	if not bool(Game.tutorial_get("seats_done", false)):
		return false
	var d: Variant = Refs.director
	if d == null or not is_instance_valid(d) or not (d as Object).has_method("current_step"):
		return false
	return str((d as Object).call("current_step")) == "free"


## C7.2: Game holds the wall-ad bubble while the FREE / VIP popup is open.
func _set_ad_hold(on: bool) -> void:
	if Game.has_method("set_ad_hold"):
		Game.call("set_ad_hold", on)


## Top of the open station sheet's frame (canvas px); INF while it is closed.
func sheet_top() -> float:
	if station_sheet != null and station_sheet.visible:
		return station_sheet.sheet_top()
	return INF


func _on_menu_unlocked(station_id: String, dish_id: String) -> void:
	if menu_pop != null:
		menu_pop.show_unlock(station_id, dish_id)


## Android back (soft launch FLOW track): closes the top thing, else asks to
## quit; nothing else. Order: the quit question itself (= STAY), a popup
## (WELCOME BACK collects without the ad), a panel / sheet / 2-tap card;
## with nothing to close, or one the tutorial keeps open (lock_close), the
## "LEAVE THE DHABA?" question. Back while a rewarded ad is being fetched
## for the VIP / FREE CASH popup waits for it. Always true: Main3's own
## top-level fallback (press back twice) is no longer reached.
func handle_back() -> bool:
	if quit_popup != null and quit_popup.is_open():
		quit_popup.answer(false)
		return true
	if current_popup != "" and not lock_close:
		if current_popup == "vip" and vip_popup.is_busy():
			return true
		if current_popup == "offline":
			offline_popup.collect_plain()
		else:
			_hide_popup()
		return true
	if current_panel != "" and not lock_close:
		_close_panel(true)
		return true
	ask_quit()
	return true


## "LEAVE THE DHABA?" (Android back with nothing to close).
func ask_quit() -> void:
	if quit_popup == null or quit_popup.is_open():
		return
	quit_popup.open()
	Analytics.event("quit_prompt", {"choice": "shown", "tutorial_done": Game.is_tutorial_done()})


## LEAVE: the same session_end Main3 sends for a back quit, a save, quit.
func _on_quit_answered(leave: bool) -> void:
	Analytics.event("quit_prompt", {"choice": "leave" if leave else "stay", "tutorial_done": Game.is_tutorial_done()})
	if not leave:
		return
	Analytics.event("session_end", {"reason": "back", "app_sec": int(float(Time.get_ticks_msec()) / 1000.0),
			"tutorial_done": Game.is_tutorial_done()})
	Game.save_game()
	get_tree().quit()


func _close_panel(restore_cam: bool) -> void:
	var pname: String = current_panel
	if pname == "":
		return
	current_panel = ""
	if pname.begins_with("station:"):
		station_sheet.close()
		if restore_cam:
			_cam_call("panel_restore", [])
	elif pname.begins_with("staff:"):
		staff_panel.close()
	elif pname.begins_with("quick:"):
		quick_buy.close()
	elif pname == "daftar":
		daftar.close()
	elif pname == "event":
		event_panel.close()
	elif pname == "menu":
		menu_panel.close()
	hud.set_mode("gameplay")
	panel_closed.emit(pname)


func _show_popup(pname: String) -> void:
	current_popup = pname
	_popup_dim.visible = true
	if _dim_tw != null and _dim_tw.is_valid():
		_dim_tw.kill()
	_dim_tw = create_tween()
	_dim_tw.tween_property(_popup_dim, "color:a", 0.5, 0.15)
	Sfx.play("pop", 0.02)
	panel_opened.emit(pname)


func _hide_popup() -> void:
	var pname: String = current_popup
	if pname == "":
		return
	current_popup = ""
	match pname:
		"vip":
			vip_popup.close()
			_set_ad_hold(false)
		"offline":
			offline_popup.close()
		"settings":
			settings_popup.close()
		"phone":
			phone_popup.close()
			hud.refresh_phone()
		"promo":
			promo_popup.close()
	if _dim_tw != null and _dim_tw.is_valid():
		_dim_tw.kill()
	_dim_tw = create_tween()
	_dim_tw.tween_property(_popup_dim, "color:a", 0.0, 0.1)
	_dim_tw.tween_callback(_popup_dim.hide)
	panel_closed.emit(pname)
	if _queued_offline:
		_queued_offline = false
		_check_pending_offline.call_deferred()
	elif _queued_daftar != "":
		_open_queued_daftar.call_deferred()


## The BUILD / STATS open that waited for a popup (open_daftar).
func _open_queued_daftar() -> void:
	var t: String = _queued_daftar
	_queued_daftar = ""
	if t == "" or current_popup != "" or current_panel != "":
		return
	open_daftar(t)


# ================================================================ anchors
## Tutorial hand anchors (see the class doc); anything else goes to
## Hud.anchor().
func anchor(n: String) -> Control:
	var c: Control = _anchor(n)
	# Bottom-sheet panels scroll (9 Nov): bring the anchored row into view.
	if c != null:
		for pnl in [staff_panel, menu_panel, event_panel]:
			if pnl != null and is_instance_valid(pnl) and (pnl as Control).visible and (pnl as Node).is_ancestor_of(c):
				pnl.call("reveal", c)
	return c


func _anchor(n: String) -> Control:
	var staff_open: bool = current_panel.begins_with("staff:") and staff_panel.is_open()
	var quick: String = quick_buy.kind if quick_buy.is_open() else ""
	match n:
		"rack_tag", "ghost_waiter", "waiter_tag":
			return waiter_tag if waiter_tag.is_showing() else null
		"table_tag":
			return table_tag if table_tag.is_showing() else null
		"sheet_close":
			return station_sheet.close_button if station_sheet.is_open() else null
		"sheet_limit_button", "sheet_fix_button":
			var lb: UiButton = station_sheet.limit_btn
			return lb if station_sheet.is_open() and lb != null and lb.is_visible_in_tree() else null
		"promo_button":
			var pb: UiButton = promo_popup.primary_button
			return pb if current_popup == "promo" and pb != null and pb.is_visible_in_tree() else null
		"build_site_tag":
			return build_site_tag if build_site_tag.is_showing() else null
		"build_row_renovation", "build_row_signboard", "build_row_move", "build_row_grow":
			return daftar.row_button(n.substr(10)) if daftar.is_open() else null
		"event_button":
			var eb: Object = _hud_widget("event_button")
			return eb as Control if eb is Control else null
		"next_chip", "home_button", "staff_button":
			return hud.anchor(n)
		"staff_close", "waiter_close", "galla_close":
			return staff_panel.close_button if staff_open else null
		"waiter_hire_button":
			if quick == "waiters":
				return quick_buy.buy_button
			return staff_panel.hire_button("waiters") if staff_open else null
		"galla_hire_button":
			return staff_panel.hire_button("cashiers") if staff_open else null
		"quick_buy_button":
			return quick_buy.buy_button if quick != "" else null
		"quick_buy_link":
			return quick_buy.link_button if quick != "" else null
		"seating_add_button":
			if quick == "tables":
				return quick_buy.buy_button
			return daftar.table_button() if daftar.is_open() else null
		"seating_close":
			return daftar.close_button if daftar.is_open() else null
		"daftar_build_table", "daftar_tables_button":
			return daftar.table_button() if daftar.is_open() else null
		"build_tag":
			return build_tag if build_tag.is_showing() else null
		"seats_full_pill":
			return seats_pill if seats_pill.is_showing() else null
		"level_up_button":
			return station_sheet.btn_level
		"hire_button":
			return station_sheet.btn_hire
		"processing_button":
			return station_sheet.btn_proc
		"sheet_outside":
			return station_sheet.catcher
		"daftar_build_tab":
			return daftar.build_tab
		"daftar_hisaab_tab":
			return daftar.hisaab_tab
		"daftar_close":
			return daftar.close_button
		"vip_free":
			return vip_popup.free_button
		"vip_unlock":
			return vip_popup.unlock_button
		"vip_close":
			return vip_popup.close_button
		"ad_bubble":
			return ad_bubble
	if n.begins_with("staff_tab_"):
		return staff_panel.tab_button(n.substr(10)) if staff_open else null
	if n.begins_with("staff_hire_cooks_"):
		return staff_panel.cook_hire_button(n.substr(17)) if staff_open else null
	if n.begins_with("staff_hire_"):
		return staff_panel.hire_button(n.substr(11)) if staff_open else null
	if n.begins_with("staff_upgrade_"):
		var rest: String = n.substr(14)
		var cut: int = rest.rfind("_")
		if cut > 0 and staff_open:
			return staff_panel.upgrade_button(rest.substr(0, cut), int(rest.substr(cut + 1)))
		return null
	if n.begins_with("galla_upgrade_"):
		return staff_panel.upgrade_button("cashiers", int(n.substr(14))) if staff_open else null
	if n.begins_with("waiter_upgrade_"):
		return staff_panel.upgrade_button("waiters", int(n.substr(15))) if staff_open else null
	if n.begins_with("daftar_build_"):
		return daftar.build_button(n.substr(13))
	if n.begins_with("meter_row_"):
		var m: Object = _hud_widget("meter")
		if m != null and m.has_method("row_control"):
			var rc: Variant = m.call("row_control", n.substr(10))
			return rc if rc is Control else null
		return null
	if n.begins_with("event_claim_"):
		return event_panel.claim_button(int(n.substr(12))) if current_panel == "event" else null
	if n.begins_with("daftar_hire_waiter_"):
		return daftar.hire_waiter_button(n.substr(19))
	return hud.anchor(n) if hud != null else null


# ================================================================ coach hand (A7)
## Points the Director's hand at `target` (an anchor name or a Control) for
## the first opts.max (2) uses of opts.kind (default: the anchor name; Game
## counter "coach_<kind>"), after opts.delay (0.35 s, the panel fade-in) at
## opts.rel of the control. Not while the Director runs a beat unless
## opts.force. Cleared by the first button press, panel / popup change or
## dialogue after it shows, or clear_coach(). A new call replaces the old
## hand. Returns true when scheduled. (Round 2: after the first two times the
## HIRE card's BEST NOW glow does the pointing, with no hand.)
## W2-FIX-ui: a use is counted when the hand actually points (_coach_run), so
## a hand that a newer call or clear_coach() cancels during its delay (e.g.
## the sheet's fix banner hand under a task / chip route's own hand) costs
## nothing.
func coach_hand(target: Variant, opts: Dictionary = {}) -> bool:
	var force: bool = bool(opts.get("force", false))
	var d: Variant = Refs.director
	if not force and d != null and is_instance_valid(d) and (d as Object).has_method("is_active") \
			and bool((d as Object).call("is_active")):
		return false
	var kind: String = str(opts.get("kind", target if target is String else "control"))
	var key: String = "coach_" + kind
	if not force and _coach_count(key) >= int(opts.get("max", COACH_MAX)):
		return false
	if _director_hand() == null:
		return false
	clear_coach()
	_coach_seq += 1
	_coach_run(_coach_seq, target, float(opts.get("delay", COACH_DELAY)), opts.get("rel", Vector2(0.5, 0.5)), key)
	return true


func clear_coach() -> void:
	_coach_seq += 1
	if not _coach_shown:
		_coach_control = null
		return
	_coach_shown = false
	var h: Variant = _director_hand()
	if h != null and _coach_control != null and is_instance_valid(_coach_control):
		var o: Object = h
		if o.has_method("current_target") and o.call("current_target") == _coach_control:
			o.call("hide_hand")
	_coach_control = null
	coach_cleared.emit()


func is_coaching() -> bool:
	return _coach_shown


func _coach_run(seq: int, target: Variant, delay: float, rel: Variant, key: String = "") -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var c: Control = null
	var left: float = COACH_RESOLVE_S
	while seq == _coach_seq:
		c = _coach_resolve(target)
		if c != null or left <= 0.0:
			break
		await get_tree().process_frame
		left -= get_process_delta_time()
	if seq != _coach_seq or c == null:
		return
	var h: Variant = _director_hand()
	if h == null:
		return
	(h as Object).call("point_at", c, rel if rel is Vector2 else Vector2(0.5, 0.5))
	if key != "":
		_coach_bump(key)
	_coach_control = c
	_coach_shown = true
	_coach_panel = current_panel
	_coach_popup = current_popup


func _coach_resolve(target: Variant) -> Control:
	if target is Control:
		var tc: Control = target
		return tc if is_instance_valid(tc) and tc.is_visible_in_tree() else null
	if target is String or target is StringName:
		var a: Control = anchor(str(target))
		return a if a != null and a.is_visible_in_tree() else null
	return null


func _director_hand() -> Variant:
	var d: Variant = Refs.director
	if d == null or not is_instance_valid(d) or not (d as Object).has_method("hand"):
		return null
	var h: Variant = (d as Object).call("hand")
	return h if h != null and is_instance_valid(h) else null


func _coach_count(key: String) -> int:
	var g: Node = UiKit.autoload("Game")
	if g != null and g.has_method("counter"):
		return UiKit.gint("counter", [key], 0)
	return int(_coach_local.get(key, 0))


func _coach_bump(key: String) -> void:
	var g: Node = UiKit.autoload("Game")
	if g != null and g.has_method("bump_counter"):
		UiKit.gcall("bump_counter", [key, 1])
	else:
		_coach_local[key] = int(_coach_local.get(key, 0)) + 1


func _on_any_button_for_coach(_id: String) -> void:
	if _coach_shown:
		clear_coach()


func _process(delta: float) -> void:
	_sync_world_cover()
	_ghost_t += delta
	if _ghost_t >= GHOST_POLL:
		_ghost_t = 0.0
		_sync_ghost_waiter()
	_hud_hook_t += delta
	if _hud_hook_t >= HUD_HOOK_POLL:
		_hud_hook_t = 0.0
		_hook_hud_widgets()
	# C3.1: the limit before a STAFF hire / BUILD table (free play only).
	if current_panel.begins_with("staff:") or current_panel == "daftar":
		_limit_t += delta
		if _limit_t >= LIMIT_POLL_S:
			_sample_limit()
	if _special_wait:
		_special_poll_t += delta
		if _special_poll_t >= SPECIAL_POLL_S:
			_special_poll_t = 0.0
			_check_special()
	if _offline_waiting:
		_offline_poll_t += delta
		if _offline_poll_t >= OFFLINE_POLL_S:
			_offline_poll_t = 0.0
			_check_pending_offline()
	if not _coach_shown:
		return
	var dlg: Variant = Refs.dialogue
	var talking: bool = dlg != null and is_instance_valid(dlg) and (dlg as Object).has_method("is_open") \
			and bool((dlg as Object).call("is_open"))
	if current_panel != _coach_panel or current_popup != _coach_popup or talking \
			or _coach_control == null or not is_instance_valid(_coach_control):
		clear_coach()


## Build optimisation (docs/optimise/report.md): STAFF, BUILD and STATS cover
## the whole screen with an opaque body, so while one of them is fully faded
## in, the 3D world is not drawn at all (same pixels; the sim, the camera and
## the world tags keep running). Off from the end of the 0.12 s fade-in, back
## on the frame a close starts, so the fades still show the world.
func _sync_world_cover() -> void:
	# _world_covered starts true, so a new UiRoot (a promotion's scene reload
	# keeps the root viewport) always writes disable_3d once.
	# STAFF, MENU and the baraat panel are bottom sheets since 9 Nov: the world
	# shows above them, so only BUILD / STATS (the Daftar) still cover it.
	var covered: bool = visible and _covers(daftar)
	if covered == _world_covered:
		return
	_world_covered = covered
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.disable_3d = covered


static func _covers(p: Control) -> bool:
	return p != null and p.is_visible_in_tree() and p.modulate.a >= 0.999 and p.has_method("is_open") \
			and bool(p.call("is_open"))


## The cyan ghost waiter (Sim.show_ghost_waiter) stands at the next waiter's
## spot while his "+ WAITER" tag is up (and while his quick card is open).
func _sync_ghost_waiter() -> void:
	var want: bool = waiter_tag.is_showing() or (quick_buy.is_open() and quick_buy.kind == "waiters")
	if not want and not _ghost_waiter_on:
		return
	var sv: Variant = Refs.sim
	if not is_instance_valid(sv) or not (sv as Object).has_method("show_ghost_waiter"):
		return
	# (Idempotent while on: Sim moves the ghost on after a hire.)
	(sv as Object).call("show_ghost_waiter", want)
	_ghost_waiter_on = want


# ================================================================ world taps
func _try_connect_world() -> void:
	if _world_connected or not is_inside_tree():
		return
	var wi: Node = Refs.world_input
	if wi != null and wi.has_signal("tapped"):
		wi.connect("tapped", _on_world_tapped)
		_world_connected = true
	else:
		get_tree().create_timer(0.25).timeout.connect(_try_connect_world)


func _on_world_tapped(tap_id: String, _world_pos: Vector3 = Vector3.ZERO) -> void:
	if current_popup != "" or current_panel != "":
		return
	var canon: String = _canonical_tap(tap_id)
	if not _tap_allowed(tap_id) and not _tap_allowed(canon):
		return
	if tap_id.begins_with("station:"):
		open_station(tap_id.substr(8))
	elif tap_id.begins_with("ghost_waiter"):
		open_quick("waiters", "tap")
	elif canon == "waiters":
		open_staff("waiters")
	elif tap_id.begins_with("ghost_table"):
		open_quick("tables")
	elif canon == "tables":
		# A built table: BUILD › TABLES (the SEATING panel is retired).
		open_daftar("build")
		daftar.focus_tables()
	elif tap_id == "galla" or tap_id.begins_with("galla"):
		open_staff("cashiers")
	elif tap_id == "ad_bubble":
		_on_bubble_tapped()
	elif tap_id == "tandoor_slab" or tap_id.ends_with("_slab"):
		open_daftar("build")
	elif tap_id.begins_with("build:"):
		open_daftar("build")
		Game.log_build_prompt(tap_id.substr(6), "pad")


## Tap-id families: every waiter id (the rack, a waiter, the ghost waiter)
## gates as "waiters", every table / ghost-table id as "tables"; anything
## else is itself.
func _canonical_tap(tap_id: String) -> String:
	if tap_id == "waiters" or tap_id.begins_with("waiter") or tap_id.begins_with("ghost_waiter"):
		return "waiters"
	if tap_id == "tables" or tap_id.begins_with("table") or tap_id.begins_with("ghost_table") \
			or tap_id.begins_with("seat") or tap_id.begins_with("charpai"):
		return "tables"
	if tap_id.begins_with("build:"):
		return "build"
	return tap_id


func _station_focus(id: String) -> Vector3:
	return Layout3.station_focus(id)


## Calls CameraRig.<method>(args) when it has it; returns true if called.
func _cam_call(method: String, args: Array) -> bool:
	var cam: Node = Refs.camera
	if cam != null and cam.has_method(method):
		cam.callv(method, args)
		return true
	return false


# ================================================================ handlers
func _relay(id: String) -> void:
	button_pressed.emit(id)


func _on_staff_tab(tab: String) -> void:
	if current_panel.begins_with("staff:"):
		current_panel = "staff:" + tab


## Station sheet actions; "goto_limit" opens what limits the takings, as the
## banner's button says. Core and feel C2.5: "fix" (the banner's saffron fix
## button) opens the card that fixes the limit: do_fix(StationSheet.fix_target)
## (W2-PANELS' property, read by name; Game.bottleneck_fix() when it is
## missing or empty, which is the same dict the banner shows).
func _on_sheet_action(id: String) -> void:
	button_pressed.emit(id)
	if id == "fix":
		var fix: Dictionary = {}
		if "fix_target" in station_sheet:
			var fv: Variant = station_sheet.get("fix_target")
			if fv is Dictionary:
				fix = fv
		if fix.is_empty() or str(fix.get("kind", "none")) == "none":
			fix = Game.bottleneck_fix()
		do_fix(fix, "sheet")
		return
	if id != "goto_limit":
		return
	var target: String = station_sheet.limit_target
	Analytics.event("sheet_limit_tap", {"station": station_sheet.station_id, "target": target})
	match target:
		"waiters", "staff:waiters":
			open_staff("waiters", {"highlight": "hire"})
			if StaffRows.can_hire("waiters"):
				coach_hand("staff_hire_waiters", {"kind": "sheet_waiters"})
		"galla", "cashiers", "staff:cashiers":
			open_staff("cashiers", {"highlight": "hire"})
			if Game.can_hire_galla():
				coach_hand("staff_hire_cashiers", {"kind": "sheet_galla"})
		"seating", "tables":
			if open_tables("sheet") != "":
				coach_hand("seating_add_button", {"kind": "sheet_seating"})
		_:
			if target.begins_with("station:"):
				open_station(target.substr(8))


func _on_hud_button(id: String) -> void:
	match id:
		"staff_button":
			var hot: bool = StaffRows.staff_alert() != ""
			open_staff("", {"highlight": "hire"} if hot else {})
		"build_button":
			open_daftar("build")
		"stats_button":
			open_daftar("hisaab")
		"settings_button":
			open_settings()
		"phone_button":
			open_phone()
		"menu_button":
			open_menu()
		"home_button":
			if not _cam_call("fly_home", []):
				_cam_call("fly_to", [Main3.home_view(), CameraRig.GAME])
		_:
			if id.begins_with("task_goto_"):
				_on_task_goto(int(id.substr(10)))
		# shop_button / manager_button / medal_button / sikke_plus: hidden
		# until Game.feature_on() says the feature ships (D5); no toasts.
	button_pressed.emit(id)


func _on_sheet_outside(screen_pos: Vector2) -> void:
	if lock_close or not can_press("panel_close"):
		return
	if current_panel.begins_with("station:"):
		# J8: ripple where the finger landed, with the larger close ring.
		var j: UiJuice = UiKit.juice_for(station_sheet)
		if j != null:
			UiKit.ripple_at(j, screen_pos, 100.0, true)
		_close_panel(true)
		button_pressed.emit("panel_close")


## The station sheet's red X (A6.1): like a tap outside the sheet.
func _on_sheet_x() -> void:
	if lock_close or not can_press("panel_close"):
		return
	if current_panel.begins_with("station:"):
		_close_panel(true)
		button_pressed.emit("panel_close")


func _on_panel_x() -> void:
	if lock_close:
		return
	_close_panel(true)
	button_pressed.emit("panel_close")


func _on_popup_x() -> void:
	if lock_close:
		return
	_hide_popup()
	button_pressed.emit("panel_close")


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_popup_dim.accept_event()
			# Only settings and the phone close on an outside tap; offers need their X.
			if current_popup in ["settings", "phone"] and not lock_close:
				_hide_popup()


func _on_bubble_tapped() -> void:
	if current_popup != "" or not _tap_allowed("ad_bubble"):
		return
	if not Game.ad_bubble_ready():
		return
	# Looking at the offer does not spend the bubble: it is consumed only when
	# FREE pays out (or it expires on its own once the popup is closed).
	# VipPopup keeps the reward.
	var reward: float = Game.ad_bubble_reward()
	open_vip(reward)
	button_pressed.emit("ad_bubble")


# ================================================================ quick card
func _on_quick_action(id: String) -> void:
	button_pressed.emit(id)
	if id == "seating_add":
		table_tag.poll_now()
		if close_seating_on_add and not lock_close:
			get_tree().create_timer(0.12).timeout.connect(_after_table_added)
	elif id == "waiter_hire":
		var at: Vector2 = _quick_tip()
		get_tree().create_timer(0.15).timeout.connect(_after_quick_waiter.bind(at))


func _quick_tip() -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(quick_buy.world_point):
		return hud.burst_center()
	return cam.unproject_position(quick_buy.world_point)


## The new waiter pops in at his spot (Sim); "+1 WAITER" rises there.
func _after_quick_waiter(at: Vector2) -> void:
	if current_panel == "quick:waiters" and not lock_close:
		_close_panel(false)
	hud.show_float("+1 WAITER", at + Vector2(0.0, 40.0))


func _on_quick_link(kind: String) -> void:
	button_pressed.emit("quick_buy_link")
	if kind == "build":
		open_daftar("build")
		daftar.focus_tables()
	else:
		open_staff("waiters", {"highlight": "hire"})


func _on_quick_outside() -> void:
	if lock_close or not can_press("panel_close"):
		return
	if current_panel.begins_with("quick:"):
		_close_panel(false)
		button_pressed.emit("panel_close")


# ================================================================ seating / waiters
## Sim push API for the Seats-full pill: travellers waiting just inside the
## door for a free seat. Once pushed, polling Refs.sim stops.
func set_door_waiting(n: int) -> void:
	_door_waiting_push = maxi(n, 0)


## The "Seats full!" pill's count: the door line, but only while it is the
## one world tag (free play: the NEXT chip points at the seats and the ghost
## table is off screen; tutorial: "tables" taps named by the Director).
func _seats_pill_count() -> int:
	if current_popup != "" or current_panel != "" or not _tap_allowed("tables"):
		return 0
	if not Game.is_tutorial_done():
		return door_waiting() if _tap_named("tables") else 0
	if tag_target() != "tables" or _slot_on_screen(table_tag):
		return 0
	return door_waiting()


## Travellers waiting at the door for a seat (pushed value or polled Sim).
func door_waiting() -> int:
	if _door_waiting_push >= 0:
		return _door_waiting_push
	var sv: Variant = Refs.sim
	if is_instance_valid(sv) and sv is Node:
		var sim: Node = sv
		for m in DOOR_WAIT_METHODS:
			if sim.has_method(m):
				return _as_count(sim.call(m))
		for p in DOOR_WAIT_PROPS:
			var v: Variant = sim.get(p)
			if v != null:
				return _as_count(v)
	# Game's copy (report_seats() pushes / its own 0.5 s Sim poll).
	return UiKit.gint("seats_waiting", [], 0)


func _as_count(v: Variant) -> int:
	if v is int or v is float:
		return int(v)
	if v is Array:
		return (v as Array).size()
	if v is bool:
		return 1 if v else 0
	return 0


## One-tag rule (§3.8): the NEXT chip's target ("build:<id>", "waiters",
## "tables", "cashiers" or ""); "" in the tutorial (the Director gates its
## tags itself).
func tag_target() -> String:
	if not Game.is_tutorial_done() or hud == null or hud.next_chip == null:
		return ""
	return hud.next_chip.target()


func _tags_blocked() -> bool:
	return current_popup != "" or current_panel.begins_with("quick:")


## "+ TABLE": free play while the NEXT chip points at the seats; in the
## tutorial while the Director names "tables" (its seats beat).
func _table_tag_allowed() -> bool:
	if _tags_blocked() or current_panel != "" or not _tap_allowed("tables"):
		return false
	if not Game.is_tutorial_done():
		return _tap_named("tables")
	return tag_target() == "tables"


func _on_table_tag_tapped() -> void:
	if current_popup != "" or current_panel != "" or not _tap_allowed("tables"):
		return
	open_quick("tables")
	button_pressed.emit("table_tag")


## "+ WAITER": free play while the NEXT chip points at the waiters; in the
## (old) tutorial's waiter beat while "waiters" taps are named.
func _waiter_tag_allowed() -> bool:
	if _tags_blocked() or current_panel != "" or not _tap_allowed("waiters"):
		return false
	if not Game.is_tutorial_done():
		return rack_tag_unlocked and _tap_named("waiters")
	return tag_target() == "waiters"


func _on_waiter_tag_tapped() -> void:
	if current_popup != "" or current_panel != "" or not _tap_allowed("waiters"):
		return
	open_quick("waiters", "tag")
	button_pressed.emit("hire_slot_waiters")
	# Old id kept for the step-1 listeners.
	button_pressed.emit("rack_tag")


## Ghost build pad price tag: free play only, "build" taps allowed, no popup,
## and the NEXT chip points at that pad.
func _build_tag_allowed() -> bool:
	if _tags_blocked() or not _tap_allowed("build") or not Game.is_tutorial_done():
		return false
	var sv: Variant = Refs.sim
	var pad: String = ""
	if is_instance_valid(sv) and (sv as Object).has_method("ghost_station_id"):
		pad = str((sv as Object).call("ghost_station_id"))
	return pad != "" and tag_target() == "build:" + pad


## Build pads only build: every pad tag opens BUILD (a waiter-gated row's
## STAFF › leads on to STAFF › WAITERS).
func _on_build_tag_tapped() -> void:
	if current_popup != "" or current_panel != "" or not _tap_allowed("build"):
		return
	var id: String = build_tag.station_id
	open_daftar("build")
	if id != "" and Game.build_block_reason(id).begins_with("waiters:"):
		coach_hand("daftar_hire_waiter_" + id, {"kind": "tag_waiters"})
	button_pressed.emit("build_tag")
	if id != "":
		Game.log_build_prompt(id, "tag")


## The tag is on screen (inside the margins).
func _slot_on_screen(tag: UiWorldTag) -> bool:
	if tag == null or not tag.is_showing():
		return false
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var r: Rect2 = tag.get_global_rect()
	return r.end.x > ON_SCREEN_SIDE and r.position.x < vs.x - ON_SCREEN_SIDE and r.end.y > ON_SCREEN_TOP \
			and r.position.y < vs.y - ON_SCREEN_BOTTOM


## The next ghost table projects inside the screen margins (its card fits).
func _ghost_table_on_screen() -> bool:
	var n: int = UiKit.gint("table_count", [], 0)
	if n >= UiKit.gint("table_max", [], 0) or not TableTag.has_table_point(n):
		return false
	var cam: Camera3D = get_viewport().get_camera_3d()
	var p: Vector3 = TableTag.table_point(n) + Vector3(0.0, HireSlot.TABLE_TAG_Y, 0.0)
	if cam == null or cam.is_position_behind(p):
		return false
	var sp: Vector2 = cam.unproject_position(p)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	return sp.x > ON_SCREEN_SIDE and sp.x < vs.x - ON_SCREEN_SIDE and sp.y > ON_SCREEN_TOP \
			and sp.y < vs.y - ON_SCREEN_BOTTOM


## NEXT chip (A7): the matching panel (or the ghost table's card), then the
## coach hand on the fix (first 2 times; then the BEST NOW glow points).
func _on_next_chip_tapped(hint: Dictionary) -> void:
	if current_popup != "" or current_panel != "" or not can_press("next_chip"):
		return
	var id: String = str(hint.get("id", ""))
	if id == "":
		return
	var panel: String = str(hint.get("panel", ""))
	var coach: String = str(hint.get("coach", ""))
	# Plan 2.8: a PROBLEM hint is the chip's fix tap (bottleneck_fix_tap
	# {fix, source: chip}, the "<kind>[:<role>]" format of do_fix). The chip
	# opens its panel itself (below); the fix comes from the hint, since the
	# seats PROBLEM is a door line, not the readout's limit.
	if bool(hint.get("problem", false)):
		var fx: String = str({"quick:waiters": "hire:waiters", "staff:waiters": "upgrade:waiters",
				"tables": "table", "seating": "table"}.get(panel, ""))
		if panel == "staff:cashiers" or panel == "cashiers" or panel == "galla":
			fx = "hire:cashiers" if coach.begins_with("staff_hire") else "upgrade:cashiers"
		if fx != "":
			Analytics.event("bottleneck_fix_tap", {"fix": fx, "source": "chip"})
	# FLOW: no hand on a button the player cannot pay for yet ("Save x / y").
	if bool(hint.get("saving", false)):
		coach = ""
	match panel:
		"quick:waiters":
			# Core and feel C3.1: the 2-tap card in the world (by the oldest
			# waiting plate, else the ghost; a fly to the ghost when neither is
			# on screen); its coach hand comes once the card shows.
			_open_quick_waiters("chip", coach, "next_" + id)
			coach = ""
		"promo:renovation":
			open_promo("renovation")
		"promo:move":
			open_promo("move", str(hint.get("target", "")))
		"daftar:signboard":
			open_daftar("build")
			daftar.focus_row("signboard")
		"daftar:grow":
			open_daftar("build")
			daftar.focus_row("grow")
		"event":
			open_event()
		"seating", "tables":
			open_tables("next")
		"waiters", "staff:waiters":
			open_staff("waiters", {"highlight": "hire"})
		"galla", "cashiers", "staff:cashiers":
			open_staff("cashiers", {"highlight": "hire"})
		"staff:cooks":
			open_staff("cooks", {"highlight": "hire"})
		"staff":
			open_staff("", {"highlight": "hire"})
		"daftar":
			open_daftar("build")
		_:
			# Soft launch polish: the endless goals' counter sheet (dish
			# milestone, SPEED, level milestone).
			if panel.begins_with("station:"):
				open_station(panel.substr(8))
	if coach != "":
		coach_hand(coach, {"kind": "next_" + id})
	button_pressed.emit("next_chip_" + id)
	Analytics.event("next_chip_tap", {"id": id})


## FLOW track (2026-10-26, UX plan B4): an unfinished TASK card leads to
## the button that does it: LEVEL UP / SPEED on the counter's sheet, STAFF
## (cooks, cashiers, waiters: HIRE or that person's UPGRADE), BUILD (a
## counter) or the next table; the coach hand goes on it when the player can
## pay (the first 2 times per kind, "coach_task_<kind>"). Tasks that count
## up by themselves (serve, earn, bill, seat) say so in a toast. Free play
## only (the tutorial keeps its own beats).
func _on_task_goto(slot: int) -> void:
	if current_popup != "" or current_panel != "" or not Game.is_tutorial_done():
		return
	if slot < 0 or slot >= Game.tasks.size() or not (Game.tasks[slot] is Dictionary):
		return
	var t: Dictionary = Game.tasks[slot]
	var kind: String = str(t.get("kind", ""))
	var st: String = str(t.get("station", ""))
	var coach: String = ""
	var cost: float = -1.0
	match kind:
		"level", "processing":
			if st == "" or not Game.is_built(st):
				kind = ""
			else:
				open_station(st)
				coach = "level_up_button" if kind == "level" else "processing_button"
				cost = Game.level_cost(st) if kind == "level" else Game.proc_cost(st)
		"hire":
			if st == "" or not Game.is_built(st) or Game.hire_maxed(st):
				kind = ""
			else:
				open_staff("cooks", {"highlight": "hire"})
				coach = "staff_hire_cooks_" + st
				cost = Game.hire_cost(st)
		"galla_level":
			var g: int = int(t.get("galla", 0))
			if g >= Game.galla_count() and Game.can_hire_galla():
				open_staff("cashiers", {"highlight": "hire"})
				coach = "staff_hire_cashiers"
				cost = Game.galla_hire_cost()
			elif g < Game.galla_count():
				open_staff("cashiers")
				coach = "staff_upgrade_cashiers_%d" % g
				cost = Game.galla_upgrade_cost(g)
			else:
				kind = ""
		"waiters":
			open_staff("waiters", {"highlight": "hire"})
			coach = "staff_hire_waiters"
			cost = Game.waiter_hire_cost()
		"waiter_level":
			var w: int = int(t.get("waiter", 0))
			if w < Game.waiter_count():
				open_staff("waiters")
				coach = "staff_upgrade_waiters_%d" % w
				cost = Game.waiter_upgrade_cost(w)
			else:
				open_staff("waiters", {"highlight": "hire"})
				coach = "staff_hire_waiters"
				cost = Game.waiter_hire_cost()
		"tables":
			open_tables("task")
			coach = "seating_add_button"
			cost = Game.table_cost()
		"build":
			open_daftar("build")
			if st != "" and Game.can_build(st):
				coach = "daftar_build_" + st
				cost = Game.build_cost(st)
		_:
			kind = ""
	if kind == "":
		# Serve / earn / bill / seat tasks fill up by themselves.
		hud.toast(UiKit.t("This task fills up as you play."))
		Analytics.event("task_goto", {"kind": str(t.get("kind", "")), "opened": false})
		return
	if coach != "" and cost >= 0.0 and Game.can_afford(cost):
		coach_hand(coach, {"kind": "task_" + kind})
	Analytics.event("task_goto", {"kind": kind, "opened": true})


## Daftar actions: "build_<id>" (a station built from a ghost pad closes BUILD
## 0.12 s later and flies the camera to it, where the Sim pops it in),
## "seating_add" (a table: likewise to the new table), "open_waiters" (a
## waiter-blocked row's STAFF ›).
## Core and feel: "see_renovation" / "see_move" (a promotion row's SEE) open
## the carry-over popup over BUILD; "signboard_buy" (C5.3) only relays (the
## world feedback is W2-FX's, on Game.signboard_changed). A table bought in
## BUILD in free play closes BUILD and shows it only under the C3.1 rule
## (_show_purchase_rule: the readout's limit was "seats" just before, once a
## session, never while the Director runs); in the tutorial BUILD still
## closes and shows every table (0.3.7, the seats beat relies on it).
func _on_daftar_action(id: String) -> void:
	button_pressed.emit(id)
	if id == "open_waiters":
		_close_panel(true)
		open_staff("waiters", {"highlight": "hire"})
		coach_hand("staff_hire_waiters", {"kind": "daftar_waiters"})
		return
	if id == "see_renovation":
		open_promo("renovation")
		return
	if id == "grow_start":
		# Dhaba growth step 3: back to the world, where the site goes up.
		close_all()
		return
	if id == "see_move":
		open_promo("move", Daftar.move_target())
		return
	if id == "seating_add":
		table_tag.poll_now()
		if not close_seating_on_add or lock_close:
			return
		if not Game.is_tutorial_done() or _director_active():
			get_tree().create_timer(0.12).timeout.connect(_after_table_added)
			return
		var why: String = _show_purchase_rule("table", "seats")
		if why != "":
			print("[ui] build table: stayed (%s)" % why)
			return
		_table_close_used = true
		print("[ui] build table: closed and flew (limit seats)")
		get_tree().create_timer(STAFF_CLOSE_DELAY).timeout.connect(_after_table_added)
		return
	if not id.begins_with("build_"):
		return
	var sid: String = id.substr(6)
	if lock_close:
		return
	# C1 review: the tandoor too (it pops in once BUILD has closed, see
	# WorldJuice), except in the tutorial's BUILD beat, whose outro shows it.
	if Layout3.BUILD_PAD_IDS.has(sid) or (sid == Game.station_with_role("first_build") and not _tutorial_build_beat()):
		get_tree().create_timer(0.12).timeout.connect(_after_station_built.bind(sid))


## The tutorial's BUILD beat (the Director closes BUILD and shows the tandoor).
func _tutorial_build_beat() -> bool:
	var d: Variant = Refs.director
	if d == null or not is_instance_valid(d) or not (d as Object).has_method("current_step"):
		return false
	return ["build_btn", "build_row", "build_close"].has(str((d as Object).call("current_step")))


func _after_station_built(sid: String) -> void:
	if current_panel != "daftar" or lock_close:
		return
	_close_panel(false)
	_fly_and_return(Layout3.station_focus(sid))


## A2.2: show the new thing, then come back to the view the player had.
func _fly_and_return(pos: Vector3) -> void:
	if not _cam_call("fly_to_and_return", [pos, -1.0, 2.5]):
		_cam_call("fly_to", [pos, -1.0])


func _on_seats_pill_tapped() -> void:
	if current_popup != "" or current_panel != "" or not _tap_allowed("tables"):
		return
	open_tables("pill")
	button_pressed.emit("seats_full_pill")


## Shows the new table popping in (J18 is played by the world on
## Game.seating_changed): closes the card / BUILD and flies the camera there.
func _after_table_added() -> void:
	if lock_close or not (current_panel == "daftar" or current_panel == "quick:tables"):
		return
	var from_quick: bool = current_panel == "quick:tables"
	_close_panel(false)
	var i: int = UiKit.gint("table_count", [], 0) - 1
	if i >= 0 and TableTag.has_table_point(i):
		if from_quick:
			return   # the table is already in view under the card
		_fly_and_return(TableTag.table_point(i))


func _on_vip_action(id: String) -> void:
	# Report the action first: listeners (the Director) must know FREE was
	# taken before they see the popup close.
	if id == "vip_free":
		# C7.2: FREE paid, so the bubble is spent (and the next one waits the
		# full interval) even if it already went away under the popup.
		Game.consume_ad_bubble()
	button_pressed.emit(id)
	if id == "vip_free" and current_popup == "vip":
		_hide_popup()
	elif id == "vip_unlock" and current_popup == "vip" and vip_popup.variant == "starter":
		# C7.4: the starter pack is paid by Game once nothing is open.
		_hide_popup()


func _on_offline_ready(_amount: float, _seconds: float) -> void:
	# The signal is deferred by Game: read the live values (a debug wipe in
	# between zeroes them) and never interrupt the tutorial.
	_check_pending_offline()


## WELCOME BACK when the launch pop-up budget allows it (C4.4); refused by
## the budget alone, the pay is collected at once with a toast; held back by
## something on screen, it is retried (OFFLINE_POLL_S).
func _check_pending_offline() -> void:
	if Game.pending_offline <= 0.0:
		_offline_waiting = false
		return
	if current_popup == "offline":
		# Already showing: Game's amount is cumulative, open_offline refreshes.
		open_offline(Game.pending_offline, Game.offline_seconds)
		_offline_waiting = false
		return
	if _tutorial_active():
		var d: Node = Refs.director
		if d != null and d.has_signal("finished") and not d.is_connected("finished", _check_pending_offline):
			d.connect("finished", _check_pending_offline, CONNECT_ONE_SHOT)
		return
	var why: String = interrupt_block_reason("offline")
	# W1-FIX-core (C4.4): Munshi-ji's one-time "New prices!" line outranks
	# WELCOME BACK: the pay arrives silently with the toast, and the line
	# takes the launch budget once the toast and burst end (munshi_notes).
	if why == "" and Game.has_method("economy_note_due") and bool(Game.call("economy_note_due")):
		_offline_waiting = false
		print("[ui] welcome back gives way: eco note due")
		_collect_offline_silently()
		return
	if why == "budget":
		if _screen_busy():
			# Collect once the screen is free, so the toast is seen.
			_offline_waiting = true
			return
		_offline_waiting = false
		_collect_offline_silently()
		return
	if why != "":
		_offline_waiting = true
		if current_popup != "":
			_queued_offline = true
		return
	_offline_waiting = false
	note_interrupt("offline")
	open_offline(Game.pending_offline, Game.offline_seconds)


## C4.4: WELCOME BACK refused by the budget: paid now, said in a toast.
func _collect_offline_silently() -> void:
	var got: float = Game.claim_offline(1.0)
	Analytics.event("popup_suppressed", {"kind": "offline"})
	if got <= 0.0:
		return
	print("[ui] welcome back paid silently: +%.2f" % got)
	SdkNotice.toast(SdkNotice.welcome_back_text(got))
	if hud != null:
		hud.play_reward_burst(hud.burst_center(), got)


## C7.2: the rewarded ad that was on screen when the app died last time paid
## now (offers module, on the first frame the UI exists).
func _on_ad_pending_paid(amount: float) -> void:
	SdkNotice.toast(SdkNotice.owed_bonus_text(amount))
	if hud != null:
		hud.play_reward_burst(hud.burst_center(), amount, true)


## C7.4: the starter pack's dhaba cash (paid once, after the tutorial).
func _on_starter_paid(amount: float) -> void:
	SdkNotice.toast(SdkNotice.starter_paid_text(amount))
	if hud != null:
		hud.play_reward_burst(hud.burst_center(), amount)


func _tutorial_active() -> bool:
	# The Director may not have started yet on the first frame: an unfinished
	# tutorial counts as active whenever a Director exists.
	var d: Node = Refs.director
	return d != null and is_instance_valid(d) and not Game.is_tutorial_done()


func _on_offline_closed() -> void:
	if current_popup == "offline":
		_hide_popup()


# ================================================================ core and feel: fix routing (W2-ROOT)
## C2.5 / C2.6: opens the card that fixes `fix` (a Game.bottleneck_fix() dict,
## or a readout row's fix): hire waiter -> the quick waiter card (by the
## oldest waiting plate, else the ghost; a fly when neither is on screen);
## upgrade waiter -> STAFF › WAITERS; table -> open_tables("fix") (the ghost
## table's card, else BUILD › TABLES); hire / upgrade cashier -> STAFF ›
## CASHIERS; cook / speed / level -> that counter's sheet; signboard -> BUILD
## at the signboard row. A coach hand points at the button the first 2 times
## per kind while it is affordable. `source` ("sheet" | "meter" | "caption" |
## "chip" | "") goes to bottleneck_fix_tap (not for "sheet" or "": the sheet
## sends it on its own press). Prints "[ui] fix <kind> [<role|station>]
## (<source>)".
func do_fix(fix: Dictionary, source: String = "") -> void:
	var kind: String = str(fix.get("kind", "none"))
	var role: String = str(fix.get("role", ""))
	var sid: String = str(fix.get("station", ""))
	var idx: int = int(fix.get("index", -1))
	var paid: bool = bool(fix.get("affordable", false))
	var what: String = role if role != "" else sid
	print("[ui] fix %s%s (%s)" % [kind, " " + what if what != "" else "", source if source != "" else "-"])
	if kind == "" or kind == "none" or current_popup != "":
		return
	# The sheet sends bottleneck_fix_tap on its own press (W2-PANELS); the
	# meter's readout_tap is the HUD's (W2-HUD).
	if source != "" and source != "sheet":
		Analytics.event("bottleneck_fix_tap", {"fix": kind + (":" + role if role != "" else ""), "source": source})
	var coach: String = ""
	match kind:
		"hire":
			if role == "cashiers":
				open_staff("cashiers", {"highlight": "hire"})
				coach = "staff_hire_cashiers"
			else:
				_open_quick_waiters("fix", "quick_buy_button" if paid else "", "fix_hire_waiters")
		"upgrade":
			var tab: String = "cashiers" if role == "cashiers" else "waiters"
			open_staff(tab)
			if idx >= 0:
				coach = "staff_upgrade_%s_%d" % [tab, idx]
		"table":
			if open_tables("fix") != "":
				coach = "seating_add_button"
		"cook", "speed", "level":
			if sid == "" or not Game.is_built(sid):
				return
			if current_panel != "station:" + sid:
				if current_panel != "" and not current_panel.begins_with("station:"):
					_close_panel(true)
				open_station(sid)
			match kind:
				"cook":
					coach = "hire_button"
				"speed":
					coach = "processing_button"
				_:
					coach = "level_up_button"
		"signboard":
			open_daftar("build")
			daftar.focus_row("signboard")
			coach = "build_row_signboard"
	if coach != "" and paid:
		coach_hand(coach, {"kind": "fix_%s_%s" % [kind, role if role != "" else "x"]})


## C2.6: a readout row tapped (BottleneckMeter.row_tapped, W2-HUD; connected
## by name): that row's fix.
func _on_meter_row(stage: String) -> void:
	if not can_press("meter_row") or current_popup != "" or current_panel != "":
		return
	# W4-FIX (onboarding_1): during a tutorial lesson only the lesson's row
	# acts (the waiter beat's SEATS row opened BUILD > TABLES before L16
	# brings BUILD in; its COOKS row opened a counter sheet mid-lesson).
	var lesson: String = BottleneckMeter._lesson_stage()
	if lesson != "" and stage != lesson:
		return
	var fix: Dictionary = {}
	for rv in Game.bottleneck_rows():
		if rv is Dictionary and str((rv as Dictionary).get("stage", "")) == stage:
			var fv: Variant = (rv as Dictionary).get("fix", {})
			fix = fv if fv is Dictionary else {}
			break
	# (readout_tap {row} is sent by the meter itself.)
	button_pressed.emit("meter_row")
	do_fix(fix, "meter")


## C2.7: the readout's road caption tapped (road_tapped): the state's fix
## (SIGNBOARD or LEVEL UP while the road is the limit).
func _on_meter_road() -> void:
	if not can_press("meter_road") or current_popup != "" or current_panel != "":
		return
	var fv: Variant = Game.bottleneck_state().get("fix", {})
	button_pressed.emit("meter_road")
	do_fix(fv if fv is Dictionary else {}, "caption")


## C6.4: the HUD's BARAAT button (EventButton.pressed_event).
func _on_event_button() -> void:
	if not can_press("event_button") or current_popup != "" or current_panel != "":
		return
	open_event()
	button_pressed.emit("event_button")


## The HUD widget `n` ("meter" | "event_button", W2-HUD's Hud methods,
## called by name), or null.
func _hud_widget(n: String) -> Object:
	if hud == null or not hud.has_method(n):
		return null
	var v: Variant = hud.call(n)
	if v is Object and is_instance_valid(v):
		return v
	return null


## Connects the readout's and the event button's signals once they exist
## (by name, plan rule 5).
func _hook_hud_widgets() -> void:
	var m: Object = _hud_widget("meter")
	if m != null and m != _meter_hooked:
		_meter_hooked = m
		if m.has_signal("row_tapped") and not m.is_connected("row_tapped", _on_meter_row):
			m.connect("row_tapped", _on_meter_row)
		if m.has_signal("road_tapped") and not m.is_connected("road_tapped", _on_meter_road):
			m.connect("road_tapped", _on_meter_road)
	var e: Object = _hud_widget("event_button")
	if e != null and e != _event_btn_hooked:
		_event_btn_hooked = e
		if e.has_signal("pressed_event") and not e.is_connected("pressed_event", _on_event_button):
			e.connect("pressed_event", _on_event_button)


# ================================================================ core and feel: staff / table show rule (C3.1)
func _director_active() -> bool:
	var d: Variant = Refs.director
	return d != null and is_instance_valid(d) and (d as Object).has_method("is_active") \
			and bool((d as Object).call("is_active"))


## The readout's limit now ("road" while the road is the limit; cached by
## the readout, so cheap).
func _limit_now() -> String:
	var st: Dictionary = Game.bottleneck_state()
	if bool(st.get("road_capped", false)):
		return "road"
	return str(st.get("limit", ""))


## Samples the readout's limit (free play: the C3.1 rule never applies while
## the Director runs, and the tutorial's numbers stay untouched).
func _sample_limit() -> void:
	_limit_t = 0.0
	if Game.is_tutorial_done() and not _director_active():
		_limit_seen = _limit_now()


## Game.cash_spent: a waiter hire or a table keeps the limit seen just before
## it (C3.1's "the hire fixes the current limit").
func _on_cash_spent(_amount: float, what: String) -> void:
	if what == "waiter_hire" or what == "table":
		_limit_at_spend[what] = _limit_seen


## Why a purchase does NOT close its panel and show the new thing ("" = it
## does): the Director runs, close is locked, used once this session, or the
## limit just before was not `stage`.
func _show_purchase_rule(what: String, stage: String) -> String:
	var before: String = str(_limit_at_spend.get(what, ""))
	_limit_at_spend.erase(what)
	if _director_active():
		return "director"
	if lock_close:
		return "lock"
	if (_staff_close_used if what == "waiter_hire" else _table_close_used):
		return "once a session"
	if before != stage:
		return "limit %s" % (before if before != "" else "none")
	return ""


## STAFF actions (relayed as button_pressed). C3.1: a STAFF › WAITERS hire
## that fixes the limit closes STAFF 0.3 s later and shows the new waiter
## (fly and return, 2.5 s); otherwise STAFF stays open.
func _on_staff_action(id: String) -> void:
	button_pressed.emit(id)
	if id != "waiter_hire" or not current_panel.begins_with("staff:"):
		return
	var why: String = _show_purchase_rule("waiter_hire", "waiters")
	if why != "":
		print("[ui] staff hire: stayed (%s)" % why)
		return
	_staff_close_used = true
	print("[ui] staff hire: closed and flew (limit waiters)")
	get_tree().create_timer(STAFF_CLOSE_DELAY).timeout.connect(_close_staff_and_show.bind(Game.waiter_count() - 1))


func _close_staff_and_show(i: int) -> void:
	if not current_panel.begins_with("staff:") or lock_close or current_popup != "":
		return
	_close_panel(false)
	if i >= 0:
		var p: Vector3 = Layout3.waiter_home(i)
		if not _cam_call("fly_to_and_return", [p, -1.0, SHOW_HOLD_S]):
			_cam_call("fly_to", [p, -1.0])


# ================================================================ dhaba growth step 3: construction
## The site tag's FINISH NOW: a rewarded ad ("build_skip"); its reward finishes
## the construction (Game reloads the scene for a new stage, or applies the
## renovation / move). No ad ready: a toast. If the app dies mid-ad nothing
## is owed: the construction just runs on by the clock.
func _on_build_site_tapped() -> void:
	if current_popup != "" or current_panel != "" or not Game.build_job_active():
		return
	if Game.build_free_skip_ready():
		# Step 4: the shack's one free skip (no ad).
		Analytics.event("build_skip_free", {"kind": Game.build_job_kind()})
		button_pressed.emit("build_skip_free")
		Game.finish_build_job_now("free")
		return
	if not Ads.is_rewarded_ready("build_skip"):
		hud.toast(tr("No video right now. The workers keep going!"))
		return
	Analytics.event("ad_offer_tapped", {"placement": "build_skip", "kind": Game.build_job_kind()})
	Ads.show_rewarded("build_skip", _on_build_skip_done)


func _on_build_skip_done(ok: bool) -> void:
	print("[ui] build_skip ad -> %s" % str(ok))
	if ok:
		Game.finish_build_job_now("ad")


# ================================================================ core and feel: promotions (C5.2, C6.1, C6.3)
## PromoPopup's primary button on a ready, affordable promotion: everything
## closes, then Game.renovate() / Game.move_highway(id) (Game saves and the
## scene reloads, main3's production hook).
func _on_promo_action(id: String) -> void:
	var tgt: String = promo_popup.target
	button_pressed.emit(id)
	close_all()
	var ok: bool = false
	if id == "promo_renovate":
		ok = Game.renovate()
	elif id == "promo_move":
		ok = Game.move_highway(tgt)
	print("[ui] promo %s -> %s" % [id, str(ok)])


# ================================================================ core and feel: Aaj ka special (C6.2)
## The special waits for its announcement: the first check after
## SPECIAL_POLL_S, so a WELCOME BACK at launch (deferred) decides first.
func _queue_special_check() -> void:
	_special_wait = true
	_special_poll_t = 0.0
	_special_wait_t = 0.0


func _on_special_changed(dish_id: String) -> void:
	if dish_id != "":
		_queue_special_check()


## The active special's dish id when it still waits for its announcement,
## else "".
func _special_due() -> String:
	var st: Dictionary = Game.special_state()
	if st.is_empty() or not bool(st.get("active", false)) or bool(st.get("announced", false)):
		return ""
	return str(st.get("dish", ""))


## The dish name as shown (title case; Hindi: the translated name).
func _special_dish_text(dish_id: String) -> String:
	return UiKit.dish_title(dish_id.get_slice(".", 0), dish_id)


## Polled while a special waits: once WELCOME BACK has decided (it carries
## the band when it opens) and nothing covers the screen, MenuPop's AAJ KA
## SPECIAL card over the counter for 4 s. Not a launch pop-up (no budget).
func _check_special() -> void:
	var sp: String = _special_due()
	if sp == "":
		_special_wait = false
		return
	_special_wait_t += SPECIAL_POLL_S
	if _tutorial_active() or current_popup == "offline":
		return
	if Game.pending_offline > 0.0 and (_offline_waiting or _special_wait_t < SPECIAL_OFFLINE_WAIT_S):
		return
	if _screen_busy() or menu_pop == null:
		return
	_special_wait = false
	menu_pop.show_special(sp.get_slice(".", 0), sp)
	_announce_special(sp, "card")


## The announcement showed (band or card): Game marks it and starts the
## counter's 8-ticket showcase; the counter's tag shows for the session.
func _announce_special(dish_id: String, where: String) -> void:
	Game.mark_special_announced()
	_special_tag_dish = dish_id
	_special_wait = false
	print("[ui] special announced: %s (%s)" % [dish_id, where])
	for nt in note_tags:
		if is_instance_valid(nt):
			(nt as WorldNoteTagScript).poll_now()


# ================================================================ core and feel: world note tags
## The note tags show in free play while nothing is open.
func _note_tags_allowed() -> bool:
	return Game.is_tutorial_done() and current_panel == "" and current_popup == ""


## The special announced this session ("" = none).
func _special_tag() -> String:
	return _special_tag_dish


## The counter under MenuPop's card on show ("" = none).
func _menu_pop_station() -> String:
	return menu_pop.showing_station() if menu_pop != null else ""


# ================================================================ core and feel: last press (W2-FX)
## The rect (canvas px) of the button under the last press; around the press
## point when no button was under it; Rect2() before any press. W2-FX aims the
## spend notes there while a panel covers the world.
func last_press_rect() -> Rect2:
	if not _press_seen:
		return Rect2()
	if _press_rect_id != _press_id:
		_press_rect_id = _press_id
		var b: Control = _button_at(_press_pos)
		if b != null:
			_press_rect = b.get_global_rect()
		else:
			_press_rect = Rect2(_press_pos - Vector2(PRESS_HALF, PRESS_HALF), Vector2(PRESS_HALF, PRESS_HALF) * 2.0)
	return _press_rect


## The topmost visible UiButton under `p` in the open popup, panel or card.
func _button_at(p: Vector2) -> Control:
	var roots: Array = []
	if current_popup != "":
		roots.append(_popup_root)
	if current_panel.begins_with("quick:"):
		roots.append(quick_buy)
	elif current_panel != "":
		roots.append(_panel_root)
	roots.append(hud)
	for r in roots:
		var hit: Control = _find_button(r as Node, p)
		if hit != null:
			return hit
	return null


func _find_button(n: Node, p: Vector2) -> Control:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return null
	# Children drawn later sit on top: search them last-first.
	for k in range(n.get_child_count() - 1, -1, -1):
		var hit: Control = _find_button(n.get_child(k), p)
		if hit != null:
			return hit
	if n is UiButton and (n as Control).get_global_rect().has_point(p):
		return n as Control
	return null


func _input(event: InputEvent) -> void:
	var down: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		down = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		pos = mb.position
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		down = st.pressed
		pos = st.position
	if down:
		_press_pos = pos
		_press_seen = true
		_press_id += 1


func _notification(what: int) -> void:
	# C6.2: a resume may pick a special (Game's module) or bring one that was
	# never announced.
	if what == NOTIFICATION_APPLICATION_RESUMED and is_node_ready():
		_queue_special_check()


# ================================================================ SDK messages / interstitials
## Iap.purchase_result -> a toast (SdkNotice; "" for a plain success).
func _on_purchase_result(product_id: String, result: String) -> void:
	SdkNotice.toast(SdkNotice.purchase_text(result))
	if result == "purchased" or result == "granted":
		Funnel.once("iap_first_success", "iap_success", {"id": product_id, "result": result})


## Soft launch analytics: the interstitial's close (Ads logs its open as
## interstitial_shown).
func _on_interstitial_finished(trigger: String, shown: bool) -> void:
	Analytics.event("interstitial_finished", {"trigger": trigger, "shown": shown})


func _note_purchase(id: String) -> void:
	if current_panel == "":
		return
	for p: String in UPGRADE_IDS:
		if id == p or (p.ends_with("_") and id.begins_with(p)):
			_bought_in_panel = true
			return


func _on_closed_for_interstitial(pname: String) -> void:
	var is_panel: bool = pname.begins_with("station:") or pname.begins_with("staff:") \
			or pname.begins_with("quick:") or pname == "daftar"
	var trigger: String = ""
	# C7.1: never on the return screen (WELCOME BACK is no call site).
	if _bought_in_panel and (pname.begins_with("station:") or pname.begins_with("staff:")):
		# Not the quick card: its hire ends on the "+1 WAITER" float.
		trigger = "upgrade"
	if is_panel:
		_bought_in_panel = false
	if trigger == "":
		return
	get_tree().create_timer(INTERSTITIAL_DELAY).timeout.connect(_try_interstitial.bind(trigger))


## A natural pause: only back in plain gameplay (nothing open, no tutorial,
## no dialogue); Ads decides the rest (caps, Remove Ads, trigger list).
func _try_interstitial(trigger: String) -> void:
	if current_panel != "" or current_popup != "" or _tutorial_active() or lock_close:
		return
	if Refs.dialogue != null and is_instance_valid(Refs.dialogue) and (Refs.dialogue as Object).has_method("is_open") \
			and bool((Refs.dialogue as Object).call("is_open")):
		return
	var ads: Node = UiKit.autoload("Ads")
	if ads != null and ads.has_method("maybe_show_interstitial"):
		ads.call("maybe_show_interstitial", trigger)
