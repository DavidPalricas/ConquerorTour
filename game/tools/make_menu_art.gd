## Makes the art of the menus. Run from the project folder:
##   godot --headless -s res://tools/make_menu_art.gd
##
## The battle and the king's portrait are cut out of the concept mock-up in refs/. The mock-up
## has a menu painted in its middle and there is no picture of what is behind it, so:
##  - the wide background has that middle painted over with the battle on either side of it,
##    reflected inwards. The title and the menu panel sit over most of it;
##  - the tall background is the two clean sides put next to each other.
## The stone, wood and parchment of the panels and buttons are painted here from noise.
extends SceneTree

const SOURCE := "../refs/Gemini_Generated_Image_8kofj48kofj48kof.jpg"
const OUTPUT := "res://ui/theme/"

## Part of the mock-up kept as the background: the battle without the trinkets in its corners.
const SCENE := Rect2i(282, 83, 2174, 1223)

## Columns of the mock-up taken up by its painted title and panel.
const PAINTED_LEFT := 690
const PAINTED_RIGHT := 2070

## Row of the mock-up where the sky above the fleet ends. Above it the painted menu is covered
## with the clouds of the left side only, so the moon on the right is not repeated.
const SKY_BOTTOM := 560

## Width over which neighbouring pieces fade into each other.
const OVERLAP := 90

## The king's face, without the frame painted around it.
const PORTRAIT := Rect2i(1660, 502, 172, 172)

const BACKGROUND_SIZE := Vector2i(1920, 1080)

## Thickness of the rim of the stone panel, and of the shadow around it. The theme
## (tools/make_menu_theme.gd) uses the same numbers to cut the picture into rim and middle.
const STONE_RIM := 26
const STONE_SHADOW := 40

const IRON := Color(0.1, 0.09, 0.08)

func _init() -> void:
	var source := Image.load_from_file(SOURCE)
	if source == null:
		push_error("Could not read %s" % SOURCE)
		quit(1)
		return
	source.convert(Image.FORMAT_RGB8)

	source.get_region(PORTRAIT).save_png(OUTPUT + "king_portrait.png")

	_join_sides(source).save_jpg(OUTPUT + "battle_background_tall.jpg", 0.88)

	_paint_over_menu(source)
	var scene: Image = source.get_region(SCENE)
	scene.resize(BACKGROUND_SIZE.x, BACKGROUND_SIZE.y, Image.INTERPOLATE_LANCZOS)
	scene.save_jpg(OUTPUT + "battle_background.jpg", 0.88)

	_make_surfaces()
	quit()

# Paints the battle over the painted menu. Each side of the battle is reflected inwards, again
# and again, so it carries on without a seam; the two meet in the middle, behind the panel.
func _paint_over_menu(image: Image) -> void:
	var original: Image = image.duplicate()
	var left_room: int = PAINTED_LEFT - SCENE.position.x - 1
	var right_room: int = SCENE.end.x - PAINTED_RIGHT - 1
	var width: float = PAINTED_RIGHT - PAINTED_LEFT

	for y in range(SCENE.position.y, SCENE.end.y):
		var below_sky: float = smoothstep(SKY_BOTTOM - 60.0, SKY_BOTTOM + 60.0, y)
		for x in range(PAINTED_LEFT, PAINTED_RIGHT):
			var from_left: Color = original.get_pixel(
					PAINTED_LEFT - 1 - int(pingpong(x - PAINTED_LEFT, left_room)), y)
			var from_right: Color = original.get_pixel(
					PAINTED_RIGHT + int(pingpong(PAINTED_RIGHT - 1 - x, right_room)), y)

			var along: float = (x - PAINTED_LEFT) / width
			var sky: Color = from_left.lerp(from_right, smoothstep(0.9, 1.0, along))
			var sea: Color = from_left.lerp(from_right, smoothstep(0.4, 0.6, along))
			image.set_pixel(x, y, sky.lerp(sea, below_sky))

