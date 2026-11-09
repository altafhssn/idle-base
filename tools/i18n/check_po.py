# Dhaba Rush i18n check (launch blockers track B; extended for core and feel, W3-STR, 2 Nov 2026).
# Every msgid the code / data uses must be in i18n/hi.po, and i18n/dhaba_rush.pot must hold the same msgids:
#   1. tr("..."), UiKit.t("..."), TranslationServer.translate("...") literals (and "a" if c else "b" inside them);
#   2. tr(NAME) / UiKit.t(NAME) where NAME is a string const (same file first, else a unique const of that name);
#   3. MSGID_CONSTS below: constants the UI translates through a variable (tr(item), a Label's auto-translate);
#   4. UI literals: "..." given to a Label / button / title (UI_PATTERNS below) in scripts/v3/ui, tutorial, fx;
#   5. Munshi-ji: every "text": "..." of ScriptLines.LINES (scripts/v3/tutorial/script_lines.gd) and every
#      const *_TEXT of scripts/v3/tutorial/munshi_notes.gd;
#   6. economy_v3.json: the station texts (name, card_name, desc, build_desc, serve_text, ...) of NH 44 and of every
#      location overlay (locations.<id>.stations), each location's name, the task texts, staff and waiter names
#      (msgctxt "name");
#   7. placeholders (%d %s {name} [k] [/k] \n) equal in msgid and msgstr, no empty msgstr, no "#, fuzzy";
#   8. .pot = .po: the same msgid set, every .pot msgstr empty;
#   9. STALE: a hi.po msgid that no script, scene or economy text holds any more (a replaced English line must
#      replace its entry, never linger).
# Usage:
#   /Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 -I tools/i18n/check_po.py [--literals] [--keywords]
# --literals also lists other English-looking literals in scripts/v3/ui, tutorial and fx (node names, debug prints ... and any
# label text that was forgotten); --keywords lists Munshi-ji's [k] words whose Hindi is not an on-screen label
# (names excepted). Both are information only. Exit code = MISSING + bad placeholders + .pot differences + STALE.
import re, sys, os, json, glob
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
def parse_po(path):
    ents = {}
    ctx = ''; mid = None; mstr = None; cur = None
    def unq(s):
        s = s.strip()[1:-1]
        return s.replace('\\n', '\n').replace('\\"', '"').replace('\\t', '\t').replace('\\\\', '\\')
    for line in open(path, encoding='utf-8').read().split('\n') + ['']:
        if line.startswith('msgctxt '):
            if mid is not None: ents[(ctx, mid)] = mstr; mid = None
            ctx = unq(line[8:]); cur = 'c'
        elif line.startswith('msgid '):
            if mid is not None and cur == 's': ents[(ctx, mid)] = mstr; ctx = ''
            mid = unq(line[6:]); cur = 'i'
        elif line.startswith('msgstr '):
            mstr = unq(line[7:]); cur = 's'
        elif line.startswith('"'):
            if cur == 'i': mid += unq(line)
            elif cur == 's': mstr += unq(line)
            elif cur == 'c': ctx += unq(line)
        elif line.strip() == '' and mid is not None and cur == 's':
            ents[(ctx, mid)] = mstr; mid = None; ctx = ''; cur = None
    ents.pop(('', ''), None)
    return ents
PO_PATH = os.path.join(ROOT, 'i18n/hi.po')
POT_PATH = os.path.join(ROOT, 'i18n/dhaba_rush.pot')
po = parse_po(PO_PATH)
ids = {k[1] for k in po}
miss = []
STR = r'"((?:[^"\\]|\\.)*)"'
def unesc(s): return s.replace('\\n', '\n').replace('\\"', '"')
def rel(f): return os.path.relpath(f, ROOT)
def need(src, mid, ctx=''):
    if (ctx, mid) not in po: miss.append((src, ctx, mid))
