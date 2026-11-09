class_name Main3
extends Node3D
## v0.3 entry scene (scenes/main3.tscn). Builds the whole game in code:
##   environment + warm daylight sun, Sim (static world, traffic + truck
##   parking, stations, gallas, staff, table sets + ghost, waiter stand +
##   waiters), the fairy-light driver and the rooftop signboard text,
##   CameraRig, WorldInput, UiRoot (+ Hud, STAFF / BUILD panels, the 2-tap
##   card, ghost-waiter and ghost-table tags, ghost build pad price tag,
##   "Seats full!" pill), DialogueBox,
##   the tutorial Director and MunshiNotes (free-play build lines).
##   Refs fields are set BEFORE each module enters the tree, so every module's
##   _ready already sees its peers.
##
## Debug command-line flags (debug builds only, after `--`):
##   --lang=hi|en        play in Hindi / English this run (not saved; read by
##                       the Loc autoload before anything is built)
##   --fresh             wipe the save and start a new game
##   --skip-tutorial     mark the tutorial done (free play, full HUD)
##   --money=N           set cash to N (reference units; the HUD shows x10)
##   --speed=N           Engine.time_scale = N
##   --auto              autopilot: advances dialogue and performs every
##                       tutorial gate with real taps where the hand / marker
##                       points (falls back to the handler a tap would call);
##                       its free-play purchases and first claim are timed
##                       from the tutorial's free step; at "step -> done" it
##                       prints "[auto] <t> done state: chai L<n> cash <c>
##                       waiters <n> tables <n>"; 1 s after the tutorial it
##                       prints an "[auto] ... home check" line (camera
##                       distance to the home view, NEXT chip); with
##                       --consent=ask it answers the consent card ALLOW once
##                       it has been open 1.5 s ("[auto] <t> consent answered")
##   --shots=t1,t2,...   save viewport PNGs at these game-time seconds…
##   --shot-dir=PATH     …into this folder (default user://shots)
##   --quit-at=SEC       quit at this game time
##   --open=NAME         open a panel at start for UI review: chai (any
##                       station id), staff (the tab STAFF picks itself),
##                       staff:waiters / staff:cashiers / staff:cooks, build
##                       (= daftar), stats (= hisaab), tables (the ghost
##                       table's 2-tap card, else BUILD › TABLES),
##                       quick:waiters, quick:tables, vip, settings, phone
##                       (story: Simran's chat), menu (every counter); the old
##                       names galla / waiters / seating still work (STAFF ›
##                       CASHIERS / STAFF › WAITERS / tables) (use with
##                       --skip-tutorial)
##   --stats=SEC         print a one-line sim summary every SEC game seconds
##                       (core and feel: "| door max | passed | held (max) |
##                       trip orders | home walks | cap | hall seated (%) |
##                       hall food .. road food .." from the Sim's getters,
##                       "-" where this build's Sim has none)
##   --buy=a,b,...       purchases at start: galla, waiter, table, waiter_up,
##                       galla_up (galla 1 level), grow (start the next stage's
##                       paid build), a station id to build it
##                       (tandoor, lassi, kadai), <id>_up (level up),
##                       <id>_hire (hire a cook), <id>_speed (processing),
##                       <id>_lvl<N> (set the level outright, station menus:
##                       milestone dish unlocks fire as on LEVEL UP taps),
##                       waiter_lvl<N> (every waiter to level N; prints
##                       "[game] waiter tray <i> orders <k>"),
##                       e.g. chai_up, lassi_hire, kadai_up, chai_lvl24
##   --no-notes          MunshiNotes off (measurement runs)
##   --seed=N            fixed pacing seed N (tutorial and free play) for
##                       repeatable / varied measurement runs
##   --arrivals=N        force the arrival ramp's target to N travellers/min
##   --window=SEC        print a [window] line (arrivals/min, lost, travellers
##                       who drove past, takings/min = sales only, food
##                       waits; event guests while the baraat is on) for the
##                       first SEC sim seconds after the tutorial ends (from
##                       the start if it is already done); no --stats needed
##   --capture=free      free-play review shots (use with --skip-tutorial
##                       --money=N --shot-dir=DIR): home view with seated
##                       travellers / Raju carrying / both gallas, the ghost
##                       table + price tag, SEATING and WAITERS panels, the
##                       exterior, a lorry reversing in and one pulling out
##   --capture=bus       BUS STOP shots into DIR/bus_*.png (same flags): a bus
##                       pulling in, riders stepping off, the waiting line
##                       under the shelter, the line climbing aboard, the bus
##                       pulling away, then reaching the zebra crossing
##                       (bus_xing*); quits when done
##   --capture=tray      whole-order shot (with --skip-tutorial --money=N
##                       --buy=tandoor --shot-dir=DIR): Raju close up with a
##                       kulhad + roti on his tray -> DIR/waiter_whole_order.png
##                       (+ _serve as they hop onto the table); quits
##   --capture=menu      menu-expansion / station-menus review shots (with
##                       --skip-tutorial --money=N --shot-dir=DIR): prints
##                       "MODELS missing: [...]" (new glbs not imported yet),
##                       then DIR/menu_*.png: ghost_lassi_needs, daftar_w1,
##                       note_lassi_waiters (one waiter: the lassi needs 2),
##                       ghost_lassi, note_lassi, lassi_home, lassi (close up),
##                       cooks_lassi, ghost_kadai (NEEDS 3 WAITERS), daftar
##                       (BUILD rows with their MENU lines), ghost_kadai_ready,
##                       note_kadai, buildpads (the 2 pads stacked), kadai
##                       (close up), annex (the kadai cooking, a waiter at a
##                       pickup, table 4), cooks_annex (Shera, Kamla, Kallu),
##                       unlock_pop (chai L24 + one LEVEL UP with the sheet
##                       open: the NEW ON THE MENU pop), chai_sheet (the same
##                       sheet once the pop is gone: coffee unlocked, green
##                       tea + kesar doodh locked), unlock_props (home
##                       view, chai and lassi at L100: the props), sheet_kadai
##                       (the kadai sheet at L50: 2 chips unlocked, 2 locked),
##                       bubbles (two-icon bubbles with the new dish icons),
##                       tray (every ticket forced to coffee / naan / chaas /
##                       paneer: a waiter with coffee + naan and one with
##                       chaas + paneer in one mid-zoom frame), tablefood (new
##                       dishes on the tables), full (all four stations, every
##                       cook, mixed orders); quits
##   --tap-check         menu-expansion tap test (docs/v3-station-menus.md
##                       §11.6; with --skip-tutorial --money=1e12 on a fresh
##                       save): stages A, B (lassi), C (the kadai pad, 5
##                       tables) and D (kadai built, 3 cooks, L100 props;
##                       also from the kadai and annex views), one TAPCHECK
##                       line per world point,
##                       then "TAPCHECK fails=<n>"; quits with exit code n.
##                       In the family layout (after --renovate) only stage E
##                       runs: the hall's ghost waiter, waiter 4 and tables
##                       2-7, from the home view and the hall view
##   --time=P            day / night cycle phase 0..1 at start (0 = dawn,
##                       0.25 bright day, 0.62 dusk, 0.84 night); the cycle
##                       runs on from there once the tutorial is done
##   --capture=daynight  day / night review shots (with --skip-tutorial
##                       --money=N --shot-dir=DIR): the cycle frozen at
##                       daynight.shots dawn / day / dusk / night, a wide
##                       front view -> DIR/daynight_<band>.png and the home
##                       view -> DIR/daynight_<band>_home.png; quits
##   --capture=zoom      DIR/zoom_in.png (player zoom at camera.zoom_min on
##                       the chai counter) and DIR/zoom_out.png (zoom_max,
##                       the whole dhaba and parking); quits
##   --capture=munshi    Munshi-ji bust review (with --skip-tutorial
##                       --shot-dir=DIR): DIR/munshi_models.png (every pose
##                       glb side by side, front view, no rig: the pure
##                       models) and DIR/munshi_<pose>_<enter>.png, each bust
##                       pose x entrance (right, bottom, left = right with
##                       the box on the left, bottomright = bottom_right with
##                       the box on the right) with a sample line, shot
##                       mid-entrance (_mid) and settled; quits
##   --zoom-test         pinch / wheel / magnify test: synthetic
##                       InputEventScreenTouch + Drag pairs, wheel notches
##                       and InputEventMagnifyGesture through Input; checks
##                       the zoom direction, the anchor staying under the
##                       pinch midpoint / cursor, the limits, no tap, no
##                       drag-pan jump, no inertia; "ZOOMTEST fails=<n>",
##                       quits with exit code n (with --skip-tutorial)
##   --tap-zoom=M        --tap-check at player zoom M (min, max or a number)
##                       instead of the game zoom
##   (--stats also prints arrivals/min, lorry vs bus, the bus-stop line, the
##    measured whole-order trips per order key, the demand shares, each
##    station's queue / pass and, at --quit-at, a [summary] line with run
##    averages, the order mix seen and the serves per dish + dish mismatches)
## Core and feel (build plan 2.7):
##   --reno-ready        Game.debug_reno_ready(): every counter built and at
##                       L100, the Family Dhaba unlocked (cash untouched);
##                       prints "[promo] renovation ready: dishes n/16 cost c"
##   --renovate-paid     --reno-ready, then a paid Game.renovate() (dhaba
##                       growth step 3: starts the timed construction; give
##                       cash with --money; --build-dur=SEC shortens it)
##   --renovate          --reno-ready, then Game.renovate(true) once the scene
##                       is up: the scene reloads (the production path) and
##                       the run goes on in the family layout
##   --move=nh48         --renovate, then on the reloaded scene
##                       debug_reno_ready() + move_highway("nh48", true): a
##                       second reload, the run goes on at NH 48
##   --signboard=N       Game.debug_set_signboard(N); prints
##                       "[game] signboard N cap <ramp cap>"
##   --claims=N          Game.debug_set_claims(N) (task claims so far)
##   --sessions=N        Game.debug_set_sessions(N) (--open=vip then prints
##                       "[offer] variant <v>")
##   --special=DISH|none|auto  the daily special: that dish (validated by
##                       Game), none, or the real rules (a debug run with flags
##                       has no special without --special or --date)
##   --phone=ID,ID,...   story: Simran's messages now (story.gd MESSAGES ids;
##                       debug builds)
##   --visit=N           story: the father's visit N (1-3) at the next calm
##   --event=on|off|auto the weekend baraat (debug runs with flags: off
##                       unless --event or --date)
##   --event-guests=N    N baraat guests counted at once
##   --event-claim       claims every done goal step, now and whenever one
##                       completes
##   --fx-log            Fx.debug_log on (spend flight log lines)
##   --promo-check       promotions end to end (with --fresh --skip-tutorial
##                       --money=1e12): renovate -> reload -> family checks,
##                       NH 48 -> reload -> NH 48 checks; one "PROMOCHECK
##                       <phase> <check> ok|FAIL|SKIP" line per check, then
##                       "PROMOCHECK fails=<n>"; quits with exit code n
##   Applied once per process (static, so they survive the promotion's scene
##   reload): --fresh, --skip-tutorial, --money; then the promotion flags,
##   one reload each; then, on the final scene only and in this order:
##   --buy, --signboard, --claims, --sessions, --special, --event,
##   --event-guests, --event-claim, --open, the checks (--tap-check,
##   --zoom-test, --promo-check, --capture). --arrivals, --stats, --window
##   and --quit-at count from the scene they run in.
##   Parsed elsewhere: --lang (Loc); --consent=ask|allow|deny|reset and
##   --sdk-test (Analytics); --date=YYYY-MM-DD and --away=SEC (Game);
##   --layout=family (Layout3: the family layout without a renovation);
##   --tray=N (Sim: every waiter carries N orders); --ads=nofill (Ads: the
##   stub never fills).

const GfxQuality := preload("res://scripts/v3/core/gfx_quality.gd")
const SHADOW_DISTANCE := 60.0
const AMBIENT_ENERGY := 0.40
const SUN_ENERGY := 0.42
## Name board text area on dhaba_v3 (ART report): centre (3.8, 2.33, 10.112),
## 2.4 x 0.44 m, facing +Z. Core and feel C8.2: two lines, "DHABA RUSH" (as
## big as before, raised) over the Hindi line (plan 5.5, BI fixed text).
const NAME_BOARD_POS := Vector3(3.8, 2.42, 10.13)
const NAME_BOARD_TEXT := "DHABA RUSH"
## The Hindi line under it: its centre, cap / headline height (m), max width.
const NAME_BOARD_HI_POS := Vector3(3.8, 2.20, 10.13)
const NAME_BOARD_HI_CAP := 0.11
const NAME_BOARD_HI_MAX_W := 2.3
const NAME_BOARD_HI_TEXT := "ढाबा · होटल"
## Rooftop signboard text (ART v3_exterior.SIGN_TEXT): text, centre (faces
## +Z), max width (m), cap height (m), colour. Board model only in the glb.
## Entry 3 (the small English line) is set per scene: Game's location line
## (NH 48 "RAJASTHANI DHABA"), else SIGN_EN_FAMILY after the renovation, else
## SIGN_EN_ROADSIDE (core and feel C8.2 / C6.3, plan 5.5).
const SIGN_TEXT := [
	["ढाबा रश", Vector3(4.5, 4.36, -0.105), 2.6, 0.34, Color("FFFFFF")],
	["DHABA RUSH", Vector3(4.5, 3.86, -0.105), 4.4, 0.44, Color("FFD23F")],
	["24 घंटे खुला", Vector3(3.0, 3.36, -0.105), 2.3, 0.17, Color("FFFFFF")],
	["HOTEL & DHABA", Vector3(6.0, 3.36, -0.105), 2.3, 0.17, Color("FFFFFF")],
]
const SIGN_EN_INDEX := 3
const SIGN_EN_ROADSIDE := "HOTEL & DHABA"
const SIGN_EN_FAMILY := "AC FAMILY HALL"
const SIGN_FONT_SIZE := 128
## Cap height / em of Baloo 2 (and the Devanagari headline height).
const SIGN_CAP_EM := 0.68
## home_view() = galla 1 focus + this (matches Director.GALLA_VIEW_OFFSET):
## Pinky, both table sets, galla 1 and most of galla 2 (fixer re-layout).
## UX fix D9: an alias; the home framing lives in CameraRig (HOME_OFFSET,
## HOME size, home_point()).
const HOME_OFFSET := CameraRig.HOME_OFFSET

# --- autopilot tuning (game seconds)
const AUTO_READ := 1.4          # "reading" time after a line finished typing
const AUTO_TYPE_TIMEOUT := 9.0  # line never reported typed -> tap anyway
const AUTO_HAND_SETTLE := 0.5   # hand must be visible this long before a tap
const AUTO_TAP_GAP := 0.7       # between two taps on the same target
const AUTO_MARKER_WAIT := 0.9   # marker visible this long before tapping it
const AUTO_FALLBACK_AFTER := 3  # real taps without progress before calling handlers
const AUTO_CLAIM_AFTER := 3.0   # task ready this long before the autopilot claims
## The first claim not before this long after the tutorial's free step began
## (ref: free step at 88.0, claimed at 136.5).
const AUTO_CLAIM_NOT_BEFORE := 48.0
## Reference dwell per line (open -> dismissing tap, from the video). A tap
## at the dwell completes a line that is still typing; the next one advances.
## UX fix lines (lw*, lt*): 0.9 s + 0.25 s per word. Round 2 step 2: no L12
## (TASKS left the chain); L10 keeps its reference dwell (it gained "All your
## staff are in STAFF.", 11 words = 3.65 s by the rule).
const AUTO_DWELL := {
	"l1": 7.4, "l2": 2.0, "l3": 2.8, "l4": 5.1, "l5": 2.0, "l6": 2.0, "l7": 2.0,
	"l8": 1.7, "l9": 1.8, "l10": 5.0,
	"lw1": 2.9, "lw2": 2.65, "lw3": 2.65, "lt1": 2.9, "lt2": 2.65,
	"l14": 4.4, "l15": 4.3, "l16": 4.4, "l17": 3.0,
	# Step 4 (the cart): 0.9 s + 0.25 s per word, like the UX fix lines.
	"l1c": 7.4, "g1": 3.4, "g2": 2.65, "g3": 3.15, "shack_done": 3.65,
	# 9 Nov, the cart's L3 / L4 (Chhotu, the cash box): L3 / L4's dwell, so the
	# tutorial's beat times stay on the baseline.
	"l3c": 2.8, "l4c": 5.1,
}
## Reference reaction time per hand gate (hand shown -> tap, from the video);
## other gates use AUTO_HAND_SETTLE.
const AUTO_HAND_DWELL := {
	"tap_out": 2.4, "hire": 1.0, "close_galla": 1.0, "bubble": 1.0, "vip": 1.5,
	"build_btn": 2.0, "build_row": 1.0, "build_close": 1.3,
	"tap_staff": 1.0, "hire_waiter": 1.0, "close_waiters": 1.0, "tap_table": 1.0, "add_table": 1.0,
	"grow_btn": 2.0, "grow_row": 1.0, "grow_site": 1.0,
}
## Free-play purchases the reference player made (seconds after the
## tutorial's free step began, action; ref: free step at 88.0 s).
const AUTO_FREE_SCRIPT := [
	[17.9, "open_checkout"], [18.9, "galla_upgrade_0"], [20.4, "close_panel"],
	[32.3, "open_core"], [33.0, "processing"], [34.6, "level_up"], [35.4, "level_up"], [39.6, "close_sheet"],
	[41.6, "open_checkout"], [42.6, "galla_upgrade_0"], [43.6, "galla_upgrade_1"], [45.6, "close_panel"],
]
## Invariant: before the tutorial is done, something must move this often (s).
const AUTO_STALL_S := 90.0

var sim: Sim
var camera_rig: CameraRig
var world_input: WorldInput
var ui: UiRoot
var dialogue: DialogueBox
var director: Director
var munshi_notes: MunshiNotes
var sun: DirectionalLight3D
var env: Environment
var fairy_lights: FairyLights
var day_night: DayNight
var low_tier: bool = false
var _time_force: float = -1.0
var _zoom_test: bool = false
var _tap_zoom: String = ""
var _tap_mult: float = CameraRig.GAME

var _game_t: float = 0.0
var _skip_tutorial: bool = false
var _shots: Array[float] = []
var _shot_dir: String = "user://shots"
var _quit_at: float = -1.0
var _quitting: bool = false
var _open_at_start: String = ""
var _stats_every: float = 0.0
var _stats_next: float = 0.0
var _buy: PackedStringArray = PackedStringArray()
var _capture: String = ""
## --stats run averages: time-weighted mean galla line, arrivals at the last print.
var _line_area: float = 0.0
var _line_time: float = 0.0
var _arr_last: int = 0
var _arr_last_t: float = 0.0
var _busq_max: int = 0
var _busq_wait_max: float = 0.0
var _arrivals_force: float = -1.0
## --window: length (sim s), start snapshot (-1 = not started) and done flag.
var _window: float = 0.0
var _win_t0: float = -1.0
var _win_arr0: int = 0
var _win_lost0: int = 0
var _win_fw_sum0: float = 0.0
var _win_fw_n0: int = 0
var _win_buses0: int = 0
var _win_bus_riders0: int = 0
var _win_done: bool = false

var _tap_check: bool = false
## --check-pack (Idle Business Kit): PackCheck.run() on the theme pack, then quit
## with the number of failed checks.
var _check_pack: bool = false
## Menu-expansion + station-menus models (docs/v3-station-menus.md §10.1)
## and the core-and-feel models of build plan section 4 (props, buildings,
## people, NH 48 dishes); --capture=menu lists the missing ones.
const MENU_MODELS := ["lassi_station", "kadai_station", "pass_lassi", "pass_bhurji", "pass_dal",
		"pass_coffee", "pass_green_tea", "pass_kesar_doodh", "pass_naan", "pass_keema_paratha", "pass_kulcha",
		"pass_chaas", "pass_mango_lassi", "pass_patiala", "pass_paneer", "pass_chole",
		"prop_coffee_kettle", "prop_green_tea_jar", "prop_milk_can", "prop_naan_basket", "prop_keema_pot",
		"prop_kulcha_board", "prop_chaas_jug", "prop_mango_crate", "prop_patiala_glass", "prop_dal_handi",
		"prop_paneer_block", "prop_chole_sack",
		"lassi_wala", "bhurji_wala", "dal_wala", "neetu", "bittu", "kallu",
		"seats_board", "plate_stool", "tray_wide", "family_hall", "family_table", "hoarding", "tv_set",
		"dog_sit", "bus_baraat", "deco_baraat", "camel_cart", "pass_kulhad",
		"trav_elder", "trav_sardar", "trav_farmer", "trav_techie", "trav_baraati_m", "trav_baraati_f",
		"gopal", "lakhan", "balwant", "sonu",
		"pass_missi_roti", "pass_lahsun_roti", "pass_baati", "pass_rabri", "pass_dal_baati", "pass_gatte",
		"pass_ker_sangri", "pass_laal_maas", "pass_shikanji"]