# The battle for a tall screen: the fleet and the castle from either side of the painted menu,
# put next to each other and faded together where they meet.
func _join_sides(image: Image) -> Image:
	var left := Rect2i(SCENE.position.x, SCENE.position.y, PAINTED_LEFT - SCENE.position.x, SCENE.size.y)
	var right := Rect2i(PAINTED_RIGHT, SCENE.position.y, SCENE.end.x - PAINTED_RIGHT, SCENE.size.y)
	var joined := Image.create(left.size.x + right.size.x - OVERLAP, SCENE.size.y, false, Image.FORMAT_RGB8)

	for y in joined.get_height():
		for x in joined.get_width():
			var from_right: int = x - (left.size.x - OVERLAP)
			var color: Color
			if from_right < 0:
				color = image.get_pixel(left.position.x + x, left.position.y + y)
			elif from_right >= OVERLAP:
				color = image.get_pixel(right.position.x + from_right, right.position.y + y)
			else:
				color = image.get_pixel(left.position.x + x, left.position.y + y).lerp(
						image.get_pixel(right.position.x + from_right, right.position.y + y),
						smoothstep(0.0, 1.0, float(from_right) / OVERLAP))
			joined.set_pixel(x, y, color)
	return joined

func _make_surfaces() -> void:
	# The slab of the panel: rough grey stone in a dark iron band, with a chiselled rim, a
	# rivet in each corner and a heavy shadow under it.
	var side: int = 124 + STONE_RIM * 2
	var stone: Image = _surface(Vector2i(side, side), Color(0.4, 0.4, 0.37), 0.09, Vector2(1, 1), 0.22, STONE_RIM)
	_frame(stone, 0, 4, IRON)
	_bevel(stone, 4, 3, 0.3, true)
	_bevel(stone, 7, 15, -0.14, true)
	_bevel(stone, 22, 3, 0.4, false)
	for corner: Vector2i in [Vector2i(14, 14), Vector2i(side - 15, 14), Vector2i(14, side - 15), Vector2i(side - 15, side - 15)]:
		_rivet(stone, corner, 5)
	_with_shadow(stone, STONE_SHADOW).save_png(OUTPUT + "stone_panel.png")

	# Planks let into the stone: an iron band around them, and the stone's shadow on them.
	var wood: Image = _surface(Vector2i(240, 96), Color(0.34, 0.2, 0.1), 0.02, Vector2(0.12, 1.6), 0.3, 10)
	_inner_shadow(wood, 3, 7, 0.6)
	_frame(wood, 0, 3, IRON)
	_bevel(wood, 0, 1, 0.5, false)
	wood.save_png(OUTPUT + "wood_panel.png")

	# Buttons: parchment in a bronze frame that stands out. Pressed, it is lit from the other
	# side, so it looks pushed in.
	_button(Color(0.86, 0.75, 0.53), true).save_png(OUTPUT + "button_normal.png")
	_button(Color(0.95, 0.85, 0.63), true).save_png(OUTPUT + "button_hover.png")
	_button(Color(0.7, 0.6, 0.41), false).save_png(OUTPUT + "button_pressed.png")
	_button(Color(0.5, 0.47, 0.42), true).save_png(OUTPUT + "button_disabled.png")

	# Text fields: a sheet of parchment sunk into its surroundings, in the shadow of their edge.
	var field: Image = _surface(Vector2i(96, 48), Color(0.93, 0.84, 0.64), 0.03, Vector2(1, 1), 0.1, 10)
	_inner_shadow(field, 3, 7, 0.5)
	_frame(field, 0, 3, Color(0.3, 0.19, 0.08))
	_bevel(field, 0, 3, 0.6, false)
	field.save_png(OUTPUT + "field.png")

func _button(paper: Color, raised: bool) -> Image:
	var image: Image = _surface(Vector2i(96, 48), paper, 0.03, Vector2(1, 1), 0.12, 10)
	if not raised:
		_inner_shadow(image, 6, 4, 0.35)
	_frame(image, 0, 6, Color(0.5, 0.33, 0.13))
	_bevel(image, 0, 6, 0.55, raised)
	_frame(image, 0, 1, IRON)
	return image

# Darkens the top and the left of an image, `inset` pixels in, fading out over `depth`
# pixels: the shadow that a raised edge throws on what is sunk inside it.
func _inner_shadow(image: Image, inset: int, depth: int, strength: float) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var nearest: int = mini(x, y) - inset
			if nearest < 0 or nearest >= depth:
				continue
			var amount: float = strength * (1.0 - float(nearest) / depth)
			image.set_pixel(x, y, _shade(image.get_pixel(x, y), -amount))

