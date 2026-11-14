## Base of the turn-phase states. Publishes its phase in the game state on enter and lets the
## bot act when the acting player has dropped out.
class_name MatchState extends State

## Phase written to the game state while this state is active.
@export var phase: GameEnums.Phase = GameEnums.Phase.IDLE

## Injected by MatchEngine._inject_dependencies().
var _engine: MatchEngine = null

var _bot_timer: float = 0.0

func enter() -> void:
	_bot_timer = 0.0
	if _engine.state == null:
		return
	_engine.state.phase = phase
	_on_enter(_engine.state)

func execute(delta: float) -> void:
	var state: GameState = _engine.state
	if state == null or state.actor < 0:
		return

	if not state.players[state.actor].bot:
		_bot_timer = 0.0
		return

	_bot_timer += delta
	if _bot_timer >= _engine.config.bot_delay:
		_bot_timer = 0.0
		_engine.submit_intent(state.actor, SimpleBot.decide(state, _engine.config))

## Applies an intent of the acting player. Returns false when it is not valid in this phase.
func handle_intent(_intent: Dictionary) -> bool:
	return false

## Called on enter once a match is running. By default the player of the turn has to act.
func _on_enter(state: GameState) -> void:
	state.actor = state.turn
