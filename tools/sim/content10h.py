#!/usr/bin/env python3
"""content10h.py - design prototype for docs/content-10h; not used by the game or the gates.

Pacing prototype for the 10-hour content pitch (docs/content-10h). It reuses the
pacing tool's seated model (tools/sim/pacing_v3.py: part A tutorial replay, then
the expected-value SeatedModel of part B with the --promo bot) and adds, on top:
more highways, a hotel stage per highway, the Izzat meta currency with perks,
dish-mastery stars, a sessions mode and purchase-cadence statistics. It never
writes anything and never changes pacing_v3.py or themes/dhaba/economy.json.

OVERLAYS: tools/sim/content10h/<name>.json. Everything except the "content" key
is deep-merged in memory over themes/dhaba/economy.json (dicts merge key by key;
lists and numbers replace; null deletes a key), so an overlay can change any
economy number. The "content" key holds the new mechanics (below). The empty
overlay (content10h/none.json = {}) is today's game: --check proves it gives
exactly the marks of pacing_v3.py --promo.

MODEL: pacing_v3's SeatedModel itself (expected values, dt 0.5 s), subclassed.
Two exact speed-ups (no change to any result): capacity() and the order-share
table are cached on the state they depend on, and the price-lock scan of each
step walks only the travellers still waiting for their food. --dt 1 or 2 is a
faster, approximate step (the doc gives its error). Part B is deterministic:
the seeds only choose the tutorial replay part B starts from (as pacing_v3).

CONTENT KEYS (every number of the new mechanics; default = off / today):
content.highways: list. Each entry names a highway by "id". An id already in
  locations (nh44, nh48) adjusts that highway; a new id is appended to
  locations.order. Game keys, as locations.nh48: name, region, mult (prices x
  mult; x renovation.mult too once renovated), cost (the move, paid on the
  previous highway), requires (unlock rule, below; default
  "renovated_all_dishes"), rebuild (true: every counter but chai is rebuilt
  after the move), stations (menu overlay; the menus are a 1.0 factor in the
  model). Prototype keys:
    cost_mult (1.0): x every post-tutorial cost on this highway (like
      difficulty.cost_mult: Level Up from chai L25, cooks, speed, builds bar the
      tandoor, waiters bar the 2nd, tables bar the 3rd, signboard);
    start ("family"): "family" = the renovation carries over (NH 48 today);
      "roadside" = the highway starts roadside and has its own renovation;
    renovation_cost (renovation.cost x cost_mult), renovation_mult
      (renovation.mult): that highway's own renovation (start "roadside");
    hotel (true): false = no hotel stage on this highway; a dict = keys merged
      over content.hotel for this highway.
  Unlock rules (requires, hotel.unlock, hotel.done): a list, or a string with
  "+" between tokens: all_dishes (every counter built and at its last dish),
  renovated (in the family layout), hotel (hotel open), hotel_done (hotel open
  and its done rule met), rooms_all, rooms:N, room_level:L (every room >= L),
  counters_level:L (every counter built and >= L), stars:N (mastery stars),
  izzat:N (Izzat earned). "renovated_all_dishes" = renovated+all_dishes.
content.hotel (the third stage, after the family stage; one block for every
  highway, scaled by the highway's price mult when scale_with_mult):
    enabled (false); unlock ("renovated+all_dishes"); cost (opening, ref units);
    scale_with_mult (true: every hotel cost and rate x the highway's price
    mult); rooms_start (rooms the opening brings, level 1); rooms_max;
    room_costs (list: room rooms_start+1, +2, ...), room_cost_growth (after the
    list); room_level_max; level_cost_base, level_cost_growth (room level L ->
    L+1 costs base x growth^(L-1)); rate_base, rate_growth (a room at level L
    pays rate_base x rate_growth^(L-1) per occupied night); occupancy (share
    of rooms filled each night); night_s (null = daynight.cycle_s, 600 game s:
    one night per day cycle of play); pay ("dawn": the night's pay lands each
    night_s of play; "continuous": the same per second); done ("rooms_all":
    the stage's content is done); offline_share (0: share of the hotel's
    income paid while away, sessions mode), offline_cap_hours (8); bias (1.0:
    the bot buys or saves for the best hotel item when its income per rupee
    is >= bias x the best LEVEL UP's). The hotel never resets the dhaba; its
    income stops after a move.
content.izzat (meta currency, never reset):
    enabled (false); start (0);
    earn.stage_done {roadside, family, hotel}: Izzat when a stage's content is
      done (all dishes; the hotel's done rule);
    earn.promotion {renovation, hotel, move}: Izzat on each promotion;
    earn.dish_unlock: per dish put on a menu (the first time per highway);
    earn.star: per mastery star; earn.baraat_step: list, per baraat step
      (sessions mode); festivals carry their own;
    perks {id: {name, effect, per_level, costs [Izzat per level], applies_on}}.
      effect: price_mult (+per_level x L on every price), cook_speed (cooking
      time / (1 + per_level x L)), waiter_speed (x (1 + per_level x L)),
      start_cash (per_level x L x the new price mult, ref units, after a reset),
      start_waiters / start_tables (+per_level x L at a reset, capped),
      offline_hours (+ per_level x L on offline.cap_hours), signboard_start
      (level after a move), hotel_rate (hotel income x (1 + per_level x L)).
      applies_on (["move"]): the resets a start_* effect applies to ("move",
      "renovation");
    policy ("cheapest": the bot buys the cheapest next perk level it can
      afford; a list of perk ids: strict priority, it saves for the first one
      with levels left).
    lock_idle_perks (false): true = a start_* perk is locked (the bot skips
      it) while no reset it applies on is still ahead: no next highway for
      "move", the renovation already done for "renovation" (the design's
      "Works at your next highway" lock, report §4.1).
content.mastery (dish stars):
    enabled (false); thresholds ([500, 2000, 10000] serves per dish -> stars);
    scope ("highway": every regional dish counts on its own; "slot": a counter's
      n-th dish counts across highways); dish_price_per_star (each star: +x on
      that dish's price, so the counter's mean price x sum of mix weight x
      (1 + x stars)); set_bonus (+x on a counter's prices per set level = the
      lowest star count of its dishes on this highway); global_per_stars,
      global_mult (+global_mult on every price per global_per_stars stars).
    Serves per dish = arrivals x the counter's order share x the dish's mix
      weight (pacing_v3's served_dish model).
content.sessions (only with --sessions): per_day (3), minutes (20), starts_h
    ([8, 13, 21] local hours), install_weekday (1 = Monday; 0 = Sunday),
    offline_ad (true: the bot doubles the offline pay with the rewarded ad when
    allowed), special_share (0.08: Aaj ka special, the bill x (1 + share x
    (special.mult - 1)) from day 2), baraat (true: weekends of event.baraat),
    guest_rate (2.4 baraat guests a minute of play, G-event-pace).
content.festivals (sessions mode): list of {name, day (days after install),
    days, izzat, cash_minutes (minutes of the reward rate)}, paid once at the
    first session inside the window.

EXTENSIONS (design step, 3 Nov 2026: docs/content-10h/research/sim.md §10 and
docs/content-10h/report.md). Merged from the two design copies and the judges'
harnesses; every one is off by default, so --check stays REGRESSION OK.
  content.max_phase (null): leave out every highway, perk, festival, hotel, decor
    and counter-look block whose "phase" is above it. One overlay holds every
    phase; --phase N is --set content.max_phase=N. content.ladder_limit (null):
    keep only the first N highways.
  content.hotel: phase (null: always; else the phase it ships in);
    guests_per_tpm (null: the constant occupancy; else a night's guests = this
    x the realized travellers a minute, filling the best rooms first, and the
    bot's room gains follow the same rule); in_rewards (false: the hotel's
    income joins the reward rate that sizes ads, cards and the chest);
    offline_x2 (false: the offline ad doubles the hotel's offline line too);
    tier_new (false: the FIRST room on a highway to reach a level is NEW, a new
    look) with tier_levels (null = every level; a list = only those levels).
    The token hotel_done holds on a highway that has no hotel (a phase without it).
  content.izzat.earn: all_dishes (Izzat once per highway when its 16 dishes are
    on, in any stage); daily_salaam (the first session of each new calendar day,
    this much Izzat per dhaba left behind; sessions mode) and daily_salaam_max
    (null: no cap; else at most this much a morning). A perk may carry "phase".
  content.mastery: station_mult {counter: x} and slot_mult [x per menu slot]: a
    star tier needs threshold x counter factor x slot factor serves (so slots
    do not cross tiers together); count_tutorial (false: the slot-1 chai track
    starts with the tutorial replay's serves, as dish_counts does in the game).
  content.festivals entries with "steps": a guest track on the baraat machinery
    (sessions mode): guests at guest_rate (default sessions.guest_rate) a minute
    of play from min_free_play_s, steps [guests], reward_minutes [minutes of the
    reward rate per step], step_izzat [Izzat per step]. Inside its window it takes
    the one event slot (no separate baraat). May carry "phase".
  content.counter_looks {levels, phase}: a counter level in the list is a new
    look the first time per highway per counter (FRESH, not NEW). The player
    design's content.visible_levels list is read as its levels.
  content.decor {enabled, phase, unlock, base, growth, items, price_per_item}:
    cosmetic dhaba items bought with the cash left after the bot's own spending
    once the unlock rule holds; item k costs base x growth^k x the price mult;
    each adds price_per_item on every price. A NEW purchase.
  --phase N, --days N (sessions freshness covers days 1..N, default 15).
  Reporting (FRESH, the one strict count of "something new"): NEW purchases
    (with tier_new, only the first room per look per highway) + recipe stars +
    baraat and festival steps + counter looks. Printed: FRESH cadence inside and
    after the story with its five longest waits, the binge view (bot time until
    the first wait of more than 15 and 30 minutes), the hotel's share when each
    hotel is done, decor and festival lines; in sessions mode a FRESHNESS block:
    the story's end in play time, in-app hours and calendar day and clock, the
    day 10 in-app hours are reached, days 1..N with nothing FRESH or no NEW
    purchase, sessions with nothing FRESH and the longest run of them, the
    offline share of all money, the salaam, and a per-day table. SUMMARY gains an
    "ext" block.

OUTPUT: CURVE (per highway and stage: start, all done, unlock, left, duration,
mult, purchases, buy moments, gap p50 / p90 / max, dry 5-minute windows, for ALL
purchases and for NEW ones: a dish put on the menu for the first time on the
highway, a build, a hire, a table, a signboard level, a tray, a promotion, a
room, a perk), the promotion saves, a TIMELINE every --every minutes, Izzat /
perks / stars / hotel, and a "SUMMARY {json}" line. With --sessions it runs the
continuous bot and the sessions bot and prints calendar days next to bot time.

Usage (python: /Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 -I):
  content10h.py [--overlay tools/sim/content10h/pitch_v0.json] [--minutes 420]
                [--seeds 40] [--seed 0] [--no-ads] [--ad-sessions M] [--realized R]
                [--no-signboard] [--no-trays] [--starter MIN] [--difficulty D]
                [--sessions 3x20] [--dt 0.5] [--every 10] [--set PATH=JSON]
                [--check] [--check-minutes 100] [--quiet] [--json-out FILE]
                [--phase N] [--days 15]
  The final design: --overlay tools/sim/content10h/design_final.json --phase 1
  (before the soft launch), 2, 3 (after the data) or 4 (the reserve highways).
"""
import argparse
import bisect
import copy
import json
import math
import subprocess
import sys
import time
from collections import deque
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True          # never leave a __pycache__ in tools/sim
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))       # python -I does not add the script folder
import pacing_v3 as P                   # noqa: E402

OVERLAY_DIR = HERE / "content10h"
TUTORIAL_MIN = 3.0                       # the tutorial (part A) takes about 3 min of session 1
WINDOW_S = 300.0                         # cadence: 5-minute windows
LEGACY_KEYS = ["end0", "unlock0", "promo0", "end1", "unlock1", "promo1", "end2"]
PERK_EFFECTS = ("price_mult", "cook_speed", "waiter_speed", "start_cash", "start_waiters",
                "start_tables", "offline_hours", "signboard_start", "hotel_rate")
RULE_TOKENS = ("all_dishes", "renovated", "hotel", "hotel_done", "rooms_all", "rooms", "room_level",
               "counters_level", "stars", "izzat", "none")
GAME_LOC_KEYS = ("name", "region", "mult", "cost", "requires", "rebuild", "palette", "milestone",
                 "sign_en", "sign_hi", "stations")

