## A player's piece. Every king shares the same sprite; only the clothes layer, painted in
## greys, is tinted with the player's colour. Its position is where its feet stand.
class_name King extends Node2D

## Seconds to walk from one tile to the next.
const STEP_SECONDS := 0.12

@export var clothes: Sprite2D = null

var _placed: bool = false
var _tween: Tween = null

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
