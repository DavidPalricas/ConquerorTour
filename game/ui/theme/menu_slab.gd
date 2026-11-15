## The slab of stone the menus are carved on. It is as big as what is on it, except that on a
## wide screen it is at least half as wide as the screen: the middle of the wide battle picture
## is a reflection of its sides (see tools/make_menu_art.gd), best kept behind the slab.
class_name MenuSlab extends PanelContainer

## Least width of the slab on a wide screen, as a share of the screen's width.
const WIDE_SHARE := 0.5

func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var screen: Vector2 = get_viewport_rect().size
	custom_minimum_size = Vector2(screen.x * WIDE_SHARE if screen.x > screen.y else 0.0, 0.0)