files = sorted(glob.glob(ROOT + '/scripts/**/*.gd', recursive=True))
SRC = {f: open(f, encoding='utf-8').read() for f in files}

# ---------------------------------------------------------------- 1. literal tr() / UiKit.t() arguments
pat = re.compile(r'(?:\btr|UiKit\.t|TranslationServer\.translate)\(\s*' + STR + r'(?:\s*,\s*' + STR + r')?')
pat_if = re.compile(r'(?:\btr|UiKit\.t)\(\s*' + STR + r'\s+if\s+[^)]*?\belse\s+' + STR)
for f in files:
    src = SRC[f]
    for m in pat.finditer(src):
        need(rel(f), unesc(m.group(1)), unesc(m.group(2) or ''))
    for m in pat_if.finditer(src):
        for g in (1, 2):
            need(rel(f), unesc(m.group(g)))

# ---------------------------------------------------------------- 2. tr(NAME) of a string const
CONST_STR = re.compile(r'^const\s+([A-Z][A-Z0-9_]*)\s*(?::\s*String\s*)?:?=\s*' + STR + r'\s*(?:#.*)?$', re.M)
consts = {}            # file -> {name: value}
by_name = {}           # name -> set of values
for f in files:
    d = {m.group(1): unesc(m.group(2)) for m in CONST_STR.finditer(SRC[f])}
    consts[f] = d
    for k, v in d.items(): by_name.setdefault(k, set()).add(v)
pat_name = re.compile(r'(?:\btr|UiKit\.t|TranslationServer\.translate)\(\s*(?:[A-Z][A-Za-z0-9]*\.)?([A-Z][A-Z0-9_]*)\s*\)')
for f in files:
    for m in pat_name.finditer(SRC[f]):
        n = m.group(1)
        if n in consts[f]: need(rel(f), consts[f][n])
        elif len(by_name.get(n, ())) == 1: need(rel(f), next(iter(by_name[n])))

# ---------------------------------------------------------------- 3. constants translated through a variable
# (file, const, how): how = "all" (every string literal that is not a dict key) or "col1" (the second element of
# each inner array). A package that adds such a constant adds it here.
MSGID_CONSTS = [
    ('scripts/autoload/game.gd', 'RENO_KEEPS', 'all'), ('scripts/autoload/game.gd', 'RENO_RESETS', 'all'),
    ('scripts/autoload/game.gd', 'RENO_ADDS', 'all'), ('scripts/autoload/game.gd', 'RENO_HONEST', 'all'),
    ('scripts/autoload/game.gd', 'MOVE_KEEPS', 'all'), ('scripts/autoload/game.gd', 'MOVE_RESETS', 'all'),
    ('scripts/autoload/game.gd', 'MOVE_ADDS', 'all'), ('scripts/autoload/game.gd', 'PROMO_REASON_TEXT', 'all'),
    ('scripts/v3/core/readout.gd', 'LABELS', 'all'), ('scripts/v3/core/readout.gd', 'MAX_LABEL', 'all'),
    ('scripts/v3/core/readout.gd', 'RIBBON', 'all'), ('scripts/v3/core/readout.gd', 'FIX_LABELS', 'all'),
    ('scripts/v3/ui/bottleneck_meter.gd', 'LABELS', 'all'), ('scripts/v3/ui/bottleneck_meter.gd', 'MAX_TEXT', 'all'),
    ('scripts/v3/ui/bottleneck_meter.gd', 'DROVE_PAST', 'all'), ('scripts/v3/ui/bottleneck_meter.gd', 'ROAD_TEXT', 'all'),
    ('scripts/v3/ui/bottleneck_meter.gd', 'ROAD_SIGNBOARD', 'all'), ('scripts/v3/ui/bottleneck_meter.gd', 'ROAD_LEVEL', 'all'),
    ('scripts/v3/ui/world_note_tag.gd', 'PASS_TEXT', 'all'),
    ('scripts/v3/ui/staff_rows.gd', 'RIBBON', 'all'), ('scripts/v3/ui/staff_rows.gd', 'NOT_BOTTLENECK', 'all'),
    ('scripts/v3/ui/staff_rows.gd', 'NEED_TEXT', 'all'), ('scripts/v3/ui/staff_rows.gd', 'ENOUGH_TEXT', 'all'),
    ('scripts/v3/ui/staff_rows.gd', 'TRAY_NEXT_TEXT', 'all'), ('scripts/v3/ui/staff_rows.gd', 'TRAY_NOW_TEXT', 'all'),
    ('scripts/v3/ui/staff_panel.gd', 'MUNSHI_TITLE', 'all'), ('scripts/v3/ui/staff_panel.gd', 'MUNSHI_LINE', 'all'),
    ('scripts/v3/ui/staff_panel.gd', 'MUNSHI_PROGRESS', 'all'),
    ('scripts/v3/ui/station_sheet.gd', 'SPECIAL_TAG', 'all'),
    ('scripts/v3/ui/event_button.gd', 'CAPTION', 'all'),
    ('scripts/v3/ui/daftar.gd', 'STAT_ROWS', 'col1'),
]
def const_body(src, name):
    m = re.search(r'^const\s+' + name + r'\b[^=\n]*=\s*', src, re.M)
    if not m: return None
    i = m.end(); depth = 0; j = i; ins = False
    while j < len(src):
        c = src[j]
        if ins:
            if c == '\\': j += 2; continue
            if c == '"': ins = False
        elif c == '"': ins = True
        elif c in '[{(': depth += 1
        elif c in ']})': depth -= 1
        elif c == '\n' and depth <= 0: break
        elif c == '#' and depth <= 0: break
        j += 1
    return src[i:j]
