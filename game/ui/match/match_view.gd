## The match screen. Draws whatever state arrives through the EventBus and turns clicks into
## intents. It holds no rules: the same code runs on the host and on the clients.
class_name MatchView extends Node2D

const KING_SCENE := preload("res://players/king.tscn")

## Where each player's king stands inside a tile, in screen pixels from its centre, so up to
## eight fit on the same isometric tile.
const KING_SLOTS: Array[Vector2] = [
	Vector2(-54, 4), Vector2(-18, 4), Vector2(18, 4), Vector2(54, 4),
	Vector2(-36, 28), Vector2(-12, 28), Vector2(12, 28), Vector2(36, 28),
]

## Money won or lost floats up from the king for a moment.
const GAIN_COLOR := Color(0.45, 1.0, 0.5)
const LOSS_COLOR := Color(1.0, 0.4, 0.35)
const MONEY_FLOAT_SECONDS := 1.6
const MONEY_FLOAT_HEIGHT := 60.0
const MONEY_FONT_SIZE := 30

## Events shown for a moment in front of the board, and whether they are bad news for the
## player they are about (which only picks the colour of the message).
const TOASTS := {
	GameEnums.Event.PASSED_START: false,
	GameEnums.Event.RENT_PAID: true,
	GameEnums.Event.TAX_PAID: true,
	GameEnums.Event.DEBT_CARD_PAID: true,
	GameEnums.Event.GIFT_PAID: false,
	GameEnums.Event.SENT_TO_HELL: true,
	GameEnums.Event.POPE_CALLED: false,
	GameEnums.Event.POPE_TRAVEL: false,
	GameEnums.Event.INVASION: true,
	GameEnums.Event.SHIELD_PLACED: false,
	GameEnums.Event.SHIELD_BROKEN: false,
	GameEnums.Event.LOAN_TAKEN: true,
	GameEnums.Event.BANKRUPT: true,
	GameEnums.Event.CANT_PAY: true,
	GameEnums.Event.CANT_BUY: true,
	GameEnums.Event.CANT_UPGRADE: true,
	GameEnums.Event.CANT_OFFER: true,
	GameEnums.Event.PROPERTY_SOLD: true,
}

@export_file("*.tscn") var main_menu_path: String = ""

@export var board: Board = null

## Parent of the kings. Not transformed, so the kings stand upright on the skewed board.
@export var kings_root: Node2D = null

@export var players_hud: PlayersHud = null
@export var action_panel: ActionPanel = null
@export var buy_popup: BuyPopup = null
@export var event_log: EventLog = null

## Shows the Lucifer Roulette card that was just drawn, in the middle of the screen.
@export var card_view: CardView = null

## Short messages about what just happened, in front of the board.
@export var toasts: ToastStack = null

@export var leave_button: Button = null

var _state: GameState = null

# Player id -> King.
var _kings: Dictionary = {}

# Player id -> tile the king was last sent to.
var _shown_pos: Dictionary = {}

# Player id -> money last shown, to tell what each update gave or took.
var _shown_money: Dictionary = {}

func _ready() -> void:
	Require.that(main_menu_path != "", "MatchView.main_menu_path must be assigned in the editor.")
	Require.not_null(board, "MatchView.board must be assigned in the editor.")
	Require.not_null(kings_root, "MatchView.kings_root must be assigned in the editor.")
	Require.not_null(players_hud, "MatchView.players_hud must be assigned in the editor.")
	Require.not_null(action_panel, "MatchView.action_panel must be assigned in the editor.")
	Require.not_null(buy_popup, "MatchView.buy_popup must be assigned in the editor.")
	Require.not_null(event_log, "MatchView.event_log must be assigned in the editor.")
	Require.not_null(card_view, "MatchView.card_view must be assigned in the editor.")
	Require.not_null(toasts, "MatchView.toasts must be assigned in the editor.")
	Require.not_null(leave_button, "MatchView.leave_button must be assigned in the editor.")

	board.tile_clicked.connect(_on_tile_clicked)
	leave_button.pressed.connect(_on_leave_pressed)
	EventBus.match_updated.connect(_on_match_updated)
	EventBus.session_closed.connect(_on_session_closed)

	# The first state may have arrived while this scene was loading.
	if not Session.snapshot.is_empty():
		_on_match_updated(Session.snapshot, [])

# Connected in _ready() to EventBus.match_updated.
func _on_match_updated(snapshot: Dictionary, events: Array) -> void:
	_state = GameState.from_dict(snapshot)

	var rolled: bool = _has_event(events, GameEnums.Event.ROLLED)
	# After a roll the dice tumble first, then the king walks; only then does the screen say
	# what the landing meant (messages, card, pop-up). The Pope's Call is a single jump.
	var dice_delay: float = DiceView.ROLL_SECONDS if rolled else 0.0
	var arrival: float = 0.0
	if rolled:
		arrival = dice_delay + _dice_total() * King.STEP_SECONDS
	elif _has_event(events, GameEnums.Event.POPE_TRAVEL):
		arrival = King.STEP_SECONDS

	_refresh_tiles()
	_refresh_kings(dice_delay)
	players_hud.refresh(_state)
	action_panel.refresh(_state, rolled)
	buy_popup.refresh(_state, arrival)
	event_log.add_events(events, _state)
	_show_feedback(events, arrival)
	_show_money_changes(arrival)
	leave_button.text = "UI_BACK_TO_MENU" if _state.phase == GameEnums.Phase.GAME_OVER else "UI_LEAVE"

