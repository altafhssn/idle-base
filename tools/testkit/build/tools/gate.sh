#!/bin/bash
# Integration gate (build plan 6.4; checks of 6.2). W0-QA.
# Usage: [env] gate.sh N        N = 0 (dry run: G-suite only, untouched tree), 1 (W1-INT), 2 (W2-INT), 4 (W4-QA)
#
# Order: savecheck; slot gate<N> from the tree (mkslot.sh + import.sh); then, all at once in the background
# (the machine-wide Godot lock of run.sh / gdtest.sh lets 4 Godot processes run): the full suite
# (PREV_BASE = the previous gate's baseline) and every check of 6.2 whose Gates column holds N, each in its own
# sub-slot gate<N>__c_<check> cloned from the gate slot. Then $Q/logs/gate<N>/gate.txt:
#   GATE <N> <id> PASS|FAIL|SKIP <detail>     (one line per check, in the order of 6.2)
#   GATE <N> fails=<n>
#   GATE <N> skips=<m>
# savecheck again; on fails=0 the suite's tut_*.log and a fresh beats.json go to $Q/logs/baseline_wave<N>/;
# the sub-slots gate<N>__* are deleted. Progress goes to stderr. Exit code = fails (at most 255).
#
# Environment:
#   GATE_SRC   the tree to gate (default the real project; gate 0: $B/snap/wave1, the untouched 0.3.7)
#   PREV_BASE  the previous gate's baseline for tutcheck R11 (default: gate 0/1 $Q/logs/baseline,
#              gate 2 $Q/logs/baseline_wave1, gate 4 $Q/logs/baseline_wave2)
#   ALLOW_MOVE steps exempt from R11 (gate 4: W3-TUT's list), passed to suite.sh
#   GATE_ONLY  "G-a,G-b": run only these checks (a partial gate never writes baseline_wave<N>)
#   GATE_TAG   slot and log name instead of gate<N> (test runs; never writes baseline_wave<N>)
#   GATE_DRY=1 never write baseline_wave<N>
#   HINDI_FROZEN=1 G-strings reports SKIP with check_po's counts (lead decision 10: Hindi waits for the final English)
#   GATE_LIMIT per-run time limit in s (default 900; starts after the Godot lock wait)
# Deviation: G-sign adds --stats=120 (the 0.3.7 main3 ticks the [window] only while --stats is on).
# Lead decision 11 (2 Nov, gate 4): G-sign runs --no-notes with ROADCAP + 12 galla levels; G-realized and G-reno-reach
#                 use their own ROADCAP --no-notes level-0 runs (see j_sign).
# Lead decisions after gate 1 (plan, 1 Nov; applied by W1-BARS, notes $B/notes/W1-BARS.md):
#   G-reno-reach  warm takings: cash gained between the [stats] lines at 120 s and 600 s (up to 1 s late) of the
#                 level-0 G-sign runs, per minute, mean of seeds 1-4, x 7 >= 10,000; a buy or reward line between
#                 the two fails it; the cold [window] 0-600 s takings x 7 is printed as information.
#   G-trays       waiter-bound at the margin: 1 waiter, --reno-ready (all four counters), 3 cooks each, 5 tables,
#                 2 cashiers, --arrivals=$TRAY_ARR; tray 1 and tray 2 on seeds 1-4. Bars: mean tray-2 trip orders
#                 >= 1 + waiters.tray_batch_est - 0.1; mean tray-2 food wait <= mean tray-1 food wait; conservation
#                 in all 8 logs. Information: the measured est, a scenario guard (tray-1 lowest capacity waiters,
#                 food wait < 40 s; "SCENARIO DRIFT" when not), the plan's first scenario on seed 1.
#   Seeds         G-hall-natural, G-hall-built: seeds 1-4, the bar on every seed; G-lossless, G-held: --seed=1.
# gdtest checks read optional header lines in the test script (GDScript comments):
#   # GATE_ARGS: <game args>   one run per line (default: the args of 6.2 / the lead's notes)
#   # GATE_SAVE: <fixture>     putsave.sh before each run (a path, or a name in $B/fixtures)
#   # GATE_LIMIT: <s>          time limit per run (default 300)
# A missing test script prints SKIP with "missing <path>".
Q=${DR_WORK:-$HOME/DhabaRushQA}/qa
B=${DR_WORK:-$HOME/DhabaRushQA}/build
S=${DR_WORK:-$HOME/DhabaRushQA}
P2=$B/proto2
R=/Users/almeer/Documents/HighwayDhaba
PY=/Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13
unset FIXED   # every run at --fixed-fps 60 unless a check says otherwise

N="$1"
case "$N" in 0|1|2|4) ;; *) echo "usage: gate.sh N   (N = 0, 1, 2 or 4)" >&2; exit 2;; esac
SLOT="${GATE_TAG:-gate$N}"
OUT="$Q/logs/$SLOT"; CK="$OUT/checks"; RES="$CK/res"
LIMIT="${GATE_LIMIT:-900}"
if [ -n "$GATE_SRC" ]; then SRC="$GATE_SRC"; elif [ "$N" = 0 ]; then SRC="$B/snap/wave1"; else SRC="$R"; fi
case "$N" in 0|1) DEFPREV="$Q/logs/baseline";; 2) DEFPREV="$Q/logs/baseline_wave1";; 4) DEFPREV="$Q/logs/baseline_wave2";; esac
PREV="${PREV_BASE:-$DEFPREV}"
T0=$(date +%s)
say() { echo "[gate$N $(date +%T)] $*" >&2; }

ALL_CHECKS="G-suite G-promo G-tap-hall G-zoom-hall G-layout G-hall-natural G-hall-built G-old-saves G-resume
 G-roundtrip G-lossless G-road G-held G-trays G-dispatch G-sign G-realized G-reno-reach G-hire-rate G-table-line
 G-fill G-fans G-special-unit G-special-game G-event-unit G-event-game G-event-pace G-delegation G-offers
 G-consent G-budget G-nofill G-fps30 G-strings G-hindi-promo G-pacing"
gates_of() {
  case "$1" in
    G-suite) echo "0 1 2 4";;
    G-road|G-hire-rate|G-fans|G-event-game|G-event-pace) echo "2 4";;
    G-dispatch|G-sign|G-realized|G-reno-reach|G-pacing) echo "1 4";;
    G-strings|G-hindi-promo) echo "4";;
    *) echo "1 2 4";;
  esac
}
CHECKS=""
for c in $ALL_CHECKS; do
  case " $(gates_of "$c") " in *" $N "*) ;; *) continue;; esac
  if [ -n "$GATE_ONLY" ]; then case ",$GATE_ONLY," in *",$c,"*) ;; *) continue;; esac; fi
  CHECKS="$CHECKS $c"
done
want() { case " $CHECKS " in *" $1 "*) return 0;; esac; return 1; }

# ---------------------------------------------------------------- start
out_save=$("$Q/savecheck.sh" 2>&1)
if [ "$out_save" != "SAVE OK" ]; then say "$out_save: stop"; echo "GATE $N savecheck FAIL $out_save"; exit 1; fi
say "tree $SRC -> slot $SLOT; checks:$CHECKS; prev $PREV"
mkdir -p "$OUT"; rm -rf "$CK"; rm -f "$OUT/gate.txt" "$OUT/gate_time.txt"; mkdir -p "$RES"
rm -rf "$Q/slots/${SLOT}__"*
"$Q/mkslot.sh" "$SLOT" "$SRC" > "$CK/mkslot.txt" 2>&1 || { say "mkslot failed"; cat "$CK/mkslot.txt" >&2; exit 1; }
"$Q/import.sh" "$SLOT" > "$CK/import.txt" 2>&1
say "slot ready: $(head -1 "$CK/import.txt")"
PROJ="$Q/slots/$SLOT/proj"

# ---------------------------------------------------------------- evaluator (log reading, one result line per check)
EV="$CK/gate_eval.py"
cat > "$EV" <<'PYEOF'
import ast, json, os, re, sys
Q, BASEDIR = sys.argv[1], sys.argv[2]
check, N = sys.argv[3], int(sys.argv[4])
A = sys.argv[5:]

def bn(p): return os.path.basename(p)
def rd(p):
    try: return open(p, errors="replace").read()
    except Exception: return None
def done(status, detail):
    print("%s %s" % (status, " ".join(str(detail).split())[:900])); sys.exit(0)
def health(p):
    t = rd(p)
    if t is None: return "", "no log %s" % bn(p)
    rc = (re.findall(r"^rc=(-?\d+)", t, re.M) or ["?"])[-1]
    se = re.search(r"SCRIPT ERROR[^\n]*(\n[^\n]*)?", t)
    if se: return t, "%s: %s" % (bn(p), se.group(0).replace("\n", " | ")[:200])
    if rc != "0": return t, "%s: rc=%s%s" % (bn(p), rc, " (time limit hit)" if rc == "142" else "")
    return t, None
def logs_ok(paths):
    ts, errs = [], []
    for p in paths:
        t, e = health(p); ts.append(t)
        if e: errs.append(e)
    return ts, errs
def cons(t, name):
    m = re.findall(r"^\[sim\] conservation arrived (\d+) paid (\d+) inside (\d+) left_unpaid (\d+) drove_past (\d+)", t, re.M)
    if not m: return None, "%s: no '[sim] conservation' line" % name
    a, p, i, u, d = map(int, m[-1])
    if u != 0: return (a, p, i, u, d), "%s: conservation left_unpaid %d" % (name, u)
    if a != p + i + u: return (a, p, i, u, d), "%s: conservation arrived %d != paid %d + inside %d + left_unpaid %d" % (name, a, p, i, u)
    return (a, p, i, u, d), None
def window(t):
    m = re.findall(r"^\[window\] \d+ s after start[^\n]*", t, re.M)
    return m[-1] if m else None
def fnum(rx, s, cast=float):
    m = re.search(rx, s or "")
    return cast(m.group(1)) if m else None
def last_field(t, rx, cast=float):
    m = re.findall(rx, t, re.M)
    if not m: return None
    v = m[-1]
    return tuple(cast(x) for x in v) if isinstance(v, tuple) else cast(v)
