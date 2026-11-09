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


## Whether a switchable system is on (theme.json "systems"; on when unset,
## so a pack written before a system existed keeps it).
static func system_on(name: String) -> bool:
	var s: Variant = config().get("systems", {})
	if s is Dictionary and (s as Dictionary).has(name):
		return bool((s as Dictionary)[name])
	return true


## Debug and tests: forget the cached choice (a test that switches packs).
static func reset() -> void:
	_id = ""
	_config = {}
	_loaded = false