func _refresh_tiles() -> void:
	var tiles: Array[BoardTile] = board.get_tiles()
	var choices: Array = _choices()
	var selling: bool = _state.phase == GameEnums.Phase.SELL

	for i in tiles.size():
		var definition: Dictionary = _state.board[i]
		var ts: Dictionary = _state.tiles[i]
		var owned: bool = ts.owner >= 0
		var info := ""

		if selling and choices.has(i):
			# What Lucifer pays for it.
			info = MoneyFormat.compact(Economy.sale_value(_state, Session.CONFIG, i))
		elif owned:
			info = MoneyFormat.compact(Economy.rent(_state, Session.CONFIG, i))
		elif Economy.is_ownable(definition):
			info = MoneyFormat.compact(Economy.land_price(Session.CONFIG, definition))

		var color: Color = KingPalette.color_of(_state.players[ts.owner].color) if owned else Color.WHITE
		tiles[i].show_ownership(owned, color, ts.level, ts.shield, info)

	board.highlight(choices)

# Tiles the local player can click right now: the targets of a card or of the Pope's Call,
# or the properties that can be sold to cover a payment. Only the player who chooses sees them.
func _choices() -> Array:
	if _state.actor < 0 or not Session.controls(_state.actor):
		return []

	match _state.phase:
		GameEnums.Phase.TARGET:
			return _state.pending.targets
		GameEnums.Phase.SELL:
			# Selling stops as soon as the payment is covered.
			if _state.players[_state.actor].money < _state.pending.due:
				return _state.pending.targets
	return []

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
		piece.z_index = 2 * board.get_tile_depth(p.pos) + 3
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

func _has_event(events: Array, type: int) -> bool:
	return events.any(func(event: Dictionary) -> bool: return event.e == type)

# What the players see happen: the landing itself, the card that was drawn and a message
# for the things that matter. Everything waits [param delay] seconds, until the king arrives.
func _show_feedback(events: Array, delay: float) -> void:
	for event: Dictionary in events:
		match int(event.e):
			GameEnums.Event.ROLLED, GameEnums.Event.POPE_TRAVEL:
				_later(delay, _show_landing.bind(int(event.p)))
			GameEnums.Event.CARD_DRAWN:
				card_view.show_card(event.c, _state.players[event.p].name, delay)

		if TOASTS.has(int(event.e)):
			toasts.add_toast(event_log.describe(event, _state), TOASTS[int(event.e)], delay)

# The king hops and the tile it stopped on lights up.
func _show_landing(pid: int) -> void:
	if not _kings.has(pid) or not _shown_pos.has(pid):
		return
	(_kings[pid] as King).hop()
	board.get_tiles()[_shown_pos[pid]].flash()

# A "+200K" or "-50K" over the king of every player whose money changed, such as the salary
# of the Start tile, a rent or a purchase.
func _show_money_changes(delay: float) -> void:
	for p: Dictionary in _state.players:
		var before: int = _shown_money.get(p.id, p.money)
		_shown_money[p.id] = p.money
		var change: int = int(p.money) - before
		if change != 0 and not p.bankrupt:
			_later(delay, _float_money.bind(int(p.id), change))

func _float_money(pid: int, change: int) -> void:
	if not _kings.has(pid):
		return
	var king: King = _kings[pid]

	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = ("+" if change > 0 else "-") + MoneyFormat.compact(absi(change))
	label.add_theme_font_size_override("font_size", MONEY_FONT_SIZE)
	label.add_theme_color_override("font_color", GAIN_COLOR if change > 0 else LOSS_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.16))
	label.add_theme_constant_override("outline_size", 8)
	label.z_index = 200
	kings_root.add_child(label)
	label.position = king.position + Vector2(-label.size.x / 2.0, -130.0)

	var tween: Tween = label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - MONEY_FLOAT_HEIGHT, MONEY_FLOAT_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, MONEY_FLOAT_SECONDS) \
			.set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)

func _later(delay: float, action: Callable) -> void:
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(action)
	else:
		action.call()

# Connected in _ready() to board.tile_clicked.
func _on_tile_clicked(index: int) -> void:
	if _state == null or not _choices().has(index):
		return
	if _state.phase == GameEnums.Phase.SELL:
		Session.send_intent(Intent.sell(index))
	else:
		Session.send_intent(Intent.target(index))

# Connected in _ready() to leave_button.pressed.
func _on_leave_pressed() -> void:
	Session.leave()
	get_tree().change_scene_to_file(main_menu_path)

# Connected in _ready() to EventBus.session_closed.
func _on_session_closed(_reason_key: String) -> void:
	get_tree().change_scene_to_file(main_menu_path)