def mean(xs): return sum(xs) / len(xs) if xs else float("nan")
def mmss(s):
    m = re.match(r"(\d+):(\d+(?:\.\d+)?)", str(s))
    return int(m.group(1)) * 60 + float(m.group(2)) if m else None
def fmt_mmss(x): return "%d:%05.2f" % (int(x // 60), x - 60 * int(x // 60))
def stats_times(t):
    """(line index, game time) of every main [stats] line."""
    out = []
    for i, l in enumerate(t.split("\n")):
        m = re.match(r"^\[stats\] ([\d.]+) ", l)
        if m: out.append((i, float(m.group(1))))
    return out
def bracket(st, idx):
    lo = max([tt for i, tt in st if i < idx] or [0.0]); his = [tt for i, tt in st if i > idx]
    return lo, (min(his) if his else None)
def first_idx(t, rx):
    for i, l in enumerate(t.split("\n")):
        if re.search(rx, l): return i
    return None

# ------------------------------------------------------------------------------------------------ checks
if check == "suite":
    out = A[0]
    summ, tc = rd(os.path.join(out, "summary.txt")), rd(os.path.join(out, "tutcheck.txt"))
    bad = []
    if summ is None: done("FAIL", "no summary.txt (suite did not finish)")
    if not re.search(r"^RESULT: PASS", summ, re.M):
        bad.append((re.findall(r"^RESULT:[^\n]*", summ, re.M) or ["no RESULT line"])[-1])
        bad += ["[" + l[6:] + "]" for l in re.findall(r"^FAIL: [^\n]*", summ, re.M)[:6]]
    tf = re.findall(r"^TUTCHECK fails=(\d+)", tc or "", re.M)
    if not tf: bad.append("no TUTCHECK fails= line in tutcheck.txt")
    elif tf[-1] != "0":
        bad.append("TUTCHECK fails=%s" % tf[-1])
        bad += ["[" + l[9:200] + "]" for l in re.findall(r"^TUTCHECK \S+ FAIL[^\n]*", tc, re.M)[:5]]
    tuts = sorted(f for f in os.listdir(out) if f.startswith("tut_") and f.endswith(".log"))
    if len(tuts) < 5: bad.append("only %d tutorial logs (want tut_en_s1..4, tut_hi_s1)" % len(tuts))
    dones, cn = [], 0
    for f in tuts:
        t = rd(os.path.join(out, f))
        d = re.findall(r"^\[auto\] ([\d.]+) step -> done", t, re.M)
        dones.append("%s %s" % (f[4:-4], d[0] if d else "-"))
        has = re.search(r"^\[sim\] conservation ", t, re.M)
        if N >= 1 or has:
            c, e = cons(t, f[:-4])
            if e: bad.append(e)
            else: cn += 1
    if bad: done("FAIL", "; ".join(bad))
    done("PASS", "RESULT: PASS, TUTCHECK fails=0, done %s; conservation %s" % (
        ", ".join(dones), ("left_unpaid 0 in %d logs" % cn) if cn else "not printed (0.3.7 Sim)"))

if check == "promo":   # A: log [hindi]
    hindi = len(A) > 1 and A[1] == "hi"
    ts, errs = logs_ok(A[:1]); t = ts[0]
    pf = last_field(t, r"^PROMOCHECK fails=(\d+)", int)
    rows = re.findall(r"^PROMOCHECK (\S+) (\S+) (ok|FAIL|SKIP)\b", t, re.M)
    phases = {}
    for ph, nm, st in rows: phases.setdefault(ph, {"ok": 0, "FAIL": 0, "SKIP": 0})[st] += 1
    if pf is None: errs.append("no 'PROMOCHECK fails=' line")
    elif pf: errs.append("PROMOCHECK fails=%d: %s" % (pf, "; ".join("%s %s" % (a, b) for a, b, c in rows if c == "FAIL")[:300]))
    okp = [p for p in phases if phases[p]["ok"] > 0]
    if len(okp) < 3: errs.append("phases with ok lines: %s (want 3)" % (",".join(sorted(okp)) or "none"))
    sk = [("%s %s" % (a, b)) for a, b, c in rows if c == "SKIP"]
    if sk: errs.append("%d SKIP (missing API): %s" % (len(sk), ", ".join(sk[:8])))
    if hindi and "Rect2i size is negative" in t: errs.append("'Rect2i size is negative' in the log")
    summ = " ".join("phase %s %d ok" % (p, phases[p]["ok"]) for p in sorted(phases))
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "PROMOCHECK fails=0, %s%s" % (summ, ", no Rect2i error" if hindi else ""))

if check == "taphall":
    ts, errs = logs_ok(A[:1]); t = ts[0]
    tf = last_field(t, r"^TAPCHECK fails=(\d+)", int)
    if tf is None: errs.append("no 'TAPCHECK fails=' line")
    elif tf: errs.append("TAPCHECK fails=%d: %s" % (tf, "; ".join(re.findall(r"^TAPCHECK (\S+ \S+ want=\S+ got=\S+) FAIL", t, re.M)[:6])))
    want = {"hall_ghost_waiter": "quick:waiters", "hall_waiter4": "staff:waiters"}
    for i in range(2, 8): want["table%d_top" % i] = "daftar"
    rows = re.findall(r"^TAPCHECK (\S+) (\S+) want=(\S+) got=(\S+) (PASS|FAIL)", t, re.M)
    got = []
    for lab, w in want.items():
        mine = [r for r in rows if r[1] == lab]
        if not any(r[4] == "PASS" and r[2] == w for r in mine):
            errs.append("%s: no PASS with want=%s (%s)" % (lab, w, ", ".join("%s want=%s got=%s %s" % (r[0], r[2], r[3], r[4]) for r in mine) or "no line"))
        else: got.append(lab)
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "TAPCHECK fails=0; stage E PASS: %s" % ", ".join(got))

if check == "zoom":
    ts, errs = logs_ok(A[:1]); t = ts[0]
    zf = last_field(t, r"^ZOOMTEST fails=(\d+)", int)
    if zf is None: errs.append("no 'ZOOMTEST fails=' line")
    elif zf: errs.append("ZOOMTEST fails=%d: %s" % (zf, "; ".join(re.findall(r"^ZOOMTEST (\S+) FAIL[^\n]*", t, re.M)[:5])))
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "ZOOMTEST fails=0")

if check == "gdtest":   # A: TAG kind logs...
    tag, kind, paths = A[0], A[1], A[2:]
    ts, errs = logs_ok(paths)
    det = []
    for p, t in zip(paths, ts):
        f = last_field(t, r"^%s fails=(\d+)" % tag, int)
        if f is None: errs.append("%s: no '%s fails=' line" % (bn(p), tag))
        elif f: errs.append("%s: %s fails=%d (%s)" % (bn(p), tag, f, "; ".join(re.findall(r"^FAIL[^\n]*", t, re.M)[:4])))
        else: det.append("%s fails=0" % tag)
    allt = "\n".join(ts)
    if kind == "layout":
        g = [float(x) for x in re.findall(r"^SEATSBOARD glyph ([\d.]+) px", allt, re.M)]
        if not g: errs.append("no 'SEATSBOARD glyph <px> px' line")
        elif min(g) < 16: errs.append("SEATSBOARD glyph %.1f px < 16" % min(g))
        props = dict(re.findall(r"^PROP (\w+) home (\([-\d., ]+\))", allt, re.M))
        miss = [p for p in ("GATE_BOARD", "TV", "DOG_SIT", "SHAADI_GATE") if p not in props]
        if miss: errs.append("no PROP line for %s" % ", ".join(miss))
        det.append("SEATSBOARD glyph %s px" % ("%.1f" % min(g) if g else "-"))
        det.append("PROP " + " ".join("%s %s" % kv for kv in sorted(props.items())))
    if kind == "hire":
        j = re.findall(r"^\[sim\] waiter 2 joins: takes the oldest order \(waited ([\d.]+) s\)", allt, re.M)
        r = re.findall(r"^\[hud\] rate ([\d.]+) -> ([\d.]+) in ([\d.]+)", allt, re.M)
        if not j: errs.append("no '[sim] waiter 2 joins: takes the oldest order' line")
        if not r: errs.append("no '[hud] rate <a> -> <b> in <s>' line")
        elif not any(float(b) > float(a) and float(s) <= 3.0 for a, b, s in r):
            errs.append("rate lines without b > a and s <= 3: %s" % r[:3])
        det.append("joins waited %s s, rate %s" % (j[:1], r[:1]))
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "%d run(s): %s" % (len(paths), "; ".join(det)))

if check == "hall":   # A: kind(natural|built) log_s1 [log_s2 ...]  (lead decision 5: seeds 1-4, the bar on every seed)
    kind, paths = A[0], A[1:]
    ts, herrs = logs_ok(paths)
    errs, rows = list(herrs), []
    for p, t in zip(paths, ts):
        sd = (re.findall(r"_s(\d+)\.log$", p) or ["?"])[0]
        e1, det = [], []
        if t:
            hs = last_field(t, r"hall seated (\d+) \(([\d.]+)%\)")
            hf = last_field(t, r"hall food ([\d.]+|-)\s*s?\s*\|?\s*road food ([\d.]+|-)", str)
            c, e = cons(t, bn(p))
            if e: e1.append(e)
            if hs is None: e1.append("no 'hall seated <n> (<p>%)' in [stats]")
            else:
                det.append("hall %d (%.1f%%)" % (hs[0], hs[1]))
                if hs[1] < 25.0: e1.append("hall seated share %.1f%% < 25%%" % hs[1])
            if kind == "natural":
                if hf is None or "-" in hf: e1.append("no numeric 'hall food <s> road food <s>' in [stats] (%s)" % (hf,))
                else:
                    h, r = float(hf[0]), float(hf[1]); det.append("food hall %.1f road %.1f (x%.2f)" % (h, r, h / r if r else float("inf")))
                    if h > 1.5 * r: e1.append("hall food %.1f > 1.5 x road food %.1f" % (h, r))
                if N in (2, 4) and not re.search(r"^\[hud\] meter: limit waiters", t, re.M): e1.append("no '[hud] meter: limit waiters'")
            else:
                age = last_field(t, r"^\[sim\] max ticket age ([\d.]+)")
                if age is None: e1.append("no '[sim] max ticket age' line")
                else:
                    det.append("max ticket age %.1f" % age)
                    if age > 60: e1.append("max ticket age %.1f > 60" % age)
            if c: det.append("cons %s" % "/".join(map(str, c)))
        errs += ["seed %s: %s" % (sd, x) for x in e1]
        rows.append("s%s %s" % (sd, " ".join(det) if det else "-"))
    if len(paths) < 4: errs.append("%d seed log(s) (want seeds 1-4)" % len(paths))
    if errs: done("FAIL", "; ".join(errs) + " | " + "; ".join(rows))
    done("PASS", "every seed: " + "; ".join(rows))