DEFAULT_CONTENT = {
    "highways": [],
    "max_phase": None,           # EXT: leave out everything tagged "phase" above this (one overlay, every phase)
    "ladder_limit": None,        # EXT: keep only the first N highways of the ladder
    "hotel": {
        "enabled": False, "unlock": "renovated+all_dishes", "cost": 0.0, "scale_with_mult": True,
        "rooms_start": 1, "rooms_max": 1, "room_costs": [0.0], "room_cost_growth": 1.5,
        "room_level_max": 1, "level_cost_base": 0.0, "level_cost_growth": 1.2,
        "rate_base": 0.0, "rate_growth": 1.2, "occupancy": 0.8, "night_s": None, "pay": "dawn",
        "done": "rooms_all", "offline_share": 0.0, "offline_cap_hours": 8.0, "bias": 1.0,
        # EXT (design step): guests from the road, the one offline rule, strict "new" counting
        "phase": None, "guests_per_tpm": None, "in_rewards": False, "offline_x2": False,
        "tier_new": False, "tier_levels": None,
    },
    "izzat": {
        "enabled": False, "start": 0,
        "earn": {"stage_done": {}, "promotion": {}, "dish_unlock": 0, "star": 0, "baraat_step": [],
                 "all_dishes": 0, "daily_salaam": 0},
        "perks": {}, "policy": "cheapest", "lock_idle_perks": False,
    },
    "mastery": {
        "enabled": False, "thresholds": [500, 2000, 10000], "scope": "highway",
        "dish_price_per_star": 0.0, "set_bonus": 0.0, "global_per_stars": 0, "global_mult": 0.0,
        "station_mult": {}, "slot_mult": [], "count_tutorial": False,
    },
    "sessions": {
        "per_day": 3, "minutes": 20.0, "starts_h": [8.0, 13.0, 21.0], "install_weekday": 1,
        "offline_ad": True, "special_share": 0.08, "baraat": True, "guest_rate": 2.4,
    },
    "festivals": [],
    "counter_looks": {"levels": [], "phase": None},
    "decor": {"enabled": False, "phase": None, "unlock": "hotel_done", "base": 0.0, "growth": 2.0, "items": 0,
              "price_per_item": 0.0},
}


# =============================================================== overlay
def deep_merge(base, over):
    """Dicts merge key by key, anything else replaces, None deletes."""
    out = copy.deepcopy(base)
    for k, v in over.items():
        if v is None:
            out.pop(k, None)
        elif isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = copy.deepcopy(v)
    return out


def set_path(root, path, val):
    node = root
    keys = path.split(".")
    for k in keys[:-1]:
        node = node.setdefault(k, {})
    node[keys[-1]] = val


def load_setup(overlay, eco_path, sets=(), difficulty=None):
    """(eco, content, hwconf, name): the merged economy, the content block with
    defaults, per-highway prototype keys {id: {...}}, the overlay's name."""
    base = json.loads(Path(eco_path).read_text())
    over = json.loads(Path(overlay).read_text()) if overlay else {}
    if not isinstance(over, dict):
        raise SystemExit(f"overlay {overlay}: not a JSON object")
    over = dict(over)
    cover = over.pop("content", {}) or {}
    eco = deep_merge(base, over)
    content = deep_merge(DEFAULT_CONTENT, cover)
    for kv in sets:
        path, val = kv.split("=", 1)
        v = json.loads(val)
        if path.startswith("content."):
            set_path(content, path[len("content."):], v)
        else:
            set_path(eco, path, v)
    if difficulty is not None:
        eco.setdefault("difficulty", {})["cost_mult"] = float(difficulty)
    if content.get("visible_levels") and not content["counter_looks"].get("levels"):
        content["counter_looks"]["levels"] = list(content["visible_levels"])   # the player design's key
    apply_phase(content)
    locs = eco.setdefault("locations", {})
    order = locs.setdefault("order", ["nh44"])
    hwconf = {}
    for h in content.get("highways", []):
        if not isinstance(h, dict) or "id" not in h:
            raise SystemExit(f"content.highways: every entry needs an id ({h!r})")
        hid = str(h["id"])
        game = {k: copy.deepcopy(v) for k, v in h.items() if k in GAME_LOC_KEYS}
        if isinstance(locs.get(hid), dict):
            locs[hid] = deep_merge(locs[hid], game)
        else:
            game.setdefault("requires", "renovated_all_dishes")
            locs[hid] = game
        if hid not in order:
            order.append(hid)
        hwconf[hid] = {k: copy.deepcopy(v) for k, v in h.items() if k not in GAME_LOC_KEYS and k != "id"}
    lim = content.get("ladder_limit")
    if lim:
        del order[int(lim):]             # EXT: keep only the first N highways
    # validate the rules early (a typo would otherwise stall a highway silently)
    for hid in order:
        if isinstance(locs.get(hid), dict) and hid != order[0]:
            rule_tokens(locs[hid].get("requires", "renovated_all_dishes"))
    rule_tokens(content["hotel"].get("unlock", ""))
    rule_tokens(content["hotel"].get("done", ""))
    for pid, pd in content["izzat"].get("perks", {}).items():
        if pid.startswith("_"):
            continue
        if pd.get("effect") not in PERK_EFFECTS:
            raise SystemExit(f"perk {pid}: effect {pd.get('effect')!r} is not one of {PERK_EFFECTS}")
    name = Path(overlay).stem if overlay else "(no overlay)"
    return eco, content, hwconf, name


def apply_phase(content):
    """EXT content.max_phase: leave out every highway, perk, festival, hotel, decor and
    counter-look block whose "phase" is above it, so one overlay holds every phase
    and --phase N (= --set content.max_phase=N) runs the build that ships phase N."""
    mp = content.get("max_phase")
    if mp is None:
        return

    def later(d):
        return isinstance(d, dict) and d.get("phase") is not None and float(d["phase"]) > float(mp)
    content["highways"] = [h for h in content.get("highways", []) if not later(h)]
    if later(content.get("hotel")):
        content["hotel"]["enabled"] = False
    content["izzat"]["perks"] = {k: v for k, v in content["izzat"].get("perks", {}).items() if not later(v)}
    content["festivals"] = [f for f in content.get("festivals", []) if not later(f)]
    if later(content.get("decor")):
        content["decor"]["enabled"] = False
    if later(content.get("counter_looks")):
        content["counter_looks"]["levels"] = []


def rule_tokens(rule):
    toks = list(rule) if isinstance(rule, list) else [x for x in str(rule).split("+") if x.strip()]
    out = []
    for t in toks:
        t = str(t).strip()
        if t == "renovated_all_dishes":
            out += ["renovated", "all_dishes"]
            continue
        if t.split(":")[0] not in RULE_TOKENS:
            raise SystemExit(f"unknown unlock token {t!r} (known: {', '.join(RULE_TOKENS)}, renovated_all_dishes)")
        out.append(t)
    return out


# =============================================================== exact speed-up: capacity cache
_ORIG_CAPACITY = P.capacity
_CAP_CACHE = {}


def cached_capacity(g, built=None, plan_tandoor=False, sign_extra=0):
    """pacing_v3.capacity() memoised on every input it reads (exact)."""
    key_fn = getattr(g, "cap_key", None)
    if key_fn is None:
        return _ORIG_CAPACITY(g, built, plan_tandoor, sign_extra)
    key = key_fn(built, plan_tandoor, sign_extra)
    r = _CAP_CACHE.get(key)
    if r is None:
        r = _ORIG_CAPACITY(g, built, plan_tandoor, sign_extra)
        _CAP_CACHE[key] = r
    return r


P.capacity = cached_capacity     # this process only; pacing_v3.py is not changed


def reset_caches():
    _CAP_CACHE.clear()
    P._TRIP_CAL.clear()          # trip_cal() caches the first economy's speed
    P._TRIP_M.clear()


# =============================================================== game
class C10Game(P.SeatedGame):
    """SeatedGame + the per-highway layout flag and cost dial, perk and mastery
    factors, the hotel, and a purchase recorder."""

    def __init__(self, eco, content):
        self.c = content
        self.family = False          # family layout (pacing_v3: stage >= 1)
        self.cost_mult = 1.0         # the current highway's cost_mult
        self.perk = {}               # perk id -> level
        self.fx_cache = {}
        self.bonus_on = False        # any price factor in play (False = exactly pacing_v3)
        self.global_fac = 1.0        # perks x mastery global x the daily special
        self.mfac = {}               # station -> mastery factor on this highway
        self.special = 1.0
        self.hotel = None
        self.rec = None
        self._sh_cache = {}
        self.arr_fn = None           # EXT: the model's realized arrivals (hotel guests from the road)
        self.decor = 0               # EXT: decor (shaan) items bought
        super().__init__(eco)

    # ---- layout / dial
    def variant(self):
        return "family" if self.family else "roadside"

    def dial(self):
        d = P.Game.dial(self)
        return d * self.cost_mult if self.cost_mult != 1.0 else d

    # ---- perks
    def fx(self, effect):
        v = self.fx_cache.get(effect)
        if v is None:
            v = 0.0
            for pid, lvl in self.perk.items():
                pd = self.c["izzat"]["perks"][pid]
                if pd.get("effect") == effect:
                    v += float(pd.get("per_level", 0.0)) * lvl
            self.fx_cache[effect] = v
        return v

    # ---- prices / speeds
    def price_at(self, sid, lvl):
        p = P.SeatedGame.price_at(self, sid, lvl)
        if not self.bonus_on:
            return p
        return p * self.global_fac * self.mfac.get(sid, 1.0)

    def processing(self, sid):
        p = P.Game.processing(self, sid)
        f = self.fx("cook_speed") if self.perk else 0.0
        return p / (1.0 + f) if f else p

    def waiter_speed_mult(self, i):
        m = P.SeatedGame.waiter_speed_mult(self, i)
        f = self.fx("waiter_speed") if self.perk else 0.0
        return m * (1.0 + f) if f else m

    def shares(self, built=None, plan_tandoor=False):
        key = (self.location, tuple(built) if built is not None else tuple(self.built()), plan_tandoor)
        r = self._sh_cache.get(key)
        if r is None:
            r = P.SeatedGame.shares(self, built, plan_tandoor)
            self._sh_cache[key] = r
        return r

    def cap_key(self, built, plan_tandoor, sign_extra):
        return (self.location, tuple(built) if built is not None else None, plan_tandoor, sign_extra,
                tuple((v["built"], v["employees"], v["proc"]) for v in self.st.values()),
                self.tables, tuple(self.waiters), tuple(self.gallas), self.sign, self.family,
                self.fx("cook_speed") if self.perk else 0.0, self.fx("waiter_speed") if self.perk else 0.0,
                self.trays_on, self.sign_on)

    # ---- recorder
    def buy(self, kind, arg=None):
        before = self.cash
        ok = super().buy(kind, arg)
        if ok and self.rec is not None:
            self.rec(kind, arg, before - self.cash)
        return ok

    # ---- hotel numbers (h = the open hotel's dict)
    def room_rate(self, h, lvl):
        hc = h["conf"]
        return float(hc["rate_base"]) * float(hc["rate_growth"]) ** (lvl - 1) * h["scale"] * (1.0 + self.fx("hotel_rate"))

    def night_guests(self, h=None):
        """EXT hotel.guests_per_tpm: a night's guests = this x the realized travellers a
        minute (the signboard raises it); None when the constant occupancy applies."""
        h = h if h is not None else self.hotel
        gp = h["conf"].get("guests_per_tpm") if h else None
        if gp is None or self.arr_fn is None:
            return None
        return float(gp) * self.arr_fn()

    def night_income(self, h=None, rooms=None):
        h = h if h is not None else self.hotel
        if not h:
            return 0.0
        rooms = h["rooms"] if rooms is None else rooms
        guests = self.night_guests(h)
        if guests is None:
            occ = float(h["conf"].get("occupancy", 0.8))
            return sum(self.room_rate(h, lv) for lv in rooms) * occ
        # EXT: guests fill the best rooms first; a part guest fills part of the next room
        rates = sorted((self.room_rate(h, lv) for lv in rooms), reverse=True)
        full = int(min(len(rates), math.floor(guests)))
        inc = sum(rates[:full])
        if full < len(rates):
            inc += rates[full] * (guests - full)
        return inc

    def room_cost(self, h):
        hc = h["conf"]
        k = len(h["rooms"]) - int(hc.get("rooms_start", 1))
        costs = hc.get("room_costs") or [0.0]
        c = costs[k] if k < len(costs) else costs[-1] * float(hc.get("room_cost_growth", 1.5)) ** (k - len(costs) + 1)
        return float(c) * h["scale"]

    def room_level_cost(self, h, lvl):
        hc = h["conf"]
        return float(hc["level_cost_base"]) * float(hc["level_cost_growth"]) ** (lvl - 1) * h["scale"]


