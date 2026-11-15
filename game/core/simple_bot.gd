## Bot that replaces a player who dropped out. Deliberately simple: it buys whatever it lands
## on when it has the money, and never starts a negotiation.
class_name SimpleBot

## Intent the bot sends as the acting player of [param state].
static func decide(state: GameState, cfg: GameConfig) -> Dictionary:
	match state.phase:
		GameEnums.Phase.ROLL:
			return Intent.make(Intent.ROLL)

		GameEnums.Phase.BUY:
			# Only affordable options are offered; the bot builds as far as it can.
			return Intent.buy(state.pending.options.back().level)

		GameEnums.Phase.OFFER_RESPONSE:
			var invested: int = Economy.tile_invested(state, cfg, state.pending.tile)
			if state.pending.price >= invested * cfg.bot_accept_multiplier:
				return Intent.make(Intent.ACCEPT)
			return Intent.make(Intent.REFUSE)

		GameEnums.Phase.TARGET:
			return _pick_target(state)

		GameEnums.Phase.SELL:
			return _settle(state, cfg)

	return Intent.make(Intent.SKIP)

# Borrows when Lucifer lends; otherwise sells until the payment is covered.
static func _settle(state: GameState, cfg: GameConfig) -> Dictionary:
	var pending: Dictionary = state.pending
	var missing: int = int(pending.due) - int(state.players[state.actor].money)

	if missing > 0 and not pending.targets.is_empty() \
			and not Bank.can_borrow(state, cfg, state.actor, missing):
		return Intent.sell(pending.targets[0])
	return Intent.make(Intent.SETTLE)

static func _pick_target(state: GameState) -> Dictionary:
	var targets: Array = state.pending.targets

	# The Pope's Call is only worth it to reach a free property.
	if state.pending.kind == GameEnums.TargetKind.POPE:
		for index: int in targets:
			if state.tiles[index].owner < 0:
				return Intent.target(index)
		return Intent.make(Intent.SKIP)

	return Intent.target(targets[0])