if check == "oldsaves":   # A: fixture log fixture log ...
    errs, det = [], []
    for fx, p in zip(A[0::2], A[1::2]):
        t, e = health(p)
        if e: errs.append(e); continue
        d = json.load(open(fx)); tut = d.get("tutorial", {}); st = d.get("stations", {})
        def lv(i):
            s = st.get(i) or {}
            return str(int(s.get("level", 1))) if s.get("built") else "-"
        exp = {"tutorial": "done" if tut.get("done") else "running (%s)" % tut.get("step", ""),
               "renovations": "0", "location": "nh44",
               "levels": "chai:%s tandoor:%s lassi:%s kadai:%s" % (lv("chai"), lv("tandoor"), lv("lassi"), lv("kadai")),
               "waiters": str(len(d.get("waiters", []))), "tables": str(int(d.get("tables", 0))),
               "gallas": str(len(d.get("gallas", [])))}
        ll = re.findall(r"^\[game\] loaded save: ([^\n]*)", t, re.M)
        name = bn(fx).replace("save_037_", "").replace(".json", "")
        if not ll: errs.append("%s: no '[game] loaded save:' line" % name); continue
        fields = {}
        for part in ll[0].split(" | "):
            k, _, v = part.strip().partition(" ")
            fields[k] = v.strip()
        wrong = ["%s '%s' want '%s'" % (k, fields.get(k), v) for k, v in exp.items() if fields.get(k) != v]
        if wrong: errs.append("%s: %s" % (name, "; ".join(wrong)))
        if re.search(r"starting fresh", t): errs.append("%s: 'starting fresh' in the log" % name)
        if "late" in name and N in (2, 4) and not re.search(r"^\[ui\] build rows:[^\n]*family_dhaba unlocked", t, re.M):
            errs.append("late: no '[ui] build rows: ... family_dhaba unlocked'")
        det.append("%s ok (%s | %s)" % (name, exp["tutorial"], exp["levels"]))
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "; ".join(det))

if check == "resume":   # A: waiter_log free_log
    ts, errs = logs_ok(A[:2]); det = []
    for p, t in zip(A[:2], ts):
        dn = re.findall(r"^\[auto\] ([\d.]+) step -> done", t, re.M)
        q = re.findall(r"^\[main3\] quit at game time [\d.]+ \(tutorial step: (\w+)\)", t, re.M)
        if not dn: errs.append("%s: no 'step -> done'" % bn(p))
        if not q or q[-1] != "done": errs.append("%s: quit line %s" % (bn(p), q[-1:] or "missing"))
        det.append("%s done %s" % (bn(p)[:-4], dn[0] if dn else "-"))
    if N == 4:
        if not re.search(r"^\[tutorial\] waiter beat: hired via card", ts[0], re.M): errs.append("tut_waiter: no '[tutorial] waiter beat: hired via card'")
        if not re.search(r"^\[auto\] [\d.]+ step -> seats_done", ts[1], re.M): errs.append("tut_free: no 'step -> seats_done'")
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", ", ".join(det))

if check == "roundtrip":   # A: log1 log2
    ts, errs = logs_ok(A[:2])
    ll = re.findall(r"^\[game\] loaded save: ([^\n]*)", ts[1], re.M)
    if not ll: errs.append("second run: no '[game] loaded save:' line")
    else:
        f = {p.strip().partition(" ")[0]: p.strip().partition(" ")[2].strip() for p in ll[0].split(" | ")}
        if f.get("renovations") != "1": errs.append("second load: renovations '%s' want '1'" % f.get("renovations"))
        if f.get("tables") != "3": errs.append("second load: tables '%s' want '3'" % f.get("tables"))
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "second load: renovations 1, tables 3")

if check in ("lossless", "road"):
    p = A[0]; ts, errs = logs_ok([p]); t = ts[0]
    if check == "lossless":
        c, e = cons(t, bn(p))
        if e: errs.append(e)
        dp = re.findall(r"^\[sim\] drove past: ", t, re.M)
        if not dp: errs.append("no '[sim] drove past:' line")
        dm = last_field(t, r"^\[sim\] door line max (\d+)", int)
        if dm is None:
            sm = [int(x) for x in re.findall(r"door max (\d+)", t)]
            dm = max(sm) if sm else None
        if dm is None: errs.append("no door line max")
        elif dm > 7: errs.append("door line max %d > 7" % dm)
        age = last_field(t, r"^\[sim\] max ticket age ([\d.]+)")
        if age is None: errs.append("no '[sim] max ticket age' line")
        elif age > 90: errs.append("max ticket age %.1f > 90" % age)
        if errs: done("FAIL", "; ".join(errs))
        done("PASS", "conservation %s, drove past %d, door max %d, max ticket age %.1f" % ("/".join(map(str, c)), len(dp), dm, age))
    lines = t.split("\n")
    alldp = [i for i, l in enumerate(lines) if l.startswith("[sim] drove past: ")]
    dpi = alldp[:3]
    if len(dpi) < 3: errs.append("only %d '[sim] drove past:' lines (want 3)" % len(dpi))
    det = []
    # W2-INT: each drive-past is judged by its own caption. The HUD prints its flash in the frame of
    # Sim.vehicle_drove_past, i.e. just before the Sim's own line, so the window runs from the previous
    # '[sim] drove past:' line to the next one (at most 40 lines each way); a caption past the next
    # drive-past belongs to that one. "Still up": the last '[hud] road:' line before it is that caption.
    for i in dpi:
        kind = (re.match(r"\[sim\] drove past: (\w+)", lines[i]) or [None, "?"])[1]
        def match(l): return l.startswith("[hud] road:") and "drove past: seats full" in l and kind.lower() in l.lower()
        k = alldp.index(i)
        lo = max(0, i - 40, alldp[k - 1] + 1 if k > 0 else 0)
        hi = min(len(lines), i + 41, alldp[k + 1] if k + 1 < len(alldp) else len(lines))
        before = [j for j in range(lo, i) if match(lines[j])]
        after = [j for j in range(i + 1, hi) if match(lines[j])]
        last_cap = next((lines[j] for j in range(i - 1, -1, -1) if lines[j].startswith("[hud] road:")), "")
        if before: det.append("%s: caption in the same frame (%d line(s) before)" % (kind, i - before[-1]))
        elif after: det.append("%s: caption %d lines later" % (kind, after[0] - i))
        elif match(last_cap): det.append("%s: caption already up" % kind)
        else: errs.append("%s at line %d: no '[hud] road: ... %s drove past: seats full' for this drive-past" % (kind, i + 1, kind))
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "; ".join(det) + " (logs carry no times: judged by log order)")

if check == "held":
    p = A[0]; ts, errs = logs_ok([p]); t = ts[0]
    h = [int(x) for x in re.findall(r"^\[station\] chai held (\d+)", t, re.M)]
    if not h: errs.append("no '[station] chai held <n>' line")
    else:
        i1 = next((i for i, x in enumerate(h) if x >= 1), None)
        if i1 is None: errs.append("chai held never >= 1")
        elif not any(x == 0 for x in h[i1 + 1:]): errs.append("chai held never back to 0 after %d" % h[i1])
    sh = [(int(a), int(b)) for a, b in re.findall(r"held (\d+) \(max (\d+)\)", t)]
    if not sh: errs.append("no 'held <n> (max <m>)' in [stats]")
    elif not any(a > 0 for a, b in sh): errs.append("[stats] held never > 0 (max %d)" % max(b for a, b in sh))
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "chai held max %d then 0; stats held max %d" % (max(h), max(a for a, b in sh)))

