## Pop-up shown to the player who landed on a property they can buy or build on. Lists at
## once every level on offer, each with its picture above its name and its total price, plus
## the option to skip.
## The options come from the host (state.pending.options); this only sends the choice.
class_name BuyPopup extends PanelContainer

const OPTION_SIZE := Vector2(200, 180)
const ICON_WIDTH := 92
const OPTION_FONT_SIZE := 20

## Name of the property. Its text is a translation key.
@export var title_label: Label = null

## Filled with one button per level on offer.
@export var options_box: HBoxContainer = null

@export var skip_button: Button = null

## Point of the screen the pop-up is centred on.
@export var centre: Vector2 = Vector2(800, 462)

# Changes with every refresh, so a delayed opening knows when it is out of date.
var _version: int = 0

func _ready() -> void:
	Require.not_null(title_label, "BuyPopup.title_label must be assigned in the editor.")
	Require.not_null(options_box, "BuyPopup.options_box must be assigned in the editor.")
	Require.not_null(skip_button, "BuyPopup.skip_button must be assigned in the editor.")

	skip_button.pressed.connect(_on_skip_pressed)
	visible = false

## Opens after [param delay] seconds, the time the dice and the king take to get there.
func refresh(state: GameState, delay: float = 0.0) -> void:
	_version += 1
	var wanted: bool = state.phase == GameEnums.Phase.BUY and Session.controls(state.actor)
	if not wanted:
		visible = false
		return

	var tile: Dictionary = state.board[state.pending.tile]
	title_label.text = tile.key

	for button: Node in options_box.get_children():
		options_box.remove_child(button)
		button.queue_free()
	for option: Dictionary in state.pending.options:
		options_box.add_child(_make_button(tile, option))

	# Fits the options on offer and stays centred on the board.
	reset_size()
	position = centre - size / 2.0

	if delay > 0.0 and not visible:
		var version: int = _version
		await get_tree().create_timer(delay).timeout
		if version != _version:
			return
	visible = true

func _make_button(tile: Dictionary, option: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = OPTION_SIZE
	button.add_theme_font_size_override("font_size", OPTION_FONT_SIZE)

	# The picture of what is bought, above its name.
	button.icon = _picture(tile, option.level)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", ICON_WIDTH)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

	# Name and price on their own lines: already translated, so not a key.
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = "%s\n%s" % [tr(GameEnums.level_key(option.level)), MoneyFormat.full(option.price)]

	button.pressed.connect(_on_option_pressed.bind(int(option.level)))
	return button

func _picture(tile: Dictionary, level: int) -> Texture2D:
	if tile.type == GameEnums.TileType.CHURCH:
		return BoardTile.ICONS[GameEnums.TileType.CHURCH]
	return BoardTile.BUILDINGS[level]

# Connected in _make_button() to each option button.
func _on_option_pressed(level: int) -> void:
	Session.send_intent(Intent.buy(level))

# Connected in _ready() to skip_button.pressed.
func _on_skip_pressed() -> void:
	Session.send_intent(Intent.make(Intent.SKIP))
