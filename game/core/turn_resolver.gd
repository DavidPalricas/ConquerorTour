## What happens when a player moves and lands. Each function changes the state and returns
## the next step of the turn: END when the turn is over, or the phase that has to wait for a
## decision (the names match the triggers of the MatchEngine FSM).
class_name TurnResolver

const END := &""
const BUY := &"buy"
const OFFER := &"offer"
const TARGET := &"target"

## Moves a player forward. Passing or landing on Start pays the salary.
static func move(state: GameState, cfg: GameConfig, pid: int, steps: int) -> void:
	var p: Dictionary = state.players[pid]
	var size: int = state.board.size()
	var passed_start: bool = int(p.pos) + steps >= size

	p.pos = (int(p.pos) + steps) % size

	if passed_start:
		state.log_event(GameEnums.Event.PASSED_START, {"p": pid, "a": cfg.salary})
		Bank.receive(state, pid, cfg.salary)

## Resolves the tile the player is standing on.
static func land(state: GameState, cfg: GameConfig, random: RandomSource, pid: int) -> StringName:
	var p: Dictionary = state.players[pid]
	var tile: Dictionary = state.board[p.pos]

	match int(tile.type):
		GameEnums.TileType.CITY, GameEnums.TileType.CHURCH:
			return _land_on_property(state, cfg, pid)

		GameEnums.TileType.HELL:
			p.hell = cfg.hell_turns
			state.log_event(GameEnums.Event.SENT_TO_HELL, {"p": pid})

		GameEnums.TileType.TAX:
			var amount: int = Economy.tax(state, cfg, pid)
			if amount > 0 and Bank.pay(state, cfg, pid, amount, Bank.LUCIFER):
				state.log_event(GameEnums.Event.TAX_PAID, {"p": pid, "a": amount})

		GameEnums.TileType.POPE_CALL:
			return _ask_target(state, GameEnums.TargetKind.POPE, pope_targets(state, pid))

		GameEnums.TileType.ROULETTE:
			return _draw_card(state, cfg, random, pid)

	return END

## Buys or builds up to [param level] on the tile waiting in state.pending. The level has to
## be one of the options offered. Voluntary, so no loan: the player needs the money.
static func buy(state: GameState, pid: int, level: int) -> bool:
	var p: Dictionary = state.players[pid]
	var index: int = state.pending.tile
	var ts: Dictionary = state.tiles[index]
	var price := -1

	for option: Dictionary in state.pending.options:
		if option.level == level:
			price = option.price
	if price < 0 or p.money < price:
		return false

	var params: Dictionary = {"p": pid, "t": index, "a": price, "l": level}
	state.log_event(GameEnums.Event.BOUGHT if ts.owner < 0 else GameEnums.Event.UPGRADED, params)

	p.money -= price
	ts.owner = pid
	ts.level = level
	# A castle cannot be destroyed or bought, so a shield on it would be wasted.
	if level == GameEnums.Level.CASTLE:
		ts.shield = false

	return true

## Hands a property (land and buildings) to the buyer. The owner gets the full price, which
## goes through the garnishment rules when the owner is in debt.
static func transfer(state: GameState, index: int, buyer: int, price: int) -> void:
	var ts: Dictionary = state.tiles[index]
	var seller: int = ts.owner

	state.players[buyer].money -= price
	ts.owner = buyer
	Bank.receive(state, seller, price)

## King's Invasion: the property is wiped and the land becomes free for anyone.
static func destroy(state: GameState, index: int) -> void:
	var ts: Dictionary = state.tiles[index]
	ts.owner = -1
	ts.level = 0
	ts.shield = false

## Tiles the Pope's Call can send a player to: their own properties or free ones.
static func pope_targets(state: GameState, pid: int) -> Array:
	var targets: Array = []
	for i in state.board.size():
		var owner: int = state.tiles[i].owner
		if Economy.is_ownable(state.board[i]) and (owner == pid or owner < 0):
			targets.append(i)
	return targets

## Tiles King's Invasion can destroy: any property of another player except castles.
static func invasion_targets(state: GameState, pid: int) -> Array:
	var targets: Array = []
	for i in state.board.size():
		var owner: int = state.tiles[i].owner
		if owner >= 0 and owner != pid and not Economy.is_castle(state, i):
			targets.append(i)
	return targets

