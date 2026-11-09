#!/usr/bin/env python3
"""Per-beat tutorial bars (build plan section 6.1, rules R1 to R12). W0-QA.

Usage:
  tutcheck.py LOGDIR [--base DIR] [--prev DIR] [--allow-move STEP,...] [--slack S] [--fps30]
                     [--write-beats PATH]

Checks every tut_*.log in LOGDIR (and fps30_*.log, consent_*.log, nofill_*.log when present) and prints
  TUTCHECK <log> PASS|FAIL <reasons>
then one table row per log (done, waiter_done, seats_lines, line7, cash at done, each with its delta
against --base and --prev) and finally
  TUTCHECK fails=<n>
The exit code is n (the number of failing logs, at most 255).

Base and prev: a directory of tutorial logs (tut_en_s1.log ...) or, when a log is missing there, the
directory's beats.json. A log is compared with the base/prev log of the same name; consent_* and nofill_*
logs are compared with tut_<lang>_s<seed> (lang "hi" when the name holds "_hi", else "en"). --prev is
optional (R11 is skipped without it). fps30_* logs are 30 fps runs: R1 and the conservation check always,
R12 only with --fps30; --fps30 also treats every other log in LOGDIR as a 30 fps run.

--allow-move: steps exempt from R11 (the previous gate's baseline). "STEP+" exempts that step and every
later step of the log; "all" exempts every step. --slack S adds S seconds to every upper bound from
seats_done on (the consent run). --write-beats PATH writes beats.json for LOGDIR's tut_*.log files
(every step's times by occurrence, the cash at done) and may be used without any check.

R5 relaxes its 8 s bar (to the base offset + 1.5 s, for seeds whose base seats beat lands later than
free + 8 s) only for a log from before C4.1: no seats fill line and no "[hud] meter revealed at <t>" by the
first free step. Every wave-3+ tutorial log reveals the meter as the waiter beat starts.
"""
import argparse
import json
import os
import re
import sys

STEP_RE = re.compile(r"^\[auto\] ([\d.]+) step -> (\w+) \(cash (-?[\d.]+)\)", re.M)
QUIT_RE = re.compile(r"^\[main3\] quit at game time [\d.]+ \(tutorial step: (\w+)\)", re.M)
HOME_RE = re.compile(r"^\[auto\] [\d.]+ home check: (.*)$", re.M)
# Idle Business Kit: the core station's id is printed (chai for the dhaba pack).
DONE_STATE_RE = re.compile(r"^\[auto\] [\d.]+ done state: \w+ L(\d+)", re.M)
CONS_RE = re.compile(r"^\[sim\] conservation arrived (\d+) paid (\d+) inside (\d+) left_unpaid (\d+) drove_past (\d+)", re.M)
FILL_RE = re.compile(r"^(\[sim\] seats fill:|\[tutorial\] seats beat: filled)", re.M)
# W3-TUT's Director (the wave that brought the C4.1 fill) reveals the meter as the waiter beat starts, before the
# first free step; wave 2 revealed it only after the tutorial, wave 1 and 0.3.7 never print the line (R5, W4-NUM).
METER_RE = re.compile(r"^\[hud\] meter revealed at ([\d.]+)", re.M)

HOME_WANT = "dist 0.00 m, in view true, next chip true 'save'"
NO_AD_STEPS = ("bubble", "vip", "ad_lines")
EPS = 0.005  # the logs print 2 decimals


def parse_log(path):
    t = open(path, errors="replace").read()
    steps = [(m.group(2), float(m.group(1)), float(m.group(3))) for m in STEP_RE.finditer(t)]
    q = QUIT_RE.findall(t)
    h = HOME_RE.findall(t)
    ds = DONE_STATE_RE.findall(t)
    cons = [tuple(int(x) for x in m) for m in CONS_RE.findall(t)]
    fill = bool(FILL_RE.search(t))
    meter = METER_RE.search(t)
    free1 = next((tt for name, tt, _ in steps if name == "free"), None)
    # C4.1 in the tree: a fill line, or the meter revealed by the first free step (every wave-3+ tutorial log).
    c41 = fill or (meter is not None and free1 is not None and float(meter.group(1)) <= free1 + EPS)
    return {
        "steps": steps,
        "quit_step": q[-1] if q else None,
        "home_check": h[-1].strip() if h else None,
        "done_state_chai": int(ds[-1]) if ds else None,
        "conservation": cons,
        "fill": fill,
        "c41": c41,
    }


