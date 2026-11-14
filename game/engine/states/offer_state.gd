## The rent is paid; the visitor may now make one purchase offer, or skip.
## At the top price the purchase is forced and the owner is not asked.
## Shielded properties never get here: no offer can be made for them.
class_name OfferState extends MatchState

func handle_intent(intent: Dictionary) -> bool:
	var state: GameState = _engine.state

	if intent.type == Intent.SKIP:
		_engine.end_turn()
		return true

	if intent.type != Intent.OFFER or not intent.has("price"):
		return false

	var pid: int = state.actor
	var pending: Dictionary = state.pending
	var price: int = int(intent.price)
	var index: int = pending.tile
	var seller: int = pending.owner

	if price < pending.min or price > pending.max or state.players[pid].money < price:
		return false

	if price >= pending.max:
		TurnResolver.transfer(state, index, pid, price)
		state.log_event(GameEnums.Event.OFFER_FORCED, {"p": pid, "q": seller, "t": index, "a": price})
		_engine.end_turn()
		return true

	pending.price = price
	state.log_event(GameEnums.Event.OFFER_MADE, {"p": pid, "q": seller, "t": index, "a": price})
	_engine.change_state(MatchEngine.TO_OFFER_RESPONSE)
	return true
