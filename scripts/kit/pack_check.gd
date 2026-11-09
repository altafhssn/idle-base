class_name PackCheck
extends RefCounted
## Idle Business Kit, phase 2: checks the running theme pack before anyone
## plays it. Run with `--check-pack` (main3.gd): prints one line per check,
## "[packcheck] ok ..." or "[packcheck] FAIL ...", then "PACKCHECK fails=N"
## and quits with N (the test suite's packcheck job fails on N > 0).
##
## What it checks (theme-agnostic; later phases add layouts, text, skins):
##  1. theme.json: present, valid JSON, kit_version, the game block (name,
##     package, version), the four systems as true/false, the business words.
##  2. economy.json: present, valid JSON, the core sections, every station in
##     station_order defined, the growth and event sections when those
##     systems are on.
##  3. models/: at least one model, and every .glb in it loads as a scene.
##  4. audio/: sounds.json reads; every sound in it and every sound a
##     station's fx names has a file in the pack or the kit.
##  5. text/: every <locale>.json reads (optional; the pack's own wording).
## Models the game asks for at run time but the pack lacks are caught while
## playing: Models prints "[pack] missing model '<id>'" and the suite fails.

const SYSTEMS := ["story", "road", "growth", "events"]
const WORDS := ["business", "service_point", "checkout", "server", "seat_set", "customer", "currency"]
## "galla" may also be spelled "checkout" (the engine's internal name for
## the checkout is galla).
const ECONOMY_SECTIONS := ["start", "station_order", "stations", "galla", "waiters", "seating", "tasks", "offline"]

var fails: int = 0
var oks: int = 0


static func run() -> int:
	var c := PackCheck.new()
	print("[packcheck] theme '%s' at %s" % [ThemePack.id(), ThemePack.root()])
	c._theme()
	c._economy()
	c._models()
	c._audio()
	c._text()
	print("PACKCHECK fails=%d (%d ok)" % [c.fails, c.oks])
	return c.fails


func _ok(msg: String) -> void:
	oks += 1
	print("[packcheck] ok   " + msg)


func _fail(msg: String) -> void:
	fails += 1
	print("[packcheck] FAIL " + msg)


