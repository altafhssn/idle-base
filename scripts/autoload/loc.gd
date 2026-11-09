extends Node
## Language (autoload "Loc", launch blockers track B): English or Hindi for
## every player-facing string.
##
## English is the source text, written in code and data as the gettext msgid;
## Hindi comes from res://i18n/hi.po (loaded by TranslationServer from
## project.godot internationalization/locale/translations; the template for
## more languages is res://i18n/dhaba_rush.pot). docs/launch/hindi.md has the
## glossary and the native-speaker review list.
##
## How the UI uses it:
##  - a Label / Button caption / RichTextLabel whose text is a plain English
##    literal is translated by Godot itself (auto-translate) and re-translated
##    live when the language changes: nothing else to do;
##  - composed text (numbers, names, placeholders) is built with tr() (nodes)
##    or UiKit.t() (static code) and rebuilt on NOTIFICATION_TRANSLATION_CHANGED
##    (Godot sends it to every node when the locale changes) or on
##    `language_changed`;
##  - custom-drawn text calls tr() inside _draw() and queue_redraw()s on the
##    notification;
##  - "English label + small Hindi subtitle" pairs show the Hindi alone, as the
##    main label, in Hindi (UiKit.is_hindi()).
##
## The choice is saved as "lang" in user://settings.json (Sfx keeps the other
## keys). First launch: the device language (hi -> Hindi, anything else ->
## English). Debug builds: --lang=hi / --lang=en (after `--`) overrides it for
## that run without saving.

signal language_changed(code: String)

const LANGS: Array[String] = ["en", "hi"]
## Each language in its own script (the Settings LANGUAGE toggle).
const NATIVE := {"en": "English", "hi": "हिंदी"}
const SETTINGS_PATH := "user://settings.json"

var lang: String = "en"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Idle Business Kit: the theme pack's own wording (text/<locale>.json).
	ThemePack.install_text()
	var code: String = saved_language()
	if code == "":
		code = device_language()
	var flag: String = _flag_language()
	if flag != "":
		code = flag
	_apply(code)


## "hi" when the device's language is Hindi (hi, hi_IN), else "en".
static func device_language() -> String:
	return "hi" if OS.get_locale_language() == "hi" else "en"


func is_hindi() -> bool:
	return lang == "hi"


## Native name of a language code ("हिंदी").
static func native_name(code: String) -> String:
	return str(NATIVE.get(code, code))


## The next language in LANGS (the Settings toggle cycles through them).
func next_language() -> String:
	var i: int = LANGS.find(lang)
	return LANGS[(i + 1) % LANGS.size()]


## Switches live: TranslationServer locale (every node gets
## NOTIFICATION_TRANSLATION_CHANGED), Fmt's unit words, Game's task texts and
## numbers, then `language_changed`. Saved for the next launch.
func set_language(code: String) -> void:
	if not LANGS.has(code) or code == lang:
		return
	_apply(code)
	_save(code)
	var g: Node = get_node_or_null("/root/Game")
	if g != null and g.has_method("relocalize"):
		g.call("relocalize")
	var a: Node = get_node_or_null("/root/Analytics")
	if a != null and a.has_method("event"):
		a.call("event", "language_changed", {"lang": code})
	language_changed.emit(code)


## The saved choice ("" when none or unknown).
static func saved_language() -> String:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return ""
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return ""
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return ""
	var code: String = str((d as Dictionary).get("lang", ""))
	return code if LANGS.has(code) else ""


func _apply(code: String) -> void:
	lang = code if LANGS.has(code) else "en"
	TranslationServer.set_locale(lang)
	Fmt.set_hindi(lang == "hi")


## Read-modify-write: the sound / music / vibration keys stay as they are.
func _save(code: String) -> void:
	var d: Dictionary = {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var r := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if r != null:
			var v: Variant = JSON.parse_string(r.get_as_text())
			if v is Dictionary:
				d = v
	d["lang"] = code
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


## --lang=hi / --lang=en (debug builds only; "" when absent or unknown).
static func _flag_language() -> String:
	if not OS.is_debug_build():
		return ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			var code: String = arg.get_slice("=", 1).to_lower()
			if LANGS.has(code):
				return code
	return ""
