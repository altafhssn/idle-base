#!/usr/bin/env python3
"""Idle Business Kit, phase 3: the theme-word ratchet.

Counts the theme pack's own words (its station ids, legacy station ids, staff names
and business word) in the CODE of every engine script (scripts/**/*.gd; comment
lines and trailing comments are skipped, strings count). The baseline
(tools/kit/theme_words_baseline.json) records the count per file. --check fails
when any file has more than its baseline (or a new file has any): engine code
may only lose theme words, phase by phase. --write records the current counts
(run it after a phase removes words, so the lower count becomes the bar).

  python3 -I tools/kit/theme_words.py [--root DIR] [--theme dhaba] (--check | --write | --report)

Prints "THEMEWORDS fails=N" with --check (the suite's parser reads it).
"""
import json, os, re, sys

args = sys.argv[1:]
def opt(name, default):
    if name in args:
        return args[args.index(name) + 1]
    return default
root = os.path.abspath(opt("--root", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")))
theme = opt("--theme", "dhaba")
base_path = os.path.join(root, "tools", "kit", "theme_words_baseline.json")
pack = os.path.join(root, "themes", theme)

eco = json.load(open(os.path.join(pack, "economy.json"), encoding="utf-8"))
cfg = json.load(open(os.path.join(pack, "theme.json"), encoding="utf-8"))
words = set()
for sid, d in eco.get("stations", {}).items():
    words.add(sid.lower())
    for n in d.get("staff", []) if isinstance(d.get("staff"), list) else []:
        words.add(str(n).lower())
for sid in eco.get("legacy", {}).get("stations", {}):
    words.add(sid.lower())
for n in eco.get("waiters", {}).get("names", []):
    words.add(str(n).lower())
for n in eco.get("galla", eco.get("checkout", {})).get("staff", []):
    words.add(str(n).lower())
biz = str(cfg.get("words", {}).get("business", "")).lower()
if biz:
    words.add(biz)
words = sorted(w for w in words if len(w) >= 3)
# inside identifiers too (_add_tandoor_lock, TANDOOR_SLAB), not inside other words (modal)
pat = re.compile(r"(?<![a-z])(" + "|".join(re.escape(w) for w in words) + r")(?![a-z])", re.I)


def code_part(line):
    s = line.lstrip()
    if s.startswith("#"):
        return ""
    # drop a trailing comment that is outside any string literal
    out, q = [], None
    for i, c in enumerate(line):
        if q:
            out.append(c)
            if c == q and line[i - 1] != "\\":
                q = None
        elif c in "\"'":
            q = c
            out.append(c)
        elif c == "#":
            break
        else:
            out.append(c)
    return "".join(out)


counts = {}
for dp, _, fs in os.walk(os.path.join(root, "scripts")):
    for f in fs:
        if not f.endswith(".gd"):
            continue
        p = os.path.join(dp, f)
        n = 0
        for line in open(p, encoding="utf-8", errors="replace"):
            n += len(pat.findall(code_part(line)))
        if n:
            counts[os.path.relpath(p, root)] = n

total = sum(counts.values())
if "--write" in args:
    json.dump({"_comment": "Idle Business Kit theme-word ratchet: per engine file, how many of the dhaba pack's own words its code may still contain. tools/kit/theme_words.py --check fails when a file goes above this. Lower it (--write) whenever a phase removes words.",
               "theme": theme, "words": words, "total": total, "files": dict(sorted(counts.items()))},
              open(base_path, "w"), indent=1)
    print("THEMEWORDS baseline written: %d words in %d files (%s)" % (total, len(counts), ", ".join(words)))
    sys.exit(0)
if "--report" in args or "--check" not in args:
    for k, v in sorted(counts.items(), key=lambda kv: -kv[1]):
        print("%5d  %s" % (v, k))
    print("total %d in %d files; words: %s" % (total, len(counts), ", ".join(words)))
    sys.exit(0)
base = json.load(open(base_path)).get("files", {}) if os.path.exists(base_path) else {}
fails = 0
for k, v in sorted(counts.items()):
    b = int(base.get(k, 0))
    if v > b:
        fails += 1
        print("[themewords] FAIL %s: %d theme words (baseline %d)" % (k, v, b))
down = sum(max(0, int(b) - counts.get(k, 0)) for k, b in base.items())
print("[themewords] total %d (baseline %d)%s" % (total, sum(int(b) for b in base.values()),
      ("; %d fewer than the baseline: run --write to lower the bar" % down) if down else ""))
print("THEMEWORDS fails=%d" % fails)
sys.exit(1 if fails else 0)
