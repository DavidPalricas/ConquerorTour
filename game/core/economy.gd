## Prices, rents and values. Pure functions over the state and the config.
class_name Economy

static func is_ownable(tile: Dictionary) -> bool:
	return tile.type == GameEnums.TileType.CITY or tile.type == GameEnums.TileType.CHURCH

static func land_price(cfg: GameConfig, tile: Dictionary) -> int:
	if tile.type == GameEnums.TileType.CHURCH:
		return cfg.church_price
	if tile.type == GameEnums.TileType.CITY:
		return cfg.land_prices[tile.empire]
	return 0

## Base cost of one level of a city (level 0 is the land itself).
static func level_cost(cfg: GameConfig, tile: Dictionary, level: int) -> int:
	return roundi(land_price(cfg, tile) * cfg.level_cost_factors[level])

## Invested value: land plus buildings at table prices. Never depends on what the owner paid
## in a purchase, so prices do not spiral when a property changes hands.
static func invested_value(cfg: GameConfig, tile: Dictionary, level: int) -> int:
	if tile.type == GameEnums.TileType.CHURCH:
		return cfg.church_price
	var total := 0
	for l in level + 1:
		total += level_cost(cfg, tile, l)
	return total

static func tile_invested(state: GameState, cfg: GameConfig, index: int) -> int:
	var ts: Dictionary = state.tiles[index]
	if ts.owner < 0:
		return 0
	return invested_value(cfg, state.board[index], ts.level)

## What the owner gets for selling the property to Lucifer to cover a payment.
static func sale_value(state: GameState, cfg: GameConfig, index: int) -> int:
	return roundi(tile_invested(state, cfg, index) * cfg.sell_value_multiplier)

static func total_invested(state: GameState, cfg: GameConfig, pid: int) -> int:
	var total := 0
	for index: int in state.owned_by(pid):
		total += tile_invested(state, cfg, index)
	return total

## Net worth: money plus the invested value of every property, churches included.
static func net_worth(state: GameState, cfg: GameConfig, pid: int) -> int:
	return int(state.players[pid].money) + total_invested(state, cfg, pid)

static func tax(state: GameState, cfg: GameConfig, pid: int) -> int:
	return roundi(total_invested(state, cfg, pid) * cfg.tax_rate)

static func count_owned(state: GameState, pid: int, type: int, empire: int = -1) -> int:
	var count := 0
	for index: int in state.owned_by(pid):
		var tile: Dictionary = state.board[index]
		if tile.type == type and (empire < 0 or tile.empire == empire):
			count += 1
	return count

## Rent owed by whoever lands on the owned tile [param index].
static func rent(state: GameState, cfg: GameConfig, index: int) -> int:
	var tile: Dictionary = state.board[index]
	var ts: Dictionary = state.tiles[index]
	if ts.owner < 0:
		return 0

	if tile.type == GameEnums.TileType.CHURCH:
		var churches: int = count_owned(state, ts.owner, GameEnums.TileType.CHURCH)
		return roundi(cfg.church_base_rent * pow(cfg.church_rent_multiplier, churches - 1))

	var value: float = land_price(cfg, tile) * cfg.rent_factors[ts.level]
	if count_owned(state, ts.owner, GameEnums.TileType.CITY, tile.empire) >= cfg.group_rent_min_cities:
		value *= 1.0 + cfg.group_rent_bonus
	return roundi(value)

static func offer_min(state: GameState, cfg: GameConfig, index: int) -> int:
	return ceili(tile_invested(state, cfg, index) * cfg.offer_min_multiplier)

## Price at which the purchase is forced.
static func offer_max(state: GameState, cfg: GameConfig, index: int) -> int:
	return roundi(tile_invested(state, cfg, index) * cfg.offer_forced_multiplier)

## Churches, castles and shielded properties can never be bought from their owner.
static func can_receive_offer(state: GameState, index: int) -> bool:
	var tile: Dictionary = state.board[index]
	var ts: Dictionary = state.tiles[index]
	return ts.owner >= 0 and tile.type == GameEnums.TileType.CITY \
			and ts.level < GameEnums.Level.CASTLE and not ts.shield

## What the player standing on tile [param index] can buy there, as { level, price } entries
## with the total price up to that level, cheapest first. Only what [param money] can pay.
## A free city offers land, shack and house at once; the castle only shows up on a city
## that already has a house.
static func buy_options(state: GameState, cfg: GameConfig, index: int, money: int) -> Array:
	var tile: Dictionary = state.board[index]
	var ts: Dictionary = state.tiles[index]
	var first: int = GameEnums.Level.LAND if ts.owner < 0 else int(ts.level) + 1
	var last: int = GameEnums.Level.LAND

	if tile.type == GameEnums.TileType.CITY:
		last = GameEnums.Level.CASTLE if ts.level == GameEnums.Level.HOUSE and ts.owner >= 0 \
				else GameEnums.Level.HOUSE

	var options: Array = []
	var total := 0
	for level in range(first, last + 1):
		total += level_cost(cfg, tile, level)
		if total <= money:
			options.append({"level": level, "price": total})
	return options

## A castle is the only property that cannot be destroyed or shielded.
static func is_castle(state: GameState, index: int) -> bool:
	return state.board[index].type == GameEnums.TileType.CITY \
			and state.tiles[index].level == GameEnums.Level.CASTLE