if check == "trays":   # A: eco.json tray2_s1..s4 tray1_s1..s4 [old_tray2 old_tray1]   (lead decision 4)
    eco, t2p, t1p, oldp = A[0], A[1:5], A[5:9], A[9:11]
    ts, errs = logs_ok(t2p + t1p)
    try: est = float(json.load(open(eco))["waiters"].get("tray_batch_est", 0.45)); src = "economy"
    except Exception: est, src = 0.45, "default"
    def trip_of(t):   # the scene-end '[sim] trip orders <x> (<n> trips)', else the last [stats] '| trip orders <x>'
        m = re.findall(r"^\[sim\] trip orders ([\d.]+) \((\d+) trips\)", t or "", re.M)
        if m: return float(m[-1][0])
        return last_field(t or "", r"\| trip orders ([\d.]+)")
    def fw_of(t): return fnum(r"food wait mean ([\d.]+) s", window(t or ""))
    def low_of(t):   # the lowest capacity of the last [stats] capacity line at or before the window's end (300 s)
        best, st = None, None
        for l in (t or "").split("\n"):
            m = re.match(r"^\[stats\] ([\d.]+) cash", l)
            if m: st = float(m.group(1)); continue
            m = re.search(r"capacity seats ([\d.]+) waiters ([\d.]+) stations ([\d.]+) gallas ([\d.]+)", l)
            if m and l.startswith("[stats]") and st is not None and st <= 301.0:
                v = dict(zip(("seats", "waiters", "stations", "gallas"), map(float, m.groups())))
                best = (min(v, key=v.get), v)
        return best
    for p, t in zip(t2p + t1p, ts):
        if t:
            c, e = cons(t, bn(p))
            if e: errs.append(e)
    to2 = [trip_of(t) for t in ts[:4]]; to1 = [trip_of(t) for t in ts[4:]]
    fw2 = [fw_of(t) for t in ts[:4]]; fw1 = [fw_of(t) for t in ts[4:]]
    if None in to2: errs.append("tray 2: no 'trip orders' on seed(s) %s" % [k + 1 for k, x in enumerate(to2) if x is None])
    if None in fw2 + fw1: errs.append("no [window] food wait mean (tray2 %s, tray1 %s)" % (fw2, fw1))
    m2 = mean([x for x in to2 if x is not None]); f2 = mean([x for x in fw2 if x is not None]); f1 = mean([x for x in fw1 if x is not None])
    if None not in to2 and m2 < 1 + est - 0.1 - 1e-9: errs.append("mean tray-2 trip orders %.3f < 1 + %.2f - 0.1" % (m2, est))
    if None not in fw2 + fw1 and f2 > f1 + 1e-9: errs.append("mean tray-2 food wait %.2f > mean tray-1 %.2f" % (f2, f1))
    sug = min(0.45, int((m2 - 1.0) / 0.05 + 1e-9) * 0.05) if m2 == m2 else float("nan")
    # Scenario guard (info, not a bar): the tray-1 runs must stay waiter-bound at the margin.
    lows = [low_of(t) for t in ts[4:]]
    nw = sum(1 for x in lows if x and x[0] == "waiters")
    scen = "scenario: tray-1 lowest capacity waiters on %d/4 seeds (%s /min), tray-1 mean food wait %.1f s (< 40)" % (
        nw, " ".join(("%.1f" % x[1]["waiters"]) if x and x[0] == "waiters" else ("%s %.1f" % (x[0], x[1][x[0]]) if x else "-") for x in lows), f1)
    if nw < 4 or not (f1 < 40.0): scen = "SCENARIO DRIFT (want waiters on 4/4 and < 40 s; re-pick --arrivals): " + scen
    det = "mean tray-2 trip orders %.3f (seeds %s) >= 1 + tray_batch_est %.2f (%s) - 0.1; measured est min(0.45, floor0.05(%.3f)) = %.2f; mean food wait tray2 %.2f (%s) <= tray1 %.2f (%s); tray-1 trip orders %s; %s" % (
        m2, " ".join("%.2f" % x if x is not None else "-" for x in to2), est, src, m2 - 1, sug,
        f2, " ".join("%.1f" % x if x is not None else "-" for x in fw2), f1, " ".join("%.1f" % x if x is not None else "-" for x in fw1),
        " ".join("%.2f" % x if x is not None else "-" for x in to1), scen)
    if len(oldp) == 2:   # the plan's first scenario (2 waiters, kitchen-bound, seed 1): info only
        ot, oe = logs_ok(oldp)
        if oe: det += "; old scenario (info): %s" % "; ".join(oe)
        else: det += "; old plan scenario (2 waiters, kitchen-bound, --arrivals=24, seed 1; info): tray-2 trip orders %.2f, food wait tray2 %s tray1 %s" % (trip_of(ot[0]) or 0.0, fw_of(ot[0]), fw_of(ot[1]))
    if errs: done("FAIL", "; ".join(errs) + " | " + det)
    done("PASS", det)

if check == "dispatch":   # A: g1..g4 b1..b4
    g, b = A[:4], A[4:8]
    ts, errs = logs_ok(g + b)
    gm, gx, bm, bx, hw = [], [], [], [], []
    for k in range(4):
        wg, wb = window(ts[k]), window(ts[4 + k])
        mg, xg = fnum(r"food wait mean ([\d.]+) s", wg), fnum(r"max ([\d.]+) s", wg)
        mb, xb = fnum(r"food wait mean ([\d.]+) s", wb), fnum(r"max ([\d.]+) s", wb)
        if None in (mg, xg, mb, xb): errs.append("seed %d: missing [window] food wait (gate %s/%s base %s/%s)" % (k + 1, mg, xg, mb, xb)); continue
        gm.append(mg); bm.append(mb)
        if xg > xb + 2.0 + 1e-9: errs.append("seed %d: max food wait %.1f > base %.1f + 2" % (k + 1, xg, xb))
        h = re.findall(r"^\[sim\] home walks (\d+) per (\d+) orders", ts[k], re.M)
        if not h: errs.append("seed %d: no '[sim] home walks' line" % (k + 1))
        else:
            n, o = map(int, h[-1]); hw.append("%d/%d" % (n, o))
            if not n < o / 2.0: errs.append("seed %d: home walks %d not < half of %d orders" % (k + 1, n, o))
    if len(gm) == 4 and mean(gm) > mean(bm) + 0.5 + 1e-9: errs.append("mean food wait %.2f > base %.2f + 0.5" % (mean(gm), mean(bm)))
    det = "mean food wait %.2f vs base %.2f; home walks %s" % (mean(gm), mean(bm), " ".join(hw))
    if errs: done("FAIL", "; ".join(errs) + " | " + det)
    done("PASS", det)

if check in ("sign", "realized", "renoreach"):   # A: l0 x4, l4 x4
    l0, l4 = A[:4], A[4:8]
    ts, errs = logs_ok(l0 + l4 if check == "sign" else l0)
    def arr(t): return fnum(r"arrivals \d+ = ([\d.]+)/min", window(t))
    if check == "sign":
        a0, a4 = [arr(t) for t in ts[:4]], [arr(t) for t in ts[4:]]
        if None in a0 + a4: done("FAIL", "; ".join(errs + ["missing [window] arrivals (L0 %s, L4 %s)" % (a0, a4)]))
        d = mean(a4) - mean(a0)
        det = "arrivals/min L4 %.2f - L0 %.2f = %+.2f (bar +4.5 +- 1.5); L0 %s L4 %s" % (mean(a4), mean(a0), d, a0, a4)
        if not (3.0 - 1e-9 <= d <= 6.0 + 1e-9): errs.append("difference %+.2f outside 3.0..6.0" % d)
        if errs: done("FAIL", "; ".join(errs) + " | " + det)
        done("PASS", det)
    if check == "realized":
        r = []
        for k, t in enumerate(ts):
            a, rp = arr(t), fnum(r"ramp ([\d.]+)/min", window(t))
            if a is None or not rp: errs.append("seed %d: no [window] arrivals / ramp" % (k + 1)); continue
            r.append(a / rp)
        if errs: done("FAIL", "; ".join(errs))
        done("PASS", "REALIZED mean %.3f (seeds %s) informational; act per plan 3.3 when it differs from 0.87 by > 0.02" % (mean(r), " ".join("%.3f" % x for x in r)))
    # Lead decision 3: a warm dhaba. Takings = the cash gained between the [stats] line at 120 s and the last [stats]
    # line at 600 s (it prints at 600.0-600.x: the --stats timer fires on the first frame at or after each step, so up
    # to 1 s late is allowed), per minute. These runs buy only at the start (--buy runs 0.5 s in) and take no rewards,
    # so the cash delta is sales only; a buy, build or reward line between the two [stats] lines fails the check.
    # The cold [window] figure (0-600 s, sales only) is printed as information.
    warm, cold, used = [], [], []
    spend_rx = re.compile(r"^(\[main3\] buy |\[analytics\] (upgrade_bought|building_built|reward|task_claimed|offline_claim|rewarded_completed|rewarded_owed_paid|renovation_done|location_move)\b)")
    for k, t in enumerate(ts):
        if not t: continue
        rows = []
        for i, l in enumerate(t.split("\n")):
            m = re.match(r"^\[stats\] ([\d.]+) cash ([\d.]+) sales (\d+)", l)
            if m: rows.append((i, float(m.group(1)), float(m.group(2)), int(m.group(3))))
        a = [r for r in rows if r[1] >= 120.0 - 0.5]
        b = [r for r in rows if r[1] <= 600.0 + 1.0]
        if not a or not b or b[-1][1] - a[0][1] < 60.0:
            errs.append("seed %d: no [stats] cash lines at 120 s and 600 s (have %s)" % (k + 1, [r[1] for r in rows])); continue
        r1, r2 = a[0], b[-1]
        sp = [l for l in t.split("\n")[r1[0] + 1:r2[0]] if spend_rx.match(l)]
        if sp: errs.append("seed %d: spend or reward between %.1f s and %.1f s: %s" % (k + 1, r1[1], r2[1], sp[0][:100])); continue
        warm.append((r2[2] - r1[2]) * 60.0 / (r2[1] - r1[1])); used.append("%.1f-%.1f s sales %d" % (r1[1], r2[1], r2[3] - r1[3]))
        c = fnum(r"takings ([\d.]+)/min", window(t))
        if c is not None: cold.append(c)
    if len(warm) < 4: done("FAIL", "; ".join(errs + ["warm takings on %d of 4 seeds" % len(warm)]))
    det = "warm takings/min (stats cash %s) mean %.1f x 7 = %.0f (bar >= 10000); seeds %s; cold [window] 0-600 s takings/min mean %s x 7 = %s (info; seeds %s)" % (
        ", ".join(sorted(set(u.rsplit(" sales", 1)[0] for u in used))) + "; sales " + " ".join(u.rsplit(" ", 1)[1] for u in used), mean(warm), 7 * mean(warm), " ".join("%.1f" % x for x in warm),
        ("%.1f" % mean(cold)) if cold else "-", ("%.0f" % (7 * mean(cold))) if cold else "-", " ".join("%.1f" % x for x in cold))
    if 7 * mean(warm) < 10000: errs.append("7 x warm takings %.0f < 10000" % (7 * mean(warm)))
    if errs: done("FAIL", "; ".join(errs) + " | " + det)
    done("PASS", det)

