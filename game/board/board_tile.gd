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
const ICON_SCALE := 0.8
const BUILDING_SPOT := Vector2(-28, -28)
const BUILDING_SCALE := 1.0
const SHIELD_SPOT := Vector2(-6, -36)
const SHIELD_SCALE := 1.0

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

var _upright: Transform2D = Transform2D.IDENTITY
var _depth: int = 0

func _ready() -> void:
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
	flag.visible = is_city
	flag.texture = FLAGS[empire]
	icon.visible = not is_city
	if not is_city:
		icon.texture = ICONS[tile_type]

	queue_redraw()

func _apply_view() -> void:
	if not is_node_ready():
		return
	_stand(icon, ICON_SPOT, ICON_SCALE, 0)
	_stand(building, BUILDING_SPOT, BUILDING_SCALE, 0)
	_stand(shield_icon, SHIELD_SPOT, SHIELD_SCALE, 1)

# Puts a sprite upright on [param spot]. Standing things draw over every ground, and over
# the standing things of the tiles behind (kings use the odd levels in between).
func _stand(sprite: Sprite2D, spot: Vector2, size: float, layer: int) -> void:
	sprite.transform = Transform2D(_upright.x * size, _upright.y * size, spot)
	sprite.z_index = 2 * _depth + 1 + layer
