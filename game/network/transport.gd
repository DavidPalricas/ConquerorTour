## How messages travel between the host and the clients. The session only talks to this
## interface, so PeerJS can be swapped for another system without touching the rules.
##
## Star topology: the host accepts connections, each client connects to the host only.
## Messages are dictionaries of numbers and stable keys, sent as JSON.
@abstract
class_name Transport extends RefCounted

## The room is open (host) and can be joined with its code.
@warning_ignore("unused_signal")
signal opened

## Host: a client connected. Client: the connection to the host is ready.
@warning_ignore("unused_signal")
signal peer_connected(peer_id: String)

@warning_ignore("unused_signal")
signal peer_disconnected(peer_id: String)

@warning_ignore("unused_signal")
signal message_received(peer_id: String, message: Dictionary)

## The room could not be opened or joined. [param error_key] is a translation key.
@warning_ignore("unused_signal")
signal failed(error_key: String)

## Opens a room that others join with [param code].
@abstract func host(code: String) -> void

## Connects to the room opened with [param code].
@abstract func join(code: String) -> void

@abstract func send(peer_id: String, message: Dictionary) -> void

## Sends to every connected peer.
@abstract func broadcast(message: Dictionary) -> void

@abstract func close() -> void