if check == "fans":
    p = A[0]; ts, errs = logs_ok([p]); t = ts[0]
    left = [int(x) for x in re.findall(r"^\[game\] showcase chai\.coffee left (\d+)", t, re.M)]
    if 7 not in left: errs.append("no '[game] showcase chai.coffee left 7'")
    if 0 not in left: errs.append("no '[game] showcase chai.coffee left 0' (got %s)" % left[-3:])
    fi = first_idx(t, r"^\[sim\] fan trav_techie arrives for chai\.coffee")
    ui = first_idx(t, r"^\[game\] showcase chai\.coffee left ")
    det = "showcase left %s..%s" % (left[:1], left[-1:])
    if fi is None: errs.append("no '[sim] fan trav_techie arrives for chai.coffee'")
    elif ui is not None:
        st = stats_times(t)
        ulo, uhi = bracket(st, ui); flo, fhi = bracket(st, fi)
        est = ((flo + (fhi if fhi is not None else flo)) / 2.0) - ((ulo + (uhi if uhi is not None else ulo)) / 2.0)
        det += "; fan about %.0f s after the unlock (stats brackets unlock %.0f-%s, fan %.0f-%s)" % (est, ulo, uhi, flo, fhi)
        if est > 20.0: errs.append("fan about %.0f s after the unlock > 20" % est)
    if errs: done("FAIL", "; ".join(errs) + " | " + det)
    done("PASS", det)

if check == "specialgame":
    p = A[0]; ts, errs = logs_ok([p]); t = ts[0]
    if not re.search(r"^\[special\] today chai\.coffee x2\.00", t, re.M): errs.append("no '[special] today chai.coffee x2.00'")
    if N in (2, 4):
        if not re.search(r"^\[ui\] special announced: chai\.coffee", t, re.M): errs.append("no '[ui] special announced: chai.coffee'")
        if not re.search(r"^\[game\] showcase chai\.coffee left 7", t, re.M): errs.append("no '[game] showcase chai.coffee left 7'")
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", (re.findall(r"^\[special\] today[^\n]*", t, re.M) or [""])[0])

if check == "eventgame":
    p = A[0]; ts, errs = logs_ok([p]); t = ts[0]
    bus = re.findall(r"^\[sim\] baraat bus: (\d+) guests", t, re.M)
    if not bus: errs.append("no '[sim] baraat bus: <n> guests'")
    for rx in (r"^\[event\] step 2 done", r"^\[event\] shaadi gate owned"):
        if not re.search(rx, t, re.M): errs.append("no '%s'" % rx[3:].replace("\\", ""))
    c0 = [float(x) for x in re.findall(r"^\[event\] claim 0 \+([\d.]+)", t, re.M)]
    c1 = [float(x) for x in re.findall(r"^\[event\] claim 1 \+([\d.]+)", t, re.M)]
    if not c0 or max(c0) < 200: errs.append("claim 0 %s (want >= 200)" % c0)
    if not c1 or max(c1) < 400: errs.append("claim 1 %s (want >= 400)" % c1)
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "baraat buses %s, claim 0 +%s, claim 1 +%s, gate owned" % (bus, c0[0], c1[0]))

if check == "eventpace":
    p = A[0]; ts, errs = logs_ok([p]); t = ts[0]
    g = fnum(r"event guests (\d+)", window(t), int)
    if g is None: done("FAIL", "; ".join(errs + ["no '[window] ... event guests <n>'"]))
    if g / 10.0 < 1.5: errs.append("event guests %d in 10 min = %.2f/min < 1.5 (W4: bus_interval_s 100)" % (g, g / 10.0))
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "event guests %d in 600 s = %.2f/min" % (g, g / 10.0))

if check == "consent":   # A: log tutcheck.txt
    p = A[0]; ts, errs = logs_ok([p]); t = ts[0]
    wi = first_idx(t, r"^\[analytics\] consent card waits: game")
    si = first_idx(t, r"^\[auto\] [\d.]+ step -> seats_done")
    ci = first_idx(t, r"^\[analytics\] consent card shown")
    ai = first_idx(t, r"^\[auto\] [\d.]+ step -> ad_deal")
    if wi is None: errs.append("no '[analytics] consent card waits: game'")
    elif si is not None and wi > si: errs.append("'consent card waits: game' after seats_done")
    if ci is None: errs.append("no '[analytics] consent card shown'")
    elif si is None or ai is None or not (si < ci < ai): errs.append("card shown at line %s, not between seats_done (%s) and ad_deal (%s)" % (ci, si, ai))
    if not re.search(r"^\[auto\] [\d.]+ consent answered", t, re.M): errs.append("no '[auto] <t> consent answered'")
    tc = rd(A[1]) or ""
    tf = re.findall(r"^TUTCHECK fails=(\d+)", tc, re.M)
    if not tf or tf[-1] != "0": errs.append("tutcheck --slack 2.0: %s %s" % ("fails=" + tf[-1] if tf else "no result", "; ".join(re.findall(r"^TUTCHECK \S+ FAIL[^\n]*", tc, re.M))[:300]))
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "waits before seats_done, card between seats_done and ad_deal, answered, tutcheck --slack 2.0 fails=0")

if check == "budget":
    p = A[0]; ts, errs = logs_ok([p]); t = ts[0]
    lp = re.findall(r"^\[game\] launch popup (\w+)", t, re.M)
    sup = re.findall(r"^\[analytics\] popup_suppressed \{[^}\n]*\"kind\": \"(\w+)\"", t, re.M)
    if len(lp) != 1: errs.append("%d '[game] launch popup' lines (want exactly 1): %s" % (len(lp), lp))
    wanted = {"consent", "offline", "eco_note"}
    miss = sorted(wanted - set(lp) - set(sup))
    if miss: errs.append("no popup_suppressed for %s" % ", ".join(miss))
    pay = "offline" in lp or re.search(r"^\[analytics\] offline_claim ", t, re.M)
    if not pay: errs.append("offline pay: no WELCOME BACK ('launch popup offline') and no offline_claim")
    # Lead decision 6(c) (W1-INT, from W1-FIX-money's handoff): with consent unknown and the tutorial
    # done, the consent card takes the launch pop-up; WELCOME BACK pays silently (offline_claim) and
    # sends popup_suppressed {kind: offline}.
    cu = re.search(r"^\[analytics\] (?:GameAnalytics not started: consent unknown|--consent=ask: consent unknown)", t, re.M)
    td = re.search(r"^\[game\] loaded save: [^\n]*\| tutorial done \|", t, re.M)
    if cu and td:
        if lp != ["consent"]: errs.append("decision 6(c): consent unknown and tutorial done, launch popup %s (want ['consent'])" % lp)
        if "offline" not in sup: errs.append("decision 6(c): no popup_suppressed offline")
        if not re.search(r"^\[analytics\] offline_claim ", t, re.M): errs.append("decision 6(c): no '[analytics] offline_claim' (silent pay)")
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "launch popup %s; suppressed %s; offline pay %s" % (lp, sorted(set(sup)), "WELCOME BACK" if "offline" in lp else "silent"))

if check == "nofill":   # A: log tutcheck.txt
    p = A[0]; ts, errs = logs_ok([p]); t = ts[0]
    if not re.search(r"^\[ads\] stub fill: none", t, re.M): errs.append("no '[ads] stub fill: none'")
    if not re.search(r"^\[auto\] [\d.]+ step -> done", t, re.M): errs.append("no 'step -> done'")
    q = re.findall(r"^\[main3\] quit at game time [\d.]+ \(tutorial step: (\w+)\)", t, re.M)
    if not q or q[-1] != "done": errs.append("quit line %s" % (q[-1:] or "missing"))
    if N == 4:
        if not re.search(r"^\[tutorial\] ad beat skipped: no ad", t, re.M): errs.append("no '[tutorial] ad beat skipped: no ad'")
        if re.search(r"^\[auto\] [\d.]+ step -> bubble", t, re.M): errs.append("'step -> bubble' present")
        di = first_idx(t, r"^\[analytics\] tutorial_done ")
        if di is not None and any(re.match(r"^\[analytics\] ad_bubble_shown", l) for l in t.split("\n")[di:]):
            errs.append("ad_bubble_shown after tutorial_done")
    tc = rd(A[1]) or ""
    info = (re.findall(r"^TUTCHECK nofill\S* (?:PASS|FAIL)[^\n]*", tc, re.M) or ["tutcheck: no row"])[0][:200]
    if errs: done("FAIL", "; ".join(errs) + " | info: " + info)
    done("PASS", "stub fill none, step -> done | info: " + info)

if check == "fps30":   # A: tutcheck.txt logs...
    tc = rd(A[0]) or ""
    ts, errs = logs_ok(A[1:])
    tf = re.findall(r"^TUTCHECK fails=(\d+)", tc, re.M)
    rows = []
    for p, t in zip(A[1:], ts):
        dn = re.findall(r"^\[auto\] ([\d.]+) step -> done", t, re.M)
        fr = re.findall(r"^\[auto\] ([\d.]+) step -> free", t, re.M)
        sl = re.findall(r"^\[auto\] ([\d.]+) step -> seats_lines", t, re.M)
        rows.append("%s done %s seats-free %s" % (bn(p)[6:-4], dn[0] if dn else "-", ("%.1f" % (float(sl[0]) - float(fr[0]))) if (sl and fr) else "-"))
    if not tf: errs.append("tutcheck gave no result")
    elif tf[-1] != "0": errs.append("tutcheck%s fails=%s: %s" % (" --fps30" if N == 4 else " (R1: every run reaches done)", tf[-1], "; ".join(re.findall(r"^TUTCHECK \S+ FAIL[^\n]*", tc, re.M))[:400]))
    det = ", ".join(rows) + ("" if N == 4 else " (recorded; gate 4 bars seats-free <= 8 and done <= 183)")
    if errs: done("FAIL", "; ".join(errs) + " | " + det)
    done("PASS", det)

