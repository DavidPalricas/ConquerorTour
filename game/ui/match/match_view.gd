## The match screen. Draws whatever state arrives through the EventBus and turns clicks into
## intents. It holds no rules: the same code runs on the host and on the clients.
class_name MatchView extends Node2D

const KING_SCENE := preload("res://players/king.tscn")

## Where each player's king stands inside a tile, in screen pixels from its centre, so up to
## eight fit on the same isometric tile.
const KING_SLOTS: Array[Vector2] = [
	Vector2(-36, 8), Vector2(-12, 8), Vector2(12, 8), Vector2(36, 8),
	Vector2(-27, 24), Vector2(-9, 24), Vector2(9, 24), Vector2(27, 24),
]

@export_file("*.tscn") var main_menu_path: String = ""

@export var board: Board = null

## Parent of the kings. Not transformed, so the kings stand upright on the skewed board.
@export var kings_root: Node2D = null

@export var players_hud: PlayersHud = null
@export var action_panel: ActionPanel = null
@export var buy_popup: BuyPopup = null
@export var event_log: EventLog = null

## Shows the last Lucifer Roulette card of the turn.
@export var card_panel: Control = null
@export var card_title: Label = null
@export var card_text: Label = null

@export var leave_button: Button = null

var _state: GameState = null

# Player id -> King.
var _kings: Dictionary = {}

# Player id -> tile the king was last sent to.
var _shown_pos: Dictionary = {}

func _ready() -> void:
	Require.that(main_menu_path != "", "MatchView.main_menu_path must be assigned in the editor.")
	Require.not_null(board, "MatchView.board must be assigned in the editor.")
	Require.not_null(kings_root, "MatchView.kings_root must be assigned in the editor.")
	Require.not_null(players_hud, "MatchView.players_hud must be assigned in the editor.")
	Require.not_null(action_panel, "MatchView.action_panel must be assigned in the editor.")
	Require.not_null(buy_popup, "MatchView.buy_popup must be assigned in the editor.")
	Require.not_null(event_log, "MatchView.event_log must be assigned in the editor.")
	Require.not_null(card_panel, "MatchView.card_panel must be assigned in the editor.")
	Require.not_null(card_title, "MatchView.card_title must be assigned in the editor.")
	Require.not_null(card_text, "MatchView.card_text must be assigned in the editor.")
	Require.not_null(leave_button, "MatchView.leave_button must be assigned in the editor.")

	board.tile_clicked.connect(_on_tile_clicked)
	leave_button.pressed.connect(_on_leave_pressed)
	EventBus.match_updated.connect(_on_match_updated)
	EventBus.session_closed.connect(_on_session_closed)

	card_panel.visible = false
	# The first state may have arrived while this scene was loading.
	if not Session.snapshot.is_empty():
		_on_match_updated(Session.snapshot, [])

# Connected in _ready() to EventBus.match_updated.
func _on_match_updated(snapshot: Dictionary, events: Array) -> void:
	_state = GameState.from_dict(snapshot)

	var rolled: bool = events.any(
			func(event: Dictionary) -> bool: return event.e == GameEnums.Event.ROLLED)
	# After a roll the dice tumble first, then the king walks, then the pop-up opens.
	var dice_delay: float = DiceView.ROLL_SECONDS if rolled else 0.0
	var walk_delay: float = dice_delay + _dice_total() * King.STEP_SECONDS if rolled else 0.0

	_refresh_tiles()
	_refresh_kings(dice_delay)
	_refresh_card()
	players_hud.refresh(_state)
	action_panel.refresh(_state, rolled)
	buy_popup.refresh(_state, walk_delay)
	event_log.add_events(events, _state)
	leave_button.text = "UI_BACK_TO_MENU" if _state.phase == GameEnums.Phase.GAME_OVER else "UI_LEAVE"

func _refresh_tiles() -> void:
	var tiles: Array[BoardTile] = board.get_tiles()

	for i in tiles.size():
		var definition: Dictionary = _state.board[i]
		var ts: Dictionary = _state.tiles[i]
		var owned: bool = ts.owner >= 0
		var info := ""

		if owned:
			info = MoneyFormat.compact(Economy.rent(_state, Session.CONFIG, i))
		elif Economy.is_ownable(definition):
			info = MoneyFormat.compact(Economy.land_price(Session.CONFIG, definition))

		var color: Color = KingPalette.color_of(_state.players[ts.owner].color) if owned else Color.WHITE
		tiles[i].show_ownership(owned, color, ts.level, ts.shield, info)

	# Only the player who has to choose sees the valid tiles.
	var choosing: bool = _state.phase == GameEnums.Phase.TARGET and Session.controls(_state.actor)
	board.highlight(_state.pending.targets if choosing else [])

func _refresh_kings(delay: float) -> void:
	for p: Dictionary in _state.players:
		if not _kings.has(p.id):
			var king: King = KING_SCENE.instantiate()
			kings_root.add_child(king)
			king.set_color(KingPalette.color_of(p.color))
			_kings[p.id] = king

		var piece: King = _kings[p.id]
		piece.visible = not p.bankrupt
		# Between the buildings of its tile and the ones of the tiles in front (see BoardTile).
		piece.z_index = 2 * board.get_tile_depth(p.pos) + 2
		piece.walk(_path(p.id, _shown_pos.get(p.id, p.pos), p.pos), delay)
		_shown_pos[p.id] = p.pos

# Points a king goes through from one tile to another. A dice roll walks tile by tile; a
# longer jump (the Pope's Call) goes straight there.
func _path(pid: int, from: int, to: int) -> Array[Vector2]:
	var slot: Vector2 = KING_SLOTS[pid % KING_SLOTS.size()]
	var size: int = _state.board.size()
	var steps: int = (to - from + size) % size
	var points: Array[Vector2] = []

	if steps <= Session.CONFIG.dice_count * Session.CONFIG.dice_sides:
		for step in range(1, steps):
			points.append(board.get_tile_screen_position((from + step) % size) + slot)
	points.append(board.get_tile_screen_position(to) + slot)
	return points

func _dice_total() -> int:
	var total := 0
	for value: int in _state.dice:
		total += value
	return total

func _refresh_card() -> void:
	card_panel.visible = _state.card >= 0
	if card_panel.visible:
		card_title.text = GameEnums.card_title_key(_state.card)
		card_text.text = GameEnums.card_text_key(_state.card)

# Connected in _ready() to board.tile_clicked.
func _on_tile_clicked(index: int) -> void:
	if _state == null or _state.phase != GameEnums.Phase.TARGET:
		return
	if _state.pending.targets.has(index):
		Session.send_intent(Intent.target(index))

# Connected in _ready() to leave_button.pressed.
func _on_leave_pressed() -> void:
	Session.leave()
	get_tree().change_scene_to_file(main_menu_path)

# Connected in _ready() to EventBus.session_closed.
func _on_session_closed(_reason_key: String) -> void:
	get_tree().change_scene_to_file(main_menu_path)
