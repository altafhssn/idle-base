class_name Director
extends Node
## Tutorial step machine (spec §2 timeline + §7 script + critic corrections).
## Reproduces the reference's first ~162 s beat for beat with Munshi-ji, with
## the seated-dhaba flow (user change 2026-10-19: travellers sit on charpais,
## the cook brews a ticket, waiter Raju carries it from the pass):
##
##   intro (L1–L2) → fly to the parked lorry + FOLLOW the scripted traveller
##   to a free seat → he sits (traveller_seated) → Pinky starts his ticket
##   (ticket_started): SETTLE ×1.14 on the chai counter (seat kept in frame
##   when close), gate on settle + 0.05 s → L3 (pause_sim, Pinky + Raju) →
##   zoom back in, hold on the counter → kulhad on the pass / Raju dispatched
##   (item_ready / waiter_picked): FOLLOW Raju to the charpai → served
##   (item_served): FOLLOW the traveller (eats 3 s, walks to the galla) →
##   galla timer pops: SETTLE ×1.12 →
##   L4 (pause_sim) → first sale → +0.3 s L5–L6 → TUTORIAL FOCUS on the chai
##   counter, marker +0.2 s → G1 tap → sheet (HUD reveal 3) → +0.45 s hand on
##   LEVEL UP with the "n/10" caption, the sheet's bar reads "GOAL Lv 10" → G2
##   level 10 → L7 over the sheet → G3 hand on the sheet's X → close →
##   TRANSFER (inject 5 into galla 1, spawns resume, HUD reveal 4) → arrival
##   + 0.05 s → L8–L9 → marker on the cash counter → G4 tap → cash floor 100
##   → hand on HIRE → G5 hired → hand on X → closed → +0.5 s L10 →
##   WAITER BEAT (UX fix A9 / D3, checkpoint "waiter"): fly to the tray rack →
##   LW1–LW2 → the WAITERS rack tag appears (it already shows during LW2),
##   hand on the tag (a marker over the rack only if the tag is missing) →
##   WAITERS opens → cash floor = the hire cost (a visible "+n from
##   Munshi-ji" gift only when the cash is short) → hand on HIRE → hired →
##   hand on X → closed → fly home → LW3, L12 (TASKS bar drops in with a
##   pulsing ring; the hand only on a claimable card) → chain end: HUD
##   reveal 6, free play.
##   SEATS BEAT (free play, checkpoint "seats"): the first door line that
##   lasts 2 s (a prewarm of 6 at 45 s if none came, skipped at 90 s) → LT1
##   over the home view (full seats, the door line) → LT2 while the camera
##   flies to the next ghost table and its ADD TABLE tag pops in → hand on
##   the tag → SEATING opens → cash floor = the table cost → hand on ADD →
##   table added → the new table pops in, then the camera flies home.
##   First task claim (+0.17 s; remembered until the seats beat is done;
##   fallback if the player never claims) → L14 (no dim, HUD extras hidden) →
##   ad bubble (looping countdown) → hand on it → FREE CASH popup (no ₹299
##   offer in session 1, D7) → hand on ▶ WATCH AD → reward → +0.3 s L15–L16 →
##   HUD back → hand on BUILD → BUILD › TANDOOR → built → hand on X → closed →
##   fly home → +0.2 s L17 → done (free play, auto ad bubbles on; the NEXT
##   chip shows itself, MunshiNotes runs the drag hint).
##   Round 2 step 1: allows_next_chip() lets the NEXT chip show its goal
##   ("NEXT: TANDOOR · Save …") in the free step whenever no line is up, so
##   there is no stretch without a goal. If the player builds the tandoor
##   from it before the ad chain, L16 ("We can afford a TANDOOR now") is
##   left out and the chain goes from L15 straight to L17.
##   Round 2 step 2 (0.3.4, docs/round2/ui-proposal.md §3.7; owner decisions
##   4 and 5: STAFF for people, BUILD for things, controls appear when first
##   needed). Supersedes the waiter / L12 / seats parts above:
##   - Cashier beat: the cash counter opens STAFF › CASHIERS (panel kind
##     "staff"; only HIRE and the X work there). As it closes, Game.reveal_hud
##     ("staff") brings the STAFF button in with its gold burst, and L10
##     ("… All your staff are in STAFF.") rings it.
##   - Waiter beat, problem first: Sim.inject_orders(3) seats three
##     travellers at once (as many as there are free seats); LW1 waits
##     until WAITER_PLATES plates sit on the pass with orange wait rings
##     (WAITER_PLATES_TIMEOUT at most). No pause_sim (it would freeze
##     travellers on the road crossing while the traffic runs). LW2 "Tap
##     STAFF and HIRE a second waiter." rings STAFF; then the hand on STAFF
##     (S_TAP_STAFF; a tap on the rack or a waiter opens it too) -> STAFF ›
##     WAITERS (switched there if it opened on another tab) -> hand on HIRE
##     -> hired -> hand on X -> home, LW3. No rack tag, no S_TAP_RACK.
##   - TASKS are out of the chain (no L12): in the free step the first
##     claimable task reveals the one-task strip (Game.reveal_hud("tasks");
##     MunshiNotes shows the non-blocking "Task done! Tap CLAIM" chip). Its
##     claim still starts the ad chain.
##   - Seats beat: LT2 "Tap the new TABLE: four more seats." over the ghost
##     table's "+ TABLE" tag -> its 2-tap card (panel "quick:tables"; BUILD ›
##     TABLES when the player goes there) -> hand on BUILD -> the table.
##     The 45 s nudge prewarms the free seats + SEATS_NUDGE_EXTRA, so a
##     door line forms every time (was a fixed 6: skipped in about half).
##     Fix round 1: when diners who finish free their seats as the nudged
##     travellers walk in (seed 74: 7 sent, door line 0 for 45 s), a
##     top-up nudge follows every SEATS_RENUDGE_S (it also counts half the
##     seated diners), SEATS_NUDGES in all; the skip moves to
##     SEATS_SKIP_AT = 110 s.
##   - BUILD appears as L16 says "Tap BUILD" (Game.reveal_hud("build"), the
##     HUD keeps that button through the line, so its burst is seen).
##   - The gear, and STAFF / BUILD when a beat was skipped, come with the
##     tutorial's end (Game's own reveal rules).
##   Core and feel (W3-TUT, build plan revision 2). Supersedes the waiter,
##   seats and ad parts above where they differ:
##   - C2.6: the bottleneck meter is revealed as the waiter beat starts
##     (Game.reveal_hud("meter") on entering waiter_lines, ~1:17; the HUD
##     prints "[hud] meter revealed at <t>"); lesson_stage() says which row
##     it pulses: "waiters" from waiter_lines to waiter_done, "seats" from
##     seats_lines to seats_done, else "".
##   - C3.1: the waiter is hired in the world. LW2 ("Tap the new WAITER,
##     then HIRE.") unlocks UiRoot's "+ WAITER" tag over the ghost waiter and
##     rings it; tap_staff points the hand at the tag; the tag opens the
##     2-tap card (panel "quick:waiters") by the oldest waiting plate; the
##     hand goes on its HIRE. A card hire skips close_waiters (UiRoot closes
##     the card itself): the camera holds on the pass WAITER_HIRE_HOLD s
##     while the new waiter takes the oldest plate, then flies home for LW3
##     ("[tutorial] waiter beat: hired via card"). STAFF, the rack and the
##     waiters still open STAFF › WAITERS, and that path is unchanged.
##   - C2.3: plates held on the plate stool count as waiting plates.
##   - C4.1: the seats lesson always fires. SEATS_FILL_AT s into the free
##     step with no door line and the player idle,
##     Sim.fill_for_seats_beat(SEATS_FILL_DOOR) fills every free seat and
##     stands travellers at the gate (the line waits: C2.1); the door-line
##     trigger then plays LT1 / LT2 within free + 8 s ("[tutorial] seats
##     beat: filled <n>"). A gate line that drains first (diners leave, or a
##     panel was open) is filled again once the player is idle, up to
##     SEATS_FILLS fills (W3-FIX). No prewarm nudges and no "no_door_line"
##     skip any more: tutorial_seats_skipped {why: "fill_failed"} only from
##     SEATS_FAILSAFE_AT on, with no door line, once the fill placed nobody
##     or every fill is spent (or at the SEATS_GIVEUP_AT backstop); the
##     "tables_max" skip stays.
##   - C7.2: with no rewarded ad ready at the ad beat, L14, L15 and the
##     bubble are left out ("[tutorial] ad beat skipped: no ad"): ad_deal
##     goes straight to the BUILD beat, which says L16 itself.
##   - The meter's taps (meter_row, meter_road), event_button and home_hall
##     are never in a beat's allow list (they work only where "*" is).
## W4-FIX (final review):
##   - Munshi-ji's top-up before the waiter, table and tandoor purchases
##     (_gift_once, tutorial keys "gift_waiter" / "gift_table" /
##     "gift_tandoor") is given at most once per beat and save: re-entering
##     the beat (the card closed, the cash spent in a sheet) does not grant
##     it again. The Sim keeps selling, so the purchase stays reachable.
##   - waiter_lines and ad_deal close a panel the player opened during their
##     waits before the lines (LW1 / LW2, L14) play; ad_deal also blocks the
##     HUD buttons during its wait (up to 1 s + AD_READY_WAIT on a relaunch).
##   - The free step does not count the analytics consent card as idle, so
##     the nudge hand and the fallback ad chain wait for its answer.
##   - Closing FREE BONUS without the video is a decline (rewarded ads are
##     opt-in): the beat moves on to L15 / L16 and the BUILD beat ("[tutorial]
##     ad beat: FREE BONUS closed without the video").
## Dhaba growth step 4 (7 Nov, docs/growth/plan.md; owner: a 3-minute shack
## build with one free FINISH NOW). A new game starts on the chai cart
## (Game.stage() 0): L1c instead of L1, the first traveller, the first sale
## and the chai lesson run as before, then (instead of the transfer) the
## GROW BEAT, checkpoint "grow": spawns resume and the camera goes home, G1
## ("Chai is selling fast! This cart needs a roof now."), G2 brings BUILD in
## and names it -> hand on BUILD -> hand on THE SHACK's BUILD (a one-time
## top-up "gift_shack" keeps it affordable) -> the construction starts
## (Game.build_job_changed) -> fly to the site, G3 -> hand on the tag's
## "FINISH NOW · FREE" -> Game finishes the build, saves and the scene reloads
## as the shack -> checkpoint "shack": the reveal plays, then "shack_done",
## then the transfer and every later beat exactly as before (the shack has a
## second cash counter, waiter and table). If the player waits instead, the
## build finishes by time and the same reload follows. A game that starts on
## the dhaba (old saves) never sees the grow beat.
##
## hold_spawns is on from the start until the transfer (nobody else walks in
## between the first sale and the transfer — critic). Pause dialogues are
## gated on the camera's settle + 0.05 s, not on a timer percentage. Line 14
## does not wait for the claim count-up. Tutorial-chain dialogue keeps the
## already-revealed HUD extras; only the post-claim chain hides them.
##
## Save/resume: Game.tutorial["step"] holds the last checkpoint (CHECKPOINTS);
## a resumed game re-enters at that beat (derived from the economy state
## where possible). Game.tutorial["done"] ends it for good.
##
## Every other module is reached through Refs and tolerated when null.
## Resume (UX fix): "hired" / "waiter" land in the waiter beat while fewer
## than 2 waiters are hired (an old save from before the fix at "hired" or
## "free" too), else LW3/L12 is skipped to L12 only; "seats" resumes free play
## with the seats beat done.
##
## Sim signals the walk beats listen to (each connected only if it exists;
## argument lists may vary — handlers take up to 6 Variants and find the
## Traveller / waiter among them, or inside a ticket object / Dictionary via
## its `traveller` / `customer` / `waiter` field):
##   traveller_seated(...)            → he sat down (also traveller_sat, and
##                                      the Traveller's own seated / sat_down)
##   ticket_started(...)              → the cook started his ticket (also
##                                      station_service_started, and the chai
##                                      StationNode's service_started)
##   item_ready(...)                  → the item is on the pass (also
##                                      item_cooked, ticket_done,
##                                      StationNode.service_done)
##   waiter_assigned / waiter_dispatched(...) → a waiter is heading for it
##   waiter_picked(...)               → the waiter lifted it onto his tray
##                                      (also item_picked)
##   item_served(...)                 → the item is on his table (also
##                                      item_delivered, waiter_served, and the
##                                      Traveller's food_served / item_served /
##                                      got_food)
##   galla_service_started(...)       → the galla timer popped (also galla 1's
##                                      GallaNode.service_started)
##   sale(...) / first_sale / Traveller.paid → the first bill is in
## Watchdogs behind the signals (a missing or renamed signal degrades to the
## old timing instead of soft-locking the tutorial):
##   - the traveller's FSM state name, read at runtime from his script's `S`
##     enum (SEATED_STATES / FED_STATES / PAY_STATES);
##   - Traveller.is_seated() or a bool `seated` property; the chai
##     StationNode's is_busy() once he is seated (= his ticket is cooking);
##   - positions: still inside the dhaba at a Layout3.SEATS spot (read at
##     runtime) = seated; Raju walking during the brew = dispatched; the
##     traveller sitting still then walking = served; still at the galla pay
##     spot = at the galla;
##   - per-beat timeouts.
## The waiter to follow comes from the signal args, else Sim.waiters[0], else
## Sim.get_waiter(0), else a character under the Sim named / classed "waiter"
## or Game.waiter_staff_name(0) ("Raju"); searched again every 0.5 s while
## missing.

signal step_changed(step: String)
signal finished
## The ad-deal beat wants the wall-ad bubble now (Game.show_ad_bubble is
## also called; this is for UI that prefers a signal).
signal ad_bubble_requested

