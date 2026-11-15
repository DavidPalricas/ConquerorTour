## The Lucifer Roulette card that was just drawn, shown as a card in the middle of the screen
## for a few seconds. A click puts it away sooner.
## Layout lives in the scene; this script only fills it and animates it.
class_name CardView extends Control

## How long the card stays on screen.
const SHOW_SECONDS := 3.0

## How long it takes to pop in and to fade out.
const POP_SECONDS := 0.25

## The card itself. Scaled around its centre when it pops in.
@export var card: Control = null

## Their texts are translation keys.
@export var title_label: Label = null
@export var text_label: Label = null

## Says who drew the card.
@export var owner_label: Label = null

var _tween: Tween = null

func _ready() -> void:
	Require.not_null(card, "CardView.card must be assigned in the editor.")
	Require.not_null(title_label, "CardView.title_label must be assigned in the editor.")
	Require.not_null(text_label, "CardView.text_label must be assigned in the editor.")
	Require.not_null(owner_label, "CardView.owner_label must be assigned in the editor.")

	card.gui_input.connect(_on_card_input)
	visible = false

## Shows [param card_id] (a GameEnums.Card) after [param delay] seconds, the time the king
## takes to reach the roulette.
func show_card(card_id: int, player_name: String, delay: float = 0.0) -> void:
	title_label.text = GameEnums.card_title_key(card_id)
	text_label.text = GameEnums.card_text_key(card_id)
	owner_label.text = tr("UI_CARD_DRAWN_BY").format({"player": player_name})

	_stop()
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.tween_callback(_open)
	_tween.tween_property(card, "scale", Vector2.ONE, POP_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(card, "modulate:a", 1.0, POP_SECONDS)
	_tween.tween_interval(SHOW_SECONDS)
	_tween.tween_property(card, "modulate:a", 0.0, POP_SECONDS)
	_tween.tween_callback(_stop)

func _open() -> void:
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.4, 0.4)
	card.modulate.a = 0.0
	visible = true

func _stop() -> void:
	visible = false
	if _tween != null:
		_tween.kill()
		_tween = null

# Connected in _ready() to card.gui_input.
func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_stop()
