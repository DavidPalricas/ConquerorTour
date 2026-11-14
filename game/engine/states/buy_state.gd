## The player landed on a free property or on one of their own cities: choose how far to
## build among the options in state.pending.options, or skip.
class_name BuyState extends MatchState

func handle_intent(intent: Dictionary) -> bool:
	match intent.type:
		Intent.BUY:
			if not intent.has("level"):
				return false
			if not TurnResolver.buy(_engine.state, _engine.state.actor, int(intent.level)):
				return false
		Intent.SKIP:
			pass
		_:
			return false

	_engine.end_turn()
	return true