# ------------------------------------------------------------------ steps
const S_IDLE := "idle"
const S_INTRO := "intro"
const S_FOLLOW := "follow"
const S_SEATED := "seated"
const S_CHAI_PAUSE := "chai_pause"
const S_BREW := "brew"
const S_DELIVER := "deliver"
const S_TO_GALLA := "to_galla"
const S_GALLA_PAUSE := "galla_pause"
const S_WAIT_SALE := "wait_sale"
const S_FIRST_SALE := "first_sale"
const S_TAP_CHAI := "tap_chai"
const S_LEVEL := "level"
const S_LINE7 := "line7"
const S_TAP_OUT := "tap_out"
const S_TRANSFER := "transfer"
const S_GROW_LINES := "grow_lines"
const S_GROW_BTN := "grow_btn"
const S_GROW_ROW := "grow_row"
const S_GROW_SITE := "grow_site"
const S_SHACK_OPEN := "shack_open"
const S_TAP_GALLA := "tap_galla"
const S_HIRE := "hire"
const S_CLOSE_GALLA := "close_galla"
const S_WRAP := "wrap"
const S_WAITER_LINES := "waiter_lines"
## Round 2 step 2: the hand on the HUD STAFF button (was S_TAP_RACK).
const S_TAP_STAFF := "tap_staff"
const S_HIRE_WAITER := "hire_waiter"
const S_CLOSE_WAITERS := "close_waiters"
const S_WAITER_DONE := "waiter_done"
const S_FREE := "free"
const S_SEATS_LINES := "seats_lines"
const S_TAP_TABLE := "tap_table"
const S_ADD_TABLE := "add_table"
const S_SEATS_DONE := "seats_done"
const S_AD_DEAL := "ad_deal"
const S_BUBBLE := "bubble"
const S_VIP := "vip"
const S_AD_LINES := "ad_lines"
const S_BUILD_BTN := "build_btn"
const S_BUILD_ROW := "build_row"
const S_BUILD_CLOSE := "build_close"
const S_OUTRO := "outro"
const S_DONE := "done"

## Saved checkpoints, in order.
const CHECKPOINTS := ["intro", "first_sale", "grow", "shack", "transfer", "hired", "waiter", "free", "seats", "ad_deal", "build", "done"]
## Steps that keep the marker alive (it is cleared on any other step).
const KEEP_MARKER := ["tap_chai", "level", "tap_galla", "hire"]
## The seats beat's steps (a claim during them is remembered).
const SEATS_STEPS := ["seats_lines", "tap_table", "add_table", "seats_done"]
## The scripted first-traveller beats: Sim events only count while one of
## these runs (nobody else is in the dhaba then — hold_spawns).
const WALK_STEPS := ["follow", "seated", "chai_pause", "brew", "deliver", "to_galla", "galla_pause", "wait_sale"]
## Fields of a ticket object / Dictionary that may hold its traveller / waiter.
const TRAV_KEYS := ["traveller", "customer", "for_traveller", "guest", "diner", "owner"]
const WAITER_KEYS := ["waiter", "carrier", "runner", "assigned_waiter"]
## Traveller FSM state names (Traveller.S keys, read at runtime) that mean
## "sitting at a charpai" / "has his food (or is past it)" / "the galla timer
## runs". Used only as watchdogs behind the Sim signals.
const SEATED_STATES := ["SEATED", "SITTING", "SIT", "AT_SEAT", "ORDERED", "ORDERING",
		"WAIT_FOOD", "WAITING_FOOD", "WAIT_ITEM", "WAITING_ITEM"]
const FED_STATES := ["EATING", "EAT", "TO_GALLA", "GALLA_QUEUE"]
const PAY_STATES := ["PAYING"]
const LAYOUT_PATH := "res://scripts/v3/world/layout3.gd"

# ------------------------------------------------------------------ HUD reveal (spec 4.1)
const REVEAL_PILL := 1
const REVEAL_MONEY := 2
const REVEAL_RATE := 3
const REVEAL_MANAGER := 4
const REVEAL_TASKS := 5
const REVEAL_FULL := 6

# ------------------------------------------------------------------ tuning
const LEVEL_GATE := 10
const HIRE_FLOOR := 100.0
const INJECT_COUNT := 5
## The injected galla line appears this long into the transfer flight.
const INJECT_DELAY := 0.5
const INTRO_DELAY := 0.25
## Fly starts 0.69 s after the dismissing tap; `closed` arrives 0.2 s after it.
const FLY_DELAY := 0.49
const FLY_TIMEOUT := 0.9
const SETTLE_GATE := 0.05
const SETTLE_TIMEOUT := 0.8
const STATION_SETTLE_ZOOM := 1.14
const GALLA_SETTLE_ZOOM := 1.12
const TRANSFER_TIMEOUT := 1.3
const AFTER_SALE := 0.3
const MARKER_DELAY := 0.2
const HAND_DELAY := 0.45
const RETARGET_PAUSE := 0.15
const WRAP_DELAY := 0.5
const CLAIM_TO_LINE := 0.17
const REWARD_TO_LINE := 0.3
const OUTRO_DELAY := 0.2
## Outro after the BUILD beat: how long the camera stays on the new tandoor
## before flying home, and where on screen the tandoor sits meanwhile.
const OUTRO_TANDOOR_S := 2.0
const OUTRO_TANDOOR_SCREEN := Vector2(0.5, 0.32)
const BUBBLE_HAND_DELAY := 0.5
const BUILD_HAND_DELAY := 0.4
const TASK_HAND_DELAY := 0.35
## Free play before the ad chain: nudge a claimable card, then fall back.
const NUDGE_AFTER := 25.0
const FALLBACK_READY := 35.0
const FALLBACK_FREE := 120.0
const IDLE_BEFORE_CHAIN := 1.0
## Scripted traveller watchdogs (signals normally arrive first).
const STILL_SPEED := 0.05
const STILL_TIME := 0.35
const MOVE_SPEED := 0.4
const MOVE_TIME := 0.2
const ARRIVE_RADIUS := 0.9
const SEAT_RADIUS := 1.0
const WALK_TIMEOUT := 30.0
const SALE_TIMEOUT := 14.0
## Seated beat: let the sit pose + order bubble read before the camera swings
## to the counter; never wait longer than SEAT_COOK_TIMEOUT for the ticket.
const SEAT_DWELL := 0.15
const SEAT_COOK_TIMEOUT := 2.5
## After L3: wait for the kulhad on the pass / Raju (then follow him).
const BREW_TIMEOUT := 10.0
## Raju walking it over; then the traveller eats (3 s) and leaves his seat.
const DELIVER_TIMEOUT := 20.0
## How often (s) to look for Raju again while he cannot be found.
const WAITER_SCAN_EVERY := 0.5
## Chai-pause framing: the counter, pulled toward the seated traveller when
## he sits within SEAT_FRAME_MAX m (so his order bubble stays in frame).
const SEAT_FRAME_W := 0.4
const SEAT_FRAME_MAX := 6.5
## Camera framing (fixer re-layout 2026-10-20; targets checked with an
## ortho projection of Layout3: intro = the whole interior above the dialogue,
## galla view / free-play home = Pinky (back corner, top), both table sets,
## galla 1 and galla 2's desk, the gate at the bottom-left).
const INTRO_OFFSET := Vector3(1.3, 0.0, 0.9)
const GALLA_VIEW_OFFSET := Vector3(0.4, 0.0, -1.4)
## Camera target relative to the wall-ad anchor (y cancels the anchor height).
## UX fix A4 (2026-10-22): the anchor projects at about (496, 637), so the
## 104 x 156 bubble sits unclamped inside the safe band (x 70..650, y
## 560..950) with Pinky at the chai counter below-left of it (the old
## (-1.3, -1.9, 2.2) put it at y 458: clamped under the HUD buttons). The view
## is restored after the ad lines.
const BUBBLE_VIEW_OFFSET := Vector3(-2.0, -1.9, -0.2)
## L10 ("two cashiers"): both cashiers and their lines in
## frame (Bablu sits at the left edge of the home view), Pinky above them.
const GALLA_PAIR_VIEW := Vector3(2.25, 0.0, 4.7)
const SHEET_HAND_REL := Vector2(0.5, 0.8)
## World tags (rack, ADD TABLE): the fingertip near the bottom-right corner,
## so the glove (below-right of the tip) leaves the label readable.
const TAG_HAND_REL := Vector2(0.9, 0.8)
const GALLA_MARKER_TIP := 2.1
const TASK_CARD_MIDDLE := 1
## Waiter beat (A9): camera target relative to the tray rack (the rack and
## the chai pass at about screen y 420, above Munshi-ji's bust).
const WAITER_VIEW_OFFSET := Vector3(1.6, 0.0, 1.6)
## Round 2 step 2 waiter beat (problem first): orders injected at once, the
## plates that must wait on the pass before LW1 opens, and the longest wait
## for them (s; LW1 opens anyway after it).
const WAITER_INJECT := 3
const WAITER_PLATES := 2
const WAITER_PLATES_TIMEOUT := 9.0
## C3.1: after a hire from the 2-tap card the camera stays on the pass this
## long (the new waiter pops in and takes the oldest plate), then flies home
## (0.5 s before LW3, so the pass stays in view about 1.7 s). 1.2 s is what
## the STAFF path spent on its X, so free play starts when it did.
const WAITER_HIRE_HOLD := 1.2
## The ad bubble: fingertip on the bubble's lower right, so the glove leaves
## "+1,000 / ▶ WATCH AD" readable.
const BUBBLE_HAND_REL := Vector2(0.8, 0.8)
## Seats beat (A9): camera target relative to the next ghost table (the table
## at about screen y 548, its ADD TABLE tag's top below the TASKS bar at
## y ~400; the spec's (1.6, 0, 1.6) put the tag under the bar); a door
## line must last SEATS_DOOR_S.
## Core and feel C4.1 (replaces the 45 s prewarm nudges, which left the
## beat at free + 50 s on the 30 fps seeds 41 and 46: 5 of 8 seats were
## still free when the free step began and the arrivals never outran them
## before the nudge): SEATS_FILL_AT s into the free step with no door line
## and the player idle (IDLE_BEFORE_CHAIN: the trigger needs that too),
## Sim.fill_for_seats_beat(SEATS_FILL_DOOR) seats a traveller on every free
## seat and stands SEATS_FILL_DOOR more at the gate (fixed models, no rng
## draw); the trigger then fires 2 s later. W3-FIX: the gate line can drain
## before that (earlier diners leave and the travellers at the gate take
## their seats, often while a panel is open), so with no door line the fill
## runs again once the player is idle, SEATS_REFILL_S after the last one,
## SEATS_FILLS times a session at most. From SEATS_FAILSAFE_AT on, with no
## door line, the beat is skipped (tutorial_seats_skipped {why:
## "fill_failed"}) only when the fill placed nobody (no Sim hook) or every
## fill is spent and SEATS_REFILL_S has passed since the last; a door line
## always waits for the player's calm. SEATS_GIVEUP_AT (wave 2's last skip
## time) is the backstop for a player who is never idle.
## SEATS_SHOW_S = how long the new table is shown before home.
const SEATS_VIEW_OFFSET := Vector3(0.8, 0.0, 0.8)
const SEATS_DOOR_S := 2.0
const SEATS_FILL_AT := 3.0
const SEATS_FILL_DOOR := 3
const SEATS_FILLS := 3
const SEATS_REFILL_S := 2.0
const SEATS_FAILSAFE_AT := 20.0
const SEATS_GIVEUP_AT := 110.0
const SEATS_SHOW_S := 2.0
## The bubble view (S_BUBBLE) is flown to unless the wall-ad anchor already
## projects inside this rect (the 104x156 bubble is then not clamped).
const BUBBLE_SAFE := Rect2(70.0, 560.0, 580.0, 390.0)
## Anchors that appear with a short delay (world tags poll at 0.2 s and pop
## in): resolved for up to this long.
const ANCHOR_WAIT := 1.0
## C7.2 (W3-FIX): on a relaunch at the ad beat, the longest wait (s) for the
## first rewarded load before the beat is left out.
const AD_READY_WAIT := 8.0
## Step 4: where the camera looks at the shack's building site (the tag hangs
## at BuildSiteTag.POINTS["shack"]), the pause before G3, and the longest
## wait for the shack's reveal after the reload.
const GROW_SITE_VIEW := Vector3(4.2, 0.0, 2.2)
const GROW_SITE_DELAY := 1.0
const SHACK_REVEAL_MAX := 6.0
const SHACK_OPEN_DELAY := 0.8
## Soft launch analytics: every beat in its canonical order. tutorial_step
## carries its 1-based index "i" (GameAnalytics design id
## tutorial:step:<ii>_<step>, so the funnel sorts in play order) and "t", the
## seconds of play since the tutorial started or resumed this session.
const STEP_ORDER := ["intro", "follow", "seated", "chai_pause", "brew", "deliver", "to_galla", "galla_pause",
		"wait_sale", "first_sale", "tap_chai", "level", "line7", "tap_out", "grow_lines", "grow_btn", "grow_row",
		"grow_site", "shack_open", "transfer", "tap_galla", "hire",
		"close_galla", "wrap", "waiter_lines", "tap_staff", "hire_waiter", "close_waiters", "waiter_done", "free",
		"seats_lines", "tap_table", "add_table", "seats_done", "ad_deal", "bubble", "vip", "ad_lines", "build_btn",
		"build_row", "build_close", "outro", "done"]

@export var auto_start: bool = true

var _dialogue: DialogueBox
var _hand: HandPointer
var _trav: Traveller

var _started: bool = false
var _step: String = S_IDLE
var _gen: int = 0
var _step_t: float = 0.0
var _resume_once: bool = false
## Seconds of play since the tutorial started or resumed this session
## (analytics; counts only while the game runs, not while it is in the
## background).
var _tut_s: float = 0.0

var _cam_done: bool = false
var _cam_expect: String = ""
var _marker_on: bool = false
var _open_panels: Dictionary = {}
var _vip_taken: bool = false
## The tandoor was built in the BUILD beat (not earlier from the NEXT chip):
## the outro shows it popping in before flying home.
var _show_tandoor: bool = false
var _ad_delay: float = CLAIM_TO_LINE
## Camera target before the wall-ad beat flew to the painted ad (restored
## when the HUD comes back after L16). INF = nothing to restore.
var _bubble_return: Vector3 = Vector3.INF

## First-traveller events seen so far (latched; reset on spawn).
var _ev_seated: bool = false
var _ev_cooking: bool = false
var _ev_ready: bool = false
var _ev_dispatched: bool = false
var _ev_picked: bool = false
var _ev_served: bool = false
var _ev_galla: bool = false
var _waiter: Node3D = null

## Scripted traveller motion (XZ), reset on every step.
var _last_pos: Vector3 = Vector3.ZERO
var _still_t: float = 0.0
var _move_t: float = 0.0
var _was_still: bool = false
var _seen_move: bool = false
## Waiter motion (S_BREW fallback for a missed dispatch / pick-up signal).
var _w_last: Vector3 = Vector3.ZERO
var _w_move_t: float = 0.0
var _w_seen: bool = false
var _w_scan_t: float = 0.0
## Traveller.S value -> key name (read once from the traveller's script).
var _state_names: Dictionary = {}
var _state_names_read: bool = false

var _layout_map: Dictionary = {}
var _layout_loaded: bool = false
var _seats_cache: Array = []
var _seats_loaded: bool = false

