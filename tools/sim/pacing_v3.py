#!/usr/bin/env python3
"""Pacing simulator for Dhaba Rush v0.3 (reference-match rebuild + menu expansion
+ station menus).

Mirrors scripts/autoload/game.gd (prices, costs, galla, waiters, table sets,
tasks, ad bubble, the drink + dish ORDER RULE, the station MENUS) and reads
themes/dhaba/economy.json. Stations: chai, tandoor (the tutorial), then the
buildable LASSI (drink, 2 waiters) and KADAI (dish, 3 waiters; docs/
v3-station-menus.md, 2026-10-21, one station where the egg bhurji and dal
makhani stood).

Station menus: every station serves a MENU of dishes; dish k unlocks at its
from_level (a milestone level). A ticket's dish is rolled from the unlocked
mix (newest dish weight_newest, the rest equal) and each dish's price / brew
factor is its raw factor divided by the mix's weighted mean, so a station's
expected bill and brew time are exactly price(sid) and processing(sid) in
every unlock state: the menus are a 1.0 factor on this model (menu_factor;
MENU CHECK asserts it before part A and counts toward the exit code). The
milestone log names the dish each milestone puts on the menu, the KAAM
served_dish cards are modelled (expected progress = serves x the dish's mix
weight) and every KAAM hand-out / drop is logged (KAAM cards block).

Part A replays the reference video's first 162 s with the original
walk-to-the-counter queue model: the scripted first traveller (with the two
pause_sim dialogue windows), hold_spawns until the transfer, the 5 injected
galla travellers, and every purchase / grant / claim / ad / build at the times
measured from the recording. It prints the simulated cash curve next to the
reference money pill (read off the frames every second) over many seeds. The
tutorial is chai-only, so neither the menu expansion nor the menus change it.

Part B continues from the end of that replay (tandoor built) in the SEATED
dhaba (docs/v3-architecture.md addenda + docs/v3-menu-expansion.md): arrivals
follow the ARRIVAL RAMP (waiters with whole-order trips worked out from the
Layout3 positions, seats, demand-weighted stations, gallas), travellers order
one drink + at most one dish, and a greedy bot claims tasks, watches wall ads
(at most ad_bubble.max_per_session per session, the tutorial's bubble included),
staffs the floor (hiring the waiter that gates the next station once it holds
the build cost plus the hire, as the game's nudges ask), levels stations and
builds LASSI -> KADAI as soon as each is affordable (saving for it once it
costs <= 4 min of real income). Calibrated against the same bot run in the
game (QA round 1, 2026-10-20; main3 --auto then the bot, 8 seeds each way):
part B starts from the game's own tutorial-end cash (INGAME_TUTORIAL_END_CASH,
not the replay's), its first wall ad comes ad_bubble.interval_s after the
tutorial (the tutorial's bubble was tapped), travellers arrive at REALIZED
(0.87 then; 0.92 since core and feel) x the ramp target and each one's
bill is priced PRICE_LAG_S after arriving (cooked) and paid PAY_LAG_S after
arriving (galla). With the station menus economy (2026-10-21): with ads
lassi 2:32 / kadai 8:22, without 2:32 / 10:13 (docs/v3-station-menus.md
§4.3). The HUD "/min" (and every reward sized
from it) is the game.gd rate: price x capacity x the station's demand share.
It prints a timeline (when each station becomes affordable and is built, the
milestones with their dishes), per build arrivals / bill / income / HUD
before -> after, the KAAM cards, and the BILL CHECK: every build must raise
the expected bill by at least MIN_BILL_GAIN (+15 %) at the moment it becomes
affordable.

--matrix adds the rule check: arrivals/min before -> after each build over
floor setups (waiters, table sets, tandoor cooks, galla level); an allowed
build that drops arrivals is a failure. --report SEC sets part B's report
row interval (default 120).

ROUND 2 (0.3.3, docs/round2/economy-proposal.md §9.4, owner decisions
2026-10-22): mirrors the normalised economy (eco "version" 4):
price_step_late / level_cost_mult_late (chai's step and Level Up cost from L25),
rewards.basis "real" (the wall ad, chest, generated cards, "earned" targets and
a card's reward_minutes are minutes of the HUD takings without VIP: here the
ramp target x the expected bill / VIP), the difficulty dial (eco
"difficulty.cost_mult" x every post-tutorial cost, the exempt_* keys as in
game.gd; --difficulty D overrides it), the offline rule (min_away_s,
ad_min_away_s). Part B starts from the 0.3.2 tutorial's end state (waiter 2
hired, table 3 bought). After part B it prints the ROUND 2 tables: checkpoints
(cash, real /min, sales vs ads / chest / cards), prices at checkpoints, the
offline offers on return (0.3.2 rule vs the JSON rule), the unlock list, and a
"SUMMARY {json}" line for scripts.

CORE AND FEEL (docs/core-and-feel/build-plan.md rev 2, W1-PACE): mirrors the
build-plan prototype (proto2), every number read from the economy JSON:
  - C5.1 chai's price step ramps down linearly from price_step (L ramp_from) to
    price_step_late (L ramp_to) when the station has price_step_ramp_to (L1-L13
    exact, so part A replays identically);
  - C5.3 the highway signboard (signboard block): the ramp cap becomes
    ramp_max_tpm + tpm_per_level x level; cost cost_base x cost_growth^level x
    the dial; max_levels roadside, max_levels_family after the renovation; the
    bot buys a level only while the road binds and its payback is at most
    max(offer_payback_min, the best LEVEL UP payback), never from cash saved for
    a promotion; the offline basis is (travellers_per_min + the bonus) capped by
    the stages;
  - C3.4 trays (waiters.tray_levels, tray_batch_est): waiter capacity x the mean
    over waiters of 1 + tray_batch_est x (orders - 1); generated waiter_level
    cards aim at the next tray level when it is within 2 x waiter_level_step;
  - C6.1 / C6.3 promotions (--promo): the Family Dhaba (renovation block) once
    every counter has all its dishes, then the NH 48 move (locations.nh48, the
    menu overlay applied, every counter but the start one rebuilt), both with a
    bot that saves for them; the family layout puts the AC hall's 3 tables
    after the store's first two (HALL_TABLES), starts with
    seating.tables_start_family tables, waiters.max_family waiters and
    seating.tables_max_family tables; prices x renovation.mult (x the
    location's mult after the move);
  - C7.4 the starter pack (--starter MIN: offers.starter.amount granted MIN
    minutes after the tutorial);
  - MENU CHECK runs once per location (the base menus, then each location's
    overlay) and every failure counts toward the exit code.
The PROMO block (with --promo) prints the marks (renovation unlock,
renovated, NH 48 unlock, moved, NH 48 all dishes), the signboard buys, the
bind shares per stage and the waiter levels at each promotion; the SUMMARY
JSON carries them under "promo".

DHABA GROWTH (docs/growth/plan.md step 5, 7 Nov 2026; --growth): the tutorial now
ends in the tin shack (growth stage 1), so part B starts there: the shack's
caps (growth.stages[1]: waiters_max, tables_max) hold, lassi and kadai wait for
the dhaba (growth.station_stage), and the bot saves for THE DHABA
(growth.builds.dhaba: cost x the dial once its requires are met, the NEXT
chip's goal) and buys it as soon as it can; the dhaba opens dur_s later
(--grow-skip: at once, the FINISH NOW ad). The GROWTH block prints when the
dhaba became buyable, was bought and opened, and when lassi and kadai were built.

Exit status 1 when the menu check, the bill check or the rule check fails.

Usage:
  python3 tools/sim/pacing_v3.py [--seeds 300] [--minutes 60] [--no-ads] [--seed 0]
                                 [--eco themes/dhaba/economy.json] [--matrix] [--report 120]
                                 [--set PATH=VALUE] [--difficulty D]
                                 [--promo] [--no-signboard] [--no-trays] [--realized R]
                                 [--ad-sessions M] [--starter MIN] [--starter-amount REF]
"""
import argparse
import copy
from collections import deque
import json
import math
import random
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ECO_PATH = ROOT / "themes" / "dhaba" / "economy.json"
DT = 0.05

# Money pill read off the reference frames (value shown at that second).
REF_CURVE = [
    (36.0, 100.00), (37.0, 101.00), (46.0, 98.50), (48.0, 93.35), (50.0, 82.41),
    (51.0, 76.61), (62.0, 76.61), (63.0, 78.24), (65.0, 100.00), (66.0, 50.00),
    (68.0, 51.63), (73.0, 53.26), (74.0, 54.89), (77.0, 58.15), (84.0, 61.41),
    (89.0, 63.04), (97.0, 67.93), (101.0, 71.19), (105.0, 72.82), (108.0, 68.82),
    (110.0, 72.08), (117.0, 75.34), (121.0, 76.97), (123.0, 66.97), (127.0, 64.19),
    (130.0, 65.82), (133.0, 51.02), (134.0, 52.72), (139.0, 54.49), (141.0, 104.26),
    (147.0, 107.80), (149.0, 207.80), (154.0, 211.34), (158.0, 213.11), (161.0, 14.88),
]
# HUD "/min" read off the frames (the reference lags one level on Level Up;
# ours recomputes after the purchase, so it can read one level higher).
REF_RATE = [(45.0, 30), (51.0, 47), (63.0, 49), (123.0, 50), (127.0, 52), (130.0, 54), (161.0, 54)]

# Player actions in the reference (times measured from the money pill).
REF_ACTIONS = [
    (45.7, "level", "chai"), (46.5, "level", "chai"), (47.5, "level", "chai"),
    (49.2, "level", "chai"), (49.4, "level", "chai"), (49.6, "level", "chai"),
    (49.8, "level", "chai"), (50.4, "level", "chai"), (50.8, "level", "chai"),
    (56.6, "transfer", None),
    (57.5, "inject", None),
    (64.5, "grant", 100.0),
    (65.5, "galla_hire", None),
    (107.5, "galla_up", 0),
    (122.5, "proc", "chai"),
    (125.5, "level", "chai"), (126.5, "level", "chai"),
    (131.5, "galla_up", 0), (132.5, "galla_up", 1),
    (138.9, "claim", 1),
    (144.0, "ad_show", None),
    (147.53, "ad_free", None),
    (160.5, "build", "tandoor"),
]
# Rows where the reference HUD shows a count-up still in progress.
COUNTUP_ROWS = {139.0}
# pause_sim dialogue windows (lines 3 and 4) and the scripted traveller.
PAUSES = [(19.30, 22.34), (27.05, 32.25)]
FIRST_TRAVELLER_SPAWN = 10.3
TRANSFER_T = 56.6
TASK_ABS = ("level", "build", "galla_level", "hire", "processing")


def snap(v, step=0.01):
    return round(v / step) * step


def nice(v):
    if v <= 0:
        return 0.0
    mag = 10.0 ** (math.floor(math.log10(v)) - 1)
    return round(v / mag) * mag


def fmt_t(s):
    return f"{int(s // 60):2d}:{s % 60:05.2f}"


DISPLAY_SCALE = [10.0]


def rupees(v):
    """Display value (x money_display_scale) with Indian grouping, like Fmt.money."""
    d = v * DISPLAY_SCALE[0]
    if abs(d) >= 1e7:
        return f"{d / 1e7:.2f} Cr"
    if abs(d) >= 1e5:
        return f"{d / 1e5:.2f} L"
    if abs(d) >= 1000:
        s = f"{int(round(abs(d))):d}"
        head, tail = s[:-3], s[-3:]
        parts = []
        while len(head) > 2:
            parts.insert(0, head[-2:])
            head = head[:-2]
        if head:
            parts.insert(0, head)
        return ("-" if d < 0 else "") + ",".join(parts + [tail])
    return f"{d:.2f}" if abs(d - round(d)) > 0.001 else f"{int(round(d))}"