## Tiles the Shield can protect: the player's own properties that are not castles.
static func shield_targets(state: GameState, pid: int) -> Array:
	var targets: Array = []
	for index: int in state.owned_by(pid):
		if not Economy.is_castle(state, index) and not state.tiles[index].shield:
			targets.append(index)
	return targets

static func _land_on_property(state: GameState, cfg: GameConfig, pid: int) -> StringName:
	var p: Dictionary = state.players[pid]
	var index: int = p.pos
	var tile: Dictionary = state.board[index]
	var ts: Dictionary = state.tiles[index]

	# Free: offer everything that can be built here at once, when the player can afford it.
	if ts.owner < 0:
		return _ask_purchase(state, cfg, pid, index)

	# Own property: settle a Lucifer Debt, then offer the next level.
	if ts.owner == pid:
		if p.debt_card:
			p.debt_card = false
			var due: int = Economy.rent(state, cfg, index)
			if not Bank.pay(state, cfg, pid, due, Bank.LUCIFER):
				return END
			state.log_event(GameEnums.Event.DEBT_CARD_PAID, {"p": pid, "a": due, "t": index})

		if tile.type == GameEnums.TileType.CITY:
			return _ask_purchase(state, cfg, pid, index)
		return END

	# Someone else's: the rent is always due, offer or not.
	var owner: int = ts.owner
	var rent: int = Economy.rent(state, cfg, index)
	if p.rent_card == GameEnums.RentCard.DOUBLE:
		rent *= 2
	elif p.rent_card == GameEnums.RentCard.HALF:
		rent = roundi(rent / 2.0)
	p.rent_card = GameEnums.RentCard.NONE

	if not Bank.pay(state, cfg, pid, rent, owner):
		return END
	state.log_event(GameEnums.Event.RENT_PAID, {"p": pid, "q": owner, "a": rent, "t": index})

	# One purchase offer per visit, when the property can be bought and the minimum is affordable.
	if Economy.can_receive_offer(state, index):
		var lowest: int = Economy.offer_min(state, cfg, index)
		if p.money >= lowest:
			state.pending = {
				"tile": index,
				"owner": owner,
				"min": lowest,
				"max": Economy.offer_max(state, cfg, index),
			}
			return OFFER

	return END

static func _ask_purchase(state: GameState, cfg: GameConfig, pid: int, index: int) -> StringName:
	var options: Array = Economy.buy_options(state, cfg, index, state.players[pid].money)
	if options.is_empty():
		return END
	state.pending = {"tile": index, "options": options}
	return BUY

static func _draw_card(state: GameState, cfg: GameConfig, random: RandomSource, pid: int) -> StringName:
	var p: Dictionary = state.players[pid]
	var card: int = random.draw_card(cfg)

	state.card = card
	state.log_event(GameEnums.Event.CARD_DRAWN, {"p": pid, "c": card})

	match card:
		GameEnums.Card.LUCIFER_DEBT:
			p.debt_card = true

		GameEnums.Card.LUCIFER_GIFT:
			for other: int in state.alive_ids():
				if other == pid:
					continue
				if Bank.pay(state, cfg, other, cfg.lucifer_gift_amount, pid):
					state.log_event(GameEnums.Event.GIFT_PAID,
							{"p": other, "q": pid, "a": cfg.lucifer_gift_amount})

		GameEnums.Card.KINGS_INVASION:
			return _ask_target(state, GameEnums.TargetKind.INVASION, invasion_targets(state, pid))

		GameEnums.Card.SHIELD:
			return _ask_target(state, GameEnums.TargetKind.SHIELD, shield_targets(state, pid))

		GameEnums.Card.PAY_DOUBLE:
			p.rent_card = GameEnums.RentCard.DOUBLE

		GameEnums.Card.PAY_HALF:
			p.rent_card = GameEnums.RentCard.HALF

	return END

static func _ask_target(state: GameState, kind: int, targets: Array) -> StringName:
	if targets.is_empty():
		return END
	state.pending = {"kind": kind, "targets": targets}
	return TARGET