var _free_t: float = 0.0
var _ready_t: float = 0.0
var _idle_t: float = 0.0
## Seats beat: free-play seconds before it is done, the door line's run,
## tables when it started, a claim that came before it was done.
var _seats_t: float = 0.0
var _door_t: float = 0.0
var _tables0: int = 0
var _claim_pending: bool = false
## C4.1: seats-beat fills this session, the _seats_t of the last one and
## how many travellers it placed (-1 = none yet).
var _seats_fills: int = 0
var _seats_fill_t: float = 0.0
var _seats_fill_n: int = -1
## C3.1: the waiter beat's hire came from the 2-tap card (waiter_done holds
## on the pass before it flies home).
var _hired_via_card: bool = false
## C7.2: the ad beat was left out (no rewarded ad): the BUILD beat says L16.
var _ad_skipped: bool = false
## W3-FIX (C7.2): resumed at "ad_deal": the beat waits for the first
## rewarded load (AD_READY_WAIT) before it decides there is no ad.
var _ad_wait_load: bool = false
## Step 4: WorldJuice's promotion reveal is playing (Fx.reveal_started /
## reveal_finished).
var _reveal_on: bool = false


func _ready() -> void:
	set_process(false)
	_ensure_nodes()
	if auto_start:
		_auto_start.call_deferred()


func _auto_start() -> void:
	var tries := 0
	while tries < 120 and (Refs.camera == null or Refs.sim == null or Refs.ui == null or Refs.hud == null):
		await get_tree().process_frame
		tries += 1
	start()


# ================================================================ public API
## Starts (or resumes) the tutorial. Safe to call more than once.
func start() -> void:
	if _started:
		return
	_started = true
	_ensure_nodes()
	_wire()
	if Game.is_tutorial_done() or Game.is_built("tandoor"):
		# Returning player: free play, nothing to replay.
		_step = S_DONE
		_reveal(REVEAL_FULL)
		_hold_spawns(false)
		_allow_taps([])
		_lock_input(false)
		if not Game.is_tutorial_done():
			Game.tutorial_set("step", "done")
			Game.tutorial_set("done", true)
		return
	set_process(true)
	_tut_s = 0.0
	_resume(str(Game.tutorial_get("step", "intro")))


## Debug / settings: end the tutorial now and reveal everything.
func skip() -> void:
	if _step == S_DONE:
		return
	if _dialogue != null and _dialogue.is_open():
		_dialogue.close()
	if _hand != null:
		_hand.hide_now()
	Game.sim_paused = false
	_finish(false)


func current_step() -> String:
	return _step


## Idle Business Kit, phase 1: the world tap the current beat waits for
## while its marker stands over the target ("station:<id>" or "galla"), "" when
## no marker beat runs. Test drivers tap this instead of naming the dhaba's
## counters, so the autopilot stays theme-free.
func marker_tap_id() -> String:
	match _step:
		S_TAP_CHAI:
			return "station:" + core_station()
		S_TAP_GALLA:
			return "galla"
	return ""


## The theme's first service point (the one the tutorial starts on): the
## first id in the economy's station order.
static func core_station() -> String:
	var ids: Array = Game.station_ids()
	return str(ids[0]) if not ids.is_empty() else ""


## True from start until done (other modules: no offline popup / auto ads).
func is_active() -> bool:
	return _started and _step != S_DONE


## True while a scripted beat runs (not during the free-play wait for a claim).
func in_chain() -> bool:
	return is_active() and _step != S_FREE and _step != S_IDLE


## Round 2 step 1 (docs/round2/ui-proposal.md §3.8): the NEXT chip may show
## during the tutorial. True only in the free step (from the end of L12, about
## 1:30, until the seats beat or the ad chain starts) with no Munshi-ji line
## up, so the player always has a goal on screen and never two instructions.
func allows_next_chip() -> bool:
	return is_active() and _step == S_FREE and not (_dialogue != null and _dialogue.is_open())


func dialogue() -> DialogueBox:
	return _dialogue


func hand() -> HandPointer:
	return _hand


## Core and feel C2.6: the bottleneck meter's row the tutorial's lesson is
## about ("waiters" from waiter_lines to waiter_done, "seats" from
## seats_lines to seats_done, else ""). While it is not "", the meter pulses
## that row (and nothing else) and stays up in dialogue mode (W2-HUD reads it
## by name).
func lesson_stage() -> String:
	if not is_active():
		return ""
	match _step:
		S_WAITER_LINES, S_TAP_STAFF, S_HIRE_WAITER, S_CLOSE_WAITERS, S_WAITER_DONE:
			return "waiters"
		S_SEATS_LINES, S_TAP_TABLE, S_ADD_TABLE, S_SEATS_DONE:
			return "seats"
	return ""


# ================================================================ flow control
func _goto(step: String) -> void:
	if _step == S_LEVEL and step != S_LEVEL:
		_level_goal(false)
	_gen += 1
	_step = step
	_step_t = 0.0
	_still_t = 0.0
	_move_t = 0.0
	_was_still = false
	_seen_move = false
	_w_move_t = 0.0
	_w_seen = false
	_w_scan_t = 0.0
	if _trav_ok():
		_last_pos = _trav.global_position
	_wire()   # idempotent; picks up modules that registered late
	if not KEEP_MARKER.has(step):
		_marker_off()
	if _hand != null:
		_hand.hide_hand()
	step_changed.emit(step)
	Analytics.event("tutorial_step", {"step": step, "i": STEP_ORDER.find(step) + 1, "t": _elapsed_s()})
	var m := "_enter_" + step
	if has_method(m):
		call(m)


func _checkpoint(cp: String) -> void:
	Game.tutorial_set("step", cp)


func _resume(cp: String) -> void:
	if not CHECKPOINTS.has(cp):
		cp = "intro"
	# Derive from the economy where the save lags behind.
	var order: int = CHECKPOINTS.find(cp)
	if order < CHECKPOINTS.find("hired") and Game.galla_count() >= 2:
		cp = "hired"
	elif cp == "intro" and Game.station_level("chai") >= LEVEL_GATE:
		cp = "grow" if Game.stage() == 0 else "transfer"
	# Step 4: the grow beat follows the stage (the build may have finished
	# while the game was closed, or the save is older than the reload).
	if cp == "grow" and Game.stage() >= 1:
		cp = "shack"
	elif cp == "shack" and Game.stage() == 0:
		cp = "grow"
	# Only the re-entry beat shortens its lines (L6 only / no LW3 / L16 only).
	_resume_once = cp == "first_sale" or cp == "hired" or cp == "waiter" or cp == "build"
	Game.sim_paused = false
	if CHECKPOINTS.find(cp) >= CHECKPOINTS.find("hired"):
		# The cashier beat is behind: STAFF stays on the HUD.
		_reveal_staff()
	if CHECKPOINTS.find(cp) >= CHECKPOINTS.find("free"):
		# C2.6: the waiter beat is behind: the meter stays on the HUD.
		_reveal_meter()
	match cp:
		"intro":
			_goto(S_INTRO)
		"first_sale":
			_reveal(REVEAL_MONEY)
			_hold_spawns(true)
			_goto(S_FIRST_SALE)
		"grow":
			_reveal(REVEAL_RATE)
			_goto(S_GROW_LINES)
		"shack":
			_reveal(REVEAL_RATE)
			_goto(S_SHACK_OPEN)
		"transfer":
			_reveal(REVEAL_RATE)
			_goto(S_TRANSFER)
		"hired", "waiter":
			_reveal(REVEAL_MANAGER)
			_hold_spawns(false)
			_goto(S_WAITER_LINES if Game.waiter_count() < 2 else S_WAITER_DONE)
		"free", "seats":
			if cp == "seats":
				Game.tutorial_set("seats_done", true)
			if Game.waiter_count() < 2:
				# An old save from before the waiter beat.
				_reveal(REVEAL_MANAGER)
				_hold_spawns(false)
				_goto(S_WAITER_LINES)
			else:
				_end_chain()
		"ad_deal":
			_reveal(REVEAL_FULL)
			_hold_spawns(false)
			_ad_delay = 1.0
			_ad_wait_load = true
			_goto(S_AD_DEAL)
		"build":
			_reveal(REVEAL_FULL)
			_hold_spawns(false)
			_goto(S_AD_LINES)
		_:
			_finish(false)


func _end_chain() -> void:
	_reveal(REVEAL_FULL)
	_hold_spawns(false)
	_allow_taps([])
	_allow_buttons(["*"])
	_lock_input(false)
	_checkpoint("free")
	_goto(S_FREE)


## completed = the player reached the end (false = skipped from debug/settings).
func _finish(completed: bool) -> void:
	var from_step: String = _step
	_gen += 1
	_step = S_DONE
	if _hand != null:
		_hand.hide_hand()
		_hand.set_caption("")
	_level_goal(false)
	_marker_off()
	if _dialogue != null:
		_dialogue.set_highlight([])
	_reveal(REVEAL_FULL)
	_hold_spawns(false)
	_allow_taps([])
	_allow_buttons(["*"])
	_lock_input(false)
	var cam := _cam()
	if cam != null:
		cam.panel_min_size_mult = 0.0
	if _open_panels.is_empty():
		_hud_mode("gameplay")
	Game.tutorial_set("step", "done")
	Game.tutorial_set("done", true)
	Game.enable_ad_bubbles(true)
	Game.save_game()
	set_process(false)
	step_changed.emit(S_DONE)
	finished.emit()
	Analytics.event("tutorial_done", {"skipped": not completed, "from": from_step, "t": _elapsed_s()})


## Seconds since the tutorial started or resumed this session (analytics).
func _elapsed_s() -> int:
	return int(_tut_s)


# ================================================================ step entries
func _enter_intro() -> void:
	var g := _gen
	_checkpoint("intro")
	_hold_spawns(true)
	_reveal(REVEAL_PILL)
	_lock_input(true)
	_allow_taps(["none"])
	var cam := _cam()
	if cam != null:
		cam.snap(Layout3.CAM_START + INTRO_OFFSET, CameraRig.INTRO)
	await _wait(INTRO_DELAY)
	if g != _gen:
		return
	# Step 4: on the chai cart Rani says "Our stall is open!" (L1c).
	await _say(["l1c" if Game.stage() == 0 else "l1", "l2"])
	if g != _gen:
		return
	_goto(S_FOLLOW)


func _enter_follow() -> void:
	var g := _gen
	_wire_world()
	_spawn_traveller()
	await _wait(FLY_DELAY)
	if g != _gen:
		return
	_adopt_scripted()   # Sim may place him (at its parked lorry) a little later
	var cam := _cam()
	var at: Vector3 = Layout3.SPAWN
	if _trav_ok():
		# The head, as FOLLOW tracks it: no re-centring drift after the fly.
		at = _trav.head_position()
	if cam != null:
		_cam_wait_for("fly")
		cam.fly_to(at, CameraRig.FOLLOW)
		await _await_cam(FLY_TIMEOUT)
		if g != _gen:
			return
	if not _trav_ok():
		_adopt_scripted()
	if not _trav_ok():
		# Sim could not spawn the scripted traveller: skip the walk.
		push_warning("Director: no scripted traveller; skipping the walk beats.")
		_goto(S_FIRST_SALE)
		return
	if cam != null:
		cam.follow(_trav)
	# Events that arrived during the fly (a very short walk) move us on now.
	_advance_walk()


## He is on a charpai (or the cook already took his ticket). The camera keeps
## following him; _process moves on once the ticket is cooking (+SEAT_DWELL)
## or after SEAT_COOK_TIMEOUT.
func _enter_seated() -> void:
	var cam := _cam()
	if cam != null and _trav_ok():
		cam.follow(_trav)   # no jump: FOLLOW lerps from the current view
	_advance_walk()


## Pinky's timer popped: settle on the chai counter (the seat stays in frame
## when it is close), gate on settle + 0.05 s, L3 (pause_sim), zoom back in.
func _enter_chai_pause() -> void:
	var g := _gen
	var focus: Vector3 = _floor(Layout3.station_focus("chai"))
	if _trav_ok():
		var tp: Vector3 = _floor(_trav.global_position)
		if Vector2(tp.x - focus.x, tp.z - focus.z).length() <= SEAT_FRAME_MAX:
			focus = focus.lerp(tp, SEAT_FRAME_W)
	var cam := _cam()
	if cam != null:
		_cam_wait_for("settle")
		cam.settle_on(focus, STATION_SETTLE_ZOOM)
		await _await_cam(SETTLE_TIMEOUT)
		if g != _gen:
			return
	await _wait(SETTLE_GATE)
	if g != _gen:
		return
	await _say(["l3c" if Game.stage() == 0 else "l3"])
	if g != _gen:
		return
	if cam != null:
		cam.zoom_by(1.0 / STATION_SETTLE_ZOOM)
	_goto(S_BREW)


## Camera holds on the counter while the kulhad brews; the item reaching the
## pass (or Raju being sent / picking it up) starts the delivery follow.
func _enter_brew() -> void:
	_advance_walk()


## FOLLOW Raju from the pass to the charpai.
func _enter_deliver() -> void:
	_follow_waiter(_find_waiter())
	_advance_walk()


## Served: FOLLOW the traveller (eats, stands, walks to the galla line).
func _enter_to_galla() -> void:
	var cam := _cam()
	if cam != null and _trav_ok():
		cam.follow(_trav)
	_advance_walk()


func _enter_galla_pause() -> void:
	var g := _gen
	var focus: Vector3 = Layout3.galla_view(0)
	if _trav_ok():
		focus = (focus + _trav.global_position) * 0.5
	var cam := _cam()
	if cam != null:
		_cam_wait_for("settle")
		cam.settle_on(focus, GALLA_SETTLE_ZOOM)
		await _await_cam(SETTLE_TIMEOUT)
		if g != _gen:
			return
	await _wait(SETTLE_GATE)
	if g != _gen:
		return
	await _say(["l4c" if Game.stage() == 0 else "l4"])
	if g != _gen:
		return
	# Stay on the galla at the settle zoom (ref 32-35.5 s: no zoom-in after L4;
	# the TUTORIAL FOCUS then zooms 1.4x from here).
	_goto(S_WAIT_SALE)


func _enter_first_sale() -> void:
	var g := _gen
	_checkpoint("first_sale")
	_reveal(REVEAL_MONEY)
	_lock_input(true)
	_allow_taps(["none"])
	await _wait(AFTER_SALE)
	if g != _gen:
		return
	if _resume_once:
		_resume_once = false
		await _say(["l6"])
	else:
		await _say(["l5", "l6"])
	if g != _gen:
		return
	_goto(S_TAP_CHAI)