const_missing = []
for path, name, how in MSGID_CONSTS:
    f = os.path.join(ROOT, path)
    body = const_body(SRC.get(f, ''), name)
    if body is None:
        const_missing.append('%s %s' % (path, name)); continue
    if how == 'col1':
        vals = [unesc(m.group(1)) for m in re.finditer(r'\[\s*' + STR.replace('(', '(?:', 1) + r'\s*,\s*' + STR, body)]
    else:
        vals = [unesc(m.group(1)) for m in re.finditer(STR, body) if not re.match(r'\s*:', body[m.end():])]
    for v in vals:
        need('%s %s' % (path, name), v)

# ---------------------------------------------------------------- 4. UI literals (auto-translated captions)
UI_DIRS = ('scripts/v3/ui/', 'scripts/v3/tutorial/', 'scripts/v3/fx/')
LIT = STR + r'(?:\s+if\s+[^\n]*?\s+else\s+' + STR + r')?'
UI_PATTERNS = [
    re.compile(r'\bUiButton\.new\(\s*' + LIT),
    re.compile(r'\bUiKit\.label(?:_in)?\(\s*(?:[A-Za-z_][A-Za-z0-9_.]*\s*,\s*)?' + LIT),
    re.compile(r'\bUiKit\.para\(\s*[A-Za-z_][A-Za-z0-9_.]*\s*,\s*' + LIT),
    re.compile(r'\.text\s*=\s*' + LIT + r'\s*$', re.M),
    re.compile(r'\b(?:title_text|caption)\s*(?::\s*String\s*)?=\s*' + LIT + r'\s*$', re.M),
    re.compile(r'\bset_caption\(\s*' + LIT),
    re.compile(r'\b_fit_pill\(\s*' + LIT),
    re.compile(r'\b_extra_card\([^)]*?,\s*' + STR + r'\s*,\s*' + STR + r'\s*\)'),
    re.compile(r'\b_section\(\s*y\s*,\s*' + STR),
]
UI_ALLOW = {'HORN OK PLEASE', 'Dhaba Rush', 'GameAnalytics', 'English', 'हिंदी'}
for f in files:
    r = rel(f)
    if not r.startswith(UI_DIRS): continue
    for p in UI_PATTERNS:
        for m in p.finditer(SRC[f]):
            for g in m.groups():
                if g is None: continue
                t = unesc(g)
                if not re.search(r'[A-Za-z]{2}', t) or t in UI_ALLOW or '%' in t: continue
                need(r + ' (ui)', t)