func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_fail("%s is missing" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	var v: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	if not (v is Dictionary):
		_fail("%s is not a valid JSON object" % path)
		return null
	return v


# ---------------------------------------------------------------- theme.json
func _theme() -> void:
	var v: Variant = _json(ThemePack.root() + "theme.json")
	if v == null:
		return
	var t: Dictionary = v
	_ok("theme.json reads")
	if not (t.get("kit_version") is float or t.get("kit_version") is int):
		_fail("theme.json: kit_version (a number) is missing")
	var g: Variant = t.get("game", {})
	for k in ["name", "package", "version"]:
		if not (g is Dictionary) or str((g as Dictionary).get(k, "")) == "":
			_fail("theme.json: game.%s is missing" % k)
	if g is Dictionary:
		_ok("game: %s, %s, v%s" % [str(g.get("name", "")), str(g.get("package", "")), str(g.get("version", ""))])
	var s: Variant = t.get("systems", {})
	for k in SYSTEMS:
		if not (s is Dictionary) or not ((s as Dictionary).get(k) is bool):
			_fail("theme.json: systems.%s (true or false) is missing" % k)
	if s is Dictionary:
		var on: PackedStringArray = PackedStringArray()
		for k in SYSTEMS:
			if bool((s as Dictionary).get(k, false)):
				on.append(k)
		_ok("systems on: %s" % (", ".join(on) if not on.is_empty() else "none"))
	var w: Variant = t.get("words", {})
	var missing: PackedStringArray = PackedStringArray()
	for k in WORDS:
		if not (w is Dictionary) or str((w as Dictionary).get(k, "")) == "":
			missing.append(k)
	if missing.is_empty():
		_ok("business words: %d" % WORDS.size())
	else:
		_fail("theme.json: words missing: %s" % ", ".join(missing))


# ---------------------------------------------------------------- economy.json
func _economy() -> void:
	var v: Variant = _json(ThemePack.economy_path())
	if v == null:
		return
	var e: Dictionary = v
	_ok("economy.json reads (%d sections)" % e.size())
	var missing: PackedStringArray = PackedStringArray()
	for k in ECONOMY_SECTIONS:
		if not e.has(k) and not (k == "galla" and e.has("checkout")):
			missing.append("checkout (or galla)" if k == "galla" else k)
	if ThemePack.system_on("growth") and not e.has("growth"):
		missing.append("growth (the growth system is on)")
	if ThemePack.system_on("events") and not e.has("event"):
		missing.append("event (the events system is on)")
	if missing.is_empty():
		_ok("economy sections present")
	else:
		_fail("economy.json: sections missing: %s" % ", ".join(missing))
	var order: Variant = e.get("station_order", [])
	var defs: Variant = e.get("stations", {})
	if order is Array and defs is Dictionary:
		var undefined: PackedStringArray = PackedStringArray()
		for id in order:
			if not (defs as Dictionary).has(str(id)):
				undefined.append(str(id))
		if (order as Array).is_empty():
			_fail("economy.json: station_order is empty")
		elif undefined.is_empty():
			_ok("stations: %s" % ", ".join(PackedStringArray(order)))
		else:
			_fail("economy.json: stations not defined: %s" % ", ".join(undefined))


# ---------------------------------------------------------------- models
func _models() -> void:
	var dir: String = ThemePack.models_dir()
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	var n: int = 0
	var bad: PackedStringArray = PackedStringArray()
	for f in files:
		if not f.ends_with(".glb"):
			continue
		n += 1
		var res: Resource = load(dir + f)
		if not (res is PackedScene):
			bad.append(f)
	if n == 0:
		_fail("models/: no .glb models in %s" % dir)
	elif bad.is_empty():
		_ok("models: %d .glb, all load" % n)
	else:
		_fail("models: %d of %d do not load: %s" % [bad.size(), n, ", ".join(bad)])


# ---------------------------------------------------------------- audio
func _audio() -> void:
	var table_path: String = ThemePack.audio_dir() + "sounds.json"
	var tv: Variant = _json(table_path)
	var vol: Dictionary = {}
	if tv != null:
		var v: Variant = (tv as Dictionary).get("volume_db", {})
		vol = v if v is Dictionary else {}
		_ok("audio/sounds.json reads (%d sounds)" % vol.size())
	# every sound in the table, and every sound a station's fx names
	var want: Dictionary = {}
	for id in vol.keys():
		want[str(id)] = "sounds.json"
	for sid in Game.station_ids():
		var fx: Variant = Game.station_def(sid).get("fx", {})
		if not (fx is Dictionary):
			continue
		if str((fx as Dictionary).get("cook_sound", "")) != "":
			want[str(fx["cook_sound"])] = "station " + sid
		var ds: Variant = (fx as Dictionary).get("dish_sounds", {})
		if ds is Dictionary:
			for d in ds:
				want[str(ds[d])] = "station " + sid
	var missing: PackedStringArray = PackedStringArray()
	for id in want.keys():
		var found: bool = false
		for dir in [ThemePack.audio_dir(), ThemePack.ENGINE_DIR + "audio/"]:
			for ext in [".ogg", ".wav"]:
				if ResourceLoader.exists(str(dir) + str(id) + ext):
					found = true
		if not found:
			missing.append("%s (%s)" % [id, want[id]])
	if missing.is_empty():
		_ok("sounds: all %d present" % want.size())
	else:
		_fail("sounds missing (%d of %d): %s" % [missing.size(), want.size(), ", ".join(missing)])


# ---------------------------------------------------------------- text
func _text() -> void:
	var dir: String = ThemePack.file("text/")
	var n: int = 0
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			n += 1
			if _json(dir + f) != null:
				_ok("text/%s reads" % f)
	if n == 0:
		_ok("text: none (the engine's English wording)")