func _enter_tap_chai() -> void:
	var g := _gen
	_allow_taps(["station:chai"])
	var cam := _cam()
	if cam != null:
		# The ref's tutorial sheet zooms out from FOCUS to ~PANEL on open.
		cam.panel_min_size_mult = CameraRig.PANEL
	if _panel_open("chai"):
		_goto(S_LEVEL)
		return
	if cam != null:
		cam.focus(Layout3.station_focus("chai"))
	await _wait(MARKER_DELAY)
	if g != _gen:
		return
	_marker_at(_floor(Layout3.marker_station("chai")))


func _enter_level() -> void:
	var g := _gen
	_reveal(REVEAL_RATE)
	_allow_taps(["none"])
	_level_goal(true)
	await _wait(HAND_DELAY)
	if g != _gen:
		return
	_marker_off()
	if _chai_gate_met():
		_goto(S_LINE7)
		return
	_hand.point_at(_anchor(["level_up_button"]))


func _enter_line7() -> void:
	var g := _gen
	# Level 10 reached: a held LEVEL UP must stop repeating under the line
	# (only the tap-outside close stays allowed until the transfer).
	_allow_buttons(["panel_close"])
	await _say(["l7"])
	if g != _gen:
		return
	_goto(S_TAP_OUT)


func _enter_tap_out() -> void:
	if not _panel_open("chai"):
		_goto(_after_chai())
		return
	# The sheet closes on its X (A6.1) or a tap above it (whether UiRoot routes
	# that through WorldInput or its own catcher), so world taps stay allowed.
	_allow_taps([])
	var x := _anchor(["sheet_close"])
	if x != null:
		_hand.point_at(x)
	else:
		_hand.point_at(_anchor(["sheet_outside"]), SHEET_HAND_REL)


## Step 4: after the chai lesson, the cart builds the shack; a game that
## started on the dhaba goes straight to the transfer.
func _after_chai() -> String:
	return S_GROW_LINES if Game.stage() == 0 else S_TRANSFER


## The grow beat (cart): travellers come back and chai sells while G1 / G2
## set the goal; BUILD comes in as G2 names it.
func _enter_grow_lines() -> void:
	var g := _gen
	_checkpoint("grow")
	if Game.stage() > 0:
		_goto(S_SHACK_OPEN)
		return
	if Game.build_job_active():
		_goto(S_GROW_SITE)
		return
	_reveal(REVEAL_RATE)
	_allow_taps(["none"])
	_allow_buttons(["*"])
	_lock_input(true)
	_hold_spawns(false)
	var cam := _cam()
	if cam != null:
		cam.panel_min_size_mult = 0.0
		cam.fly_home()
	await _wait(WRAP_DELAY)
	if g != _gen:
		return
	await _say(["g1", "g2"])
	if g != _gen:
		return
	_goto(S_GROW_BTN)


## Hand on BUILD (the shack's price topped up once per save: "gift_shack").
func _enter_grow_btn() -> void:
	var g := _gen
	if Game.build_job_active() or Game.stage() > 0:
		_goto(S_GROW_SITE)
		return
	Game.reveal_hud("build")
	_allow_taps(["none"])
	_allow_buttons(["*"])
	_lock_input(true)
	_hud_mode("gameplay")
	_gift_once("shack", float(Game.growth_state().get("cost", 0.0)))
	if _panel_open("daftar"):
		_goto(S_GROW_ROW)
		return
	await _wait(BUILD_HAND_DELAY)
	if g != _gen:
		return
	_hand.point_at(_anchor(["build_button"], true))


## BUILD is open: hand on THE SHACK's BUILD. Never soft-lock: when the chai
## lesson was cut short (an unaffordable level) and the shack is still
## locked, it is built free.
func _enter_grow_row() -> void:
	var g := _gen
	if Game.build_job_active():
		_goto(S_GROW_SITE)
		return
	var ui: Node = Refs.ui
	if ui != null and is_instance_valid(ui):
		var df: Variant = ui.get("daftar")
		if df is Object and (df as Object).has_method("focus_row"):
			(df as Object).call("focus_row", "grow")
	if str(Game.growth_state().get("reason", "")) == "needs":
		print("[tutorial] grow beat: the shack is locked (chai L%d); building it free" % Game.station_level("chai"))
		Game.start_growth_build(true)
		return
	await _wait(HAND_DELAY)
	if g != _gen:
		return
	_hand.point_at(_anchor(["build_row_grow"]))


## The construction runs: fly to the site, G3, hand on the tag's free
## FINISH NOW. The build finishing (that tap, or the 3 minutes) saves and
## reloads the scene as the shack (checkpoint "shack").
func _enter_grow_site() -> void:
	var g := _gen
	_checkpoint("grow")
	if Game.stage() > 0:
		_goto(S_SHACK_OPEN)
		return
	if not Game.build_job_active():
		_goto(S_GROW_BTN)
		return
	if not _open_panels.is_empty():
		_call(Refs.ui, "close_all")
	_allow_taps(["none"])
	_allow_buttons(["*"])
	_lock_input(true)
	var cam := _cam()
	if cam != null:
		_cam_wait_for("fly")
		cam.fly_to(GROW_SITE_VIEW, CameraRig.GAME)
		await _await_cam(FLY_TIMEOUT)
		if g != _gen:
			return
	await _wait(GROW_SITE_DELAY)
	if g != _gen:
		return
	if not Game.build_free_skip_ready():
		# The free skip is spent: the workers just keep going.
		_lock_input(false)
		return
	await _say(["g3"])
	if g != _gen:
		return
	var tag: Control = await _anchor_soon(["build_site_tag"])
	if g != _gen:
		return
	if tag != null:
		_hand.point_at(tag, BuildSiteTag.capsule_rel())
	else:
		_lock_input(false)


## The new scene (the shack): WorldJuice's reveal plays, then "shack_done",
## then the transfer and the rest of the tutorial as before.
func _enter_shack_open() -> void:
	var g := _gen
	_checkpoint("shack")
	_reveal(REVEAL_RATE)
	Game.reveal_hud("build")
	_allow_taps(["none"])
	_allow_buttons(["*"])
	_lock_input(true)
	_hold_spawns(false)
	await _wait(0.1)
	if g != _gen:
		return
	var t := 0.0
	while (_reveal_on or Game.promo_reveal_pending()) and t < SHACK_REVEAL_MAX:
		await get_tree().process_frame
		if g != _gen:
			return
		t += get_process_delta_time()
	await _wait(SHACK_OPEN_DELAY)
	if g != _gen:
		return
	if Game.stage() == 1 and not Game.note_seen("shack_done"):
		Game.mark_note("shack_done")
		await _say(["shack_done"])
		if g != _gen:
			return
	_goto(S_TRANSFER)


func _enter_transfer() -> void:
	var g := _gen
	_checkpoint("transfer")
	_reveal(REVEAL_MANAGER)
	_allow_taps(["none"])
	_allow_buttons(["*"])
	_lock_input(true)
	_wire_world()
	var cam := _cam()
	if cam != null:
		cam.panel_min_size_mult = 0.0
	# One frame later, so this wins over UiRoot's panel_restore on close.
	await get_tree().process_frame
	if g != _gen:
		return
	if cam != null:
		_cam_wait_for("transfer")
		cam.transfer_to(Layout3.galla_focus(0) + GALLA_VIEW_OFFSET, CameraRig.GAME)
	# Ref: no line at +0.4 s, five standing at +0.9 s (the first bill starts
	# ~+0.65 s). Only the first run credits them to "Serve 20" (a relaunch in
	# this window re-shows the line without counting it again).
	await _wait(INJECT_DELAY)
	if g != _gen:
		return
	var first: bool = not bool(Game.tutorial_get("injected", false))
	_call(Refs.sim, "inject_galla_queue", [INJECT_COUNT, first])
	Game.tutorial_set("injected", true)
	_hold_spawns(false)
	if cam != null:
		await _await_cam(TRANSFER_TIMEOUT - INJECT_DELAY)
		if g != _gen:
			return
	await _wait(SETTLE_GATE)
	if g != _gen:
		return
	await _say(["l8", "l9"])
	if g != _gen:
		return
	_goto(S_TAP_GALLA)


func _enter_tap_galla() -> void:
	_allow_taps(["galla"])
	_allow_buttons(["*"])
	if _panel_open("staff"):
		_goto(S_HIRE)
		return
	# Tip ~one character height above Munna's head, clear of the running
	# galla timer (ref 62.0 s).
	_marker_at(_floor(Layout3.marker_galla(0)), GALLA_MARKER_TIP)


## STAFF › CASHIERS is open: only its HIRE (and the X) work; hand on HIRE.
func _enter_hire() -> void:
	var g := _gen
	Game.grant_cash_floor(HIRE_FLOOR)
	_allow_taps(["none"])
	if Game.galla_count() >= 2:
		_goto(S_CLOSE_GALLA)
		return
	_staff_tab("cashiers")
	_allow_buttons(["galla_hire", "panel_close"])
	await _wait(HAND_DELAY)
	if g != _gen:
		return
	_marker_off()
	_hand.point_at(_anchor(["staff_hire_cashiers", "galla_hire_button"]))


func _enter_close_galla() -> void:
	var g := _gen
	_allow_buttons(["*"])
	if not _panel_open("staff"):
		_goto(S_WRAP)
		return
	await _wait(RETARGET_PAUSE)
	if g != _gen:
		return
	_hand.point_at(_anchor(["staff_close", "galla_close", "panel_close"]))


## STAFF › CASHIERS closed with two cashiers: the STAFF button comes in with
## its burst (round 2 step 2), L10 names it and rings it.
func _enter_wrap() -> void:
	var g := _gen
	_checkpoint("hired")
	_reveal_staff()
	_allow_taps(["none"])
	_lock_input(true)
	var cam := _cam()
	if cam != null and Game.galla_count() >= 2:
		cam.fly_to(GALLA_PAIR_VIEW, CameraRig.GAME)
	await _wait(WRAP_DELAY)
	if g != _gen:
		return
	await _say(["l10"])
	if g != _gen:
		return
	_dialogue.set_highlight([])
	_goto(S_WAITER_LINES)


## Waiter beat, problem first (round 2 step 2, ui-proposal §3.7): fly to the
## tray rack and the chai pass, seat WAITER_INJECT travellers at once, wait
## for their plates to wait on the pass (orange rings), then LW1–LW2.
## Core and feel C2.6: the bottleneck meter comes in as the beat starts
## (its WAITERS row pulses: lesson_stage()).
func _enter_waiter_lines() -> void:
	var g := _gen
	_checkpoint("waiter")
	_resume_once = false
	_reveal_staff()
	_reveal_meter()
	if Game.waiter_count() >= 2:
		_goto(S_WAITER_DONE)
		return
	_lock_input(true)
	_allow_taps(["none"])
	var cam := _cam()
	if cam != null:
		cam.fly_to(Layout3.TRAY_RACK + WAITER_VIEW_OFFSET, CameraRig.GAME)
	var n: Variant = _call(Refs.sim, "inject_orders", [WAITER_INJECT])
	await _wait(WRAP_DELAY)
	if g != _gen:
		return
	var t := 0.0
	while _plates_waiting() < WAITER_PLATES and t < WAITER_PLATES_TIMEOUT:
		await _wait(0.1)
		if g != _gen:
			return
		t += 0.1
	print("[tutorial] waiter beat: %s orders injected, %d plates waiting after %.1f s" % [str(n), _plates_waiting(), t])
	Analytics.event("tutorial_waiter_problem", {"plates": _plates_waiting(), "wait_s": snappedf(t, 0.1)})
	if not _open_panels.is_empty():
		# W4-FIX: STAFF (ringed by L10) or the meter's card opened during the
		# plate wait: LW1 shows the plates on the pass and LW2 rings the
		# "+ WAITER" tag, which UiRoot hides while a panel is open, so the
		# screen is reset first (as seats_done does).
		print("[tutorial] waiter beat: closed %s before LW1" % str(_open_panels.keys()))
		_call(Refs.ui, "close_all")
	await _say(["lw1", "lw2"])
	if g != _gen:
		return
	_goto(S_TAP_STAFF)


## Core and feel C3.1: the hand on the new waiter's "+ WAITER" tag over the
## ghost by the rack (it opens the 2-tap card). STAFF, the rack or a waiter
## still open STAFF › WAITERS, and that path goes on as before.
func _enter_tap_staff() -> void:
	var g := _gen
	_dialogue.set_highlight([])
	_reveal_staff()
	if Game.waiter_count() >= 2:
		_goto(S_WAITER_DONE)
		return
	if _panel_open("staff") or _panel_open("quick_waiters"):
		_goto(S_HIRE_WAITER)
		return
	_unlock_waiter_tag(true)
	_allow_buttons(["*"])
	print("[tutorial] tap the WAITER tag: %d plates still waiting" % _plates_waiting())
	await _wait(HAND_DELAY)
	if g != _gen:
		return
	var a: Control = await _anchor_soon(["waiter_tag"])
	if g != _gen:
		return
	if a != null:
		_hand.point_at(a, TAG_HAND_REL)
	else:
		_hand.point_at(Layout3.waiter_home(Game.waiter_count()) + Vector3(0.0, HireSlot.WAITER_TAG_Y, 0.0))


## The 2-tap card (or STAFF › WAITERS, switched there if STAFF opened on
## another tab) is open: top the cash up to the hire cost (visible gift,
## once: _gift_once), hand on its HIRE.
func _enter_hire_waiter() -> void:
	var g := _gen
	_gift_once("waiter", Game.waiter_hire_cost())
	_allow_taps(["none"])
	var card: bool = _panel_open("quick_waiters")
	if Game.waiter_count() >= 2:
		_goto(S_WAITER_DONE if card else S_CLOSE_WAITERS)
		return
	if not card:
		_staff_tab("waiters")
	_allow_buttons(["waiter_hire", "panel_close"])
	await _wait(HAND_DELAY)
	if g != _gen:
		return
	_marker_off()
	if card and _panel_open("quick_waiters"):
		_hand.point_at(_anchor(["quick_buy_button", "waiter_hire_button"]))
	else:
		_hand.point_at(_anchor(["staff_hire_waiters", "waiter_hire_button"]))


func _enter_close_waiters() -> void:
	var g := _gen
	_allow_buttons(["*"])
	if not _panel_open("staff"):
		_goto(S_WAITER_DONE)
		return
	await _wait(RETARGET_PAUSE)
	if g != _gen:
		return
	_hand.point_at(_anchor(["staff_close", "waiter_close", "panel_close"]))


