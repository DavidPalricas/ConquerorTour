## The battle painting behind the menus. It always covers the whole screen, with the picture
## that suits its shape: the wide one is the whole battle, the tall one is the fleet and the
## castle side by side.
class_name BattleBackground extends Control

@export var wide_picture: Texture2D = null
@export var tall_picture: Texture2D = null

func _ready() -> void:
	Require.not_null(wide_picture, "BattleBackground.wide_picture must be assigned in the editor.")
	Require.not_null(tall_picture, "BattleBackground.tall_picture must be assigned in the editor.")
	resized.connect(queue_redraw)

func _draw() -> void:
	var picture: Texture2D = wide_picture if size.x > size.y else tall_picture
	var picture_size: Vector2 = picture.get_size()
	var drawn: Vector2 = picture_size * maxf(size.x / picture_size.x, size.y / picture_size.y)
	draw_texture_rect(picture, Rect2((size - drawn) / 2.0, drawn), false)
