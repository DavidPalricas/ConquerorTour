## Host-side referee of a match. A state machine with one state per turn phase: the active
## state decides which intents are valid and what they do, using the pure rules in res://core.
## Knows nothing about the interface or the network: it takes intents in and gives snapshots out.
class_name MatchEngine extends FSM

## Emitted after every change, with the JSON-ready state and the events since the last flush.
signal state_flushed(snapshot: Dictionary, events: Array)

const TO_ROLL := &"roll"
const TO_OFFER_RESPONSE := &"offer_response"
const TO_GAME_OVER := &"game_over"

@export var config: GameConfig = null

var state: GameState = null
var random := RandomSource.new()

func _ready() -> void:
	Require.not_null(config, "MatchEngine.config must be assigned in the editor.")
	super()

## Gives every state a typed reference to the engine, next to the FSM one.
func _inject_dependencies() -> void:
	super()
	for s: State in _states:
		(s as MatchState)._engine = self

## Starts a match. [param board_def] comes from Board.to_definition() and [param infos] holds
## { name, color } for each player, in turn order.
func start_match(board_def: Array, infos: Array) -> void:
	state = GameState.create(board_def, infos, config)
	change_state(TO_ROLL)
	flush()

## Entry point for everything a player does. Returns false when the intent is not valid for
## the current phase or does not come from the player who has to act.
func submit_intent(pid: int, intent: Dictionary) -> bool:
	if state == null or pid != state.actor or not intent.has("type"):
		return false

	var accepted: bool = (current_state as MatchState).handle_intent(intent)
	if accepted:
		flush()
	return accepted

## Hands a player to the bot (dropped out) or back to the human (returned).
func set_bot(pid: int, is_bot: bool) -> void:
	if state == null or state.players[pid].bot == is_bot:
		return
	state.players[pid].bot = is_bot
	var event: int = GameEnums.Event.PLAYER_LEFT if is_bot else GameEnums.Event.PLAYER_RETURNED
	state.log_event(event, {"p": pid})
	flush()

func flush() -> void:
	var events: Array = state.events.duplicate(true)
	state.events.clear()
	state_flushed.emit(state.to_dict(), events)

## Resolves the tile the player stands on and moves to whatever the turn needs next.
func resolve_landing(pid: int) -> void:
	advance(TurnResolver.land(state, config, random, pid))

## Follows the step returned by the rules: wait for a decision, or end the turn.
func advance(next: StringName) -> void:
	if next == TurnResolver.END:
		end_turn()
	else:
		change_state(next)

## Checks for a winner, then gives the turn to the next player who can play. Players in Hell
## lose the turn and get one turn closer to leaving.
func end_turn() -> void:
	var result: Dictionary = Victory.check(state, config)
	if result.winner >= 0:
		state.winner = result.winner
		state.win_reason = result.reason
		state.log_event(GameEnums.Event.WON, {"p": state.winner, "r": state.win_reason})
		change_state(TO_GAME_OVER)
		return

	# A double earns another roll, unless the player ended up in Hell or went bankrupt.
	if state.extra_turn:
		state.extra_turn = false
		var current: Dictionary = state.players[state.turn]
		if not current.bankrupt and current.hell == 0:
			state.log_event(GameEnums.Event.EXTRA_TURN, {"p": state.turn})
			change_state(TO_ROLL)
			return

	var count: int = state.players.size()
	for i in count * (config.hell_turns + 1):
		state.turn = (state.turn + 1) % count
		var p: Dictionary = state.players[state.turn]
		if p.bankrupt:
			continue
		if p.hell > 0:
			p.hell -= 1
			state.log_event(GameEnums.Event.HELL_WAIT, {"p": state.turn, "n": p.hell})
			continue
		break

	change_state(TO_ROLL)