## Two waiters: back home, LW3, then free play (round 2 step 2: no L12; the
## task strip comes with the first claimable task, _tick_tasks). C3.1: after
## a card hire the camera first holds on the pass for WAITER_HIRE_HOLD s
## while the new waiter pops in and takes the oldest plate.
func _enter_waiter_done() -> void:
	var g := _gen
	_allow_taps(["none"])
	_allow_buttons(["*"])
	_lock_input(true)
	_unlock_waiter_tag(false)
	_reveal_meter()
	if _hired_via_card:
		_hired_via_card = false
		await _wait(WAITER_HIRE_HOLD)
		if g != _gen:
			return
	var cam := _cam()
	if cam != null:
		cam.fly_home()
	await _wait(WRAP_DELAY)
	if g != _gen:
		return
	var ids: Array = ["lw3"]
	if _resume_once:
		_resume_once = false
		ids = []
	await _say(ids)
	if g != _gen:
		return
	_dialogue.set_highlight([])
	_end_chain()


func _enter_free() -> void:
	_free_t = 0.0
	_ready_t = 0.0
	_idle_t = 0.0
	_door_t = 0.0
	_allow_taps([])
	_lock_input(false)


## Seats beat (A9): the first door line. LT1 over the home view (the full
## seats and the door line; the camera flies home first if the player had
## panned away), LT2 at the next ghost table (see _on_line_started).
func _enter_seats_lines() -> void:
	var g := _gen
	_tables0 = Game.table_count()
	_lock_input(true)
	# "tables" taps on (the box takes every tap while it is open): the
	# "Seats full!" pill keeps showing over the door line during LT1.
	_allow_taps(["tables"])
	_allow_buttons(["panel_close"])
	var cam := _cam()
	if cam != null and not cam.is_home_in_view(60.0):
		cam.fly_home()
		await _wait(WRAP_DELAY)
		if g != _gen:
			return
	await _say(["lt1", "lt2"])
	if g != _gen:
		return
	_goto(S_TAP_TABLE)


## The "+ TABLE" tag over the ghost table; the hand on it.
func _enter_tap_table() -> void:
	var g := _gen
	if Game.table_count() > _tables0:
		_goto(S_SEATS_DONE)
		return
	if _tables_open():
		_goto(S_ADD_TABLE)
		return
	_allow_taps(["tables"])
	_allow_buttons(["*"])
	await _wait(HAND_DELAY)
	if g != _gen:
		return
	var a: Control = await _anchor_soon(["table_tag"])
	if g != _gen:
		return
	if a != null:
		_hand.point_at(a, TAG_HAND_REL)
	else:
		_hand.point_at(TableTag.table_point(Game.table_count()) + Vector3(0.0, TableTag.HOVER_Y, 0.0))


## The table's 2-tap card (or BUILD › TABLES) is open: top the cash up to the
## table cost (once: _gift_once), hand on its BUILD.
func _enter_add_table() -> void:
	var g := _gen
	_gift_once("table", Game.table_cost())
	_allow_taps(["none"])
	if Game.table_count() > _tables0:
		_goto(S_SEATS_DONE)
		return
	_allow_buttons(["seating_add", "panel_close"])
	await _wait(HAND_DELAY)
	if g != _gen:
		return
	_hand.point_at(_anchor(["seating_add_button", "quick_buy_button"]))


## Table added: UiRoot closes the card (or BUILD) and shows the new table
## popping in; then the camera flies home and free play (or the remembered
## claim's ad chain) goes on.
func _enter_seats_done() -> void:
	var g := _gen
	_checkpoint("seats")
	Game.tutorial_set("seats_done", true)
	_allow_taps([])
	_allow_buttons(["*"])
	await _wait(0.5)
	if g != _gen:
		return
	if _tables_open():
		_call(Refs.ui, "close_all")
	await _wait(SEATS_SHOW_S)
	if g != _gen:
		return
	var cam := _cam()
	if cam != null:
		_cam_wait_for("fly")
		cam.fly_home()
		await _await_cam(FLY_TIMEOUT + 0.6)
		if g != _gen:
			return
	_lock_input(false)
	if _claim_pending:
		_claim_pending = false
		_start_ad_chain(CLAIM_TO_LINE, "claim")
	else:
		_goto(S_FREE)


## C7.2: with no rewarded ad ready (offline, no fill, consent), L14, L15 and
## the bubble are left out and the BUILD beat follows at once (it says L16).
## W3-FIX: on a relaunch at this checkpoint the check comes 1 s after the
## launch, while the first rewarded load (AdMob: UMP, initialize, load) is
## usually still in flight: it waits up to AD_READY_WAIT s for that load,
## only while it is pending (no failure yet), so no fill / offline / consent
## still skip at once and the fresh path is unchanged.
func _enter_ad_deal() -> void:
	var g := _gen
	_checkpoint("ad_deal")
	_allow_taps(["none"])
	# W4-FIX: no HUD button during the wait (on a relaunch 1 s plus up to
	# AD_READY_WAIT): STAFF opened here put L14 to L16 and the bubble's hand
	# over the full-screen panel. "*" comes back before L14 / the BUILD beat.
	_allow_buttons([])
	await _wait(_ad_delay)
	if g != _gen:
		return
	_ad_delay = CLAIM_TO_LINE
	_lock_input(true)
	if _ad_wait_load:
		_ad_wait_load = false
		var t := 0.0
		while not Ads.is_rewarded_ready("wall_ad") and t < AD_READY_WAIT \
				and Ads.rewarded_block_reason() == "loading" and Ads.last_load_failure() == "":
			await _wait(0.1)
			if g != _gen:
				return
			t += 0.1
		if t > 0.0:
			print("[tutorial] ad beat: waited %.1f s for the first ad (ready %s)" % [t, Ads.is_rewarded_ready("wall_ad")])
	_allow_buttons(["*"])
	if not _open_panels.is_empty():
		# W4-FIX: a panel or popup still open from before the beat: the lines
		# and the bubble's hand need the world in view.
		print("[tutorial] ad beat: closed %s before the beat" % str(_open_panels.keys()))
		_call(Refs.ui, "close_all")
	if not Ads.is_rewarded_ready("wall_ad"):
		_ad_skipped = true
		print("[tutorial] ad beat skipped: no ad")
		_goto(S_BUILD_BTN)
		return
	await _say(["l14"])
	if g != _gen:
		return
	_goto(S_BUBBLE)


func _enter_bubble() -> void:
	var g := _gen
	_vip_taken = false
	_hud_mode("dialogue")
	_allow_taps(["ad_bubble"])
	_lock_input(true)
	if not Game.ad_bubble_ready():
		Game.show_ad_bubble(-1.0, -1.0, true)
	ad_bubble_requested.emit()
	var cam := _cam()
	if cam != null and not _bubble_in_view(cam):
		# Frame the painted-ad wall so the bubble sits unclamped above the
		# dialogue, and remember the view: it comes back with the HUD after L16.
		if not _bubble_return.is_finite():
			_bubble_return = cam.target_point()
		cam.fly_to(Layout3.WALL_AD + BUBBLE_VIEW_OFFSET, CameraRig.GAME)
	await _wait(BUBBLE_HAND_DELAY)
	if g != _gen:
		return
	var a := _anchor(["ad_bubble"])
	if a != null:
		_hand.point_at(a, BUBBLE_HAND_REL)
	else:
		_hand.point_at(Layout3.WALL_AD)


func _enter_vip() -> void:
	var g := _gen
	await _wait(HAND_DELAY)
	if g != _gen:
		return
	_hand.point_at(_anchor(["vip_free_button", "vip_free"]))


func _enter_ad_lines() -> void:
	var g := _gen
	await _wait(REWARD_TO_LINE)
	if g != _gen:
		return
	var ids: Array = ["l15", "l16"]
	if _resume_once:
		_resume_once = false
		ids = ["l16"]
	if Game.is_built("tandoor"):
		# Round 2: built early from the NEXT chip; L16 would ask for it again.
		ids.erase("l16")
	await _say(ids)
	if g != _gen:
		return
	_hud_mode("gameplay")
	_restore_bubble_view()
	_goto(S_BUILD_BTN)


func _enter_build_btn() -> void:
	var g := _gen
	_checkpoint("build")
	if Game.is_built("tandoor"):
		_goto(S_OUTRO)
		return
	# Normally L16 revealed it; a resumed beat without L16 still needs it.
	Game.reveal_hud("build")
	_allow_taps(["none"])
	_lock_input(true)
	# Keep the beat completable: the ref arrived here with 215 >= 200. Once
	# per save (_gift_once): a player who spends it elsewhere earns it back.
	_gift_once("tandoor", Game.build_cost("tandoor"))
	if _panel_open("daftar"):
		_goto(S_BUILD_ROW)
		return
	if _ad_skipped:
		# C7.2: the ad lines were left out, so L16 ("We can afford a TANDOOR
		# now. Tap BUILD.") is said here, BUILD coming in as it names it.
		_ad_skipped = false
		await _say(["l16"])
		if g != _gen:
			return
		_hud_mode("gameplay")
		if _panel_open("daftar"):
			_goto(S_BUILD_ROW)
			return
	await _wait(BUILD_HAND_DELAY)
	if g != _gen:
		return
	_hand.point_at(_anchor(["build_button"], true))


func _enter_build_row() -> void:
	var g := _gen
	if Game.is_built("tandoor"):
		_goto(S_BUILD_CLOSE)
		return
	await _wait(HAND_DELAY)
	if g != _gen:
		return
	_hand.point_at(_anchor(["daftar_build_tandoor"]))


func _enter_build_close() -> void:
	var g := _gen
	if not _panel_open("daftar"):
		_goto(S_OUTRO)
		return
	await _wait(RETARGET_PAUSE)
	if g != _gen:
		return
	_hand.point_at(_anchor(["daftar_close", "panel_close"]))


func _enter_outro() -> void:
	var g := _gen
	_allow_taps(["none"])
	var cam := _cam()
	if cam != null:
		if _show_tandoor:
			# C1 review: the new tandoor pops in once BUILD has closed
			# (WorldJuice holds it while the panel covers the world), but it
			# sits right of the home view. Show it while L17 ("Roti + chai =
			# a bigger bill!") starts, then fly home, where free play starts
			# (A2.1), well before the line ends.
			_show_tandoor = false
			cam.fly_to(_tandoor_view(cam))
			get_tree().create_timer(OUTRO_TANDOOR_S).timeout.connect(_outro_home.bind(g))
		else:
			# A2.1: L17 is said over the home view; free play starts there.
			cam.fly_home()
	await _wait(OUTRO_DELAY)
	if g != _gen:
		return
	await _say(["l17"])
	if g != _gen:
		return
	_finish(true)


## Camera target that puts the tandoor at OUTRO_TANDOOR_SCREEN (above
## Munshi-ji's bust and box) at the current zoom.
func _tandoor_view(cam: CameraRig) -> Vector3:
	var vp: Vector2 = cam.get_viewport().get_visible_rect().size
	var shift: Vector3 = cam.screen_to_ground(vp * 0.5) - cam.screen_to_ground(vp * OUTRO_TANDOOR_SCREEN)
	return Layout3.station_focus("tandoor") + Vector3(shift.x, 0.0, shift.z)


func _outro_home(g: int) -> void:
	if g != _gen:
		return
	var cam := _cam()
	if cam != null:
		cam.fly_home()


# ================================================================ per frame
func _process(delta: float) -> void:
	_step_t += delta
	_tut_s += delta
	match _step:
		S_FOLLOW:
			_track_motion(delta)
			if not _trav_ok():
				_adopt_scripted()
			if _poll_state():
				return
			_poll_seat()
		S_SEATED:
			if _step_t > SEAT_COOK_TIMEOUT:
				_goto(S_CHAI_PAUSE)
			elif not _poll_state():
				_poll_cook()
				_advance_walk()
		S_BREW:
			_track_motion(delta)
			if _step_t > BREW_TIMEOUT:
				_goto(S_DELIVER)
			elif not _poll_state():
				_poll_left_seat()
				_poll_waiter_moving(delta)
		S_DELIVER:
			_track_motion(delta)
			if _step_t > DELIVER_TIMEOUT:
				_goto(S_TO_GALLA)
			elif not _poll_state():
				_poll_left_seat()
				_retry_waiter_follow(delta)
		S_TO_GALLA:
			_track_motion(delta)
			if not _poll_state():
				_poll_arrival(Layout3.galla_pay(0), S_GALLA_PAUSE)
		S_WAIT_SALE:
			if _step_t > SALE_TIMEOUT:
				_goto(S_FIRST_SALE)
		S_FREE:
			_tick_free(delta)


## Scripted traveller XZ motion: _still_t / _move_t run while he is still /
## walking; _was_still and _seen_move latch for the current step. Frozen
## while the sim is paused (a pause line is up).
func _track_motion(delta: float) -> void:
	if not _trav_ok():
		return
	var p: Vector3 = _trav.global_position
	var d: float = Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
	_last_pos = p
	if Game.sim_paused:
		return
	var speed: float = d / maxf(delta, 0.0001)
	if speed < STILL_SPEED:
		_still_t += delta
		_move_t = 0.0
		if _still_t >= STILL_TIME:
			_was_still = true
	elif speed > MOVE_SPEED:
		_move_t += delta
		_still_t = 0.0
		if _move_t >= MOVE_TIME:
			_seen_move = true
	else:
		_still_t = 0.0
		_move_t = 0.0


## Seat watchdog (S_FOLLOW): the traveller says he is seated, or he walked in
## and has stood still inside the dhaba (at a Layout3.SEATS spot when that
## constant exists) — or a long timeout.
func _poll_seat() -> void:
	if _step_t > WALK_TIMEOUT:
		_goto(S_CHAI_PAUSE)
		return
	if not _trav_ok() or Game.sim_paused:
		return
	if _trav_reports_seated():
		_ev_seated = true
		_advance_walk()
		return
	if _step_t < 0.5 or _still_t < STILL_TIME:
		return
	var p: Vector3 = _trav.global_position
	if Layout3.is_inside(p) and _near_seat(p):
		_ev_seated = true
		_advance_walk()


## S_BREW / S_DELIVER watchdog: he sat still, then got up and walked = he was
## served and has eaten (the item_served signal was missed).
func _poll_left_seat() -> void:
	if _was_still and _move_t >= MOVE_TIME:
		_ev_served = true
		_advance_walk()


## State watchdog: the scripted traveller's FSM state name (when it matches
## SEATED_STATES / FED_STATES / PAY_STATES) latches the walk events a missed
## or renamed Sim signal would have set. Returns true when the step changed.
func _poll_state() -> bool:
	if Game.sim_paused:
		return false
	var s: String = _trav_state()
	if s == "":
		return false
	if PAY_STATES.has(s):
		_ev_galla = true
	elif FED_STATES.has(s):
		_ev_seated = true
		_ev_served = true
	elif SEATED_STATES.has(s):
		_ev_seated = true
	else:
		return false
	var before: int = _gen
	_advance_walk()
	return _gen != before


