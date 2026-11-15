## One tile of the board. Everything about it is edited in the Inspector: type, name
## (a translation key such as CITY_LISBON) and empire. The flag, the icon and the text follow
## those values on their own, in the editor too. Building a board is duplicating tiles and
## changing the name and the empire.
##
## The ground of the tile (colour, flag, texts) follows the board, so it is skewed with it in
## the isometric view. The icon, the building and the shield stand upright on it.
@tool
class_name BoardTile extends Node2D

## Side of the square tile, in pixels.
const SIZE := 92.0

const FLAGS := {
	GameEnums.Empire.PORTUGAL: preload("res://board/flags/portugal.png"),
	GameEnums.Empire.SPAIN: preload("res://board/flags/spain.png"),
	GameEnums.Empire.BRITAIN: preload("res://board/flags/britain.png"),
	GameEnums.Empire.FRANCE: preload("res://board/flags/france.png"),
	GameEnums.Empire.OTTOMAN: preload("res://board/flags/ottoman.png"),
	GameEnums.Empire.NETHERLANDS: preload("res://board/flags/netherlands.png"),
	GameEnums.Empire.CHINA: preload("res://board/flags/china.png"),
	GameEnums.Empire.JAPAN: preload("res://board/flags/japan.png"),
}

const ICONS := {
	GameEnums.TileType.CHURCH: preload("res://board/icons/church.png"),
	GameEnums.TileType.START: preload("res://board/icons/start.png"),
	GameEnums.TileType.HELL: preload("res://board/icons/hell.png"),
	GameEnums.TileType.POPE_CALL: preload("res://board/icons/pope_call.png"),
	GameEnums.TileType.TAX: preload("res://board/icons/tax.png"),
	GameEnums.TileType.ROULETTE: preload("res://board/icons/roulette.png"),
}

## Building sprite for each GameEnums.Level.
const BUILDINGS: Array[Texture2D] = [
	preload("res://board/buildings/land.png"),
	preload("res://board/buildings/shack.png"),
	preload("res://board/buildings/house.png"),
	preload("res://board/buildings/castle.png"),
]

const BACKGROUNDS := {
	GameEnums.TileType.CITY: Color(0.93, 0.87, 0.72),
	GameEnums.TileType.CHURCH: Color(0.84, 0.88, 0.96),
	GameEnums.TileType.START: Color(0.70, 0.90, 0.68),
	GameEnums.TileType.HELL: Color(0.93, 0.55, 0.45),
	GameEnums.TileType.POPE_CALL: Color(0.96, 0.92, 0.62),
	GameEnums.TileType.TAX: Color(0.80, 0.80, 0.82),
	GameEnums.TileType.ROULETTE: Color(0.78, 0.64, 0.88),
}

const BORDER_COLOR := Color(0.20, 0.14, 0.24)
const HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.1)

## Where the upright sprites stand on the tile (their feet), and their scale.
const ICON_SPOT := Vector2(-24, -24)
const ICON_SCALE := 1.5
const BUILDING_SPOT := Vector2(-28, -28)
const BUILDING_SCALE := 2.0
const SHIELD_SPOT := Vector2(-2, -40)
const SHIELD_SCALE := 2.0

## The name is written as big as it fits: no word broken and no more than two lines.
const NAME_FONT_MAX := 19
const NAME_FONT_MIN := 9

## The glow of a tile a king just landed on: a halo of light around it that pulses twice.
const GLOW_COLOR := Color(1.0, 0.82, 0.25)
const GLOW_RINGS := 10
const GLOW_RING_WIDTH := 4.0

## The tile is also pressed down by the king and springs back: how small it gets, how far it
## overshoots on the way back, and how deep it sinks, in screen pixels.
const SQUASH_SCALE := 0.68
const BOUNCE_SCALE := 1.28
const SQUASH_DEPTH := 20.0

## What the tile is. Cities and churches can be bought; the others are special tiles.
@export var tile_type: GameEnums.TileType = GameEnums.TileType.CITY:
	set(value):
		tile_type = value
		_refresh()

## Translation key of the name shown on the tile (for example CITY_LISBON).
@export var city_name: String = "":
	set(value):
		city_name = value
		_refresh()

## Empire of a city. Sets the flag, and every city of the same empire forms a monopoly.
@export var empire: GameEnums.Empire = GameEnums.Empire.PORTUGAL:
	set(value):
		empire = value
		_refresh()

@export_group("Nodes")
@export var flag: Sprite2D = null
@export var icon: Sprite2D = null
@export var name_label: Label = null
@export var info_label: Label = null
@export var building: Sprite2D = null
@export var shield_icon: Sprite2D = null

var _has_owner: bool = false
var _owner_color: Color = Color.WHITE
var _highlighted: bool = false

# Strength of the glow, from 0 (off) to 1.
var _glow: float = 0.0:
	set(value):
		_glow = value
		if _glow_layer != null:
			_glow_layer.queue_redraw()

var _glow_tween: Tween = null
var _squash_tween: Tween = null

# Where the Board put the tile, to come back to after the squash.
var _rest_position: Vector2 = Vector2.ZERO

# Draws the glow. Its own node, so the light spills over the neighbouring tiles (it is above
# every ground) while buildings, icons and kings stay in front of it.
var _glow_layer: Node2D = null

var _upright: Transform2D = Transform2D.IDENTITY
var _depth: int = 0

func _ready() -> void:
	_glow_layer = Node2D.new()
	_glow_layer.z_index = 1
	var light := CanvasItemMaterial.new()
	light.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_layer.material = light
	_glow_layer.draw.connect(_draw_glow)
	add_child(_glow_layer, false, Node.INTERNAL_MODE_FRONT)

	_refresh()
	_apply_view()

