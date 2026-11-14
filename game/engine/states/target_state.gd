## The player has to pick a tile: where the Pope's Call sends them, what King's Invasion
## destroys, or what the Shield protects. The valid tiles are in state.pending.targets.
class_name TargetState extends MatchState

func handle_intent(intent: Dictionary) -> bool:
	var state: GameState = _engine.state

	if intent.type == Intent.SKIP:
		_engine.end_turn()
		return true

	if intent.type != Intent.TARGET or not intent.has("tile"):
		return false

	var pid: int = state.actor
	var index: int = int(intent.tile)
	if not state.pending.targets.has(index):
		return false

	match int(state.pending.kind):
		GameEnums.TargetKind.POPE:
			# The trip goes forward, so passing the Start on the way pays the salary.
			var size: int = state.board.size()
			var steps: int = (index - int(state.players[pid].pos) + size) % size
			TurnResolver.move(state, _engine.config, pid, steps)
			state.pending = {}
			state.log_event(GameEnums.Event.POPE_TRAVEL, {"p": pid, "t": index})
			_engine.resolve_landing(pid)
			return true

		GameEnums.TargetKind.INVASION:
			var victim: int = state.tiles[index].owner
			if state.tiles[index].shield:
				state.tiles[index].shield = false
				state.log_event(GameEnums.Event.SHIELD_BROKEN, {"p": pid, "q": victim, "t": index})
			else:
				TurnResolver.destroy(state, index)
				state.log_event(GameEnums.Event.INVASION, {"p": pid, "q": victim, "t": index})

		GameEnums.TargetKind.SHIELD:
			state.tiles[index].shield = true
			state.log_event(GameEnums.Event.SHIELD_PLACED, {"p": pid, "t": index})

	_engine.end_turn()
	return true