def keyed(steps):
    """[(name, t, cash)] -> ordered list of (key, t, cash) with key 'name' or 'name#k' (k-th occurrence)."""
    seen = {}
    out = []
    for name, tt, cash in steps:
        seen[name] = seen.get(name, 0) + 1
        key = name if seen[name] == 1 else "%s#%d" % (name, seen[name])
        out.append((key, tt, cash))
    return out


class Run:
    def __init__(self, name, data):
        self.name = name
        self.data = data
        self.order = keyed(data["steps"])
        self.t = {k: tt for k, tt, _ in self.order}
        self.cash = {k: c for k, _, c in self.order}
        self.idx = {k: i for i, (k, _, _) in enumerate(self.order)}

    def get(self, key):
        return self.t.get(key)


def run_from_beats(name, entry):
    steps = [(s[0], float(s[1]), float(s[2])) for s in entry.get("steps", [])]
    return Run(name, {"steps": steps, "quit_step": entry.get("quit_step"), "home_check": entry.get("home_check"),
                      "done_state_chai": entry.get("done_state_chai"), "conservation": [], "fill": False,
                      "c41": False})


class RefDir:
    """A base or prev directory: its tutorial logs, else its beats.json."""

    def __init__(self, d):
        self.d = d
        self.cache = {}
        self.beats = None
        bp = os.path.join(d, "beats.json") if d else None
        if bp and os.path.exists(bp):
            try:
                self.beats = json.load(open(bp)).get("logs", {})
            except Exception:
                self.beats = None

    def run(self, name):
        if not self.d:
            return None
        if name in self.cache:
            return self.cache[name]
        p = os.path.join(self.d, name + ".log")
        r = None
        if os.path.exists(p):
            r = Run(name, parse_log(p))
            if not r.order:
                r = None
        if r is None and self.beats and name in self.beats:
            r = run_from_beats(name, self.beats[name])
        self.cache[name] = r
        return r


def ref_name(name):
    """Log name -> the name of its reference log in base / prev."""
    if name.startswith("tut_"):
        return name
    m = re.search(r"_s(\d+)", name)
    if not m:
        return None
    lang = "hi" if "_hi" in name else "en"
    return "tut_%s_s%s" % (lang, m.group(1))


def fmt_d(x):
    return "%+.2f" % x


def bar_txt(lo, hi):
    if lo is None:
        return "<= %+.2f" % hi
    if hi is None:
        return ">= %+.2f" % lo
    if abs(lo + hi) < 1e-9:
        return "+-%.2f" % hi
    return "%+.2f..%+.2f" % (lo, hi)


