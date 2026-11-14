## Transport with no network, used outside the browser (editor and desktop runs).
## A room opens at once and nobody can join it: every player is added locally in the lobby
## and they share the screen. This is the development prototype mode.
class_name LocalTransport extends Transport

func host(_code: String) -> void:
	opened.emit.call_deferred()

func join(_code: String) -> void:
	failed.emit.call_deferred("ERR_ONLINE_WEB_ONLY")

func send(_peer_id: String, _message: Dictionary) -> void:
	pass

func broadcast(_message: Dictionary) -> void:
	pass

func close() -> void:
	pass
