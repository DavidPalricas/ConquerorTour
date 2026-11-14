## The room the local player is in: who is there, who is the host, and the link between the
## match engine, the network and the screens. Registered as the Autoload "Session".
##
## Host-authoritative: clients send intents, the host runs the MatchEngine and sends the
## resulting state to everyone. Screens never talk to the engine or to the transport; they
## call this node and listen to the EventBus.
##
## Messages (field "t" is the type):
##   client -> host: hello { name, color }, ready { v }, intent { i }
##   host -> client: welcome { pid }, lobby { code, players }, start { pid },
##                   state { s, ev }, reject { reason }
extends Node

enum Role { NONE, HOST, CLIENT }

const ENGINE_SCENE := preload("res://engine/match_engine.tscn")
const BOARD_SCENE := preload("res://board/board.tscn")
const CONFIG: GameConfig = preload("res://config/game_config.tres")

const MAX_NAME_LENGTH := 16

var role: Role = Role.NONE
var room_code: String = ""

## Players in the room, for the lobby: { id, name, color, ready }.
var lobby: Array = []

## Ids of the players controlled from this screen. One when online; several in a local game.
var local_ids: Array = []

## Last state of the match, as received (GameState.to_dict()).
var snapshot: Dictionary = {}

var in_match: bool = false

## Why the last session ended (a translation key), for the main menu to show once.
var close_reason: String = ""

var _transport: Transport = null
var _engine: MatchEngine = null

# Host: PeerJS id of each client -> player id.
var _peers: Dictionary = {}
var _next_id: int = 0

# Client: connection to the host, and what to say on arrival.
var _host_peer: String = ""
var _hello: Dictionary = {}
var _entered: bool = false

# ====== Called by the screens ======

func is_host() -> bool:
	return role == Role.HOST

## Whether the room goes through the network. Outside the browser everything is local.
func is_online() -> bool:
	return OS.has_feature("web")

func controls(pid: int) -> bool:
	return local_ids.has(pid)

func create_room(player_name: String, color: int) -> void:
	leave()
	role = Role.HOST
	room_code = RoomCode.generate()
	lobby = [{"id": 0, "name": _clean_name(player_name), "color": color, "ready": false}]
	local_ids = [0]
	_next_id = 1

	_open_transport()
	_transport.host(room_code)

func join_room(code: String, player_name: String, color: int) -> void:
	leave()
	role = Role.CLIENT
	room_code = RoomCode.normalise(code)
	_hello = {"t": "hello", "name": _clean_name(player_name), "color": color}

	_open_transport()
	_transport.join(room_code)

func set_ready(ready: bool) -> void:
	if in_match or local_ids.is_empty():
		return
	if is_host():
		_set_ready(local_ids[0], ready)
	else:
		_transport.send(_host_peer, {"t": "ready", "v": ready})

## Adds a player who shares this screen. Local rooms only (see LocalTransport).
func add_local_player(player_name: String) -> void:
	if not is_host() or is_online() or in_match or lobby.size() >= CONFIG.max_players:
		return
	var entry: Dictionary = _add_to_lobby(player_name, 0)
	entry.ready = true
	local_ids.append(entry.id)
	_sync_lobby()

func can_start() -> bool:
	if not is_host() or in_match or lobby.size() < CONFIG.min_players:
		return false
	for entry: Dictionary in lobby:
		if not entry.ready:
			return false
	return true

func start_match() -> void:
	if not can_start():
		return

	# From here on a player id is the position in the turn order.
	var new_ids: Dictionary = {}
	var infos: Array = []
	for i in lobby.size():
		new_ids[lobby[i].id] = i
		lobby[i].id = i
		infos.append({"name": lobby[i].name, "color": lobby[i].color})
	local_ids = local_ids.map(func(id: int) -> int: return new_ids[id])
	for peer: String in _peers:
		_peers[peer] = new_ids[_peers[peer]]

	var board: Board = BOARD_SCENE.instantiate()
	var board_def: Array = board.to_definition()
	board.free()

	_engine = ENGINE_SCENE.instantiate()
	add_child(_engine)
	_engine.state_flushed.connect(_on_state_flushed)

	in_match = true
	for peer: String in _peers:
		_transport.send(peer, {"t": "start", "pid": _peers[peer]})
	_engine.start_match(board_def, infos)
	EventBus.match_started.emit()

## Sends an intent for the player who has to act, when that player is controlled here.
func send_intent(intent: Dictionary) -> void:
	if not in_match or snapshot.is_empty():
		return
	var actor: int = snapshot.actor
	if not controls(actor):
		return

	if is_host():
		_engine.submit_intent(actor, intent)
	else:
		_transport.send(_host_peer, {"t": "intent", "i": intent})

## Leaves the room on purpose. When the host leaves, the match ends for everyone.
func leave() -> void:
	_close("", false)

# ====== Transport ======

func _open_transport() -> void:
	_transport = PeerJsTransport.new() if is_online() else LocalTransport.new()
	_transport.opened.connect(_on_opened)
	_transport.peer_connected.connect(_on_peer_connected)
	_transport.peer_disconnected.connect(_on_peer_disconnected)
	_transport.message_received.connect(_on_message)
	_transport.failed.connect(_on_failed)

func _on_opened() -> void:
	_entered = true
	EventBus.lobby_entered.emit()

func _on_failed(error_key: String) -> void:
	_close(error_key, true)

func _on_peer_connected(peer_id: String) -> void:
	if role == Role.CLIENT:
		_host_peer = peer_id
		_transport.send(peer_id, _hello)