def check_run(run, base, prev, opts):
    """Returns (reasons, info). reasons: list of (priority, text); priority 0 sorts first."""
    reasons = []
    info = []
    name = run.name
    is30 = opts["fps30"] or name.startswith("fps30_")
    nofill = name.startswith("nofill_")
    S = opts["slack"]
    d = run.data

    def fail(pri, text):
        reasons.append((pri, text))

    # ---- R1: the tutorial ends, the quit line says so, the home check holds
    if run.get("done") is None:
        fail(0, "no 'step -> done' (R1)")
    if d["quit_step"] is None:
        fail(1, "no '[main3] quit at ... (tutorial step: ...)' line (R1)")
    elif d["quit_step"] != "done":
        fail(1, "quit with tutorial step '%s', not done (R1)" % d["quit_step"])
    if d["home_check"] is None:
        fail(1, "no home check line (R1)")
    elif d["home_check"] != HOME_WANT:
        fail(1, "home check '%s' (R1 wants '%s')" % (d["home_check"], HOME_WANT))
    # ---- conservation (when present): nobody leaves unpaid
    for a, p, i, u, dp in d["conservation"]:
        if u != 0:
            fail(1, "conservation left_unpaid %d" % u)
        if a != p + i + u:
            fail(1, "conservation arrived %d != paid %d + inside %d + left_unpaid %d" % (a, p, i, u))
    # ---- 30 fps runs: R12 only (with --fps30); no base comparison
    if is30:
        if opts["fps30"]:
            f1, sl, dn = run.get("free"), run.get("seats_lines"), run.get("done")
            if f1 is None or sl is None:
                fail(2, "no free / seats_lines step (R12)")
            elif sl - f1 > 8.0 + EPS:
                fail(2, "seats_lines-free %.2f (R12 bar <= 8.00)" % (sl - f1))
            if dn is not None and dn > 183.0 + EPS:
                fail(0, "done %.2f (R12 bar <= 183.00)" % dn)
        else:
            info.append("30 fps run: recorded only (R12 needs --fps30)")
        return reasons, info
    if base is None:
        if opts["base"]:
            fail(3, "no base log %s in %s" % (ref_name(name), opts["base"]))
        return reasons, info

    def delta(key, ref=None):
        ref = ref or base
        a, b = run.get(key), ref.get(key)
        if a is None or b is None:
            return None
        return a - b

    def within(key, lo, hi, rule, pri=4, what=None, ref=None):
        """lo/hi: bounds on the delta (None = open). Missing -> fail."""
        ref = ref or base
        if ref.get(key) is None:
            return
        if run.get(key) is None:
            fail(pri, "%s missing (%s)" % (key, rule))
            return
        dd = run.get(key) - ref.get(key)
        if (lo is not None and dd < lo - EPS) or (hi is not None and dd > hi + EPS):
            fail(pri, "%s %s%s (%s bar %s)" % (key, fmt_d(dd), (" " + what) if what else "", rule, bar_txt(lo, hi)))

    def offset_within(key, anchor, lo, hi, rule, pri=4):
        if base.get(key) is None or base.get(anchor) is None:
            return
        if run.get(key) is None:
            fail(pri, "%s missing (%s)" % (key, rule))
            return
        if run.get(anchor) is None:
            return  # the anchor's own rule reports it
        dd = (run.get(key) - run.get(anchor)) - (base.get(key) - base.get(anchor))
        if (lo is not None and dd < lo - EPS) or (hi is not None and dd > hi + EPS):
            fail(pri, "%s %s after %s (%s bar %s)" % (key, fmt_d(dd), anchor, rule, bar_txt(lo, hi)))

    # ---- R2: intro .. waiter_lines within +-1.5 s of base
    keys = [k for k, _, _ in base.order]
    if "intro" in base.idx and "waiter_lines" in base.idx:
        for k in keys[base.idx["intro"]:base.idx["waiter_lines"] + 1]:
            within(k, -1.5, 1.5, "R2", pri=5)
    # ---- R3: waiter_done in [base-3, base+1.5]; tap_staff and hire_waiter present
    within("waiter_done", -3.0, 1.5, "R3", pri=3)
    for k in ("tap_staff", "hire_waiter"):
        if run.get(k) is None:
            fail(3, "%s missing (R3)" % k)
    # ---- R4: first free in [base-3, base+1.5]
    within("free", -3.0, 1.5, "R4", pri=3)
    # ---- R5: seats_lines - first free in [0, 8]
    f1, sl = run.get("free"), run.get("seats_lines")
    bf1, bsl = base.get("free"), base.get("seats_lines")
    base_seats_off = (bsl - bf1) if (bf1 is not None and bsl is not None) else None
    if f1 is not None and sl is not None:
        off = sl - f1
        hi = 8.0
        why = ""
        # Before C4.1 (no fill line, and the meter not revealed by the first free: the 0.3.7 to wave-2
        # Director): a seed whose base beat already lands later than free + 8 s (EN 3, EN 4) keeps its own
        # base offset + 1.5 s (notes W0-QA). From wave 3 on every log is barred at 8 s, also when a natural
        # line beats the fill and no fill line is printed (W3-FIX-tut handoff 2, W4-NUM).
        if not d["c41"] and base_seats_off is not None and base_seats_off > 8.0:
            hi = base_seats_off + 1.5
            why = ", no seats fill yet: base %.2f + 1.50" % base_seats_off
        if off < -EPS or off > hi + EPS:
            fail(3, "seats_lines-free %.2f (R5 bar 0..%.2f%s)" % (off, hi, why))
    elif sl is None:
        fail(3, "seats_lines missing (R5)")
    # ---- R6: tap_table, add_table, seats_done, second free: offsets from seats_lines
    for k in ("tap_table", "add_table", "seats_done", "free#2"):
        s = S if k in ("seats_done", "free#2") else 0.0
        offset_within(k, "seats_lines", -1.5, 1.5 + s, "R6")
    # ---- R7: ad_deal <= base + 3 and after the second free
    within("ad_deal", None, 3.0 + S, "R7", pri=3)
    if run.get("ad_deal") is not None and run.get("free#2") is not None:
        if run.idx["ad_deal"] < run.idx["free#2"] or run.get("ad_deal") < run.get("free#2") - EPS:
            fail(3, "ad_deal %.2f before the second free %.2f (R7)" % (run.get("ad_deal"), run.get("free#2")))
    elif run.get("ad_deal") is not None and base.get("free#2") is not None:
        fail(3, "no second free before ad_deal (R7)")
    # ---- R8: every step after ad_deal: offset from ad_deal within +-1.5 s of base
    if "ad_deal" in base.idx:
        for k in keys[base.idx["ad_deal"] + 1:]:
            if run.get(k) is None and k.split("#")[0] in NO_AD_STEPS:
                continue  # the no-ad path
            offset_within(k, "ad_deal", None if nofill else -1.5, 1.5 + S, "R8", pri=0 if k == "done" else 4)
    # ---- R9: done
    if base_seats_off is not None and base_seats_off > 8.0:
        lo9 = -20.0
    else:
        lo9 = -3.0
    within("done", None if nofill else lo9, 3.0 + S, "R9", pri=0)
    # ---- R10: cash at done; done state chai L12
    if not nofill and run.cash.get("done") is not None and base.cash.get("done") is not None:
        dc = run.cash["done"] - base.cash["done"]
        # Lead decision after gate 1: EN 3 and EN 4 (base seats beat later than free + 8 s) keep the
        # travellers 0.3.7 lost once the door line is lossless, so they may end with up to three more sales.
        hi10 = 5.31 if (base_seats_off is not None and base_seats_off > 8.0) else 1.77
        if dc < -1.77 - EPS or dc > hi10 + EPS:
            fail(2, "cash at done %.2f %s (R10 bar %s of %.2f)" % (run.cash["done"], fmt_d(dc), bar_txt(-1.77, hi10), base.cash["done"]))
    # Dhaba growth step 4 (7 Nov): the tutorial reloads into the shack, whose floor starts empty, so the
    # scripted free-play LEVEL UPs may be skipped for cash: L10 to L12.
    if d["done_state_chai"] is not None and not (10 <= d["done_state_chai"] <= 12):
        fail(2, "done state chai L%d (R10 wants L10-L12)" % d["done_state_chai"])
    # ---- R11: against the previous gate's baseline
    if prev is not None:
        allow = opts["allow"]
        from_i = None
        for a in allow:
            if a.endswith("+") and a[:-1] in run.idx:
                i = run.idx[a[:-1]]
                from_i = i if from_i is None else min(from_i, i)
        # Lead decision after gate 1: when the prev baseline still has this seed's seats beat later than
        # free + 8 s and this run brings it within free + 8 s (the move plan 6.3 expects), R11 skips
        # seats_lines and every later step; R5 to R9 hold them against the base.
        pf1, psl = prev.get("free"), prev.get("seats_lines")
        if (pf1 is not None and psl is not None and psl - pf1 > 8.0 and f1 is not None and sl is not None
                and sl - f1 <= 8.0 + EPS and "seats_lines" in run.idx):
            i = run.idx["seats_lines"]
            from_i = i if from_i is None else min(from_i, i)
            info.append("R11 skips seats_lines+ (seats beat moved in from prev free + %.2f)" % (psl - pf1))
        sd = run.idx.get("seats_done")
        for k, tt, _ in run.order:
            if prev.get(k) is None:
                continue
            base_name = k.split("#")[0]
            if "all" in allow or k in allow or base_name in allow or (from_i is not None and run.idx[k] >= from_i):
                continue
            tol = 2.0 if k == "done" else 1.5
            s = S if (sd is not None and run.idx[k] >= sd) else 0.0
            dd = tt - prev.get(k)
            if dd < -tol - EPS or dd > tol + s + EPS:
                fail(1 if k == "done" else 6, "%s %s vs prev (R11 bar %s)" % (k, fmt_d(dd), bar_txt(-tol, tol + s)))
    elif opts["prev"]:
        info.append("no prev log %s: R11 skipped" % ref_name(name))
    return reasons, info


