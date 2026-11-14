## The board: a square ring of BoardTile children. Their order in the scene tree is the order
## of play, and their positions are laid out from that order, so rearranging the board is
## just reordering (or duplicating) tiles in the editor.
##
## Tile 0 is the bottom-right corner of the flat board and play goes clockwise. The tile count
## must be a multiple of 4; each quarter of the list is one side, starting at its corner.
##
## The board is edited flat. The isometric view of the match is only the Transform of this
## node in the scene that uses it: the ground follows the transform, while buildings, icons
## and kings are kept upright (see BoardTile.set_view and get_tile_screen_position).
@tool
class_name Board extends Node2D

signal tile_clicked(index: int)

## Height of the slab the board sits on, in screen pixels.
const THICKNESS := 16.0

const GROUND_COLOR := Color(0.10, 0.24, 0.32)
const SLAB_COLOR := Color(0.05, 0.10, 0.16)

func _ready() -> void:
	child_order_changed.connect(layout)
	layout()

## Tiles in order of play.
func get_tiles() -> Array[BoardTile]:
	var tiles: Array[BoardTile] = []
	for child: Node in get_children():
		if child is BoardTile:
			tiles.append(child)
	return tiles

## Board definition consumed by the rules: one { type, empire, key } per tile.
func to_definition() -> Array:
	var definition: Array = []
	for tile: BoardTile in get_tiles():
		definition.append(tile.to_definition())
	return definition

## Side of the whole flat board, in pixels.
func get_pixel_size() -> float:
	return (get_tiles().size() / 4.0 + 1.0) * BoardTile.SIZE

## Centre of a tile, in the board's flat local coordinates.
func get_tile_position(index: int) -> Vector2:
	var count: int = get_tiles().size()
	if count < 4:
		return Vector2.ZERO
	return (Vector2(_grid_cell(index, count / 4)) + Vector2(0.5, 0.5)) * BoardTile.SIZE

## Centre of a tile as seen on screen, in the coordinates of the board's parent. Use it to
## place things that stand on the board without being skewed by it, like the kings.
func get_tile_screen_position(index: int) -> Vector2:
	return transform * get_tile_position(index)

## How close a tile is to the viewer: bigger is nearer. Things standing on nearer tiles are
## drawn over the ones behind them.
func get_tile_depth(index: int) -> int:
	var count: int = get_tiles().size()
	if count < 4:
		return 0
	var cell: Vector2i = _grid_cell(index, count / 4)
	return cell.x + cell.y

func layout() -> void:
	if not is_inside_tree():
		return

	var tiles: Array[BoardTile] = get_tiles()
	if not Engine.is_editor_hint():
		Require.that(tiles.size() >= 4 and tiles.size() % 4 == 0,
				"Board needs a tile count that is a multiple of 4.")

	var upright: Transform2D = _upright_basis()
	for i in tiles.size():
		tiles[i].position = get_tile_position(i)
		tiles[i].set_view(upright, get_tile_depth(i))

	queue_redraw()

## Marks the tiles the local player can pick.
func highlight(indices: Array) -> void:
	var tiles: Array[BoardTile] = get_tiles()
	for i in tiles.size():
		tiles[i].set_highlighted(indices.has(i))

# The ground inside the ring and the slab under the whole board. The tiles draw over it.
func _draw() -> void:
	var side: float = get_pixel_size()
	var top := PackedVector2Array([
		Vector2.ZERO, Vector2(side, 0), Vector2(side, side), Vector2(0, side),
	])

	# "Down" on screen, expressed in the board's own (possibly skewed) coordinates.
	var down: Vector2 = _upright_basis() * Vector2(0, THICKNESS)
	var swept := PackedVector2Array(top)
	for point: Vector2 in top:
		swept.append(point + down)

	draw_colored_polygon(Geometry2D.convex_hull(swept), SLAB_COLOR)
	draw_colored_polygon(top, GROUND_COLOR)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return

	# Local coordinates already undo the isometric transform.
	var point: Vector2 = get_local_mouse_position()
	var half := Vector2.ONE * BoardTile.SIZE / 2.0
	var tiles: Array[BoardTile] = get_tiles()

	for i in tiles.size():
		if Rect2(tiles[i].position - half, half * 2.0).has_point(point):
			tile_clicked.emit(i)
			get_viewport().set_input_as_handled()
			return

# Basis that cancels this node's rotation, scale and skew: a child using it looks upright.
func _upright_basis() -> Transform2D:
	var inverse: Transform2D = transform.affine_inverse()
	return Transform2D(inverse.x, inverse.y, Vector2.ZERO)

# Column and row of a tile on the ring, for a board with `side` tiles between corners.
func _grid_cell(index: int, side: int) -> Vector2i:
	var along: int = index % side

	match index / side:
		0:
			return Vector2i(side - along, side)
		1:
			return Vector2i(0, side - along)
		2:
			return Vector2i(along, 0)
		_:
			return Vector2i(side, along)