if check == "strings":   # A: check_po output file, rc, po, pot
    outp, rc, po, pot = A[0], A[1], A[2], A[3]
    t = rd(outp) or ""; errs = []
    mm = re.findall(r"^MISSING \((\d+)\)", t, re.M)
    if not mm: errs.append("no 'MISSING (n)' line")
    elif mm[-1] != "0": errs.append("MISSING %s" % mm[-1])
    if rc != "0": errs.append("check_po exit %s" % rc)
    def ids(path):
        s, out, cur, ctx, inid = open(path, encoding="utf-8").read().split("\n"), set(), None, "", False
        def unq(x): return x.strip()[1:-1]
        for l in s + [""]:
            if l.startswith("msgctxt "): ctx = unq(l[8:]); inid = False
            elif l.startswith("msgid "): cur = unq(l[6:]); inid = True
            elif l.startswith('"') and inid: cur += unq(l)
            elif l.startswith("msgstr") or l.startswith("msgid_plural"):
                if inid and cur: out.add((ctx, cur))
                inid = False; cur = None; ctx = ""
        return out
    try:
        a, b = ids(po), ids(pot)
        if a != b: errs.append(".po and .pot msgids differ: %d only in .po, %d only in .pot (e.g. %s)" % (len(a - b), len(b - a), [x[1][:30] for x in list(a ^ b)[:3]]))
    except Exception as e: errs.append("cannot compare .po/.pot: %s" % e)
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "MISSING 0, exit 0, .pot = .po msgids (%d)" % len(a))