# --- core and feel debug flags (build plan 2.7). Static: they survive the
# promotion's get_tree().reload_current_scene() (one process = one run).
## --fresh / --skip-tutorial / --money / --reno-ready already applied.
static var _once_done: bool = false
## Promotion steps still to run, one per scene: "renovate", "move:<id>".
static var _promo_steps: Array = []
## --promo-check: the phase the next scene runs (1 = the first scene) and the
## fails so far.
static var _pc_phase: int = 1
static var _pc_fails: int = 0
## session_settings is sent once per app start, not again after a reload.
static var _session_settings_sent: bool = false
## A final scene ran its debug flags (_start_debug_flags): a later scene (a
## promotion reload) does not apply the one-shot flags (--buy, --open, the
## game-state flags) again (plan 2.7).
static var _final_done: bool = false
## Step 4: the game clock carried over a promotion's reload (the tutorial's
## shack beat reloads mid-run; logs keep one timeline). -1 = none.
static var _game_t_carry: float = -1.0
## This scene only runs a promotion flag's step and reloads (debug).
var _promo_scene: bool = false
## The promoted signal arrived: this scene is about to be replaced.
var _reloading: bool = false
var _promo_check: bool = false
var _fx_log: bool = false
var _signboard_n: int = -1
var _claims_n: int = -1
var _sessions_n: int = -1
var _special_arg: String = ""
## Story (4 Nov): --phone=id,id,... sends Simran's messages at start (debug).
var _phone_arg: String = ""
var _event_mode: String = ""
var _event_guests: int = -1
var _event_claim: bool = false
## The two sign lines set this scene (C8.2 / C6.3): name board Hindi, rooftop English.
var _sign_hi: String = ""
var _sign_en: String = ""
## --window extras: passed and takings (sales only: lifetime earnings minus
## rewards) and baraat guests at the window start.
var _win_passed0: int = 0
var _win_life0: float = 0.0
var _win_reward0: float = 0.0
var _win_event0: int = 0
var _rewards_seen: float = 0.0

var _auto: bool = false
var _auto_next: float = 0.0
var _auto_sig: String = ""
var _auto_tries: int = 0
var _auto_line: String = ""
var _auto_line_t: float = 0.0
var _auto_typed_t: float = -1.0
var _auto_hand_since: float = -1.0
var _auto_marker_t: float = 0.0
var _auto_prog_key: String = ""
var _auto_prog_t: float = 0.0
var _auto_stall_step: String = ""
var _auto_ready_t: float = -1.0
var _auto_free_i: int = 0
var _auto_done_t: float = -1.0
var _auto_drag_done: bool = false
var _auto_log_step: String = ""
## Game time the tutorial's free step was first entered (-1 = not yet).
var _auto_free_t0: float = -1.0
var _auto_home_checked: bool = false
## --consent=ask: game time the consent card was first seen open, and when
## the autopilot tapped ALLOW (-1 = not yet).
const AUTO_CONSENT_DWELL := 1.5
const AUTO_CONSENT_RETRY := 1.0
var _auto_card_t: float = -1.0
var _auto_card_tap_t: float = -1.0
## 0 = not answered yet, 1 = ALLOW tapped, 2 = answered by its handler.
var _auto_card_stage: int = 0


func _ready() -> void:
	if _game_t_carry >= 0.0:
		_game_t = _game_t_carry
		_game_t_carry = -1.0
	_parse_cmdline()
	_detect_tier()
	Refs.world = self
	# Core and feel C6.1 / C6.3 (production): a renovation or a move resets
	# Game, which saves and emits promoted; this scene then reloads.
	if Game.has_signal("promoted") and not Game.is_connected("promoted", _on_promoted):
		Game.connect("promoted", _on_promoted)
	_build_environment()

	# Modules: Refs first, then into the tree (Sim builds the world in _ready).
	camera_rig = CameraRig.new()
	Refs.camera = camera_rig
	sim = Sim.new()
	sim.name = "Sim"
	Refs.sim = sim
	world_input = WorldInput.new()
	world_input.name = "WorldInput"
	world_input.camera_rig = camera_rig
	Refs.world_input = world_input
	ui = UiRoot.new()
	ui.name = "UiRoot"
	Refs.ui = ui
	dialogue = DialogueBox.new()
	dialogue.name = "DialogueBox"
	Refs.dialogue = dialogue
	director = Director.new()
	director.name = "Director"
	Refs.director = director

	add_child(sim)
	add_child(camera_rig)
	# The Director snaps its own intro view; free play starts on the gallas
	# (the same view the tutorial's transfer ends on).
	camera_rig.snap(home_view() if Game.is_tutorial_done() else Layout3.CAM_START, CameraRig.HOME if Game.is_tutorial_done() else CameraRig.GAME)
	_prewarm_puff_shader()
	add_child(world_input)
	add_child(ui)
	Refs.hud = ui.hud
	add_child(dialogue)
	add_child(director)
	munshi_notes = MunshiNotes.new()
	munshi_notes.name = "MunshiNotes"
	add_child(munshi_notes)
	# Story (4 Nov): Simran's father's visits.
	var visits := FatherVisits.new()
	visits.name = "FatherVisits"
	add_child(visits)
	var signs: Array = _sign_lines()
	_sign_hi = str(signs[0])
	_sign_en = str(signs[1])
	# Dhaba growth (6 Nov): the cart and the shack have no dhaba front, so no
	# "DHABA RUSH" board over the door and no rooftop signboard text.
	if Layout3.stage_id() == "dhaba":
		_add_name_board()
		_add_signboard()
	print("[main3] signs: %s | %s" % [_sign_hi, _sign_en])
	fairy_lights = FairyLights.new()
	fairy_lights.name = "FairyLights"
	add_child(fairy_lights)
	var strings: int = fairy_lights.attach(sim)
	day_night = DayNight.new()
	day_night.name = "DayNight"
	day_night.forced = _time_force
	day_night.low = low_tier
	add_child(day_night)
	day_night.setup(env, sun, sim, fairy_lights)
	if Game.is_tutorial_done():
		sim.prewarm(6)   # returning player: travellers already on their way in
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("--traffic-debug") and sim.traffic != null:
		sim.traffic.debug_overlaps = true
	if _promo_scene:
		# Debug: this scene only runs the next promotion flag, then reloads.
		_run_promo_step.call_deferred()
	else:
		_start_debug_flags()
	if not _shots.is_empty():
		DirAccess.make_dir_recursive_absolute(_globalize(_shot_dir))
	print("[main3] ready (low_tier=%s, auto=%s, shots=%d, fairy strings=%d, graphics=%s, max_fps=%d)" % [low_tier, _auto, _shots.size(), strings, GfxQuality.mode(), Engine.max_fps])
	# Soft launch analytics: the settings this session plays with (language,
	# graphics, sound), for splitting the funnel by them. Once per app start
	# (a promotion reloads this scene within the same session).
	if not _session_settings_sent:
		_session_settings_sent = true
		var loc: Node = get_node_or_null("/root/Loc")
		Analytics.event("session_settings", {"lang": str(loc.get("lang")) if loc != null else "en",
				"gfx": GfxQuality.mode(), "low": low_tier, "music": Sfx.music_on, "sound": Sfx.sound_on})


## The final scene's debug flags (plan 2.7 order): --arrivals, --stats and
## --window measure from this scene's start (as in 0.3.7); --buy, then the
## game-state flags, then --open run in one deferred sequence; the checks and
## captures start deferred as before.
func _start_debug_flags() -> void:
	_final_done = true
	if _arrivals_force > 0.0:
		sim.debug_arrivals_tpm = _arrivals_force
	if _window > 0.0 and Game.has_signal("reward_added"):
		Game.reward_added.connect(_on_reward_seen)
	if _fx_log:
		if "debug_log" in Fx:
			Fx.set("debug_log", true)
			print("[main3] --fx-log: Fx.debug_log on")
		else:
			print("[main3] --fx-log: SKIP (no Fx.debug_log)")
	if not _buy.is_empty() or _open_at_start != "" or _has_state_flags():
		_debug_sequence.call_deferred()
	if _capture == "free" or _capture == "lorry":
		_free_capture.call_deferred()
	elif _capture == "bus":
		_bus_capture.call_deferred()
	elif _capture == "tray":
		_tray_capture.call_deferred()
	elif _capture == "menu":
		_menu_capture.call_deferred()
	elif _capture == "daynight":
		_daynight_capture.call_deferred()
	elif _capture == "zoom":
		_zoom_capture.call_deferred()
	elif _capture == "munshi":
		_munshi_capture.call_deferred()
	if _zoom_test:
		_run_zoom_test.call_deferred()
	if _tap_check:
		_run_tap_check.call_deferred()
	if _check_pack:
		_run_check_pack.call_deferred()
	if _auto:
		dialogue.line_typed.connect(_on_auto_line_typed)
		ui.panel_opened.connect(func(n: String) -> void: print("[auto] %.2f panel opened: %s" % [_game_t, n]))
		ui.panel_closed.connect(func(n: String) -> void: print("[auto] %.2f panel closed: %s" % [_game_t, n]))
		ui.button_pressed.connect(func(b: String) -> void: print("[auto] %.2f button: %s" % [_game_t, b]))
		dialogue.line_started.connect(func(l: String) -> void: print("[auto] %.2f line %s" % [_game_t, l]))
	if _promo_check:
		_run_promo_check.call_deferred()


func _process(delta: float) -> void:
	_game_t += delta
	if _promo_scene:
		return   # debug: a promotion flag's scene; it reloads in a moment
	if not _shots.is_empty() and _game_t >= _shots[0]:
		var t: float = _shots.pop_front()
		_take_shot(t)
	if _auto:
		_auto_tick(delta)
	# (--window no longer needs --stats: it ticks on its own.)
	if _window > 0.0 and not _win_done:
		_tick_window()
	if _stats_every > 0.0:
		if not Game.sim_paused:
			_line_area += sim.avg_galla_line() * delta
			_line_time += delta
		_busq_max = maxi(_busq_max, sim.bus_line.size())
		_busq_wait_max = maxf(_busq_wait_max, sim.bus_wait_oldest())
		if _game_t >= _stats_next:
			_stats_next = _game_t + _stats_every
			_print_stats()
	if _quit_at > 0.0 and _game_t >= _quit_at and not _quitting:
		_quitting = true
		if _stats_every > 0.0:
			_print_summary()
		print("[main3] quit at game time %.2f (tutorial step: %s)" % [_game_t, director.current_step()])
		Game.save_game()
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# quit_on_go_back is off, so Android back comes here. UiRoot answers
		# every back: it closes the top popup / panel / sheet, else asks
		# "LEAVE THE DHABA?" (docs/launch/release.md §4.7). The old "press
		# back twice" toast fallback was never reached and is gone (C1).
		if ui != null:
			ui.handle_back()
		return
	match what:
		# Soft launch audio pass: silent while the app is in the background
		# (home button, another app, a full-screen ad, the store sheet). On a
		# phone losing focus counts too (notification shade, system dialogs);
		# on desktop it does not, so a dev build keeps playing behind the
		# editor.
		NOTIFICATION_APPLICATION_PAUSED:
			set_app_audio(false)
		NOTIFICATION_APPLICATION_RESUMED:
			set_app_audio(true)
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if OS.has_feature("mobile"):
				set_app_audio(false)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			if OS.has_feature("mobile"):
				set_app_audio(true)
		NOTIFICATION_WM_CLOSE_REQUEST:
			_session_end("close")


# ================================================================ app audio
## Master bus level while in the foreground (dB) and the fade back in.
const APP_AUDIO_DB := 0.0
const APP_AUDIO_SILENT_DB := -80.0
const APP_AUDIO_FADE_IN := 0.35

var _app_audio_on: bool = true
var _app_audio_tw: Tween


## Background silence on the Master bus VOLUME (Ads mutes the same bus with
## its MUTE flag while an ad is open and restores that flag itself, so the
## two never undo each other). Sfx's music and sound toggles stay as they
## are; the music keeps its place and fades back in.
func set_app_audio(on: bool) -> void:
	if on == _app_audio_on:
		return
	_app_audio_on = on
	if _app_audio_tw != null and _app_audio_tw.is_valid():
		_app_audio_tw.kill()
	if not on:
		AudioServer.set_bus_volume_db(0, APP_AUDIO_SILENT_DB)
		return
	AudioServer.set_bus_volume_db(0, -30.0)
	_app_audio_tw = create_tween()
	_app_audio_tw.tween_method(_set_master_db, -30.0, APP_AUDIO_DB, APP_AUDIO_FADE_IN)


func app_audio_on() -> bool:
	return _app_audio_on


func _set_master_db(db: float) -> void:
	AudioServer.set_bus_volume_db(0, db)


## Soft launch analytics: the player closed the window. (A LEAVE on the back
## question sends its own session_end {reason: back} from UiRoot.)
## Backgrounding is Analytics' app_background; GameAnalytics also ends its
## own session there.
func _session_end(reason: String) -> void:
	Analytics.event("session_end", {"reason": reason, "app_sec": int(float(Time.get_ticks_msec()) / 1000.0),
			"tutorial_done": Game.is_tutorial_done()})


## Free-play camera target: both gallas, their lines and the gate in view
## (CameraRig.home_point(); free play starts on it at CameraRig.HOME).
static func home_view() -> Vector3:
	return CameraRig.home_point()


## Game time (scaled by --speed) since the scene started.
func game_time() -> float:
	return _game_t


# ================================================================ build
## Graphics tier (GfxQuality: Settings GRAPHICS AUTO / HIGH / LOW). AUTO keeps
## the 0.3 rule (a phone with < 4.5 GB RAM is low tier); weak GPUs only count
## when GfxQuality.AUTO_WEAK_GPU is on (off, see there).
func _detect_tier() -> void:
	low_tier = GfxQuality.is_low()
	_apply_viewport_quality()


## Applies the GRAPHICS setting live (Settings): MSAA and 3D scale of the
## world view, the frame cap, sun shadows and DayNight's LOW light balance;
## Munshi-ji's bust follows when it next renders.
func apply_graphics() -> void:
	low_tier = GfxQuality.is_low()
	_apply_viewport_quality()
	if sun != null:
		sun.shadow_enabled = not low_tier
	if day_night != null:
		day_night.set_low(low_tier)
	print("[main3] graphics %s (low_tier=%s, max_fps=%d)" % [GfxQuality.mode(), low_tier, Engine.max_fps])


func _apply_viewport_quality() -> void:
	var vp: Viewport = get_viewport()
	var msaa: int = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", Viewport.MSAA_2X))
	vp.msaa_3d = Viewport.MSAA_DISABLED if low_tier else (msaa as Viewport.MSAA)
	var win: Vector2i = DisplayServer.window_get_size()
	vp.scaling_3d_scale = GfxQuality.scale_3d(low_tier, float(win.x) * float(win.y))
	# LOW: the 30 fps battery saver (GfxQuality.LOW_MAX_FPS).
	Engine.max_fps = GfxQuality.max_fps(low_tier)


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.60, 0.74, 0.50)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.96, 0.96, 0.94)
	# Tuned down 2026-10-19 after "looks very bright": the palette atlas already
	# carries the colour, so light should sit near 1.0 combined, not ~1.25.
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	# Same direction as the Blender review renders (SUN_TO_LIGHT_BL).
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, -45.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = not low_tier
	sun.shadow_opacity = 0.5
	sun.shadow_blur = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	add_child(sun)


func _add_name_board() -> void:
	var l := Label3D.new()
	l.name = "NameBoard"
	l.text = NAME_BOARD_TEXT
	l.font = load("res://ui/main_font.tres") as Font
	l.font_size = 96
	l.pixel_size = 0.0028
	l.outline_size = 14
	l.modulate = Color(1.0, 0.86, 0.32)
	l.outline_modulate = Color(0.35, 0.08, 0.06)
	l.position = NAME_BOARD_POS
	l.shaded = false
	l.double_sided = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(l)
	# C8.2: the Hindi line under it ("ढाबा · होटल"; NH 48 "राजस्थानी ढाबा ·
	# होटल"), same colours, fixed text (never translated).
	var h := Label3D.new()
	h.name = "NameBoardHi"
	h.text = _sign_hi
	h.font = l.font
	h.font_size = 96
	var px: float = NAME_BOARD_HI_CAP / (SIGN_CAP_EM * 96.0)
	if h.font != null:
		var w: float = h.font.get_string_size(_sign_hi, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
		if w > 0.0:
			px = minf(px, NAME_BOARD_HI_MAX_W / w)
	h.pixel_size = px
	h.outline_size = 14
	h.modulate = l.modulate
	h.outline_modulate = l.outline_modulate
	h.position = NAME_BOARD_HI_POS
	h.shaded = false
	h.double_sided = false
	h.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(h)


## Hindi + English text on ART's rooftop signboard (board only in dhaba_v3).
## The small English line (SIGN_EN_INDEX) is this scene's _sign_en (C8.2).
func _add_signboard() -> void:
	var font: Font = load("res://ui/main_font.tres") as Font
	for i in SIGN_TEXT.size():
		var e: Array = SIGN_TEXT[i]
		var text: String = _sign_en if i == SIGN_EN_INDEX else str(e[0])
		var l := Label3D.new()
		l.name = "Sign_" + str(get_child_count())
		l.text = text
		l.font = font
		l.font_size = SIGN_FONT_SIZE
		var cap: float = float(e[3])
		var px: float = cap / (SIGN_CAP_EM * float(SIGN_FONT_SIZE))
		if font != null:
			var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT_SIZE).x
			if w > 0.0:
				px = minf(px, float(e[2]) / w)
		l.pixel_size = px
		l.outline_size = 18
		l.modulate = e[4]
		l.outline_modulate = Color(0.24, 0.05, 0.06)
		l.position = e[1]
		l.shaded = false
		l.double_sided = false
		if i == SIGN_EN_INDEX:
			l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(l)


## C8.2 / C6.3 (plan 5.5, BI fixed text): [name board Hindi line, rooftop
## English small line] for this scene: Game.location_signs() (NH 48) when it
## has them, else the layout's lines (by name: W1-CORE's Game, rule 5).
func _sign_lines() -> Array:
	var signs: Dictionary = {}
	if Game.has_method("location_signs"):
		var v: Variant = Game.call("location_signs")
		if v is Dictionary:
			signs = v
	var hi: String = str(signs.get("sign_hi", ""))
	if hi == "":
		hi = NAME_BOARD_HI_TEXT
	var en: String = str(signs.get("sign_en", ""))
	if en == "":
		en = SIGN_EN_FAMILY if _layout_variant() == "family" else SIGN_EN_ROADSIDE
	return [hi, en]


## The layout this scene shows, resolved as Layout3 and the Sim do: "family"
## with a debug run's --layout=family, else Game.layout_variant() (W1-CORE,
## by name: "family" after the renovation), else "roadside".
func _layout_variant() -> String:
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("--layout=family"):
		return "family"
	if Game.has_method("layout_variant"):
		return str(Game.call("layout_variant"))
	return "roadside"


# ================================================================ promotions (core and feel C6.1 / C6.3)
## Production, every build: Game reset itself for a renovation or a move and
## saved (W1-CORE's _promote_reset). The old scene must not run another frame
## on the reset state, so it stops here and the whole scene reloads: the Sim,
## the world and the UI rebuild from Game's state, as for a loaded save.
func _on_promoted(kind: String, count: int) -> void:
	if _reloading:
		return
	_reloading = true
	_game_t_carry = _game_t
	print("[promo] %s %d: reloading scene" % [kind, count])
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if tree.current_scene != null:
		tree.current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	# UiRoot turns the root viewport's 3D off while STAFF / BUILD cover the
	# screen; the root Window survives the reload and the disabled old UiRoot
	# never turns it back on, so the new scene would draw no world.
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.disable_3d = false
	tree.reload_current_scene.call_deferred()


## Debug (--reno-ready, --renovate, --move, --promo-check): every counter
## built and at L100 (Game.debug_reno_ready, by name; cash untouched) and the
## plan 2.7 line. False when this build's Game lacks it.
func _reno_ready_now() -> bool:
	if not Game.has_method("debug_reno_ready"):
		print("[main3] reno-ready: SKIP (no Game.debug_reno_ready)")
		return false
	Game.call("debug_reno_ready")
	var rs: Dictionary = _game_dict("renovation_state")
	print("[promo] renovation ready: dishes %d/%d cost %.2f" % [int(rs.get("dishes", 0)),
			int(rs.get("dishes_total", 0)), float(rs.get("cost", 0.0))])
	return true


## Debug: the next promotion flag's step on this scene, once it is up (two
## frames: the Sim and the UI are in the tree). Game's promoted signal then
## reloads the scene and the next scene goes on. When the step cannot run
## (an API missing in this build, a refusal) this scene becomes the final one.
func _run_promo_step() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _promo_steps.is_empty():
		_promo_scene = false
		_start_debug_flags()
		return
	var step: String = str(_promo_steps.pop_front())
	var ok: bool = false
	if step == "renovate":
		if Game.has_method("renovate"):
			ok = bool(Game.call("renovate", true))
	elif step == "renovate_paid":
		ok = bool(Game.call("renovate", false))
		print("[main3] paid renovation: %s, job %s" % [str(ok), str(Game.call("build_job"))])
	elif step.begins_with("move:"):
		if Game.has_method("move_highway"):
			_reno_ready_now()
			ok = bool(Game.call("move_highway", step.substr(5), true))
	if ok and _reloading:
		return
	print("[main3] promotion flag %s: %s; this scene is the final one" % [step,
			"no reload" if ok else ("refused" if Game.has_method("renovate") else "SKIP (no promotion API in this build)")])
	_promo_steps.clear()
	_promo_scene = false
	_start_debug_flags()