## S_SEATED watchdog: the chai StationNode reports is_busy() = his ticket is
## cooking (nobody else is inside during the walk), for a missed
## ticket_started / service_started.
func _poll_cook() -> void:
	if _ev_cooking or Game.sim_paused:
		return
	var st: StationNode = _station_node("chai")
	if st == null or not is_instance_valid(st) or not st.has_method("is_busy"):
		return
	var r: Variant = st.call("is_busy")
	if r is bool and bool(r):
		_ev_cooking = true


## S_DELIVER: keep looking for Raju (throttled) when he was not found on entry.
func _retry_waiter_follow(delta: float) -> void:
	if is_instance_valid(_waiter) and _waiter.is_inside_tree():
		return
	_w_scan_t -= delta
	if _w_scan_t > 0.0:
		return
	_w_scan_t = WAITER_SCAN_EVERY
	var w: Node3D = _find_waiter()
	if w != null:
		_follow_waiter(w)


## S_BREW watchdog: the waiter starts walking (to or from the pass) = he is
## on his way with the kulhad, even if no dispatch / pick-up signal came.
func _poll_waiter_moving(delta: float) -> void:
	if _step != S_BREW:
		return
	if not (is_instance_valid(_waiter) and _waiter.is_inside_tree()):
		_w_seen = false
		_w_scan_t -= delta
		if _w_scan_t > 0.0:
			return
		_w_scan_t = WAITER_SCAN_EVERY
		_waiter = _find_waiter()
		if _waiter == null:
			return
	var p: Vector3 = _waiter.global_position
	if _w_seen and not Game.sim_paused:
		var d: float = Vector2(p.x - _w_last.x, p.z - _w_last.z).length()
		if d / maxf(delta, 0.0001) > MOVE_SPEED:
			_w_move_t += delta
		else:
			_w_move_t = 0.0
		if _w_move_t >= MOVE_TIME:
			_ev_dispatched = true
			_advance_walk()
			return
	_w_last = p
	_w_seen = true


## Galla watchdog: after walking, standing still at the pay spot (or a long
## timeout) moves on even if the galla service signal was missed.
func _poll_arrival(spot: Vector3, next: String) -> void:
	if _step_t > WALK_TIMEOUT:
		_goto(next)
		return
	if not _trav_ok() or Game.sim_paused or not _seen_move:
		return
	var p: Vector3 = _trav.global_position
	var d := Vector2(p.x - spot.x, p.z - spot.z).length()
	if d < ARRIVE_RADIUS and _still_t >= STILL_TIME and _step_t > 0.5:
		_goto(next)


## Moves the scripted walk on from the latched events (idempotent; called by
## every event handler, step entry and the S_SEATED tick).
func _advance_walk() -> void:
	match _step:
		S_FOLLOW:
			if _ev_galla:
				_goto(S_GALLA_PAUSE)
			elif _ev_seated or _ev_cooking:
				_goto(S_SEATED)
		S_SEATED:
			if _ev_galla:
				_goto(S_GALLA_PAUSE)
			elif _ev_served:
				_goto(S_TO_GALLA)   # (a very fast sim: his food is already there)
			elif _ev_cooking and _step_t >= SEAT_DWELL:
				_goto(S_CHAI_PAUSE)
		S_BREW:
			if _ev_galla:
				_goto(S_GALLA_PAUSE)
			elif _ev_served:
				_goto(S_TO_GALLA)
			elif _ev_ready or _ev_dispatched or _ev_picked:
				_goto(S_DELIVER)
		S_DELIVER:
			if _ev_galla:
				_goto(S_GALLA_PAUSE)
			elif _ev_served:
				_goto(S_TO_GALLA)
		S_TO_GALLA:
			if _ev_galla:
				_goto(S_GALLA_PAUSE)


func _tick_free(delta: float) -> void:
	_free_t += delta
	# W4-FIX: the analytics consent card (layer 36, C4.4) is not idle either:
	# the nudge hand and the fallback ad chain wait for its answer.
	var idle: bool = _open_panels.is_empty() and not (_dialogue != null and _dialogue.is_open()) \
			and not Analytics.is_card_open()
	if idle:
		_idle_t += delta
	else:
		_idle_t = 0.0
	_tick_tasks()
	if not _seats_done():
		# The seats beat comes first; nudges and the ad chain count from it.
		_tick_seats(delta)
		return
	var slot := _ready_slot()
	if slot >= 0:
		_ready_t += delta
	else:
		_ready_t = 0.0
		if _hand.is_showing():
			_hand.hide_hand()
	if slot >= 0 and _ready_t > NUDGE_AFTER and _idle_t > IDLE_BEFORE_CHAIN and not _hand.is_showing():
		_hand.point_at(_anchor(["task_card_%d" % slot], true))
	if _idle_t > IDLE_BEFORE_CHAIN and ((slot >= 0 and _ready_t > FALLBACK_READY) or _free_t > FALLBACK_FREE):
		_start_ad_chain(REWARD_TO_LINE, "fallback")


## Seats trigger: a door line for SEATS_DOOR_S while idle. Core and feel
## C4.1: SEATS_FILL_AT s into the free step with no door line and the
## player idle, the Sim fills every free seat and stands SEATS_FILL_DOOR
## travellers at the gate (the door line waits for a seat, C2.1), so the
## trigger fires about 2 s later. W3-FIX: a gate line that drained before
## the trigger (diners leaving, a panel open) gets another fill once the
## player is idle again (SEATS_REFILL_S after the last, SEATS_FILLS in
## all). Skipped only when the tables are maxed, or (failsafe, from
## SEATS_FAILSAFE_AT, no door line) when the fill placed nobody or every
## fill is spent, or at the SEATS_GIVEUP_AT backstop. A door line with the
## player busy in a panel just waits for the calm.
func _tick_seats(delta: float) -> void:
	_seats_t += delta
	var door: Variant = _call(Refs.ui, "door_waiting")
	if (door is int or door is float) and int(door) > 0:
		_door_t += delta
	else:
		_door_t = 0.0
	if Game.table_count() >= Game.table_max():
		_seats_skip("tables_max")
		return
	if _door_t >= SEATS_DOOR_S and _idle_t > IDLE_BEFORE_CHAIN:
		_goto(S_SEATS_LINES)
		return
	if _door_t > 0.0:
		return   # a door line: it waits for the player's calm
	if _seats_t >= SEATS_GIVEUP_AT or (_seats_t >= SEATS_FAILSAFE_AT and _seats_fill_spent()):
		_seats_skip("fill_failed")
		return
	if _seats_t >= SEATS_FILL_AT and _idle_t > IDLE_BEFORE_CHAIN and _seats_fills < SEATS_FILLS \
			and (_seats_fills == 0 or (_seats_fill_n > 0 and _seats_t - _seats_fill_t >= SEATS_REFILL_S)):
		_seats_fills += 1
		_seats_fill_t = _seats_t
		var free_n: int = _seats_free()
		var r: Variant = _call(Refs.sim, "fill_for_seats_beat", [SEATS_FILL_DOOR])
		_seats_fill_n = int(r) if (r is int or r is float) else 0
		print("[tutorial] seats beat: filled %d (%d seats were free) at free +%.1f s (fill %d of %d)" % [
				_seats_fill_n, free_n, _seats_t, _seats_fills, SEATS_FILLS])


## C4.1 failsafe: the fill placed nobody (no Sim hook), or every fill ran
## and SEATS_REFILL_S has passed since the last with no door line.
func _seats_fill_spent() -> bool:
	if _seats_fills <= 0:
		return false
	if _seats_fill_n <= 0:
		return true
	return _seats_fills >= SEATS_FILLS and _seats_t - _seats_fill_t >= SEATS_REFILL_S


## Free seats right now (Sim, else Game's copy of the seat counts).
func _seats_free() -> int:
	var v: Variant = _call(Refs.sim, "seats_free")
	if v is int or v is float:
		return maxi(int(v), 0)
	return maxi(Game.seats_total() - Game.seats_in_use(), 0)


## Round 2 step 2: TASKS are out of the chain. The first claimable task in
## the free step reveals the one-task strip (its "Task done! Tap CLAIM" chip
## is MunshiNotes'); the claim then starts the ad chain as before.
func _tick_tasks() -> void:
	if _ready_slot() < 0 or Game.hud_revealed("tasks"):
		return
	if Game.reveal_hud("tasks"):
		print("[tutorial] task strip revealed (first claimable task) at free +%.1f s" % _free_t)


func _seats_skip(why: String) -> void:
	Game.tutorial_set("seats_done", true)
	_free_t = 0.0
	_ready_t = 0.0
	Analytics.event("tutorial_seats_skipped", {"why": why})
	print("[tutorial] seats beat skipped (%s)" % why)
	if _claim_pending:
		_claim_pending = false
		_start_ad_chain(CLAIM_TO_LINE, "claim")


func _seats_done() -> bool:
	return bool(Game.tutorial_get("seats_done", false))


func _start_ad_chain(delay: float, why: String) -> void:
	_ad_delay = delay
	Analytics.event("tutorial_ad_chain", {"trigger": why})
	_goto(S_AD_DEAL)


func _ready_slot() -> int:
	var i := 0
	for t in Game.tasks:
		if t is Dictionary and bool((t as Dictionary).get("done", false)):
			return i
		i += 1
	return -1


## W4-FIX: Munshi-ji's visible top-up (Game.grant_cash_floor) before a
## purchase the tutorial walks through, at most once per beat and save
## (tutorial key "gift_<key>", set only when it added something). Re-entering
## the beat (the card closed, the cash spent in a sheet the meter opened) no
## longer grants it again, so it cannot be farmed; the Sim keeps selling.
func _gift_once(key: String, amount: float) -> void:
	var k: String = "gift_" + key
	if bool(Game.tutorial_get(k, false)):
		return
	if Game.grant_cash_floor(amount) > 0.0:
		Game.tutorial_set(k, true)


# ================================================================ event handlers
func _on_line_started(id: String = "") -> void:
	match id:
		"l10":
			# Round 2 step 2: the line names STAFF; a pulsing ring around the
			# button through the dim (it came in as STAFF › CASHIERS closed).
			if _step == S_WRAP:
				_reveal_staff()
				var sb := _anchor(["staff_button"], true)
				if sb != null:
					_dialogue.set_highlight([sb], true)
		"lw2":
			# Core and feel C3.1: the line names the new waiter; his "+ WAITER"
			# tag pops in over the ghost by the rack (like LT2's "+ TABLE")
			# and a pulsing ring shows it through the dim.
			if _step == S_WAITER_LINES:
				_unlock_waiter_tag(true)
				_ring_waiter_tag(_gen)
		"lt2":
			# LT1 is said where the problem shows (the full seats, the door
			# line and its "Seats full!" pill); LT2 flies to the next ghost
			# table and its "+ TABLE" tag shows while the line names it.
			if _step == S_SEATS_LINES:
				var cam := _cam()
				if cam != null:
					cam.fly_to(TableTag.table_point(Game.table_count()) + SEATS_VIEW_OFFSET, CameraRig.GAME)
				_allow_taps(["tables"])
		"g2":
			# Step 4: BUILD comes in as G2 names it, as with L16.
			if _step == S_GROW_LINES:
				_call(Refs.hud, "set_mode", ["dialogue", ["build_button"]])
				Game.reveal_hud("build")
		"l16":
			# Round 2 step 2: BUILD appears as the line says "Tap BUILD". The
			# HUD keeps that one button through the hidden-HUD line, so its
			# gold reveal burst is seen.
			_call(Refs.hud, "set_mode", ["dialogue", ["build_button"]])
			Game.reveal_hud("build")


## ---- first-traveller walk events (Sim / StationNode / GallaNode). Each
## takes up to 6 Variant args (the signal shapes vary) and only counts during
## the scripted walk, for the scripted traveller (or when no traveller can be
## read from the args — nobody else is inside then).
func _on_ev_seated(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null, e: Variant = null, f: Variant = null) -> void:
	if _mine([a, b, c, d, e, f]):
		_ev_seated = true
		_advance_walk()


func _on_ev_cook(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null, e: Variant = null, f: Variant = null) -> void:
	if _mine([a, b, c, d, e, f]):
		_ev_cooking = true
		_advance_walk()


func _on_ev_ready(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null, e: Variant = null, f: Variant = null) -> void:
	if _mine([a, b, c, d, e, f]):
		_ev_ready = true   # (args may hold the pass-slot prop: never a waiter)
		_advance_walk()


func _on_ev_dispatch(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null, e: Variant = null, f: Variant = null) -> void:
	if _mine([a, b, c, d, e, f]):
		_ev_dispatched = true
		_note_waiter([a, b, c, d, e, f])
		_advance_walk()


func _on_ev_picked(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null, e: Variant = null, f: Variant = null) -> void:
	if _mine([a, b, c, d, e, f]):
		_ev_picked = true
		_note_waiter([a, b, c, d, e, f])
		_advance_walk()


func _on_ev_served(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null, e: Variant = null, f: Variant = null) -> void:
	if _mine([a, b, c, d, e, f]):
		_ev_served = true
		_advance_walk()


func _on_ev_galla(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null, e: Variant = null, f: Variant = null) -> void:
	if _mine([a, b, c, d, e, f]):
		_ev_galla = true
		_advance_walk()


func _on_trav_paid(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null, _e: Variant = null, _f: Variant = null) -> void:
	if _step == S_WAIT_SALE or _step == S_GALLA_PAUSE or _step == S_TO_GALLA:
		_goto(S_FIRST_SALE)


func _on_sim_sale(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null, _e: Variant = null, _f: Variant = null) -> void:
	if _step == S_WAIT_SALE:
		_goto(S_FIRST_SALE)


func _on_cam_finished(mode: String = "") -> void:
	if _cam_expect == "" or mode == _cam_expect:
		_cam_done = true


func _on_panel_opened(panel: Variant = "") -> void:
	var k := _panel_kind(str(panel))
	_open_panels[k] = true
	match _step:
		S_TAP_CHAI:
			if k == "chai":
				_goto(S_LEVEL)
		S_TAP_GALLA:
			if k == "staff":
				_goto(S_HIRE)
		S_TAP_STAFF:
			# C3.1: the tag's 2-tap card, or STAFF › WAITERS (STAFF, the rack
			# or a waiter).
			if k == "staff" or k == "quick_waiters":
				_goto(S_HIRE_WAITER)
		S_TAP_TABLE:
			if k == "quick_tables" or k == "daftar":
				_goto(S_ADD_TABLE)
		S_BUBBLE:
			if k == "vip":
				_goto(S_VIP)
		S_BUILD_BTN:
			if k == "daftar":
				_goto(S_BUILD_ROW)
		S_GROW_BTN:
			if k == "daftar":
				_goto(S_GROW_ROW)
		S_FREE:
			_hand.hide_hand()