if check == "pacing":   # A: dir with p1.txt p2_*.txt p3_*.txt and rc files; baseline file
    d, basef = A[0], A[1]
    errs, det = [], []
    def get(name):
        t = rd(os.path.join(d, name + ".txt")); rc = (rd(os.path.join(d, name + ".rc")) or "?").strip()
        if t is None: errs.append("%s: no output" % name); return ""
        if rc != "0": errs.append("%s: exit %s (%s)" % (name, rc, " ".join(t.strip().split("\n")[-2:])[:160]))
        return t
    def part_a(t):
        m = re.search(r"^PART A.*?(?=^=+\s*\n\s*PART B)", t, re.M | re.S)
        return m.group(0).strip() if m else None
    t1 = get("p1")
    if t1:
        mc = re.findall(r"MENU CHECK: (\d+) states, failures: (\d+)", t1)
        if len(mc) != 2 or any(s != "16" or f != "0" for s, f in mc): errs.append("MENU CHECK lines %s (want two with 16 states, 0 failures)" % mc)
        pa, pb = part_a(t1), part_a(rd(basef) or "")
        if pa is None: errs.append("p1: no PART A block")
        elif pa != pb: errs.append("PART A differs from %s" % bn(basef))
        if not re.search(r"mean \|p50 - ref\| = 0\.62\b", t1): errs.append("no 'mean |p50 - ref| = 0.62'")
        bf = re.findall(r"^\s*bill check failures: (\d+)", t1, re.M)
        if not bf: errs.append("no 'bill check failures: <n>' line")
        elif bf[-1] != "0": errs.append("bill check failures: %s (%s)" % (bf[-1], "; ".join(l.strip()[:80] for l in re.findall(r"^\s+\w+\s+affordable[^\n]*", t1, re.M) if "OK" not in l)))
        la = re.search(r"^\s+lassi\s+affordable\s+(\d+:\d+(?:\.\d+)?)", t1, re.M)
        ka = re.search(r"^\s+kadai\s+affordable\s+(\d+:\d+(?:\.\d+)?)", t1, re.M)
        if not la or not (145 <= mmss(la.group(1)) < 146): errs.append("lassi affordable %s (want 2:25)" % (la.group(1) if la else "-"))
        if not ka or not (570 <= mmss(ka.group(1)) < 574): errs.append("kadai affordable %s (want 9:30 to 9:33)" % (ka.group(1) if ka else "-"))
        det.append("part A identical, MENU CHECK x2 ok, lassi %s kadai %s" % (la.group(1) if la else "-", ka.group(1) if ka else "-"))
    def marks(name):
        t = get(name)
        if not t: return None
        m = re.findall(r"^PROMO marks: (\{[^\n]*\})", t, re.M)
        if m:
            try: return ast.literal_eval(m[-1])
            except Exception: pass
        s = re.findall(r"^SUMMARY (\{[^\n]*\})", t, re.M)
        if s:
            try:
                pr = json.loads(s[-1]).get("promo")
                if isinstance(pr, dict) and "promo0" in pr: return pr
            except Exception: pass
        errs.append("%s: no 'PROMO marks: {...}' line (proto2 format: unlock0 promo0 unlock1 promo1 end2)" % name)
        return None
    keys = ("unlock0", "promo0", "unlock1", "promo1", "end2")
    # W4-NUM (2 Nov): the pacing table at REALIZED 0.92 and tray_batch_est 0.40 ($B/notes/W4-NUM.md); was plan 3.2's
    # 0.87 table (38:08 43:16 65:34 73:08 88:10 / 45:25 51:45 68:15 76:24 90:45 / 38:08 42:59 58:39 66:28 82:31)
    exp = {"p2_ads": ("36:10", "41:07", "60:45", "67:54", "82:55"),
           "p2_noads": ("43:05", "49:03", "64:41", "72:21", "85:15"),
           "p2_sess": ("36:10", "40:58", "56:20", "63:34", "78:53")}
    for name, ev in exp.items():
        mk = marks(name)
        if mk is None: continue
        bad = []
        for k, e in zip(keys, ev):
            v = mmss(mk.get(k)) if mk.get(k) is not None else None
            if v is None or abs(v - mmss(e)) > 30.0 + 1e-9: bad.append("%s %s (want %s +- 0:30)" % (k, mk.get(k), e))
        if bad: errs.append("%s: %s" % (name, "; ".join(bad)))
        else: det.append("%s marks ok" % name)
    bands = []
    for name in ("p3_r085", "p3_r085_noads", "p3_r097", "p3_r097_noads", "p3_st15", "p3_st15_noads"):
        mk = marks(name)
        if mk is None: continue
        noads = name.endswith("noads")
        r, mv = mmss(mk.get("promo0") or ""), mmss(mk.get("promo1") or "")
        lo, hi, mx = (45 * 60, 58 * 60, 85 * 60) if noads else (38 * 60, 50 * 60, 80 * 60)
        if r is None or not (lo <= r <= hi): errs.append("%s: renovated %s outside %d-%d min" % (name, mk.get("promo0"), lo // 60, hi // 60))
        if mv is None or mv > mx: errs.append("%s: moved %s > %d min" % (name, mk.get("promo1"), mx // 60))
        bands.append("%s %s/%s" % (name[3:], mk.get("promo0"), mk.get("promo1")))
    det.append("bands (renovated/moved) " + ", ".join(bands))
    if errs: done("FAIL", "; ".join(errs))
    done("PASS", "; ".join(det))

done("FAIL", "evaluator: unknown check %s" % check)
PYEOF

ev() { python3 -I "$EV" "$Q" "$B" "$@" 2>&1 | tail -1; }   # one line: PASS|FAIL|SKIP <detail> (else the error)
put() {  # ID "STATUS detail"
  local id="$1" line="$2"
  case "$line" in PASS*|FAIL*|SKIP*) ;; *) line="FAIL evaluator error: ${line:0:300}";; esac
  echo "$line" > "$RES/$id"; say "$id ${line:0:160}"
}
mksub() { local s="${SLOT}__c_$1"; "$Q/mkslot.sh" "$s" "$PROJ" > /dev/null 2>&1; echo "$s"; }
rr() { local sub="$1" log="$2"; shift 2; "$Q/run.sh" "$sub" "$log" "$LIMIT" -- "$@" > /dev/null; }
ps_() { "$B/tools/putsave.sh" "$1" "$2" > /dev/null; }
ROADCAP="--buy=waiter,waiter,tandoor,lassi,kadai,table,table,table,galla,chai_lvl100,tandoor_lvl100,lassi_lvl100,kadai_lvl100,chai_hire,chai_hire,tandoor_hire,tandoor_hire,lassi_hire,lassi_hire,kadai_hire,kadai_hire"

# ---------------------------------------------------------------- checks (each runs in the background)
j_suite() {
  if [ ! -d "$PREV" ]; then put G-suite "FAIL previous baseline $PREV is missing (set PREV_BASE)"; return; fi
  PREV_BASE="$PREV" ALLOW_MOVE="${ALLOW_MOVE:-}" "$Q/suite.sh" "$SLOT" "$SLOT" > "$CK/suite.out" 2>&1
  put G-suite "$(ev suite "$N" "$OUT")"
}
j_promo() {  # G-promo, and G-hindi-promo (gate 4)
  local id="$1" d="$CK/promo"; mkdir -p "$d"; local s; s=$(mksub "${2:-promo}")
  if [ "$id" = G-hindi-promo ]; then
    rr "$s" "$d/promo_hi.log" --lang=hi --fresh --skip-tutorial --money=1e12 --promo-check
    put "$id" "$(ev promo "$N" "$d/promo_hi.log" hi)"
  else
    rr "$s" "$d/promo.log" --fresh --skip-tutorial --money=1e12 --promo-check
    put "$id" "$(ev promo "$N" "$d/promo.log")"
  fi
}
j_taphall() { local d="$CK/tap_hall"; mkdir -p "$d"; local s; s=$(mksub taphall)
  rr "$s" "$d/tap_hall.log" --fresh --skip-tutorial --money=1e12 --renovate --tap-check
  put G-tap-hall "$(ev taphall "$N" "$d/tap_hall.log")"; }
j_zoomhall() { local d="$CK/zoom_hall"; mkdir -p "$d"; local s; s=$(mksub zoomhall)
  rr "$s" "$d/zoom_hall.log" --fresh --skip-tutorial --renovate --zoom-test
  put G-zoom-hall "$(ev zoom "$N" "$d/zoom_hall.log")"; }
j_gd() {  # ID test-name TAG kind default-run-args...
  local id="$1" tn="$2" tag="$3" kind="$4"; shift 4
  local T="$B/tests/$tn.gd"
  if [ ! -f "$T" ]; then put "$id" "SKIP missing $T"; return; fi
  local d="$CK/$tn"; mkdir -p "$d"; local s; s=$(mksub "$tn")
  local lim save runs=() a i=0 logs=()
  lim=$(sed -n 's/^# GATE_LIMIT: *\([0-9][0-9]*\).*/\1/p' "$T" | head -1); lim="${lim:-300}"
  save=$(sed -n 's/^# GATE_SAVE: *\([^ ]*\).*/\1/p' "$T" | head -1)
  [ -n "$save" ] && [ ! -f "$save" ] && save="$B/fixtures/$save"
  while IFS= read -r a; do runs+=("$a"); done < <(sed -n 's/^# GATE_ARGS:\(.*\)$/\1/p' "$T")
  [ ${#runs[@]} -eq 0 ] && runs=("$@")
  for a in "${runs[@]}"; do
    i=$((i+1))
    if [ -n "$save" ]; then ps_ "$s" "$save"; fi
    # shellcheck disable=SC2086
    "$B/tools/gdtest.sh" "$s" "$T" "$d/${tn}_$i.log" "$lim" -- $a > /dev/null
    logs+=("$d/${tn}_$i.log")
  done
  put "$id" "$(ev gdtest "$N" "$tag" "$kind" "${logs[@]}")"
}
j_hall() { local d="$CK/hall" k; mkdir -p "$d"; local s; s=$(mksub "hall_$1")
  # lead decision 5 (1 Nov): seeds 1-4, the bar on every seed
  for k in 1 2 3 4; do
    if [ "$1" = natural ]; then
      rr "$s" "$d/hall_natural_s$k.log" --fresh --skip-tutorial --money=1e9 --renovate --stats=60 --window=300 --quit-at=420 --seed=$k
    else
      rr "$s" "$d/hall_built_s$k.log" --fresh --skip-tutorial --money=1e9 --renovate --buy=waiter,waiter,waiter,table,table,table,table,table --stats=60 --window=300 --quit-at=420 --seed=$k
    fi
  done
  if [ "$1" = natural ]; then put G-hall-natural "$(ev hall "$N" natural "$d"/hall_natural_s{1,2,3,4}.log)"
  else put G-hall-built "$(ev hall "$N" built "$d"/hall_built_s{1,2,3,4}.log)"; fi; }
j_oldsaves() { local d="$CK/old_saves" s f; local a=(); mkdir -p "$d"; s=$(mksub oldsaves)
  for f in post_tutorial late tut_waiter tut_free; do
    ps_ "$s" "$B/fixtures/save_037_$f.json"
    if [ "$f" = late ]; then rr "$s" "$d/old_$f.log" --quit-at=40 --stats=20 --open=build
    else rr "$s" "$d/old_$f.log" --quit-at=40 --stats=20; fi
    a+=("$B/fixtures/save_037_$f.json" "$d/old_$f.log")
  done
  put G-old-saves "$(ev oldsaves "$N" "${a[@]}")"; }
j_resume() { local d="$CK/resume" s f; mkdir -p "$d"; s=$(mksub resume)
  for f in tut_waiter tut_free; do
    ps_ "$s" "$B/fixtures/save_037_$f.json"
    rr "$s" "$d/resume_$f.log" --auto --seed=1 --quit-at=260
  done
  put G-resume "$(ev resume "$N" "$d/resume_tut_waiter.log" "$d/resume_tut_free.log")"; }
j_roundtrip() { local d="$CK/roundtrip"; mkdir -p "$d"; local s; s=$(mksub roundtrip)
  rr "$s" "$d/roundtrip_1.log" --fresh --skip-tutorial --money=1e12 --renovate --quit-at=20
  rr "$s" "$d/roundtrip_2.log" --quit-at=20
  put G-roundtrip "$(ev roundtrip "$N" "$d/roundtrip_1.log" "$d/roundtrip_2.log")"; }
j_lossless() { local d="$CK/lossless"; mkdir -p "$d"; local s; s=$(mksub lossless)
  rr "$s" "$d/lossless.log" --fresh --skip-tutorial --money=0 --arrivals=40 --window=240 --stats=60 --quit-at=300 --seed=1
  want G-lossless && put G-lossless "$(ev lossless "$N" "$d/lossless.log")"
  want G-road && put G-road "$(ev road "$N" "$d/lossless.log")"; }
j_held() { local d="$CK/held"; mkdir -p "$d"; local s; s=$(mksub held)
  rr "$s" "$d/held.log" --fresh --skip-tutorial --money=1e9 --buy=tandoor,chai_hire,chai_hire,tandoor_hire --arrivals=19 --stats=20 --quit-at=200 --seed=1
  put G-held "$(ev held "$N" "$d/held.log")"; }
# G-trays (lead decision 4, 1 Nov): the waiter is the bottleneck at the margin. One waiter, every counter built
# (--reno-ready: all four at L100, no waiter rule) and staffed (3 cooks each), 5 tables, 2 cashiers, and
# --arrivals=$TRAY_ARR: the tray-1 runs' lowest [stats] capacity is waiters and their mean food wait is under 40 s.
# Tray 1 and tray 2 on seeds 1-4 (W1-BARS notes: the sweep that picked the rate). The plan's first scenario
# (2 waiters, kitchen-bound: no bundle can form) runs once more on seed 1 as information.
TRAY_ARR=10
TRAY_SET="--buy=table,table,table,galla,chai_hire,chai_hire,tandoor_hire,tandoor_hire,lassi_hire,lassi_hire,kadai_hire,kadai_hire"
j_trays() { local d="$CK/trays" k; mkdir -p "$d"
  for k in 2 1; do
    ( local s sd; s=$(mksub "trays$k")
      for sd in 1 2 3 4; do
        rr "$s" "$d/tray${k}_s$sd.log" --fresh --skip-tutorial --money=1e9 --reno-ready $TRAY_SET --tray=$k --arrivals=$TRAY_ARR --seed=$sd --stats=60 --window=300 --quit-at=400
      done
      rr "$s" "$d/old_tray$k.log" --fresh --skip-tutorial --money=1e9 --buy=waiter,tandoor,lassi --tray=$k --arrivals=24 --stats=60 --window=300 --quit-at=400 --seed=1 ) &
  done
  wait
  put G-trays "$(ev trays "$N" "$PROJ/themes/dhaba/economy.json" "$d"/tray2_s{1,2,3,4}.log "$d"/tray1_s{1,2,3,4}.log "$d/old_tray2.log" "$d/old_tray1.log")"; }
j_dispatch() { local d="$CK/dispatch" s k; mkdir -p "$d"; s=$(mksub dispatch)
  local C="$Q/logs/gate_dispatch_base" stamp; stamp=$(cat "$B/snap/wave1/.done" 2>/dev/null)
  # the 0.3.7 base runs never change: cached once per wave-1 snapshot
  if [ "$(cat "$C/stamp" 2>/dev/null)" != "$stamp" ] || ! grep -q '^rc=0' "$C/base_s4.log" 2>/dev/null; then
    ( local b="${SLOT}__c_dispbase"; "$Q/mkslot.sh" "$b" "$B/snap/wave1" > /dev/null 2>&1; rm -rf "$C"; mkdir -p "$C"
      for k in 1 2 3 4; do rr "$b" "$C/base_s$k.log" --fresh --skip-tutorial --money=1e9 --buy=waiter,tandoor,lassi,table --seed=$k --window=300 --stats=60 --quit-at=420; done
      echo "$stamp" > "$C/stamp" ) &
  fi
  for k in 1 2 3 4; do rr "$s" "$d/dispatch_s$k.log" --fresh --skip-tutorial --money=1e9 --buy=waiter,tandoor,lassi,table --seed=$k --window=300 --stats=60 --quit-at=420; done
  wait
  put G-dispatch "$(ev dispatch "$N" "$d"/dispatch_s{1,2,3,4}.log "$C"/base_s{1,2,3,4}.log)"; }
# Lead decision 11 (gate 4): every run here takes --no-notes, so no open reno_ready dialogue parks the camera for the
# whole window. G-sign's own L0/L4 pair adds 12 galla levels, so two level-1 cashiers no longer cap the L4 target;
# G-realized and G-reno-reach keep plain ROADCAP in their own level-0 runs ("roadcap0").
j_sign() { local d="$CK/sign" k L; mkdir -p "$d"
  local galla; galla=$(printf ',galla_up%.0s' $(seq 1 12))
  for L in 0 4; do
    ( local s; s=$(mksub "sign$L")
      for k in 1 2 3 4; do rr "$s" "$d/sign${L}_s$k.log" --fresh --skip-tutorial --money=1e12 $ROADCAP$galla --no-notes --signboard=$L --window=600 --stats=120 --quit-at=640 --seed=$k; done ) &
  done
  ( local s; s=$(mksub "roadcap0")
    for k in 1 2 3 4; do rr "$s" "$d/roadcap0_s$k.log" --fresh --skip-tutorial --money=1e12 $ROADCAP --no-notes --signboard=0 --window=600 --stats=120 --quit-at=640 --seed=$k; done ) &
  wait
  local l0 l4 r0; l0=("$d"/sign0_s{1,2,3,4}.log); l4=("$d"/sign4_s{1,2,3,4}.log); r0=("$d"/roadcap0_s{1,2,3,4}.log)
  want G-sign && put G-sign "$(ev sign "$N" "${l0[@]}" "${l4[@]}")"
  want G-realized && put G-realized "$(ev realized "$N" "${r0[@]}")"
  want G-reno-reach && put G-reno-reach "$(ev renoreach "$N" "${r0[@]}")"; }
j_fans() { local d="$CK/fans"; mkdir -p "$d"; local s; s=$(mksub fans)
  rr "$s" "$d/fans.log" --fresh --skip-tutorial --money=1e9 --buy=chai_lvl24,chai_up --stats=10 --quit-at=120
  put G-fans "$(ev fans "$N" "$d/fans.log")"; }
j_specialgame() { local d="$CK/special_game"; mkdir -p "$d"; local s; s=$(mksub specialgame)
  rr "$s" "$d/special_game.log" --fresh --skip-tutorial --money=1e9 --buy=chai_lvl30 --special=chai.coffee --quit-at=60
  put G-special-game "$(ev specialgame "$N" "$d/special_game.log")"; }
j_eventgame() { local d="$CK/event_game"; mkdir -p "$d"; local s; s=$(mksub eventgame)
  rr "$s" "$d/event_game.log" --fresh --skip-tutorial --money=1e9 --buy=waiter,waiter,tandoor,lassi,kadai,table,table,table --event=on --event-guests=24 --event-claim --stats=60 --quit-at=400
  put G-event-game "$(ev eventgame "$N" "$d/event_game.log")"; }
j_eventpace() { local d="$CK/event_pace"; mkdir -p "$d"; local s; s=$(mksub eventpace)
  ps_ "$s" "$B/fixtures/save_037_late.json"
  rr "$s" "$d/event_pace.log" --event=on --window=600 --stats=60 --quit-at=620
  put G-event-pace "$(ev eventpace "$N" "$d/event_pace.log")"; }
j_consent() { local d="$CK/consent"; mkdir -p "$d"; local s; s=$(mksub consent)
  rr "$s" "$d/consent_s1.log" --fresh --auto --consent=ask --seed=1 --quit-at=260
  python3 -I "$Q/tutcheck.py" "$d" --base "$Q/logs/baseline" --slack 2.0 > "$d/tutcheck.txt" 2>&1
  put G-consent "$(ev consent "$N" "$d/consent_s1.log" "$d/tutcheck.txt")"; }
j_budget() { local d="$CK/budget"; mkdir -p "$d"; local s; s=$(mksub budget)
  ps_ "$s" "$B/fixtures/save_037_return_eco3.json"
  rr "$s" "$d/budget.log" --away=3600 --consent=ask --quit-at=60
  put G-budget "$(ev budget "$N" "$d/budget.log")"; }
j_nofill() { local d="$CK/nofill"; mkdir -p "$d"; local s; s=$(mksub nofill)
  rr "$s" "$d/nofill_s1.log" --fresh --auto --seed=1 --ads=nofill --quit-at=260
  python3 -I "$Q/tutcheck.py" "$d" --base "$Q/logs/baseline" > "$d/tutcheck.txt" 2>&1
  put G-nofill "$(ev nofill "$N" "$d/nofill_s1.log" "$d/tutcheck.txt")"; }
j_fps30() { local d="$CK/fps30" s k; mkdir -p "$d"; s=$(mksub fps30)
  for k in 41 42 43 44 45 46; do
    FIXED="--fixed-fps 30" "$Q/run.sh" "$s" "$d/fps30_s$k.log" "$LIMIT" -- --fresh --auto --seed=$k --quit-at=260 > /dev/null
  done
  if [ "$N" = 4 ]; then python3 -I "$Q/tutcheck.py" "$d" --fps30 > "$d/tutcheck.txt" 2>&1
  else python3 -I "$Q/tutcheck.py" "$d" > "$d/tutcheck.txt" 2>&1; fi
  put G-fps30 "$(ev fps30 "$N" "$d/tutcheck.txt" "$d"/fps30_s4{1,2,3,4,5,6}.log)"; }
j_strings() { local d="$CK/strings"; mkdir -p "$d"
  ( cd "$d" && "$PY" -I "$PROJ/tools/i18n/check_po.py" > "$d/check_po.txt" 2>&1; echo $? > "$d/check_po.rc" )
  if [ -n "$HINDI_FROZEN" ]; then  # lead decision 10: Hindi waits until the English is final
    put G-strings "SKIP Hindi frozen until the English is final (lead decision 10); check_po rc=$(cat "$d/check_po.rc"): $(grep -E 'MISSING|STALE' "$d/check_po.txt" | tr '\n' ' ' | cut -c1-200)"; return; fi
  put G-strings "$(ev strings "$N" "$d/check_po.txt" "$(cat "$d/check_po.rc")" "$PROJ/i18n/hi.po" "$PROJ/i18n/dhaba_rush.pot")"; }
j_pacing() { local d="$CK/pacing"; mkdir -p "$d"
  # W4-NUM (2 Nov): the gate tree's own economy (tray_batch_est 0.40, lead decision 8); REALIZED 0.92 (plan 3.3)
  local T="$PROJ/tools/sim/pacing_v3.py" E="${PACE_ECO:-$PROJ/themes/dhaba/economy.json}"
  pr() { local n="$1"; shift; ( cd "$d" && "$PY" -I "$T" --eco "$E" "$@" > "$d/$n.txt" 2>&1; echo $? > "$d/$n.rc" ); }
  ( pr p1 --seeds 20 --minutes 60; pr p2_ads --minutes 200 --promo; pr p2_noads --minutes 200 --promo --no-ads
    pr p2_sess --minutes 200 --promo --ad-sessions 20 ) &
  ( pr p3_r085 --minutes 200 --promo --realized 0.85; pr p3_r085_noads --minutes 200 --promo --realized 0.85 --no-ads
    pr p3_r097 --minutes 200 --promo --realized 0.97; pr p3_r097_noads --minutes 200 --promo --realized 0.97 --no-ads
    pr p3_st15 --minutes 200 --promo --starter 15; pr p3_st15_noads --minutes 200 --promo --starter 15 --no-ads ) &
  wait
  put G-pacing "$(ev pacing "$N" "$d" "$S/pacing_core_baseline.txt")"; }

# ---------------------------------------------------------------- launch
launch() { say "start $1"; shift; ( "$@" ) & }
for c in $CHECKS; do
  case "$c" in
    G-suite) launch "$c" j_suite;;
    G-promo) launch "$c" j_promo G-promo promo;;
    G-hindi-promo) launch "$c" j_promo G-hindi-promo promohi;;
    G-tap-hall) launch "$c" j_taphall;;
    G-zoom-hall) launch "$c" j_zoomhall;;
    G-layout) launch "$c" j_gd G-layout layout_test LAYOUTTEST layout "--fresh --skip-tutorial --layout=family" "--fresh --skip-tutorial";;
    G-hall-natural) launch "$c" j_hall natural;;
    G-hall-built) launch "$c" j_hall built;;
    G-old-saves) launch "$c" j_oldsaves;;
    G-resume) launch "$c" j_resume;;
    G-roundtrip) launch "$c" j_roundtrip;;
    G-lossless) launch "$c" j_lossless;;
    G-road) want G-lossless || launch "$c" j_lossless;;
    G-held) launch "$c" j_held;;
    G-trays) launch "$c" j_trays;;
    G-dispatch) launch "$c" j_dispatch;;
    G-sign) launch "$c" j_sign;;
    G-realized|G-reno-reach) want G-sign || { [ -z "$SIGN_STARTED" ] && SIGN_STARTED=1 && launch "$c" j_sign; };;
    G-hire-rate) launch "$c" j_gd G-hire-rate hire_test HIRETEST hire "--fresh --skip-tutorial --money=1e9 --buy=tandoor --arrivals=19";;
    G-table-line) launch "$c" j_gd G-table-line table_test TABLETEST plain "--fresh --skip-tutorial --money=1e9";;
    G-fill) launch "$c" j_gd G-fill fill_test FILLTEST plain "--fresh --skip-tutorial";;
    G-fans) launch "$c" j_fans;;
    G-special-unit) launch "$c" j_gd G-special-unit special_test SPECIALTEST plain "";;
    G-special-game) launch "$c" j_specialgame;;
    G-event-unit) launch "$c" j_gd G-event-unit event_test EVENTTEST plain "";;
    G-event-game) launch "$c" j_eventgame;;
    G-event-pace) launch "$c" j_eventpace;;
    G-delegation) launch "$c" j_gd G-delegation delegation_test DELEGATIONTEST plain "";;
    G-offers) launch "$c" j_gd G-offers offers_test OFFERSTEST plain "";;
    G-consent) launch "$c" j_consent;;
    G-budget) launch "$c" j_budget;;
    G-nofill) launch "$c" j_nofill;;
    G-fps30) launch "$c" j_fps30;;
    G-strings) launch "$c" j_strings;;
    G-pacing) launch "$c" j_pacing;;
  esac
