## One player on the match screen: portrait of the king in the player's colour, money and
## name. A red notice above the card counts the turns left in Hell, and a small red line
## says how much is still owed to Lucifer.
## Layout lives in the scene; this script only fills it.
class_name PlayerCard extends Control

const BACKGROUND := Color(0.14, 0.11, 0.28, 0.96)
const TURN_BORDER := Color(1.0, 0.84, 0.3)
const FADED := Color(1, 1, 1, 0.45)

## Red notice above the card while the player is in Hell.
@export var hell_label: Label = null

@export var panel: PanelContainer = null

## Clothes layer of the portrait, tinted with the player's colour.
@export var clothes: TextureRect = null

@export var money_label: Label = null
@export var name_label: Label = null

## Small red line with the debt still to pay.
@export var debt_label: Label = null

var _box := StyleBoxFlat.new()

func _ready() -> void:
	Require.not_null(hell_label, "PlayerCard.hell_label must be assigned in the editor.")
	Require.not_null(panel, "PlayerCard.panel must be assigned in the editor.")
	Require.not_null(clothes, "PlayerCard.clothes must be assigned in the editor.")
	Require.not_null(money_label, "PlayerCard.money_label must be assigned in the editor.")
	Require.not_null(name_label, "PlayerCard.name_label must be assigned in the editor.")
	Require.not_null(debt_label, "PlayerCard.debt_label must be assigned in the editor.")

	_box.bg_color = BACKGROUND
	_box.set_corner_radius_all(8)
	_box.set_content_margin_all(8)
	_box.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", _box)

## [param p] is the player's entry in the game state.
func refresh(p: Dictionary, is_turn: bool) -> void:
	var color: Color = KingPalette.color_of(p.color)

	clothes.modulate = color
	_box.border_color = TURN_BORDER if is_turn else color.darkened(0.2)
	modulate = FADED if p.bankrupt else Color.WHITE

	var title: String = p.name
	if Session.is_online() and Session.controls(p.id):
		title += " " + tr("UI_YOU_TAG")
	if p.bot:
		title += " " + tr("UI_BOT_TAG")
	name_label.text = title

	money_label.text = tr("UI_STATUS_BANKRUPT") if p.bankrupt else MoneyFormat.full(p.money)

	hell_label.visible = p.hell > 0
	hell_label.text = tr("UI_STATUS_HELL").format({"count": p.hell})

	debt_label.visible = p.debt > 0
	debt_label.text = tr("UI_DEBT").format({"amount": MoneyFormat.full(p.debt)})
