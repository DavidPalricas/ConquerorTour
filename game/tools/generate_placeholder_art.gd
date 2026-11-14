## Draws the placeholder art: simple shapes and flat colours, on purpose.
## The file names are stable, so the final painted art replaces these files without touching
## any code or scene.
##
## Run from the project folder:
##   godot --headless -s res://tools/generate_placeholder_art.gd
##   godot --headless --import
extends SceneTree

const CLEAR := Color(0, 0, 0, 0)
const WHITE := Color(0.96, 0.96, 0.94)
const RED := Color(0.80, 0.13, 0.15)
const GREEN := Color(0.10, 0.50, 0.25)
const BLUE := Color(0.12, 0.25, 0.60)
const YELLOW := Color(0.98, 0.80, 0.15)
const ORANGE := Color(0.95, 0.50, 0.10)
const DARK := Color(0.15, 0.12, 0.18)
const STONE := Color(0.72, 0.72, 0.76)
const WOOD := Color(0.55, 0.36, 0.20)
const SKIN := Color(0.96, 0.80, 0.66)

func _init() -> void:
	_flags()
	_icons()
	_buildings()
	_king()
	print("Placeholder art written.")
	quit()

# ====== Flags (48 x 32) ======

func _flags() -> void:
	var dir := "res://board/flags/"

	var img := _new(48, 32, GREEN)
	_rect(img, 19, 0, 29, 32, RED)
	_circle(img, 19, 16, 6, YELLOW)
	_save(img, dir + "portugal.png")

	img = _new(48, 32, RED)
	_rect(img, 0, 8, 48, 16, YELLOW)
	_save(img, dir + "spain.png")

	img = _new(48, 32, WHITE)
	_rect(img, 20, 0, 8, 32, RED)
	_rect(img, 0, 12, 48, 8, RED)
	_save(img, dir + "britain.png")

	img = _new(48, 32, BLUE)
	_circle(img, 14, 10, 4, YELLOW)
	_circle(img, 34, 10, 4, YELLOW)
	_circle(img, 24, 22, 4, YELLOW)
	_save(img, dir + "france.png")

	img = _new(48, 32, RED)
	_circle(img, 22, 16, 9, WHITE)
	_circle(img, 26, 16, 7, RED)
	_save(img, dir + "ottoman.png")

	img = _new(48, 32, WHITE)
	_rect(img, 0, 0, 48, 11, ORANGE)
	_rect(img, 0, 21, 48, 11, BLUE)
	_save(img, dir + "netherlands.png")

	img = _new(48, 32, YELLOW)
	_circle(img, 24, 16, 8, BLUE)
	_save(img, dir + "china.png")

	img = _new(48, 32, WHITE)
	_circle(img, 24, 16, 9, RED)
	_save(img, dir + "japan.png")

# ====== Special tile icons (48 x 48) ======

func _icons() -> void:
	var dir := "res://board/icons/"

	# Start: arrow.
	var img := _new(48, 48, CLEAR)
	_rect(img, 6, 19, 22, 10, GREEN)
	_triangle(img, Vector2(26, 8), Vector2(44, 24), Vector2(26, 40), GREEN)
	_save(img, dir + "start.png")

	# Hell: flame.
	img = _new(48, 48, CLEAR)
	_circle(img, 24, 30, 14, RED)
	_triangle(img, Vector2(12, 26), Vector2(24, 2), Vector2(36, 26), RED)
	_circle(img, 24, 33, 8, ORANGE)
	_triangle(img, Vector2(18, 30), Vector2(24, 16), Vector2(30, 30), ORANGE)
	_circle(img, 24, 36, 4, YELLOW)
	_save(img, dir + "hell.png")

	# Pope's Call: mitre.
	img = _new(48, 48, CLEAR)
	_rect(img, 12, 26, 24, 16, WHITE)
	_triangle(img, Vector2(12, 26), Vector2(24, 4), Vector2(36, 26), WHITE)
	_rect(img, 22, 10, 4, 30, YELLOW)
	_rect(img, 12, 36, 24, 4, YELLOW)
	_save(img, dir + "pope_call.png")

	# Tax: coins.
	img = _new(48, 48, CLEAR)
	_circle(img, 18, 30, 12, YELLOW.darkened(0.25))
	_circle(img, 18, 30, 9, YELLOW)
	_circle(img, 31, 19, 12, YELLOW.darkened(0.25))
	_circle(img, 31, 19, 9, YELLOW)
	_save(img, dir + "tax.png")

	# Lucifer Roulette: wheel.
	img = _new(48, 48, CLEAR)
	_circle(img, 24, 24, 21, DARK)
	_circle(img, 24, 24, 18, RED)
	_rect(img, 22, 6, 4, 36, DARK)
	_rect(img, 6, 22, 36, 4, DARK)
	_circle(img, 24, 24, 6, YELLOW)
	_save(img, dir + "roulette.png")

	# Church: nave, tower and cross.
	img = _new(48, 48, CLEAR)
	_rect(img, 8, 26, 32, 18, STONE)
	_rect(img, 18, 14, 12, 30, STONE.lightened(0.15))
	_triangle(img, Vector2(16, 14), Vector2(24, 6), Vector2(32, 14), RED)
	_rect(img, 23, 0, 2, 8, YELLOW)
	_rect(img, 20, 2, 8, 2, YELLOW)
	_rect(img, 21, 34, 6, 10, DARK)
	_save(img, dir + "church.png")