# =============================================================== Game mirror
class Game:
    """Mirror of scripts/autoload/game.gd economy + tasks (no Godot)."""

    def __init__(self, eco):
        self.e = eco
        st = eco["start"]
        self.cash = float(st["cash"])
        self.sikke = int(st["sikke"])
        self.vip = False
        self.st = {}
        for sid in self.station_ids():
            d = eco["stations"][sid]
            self.st[sid] = {"built": bool(d.get("start_built", False)), "level": 1,
                            "employees": max(1, int(d.get("employees_start", 1))), "proc": 0}
        self.gallas = [1]
        self.task_used = set()
        self.task_log = []   # ("card" | "drop", id) since the last flush (SeatedModel.act logs them)
        self.task_gen = 0
        self.chest_claims = 0
        self.claims = 0
        self.lifetime = 0.0
        self.sales = 0
        self.served = 0
        self.ad_auto = False
        self.on_galla_hired = None
        # ROUND 2 (economy proposal): rewards can be sized on the REAL takings
        # (eco "rewards.basis" = "real": the HUD /min without VIP, set by
        # SeatedModel) instead of the capacity rate; per-source sums.
        self.reward_rate_fn = None
        self.rew = {}
        self.sales_sum = 0.0
        # CORE AND FEEL: promotions (stage 0 roadside, 1 Family Dhaba, 2 NH 48),
        # the price multiplier they bring (game.gd fame_mult) and the signboard level
        self.stage = 0
        self.mult = 1.0
        self.sign = 0
        self.location = "nh44"
        self.tasks = self._start_tasks()

    # ---- stations
    def station_ids(self):
        return [s for s in self.e["station_order"] if s in self.e["stations"]]

    def sdef(self, sid):
        return self.e["stations"][sid]

    def built(self):
        return [s for s in self.station_ids() if self.st[s]["built"]]

    def milestones(self, lvl):
        return sum(1 for m in self.e["level_milestones"] if lvl >= m)

    def milestone_mult(self, lvl):
        return self.e.get("milestone_price_mult", 2.0) ** self.milestones(lvl)

    def price_at(self, sid, lvl):
        d = self.sdef(sid)
        base, step = d["price_base"], d["price_step"]
        if "price_step_late" in d:
            # ROUND 2: the step changes at the first milestone (chai keeps the
            # tutorial's 0.07 up to L24, then price_step_late).
            # C5.1 (core and feel): with price_step_ramp_to the step ramps down
            # linearly from price_step at price_step_ramp_from to price_step_late
            # at price_step_ramp_to (closed form, as game.gd _price_at).
            late = d["price_step_late"]
            f0 = int(self.e["level_milestones"][0])
            f1 = f0
            if "price_step_ramp_to" in d:
                f0 = int(d.get("price_step_ramp_from", f0))
                f1 = max(f0, int(d["price_step_ramp_to"]))
            if lvl <= f0:
                p = base + step * (lvl - 1)
            elif lvl <= f1:
                n = lvl - f0
                p = base + step * (lvl - 1) - (step - late) / max(1, f1 - f0) * n * (n + 1) / 2.0
            else:
                n = f1 - f0
                p = base + step * (f1 - 1) - (step - late) / max(1, f1 - f0) * n * (n + 1) / 2.0 + late * (lvl - f1)
        else:
            p = base + step * (lvl - 1)
        # x the promotion multiplier (renovation.mult, x the location's mult after a move)
        return snap(p * self.milestone_mult(lvl)) * self.mult

    def price(self, sid):
        return self.price_at(sid, self.st[sid]["level"]) * self.menu_factor(sid)

    def processing(self, sid):
        d = self.sdef(sid)
        return d["processing_base"] / d["processing_div"] ** self.st[sid]["proc"] * self.menu_factor(sid)

    # ---- station menus (docs/v3-station-menus.md §1-2)
    def menu_factor(self, sid):
        """Station menus: every station serves a MENU of dishes (dish k unlocks at
        its from_level = a milestone level). A ticket's dish is rolled from the
        unlocked mix (newest dish weight_newest, the rest equal) and each dish's
        price / brew-time factor is its raw factor divided by the mix's weighted
        mean, so the expected bill and the expected brew time of a station equal
        price(sid) and processing(sid) in every unlock state: the factor the
        menus apply to this model is exactly 1.0 (menu_check asserts it)."""
        return 1.0

    def menu(self, sid):
        return self.sdef(sid).get("menu", [])

    def menu_weights(self, n):
        wn = float(self.e.get("menus", {}).get("weight_newest", 0.4))
        return [1.0] if n <= 1 else [(1.0 - wn) / (n - 1)] * (n - 1) + [wn]

    def dishes_unlocked(self, sid):
        lvl = self.st[sid]["level"]
        return max(1, sum(1 for d in self.menu(sid) if int(d.get("from_level", 1)) <= lvl))

    def dish_weight(self, sid, key):
        """Mix weight of dish `key` at the station's current unlock state (0 = locked)."""
        n = self.dishes_unlocked(sid)
        w = self.menu_weights(n)
        for k, d in enumerate(self.menu(sid)[:n]):
            if d.get("key") == key:
                return w[k]
        return 0.0

    def dish_name(self, sid, key):
        for d in self.menu(sid):
            if d.get("key") == key:
                return str(d.get("name", key))
        return key

    def capacity(self, sid):
        return 60.0 / self.processing(sid) * self.st[sid]["employees"]

    def income_mult(self):
        return self.e["income"]["vip_mult"] if self.vip else 1.0

    def station_income(self, sid):
        if not self.st[sid]["built"]:
            return 0.0
        return self.price(sid) * self.capacity(sid) * self.income_mult()

    def rate(self):
        return sum(self.station_income(s) for s in self.station_ids())

    def reward_rate(self):
        """Basis of every rate-sized reward: capacity (0.3.2) or the real takings (proposal)."""
        basis = self.e.get("rewards", {}).get("basis", "capacity")
        if basis == "real" and self.reward_rate_fn is not None:
            return self.reward_rate_fn()
        return self.rate()

    # ---- ROUND 2: the difficulty dial (game.gd _ddef / difficulty_cost_mult)
    def ddef(self):
        return self.e.get("difficulty") or {"cost_mult": 1.0, "exempt_levels_below": {"chai": 25},
                                            "exempt_speed": ["chai"], "exempt_builds": ["tandoor"],
                                            "exempt_waiter_hires": 1, "exempt_tables": 1}

    def dial(self):
        return max(0.1, float(self.ddef().get("cost_mult", 1.0)))

    def level_cost(self, sid):
        d = self.sdef(sid)
        lvl = self.st[sid]["level"]
        mc = self.e.get("milestone_cost_mult", 1.0) ** self.milestones(lvl)
        if self.milestones(lvl) > 0:
            mc *= float(d.get("level_cost_mult_late", 1.0))   # ROUND 2: chai's Level Up factor from L25
        if lvl >= int(self.ddef().get("exempt_levels_below", {}).get(sid, 0)):
            mc *= self.dial()
        return snap(d["level_cost_base"] * d["level_cost_growth"] ** (lvl - 1) * mc)

    def hire_cost(self, sid):
        d = self.sdef(sid)
        n = self.st[sid]["employees"] - max(1, int(d.get("employees_start", 1)))
        return snap(d["hire_cost_base"] * d["hire_cost_growth"] ** n * self.dial())

    def proc_cost(self, sid):
        d = self.sdef(sid)
        dial = 1.0 if sid in self.ddef().get("exempt_speed", []) else self.dial()
        return snap(d["proc_cost_base"] * d["proc_cost_growth"] ** self.st[sid]["proc"] * dial)

    def build_cost(self, sid):
        c = float(self.sdef(sid).get("build_cost", 0.0))
        return c if sid in self.ddef().get("exempt_builds", []) else snap(c * self.dial())

    def can_build(self, sid):
        d = self.sdef(sid)
        if not d.get("enabled", True) or self.st[sid]["built"]:
            return False
        req = d.get("requires", "")
        return req == "" or self.st[req]["built"]

    # ---- galla
    def galla_service(self, i):
        g = self.e["galla"]
        return g["service_base"] / g["service_div"] ** (self.gallas[i] - 1)

    def galla_rate_total(self):
        return sum(60.0 / self.galla_service(i) for i in range(len(self.gallas)))

    def galla_up_cost(self, i):
        g = self.e["galla"]
        bases = g["upgrade_cost_base"]
        base = bases[min(i, len(bases) - 1)] * 2.5 ** max(0, i - (len(bases) - 1))
        return snap(base * g["upgrade_cost_growth"] ** (self.gallas[i] - 1))

    def galla_hire_cost(self):
        costs = self.e["galla"]["hire_costs"]
        k = len(self.gallas) - 1
        return costs[k] if k < len(costs) else costs[-1] * 10 ** (k - len(costs) + 1)

    # ---- money
    def spend(self, amount):
        if self.cash + 1e-4 < amount:
            return False
        self.cash = max(0.0, self.cash - amount)
        return True

    def add_sale(self, amount):
        paid = snap(amount * self.income_mult())
        self.sales += 1
        self.sales_sum += paid
        self.lifetime += paid
        self.cash += paid
        self._task_add("earned", "", paid)
        self._task_add("billed", "", 1)
        self._check()
        return paid

    def add_reward(self, amount, source="task"):
        if amount <= 0:
            return
        self.rew[source] = self.rew.get(source, 0.0) + amount
        self.lifetime += amount
        self.cash += amount
        self._task_add("earned", "", amount)
        self._check()

    def buy(self, kind, arg=None):
        if kind == "level":
            d = self.sdef(arg)
            if not self.st[arg]["built"] or self.st[arg]["level"] >= d["max_level"]:
                return False
            if not self.spend(self.level_cost(arg)):
                return False
            self.st[arg]["level"] += 1
        elif kind == "hire":
            if not self.st[arg]["built"] or self.st[arg]["employees"] >= self.sdef(arg)["employees_max"]:
                return False
            if not self.spend(self.hire_cost(arg)):
                return False
            self.st[arg]["employees"] += 1
        elif kind == "proc":
            if not self.st[arg]["built"] or self.st[arg]["proc"] >= self.sdef(arg)["processing_max"]:
                return False
            if not self.spend(self.proc_cost(arg)):
                return False
            self.st[arg]["proc"] += 1
        elif kind == "galla_up":
            if arg >= len(self.gallas) or self.gallas[arg] >= self.e["galla"]["max_level"]:
                return False
            if not self.spend(self.galla_up_cost(arg)):
                return False
            self.gallas[arg] += 1
        elif kind == "galla_hire":
            if len(self.gallas) >= self.e["galla"]["max"]:
                return False
            if not self.spend(self.galla_hire_cost()):
                return False
            self.gallas.append(1)
            if self.on_galla_hired:
                self.on_galla_hired()
        elif kind == "build":
            if not self.can_build(arg) or not self.spend(self.build_cost(arg)):
                return False
            self.st[arg]["built"] = True
        else:
            raise ValueError(kind)
        self._refresh_abs()
        self._check()
        return True

    # ---- tasks (same rules as game.gd)
    def _tdef(self):
        return self.e["tasks"]

    def _start_tasks(self):
        out = []
        self.tasks = out
        for tid in self._tdef()["start"]:
            self.task_used.add(tid)
            out.append(self._new_task(tid, self._tdef()["defs"][tid]))
        while len(out) < self._tdef()["slots"]:
            out.append(self._next_task())
        return out

    def _new_task(self, tid, d):
        t = {"id": tid, "kind": d["kind"], "station": d.get("station", ""), "galla": d.get("galla", 0),
             "dish": d.get("dish", ""),
             "target": float(d.get("target", 1)), "reward": float(d.get("reward", 0.0)),
             "progress": 0.0, "done": False}
        if d.get("reward_minutes") is not None:
            g = self._tdef()["generators"]
            t["reward"] = max(g["reward_min"], nice(self.reward_rate() * float(d["reward_minutes"])))
        elif t["reward"] <= 0:
            g = self._tdef()["generators"]
            t["reward"] = max(g["reward_min"], nice(self.reward_rate() * g["reward_minutes"]))
        if t["kind"] in TASK_ABS:
            t["progress"] = self._abs_progress(t)
        return t

    def _abs_progress(self, t):
        s, k = t["station"], t["kind"]
        if k == "level":
            return float(self.st[s]["level"]) if self.st[s]["built"] else 0.0
        if k == "build":
            return 1.0 if self.st[s]["built"] else 0.0
        if k == "galla_level":
            return float(self.gallas[t["galla"]]) if t["galla"] < len(self.gallas) else 0.0
        if k == "hire":
            return float(self.st[s]["employees"]) if self.st[s]["built"] else 0.0
        if k == "processing":
            return float(self.st[s]["proc"]) if self.st[s]["built"] else 0.0
        return t["progress"]

    def _ready(self, t):
        k = t["kind"]
        if k == "build":
            return self.can_build(t["station"])
        if k == "galla_level":
            return t["galla"] < len(self.gallas)
        if k in ("level", "hire", "processing", "served"):
            return self.st[t["station"]]["built"]
        if k == "served_dish":   # the dish must be on the menu (station built, level >= from_level)
            return self.st[t["station"]]["built"] and self.dish_weight(t["station"], t["dish"]) > 0.0
        return True

    def _stale(self, t):
        if t["kind"] == "build":
            return self.st[t["station"]]["built"]
        if t["kind"] in TASK_ABS:
            return self._ready(t) and self._abs_progress(t) >= t["target"]
        return False

    def _next_task(self):
        active = {t["id"] for t in self.tasks}
        defs = self._tdef()["defs"]
        for tid in self._tdef()["sequence"]:
            if tid in self.task_used or tid in active or tid not in defs:
                continue
            t = self._new_task(tid, defs[tid])
            if self._stale(t):
                self.task_used.add(tid)
                self.task_log.append(("drop", tid))
                continue
            if self._ready(t):
                self.task_used.add(tid)
                self.task_log.append(("card", tid))
                return t
        t = self._generate()
        self.task_log.append(("card", f"{t['id']} ({t['kind']}{' ' + t['station'] if t['station'] else ''}"
                              f"{'.' + t['dish'] if t.get('dish') else ''} {t['target']:g})"))
        return t

    def _generate(self):
        g = self._tdef()["generators"]
        rot = g["rotation"] or ["earned"]
        for _ in range(len(rot)):
            kind = rot[self.task_gen % len(rot)]
            self.task_gen += 1
            t = self._gen(kind, g)
            if t:
                return t
        self.task_gen += 1
        return self._gen("earned", g)

    def _gen(self, kind, g):
        rnd = self.task_gen // max(1, len(g["rotation"]))
        d = {"kind": kind}
        built = self.built()
        if kind == "earned":
            d["target"] = nice(max(100.0, self.reward_rate() * g["earned_target_minutes"]))
        elif kind == "served":
            d["station"] = built[self.task_gen % len(built)]
            d["target"] = min(500, g["served_base"] + g["served_step"] * rnd)
        elif kind == "served_dish":
            # the most recently unlocked dish (beyond dish 1) of each built station, round-robin
            cands = [(s, self.menu(s)[self.dishes_unlocked(s) - 1]["key"]) for s in built if self.dishes_unlocked(s) > 1]
            if not cands:
                return None
            d["station"], d["dish"] = cands[self.task_gen % len(cands)]
            d["target"] = min(500, g["served_base"] + g["served_step"] * rnd)
        elif kind == "billed":
            d["target"] = min(1000, g["billed_base"] + g["billed_step"] * rnd)
        elif kind == "level":
            cands = [s for s in built if self.st[s]["level"] < self.sdef(s)["max_level"]]
            if not cands:
                return None
            best = min(cands, key=lambda s: self.st[s]["level"])
            step = max(1, g["level_step"])
            lvl = self.st[best]["level"]
            d["station"] = best
            d["target"] = min(((lvl + step // 2) // step + 1) * step, self.sdef(best)["max_level"])
            if d["target"] <= lvl:
                return None
        elif kind == "galla_level":
            cands = [i for i in range(len(self.gallas)) if self.gallas[i] < self.e["galla"]["max_level"]]
            if not cands:
                return None
            gi = min(cands, key=lambda i: self.gallas[i])
            d["galla"] = gi
            d["target"] = min(self.e["galla"]["max_level"], self.gallas[gi] + g["galla_level_step"])
        else:
            return None
        return self._new_task(f"gen_{self.task_gen}", d)

    def _task_add(self, kind, station, amount):
        for t in self.tasks:
            if t["done"] or t["kind"] != kind:
                continue
            if t["station"] and (not station or t["station"] != station):
                continue
            t["progress"] += amount

    def _task_add_dish(self, station, dish, amount):
        for t in self.tasks:
            if not t["done"] and t["kind"] == "served_dish" and t["station"] == station and t["dish"] == dish:
                t["progress"] += amount

    def _refresh_abs(self):
        for t in self.tasks:
            if not t["done"] and t["kind"] in TASK_ABS:
                t["progress"] = self._abs_progress(t)

    def _check(self):
        for t in self.tasks:
            if not t["done"] and t["progress"] >= t["target"] - 1e-4:
                t["done"] = True
                t["done_at"] = getattr(self, "now", 0.0)

    def served_event(self, sid):
        self.served += 1
        self._task_add("served", sid, 1)
        self._check()

    def claim(self, slot):
        t = self.tasks[slot]
        if not t["done"]:
            return 0.0
        self.tasks[slot] = self._next_task()
        self.chest_claims += 1
        self.claims += 1
        self.add_reward(t["reward"], "task")
        self._refresh_abs()
        self._check()
        return t["reward"]

    def chest_ready(self):
        return self.chest_claims >= self._tdef()["chest_claims"]

    def open_chest(self):
        cr = self._tdef()["chest_reward"]
        self.chest_claims -= self._tdef()["chest_claims"]
        self.sikke += cr["sikke"]
        cash = nice(max(self.reward_rate(), 30.0) * cr["cash_minutes"])
        self.add_reward(cash, "chest")
        return cash

    def ad_reward(self):
        a = self.e["ad_bubble"]
        if not self.ad_auto:
            return a["tutorial_reward"]
        return max(a["reward_min"], nice(self.reward_rate() * a["reward_minutes"]))


# =============================================================== queue world
class Trav:
    __slots__ = ("route", "idx", "walk", "locked", "state", "galla", "q_since", "visited")

    def __init__(self, route, walk):
        self.route = route
        self.idx = 0
        self.walk = walk
        self.locked = 0.0
        self.state = "walk"
        self.galla = -1
        self.q_since = 0.0
        self.visited = 0


class World:
    def __init__(self, game, rng):
        self.g = game
        self.rng = rng
        tr = game.e["traffic"]
        self.tr = tr
        self.t = 0.0
        self.hold = True
        self.paused = False
        self.trav = []
        self.st_queue = {s: [] for s in game.station_ids()}
        self.st_busy = {s: [] for s in game.station_ids()}   # [trav, left]
        self.gq = [[]]                                        # galla queues
        self.gcur = [None]
        self.gleft = [0.0]
        self.grestart = [0.0]
        self.next_vehicle = 0.0
        self.line_samples = []
        self.line_samples_pay = []
        self.waits = []
        self.sample_t = 0.0
        self.sales_log = []
        self.lost = 0
        game.on_galla_hired = self.rebalance

    def rebalance(self):
        """A new galla opens: travellers at the tail of the longest line walk
        over (ref: a new checkout gets its first queuer within ~1.5 s)."""
        self.sync_gallas()
        new = len(self.gq) - 1
        self.grestart[new] = self.tr.get("galla_switch_walk_s", 1.5)
        while True:
            src = max(range(new), key=lambda i: len(self.gq[i]))
            if len(self.gq[src]) - len(self.gq[new]) < 2:
                break
            tv = self.gq[src].pop()
            tv.galla = new
            self.gq[new].append(tv)

    def sync_gallas(self):
        while len(self.gq) < len(self.g.gallas):
            self.gq.append([])
            self.gcur.append(None)
            self.gleft.append(0.0)
            self.grestart.append(0.0)

    def spawn(self, delay_extra=0.0):
        route = self.g.built()
        tv = Trav(route, self.tr["walk_spawn_to_station_s"] + delay_extra)
        self.trav.append(tv)
        return tv

    def spawn_group(self):
        lo, hi = self.tr["group_size"]
        n = self.rng.randint(lo, hi)
        for k in range(n):
            self.spawn(0.6 * k)

    def inject(self, n, galla=0):
        for _ in range(n):
            tv = Trav([], 0.0)
            tv.locked = self.g.price("chai")
            tv.state = "gq"
            tv.galla = galla
            tv.q_since = self.t
            self.trav.append(tv)
            self.gq[galla].append(tv)

    def _arrive(self, tv):
        if tv.idx < len(tv.route):
            sid = tv.route[tv.idx]
            if not self.g.st[sid]["built"]:
                tv.idx += 1
                tv.walk = self.tr["walk_station_to_station_s"]
                return
            if len(self.st_queue[sid]) >= self.tr["max_station_queue"]:
                tv.idx += 1   # skip a station with a full line
                tv.walk = self.tr["walk_station_to_station_s"] if tv.idx < len(tv.route) else self.tr["walk_station_to_galla_s"]
                return
            tv.state = "sq"
            self.st_queue[sid].append(tv)
            return
        if tv.visited == 0:
            tv.state = "gone"
            self.lost += 1
            return
        best = min(range(len(self.gq)), key=lambda i: len(self.gq[i]) + (1 if self.gcur[i] else 0))
        tv.state = "gq"
        tv.galla = best
        tv.q_since = self.t
        self.gq[best].append(tv)

    def step(self, dt):
        g = self.g
        g.now = self.t
        self.sync_gallas()
        # spawner (traffic never pauses; hold_spawns stops it)
        if not self.hold:
            self.next_vehicle -= dt
            if self.next_vehicle <= 0.0:
                self.spawn_group()
                lo, hi = self.tr["group_size"]
                lam = self.tr["travellers_per_min"] / 60.0 / ((lo + hi) / 2.0)
                self.next_vehicle += self.rng.expovariate(lam)
        if not self.paused:
            for tv in self.trav:
                if tv.state == "walk":
                    tv.walk -= dt
                    if tv.walk <= 0.0:
                        self._arrive(tv)
            # stations
            for sid in g.built():
                busy = self.st_busy[sid]
                q = self.st_queue[sid]
                while q and len(busy) < g.st[sid]["employees"]:
                    busy.append([q.pop(0), g.processing(sid)])
                for item in list(busy):
                    item[1] -= dt
                    if item[1] <= 0.0:
                        busy.remove(item)
                        tv = item[0]
                        tv.locked += g.price(sid)
                        tv.visited += 1
                        g.served_event(sid)
                        tv.idx += 1
                        tv.state = "walk"
                        tv.walk = self.tr["walk_station_to_station_s"] if tv.idx < len(tv.route) else self.tr["walk_station_to_galla_s"]
            # gallas
            for i in range(len(self.gq)):
                if self.gcur[i] is None:
                    self.grestart[i] -= dt
                    if self.grestart[i] <= 0.0 and self.gq[i]:
                        tv = self.gq[i].pop(0)
                        self.waits.append(self.t - tv.q_since)
                        self.gcur[i] = tv
                        self.gleft[i] = g.galla_service(i)
                if self.gcur[i] is not None:
                    self.gleft[i] -= dt
                    if self.gleft[i] <= 0.0:
                        tv = self.gcur[i]
                        paid = g.add_sale(tv.locked)
                        self.sales_log.append((self.t, paid, i))
                        tv.state = "gone"
                        self.gcur[i] = None
                        self.grestart[i] = g.e["galla"]["restart_delay"]
            self.trav = [tv for tv in self.trav if tv.state != "gone"]
        self.sample_t += dt
        if self.sample_t >= 0.5:
            self.sample_t = 0.0
            self.line_samples.append(sum(len(q) for q in self.gq) / len(self.gq))
            self.line_samples_pay.append(sum(len(q) + (1 if c else 0) for q, c in zip(self.gq, self.gcur)) / len(self.gq))
        self.t += dt


# =============================================================== part A
def run_reference(eco, seed, ads=True):
    rng = random.Random(seed)
    g = Game(eco)
    w = World(g, rng)
    first = None
    actions = list(REF_ACTIONS)
    curve = {}
    rates = {}
    ref_ts = sorted({t for t, _ in REF_CURVE} | {t for t, _ in REF_RATE} | {80.0, 116.0})
    claim_pending = None
    claim_at = None
    serve_done_at = None
    ad_visible = False
    log = []
    while w.t < 162.0 - 1e-9:
        t = w.t
        w.paused = any(a <= t < b for a, b in PAUSES)
        if first is None and t >= FIRST_TRAVELLER_SPAWN:
            first = w.spawn()
            first.walk = 8.25
        while actions and actions[0][0] <= t + 1e-9:
            _, kind, arg = actions.pop(0)
            if kind == "transfer":
                w.hold = False
                w.next_vehicle = 0.0
            elif kind == "inject":
                w.inject(int(eco["traffic"].get("tutorial_inject", 5)))
            elif kind == "grant":
                g.cash = max(g.cash, arg)
            elif kind == "claim":
                claim_pending = arg
            elif kind == "ad_show":
                ad_visible = True
            elif kind == "ad_free":
                if ad_visible and ads:
                    g.add_reward(g.ad_reward())
                    ad_visible = False
            else:
                ok = g.buy(kind, arg)
                if not ok:
                    log.append(f"{t:6.2f} could not {kind} {arg} (cash {g.cash:.2f})")
        if claim_pending is not None and g.tasks[claim_pending]["done"]:
            claim_at = t
            g.claim(claim_pending)
            claim_pending = None
        if serve_done_at is None:
            for tk in g.tasks:
                if tk["id"] == "chai_serve20" and tk["done"]:
                    serve_done_at = tk.get("done_at", t)
        for rt in ref_ts:
            if rt not in curve and t >= rt - 1e-9:
                curve[rt] = g.cash
                rates[rt] = g.rate()
                if rt in (80.0, 116.0):
                    curve[("served", rt)] = g.served
        w.step(DT)
    first_sale = w.sales_log[0][0] if w.sales_log else None
    post = [s for s in w.sales_log if 62.0 <= s[0] <= 160.6]
    return {
        "game": g, "world": w, "curve": curve, "rates": rates, "first_sale": first_sale,
        "sales_post": len(post), "claim_at": claim_at, "serve_done_at": serve_done_at,
        "avg_line": statistics.mean(w.line_samples[int(70 / 0.5):]) if len(w.line_samples) > 150 else 0.0,
        "avg_line_pay": statistics.mean(w.line_samples_pay[int(70 / 0.5):]) if len(w.line_samples_pay) > 150 else 0.0,
        "avg_wait": statistics.mean(w.waits[6:]) if len(w.waits) > 7 else 0.0,
        "log": log,
    }


def pct(vals, p):
    s = sorted(vals)
    return s[min(len(s) - 1, max(0, int(round(p * (len(s) - 1)))))]


def part_a(eco, seeds, ads):
    runs = [run_reference(eco, s, ads) for s in range(seeds)]
    print("=" * 78)
    print(f"PART A - reference replay, first 162 s ({seeds} seeds). Money in REF units"
          f" (x10 on screen).")
    print("=" * 78)
    print(f"{'t':>6} | {'ref':>7} | {'sim p50':>7} | {'p10':>7} | {'p90':>7} | {'p50-ref':>7}")
    print("-" * 56)
    errs = []
    for t, ref in REF_CURVE:
        vals = [r["curve"][t] for r in runs]
        med = statistics.median(vals)
        note = ""
        if t in COUNTUP_ROWS:
            note = "  (ref HUD still counting up the claim; Game credits at the tap)"
        else:
            errs.append(abs(med - ref))
        print(f"{t:6.1f} | {ref:7.2f} | {med:7.2f} | {pct(vals, .1):7.2f} | {pct(vals, .9):7.2f} | {med - ref:+7.2f}{note}")
    print("-" * 56)
    print(f"mean |p50 - ref| = {statistics.mean(errs):.2f}   max = {max(errs):.2f}   (one sale = 1.63-1.77)")
    print()
    print("HUD /min (ref lags one level on Level Up; ours is computed after the purchase):")
    for t, ref in REF_RATE:
        vals = [r["rates"][t] for r in runs]
        print(f"  t={t:5.1f}  ref {ref:3d}/min   sim {round(statistics.median(vals)):3d}/min")
    fs = [r["first_sale"] for r in runs]
    sp = [r["sales_post"] for r in runs]
    sd = [r["serve_done_at"] for r in runs if r["serve_done_at"]]
    s80 = [r["curve"][("served", 80.0)] for r in runs]
    s116 = [r["curve"][("served", 116.0)] for r in runs]
    ca = [r["claim_at"] for r in runs if r["claim_at"]]
    al = [r["avg_line"] for r in runs]
    alp = [r["avg_line_pay"] for r in runs]
    aw = [r["avg_wait"] for r in runs]
    built = sum(1 for r in runs if r["game"].st["tandoor"]["built"])
    print()
    print(f"first sale              ref 36.70 s     sim {statistics.median(fs):6.2f} s")
    print(f"sales 62-160.5 s        ref 32          sim p50 {statistics.median(sp):.0f} (p10 {pct(sp, .1)}, p90 {pct(sp, .9)})"
          f" = {statistics.median(sp) / (98.0 / 60):.1f}/min")
    print(f"'serve 20' progress     ref 7 @80 s, 18 @116 s   sim p50 {statistics.median(s80):.0f} @80 s, {statistics.median(s116):.0f} @116 s")
    print(f"'serve 20' complete     ref ~128.7 s    sim p50 {statistics.median(sd):6.1f} s (p10 {pct(sd, .1):.1f}, p90 {pct(sd, .9):.1f})")
    print(f"claim (+48)             ref 138.9 s     sim p50 {statistics.median(ca):6.1f} s ({len(ca)}/{seeds} runs claimed by 162 s)")
    print(f"avg galla line (70+ s)  ref 1.5-2       sim p50 {statistics.median(al):.2f} waiting,"
          f" {statistics.median(alp):.2f} incl. the payer (per galla)")
    print(f"avg galla wait in line  ref '5 s'       sim p50 {statistics.median(aw):.1f} s (time queued before billing)")
    print(f"tandoor built @160.5 s  ref yes         sim {built}/{seeds} runs")
    fails = [ln for r in runs for ln in r["log"]]
    if fails:
        print(f"purchase failures: {len(fails)} (first: {fails[0]})")
    return runs


# =============================================================== part B - seated dhaba
# Free play after the tutorial, modelled like the game since the seated-dhaba,
# WHOLE ORDER and ARRIVAL RAMP addenda (docs/v3-architecture.md) and the menu
# expansion (docs/v3-menu-expansion.md):
#   - arrivals/min = the ramp: clamp(ramp_capacity_k x min(waiters, seats,
#     stations, gallas), ramp_min_tpm, ramp_max_tpm), eased up over ramp_ease_s
#     and down over ramp_ease_down_s (steady state: no backlog damping);
#   - the ORDER RULE: one drink (chai / lassi) + at most one dish (roti /
#     egg bhurji / dal makhani), picked by economy "orders" + station
#     "menu_group" / "order_weight"; a station's demand share = group chance x
#     its weight / the summed weights of the built stations of its group;
#   - stations count at ramp_station_k of employees x 60 / processing, divided
#     by their demand share (a station half the travellers order from can feed
#     twice as many arrivals);
#   - waiters: n x 60 / the expected WHOLE-ORDER trip, worked out from the
#     Layout3 positions of the passes and the table sets (LAYOUT below) with
#     the Sim's walk estimate, calibrated so chai + roti with tables 0-1 is the
#     measured ~5.5 s loop;
#   - money = arrivals x the expected bill (sum over the order mix of share x
#     price), tasks / chest / wall-ad rewards as in game.gd.
# Deterministic (expected values), so the timeline is reproducible.

# ---- Layout3 mirror (menu expansion layout; metres, (x, z))
LAYOUT = {
    "aisle_z": 4.05,
    "gate": (9.05, 3.6, 4.5),          # side gate in the x = 9 wall: x, z0, z1
    "pickup": {                        # pass slot 0 pickup point per station
        "chai": (2.6, 2.59), "lassi": (2.6, 4.2), "tandoor": (7.09, 3.2),
        "kadai": (10.4, 3.2),
    },
    "tables": [(3.95, 2.0), (6.9, 6.1), (11.0, 6.1), (13.45, 6.1), (13.6, 2.0)],
    "strip_x": 1.12, "serve_z": 0.3,
    "home": (2.45, 3.55),
}
# C6.1 the AC family hall: = Layout3.HALL_TABLES (frozen, plan 2.3), (x, z). In the
# family layout table indices 2 to 4 are the hall sets and the courtyard sets
# follow (indices 5 to 7): family_tables() below.
HALL_TABLES = [(17.25, 2.1), (17.25, 6.1), (20.15, 2.1)]


def family_tables():
    """Table order of the family layout: the store's first two, the hall, the rest."""
    t = LAYOUT["tables"]
    return list(t[:2]) + list(HALL_TABLES) + list(t[2:])


# The bot spends at most this share of its spendable cash on one signboard level
# (as on any other staff purchase; a bot policy, not a game rule).
SIGN_SPEND_FRAC = 0.5
# The game's own tutorial (main3 --fresh --auto, the seated dhaba) ends with
# this much cash (ref units): 1.77, 3.54 or 5.31 by seed (a chai sale either
# side), 3.54 the median over 16 seeds, against ~7.9 at the end of the
# reference replay above (part A replays the video's walk-up queue). All three
# give the bot the same first minutes (no early table / waiter cascade).
# Part B starts from the game's figure: with the replay's cash the bot's first
# claims cascade (table -> galla -> waiter cards in 3 s) and its whole timeline
# runs 1.5-9 min early against the game (QA round 1, 2026-10-20). Levels,
# gallas and tasks match the game already (chai L12, tandoor L1, gallas
# [3, 2], earn_100 done).
INGAME_TUTORIAL_END_CASH = 3.54
# A traveller's bill is priced when the items are cooked (station_node.gd
# _complete) and paid at the galla: seconds after the traveller appears,
# measured in-game over 40 min of free play (QA round 1 bot, 4 seeds, ~700
# paying travellers each: priced 20.6-22.2 s, paid 36.7-38.6 s, means).
PRICE_LAG_S = 21.5
PAY_LAG_S = 38.0
# Realized arrivals / ramp target. The ramp target is a ceiling: headless runs
# land below it (architecture WHOLE ORDER addendum: 3 waiters / 5 tables chai
# only 17.1/min vs 19.5; 1 waiter + tandoor 9.5-9.8 vs 10.9), so part B pays out
# REALIZED x the target. The rule check (--matrix) compares targets. QA round 1
# bot runs: arrivals ran 0.82-0.95 x the target (0.82 while the ramp eases up
# after the first hires, ~0.92 at the 19.5 cap); with the price / pay lags
# below, 0.87 reproduced the game's affordable times (sales lose the
# travellers who give up and the ones still inside at a level-up).
# Core and feel (build plan 3.3): nobody gives up any more (C2.1), so W4
# measured it in-game (G-realized: the road-cap buy set, --window=600, seeds
# 1-4, [window] arrivals / ramp): 0.935 at gate 1, 0.924 on the wave-4 tree
# (signboard 0: 0.908 0.949 0.928 0.913; signboard 4: 0.957 1.038 0.905 0.909,
# the 1.038 read against a ramp damped by a backlog at the window's end).
# Moved > 0.02, so REALIZED is 0.92 from 2 Nov 2026 (was 0.87).
REALIZED = 0.92
MIN_BILL_GAIN = 0.15             # a build must raise the expected bill by >= 15 % (part B check)
MEASURED_LOOP_S = 5.5            # chai + roti, tables 0-1, base_speed_ratio 1.65 (architecture addendum)
PICK_S, SERVE_S, STAGGER_S = 0.22, 0.34, 0.12
TRAV_SPEED = 1.8 * 1.05           # Traveller.WALK_HEIGHTS_PER_S x DEFAULT_HEIGHT (m/s)


def _est(a, b):
    """Sim._walk_est: halfway between the straight line and the aisle route."""
    az = LAYOUT["aisle_z"]
    d_aisle = abs(a[1] - az) + abs(a[0] - b[0]) + abs(b[1] - az)
    return 0.5 * (d_aisle + math.hypot(b[0] - a[0], b[1] - a[1]))


def walk(a, b):
    """Walk length a -> b; crossing the x = 9 wall goes through the side gate."""
    gx, gz0, gz1 = LAYOUT["gate"]
    if (a[0] - 9.1) * (b[0] - 9.1) < 0.0:
        g = (gx, min(gz1, max(gz0, 0.5 * (a[1] + b[1]))))
        return _est(a, g) + _est(g, b)
    return _est(a, b)


def serve_stands(t, layout=None):
    tx, tz = (layout if layout is not None else LAYOUT["tables"])[t]
    sx, sz = LAYOUT["strip_x"], LAYOUT["serve_z"]
    return [(tx - sx, tz - sz), (tx + sx, tz - sz), (tx - sx, tz + sz), (tx + sx, tz + sz)]


_TRIP_M = {}


def raw_trip_m(ids, tables, layout=None):
    """Expected metres a busy waiter walks for one whole order of `ids`
    (start = a random built table's serve stand, best pass order). Cached.
    `layout` = the table positions in purchase order (default: the roadside
    LAYOUT["tables"]; the family layout passes family_tables())."""
    lay = tuple(layout) if layout is not None else tuple(LAYOUT["tables"])
    key = (tuple(ids), tables, lay)
    if key not in _TRIP_M:
        _TRIP_M[key] = _raw_trip_m(list(ids), tables, lay)
    return _TRIP_M[key]


def _raw_trip_m(ids, tables, layout=None):
    stands = [s for t in range(tables) for s in serve_stands(t, layout)]
    tot = 0.0
    for start in stands:
        for end in stands:
            best = None
            orders = [ids] if len(ids) < 2 else [ids, ids[::-1]]
            for seq in orders:
                d, p = 0.0, start
                for sid in seq:
                    q = LAYOUT["pickup"][sid]
                    d += walk(p, q)
                    p = q
                d += walk(p, end)
                best = d if best is None or d < best else best
            tot += best
    return tot / (len(stands) ** 2)


_TRIP_CAL = {}


def trip_cal(eco):
    """Metres -> seconds factor so chai + roti (tables 0-1, waiter L1) = MEASURED_LOOP_S."""
    if "k" not in _TRIP_CAL:
        speed = TRAV_SPEED * eco["waiters"]["base_speed_ratio"]
        t = raw_trip_m(["chai", "tandoor"], 2) / speed + 2 * PICK_S + SERVE_S + STAGGER_S
        _TRIP_CAL["k"] = MEASURED_LOOP_S / t
    return _TRIP_CAL["k"]


class SeatedGame(Game):
    """Game mirror + waiters, table sets, the order rule and every task kind."""

    def __init__(self, eco):
        self.waiters = [1] * max(1, int(eco["waiters"]["start"]))
        self.tables = int(eco["seating"]["tables_start"])
        self.seated = 0
        # C3.4 trays and C5.3 signboard switches (--no-trays, --no-signboard)
        self.trays_on = bool(eco["waiters"].get("tray_levels"))
        self.sign_on = bool(eco.get("signboard"))
        # DHABA GROWTH (--growth): 0 cart, 1 shack, 2 dhaba (game.gd _stage); the
        # dhaba unless part B starts in the shack
        self.grow = 2
        super().__init__(eco)

    def grow_def(self):
        """growth.stages[grow] before the dhaba ({} on the dhaba)."""
        arr = self.e.get("growth", {}).get("stages", [])
        return arr[self.grow] if self.grow < 2 and self.grow < len(arr) else {}

    def _grow_cap(self, key, m):
        d = self.grow_def()
        return min(m, int(d[key])) if key in d else m

    # ---- CORE AND FEEL: layout variant, caps, trays, signboard (game.gd W1-CORE)
    def variant(self):
        """game.gd layout_variant(): "family" once renovated."""
        return "family" if self.stage >= 1 else "roadside"

    def waiters_max(self):
        w = self.e["waiters"]
        m = int(w.get("max_family", w["max"])) if self.variant() == "family" else int(w["max"])
        return self._grow_cap("waiters_max", m)

    def tables_max(self):
        s = self.e["seating"]
        m = int(s.get("tables_max_family", s["tables_max"])) if self.variant() == "family" else int(s["tables_max"])
        return self._grow_cap("tables_max", m)

    def tables_start(self):
        s = self.e["seating"]
        return int(s.get("tables_start_family", s["tables_start"])) if self.variant() == "family" else int(s["tables_start"])

    def layout_tables(self):
        return family_tables() if self.variant() == "family" else LAYOUT["tables"]

    def tray_orders(self, i):
        """game.gd waiter_tray_orders(i): 1 + the tray levels waiter i has reached."""
        if not self.trays_on:
            return 1
        return 1 + sum(1 for lv in self.e["waiters"].get("tray_levels", []) if self.waiters[i] >= int(lv))

    def tray_factor(self):
        """Mean over waiters of 1 + tray_batch_est x (orders - 1) (waiter capacity factor)."""
        if not self.trays_on:
            return 1.0
        b = float(self.e["waiters"].get("tray_batch_est", 0.0))
        return sum(1.0 + b * (self.tray_orders(i) - 1) for i in range(len(self.waiters))) / len(self.waiters)

    def sdef_sign(self):
        return self.e.get("signboard", {})

    def sign_max(self):
        d = self.sdef_sign()
        if not self.sign_on or not d:
            return 0
        return int(d.get("max_levels_family", d.get("max_levels", 0))) if self.variant() == "family" else int(d.get("max_levels", 0))

    def sign_unlocked(self):
        req = str(self.sdef_sign().get("requires", ""))
        return req == "" or (req in self.st and self.st[req]["built"])

    def sign_cost(self):
        d = self.sdef_sign()
        return float(d.get("cost_base", 0.0)) * float(d.get("cost_growth", 1.0)) ** self.sign * self.dial()

    def sign_bonus(self, extra=0):
        """game.gd signboard_bonus_tpm(): level x tpm_per_level (travellers/min on the cap)."""
        return float(self.sdef_sign().get("tpm_per_level", 0.0)) * (self.sign + extra)

    # ---- order rule
    def group_of(self, sid):
        return self.sdef(sid).get("menu_group", "drink" if sid == "chai" else "dish")

    def shares(self, built=None, plan_tandoor=False):
        """{station: share of travellers ordering it} for the built stations."""
        built = list(built if built is not None else self.built())
        if plan_tandoor and "tandoor" not in built:
            built.append("tandoor")
        o = self.e.get("orders", {})
        groups = o.get("groups", ["drink", "dish"])
        chance = o.get("group_chance", {})
        out = {}
        for gname in groups:
            ids = [s for s in self.station_ids() if s in built and self.group_of(s) == gname]
            if not ids:
                continue
            c = float(chance.get(gname, 1.0))
            wsum = sum(float(self.sdef(s).get("order_weight", 1.0)) for s in ids)
            for s in ids:
                out[s] = c * float(self.sdef(s).get("order_weight", 1.0)) / wsum
        return out

    def order_mix(self, built=None):
        """[(prob, [ids in ticket order])] over the whole order rule."""
        built = list(built if built is not None else self.built())
        o = self.e.get("orders", {})
        mix = [(1.0, [])]
        for gname in o.get("groups", ["drink", "dish"]):
            ids = [s for s in self.station_ids() if s in built and self.group_of(s) == gname]
            if not ids:
                continue
            c = float(o.get("group_chance", {}).get(gname, 1.0))
            wsum = sum(float(self.sdef(s).get("order_weight", 1.0)) for s in ids)
            nxt = []
            for p, seq in mix:
                if c < 1.0:
                    nxt.append((p * (1.0 - c), seq))
                for s in ids:
                    nxt.append((p * c * float(self.sdef(s).get("order_weight", 1.0)) / wsum, seq + [s]))
            mix = nxt
        return [(p, seq) for p, seq in mix if seq]

    def station_income(self, sid):
        """game.gd station_income_per_min (menu expansion): price x capacity x
        income mult x the station's demand share, so the HUD "/min" (and every
        reward sized from it: generated KAAM rewards and earned targets, chest,
        wall ad) follows what the travellers actually order. Shares are 1.0
        while each group has one built station (chai, chai + roti), so the
        tutorial and today's free play read exactly as before."""
        if not self.st[sid]["built"]:
            return 0.0
        return self.price(sid) * self.capacity(sid) * self.income_mult() * self.shares().get(sid, 0.0)

    def basket(self, built=None):
        sh = self.shares(built)
        return sum(sh[s] * self.price(s) for s in sh) * self.income_mult()

    # ---- waiters / tables
    def waiter_speed_mult(self, i):
        return self.e["waiters"]["speed_step"] ** (self.waiters[i] - 1)

    def waiter_up_cost(self, i):
        w = self.e["waiters"]
        return snap(w["upgrade_cost_base"] * w["upgrade_cost_growth"] ** (self.waiters[i] - 1) * self.dial())

    def waiter_hire_cost(self):
        w = self.e["waiters"]
        k = len(self.waiters) - int(w["start"])
        c = w["hire_costs"]
        dial = self.dial() if k >= int(self.ddef().get("exempt_waiter_hires", 1)) else 1.0
        return snap(c[k] * dial) if k < len(c) else snap(c[-1] * w["hire_cost_growth"] ** (k - len(c) + 1) * dial)

    def table_cost(self):
        s = self.e["seating"]
        k = self.tables - self.tables_start()   # the family layout counts from tables_start_family
        c = s["table_costs"]
        dial = self.dial() if k >= int(self.ddef().get("exempt_tables", 1)) else 1.0
        return snap(c[k] * dial) if k < len(c) else snap(c[-1] * s["table_cost_growth"] ** (k - len(c) + 1) * dial)

    def can_build(self, sid):
        if not super().can_build(sid):
            return False
        if int(self.e.get("growth", {}).get("station_stage", {}).get(sid, 0)) > self.grow:
            return False
        return len(self.waiters) >= int(self.sdef(sid).get("requires_waiters", 0))

    def dhaba_build(self):
        """(cost, dur_s, requires met) of growth.builds.dhaba (game.gd growth_state)."""
        d = self.e.get("growth", {}).get("builds", {}).get("dhaba", {})
        req = d.get("requires", {})
        ok = True
        if "built" in req and not self.st[req["built"]]["built"]:
            ok = False
        if "tables" in req and self.tables < int(req["tables"]):
            ok = False
        return snap(float(d.get("cost", 0.0)) * self.dial()), float(d.get("dur_s", 0.0)), ok

    def buy(self, kind, arg=None):
        if kind == "waiter_hire":
            if len(self.waiters) >= self.waiters_max() or not self.spend(self.waiter_hire_cost()):
                return False
            self.waiters.append(1)
        elif kind == "waiter_up":
            if self.waiters[arg] >= self.e["waiters"]["max_level"] or not self.spend(self.waiter_up_cost(arg)):
                return False
            self.waiters[arg] += 1
        elif kind == "table":
            if self.tables >= self.tables_max() or not self.spend(self.table_cost()):
                return False
            self.tables += 1
        else:
            return super().buy(kind, arg)
        self._refresh_abs()
        self._check()
        return True

    # ---- tasks: every kind game.gd knows
    def _abs_progress(self, t):
        k = t["kind"]
        if k == "tables":
            return float(self.tables)
        if k == "waiters":
            return float(len(self.waiters))
        if k == "waiter_level":
            wi = t.get("waiter", 0)
            return float(self.waiters[wi]) if wi < len(self.waiters) else 0.0
        return super()._abs_progress(t)

    def _new_task(self, tid, d):
        t = super()._new_task(tid, d)
        t["waiter"] = d.get("waiter", 0)
        if t["kind"] in ("tables", "waiters", "waiter_level"):
            t["progress"] = self._abs_progress(t)
        return t

    def _ready(self, t):
        k = t["kind"]
        if k == "tables":
            return t["target"] <= self.tables_max()
        if k == "waiters":
            return t["target"] <= self.waiters_max()
        if k == "waiter_level":
            return t.get("waiter", 0) < len(self.waiters)
        return super()._ready(t)

    def _stale(self, t):
        if t["kind"] in ("tables", "waiters", "waiter_level"):
            return self._ready(t) and self._abs_progress(t) >= t["target"]
        return super()._stale(t)

    def _gen(self, kind, g):
        rnd = self.task_gen // max(1, len(g["rotation"]))
        if kind == "seated":
            return self._new_task(f"gen_{self.task_gen}", {"kind": "seated", "target": min(1000, g["seated_base"] + g["seated_step"] * rnd)})
        if kind == "tables":
            if self.tables >= self.tables_max():
                return None
            return self._new_task(f"gen_{self.task_gen}", {"kind": "tables", "target": self.tables + 1})
        if kind == "waiters":
            if len(self.waiters) >= self.waiters_max():
                return None
            return self._new_task(f"gen_{self.task_gen}", {"kind": "waiters", "target": len(self.waiters) + 1})
        if kind == "waiter_level":
            wk = min(range(len(self.waiters)), key=lambda i: self.waiters[i])
            t = self._new_task(f"gen_{self.task_gen}", {"kind": "waiter_level", "waiter": wk,
                                                       "target": self.waiters[wk] + g["waiter_level_step"]})
            # C3.4: the card aims at the next tray level when it is within 2 x waiter_level_step
            if self.trays_on:
                lvl = self.waiters[wk]
                nxt = [int(lv) for lv in self.e["waiters"].get("tray_levels", []) if int(lv) > lvl]
                if nxt and nxt[0] - lvl <= 2 * g["waiter_level_step"]:
                    t["target"] = nxt[0]
            return t
        return super()._gen(kind, g)

    def _refresh_abs(self):
        for t in self.tasks:
            if not t["done"] and t["kind"] in TASK_ABS + ("tables", "waiters", "waiter_level"):
                t["progress"] = self._abs_progress(t)


def capacity(g, built=None, plan_tandoor=False, sign_extra=0):
    """Mirror of the (menu-expansion) Sim.capacity_estimate(), steady state:
    {seats, waiters, stations, gallas, min, target, trip, shares, bind}.
    Core and feel: the waiters' capacity x the tray factor (C3.4), the ramp cap
    ramp_max_tpm + the signboard bonus (C5.3; `sign_extra` = what-if levels),
    the trips over the table positions of the current layout (C6.1)."""
    e = g.e
    tr = e["traffic"]
    built = list(built if built is not None else g.built())
    if plan_tandoor and "tandoor" not in built:
        built.append("tandoor")
    sh = g.shares(built)
    mix = g.order_mix(built)
    k = trip_cal(e)
    speed = TRAV_SPEED * e["waiters"]["base_speed_ratio"]
    lay = g.layout_tables() if hasattr(g, "layout_tables") else None
    trip = 0.0
    for p, seq in mix:
        n = len(seq)
        t = raw_trip_m(seq, g.tables, lay) / speed + n * PICK_S + SERVE_S + STAGGER_S * (n - 1)
        trip += p * t * k
    sp = sum(g.waiter_speed_mult(i) for i in range(len(g.waiters))) / len(g.waiters)
    trip_eff = trip / sp
    w_cap = len(g.waiters) * 60.0 / max(0.5, trip_eff)
    if hasattr(g, "tray_factor"):
        w_cap *= g.tray_factor()
    st_k = tr.get("ramp_station_k", 0.9)
    st_cap = min(g.capacity(s) * st_k / max(1e-6, sh[s]) for s in sh)
    proc = sum(p * max(g.processing(s) for s in seq) for p, seq in mix)
    food = proc + tr.get("ramp_food_trip_k", 0.6) * trip_eff
    seat_time = tr.get("ramp_seat_overhead_s", 1.5) + food + e["seating"]["eat_s"]
    s_cap = g.tables * e["seating"]["seats_per_table"] * 60.0 / max(1.0, seat_time)
    g_cap = sum(60.0 / (g.galla_service(i) + e["galla"]["restart_delay"]) for i in range(len(g.gallas)))
    caps = {"waiters": w_cap, "seats": s_cap, "stations": st_cap, "gallas": g_cap}
    m = min(caps.values())
    hi = tr["ramp_max_tpm"] + (g.sign_bonus(sign_extra) if hasattr(g, "sign_bonus") else 0.0)
    target = min(hi, max(tr["ramp_min_tpm"], tr["ramp_capacity_k"] * m))
    bind = min(caps, key=caps.get) if tr["ramp_capacity_k"] * m < hi else "max"
    if bind == "stations":
        bind = "station:" + min(sh, key=lambda s: g.capacity(s) / max(1e-6, sh[s]))
    return dict(caps, min=m, target=target, trip=trip_eff, shares=sh, bind=bind, food=food, cap=hi)


def utilisation(g, lam):
    """Busy share of each built station's cooks and of the waiters at lam travellers/min."""
    c = capacity(g)
    out = {s: lam * c["shares"][s] / g.capacity(s) for s in c["shares"]}
    tf = g.tray_factor() if hasattr(g, "tray_factor") else 1.0
    out["waiters"] = lam * c["trip"] / (60.0 * len(g.waiters) * tf)
    return out


NEW_STATIONS = ("lassi", "kadai")
TUT_END_WAITERS = [2]
TUT_END_TABLES = [3]


def offline_offer(eco, basis_per_min, away_s, rule):
    """(base, x2 or None, popup?) of the offline popup for `away_s` seconds away.
    rule "v032": game.gd 0.3.2 (0.5 x real, 2 h cap, >= 60 s, x2 always).
    rule "eco": the JSON's offline block incl. the proposal keys (min_away_s,
    rate, cap_hours, popup_min_minutes, ad_min_away_s)."""
    if rule == "v032":
        od = {"rate": 0.5, "cap_hours": 2.0, "min_away_s": 60.0, "ad_mult": 2.0}
    else:
        od = eco.get("offline", {})
    if away_s < float(od.get("min_away_s", 60.0)):
        return 0.0, None, False
    cap = float(od.get("cap_hours", 2.0)) * 3600.0
    base = basis_per_min * float(od.get("rate", 0.5)) * min(away_s, cap) / 60.0
    vip_free = basis_per_min  # basis already includes VIP when on
    popup = base >= float(od.get("popup_min_minutes", 0.0)) * vip_free
    x2 = base * float(od.get("ad_mult", 2.0)) if away_s >= float(od.get("ad_min_away_s", 0.0)) else None
    return base, x2, popup


def print_round2(eco, m):
    g = m.g
    print()
    print("ROUND 2 CHECKPOINTS (display rupees; t = minutes after the tutorial; real = takings/min actually paid;"
          " HUD = ramp target x bill; cap = 0.3.2 capacity rate):")
    print(f"{'t':>5} | {'cash':>9} | {'real/min':>9} | {'HUD/min':>9} | {'cap/min':>9} | {'sales cum':>10} | {'rewards cum':>11} |"
          f" {'ads':>9} {'chest':>9} {'tasks':>9} | {'earned cum':>10} | {'bill':>8} | levels")
    for c in m.checks:
        r = c["rew"]
        rw = sum(r.values())
        lv = " ".join(f"{k[:4]}{v}" for k, v in c["levels"].items())
        if c.get("stage", 0) > 0 or c.get("sign", 0) > 0:
            lv = (f"s{c['stage']} " if c.get("stage", 0) > 0 else "") + lv + f" sign{c.get('sign', 0)}"
        print(f"{c['min']:5.1f} | {rupees(c['cash']):>9} | {rupees(c['real']):>9} | {rupees(c['hud']):>9} | {rupees(c['cap']):>9} |"
              f" {rupees(c['sales']):>10} | {rupees(rw):>11} | {rupees(r.get('ad', 0)):>9} {rupees(r.get('chest', 0)):>9}"
              f" {rupees(r.get('task', 0)):>9} | {rupees(c['sales'] + rw):>10} | {rupees(c['bill']):>8} | {lv} W{c['W']} T{c['T']} G{c['G']}")
    print()
    print("Prices at the checkpoints (station mean bill per item, display rupees):")
    for c in m.checks:
        if c["min"] in (0.5, 5, 10, 20, 30, 45, 60, 90):
            print(f"  {c['min']:5.1f} min: " + ", ".join(f"{k} L{c['levels'][k]} {rupees(v)}" for k, v in c["prices"].items()))
    print()
    print("OFFLINE OFFERS on return (base / x2 with ad; '-' = no popup):")
    aways = [60, 300, 900, 1800, 7200]
    for rule in ("v032", "eco"):
        print(f"  rule {rule}:")
        for c in m.checks:
            if c["min"] not in (5, 10, 20, 30, 60):
                continue
            cells = []
            for a in aways:
                b, x2, pop = offline_offer(eco, c["off_basis"], a, rule)
                if b <= 0 or not pop:
                    cells.append(f"{a // 60:>3}m: -")
                else:
                    cells.append(f"{a // 60:>3}m: {rupees(b)}" + (f" / {rupees(x2)}" if x2 else " / (no x2)"))
            print(f"    at {c['min']:4.1f} min (basis {rupees(c['off_basis'])}/min, cash {rupees(c['cash'])}): " + " | ".join(cells))
    print()
    print("UNLOCKS (min:sec after the tutorial):")
    for sid in ("lassi", "kadai"):
        print(f"  {sid:<8} affordable {fmt_t(m.first_afford[sid]) if sid in m.first_afford else '   -'}  built {fmt_t(m.built_at[sid]) if sid in m.built_at else '   -'}")
    for k, t in sorted(m.unlock_t.items(), key=lambda kv: kv[1]):
        print(f"  {k:<28} {fmt_t(t)}")
    summ = {"afford": {k: round(v, 1) for k, v in m.first_afford.items()},
            "unlock": {k: round(v, 1) for k, v in m.unlock_t.items()},
            "checks": [{"min": c["min"], "cash": round(c["cash"] * DISPLAY_SCALE[0]), "real": round(c["real"] * DISPLAY_SCALE[0]),
                        "hud": round(c["hud"] * DISPLAY_SCALE[0]),
                        "sales": round(c["sales"] * DISPLAY_SCALE[0]), "rew": round(sum(c["rew"].values()) * DISPLAY_SCALE[0]),
                        "ads": round(c["rew"].get("ad", 0) * DISPLAY_SCALE[0]), "bill": round(c["bill"] * DISPLAY_SCALE[0], 1),
                        "off": round(c["off_basis"] * DISPLAY_SCALE[0]),
                        "prices": {k: round(v * DISPLAY_SCALE[0], 1) for k, v in c["prices"].items()},
                        "levels": c["levels"]} for c in m.checks]}
    summ["promo"] = promo_summary(m)
    print("SUMMARY " + json.dumps(summ, ensure_ascii=False))


PROMO_MARKS = [("unlock0", "renovation unlocks (all 16 dishes)"), ("promo0", "renovated (Family Dhaba)"),
               ("end1", "family run: every counter L100 again"), ("unlock1", "NH 48 unlocks"),
               ("promo1", "moved to NH 48"), ("end2", "NH 48: all 16 dishes")]


def promo_summary(m):
    """The "promo" key of SUMMARY: marks in seconds after the tutorial, the signboard
    buys, the bind shares per stage, the waiter levels at each promotion."""
    marks = {k: round(v, 1) for k, v in m.marks.items() if not isinstance(v, list) and not k.startswith("sign")}
    tot = {st: sum(d.values()) for st, d in m.bind_t.items()}
    return {"enabled": m.stages > 0, "stage": m.g.stage, "location": m.g.location, "marks": marks,
            "waiter_levels": {k[2:]: v for k, v in m.marks.items() if k.startswith("wl")},
            "sign_buys": [{"t": round(t, 1), "stage": s, "level": n, "cost": round(c, 2)} for t, s, n, c in m.sign_log],
            "binds": {str(st): {k: round(v / max(1e-9, tot[st]), 3) for k, v in d.items()} for st, d in m.bind_t.items()},
            "rebuilds": [{"t": round(t, 1), "stage": s, "station": sid} for t, s, sid, _c in m.rebuilds],
            "starter": round(m.marks["starter"], 1) if "starter" in m.marks else None}


def print_promo(m):
    """PROMO block: the promotion marks, signboard buys, bind shares, waiter levels."""
    g = m.g
    print()
    print("=" * 96)
    e = g.e
    reno = e.get("renovation", {})
    locs = [x for x in m.location_order() if x != "nh44"]
    mv = ", ".join(f"{x} {e['locations'][x].get('cost', 0):g} x{e['locations'][x].get('mult', 1.0):g}" for x in locs)
    print(f"PROMO - renovation {reno.get('cost', 0):g} x{reno.get('mult', 1.0):g}, move {mv or '-'}; signboard "
          f"{'off' if not g.sign_on else 'on'}; trays {'off' if not g.trays_on else e['waiters'].get('tray_levels')};"
          f" realized {m.realized:.2f}; ads {'on' if m.ads else 'off'}"
          + (f" in sessions of {m.ad_sessions:g} min" if m.ad_sessions > 0 else "")
          + (f"; starter {rupees(m.starter_amount)} at {m.starter_min:g} min" if m.starter_min > 0 else ""))
    print("=" * 96)
    for key, label in PROMO_MARKS:
        v = m.marks.get(key)
        extra = ""
        if key in ("promo0", "promo1"):
            st = key[-1]
            extra = f"   waiter levels {m.marks.get('wl' + st)}, signboard {m.marks.get('sign' + st)}"
        print(f"  {label:<40} {fmt_t(v) if v is not None else '     -'}{extra}")
    if "starter" in m.marks:
        print(f"  {'starter granted':<40} {fmt_t(m.marks['starter'])}")
    # Flush left, as proto2 prints it: the gate (G-pacing) reads "^PROMO marks: {...}".
    print("PROMO marks: " + json.dumps({k: (fmt_t(v).strip() if not isinstance(v, list) else v)
                                       for k, v in m.marks.items() if not k.startswith("sign")}))
    print("  signboard buys (time, stage, level, cost): "
          + (", ".join(f"({fmt_t(t).strip()}, s{s}, L{n}, {rupees(c)})" for t, s, n, c in m.sign_log) or "none"))
    tot = {st: sum(d.values()) for st, d in m.bind_t.items()}
    print("  binds per stage: " + "; ".join(f"s{st} " + ", ".join(f"{k} {100 * v / tot[st]:.0f}%" for k, v in sorted(d.items(), key=lambda kv: -kv[1]))
                                          for st, d in sorted(m.bind_t.items())))
    if m.rebuilds:
        print("  rebuilt after the move: " + ", ".join(f"{sid} {fmt_t(t).strip()} ({rupees(c)})" for t, s, sid, c in m.rebuilds))
    print(f"  end: stage {g.stage} ({g.location}) mult x{g.mult:.2f} signboard {g.sign} levels "
          + " ".join(f"{s}{g.st[s]['level']}" for s in g.station_ids() if g.st[s]["built"])
          + f" waiters {g.waiters} tables {g.tables} gallas {len(g.gallas)} real/min {rupees(m.real_per_min())}")
REPORT = [120.0]


class SeatedModel:
    """Expected-value free play (dt 0.5 s) on top of a SeatedGame."""

    def __init__(self, g, ads=True, save_min=4.0, verbose=True, realized=REALIZED, first_ad=None,
                 stages=0, starter_min=0.0, starter_amount=None, ad_sessions=0.0):
        self.g = g
        self.ads = ads
        self.realized = realized
        # CORE AND FEEL: promotions (--promo: stages = the renovation + every further
        # location), the starter grant (--starter MIN), sessions of M minutes for the
        # wall-ad cap (--ad-sessions M); marks / signboard buys / binds per stage
        self.stages = int(stages)
        self.starter_min = float(starter_min)
        self.starter_amount = (float(g.e.get("offers", {}).get("starter", {}).get("amount", 0.0))
                               if starter_amount is None else float(starter_amount))
        self.starter_paid = False
        self.ad_sessions = float(ad_sessions)
        self._sess = 0
        self.marks = {}
        self.stage_start = {0: 0.0}
        self.sign_log = []
        self.bind_t = {}
        self.rebuilds = []
        # wall ads shown this session (game.gd _ad_session_count, capped at
        # ad_bubble.max_per_session): the tutorial's scripted bubble counts as 1
        self.ads_shown = 1
        self.ads_capped_at = None
        self.save_min = save_min
        self.t = 0.0
        self.lam = capacity(g)["target"]
        # first free-play wall ad: after the tutorial the game.gd countdown
        # (_ad_next_in) holds ad_bubble.interval_s, not first_delay_s - the
        # tutorial's bubble was tapped (consume_ad_bubble) and the countdown
        # only runs once the tutorial is done (measured: ad_next_in 180.0 at
        # the end of main3 --auto on every seed tried)
        self.next_ad = g.e["ad_bubble"]["interval_s"] if first_ad is None else first_ad
        # travellers in the dhaba: [arrived at, travellers, locked bill or None,
        # shares at the lock]. The game prices an order when its items are
        # cooked (PRICE_LAG_S after arriving) and is paid at the galla
        # (PAY_LAG_S after arriving); the tutorial's last travellers are
        # already inside, priced at today's menu.
        self.pipe = deque()
        n0 = self.arrivals() * 0.5 / 60.0
        sh0 = capacity(g)["shares"]
        t0 = -PAY_LAG_S
        while t0 < -1e-9:
            self.pipe.append([t0, n0, g.basket() if t0 + PRICE_LAG_S <= 0.0 else None, sh0])
            t0 += 0.5
        self.events = []
        self.first_afford = {}
        self.built_at = {}
        self.stage = []
        self.real_window = []
        self.verbose = verbose
        self.seen_levels = set()
        # ROUND 2: rewards sized on the HUD takings without VIP (proposal basis)
        g.reward_rate_fn = lambda: self.lam * g.basket() / max(1e-9, g.income_mult())
        self.checks = []
        self.check_mins = [1, 2, 3, 5, 7.5, 10, 12.5, 15, 20, 25, 30, 40, 45, 50, 60, 75, 90, 120]
        self.unlock_t = {}
        # DHABA GROWTH: the dhaba's opening time while it is being built, the
        # FINISH NOW ad (--grow-skip), the marks
        self.grow_open_at = None
        self.grow_skip = False
        self.grow_marks = {}

    def arrivals(self):
        """Realized arrivals/min: the ramp target x REALIZED (headless runs land
        below the target; see REALIZED)."""
        return self.lam * self.realized

    def real_per_min(self):
        return self.arrivals() * self.g.basket()

    def step(self, dt):
        """Arrivals at REALIZED x the ramp target; each one's bill is locked at
        the prices PRICE_LAG_S later (cooked) and paid PAY_LAG_S later."""
        g, e = self.g, self.g.e
        g.now = self.t
        c = capacity(g)
        tau = e["traffic"]["ramp_ease_s"] if c["target"] > self.lam else e["traffic"]["ramp_ease_down_s"]
        self.lam += (c["target"] - self.lam) * (1.0 - math.exp(-dt / tau))
        n = self.arrivals() * dt / 60.0
        self.pipe.append([self.t, n, None, None])
        g._task_add("seated", "", n)
        for entry in self.pipe:
            if entry[2] is None and self.t >= entry[0] + PRICE_LAG_S - 1e-9:
                entry[2] = g.basket()
                entry[3] = c["shares"]
                for s, p in c["shares"].items():
                    g._task_add("served", s, entry[1] * p)
                    for d in g.menu(s)[:g.dishes_unlocked(s)]:
                        g._task_add_dish(s, d["key"], entry[1] * p * g.dish_weight(s, d["key"]))
        while self.pipe and self.t >= self.pipe[0][0] + PAY_LAG_S - 1e-9:
            t_arr, k, bill, _sh = self.pipe.popleft()
            earned = k * (bill if bill is not None else g.basket())
            g.sales_sum += earned
            g.cash += earned
            g.lifetime += earned
            g._task_add("earned", "", earned)
            g._task_add("billed", "", k)
        g._check()
        self.t += dt

    def log(self, msg):
        self.events.append((self.t, msg))

    def offline_basis(self):
        """game.gd real_income_per_min(): min(config arrivals + the signboard bonus, caps)
        x bill (VIP applied)."""
        g = self.g
        c = capacity(g)
        thr = min(float(g.e["traffic"]["travellers_per_min"]) + g.sign_bonus(), c["min"])
        return thr * g.basket()

    def snapshot(self, minute):
        g = self.g
        return dict(min=minute, cash=g.cash, real=self.real_per_min(), hud=self.lam * g.basket(), cap=g.rate(),
                    sales=g.sales_sum, rew=dict(g.rew), lifetime=g.lifetime, off_basis=self.offline_basis(),
                    prices={s: g.price(s) for s in g.built()}, levels={s: g.st[s]["level"] for s in g.built()},
                    W=len(g.waiters), T=g.tables, G=len(g.gallas), bill=g.basket(), arr=self.arrivals(),
                    stage=g.stage, sign=g.sign, wl=list(g.waiters), bind=capacity(g)["bind"])

    def _gain_of(self, mutate, undo):
        g = self.g
        before = capacity(g)["target"]
        mutate()
        after = capacity(g)["target"]
        undo()
        return (after - before) * g.basket()

    def next_build(self):
        for s in self.g.station_ids():
            if not self.g.st[s]["built"] and self.g.sdef(s).get("enabled", True):
                return s
        return None

    # ---- CORE AND FEEL: promotions, signboard, starter (the build-plan prototype's bot)
    def last_dish_level(self, sid):
        menu = self.g.menu(sid)
        return int(menu[-1].get("from_level", 100)) if menu else 100

    def content_done(self):
        """Every counter built and at its last dish (renovation.unlock "all_dishes": L100)."""
        g = self.g
        return all(g.st[s]["built"] and g.st[s]["level"] >= self.last_dish_level(s) for s in g.station_ids())

    def location_order(self):
        locs = self.g.e.get("locations", {})
        return [x for x in locs.get("order", []) if isinstance(locs.get(x), dict)]

    def next_location(self):
        order = self.location_order()
        cur = self.g.location
        if cur in order and order.index(cur) + 1 < len(order):
            return order[order.index(cur) + 1]
        return ""

    def promo_cost(self):
        """Stage 0: the renovation; later: the move to the next location."""
        e = self.g.e
        if self.g.stage == 0:
            return float(e.get("renovation", {}).get("cost", 0.0))
        return float(e["locations"][self.next_location()].get("cost", 0.0))

    def best_level_payback(self, c):
        """Minutes for the best LEVEL UP to pay for itself (game.gd level_payback_min)."""
        g = self.g
        best = math.inf
        for s in g.built():
            if g.st[s]["level"] < g.sdef(s)["max_level"]:
                gain = (g.price_at(s, g.st[s]["level"] + 1) - g.price(s)) * self.lam * c["shares"].get(s, 0.0)
                if gain > 0:
                    best = min(best, g.level_cost(s) / gain)
        return best

    def sign_payback(self, c):
        """Minutes for one more signboard level to pay for itself (cost / gain per minute)."""
        g = self.g
        c2 = capacity(g, sign_extra=1)
        gain = (c2["target"] - c["target"]) * g.basket()
        return g.sign_cost() / gain if gain > 1e-9 else math.inf

    def promote(self):
        """game.gd renovate() / move_highway() (_promote_reset): levels 1, cooks 1, SPEED 0,
        waiters [1], gallas [1], the family tables; on a move the location overlay,
        every counter but the start ones to rebuild and the signboard reset."""
        g, e = self.g, self.g.e
        kind = "renovation" if g.stage == 0 else "move"
        cost = self.promo_cost()
        g.cash -= cost
        self.marks[f"promo{g.stage}"] = self.t
        self.marks[f"wl{g.stage}"] = list(g.waiters)
        self.marks[f"sign{g.stage}"] = g.sign
        g.stage += 1
        self.stage_start[g.stage] = self.t
        remap = {}
        if kind == "move":
            dest = self.next_location()
            old_menus = {s: [d.get("key") for d in g.menu(s)] for s in g.station_ids()}
            g.location = dest
            apply_location(e, dest)
            # dish keys by menu position (every location keeps NH 44's from_level / weight
            # pattern, so the dish at the same position has the same unlock level and mix weight)
            remap = {s: {k: nd.get("key") for k, nd in zip(old_menus[s], g.menu(s))} for s in g.station_ids()}
        locd = e.get("locations", {}).get(g.location, {})
        g.mult = float(e.get("renovation", {}).get("mult", 1.0)) * float(locd.get("mult", 1.0) if isinstance(locd, dict) else 1.0)
        rebuild = kind == "move" and bool(locd.get("rebuild", False))
        for s in g.station_ids():
            g.st[s]["level"] = 1
            g.st[s]["employees"] = max(1, int(g.sdef(s).get("employees_start", 1)))
            g.st[s]["proc"] = 0
            if rebuild and not g.sdef(s).get("start_built", False):
                g.st[s]["built"] = False
        g.waiters = [1] * max(1, int(e["waiters"]["start"]))
        g.gallas = [1]
        g.tables = g.tables_start()
        if kind == "move" and e.get("signboard", {}).get("reset_on_move", True):
            g.sign = 0
        self.seen_levels = set()
        # the ad bubble countdown restarts (game.gd: _ad_next_in = ad_bubble.first_delay_s)
        self.next_ad = self.t + float(e["ad_bubble"].get("first_delay_s", e["ad_bubble"]["interval_s"]))
        # task cards: absolute ones refresh, stale slots refill. After a move an open
        # served_dish card follows its dish's menu position (the new dish at the same
        # unlock level and weight) instead of the game's refill of that slot: a refill
        # changes the greedy bot's later path (NH 48 all dishes +0:23 with ads, -1:38
        # without, -0:52 in 20 min sessions; W1-PACE notes), not the economy, so the
        # tool keeps the prototype's path. A card whose dish has no counterpart refills.
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
        self.log(f"PROMOTED {kind} {g.stage}: cost {rupees(cost)} mult x{g.mult:.2f} location {g.location}"
                 f" waiters before {self.marks[f'wl{g.stage - 1}']}")

    def act(self):
        """The prototype's bot around the base bot: sessions of the wall-ad cap, the
        starter grant, saving for a promotion (that cash is never spent on anything
        else), the signboard by the NEXT-chip payback rule."""
        g, e = self.g, self.g.e
        t = self.t
        if self.ad_sessions > 0 and self.ads and t > 0:
            sess = int(t // (self.ad_sessions * 60.0))
            if sess != self._sess:
                self._sess = sess
                self.ads_shown = 0
                self.ads_capped_at = None
        b = capacity(g)["bind"].split(":")[0]
        bt = self.bind_t.setdefault(g.stage, {})
        bt[b] = bt.get(b, 0.0) + 0.5
        if self.starter_min > 0 and not self.starter_paid and t >= self.starter_min * 60.0:
            g.add_reward(self.starter_amount, "starter")
            self.starter_paid = True
            self.marks["starter"] = t
            self.log(f"STARTER +{rupees(self.starter_amount)}")
        reserve = 0.0
        # DHABA GROWTH: in the shack the NEXT chip's goal is THE DHABA; save for it
        # (that cash is never spent on anything else), buy it, open it dur_s later
        if g.grow < 2:
            if self.grow_open_at is not None:
                if t >= self.grow_open_at - 1e-9:
                    g.grow = 2
                    self.grow_open_at = None
                    self.grow_marks["opened"] = t
                    self.log("DHABA OPEN (lassi and kadai can be built)")
            else:
                cost, dur, ok = g.dhaba_build()
                if ok:
                    if "buyable" not in self.grow_marks:
                        self.grow_marks["buyable"] = t
                        self.log(f"DHABA BUYABLE ({rupees(cost)})")
                    if g.cash >= cost:
                        g.cash -= cost
                        self.grow_marks["bought"] = t
                        self.grow_open_at = t if self.grow_skip else t + dur
                        self.log(f"DHABA BOUGHT ({rupees(cost)}), opens in {0 if self.grow_skip else dur:.0f} s")
                    else:
                        reserve = cost
        if self.content_done() and f"end{g.stage}" not in self.marks:
            self.marks[f"end{g.stage}"] = t
            self.log(f"ALL DISHES (stage {g.stage})")
        if g.stage < self.stages and self.content_done():
            key = f"unlock{g.stage}"
            if key not in self.marks:
                self.marks[key] = t
                self.log(f"UNLOCKED {'renovation' if g.stage == 0 else 'move'} ({rupees(self.promo_cost())})")
            reserve = self.promo_cost()
            if g.cash >= reserve:
                self.promote()
                reserve = 0.0
        # the NEXT chip offers the signboard only while the road is the limit and its
        # payback is at most max(offer_payback_min, the best LEVEL UP payback); never
        # from the cash saved for a promotion
        if g.sign_on and g.sign < g.sign_max() and g.sign_unlocked():
            c = capacity(g)
            spend = g.cash - reserve
            ok = c["bind"] == "max"
            if ok:
                pb = self.sign_payback(c)
                ok = pb <= max(float(g.sdef_sign().get("offer_payback_min", 0.0)), self.best_level_payback(c))
            cost = g.sign_cost()
            if ok and cost <= SIGN_SPEND_FRAC * spend:
                g.cash -= cost
                g.sign += 1
                self.sign_log.append((t, g.stage, g.sign, cost))
                self.log(f"SIGNBOARD level {g.sign} ({rupees(cost)}), cap {e['traffic']['ramp_max_tpm'] + g.sign_bonus():.1f}/min")
        saved = min(g.cash, reserve)
        g.cash -= saved
        self.act_base()
        g.cash += saved

    def act_base(self):
        g, e = self.g, self.g.e
        t = self.t
        for i, tk in enumerate(g.tasks):
            if tk["done"]:
                r = g.claim(i)
                self.log(f"claim '{tk['id']}' +{rupees(r)}")
        for what, tid in g.task_log:
            self.log(f"{what} {tid}")
        g.task_log.clear()
        if g.chest_ready():
            self.log(f"chest +{rupees(g.open_chest())}")
        if self.ads and t >= self.next_ad and self.ads_shown >= int(e["ad_bubble"].get("max_per_session", 15)):
            if self.ads_capped_at is None:
                self.ads_capped_at = t
                self.log(f"AD CAP reached (max_per_session {e['ad_bubble'].get('max_per_session', 15)}): no more wall ads this session")
        elif self.ads and t >= self.next_ad:
            self.ads_shown += 1
            r = g.ad_reward()
            g.add_reward(r, "ad")
            self.next_ad = t + e["ad_bubble"]["interval_s"]
            self.log(f"wall ad +{rupees(r)}")
        # builds: as soon as affordable (the Daftar "!" + Munshi-ji's line)
        nb = self.next_build()
        reserve = 0.0
        # Station menus (2026-10-21): the game nudges the player when the next
        # station is blocked only by waiters and the money is there (Munshi-ji's
        # "hire a second waiter first" line, the NEEDS n WAITERS tag, KAAM's
        # waiter_hire card): the bot hires the missing waiter(s) as soon as it
        # holds the build cost plus the hire, and saves for both meanwhile.
        if nb is not None and not g.can_build(nb) and Game.can_build(g, nb):
            cost = g.build_cost(nb)
            need = int(g.sdef(nb).get("requires_waiters", 0)) - len(g.waiters)
            if need > 0 and len(g.waiters) < g.waiters_max():
                hire = g.waiter_hire_cost()
                if g.cash >= cost + hire:
                    if g.buy("waiter_hire"):
                        self.log(f"hire waiter {len(g.waiters)} (for {nb})")
                elif cost + hire <= self.save_min * max(1.0, self.real_per_min()):
                    reserve = cost + hire
        if nb is not None and g.can_build(nb):
            cost = g.build_cost(nb)
            if g.cash >= cost and nb not in self.first_afford and g.stage == 0:
                self.first_afford[nb] = t
                self.log(f"AFFORDABLE {nb} ({rupees(cost)})")
            if g.cash >= cost and g.stage > 0:
                # a counter rebuilt after a move (not in the BILL CHECK: that checks the
                # first build of each station on the roadside)
                g.buy("build", nb)
                self.rebuilds.append((t, g.stage, nb, cost))
                self.log(f"REBUILD {nb} ({rupees(cost)}) at {g.location}")
            elif g.cash >= cost:
                mates = [(s, g.st[s]["level"], g.price(s)) for s in g.built() if g.group_of(s) == g.group_of(nb)]
                before = capacity(g)
                real_before = self.real_per_min()
                basket_before = g.basket()
                rate_before = g.rate()
                g.buy("build", nb)
                self.built_at[nb] = t
                after = capacity(g)
                self.stage.append(dict(t=t, sid=nb, before=before, after=after, real_before=real_before,
                                       l1=g.price_at(nb, 1),
                                       basket_before=basket_before, basket_after=g.basket(),
                                       rate_before=rate_before, rate_after=g.rate(), afford_t=self.first_afford.get(nb, t), mates=mates,
                                       waiters=len(g.waiters), tables=g.tables,
                                       util=utilisation(g, after["target"])))
                self.log(f"BUILD {nb}")
            elif cost <= self.save_min * max(1.0, self.real_per_min()):
                reserve = cost
        spendable = g.cash - reserve
        # staff the floor: waiters first, tables when seats bind, gallas by queue
        c = capacity(g)
        if len(g.waiters) < g.waiters_max() and g.waiter_hire_cost() <= 0.5 * spendable:
            if g.buy("waiter_hire"):
                spendable = g.cash - reserve
                self.log(f"hire waiter {len(g.waiters)}")
        if g.tables < g.tables_max() and g.table_cost() <= 0.5 * spendable \
                and (c["bind"] == "seats" or c["seats"] < c["target"] * 1.3):
            if g.buy("table"):
                spendable = g.cash - reserve
                self.log(f"table set {g.tables}")
        if len(g.gallas) < e["galla"]["max"] and g.galla_hire_cost() <= 0.5 * spendable:
            if g.buy("galla_hire"):
                spendable = g.cash - reserve
        # KAAM chasing
        for tk in g.tasks:
            if tk["done"]:
                continue
            kind = tk["kind"]
            if kind == "galla_level" and tk["galla"] < len(g.gallas):
                want, cost = ("galla_up", tk["galla"]), g.galla_up_cost(tk["galla"])
            elif kind == "processing" and g.st[tk["station"]]["built"]:
                want, cost = ("proc", tk["station"]), g.proc_cost(tk["station"])
            elif kind == "hire" and g.st[tk["station"]]["built"] and g.st[tk["station"]]["employees"] < 3:
                want, cost = ("hire", tk["station"]), g.hire_cost(tk["station"])
            elif kind == "waiter_level" and tk.get("waiter", 0) < len(g.waiters):
                want, cost = ("waiter_up", tk.get("waiter", 0)), g.waiter_up_cost(tk.get("waiter", 0))
            elif kind == "tables" and g.tables < g.tables_max():
                want, cost = ("table", None), g.table_cost()
            elif kind == "waiters" and len(g.waiters) < g.waiters_max():
                want, cost = ("waiter_hire", None), g.waiter_hire_cost()
            else:
                continue
            if cost <= 0.5 * spendable and g.buy(*want):
                spendable = g.cash - reserve
        # greedy upgrades by income gain per cost
        for _ in range(30):
            best = None
            basket = g.basket()
            sh = c["shares"]
            for s in g.built():
                d = g.sdef(s)
                if g.st[s]["level"] < d["max_level"]:
                    gain = (g.price_at(s, g.st[s]["level"] + 1) - g.price(s)) * self.lam * sh.get(s, 0.0)
                    cand = (gain / g.level_cost(s), "level", s, g.level_cost(s))
                    best = cand if best is None or cand > best else best
                if c["bind"] == "station:" + s:
                    if g.st[s]["employees"] < d["employees_max"]:
                        gain = self._gain_of(lambda: g.st[s].__setitem__("employees", g.st[s]["employees"] + 1),
                                             lambda: g.st[s].__setitem__("employees", g.st[s]["employees"] - 1))
                        cand = (gain / g.hire_cost(s) * 1.5 + 1e-9, "hire", s, g.hire_cost(s))
                        best = cand if best is None or cand > best else best
                    if g.st[s]["proc"] < d["processing_max"]:
                        gain = self._gain_of(lambda: g.st[s].__setitem__("proc", g.st[s]["proc"] + 1),
                                             lambda: g.st[s].__setitem__("proc", g.st[s]["proc"] - 1))
                        cand = (gain / g.proc_cost(s) * 1.5 + 1e-9, "proc", s, g.proc_cost(s))
                        best = cand if best is None or cand > best else best
            if c["bind"] == "gallas":
                for i in range(len(g.gallas)):
                    gain = self._gain_of(lambda: g.gallas.__setitem__(i, g.gallas[i] + 1),
                                         lambda: g.gallas.__setitem__(i, g.gallas[i] - 1))
                    cand = (gain / g.galla_up_cost(i) * 1.5 + 1e-9, "galla_up", i, g.galla_up_cost(i))
                    best = cand if best is None or cand > best else best
            if c["bind"] == "waiters":
                for i in range(len(g.waiters)):
                    gain = self._gain_of(lambda: g.waiters.__setitem__(i, g.waiters[i] + 1),
                                         lambda: g.waiters.__setitem__(i, g.waiters[i] - 1))
                    cand = (gain / g.waiter_up_cost(i) * 1.5 + 1e-9, "waiter_up", i, g.waiter_up_cost(i))
                    best = cand if best is None or cand > best else best
            if best is None or best[3] > spendable:
                break
            if not g.buy(best[1], best[2]):
                break
            if best[1] in ("hire", "proc"):
                self.log(f"{best[1]} {best[2]}")
            spendable = g.cash - reserve
            c = capacity(g)
        for s in g.built():
            for m in e["level_milestones"][:3]:
                if g.st[s]["level"] >= m and (s, m) not in self.seen_levels:
                    self.seen_levels.add((s, m))
                    dish = next((d for d in g.menu(s) if int(d.get("from_level", 1)) == m), None)
                    pre = f"s{g.stage} " if g.stage > 0 else ""   # after a promotion: the stage
                    self.log(f"{pre}{s} reached L{m}" + (f": {dish['name']} on the menu" if dish else ""))
                    self.unlock_t[f"{pre}{s}.L{m}" + (f" {dish['name']}" if dish else "")] = t

    def run(self, minutes, report_every=120.0, quiet=False):
        g = self.g
        end = self.t + minutes * 60.0
        last = self.t
        if not quiet:
            print(f"{'time':>6} | {'cash':>9} | {'HUD/min':>9} | {'real/min':>9} | {'arr':>4} | {'binds':<14} |"
                  f" chai tand lass kada | W T G | claims")
        while self.t < end - 1e-9:
            self.step(0.5)
            self.act()
            for st in self.stage:
                if "real_60" not in st and self.t >= st["t"] + 60.0:
                    st["real_60"] = self.real_per_min()
                    st["level_60"] = g.st[st["sid"]]["level"]
            while self.check_mins and self.t >= self.check_mins[0] * 60.0 - 1e-6:
                self.checks.append(self.snapshot(self.check_mins.pop(0)))
            if not quiet and self.t - last >= report_every - 1e-6:
                last = self.t
                lv = []
                for s in ("chai", "tandoor", "lassi", "kadai"):
                    lv.append(f"{g.st[s]['level']:4d}" if s in g.st and g.st[s]["built"] else "   -")
                c = capacity(g)
                extra = ""
                if g.stage > 0 or g.sign > 0:
                    extra = f" | s{g.stage} sign {g.sign}" + (f" W{g.waiters}" if g.stage > 0 else "")
                print(f"{fmt_t(self.t)[:-3]:>6} | {rupees(g.cash):>9} | {rupees(g.rate()):>9} | {rupees(self.real_per_min()):>9} |"
                      f" {self.arrivals():4.1f} | {c['bind']:<14} | {' '.join(lv)} | {len(g.waiters)} {g.tables} {len(g.gallas)} | {g.claims:5d}{extra}")


def stage_matrix(eco):
    """Rule check: arrivals/min (ramp target) before -> after each new station is
    built, over floor setups (waiters, table sets, tandoor cooks, galla level)."""
    rows = []
    chain = [("lassi", ["chai", "tandoor"]), ("kadai", ["chai", "tandoor", "lassi"])]
    for w in (1, 2, 3):
        for tb in (2, 3, 5):
            for cooks in (1, 2):
                for gl in (1, 10):
                    g = SeatedGame(eco)
                    g.waiters = [1] * w
                    g.tables = tb
                    g.gallas = [gl, gl]
                    g.st["tandoor"]["employees"] = cooks
                    out = []
                    for sid, before in chain:
                        req = int(g.sdef(sid).get("requires_waiters", 0))
                        cb = capacity(g, before)
                        ca = capacity(g, before + [sid])
                        out.append((sid, cb["target"], ca["target"], cb["bind"], ca["bind"], w >= req, ca["trip"]))
                    rows.append(((w, tb, cooks, gl), out))
    return rows


def part_b(eco, run, minutes, ads, opts=None):
    """Seated free play from the end of the reference replay (tandoor built).
    `opts` (core and feel): promo, no_signboard, no_trays, realized, ad_sessions,
    starter, starter_amount."""
    o = dict(promo=False, no_signboard=False, no_trays=False, realized=REALIZED, ad_sessions=0.0,
             starter=0.0, starter_amount=None, growth=False, grow_skip=False)
    o.update(opts or {})
    g0 = run["game"]
    # the model's own copy: a move applies the location overlay to it
    g = SeatedGame(copy.deepcopy(eco))
    if o["no_trays"]:
        g.trays_on = False
    if o["no_signboard"]:
        g.sign_on = False
    # carry the reference run's end state over (levels, gallas, tasks); the cash
    # is the game's own tutorial-end figure (INGAME_TUTORIAL_END_CASH)
    g.cash = INGAME_TUTORIAL_END_CASH
    for s in g0.st:
        g.st[s] = dict(g0.st[s])
    g.gallas = list(g0.gallas)
    g.task_used = set(g0.task_used)
    g.tasks = [g._new_task(t["id"], g.e["tasks"]["defs"].get(t["id"], {"kind": t["kind"], "target": t["target"],
                                                                          "reward": t["reward"]})) for t in g0.tasks]
    for t, t0 in zip(g.tasks, g0.tasks):
        t["progress"] = t0["progress"] if t["kind"] not in TASK_ABS else g._abs_progress(t)
    g.chest_claims, g.claims, g.task_gen = g0.chest_claims, g0.claims, g0.task_gen
    g.ad_auto = True
    g.st["tandoor"]["built"] = True
    # ROUND 2: the UX-fix tutorial (0.3.2) ends with waiter 2 hired and table 3
    # bought (measured in-game: W2 T3 G2 [3, 2] at TUTORIAL_END, every seed)
    g.waiters = [1] * TUT_END_WAITERS[0]
    g.tables = TUT_END_TABLES[0]
    if o["growth"]:
        g.grow = 1   # the step 4 tutorial ends in the shack
    g._refresh_abs()
    g._check()
    stages = 0
    if o["promo"] and g.e.get("renovation"):
        locs = [x for x in g.e.get("locations", {}).get("order", []) if isinstance(g.e["locations"].get(x), dict)]
        stages = 1 + max(0, len(locs) - 1)
    print()
    print("=" * 96)
    print(f"PART B - seated free play after the tutorial (expected values), {minutes:.0f} min, ads {'on' if ads else 'off'},"
          f" greedy bot that saves for the next station once it costs <= 4 min of real income")
    ch = g.e["stations"].get("chai", {})
    sb = g.e.get("signboard", {})
    feat = [f"chai price ramp L{ch.get('price_step_ramp_from')}->L{ch.get('price_step_ramp_to')}" if "price_step_ramp_to" in ch
            else "no price ramp",
            (f"signboard +{sb.get('tpm_per_level', 0):g}/min a level, {sb.get('cost_base', 0):g} x {sb.get('cost_growth', 1):g}^L,"
             f" {sb.get('max_levels', 0)}/{sb.get('max_levels_family', 0)} levels, payback <= max({sb.get('offer_payback_min', 0):g} min,"
             f" best LEVEL UP)") if g.sign_on else "signboard off",
            (f"trays at waiter L{g.e['waiters'].get('tray_levels')} x{g.e['waiters'].get('tray_batch_est', 0):g}") if g.trays_on
            else "trays off",
            f"promotions {'on (' + str(stages) + ')' if stages else ('off (no renovation block)' if o['promo'] else 'off')}",
            f"realized {o['realized']:.2f}"]
    if o["ad_sessions"] > 0:
        feat.append(f"wall-ad sessions of {o['ad_sessions']:g} min")
    if o["starter"] > 0:
        feat.append(f"starter at {o['starter']:g} min")
    print("Core and feel: " + "; ".join(feat))
    print("=" * 96)
    m = SeatedModel(g, ads=ads, realized=o["realized"], stages=stages, starter_min=o["starter"],
                    starter_amount=o["starter_amount"], ad_sessions=o["ad_sessions"])
    m.grow_skip = bool(o["grow_skip"])
    if stages:
        # the prototype's checkpoints past the first hour
        m.check_mins = sorted(set(m.check_mins) | {70, 80, 100, 150, 180})
    m.run(minutes, report_every=REPORT[0])
    print_round2(eco, m)
    if stages:
        print_promo(m)
    if o["growth"]:
        cost, dur, _ok = g.dhaba_build()
        gm = m.grow_marks
        f = lambda k: fmt_t(gm[k]) if k in gm else "never"
        print()
        print(f"GROWTH (started in the shack; the dhaba {rupees(cost)}, {'FINISH NOW at once' if m.grow_skip else f'{dur:.0f} s build'}):"
              f" buyable {f('buyable')}, bought {f('bought')}, open {f('opened')},"
              f" lassi {fmt_t(m.built_at['lassi']) if 'lassi' in m.built_at else 'never'},"
              f" kadai {fmt_t(m.built_at['kadai']) if 'kadai' in m.built_at else 'never'}")
        print("GROWTH_SUMMARY " + json.dumps({k: round(v, 1) for k, v in gm.items()} |
                                             {"lassi": round(m.built_at.get("lassi", -1), 1),
                                              "kadai": round(m.built_at.get("kadai", -1), 1), "cost": cost}))
    print()
    print("Timeline (station affordable / built, staff, milestones):")
    for t, ev in m.events:
        if not ev.startswith(("claim", "wall ad", "chest", "card", "drop")):
            print(f"  {fmt_t(t)}  {ev}")
    claims = sum(1 for _, ev in m.events if ev.startswith("claim"))
    print(f"  task claims: {claims}; lifetime earned {rupees(g.lifetime)} (display)")
    print()
    print("KAAM cards handed out (sequence order; 'drop' = stale when its turn came, never shown):")
    n_cards = 0
    for t, ev in m.events:
        if ev.startswith(("card", "drop")):
            n_cards += 1
            print(f"  {fmt_t(t)}  {ev}")
    print()
    print(f"Each build (arrivals = ramp target; real = {m.realized:.2f} x target x expected bill;"
          " HUD = sum of station price x capacity x demand share):")
    for st in m.stage:
        b, a = st["before"], st["after"]
        u = utilisation(g, a["target"]) if st is m.stage[-1] else None
        print(f"  {fmt_t(st['t'])} {st['sid']:<6} W{st['waiters']} T{st['tables']}: arrivals {b['target']:.1f} ({b['bind']})"
              f" -> {a['target']:.1f} ({a['bind']}) | bill {rupees(st['basket_before'])} -> {rupees(st['basket_after'])}"
              f" | real/min {rupees(st['real_before'])} -> {rupees(a['target'] * m.realized * st['basket_after'])}"
              f" | HUD {rupees(st['rate_before'])} -> {rupees(st['rate_after'])} | waiter trip {b['trip']:.2f} -> {a['trip']:.2f} s")
        print("           busy right after (1 new cook): " + ", ".join(f"{k} {v:.0%}" for k, v in st["util"].items()))
        if "real_60" in st:
            print(f"           60 s later: {st['sid']} L{st['level_60']}, real/min {rupees(st['real_60'])}"
                  f" ({st['real_60'] / max(1e-9, st['real_before']):.1f}x the pre-build rate)")
    print()
    print("Order mix now:", ", ".join(f"{'+'.join(seq)} {p:.0%}" for p, seq in g.order_mix()))
    u = utilisation(g, m.lam)
    print("Busy share at", f"{m.lam:.1f}/min:", ", ".join(f"{k} {v:.0%}" for k, v in u.items()))
    print()
    print(f"BILL CHECK (expected bill change when each station is built, at the moment it becomes affordable; must be >= +{MIN_BILL_GAIN:.0%}):")
    m.bill_fail = 0
    for st in m.stage:
        gain = st["basket_after"] / max(1e-9, st["basket_before"]) - 1.0
        hud = st["rate_after"] / max(1e-9, st["rate_before"]) - 1.0
        ok = gain >= MIN_BILL_GAIN - 1e-9
        m.bill_fail += 0 if ok else 1
        mates = ", ".join(f"{s} L{lv} {rupees(p)}" for s, lv, p in st["mates"])
        print(f"  {st['sid']:<6} affordable {fmt_t(st['afford_t'])}, built {fmt_t(st['t'])}: bill {gain:+.1%}, HUD {hud:+.1%}"
              f"  {'OK' if ok else 'FAIL'}   ({st['sid']} L1 {rupees(st.get('l1', g.price_at(st['sid'], 1)))} vs {mates})")
    print(f"  bill check failures: {m.bill_fail}")
    if m.ads:
        n = m.ads_shown - 1
        cap = f", capped at {fmt_t(m.ads_capped_at)}" if m.ads_capped_at is not None else ""
        print(f"  wall ads watched after the tutorial: {n} (max_per_session {g.e['ad_bubble'].get('max_per_session', 15)}"
              f" incl. the tutorial's{cap})")
    return m


def print_matrix(eco):
    if any(s not in eco["stations"] for s in NEW_STATIONS):
        print("\n(--matrix needs the menu-expansion stations lassi / kadai in the economy)")
        return 0
    print()
    print("=" * 96)
    print("RULE CHECK - arrivals/min before -> after each build (ramp target; W waiters, T table sets,"
          " C tandoor cooks, G galla level)")
    print("=" * 96)
    drops = 0
    for (w, tb, cooks, gl), out in stage_matrix(eco):
        cells = []
        for sid, b, a, bb, ab, allowed, trip in out:
            flag = " (locked)" if not allowed else ("" if a >= b - 0.05 else " DROP")
            if flag == " DROP":
                drops += 1
            cells.append(f"{sid} {b:4.1f}->{a:4.1f}{flag}")
        print(f"  W{w} T{tb} C{cooks} G{gl:<2} | " + " | ".join(cells))
    print(f"  drops where the build is allowed: {drops}")
    fails = drops
    g = SeatedGame(eco)
    g.tables = 5
    print()
    print("Whole-order waiter trips (s, waiter L1, 5 table sets, calibrated to chai+roti = %.1f s on tables 0-1):" % MEASURED_LOOP_S)
    for key in (["chai"], ["chai", "tandoor"], ["lassi", "tandoor"], ["chai", "kadai"], ["lassi", "kadai"]):
        for tb in (2, 5):
            g.tables = tb
            speed = TRAV_SPEED * eco["waiters"]["base_speed_ratio"]
            n = len(key)
            t = (raw_trip_m(key, tb) / speed + n * PICK_S + SERVE_S + STAGGER_S * (n - 1)) * trip_cal(eco)
            print(f"  {'+'.join(key):<14} tables {tb}: {t:4.2f} s")
    return fails


def apply_location(eco, loc_id):
    """game.gd _apply_location (C6.3): for each station listed in
    locations.<loc_id>.stations, replace each listed key wholesale (in place)."""
    block = eco.get("locations", {}).get(loc_id, {})
    over = block.get("stations", {}) if isinstance(block, dict) else {}
    missing = []
    for sid, keys in over.items():
        if sid not in eco["stations"]:
            missing.append(sid)
            continue
        for k, v in keys.items():
            eco["stations"][sid][k] = copy.deepcopy(v)
    return missing


def menu_check_all(eco):
    """MENU CHECK once per location: the base menus (the first location), then each
    location's overlay applied to a copy of the economy. Returns all failures."""
    locs = eco.get("locations", {})
    order = [x for x in locs.get("order", []) if isinstance(locs.get(x), dict)] if isinstance(locs, dict) else []
    if not order:
        return menu_check(eco)
    fails = 0
    for loc in order:
        e2 = copy.deepcopy(eco)
        missing = apply_location(e2, loc)
        fails += menu_check(e2, loc)
        for sid in missing:
            print(f"  {loc}: overlay station {sid} is not in the economy  FAIL")
            fails += 1
    return fails


def menu_check(eco, label=""):
    """Station menus (docs/v3-station-menus.md §1.3): for every station and every
    unlock state n, the effective price / cook factors (raw / weighted mean of
    the unlocked raws) have weighted mean exactly 1.0, no dish's price falls
    across an unlock (milestone_price_mult x M(n-1) / M(n) >= 1), every
    unlock level (dish 2+) is a milestone level, and every price_mult / cook_mult
    is a positive number. Returns the number of failures."""
    fails = 0
    wn = float(eco.get("menus", {}).get("weight_newest", 0.4))
    pm = float(eco.get("milestone_price_mult", 2.0))
    ms = [int(m) for m in eco["level_milestones"]]
    print()
    print("=" * 96)
    print(f"MENU CHECK{' [' + label + ']' if label else ''} - effective price / cook factors per unlock state"
          f" (newest dish {wn:.0%}; must average 1.0,"
          f" never drop a price across an unlock; unlock levels in level_milestones {ms[:3]})")
    print("=" * 96)
    states = 0
    for sid in eco["station_order"]:
        menu = eco["stations"][sid].get("menu", [])
        if not menu:
            print(f"  {sid}: NO MENU  FAIL")
            fails += 1
            continue
        if int(menu[0].get("from_level", 1)) != 1:
            print(f"  {sid}: dish 1 from_level {menu[0].get('from_level')} != 1  FAIL")
            fails += 1
        bad = False
        for d in menu:
            for k in ("price_mult", "cook_mult"):
                v = d.get(k, 1.0)
                if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(float(v)) or float(v) <= 0.0:
                    print(f"  {sid}.{d.get('key')}: {k} {v!r} is not a positive number  FAIL")
                    fails += 1
                    bad = True
        if bad:
            continue
        for k, d in enumerate(menu[1:], 2):
            fl = int(d.get("from_level", 1))
            if fl not in ms or fl <= int(menu[k - 2].get("from_level", 1)):
                print(f"  {sid}.{d.get('key')}: from_level {fl} is not a later milestone level  FAIL")
                fails += 1
        prev_m = None
        for n in range(1, len(menu) + 1):
            w = [1.0] if n <= 1 else [(1.0 - wn) / (n - 1)] * (n - 1) + [wn]
            raw_p = [float(d.get("price_mult", 1.0)) for d in menu[:n]]
            raw_c = [float(d.get("cook_mult", 1.0)) for d in menu[:n]]
            mp = sum(a * b for a, b in zip(w, raw_p))
            mc = sum(a * b for a, b in zip(w, raw_c))
            eff_p = [r / mp for r in raw_p]
            eff_c = [r / mc for r in raw_c]
            sp = sum(a * b for a, b in zip(w, eff_p))
            sc = sum(a * b for a, b in zip(w, eff_c))
            ok = abs(sp - 1.0) < 1e-9 and abs(sc - 1.0) < 1e-9
            ratio = pm * prev_m / mp if prev_m is not None else None
            if ratio is not None and ratio < 1.0 - 1e-9:
                ok = False
            fails += 0 if ok else 1
            states += 1
            print(f"  {sid:<8} n={n}  price {' '.join(f'{x:.4f}' for x in eff_p):<30} cook {' '.join(f'{x:.3f}' for x in eff_c):<26}"
                  f" mean {sp:.6f} / {sc:.6f}" + (f"  unlock x{ratio:.3f}" if ratio is not None else "          ")
                  + f"  {'OK' if ok else 'FAIL'}")
            prev_m = mp
    print(f"  MENU CHECK: {states} states, failures: {fails}")
    return fails


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seeds", type=int, default=300)
    ap.add_argument("--minutes", type=float, default=60.0)
    ap.add_argument("--no-ads", action="store_true")
    ap.add_argument("--seed", type=int, default=0, help="reference run whose end state starts part B")
    ap.add_argument("--eco", default=str(ECO_PATH), help="economy JSON (default themes/dhaba/economy.json)")
    ap.add_argument("--matrix", action="store_true", help="also print the arrivals rule check per floor setup")
    ap.add_argument("--report", type=float, default=120.0, help="part B report row interval in seconds (default 120)")
    ap.add_argument("--set", action="append", default=[], metavar="PATH=VALUE",
                    help="override an economy value for a what-if run, e.g. --set milestone_cost_mult=3"
                         " or --set stations.tandoor.price_base=8")
    ap.add_argument("--difficulty", type=float, default=None, metavar="D",
                    help="ROUND 2: the difficulty dial (difficulty.cost_mult; the JSON's value by default)")
    ap.add_argument("--promo", action="store_true",
                    help="CORE AND FEEL: part B also runs the Family Dhaba renovation and the moves of"
                         " locations.order (the bot saves for each once it unlocks); prints the PROMO block")
    ap.add_argument("--no-signboard", action="store_true", help="part B without the highway signboard (C5.3)")
    ap.add_argument("--no-trays", action="store_true", help="part B without the waiter trays (C3.4)")
    ap.add_argument("--realized", type=float, default=REALIZED, metavar="R",
                    help=f"realized arrivals / ramp target in part B (default {REALIZED})")
    ap.add_argument("--ad-sessions", type=float, default=0.0, metavar="M",
                    help="part B as sessions of M minutes: the wall-ad cap (ad_bubble.max_per_session) resets each one")
    ap.add_argument("--growth", action="store_true",
                    help="part B starts in the tin shack (dhaba growth step 4): caps, and THE DHABA before lassi")
    ap.add_argument("--grow-skip", action="store_true", help="with --growth: the dhaba opens at once (FINISH NOW ad)")
    ap.add_argument("--starter", type=float, default=0.0, metavar="MIN",
                    help="grant the starter pack (offers.starter.amount) MIN minutes into part B (C7.4)")
    ap.add_argument("--starter-amount", type=float, default=None, metavar="REF",
                    help="override the starter pack's cash (ref units; default offers.starter.amount)")
    args = ap.parse_args()
    eco = json.loads(Path(args.eco).read_text())
    DISPLAY_SCALE[0] = float(eco.get("money_display_scale", 10.0))
    for kv in args.set:
        path, val = kv.split("=", 1)
        node = eco
        keys = path.split(".")
        for k in keys[:-1]:
            node = node[k]
        node[keys[-1]] = json.loads(val)
        print(f"override {path} = {val}")
    if args.difficulty is not None:
        eco.setdefault("difficulty", {})["cost_mult"] = float(args.difficulty)
        print(f"override difficulty.cost_mult = {args.difficulty}")
    print(f"economy version {eco.get('version')}, difficulty dial {float(eco.get('difficulty', {}).get('cost_mult', 1.0))}")
    fails = menu_check_all(eco)
    runs = part_a(eco, args.seeds, not args.no_ads)
    if args.minutes > 0:
        # start part B from a replay that built the tandoor at 160.5 s like the reference
        # (the first such run from --seed on); its cash, levels, gallas and tasks carry over
        # (always the replay with the reference's wall ad: without it the tandoor is not
        # affordable at 160.5 s; --no-ads then applies to part B only)
        src = runs if not args.no_ads else [run_reference(eco, s, True) for s in range(args.seed, args.seed + 8)]
        built = [r for r in src[args.seed if not args.no_ads else 0:] if r["game"].st["tandoor"]["built"]]
        run = built[0] if built else run_reference(eco, args.seed, True)
        REPORT[0] = args.report
        m = part_b(eco, run, args.minutes, not args.no_ads,
                   dict(promo=args.promo, no_signboard=args.no_signboard, no_trays=args.no_trays,
                        realized=args.realized, ad_sessions=args.ad_sessions, starter=args.starter,
                        starter_amount=args.starter_amount, growth=args.growth, grow_skip=args.grow_skip))
        fails += m.bill_fail
    if args.matrix:
        fails += print_matrix(eco)
    if fails:
        print(f"\nFAILED: {fails} check(s)")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
