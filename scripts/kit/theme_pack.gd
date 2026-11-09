class_name ThemePack
extends RefCounted
## Idle Business Kit, phase 2: the theme pack the game runs.
##
## A pack is one folder, res://themes/<id>/, holding everything one game owns:
##   theme.json      the game (name, package, version), the systems switched
##                   on, the business words, and optional path overrides
##   economy.json    prices, levels, staff, seats, checkout, pacing
##   models/         .glb models (+ their extracted palettes)
##   audio/          sounds and music, file name = sound id
##   textures/       pictures the UI shows (narrator sprites, previews...)
## The pack is picked by the launch flag `--theme=<id>` (after `--`), else
## the project setting `idle_business_kit/theme`, else DEFAULT_ID.
## Engine code never builds a pack path itself: it asks here (models via
## Models.path_of, sounds via Sfx, the economy via economy_path()).
## A file the pack lacks may fall back to ENGINE_DIR (the kit's own default
## art; empty for now), so a new pack can start small.

const DEFAULT_ID := "dhaba"
const SETTING := "idle_business_kit/theme"
const THEMES_DIR := "res://themes/"
## The kit's own fallback content (same sub-folders as a pack).
const ENGINE_DIR := "res://kit/"

static var _id: String = ""
static var _config: Dictionary = {}
static var _loaded: bool = false


## The running pack's id.
static func id() -> String:
	if _id == "":
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--theme="):
				_id = a.substr(8)
		if _id == "" and ProjectSettings.has_setting(SETTING):
			_id = str(ProjectSettings.get_setting(SETTING))
		if _id == "":
			_id = DEFAULT_ID
	return _id


## res://themes/<id>/
static func root() -> String:
	return THEMES_DIR + id() + "/"


## theme.json as a Dictionary ({} when missing or invalid; the pack checker
## reports why).
static func config() -> Dictionary:
	if not _loaded:
		_loaded = true
		var f := FileAccess.open(root() + "theme.json", FileAccess.READ)
		if f != null:
			var v: Variant = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_config = v
	return _config


## A path inside the pack: theme.json "paths" may rename a standard file or
## folder (key = the standard name, e.g. "economy.json" or "models/").
static func file(rel: String) -> String:
	var paths: Variant = config().get("paths", {})
	if paths is Dictionary and (paths as Dictionary).has(rel):
		return root() + str((paths as Dictionary)[rel])
	return root() + rel


static func economy_path() -> String:
	return file("economy.json")


static func models_dir() -> String:
	return file("models/")


static func audio_dir() -> String:
	return file("audio/")


static func textures_dir() -> String:
	return file("textures/")


## A texture of the pack by its path under textures/ ("" when neither the
## pack nor the kit has it).
static func texture_path(rel: String) -> String:
	var p: String = textures_dir() + rel
	if ResourceLoader.exists(p):
		return p
	p = ENGINE_DIR + "textures/" + rel
	return p if ResourceLoader.exists(p) else ""


## The pack's "game" block ({name, package, version}).
static func game() -> Dictionary:
	var g: Variant = config().get("game", {})
	return g if g is Dictionary else {}


## The pack's money style (theme.json "money"): symbol (shown before
## amounts) and number_style ("auto" = lakh / crore on Indian locales,
## "indian", or "intl").
static func money() -> Dictionary:
	var m: Variant = config().get("money", {})
	var out: Dictionary = {"symbol": "$", "number_style": "intl"}
	if m is Dictionary:
		out.merge(m, true)
	return out


## The economy's money_display_scale (stored reference units x this = shown).
static func money_display_scale() -> float:
	var f := FileAccess.open(economy_path(), FileAccess.READ)
	var v: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	if v is Dictionary:
		return float((v as Dictionary).get("money_display_scale", 1.0))
	return 1.0


## Whether a switchable system is on (theme.json "systems"; on when unset,
## so a pack written before a system existed keeps it).
static func system_on(name: String) -> bool:
	var s: Variant = config().get("systems", {})
	if s is Dictionary and (s as Dictionary).has(name):
		return bool((s as Dictionary)[name])
	return true


## The pack's own wording (text/<locale>.json), installed as translations
## so every on-screen string can be renamed by a pack without code: a car
## wash renames "CASH COUNTER" to "PAY DESK" in text/en.json. Format:
##   {"messages": {"<engine English>": "<pack text>"},
##    "contexts": {"<context>": {"<engine English>": "<pack text>"}}}
## Called once by Loc before the UI is built. Returns the messages installed.
static func install_text() -> int:
	var n: int = 0
	var dir: String = file("text/")
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"):
			continue
		var fa := FileAccess.open(dir + f, FileAccess.READ)
		var v: Variant = JSON.parse_string(fa.get_as_text()) if fa != null else null
		if not (v is Dictionary):
			push_warning("ThemePack: %s%s is not a JSON object" % [dir, f])
			continue
		var t := Translation.new()
		t.locale = f.get_basename()
		var msgs: Variant = (v as Dictionary).get("messages", {})
		if msgs is Dictionary:
			for k in msgs:
				t.add_message(str(k), str(msgs[k]))
				n += 1
		var ctxs: Variant = (v as Dictionary).get("contexts", {})
		if ctxs is Dictionary:
			for c in ctxs:
				var cm: Variant = ctxs[c]
				if cm is Dictionary:
					for k in cm:
						t.add_message(str(k), str(cm[k]), str(c))
						n += 1
		TranslationServer.add_translation(t)
	if n > 0:
		print("[pack] %d text lines from %s" % [n, dir])
	return n


## Debug and tests: forget the cached choice (a test that switches packs).
static func reset() -> void:
	_id = ""
	_config = {}
	_loaded = false
