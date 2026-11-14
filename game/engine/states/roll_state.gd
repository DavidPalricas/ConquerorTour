## Start of a turn: waits for the player to roll, then moves and resolves the landing.
class_name RollState extends MatchState

func _on_enter(state: GameState) -> void:
	state.actor = state.turn
	state.pending = {}

func handle_intent(intent: Dictionary) -> bool:
	if intent.type != Intent.ROLL:
		return false

	var state: GameState = _engine.state
	var pid: int = state.actor
	var steps := 0

	state.card = -1
	state.dice = _engine.random.roll(_engine.config)
	# A double (every die showing the same) earns another roll after this one is resolved.
	var is_double: bool = state.dice.size() > 1
	for value: int in state.dice:
		steps += value
		is_double = is_double and value == state.dice[0]
	state.extra_turn = is_double
	state.log_event(GameEnums.Event.ROLLED, {"p": pid, "d": state.dice.duplicate()})

	TurnResolver.move(state, _engine.config, pid, steps)
	_engine.resolve_landing(pid)
	return true
