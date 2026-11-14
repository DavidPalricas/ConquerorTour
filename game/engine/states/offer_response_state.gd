## The owner answers a purchase offer. No answer before the time runs out counts as a refusal.
class_name OfferResponseState extends MatchState

var _time_left: float = 0.0

func _on_enter(state: GameState) -> void:
	state.actor = state.pending.owner
	state.pending.timeout = _engine.config.offer_timeout
	_time_left = _engine.config.offer_timeout

func execute(delta: float) -> void:
	super(delta)

	# The bot may have answered in super(), which already left this state.
	var state: GameState = _engine.state
	if state == null or _engine.current_state != self:
		return

	_time_left -= delta
	if _time_left <= 0.0:
		var pending: Dictionary = state.pending
		state.log_event(GameEnums.Event.OFFER_TIMEOUT,
				{"p": pending.owner, "q": state.turn, "t": pending.tile})
		_engine.end_turn()
		_engine.flush()

func handle_intent(intent: Dictionary) -> bool:
	var state: GameState = _engine.state
	var pending: Dictionary = state.pending
	var params: Dictionary = {"p": pending.owner, "q": state.turn, "t": pending.tile, "a": pending.price}

	match intent.type:
		Intent.ACCEPT:
			# The buyer's money cannot have changed since the offer, but the host checks anyway.
			if state.players[state.turn].money < pending.price:
				return false
			TurnResolver.transfer(state, pending.tile, state.turn, pending.price)
			state.log_event(GameEnums.Event.OFFER_ACCEPTED, params)
		Intent.REFUSE:
			state.log_event(GameEnums.Event.OFFER_REFUSED, params)
		_:
			return false

	_engine.end_turn()
	return true
