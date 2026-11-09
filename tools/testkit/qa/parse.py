#!/usr/bin/env python3
"""Summarise a suite log folder. Usage: parse.py LOGDIR [--beats PATH]

Per log: rc, SCRIPT ERRORs, the home check, the `[auto] <t> step -> done` line, [window], [summary],
TAPCHECK / ZOOMTEST, sdk-test counts, the conservation line. Per tutorial log (tut_*) also the beats
done / waiter_done / seats_lines / line7 with their delta against beats.json (default:
<this folder>/logs/baseline/beats.json).

RESULT: FAIL when a job exits non-zero or prints SCRIPT ERROR; a tut_* log lacks `step -> done` or the
quit line ending `(tutorial step: done)`; a conservation line has left_unpaid > 0 or does not add up
(arrived = paid + inside + left_unpaid); a "[check] STALL" line; TAPCHECK / ZOOMTEST
report fails > 0 (or tapcheck.log / zoomtest.log lack the line); sdk-test prints a FAIL; tutcheck.txt
(written by suite.sh) reports fails > 0 or has no `TUTCHECK fails=` line.
"""
import json, os, re, sys

args = sys.argv[1:]
beats_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs", "baseline", "beats.json")
if "--beats" in args:
    i = args.index("--beats")
    beats_path = args[i + 1]
    del args[i:i + 2]
d = args[0]
beats = {}
if os.path.exists(beats_path):
    try:
        beats = json.load(open(beats_path)).get("logs", {})
    except Exception as e:
        print("parse: cannot read %s: %s" % (beats_path, e))

