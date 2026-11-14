## Waiting room: the room code, who is in, who is ready. The host starts the match once
## everyone is ready.
## Layout and styling live in the scene; this script fills the list and answers the buttons.
class_name Lobby extends Control

@export_file("*.tscn") var main_menu_path: String = ""
@export_file("*.tscn") var match_scene_path: String = ""

## Shows the room code, as it is.
@export var code_label: Label = null

## Copies the invitation: a link with the room code on the web, the code alone elsewhere.
@export var copy_button: Button = null

## Filled with one row per player.
@export var player_list: VBoxContainer = null

## Explains what to do. Its text is always a translation key.
@export var hint_label: Label = null

@export var ready_button: Button = null

## Host only.
@export var start_button: Button = null

## Local rooms only: adds a player who shares the screen.
@export var add_local_button: Button = null

@export var leave_button: Button = null

func _ready() -> void:
	Require.that(main_menu_path != "", "Lobby.main_menu_path must be assigned in the editor.")
	Require.that(match_scene_path != "", "Lobby.match_scene_path must be assigned in the editor.")
	Require.not_null(code_label, "Lobby.code_label must be assigned in the editor.")
	Require.not_null(copy_button, "Lobby.copy_button must be assigned in the editor.")
	Require.not_null(player_list, "Lobby.player_list must be assigned in the editor.")
	Require.not_null(hint_label, "Lobby.hint_label must be assigned in the editor.")
	Require.not_null(ready_button, "Lobby.ready_button must be assigned in the editor.")
	Require.not_null(start_button, "Lobby.start_button must be assigned in the editor.")
	Require.not_null(add_local_button, "Lobby.add_local_button must be assigned in the editor.")
	Require.not_null(leave_button, "Lobby.leave_button must be assigned in the editor.")

	copy_button.pressed.connect(_on_copy_pressed)
	ready_button.toggled.connect(_on_ready_toggled)
	start_button.pressed.connect(_on_start_pressed)
	add_local_button.pressed.connect(_on_add_local_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

	EventBus.lobby_changed.connect(_refresh)
	EventBus.match_started.connect(_on_match_started)
	EventBus.session_closed.connect(_on_session_closed)

	var local_room: bool = Session.is_host() and not Session.is_online()
	code_label.text = Session.room_code
	copy_button.visible = Session.is_online()
	start_button.visible = Session.is_host()
	add_local_button.visible = local_room
	if local_room:
		hint_label.text = "UI_LOBBY_HINT_LOCAL"
	elif Session.is_host():
		hint_label.text = "UI_LOBBY_HINT_HOST"
	else:
		hint_label.text = "UI_LOBBY_HINT_CLIENT"

	_refresh()

# Connected in _ready() to EventBus.lobby_changed.
func _refresh() -> void:
	for row: Node in player_list.get_children():
		player_list.remove_child(row)
		row.queue_free()
	for entry: Dictionary in Session.lobby:
		player_list.add_child(_make_row(entry))

	start_button.disabled = not Session.can_start()
	add_local_button.disabled = Session.lobby.size() >= Session.CONFIG.max_players

func _make_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(28, 28)
	swatch.color = KingPalette.color_of(entry.color)
	row.add_child(swatch)

	# Player names are not translation keys.
	var name_label := Label.new()
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.text = entry.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	if Session.controls(entry.id):
		var you_label := Label.new()
		you_label.text = "UI_YOU_TAG"
		row.add_child(you_label)

	var ready_label := Label.new()
	ready_label.text = "UI_READY" if entry.ready else "UI_NOT_READY"
	ready_label.modulate = Color(0.5, 1.0, 0.55) if entry.ready else Color(1.0, 0.65, 0.5)
	row.add_child(ready_label)

	return row

# Connected in _ready() to copy_button.pressed.
func _on_copy_pressed() -> void:
	var invitation: String = Session.room_code
	if OS.has_feature("web"):
		var base: Variant = JavaScriptBridge.eval(
				"window.location.origin + window.location.pathname", true)
		invitation = "%s?room=%s" % [base, Session.room_code]
	DisplayServer.clipboard_set(invitation)
	copy_button.text = "UI_COPIED"

# Connected in _ready() to ready_button.toggled.
func _on_ready_toggled(pressed: bool) -> void:
	Session.set_ready(pressed)

# Connected in _ready() to start_button.pressed.
func _on_start_pressed() -> void:
	Session.start_match()

# Connected in _ready() to add_local_button.pressed.
func _on_add_local_pressed() -> void:
	var player_name: String = tr("UI_LOCAL_PLAYER_NAME").format({"number": Session.lobby.size() + 1})
	Session.add_local_player(player_name)

# Connected in _ready() to leave_button.pressed.
func _on_leave_pressed() -> void:
	Session.leave()
	get_tree().change_scene_to_file(main_menu_path)

# Connected in _ready() to EventBus.match_started.
func _on_match_started() -> void:
	get_tree().change_scene_to_file(match_scene_path)

# Connected in _ready() to EventBus.session_closed.
func _on_session_closed(_reason_key: String) -> void:
	get_tree().change_scene_to_file(main_menu_path)