# ====== Buildings (32 x 32) and shield (16 x 16) ======

func _buildings() -> void:
	var dir := "res://board/buildings/"

	# Land: a pole with a pennant. Light greys, tinted with the owner's colour.
	var img := _new(32, 32, CLEAR)
	_rect(img, 8, 4, 3, 26, WOOD)
	_triangle(img, Vector2(11, 4), Vector2(28, 10), Vector2(11, 16), WHITE)
	_save(img, dir + "land.png")

	img = _new(32, 32, CLEAR)
	_rect(img, 6, 16, 20, 14, WOOD)
	_triangle(img, Vector2(3, 17), Vector2(16, 6), Vector2(29, 17), WOOD.darkened(0.35))
	_rect(img, 14, 22, 5, 8, DARK)
	_save(img, dir + "shack.png")

	img = _new(32, 32, CLEAR)
	_rect(img, 5, 14, 22, 16, WHITE)
	_triangle(img, Vector2(2, 15), Vector2(16, 3), Vector2(30, 15), RED)
	_rect(img, 13, 21, 6, 9, WOOD)
	_rect(img, 21, 17, 4, 4, BLUE)
	_save(img, dir + "house.png")

	img = _new(32, 32, CLEAR)
	_rect(img, 3, 8, 8, 22, STONE)
	_rect(img, 21, 8, 8, 22, STONE)
	_rect(img, 9, 14, 14, 16, STONE.darkened(0.12))
	_rect(img, 3, 4, 3, 4, STONE)
	_rect(img, 8, 4, 3, 4, STONE)
	_rect(img, 21, 4, 3, 4, STONE)
	_rect(img, 26, 4, 3, 4, STONE)
	_rect(img, 13, 21, 6, 9, DARK)
	_save(img, dir + "castle.png")

	img = _new(16, 16, CLEAR)
	_rect(img, 2, 1, 12, 8, BLUE.lightened(0.3))
	_triangle(img, Vector2(2, 8), Vector2(8, 16), Vector2(14, 8), BLUE.lightened(0.3))
	_rect(img, 7, 3, 2, 8, WHITE)
	_rect(img, 4, 5, 8, 2, WHITE)
	_save(img, dir + "shield.png")

# ====== King (48 x 64): body layer, plus clothes layer in greys to be tinted ======

func _king() -> void:
	var dir := "res://players/"

	var body := _new(48, 64, CLEAR)
	_rect(body, 16, 54, 6, 8, DARK)
	_rect(body, 26, 54, 6, 8, DARK)
	_circle(body, 24, 20, 10, SKIN)
	_circle(body, 20, 19, 2, DARK)
	_circle(body, 28, 19, 2, DARK)
	_rect(body, 14, 6, 20, 6, YELLOW)
	_triangle(body, Vector2(14, 6), Vector2(17, 0), Vector2(20, 6), YELLOW)
	_triangle(body, Vector2(21, 6), Vector2(24, 0), Vector2(27, 6), YELLOW)
	_triangle(body, Vector2(28, 6), Vector2(31, 0), Vector2(34, 6), YELLOW)
	_save(body, dir + "king_body.png")

	var clothes := _new(48, 64, CLEAR)
	var light := Color(0.92, 0.92, 0.92)
	var shade := Color(0.70, 0.70, 0.70)
	_rect(clothes, 14, 30, 20, 26, light)
	_triangle(clothes, Vector2(6, 56), Vector2(14, 30), Vector2(14, 56), shade)
	_triangle(clothes, Vector2(42, 56), Vector2(34, 30), Vector2(34, 56), shade)
	_rect(clothes, 22, 30, 4, 26, shade)
	_rect(clothes, 14, 30, 20, 3, Color(1, 1, 1))
	_save(clothes, dir + "king_clothes.png")

# ====== Drawing helpers ======

func _new(w: int, h: int, color: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img

func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), color)

func _circle(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if _inside(img, x, y) and Vector2(x - cx, y - cy).length() <= radius:
				img.set_pixel(x, y, color)

func _triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var points := PackedVector2Array([a, b, c])
	for y in img.get_height():
		for x in img.get_width():
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				img.set_pixel(x, y, color)

func _inside(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height()

func _save(img: Image, path: String) -> void:
	var error := img.save_png(path)
	if error != OK:
		push_error("Could not write %s (error %d)" % [path, error])