def cell(run, key, base, prev, cash=False):
    def val(r):
        if r is None:
            return None
        return r.cash.get(key) if cash else r.get(key)
    v = val(run)
    if v is None:
        return "-"
    out = "%.2f" % v
    b, p = val(base), val(prev)
    out += " b" + (fmt_d(v - b) if b is not None else "-")
    out += " p" + (fmt_d(v - p) if p is not None else "-")
    return out


def beats_of(logdir):
    out = {}
    for fn in sorted(os.listdir(logdir)):
        if not (fn.startswith("tut_") and fn.endswith(".log")):
            continue
        d = parse_log(os.path.join(logdir, fn))
        r = Run(fn[:-4], d)
        times = {}
        cash = {}
        for name, tt, c in d["steps"]:
            times.setdefault(name, []).append(tt)
            cash.setdefault(name, []).append(c)
        out[fn[:-4]] = {
            "times": times,
            "cash": cash,
            "steps": [[n, tt, c] for n, tt, c in d["steps"]],
            "done": r.get("done"),
            "cash_done": r.cash.get("done"),
            "quit_step": d["quit_step"],
            "home_check": d["home_check"],
            "done_state_chai": d["done_state_chai"],
        }
    return out


def main(argv):
    ap = argparse.ArgumentParser(prog="tutcheck.py", add_help=True)
    ap.add_argument("logdir")
    ap.add_argument("--base", default=None)
    ap.add_argument("--prev", default=None)
    ap.add_argument("--allow-move", default="")
    ap.add_argument("--slack", type=float, default=0.0)
    ap.add_argument("--fps30", action="store_true")
    ap.add_argument("--write-beats", default=None)
    a = ap.parse_args(argv)
    opts = {"base": a.base or None, "prev": a.prev or None, "slack": a.slack, "fps30": a.fps30,
            "write": a.write_beats, "allow": [x.strip() for x in a.allow_move.split(",") if x.strip()]}
    if not os.path.isdir(a.logdir):
        print("tutcheck: no such log dir %s" % a.logdir, file=sys.stderr)
        return 2
    pos = [a.logdir]
    logdir = pos[0]
    if opts["write"]:
        b = beats_of(logdir)
        with open(opts["write"], "w") as f:
            json.dump({"format": 1, "source": os.path.abspath(logdir), "logs": b}, f, indent=1, sort_keys=True)
        print("TUTCHECK beats: %d logs -> %s" % (len(b), opts["write"]))
    names = []
    for fn in sorted(os.listdir(logdir)):
        if fn.endswith(".log") and fn.split("_")[0] in ("tut", "fps30", "consent", "nofill"):
            names.append(fn[:-4])
    base = RefDir(opts["base"]) if opts["base"] else None
    prev = RefDir(opts["prev"]) if opts["prev"] else None
    print("TUTCHECK dir=%s base=%s prev=%s allow-move=%s slack=%.2f fps30=%s logs=%d" % (
        logdir, opts["base"] or "-", opts["prev"] or "-", ",".join(opts["allow"]) or "-", opts["slack"],
        "yes" if opts["fps30"] else "no", len(names)))
    fails = 0
    rows = []
    for n in names:
        run = Run(n, parse_log(os.path.join(logdir, n + ".log")))
        rn = ref_name(n)
        b = base.run(rn) if (base and rn) else None
        p = prev.run(rn) if (prev and rn) else None
        is30 = opts["fps30"] or n.startswith("fps30_")
        reasons, info = check_run(run, None if is30 else b, None if is30 else p, opts)
        reasons.sort(key=lambda r: r[0])
        if reasons:
            fails += 1
            print("TUTCHECK %s FAIL %s" % (n, "; ".join(r[1] for r in reasons)))
        else:
            print("TUTCHECK %s PASS%s" % (n, (" (" + "; ".join(info) + ")") if info else ""))
        if is30:
            b = p = None
        rows.append((n, run, b, p))
    print("%-14s %-28s %-28s %-28s %-28s %-28s" % ("log", "done", "waiter_done", "seats_lines", "line7", "cash@done"))
    for n, run, b, p in rows:
        print("%-14s %-28s %-28s %-28s %-28s %-28s" % (
            n, cell(run, "done", b, p), cell(run, "waiter_done", b, p), cell(run, "seats_lines", b, p),
            cell(run, "line7", b, p), cell(run, "done", b, p, cash=True)))
    print("  (b = delta against --base, p = delta against --prev, seconds; cash in reference units)")
    print("TUTCHECK fails=%d" % fails)
    return min(fails, 255)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
