## WebRTC transport through PeerJS, for the web export. The public PeerJS server is only
## used for signalling (finding each other); the game data goes peer to peer.
##
## The PeerJS library itself is loaded by the exported HTML page (see the head include of the
## Web export preset). The small script below wraps it in an object this class talks to
## through JavaScriptBridge.
class_name PeerJsTransport extends Transport

## Prefix of the PeerJS id of a room, so room codes do not collide with other PeerJS users.
const ID_PREFIX := "ctour-room-"

const ERROR_KEYS := {
	"peer-unavailable": "ERR_ROOM_NOT_FOUND",
	"unavailable-id": "ERR_CODE_TAKEN",
	"no-peerjs": "ERR_NO_PEERJS",
	"browser-incompatible": "ERR_BROWSER",
}

const BRIDGE_SOURCE := """
(function () {
	if (window.ctNet) { return; }
	var peer = null, conns = {}, cb = null, farewell = "";

	// Changes whenever a room is opened or closed, so late events of an old room are ignored.
	var session = 0;

	function emit(type, id, data) { if (cb) { cb(type, id || "", data || ""); } }

	function drop(conn) {
		if (conns[conn.peer] === conn) {
			delete conns[conn.peer];
			emit("disconnected", conn.peer);
		}
	}

	function wire(conn) {
		var mine = session;
		conn.on("open", function () {
			if (mine !== session) { conn.close(); return; }
			conns[conn.peer] = conn;
			emit("connected", conn.peer);

			// PeerJS does not fire "close" in every browser when the other side goes away:
			// watch the WebRTC connection itself too.
			var pc = conn.peerConnection;
			if (pc) {
				pc.addEventListener("iceconnectionstatechange", function () {
					var s = pc.iceConnectionState;
					if (s === "failed" || s === "closed") { drop(conn); }
				});
			}
		});
		conn.on("data", function (data) {
			if (conns[conn.peer] === conn) { emit("data", conn.peer, String(data)); }
		});
		conn.on("close", function () { drop(conn); });
		conn.on("error", function () { drop(conn); });
	}

	function start(id) {
		if (typeof Peer === "undefined") { emit("error", "", "no-peerjs"); return null; }
		session++;
		var p = id ? new Peer(id) : new Peer();
		peer = p;
		p.on("error", function (e) { if (p === peer) { emit("error", "", (e && e.type) || "unknown"); } });
		// Losing the signalling server does not close the game connections: just go back to it.
		p.on("disconnected", function () { if (p === peer && !p.destroyed) { p.reconnect(); } });
		return p;
	}

	// Closing the tab does not run the game's own leave: say goodbye from here.
	window.addEventListener("pagehide", function () {
		if (!farewell) { return; }
		for (var id in conns) { try { conns[id].send(farewell); } catch (e) {} }
	});

	window.ctNet = {
		setCallback: function (f) { cb = f; },
		setFarewell: function (text) { farewell = text || ""; },
		host: function (id) {
			var p = start(id);
			if (!p) { return; }
			p.on("open", function () { if (p === peer) { emit("open", id); } });
			p.on("connection", function (conn) { if (p === peer) { wire(conn); } });
		},
		join: function (hostId) {
			var p = start("");
			if (!p) { return; }
			p.on("open", function () { if (p === peer) { wire(p.connect(hostId, { reliable: true })); } });
		},
		send: function (id, text) { var c = conns[id]; if (c && c.open) { c.send(text); } },
		broadcast: function (text) {
			for (var id in conns) { if (conns[id].open) { conns[id].send(text); } }
		},
		close: function () {
			var old = peer;
			peer = null; conns = {}; farewell = ""; session++;
			// The last messages (the goodbye) need a moment to leave before the teardown.
			if (old) { setTimeout(function () { old.destroy(); }, 400); }
		}
	};
})();
"""

var _js: JavaScriptObject = null

# Kept in a member: the callback stops working once its JavaScriptObject is freed.
var _callback: JavaScriptObject = null

# Errors only end the session while the room is being opened or joined. Later ones (for
# example a hiccup of the signalling server) do not affect the open connections.
var _established: bool = false

func host(code: String) -> void:
	if _connect_bridge():
		_js.host(ID_PREFIX + code)

func join(code: String) -> void:
	if _connect_bridge():
		_js.join(ID_PREFIX + code)

func set_farewell(message: Dictionary) -> void:
	if _js != null:
		_js.setFarewell(JSON.stringify(message))

func send(peer_id: String, message: Dictionary) -> void:
	if _js != null:
		_js.send(peer_id, JSON.stringify(message))

func broadcast(message: Dictionary) -> void:
	if _js != null:
		_js.broadcast(JSON.stringify(message))

func close() -> void:
	if _js != null:
		_js.setCallback(null)
		_js.close()
	_js = null
	_callback = null

func _connect_bridge() -> bool:
	JavaScriptBridge.eval(BRIDGE_SOURCE, true)
	_js = JavaScriptBridge.get_interface("ctNet")
	if _js == null:
		failed.emit.call_deferred("ERR_NETWORK")
		return false

	_callback = JavaScriptBridge.create_callback(_on_js_event)
	_js.setCallback(_callback)
	return true

# Called from JavaScript with [type, peer id, data].
func _on_js_event(args: Array) -> void:
	var type: String = str(args[0])
	var peer_id: String = str(args[1])
	var data: String = str(args[2])

	match type:
		"open":
			_established = true
			opened.emit()
		"connected":
			_established = true
			peer_connected.emit(peer_id)
		"disconnected":
			peer_disconnected.emit(peer_id)
		"data":
			var message: Variant = JSON.parse_string(data)
			if message is Dictionary:
				message_received.emit(peer_id, message)
		"error":
			if not _established:
				failed.emit(ERROR_KEYS.get(data, "ERR_NETWORK"))