STEP_RE = r"^\[auto\] ([\d.]+) step -> (\w+) \(cash (-?[\d.]+)\)"
print("SUITE", os.path.basename(d.rstrip("/")))
bad = 0
problems = []
for fn in sorted(os.listdir(d)):
    if not fn.endswith(".log"):
        continue
    name = fn[:-4]
    t = open(os.path.join(d, fn), errors="replace").read()
    rc = (re.findall(r"^rc=(-?\d+)", t, re.M) or ["?"])[-1]
    serr = len(re.findall(r"SCRIPT ERROR", t))
    errs = len(re.findall(r"^ERROR:", t, re.M))
    line = "%-12s rc=%s script_errors=%d errors=%d" % (name, rc, serr, errs)
    job_bad = []
    m = re.findall(r"\[auto\][^\n]*home check[^\n]*", t)
    if m: line += "\n    " + m[-1][:220]
    m = re.findall(r"^\[auto\] ([\d.]+) step -> done[^\n]*", t, re.M)
    if m:
        line += "\n    " + re.findall(r"^\[auto\] [\d.]+ step -> done[^\n]*", t, re.M)[0][:160]
    is_tut = name.startswith("tut_")
    if is_tut:
        steps = {}
        for tt, st, _c in re.findall(STEP_RE, t, re.M):
            steps.setdefault(st, float(tt))
        b = beats.get(name)
        parts = []
        for k in ("done", "waiter_done", "seats_lines", "line7"):
            v = steps.get(k)
            if v is None:
                parts.append("%s -" % k)
                continue
            bt = (b.get("times", {}).get(k) or [None])[0] if b else None
            parts.append("%s %.2f (%s)" % (k, v, ("%+.2f" % (v - bt)) if bt is not None else "base -"))
        line += "\n    beats: " + " ".join(parts)
        if not m:
            job_bad.append("no 'step -> done'")
        q = re.findall(r"^\[main3\] quit at game time [\d.]+ \(tutorial step: (\w+)\)", t, re.M)
        if not q:
            job_bad.append("no '[main3] quit at' line")
        elif q[-1] != "done":
            job_bad.append("quit with tutorial step '%s'" % q[-1])
    for c in re.findall(r"^\[sim\] conservation [^\n]*", t, re.M):
        line += "\n    " + c[:200]
        mm = re.search(r"left_unpaid (\d+)", c)
        if mm and int(mm.group(1)) > 0:
            job_bad.append("left_unpaid %s" % mm.group(1))
        # Invariant (Idle Business Kit): every customer who came in paid, is
        # still inside, or left unpaid - nobody vanishes.
        cm = re.search(r"arrived (\d+) paid (\d+) inside (\d+) left_unpaid (\d+)", c)
        if cm:
            arr, paid, ins, unp = (int(x) for x in cm.groups())
            if arr != paid + ins + unp:
                job_bad.append("conservation: arrived %d != paid %d + inside %d + left_unpaid %d" % (arr, paid, ins, unp))
    # Invariant: the autopilot saw no tutorial stall ("[check] STALL", main3.gd).
    for st in re.findall(r"^\[check\] STALL[^\n]*", t, re.M)[:2]:
        line += "\n    " + st[:200]
        job_bad.append("stall")
    m = re.findall(r"^\[window\] \d+ s after start[^\n]*", t, re.M)
    if m: line += "\n    " + m[-1][:260]
    m = re.findall(r"^\[summary\][^\n]*", t, re.M)
    if m: line += "\n    " + m[-1][:260]
    m = re.findall(r"(TAPCHECK fails=\d+|ZOOMTEST fails=\d+|PACKCHECK fails=\d+)", t)
    if m:
        line += "\n    " + m[-1]
        if not m[-1].endswith("=0"):
            job_bad.append(m[-1])
    elif name in ("tapcheck", "zoomtest", "packcheck"):
        job_bad.append("no %s fails= line" % name.upper())
    for pf in re.findall(r"^\[packcheck\] FAIL[^\n]*", t, re.M)[:5]:
        line += "\n    " + pf[:220]
    # Idle Business Kit: a model or sound the game asked for that the pack lacks.
    miss = sorted(set(re.findall(r"^\[pack\] missing (model|sound) '([^']+)'", t, re.M)))
    if miss:
        line += "\n    pack missing: " + ", ".join("%s %s" % m for m in miss)[:300]
        if any(k == "model" for k, _ in miss):
            job_bad.append("pack missing model")
    p = len(re.findall(r"\[sdk-test\] PASS", t)); f = len(re.findall(r"\[sdk-test\] FAIL", t))
    if p or f: line += "\n    sdk-test pass=%d fail=%d" % (p, f)
    if f:
        job_bad.append("sdk-test fail=%d" % f)
    if serr or (rc not in ("0",)):
        job_bad.insert(0, "rc=%s script_errors=%d" % (rc, serr))
        for e in re.findall(r"SCRIPT ERROR[^\n]*\n[^\n]*\n?[^\n]*", t)[:3]:
            line += "\n    !! " + e.replace("\n", " | ")[:300]
    if job_bad:
        bad += 1
        line += "\n    !! " + "; ".join(job_bad)
        problems.append("%s: %s" % (name, "; ".join(job_bad)))
    print(line)
sc = open(os.path.join(d, "savecheck.txt")).read().strip() if os.path.exists(os.path.join(d, "savecheck.txt")) else "?"
print("save:", sc)
if sc != "?" and "SAVE OK" not in sc:
    bad += 1
    problems.append("savecheck: %s" % sc.splitlines()[-1][:120])
tc = os.path.join(d, "tutcheck.txt")
if os.path.exists(tc):
    tt = open(tc, errors="replace").read()
    fl = re.findall(r"^TUTCHECK fails=(\d+)", tt, re.M)
    for l in re.findall(r"^TUTCHECK \S+ FAIL[^\n]*", tt, re.M):
        print("tutcheck: " + l[:400])
    if not fl:
        print("tutcheck: no 'TUTCHECK fails=' line in tutcheck.txt")
        bad += 1
        problems.append("tutcheck.txt has no TUTCHECK fails= line")
    else:
        print("tutcheck: TUTCHECK fails=%s" % fl[-1])
        if int(fl[-1]) > 0:
            bad += 1
            problems.append("TUTCHECK fails=%s" % fl[-1])
else:
    print("tutcheck: not run (no tutcheck.txt)")
for pr in problems:
    print("FAIL:", pr)
print("RESULT:", "FAIL (%d jobs)" % bad if bad else "PASS")
