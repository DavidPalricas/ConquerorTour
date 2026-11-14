## The match has a winner. Nobody acts any more.
class_name GameOverState extends MatchState

func _on_enter(state: GameState) -> void:
	state.actor = -1
	state.pending = {}