func _on_panel_closed(panel: Variant = "") -> void:
	var k := _panel_kind(str(panel))
	_open_panels.erase(k)
	match _step:
		S_LEVEL:
			if k == "chai":
				_goto(S_TAP_CHAI)
		S_TAP_OUT:
			if k == "chai":
				_goto(_after_chai())
		S_GROW_ROW:
			if k == "daftar" and not Game.build_job_active():
				_goto(S_GROW_BTN)
		S_HIRE:
			if k == "staff":
				_goto(S_TAP_GALLA)
		S_CLOSE_GALLA:
			if k == "staff":
				_goto(S_WRAP)
		S_HIRE_WAITER:
			# Closed without a hire (a tap outside the card, STAFF's X): back
			# to the tag. (The card's "STAFF ›" link closes it and opens STAFF
			# › WAITERS, which comes straight back here.)
			if k == "staff" or k == "quick_waiters":
				_goto(S_TAP_STAFF if Game.waiter_count() < 2 else S_WAITER_DONE)
		S_CLOSE_WAITERS:
			if k == "staff" or k == "quick_waiters":
				_goto(S_WAITER_DONE)
		S_ADD_TABLE:
			if (k == "quick_tables" or k == "daftar") and Game.table_count() <= _tables0:
				_goto(S_TAP_TABLE)
		S_VIP:
			if k == "vip":
				# W4-FIX: closed without the video (its X; the popup cannot
				# close while the ad plays) is a decline, since rewarded ads
				# are opt-in (C7.4): move on to L15 / L16 and the BUILD beat,
				# whose top-up keeps the tandoor reachable, instead of looping
				# bubble -> popup -> X. (No ad fill moved on here before too.)
				if not _vip_taken:
					print("[tutorial] ad beat: FREE BONUS closed without the video")
				_goto(S_AD_LINES)
		S_BUILD_ROW:
			if k == "daftar":
				_goto(S_BUILD_BTN)
		S_BUILD_CLOSE:
			if k == "daftar":
				_goto(S_OUTRO)


func _on_button(id: Variant = "") -> void:
	var b := str(id)
	match _step:
		S_LEVEL:
			if b == "level_up" and _chai_gate_met():
				_goto(S_LINE7)
		S_VIP:
			if b == "vip_free" or b == "vip_unlock":
				_vip_taken = true
				_hand.hide_hand()
				# The reward is in the bank: a relaunch must not replay it.
				_checkpoint("build")
				Game.save_game()
		S_BUILD_ROW:
			if b == "build_tandoor":
				_hand.hide_hand()


func _on_station_changed(id: String = "") -> void:
	if _step == S_LEVEL and id == "chai":
		if _chai_gate_met():
			_goto(S_LINE7)
		else:
			_level_goal(true)


## C3.1: a hire from the 2-tap card skips close_waiters (UiRoot closes the
## card itself, 0.15 s later); STAFF's hire still asks for its X. W3-FIX: a
## hire made before the lesson asks for it (the meter's pulsing WAITERS row
## or STAFF during the plate wait of waiter_lines, or in tap_staff) ends the
## beat the same way, so LW1 / LW2 never teach a hire that is already done
## (nor ring the tag of a third waiter).
func _on_waiter_hired(_index: int = 0) -> void:
	if Game.waiter_count() < 2:
		return
	if _step == S_HIRE_WAITER or _step == S_WAITER_LINES or _step == S_TAP_STAFF:
		if _step != S_HIRE_WAITER:
			print("[tutorial] waiter beat: hired early (step %s)" % _step)
		if _panel_open("quick_waiters"):
			_hired_via_card = true
			print("[tutorial] waiter beat: hired via card")
			_goto(S_WAITER_DONE)
		else:
			_goto(S_CLOSE_WAITERS)


func _on_table_added(_index: int = 0) -> void:
	if (_step == S_ADD_TABLE or _step == S_TAP_TABLE) and Game.table_count() > _tables0:
		_goto(S_SEATS_DONE)


func _on_galla_changed(_index: int = 0) -> void:
	if _step == S_HIRE and Game.galla_count() >= 2:
		_goto(S_CLOSE_GALLA)


func _on_building_built(id: String = "") -> void:
	if id == "tandoor":
		Game.tutorial_set("built", true)
		if _step == S_BUILD_ROW or _step == S_BUILD_BTN:
			_show_tandoor = true
			_goto(S_BUILD_CLOSE)


## Step 4: the shack's construction started from BUILD (or the free
## fallback): on to the site. Its end saves the checkpoint for the reload.
func _on_build_job_changed(kind: String = "") -> void:
	if kind == "shack" and (_step == S_GROW_BTN or _step == S_GROW_ROW or _step == S_GROW_LINES):
		_hand.hide_hand()
		_goto(S_GROW_SITE)
	elif kind == "" and _step == S_GROW_SITE:
		_hand.hide_hand()
		_checkpoint("shack")


func _on_reveal_started(_kind: String = "") -> void:
	_reveal_on = true


func _on_reveal_finished(_kind: String = "") -> void:
	_reveal_on = false


func _on_task_claimed(_slot: int = -1, _reward: float = 0.0) -> void:
	Game.tutorial_set("claimed", true)
	if _step == S_FREE and _seats_done():
		_start_ad_chain(CLAIM_TO_LINE, "claim")
	elif _step == S_FREE or SEATS_STEPS.has(_step):
		# The seats beat comes first; the ad chain starts right after it.
		_claim_pending = true


# ================================================================ wiring
func _ensure_nodes() -> void:
	if _dialogue == null:
		var existing := Refs.dialogue as DialogueBox
		if existing != null:
			_dialogue = existing
		else:
			_dialogue = DialogueBox.new()
			_dialogue.name = "DialogueBox"
			add_child(_dialogue)
			Refs.dialogue = _dialogue
	if _hand == null:
		_hand = HandPointer.new()
		_hand.name = "HandPointer"
		add_child(_hand)
	if Refs.director == null:
		Refs.director = self


func _wire() -> void:
	_connect(Game, "station_changed", _on_station_changed)
	_connect(Game, "galla_changed", _on_galla_changed)
	_connect(Game, "building_built", _on_building_built)
	_connect(Game, "task_claimed", _on_task_claimed)
	_connect(Game, "waiter_hired", _on_waiter_hired)
	_connect(Game, "table_added", _on_table_added)
	_connect(Game, "build_job_changed", _on_build_job_changed)
	_connect(Fx, "reveal_started", _on_reveal_started)
	_connect(Fx, "reveal_finished", _on_reveal_finished)
	_connect(_dialogue, "line_started", _on_line_started)
	_connect(Refs.camera, "move_finished", _on_cam_finished)
	_connect(Refs.ui, "panel_opened", _on_panel_opened)
	_connect(Refs.ui, "panel_closed", _on_panel_closed)
	_connect(Refs.ui, "button_pressed", _on_button)
	_connect(Refs.sim, "sale", _on_sim_sale)
	_connect(Refs.sim, "first_sale", _on_sim_sale)
	# Seated-dhaba flow (every name is optional; aliases are harmless).
	_connect(Refs.sim, "traveller_seated", _on_ev_seated)
	_connect(Refs.sim, "traveller_sat", _on_ev_seated)
	_connect(Refs.sim, "ticket_started", _on_ev_cook)
	_connect(Refs.sim, "station_service_started", _on_ev_cook)
	_connect(Refs.sim, "item_ready", _on_ev_ready)
	_connect(Refs.sim, "item_cooked", _on_ev_ready)
	_connect(Refs.sim, "ticket_done", _on_ev_ready)
	_connect(Refs.sim, "waiter_assigned", _on_ev_dispatch)
	_connect(Refs.sim, "waiter_dispatched", _on_ev_dispatch)
	_connect(Refs.sim, "waiter_picked", _on_ev_picked)
	_connect(Refs.sim, "item_picked", _on_ev_picked)
	_connect(Refs.sim, "item_served", _on_ev_served)
	_connect(Refs.sim, "item_delivered", _on_ev_served)
	_connect(Refs.sim, "waiter_served", _on_ev_served)
	_connect(Refs.sim, "galla_service_started", _on_ev_galla)
	_wire_world()


## Station / galla node signals (the nodes exist once Sim has built the world).
func _wire_world() -> void:
	var st := _station_node("chai")
	if st != null:
		_connect(st, "service_started", _on_ev_cook)
		_connect(st, "service_done", _on_ev_ready)
	var gn := _galla_node(0)
	if gn != null:
		_connect(gn, "service_started", _on_ev_galla)


func _connect(obj: Object, sig: String, c: Callable) -> void:
	if obj == null or not is_instance_valid(obj) or not obj.has_signal(sig):
		return
	if not obj.is_connected(sig, c):
		obj.connect(sig, c)


## The tutorial's first traveller. No arguments: Sim places him at its parked
## lorry (point 11) and routes him to the nearest free seat.
func _spawn_traveller() -> void:
	_trav = null
	_state_names_read = false
	_reset_walk_events()
	var r: Variant = _call(Refs.sim, "spawn_scripted", [])
	if is_instance_valid(r) and r is Traveller:
		_set_trav(r as Traveller)
	else:
		_adopt_scripted()


## Picks up Sim.scripted_traveller when spawn_scripted() returned nothing (or
## the Sim places him at its parked lorry a little later).
func _adopt_scripted() -> void:
	if _trav_ok():
		return
	var s: Node = Refs.sim
	if s == null or not is_instance_valid(s):
		return
	var r: Variant = s.get("scripted_traveller")
	if is_instance_valid(r) and r is Traveller:
		_set_trav(r as Traveller)


func _set_trav(t: Traveller) -> void:
	if t == _trav:
		return
	_trav = t
	_state_names_read = false
	_connect(_trav, "paid", _on_trav_paid)
	# Traveller-level mirrors of the seated flow (optional; harmless if absent).
	_connect(_trav, "seated", _on_ev_seated)
	_connect(_trav, "sat_down", _on_ev_seated)
	_connect(_trav, "food_served", _on_ev_served)
	_connect(_trav, "item_served", _on_ev_served)
	_connect(_trav, "got_food", _on_ev_served)
	_last_pos = _trav.global_position if _trav.is_inside_tree() else Layout3.SPAWN


func _reset_walk_events() -> void:
	_ev_seated = false
	_ev_cooking = false
	_ev_ready = false
	_ev_dispatched = false
	_ev_picked = false
	_ev_served = false
	_ev_galla = false
	_waiter = null


# ================================================================ helpers
func _say(ids: Array) -> void:
	var lines: Array = ScriptLines.lines(ids)
	if lines.is_empty() or _dialogue == null:
		return
	var first: Dictionary = lines[0]
	if bool(first.get("hide_hud", false)):
		_hud_mode("dialogue")
	_dialogue.play(lines)
	await _dialogue.closed


func _wait(sec: float) -> void:
	if sec <= 0.0:
		return
	await get_tree().create_timer(sec).timeout


func _cam_wait_for(mode: String) -> void:
	_cam_expect = mode
	_cam_done = false


func _await_cam(timeout: float) -> void:
	var t := 0.0
	while not _cam_done and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	_cam_expect = ""


func _cam() -> CameraRig:
	return Refs.camera as CameraRig


func _trav_ok() -> bool:
	return _trav != null and is_instance_valid(_trav) and _trav.is_inside_tree()


## A Sim event counts for the scripted walk: we are in it, and the event is
## about our traveller (or names none — nobody else is inside then).
func _mine(args: Array) -> bool:
	if not WALK_STEPS.has(_step):
		return false
	var t: Traveller = _event_traveller(args)
	if t == null:
		return true
	return is_instance_valid(_trav) and t == _trav


## The Traveller an event is about: a Traveller arg, or the `traveller`-like
## field of a ticket object / Dictionary arg.
func _event_traveller(args: Array) -> Traveller:
	for a in args:
		if a is Dictionary:
			var dict: Dictionary = a
			for k in TRAV_KEYS:
				var dv: Variant = dict.get(k, null)
				if is_instance_valid(dv) and dv is Traveller:
					return dv as Traveller
			continue
		if not is_instance_valid(a):
			continue
		if a is Traveller:
			return a as Traveller
	for a in args:
		if not is_instance_valid(a) or a is Traveller or a is StationNode or a is GallaNode:
			continue
		var o: Object = a
		for k in TRAV_KEYS:
			if k in o:
				var v: Variant = o.get(k)
				if is_instance_valid(v) and v is Traveller:
					return v as Traveller
	return null


## The waiter an event names: a Node3D arg that is not a traveller / station /
## galla (and is in Sim.waiters when that list exists), or a ticket's
## `waiter` field.
func _event_waiter(args: Array) -> Node3D:
	for a in args:
		if a is Dictionary:
			var dict: Dictionary = a
			for k in WAITER_KEYS:
				var dv: Variant = dict.get(k, null)
				if _is_waiter_node(dv):
					return dv as Node3D
			continue
		if not is_instance_valid(a):
			continue
		if _is_waiter_node(a):
			return a as Node3D
	for a in args:
		if not is_instance_valid(a) or a is Traveller:
			continue
		var o: Object = a
		for k in WAITER_KEYS:
			if k in o:
				var v: Variant = o.get(k)
				if _is_waiter_node(v):
					return v as Node3D
	return null


## A waiter named by an event: one of Sim.waiters when that list exists,
## else any character node (has a CharacterRig) that is not a traveller —
## never a plain prop such as the kulhad on the pass.
func _is_waiter_node(v: Variant) -> bool:
	if not is_instance_valid(v) or not (v is Node3D):
		return false
	if v is Traveller or v is StationNode or v is GallaNode:
		return false
	var list: Array = _sim_waiters()
	if list.is_empty():
		return _is_character(v as Node3D)
	for e in list:   # (no Array.has: a typed Array[Waiter] logs on a foreign type)
		if e == v:
			return true
	return false


## Sim.waiters filtered to live Node3Ds in the tree (empty when Sim has no
## such list, or keeps something else in it).
func _sim_waiters() -> Array:
	var out: Array = []
	var s: Node = Refs.sim
	if s == null or not is_instance_valid(s):
		return out
	var v: Variant = s.get("waiters")
	if not (v is Array):
		return out
	for e in (v as Array):
		if is_instance_valid(e) and e is Node3D and (e as Node3D).is_inside_tree():
			out.append(e)
	return out


## A walking character: a CharacterRig itself, or a node holding one (a
## `rig` property or a CharacterRig child).
static func _is_character(n: Node3D) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n is CharacterRig:
		return true
	var o: Object = n
	var r: Variant = o.get("rig")
	if is_instance_valid(r) and r is CharacterRig:
		return true
	for c in n.get_children():
		if c is CharacterRig:
			return true
	return false


