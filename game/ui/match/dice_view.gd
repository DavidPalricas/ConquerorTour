## The dice. A roll tumbles through random faces for a moment and then stops on the real
## values, which were already decided by the host: the animation is only for show.
class_name DiceView extends Control

## Emitted when a roll stops on its values.
signal settled

## How long a roll tumbles.
const ROLL_SECONDS := 0.9

## How often a tumbling die changes face.
const FACE_SECONDS := 0.07

const DIE_SIZE := 58.0
const GAP := 20.0
const MAX_TILT := 0.5

const FACE_COLOR := Color(0.97, 0.96, 0.92)
const EDGE_COLOR := Color(0.20, 0.14, 0.24)
const PIP_COLOR := Color(0.15, 0.10, 0.18)

## Pips of each face, on a 3 x 3 grid (-1, 0, 1).
const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}

## The real values of the last roll.
var values: Array = []

# What is drawn right now: random faces and tilts while tumbling.
var _faces: Array = []
var _tilts: Array = []

var _time_left: float = 0.0
var _face_time: float = 0.0

func _ready() -> void:
	set_process(false)

func is_rolling() -> bool:
	return _time_left > 0.0

func total() -> int:
	var sum := 0
	for value: int in values:
		sum += value
	return sum

## Tumbles and stops on [param new_values].
func roll(new_values: Array) -> void:
	values = new_values.duplicate()
	_time_left = ROLL_SECONDS
	_face_time = 0.0
	set_process(true)

## Shows [param new_values] at once, with no animation.
func show_values(new_values: Array) -> void:
	values = new_values.duplicate()
	_rest()

func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		_rest()
		settled.emit()
		return

	_face_time -= delta
	if _face_time <= 0.0:
		_face_time = FACE_SECONDS
		_faces.clear()
		_tilts.clear()
		for i in values.size():
			_faces.append(randi_range(1, 6))
			_tilts.append(randf_range(-MAX_TILT, MAX_TILT))
		queue_redraw()

func _rest() -> void:
	_time_left = 0.0
	_faces = values.duplicate()
	_tilts.clear()
	for i in values.size():
		_tilts.append(0.0)
	set_process(false)
	queue_redraw()

func _draw() -> void:
	var count: int = _faces.size()
	var width: float = count * DIE_SIZE + maxi(count - 1, 0) * GAP
	var start := Vector2((size.x - width) / 2.0 + DIE_SIZE / 2.0, size.y / 2.0)

	for i in count:
		draw_set_transform(start + Vector2(i * (DIE_SIZE + GAP), 0), _tilts[i])
		_draw_die(_faces[i])
	draw_set_transform(Vector2.ZERO)

func _draw_die(face: int) -> void:
	var rect := Rect2(-DIE_SIZE / 2.0, -DIE_SIZE / 2.0, DIE_SIZE, DIE_SIZE)
	draw_rect(rect, FACE_COLOR)
	draw_rect(rect, EDGE_COLOR, false, 3.0)

	if PIPS.has(face):
		for pip: Vector2 in PIPS[face]:
			draw_circle(pip * DIE_SIZE * 0.27, DIE_SIZE * 0.09, PIP_COLOR)
	else:
		# Dice with more than six sides (see GameConfig.dice_sides) show the number.
		var font: Font = get_theme_default_font()
		draw_string(font, Vector2(-DIE_SIZE / 2.0, 10), str(face), HORIZONTAL_ALIGNMENT_CENTER,
				DIE_SIZE, 28, PIP_COLOR)
