## Player preferences kept between visits: language, name and king colour.
## Registered as the Autoload "Settings". On the web, user:// is stored by the browser.
extends Node

const PATH := "user://settings.cfg"
const SECTION := "player"

## Browser storage key of the device id. localStorage is shared by every tab at once, unlike
## user://, which each tab only reads when it loads.
const DEVICE_KEY := "ctour-device"

## Languages of the game. Adding one is a new column in translations/strings.csv, a new
## entry here and a LANG_<LOCALE> key.
const LOCALES: Array[String] = ["en_GB", "pt_PT"]

var locale: String = "en_GB"
var player_name: String = ""
var color: int = 0

## Random id of this browser or installation. The host uses it to recognise the same person
## coming back or opening the room in another tab. It says nothing about who the person is.
var device_id: String = ""

func _ready() -> void:
	var file := ConfigFile.new()
	var saved: bool = file.load(PATH) == OK

	locale = file.get_value(SECTION, "locale", _default_locale()) if saved else _default_locale()
	if not LOCALES.has(locale):
		locale = LOCALES[0]
	if saved:
		player_name = str(file.get_value(SECTION, "name", ""))
		color = int(file.get_value(SECTION, "color", 0))
		device_id = str(file.get_value(SECTION, "device", ""))
	_load_device_id()

	TranslationServer.set_locale(locale)

func set_locale(value: String) -> void:
	locale = value
	TranslationServer.set_locale(locale)
	save()

func save() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "locale", locale)
	file.set_value(SECTION, "name", player_name)
	file.set_value(SECTION, "color", color)
	file.set_value(SECTION, "device", device_id)
	file.save(PATH)

# Reads the device id, or makes one on the first visit.
func _load_device_id() -> void:
	var on_web: bool = OS.has_feature("web")
	if on_web:
		var stored: Variant = JavaScriptBridge.eval(
				"(function(){try{return window.localStorage.getItem('%s')||''}catch(e){return ''}})()"
				% DEVICE_KEY, true)
		if stored is String and stored != "":
			device_id = stored
	if device_id != "":
		return

	for i in 4:
		device_id += "%08x" % randi()
	if on_web:
		JavaScriptBridge.eval(
				"(function(){try{window.localStorage.setItem('%s','%s')}catch(e){}})()"
				% [DEVICE_KEY, device_id], true)
	else:
		save()

static func language_key(value: String) -> String:
	return "LANG_" + value.to_upper()

# First visit: follow the language of the system when the game has it.
func _default_locale() -> String:
	var system: String = OS.get_locale_language()
	for candidate: String in LOCALES:
		if candidate.begins_with(system):
			return candidate
	return LOCALES[0]
