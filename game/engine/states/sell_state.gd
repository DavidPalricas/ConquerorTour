## A player cannot cover a mandatory payment (rent, tax or card) and owns properties: they
## may sell some to Lucifer before settling. The payment is in state.pending: { payer, due,
## payee, kind, targets }. The payer is not always the player of the turn (Lucifer Gift).
class_name SellState extends MatchState

func _on_enter(state: GameState) -> void:
	state.actor = state.pending.payer

func handle_intent(intent: Dictionary) -> bool:
	var state: GameState = _engine.state

	match intent.type:
		Intent.SELL:
			return intent.has("tile") and TurnResolver.sell(state, _engine.config, int(intent.tile))
		Intent.SETTLE:
			# Pays with what there is now; what is missing becomes a loan or a bankruptcy.
			_engine.advance(TurnResolver.settle(state, _engine.config))
			return true

	return false
