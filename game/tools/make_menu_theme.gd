## Builds ui/theme/menu_theme.tres, the stone, wood and parchment look of the menus.
## Run from the project folder, after make_menu_art.gd and an import of its pictures:
##   godot --headless -s res://tools/make_menu_theme.gd
extends SceneTree

const FONT := "res://ui/theme/Cinzel.ttf"
const ART := "res://ui/theme/"
const OUTPUT := "res://ui/theme/menu_theme.tres"

## Shadow and rim of the stone panel, as painted by tools/make_menu_art.gd.
const STONE_SHADOW := 40
const STONE_RIM := 26

const GOLD := Color(1.0, 0.82, 0.36)
const INK := Color(0.2, 0.11, 0.04)

func _init() -> void:
	var theme := Theme.new()

	var font := FontVariation.new()
	font.base_font = load(FONT)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	theme.default_font = font
	theme.default_font_size = 20

	# Labels: gold lettering with a soft dark shadow, as if raised from the surface.
	theme.set_color("font_color", "Label", GOLD)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.8))
	theme.set_constant("shadow_offset_x", "Label", 2)
	theme.set_constant("shadow_offset_y", "Label", 2)
	theme.set_constant("shadow_outline_size", "Label", 4)

	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font_size("font_size", "TitleLabel", 46)
	theme.set_color("font_color", "TitleLabel", Color(1.0, 0.8, 0.3))
	theme.set_color("font_outline_color", "TitleLabel", Color(0.25, 0.13, 0.02))
	theme.set_constant("outline_size", "TitleLabel", 8)
	theme.set_constant("shadow_offset_x", "TitleLabel", 0)
	theme.set_constant("shadow_offset_y", "TitleLabel", 5)
	theme.set_constant("shadow_outline_size", "TitleLabel", 14)

	# Panels: a slab of stone, with planks of wood set into it.
	var stone: StyleBoxTexture = _textured("stone_panel.png", STONE_SHADOW + STONE_RIM, STONE_RIM + 8)
	stone.set_expand_margin_all(STONE_SHADOW)
	theme.set_stylebox("panel", "PanelContainer", stone)

	theme.set_type_variation("WoodPanel", "PanelContainer")
	theme.set_stylebox("panel", "WoodPanel", _textured("wood_panel.png", 10, 14))

	# Buttons: parchment in a bronze frame, which sinks when pressed.
	for type: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, _button("button_normal.png", 0))
		theme.set_stylebox("hover", type, _button("button_hover.png", 0))
		theme.set_stylebox("pressed", type, _button("button_pressed.png", 2))
		theme.set_stylebox("disabled", type, _button("button_disabled.png", 0))
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		for state: String in ["font_color", "font_hover_color", "font_pressed_color",
				"font_hover_pressed_color", "font_focus_color", "icon_normal_color",
				"icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			theme.set_color(state, type, INK)
		theme.set_color("font_disabled_color", type, Color(0.3, 0.27, 0.24))

	# Text fields: a sheet sunk into its surroundings, written in ink.
	theme.set_stylebox("normal", "LineEdit", _button("field.png", 0))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", Color(INK, 0.5))
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_color("selection_color", "LineEdit", Color(0.75, 0.5, 0.2, 0.6))

	# The list a dropdown opens.
	theme.set_stylebox("panel", "PopupMenu", _button("button_normal.png", 0))
	theme.set_stylebox("hover", "PopupMenu", _button("button_pressed.png", 0))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)

	var error: Error = ResourceSaver.save(theme, OUTPUT)
	if error != OK:
		push_error("Could not save %s (%d)" % [OUTPUT, error])
	quit(0 if error == OK else 1)

# A parchment box. `sink` moves its contents down, for the pressed state.
func _button(file: String, sink: int) -> StyleBoxTexture:
	var box: StyleBoxTexture = _textured(file, 10, 14)
	box.content_margin_top = 8 + sink
	box.content_margin_bottom = 8 - sink
	return box

# A box drawn with one of the textures of tools/make_menu_art.gd. Its rim keeps its size and
# its middle is tiled, so the grain is never stretched.
func _textured(file: String, rim: int, padding: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(ART + file)
	box.set_texture_margin_all(rim)
	box.set_content_margin_all(padding)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return box
