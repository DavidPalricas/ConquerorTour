## The middle of the board: whose turn it is, the dice with their total, and what the local
## player can do right now. Shows the controls of the current phase when the acting player is
## controlled from this screen, and a waiting message otherwise.
## Every button only sends an intent; the host decides what happens.
## Buying and building has its own pop-up (see BuyPopup).
class_name ActionPanel extends VBoxContainer

## Step of the offer slider, in money.
const OFFER_STEP := 1000

@export var turn_label: Label = null

## Total of the dice, shown once they stop.
@export var total_label: Label = null
@export var dice_view: DiceView = null
@export var prompt_label: Label = null
@export var roll_button: Button = null
@export var offer_box: Control = null
@export var offer_value_label: Label = null
@export var offer_slider: HSlider = null
@export var offer_button: Button = null

## Holds the Accept and Refuse buttons.
@export var response_box: Control = null
@export var accept_button: Button = null
@export var refuse_button: Button = null
@export var skip_button: Button = null

## Pays what is due once the player has finished selling, or gives up (loan or bankruptcy).
## Its text is set here, already translated.
@export var settle_button: Button = null
@export var timer_label: Label = null

var _time_left: float = 0.0

# Identifies the decision on screen, so the slider and the timer only reset for a new one.
var _decision: String = ""

func _ready() -> void:
	Require.not_null(turn_label, "ActionPanel.turn_label must be assigned in the editor.")
	Require.not_null(total_label, "ActionPanel.total_label must be assigned in the editor.")
	Require.not_null(dice_view, "ActionPanel.dice_view must be assigned in the editor.")
	Require.not_null(prompt_label, "ActionPanel.prompt_label must be assigned in the editor.")
	Require.not_null(roll_button, "ActionPanel.roll_button must be assigned in the editor.")
	Require.not_null(offer_box, "ActionPanel.offer_box must be assigned in the editor.")
	Require.not_null(offer_value_label, "ActionPanel.offer_value_label must be assigned in the editor.")
	Require.not_null(offer_slider, "ActionPanel.offer_slider must be assigned in the editor.")
	Require.not_null(offer_button, "ActionPanel.offer_button must be assigned in the editor.")
	Require.not_null(response_box, "ActionPanel.response_box must be assigned in the editor.")
	Require.not_null(accept_button, "ActionPanel.accept_button must be assigned in the editor.")
	Require.not_null(refuse_button, "ActionPanel.refuse_button must be assigned in the editor.")
	Require.not_null(skip_button, "ActionPanel.skip_button must be assigned in the editor.")
	Require.not_null(settle_button, "ActionPanel.settle_button must be assigned in the editor.")
	Require.not_null(timer_label, "ActionPanel.timer_label must be assigned in the editor.")

	roll_button.pressed.connect(_send.bind(Intent.ROLL))
	accept_button.pressed.connect(_send.bind(Intent.ACCEPT))
	refuse_button.pressed.connect(_send.bind(Intent.REFUSE))
	skip_button.pressed.connect(_send.bind(Intent.SKIP))
	settle_button.pressed.connect(_send.bind(Intent.SETTLE))
	offer_button.pressed.connect(_on_offer_pressed)
	offer_slider.value_changed.connect(_on_offer_changed)
	dice_view.settled.connect(_on_dice_settled)

func _process(delta: float) -> void:
	if not timer_label.visible:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	timer_label.text = tr("UI_TIME_LEFT").format({"seconds": ceili(_time_left)})