func _on_peer_disconnected(peer_id: String) -> void:
	if role == Role.CLIENT:
		_close("ERR_HOST_LEFT", true)
		return

	if not _peers.has(peer_id):
		return
	var pid: int = _peers[peer_id]
	_peers.erase(peer_id)

	if in_match:
		# The bot plays until the player comes back with the same name.
		_engine.set_bot(pid, true)
	else:
		lobby = lobby.filter(func(entry: Dictionary) -> bool: return entry.id != pid)
		_sync_lobby()

func _on_message(peer_id: String, message: Dictionary) -> void:
	if role == Role.HOST:
		_host_handle(peer_id, message)
	elif role == Role.CLIENT and peer_id == _host_peer:
		_client_handle(message)

# ====== Host side ======

func _host_handle(peer_id: String, message: Dictionary) -> void:
	match str(message.get("t", "")):
		"hello":
			_host_hello(peer_id, message)
		"ready":
			if _peers.has(peer_id) and not in_match:
				_set_ready(_peers[peer_id], bool(message.get("v", false)))
		"intent":
			var intent: Variant = message.get("i")
			if _peers.has(peer_id) and in_match and intent is Dictionary:
				# The engine refuses it unless this player is the one who has to act.
				_engine.submit_intent(_peers[peer_id], GameState.normalise(intent))

func _host_hello(peer_id: String, message: Dictionary) -> void:
	if _peers.has(peer_id):
		return
	var player_name: String = _clean_name(str(message.get("name", "")))
	var color: int = clampi(int(message.get("color", 0)), 0, KingPalette.COLORS.size() - 1)

	if in_match:
		var pid: int = _find_returning_player(player_name)
		if pid < 0:
			_transport.send(peer_id, {"t": "reject", "reason": "ERR_MATCH_IN_PROGRESS"})
			return
		_peers[peer_id] = pid
		_transport.send(peer_id, {"t": "start", "pid": pid})
		_engine.set_bot(pid, false)
		return

	if lobby.size() >= CONFIG.max_players:
		_transport.send(peer_id, {"t": "reject", "reason": "ERR_ROOM_FULL"})
		return

	var entry: Dictionary = _add_to_lobby(player_name, color)
	_peers[peer_id] = entry.id
	_transport.send(peer_id, {"t": "welcome", "pid": entry.id})
	_sync_lobby()

# A player who dropped out is recognised by name: the one a bot is playing for.
func _find_returning_player(player_name: String) -> int:
	for p: Dictionary in _engine.state.players:
		if p.bot and p.name == player_name and not _peers.values().has(p.id):
			return p.id
	return -1

func _add_to_lobby(player_name: String, color: int) -> Dictionary:
	var entry: Dictionary = {
		"id": _next_id,
		"name": _unique_name(_clean_name(player_name)),
		"color": _free_color(color),
		"ready": false,
	}
	_next_id += 1
	lobby.append(entry)
	return entry

func _set_ready(pid: int, ready: bool) -> void:
	for entry: Dictionary in lobby:
		if entry.id == pid:
			entry.ready = ready
	_sync_lobby()

func _sync_lobby() -> void:
	_transport.broadcast({"t": "lobby", "code": room_code, "players": lobby})
	EventBus.lobby_changed.emit()

func _on_state_flushed(new_snapshot: Dictionary, events: Array) -> void:
	snapshot = new_snapshot
	_transport.broadcast({"t": "state", "s": new_snapshot, "ev": events})
	EventBus.match_updated.emit(snapshot, events)

# Names identify returning players, so two players cannot share one.
func _unique_name(player_name: String) -> String:
	var taken: Array = lobby.map(func(entry: Dictionary) -> String: return entry.name)
	var candidate: String = player_name
	var suffix := 2
	while taken.has(candidate):
		candidate = "%s %d" % [player_name, suffix]
		suffix += 1
	return candidate

# The colour asked for, or the first free one when someone already has it.
func _free_color(wanted: int) -> int:
	var taken: Array = lobby.map(func(entry: Dictionary) -> int: return entry.color)
	if not taken.has(wanted):
		return wanted
	for color in KingPalette.COLORS.size():
		if not taken.has(color):
			return color
	return wanted

# ====== Client side ======

func _client_handle(message: Dictionary) -> void:
	var data: Dictionary = GameState.normalise(message)

	match str(data.get("t", "")):
		"welcome":
			local_ids = [int(data.get("pid", -1))]
		"lobby":
			lobby = data.get("players", [])
			if _entered:
				EventBus.lobby_changed.emit()
			else:
				_entered = true
				EventBus.lobby_entered.emit()
		"start":
			local_ids = [int(data.get("pid", -1))]
			in_match = true
			EventBus.match_started.emit()
		"state":
			snapshot = data.get("s", {})
			EventBus.match_updated.emit(snapshot, data.get("ev", []))
		"reject":
			_close(str(data.get("reason", "ERR_NETWORK")), true)

# ====== Shared ======

func _close(reason_key: String, notify: bool) -> void:
	var was_open: bool = role != Role.NONE

	if _transport != null:
		_transport.close()
		_transport = null
	if _engine != null:
		_engine.queue_free()
		_engine = null

	role = Role.NONE
	room_code = ""
	lobby = []
	local_ids = []
	snapshot = {}
	in_match = false
	_peers = {}
	_host_peer = ""
	_entered = false

	if was_open and notify:
		close_reason = reason_key
		EventBus.session_closed.emit(reason_key)

func _clean_name(player_name: String) -> String:
	return player_name.strip_edges().left(MAX_NAME_LENGTH)
