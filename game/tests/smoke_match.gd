## End-to-end smoke test: opens every screen and plays a whole local match through the same
## path a real game uses (Session -> MatchEngine -> EventBus -> MatchView), with the simple
## bot choosing for every player.
##
## Run from the project folder:
##   godot --headless res://tests/smoke_match.tscn
## Without --headless it also saves screenshots to user://smoke_*.png.
## The exit code is 0 when the match reached a winner without errors.
extends Node

const MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const LOBBY_SCENE := "res://ui/lobby/lobby.tscn"
const MATCH_SCENE := "res://ui/match/match.tscn"

const PLAYERS := 4
const MAX_STEPS := 20000
const SHOT_AT_STEP := 40
const SETTLE_SECONDS := 7.0

## Where the owner strip of a tile is checked, along the tile, in flat board pixels.
const STRIP_SAMPLES: Array[int] = [-40, -22, 0, 22, 42]

var _view: MatchView = null

func _ready() -> void:
	var menu: Node = load(MENU_SCENE).instantiate()
	add_child(menu)
	await _shot("menu")
	menu.free()

	Session.create_room("Ana", 0)
	await EventBus.lobby_entered
	for i in PLAYERS - 1:
		Session.add_local_player("King %d" % (i + 2))
	Session.set_ready(true)

	var lobby: Node = load(LOBBY_SCENE).instantiate()
	add_child(lobby)
	await _shot("lobby")
	lobby.free()

	if not Session.can_start():
		_finish(false, "the lobby could not start the match")
		return
	Session.start_match()
	_view = load(MATCH_SCENE).instantiate()
	# As the current scene, so the screen is fitted for the match (see ScreenFit).
	get_tree().root.add_child(_view)
	get_tree().current_scene = _view

	var steps := 0
	var shot_taken := false
	while steps < MAX_STEPS:
		var state: GameState = GameState.from_dict(Session.snapshot)
		if state.phase == GameEnums.Phase.GAME_OVER:
			await _shot("game_over")
			if not _board_matches(state):
				_finish(false, "the board on screen does not match the state")
				return
			_finish(true, "winner after %d intents: %s (%s)" % [
				steps, state.players[state.winner].name,
				GameEnums.WinReason.keys()[state.win_reason],
			])
			return

		Session.send_intent(_decide(state, steps))
		steps += 1
		if not shot_taken and steps >= SHOT_AT_STEP and Session.snapshot.phase == GameEnums.Phase.BUY:
			# Taken on a purchase, so the buy pop-up is in the picture.
			shot_taken = true
			await _shot("match")
		elif steps % 50 == 0:
			await get_tree().process_frame

	_finish(false, "no winner after %d intents" % MAX_STEPS)

# The simple bot, plus an offer now and then so the negotiation is exercised too.
func _decide(state: GameState, step: int) -> Dictionary:
	if state.phase == GameEnums.Phase.OFFER and step % 3 == 0:
		var price: int = state.pending.max if step % 2 == 0 else state.pending.min
		if state.players[state.actor].money >= price:
			return Intent.offer(price)
	return SimpleBot.decide(state, Session.CONFIG)

# Compares the owner strip drawn on every tile with the owner in the state.
# Needs a real window, so it is skipped in headless runs.
func _board_matches(state: GameState) -> bool:
	if DisplayServer.get_name() == "headless":
		return true

	var image: Image = get_viewport().get_texture().get_image()
	var tiles: Array[BoardTile] = _view.board.get_tiles()
	var matches := true

	for i in tiles.size():
		var expected: Color = BoardTile.BACKGROUNDS[tiles[i].tile_type]
		if state.tiles[i].owner >= 0:
			expected = KingPalette.color_of(state.players[state.tiles[i].owner].color)

		# The strip runs along one edge of the tile. Kings and buildings, also the ones of the
		# tiles in front, may stand over part of it: one clear point is enough.
		var found := false
		for x: int in STRIP_SAMPLES:
			var point: Vector2 = _view.board.transform * (tiles[i].position + Vector2(x, 43))
			var pixel: Color = image.get_pixelv(Vector2i(point))
			if absf(pixel.r - expected.r) + absf(pixel.g - expected.g) + absf(pixel.b - expected.b) <= 0.05:
				found = true
		if not found:
			printerr("Tile %s is drawn with the wrong owner." % state.board[i].key)
			matches = false

	return matches

func _shot(shot_name: String) -> void:
	# Lets the dice stop, the kings arrive, the pop-up open and the messages fade away.
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(SETTLE_SECONDS).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://smoke_%s.png" % shot_name)

func _finish(passed: bool, message: String) -> void:
	print(("PASS: " if passed else "FAIL: ") + message)
	get_tree().quit(0 if passed else 1)