# ---------------------------------------------------------------- 5. Munshi-ji: ScriptLines.LINES and MunshiNotes *_TEXT
sl = SRC.get(os.path.join(ROOT, 'scripts/v3/tutorial/script_lines.gd'), '')
sl_ids = [unesc(m.group(1)) for m in re.finditer(r'"text"\s*:\s*' + STR, sl)]
sl_miss = [t for t in sl_ids if ('', t) not in po]
for t in sl_ids: need('script_lines.gd LINES', t)
mn = SRC.get(os.path.join(ROOT, 'scripts/v3/tutorial/munshi_notes.gd'), '')
mn_ids = [unesc(m.group(2)) for m in re.finditer(r'^const\s+([A-Z0-9_]*_TEXT)\s*(?::\s*String\s*)?:?=\s*' + STR, mn, re.M)]
mn_miss = [t for t in mn_ids if ('', t) not in po]
for t in mn_ids: need('munshi_notes.gd *_TEXT', t)

# ---------------------------------------------------------------- 6. economy data (NH 44 and every location overlay)
eco = json.load(open(ROOT + '/themes/dhaba/economy.json', encoding='utf-8'))
def walk(o, path):
    if isinstance(o, dict):
        for k, v in o.items(): yield from walk(v, path + [k])
    elif isinstance(o, list):
        for i, v in enumerate(o): yield from walk(v, path + [i])
    elif isinstance(o, str): yield path, o
TEXT_KEYS = {'name', 'noun', 'build_desc', 'serve_text', 'build_text', 'card_name', 'desc', 'text'}
eco_count = {}
def eco_need(where, v, ctx=''):
    n, m = eco_count.get(where, (0, 0))
    eco_count[where] = (n + 1, m + (0 if (ctx, v) in po else 1))
    need('economy ' + where, v, ctx)
for path, v in walk(eco, []):
    k = path[-1] if not isinstance(path[-1], int) else path[-2]
    if path[0] == 'stations' and k in TEXT_KEYS and path[-2:] != ['daynight']:
        eco_need('stations', v)
    if path[0] == 'locations' and len(path) > 3 and path[2] == 'stations' and k in TEXT_KEYS:
        eco_need('locations.%s.stations' % path[1], v)
    if path[0] == 'locations' and len(path) == 3 and path[2] == 'name':
        eco_need('locations.name', v)
    if path[:2] == ['tasks', 'texts'] or (path[:2] == ['tasks', 'defs'] and k == 'text'):
        eco_need('tasks', v)
    if k == 'staff' or (path[0] == 'waiters' and k == 'names'):
        eco_need('names', v, 'name')

# ---------------------------------------------------------------- 7. placeholders, empty, fuzzy
PH = re.compile(r'%(?:\d*\.\d+|0?\d+)?[dsf%]|\{[a-z_]+\}|\[/?[kn]\]|\n')
bad = [(k, v) for k, v in po.items() if sorted(PH.findall(k[1])) != sorted(PH.findall(v)) or not v.strip()]
for k, v in bad:
    print('PLACEHOLDERS / EMPTY:', k, '->', v)
fuzzy = [l for l in open(PO_PATH, encoding='utf-8').read().split('\n') if l.startswith('#,') and 'fuzzy' in l]
for l in fuzzy: print('FUZZY:', l)

