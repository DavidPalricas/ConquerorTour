## Log of what happens in the match. The host only sends event ids and numbers; the text is
## built here, in the language of this player.
class_name EventLog extends RichTextLabel

func add_events(events: Array, state: GameState) -> void:
	for event: Dictionary in events:
		append_text(_describe(event, state) + "\n")

func _describe(event: Dictionary, state: GameState) -> String:
	var args: Dictionary = {}

	if event.has("p"):
		args["player"] = _player(state, event.p)
	if event.has("q"):
		args["other"] = _player(state, event.q)
	if event.has("a"):
		args["amount"] = MoneyFormat.full(event.a)
	if event.has("t"):
		args["tile"] = tr(state.board[event.t].key)
	if event.has("c"):
		args["card"] = tr(GameEnums.card_title_key(event.c))
	if event.has("l"):
		args["level"] = tr(GameEnums.level_key(event.l))
	if event.has("n"):
		args["count"] = event.n
	if event.has("r"):
		args["reason"] = tr(GameEnums.win_reason_key(event.r))
	if event.has("d"):
		args["dice"] = " + ".join(event.d.map(func(value: int) -> String: return str(value)))

	return tr(GameEnums.event_key(event.e)).format(args)

# The name in the colour of the king. "[" is escaped so a name cannot inject BBCode.
func _player(state: GameState, pid: int) -> String:
	var p: Dictionary = state.players[pid]
	var color: Color = KingPalette.color_of(p.color).lightened(0.25)
	var safe_name: String = str(p.name).replace("[", "[lb]")
	return "[color=#%s]%s[/color]" % [color.to_html(false), safe_name]
