## Title screen: name, king colour, language, and the only two actions of the game:
## create a room or join one.
## Layout and styling live in the scene; this script only answers the controls.
class_name MainMenu extends Control

const SHIELD_SIZE := Vector2(44, 52)

## Screen shown once inside a room.
@export_file("*.tscn") var lobby_scene_path: String = ""

## Screen shown when the player is let back into a running match.
@export_file("*.tscn") var match_scene_path: String = ""

@export var name_edit: LineEdit = null

## Row filled with one button per king colour.
@export var color_row: HBoxContainer = null

## Frame around the king's portrait. Its panel style is a StyleBoxFlat made in the scene.
@export var portrait_frame: PanelContainer = null

@export var create_button: Button = null
@export var code_edit: LineEdit = null
@export var join_button: Button = null
@export var language_option: OptionButton = null

## Shows errors and progress. Its text is always a translation key.
@export var status_label: Label = null

var _color: int = 0
var _color_group := ButtonGroup.new()

func _ready() -> void:
	Require.that(lobby_scene_path != "", "MainMenu.lobby_scene_path must be assigned in the editor.")
	Require.that(match_scene_path != "", "MainMenu.match_scene_path must be assigned in the editor.")
	Require.not_null(name_edit, "MainMenu.name_edit must be assigned in the editor.")
	Require.not_null(color_row, "MainMenu.color_row must be assigned in the editor.")
	Require.not_null(portrait_frame, "MainMenu.portrait_frame must be assigned in the editor.")
	Require.not_null(create_button, "MainMenu.create_button must be assigned in the editor.")
	Require.not_null(code_edit, "MainMenu.code_edit must be assigned in the editor.")
	Require.not_null(join_button, "MainMenu.join_button must be assigned in the editor.")
	Require.not_null(language_option, "MainMenu.language_option must be assigned in the editor.")
	Require.not_null(status_label, "MainMenu.status_label must be assigned in the editor.")

	name_edit.max_length = Session.MAX_NAME_LENGTH
	name_edit.text = Settings.player_name
	code_edit.text = _room_from_link()
	_color = Settings.color
	_build_color_row()
	_show_color()
	_build_language_option()

	create_button.pressed.connect(_on_create_pressed)
	join_button.pressed.connect(_on_join_pressed)
	language_option.item_selected.connect(_on_language_selected)

	EventBus.lobby_entered.connect(_on_lobby_entered)
	EventBus.match_started.connect(_on_match_started)
	EventBus.session_closed.connect(_on_session_closed)

	# Says why the previous session ended, when it was not the player's choice.
	status_label.text = Session.close_reason
	Session.close_reason = ""

	name_edit.text_submitted.connect(_on_text_submitted)
	code_edit.text_submitted.connect(_on_text_submitted)

	# On a touch screen the keyboard only opens from a tap, so focusing here would
	# leave the field "active" with no keyboard until the player taps it twice.
	if not DisplayServer.is_touchscreen_available():
		name_edit.grab_focus()

# Enter / the keyboard's "done" key confirms the field and closes the on-screen keyboard.
func _on_text_submitted(_text: String) -> void:
	DisplayServer.virtual_keyboard_hide()
	get_viewport().gui_release_focus()

func _build_color_row() -> void:
	for index in KingPalette.COLORS.size():
		var button := ShieldButton.new()
		button.custom_minimum_size = SHIELD_SIZE
		button.color = KingPalette.COLORS[index]
		button.button_group = _color_group
		button.button_pressed = index == _color
		button.pressed.connect(_on_color_pressed.bind(index))
		color_row.add_child(button)

# The frame of the portrait wears the king's colour.
func _show_color() -> void:
	var frame: StyleBoxFlat = portrait_frame.get_theme_stylebox("panel")
	frame.bg_color = KingPalette.color_of(_color)

func _build_language_option() -> void:
	for index in Settings.LOCALES.size():
		language_option.add_item(Settings.language_key(Settings.LOCALES[index]))
		if Settings.LOCALES[index] == Settings.locale:
			language_option.select(index)

# A link shared by the host carries the room code: ...?room=ABC123
func _room_from_link() -> String:
	if not OS.has_feature("web"):
		return ""
	var code: Variant = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('room') || ''", true)
	return RoomCode.normalise(str(code)) if code != null else ""

# Checks the name, remembers the choices and locks the buttons while connecting.
func _begin() -> bool:
	if name_edit.text.strip_edges() == "":
		status_label.text = "ERR_NAME_REQUIRED"
		return false

	Settings.player_name = name_edit.text.strip_edges()
	Settings.color = _color
	Settings.save()

	status_label.text = "UI_CONNECTING"
	_set_busy(true)
	return true

func _set_busy(busy: bool) -> void:
	create_button.disabled = busy
	join_button.disabled = busy

# Connected in _build_color_row() to each colour button.
func _on_color_pressed(index: int) -> void:
	_color = index
	_show_color()

# Connected in _ready() to create_button.pressed.
func _on_create_pressed() -> void:
	if _begin():
		Session.create_room(Settings.player_name, _color)

# Connected in _ready() to join_button.pressed.
func _on_join_pressed() -> void:
	if RoomCode.normalise(code_edit.text) == "":
		status_label.text = "ERR_CODE_REQUIRED"
		return
	if _begin():
		Session.join_room(code_edit.text, Settings.player_name, _color)

# Connected in _ready() to language_option.item_selected.
func _on_language_selected(index: int) -> void:
	Settings.set_locale(Settings.LOCALES[index])

# Connected in _ready() to EventBus.lobby_entered.
func _on_lobby_entered() -> void:
	get_tree().change_scene_to_file(lobby_scene_path)

# Connected in _ready() to EventBus.match_started.
func _on_match_started() -> void:
	get_tree().change_scene_to_file(match_scene_path)

# Connected in _ready() to EventBus.session_closed.
func _on_session_closed(reason_key: String) -> void:
	status_label.text = reason_key
	Session.close_reason = ""
	_set_busy(false)
