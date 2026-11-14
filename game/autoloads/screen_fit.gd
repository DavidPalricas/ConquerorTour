## Fits the game to the screen it runs on. Registered as the Autoload "ScreenFit".
##
## The match is a 16:9 landscape layout, so it keeps its 1600x900 canvas and is letterboxed
## (the bars use the background colour). The menus are centred, so on a portrait screen they
## switch to a narrow canvas that fills it. In portrait the match asks to rotate the device.
extends Node

const LANDSCAPE_SIZE := Vector2i(1600, 900)
const PORTRAIT_SIZE := Vector2i(560, 1000)

var _overlay: CanvasLayer = null
var _last_size := Vector2i.ZERO
var _last_scene: Node = null

func _ready() -> void:
	_overlay = _build_overlay()
	add_child(_overlay)
	get_window().size_changed.connect(_apply)
	get_tree().node_added.connect(_on_node_added)
	_apply()

# Browsers on some phones do not report a rotation or a scene change reliably, so check each frame.
func _process(_delta: float) -> void:
	if get_window().size != _last_size or get_tree().current_scene != _last_scene:
		_apply()

func _on_node_added(node: Node) -> void:
	# A new scene was loaded under the root: refit for it once it is the current scene.
	if node.get_parent() == get_tree().root and node != self:
		_apply.call_deferred()

func _apply() -> void:
	var window: Window = get_window()
	_last_size = window.size
	_last_scene = get_tree().current_scene
	var portrait: bool = window.size.y > window.size.x
	var scene: Node = get_tree().current_scene
	var is_match: bool = scene is MatchView

	if portrait and not is_match:
		window.content_scale_size = PORTRAIT_SIZE
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	else:
		window.content_scale_size = LANDSCAPE_SIZE
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	_overlay.visible = portrait and is_match

func _build_overlay() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.visible = false

	var background := ColorRect.new()
	background.color = Color(0.11, 0.08, 0.24, 1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)

	var label := Label.new()
	label.text = "UI_ROTATE"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 28)
	background.add_child(label)
	return layer