# A round iron rivet, lit from the top left.
func _rivet(image: Image, centre: Vector2i, radius: int) -> void:
	for dy in range(-radius - 1, radius + 2):
		for dx in range(-radius - 1, radius + 2):
			var distance: float = Vector2(dx, dy).length()
			var pixel: Vector2i = centre + Vector2i(dx, dy)
			if distance > radius + 1.0:
				continue
			if distance > radius:
				# A ring of shadow where the rivet meets the stone.
				image.set_pixelv(pixel, _shade(image.get_pixelv(pixel), -0.45))
				continue
			var light: float = -(dx + dy) / (radius * 2.0)
			image.set_pixelv(pixel, _shade(Color(0.36, 0.34, 0.32), light * 0.7))

# A surface of one colour broken up by noise. `stretch` pulls the noise along one axis, which
# turns blotches into wood grain. The part inside `rim` repeats without a seam, so a box
# drawn with it can tile its middle.
func _surface(size: Vector2i, base: Color, frequency: float, stretch: Vector2, strength: float, rim: int) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = hash(base)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	noise.fractal_octaves = 4

	var middle: Vector2i = size - Vector2i.ONE * rim * 2
	var speckle := RandomNumberGenerator.new()
	speckle.seed = hash(size)
	var grain := Image.create(middle.x, middle.y, false, Image.FORMAT_RF)
	for y in middle.y:
		for x in middle.x:
			# Blending four shifted samples makes the noise wrap around the middle.
			var across: float = float(x) / middle.x
			var down: float = float(y) / middle.y
			var value: float = lerpf(
					lerpf(_grain(noise, x, y, stretch), _grain(noise, x - middle.x, y, stretch), across),
					lerpf(_grain(noise, x, y - middle.y, stretch),
							_grain(noise, x - middle.x, y - middle.y, stretch), across),
					down)
			grain.set_pixel(x, y, Color(value * 1.6 + speckle.randf_range(-0.25, 0.25), 0, 0))

	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var value: float = grain.get_pixel(posmod(x - rim, middle.x), posmod(y - rim, middle.y)).r
			image.set_pixel(x, y, _shade(base, value * strength))
	return image

func _grain(noise: FastNoiseLite, x: int, y: int, stretch: Vector2) -> float:
	return noise.get_noise_2d(x * stretch.x, y * stretch.y)

# Lightens (positive) or darkens (negative) a colour.
func _shade(color: Color, amount: float) -> Color:
	var shaded: Color = color.lightened(amount) if amount > 0.0 else color.darkened(-amount)
	shaded.a = color.a
	return shaded

# Paints a flat band of `width` pixels, `inset` pixels in from the edge.
func _frame(image: Image, inset: int, width: int, color: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var depth: int = _depth(image, x, y)
			if depth >= inset and depth < inset + width:
				image.set_pixel(x, y, _shade(color, (image.get_pixel(x, y).v - 0.6) * 0.3))

# Lights a band as if it were a slope. Raised, it catches light on the top and left; sunk,
# on the bottom and right.
func _bevel(image: Image, inset: int, width: int, strength: float, raised: bool) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var depth: int = _depth(image, x, y)
			if depth < inset or depth >= inset + width:
				continue
			var lit: bool = mini(x, y) <= mini(image.get_width() - 1 - x, image.get_height() - 1 - y)
			var amount: float = strength if lit == raised else -strength
			image.set_pixel(x, y, _shade(image.get_pixel(x, y), amount))

# Distance of a pixel from the nearest edge of the image.
func _depth(image: Image, x: int, y: int) -> int:
	return mini(mini(x, y), mini(image.get_width() - 1 - x, image.get_height() - 1 - y))

# Puts an image on a bigger transparent one with a soft shadow spreading out from under it.
func _with_shadow(image: Image, spread: int) -> Image:
	var size: Vector2i = image.get_size() + Vector2i.ONE * spread * 2
	var result := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var inner := Rect2i(Vector2i.ONE * spread, image.get_size())

	for y in size.y:
		for x in size.x:
			var outside := Vector2(
					maxf(maxf(inner.position.x - x, x - inner.end.x + 1), 0.0),
					maxf(maxf(inner.position.y - y, y - inner.end.y + 1), 0.0))
			var alpha: float = pow(clampf(1.0 - outside.length() / spread, 0.0, 1.0), 2.0) * 0.9
			result.set_pixel(x, y, Color(0, 0, 0, alpha))

	result.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), inner.position)
	return result