## Entry of this tile in the board definition used by the rules.
func to_definition() -> Dictionary:
	return {"type": tile_type, "empire": empire, "key": city_name}

## Called by the Board. [param upright] cancels the board's transform, so the sprites that
## use it stand straight on a skewed board; [param depth] orders them back to front.
func set_view(upright: Transform2D, depth: int) -> void:
	_upright = upright
	_depth = depth
	_apply_view()

## Shows who owns the tile and what is built on it. [param info] is the already formatted
## price or rent.
func show_ownership(has_owner: bool, color: Color, level: int, shielded: bool, info: String) -> void:
	_has_owner = has_owner
	_owner_color = color

	info_label.text = info
	shield_icon.visible = shielded
	building.visible = has_owner and tile_type == GameEnums.TileType.CITY
	if building.visible:
		building.texture = BUILDINGS[level]
		# Only the bare land carries the owner's colour, as a pennant.
		building.modulate = color if level == GameEnums.Level.LAND else Color.WHITE

	queue_redraw()

## Makes the tile glow for a moment: a king just landed on it.
func flash() -> void:
	if _glow_tween != null:
		_glow_tween.kill()
	_glow = 0.0
	_glow_tween = create_tween()
	_glow_tween.tween_property(self, "_glow", 1.0, 0.15)
	_glow_tween.tween_property(self, "_glow", 0.4, 0.3)
	_glow_tween.tween_property(self, "_glow", 1.0, 0.25)
	_glow_tween.tween_property(self, "_glow", 0.0, 0.8)
	_squash()

# Squash and stretch: the tile sinks and shrinks under the king, then springs back a little
# too far and settles.
func _squash() -> void:
	if _squash_tween != null:
		_squash_tween.kill()
	else:
		_rest_position = position

	# "Down" on screen, in the board's own (possibly skewed) coordinates.
	var sunk: Vector2 = _rest_position + _upright * Vector2(0, SQUASH_DEPTH)

	_squash_tween = create_tween()
	_squash_tween.tween_property(self, "scale", Vector2.ONE * SQUASH_SCALE, 0.09) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash_tween.parallel().tween_property(self, "position", sunk, 0.09)
	_squash_tween.tween_property(self, "scale", Vector2.ONE * BOUNCE_SCALE, 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash_tween.parallel().tween_property(self, "position", _rest_position, 0.14)
	_squash_tween.tween_property(self, "scale", Vector2.ONE, 0.6) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_callback(_end_squash)

func _end_squash() -> void:
	_squash_tween = null

# Connected in _ready() to the draw signal of the glow layer.
func _draw_glow() -> void:
	if _glow <= 0.0:
		return
	var rect := Rect2(-SIZE / 2.0, -SIZE / 2.0, SIZE, SIZE)

	# The tile itself lights up, and rings of light fade out around it.
	_glow_layer.draw_rect(rect, Color(GLOW_COLOR, 0.45 * _glow))
	_glow_layer.draw_rect(rect.grow(-3.0), Color(1, 1, 1, 0.8 * _glow), false, 6.0)
	for ring in GLOW_RINGS:
		var fade: float = 1.0 - float(ring) / GLOW_RINGS
		_glow_layer.draw_rect(rect.grow((ring + 0.5) * GLOW_RING_WIDTH),
				Color(GLOW_COLOR, 0.55 * fade * fade * _glow), false, GLOW_RING_WIDTH)

func _notification(what: int) -> void:
	# The name changes length with the language.
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fit_name()

func set_highlighted(value: bool) -> void:
	if _highlighted != value:
		_highlighted = value
		queue_redraw()

func _draw() -> void:
	var rect := Rect2(-SIZE / 2.0, -SIZE / 2.0, SIZE, SIZE)

	draw_rect(rect, BACKGROUNDS[tile_type])
	if _has_owner:
		draw_rect(Rect2(rect.position.x, rect.end.y - 12.0, SIZE, 12.0), _owner_color)
	draw_rect(rect, BORDER_COLOR, false, 2.0)
	if _highlighted:
		draw_rect(rect.grow(-4.0), HIGHLIGHT_COLOR, false, 5.0)

func _refresh() -> void:
	if not is_node_ready():
		return

	var is_city: bool = tile_type == GameEnums.TileType.CITY

	name_label.text = city_name
	_fit_name()
	flag.visible = is_city
	flag.texture = FLAGS[empire]
	icon.visible = not is_city
	if not is_city:
		icon.texture = ICONS[tile_type]

	queue_redraw()

# Picks the biggest font size that keeps the translated name inside the tile.
func _fit_name() -> void:
	var font: Font = name_label.get_theme_font("font")
	var text: String = tr(city_name)
	var width: float = name_label.size.x
	var font_size: int = NAME_FONT_MAX

	while font_size > NAME_FONT_MIN:
		var fits: bool = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width,
				font_size).y <= 2.2 * font.get_height(font_size)
		for word: String in text.split(" "):
			fits = fits and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width
		if fits:
			break
		font_size -= 1

	name_label.add_theme_font_size_override("font_size", font_size)

func _apply_view() -> void:
	if not is_node_ready():
		return
	_stand(icon, ICON_SPOT, ICON_SCALE, 0)
	_stand(building, BUILDING_SPOT, BUILDING_SCALE, 0)
	_stand(shield_icon, SHIELD_SPOT, SHIELD_SCALE, 1)

# Puts a sprite upright on [param spot]. Standing things draw over every ground and over the
# glow (level 1), and over the standing things of the tiles behind (kings use the levels in
# between).
func _stand(sprite: Sprite2D, spot: Vector2, size: float, layer: int) -> void:
	sprite.transform = Transform2D(_upright.x * size, _upright.y * size, spot)
	sprite.z_index = 2 * _depth + 2 + layer