done
wait
say "all checks finished"

# ---------------------------------------------------------------- gate.txt
fails=0; skips=0
{
  for c in $CHECKS; do
    line=$(cat "$RES/$c" 2>/dev/null)
    [ -z "$line" ] && line="FAIL no result (the check did not finish; see $CK)"
    case "$line" in FAIL*) fails=$((fails+1));; SKIP*) skips=$((skips+1));; esac
    echo "GATE $N $c $line"
  done
  out_save=$("$Q/savecheck.sh" 2>&1)
  if [ "$out_save" != "SAVE OK" ]; then fails=$((fails+1)); echo "GATE $N savecheck FAIL $out_save"; fi
  echo "GATE $N fails=$fails"
  echo "GATE $N skips=$skips"
} > "$OUT/gate.txt.tmp"
mv "$OUT/gate.txt.tmp" "$OUT/gate.txt"
fails=$(sed -n "s/^GATE $N fails=\([0-9]*\)$/\1/p" "$OUT/gate.txt")
T1=$(date +%s); echo "gate $N ($SLOT): $((T1-T0)) s wall, checks:$CHECKS" > "$OUT/gate_time.txt"

# ---------------------------------------------------------------- baseline of this gate
if [ "$fails" = 0 ] && [ -z "$GATE_ONLY" ] && [ -z "$GATE_TAG" ] && [ -z "$GATE_DRY" ] && want G-suite; then
  BW="$Q/logs/baseline_wave$N"; rm -rf "$BW.tmp"; mkdir -p "$BW.tmp"
  cp "$OUT"/tut_*.log "$OUT/summary.txt" "$OUT/tutcheck.txt" "$OUT/gate.txt" "$BW.tmp/"
  python3 -I "$Q/tutcheck.py" "$BW.tmp" --write-beats "$BW.tmp/beats.json" > /dev/null
  rm -rf "$BW"; mv "$BW.tmp" "$BW"; say "baseline written: $BW"
fi
rm -rf "$Q/slots/${SLOT}__"*
say "done in $((T1-T0)) s: $(tail -2 "$OUT/gate.txt" | tr '\n' ' ')"
cat "$OUT/gate.txt"
[ "$fails" -gt 255 ] && fails=255
exit "$fails"