## Raju-looking node: name, script class or staff_name says "waiter" or the
## first waiter's name, and it is a character (not the tray rack or its tap
## area).
func _looks_like_waiter(n: Node) -> bool:
	if not is_instance_valid(n) or not (n is Node3D) or n is Traveller or n is Area3D:
		return false
	var label: String = str(n.name).to_lower()
	var scr: Script = n.get_script() as Script
	if scr != null:
		label += " " + str(scr.get_global_name()).to_lower()
	var o: Object = n
	var sn: Variant = o.get("staff_name")
	if sn is String or sn is StringName:
		label += " " + str(sn).to_lower()
	var raju: String = Game.waiter_staff_name(0).to_lower()
	if not (label.contains("waiter") or (raju != "" and label.contains(raju))):
		return false
	return _is_character(n as Node3D)


## Remember the waiter an event names; re-target the delivery follow to him.
func _note_waiter(args: Array) -> void:
	var w: Node3D = _event_waiter(args)
	if w == null:
		return
	if is_instance_valid(_waiter) and w == _waiter:
		return
	_waiter = w
	if _step == S_DELIVER:
		_follow_waiter(w)


## The waiter carrying the first kulhad: the one an event named, else the
## first of Sim.waiters (Raju — one waiter during the tutorial), else
## Sim.get_waiter(0), else a Raju-looking character under the Sim (name or
## class "waiter" / Game.waiter_staff_name(0)). Callers throttle this.
func _find_waiter() -> Node3D:
	if is_instance_valid(_waiter) and _waiter.is_inside_tree():
		return _waiter
	var list: Array = _sim_waiters()
	if not list.is_empty():
		return list[0] as Node3D
	var s: Node = Refs.sim
	if s == null or not is_instance_valid(s):
		return null
	if s.has_method("get_waiter") and s.get_method_argument_count("get_waiter") >= 1:
		var r: Variant = s.call("get_waiter", 0)
		if is_instance_valid(r) and r is Node3D and (r as Node3D).is_inside_tree():
			return r as Node3D
	var raju: String = Game.waiter_staff_name(0)
	var patterns: Array[String] = ["*aiter*"]
	if raju.length() > 1:
		patterns.append("*" + raju.substr(1) + "*")   # "*aju*": either case of the initial
	for pat in patterns:
		for n in s.find_children(pat, "Node3D", true, false):
			if _looks_like_waiter(n):
				return n as Node3D
	return null


func _follow_waiter(w: Node3D) -> void:
	if not is_instance_valid(w) or not w.is_inside_tree():
		return
	_waiter = w
	var cam := _cam()
	if cam != null:
		cam.follow(w)


## Traveller-side seated flag, when Traveller exposes one (is_seated() or a
## `seated` property).
func _trav_reports_seated() -> bool:
	if not _trav_ok():
		return false
	var o: Object = _trav
	if o.has_method("is_seated") and o.get_method_argument_count("is_seated") == 0:
		var r: Variant = o.call("is_seated")
		return r is bool and bool(r)
	var v: Variant = o.get("seated")   # (a `seated` signal reads as a Signal: ignored)
	return v is bool and bool(v)


## The scripted traveller's FSM state as an upper-case name ("" if unknown):
## an int `state` is named through the `S` enum of his script's constant map
## (read once), so states the SIM module adds need no compile-time reference.
func _trav_state() -> String:
	if not _trav_ok():
		return ""
	var o: Object = _trav
	var sv: Variant = o.get("state")
	if sv is String or sv is StringName:
		return str(sv).to_upper()
	if not (sv is int):
		return ""
	if not _state_names_read:
		_state_names_read = true
		_state_names.clear()
		var scr: Script = _trav.get_script() as Script
		if scr != null:
			var e: Variant = scr.get_script_constant_map().get("S", null)
			if e is Dictionary:
				var ed: Dictionary = e
				for k in ed:
					var val: Variant = ed[k]
					if val is int:
						_state_names[int(val)] = str(k).to_upper()
	return str(_state_names.get(int(sv), ""))


## True when p is at one of Layout3.SEATS (or when that constant is missing).
func _near_seat(p: Vector3) -> bool:
	var seats: Array = _seat_points()
	if seats.is_empty():
		return true
	for s in seats:
		var q: Vector3 = s
		if Vector2(p.x - q.x, p.z - q.z).length() <= SEAT_RADIUS:
			return true
	return false


## Layout3.SEATS flattened to Vector3s (accepts a flat list, one list per
## table, or {pos: Vector3} entries); read once, then cached.
func _seat_points() -> Array:
	if _seats_loaded:
		return _seats_cache
	_seats_loaded = true
	_seats_cache.clear()
	var v: Variant = _layout_const("SEATS")
	if v is Array or v is PackedVector3Array:
		for e in v:
			_add_seat_point(e)
			if e is Array or e is PackedVector3Array:
				for e2 in e:
					_add_seat_point(e2)
	return _seats_cache


func _add_seat_point(e: Variant) -> void:
	if e is Vector3:
		_seats_cache.append(e)
	elif e is Transform3D:
		var tf: Transform3D = e
		_seats_cache.append(tf.origin)
	elif e is Dictionary:
		var d: Dictionary = e
		for k in ["pos", "position", "at"]:
			var p: Variant = d.get(k, null)
			if p is Vector3:
				_seats_cache.append(p)
				return


## A Layout3 constant by name, or null (read at runtime so a constant the SIM
## module has not added yet is not a compile error here).
func _layout_const(const_name: String) -> Variant:
	if not _layout_loaded:
		_layout_loaded = true
		var scr: Script = load(LAYOUT_PATH) as Script
		if scr != null:
			_layout_map = scr.get_script_constant_map()
	return _layout_map.get(const_name, null)


func _station_node(id: String) -> StationNode:
	var s: Object = Refs.sim
	if s == null:
		return null
	var d: Variant = s.get("stations")
	if d is Dictionary and (d as Dictionary).has(id):
		return (d as Dictionary)[id] as StationNode
	return null


func _galla_node(i: int) -> GallaNode:
	var s: Object = Refs.sim
	if s == null:
		return null
	var a: Variant = s.get("gallas")
	if a is Array and i >= 0 and i < (a as Array).size():
		return (a as Array)[i] as GallaNode
	return null


## First Control any of `names` resolves to (UiRoot first, or Hud first).
func _anchor(names: Array, hud_first: bool = false) -> Control:
	var srcs: Array = [Refs.hud, Refs.ui] if hud_first else [Refs.ui, Refs.hud]
	for n in names:
		for src in srcs:
			if typeof(src) != TYPE_OBJECT or not is_instance_valid(src):
				continue
			var o: Object = src
			if not o.has_method("anchor"):
				continue
			var c: Variant = o.call("anchor", str(n))
			if c is Control:
				return c as Control
	return null


## Like _anchor, but waits up to ANCHOR_WAIT s for a world tag that is
## still popping in (null if it never shows).
func _anchor_soon(names: Array) -> Control:
	var g := _gen
	var t := 0.0
	var a := _anchor(names)
	while a == null and t < ANCHOR_WAIT and g == _gen:
		await get_tree().process_frame
		t += get_process_delta_time()
		a = _anchor(names)
	return a


func _panel_open(kind: String) -> bool:
	return _open_panels.has(kind)


## The seats beat's buy screens: the ghost table's 2-tap card or BUILD.
func _tables_open() -> bool:
	return _panel_open("quick_tables") or _panel_open("daftar")


## STAFF on the HUD for good (gold burst the first time; Game saves it).
func _reveal_staff() -> void:
	Game.reveal_hud("staff")


## Core and feel C2.6: the bottleneck meter on the HUD for good, from the
## waiter beat on (the HUD prints "[hud] meter revealed at <t>").
func _reveal_meter() -> void:
	Game.reveal_hud("meter")


## C3.1: UiRoot shows the ghost waiter's "+ WAITER" tag in the tutorial only
## while rack_tag_unlocked and "waiters" taps are named; off again after the
## waiter beat ("waiters" taps alone still let the rack and the waiters open
## STAFF › WAITERS).
func _unlock_waiter_tag(on: bool) -> void:
	_set_prop(Refs.ui, "rack_tag_unlocked", on)
	if on:
		_allow_taps(["waiters"])


## C3.1: once the tag has popped in (UiRoot polls it), a pulsing ring around
## it through LW2's dim.
func _ring_waiter_tag(g: int) -> void:
	var a: Control = await _anchor_soon(["waiter_tag"])
	if g != _gen or a == null or _dialogue == null or not _dialogue.is_open() or _dialogue.current_id() != "lw2":
		return
	_dialogue.set_highlight([a], true)


## The open STAFF panel on `tab` (STAFF opens on the tab that needs it most,
## which during a beat may be another one): switched in place.
func _staff_tab(tab: String) -> void:
	var ui: Node = Refs.ui
	if ui == null or not is_instance_valid(ui):
		return
	var cur: String = str(ui.get("current_panel"))
	if cur.begins_with("staff:") and cur != "staff:" + tab:
		_call(ui, "open_staff", [tab, {"highlight": "hire"}])


## Plates on a pass waiting for a waiter (cooked, nobody coming for them):
## the ones the Sim draws orange wait rings under. Core and feel C2.3: the
## plates held on the counter's plate stool (pass full) count too.
func _plates_waiting() -> int:
	var s: Object = Refs.sim
	if s == null or not is_instance_valid(s):
		return 0
	var d: Variant = s.get("stations")
	if not (d is Dictionary):
		return 0
	var n: int = 0
	for sv in (d as Dictionary).values():
		var st: StationNode = sv as StationNode
		if st == null or not is_instance_valid(st):
			continue
		for list: Array in [st.pass_items, st.held_tickets]:
			for v in list:
				var tk: StationNode.Ticket = v as StationNode.Ticket
				if tk != null and tk.state == StationNode.TK.READY and tk.waiter == null:
					n += 1
	return n


## A6.5: the chai sheet's bar shows "GOAL Lv 10" and the hand carries the
## "n/10" caption while the level gate runs.
func _level_goal(on: bool) -> void:
	var ui: Node = Refs.ui
	var sheet: Variant = ui.get("station_sheet") if ui != null and is_instance_valid(ui) else null
	if sheet is Object and is_instance_valid(sheet) and (sheet as Object).has_method("set_goal_level"):
		(sheet as Object).call("set_goal_level", LEVEL_GATE if on else 0)
	if _hand != null:
		_hand.set_caption("%d/%d" % [mini(Game.station_level("chai"), LEVEL_GATE), LEVEL_GATE] if on else "")


## The wall-ad anchor projects inside BUBBLE_SAFE (the bubble is unclamped).
## Canvas x is taken relative to a centred 720 px column (a wider "expand"
## viewport adds equal space both sides); the bottom edge follows a taller one.
func _bubble_in_view(cam: CameraRig) -> bool:
	var c: Camera3D = cam.get_camera()
	if c == null or c.is_position_behind(Layout3.WALL_AD):
		return false
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sp: Vector2 = c.unproject_position(Layout3.WALL_AD)
	sp.x -= (vp.x - 720.0) * 0.5
	var r: Rect2 = BUBBLE_SAFE
	r.size.y += maxf(0.0, vp.y - 1280.0)
	return r.has_point(sp)


## Round 2 step 2: every STAFF tab is one kind, "staff" (a tab switch inside
## the panel emits no open / close, so the kind must not follow the tab);
## the 2-tap cards are "quick_waiters" / "quick_tables".
static func _panel_kind(panel: String) -> String:
	var n := panel.to_lower()
	if n.begins_with("staff:") or n == "staff":
		return "staff"
	if n.begins_with("quick:"):
		return "quick_" + n.substr(6)
	if n.contains("vip"):
		return "vip"
	if n.contains("daftar") or n.contains("hisaab") or n.contains("management"):
		return "daftar"
	if n.contains("galla"):
		return "galla"
	if n.contains("waiter"):
		return "waiters"
	if n.contains("seat") or n.contains("table"):
		return "seating"
	if n.contains("tandoor"):
		return "tandoor"
	if n.contains("chai") or n.contains("station") or n.contains("sheet"):
		return "chai"
	return n


func _chai_gate_met() -> bool:
	if Game.station_level("chai") >= LEVEL_GATE or Game.level_maxed("chai"):
		return true
	# Never soft-lock: if the next level is unaffordable, move on.
	return not Game.can_afford(Game.level_cost("chai"))


func _reveal(level: int) -> void:
	if Game.hud_reveal < level:
		Game.hud_reveal = level


func _hold_spawns(on: bool) -> void:
	_set_prop(Refs.sim, "hold_spawns", on)


func _lock_input(on: bool) -> void:
	var cam := _cam()
	if cam != null:
		cam.input_locked = on


## UiRoot.allowed_taps: [] = every world tap allowed; ["none"] = none.
## (UiRoot's own convention is the opposite: ["*"] = all, [] = none — mapped here.)
func _allow_taps(ids: Array) -> void:
	var typed: Array[String] = []
	if ids.is_empty():
		typed.append("*")
	else:
		for i in ids:
			if str(i) != "none":
				typed.append(str(i))
	_set_prop(Refs.ui, "allowed_taps", typed)


func _hud_mode(mode: String) -> void:
	_call(Refs.hud, "set_mode", [mode])


## UiRoot.allowed_buttons (same convention as UiRoot: ["*"] = all).
func _allow_buttons(ids: Array) -> void:
	var typed: Array[String] = []
	for i in ids:
		typed.append(str(i))
	_set_prop(Refs.ui, "allowed_buttons", typed)


## Back to the view the wall-ad beat left (or the free-play home view when
## the beat was resumed from a save).
func _restore_bubble_view() -> void:
	var cam := _cam()
	if cam == null:
		return
	var back: Vector3 = _bubble_return
	_bubble_return = Vector3.INF
	if not back.is_finite():
		cam.fly_home()
		return
	cam.fly_to(back, CameraRig.GAME)


## TargetMarker.show_at takes a FLOOR point (tip `tip` m above it; default
## level with the clerk's head).
func _marker_at(floor_pos: Vector3, tip: float = TargetMarker.TIP_HEIGHT) -> void:
	Fx.marker_show(floor_pos, tip)
	_marker_on = true


func _marker_off() -> void:
	if _marker_on:
		_marker_on = false
		Fx.marker_hide()


static func _floor(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)


func _call(obj: Object, method: String, args: Array = []) -> Variant:
	if obj == null or not is_instance_valid(obj):
		return null
	if not obj.has_method(method):
		push_warning("Director: %s has no %s()" % [obj.get_class(), method])
		return null
	return obj.callv(method, args)


func _set_prop(obj: Object, prop: String, value: Variant) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	if prop in obj:
		obj.set(prop, value)