## --promo-check (plan W1-HARNESS 5; with --fresh --skip-tutorial
## --money=1e12): phase 1 renovates (reload), phase 2 checks the family
## layout, builds it out, plays 60 s and moves to NH 48 (reload), phase 3
## checks NH 48. The phase and the fails live in statics across the reloads.
## A Game or Sim method this build lacks prints SKIP; then the check ends.
func _run_promo_check() -> void:
	await _game_wait(0.5)
	Game.debug_set_cash(maxf(Game.cash, 1.0e12))
	match _pc_phase:
		1:
			await _promo_check_1()
		2:
			await _promo_check_2()
		_:
			await _promo_check_3()


func _pc(phase: int, check: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_pc_fails += 1
	print("PROMOCHECK %d %s %s %s" % [phase, check, "ok" if ok else "FAIL", detail])


func _pc_skip(phase: int, check: String, why: String) -> void:
	print("PROMOCHECK %d %s SKIP %s" % [phase, check, why])


## The end of the check (this scene does not reload any more).
func _pc_end() -> void:
	print("PROMOCHECK fails=%d" % _pc_fails)
	get_tree().quit(_pc_fails)


## Game methods the check needs; SKIP lines for the missing ones.
func _pc_needs(phase: int, methods: Array) -> bool:
	var ok: bool = true
	for m in methods:
		if not Game.has_method(str(m)):
			_pc_skip(phase, str(m), "(no Game.%s in this build)" % str(m))
			ok = false
	return ok


func _promo_check_1() -> void:
	print("[promocheck] phase 1: renovation (scene 1)")
	if not _pc_needs(1, ["debug_reno_ready", "renovation_state", "renovate"]) or not Game.has_signal("promoted"):
		if not Game.has_signal("promoted"):
			_pc_skip(1, "promoted", "(no Game.promoted signal in this build)")
		_pc_end()
		return
	# (debug_reno_ready ran at parse time, before the world was built: a
	# counter built live here would still be mid-reveal at the reload.)
	var rs: Dictionary = _game_dict("renovation_state")
	_pc(1, "reno_unlocked", bool(rs.get("unlocked", false)), "dishes %s/%s cost %s" % [rs.get("dishes"), rs.get("dishes_total"), rs.get("cost")])
	var cash0: float = Game.cash
	_pc_phase = 2
	var ok: bool = bool(Game.call("renovate"))
	_pc(1, "renovate", ok, "cash %.2f -> %.2f" % [cash0, Game.cash])
	_pc(1, "reload", ok and _reloading, "promoted -> scene reload" if _reloading else "no reload")
	if not (ok and _reloading):
		_pc_end()


func _promo_check_2() -> void:
	print("[promocheck] phase 2: family layout (scene 2, after the reload)")
	await _game_wait(0.5)
	_pc(2, "waiters_1", Game.waiter_count() == 1, "waiters %d" % Game.waiter_count())
	_pc(2, "gallas_1", Game.galla_count() == 1, "gallas %d" % Game.galla_count())
	_pc(2, "tables_3", Game.table_count() == 3, "tables %d" % Game.table_count())
	var dl: PackedStringArray = PackedStringArray()
	var dish_ok: bool = true
	for id: String in Game.station_ids():
		var n: int = Game.dishes_unlocked(id)
		dl.append("%s %d" % [id, n])
		if n != 4:
			dish_ok = false
	_pc(2, "dishes_4", dish_ok, ", ".join(dl))
	if _pc_needs(2, ["fame_mult"]):
		var fm: float = float(Game.call("fame_mult"))
		_pc(2, "fame_mult_2", absf(fm - 2.0) < 0.0001, "%.2f" % fm)
	_pc(2, "layout_family", _layout_variant() == "family", _layout_variant())
	_pc(2, "seats_12", sim.seats_total() == 12, "seats %d" % sim.seats_total())
	_pc(2, "rooftop_family", _sign_en == SIGN_EN_FAMILY, "'%s'" % _sign_en)
	for k in 5:
		Game.buy_table()
	await _game_wait(1.0)
	_pc(2, "tables_8_seats_32", Game.table_count() == 8 and sim.seats_total() == 32,
			"tables %d seats %d" % [Game.table_count(), sim.seats_total()])
	for k in 3:
		Game.buy_waiter_hire()
	await _game_wait(1.0)
	_pc(2, "waiters_4", Game.waiter_count() == 4, "waiters %d" % Game.waiter_count())
	var t0: float = _game_t
	await _game_wait(60.0)
	if sim.has_method("hall_seated_total"):
		var hs: int = int(sim.call("hall_seated_total"))
		var st: int = int(sim.call("seated_total_scene")) if sim.has_method("seated_total_scene") else -1
		_pc(2, "hall_seated", hs >= 1, "hall seated %d of %d in %.0f s" % [hs, st, _game_t - t0])
	else:
		_pc_skip(2, "hall_seated", "(no Sim.hall_seated_total in this build)")
	if not _pc_needs(2, ["move_highway"]):
		_pc_end()
		return
	_reno_ready_now()
	var cash0: float = Game.cash
	_pc_phase = 3
	var ok: bool = bool(Game.call("move_highway", "nh48"))
	_pc(2, "move_nh48", ok, "cash %.2f -> %.2f" % [cash0, Game.cash])
	_pc(2, "reload", ok and _reloading, "promoted -> scene reload" if _reloading else "no reload")
	if not (ok and _reloading):
		_pc_end()


func _promo_check_3() -> void:
	print("[promocheck] phase 3: NH 48 (scene 3, after the reload)")
	await _game_wait(0.5)
	if _pc_needs(3, ["location_id"]):
		_pc(3, "location_nh48", str(Game.call("location_id")) == "nh48", str(Game.call("location_id")))
	if _pc_needs(3, ["fame_mult"]):
		var fm: float = float(Game.call("fame_mult"))
		_pc(3, "fame_mult_3", absf(fm - 3.0) < 0.0001, "%.2f" % fm)
	var built: Array[String] = Game.built_station_ids()
	_pc(3, "only_chai_built", built.size() == 1 and built[0] == "chai", str(built))
	var dishes: Array[String] = Game.dish_ids("chai")
	_pc(3, "chai_masala_chai", not dishes.is_empty() and dishes[0] == "chai.masala_chai", str(dishes))
	_pc(3, "rooftop_rajasthani", _sign_en == "RAJASTHANI DHABA", "'%s'" % _sign_en)
	_pc(3, "gate_board_hindi", _sign_hi == "राजस्थानी ढाबा · होटल", "'%s'" % _sign_hi)
	_pc(3, "layout_family", _layout_variant() == "family", _layout_variant())
	_pc_end()


## A Game method returning a Dictionary, by name ({} when missing).
func _game_dict(m: String, args: Array = []) -> Dictionary:
	if not Game.has_method(m):
		return {}
	var v: Variant = Game.callv(m, args)
	if v is Dictionary:
		return v
	return {}


# ================================================================ debug flags
## Every scene parses the flags again (a promotion reloads it); --fresh,
## --skip-tutorial, --money, --reno-ready and the promotion steps are applied
## only on the first scene of the process (static _once_done).
func _parse_cmdline() -> void:
	if not OS.is_debug_build():
		return
	var first: bool = not _once_done
	var money: float = -1.0
	var reno_ready: bool = false
	var steps: Array = []
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--fresh":
			if first:
				Game.wipe_save()
		elif arg == "--reno-ready":
			reno_ready = true
		elif arg == "--renovate":
			reno_ready = true
			if not steps.has("renovate"):
				steps.push_front("renovate")
		elif arg == "--renovate-paid":
			# Dhaba growth step 3: a paid (timed) renovation, as the BUILD button
			# starts it (give cash with --money).
			reno_ready = true
			steps.append("renovate_paid")
		elif arg.begins_with("--move="):
			reno_ready = true
			if not steps.has("renovate"):
				steps.push_front("renovate")
			steps.append("move:" + arg.get_slice("=", 1))
		elif arg.begins_with("--signboard="):
			_signboard_n = maxi(0, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--claims="):
			_claims_n = maxi(0, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--sessions="):
			_sessions_n = maxi(0, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--special="):
			_special_arg = arg.get_slice("=", 1)
		elif arg.begins_with("--phone="):
			_phone_arg = arg.get_slice("=", 1)
		elif arg.begins_with("--visit="):
			FatherVisits.debug_visit = clampi(int(arg.get_slice("=", 1)), 1, 3)
		elif arg.begins_with("--event="):
			_event_mode = arg.get_slice("=", 1)
		elif arg.begins_with("--event-guests="):
			_event_guests = maxi(0, int(arg.get_slice("=", 1)))
		elif arg == "--event-claim":
			_event_claim = true
		elif arg == "--fx-log":
			_fx_log = true
		elif arg == "--promo-check":
			_promo_check = true
			MunshiNotes.enabled = false
		elif arg == "--skip-tutorial":
			_skip_tutorial = true
		elif arg.begins_with("--money="):
			money = float(arg.get_slice("=", 1))
		elif arg.begins_with("--speed="):
			Engine.time_scale = maxf(0.05, float(arg.get_slice("=", 1)))
		elif arg == "--auto":
			_auto = true
		elif arg.begins_with("--shots="):
			for s: String in arg.get_slice("=", 1).split(",", false):
				_shots.append(float(s))
			_shots.sort()
		elif arg.begins_with("--shot-dir="):
			_shot_dir = arg.substr(11)
		elif arg.begins_with("--quit-at="):
			_quit_at = float(arg.get_slice("=", 1))
		elif arg.begins_with("--open="):
			_open_at_start = arg.get_slice("=", 1)
		elif arg.begins_with("--stats="):
			_stats_every = maxf(0.5, float(arg.get_slice("=", 1)))
		elif arg.begins_with("--buy="):
			_buy = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--capture="):
			_capture = arg.get_slice("=", 1)
		elif arg == "--check-pack":
			_check_pack = true
		elif arg.begins_with("--seed="):
			Sim.debug_seed = maxi(0, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--arrivals="):
			_arrivals_force = float(arg.get_slice("=", 1))
		elif arg.begins_with("--window="):
			_window = maxf(1.0, float(arg.get_slice("=", 1)))
		elif arg == "--no-notes":
			MunshiNotes.enabled = false
		elif arg == "--tap-check":
			_tap_check = true
			MunshiNotes.enabled = false
		elif arg.begins_with("--time="):
			_time_force = fposmod(float(arg.get_slice("=", 1)), 1.0)
		elif arg == "--zoom-test":
			_zoom_test = true
			MunshiNotes.enabled = false
		elif arg.begins_with("--tap-zoom="):
			_tap_zoom = arg.get_slice("=", 1)
	if _capture != "" and _capture != "menu":
		MunshiNotes.enabled = false
	if not first:
		# A promotion reloaded the scene: the run goes on with the next step.
		# Game time carries over, so shots already taken are dropped.
		while not _shots.is_empty() and _shots[0] <= _game_t:
			_shots.pop_front()
		_promo_scene = not _promo_steps.is_empty()
		if _final_done:
			# Plan 2.7: a reload never re-applies --buy (nor --open and the
			# game-state flags); --event-claim re-hooks this scene, and the
			# measures (--arrivals, --stats, --window, --quit-at) and
			# --promo-check's later phases go on.
			var had: bool = not _buy.is_empty() or _open_at_start != "" or _signboard_n >= 0 \
					or _claims_n >= 0 or _sessions_n >= 0 or _special_arg != "" or _event_mode != "" \
					or _event_guests >= 0 or _phone_arg != ""
			_buy = PackedStringArray()
			_open_at_start = ""
			_signboard_n = -1
			_claims_n = -1
			_sessions_n = -1
			_special_arg = ""
			_phone_arg = ""
			_event_mode = ""
			_event_guests = -1
			if had:
				print("[main3] reload: one-shot flags not re-applied")
		return
	_once_done = true
	# Step 4: tests that skip the tutorial expect today's dhaba (a new game
	# now starts on the cart); --stage= still picks the stage.
	if _skip_tutorial and Game.stage() < Game.STAGE_DHABA and int(Game.get("_debug_stage")) < 0:
		Game.set_stage(Game.STAGE_DHABA)
	if _skip_tutorial and not Game.is_tutorial_done():
		Game.tutorial_set("step", "done")
		Game.tutorial_set("done", true)
		Game.hud_reveal = Game.HUD_FULL
		Game.enable_ad_bubbles(true)
	if money >= 0.0:
		Game.cash = money
	# Core and feel promotion flags: every counter at L100 before the world
	# is built (so no counter is revealed live), then (deferred, once the
	# scene is up) renovate / move. --promo-check's phase 1 likewise.
	if reno_ready or (_promo_check and _pc_phase == 1):
		_reno_ready_now()
	_promo_steps = steps
	_promo_scene = not _promo_steps.is_empty()


func _debug_open(what: String) -> void:
	await get_tree().create_timer(0.5).timeout
	match what:
		"staff":
			ui.open_staff()
		"galla", "cashiers":
			ui.open_galla()
		"daftar", "build":
			ui.open_daftar("build")
		"hisaab", "stats":
			ui.open_daftar("hisaab")
		"vip":
			# C7.4: which offer this open shows (W1-MONEY's UiRoot marks it shown).
			print("[offer] variant %s" % _offer_variant())
			ui.open_vip(100.0)
		"settings":
			ui.open_settings()
		"phone":
			ui.open_phone()
		"menu":
			ui.open_menu()
		"waiters":
			ui.open_waiters()
		"seating", "tables":
			print("[main3] --open=%s -> %s" % [what, ui.open_tables("debug")])
		_:
			if what.begins_with("staff:"):
				ui.open_staff(what.substr(6))
			elif what.begins_with("quick:"):
				ui.open_quick(what.substr(6))
			else:
				ui.open_station(what)


## C7.4: Game.offer_variant() (W1-CORE, by name), else the 0.3.7 rule.
func _offer_variant() -> String:
	if Game.has_method("offer_variant"):
		return str(Game.call("offer_variant"))
	return "vip" if Game.vip_offer_visible() else "free"


## The final scene's --buy, game-state flags and --open, in the plan 2.7
## order (each waits for the one before it).
func _debug_sequence() -> void:
	if not _buy.is_empty():
		await _debug_buy()
	_apply_state_flags()
	if _open_at_start != "":
		await _debug_open(_open_at_start)


func _has_state_flags() -> bool:
	return _signboard_n >= 0 or _claims_n >= 0 or _sessions_n >= 0 or _special_arg != "" \
			or _event_mode != "" or _event_guests >= 0 or _event_claim or _phone_arg != ""


## --signboard, --claims, --sessions, --special, --event, --event-guests,
## --event-claim (plan 2.7), each through Game by name (W1-CORE; SKIP when
## this build's Game lacks the method).
func _apply_state_flags() -> void:
	if _signboard_n >= 0:
		if _game_has("debug_set_signboard", "--signboard"):
			Game.call("debug_set_signboard", _signboard_n)
			var lv: int = int(Game.call("signboard_level")) if Game.has_method("signboard_level") else _signboard_n
			print("[game] signboard %d cap %.1f" % [lv, _ramp_cap_formula()])
	if _claims_n >= 0 and _game_has("debug_set_claims", "--claims"):
		Game.call("debug_set_claims", _claims_n)
		print("[main3] --claims=%d (claims_total %d)" % [_claims_n, Game.claims_total])
	if _sessions_n >= 0 and _game_has("debug_set_sessions", "--sessions"):
		Game.call("debug_set_sessions", _sessions_n)
		print("[main3] --sessions=%d (sessions %d)" % [_sessions_n, Game.sessions])
	if _special_arg != "":
		match _special_arg:
			"auto":
				print("[main3] --special=auto: the special follows its real rules this run")
			"none":
				print("[main3] --special=none: no special this run")
			_:
				if _game_has("debug_set_special", "--special"):
					var ok: bool = bool(Game.call("debug_set_special", _special_arg))
					print("[main3] --special=%s -> %s" % [_special_arg, ok])
	if _phone_arg != "" and _game_has("debug_phone", "--phone"):
		for id: String in _phone_arg.split(",", false):
			print("[main3] --phone=%s -> %s" % [id, bool(Game.call("debug_phone", id))])
	if _event_mode != "" and _game_has("debug_event", "--event"):
		Game.call("debug_event", _event_mode)
	if _event_guests >= 0 and _game_has("debug_event_served", "--event-guests"):
		Game.call("debug_event_served", _event_guests)
	if _event_claim:
		if Game.has_signal("event_changed") and Game.has_method("claim_event_step"):
			Game.connect("event_changed", _on_event_changed_claim)
			_event_claim_pass()
		else:
			print("[main3] --event-claim: SKIP (no Game.event_changed / claim_event_step)")


## True when Game has `m`; else prints the flag's SKIP line (plan: every new
## flag parses on a Game without the API and says so).
func _game_has(m: String, flag: String) -> bool:
	if Game.has_method(m):
		return true
	print("[main3] %s: SKIP (no Game.%s)" % [flag, m])
	return false


## The Sim's arrival ramp cap: traffic ramp_max_tpm (19.5) + the signboard's
## travellers/min (C5.3, 1.5 a level; 0 in the tutorial).
func _ramp_cap_formula() -> float:
	var hi: float = float(Game.traffic_value("ramp_max_tpm", 19.5))
	if Game.has_method("signboard_bonus_tpm"):
		hi += float(Game.call("signboard_bonus_tpm"))
	return hi


## --event-claim: Game's event_changed (also emitted by a claim) -> one
## deferred pass over the goal steps.
func _on_event_changed_claim() -> void:
	_event_claim_pass.call_deferred()


func _event_claim_pass() -> void:
	var st: Dictionary = _game_dict("event_state")
	var steps: Array = st.get("steps", [])
	for i in steps.size():
		var s: Variant = steps[i]
		if s is Dictionary and bool((s as Dictionary).get("done", false)) and not bool((s as Dictionary).get("claimed", false)):
			Game.call("claim_event_step", i)


func _on_reward_seen(amount: float, _source: String = "") -> void:
	_rewards_seen += amount


func _debug_buy() -> void:
	await _game_wait(0.5)
	for b: String in _buy:
		var ok: bool = false
		match b:
			"galla":
				ok = Game.buy_galla_hire()
			"waiter":
				ok = Game.buy_waiter_hire()
			"table":
				ok = Game.buy_table()
			"waiter_up":
				ok = Game.buy_waiter_upgrade(0)
			"galla_up":
				ok = Game.buy_galla_upgrade(0)
			"grow":
				# Growth step 3: starts the next stage's paid build.
				ok = Game.start_growth_build()
			_:
				if b.begins_with("waiter_lvl") and b.substr(10).is_valid_int():
					ok = _debug_waiter_levels(int(b.substr(10)))
				else:
					ok = _debug_buy_station(b)
		print("[main3] buy %s -> %s (cash %.2f)" % [b, ok, Game.cash])


## --buy=waiter_lvl<N> (C3.4): every waiter to level N (Game, by name), then
## each waiter's tray size.
func _debug_waiter_levels(level: int) -> bool:
	if not _game_has("debug_set_waiter_levels", "--buy=waiter_lvl%d" % level):
		return false
	Game.call("debug_set_waiter_levels", level)
	for i in Game.waiter_count():
		var k: int = int(Game.call("waiter_tray_orders", i)) if Game.has_method("waiter_tray_orders") else 1
		print("[game] waiter tray %d orders %d" % [i, k])
	return true


## --buy station keys: "<id>" builds it, "<id>_up" levels it, "<id>_hire"
## hires a cook, "<id>_speed" buys a processing step, "<id>_lvl<N>" sets the
## level outright (Game.debug_set_level; station menus).
func _debug_buy_station(b: String) -> bool:
	if not Game.station_def(b).is_empty():
		return Game.build(b)
	var li: int = b.rfind("_lvl")
	if li > 0 and b.substr(li + 4).is_valid_int():
		var sid: String = b.substr(0, li)
		if Game.station_def(sid).is_empty() or not Game.is_built(sid):
			return false
		Game.debug_set_level(sid, int(b.substr(li + 4)))
		return true
	for suffix in ["_up", "_hire", "_speed"]:
		var sfx: String = suffix
		if b.ends_with(sfx):
			var id: String = b.trim_suffix(sfx)
			if Game.station_def(id).is_empty():
				return false
			match sfx:
				"_up":
					return Game.buy_level(id)
				"_hire":
					return Game.buy_hire(id)
				"_speed":
					return Game.buy_processing(id)
	print("[main3] buy: unknown key '%s'" % b)
	return false


## Waits `sec` of game time (follows --speed).
## The billboard puff material (traffic exhaust / dust, the kadai
## steam) compiles its shader the first time a puff is drawn: a one-off
## 120-290 ms frame mid-play, e.g. when the annex first comes on screen (QA
## round 1, windowed probe). Draw one invisible puff (same material flags =
## the same shader) in front of the camera for the first half second
## instead, inside the start-up load (that annex frame: 118 ms -> 7-8 ms).
## Rendering only: the simulation never sees it.
func _prewarm_puff_shader() -> void:
	if camera_rig == null or camera_rig.camera == null or DisplayServer.get_name() == "headless":
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = FxTex.glow()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mi := MeshInstance3D.new()
	mi.name = "PuffShaderWarm"
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, 0.0, -(camera_rig.camera.near + 1.0))
	camera_rig.camera.add_child(mi)
	get_tree().create_timer(0.5, true).timeout.connect(mi.queue_free)


func _game_wait(sec: float) -> void:
	var until: float = _game_t + sec
	while _game_t < until:
		await get_tree().process_frame


## Free-play review shots (--capture=free). Each beat waits for its moment
## (with a timeout) and saves <shot-dir>/free_<label>.png.
func _free_capture() -> void:
	DirAccess.make_dir_recursive_absolute(_globalize(_shot_dir))
	await _game_wait(1.0)
	if Game.galla_count() < 2:
		Game.buy_galla_hire()
	if _capture == "lorry":
		await _capture_lorries()
		get_tree().quit()
		return
	# 1. Travellers seated, Raju carrying a kulhad, both gallas billing (a
	# view a little left of the home view so Bablu is in frame too).
	camera_rig.fly_to(Vector3(2.2, 0.0, 4.6), CameraRig.GAME)
	var t0: float = _game_t
	while _game_t - t0 < 60.0:
		var w: Waiter = sim.get_waiter(0)
		var carrying: bool = w != null and w.state == Waiter.W.TO_TABLE
		var busy: int = 0
		for g in sim.gallas:
			if g.is_busy():
				busy += 1
		if carrying and busy >= 2 and sim.seats_in_use() >= 4:
			break
		await get_tree().process_frame
	await _named_shot("home")
	# 2. The ghost table (next set) with its price tag.
	camera_rig.fly_to(Layout3.table_pos(sim.tables_built) + Vector3(-1.2, 0.0, 1.6), CameraRig.GAME)
	await _game_wait(2.0)
	await _named_shot("ghost_table")
	# 3. Tables (the ghost table's 2-tap card here, the SEATING panel is
	# retired) and STAFF › WAITERS.
	ui.open_tables("capture")
	await _game_wait(1.2)
	await _named_shot("tables_card")
	ui.close_all()
	await _game_wait(0.6)
	ui.open_staff("waiters")
	await _game_wait(1.2)
	await _named_shot("staff_panel")
	ui.close_all()
	await _game_wait(0.6)
	# 4. Exterior views (intro zoom).
	var views: Array = [
		["exterior_front", Vector3(3.0, 0.0, 10.6), CameraRig.INTRO],
		["exterior_west", Vector3(-3.2, 0.0, 6.5), CameraRig.INTRO],
		["exterior_courtyard", Vector3(12.0, 0.0, 4.0), CameraRig.INTRO],
		["exterior_roof", Vector3(4.5, 0.0, 1.2), CameraRig.INTRO],
		["truck_parking", Vector3(3.6, 0.0, 20.0), CameraRig.INTRO],
	]
	for v in views:
		var e: Array = v
		camera_rig.fly_to(e[1], float(e[2]))
		await _game_wait(1.6)
		await _named_shot(str(e[0]))
	if OS.get_cmdline_user_args().has("--puff-test"):
		sim.traffic.debug_puffs(Vector3(3.6, 0.5, 19.0))
		await _game_wait(0.3)
		await _named_shot("puff_test")
	await _capture_lorries()
	print("[main3] free capture done at %.2f" % _game_t)
	if _quit_at < 0.0:
		get_tree().quit()


## WHOLE-ORDER review shot (--capture=tray; use with --skip-tutorial
## --money=N --buy=tandoor --shot-dir=DIR): the camera follows Raju close up
## and saves DIR/waiter_whole_order.png while he carries a kulhad and a roti
## plate together on his tray, walking toward the camera (tray in view), then
## DIR/waiter_whole_order_serve.png as the items hop onto the table; quits.
func _tray_capture() -> void:
	DirAccess.make_dir_recursive_absolute(_globalize(_shot_dir))
	await _game_wait(0.5)
	var w: Waiter = sim.get_waiter(0)
	if w == null:
		print("[main3] tray capture: no waiter")
		get_tree().quit()
		return
	camera_rig.follow(w, 0.6)
	camera_rig.zoom_to(0.42, 0.3)
	var t0: float = _game_t
	var prev: Vector3 = w.position
	var shot: bool = false
	var since: float = -1.0
	while _game_t - t0 < 240.0 and not shot:
		await get_tree().process_frame
		var d: Vector3 = w.position - prev
		prev = w.position
		var loaded: bool = w.state == Waiter.W.TO_TABLE and w.carried_count() >= 2
		# The camera looks toward -X -Z: walking toward +X +Z shows the tray.
		if loaded and d.x + d.z > 0.001:
			if since < 0.0:
				since = _game_t
			if _game_t - since >= 0.35:
				await _named_shot("whole_order", "waiter")
				shot = true
		else:
			since = -1.0
	if not shot:
		print("[main3] tray capture: no loaded walk toward the camera seen")
		get_tree().quit()
		return
	var t1: float = _game_t
	while _game_t - t1 < 15.0 and w.state != Waiter.W.SERVING:
		await get_tree().process_frame
	await _game_wait(0.2)
	await _named_shot("whole_order_serve", "waiter")
	print("[main3] tray capture done at %.2f" % _game_t)
	get_tree().quit()


## A lorry reversing into a bay, then one leaving: honk + exhaust puff,
## pull-out. The camera follows the vehicle (intro zoom) and shoots
## mid-manoeuvre.
func _capture_lorries() -> void:
	camera_rig.zoom_to(CameraRig.INTRO, 0.3)
	for want in [["REVERSE", "lorry_in", [1.2, 2.2]], ["LEAVING", "lorry_out", [0.3]]]:
		var a: Array = want
		var t1: float = _game_t
		var node: Node3D = null
		while _game_t - t1 < 150.0:
			node = sim.traffic.find_phase_node(str(a[0]))
			if node != null:
				break
			await get_tree().process_frame
		if node == null:
			print("[main3] capture: no %s seen" % a[0])
			continue
		camera_rig.follow(node, 0.0)
		var t2: float = _game_t
		var times: Array = a[2]
		var k: int = 0
		while k < times.size():
			if _game_t - t2 >= float(times[k]):
				await _named_shot("%s_%d" % [a[1], k + 1])
				k += 1
			else:
				await get_tree().process_frame
		if str(a[0]) == "LEAVING":
			# ...then the pull-out itself (after it found a gap).
			var t3: float = _game_t
			while _game_t - t3 < 25.0 and sim.traffic.phase_of(node) != "PULL_OUT":
				await get_tree().process_frame
			var t4: float = _game_t
			for dt in [0.4, 1.3, 2.4]:
				while _game_t - t4 < float(dt):
					await get_tree().process_frame
				await _named_shot("lorry_out_pull_%.1f" % float(dt))
	camera_rig.set_free()


## BUS STOP review shots (--capture=bus) -> <shot-dir>/bus_<label>.png: a bus
## pulling in (indicator), its riders stepping off toward the crossing, the
## waiting line under the shelter, a bus taking the line aboard, and the bus
## pulling away (honk + exhaust). Each beat waits for its moment (timeouts).
func _bus_capture() -> void:
	DirAccess.make_dir_recursive_absolute(_globalize(_shot_dir))
	await _game_wait(0.5)
	if Game.galla_count() < 2:
		Game.buy_galla_hire()
	camera_rig.fly_to(Layout3.BUS_STOP_VIEW, 1.15)
	# 1) The first bus: pulling in, then its riders stepping off.
	if await _wait_for(func() -> bool: return sim.traffic.bus_phase() == "BUS_APPROACH", 90.0):
		await _wait_for(func() -> bool: return _bus_to_stop() < 2.2, 15.0)
		await _named_shot("arrive", "bus")
		if await _wait_for(func() -> bool: return sim.bus_boarding(), 20.0):
			await _game_wait(0.8)
			await _named_shot("drop", "bus")
			await _game_wait(0.8)
			await _named_shot("drop_2", "bus")
	# 2) The waiting line under the shelter (no bus at the stop).
	await _wait_for(func() -> bool: return sim.bus_line.size() >= 4 and not sim.bus_boarding(), 180.0)
	await _game_wait(0.6)
	await _named_shot("queue", "bus")
	# 3) A bus picking the line up: the head of the line climbing aboard.
	if await _wait_for(func() -> bool: return sim.bus_boarding() and sim.bus_line.size() >= 2, 120.0):
		await _named_shot("pickup_door", "bus")
		await _wait_for(func() -> bool: return sim.bus_boarding_count() > 0, 15.0)
		await _game_wait(0.12)
		await _named_shot("board", "bus")
		await _game_wait(0.5)
		await _named_shot("board_2", "bus")
		# 4) All aboard: honk, exhaust puff, pulling away.
		if await _wait_for(func() -> bool: return sim.traffic.bus_phase() == "BUS_GO", 30.0):
			var bn: Node3D = sim.traffic.bus_node()
			await _game_wait(0.2)
			await _named_shot("leave", "bus")
			await _game_wait(0.8)
			await _named_shot("leave_2", "bus")
			# 5) The same bus at the zebra crossing: it gives way / holds it
			# while people wait at the kerb (2026-10-20 fix).
			if bn != null:
				camera_rig.fly_to(Vector3(5.2, 0.0, 13.2), 1.15)
				var near_xing := func() -> bool:
					return bn.visible and sim.traffic.phase_of(bn) != "" \
							and bn.position.x - 3.45 < Layout3.CROSSING_X.y + 1.2
				if await _wait_for(near_xing, 25.0):
					await _named_shot("xing", "bus")
					_xing_debug(bn)
					await _game_wait(0.9)
					await _named_shot("xing_2", "bus")
					_xing_debug(bn)
	print("[main3] bus capture done at %.2f" % _game_t)
	if _quit_at < 0.0:
		get_tree().quit()


## --capture=bus: where the bus and the people on the crossing are (log).
func _xing_debug(bn: Node3D) -> void:
	var s: String = "[main3] crossing: bus %s at x %.2f z %.2f |" % [sim.traffic.phase_of(bn), bn.position.x, bn.position.z]
	for t in sim.travellers:
		if is_instance_valid(t) and t.position.x > 1.5 and t.position.x < 6.5 and t.position.z > 9.5 and t.position.z < 17.0:
			s += " %s %.2f,%.2f dz %.1f%s" % [Traveller.S.keys()[t.state], t.position.x, t.position.z, t.walk_direction().z, " (kerb)" if t.kerb_wait else ""]
	print(s)


## Metres the stop bus still has to go to its stop point (INF if none).
func _bus_to_stop() -> float:
	var n: Node3D = sim.traffic.bus_node()
	if n == null:
		return INF
	return n.position.x - Layout3.BUS_STOP_X


## Waits (game time) until `cond` is true or `timeout` s passed; returns cond.
func _wait_for(cond: Callable, timeout: float) -> bool:
	var t0: float = _game_t
	while not bool(cond.call()):
		if _game_t - t0 >= timeout:
			print("[main3] capture: timed out after %.0f s" % timeout)
			return false
		await get_tree().process_frame
	return true


func _named_shot(label: String, prefix: String = "free") -> void:
	if DisplayServer.get_name() == "headless":
		# No frame is ever drawn: a capture run still walks its beats (and
		# prints its logic) without waiting on a frame that never comes.
		print("[main3] shot %s skipped (headless)" % label)
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("[main3] shot %s skipped (no rendering)" % label)
		return
	var path: String = _globalize(_shot_dir).path_join("%s_%s.png" % [prefix, label])
	var err: Error = img.save_png(path)
	print("[main3] shot %s (game %.2f) -> %s %s" % [label, _game_t, path, "" if err == OK else "FAILED %d" % err])


## --stats: one line of sim state (debug only; walks the tree, so not per frame).
func _print_stats() -> void:
	var ws: String = ""
	for w in sim.waiters:
		ws += "%s:%d " % [w.staff_name, w.state]
	var chai: StationNode = sim.get_station("chai")
	var timers: int = 0
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is RadialTimer:
			timers += 1
		for c in n.get_children():
			stack.append(c)
	var gl: String = ""
	for g in sim.gallas:
		gl += "%d " % g.line_count()
	var cap: Dictionary = sim.capacity_estimate()
	print("[stats] %.1f cash %.2f sales %d trav %d inside %d seats %d/%d door %d lost %d park %.2f | chai q %d pass %d | gallas %s| waiters %s| served %d foodwait %.1f | nodes %d timers %d step %s%s" % [
		_game_t, Game.cash, sim.sales_count, sim.travellers.size(), sim.travellers_inside(),
		sim.seats_in_use(), sim.seats_total(), sim.seats_waiting(), Game.lost_session, sim.parking_usage(),
		chai.queue_length() if chai != null else -1, chai.pass_used() if chai != null else -1,
		gl, ws, Game.served_total, float(Game.stats().get("avg_food_wait", -1.0)),
		get_tree().get_node_count(), timers, director.current_step(), _stats_core_feel(cap)])
	var vp: Viewport = get_viewport()
	print("[stats]    draw calls: canvas %d, 3d %d | fps %.0f" % [
		vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.TIME_FPS)])
	if sim.traffic != null:
		print("[stats]    bays %s" % sim.traffic.debug_bays())
		print("[stats]    bus %s | line %d (oldest %.1f s, max %d / %.1f s) boarded %d" % [sim.traffic.debug_bus(),
				sim.bus_line.size(), sim.bus_wait_oldest(), _busq_max, _busq_wait_max, sim.boarded_total])
		if OS.get_cmdline_user_args().has("--traffic-debug"):
			print("[stats]    cars %s" % sim.traffic.debug_active())
			print("[stats]    %s" % _overlap_line())
	print("[stats]    ramp %.1f/min (raw %.1f, lorries measured %.1f) bus every %.0f s | capacity seats %.1f waiters %.1f stations %.1f gallas %.1f (items %.2f, expected waiter order trip %.2f s, chai %.1f s chai+tandoor %.1f s) | backlog %.1f s damp %.2f" % [
			sim.arrivals_target, sim.arrivals_raw, sim.lorry_supply(),
			minf(9999.0, sim.bus_interval()), float(cap["seats"]), float(cap["waiters"]), float(cap["stations"]),
			float(cap["gallas"]), float(cap["items"]), float(cap["order_trip"]), sim.waiter_trip_s("chai"), sim.waiter_trip_s("chai+tandoor"),
			float(cap["backlog_s"]), float(cap["damp"])])
	# Menu expansion: measured trips per order key, demand shares, stations.
	var trips: String = ""
	for k in sim._trip_s.keys():
		trips += "%s %.2f s, " % [str(k), float(sim._trip_s[k])]
	var shares: String = ""
	var shd: Dictionary = cap.get("shares", {})
	for k in shd.keys():
		shares += "%s %.1f%% " % [str(k), 100.0 * float(shd[k])]
	print("[stats]    order trips (measured): %s| shares: %s" % [trips if trips != "" else "- ", shares])
	var sts: String = ""
	for id: String in Game.built_station_ids():
		var st: StationNode = sim.get_station(id)
		if st == null:
			continue
		var busy: int = 0
		for v in st.slots:
			if (v as StationNode.Slot).ticket != null:
				busy += 1
		sts += "%s q %d cooking %d/%d pass %d/%d cooked %d dishes %d props %d%s | " % [id, st.queue_length(), busy, st.slots.size(),
				st.pass_used(), st.pass_items.size(), st.cooked_count, Game.dishes_unlocked(id), st.unlock_prop_count(),
				" (reveal pending)" if st.reveal_pending else ""]
	print("[stats]    stations: %s" % sts)
	var arr: int = sim.arrivals_lorry + sim.arrivals_bus
	var span: float = maxf(0.001, sim.sim_clock - _arr_last_t)
	print("[stats]    arrivals %d (lorry %d, bus %d, %d buses) | last %.0f s: %.1f/min | run: %.1f/min | account %.1f (called %.1f, dropped at cap %.1f)" % [
		arr, sim.arrivals_lorry, sim.arrivals_bus, sim.buses_stopped, span,
		float(arr - _arr_last) * 60.0 / span, float(arr) * 60.0 / maxf(0.001, sim.sim_clock), sim.debug_credit(), sim.debug_inflight(), sim.debug_credit_lost])
	_arr_last = arr
	_arr_last_t = sim.sim_clock
	print("[stats]    %s" % _daynight_line())


## --window: snapshot when the tutorial is done (or at once), then one
## [window] line SEC sim seconds later.
func _tick_window() -> void:
	if _win_t0 < 0.0:
		if not Game.is_tutorial_done():
			return
		_win_t0 = sim.sim_clock
		_win_arr0 = sim.arrivals_lorry + sim.arrivals_bus
		_win_lost0 = Game.lost_session
		_win_fw_sum0 = sim.food_wait_sum
		_win_fw_n0 = sim.food_wait_n
		_win_buses0 = sim.buses_stopped
		_win_bus_riders0 = sim.arrivals_bus
		_win_passed0 = _game_int("passed_session")
		_win_life0 = Game.lifetime_earned
		_win_reward0 = _rewards_seen
		_win_event0 = int(_game_dict("event_state").get("served", 0))
		sim.food_wait_max = 0.0
		print("[window] start at game %.1f s (sim %.1f s): waiters %d, tables %d, gallas %d, stations %s, ramp %.1f/min" % [
				_game_t, sim.sim_clock, Game.waiter_count(), Game.table_count(), Game.galla_count(),
				str(Game.built_station_ids()), sim.arrivals_target])
		return
	var span: float = sim.sim_clock - _win_t0
	if span < _window:
		return
	_win_done = true
	var arr: int = sim.arrivals_lorry + sim.arrivals_bus - _win_arr0
	var fn: int = sim.food_wait_n - _win_fw_n0
	# Core and feel (plan 2.7): travellers who drove past (C2.1), takings =
	# sales only (lifetime earnings minus rewards) per minute, and the baraat
	# guests while the event is on (C6.4).
	var passed: String = ("%d" % (_game_int("passed_session") - _win_passed0)) if "passed_session" in Game else "-"
	var takings: float = (Game.lifetime_earned - _win_life0 - (_rewards_seen - _win_reward0)) * 60.0 / span
	var ev: String = ""
	if Game.has_method("event_active") and bool(Game.call("event_active")):
		ev = "event guests %d | " % maxi(0, int(_game_dict("event_state").get("served", 0)) - _win_event0)
	print("[window] %.0f s after start | arrivals %d = %.1f/min | buses %d (bringing %d riders) | lost %d | passed %s | takings %.1f/min | %sfood wait mean %.1f s (n %d), max %.1f s | HISAAB avg food wait %.1f s | ramp %.1f/min (raw %.1f), bus every %.0f s" % [
			span, arr, float(arr) * 60.0 / span, sim.buses_stopped - _win_buses0, sim.arrivals_bus - _win_bus_riders0, Game.lost_session - _win_lost0,
			passed, takings, ev, (sim.food_wait_sum - _win_fw_sum0) / maxf(1.0, float(fn)), fn, sim.food_wait_max,
			float(Game.stats().get("avg_food_wait", -1.0)), sim.arrivals_target, sim.arrivals_raw, minf(9999.0, sim.bus_interval())])


## A Game int property by name (W1-CORE's new vars), 0 when missing.
func _game_int(p: String) -> int:
	if p in Game:
		return int(Game.get(p))
	return 0


## --stats: the core-and-feel fields of plan 2.7 from the wave-1 Sim's getters
## (by name: "-" where this build's Sim has none).
func _stats_core_feel(cap: Dictionary) -> String:
	var held: String = "-"
	if sim.has_method("held_plates") and sim.has_method("held_plates_max"):
		held = "%d (max %d)" % [int(sim.call("held_plates")), int(sim.call("held_plates_max"))]
	var hall: String = "-"
	if sim.has_method("hall_seated_total") and sim.has_method("seated_total_scene"):
		var h: int = int(sim.call("hall_seated_total"))
		hall = "%d (%.1f%%)" % [h, 100.0 * float(h) / maxf(1.0, float(sim.call("seated_total_scene")))]
	var ramp_cap: float = float(cap["cap"]) if cap.has("cap") else _ramp_cap_formula()
	return " | door max %s | passed %s | held %s | trip orders %s | home walks %s | cap %.1f | hall seated %s | hall food %s road food %s | linger %s" % [
		_sim_val("door_line_max_seen", "%d"), ("%d" % _game_int("passed_session")) if "passed_session" in Game else "-",
		held, _sim_val("trip_orders_mean", "%.2f"), _sim_val("home_walks", "%d"), ramp_cap,
		hall, _sim_val("hall_food_wait_mean", "%.1f"), _sim_val("road_food_wait_mean", "%.1f"), _sim_val("lingering_count", "%d")]


## A wave-1 Sim getter by name, formatted; "-" when this build's Sim lacks it.
func _sim_val(m: String, fmt: String) -> String:
	if sim != null and sim.has_method(m):
		return fmt % sim.call(m)
	return "-"


## --stats + --quit-at: one line of run averages (arrivals over unpaused sim time).
func _print_summary() -> void:
	var t: float = maxf(0.001, sim.sim_clock)
	var arr: int = sim.arrivals_lorry + sim.arrivals_bus
	print("[summary] sim %.0f s | arrivals %d = %.1f/min (lorry %.1f/min, bus %.1f/min, %d buses) | lost %d | avg galla line %.2f (time-avg), avg galla wait %.1f s | avg food wait %.1f s (n %d) | sales %d | bus line max %d, longest wait for a bus %.1f s (to boarding %.1f s), boarded %d" % [
		t, arr, float(arr) * 60.0 / t, float(sim.arrivals_lorry) * 60.0 / t, float(sim.arrivals_bus) * 60.0 / t,
		sim.buses_stopped, Game.lost_session, _line_area / maxf(0.001, _line_time),
		sim.galla_wait_sum / maxf(1.0, float(sim.galla_wait_n)),
		sim.food_wait_sum / maxf(1.0, float(sim.food_wait_n)), sim.food_wait_n, sim.sales_count,
		_busq_max, sim.bus_wait_max, _busq_wait_max, sim.boarded_total])
	print("[summary] %s" % _order_mix_line())
	print("[summary] %s" % _dish_line())
	if sim.traffic != null and sim.traffic.debug_overlaps:
		print("[summary] %s" % _overlap_line())
	print("[summary] %s" % _daynight_line())


## Station menus: serves per full dish id this run (every dish of every
## built station, zeros included) and the dish mismatches seen at pick-up /
## serve (item model or bubble key vs the ticket's dish).
func _dish_line() -> String:
	var parts: PackedStringArray = PackedStringArray()
	var total: int = 0
	for id: String in Game.built_station_ids():
		for did: String in Game.dish_ids(id):
			var n: int = int(sim.dish_served.get(did, 0))
			total += n
			parts.append("%s %d" % [did, n])
	return "dishes %d: %s | mismatch %d (of %d checks)" % [total, " ".join(parts), sim.dish_mismatch, sim.dish_checks]


## Orders seen this run by key (Sim.order_counts) vs the expected mix now.
func _order_mix_line() -> String:
	var total: int = 0
	for k in sim.order_counts.keys():
		total += int(sim.order_counts[k])
	var seen: String = ""
	for k in sim.order_counts.keys():
		seen += "%s %d (%.1f%%) " % [str(k), int(sim.order_counts[k]), 100.0 * float(sim.order_counts[k]) / maxf(1.0, float(total))]
	var want: String = ""
	for cv in Game.order_mix():
		var c: Dictionary = cv
		want += "%s %.1f%% " % [Sim.order_key(c["ids"]), 100.0 * float(c["p"])]
	return "orders %d: %s| expected now: %s" % [total, seen, want]


## --traffic-debug: vehicle-vehicle and bus-person overlap frames, manoeuvre
## waits, the longest any vehicle stood still on the road.
func _overlap_line() -> String:
	var tr: Traffic = sim.traffic
	return "overlap frames (all vehicles): %d full-size, %d at 85%% [%s] | bus over a person on the crossing: %d frames [%s] | merge retries %d, guard waits %d (max %.1f s), longest bay wait to pull out %.1f s [%s] | longest standstill %.1f s [%s] | ready stop bus waited for the crossing max %.1f s" % [
			tr.debug_hits, tr.debug_hits85, tr.debug_hit_desc, tr.debug_ped_hits, tr.debug_ped_desc,
			tr.merge_retries, tr.guard_waits, tr.guard_max, tr.debug_merge_max, tr.debug_merge_desc,
			tr.debug_still_max, tr.debug_still_desc, tr.debug_bus_xbusy_max]


## Day / night: phase, band, night factor, seconds per band and the vehicles
## seen per band (Traffic.mix_line).
func _daynight_line() -> String:
	if day_night == null:
		return "daynight -"
	var bt: String = ""
	for b in day_night.band_time.keys():
		bt += "%s %.0f s " % [str(b), float(day_night.band_time[b])]
	return "daynight phase %.3f band %s night %.2f | time: %s| vehicles: %s" % [day_night.phase, day_night.band(),
			day_night.night, bt, sim.traffic.mix_line() if sim.traffic != null else "-"]


static func _globalize(p: String) -> String:
	if p.begins_with("res://") or p.begins_with("user://"):
		return ProjectSettings.globalize_path(p)
	return p


func _take_shot(t: float) -> void:
	await RenderingServer.frame_post_draw
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		print("[main3] shot t=%.1f skipped (no rendering)" % t)
		return
	var path: String = _globalize(_shot_dir).path_join("t%05.1f.png" % t)
	var err: Error = img.save_png(path)
	print("[main3] shot t=%.1f (game %.2f, step %s) -> %s %s" % [t, _game_t, director.current_step(), path, "" if err == OK else "FAILED %d" % err])


# ================================================================ autopilot (--auto)
func _on_auto_line_typed(_id: String) -> void:
	_auto_typed_t = _game_t


## The analytics consent card (--consent=ask) is open: true while the
## autopilot leaves everything else alone. After AUTO_CONSENT_DWELL s it taps
## ALLOW (a real tap at the button); if the card is still open
## AUTO_CONSENT_RETRY s later, it calls the card's own answer (the handler the
## tap reaches), else Analytics.set_consent(true, "auto").
func _auto_consent_tick() -> bool:
	if not Analytics.is_card_open():
		_auto_card_t = -1.0
		_auto_card_stage = 0
		return false
	if _auto_card_t < 0.0:
		_auto_card_t = _game_t
		_auto_card_stage = 0
	if _auto_card_stage == 2:
		return false   # answered by hand already and still open: carry on
	if _game_t - _auto_card_t < AUTO_CONSENT_DWELL:
		return true
	var card: Variant = Analytics.get("_card")
	if _auto_card_stage == 0:
		_auto_card_stage = 1
		_auto_card_tap_t = _game_t
		print("[auto] %.2f consent answered" % _game_t)
		var btn: Control = null
		if card is Control and is_instance_valid(card) and "allow_button" in (card as Object):
			btn = (card as Object).get("allow_button") as Control
		if btn != null and btn.is_visible_in_tree():
			_send_tap(btn.get_global_transform_with_canvas() * (btn.size * 0.5))
			return true
	elif _game_t - _auto_card_tap_t < AUTO_CONSENT_RETRY:
		return true
	_auto_card_stage = 2
	if card is Object and is_instance_valid(card) and (card as Object).has_method("answer"):
		print("[auto] %.2f consent: the tap did not land; answering through the card" % _game_t)
		(card as Object).call("answer", true)
	else:
		print("[auto] %.2f consent: no card button; Analytics.set_consent(true, auto)" % _game_t)
		Analytics.set_consent(true, "auto")
	return true


func _auto_tick(delta: float) -> void:
	var step: String = director.current_step()
	if step != _auto_log_step:
		_auto_log_step = step
		print("[auto] %.2f step -> %s (cash %.2f)" % [_game_t, step, Game.cash])
		if step == Director.S_FREE and _auto_free_t0 < 0.0:
			_auto_free_t0 = _game_t
		if step == Director.S_DONE:
			var core: String = Director.core_station()
			print("[auto] %.2f done state: %s L%d cash %.2f waiters %d tables %d" % [_game_t, core,
					Game.station_level(core), Game.cash, Game.waiter_count(), Game.table_count()])
	# --consent=ask: the consent card covers the game (its dim swallows taps);
	# nothing else is tapped while it is up, and it is answered ALLOW.
	if _auto_consent_tick():
		return
	# Progress signature: any change resets the no-progress counter.
	var sig: String = "%s|%s|%s|%s|%s|%d|%d|%d|%d|%d|%d" % [step, dialogue.current_id(), str(dialogue.is_open()),
		ui.current_panel, ui.current_popup, _auto_levels_sum(), Game.galla_count(),
		Game.claims_total, Game.built_station_ids().size(), Game.waiter_count(), Game.table_count()]
	if sig != _auto_sig:
		_auto_sig = sig
		_auto_tries = 0
	_auto_stall_check(step)
	var hand: HandPointer = director.hand()
	var hand_on: bool = hand != null and hand.is_showing()
	if not hand_on:
		_auto_hand_since = -1.0
	elif _auto_hand_since < 0.0:
		_auto_hand_since = _game_t
	# Line timing starts when the line does (before the tap-gap early-out).
	if dialogue.is_open() and dialogue.current_id() != _auto_line:
		_auto_line = dialogue.current_id()
		_auto_line_t = _game_t
		_auto_typed_t = -1.0
	if _game_t < _auto_next:
		return
	# 1) Dialogue: read the typed line, then tap the box.
	if dialogue.is_open():
		var id: String = dialogue.current_id()
		var typed: bool = _auto_typed_t >= _auto_line_t
		var dwell: float = float(AUTO_DWELL.get(id, -1.0))
		var due: bool = (_game_t - _auto_line_t >= dwell) if dwell > 0.0 else (typed and _game_t - _auto_typed_t >= AUTO_READ)
		if due or _game_t - _auto_line_t > AUTO_TYPE_TIMEOUT:
			_auto_tap_dialogue()
			if not typed:
				_auto_next = _game_t + 0.25
		return
	_auto_line = ""
	# 2) The hand points at something: tap exactly there. (In free play the
	# hand only nudges a ready TASKS card; the ref player claimed at 136.5 s.)
	if hand_on and not (step == Director.S_FREE and _free_rel() < AUTO_CLAIM_NOT_BEFORE):
		if _game_t - _auto_hand_since >= float(AUTO_HAND_DWELL.get(step, AUTO_HAND_SETTLE)):
			_auto_tap_hand(hand)
		return
	# 3) Marker gates (no hand): tap whatever the tutorial's marker stands
	# over (Director.marker_tap_id), then free play.
	var marked: String = director.marker_tap_id()
	if marked != "":
		_auto_marker_t += delta
		if _auto_marker_t >= AUTO_MARKER_WAIT:
			_auto_tap_world(marked)
		return
	_auto_marker_t = 0.0
	if step == Director.S_FREE or step == Director.S_DONE:
		_auto_free(step)


## Seconds since the tutorial's free step first began (game time if it never ran).
func _free_rel() -> float:
	return _game_t - maxf(0.0, _auto_free_t0)


func _auto_free(step: String) -> void:
	# Scripted purchases (ref 105.9 – 133.6 s = free step + 17.9 – 45.6 s),
	# only in the tutorial's free play.
	if step == Director.S_FREE and _auto_free_i < AUTO_FREE_SCRIPT.size():
		var e: Array = AUTO_FREE_SCRIPT[_auto_free_i]
		if _free_rel() >= float(e[0]):
			_auto_free_i += 1
			_auto_free_action(str(e[1]))
			return
	if step == Director.S_DONE and _auto_done_t < 0.0:
		_auto_done_t = _game_t
	# 1 s after the tutorial: where the camera is and what the NEXT chip says.
	if step == Director.S_DONE and not _auto_home_checked and _game_t - _auto_done_t >= 1.0:
		_auto_home_checked = true
		_auto_home_check()
	# Once the tutorial is over: one real drag gesture (camera pan + inertia).
	if step == Director.S_DONE and not _auto_drag_done:
		if _game_t - _auto_done_t > 3.0 and ui.current_panel == "" and ui.current_popup == "":
			_auto_drag_done = true
			_auto_drag_test()
			return
	# Claim a ready task (ref: ready ~128.7, claimed 136.5).
	if ui.current_panel != "" or ui.current_popup != "":
		_auto_ready_t = -1.0
		return
	var slot: int = -1
	for i in Game.tasks.size():
		var t: Variant = Game.tasks[i]
		if t is Dictionary and bool((t as Dictionary).get("done", false)):
			slot = i
			break
	if slot < 0:
		_auto_ready_t = -1.0
		return
	if _auto_ready_t < 0.0:
		_auto_ready_t = _game_t
	if _game_t - _auto_ready_t >= AUTO_CLAIM_AFTER and _free_rel() >= AUTO_CLAIM_NOT_BEFORE:
		var card: Control = ui.anchor("task_card_%d" % slot)
		if card != null:
			_auto_tap_control(card, Vector2(0.5, 0.5))


## T3 (UX fix): the tutorial ends on the home view with the NEXT chip up.
func _auto_home_check() -> void:
	var tp: Vector3 = camera_rig.target_point()
	var hp: Vector3 = CameraRig.home_point()
	var d: float = Vector2(tp.x - hp.x, tp.z - hp.z).length()
	var chip: NextChip = ui.hud.next_chip if ui.hud != null else null
	var vis: bool = chip != null and chip.is_showing()
	var hid: String = str(chip.hint.get("id", "")) if chip != null else ""
	print("[auto] %.2f home check: dist %.2f m, in view %s, next chip %s '%s'" % [_game_t, d,
			camera_rig.is_home_in_view(), vis, hid])


func _auto_free_action(a: String) -> void:
	print("[auto] %.2f free-play: %s" % [_game_t, a])
	match a:
		"open_checkout":
			if ui.current_panel == "":
				_auto_tap_world("galla")
		"open_core":
			if ui.current_panel == "":
				_auto_tap_world("station:" + Director.core_station())
		"close_panel":
			if ui.current_panel.begins_with("staff:") or ui.current_panel == "galla":
				_auto_tap_control(ui.anchor("staff_close"), Vector2(0.5, 0.5))
			elif ui.current_panel.begins_with("quick:"):
				ui.close_all()
			elif ui.current_panel == "daftar":
				_auto_tap_control(ui.anchor("daftar_close"), Vector2(0.5, 0.5))
		"close_sheet":
			if ui.current_panel.begins_with("station:"):
				_auto_tap_control(ui.anchor("sheet_outside"), Vector2(0.5, 0.6))
		"processing":
			if _auto_affords(Game.proc_cost(_auto_sheet_id()), a):
				_auto_tap_control(ui.anchor("processing_button"), Vector2(0.5, 0.5))
		"level_up":
			if _auto_affords(Game.level_cost(_auto_sheet_id()), a):
				_auto_tap_control(ui.anchor("level_up_button"), Vector2(0.5, 0.5))
		_:
			if a.begins_with("galla_upgrade_"):
				if _auto_affords(Game.galla_upgrade_cost(int(a.substr(14))), a):
					_auto_tap_control(ui.anchor(a), Vector2(0.5, 0.5))


## The open counter sheet's station id (the core station when none is open).
func _auto_sheet_id() -> String:
	return ui.current_panel.substr(8) if ui.current_panel.begins_with("station:") else Director.core_station()


## Sum of every station's level (the progress signature; theme-free).
func _auto_levels_sum() -> int:
	var n: int = 0
	for id in Game.station_ids():
		n += Game.station_level(str(id))
	return n


## Invariant check (Idle Business Kit, phase 1): before the tutorial is done,
## something must move at least every AUTO_STALL_S of game time: the step,
## the line, a panel, a sale. Otherwise "[check] STALL" is printed once per
## step (the suite parser fails on it).
func _auto_stall_check(step: String) -> void:
	var sales: int = sim.sales_count if sim != null else 0
	var key: String = "%s|%s|%s|%d" % [step, dialogue.current_id(), ui.current_panel, sales]
	if key != _auto_prog_key:
		_auto_prog_key = key
		_auto_prog_t = _game_t
		return
	if step == Director.S_DONE or step == _auto_stall_step:
		return
	if _game_t - _auto_prog_t >= AUTO_STALL_S:
		_auto_stall_step = step
		print("[check] STALL: no progress for %.0f s at step %s (line '%s', panel '%s', sales %d)" % [
				_game_t - _auto_prog_t, step, dialogue.current_id(), ui.current_panel, sales])


## Round 2 step 2: a player does not tap a price he cannot pay (the seats
## beat may now come right after the waiter beat and spend the cash first),
## so a scripted purchase is skipped instead of counted as a stalled tap.
func _auto_affords(cost: float, what: String) -> bool:
	if Game.can_afford(cost):
		return true
	print("[auto] %.2f free-play: %s skipped (cash %.2f < %.2f)" % [_game_t, what, Game.cash, cost])
	return false


func _auto_fallback() -> bool:
	_auto_tries += 1
	return _auto_tries > AUTO_FALLBACK_AFTER


## Printed once per stall (the progress signature resets the counter).
func _auto_warn(msg: String) -> void:
	if _auto_tries == AUTO_FALLBACK_AFTER + 1:
		print("[auto] WARNING %.2f: %s" % [_game_t, msg])


func _auto_tap_dialogue() -> void:
	_auto_next = _game_t + AUTO_TAP_GAP
	var box: Control = dialogue.get("_box") as Control
	var p: Vector2 = get_viewport().get_visible_rect().size * Vector2(0.5, 0.88)
	if box != null and box.is_visible_in_tree():
		p = box.get_global_transform_with_canvas() * (box.size * 0.5)
	if _auto_fallback():
		_auto_warn("dialogue '%s' ignored real taps; calling its input handler" % dialogue.current_id())
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = p
		dialogue.call("_on_input", ev)
		return
	_send_tap(p)


func _auto_tap_hand(hand: HandPointer) -> void:
	_auto_next = _game_t + AUTO_TAP_GAP
	var target: Variant = hand.current_target()
	var p: Variant = hand.call("_screen_point")
	if not (p is Vector2):
		return
	if _auto_fallback():
		_auto_warn("step %s: real taps at the hand did not advance; calling handlers" % director.current_step())
		if target is Control:
			_handler_for_control(target as Control, p as Vector2)
		elif ui.ad_bubble != null and ui.ad_bubble.is_showing():
			ui.call("_on_bubble_tapped")
		return
	_send_tap(p as Vector2)


func _auto_tap_control(c: Control, rel: Vector2) -> void:
	_auto_next = _game_t + AUTO_TAP_GAP
	if c == null or not c.is_visible_in_tree():
		return
	var p: Vector2 = c.get_global_transform_with_canvas() * (c.size * rel)
	if _auto_fallback():
		_auto_warn("control %s ignored real taps; calling its handler" % c.name)
		_handler_for_control(c, p)
		return
	_send_tap(p)


func _auto_tap_world(tap_id: String) -> void:
	_auto_next = _game_t + AUTO_TAP_GAP
	var area: Area3D = _find_tap_area(tap_id)
	var pos: Vector3 = Vector3.ZERO
	if area != null:
		pos = area.global_position
		# Aim at the middle of the box shape, not its floor origin.
		for c in area.get_children():
			if c is CollisionShape3D:
				pos = (c as CollisionShape3D).global_position
				break
	elif tap_id == "galla":
		pos = Layout3.galla_focus(0)
	else:
		pos = Layout3.station_focus(tap_id.trim_prefix("station:"))
	if _auto_fallback():
		_auto_warn("world tap '%s' ignored; emitting WorldInput.tapped" % tap_id)
		world_input.tapped.emit(tap_id, pos)
		return
	var cam: Camera3D = camera_rig.get_camera()
	_send_tap(cam.unproject_position(pos))


func _find_tap_area(tap_id: String) -> Area3D:
	var stack: Array[Node] = [sim]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Area3D and str(n.get_meta("tap_id", "")) == tap_id:
			if tap_id != "galla" or int(n.get_meta("galla_index", 0)) == 0:
				return n as Area3D
		for c in n.get_children():
			stack.append(c)
	return null


## The handler a real tap on `c` would reach.
func _handler_for_control(c: Control, p: Vector2) -> void:
	if c is BaseButton:
		(c as BaseButton).pressed.emit()
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = c.get_global_transform_with_canvas().affine_inverse() * p
	ev.global_position = p
	c.gui_input.emit(ev)
	if c.has_method("_gui_input"):
		c.call("_gui_input", ev)


## A real one-finger drag (mouse with the button held, which the project
## also turns into ScreenDrag): 200 px up-left over 0.3 s, then release.
func _auto_drag_test() -> void:
	_auto_next = _game_t + 2.0
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var a: Vector2 = vp * Vector2(0.6, 0.55)
	var b: Vector2 = a + Vector2(-160.0, -120.0)
	var before: Vector3 = camera_rig.target_point()
	var xf: Transform2D = get_viewport().get_final_transform()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	down.position = xf * a
	down.global_position = down.position
	Input.parse_input_event(down)
	var steps: int = 10
	for i in steps:
		await get_tree().create_timer(0.03, true, false, true).timeout
		var mm := InputEventMouseMotion.new()
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		var pt: Vector2 = a.lerp(b, float(i + 1) / float(steps))
		mm.position = xf * pt
		mm.global_position = mm.position
		mm.relative = xf.basis_xform((b - a) / float(steps))
		Input.parse_input_event(mm)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	up.button_mask = 0
	up.position = xf * b
	up.global_position = up.position
	Input.parse_input_event(up)
	var mid: Vector3 = camera_rig.target_point()
	await get_tree().create_timer(1.0, true, false, true).timeout
	var after: Vector3 = camera_rig.target_point()
	print("[auto] %.2f drag test: camera %s -> %s (release) -> %s (after inertia), mode %s" % [_game_t, before, mid, after, camera_rig.mode_name()])


## A real tap at a canvas (viewport) position: mouse press + release, which
## the project turns into a touch as well (emulate_touch_from_mouse).
func _send_tap(canvas_pos: Vector2) -> void:
	var wp: Vector2 = get_viewport().get_final_transform() * canvas_pos
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	down.position = wp
	down.global_position = wp
	var move := InputEventMouseMotion.new()
	move.position = wp
	move.global_position = wp
	Input.parse_input_event(move)
	Input.parse_input_event(down)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	up.button_mask = 0
	await get_tree().create_timer(0.06, true, false, true).timeout
	Input.parse_input_event(up)


# ================================================================ menu expansion (capture + tap check)
## §15.10 tap test points: [label, world point, expected UiRoot.current_panel].
## Round 2 step 2: the rack and every waiter open STAFF › WAITERS, the cash
## counters STAFF › CASHIERS, a built table BUILD › TABLES ("daftar"; the
## SEATING panel is retired).
const TAP_A := [
	["chai_top", Vector3(1.70, 0.80, 1.75), "station:chai"],
	["chai_pass0_item", Vector3(2.04, 0.85, 2.59), "station:chai"],
	["chai_pass_end", Vector3(2.10, 0.80, 2.90), "station:chai"],
	["pinky", Vector3(0.70, 0.70, 1.75), "station:chai"],
	["lassi_pad_top", Vector3(1.75, 0.80, 4.20), "daftar"],
	["matka_mouth", Vector3(1.52, 1.02, 3.95), "daftar"],
	["tray_rack", Vector3(1.60, 0.60, 3.42), "staff:waiters"],
	["raju_spot", Vector3(2.45, 0.70, 3.55), "staff:waiters"],
	["raju_free_spot", Vector3(2.20, 0.70, 3.32), "staff:waiters"],
	["idle_spot_2", Vector3(3.65, 0.70, 4.55), "staff:waiters"],
	["idle_spot_1", Vector3(3.10, 0.70, 4.50), "staff:waiters"],
	["galla1_desk", Vector3(2.20, 0.85, 5.40), "staff:cashiers"],
	["galla1_cashier", Vector3(1.30, 0.70, 5.40), "staff:cashiers"],
	["galla2_desk", Vector3(2.20, 0.85, 7.20), "staff:cashiers"],
	["galla2_cashier", Vector3(1.30, 0.70, 7.20), "staff:cashiers"],
	["table0_top", Vector3(3.95, 0.50, 2.00), "daftar"],
	["table0_front_charpai", Vector3(3.95, 0.42, 2.95), "daftar"],
]
const TAP_B_EXTRA := [
	["lassi_pass0_item", Vector3(2.04, 0.85, 4.20), "station:lassi"],
	["lassi_cook0", Vector3(0.95, 0.70, 4.20), "station:lassi"],
	["lassi_cook1", Vector3(0.70, 0.70, 3.30), "station:lassi"],
	["lassi_cook2", Vector3(0.25, 0.70, 4.15), "station:lassi"],
	["lassi_cook1_head", Vector3(0.70, 1.00, 3.30), "station:lassi"],
	["lassi_cook2_head", Vector3(0.25, 1.00, 4.15), "station:lassi"],
]
## C: the kadai pad (lassi built, 5 table sets): the pad opens the Daftar,
## table 4 beside it opens BUILD › TABLES (also the Daftar).
const TAP_C := [
	["kadai_pad_top", Vector3(10.70, 0.85, 2.20), "daftar"],
	["table4_top", Vector3(13.60, 0.50, 2.00), "daftar"],
	["table4_back_charpai", Vector3(13.20, 0.42, 1.05), "daftar"],
]
## D: the kadai built with 3 cooks and every unlock prop up (L100): counter,
## rim, side counter, pass item, the chole sack, the cooks and their heads
## open the kadai; also tapped from the kadai focus and the annex view.
const TAP_D := [
	["kadai_counter_top", Vector3(10.70, 0.85, 2.20), "station:kadai"],
	["kadai_rim", Vector3(10.48, 0.96, 2.18), "station:kadai"],
	["kadai_side_counter", Vector3(11.15, 0.75, 2.20), "station:kadai"],
	["kadai_pass0_item", Vector3(10.40, 0.85, 2.64), "station:kadai"],
	["kadai_chole_sack", Vector3(11.60, 0.32, 2.30), "station:kadai"],
	["kadai_cook0", Vector3(10.70, 0.70, 1.20), "station:kadai"],
	["kadai_cook0_head", Vector3(10.70, 1.00, 1.20), "station:kadai"],
	["kadai_cook1", Vector3(10.25, 0.70, 1.65), "station:kadai"],
	["kadai_cook1_head", Vector3(10.25, 1.00, 1.65), "station:kadai"],
	["kadai_cook2", Vector3(11.15, 0.70, 0.75), "station:kadai"],
	["kadai_cook2_head", Vector3(11.15, 1.00, 0.75), "station:kadai"],
	["table4_top", Vector3(13.60, 0.50, 2.00), "daftar"],
]
const TAP_D_VIEWS := [["kadai_focus", Vector3(10.7, 0.0, 2.2)], ["annex", Vector3(11.0, 0.0, 3.4)]]
## E (family layout, core and feel C6.1): waiter 4's hall home and the hall
## view. Wave 1 reaches no new Layout3 name (build plan rule 5):
const WAITER_HOME_HALL := Vector3(15.85, 0.0, 3.35)   # = Layout3.WAITER_HOME_HALL (frozen, plan 2.3)
const HALL_CENTER := Vector3(18.6, 0.0, 4.1)          # = Layout3.HALL_CENTER (frozen, plan 2.3)
## --capture=menu: camera target offset from a ghost pad (pad + tag in view).
const GHOST_VIEW_OFFSET := Vector3(0.5, 0.0, 0.5)
const TAP_SETTLE := 0.25
const TAP_RESULT := 0.35
const TAP_CENTRE := 0.7


func _run_check_pack() -> void:
	var fails: int = PackCheck.run()
	get_tree().quit(fails)


## --tap-check: docs/v3-station-menus.md §11.6 (stages A, B, C, D; the
## bhurji / dal stages C / C2 / D of the menu expansion are gone with those
## stations). Quits with exit code = the number of failed points.
func _run_tap_check() -> void:
	await _game_wait(0.5)
	# Core and feel C6.1: the family layout (after --renovate) keeps every
	# counter built, so the fresh-save precondition and stages A-D are
	# skipped there and only stage E runs.
	var family: bool = _layout_variant() == "family"
	if not family and (Game.is_built("lassi") or not Game.is_tutorial_done()):
		print("TAPCHECK needs --skip-tutorial on a fresh save (lassi already built or the tutorial still running)")
		print("TAPCHECK fails=99")
		get_tree().quit(99)
		return
	Game.debug_set_cash(maxf(Game.cash, 1.0e12))
	match _tap_zoom:
		"":
			_tap_mult = CameraRig.GAME
		"min":
			_tap_mult = camera_rig.zoom_min
		"max":
			_tap_mult = camera_rig.zoom_max
		_:
			_tap_mult = clampf(float(_tap_zoom), camera_rig.zoom_min, camera_rig.zoom_max)
	print("[tapcheck] zoom x%.2f" % _tap_mult)
	if family:
		print("[tapcheck] family layout: stages A-D skipped, stage E only")
		var fe: int = await _tap_stage_e()
		print("TAPCHECK fails=%d" % fe)
		get_tree().quit(fe)
		return
	# A: lassi pad (tandoor, 3 waiters, 2 gallas, 3 tables).
	if not Game.is_built("tandoor"):
		Game.build("tandoor")
	while Game.galla_count() < 2 and Game.buy_galla_hire():
		pass
	while Game.waiter_count() < 3 and Game.buy_waiter_hire():
		pass
	while Game.table_count() < 3 and Game.buy_table():
		pass
	await _game_wait(1.5)
	var fails: int = 0
	fails += await _tap_stage("A", TAP_A)
	# B: lassi built with 3 cooks.
	Game.build("lassi")
	Game.buy_hire("lassi")
	Game.buy_hire("lassi")
	await _game_wait(1.5)
	var pts_b: Array = []
	for v in TAP_A:
		var e: Array = (v as Array).duplicate()
		if str(e[0]) == "lassi_pad_top" or str(e[0]) == "matka_mouth":
			e[2] = "station:lassi"
		pts_b.append(e)
	pts_b.append_array(TAP_B_EXTRA)
	fails += await _tap_stage("B", pts_b)
	# C: the kadai pad (lassi built), 5 table sets.
	while Game.table_count() < 5 and Game.buy_table():
		pass
	await _game_wait(1.5)
	fails += await _tap_stage("C", TAP_C)
	# D: the kadai built with 3 cooks and L100 (every unlock prop up).
	Game.build("kadai")
	Game.buy_hire("kadai")
	Game.buy_hire("kadai")
	Game.debug_set_level("kadai", 100)
	await _game_wait(2.0)
	fails += await _tap_stage("D", TAP_D)
	fails += await _tap_stage_views("D", TAP_D, TAP_D_VIEWS)
	print("[tapcheck] stage E: SKIP (roadside layout; E runs after --renovate)")
	print("TAPCHECK fails=%d" % fails)
	get_tree().quit(fails)


## Stage E (core and feel C6.1, family layout): waiter 4's ghost at the hall
## home (the 2-tap card), waiter 4 there once hired (STAFF › WAITERS) and the
## tables 2-7 of the family layout (BUILD › TABLES), each tried from the home
## view and the hall view (a point off screen or under the HUD in a view is
## skipped there); a point no view shows is tapped centred, as stages A-C do.
func _tap_stage_e() -> int:
	while Game.waiter_count() < 3 and Game.buy_waiter_hire():
		pass
	await _game_wait(1.5)
	var views: Array = [["home", home_view()], ["hall", HALL_CENTER]]
	var p_home: Vector3 = WAITER_HOME_HALL + Vector3(0.0, 0.7, 0.0)
	var fails: int = 0
	_show_ghost_waiter()
	await _game_wait(0.5)
	print("[tapcheck] stage E: waiters %d, ghost waiter %s" % [Game.waiter_count(),
			str(sim.call("ghost_waiter_shown")) if sim.has_method("ghost_waiter_shown") else "?"])
	fails += await _tap_points_views("E", [["hall_ghost_waiter", p_home, "quick:waiters"]], views, _show_ghost_waiter)
	while Game.waiter_count() < 4 and Game.buy_waiter_hire():
		pass
	await _game_wait(1.5)
	print("[tapcheck] stage E: waiters %d" % Game.waiter_count())
	fails += await _tap_points_views("E", [["hall_waiter4", p_home, "staff:waiters"]], views)
	while Game.table_count() < 8 and Game.buy_table():
		pass
	await _game_wait(2.0)
	print("[tapcheck] stage E: tables %d" % Game.table_count())
	var pts: Array = []
	for i in range(2, 8):
		pts.append(["table%d_top" % i, Layout3.table_tap_center(i), "daftar"])
	fails += await _tap_points_views("E", pts, views)
	return fails


func _show_ghost_waiter() -> void:
	sim.show_ghost_waiter(true)


## Taps every point of `pts` ([label, world point, expected panel]) from each
## view ([label, ground point]) as _tap_stage_views does, `prep` called before
## each tap; a point that no view shows (off screen or under the HUD) is then
## tapped once with the camera centred on it, as _tap_stage does.
func _tap_points_views(stage: String, pts: Array, views: Array, prep: Callable = Callable()) -> int:
	var fails: int = 0
	var cam: Camera3D = camera_rig.get_camera()
	for v in pts:
		var e: Array = v
		var label: String = str(e[0])
		var p: Vector3 = e[1]
		var want: String = str(e[2])
		var tapped: bool = false
		for vv in views:
			var view: Array = vv
			ui.close_all()
			Game.hide_ad_bubble()
			if dialogue.is_open():
				dialogue.close()
			if prep.is_valid():
				prep.call()
			camera_rig.snap(view[1], _tap_mult)
			await _game_wait(TAP_SETTLE)
			var sp: Vector2 = cam.unproject_position(p)
			var cover: String = await _gui_cover(sp)
			if cover != "" or not _tap_on_screen(sp) or cam.is_position_behind(p):
				print("TAPCHECK %s@%s %s skipped (%s)" % [stage, str(view[0]), label, cover if cover != "" else "off screen"])
				continue
			tapped = true
			_send_tap(sp)
			await _game_wait(TAP_RESULT)
			var got: String = ui.current_panel
			var ok: bool = got == want
			if not ok:
				fails += 1
			print("TAPCHECK %s@%s %s want=%s got=%s %s" % [stage, str(view[0]), label, want, got if got != "" else "-",
					"PASS" if ok else "FAIL"])
		if tapped:
			continue
		ui.close_all()
		Game.hide_ad_bubble()
		if dialogue.is_open():
			dialogue.close()
		if prep.is_valid():
			prep.call()
		camera_rig.fly_to(Vector3(p.x, 0.0, p.z), _tap_mult)
		await _game_wait(TAP_CENTRE)
		var sp2: Vector2 = cam.unproject_position(p)
		var cover2: String = await _gui_cover(sp2)
		_send_tap(sp2)
		await _game_wait(TAP_RESULT)
		var got2: String = ui.current_panel
		var ok2: bool = got2 == want
		if not ok2:
			fails += 1
		print("TAPCHECK %s %s want=%s got=%s %s (centred%s)" % [stage, label, want, got2 if got2 != "" else "-",
				"PASS" if ok2 else "FAIL", (": under %s" % cover2) if cover2 != "" else ""])
	ui.close_all()
	return fails


func _tap_stage(stage: String, pts: Array) -> int:
	var fails: int = 0
	var cam: Camera3D = camera_rig.get_camera()
	var bt: BuildTag = ui.build_tag
	print("[tapcheck] stage %s: ghost pad '%s', build tag %s" % [stage, sim.ghost_station_id(),
			("'%s' shown" % bt.station_id) if bt != null and bt.is_showing() else "hidden"])
	for v in pts:
		var e: Array = v
		var label: String = str(e[0])
		var p: Vector3 = e[1]
		var want: String = str(e[2])
		ui.close_all()
		Game.hide_ad_bubble()
		if dialogue.is_open():
			dialogue.close()
		camera_rig.snap(home_view(), _tap_mult)
		await _game_wait(TAP_SETTLE)
		var sp: Vector2 = cam.unproject_position(p)
		var note: String = ""
		var cover: String = await _gui_cover(sp)
		if cover != "" or not _tap_on_screen(sp):
			note = " (centred: %s)" % (cover if cover != "" else "off screen at home")
			camera_rig.fly_to(Vector3(p.x, 0.0, p.z), _tap_mult)
			await _game_wait(TAP_CENTRE)
			sp = cam.unproject_position(p)
		var on_tag: bool = ui.build_tag != null and ui.build_tag.is_showing() \
				and ui.build_tag.get_global_rect().has_point(sp)
		_send_tap(sp)
		await _game_wait(TAP_RESULT)
		var got: String = ui.current_panel
		var ok: bool = got == want
		if not ok:
			fails += 1
		print("TAPCHECK %s %s want=%s got=%s %s%s%s" % [stage, label, want, got if got != "" else "-",
				"PASS" if ok else "FAIL", note, " (on the build tag)" if on_tag else ""])
	ui.close_all()
	return fails


## Taps every point of `pts` from each camera target of `views` ([label,
## ground point], game zoom). A point off screen or under the HUD in a view
## is skipped there (the BuildTag does not count as cover: a tap on it opens
## the Daftar, which is the failure this stage looks for).
func _tap_stage_views(stage: String, pts: Array, views: Array) -> int:
	var fails: int = 0
	var cam: Camera3D = camera_rig.get_camera()
	for vv in views:
		var view: Array = vv
		for v in pts:
			var e: Array = v
			var label: String = str(e[0])
			var p: Vector3 = e[1]
			var want: String = str(e[2])
			ui.close_all()
			Game.hide_ad_bubble()
			if dialogue.is_open():
				dialogue.close()
			camera_rig.snap(view[1], _tap_mult)
			await _game_wait(TAP_SETTLE)
			var sp: Vector2 = cam.unproject_position(p)
			var cover: String = await _gui_cover(sp)
			if cover != "" or not _tap_on_screen(sp):
				print("TAPCHECK %s@%s %s skipped (%s)" % [stage, str(view[0]), label, cover if cover != "" else "off screen"])
				continue
			var on_tag: bool = ui.build_tag != null and ui.build_tag.is_showing() \
					and ui.build_tag.get_global_rect().has_point(sp)
			_send_tap(sp)
			await _game_wait(TAP_RESULT)
			var got: String = ui.current_panel
			var ok: bool = got == want
			if not ok:
				fails += 1
			print("TAPCHECK %s@%s %s want=%s got=%s %s%s" % [stage, str(view[0]), label, want, got if got != "" else "-",
					"PASS" if ok else "FAIL", " (on the build tag)" if on_tag else ""])
	ui.close_all()
	return fails


func _tap_on_screen(sp: Vector2) -> bool:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	return sp.x >= 24.0 and sp.y >= 24.0 and sp.x <= vs.x - 24.0 and sp.y <= vs.y - 24.0


## Name of the HUD / KAAM control under canvas point `sp` ("" = none, or the
## BuildTag, which a tap may legitimately hit over a pad).
func _gui_cover(sp: Vector2) -> String:
	var wp: Vector2 = get_viewport().get_final_transform() * sp
	var mm := InputEventMouseMotion.new()
	mm.position = wp
	mm.global_position = wp
	Input.parse_input_event(mm)
	await get_tree().process_frame
	await get_tree().process_frame
	var c: Control = get_viewport().gui_get_hovered_control()
	if c == null or not c.is_visible_in_tree():
		return ""
	if ui.build_tag != null and (c == ui.build_tag or ui.build_tag.is_ancestor_of(c)):
		return ""
	return str(c.name)


## --capture=menu: menu-expansion review shots -> <shot-dir>/menu_<label>.png.
func _menu_capture() -> void:
	DirAccess.make_dir_recursive_absolute(_globalize(_shot_dir))
	var missing: Array = []
	for m in MENU_MODELS:
		if not Models.exists(str(m)):
			missing.append(str(m))
	print("MODELS missing: %s" % str(missing))
	await _game_wait(0.5)
	MunshiNotes.enabled = false
	Game.debug_set_cash(maxf(Game.cash, 1.0e9))
	if not Game.is_built("tandoor"):
		Game.build("tandoor")
	while Game.galla_count() < 2 and Game.buy_galla_hire():
		pass
	while Game.table_count() < 3 and Game.buy_table():
		pass
	# 0) One waiter (QA round 1: the lassi needs 2): the lassi tag reads
	# "NEEDS 2 WAITERS", so does its Daftar row, and Munshi-ji asks for a
	# second waiter at the waiter stand.
	camera_rig.fly_to(Layout3.station_focus("lassi") + GHOST_VIEW_OFFSET, CameraRig.GAME)
	await _game_wait(2.0)
	await _named_shot("ghost_lassi_needs", "menu")
	ui.open_daftar("build")
	await _game_wait(1.5)
	await _named_shot("daftar_w1", "menu")
	ui.close_all()
	await _game_wait(0.6)
	MunshiNotes.enabled = true
	if await _wait_for(func() -> bool: return dialogue.is_open() and dialogue.current_id() == "menu_need_waiters_lassi", 15.0):
		await _game_wait(5.0)   # the line types at 30 chars/s
		await _named_shot("note_lassi_waiters", "menu")
	dialogue.close()
	MunshiNotes.enabled = false
	await _game_wait(0.6)
	while Game.waiter_count() < 2 and Game.buy_waiter_hire():
		pass
	# 1) The lassi ghost pad and its price tag (framed a little lower than
	# Munshi-ji's note view, so the tag clears the KAAM bar on a 9:16 screen).
	camera_rig.fly_to(Layout3.station_focus("lassi") + GHOST_VIEW_OFFSET, CameraRig.GAME)
	await _game_wait(2.0)
	await _named_shot("ghost_lassi", "menu")
	var pads: Array = [await _pad_band("lassi")]
	# 2) Munshi-ji's line over the pad.
	MunshiNotes.enabled = true
	if await _wait_for(func() -> bool: return dialogue.is_open() and dialogue.current_id() == "menu_lassi", 15.0):
		await _game_wait(5.0)   # the whole line typed (30 chars/s)
		await _named_shot("note_lassi", "menu")
	dialogue.close()
	MunshiNotes.enabled = false
	await _game_wait(0.6)
	# 3) Lassi built: home view, the counter churning, a waiter with lassi + roti
	# (menu_lassi_home); then the counter close up: Gopi churning, a glass on
	# the pass (menu_lassi).
	Game.build("lassi")
	camera_rig.fly_to(home_view(), CameraRig.GAME)
	await _wait_for(_menu_lassi_moment, 120.0)
	await _named_shot("lassi_home", "menu")
	await _menu_station_shot("lassi")
	# 3b) Every lassi cook (QA round 2): Neetu + Bittu beside Gopi and the
	# LASSI / लस्सी board.
	while Game.station_employees("lassi") < Layout3.MAX_STATION_STAFF and Game.buy_hire("lassi"):
		pass
	await _game_wait(1.0)
	var lassi_pts: Array = _station_points("lassi")
	lassi_pts.append_array(MENU_LASSI_BOARD_POINTS)
	_frame_points(lassi_pts, MENU_TOP_PX + 30.0, 1010.0, 40.0, 0.5)
	await _game_wait(2.0)
	await _wait_for(_no_cash_burst, 20.0)
	await _named_shot("cooks_lassi", "menu")
	# 4) The kadai pad with 2 waiters ("NEEDS 3 WAITERS"), the Daftar with
	# its MENU lines, then the pad with its price once waiter 3 is hired.
	camera_rig.fly_to(Layout3.station_focus("kadai") + GHOST_VIEW_OFFSET, CameraRig.GAME)
	await _game_wait(2.0)
	await _named_shot("ghost_kadai", "menu")
	ui.open_daftar("build")
	await _game_wait(1.5)
	await _named_shot("daftar", "menu")
	ui.close_all()
	await _game_wait(0.6)
	Game.buy_waiter_hire()
	await _game_wait(1.5)
	await _named_shot("ghost_kadai_ready", "menu")
	pads.append(await _pad_band("kadai"))
	_save_pad_sheet(pads)
	# 5) Munshi-ji's kadai line over the pad.
	MunshiNotes.enabled = true
	if await _wait_for(func() -> bool: return dialogue.is_open() and dialogue.current_id() == "menu_kadai", 15.0):
		await _game_wait(5.0)
		await _named_shot("note_kadai", "menu")
	dialogue.close()
	MunshiNotes.enabled = false
	await _game_wait(0.6)
	# 6) The kadai built (no pad or tag left in the annex), 5 table sets;
	# the kadai close up: Shera stirring, the fire mouth, steam, a plate on
	# the pass; then the annex with a waiter at a kadai pickup and table 4.
	Game.build("kadai")
	while Game.table_count() < 5 and Game.buy_table():
		pass
	await _menu_station_shot("kadai")
	camera_rig.fly_to(Vector3(11.0, 0.0, 2.9), CameraRig.GAME)
	await _game_wait(1.0)
	await _wait_for(_menu_annex_moment, 120.0)
	await _named_shot("annex", "menu")
	# 6b) Every kadai cook: Shera (karchhi), Kamla (karchhi), Kallu (plates).
	while Game.station_employees("kadai") < Layout3.MAX_STATION_STAFF and Game.buy_hire("kadai"):
		pass
	await _game_wait(1.0)
	_frame_points(_station_points("kadai"), MENU_TOP_PX + 30.0, 1010.0, 40.0)
	await _game_wait(2.0)
	await _wait_for(_no_cash_burst, 20.0)
	await _named_shot("cooks_annex", "menu")
	# 7) The unlock moment: chai at L24, the sheet open, one LEVEL UP -> the
	# NEW ON THE MENU pop over the counter (shot 0.9 s after the tap: the card
	# fully popped in, its sparkles gone; the tap waits for a frame with no
	# galla cash burst, whose notes would cross the counter at the sheet's
	# zoom).
	camera_rig.fly_to(home_view(), CameraRig.GAME)
	Game.debug_set_level("chai", 24)
	await _game_wait(1.0)
	ui.open_station("chai")
	await _game_wait(1.2)
	await _wait_for(_no_cash_burst, 20.0)
	Game.buy_level("chai")
	await _game_wait(0.9)
	await _named_shot("unlock_pop", "menu")
	# 7b) The chai sheet once the pop has gone: coffee unlocked (its chip
	# bordered marigold), green tea and kesar doodh locked.
	await _wait_for(func() -> bool: return ui.menu_pop == null or not ui.menu_pop.is_showing(), 20.0)
	await _game_wait(0.6)
	await _named_shot("chai_sheet", "menu")
	ui.close_all()
	await _game_wait(0.6)
	# 8) The unlock props: chai and lassi at L100, every pop played out.
	Game.debug_set_level("chai", 100)
	Game.debug_set_level("lassi", 100)
	await _wait_for(func() -> bool: return ui.menu_pop == null or not ui.menu_pop.is_showing(), 20.0)
	await _game_wait(0.8)
	await _wait_for(_no_cash_burst, 20.0)
	await _named_shot("unlock_props", "menu")
	# 9) The kadai sheet at L50: two chips unlocked with prices, two locked.
	Game.debug_set_level("kadai", 50)
	await _wait_for(func() -> bool: return ui.menu_pop == null or not ui.menu_pop.is_showing(), 20.0)
	ui.open_station("kadai")
	await _game_wait(1.5)
	await _named_shot("sheet_kadai", "menu")
	ui.close_all()
	await _game_wait(0.6)
	# 10) Every dish on the menu (tandoor and kadai to L100 too): bubbles
	# with the new icons, a tray with two new dishes, the tables, the whole
	# dhaba.
	Game.debug_set_level("tandoor", 100)
	Game.debug_set_level("kadai", 100)
	await _wait_for(func() -> bool: return ui.menu_pop == null or not ui.menu_pop.is_showing(), 20.0)
	camera_rig.fly_to(home_view() + Vector3(1.6, 0.0, -0.6), CameraRig.GAME)
	await _game_wait(1.0)
	await _wait_for(_menu_bubbles_moment, 150.0)
	await _named_shot("bubbles", "menu")
	await _menu_tray_shot()
	camera_rig.set_free()
	camera_rig.zoom_to(CameraRig.GAME, 0.3)
	camera_rig.fly_to(home_view(), CameraRig.GAME)
	await _game_wait(1.0)
	await _wait_for(_menu_tablefood_moment, 150.0)
	await _named_shot("tablefood", "menu")
	_frame_points(MENU_FULL_POINTS, MENU_TOP_PX, MENU_BOTTOM_PX, 14.0)
	await _game_wait(0.3)
	await _wait_for(_menu_full_moment, 150.0)
	await _named_shot("full", "menu")
	print("[main3] menu capture done at %.2f" % _game_t)
	get_tree().quit()


## --capture=menu framings (integration review shots): world points that
## _frame_points fits between the KAAM bar and the bottom of the screen.
const MENU_TOP_PX := 372.0
const MENU_BOTTOM_PX := 1272.0
## Close-up zoom per new station (the station's own points are centred).
const MENU_STATION_ZOOM := 0.66
## The LASSI board's frame corners (polish round 2: on the wall left of Bittu,
## v3_props.LASSI_BOARD_C), framed with the lassi close-ups.
const MENU_LASSI_BOARD_POINTS := [Vector3(0.045, 0.88, 4.36), Vector3(0.045, 0.23, 5.38)]
## The whole dhaba: Pinky and Gopi (heads + timers), the lassi counter's
## front and its board's words (polish round 2), the kadai cooks and its
## side counter, tables 1 and 2.
const MENU_FULL_POINTS := [Vector3(0.7, 1.75, 1.75), Vector3(0.7, 1.75, 4.2), Vector3(2.2, 0.0, 4.7), Vector3(0.045, 0.5, 5.1),
		Vector3(10.25, 1.75, 1.3), Vector3(11.15, 1.75, 1.3), Vector3(11.8, 0.0, 2.95),
		Vector3(6.9, 0.0, 7.5), Vector3(11.0, 0.0, 7.5)]
## Build-pad sheet: band height per pad (2 bands + 1 gap; was 3 pads).
const PAD_BAND_H := 424
const PAD_BAND_GAP := 4


## Close-up of station `id` once its cook is cooking and an item waits on
## its pass (waits for the build reveal first) -> menu_<id>.png.
func _menu_station_shot(id: String) -> void:
	var pts: Array = _station_points(id)
	if id == "lassi":
		pts.append_array(MENU_LASSI_BOARD_POINTS)
	_frame_points(pts, MENU_TOP_PX + 30.0, 1010.0, 40.0, MENU_STATION_ZOOM)
	await _game_wait(0.5)
	# (polish round 2: and no galla cash burst over the counter)
	if not await _wait_for(func() -> bool: return _menu_station_moment(id, true) and _no_cash_burst(), 90.0):
		await _wait_for(func() -> bool: return _menu_station_moment(id, false) and _no_cash_burst(), 30.0)
	await _named_shot(id, "menu")


## World points of station `id` for a close-up: its pass slots, the counter
## anchor and every cook slot's head with the timer above it.
func _station_points(id: String) -> Array:
	var pts: Array = []
	var a: Array = Layout3.PASS_POINTS.get(id, [])
	pts.append_array(a)
	for k in Layout3.MAX_STATION_STAFF:
		pts.append(Layout3.station_staff(id, k) + Vector3(0.0, 1.9, 0.0))
	pts.append(Layout3.station_pos(id))
	return pts


## Snaps the camera so every point of `pts` fits on screen between y
## `top_px` and `bottom_px` with `margin_px` at the sides (canvas pixels),
## centred; `fixed_mult` > 0 keeps that zoom instead of fitting it.
func _frame_points(pts: Array, top_px: float, bottom_px: float, margin_px: float, fixed_mult: float = -1.0) -> void:
	var right: Vector3 = camera_rig._right
	var up: Vector3 = camera_rig._up
	var r0: float = INF
	var r1: float = -INF
	var u0: float = INF
	var u1: float = -INF
	for v in pts:
		var p: Vector3 = v
		r0 = minf(r0, p.dot(right))
		r1 = maxf(r1, p.dot(right))
		u0 = minf(u0, p.dot(up))
		u1 = maxf(u1, p.dot(up))
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var mult: float = fixed_mult
	if mult <= 0.0:
		var k: float = minf((vs.x - 2.0 * margin_px) / maxf(r1 - r0, 0.01), (bottom_px - top_px) / maxf(u1 - u0, 0.01))
		mult = vs.y / (camera_rig.s_game * k)
	var kk: float = vs.y / (camera_rig.s_game * mult)
	var yc: float = (top_px + bottom_px) * 0.5
	var u_t: float = (u0 + u1) * 0.5 - (vs.y * 0.5 - yc) / kk
	var c: Vector3 = right * ((r0 + r1) * 0.5) + up * u_t
	camera_rig.snap(camera_rig._to_ground(c), mult)


## Station `id` revealed, a cook cooking and at least one item on its pass,
## with no waiter standing at its pickups (he would hide the pass); with
## `need_waiter`, also a waiter on screen within 4 m.
func _menu_station_moment(id: String, need_waiter: bool) -> bool:
	var st: StationNode = sim.get_station(id)
	if st == null or st.reveal_pending or st.pass_used() < 1:
		return false
	var run: bool = false
	for v in st.slots:
		if (v as StationNode.Slot).phase == StationNode.P.RUN:
			run = true
	if not run:
		return false
	var near: bool = false
	var pickups: Array = Layout3.PASS_PICKUPS.get(id, [])
	for w in sim.waiters:
		for q in pickups:
			if Vector2(w.position.x - (q as Vector3).x, w.position.z - (q as Vector3).z).length() < 0.5:
				return false
		if w.position.distance_to(Layout3.station_pos(id)) < 4.0 and camera_rig.is_on_screen(w.position, 60.0):
			near = true
	return near or not need_waiter


## Two waiters carrying whole orders, order bubbles on screen showing at
## least two of the new items, and no cash burst in flight.
func _menu_full_moment() -> bool:
	# no galla cash burst in flight (its bills would cover the drink corner)
	var bills: PackedByteArray = Fx._burst._alive
	if bills.has(1):
		return false
	var carrying: int = 0
	for w in sim.waiters:
		if w.state == Waiter.W.TO_TABLE and w.carried_count() >= 2 and camera_rig.is_on_screen(w.position, 40.0):
			carrying += 1
	if carrying < 2:
		return false
	var seen: Dictionary = {}
	for t in sim.travellers:
		if not is_instance_valid(t) or t.state != Traveller.S.SEATED:
			continue
		var k: String = str(t.get("_bubble_key"))
		if k == "" or not camera_rig.is_on_screen(t.position + Vector3(0.0, 1.4, 0.0), 40.0):
			continue
		for part in k.split("+", false):
			var did: String = str(part)
			var sid: String = did.get_slice(".", 0)
			if sid == "lassi" or sid == "kadai" or (did != Game.dish_at(sid, 0)):
				seen[did] = true
	return seen.size() >= 2


## HUD, its pills and the wall-ad bubble on / off (review sheets only).
func _set_overlays(on: bool) -> void:
	ui.hud.visible = on
	ui.hud._pill_layer.visible = on
	if ui.ad_bubble != null:
		ui.ad_bubble.visible = on and Game.ad_bubble_ready()


## The current frame without HUD overlays (canvas pixels, full width).
func _overlay_free_frame() -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	_set_overlays(false)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_set_overlays(true)
	if img == null or img.is_empty():
		return null
	return img


## Rows y0 .. y0 + h of an overlay-free frame.
func _overlay_free_band(y0: int, h: int) -> Image:
	var img: Image = await _overlay_free_frame()
	if img == null:
		return null
	return img.get_region(Rect2i(0, y0, img.get_width(), h))


## A band of the frame around the ghost pad of `id` and its price tag
## (PAD_BAND_H px tall, full width; HUD hidden for that frame), for the
## build-pad sheet.
func _pad_band(id: String) -> Image:
	var img: Image = await _overlay_free_frame()
	if img == null:
		return null
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var k: float = float(img.get_height()) / maxf(vs.y, 1.0)
	var cam: Camera3D = camera_rig.get_camera()
	var pad_y: float = cam.unproject_position(Layout3.station_pos(id)).y + 120.0
	var top: float = pad_y - 330.0
	if ui.build_tag != null and ui.build_tag.is_showing():
		top = minf(top, ui.build_tag.get_global_rect().position.y - 30.0)
	var h: int = PAD_BAND_H
	var y0: int = clampi(int(roundf(((top + pad_y) * 0.5) * k)) - h / 2, 0, img.get_height() - h)
	return img.get_region(Rect2i(0, y0, img.get_width(), h))


## menu_buildpads.png: the ghost pads (lassi, kadai) with their price tags, stacked.
func _save_pad_sheet(bands: Array) -> void:
	var hs: Array = []
	for b in bands:
		hs.append(PAD_BAND_H)
	_save_sheet(bands, hs, "menu_buildpads.png")


## Stacks image bands (heights `hs`, PAD_BAND_GAP px dark gaps) into
## <shot-dir>/<file_name>.
func _save_sheet(bands: Array, hs: Array, file_name: String) -> void:
	var w: int = 0
	var fmt: int = Image.FORMAT_RGBA8
	for b in bands:
		if b != null:
			w = maxi(w, (b as Image).get_width())
			fmt = (b as Image).get_format()
	if w == 0:
		print("[main3] shot %s skipped (no rendering)" % file_name)
		return
	var hh: int = PAD_BAND_GAP * (bands.size() - 1)
	for h in hs:
		hh += int(h)
	var sheet: Image = Image.create_empty(w, hh, false, fmt)
	sheet.fill(Color("2B2118"))
	var y: int = 0
	for i in bands.size():
		var b: Image = bands[i]
		if b != null:
			sheet.blit_rect(b, Rect2i(0, 0, b.get_width(), mini(b.get_height(), int(hs[i]))), Vector2i(0, y))
		y += int(hs[i]) + PAD_BAND_GAP
	var path: String = _globalize(_shot_dir).path_join(file_name)
	var err: Error = sheet.save_png(path)
	print("[main3] shot %s (game %.2f) -> %s %s" % [file_name, _game_t, path, "" if err == OK else "FAILED %d" % err])


## No galla cash burst in flight (its bills fly across the drink corner).
func _no_cash_burst() -> bool:
	return not Fx._burst._alive.has(1)


## Lassi churning and a waiter carrying lassi + roti toward a table on screen
## (and no galla cash burst in flight: galla 1's bills would cover the lassi
## counter, QA round 2).
func _menu_lassi_moment() -> bool:
	var bills: PackedByteArray = Fx._burst._alive
	if bills.has(1):
		return false
	var st: StationNode = sim.get_station("lassi")
	if st == null or st.reveal_pending:
		return false
	var churning: bool = false
	for v in st.slots:
		if (v as StationNode.Slot).phase == StationNode.P.RUN:
			churning = true
	if not churning:
		return false
	for w in sim.waiters:
		if w.state == Waiter.W.TO_TABLE and w.carried_count() >= 2 and _order_has(w.order, ["lassi", "tandoor"]) \
				and camera_rig.is_on_screen(w.position, 60.0):
			return true
	return false


## The kadai cooking and a waiter in the annex (pickup lane or walking in
## through the side gate).
func _menu_annex_moment() -> bool:
	for id: String in ["kadai"]:
		var st: StationNode = sim.get_station(id)
		if st == null or st.reveal_pending:
			return false
		var run: bool = false
		for v in st.slots:
			if (v as StationNode.Slot).phase == StationNode.P.RUN:
				run = true
		if not run:
			return false
	for w in sim.waiters:
		if w.position.x > 9.2 and w.position.x < 12.4 and w.position.z > 2.6 and w.position.z < 4.3:
			return true
	return false


## At least three two-icon bubbles on screen, two kinds or more, and (station
## menus) at least two of them showing a dish beyond its station's dish 1.
func _menu_bubbles_moment() -> bool:
	var keys: Dictionary = {}
	var n: int = 0
	var fresh: int = 0
	for t in sim.travellers:
		if not is_instance_valid(t) or t.state != Traveller.S.SEATED:
			continue
		var k: String = str(t.get("_bubble_key"))
		if k.count("+") >= 1 and camera_rig.is_on_screen(t.position + Vector3(0.0, 1.4, 0.0), 40.0):
			n += 1
			keys[k] = true
			if _new_dishes_in(k.split("+", false)) > 0:
				fresh += 1
	return n >= 3 and keys.size() >= 2 and fresh >= 2


## How many of these full dish ids are beyond their station's dish 1.
func _new_dishes_in(ids: PackedStringArray) -> int:
	var n: int = 0
	for v in ids:
		var did: String = str(v)
		var sid: String = did.get_slice(".", 0)
		if did != "" and did != Game.dish_at(sid, 0):
			n += 1
	return n


## Station menus: at least three different dishes beyond dish 1 served on
## the tables in view, from two stations or more (no galla cash burst in
## flight).
func _menu_tablefood_moment() -> bool:
	var bills: PackedByteArray = Fx._burst._alive
	if bills.has(1):
		return false
	var seen: Dictionary = {}
	var stations: Dictionary = {}
	for t in sim.travellers:
		if not is_instance_valid(t) or (t.state != Traveller.S.SEATED and t.state != Traveller.S.EATING):
			continue
		for v in t.tickets:
			var tk: StationNode.Ticket = v
			if tk == null or tk.state != StationNode.TK.SERVED or tk.item == null or not is_instance_valid(tk.item):
				continue
			if camera_rig.is_on_screen(tk.item.global_position, 60.0) and tk.item.global_position.y < 0.6 \
					and tk.dish_id != Game.dish_at(tk.station_id, 0):
				seen[tk.dish_id] = true
				stations[tk.station_id] = true
	return seen.size() >= 3 and stations.size() >= 2


## `ids`: station ids or full dish ids (station menus).
func _order_has(order: Array, ids: Array) -> bool:
	var have: Dictionary = {}
	for v in order:
		var tk: StationNode.Ticket = v
		if tk != null:
			have[tk.station_id] = true
			have[tk.dish_id] = true
	for id in ids:
		if not have.has(str(id)):
			return false
	return true


## No other waiter within 0.9 m of `w` (waiters walk through each other; a
## close-up shot waits for a clear moment).
func _waiter_alone(w: Waiter) -> bool:
	for o in sim.waiters:
		if o != w and Vector2(o.position.x - w.position.x, o.position.z - w.position.z).length() < 0.9:
			return false
	return true


## The tray mix (integration brief): with every new ticket forced to coffee /
## naan / chaas / kadai paneer (Game.debug_force_dish, cleared after), a
## mid-zoom floor view shot when one waiter carries coffee + naan and another
## chaas + paneer at the same time, both walking to a table on screen and
## clear of each other; after TRAY_MIX_WAIT s without that frame, the
## single-waiter close-up of _menu_tray_follow_shot instead.
const TRAY_MIX_WAIT := 150.0
const TRAY_MIX_FOCUS := Vector3(6.3, 0.0, 5.0)
const TRAY_MIX_ZOOM := 0.56
const TRAY_MIX_PAIRS := [["chai.coffee", "tandoor.naan"], ["lassi.chaas", "kadai.paneer"]]


func _menu_tray_shot() -> void:
	Game.debug_force_dish = {"chai": "coffee", "tandoor": "naan", "lassi": "chaas", "kadai": "paneer"}
	camera_rig.set_free()
	_frame_points([TRAY_MIX_FOCUS], MENU_TOP_PX, MENU_BOTTOM_PX, 0.0, TRAY_MIX_ZOOM)
	await _game_wait(0.5)
	if await _wait_for(_menu_tray_mix_moment, TRAY_MIX_WAIT):
		await _named_shot("tray", "menu")
	else:
		print("[main3] menu capture: no coffee + naan / chaas + paneer pair on screen together")
		await _menu_tray_follow_shot()
	Game.debug_force_dish = {}


## One waiter per TRAY_MIX_PAIRS pair carrying it toward a table, on screen
## with a 60 px margin, the two at least 1.4 m apart, no cash burst in flight.
func _menu_tray_mix_moment() -> bool:
	if not _no_cash_burst():
		return false
	var found: Array = []
	for pair in TRAY_MIX_PAIRS:
		var hit: Waiter = null
		for w in sim.waiters:
			if w.state == Waiter.W.TO_TABLE and w.carried_count() >= 2 and _order_has(w.order, pair) \
					and camera_rig.is_on_screen(w.position, 60.0) and camera_rig.is_on_screen(w.position + Vector3(0.0, 1.2, 0.0), 60.0):
				hit = w
				break
		if hit == null:
			return false
		found.append(hit)
	var a: Waiter = found[0]
	var b: Waiter = found[1]
	return Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length() >= 1.4


## Follows a waiter carrying two dishes beyond dish 1 on his tray (zoomed in;
## a coffee + naan or chaas + paneer pair is taken first, any two new dishes
## after 60 s) and shoots while he walks toward the camera with both items,
## like --capture=tray.
func _menu_tray_follow_shot() -> void:
	var t0: float = _game_t
	var w: Waiter = null
	while _game_t - t0 < 200.0:
		var strict: bool = _game_t - t0 < 60.0
		if w == null or w.order.is_empty() or not _tray_wanted(w.order, strict):
			w = null
			for cand in sim.waiters:
				if not cand.order.is_empty() and _tray_wanted(cand.order, strict):
					w = cand
					break
			if w == null:
				await get_tree().process_frame
				continue
			camera_rig.follow(w, 0.6)
			camera_rig.zoom_to(0.42, 0.3)
		var prev: Vector3 = w.position
		await get_tree().process_frame
		var d: Vector3 = w.position - prev
		if w.state == Waiter.W.TO_TABLE and w.carried_count() >= 2 and d.x + d.z > 0.001 and _waiter_alone(w):
			await _game_wait(0.3)
			if w.state == Waiter.W.TO_TABLE and _waiter_alone(w):
				await _named_shot("tray", "menu")
				return
	print("[main3] menu capture: no tray with two new dishes seen")
	await _named_shot("tray", "menu")


## A tray order worth the shot: coffee + naan or chaas + kadai paneer when
## `strict` (the integration brief's pairs), else any two dishes beyond their
## station's dish 1.
func _tray_wanted(order: Array, strict: bool) -> bool:
	if strict:
		return _order_has(order, ["chai.coffee", "tandoor.naan"]) or _order_has(order, ["lassi.chaas", "kadai.paneer"])
	var ids: PackedStringArray = PackedStringArray()
	for v in order:
		var tk: StationNode.Ticket = v
		if tk != null:
			ids.append(tk.dish_id)
	return ids.size() >= 2 and _new_dishes_in(ids) >= 2


# ================================================================ day / night + zoom (captures, test)
## --capture=daynight framing: a wide front view (gate, signboard, road,
## parking) and the home view.
const DN_WIDE_VIEW := Vector3(5.2, 0.0, 7.4)
const DN_WIDE_MULT := 1.75
const DN_SETTLE := 1.5


func _daynight_capture() -> void:
	DirAccess.make_dir_recursive_absolute(_globalize(_shot_dir))
	await _game_wait(1.0)
	if Game.galla_count() < 2:
		Game.buy_galla_hire()
	day_night.frozen = true
	day_night.set_phase(day_night.shot_phase("day"))
	camera_rig.snap(home_view(), CameraRig.GAME)
	await _game_wait(25.0)   # travellers seated, traffic on the road
	for label: String in ["dawn", "day", "dusk", "night"]:
		Game.hide_ad_bubble()
		day_night.set_phase(day_night.shot_phase(label))
		camera_rig.snap(DN_WIDE_VIEW, DN_WIDE_MULT)
		await _game_wait(DN_SETTLE)
		print("[main3] daynight %s: phase %.3f night %.2f band %s" % [label, day_night.phase, day_night.night, day_night.band()])
		await _named_shot(label, "daynight")
		camera_rig.snap(home_view(), CameraRig.GAME)
		await _game_wait(DN_SETTLE)
		await _named_shot(label + "_home", "daynight")
	print("[main3] daynight capture done at %.2f" % _game_t)
	get_tree().quit()


## --capture=zoom: the player zoom at its limits (through CameraRig.user_zoom,
## the wheel / magnify path).
func _zoom_capture() -> void:
	DirAccess.make_dir_recursive_absolute(_globalize(_shot_dir))
	await _game_wait(1.0)
	if Game.galla_count() < 2:
		Game.buy_galla_hire()
	day_night.frozen = true
	camera_rig.snap(home_view(), CameraRig.GAME)
	await _game_wait(20.0)
	Game.hide_ad_bubble()
	var chai: Vector3 = Layout3.station_pos("chai") + Vector3(0.0, 0.8, 0.0)
	camera_rig.snap(chai + Vector3(0.0, 0.0, 0.4), CameraRig.GAME)
	await _game_wait(0.3)
	camera_rig.user_zoom(camera_rig.zoom_min / camera_rig.get_size_mult(), camera_rig.unproject(chai))
	await _game_wait(1.0)
	print("[main3] zoom in: x%.2f" % camera_rig.get_size_mult())
	await _named_shot("in", "zoom")
	camera_rig.snap(ZOOM_OUT_VIEW, CameraRig.GAME)
	await _game_wait(0.3)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	camera_rig.user_zoom(camera_rig.zoom_max / camera_rig.get_size_mult(), vs * 0.5)
	await _game_wait(1.0)
	print("[main3] zoom out: x%.2f" % camera_rig.get_size_mult())
	await _named_shot("out", "zoom")
	get_tree().quit()


const ZOOM_OUT_VIEW := Vector3(5.6, 0.0, 10.4)

var _zt_taps: int = 0
var _zt_fails: int = 0


func _zt_check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_zt_fails += 1
	print("ZOOMTEST %s %s %s" % [label, "PASS" if ok else "FAIL", detail])


## Canvas (viewport) point -> window point for Input.parse_input_event.
func _to_win(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


func _zt_touch(idx: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = _to_win(p)
	e.pressed = down
	Input.parse_input_event(e)
	await get_tree().process_frame


## Moves finger `idx` from a to b in `steps` drag events (one per frame).
func _zt_drag(idx: int, a: Vector2, b: Vector2, steps: int) -> void:
	for i in steps:
		var e := InputEventScreenDrag.new()
		e.index = idx
		var p: Vector2 = a.lerp(b, float(i + 1) / float(steps))
		var q: Vector2 = a.lerp(b, float(i) / float(steps))
		e.position = _to_win(p)
		e.relative = p - q
		Input.parse_input_event(e)
		await get_tree().process_frame


## Two fingers at once: finger 0 a0 -> b0, finger 1 a1 -> b1.
func _zt_drag2(a0: Vector2, b0: Vector2, a1: Vector2, b1: Vector2, steps: int) -> void:
	for i in steps:
		var u: float = float(i + 1) / float(steps)
		for f in 2:
			var e := InputEventScreenDrag.new()
			e.index = f
			e.position = _to_win((a0 if f == 0 else a1).lerp(b0 if f == 0 else b1, u))
			Input.parse_input_event(e)
		await get_tree().process_frame


func _zt_wheel(p: Vector2, up: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	e.factor = 1.0
	e.position = _to_win(p)
	e.global_position = e.position
	Input.parse_input_event(e)
	var r := e.duplicate() as InputEventMouseButton
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame


## Pixels between where ground point g shows now and screen point p.
func _zt_err(g: Vector3, p: Vector2) -> float:
	return camera_rig.unproject(g).distance_to(p)


func _run_zoom_test() -> void:
	await _game_wait(1.0)
	if not Game.is_tutorial_done():
		print("ZOOMTEST needs --skip-tutorial")
		print("ZOOMTEST fails=99")
		get_tree().quit(99)
		return
	day_night.frozen = true
	world_input.tapped.connect(func(_id: String, _p: Vector3) -> void: _zt_taps += 1)
	world_input.tapped_nothing.connect(func(_p: Vector2) -> void: _zt_taps += 1)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var mid := Vector2(vs.x * 0.42, vs.y * 0.55)
	var zmin: float = camera_rig.zoom_min
	var zmax: float = camera_rig.zoom_max
	print("ZOOMTEST viewport %s, limits x%.2f..x%.2f, wheel x%.3f" % [str(vs), zmin, zmax, camera_rig.wheel_step])

	# 1. Pinch OUT (fingers apart 120 -> 240 px): zoom in x0.5 about the midpoint.
	camera_rig.snap(home_view(), CameraRig.GAME)
	await _game_wait(0.3)
	var g: Vector3 = camera_rig.screen_to_ground(mid)
	var m0: float = camera_rig.get_size_mult()
	await _zt_touch(0, mid + Vector2(-60, 0), true)
	await _zt_touch(1, mid + Vector2(60, 0), true)
	await _zt_drag2(mid + Vector2(-60, 0), mid + Vector2(-120, 0), mid + Vector2(60, 0), mid + Vector2(120, 0), 10)
	var m1: float = camera_rig.get_size_mult()
	_zt_check("pinch_out_zooms_in", absf(m1 - maxf(zmin, m0 * 0.5)) < 0.01, "x%.3f -> x%.3f (want x%.3f)" % [m0, m1, maxf(zmin, m0 * 0.5)])
	_zt_check("pinch_out_anchor", _zt_err(g, mid) < 2.0, "midpoint ground drift %.2f px" % _zt_err(g, mid))
	# lift finger 1, then move finger 0 (must NOT pan), then lift it (no tap).
	var tgt: Vector3 = camera_rig.target_point()
	await _zt_touch(1, mid + Vector2(120, 0), false)
	await _zt_drag(0, mid + Vector2(-120, 0), mid + Vector2(-40, 90), 8)
	await _zt_touch(0, mid + Vector2(-40, 90), false)
	await _game_wait(0.4)
	_zt_check("after_pinch_no_pan", camera_rig.target_point().distance_to(tgt) < 0.001, "target moved %.4f m" % camera_rig.target_point().distance_to(tgt))
	_zt_check("after_pinch_no_inertia", not camera_rig.is_busy(), "busy %s" % camera_rig.is_busy())
	_zt_check("pinch_no_tap", _zt_taps == 0 and ui.current_panel == "", "taps %d panel '%s'" % [_zt_taps, ui.current_panel])

	# 2. Pinch IN (240 -> 120 px): zoom out x2 about another midpoint.
	var mid2 := Vector2(vs.x * 0.6, vs.y * 0.4)
	g = camera_rig.screen_to_ground(mid2)
	m0 = camera_rig.get_size_mult()
	await _zt_touch(0, mid2 + Vector2(0, -120), true)
	await _zt_touch(1, mid2 + Vector2(0, 120), true)
	await _zt_drag2(mid2 + Vector2(0, -120), mid2 + Vector2(0, -60), mid2 + Vector2(0, 120), mid2 + Vector2(0, 60), 10)
	m1 = camera_rig.get_size_mult()
	_zt_check("pinch_in_zooms_out", absf(m1 - minf(zmax, m0 * 2.0)) < 0.01, "x%.3f -> x%.3f" % [m0, m1])
	_zt_check("pinch_in_anchor", _zt_err(g, mid2) < 2.0, "drift %.2f px" % _zt_err(g, mid2))
	# 3. Two-finger pan: both fingers move (+80, +50): the ground follows.
	g = camera_rig.screen_to_ground(mid2)
	var d := Vector2(80, 50)
	await _zt_drag2(mid2 + Vector2(0, -60), mid2 + Vector2(0, -60) + d, mid2 + Vector2(0, 60), mid2 + Vector2(0, 60) + d, 8)
	_zt_check("two_finger_pan", _zt_err(g, mid2 + d) < 2.0, "drift %.2f px" % _zt_err(g, mid2 + d))
	await _zt_touch(0, mid2 + Vector2(0, -60) + d, false)
	await _zt_touch(1, mid2 + Vector2(0, 60) + d, false)
	await _game_wait(0.4)
	_zt_check("pinch2_no_tap", _zt_taps == 0 and ui.current_panel == "", "taps %d" % _zt_taps)

	# 4. Drag in progress, then a second finger: the drag stops dead, no jump.
	camera_rig.snap(home_view(), CameraRig.GAME)
	await _game_wait(0.3)
	var a := Vector2(vs.x * 0.5, vs.y * 0.6)
	await _zt_touch(0, a, true)
	await _zt_drag(0, a, a + Vector2(0, 60), 2)    # past the tap slop: the drag starts
	g = camera_rig.screen_to_ground(a + Vector2(0, 60))
	await _zt_drag(0, a + Vector2(0, 60), a + Vector2(0, 120), 4)
	_zt_check("drag_pans_1to1", _zt_err(g, a + Vector2(0, 120)) < 2.0, "drift %.2f px" % _zt_err(g, a + Vector2(0, 120)))
	tgt = camera_rig.target_point()
	await _zt_touch(1, a + Vector2(150, 0), true)
	await _game_wait(0.3)
	_zt_check("drag_then_pinch_no_jump", camera_rig.target_point().distance_to(tgt) < 0.001 and not camera_rig.is_dragging(),
			"moved %.4f m, dragging %s" % [camera_rig.target_point().distance_to(tgt), camera_rig.is_dragging()])
	await _zt_touch(1, a + Vector2(150, 0), false)
	await _zt_touch(0, a + Vector2(0, 120), false)
	await _game_wait(0.4)
	_zt_check("drag_pinch_no_tap", _zt_taps == 0, "taps %d" % _zt_taps)

	# 5. A plain fling still glides (inertia kept).
	camera_rig.snap(home_view(), CameraRig.GAME)
	await _game_wait(0.3)
	await _zt_touch(0, a, true)
	await _zt_drag(0, a, a + Vector2(-200, 0), 4)
	await _zt_touch(0, a + Vector2(-200, 0), false)
	var t0: Vector3 = camera_rig.target_point()
	await get_tree().process_frame
	await get_tree().process_frame
	_zt_check("fling_inertia", camera_rig.target_point().distance_to(t0) > 0.0005, "glide %.4f m" % camera_rig.target_point().distance_to(t0))
	await _game_wait(1.0)

	# 6. Mouse wheel about the cursor, eased.
	camera_rig.snap(home_view(), CameraRig.GAME)
	await _game_wait(0.3)
	var c := Vector2(vs.x * 0.3, vs.y * 0.35)
	g = camera_rig.screen_to_ground(c)
	await _zt_wheel(c, true)
	await _game_wait(0.6)
	_zt_check("wheel_up_zooms_in", absf(camera_rig.get_size_mult() - 1.0 / camera_rig.wheel_step) < 0.002, "x%.3f" % camera_rig.get_size_mult())
	_zt_check("wheel_anchor", _zt_err(g, c) < 2.0, "drift %.2f px" % _zt_err(g, c))
	await _zt_wheel(c, false)
	await _zt_wheel(c, false)
	await _game_wait(0.6)
	_zt_check("wheel_down_zooms_out", absf(camera_rig.get_size_mult() - camera_rig.wheel_step) < 0.002, "x%.3f" % camera_rig.get_size_mult())
	# 7. Trackpad magnify (factor 1.5 = zoom in) about another point.
	var c2 := Vector2(vs.x * 0.7, vs.y * 0.7)
	g = camera_rig.screen_to_ground(c2)
	m0 = camera_rig.get_size_mult()
	var mg := InputEventMagnifyGesture.new()
	mg.factor = 1.5
	mg.position = _to_win(c2)
	Input.parse_input_event(mg)
	await _game_wait(0.6)
	_zt_check("magnify_zooms_in", absf(camera_rig.get_size_mult() - m0 / 1.5) < 0.002, "x%.3f -> x%.3f" % [m0, camera_rig.get_size_mult()])
	_zt_check("magnify_anchor", _zt_err(g, c2) < 2.0, "drift %.2f px" % _zt_err(g, c2))
	# 8. Limits.
	for i in 30:
		await _zt_wheel(c, false)
	await _game_wait(0.8)
	_zt_check("limit_max", absf(camera_rig.get_size_mult() - zmax) < 0.001, "x%.3f" % camera_rig.get_size_mult())
	for i in 40:
		await _zt_wheel(c, true)
	await _game_wait(0.8)
	_zt_check("limit_min", absf(camera_rig.get_size_mult() - zmin) < 0.001, "x%.3f" % camera_rig.get_size_mult())
	_zt_check("wheel_no_tap", _zt_taps == 0, "taps %d" % _zt_taps)

	# 9. Taps on stations at both limits; the sheet keeps / restores the zoom.
	var chai := Vector3(1.70, 0.80, 1.75)
	for z in [zmin, zmax]:
		ui.close_all()
		await _game_wait(0.4)
		camera_rig.snap(Vector3(chai.x, 0.0, chai.z + 1.0), CameraRig.GAME)
		camera_rig.user_zoom(float(z) / camera_rig.get_size_mult(), vs * 0.5)
		await _game_wait(0.6)
		var mz: float = camera_rig.get_size_mult()
		var tp: Vector3 = camera_rig.target_point()
		_send_tap(camera_rig.unproject(chai))
		await _game_wait(0.6)
		_zt_check("tap_chai_x%.2f" % mz, ui.current_panel == "station:chai", "panel '%s'" % ui.current_panel)
		_zt_check("sheet_keeps_zoom_x%.2f" % mz, absf(camera_rig.get_size_mult() - mz) < 0.001, "x%.3f" % camera_rig.get_size_mult())
		ui.close_all()
		await _game_wait(0.6)
		_zt_check("sheet_restore_x%.2f" % mz, absf(camera_rig.get_size_mult() - mz) < 0.001 and camera_rig.target_point().distance_to(tp) < 0.01,
				"x%.3f, target off %.3f m" % [camera_rig.get_size_mult(), camera_rig.target_point().distance_to(tp)])
		_zt_taps = 0

	# 10. Locked input (tutorial-style): no zoom.
	camera_rig.snap(home_view(), CameraRig.GAME)
	camera_rig.input_locked = true
	await _zt_wheel(c, true)
	await _game_wait(0.4)
	_zt_check("locked_no_zoom", absf(camera_rig.get_size_mult() - CameraRig.GAME) < 0.0001, "x%.3f" % camera_rig.get_size_mult())
	camera_rig.input_locked = false
	print("ZOOMTEST fails=%d" % _zt_fails)
	get_tree().quit(_zt_fails)


# ================================================================ Munshi-ji bust (capture)
## --capture=munshi: pose -> sample line id (its text), entrances
## [label, enter, box_side].
const MUNSHI_SHOT_LINES := {"idle": "l1", "cheer": "l10", "worried": "lw1", "point": "lw2",
		"namaste": "l1", "ledger": "l4", "chai": "l7"}
const MUNSHI_SHOT_ENTERS := [["right", "right", ""], ["bottom", "bottom", ""], ["left", "right", "left"],
		["bottomright", "bottom_right", "right"]]


func _munshi_capture() -> void:
	DirAccess.make_dir_recursive_absolute(_globalize(_shot_dir))
	day_night.frozen = true
	await _game_wait(2.0)
	await _munshi_model_sheet()
	Game.hide_ad_bubble()
	for pose: String in MunshiBust.POSES:
		for e: Array in MUNSHI_SHOT_ENTERS:
			var line: Dictionary = ScriptLines.line(str(MUNSHI_SHOT_LINES.get(pose, "l1")))
			line["id"] = "munshi_capture"
			line["pose"] = pose
			line["enter"] = str(e[1])
			line["box_side"] = str(e[2])
			line["chain"] = []
			line["then_pose"] = ""
			line["pause_sim"] = false
			dialogue.play([line])
			await _game_wait(0.42)
			await _named_shot("%s_%s_mid" % [pose, e[0]], "munshi")
			await _game_wait(1.1)
			await _named_shot("%s_%s" % [pose, e[0]], "munshi")
			dialogue.close()
			while dialogue.is_open():
				await get_tree().process_frame
			await _game_wait(0.2)
	_munshi_contact_sheets()
	print("[main3] munshi capture done at %.2f" % _game_t)
	get_tree().quit()


## --capture=munshi: the settled shots at 1/3 size, three poses (rows) x the
## entrances (columns) per sheet -> DIR/munshi_sheet_<n>.png.
func _munshi_contact_sheets() -> void:
	var dir: String = _globalize(_shot_dir)
	var cw := 240
	var ch := 427
	var poses: Array = MunshiBust.POSES
	var n := 0
	for start in range(0, poses.size(), 3):
		var rows: Array = poses.slice(start, start + 3)
		var sheet := Image.create(cw * MUNSHI_SHOT_ENTERS.size(), ch * rows.size(), false, Image.FORMAT_RGBA8)
		for r in rows.size():
			for c in MUNSHI_SHOT_ENTERS.size():
				var path: String = dir.path_join("munshi_%s_%s.png" % [rows[r], MUNSHI_SHOT_ENTERS[c][0]])
				if not FileAccess.file_exists(path):
					continue
				var img := Image.load_from_file(path)
				img.convert(Image.FORMAT_RGBA8)
				img.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
				sheet.blit_rect(img, Rect2i(0, 0, cw, ch), Vector2i(c * cw, r * ch))
		n += 1
		sheet.save_png(dir.path_join("munshi_sheet_%d.png" % n))


## The pose glbs as exported (no bust camera / rig), side by side.
func _munshi_model_sheet() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var poses: Array = ["idle", "cheer", "worried", "point", "namaste", "ledger", "chai"]
	var vp := SubViewport.new()
	vp.size = Vector2i(2500, 520)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.87, 0.86, 0.83)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	var cam := Camera3D.new()
	cam.environment = env
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	cam.current = true
	var span := 1.4
	cam.position = Vector3(span * (poses.size() - 1) * 0.5, 0.58, 10.0)
	cam.size = 2.2
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 20.0, 0.0)
	key.light_energy = 0.8
	vp.add_child(key)
	for i in poses.size():
		var m: Node3D = Models.make("munshi_" + str(poses[i]))
		m.position = Vector3(span * i, 0.0, 0.0)
		vp.add_child(m)
	await _game_wait(0.3)
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var path: String = _globalize(_shot_dir).path_join("munshi_models.png")
	img.save_png(path)
	print("[main3] shot models -> %s" % path)
	vp.queue_free()
