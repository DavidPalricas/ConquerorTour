## Victory conditions: a full board line, enough complete empires, all the churches, or being
## the last player standing.
class_name Victory

## Returns { winner, reason }. winner is -1 while nobody has won.
static func check(state: GameState, cfg: GameConfig) -> Dictionary:
	var alive: Array = state.alive_ids()
	if alive.size() == 1:
		return {"winner": alive[0], "reason": GameEnums.WinReason.LAST_STANDING}

	for pid: int in alive:
		if Economy.count_owned(state, pid, GameEnums.TileType.CHURCH) >= cfg.churches_to_win:
			return {"winner": pid, "reason": GameEnums.WinReason.CHURCHES}
		if complete_empires(state, pid) >= cfg.monopolies_to_win:
			return {"winner": pid, "reason": GameEnums.WinReason.MONOPOLIES}
		if has_line(state, pid):
			return {"winner": pid, "reason": GameEnums.WinReason.LINE}

	return {"winner": -1, "reason": GameEnums.WinReason.NONE}

## Number of empires whose cities all belong to [param pid]. The groups come from the empire
## of each tile; no list of groups is kept by hand.
static func complete_empires(state: GameState, pid: int) -> int:
	var total: Dictionary = {}
	var owned: Dictionary = {}

	for i in state.board.size():
		var tile: Dictionary = state.board[i]
		if tile.type != GameEnums.TileType.CITY:
			continue
		total[tile.empire] = total.get(tile.empire, 0) + 1
		if state.tiles[i].owner == pid:
			owned[tile.empire] = owned.get(tile.empire, 0) + 1

	var complete := 0
	for empire: int in total:
		if owned.get(empire, 0) == total[empire]:
			complete += 1
	return complete

## Whether [param pid] owns every property of one side of the board. Special tiles do not
## count because they cannot be bought; churches do.
static func has_line(state: GameState, pid: int) -> bool:
	var side: int = state.board.size() / 4

	for s in 4:
		var ownable := 0
		var owned := 0
		for i in range(s * side + 1, (s + 1) * side):
			if Economy.is_ownable(state.board[i]):
				ownable += 1
				if state.tiles[i].owner == pid:
					owned += 1
		if ownable > 0 and owned == ownable:
			return true

	return false