## [param rolled] says the dice were just thrown, so they tumble before showing the result.
func refresh(state: GameState, rolled: bool) -> void:
	var mine: bool = state.actor >= 0 and Session.controls(state.actor)
	var phase: int = state.phase
	var pending: Dictionary = state.pending
	var decision: String = "%d/%d/%d/%s" % [phase, state.turn, state.actor, pending.get("tile", -1)]
	var is_new: bool = decision != _decision
	_decision = decision

	roll_button.visible = mine and phase == GameEnums.Phase.ROLL
	offer_box.visible = mine and phase == GameEnums.Phase.OFFER
	response_box.visible = mine and phase == GameEnums.Phase.OFFER_RESPONSE
	skip_button.visible = mine and phase in [GameEnums.Phase.OFFER, GameEnums.Phase.TARGET]
	settle_button.visible = mine and phase == GameEnums.Phase.SELL
	timer_label.visible = phase == GameEnums.Phase.OFFER_RESPONSE

	# The offer controls need the room the dice take.
	dice_view.visible = not offer_box.visible
	total_label.visible = dice_view.visible
	_show_dice(state.dice, rolled)

	if phase == GameEnums.Phase.GAME_OVER:
		turn_label.text = tr("UI_WINNER").format({"player": _name(state, state.winner)})
		prompt_label.text = tr(GameEnums.win_reason_key(state.win_reason))
		return

	turn_label.text = tr("UI_TURN_OF").format({"player": _name(state, state.turn)})
	prompt_label.text = _prompt(state, mine)

	match phase:
		GameEnums.Phase.OFFER:
			if is_new:
				offer_slider.min_value = pending.min
				offer_slider.max_value = pending.max
				offer_slider.step = OFFER_STEP
				offer_slider.value = pending.min
			_on_offer_changed(offer_slider.value)
		GameEnums.Phase.OFFER_RESPONSE:
			if is_new:
				_time_left = pending.get("timeout", 0)
		GameEnums.Phase.SELL:
			settle_button.text = _settle_text(state)

func _show_dice(dice: Array, rolled: bool) -> void:
	if rolled:
		total_label.text = ""
		dice_view.roll(dice)
	elif not dice_view.is_rolling():
		dice_view.show_values(dice)
		_on_dice_settled()

func _prompt(state: GameState, mine: bool) -> String:
	var pending: Dictionary = state.pending
	var args: Dictionary = {"player": _name(state, state.actor)}
	if pending.has("tile"):
		args["tile"] = tr(state.board[pending.tile].key)

	match state.phase:
		GameEnums.Phase.OFFER_RESPONSE:
			args["player"] = _name(state, state.turn)
			args["other"] = _name(state, state.actor)
			args["amount"] = MoneyFormat.full(pending.price)
			return tr("PROMPT_OFFER_RESPONSE" if mine else "PROMPT_OFFER_PENDING").format(args)
		_ when not mine:
			return tr("PROMPT_WAITING").format(args)
		GameEnums.Phase.ROLL:
			return tr("PROMPT_ROLL")
		GameEnums.Phase.BUY:
			return tr("PROMPT_BUY")
		GameEnums.Phase.OFFER:
			return tr("PROMPT_OFFER").format(args)
		GameEnums.Phase.TARGET:
			return tr(GameEnums.target_prompt_key(pending.kind))
		GameEnums.Phase.SELL:
			var missing: int = _missing(state)
			args["total"] = MoneyFormat.full(pending.due)
			args["amount"] = MoneyFormat.full(missing)
			return tr("PROMPT_SELL" if missing > 0 else "PROMPT_SELL_READY").format(args)
	return ""

# What the payer still lacks to cover the payment that is waiting.
func _missing(state: GameState) -> int:
	return maxi(int(state.pending.due) - int(state.players[state.actor].money), 0)

# What settling does right now: pay, borrow what is missing from Lucifer, or go bankrupt.
func _settle_text(state: GameState) -> String:
	var missing: int = _missing(state)
	if missing == 0:
		return tr("UI_SETTLE_PAY").format({"amount": MoneyFormat.full(state.pending.due)})
	if Bank.can_borrow(state, Session.CONFIG, state.actor, missing):
		return tr("UI_SETTLE_LOAN").format({"amount": MoneyFormat.full(missing)})
	return tr("UI_SETTLE_BANKRUPT")

func _name(state: GameState, pid: int) -> String:
	return state.players[pid].name if pid >= 0 else ""

# Connected in _ready() to the buttons that send an intent with no data.
func _send(type: String) -> void:
	Session.send_intent(Intent.make(type))

# Connected in _ready() to dice_view.settled.
func _on_dice_settled() -> void:
	total_label.text = str(dice_view.total()) if not dice_view.values.is_empty() else ""

# Connected in _ready() to offer_button.pressed.
func _on_offer_pressed() -> void:
	Session.send_intent(Intent.offer(int(offer_slider.value)))

# Connected in _ready() to offer_slider.value_changed.
func _on_offer_changed(value: float) -> void:
	offer_value_label.text = tr("UI_OFFER_VALUE").format({"amount": MoneyFormat.full(int(value))})
	offer_button.text = "UI_OFFER_FORCE" if value >= offer_slider.max_value else "UI_OFFER_SEND"