# =============================================================== model
class C10Model(P.SeatedModel):
    """SeatedModel + highways / hotel / Izzat / mastery / sessions / cadence."""

    def __init__(self, g, content, hwconf, ads=True, realized=P.REALIZED, starter_min=0.0, starter_amount=None,
                 ad_sessions=0.0, dt=0.5, sessions=None, label=""):
        self.c = content
        self.hwconf = hwconf
        self.dt = float(dt)
        self.label = label
        self.purchases = []          # (t, kind, arg, cost, stage)
        self.stage_info = []
        self.izzat = float(content["izzat"].get("start", 0)) if content["izzat"].get("enabled") else 0.0
        self.izzat_earned = self.izzat
        self.izzat_src = {}
        self.izzat_log = []
        self.perk_log = []
        self.dish_seen = set()
        self.dish_new_seen = set()   # (location, station, level) dish unlocks already counted as NEW
        self.serves = {}             # (scope, station, dish index) -> serves
        self.stars = {}
        self.star_log = []
        self.hotel_log = []
        self.hotel_paid = 0.0
        self.timeline = []
        self.sess = sessions
        self.cal_marks = {}
        self.session_log = []
        self._act_n = 0
        # EXT (design step): the strict "new" count and the session / day freshness report
        self.fresh_events = []       # (t, kind) seen-new things that are not NEW purchases: star, baraat, festival, look
        self.sess_bounds = []        # (session index, play start, play end, calendar day)
        self.salaam_log = []         # (t, calendar day, Izzat)
        self.all_dishes_seen = set()
        self.fest_prog = {}          # festival index -> {"guests", "steps"}
        self.tut_serves = 0.0
        self.hotel_done_log = []     # (t, highway, hotel income / min, dhaba takings / min) when a hotel is done
        g.rec = self._rec
        super().__init__(g, ads=ads, realized=realized, stages=0, starter_min=starter_min,
                         starter_amount=starter_amount, ad_sessions=ad_sessions)
        self.pend = deque(e for e in self.pipe if e[2] is None)
        # EXT: the hotel reads the realized arrivals; with hotel.in_rewards its income joins the
        # reward rate (game.gd: every rate path, code-map §2.6). Adds exactly 0.0 with no hotel.
        g.arr_fn = self.arrivals
        _base_rr = g.reward_rate_fn
        g.reward_rate_fn = lambda: _base_rr() + (self.hotel_per_min() if g.hotel is not None
                                                 and g.hotel["conf"].get("in_rewards") else 0.0)
        self.stage_info.append(self._stage_rec("roadside" if not g.family else "family"))
        if sessions:
            self._sess_init()

    # ---------------------------------------------------------- helpers
    def _rec(self, kind, arg, cost):
        """Every purchase: (t, kind, arg, cost, stage, new). "new" = it adds something:
        a LEVEL UP that puts a dish on the menu for the first time on this highway (the
        renovation keeps the dishes: game.gd renovate(), the dish floor), a build, a hire
        (cook, waiter, cashier), a table, a signboard level, a tray (waiter level in
        tray_levels), a promotion, a hotel room, a perk. Plain: other LEVEL UPs
        (price-only milestones too), waiter / cashier / room levels, SPEED."""
        g = self.g
        if kind == "level":
            lvl = g.st[arg]["level"]
            new = False
            if any(int(d.get("from_level", 1)) == lvl for d in g.menu(arg)[1:]):
                key = (g.location, arg, lvl)
                new = key not in self.dish_new_seen
                self.dish_new_seen.add(key)
            elif lvl in [int(x) for x in self.c.get("counter_looks", {}).get("levels", [])]:
                # EXT counter_looks: a counter's new look at this level, the first time per highway
                key = (g.location, arg, "look", lvl)
                if key not in self.dish_new_seen:
                    self.dish_new_seen.add(key)
                    self.fresh_events.append((self.t, "look"))
        elif kind == "waiter_up":
            new = g.trays_on and g.waiters[arg] in [int(x) for x in g.e["waiters"].get("tray_levels", [])]
        elif kind == "room_up" and g.hotel is not None and g.hotel["conf"].get("tier_new"):
            # EXT hotel.tier_new: the FIRST room on this highway to reach a look (a level in
            # tier_levels, or every level when it is null) is NEW; later rooms reaching it are not
            lv = g.hotel["rooms"][arg]
            tl = g.hotel["conf"].get("tier_levels")
            new = False
            if tl is None or lv in [int(x) for x in tl]:
                key = (g.location, "room_tier", lv)
                new = key not in self.dish_new_seen
                self.dish_new_seen.add(key)
        else:
            new = kind not in ("galla_up", "proc", "room_up")
        self.purchases.append((self.t, kind, arg, cost, g.stage, new))

    def _stage_rec(self, kind):
        g = self.g
        return {"idx": g.stage, "hw": g.location, "kind": kind, "key": f"{g.location}.{kind}",
                "start": self.t, "mult": g.mult, "cost_mult": g.cost_mult}

    def cur_kind(self):
        return self.stage_info[-1]["kind"]

    def hwc(self, loc=None):
        return self.hwconf.get(loc or self.g.location, {})

    def hotel_conf(self, loc=None):
        hc = self.c["hotel"]
        h = self.hwc(loc).get("hotel", True)
        if h is False or not hc.get("enabled"):
            return None
        return deep_merge(hc, h) if isinstance(h, dict) else hc

    def add_izzat(self, n, src):
        if not self.c["izzat"].get("enabled") or not n:
            return
        n = float(n)
        self.izzat += n
        self.izzat_earned += n
        self.izzat_src[src] = self.izzat_src.get(src, 0.0) + n
        self.izzat_log.append((self.t, src, n))

    def earn_table(self, key, sub):
        v = self.c["izzat"].get("earn", {}).get(key, {})
        return float(v.get(sub, 0)) if isinstance(v, dict) else float(v or 0)

    # ---------------------------------------------------------- rules
    def rule_ok(self, rule):
        g = self.g
        h = g.hotel
        for t in rule_tokens(rule):
            name, _, arg = t.partition(":")
            if name == "none":
                continue
            if name == "all_dishes":
                ok = self.content_done()
            elif name == "renovated":
                ok = g.family
            elif name == "hotel":
                ok = h is not None
            elif name == "hotel_done":
                if h is None and self.hotel_conf() is None:
                    ok = True        # EXT: a highway with no hotel (or a phase without it) has none to finish
                else:
                    ok = h is not None and self.rule_ok(h["conf"].get("done", "rooms_all"))
            elif name == "rooms_all":
                ok = h is not None and len(h["rooms"]) >= int(h["conf"].get("rooms_max", 1))
            elif name == "rooms":
                ok = h is not None and len(h["rooms"]) >= int(arg)
            elif name == "room_level":
                ok = h is not None and all(lv >= int(arg) for lv in h["rooms"])
            elif name == "counters_level":
                ok = all(g.st[s]["built"] and g.st[s]["level"] >= int(arg) for s in g.station_ids())
            elif name == "stars":
                ok = sum(self.stars.values()) >= int(arg)
            elif name == "izzat":
                ok = self.izzat_earned >= float(arg)
            else:
                ok = False
            if not ok:
                return False
        return True

    def stage_done(self):
        if self.cur_kind() == "hotel":
            return self.rule_ok("hotel_done")
        return self.content_done()

    def next_promotion(self):
        """{kind, cost, unlocked, dest} of the next promotion from the current stage, or None."""
        g, e = self.g, self.g.e
        kind = self.cur_kind()
        if kind == "roadside":
            first = self.location_order()[0] if self.location_order() else g.location
            if g.location == first:
                reno = e.get("renovation")
                if not reno:
                    return None
                return {"kind": "renovation", "cost": float(reno.get("cost", 0.0)),
                        "unlocked": self.rule_ok(reno.get("unlock", "all_dishes")), "dest": g.location}
            hc = self.hwc()
            cost = float(hc.get("renovation_cost", float(e.get("renovation", {}).get("cost", 0.0)) * g.cost_mult))
            return {"kind": "renovation", "cost": cost, "unlocked": self.rule_ok("all_dishes"), "dest": g.location}
        if kind == "family":
            hc = self.hotel_conf()
            if hc is not None:
                scale = g.mult if hc.get("scale_with_mult", True) else 1.0
                return {"kind": "hotel", "cost": float(hc.get("cost", 0.0)) * scale,
                        "unlocked": self.rule_ok(hc.get("unlock", "renovated+all_dishes")), "dest": g.location}
        nxt = self.next_location()
        if not nxt:
            return None
        locd = e["locations"][nxt]
        return {"kind": "move", "cost": float(locd.get("cost", 0.0)),
                "unlocked": self.rule_ok(locd.get("requires", "renovated_all_dishes")), "dest": nxt}

    # ---------------------------------------------------------- the step (exact, faster lock scan)
    def step(self, dt):
        g, e = self.g, self.g.e
        g.now = self.t
        c = P.capacity(g)
        tau = e["traffic"]["ramp_ease_s"] if c["target"] > self.lam else e["traffic"]["ramp_ease_down_s"]
        self.lam += (c["target"] - self.lam) * (1.0 - math.exp(-dt / tau))
        n = self.arrivals() * dt / 60.0
        entry = [self.t, n, None, None]
        self.pipe.append(entry)
        self.pend.append(entry)
        g._task_add("seated", "", n)
        mastery = self.c["mastery"].get("enabled")
        while self.pend and self.t >= self.pend[0][0] + P.PRICE_LAG_S - 1e-9:
            entry = self.pend.popleft()
            entry[2] = g.basket()
            entry[3] = c["shares"]
            open_dish = {(tk["station"], tk["dish"]) for tk in g.tasks if not tk["done"] and tk["kind"] == "served_dish"}
            for s, p in c["shares"].items():
                g._task_add("served", s, entry[1] * p)
                nd = g.dishes_unlocked(s)
                if open_dish or mastery:
                    for d in g.menu(s)[:nd]:
                        if (s, d["key"]) in open_dish:
                            g._task_add_dish(s, d["key"], entry[1] * p * g.dish_weight(s, d["key"]))
                if mastery:
                    w = g.menu_weights(nd)
                    scope = g.location if self.c["mastery"].get("scope", "highway") == "highway" else "*"
                    for k in range(nd):
                        key = (scope, s, k)
                        self.serves[key] = self.serves.get(key, 0.0) + entry[1] * p * w[k]
        while self.pipe and self.t >= self.pipe[0][0] + P.PAY_LAG_S - 1e-9:
            t_arr, k, bill, _sh = self.pipe.popleft()
            earned = k * (bill if bill is not None else g.basket())
            g.sales_sum += earned
            g.cash += earned
            g.lifetime += earned
            g._task_add("earned", "", earned)
            g._task_add("billed", "", k)
        g._check()
        self.t += dt

    # ---------------------------------------------------------- the bot
    def act(self):
        """pacing_v3 SeatedModel.act (same order of every step) + the hotel stage,
        Izzat perks, mastery stars and the hotel's pay."""
        g, e = self.g, self.g.e
        t = self.t
        if self.ad_sessions > 0 and self.ads and t > 0 and not self.sess:
            sess = int(t // (self.ad_sessions * 60.0))
            if sess != self._sess:
                self._sess = sess
                self.ads_shown = 0
                self.ads_capped_at = None
        b = P.capacity(g)["bind"].split(":")[0]
        bt = self.bind_t.setdefault(g.stage, {})
        bt[b] = bt.get(b, 0.0) + self.dt
        if self.starter_min > 0 and not self.starter_paid and t >= self.starter_min * 60.0:
            g.add_reward(self.starter_amount, "starter")
            self.starter_paid = True
            self.marks["starter"] = t
            self.log(f"STARTER +{P.rupees(self.starter_amount)}")
        reserve = 0.0
        if self.stage_done() and f"end{g.stage}" not in self.marks:
            self.marks[f"end{g.stage}"] = t
            self.stage_info[-1]["end"] = t
            self.log(f"{'HOTEL DONE' if self.cur_kind() == 'hotel' else 'ALL DISHES'} (stage {g.stage})")
            if self.cur_kind() == "hotel":     # EXT: the hotel's share of the takings when it is done
                self.hotel_done_log.append((t, g.location, self.hotel_per_min(), self.real_per_min()))
            self.add_izzat(self.earn_table("stage_done", self.cur_kind()), f"stage_done.{self.cur_kind()}")
        nxt = self.next_promotion()
        if nxt is not None and nxt["unlocked"]:
            key = f"unlock{g.stage}"
            if key not in self.marks:
                self.marks[key] = t
                self.stage_info[-1]["unlock"] = t
                self.log(f"UNLOCKED {nxt['kind']} ({P.rupees(nxt['cost'])})")
            reserve = nxt["cost"]
            if g.cash >= reserve:
                self.promote(nxt)
                reserve = 0.0
        if g.sign_on and g.sign < g.sign_max() and g.sign_unlocked():
            c = P.capacity(g)
            spend = g.cash - reserve
            ok = c["bind"] == "max"
            if ok:
                pb = self.sign_payback(c)
                ok = pb <= max(float(g.sdef_sign().get("offer_payback_min", 0.0)), self.best_level_payback(c))
            cost = g.sign_cost()
            if ok and cost <= P.SIGN_SPEND_FRAC * spend:
                g.cash -= cost
                g.sign += 1
                self.sign_log.append((t, g.stage, g.sign, cost))
                self._rec("sign", g.sign, cost)
                self.log(f"SIGNBOARD level {g.sign} ({P.rupees(cost)}), cap {e['traffic']['ramp_max_tpm'] + g.sign_bonus():.1f}/min")
        if self.c["izzat"].get("enabled"):
            self.buy_perks()
        if g.hotel is not None:
            reserve += self.hotel_buy(reserve)
        saved = min(g.cash, reserve)
        g.cash -= saved
        self.act_base()
        g.cash += saved
        if self.c.get("decor", {}).get("enabled"):
            self.decor_buy(reserve)
        # every 10 s of play: stars, dish unlocks (Izzat), the mastery factors
        self._act_n += 1
        if self._act_n % max(1, int(round(10.0 / self.dt))) == 0:
            self.slow_tick()
        if g.hotel is not None:
            self.hotel_pay()

    def slow_tick(self):
        g = self.g
        # EXT izzat.earn.all_dishes: once per highway when its 16 dishes are all on the menu,
        # whatever stage the dhaba is in (the hotel can open before that, at L50)
        ad = float(self.c["izzat"].get("earn", {}).get("all_dishes", 0) or 0)
        if self.c["izzat"].get("enabled") and ad and g.location not in self.all_dishes_seen and self.content_done():
            self.all_dishes_seen.add(g.location)
            self.add_izzat(ad, "all_dishes")
        if self.c["izzat"].get("enabled") and self.c["izzat"]["earn"].get("dish_unlock"):
            for s in g.built():
                for k in range(g.dishes_unlocked(s)):
                    key = (g.location, s, k)
                    if key not in self.dish_seen:
                        self.dish_seen.add(key)
                        if k > 0:
                            self.add_izzat(self.c["izzat"]["earn"]["dish_unlock"], "dish_unlock")
        if self.c["mastery"].get("enabled"):
            th = sorted(float(x) for x in self.c["mastery"].get("thresholds", []))
            # EXT station_mult {counter: x} and slot_mult [x per menu slot]: a slot's tier needs
            # threshold x counter factor x slot factor serves, so slots do not cross tiers together
            stm = self.c["mastery"].get("station_mult", {}) or {}
            slm = self.c["mastery"].get("slot_mult", []) or []
            for key, n in self.serves.items():
                f = float(stm.get(key[1], 1.0)) * (float(slm[key[2]]) if key[2] < len(slm) else 1.0)
                s = sum(1 for x in th if n >= x * f)
                if s > self.stars.get(key, 0):
                    for _ in range(s - self.stars.get(key, 0)):
                        self.star_log.append((self.t, key))
                        self.fresh_events.append((self.t, "star"))
                        self.add_izzat(self.c["izzat"]["earn"].get("star", 0), "star")
                    self.stars[key] = s
            self.refresh_factors()

    def refresh_factors(self):
        """The price factors: perks (price_mult), mastery (per dish, per set, global),
        the daily special (sessions)."""
        g, m = self.g, self.c["mastery"]
        gf = (1.0 + g.fx("price_mult")) * g.special
        if g.decor:
            gf *= 1.0 + float(self.c.get("decor", {}).get("price_per_item", 0.0)) * g.decor   # EXT decor
        if m.get("enabled"):
            per = int(m.get("global_per_stars", 0) or 0)
            if per > 0:
                gf *= 1.0 + float(m.get("global_mult", 0.0)) * (sum(self.stars.values()) // per)
            scope = g.location if m.get("scope", "highway") == "highway" else "*"
            x = float(m.get("dish_price_per_star", 0.0))
            sb = float(m.get("set_bonus", 0.0))
            for s in g.station_ids():
                nd = g.dishes_unlocked(s)
                w = g.menu_weights(nd)
                f = sum(w[k] * (1.0 + x * self.stars.get((scope, s, k), 0)) for k in range(nd))
                if sb:
                    f *= 1.0 + sb * min(self.stars.get((scope, s, k), 0) for k in range(max(1, len(g.menu(s)))))
                g.mfac[s] = f
        g.global_fac = gf
        g.bonus_on = gf != 1.0 or any(v != 1.0 for v in g.mfac.values())

    def decor_buy(self, reserve):
        """EXT content.decor (dhaba decor, "shaan"): cosmetic items kept across moves, bought
        with the cash left after the bot's own spending (so only when nothing better is
        left), once the unlock rule holds; item k costs base x growth^k x the current
        price mult; each item adds price_per_item on every price."""
        d = self.c.get("decor") or {}
        g = self.g
        k = g.decor
        if k >= int(d.get("items", 0)) or not self.rule_ok(d.get("unlock", "hotel_done")):
            return
        cost = float(d.get("base", 0.0)) * float(d.get("growth", 2.0)) ** k * g.mult
        if g.cash - reserve + 1e-9 < cost:
            return
        g.cash -= cost
        g.decor = k + 1
        self._rec("decor", k, cost)
        self.log(f"DECOR {k + 1} ({P.rupees(cost)})")
        self.refresh_factors()

    # ---------------------------------------------------------- Izzat perks
    def perk_can_act(self, pd):
        """EXT content.izzat.lock_idle_perks: False for a start_* perk while no reset it
        applies on is still ahead (no next highway for "move"; for "renovation", the
        dhaba is already in the family layout). Every other perk can act."""
        if pd.get("effect") not in ("start_cash", "start_waiters", "start_tables", "signboard_start"):
            return True
        kinds = pd.get("applies_on", ["move"])
        if "move" in kinds and self.next_location():
            return True
        return "renovation" in kinds and not self.g.family

    def buy_perks(self):
        g, iz = self.g, self.c["izzat"]
        perks = {k: v for k, v in iz.get("perks", {}).items() if not k.startswith("_")}
        pol = iz.get("policy", "cheapest")
        lock = bool(iz.get("lock_idle_perks", False))
        for _ in range(20):
            nxt = []
            for pid, pd in perks.items():
                if lock and not self.perk_can_act(pd):
                    continue
                lvl = g.perk.get(pid, 0)
                costs = pd.get("costs", [])
                if lvl < len(costs):
                    nxt.append((float(costs[lvl]), list(perks).index(pid), pid))
            if not nxt:
                return
            if isinstance(pol, list):
                order = [p for p in pol if any(x[2] == p for x in nxt)]
                pick = next((x for x in nxt if order and x[2] == order[0]), None)
            else:
                pick = min(nxt)
            if pick is None or pick[0] > self.izzat + 1e-9:
                return
            self.izzat -= pick[0]
            g.perk[pick[2]] = g.perk.get(pick[2], 0) + 1
            g.fx_cache = {}
            self.perk_log.append((self.t, pick[2], g.perk[pick[2]], pick[0]))
            self._rec("perk", pick[2], 0.0)
            self.log(f"PERK {pick[2]} L{g.perk[pick[2]]} ({pick[0]:g} Izzat)")
            self.refresh_factors()

    # ---------------------------------------------------------- hotel
    def hotel_open(self, hc):
        g = self.g
        scale = g.mult if hc.get("scale_with_mult", True) else 1.0
        night = float(hc.get("night_s") or g.e.get("daynight", {}).get("cycle_s", 600.0))
        g.hotel = {"conf": hc, "scale": scale, "rooms": [1] * int(hc.get("rooms_start", 1)), "night_s": night,
                   "opened": self.t, "night_idx": int(self.t // night), "loc": g.location, "last_t": self.t}

    def hotel_items(self):
        """[(gain per min / cost, kind, index, cost, gain per min)] for the next room and each room level."""
        g, h = self.g, self.g.hotel
        hc = h["conf"]
        occ = float(hc.get("occupancy", 0.8))
        per_min = 60.0 / h["night_s"]
        guests_mode = g.night_guests(h) is not None      # EXT: gains under the guests-from-the-road rule
        base = g.night_income(h) if guests_mode else 0.0
        out = []
        if len(h["rooms"]) < int(hc.get("rooms_max", 1)):
            cost = g.room_cost(h)
            if guests_mode:
                gain = (g.night_income(h, h["rooms"] + [1]) - base) * per_min
            else:
                gain = g.room_rate(h, 1) * occ * per_min
            out.append((gain / max(1e-9, cost), "room", len(h["rooms"]), cost, gain))
        seen = set()
        for i, lv in enumerate(h["rooms"]):
            if lv >= int(hc.get("room_level_max", 1)) or lv in seen:
                continue
            seen.add(lv)     # rooms at the same level are the same offer: the first one
            cost = g.room_level_cost(h, lv)
            if guests_mode:
                rr = list(h["rooms"])
                rr[i] += 1
                gain = (g.night_income(h, rr) - base) * per_min
            else:
                gain = (g.room_rate(h, lv + 1) - g.room_rate(h, lv)) * occ * per_min
            out.append((gain / max(1e-9, cost), "room_up", i, cost, gain))
        return out

    def hotel_buy(self, reserve):
        """Buys hotel items whose income per rupee beats bias x the best LEVEL UP's;
        returns the cash to keep aside while saving for the best one."""
        g = self.g
        hc = g.hotel["conf"]
        bias = float(hc.get("bias", 1.0))
        for _ in range(12):
            items = self.hotel_items()
            if not items:
                return 0.0
            best = max(items)
            lp = self.best_level_payback(P.capacity(g))
            dh_ratio = 1.0 / lp if lp and math.isfinite(lp) else 0.0
            if best[0] < bias * dh_ratio:
                return 0.0
            if g.cash - reserve + 1e-9 < best[3]:
                return best[3]       # save for it (the greedy LEVEL UP loop waits too)
            g.cash -= best[3]
            if best[1] == "room":
                g.hotel["rooms"].append(1)
            else:
                g.hotel["rooms"][best[2]] += 1
            self._rec(best[1], best[2], best[3])
            self.hotel_log.append((self.t, best[1], best[2], best[3]))
        return 0.0

    def hotel_pay(self):
        g, h = self.g, self.g.hotel
        if h["conf"].get("pay", "dawn") == "continuous":
            amt = g.night_income(h) * (self.t - h["last_t"]) / h["night_s"]
            h["last_t"] = self.t
        else:
            idx = int(self.t // h["night_s"])
            if idx <= h["night_idx"]:
                return
            amt = g.night_income(h) * (idx - h["night_idx"])
            h["night_idx"] = idx
        if amt > 0:
            g.add_reward(amt, "hotel")
            self.hotel_paid += amt

    def hotel_per_min(self):
        h = self.g.hotel
        return self.g.night_income(h) * 60.0 / h["night_s"] if h else 0.0

    # ---------------------------------------------------------- promotions
    def promote(self, nxt):
        """pacing_v3 promote() (renovation, move: the same reset) + the hotel stage,
        the per-highway start / cost_mult, the start_* perks and Izzat."""
        g, e = self.g, self.g.e
        kind = nxt["kind"]
        cost = nxt["cost"]
        g.cash -= cost
        self.marks[f"promo{g.stage}"] = self.t
        self.marks[f"wl{g.stage}"] = list(g.waiters)
        self.marks[f"sign{g.stage}"] = g.sign
        self.stage_info[-1]["promo"] = self.t
        self._rec("promo:" + kind, nxt["dest"], cost)
        g.stage += 1
        self.stage_start[g.stage] = self.t
        self.add_izzat(self.earn_table("promotion", kind), f"promotion.{kind}")
        if kind == "hotel":
            self.hotel_open(self.hotel_conf())
            self.stage_info.append(self._stage_rec("hotel"))
            self.log(f"PROMOTED hotel {g.stage}: cost {P.rupees(cost)} at {g.location}")
            return
        remap = {}
        if kind == "move":
            # EXT izzat.earn.all_dishes: a session's opening burst can reach all 16 dishes and
            # move within one 10 s check; the award is made here then (the game awards at once)
            ad = float(self.c["izzat"].get("earn", {}).get("all_dishes", 0) or 0)
            if self.c["izzat"].get("enabled") and ad and g.location not in self.all_dishes_seen and self.content_done():
                self.all_dishes_seen.add(g.location)
                self.add_izzat(ad, "all_dishes")
            dest = nxt["dest"]
            old_menus = {s: [d.get("key") for d in g.menu(s)] for s in g.station_ids()}
            g.location = dest
            P.apply_location(e, dest)
            remap = {s: {k: nd.get("key") for k, nd in zip(old_menus[s], g.menu(s))} for s in g.station_ids()}
            g.hotel = None
            hc = self.hwc(dest)
            g.family = str(hc.get("start", "family")) != "roadside"
            g.cost_mult = float(hc.get("cost_mult", 1.0))
            g._sh_cache = {}
        else:
            g.family = True
        locd = e.get("locations", {}).get(g.location, {})
        lmult = float(locd.get("mult", 1.0) if isinstance(locd, dict) else 1.0)
        if g.family:
            rm = self.hwc().get("renovation_mult") if g.location != self.location_order()[0] else None
            g.mult = float(rm if rm is not None else e.get("renovation", {}).get("mult", 1.0)) * lmult
        else:
            g.mult = lmult
        rebuild = kind == "move" and bool(locd.get("rebuild", False))
        for s in g.station_ids():
            g.st[s]["level"] = 1
            g.st[s]["employees"] = max(1, int(g.sdef(s).get("employees_start", 1)))
            g.st[s]["proc"] = 0
            if rebuild and not g.sdef(s).get("start_built", False):
                g.st[s]["built"] = False
        fx = self.start_fx(kind)
        g.waiters = [1] * min(max(1, int(e["waiters"]["start"])) + int(fx.get("start_waiters", 0)),
                              max(max(1, int(e["waiters"]["start"])), g.waiters_max()))
        g.gallas = [1]
        g.tables = min(g.tables_start() + int(fx.get("start_tables", 0)), max(g.tables_start(), g.tables_max()))
        if kind == "move" and e.get("signboard", {}).get("reset_on_move", True):
            g.sign = 0
        if kind == "move" and fx.get("signboard_start"):
            g.sign = min(int(fx["signboard_start"]), g.sign_max())
        if fx.get("start_cash"):
            g.cash += float(fx["start_cash"]) * g.mult
        self.seen_levels = set()
        self.next_ad = self.t + float(e["ad_bubble"].get("first_delay_s", e["ad_bubble"]["interval_s"]))
        for i, tk in enumerate(g.tasks):
            if tk["done"]:
                continue
            if tk["kind"] == "served_dish" and tk["dish"] in remap.get(tk["station"], {}):
                tk["dish"] = remap[tk["station"]][tk["dish"]]
            gone = tk["kind"] == "served_dish" and not any(d.get("key") == tk["dish"] for d in g.menu(tk["station"]))
            if gone or g._stale(tk):
                g.tasks[i] = g._next_task()
        g._refresh_abs()
        g._check()
        self.stage_info.append(self._stage_rec("family" if g.family else "roadside"))
        if g.bonus_on or self.c["mastery"].get("enabled"):
            self.refresh_factors()
        self.log(f"PROMOTED {kind} {g.stage}: cost {P.rupees(cost)} mult x{g.mult:.2f} location {g.location}"
                 f" waiters before {self.marks[f'wl{g.stage - 1}']}")

    def start_fx(self, kind):
        """{effect: value} of the start_* perks that apply to this reset."""
        g = self.g
        out = {}
        for pid, lvl in g.perk.items():
            pd = self.c["izzat"]["perks"][pid]
            eff = pd.get("effect")
            if eff in ("start_cash", "start_waiters", "start_tables", "signboard_start") and \
                    kind in pd.get("applies_on", ["move"]):
                out[eff] = out.get(eff, 0.0) + float(pd.get("per_level", 0.0)) * lvl
        return out

    # ---------------------------------------------------------- sessions
    def _sess_init(self):
        s = self.sess
        self.s_idx = 0
        self.s_start_t = 0.0
        self.s_end_t = max(1.0, float(s["minutes"]) - TUTORIAL_MIN) * 60.0
        self.baraat = {"key": None, "guests": 0.0, "steps": 0}
        self.fest_done = set()
        self._sess_begin(first=True)

    def cal_start(self, k):
        """Calendar seconds (from install day 00:00) when session k starts."""
        s = self.sess
        day, j = divmod(k, int(s["per_day"]))
        starts = list(s["starts_h"])
        return day * 86400.0 + float(starts[j % len(starts)]) * 3600.0 + (TUTORIAL_MIN * 60.0 if k == 0 else 0.0)

    def cal_now(self):
        return self.cal_start(self.s_idx) + (self.t - self.s_start_t)

    def day(self):
        return int(self.cal_now() // 86400)

    def weekday(self, day):
        return (int(self.sess.get("install_weekday", 1)) + day) % 7

    def _sess_begin(self, first=False):
        """A session opens: the wall-ad cap resets, the bubble waits first_delay_s,
        the daily special (from day 2), festivals."""
        g, e = self.g, self.g.e
        if not first:
            self.ads_shown = 0
            self.ads_capped_at = None
            self.next_ad = self.t + max(self._ad_left, float(e["ad_bubble"].get("first_delay_s", 120.0)))
        day = self.day()
        sp = float(self.sess.get("special_share", 0.0))
        g.special = 1.0 + sp * (float(e.get("special", {}).get("mult", 2.0)) - 1.0) if day >= 1 and sp > 0 else 1.0
        # EXT izzat.earn.daily_salaam: the first session of each new calendar day, every dhaba
        # left behind (the highways before the current one) sends this much Izzat. No streak:
        # a missed day pays nothing and loses nothing. The game keys it by date (anti-clock).
        sal = float(self.c["izzat"].get("earn", {}).get("daily_salaam", 0) or 0)
        if sal and not first and day != getattr(self, "_salaam_day", 0):
            order = self.location_order()
            done = order.index(g.location) if g.location in order else 0
            if done > 0:
                n = sal * done
                cap = self.c["izzat"].get("earn", {}).get("daily_salaam_max")
                if cap is not None:
                    n = min(n, float(cap))      # EXT: at most this much a morning
                self.add_izzat(n, "daily_salaam")
                self.salaam_log.append((self.t, day, n))
        self._salaam_day = day
        for i, f in enumerate(self.c.get("festivals", [])):
            if i in self.fest_done or f.get("steps"):
                continue         # a festival with steps runs as a guest track (festival_tick)
            if int(f.get("day", 0)) <= day < int(f.get("day", 0)) + int(f.get("days", 1)):
                self.fest_done.add(i)
                self.add_izzat(f.get("izzat", 0), "festival")
                cash = float(f.get("cash_minutes", 0.0)) * g.reward_rate()
                if cash > 0:
                    g.add_reward(cash, "festival")
                self.log(f"FESTIVAL {f.get('name', i)}")
        self.refresh_factors()

    def session_tick(self):
        """At a session's end: the away time, the offline pay (+ the x2 ad), the hotel's
        offline share; then the next session opens."""
        if self.t < self.s_end_t - 1e-9:
            return
        g, e = self.g, self.g.e
        s = self.sess
        away = self.cal_start(self.s_idx + 1) - self.cal_now()
        od = e.get("offline", {})
        pay = 0.0
        x2 = False
        if away >= float(od.get("min_away_s", 60.0)):
            cap = (float(od.get("cap_hours", 2.0)) + g.fx("offline_hours")) * 3600.0
            pay = self.offline_basis() * float(od.get("rate", 0.5)) * min(away, cap) / 60.0
            if self.ads and s.get("offline_ad", True) and away >= float(od.get("ad_min_away_s", 0.0)):
                pay *= float(od.get("ad_mult", 2.0))
                x2 = True
            g.add_reward(pay, "offline")
        hpay = 0.0
        if g.hotel is not None:
            hc = g.hotel["conf"]
            share = float(hc.get("offline_share", 0.0))
            if share > 0:
                hcap = float(hc.get("offline_cap_hours", 8.0)) * 3600.0
                hpay = g.night_income() / g.hotel["night_s"] * min(away, hcap) * share
                if hc.get("offline_x2") and x2:
                    hpay *= float(od.get("ad_mult", 2.0))     # EXT: the offline ad doubles the hotel's line too
                g.add_reward(hpay, "hotel_offline")
        self.session_log.append({"k": self.s_idx, "end_t": self.t, "away_h": away / 3600.0, "offline": pay, "x2": x2,
                                 "hotel": hpay, "real": self.real_per_min()})
        self.sess_bounds.append((self.s_idx, self.s_start_t, self.t, self.day()))
        self._ad_left = max(0.0, self.next_ad - self.t)
        self.s_idx += 1
        self.s_start_t = self.t
        self.s_end_t = self.t + float(s["minutes"]) * 60.0
        self._sess_begin()

    def baraat_tick(self, dt):
        """Weekend baraat: guests at guest_rate a minute of play on the window's days
        (once free play >= min_free_play_s); steps pay reward_minutes of the reward
        rate (at least reward_min) and earn.baraat_step Izzat; the guests' bills are
        paid on top."""
        g, s = self.g, self.sess
        fi, fest = self.festival_today()
        if fest is not None:
            self.festival_tick(fi, fest, dt)     # EXT: a festival takes the one event slot for its days
            return
        bd = g.e.get("event", {}).get("baraat")
        if not s.get("baraat", True) or not bd:
            return
        day = self.day()
        days = [int(x) for x in bd.get("days", [6, 0])]
        if self.weekday(day) not in days or self.t < float(bd.get("min_free_play_s", 600)):
            return
        k = day
        while k > 0 and self.weekday(k - 1) in days:
            k -= 1
        if self.baraat["key"] != k:
            self.baraat = {"key": k, "guests": 0.0, "steps": 0}
        n = float(s.get("guest_rate", 2.4)) * dt / 60.0
        self.baraat["guests"] += n
        bill = n * g.basket()
        g.cash += bill
        g.sales_sum += bill
        g.lifetime += bill
        steps = bd.get("steps", [])
        while self.baraat["steps"] < len(steps) and self.baraat["guests"] >= float(steps[self.baraat["steps"]]):
            i = self.baraat["steps"]
            r = max(float(bd["reward_min"][i]), P.nice(g.reward_rate() * float(bd["reward_minutes"][i])))
            g.add_reward(r, "event")
            bs = self.c["izzat"].get("earn", {}).get("baraat_step", [])
            self.add_izzat(bs[i] if i < len(bs) else 0, "baraat")
            self.baraat["steps"] += 1
            self.fresh_events.append((self.t, "baraat"))
            self.log(f"BARAAT step {i + 1} +{P.rupees(r)}")

    def festival_today(self):
        """EXT: (index, festival) of a festival with a guest track (steps) whose window holds
        today, or (None, None)."""
        if not self.sess:
            return None, None
        day = self.day()
        for i, f in enumerate(self.c.get("festivals", [])):
            if f.get("steps") and int(f.get("day", 0)) <= day < int(f.get("day", 0)) + int(f.get("days", 1)):
                return i, f
        return None, None

    def festival_tick(self, i, f, dt):
        """EXT festival week on the baraat machinery: guests come at guest_rate a minute of
        play (capped by free seats in the game, as the baraat bus) once free play >=
        min_free_play_s; each step (guests served) pays reward_minutes of the reward rate
        and step_izzat Izzat; the guests' bills are paid on top. A baraat weekend inside the
        window counts toward the festival (one HUD slot)."""
        g, s = self.g, self.sess
        bd = g.e.get("event", {}).get("baraat") or {}
        if self.t < float(bd.get("min_free_play_s", 600)):
            return
        st = self.fest_prog.setdefault(i, {"guests": 0.0, "steps": 0})
        n = float(f.get("guest_rate", s.get("guest_rate", 2.4))) * dt / 60.0
        st["guests"] += n
        bill = n * g.basket()
        g.cash += bill
        g.sales_sum += bill
        g.lifetime += bill
        steps = f.get("steps", [])
        while st["steps"] < len(steps) and st["guests"] >= float(steps[st["steps"]]):
            k = st["steps"]
            rm = f.get("reward_minutes", [])
            r = P.nice(g.reward_rate() * float(rm[k] if k < len(rm) else 0.0))
            g.add_reward(r, "festival")
            si = f.get("step_izzat", [])
            self.add_izzat(si[k] if k < len(si) else 0, "festival")
            st["steps"] += 1
            st["done_t"] = self.t
            self.fresh_events.append((self.t, "festival"))
            self.log(f"FESTIVAL {f.get('name', i)} step {k + 1} +{P.rupees(r)}")

    # ---------------------------------------------------------- run
    def run_all(self, minutes, every_min=10.0, check_mins=None):
        g = self.g
        end = minutes * 60.0
        self._ad_left = 0.0
        nxt_tl = 0.0
        if check_mins is not None:
            self.check_mins = list(check_mins)
        while self.t < end - 1e-9:
            if self.sess:
                self.session_tick()
            self.step(self.dt)
            if self.sess:
                self.baraat_tick(self.dt)
            self.act()
            while self.check_mins and self.t >= self.check_mins[0] * 60.0 - 1e-6:
                self.checks.append(self.snapshot(self.check_mins.pop(0)))
            if self.t >= nxt_tl - 1e-9:
                self.timeline.append(self.tl_snap())
                nxt_tl += every_min * 60.0
            if self.sess:
                for k in list(self.marks):
                    if k not in self.cal_marks and not k.startswith(("wl", "sign")):
                        self.cal_marks[k] = (self.cal_now(), self.s_idx)
        if not self.timeline or self.timeline[-1]["t"] < self.t - 1e-6:
            self.timeline.append(self.tl_snap())
        if self.sess:
            self.sess_bounds.append((self.s_idx, self.s_start_t, self.t, self.day()))   # the open last session

    def tl_snap(self):
        g = self.g
        pb = self.best_level_payback(P.capacity(g))
        return {"t": self.t, "stage": self.stage_info[-1]["key"], "cash": g.cash, "real": self.real_per_min(),
                "payback": pb if math.isfinite(pb) else None,
                "hotel": self.hotel_per_min(), "n_buys": len(self.purchases), "izzat": self.izzat,
                "izzat_earned": self.izzat_earned, "stars": sum(self.stars.values()),
                "levels": [g.st[s]["level"] for s in g.station_ids() if g.st[s]["built"]],
                "rooms": list(g.hotel["rooms"]) if g.hotel else [], "W": list(g.waiters), "T": g.tables, "sign": g.sign}


# =============================================================== setup (pacing_v3 part_b's start state)
def pick_start_run(eco, seeds, seed, ads):
    """pacing_v3 main(): part A replays seeds 0..N-1 (ads on), part B starts from
    the first one from --seed that built the tandoor (--no-ads: the ads-on replays
    of seeds seed..seed+7)."""
    t0 = time.time()
    if ads:
        runs = [P.run_reference(eco, s, True) for s in range(seeds)]
        src = runs[seed:]
    else:
        runs = [P.run_reference(eco, s, True) for s in range(seed, seed + 8)]
        src = runs
    built = [r for r in src if r["game"].st["tandoor"]["built"]]
    run = built[0] if built else P.run_reference(eco, seed, True)
    info = {"replays": len(runs), "tandoor_built": sum(1 for r in runs if r["game"].st["tandoor"]["built"]),
            "start_seed": (seed + src.index(run)) if run in src else seed, "part_a_s": time.time() - t0}
    return run, info


def make_model(eco, content, hwconf, run, opts, sessions=None, label=""):
    """pacing_v3 part_b()'s start state on a C10Game, then the C10Model."""
    reset_caches()
    g0 = run["game"]
    g = C10Game(copy.deepcopy(eco), content)
    if opts.get("no_trays"):
        g.trays_on = False
    if opts.get("no_signboard"):
        g.sign_on = False
    g.cash = P.INGAME_TUTORIAL_END_CASH
    for s in g0.st:
        g.st[s] = dict(g0.st[s])
    g.gallas = list(g0.gallas)
    g.task_used = set(g0.task_used)
    g.tasks = [g._new_task(t["id"], g.e["tasks"]["defs"].get(t["id"], {"kind": t["kind"], "target": t["target"],
                                                                          "reward": t["reward"]})) for t in g0.tasks]
    for t, t0 in zip(g.tasks, g0.tasks):
        t["progress"] = t0["progress"] if t["kind"] not in P.TASK_ABS else g._abs_progress(t)
    g.chest_claims, g.claims, g.task_gen = g0.chest_claims, g0.claims, g0.task_gen
    g.ad_auto = True
    g.st["tandoor"]["built"] = True
    g.waiters = [1] * P.TUT_END_WAITERS[0]
    g.tables = P.TUT_END_TABLES[0]
    g._refresh_abs()
    g._check()
    g.cost_mult = float(hwconf.get(g.location, {}).get("cost_mult", 1.0))
    m = C10Model(g, content, hwconf, ads=opts.get("ads", True), realized=opts.get("realized", P.REALIZED),
                 starter_min=opts.get("starter", 0.0), starter_amount=opts.get("starter_amount"),
                 ad_sessions=opts.get("ad_sessions", 0.0), dt=opts.get("dt", 0.5), sessions=sessions, label=label)
    ms = content["mastery"]
    if ms.get("enabled") and ms.get("count_tutorial"):
        # EXT mastery.count_tutorial: the game counts dish_counts at cook time from the first
        # tutorial chai (code-map §5), so the slot-1 chai track starts with the replay's serves
        # (all chai: the tandoor is built at 160.5 s). A star they earn is held until the
        # tutorial ends; in the model that is the first 10 s check after it (t = 0:00:10).
        scope = g.location if ms.get("scope", "highway") == "highway" else "*"
        n = float(getattr(g0, "served", 0) or 0)
        if n > 0:
            m.serves[(scope, "chai", 0)] = m.serves.get((scope, "chai", 0), 0.0) + n
            m.tut_serves = n
    if content["izzat"].get("enabled") or content["mastery"].get("enabled"):
        m.refresh_factors()
    return m


def run_model(eco, content, hwconf, run, opts, minutes, sessions=None, label="", every=10.0):
    m = make_model(eco, content, hwconf, run, opts, sessions=sessions, label=label)
    t0 = time.time()
    m.run_all(minutes, every_min=every, check_mins=sorted(set(m.check_mins) | {70, 80, 100, 150, 180}))
    m.wall_s = time.time() - t0
    return m


# =============================================================== statistics
def pctl(vals, p):
    if not vals:
        return None
    s = sorted(vals)
    return s[min(len(s) - 1, max(0, int(round(p * (len(s) - 1)))))]


def cadence(m, t0, t1, new_only=False):
    """Purchases in [t0, t1] (new_only: only the ones that add something, see
    C10Model._rec): units, buy moments (distinct steps), gaps (between moments; the
    first one from the previous purchase), dry 5-minute windows."""
    pur = [p for p in m.purchases if p[5]] if new_only else m.purchases
    times = sorted({round(p[0], 3) for p in pur})
    inside = [x for x in times if t0 - 1e-6 <= x <= t1 + 1e-6]
    n_units = sum(1 for p in pur if t0 - 1e-6 <= p[0] <= t1 + 1e-6)
    gaps = []
    for x in inside:
        i = bisect.bisect_left(times, x)
        prev = times[i - 1] if i > 0 else 0.0
        gaps.append(x - prev)
    nwin = int((t1 - t0) // WINDOW_S)
    dry = 0
    for k in range(nwin):
        a, b = t0 + k * WINDOW_S, t0 + (k + 1) * WINDOW_S
        i = bisect.bisect_left(times, a - 1e-6)
        if not (i < len(times) and times[i] < b - 1e-6):
            dry += 1
    kinds = {}
    for p in pur:
        if t0 - 1e-6 <= p[0] <= t1 + 1e-6:
            k = p[1].split(":")[0]
            kinds[k] = kinds.get(k, 0) + 1
    return {"units": n_units, "moments": len(inside), "p50": pctl(gaps, 0.5), "p90": pctl(gaps, 0.9),
            "max": max(gaps) if gaps else None, "dry5": dry, "windows": nwin, "kinds": kinds}


def fmt_h(s):
    if s is None:
        return "-"
    s = float(s)
    return f"{int(s // 3600)}:{int(s % 3600 // 60):02d}:{int(s % 60):02d}"


def fmt_m(s):
    if s is None:
        return "-"
    return f"{s / 60.0:.1f}"


def stage_rows(m, run_end):
    rows = []
    for i, st in enumerate(m.stage_info):
        left = st.get("promo")
        t1 = left if left is not None else run_end
        cad = cadence(m, st["start"], t1)
        row = dict(st)
        row["t1"] = t1
        row["dur"] = t1 - st["start"]
        row["cad"] = cad
        row["new_cad"] = cadence(m, st["start"], t1, new_only=True)
        if st.get("end") is not None:
            row["after_cad"] = cadence(m, st["end"], t1)
            row["after_new"] = cadence(m, st["end"], t1, new_only=True)
        rows.append(row)
    return rows


# =============================================================== EXT: the strict "new" count (FRESH)
def fresh_times(m, kinds=None):
    """FRESH: the one strict count of "something new" used for every design (the judges'
    shared count): the NEW purchases (a hotel room look counts only for the FIRST room on a
    highway to reach it, hotel.tier_new), every recipe star, every baraat or festival step,
    and each counter look the first time per highway per counter. kinds: limit the
    non-purchase events to these kinds."""
    ev = [t for t, k in m.fresh_events if kinds is None or k in kinds]
    return sorted([p[0] for p in m.purchases if p[5]] + ev)


def cadence_times(times_all, t0, t1):
    """cadence() on a plain list of event times: units, distinct moments, gaps between
    moments (the first from the previous event), dry 5-minute windows, the longest gap's end."""
    times = sorted({round(x, 3) for x in times_all})
    inside = [x for x in times if t0 - 1e-6 <= x <= t1 + 1e-6]
    gaps = []
    for x in inside:
        i = bisect.bisect_left(times, x)
        gaps.append(x - (times[i - 1] if i > 0 else 0.0))
    nwin = int((t1 - t0) // WINDOW_S)
    dry = 0
    for k in range(nwin):
        a, b = t0 + k * WINDOW_S, t0 + (k + 1) * WINDOW_S
        i = bisect.bisect_left(times, a - 1e-6)
        if not (i < len(times) and times[i] < b - 1e-6):
            dry += 1
    n = sum(1 for x in times_all if t0 - 1e-6 <= x <= t1 + 1e-6)
    mx = max(gaps) if gaps else None
    return {"units": n, "moments": len(inside), "p50": pctl(gaps, 0.5), "p90": pctl(gaps, 0.9),
            "max": mx, "max_at": inside[gaps.index(mx)] if gaps else None, "dry5": dry, "windows": nwin}


def authored_end(m):
    """Time of the last authored mark: the last stage's "all done" when no promotion is left
    (the end of the story), else None."""
    last = None
    for st in m.stage_info:
        if st.get("end") is not None:
            last = st["end"]
    done = bool(m.stage_info) and m.stage_info[-1].get("end") is not None and m.next_promotion() is None
    return last if done else None


def first_wait_over(times, limit_s, t_end):
    """Time of the last FRESH thing before the first wait longer than limit_s (None: none
    before t_end): the binge view of how long something new keeps coming."""
    prev = 0.0
    for x in sorted({round(v, 3) for v in times}) + [t_end]:
        if x - prev > limit_s + 1e-6:
            return prev
        prev = x
    return None


def print_fresh(m, run_end):
    """EXT: FRESH cadence inside and after the story, its longest waits and the binge view."""
    ft = fresh_times(m)
    ae = authored_end(m)
    te = ae if ae is not None else run_end
    a = cadence(m, 0.0, te)
    f = cadence_times(ft, 0.0, te)
    print(f"  FRESH (strict: NEW purchases, first room per look per highway, stars, event steps, counter looks)"
          f" inside the story 0:00:00 -> {fmt_h(te)}{'' if ae is not None else ' (story not finished)'}:"
          f" {f['units']} things, gap p50 {fmt_m(f['p50'])} p90 {fmt_m(f['p90'])} max {fmt_m(f['max'])} min"
          f" (ends {fmt_h(f['max_at'])}), dry {f['dry5']}/{f['windows']}; ALL purchases max gap {fmt_m(a['max'])} min,"
          f" dry {a['dry5']}/{a['windows']}")
    tt = sorted({round(x, 3) for x in ft if x <= te + 1e-6})
    big = sorted(((b - x, x, b) for x, b in zip(tt, tt[1:])), reverse=True)[:5]
    if big:
        print("  longest FRESH waits inside the story (min, from -> to): "
              + ", ".join(f"{gg / 60:.1f} ({fmt_h(x)} -> {fmt_h(b)})" for gg, x, b in big))
    if ae is not None and run_end > ae + WINDOW_S:
        aa, ff = cadence(m, ae, run_end), cadence_times(ft, ae, run_end)
        print(f"  after the story {fmt_h(ae)} -> {fmt_h(run_end)}: ALL {aa['units']} purchases, max gap {fmt_m(aa['max'])};"
              f" FRESH {ff['units']}, p50 {fmt_m(ff['p50'])} p90 {fmt_m(ff['p90'])} max {fmt_m(ff['max'])}, dry {ff['dry5']}/{ff['windows']}")
    w15, w30 = first_wait_over(ft, 900.0, run_end), first_wait_over(ft, 1800.0, run_end)
    print(f"  binge view: something new at least every 15 min until {fmt_h(w15) if w15 is not None else 'the run end ' + fmt_h(run_end)};"
          f" every 30 min until {fmt_h(w30) if w30 is not None else 'the run end ' + fmt_h(run_end)}")
    return {"story_end_s": ae, "inside": f, "w15_s": w15, "w30_s": w30}


def clock(cal_s):
    """Calendar seconds after install-day 00:00 -> 'day N HH:MM'."""
    d = int(cal_s // 86400)
    r = cal_s - d * 86400
    return f"day {d + 1} {int(r // 3600):02d}:{int(r % 3600 // 60):02d}"


def play_to_cal(m, t):
    """Calendar seconds of play time t in a sessions run."""
    for k, a, b, _day in m.sess_bounds:
        if a - 1e-6 <= t <= b + 1e-6:
            return m.cal_start(k) + (t - a)
    k, a, _b, _day = m.sess_bounds[-1]
    return m.cal_start(k) + (t - a)


def freshness(m, ndays):
    """EXT: per session and per calendar day, the FRESH things (NEW purchases, stars, event
    steps, counter looks), plus the story's end, 10 in-app hours and the offline share."""
    newt = sorted(p[0] for p in m.purchases if p[5])
    cats = {"star": [], "baraat": [], "festival": [], "look": []}
    for t, k in m.fresh_events:
        cats.setdefault(k, []).append(t)
    for v in cats.values():
        v.sort()

    def cnt(ts, lo, hi):
        return bisect.bisect_left(ts, hi) - bisect.bisect_left(ts, lo)
    rows = []
    last = m.sess_bounds[-1] if m.sess_bounds else None
    for sb in m.sess_bounds:
        k, a, b, day = sb
        lo, hi = a - 1e-6, (b + 1e-6 if sb is last else b - 1e-6)
        r = {"k": k, "day": day, "a": a, "b": b, "new": cnt(newt, lo, hi), "stars": cnt(cats["star"], lo, hi),
             "events": cnt(cats["baraat"], lo, hi) + cnt(cats["festival"], lo, hi), "looks": cnt(cats["look"], lo, hi),
             "buys": sum(1 for p in m.purchases if lo <= p[0] < hi)}
        r["fresh"] = r["new"] + r["stars"] + r["events"] + r["looks"]
        rows.append(r)
    days = {}
    for r in rows:
        d = days.setdefault(r["day"], {"day": r["day"] + 1, "sessions": 0, "empty_sessions": 0, "play_end": 0.0,
                                        "buys": 0, "new": 0, "stars": 0, "events": 0, "looks": 0, "fresh": 0})
        d["sessions"] += 1
        d["empty_sessions"] += 1 if r["fresh"] == 0 else 0
        d["play_end"] = r["b"]
        for kk in ("buys", "new", "stars", "events", "looks", "fresh"):
            d[kk] += r[kk]
    win = [r for r in rows if r["day"] < ndays]
    streak = best = best_win = 0
    for r in rows:
        streak = streak + 1 if r["fresh"] == 0 else 0
        best = max(best, streak)
        if r["day"] < ndays:
            best_win = max(best_win, streak)
    ae = authored_end(m)
    ten = None
    for r in rows:
        if r["b"] >= 600 * 60.0 - 1e-6:
            ten = m.cal_start(r["k"]) + (600 * 60.0 - r["a"])
            break
    off = sum(x["offline"] for x in m.session_log)
    hoff = sum(x["hotel"] for x in m.session_log)
    other = sum(v for k, v in m.g.rew.items() if k not in ("offline", "hotel_offline"))
    return {"rows": rows, "days": [days[k] for k in sorted(days)], "ndays": ndays,
            "empty_days": [d + 1 for d in range(ndays) if d in days and days[d]["fresh"] == 0],
            "days_no_purchase": [d + 1 for d in range(ndays) if d in days and days[d]["new"] == 0],
            "missing_days": [d + 1 for d in range(ndays) if d not in days],
            "win_sessions": len(win), "win_empty": sum(1 for r in win if r["fresh"] == 0),
            "win_longest_empty": best_win, "longest_empty": best,
            "story_end_s": ae, "story_end_cal": play_to_cal(m, ae) if ae is not None else None,
            "ten_h_cal": ten, "offline": off + hoff, "hotel_offline": hoff,
            "offline_share": (off + hoff) / max(1e-9, off + hoff + m.g.sales_sum + other)}


def print_freshness(m, ndays, show_days=True):
    f = freshness(m, ndays)
    print()
    print(f"FRESHNESS (sessions {m.sess['per_day']}x{m.sess['minutes']:g}; FRESH = NEW purchases + stars + baraat/festival steps"
          f" + counter looks; a session's opening burst counts in that session)")
    se = f["story_end_s"]
    if se is not None:
        print(f"  story end: play {fmt_h(se)} = {se / 3600:.2f} in-app h, {clock(f['story_end_cal'])}"
              f" ({f['story_end_cal'] / 86400:.2f} days after install-day 00:00)")
    else:
        print("  story end: not reached in this run")
    if f["ten_h_cal"] is not None:
        print(f"  10 in-app hours of play reached on {clock(f['ten_h_cal'])}")
    print(f"  days 1-{ndays} with nothing FRESH: {f['empty_days'] or 'none'}; with no NEW purchase: "
          f"{f['days_no_purchase'] or 'none'}" + (f"; not reached in the run: {f['missing_days']}" if f["missing_days"] else ""))
    pc = f["win_empty"] / max(1, f["win_sessions"])
    print(f"  sessions in days 1-{ndays}: {f['win_sessions']}, with nothing FRESH {f['win_empty']} ({pc:.0%}),"
          f" longest run of such sessions {f['win_longest_empty']} (whole run: {f['longest_empty']})")
    print(f"  money: offline pay {P.rupees(f['offline'])} (hotel line {P.rupees(f['hotel_offline'])}),"
          f" {f['offline_share']:.0%} of all money")
    if m.salaam_log:
        print(f"  daily salaam: {len(m.salaam_log)} mornings, {sum(x[2] for x in m.salaam_log):g} Izzat")
    if show_days:
        print(f"  {'day':>4} {'sess':>4} {'empty':>5} {'play to':>8} {'buys':>6} {'NEW':>4} {'stars':>5} {'steps':>5}"
              f" {'looks':>5} {'FRESH':>5}")
        for d in f["days"]:
            print(f"  {d['day']:>4} {d['sessions']:>4} {d['empty_sessions']:>5} {fmt_h(d['play_end']):>8} {d['buys']:>6}"
                  f" {d['new']:>4} {d['stars']:>5} {d['events']:>5} {d['looks']:>5} {d['fresh']:>5}")
    return f


# =============================================================== printing
def _cad_cells(c):
    return (f"{c['units']:>5} {c['moments']:>5} {fmt_m(c['p50']):>5} {fmt_m(c['p90']):>5} {fmt_m(c['max']):>5}"
            f" {str(c['dry5']) + '/' + str(c['windows']):>7}")


def print_curve(m, title, run_end):
    rows = stage_rows(m, run_end)
    print()
    print("=" * 140)
    print(f"CURVE - {title}")
    print("  bot time after the tutorial (h:mm:ss); left = promotion bought; per stage from its start to 'left' (or the run's end):"
          " buys = purchases, mom = buy moments,")
    print("  gaps between buy moments in minutes (p50 / p90 / max), dry = 5-min windows with no purchase / all windows;"
          " NEW = only purchases that add something (dish, build, hire, table, signboard, tray, promotion, room, perk)")
    print("=" * 140)
    hdr = f"{'buys':>5} {'mom':>5} {'p50':>5} {'p90':>5} {'max':>5} {'dry':>7}"
    print(f"{'#':>2} {'stage':<16} {'mult':>6} {'start':>8} {'all done':>8} {'unlock':>8} {'left':>8} {'min':>6} |"
          f" ALL {hdr} | NEW {hdr}")
    for r in rows:
        left = fmt_h(r.get('promo')) if r.get('promo') is not None else '(open)'
        print(f"{r['idx']:>2} {r['key']:<16} {r['mult']:>6.2f} {fmt_h(r['start']):>8} {fmt_h(r.get('end')):>8}"
              f" {fmt_h(r.get('unlock')):>8} {left:>8} {r['dur'] / 60:>6.1f} |"
              f"     {_cad_cells(r['cad'])} |     {_cad_cells(r['new_cad'])}")
    print("  after 'all done' (the stage's content is done; to 'left' or the run's end):")
    for r in rows:
        if r.get("after_cad") is None:
            continue
        a, an = r["after_cad"], r["after_new"]
        print(f"     {r['key']:<16} {(r['t1'] - r['end']) / 60:>6.1f} min | ALL {_cad_cells(a)} | NEW {_cad_cells(an)}")
    whole = cadence(m, 0.0, run_end)
    wn = cadence(m, 0.0, run_end, new_only=True)
    print(f"  whole run 0:00:00 -> {fmt_h(run_end)}: ALL {whole['units']} purchases, {whole['moments']} moments,"
          f" gap p50 {fmt_m(whole['p50'])} p90 {fmt_m(whole['p90'])} max {fmt_m(whole['max'])} min, dry {whole['dry5']}/{whole['windows']};"
          f" NEW {wn['units']}, gap p50 {fmt_m(wn['p50'])} p90 {fmt_m(wn['p90'])} max {fmt_m(wn['max'])} min, dry {wn['dry5']}/{wn['windows']}")
    print("  by kind: " + ", ".join(f"{k} {v}" for k, v in sorted(whole["kinds"].items(), key=lambda kv: -kv[1])))
    last = max((p[0] for p in m.purchases), default=None)
    last_new = max((p[0] for p in m.purchases if p[5]), default=None)
    print(f"  last purchase {fmt_h(last)}, last NEW purchase {fmt_h(last_new)}")
    saves = [(r["key"], r["promo"] - r["unlock"]) for r in rows if r.get("promo") is not None and r.get("unlock") is not None]
    if saves:
        print("   saves for a promotion (unlock -> bought, min): " + ", ".join(f"{k} {v / 60:.1f}" for k, v in saves)
              + f"; longest {max(saves, key=lambda kv: kv[1])[0]} {max(v for _, v in saves) / 60:.1f} min")
    return rows


def print_timeline(m, every):
    print()
    print(f"TIMELINE (every {every:g} min; display rupees; buys = purchases in the window; cash min = cash on hand in minutes of"
          f" the takings; payback = minutes the best LEVEL UP needs to pay for itself; izzat = unspent/earned)")
    print(f"{'t':>8} | {'stage':<16} | {'cash':>10} | {'cash min':>8} | {'real/min':>10} | {'hotel/min':>9} | {'payback':>7} | {'buys':>4} |"
          f" {'izzat':>9} | {'stars':>5} | levels / rooms / waiters / tables / signboard")
    prev = 0
    for s in m.timeline:
        cm = s["cash"] / max(1e-9, s["real"] + s["hotel"])
        pb = f"{s['payback']:.0f}" if s.get("payback") is not None else "-"
        print(f"{fmt_h(s['t']):>8} | {s['stage']:<16} | {P.rupees(s['cash']):>10} | {cm:>8.1f} | {P.rupees(s['real']):>10} |"
              f" {P.rupees(s['hotel']):>9} | {pb:>7} | {s['n_buys'] - prev:>4} | {s['izzat']:>4.0f}/{s['izzat_earned']:<4.0f} | {s['stars']:>5} |"
              f" L{s['levels']} R{s['rooms']} W{s['W']} T{s['T']} S{s['sign']}")
        prev = s["n_buys"]


def print_meta(m):
    c = m.c
    if c["izzat"].get("enabled"):
        print()
        print(f"IZZAT: earned {m.izzat_earned:g}, unspent {m.izzat:g}; by source "
              + ", ".join(f"{k} {v:g}" for k, v in sorted(m.izzat_src.items(), key=lambda kv: -kv[1])))
        print("  perks bought (time, perk, level, cost): "
              + (", ".join(f"({fmt_h(t)}, {p} L{lv}, {cst:g})" for t, p, lv, cst in m.perk_log) or "none"))
        print("  perk levels at the end: " + ", ".join(f"{k} {v}" for k, v in m.g.perk.items()))
    if c["mastery"].get("enabled"):
        tot = sum(m.stars.values())
        by_n = {}
        for v in m.stars.values():
            by_n[v] = by_n.get(v, 0) + 1
        top = sorted(m.serves.items(), key=lambda kv: -kv[1])[:6]
        print(f"MASTERY: {tot} stars ({', '.join(f'{n} dishes at {k} star(s)' for k, n in sorted(by_n.items()) if k > 0) or 'none'});"
              f" first star at {fmt_h(m.star_log[0][0]) if m.star_log else '-'}; last at {fmt_h(m.star_log[-1][0]) if m.star_log else '-'};"
              f" dishes counted {len(m.serves)}")
        print("  most served: " + ", ".join(f"{k[0]}.{k[1]}#{k[2] + 1} {v:.0f}" for k, v in top))
    if m.hotel_log or m.hotel_paid:
        print(f"HOTEL: {len(m.hotel_log)} hotel purchases, paid {P.rupees(m.hotel_paid)} in play")
    if m.hotel_done_log:
        print("  hotel share of the takings when each hotel is done: "
              + ", ".join(f"{loc} {fmt_h(t)} {h / max(1e-9, h + r):.0%}" for t, loc, h, r in m.hotel_done_log))
    dec = [p for p in m.purchases if p[1] == "decor"]
    if dec:
        print("DECOR: " + ", ".join(f"#{p[2] + 1} {fmt_h(p[0])} ({P.rupees(p[3])})" for p in dec))
    if m.fest_prog:
        print("FESTIVALS: " + ", ".join(f"{m.c['festivals'][i].get('name', i)} {v['steps']} steps, {v['guests']:.0f} guests"
                                        + (f", last step at {fmt_h(v['done_t'])}" if v.get("done_t") else "")
                                        for i, v in m.fest_prog.items()))
    if m.tut_serves:
        print(f"MASTERY: the slot-1 chai track starts with {m.tut_serves:.0f} tutorial serves (mastery.count_tutorial)")


# =============================================================== summary
def _cad_json(c):
    """Cadence dict with the gaps in minutes."""
    return {k: (round(v / 60.0, 2) if k in ("p50", "p90", "max") and v is not None else v) for k, v in c.items()}


def summary(m, name, mode, minutes, rows):
    ds = P.DISPLAY_SCALE[0]
    legacy = {k: round(v, 1) for k, v in m.marks.items() if k in LEGACY_KEYS}
    last_end = None
    for r in rows:
        if r.get("end") is not None:
            last_end = r["end"]
    final_reached = rows and rows[-1].get("end") is not None and m.next_promotion() is None
    out = {
        "tool": "content10h", "overlay": name, "mode": mode, "minutes": minutes, "dt": m.dt, "wall_s": round(m.wall_s, 2),
        "marks": {k: round(v, 1) for k, v in m.marks.items() if not k.startswith(("wl", "sign"))},
        "legacy_marks": legacy,
        "waiter_levels": {k[2:]: v for k, v in m.marks.items() if k.startswith("wl")},
        "total_bot_s": round(last_end, 1) if final_reached else None,
        "last_mark_s": round(last_end, 1) if last_end is not None else None,
        "stages": [{"idx": r["idx"], "key": r["key"], "mult": round(r["mult"], 3), "start": round(r["start"], 1),
                    "end": round(r["end"], 1) if r.get("end") is not None else None,
                    "unlock": round(r["unlock"], 1) if r.get("unlock") is not None else None,
                    "promo": round(r["promo"], 1) if r.get("promo") is not None else None,
                    "dur_min": round(r["dur"] / 60.0, 2),
                    "cadence": _cad_json(r["cad"]), "cadence_new": _cad_json(r["new_cad"]),
                    "after_all_done": _cad_json(r["after_cad"]) if r.get("after_cad") else None,
                    "after_all_done_new": _cad_json(r["after_new"]) if r.get("after_new") else None} for r in rows],
        "cadence_all": _cad_json(cadence(m, 0.0, m.t)),
        "cadence_all_new": _cad_json(cadence(m, 0.0, m.t, new_only=True)),
        "last_purchase_s": round(max((p[0] for p in m.purchases), default=0.0), 1),
        "last_new_purchase_s": round(max((p[0] for p in m.purchases if p[5]), default=0.0), 1),
        "longest_save_min": round(max([(r["promo"] - r["unlock"]) for r in rows if r.get("promo") is not None
                                       and r.get("unlock") is not None] or [0.0]) / 60.0, 2),
        "izzat": {"earned": m.izzat_earned, "unspent": m.izzat, "by_source": m.izzat_src, "perks": m.g.perk},
        "stars": sum(m.stars.values()),
        "hotel_paid": round(m.hotel_paid * ds),
        "end": {"cash": round(m.g.cash * ds), "real_per_min": round(m.real_per_min() * ds),
                "levels": {s: m.g.st[s]["level"] for s in m.g.station_ids() if m.g.st[s]["built"]},
                "waiters": m.g.waiters, "location": m.g.location, "stage": m.stage_info[-1]["key"]},
    }
    if m.sess:
        out["sessions"] = {"pattern": f"{m.sess['per_day']}x{m.sess['minutes']:g}",
                           "cal_marks_days": {k: round(v[0] / 86400.0, 2) for k, v in m.cal_marks.items()},
                           "sessions_played": m.s_idx + 1}
    return out


def checks_like_pacing(m):
    """The SUMMARY "checks" list exactly as pacing_v3 print_round2 rounds it."""
    ds = P.DISPLAY_SCALE[0]
    return [{"min": c["min"], "cash": round(c["cash"] * ds), "real": round(c["real"] * ds), "hud": round(c["hud"] * ds),
             "sales": round(c["sales"] * ds), "rew": round(sum(c["rew"].values()) * ds),
             "ads": round(c["rew"].get("ad", 0) * ds), "bill": round(c["bill"] * ds, 1),
             "off": round(c["off_basis"] * ds),
             "prices": {k: round(v * ds, 1) for k, v in c["prices"].items()},
             "levels": c["levels"]} for c in m.checks]


# =============================================================== regression
def regression(args):
    """Runs pacing_v3.py --promo (subprocess) and this tool with the empty overlay for
    the same seeds and flags; compares the stage marks, the waiter levels and every
    checkpoint of its SUMMARY. Three flag sets: ads, --no-ads, --ad-sessions 20."""
    base = []
    if args.realized != P.REALIZED:
        base += ["--realized", str(args.realized)]
    if args.no_signboard:
        base.append("--no-signboard")
    if args.no_trays:
        base.append("--no-trays")
    if args.starter:
        base += ["--starter", str(args.starter)]
    if args.difficulty is not None:
        base += ["--difficulty", str(args.difficulty)]
    combos = [("ads", []), ("no-ads", ["--no-ads"]), ("sessions-20", ["--ad-sessions", "20"])]
    mins = args.check_minutes
    fails = 0
    print("=" * 100)
    print(f"REGRESSION - content10h with {OVERLAY_DIR / 'none.json'} vs pacing_v3.py --promo"
          f" (--seeds {args.seeds} --seed {args.seed} --minutes {mins:g} {' '.join(base)})")
    print("=" * 100)
    for label, flags in combos:
        cmd = [sys.executable, "-I", "-B", str(HERE / "pacing_v3.py"), "--promo", "--seeds", str(args.seeds),
               "--seed", str(args.seed), "--minutes", str(mins)] + base + flags
        t0 = time.time()
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
        t_ref = time.time() - t0
        line = next((ln for ln in res.stdout.splitlines() if ln.startswith("SUMMARY ")), None)
        if line is None:
            print(f"  [{label}] pacing_v3.py printed no SUMMARY (exit {res.returncode}): REGRESSION FAIL")
            fails += 1
            continue
        ref = json.loads(line[len("SUMMARY "):])
        eco, content, hwconf, _ = load_setup(OVERLAY_DIR / "none.json", args.eco, (), args.difficulty)
        ads = "--no-ads" not in flags
        P.DISPLAY_SCALE[0] = float(eco.get("money_display_scale", 10.0))
        t0 = time.time()
        run, _info = pick_start_run(eco, args.seeds, args.seed, ads)
        opts = dict(ads=ads, realized=args.realized, no_signboard=args.no_signboard, no_trays=args.no_trays,
                    ad_sessions=20.0 if "--ad-sessions" in flags else 0.0, starter=args.starter, dt=0.5)
        m = run_model(eco, content, hwconf, run, opts, mins)
        t_me = time.time() - t0
        diffs = []
        rm = ref["promo"]["marks"]
        for k in LEGACY_KEYS:
            a, b = rm.get(k), (round(m.marks[k], 1) if k in m.marks else None)
            if a != b:
                diffs.append(f"{k}: pacing_v3 {a} vs content10h {b}")
        rw = ref["promo"]["waiter_levels"]
        mw = {k[2:]: v for k, v in m.marks.items() if k.startswith("wl")}
        for k in sorted(set(rw) | set(mw)):
            if rw.get(k) != mw.get(k):
                diffs.append(f"waiter levels at promotion {k}: pacing_v3 {rw.get(k)} vs content10h {mw.get(k)}")
        mine = checks_like_pacing(m)
        nchk = 0
        for a, b in zip(ref["checks"], mine):
            nchk += 1
            if a != b:
                diffs.append(f"checkpoint {a['min']} min differs: pacing_v3 {json.dumps(a)[:160]} vs content10h {json.dumps(b)[:160]}")
        if len(ref["checks"]) != len(mine):
            diffs.append(f"checkpoint count {len(ref['checks'])} vs {len(mine)}")
        sb = [(round(t, 1), s, n, round(c, 2)) for t, s, n, c in m.sign_log]
        rsb = [(x["t"], x["stage"], x["level"], x["cost"]) for x in ref["promo"]["sign_buys"]]
        if sb != rsb:
            diffs.append(f"signboard buys differ: {rsb} vs {sb}")
        ok = not diffs
        fails += 0 if ok else 1
        marks_s = " ".join(f"{k} {P.fmt_t(m.marks[k]).strip()}" for k in LEGACY_KEYS if k in m.marks)
        print(f"  [{label:<11}] {'OK  ' if ok else 'FAIL'} marks {marks_s}; wl {mw}; {nchk} checkpoints and"
              f" {len(sb)} signboard buys compared (pacing_v3 {t_ref:.1f} s, content10h {t_me:.1f} s)")
        for d in diffs:
            print("       DIFF " + d)
    print("REGRESSION OK" if fails == 0 else f"REGRESSION FAIL ({fails} of {len(combos)} flag sets differ)")
    return fails


# =============================================================== main
def parse_sessions(txt, content):
    s = copy.deepcopy(content["sessions"])
    if txt and txt != "content":
        a, _, b = txt.lower().partition("x")
        s["per_day"] = int(a)
        s["minutes"] = float(b)
        if len(s["starts_h"]) != s["per_day"]:
            # spread the sessions over the waking day (8:00 - 22:00)
            n = s["per_day"]
            s["starts_h"] = [8.0 + (14.0 * i / max(1, n - 1) if n > 1 else 0.0) for i in range(n)]
    return s


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--overlay", default=str(OVERLAY_DIR / "none.json"), help="overlay JSON (default content10h/none.json)")
    ap.add_argument("--eco", default=str(P.ECO_PATH))
    ap.add_argument("--minutes", type=float, default=420.0, help="bot minutes after the tutorial (default 420 = 7 h)")
    ap.add_argument("--seeds", type=int, default=40)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--no-ads", action="store_true")
    ap.add_argument("--ad-sessions", type=float, default=0.0, metavar="M")
    ap.add_argument("--realized", type=float, default=P.REALIZED)
    ap.add_argument("--no-signboard", action="store_true")
    ap.add_argument("--no-trays", action="store_true")
    ap.add_argument("--starter", type=float, default=0.0, metavar="MIN")
    ap.add_argument("--difficulty", type=float, default=None)
    ap.add_argument("--sessions", default=None, metavar="NxMIN",
                    help="also run the sessions bot: N sessions a day of MIN minutes (e.g. 3x20; 'content' = the overlay's)")
    ap.add_argument("--dt", type=float, default=0.5, help="model step in seconds (0.5 = pacing_v3, exact)")
    ap.add_argument("--every", type=float, default=10.0, help="TIMELINE row interval in minutes")
    ap.add_argument("--set", action="append", default=[], metavar="PATH=JSON",
                    help="what-if override: an economy path or content.<path>, e.g. --set content.mastery.scope='\"slot\"'")
    ap.add_argument("--phase", type=float, default=None,
                    help="EXT: run only what ships up to this phase (= --set content.max_phase=N)")
    ap.add_argument("--days", type=int, default=15, help="EXT: sessions freshness check covers days 1..N (default 15)")
    ap.add_argument("--check", action="store_true", help="run the regression against pacing_v3.py --promo and exit")
    ap.add_argument("--check-minutes", type=float, default=100.0)
    ap.add_argument("--quiet", action="store_true", help="no TIMELINE")
    ap.add_argument("--json-out", default=None, help="also write the SUMMARY json(s) to this file (scratch use)")
    args = ap.parse_args()
    wall0 = time.time()
    if args.check:
        fails = regression(args)
        print(f"(wall time {time.time() - wall0:.1f} s)")
        raise SystemExit(1 if fails else 0)
    if args.phase is not None:
        args.set.append(f"content.max_phase={args.phase:g}")
    eco, content, hwconf, name = load_setup(args.overlay, args.eco, args.set, args.difficulty)
    if args.phase is not None:
        name = f"{name} (phase {args.phase:g})"
    P.DISPLAY_SCALE[0] = float(eco.get("money_display_scale", 10.0))
    ads = not args.no_ads
    run, info = pick_start_run(eco, args.seeds, args.seed, ads)
    order = [x for x in eco["locations"]["order"] if isinstance(eco["locations"].get(x), dict)]
    print(f"content10h - overlay {name}; economy version {eco.get('version')}; highways {' > '.join(order)};"
          f" hotel {'on' if content['hotel'].get('enabled') else 'off'}; Izzat {'on' if content['izzat'].get('enabled') else 'off'};"
          f" mastery {'on' if content['mastery'].get('enabled') else 'off'}; ads {'on' if ads else 'off'}; realized {args.realized:.2f}; dt {args.dt:g} s")
    print(f"part A: {info['replays']} tutorial replays in {info['part_a_s']:.1f} s ({info['tandoor_built']} built the tandoor);"
          f" part B starts from seed {info['start_seed']}'s end state (deterministic expected values: every seed gives this curve)")
    opts = dict(ads=ads, realized=args.realized, no_signboard=args.no_signboard, no_trays=args.no_trays,
                ad_sessions=args.ad_sessions, starter=args.starter, dt=args.dt)
    outs = []
    m = run_model(eco, content, hwconf, run, opts, args.minutes, label="continuous", every=args.every)
    rows = print_curve(m, f"{name}, continuous bot, {args.minutes:g} min"
                       + (f", ad cap per {args.ad_sessions:g}-min session" if args.ad_sessions else ", one ad session"), m.t)
    fx1 = print_fresh(m, m.t)
    print_meta(m)
    if not args.quiet:
        print_timeline(m, args.every)
    s1 = summary(m, name, "continuous", args.minutes, rows)
    s1["ext"] = {"story_end_s": fx1["story_end_s"], "fresh_inside": _cad_json(fx1["inside"]),
                 "w15_s": fx1["w15_s"], "w30_s": fx1["w30_s"], "stars_first_s": m.star_log[0][0] if m.star_log else None}
    outs.append(s1)
    print(f"(continuous model: {m.wall_s:.1f} s for {args.minutes:g} bot minutes)")
    if args.sessions:
        sess = parse_sessions(args.sessions, content)
        ms = run_model(eco, content, hwconf, run, opts, args.minutes, sessions=sess, label="sessions", every=args.every)
        rows2 = print_curve(ms, f"{name}, sessions {sess['per_day']} a day x {sess['minutes']:g} min"
                                f" (starts {sess['starts_h']} h, install weekday {sess['install_weekday']}), {args.minutes:g} play min", ms.t)
        fx2 = print_fresh(ms, ms.t)
        print_meta(ms)
        print()
        print("SESSIONS vs CONTINUOUS (bot / play time after the tutorial; calendar = day N (1 = install day), session k of that day)")
        print(f"  {'mark':<10} {'stage':<16} {'continuous':>11} {'sessions play':>13} {'calendar':>16} {'days':>6}")
        keys = [k for k in ms.marks if not k.startswith(("wl", "sign", "starter"))]
        stage_of = {}
        for r in rows2:
            for kk in ("end", "unlock", "promo"):
                stage_of[f"{kk}{r['idx']}"] = r["key"]
        for k in keys:
            cal, si = ms.cal_marks.get(k, (None, None))
            dday = cal / 86400.0 if cal is not None else None
            per = int(sess["per_day"])
            print(f"  {k:<10} {stage_of.get(k, ''):<16} {fmt_h(m.marks.get(k)):>11} {fmt_h(ms.marks[k]):>13}"
                  f" {('day ' + str(si // per + 1) + ' s' + str(si % per + 1)) if si is not None else '-':>16}"
                  f" {dday if dday is None else round(dday, 2):>6}")
        off = sum(x["offline"] for x in ms.session_log)
        hoff = sum(x["hotel"] for x in ms.session_log)
        print(f"  sessions played {ms.s_idx + 1}; offline paid {P.rupees(off)} ({sum(1 for x in ms.session_log if x['x2'])} doubled by the ad),"
              f" hotel offline {P.rupees(hoff)}; rewards by source: "
              + ", ".join(f"{k} {P.rupees(v)}" for k, v in sorted(ms.g.rew.items(), key=lambda kv: -kv[1])))
        fr = print_freshness(ms, args.days, show_days=True)
        if not args.quiet:
            print_timeline(ms, args.every)
        s2 = summary(ms, name, "sessions", args.minutes, rows2)
        s2["ext"] = {"story_end_s": fx2["story_end_s"], "fresh_inside": _cad_json(fx2["inside"]),
                     "story_end_cal_days": round(fr["story_end_cal"] / 86400.0, 3) if fr["story_end_cal"] is not None else None,
                     "ten_h_cal_days": round(fr["ten_h_cal"] / 86400.0, 3) if fr["ten_h_cal"] is not None else None,
                     "empty_days": fr["empty_days"], "days_no_purchase": fr["days_no_purchase"],
                     "win_sessions": fr["win_sessions"], "win_empty": fr["win_empty"],
                     "win_longest_empty": fr["win_longest_empty"], "offline_share": round(fr["offline_share"], 4),
                     "days": fr["days"]}
        outs.append(s2)
        print(f"(sessions model: {ms.wall_s:.1f} s)")
    for s in outs:
        print("SUMMARY " + json.dumps(s, ensure_ascii=False))
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(outs, indent=1, ensure_ascii=False))
    print(f"(wall time {time.time() - wall0:.1f} s)")


if __name__ == "__main__":
    main()
