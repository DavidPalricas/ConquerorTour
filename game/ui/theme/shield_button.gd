## A heraldic shield in one colour, used to pick the king's colour. It is a toggle button:
## the chosen shield has a gold rim and a glow.
class_name ShieldButton extends BaseButton

const SILVER := Color(0.78, 0.79, 0.83)
const GOLD := Color(1.0, 0.82, 0.3)

## Thickness of the metal rim, in pixels.
const RIM := 4.0

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()

# Set here and not in _ready(), so the shield can be pressed from code before it is in the tree.
func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE

func _ready() -> void:
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(queue_redraw.unbind(1))

func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	var outline: PackedVector2Array = _shield(box)
	var metal: Color = GOLD if button_pressed else SILVER

	if button_pressed:
		for ring in 4:
			draw_colored_polygon(_shield(box.grow(2.0 + ring * 2.0)), Color(GOLD, 0.28))

	# The rim catches the light at the top and falls into shadow at the point.
	draw_polygon(outline, _lit(outline, metal.lightened(0.45), metal.darkened(0.45)))

	var field: PackedVector2Array = _shield(box.grow(-RIM))
	var paint: Color = color.lightened(0.15) if is_hovered() else color
	draw_polygon(field, _lit(field, paint.lightened(0.12), paint.darkened(0.3)))

	# A sheen down the left half, as on polished metal.
	var sheen := PackedVector2Array()
	for point: Vector2 in field:
		sheen.append(Vector2(minf(point.x, size.x / 2.0), point.y))
	draw_colored_polygon(sheen, Color(1, 1, 1, 0.13))

# Outline of a shield filling `box`: a flat top with a small peak, straight shoulders, and
# sides that curve in to a point.
func _shield(box: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(box.position)
	points.append(box.position + Vector2(box.size.x / 2.0, box.size.y * 0.06))
	points.append(box.position + Vector2(box.size.x, 0))

	var shoulder: float = box.size.y * 0.42
	var steps: int = 8
	for step in steps + 1:
		var turn: float = float(step) / steps * PI / 2.0
		points.append(box.position + Vector2(
				box.size.x / 2.0 + cos(turn) * box.size.x / 2.0,
				shoulder + sin(turn) * (box.size.y - shoulder)))
	for step in range(steps - 1, -1, -1):
		var turn: float = float(step) / steps * PI / 2.0
		points.append(box.position + Vector2(
				box.size.x / 2.0 - cos(turn) * box.size.x / 2.0,
				shoulder + sin(turn) * (box.size.y - shoulder)))
	return points

# One colour per point, going from `top` to `bottom` down the shield.
func _lit(points: PackedVector2Array, top: Color, bottom: Color) -> PackedColorArray:
	var colors := PackedColorArray()
	for point: Vector2 in points:
		colors.append(top.lerp(bottom, clampf(point.y / size.y, 0.0, 1.0)))
	return colors