# ---------------------------------------------------------------- 8. .pot = .po
pot = parse_po(POT_PATH) if os.path.exists(POT_PATH) else {}
only_po = sorted(set(po) - set(pot)); only_pot = sorted(set(pot) - set(po))
pot_filled = sorted(k for k, v in pot.items() if v != '')
for k in only_po: print('POT: only in hi.po:', k)
for k in only_pot: print('POT: only in dhaba_rush.pot:', k)
for k in pot_filled: print('POT: msgstr not empty in dhaba_rush.pot:', k)

# ---------------------------------------------------------------- 9. stale msgids
lits = set()
for f in files + glob.glob(ROOT + '/scenes/**/*.tscn', recursive=True):
    s = SRC.get(f) or open(f, encoding='utf-8').read()
    for m in re.finditer(STR, s): lits.add(unesc(m.group(1)).replace('\\\\', '\\'))
for _p, v in walk(eco, []): lits.add(v)
stale = sorted(k for k in po if k[1] not in lits)
for k in stale: print('STALE:', k)

# ---------------------------------------------------------------- report
print('msgids in hi.po: %d, in dhaba_rush.pot: %d' % (len(po), len(pot)))
print('SCRIPTLINES text msgids %d, missing %d' % (len(sl_ids), len(sl_miss)))
print('MUNSHI_NOTES *_TEXT msgids %d, missing %d' % (len(mn_ids), len(mn_miss)))
for w in sorted(eco_count): print('ECONOMY %s msgids %d, missing %d' % (w, eco_count[w][0], eco_count[w][1]))
for c in const_missing: print('CONST NOT FOUND (update MSGID_CONSTS):', c)
print('POT only in .po %d, only in .pot %d, filled msgstr %d' % (len(only_po), len(only_pot), len(pot_filled)))
print('STALE (%d)' % len(stale))
print('MISSING (%d):' % len(set(miss)))
for x in sorted(set(miss)): print('  ', x)

# English-looking literals in the UI sources that are not msgids (information only)
if '--literals' in sys.argv:
    lit = re.compile(STR)
    allow = re.compile(r'^[a-z0-9_:%./|\-]*$')
    for f in sorted(glob.glob(ROOT + '/scripts/v3/**/*.gd', recursive=True)):
        if not rel(f).startswith(UI_DIRS): continue
        for n, line in enumerate(open(f, encoding='utf-8').read().split('\n'), 1):
            s = line.strip()
            if s.startswith('#') or re.search(r'\bprint(?:err)?\(|push_(?:warning|error)\(', s): continue
            code = line.split(' #')[0] if '"' not in line.split(' #')[-1] else line
            for m in lit.finditer(code):
                t = unesc(m.group(1))
                if not re.search(r'[A-Za-z]{2}', t) or allow.match(t): continue
                if t in ids: continue
                print('LIT %s:%d %r' % (rel(f), n, t))

# Munshi-ji's [k] words against the on-screen Hindi labels (information only)
if '--keywords' in sys.argv:
    labels = [v for (c, m), v in po.items() if '[k]' not in m]
    names = {m: v for (c, m), v in po.items() if c == 'name'}
    for (c, m), v in sorted(po.items(), key=lambda kv: kv[0][1]):
        en = re.findall(r'\[k\](.*?)\[/k\]', m); hi = re.findall(r'\[k\](.*?)\[/k\]', v)
        if not en: continue
        if len(en) != len(hi):
            print('KEYWORD count %d != %d: %r' % (len(en), len(hi), m)); continue
        for e, h in zip(en, hi):
            want = po.get(('', e)) or names.get(e)
            if want is not None and (h == want or want.endswith(' ' + h) or want.startswith(h + ' ')):
                continue
            if any(h == l or h in l.split(' · ') for l in labels) or any(h in l for l in labels):
                continue
            print('KEYWORD %r -> %r: not an on-screen label (%r)' % (e, h, m))

sys.exit(len(set(miss)) + len(bad) + len(fuzzy) + len(only_po) + len(only_pot) + len(pot_filled) + len(stale))
