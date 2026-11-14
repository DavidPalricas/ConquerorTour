## The whole state of a match. Plain data: arrays, dictionaries, numbers and stable keys, so it
## goes through JSON unchanged (see to_dict / from_dict). No text shown to players lives here.
class_name GameState extends RefCounted

## Static board definition, one entry per tile: { type, empire, key }.
var board: Array = []

## Ownership of each tile, same order as board: { owner (-1 = free), level, shield }.
var tiles: Array = []

## One entry per player, indexed by player id:
## { id, name, color, money, pos, hell, debt, bankrupt, bot, debt_card, rent_card }.
var players: Array = []

## Id of the player whose turn it is.
var turn: int = 0

## Current GameEnums.Phase.
var phase: int = GameEnums.Phase.IDLE

## Id of the player who has to act now (-1 = nobody).
var actor: int = -1

## Data of the decision being waited for. Its content depends on the phase.
var pending: Dictionary = {}

## Last dice rolled.
var dice: Array = []

## Last card drawn this turn (-1 = none).
var card: int = -1

## Host only: the roll that just happened was a double, so the player rolls again.
var extra_turn: bool = false

var winner: int = -1
var win_reason: int = GameEnums.WinReason.NONE

## Events since the last flush. Sent next to the snapshot, never inside it.
var events: Array = []

## Builds the state of a new match. [param infos] holds { name, color } per player.
static func create(board_def: Array, infos: Array, cfg: GameConfig) -> GameState:
	var state := GameState.new()
	state.board = board_def.duplicate(true)

	for i in board_def.size():
		state.tiles.append({"owner": -1, "level": 0, "shield": false})

	for i in infos.size():
		var info: Dictionary = infos[i]
		state.players.append({
			"id": i,
			"name": info.get("name", ""),
			"color": info.get("color", 0),
			"money": cfg.starting_money,
			"pos": 0,
			"hell": 0,
			"debt": 0,
			"bankrupt": false,
			"bot": false,
			"debt_card": false,
			"rent_card": GameEnums.RentCard.NONE,
		})

	return state

func log_event(type: int, params: Dictionary = {}) -> void:
	params["e"] = type
	events.append(params)

## Ids of the players still in the match.
func alive_ids() -> Array:
	var ids: Array = []
	for p: Dictionary in players:
		if not p.bankrupt:
			ids.append(p.id)
	return ids

## Indices of the tiles owned by [param pid].
func owned_by(pid: int) -> Array:
	var owned: Array = []
	for i in tiles.size():
		if tiles[i].owner == pid:
			owned.append(i)
	return owned

func to_dict() -> Dictionary:
	return {
		"board": board.duplicate(true),
		"tiles": tiles.duplicate(true),
		"players": players.duplicate(true),
		"turn": turn,
		"phase": phase,
		"actor": actor,
		"pending": pending.duplicate(true),
		"dice": dice.duplicate(),
		"card": card,
		"winner": winner,
		"win_reason": win_reason,
	}

static func from_dict(data: Dictionary) -> GameState:
	var d: Dictionary = normalise(data)
	var state := GameState.new()
	state.board = d.get("board", [])
	state.tiles = d.get("tiles", [])
	state.players = d.get("players", [])
	state.turn = d.get("turn", 0)
	state.phase = d.get("phase", GameEnums.Phase.IDLE)
	state.actor = d.get("actor", -1)
	state.pending = d.get("pending", {})
	state.dice = d.get("dice", [])
	state.card = d.get("card", -1)
	state.winner = d.get("winner", -1)
	state.win_reason = d.get("win_reason", GameEnums.WinReason.NONE)
	return state

## JSON turns every number into a float. The state only holds whole numbers, so this puts them
## back as ints, recursively.
static func normalise(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var f: float = value
			if f == floorf(f):
				return int(f)
			return f
		TYPE_ARRAY:
			var out: Array = []
			for item: Variant in value:
				out.append(normalise(item))
			return out
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in value:
				out[key] = normalise(value[key])
			return out
	return value
