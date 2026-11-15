## A player's piece. Every king shares the same sprite; only the clothes layer, painted in
## greys, is tinted with the player's colour. Its position is where its feet stand.
class_name King extends Node2D

## Seconds to walk from one tile to the next.
const STEP_SECONDS := 0.12

## The little jump a king gives when it stops on a tile.
const HOP_HEIGHT := 44.0
const HOP_SECONDS := 0.32

## How flat the king gets when it comes down from the hop (squash and stretch).
const LAND_SQUASH := Vector2(1.5, 0.5)

@export var clothes: Sprite2D = null

var _placed: bool = false
var _tween: Tween = null
var _hop_tween: Tween = null

# Scale given in the scene, to come back to after the squash.
@onready var _rest_scale: Vector2 = scale

func _ready() -> void:
	Require.not_null(clothes, "King.clothes must be assigned in the editor.")

func set_color(color: Color) -> void:
	clothes.modulate = color

## Walks through [param points], one after the other, and stops on the last one, after
## waiting [param delay] seconds (the time the dice take to stop).
## The first call places the king without animation.
func walk(points: Array[Vector2], delay: float = 0.0) -> void:
	if points.is_empty():
		return
	if _tween != null:
		_tween.kill()
		_tween = null

	var target: Vector2 = points[points.size() - 1]
	if not _placed or position.is_equal_approx(target):
		_placed = true
		position = target
		return

	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	for point: Vector2 in points:
		_tween.tween_property(self, "position", point, STEP_SECONDS)

## Jumps on the spot: the feedback of landing on a tile.
func hop() -> void:
	if _hop_tween != null:
		_hop_tween.kill()
		scale = _rest_scale
	_hop_tween = create_tween()
	_hop_tween.tween_method(_set_lift, 0.0, HOP_HEIGHT, HOP_SECONDS / 2.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_method(_set_lift, HOP_HEIGHT, 0.0, HOP_SECONDS / 2.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Flattens on the ground and springs back up.
	_hop_tween.tween_property(self, "scale", _rest_scale * LAND_SQUASH, 0.08)
	_hop_tween.tween_property(self, "scale", _rest_scale, 0.6) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# Raises the sprites above the feet, which stay where the king stands.
func _set_lift(height: float) -> void:
	for child: Node in get_children():
		if child is Sprite2D:
			child.position.y = -height
