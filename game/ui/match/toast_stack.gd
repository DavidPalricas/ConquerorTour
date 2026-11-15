## Short messages in front of the board about what just happened: a rent paid, a tax, money
## that is missing. Each one stays for a few seconds and fades away. The newest is at the bottom.
class_name ToastStack extends VBoxContainer

## How long a message stays on screen.
const SHOW_SECONDS := 3.0
const FADE_SECONDS := 0.25

## Older messages leave early when more than this many are on screen.
const MAX_TOASTS := 4

const WIDTH := 660.0
const FONT_SIZE := 22

const BACKGROUND := Color(0.10, 0.07, 0.20, 0.94)
const GOOD_COLOR := Color(1.0, 0.84, 0.3)
const BAD_COLOR := Color(1.0, 0.4, 0.3)

## Shows [param text] (BBCode, already translated) after [param delay] seconds.
## [param bad] only picks the colour of the frame.
func add_toast(text: String, bad: bool, delay: float = 0.0) -> void:
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toast.add_theme_stylebox_override("panel", _make_box(BAD_COLOR if bad else GOOD_COLOR))
	toast.visible = false
	toast.modulate.a = 0.0

	var label := RichTextLabel.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size.x = WIDTH
	label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	label.text = "[center]%s[/center]" % text
	toast.add_child(label)
	add_child(toast)

	var tween: Tween = toast.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(_reveal.bind(toast))
	tween.tween_property(toast, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_interval(SHOW_SECONDS)
	tween.tween_property(toast, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(toast.queue_free)

func _reveal(toast: Control) -> void:
	toast.visible = true

	var shown: Array = get_children().filter(
			func(child: Node) -> bool: return child.visible and not child.is_queued_for_deletion())
	while shown.size() > MAX_TOASTS:
		shown.pop_front().queue_free()

func _make_box(border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BACKGROUND
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(10)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 8
	return box
