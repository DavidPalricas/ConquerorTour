## Headless tests of the rules and of the match engine. No interface, no network.
##
## Run from the project folder:
##   godot --headless res://tests/test_runner.tscn
## The exit code is the number of failed checks.
extends Node

const ENGINE_SCENE := preload("res://engine/match_engine.tscn")
const BOARD_SCENE := preload("res://board/board.tscn")

## Stands in for the network: remembers what the session sends to each peer.
class FakeTransport extends Transport:
	var sent: Array = []

	func host(_code: String) -> void:
		pass

	func join(_code: String) -> void:
		pass

	func send(peer_id: String, message: Dictionary) -> void:
		sent.append({"to": peer_id, "m": message})

	func broadcast(message: Dictionary) -> void:
		sent.append({"to": "*", "m": message})

	func close() -> void:
		pass

	## Types of the messages sent to [param peer_id], in order.
	func types_for(peer_id: String) -> Array:
		var types: Array = []
		for entry: Dictionary in sent:
			if entry.to == peer_id:
				types.append(entry.m.t)
		return types

var _board_def: Array = []
var _checks: int = 0
var _failures: int = 0
var _current: String = ""

func _ready() -> void:
	var board: Board = BOARD_SCENE.instantiate()
	_board_def = board.to_definition()
	board.free()

	for method: Dictionary in get_method_list():
		var method_name: String = method.name
		if method_name.begins_with("test_"):
			_current = method_name
			call(method_name)

	print("\n%d checks, %d failed" % [_checks, _failures])
	get_tree().quit(_failures)

# ====== Board ======

func test_board_composition() -> void:
	var by_type: Dictionary = {}
	var by_empire: Dictionary = {}
	for tile: Dictionary in _board_def:
		by_type[tile.type] = by_type.get(tile.type, 0) + 1
		if tile.type == GameEnums.TileType.CITY:
			by_empire[tile.empire] = by_empire.get(tile.empire, 0) + 1

	_eq(_board_def.size(), 32, "32 tiles")
	_eq(by_type[GameEnums.TileType.CITY], 22, "22 cities")
	_eq(by_type[GameEnums.TileType.CHURCH], 4, "4 churches")
	_eq(by_type[GameEnums.TileType.ROULETTE], 2, "2 roulettes")
	_eq(by_empire.size(), 8, "8 empires")

	var sizes: Array = by_empire.values()
	_eq(sizes.count(3), 6, "6 empires with 3 cities")
	_eq(sizes.count(2), 2, "2 empires with 2 cities")

	for corner: int in [0, 8, 16, 24]:
		_ok(not Economy.is_ownable(_board_def[corner]), "corner %d is special" % corner)

# ====== Turn, movement, buying ======

func test_roll_moves_and_offers_purchase() -> void:
	var e := _engine(2)
	# Goa: a Portuguese city reached from here without passing the Start.
	var city: int = _tile("CITY_GOA")
	e.state.players[0].pos = city - 3
	e.random.forced_rolls = [[1, 2]]

	_ok(not e.submit_intent(1, Intent.make(Intent.ROLL)), "only the acting player rolls")
	_ok(e.submit_intent(0, Intent.make(Intent.ROLL)), "roll accepted")
	_eq(e.state.players[0].pos, city, "moved by the dice total")
	_eq(e.state.phase, GameEnums.Phase.BUY, "buy phase on a free city")

	_ok(not e.submit_intent(0, Intent.buy(GameEnums.Level.CASTLE)), "castle is not offered on a free city")
	_ok(e.submit_intent(0, Intent.buy(GameEnums.Level.LAND)), "buy accepted")
	_eq(e.state.tiles[city].owner, 0, "city owned")
	_eq(e.state.players[0].money, e.config.starting_money - e.config.land_prices[0], "price paid")
	_eq(e.state.turn, 1, "turn passes")
	_eq(e.state.phase, GameEnums.Phase.ROLL, "next player rolls")
	e.free()

func test_salary_when_passing_start() -> void:
	var e := _engine(2)
	e.state.players[0].pos = 31
	e.random.forced_rolls = [[1, 2]]
	e.submit_intent(0, Intent.make(Intent.ROLL))
	_eq(e.state.players[0].pos, 2, "wrapped around the board")
	_eq(e.state.players[0].money, e.config.starting_money + e.config.salary, "salary received")
	e.free()

func test_buy_popup_offers_every_level_at_once() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	_land(e, 0, lisbon)

	_eq(_levels(e), [0, 1, 2], "land, shack and house on a free city")
	_eq(_prices(e), [100_000, 150_000, 250_000], "prices are totals")

	e.submit_intent(0, Intent.buy(GameEnums.Level.HOUSE))
	_eq(e.state.tiles[lisbon].owner, 0, "owned")
	_eq(e.state.tiles[lisbon].level, GameEnums.Level.HOUSE, "built straight up to the house")
	_eq(e.state.players[0].money, e.config.starting_money - 250_000, "total price paid")
	e.free()

func test_castle_only_after_the_house() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	_own(e, lisbon, 0, GameEnums.Level.LAND)
	_land(e, 0, lisbon)
	_eq(_levels(e), [1, 2], "no castle before the house")
	e.submit_intent(0, Intent.buy(GameEnums.Level.HOUSE))

	_land(e, 1, _tile("TILE_START"))
	_land(e, 0, lisbon)
	_eq(_levels(e), [3], "castle offered on a house")
	e.submit_intent(0, Intent.buy(GameEnums.Level.CASTLE))
	_eq(e.state.tiles[lisbon].level, GameEnums.Level.CASTLE, "castle built")

	_land(e, 1, _tile("TILE_START"))
	_land(e, 0, lisbon)
	_eq(e.state.turn, 1, "nothing to do on a castle: turn ends")
	e.free()

func test_only_affordable_levels_are_offered() -> void:
	var e := _engine(2)
	e.state.players[0].money = 160_000
	_land(e, 0, _tile("CITY_LISBON"))
	_eq(_levels(e), [0, 1], "house is too expensive")
	e.free()

func test_double_gives_an_extra_turn() -> void:
	var e := _engine(2)
	e.random.forced_rolls = [[2, 2], [1, 2]]

	e.submit_intent(0, Intent.make(Intent.ROLL))
	e.submit_intent(0, Intent.make(Intent.SKIP))
	_eq(e.state.turn, 0, "same player again after a double")
	_eq(e.state.phase, GameEnums.Phase.ROLL, "rolls again")

	e.submit_intent(0, Intent.make(Intent.ROLL))
	e.submit_intent(0, Intent.make(Intent.SKIP))
	_eq(e.state.turn, 1, "no extra turn without a double")
	e.free()

func test_double_into_hell_gives_no_extra_turn() -> void:
	var e := _engine(2)
	e.state.players[0].pos = _tile("TILE_HELL") - 4
	e.random.forced_rolls = [[2, 2]]
	e.submit_intent(0, Intent.make(Intent.ROLL))
	_eq(e.state.players[0].hell, 3, "in Hell")
	_eq(e.state.turn, 1, "the turn passes")
	e.free()

# ====== Rent ======

func test_rent_and_group_bonus() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	var porto: int = _tile("CITY_PORTO")
	var base: int = roundi(e.config.land_prices[0] * e.config.rent_factors[0])

	_own(e, lisbon, 1)
	_eq(Economy.rent(e.state, e.config, lisbon), base, "base rent with one city")

	_own(e, porto, 1)
	_eq(Economy.rent(e.state, e.config, lisbon), roundi(base * 1.25), "+25% with two cities")

	_own(e, _tile("CITY_GOA"), 1)
	_eq(Economy.rent(e.state, e.config, lisbon), roundi(base * 1.25), "bonus does not stack")

	_land(e, 0, lisbon)
	_eq(e.state.players[0].money, e.config.starting_money - roundi(base * 1.25), "visitor paid")
	_eq(e.state.players[1].money, e.config.starting_money + roundi(base * 1.25), "owner received")
	e.free()

func test_church_rent_compounds() -> void:
	var e := _engine(2)
	var churches: Array = _tiles_of_type(GameEnums.TileType.CHURCH)

	_own(e, churches[0], 1)
	_eq(Economy.rent(e.state, e.config, churches[0]), 50_000, "one church: 50k")
	_own(e, churches[1], 1)
	_eq(Economy.rent(e.state, e.config, churches[0]), 75_000, "two churches: 75k each")
	_own(e, churches[2], 1)
	_eq(Economy.rent(e.state, e.config, churches[0]), 112_500, "three churches: 112.5k each")

	_land(e, 0, churches[0])
	_eq(e.state.turn, 1, "no purchase offer on a church")
	e.free()

# ====== Purchase negotiation ======

func test_offer_accepted() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	_own(e, lisbon, 1, GameEnums.Level.SHACK)
	var invested: int = Economy.tile_invested(e.state, e.config, lisbon)
	_eq(invested, 150_000, "invested = land + shack")

	_land(e, 0, lisbon)
	_eq(e.state.phase, GameEnums.Phase.OFFER, "offer phase after paying rent")
	_eq(e.state.pending.min, 225_000, "minimum is 1.5x")
	_eq(e.state.pending.max, 450_000, "forced price is 3x")
	_ok(not e.submit_intent(0, Intent.offer(100_000)), "offer below 1.5x rejected")
	_ok(not e.submit_intent(0, Intent.offer(500_000)), "offer above 3x rejected")

	var buyer_money: int = e.state.players[0].money
	var owner_money: int = e.state.players[1].money
	_ok(e.submit_intent(0, Intent.offer(300_000)), "valid offer")
	_eq(e.state.phase, GameEnums.Phase.OFFER_RESPONSE, "waiting for the owner")
	_eq(e.state.actor, 1, "the owner acts")

	_ok(e.submit_intent(1, Intent.make(Intent.ACCEPT)), "accepted")
	_eq(e.state.tiles[lisbon].owner, 0, "ownership moved")
	_eq(e.state.tiles[lisbon].level, GameEnums.Level.SHACK, "buildings kept")
	_eq(e.state.players[0].money, buyer_money - 300_000, "buyer paid")
	_eq(e.state.players[1].money, owner_money + 300_000, "owner got the full price")
	_eq(Economy.tile_invested(e.state, e.config, lisbon), invested, "invested value ignores the price paid")
	e.free()

func test_offer_refused_forced_and_timeout() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	_own(e, lisbon, 1)

	_land(e, 0, lisbon)
	e.submit_intent(0, Intent.offer(e.state.pending.min))
	e.submit_intent(1, Intent.make(Intent.REFUSE))
	_eq(e.state.tiles[lisbon].owner, 1, "refused: owner keeps it")
	_eq(e.state.turn, 1, "turn passes after a refusal")

	_land(e, 1, _tile("TILE_START"))
	_land(e, 0, lisbon)
	e.submit_intent(0, Intent.offer(e.state.pending.min))
	e.current_state.execute(e.config.offer_timeout + 0.1)
	_eq(e.state.tiles[lisbon].owner, 1, "timeout counts as a refusal")
	_eq(e.state.phase, GameEnums.Phase.ROLL, "turn continues after the timeout")

	_land(e, 1, _tile("TILE_START"))
	_land(e, 0, lisbon)
	e.submit_intent(0, Intent.offer(e.state.pending.max))
	_eq(e.state.tiles[lisbon].owner, 0, "3x is forced without asking")
	e.free()

func test_castles_and_shields_block_purchases() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	_own(e, lisbon, 1, GameEnums.Level.CASTLE)
	_land(e, 0, lisbon)
	_eq(e.state.turn, 1, "no offer on a castle")

	_land(e, 1, _tile("TILE_START"))
	e.state.tiles[lisbon].level = GameEnums.Level.LAND
	e.state.tiles[lisbon].shield = true
	var before: int = e.state.players[0].money
	_land(e, 0, lisbon)
	_ok(e.state.players[0].money < before, "rent is still paid")
	_eq(e.state.turn, 1, "no offer on a shielded property, not even forced")
	_ok(e.state.tiles[lisbon].shield, "the shield is not spent by a visit")
	e.free()

func test_bot_owner_accepts_from_2x() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	_own(e, lisbon, 1)
	e.set_bot(1, true)

	_land(e, 0, lisbon)
	e.submit_intent(0, Intent.offer(199_000))
	e.current_state.execute(e.config.bot_delay + 0.1)
	_eq(e.state.tiles[lisbon].owner, 1, "bot refuses below 2x")

	e.state.turn = 0
	e.change_state(MatchEngine.TO_ROLL)
	_land(e, 0, lisbon)
	e.submit_intent(0, Intent.offer(200_000))
	e.current_state.execute(e.config.bot_delay + 0.1)
	_eq(e.state.tiles[lisbon].owner, 0, "bot accepts at 2x")
	e.free()

func test_bot_buys_when_it_can() -> void:
	var e := _engine(2)
	var city: int = _tile("CITY_GOA")
	e.set_bot(0, true)
	e.state.players[0].pos = city - 3
	e.random.forced_rolls = [[1, 2]]

	e.current_state.execute(e.config.bot_delay + 0.1)
	_eq(e.state.phase, GameEnums.Phase.BUY, "bot rolled")
	e.current_state.execute(e.config.bot_delay + 0.1)
	_eq(e.state.tiles[city].owner, 0, "bot bought the city")
	_eq(e.state.tiles[city].level, GameEnums.Level.HOUSE, "and built as far as it could")
	e.free()

# ====== Tax, loans, bankruptcy ======

func test_tax_is_a_share_of_invested_value() -> void:
	var e := _engine(2)
	_own(e, _tile("CITY_LISBON"), 0, GameEnums.Level.SHACK)
	_own(e, _tiles_of_type(GameEnums.TileType.CHURCH)[0], 0)
	var invested: int = 150_000 + e.config.church_price

	_eq(Economy.total_invested(e.state, e.config, 0), invested, "land, buildings and churches")
	_eq(Economy.net_worth(e.state, e.config, 0), e.config.starting_money + invested, "net worth")

	_land(e, 0, _tile("TILE_TAX"))
	_eq(e.state.players[0].money, e.config.starting_money - roundi(invested * 0.10), "10% paid to Lucifer")
	e.free()

func test_loan_and_garnishment() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	_own(e, lisbon, 1, GameEnums.Level.CASTLE)
	_own(e, _tile("CITY_PARIS"), 0)
	var rent: int = Economy.rent(e.state, e.config, lisbon)
	e.state.players[0].money = rent - 30_000

	_land(e, 0, lisbon)
	_eq(e.state.phase, GameEnums.Phase.SELL, "short of money with a property: may sell first")
	_ok(e.submit_intent(0, Intent.make(Intent.SETTLE)), "settles without selling")
	_eq(e.state.tiles[_tile("CITY_PARIS")].owner, 0, "property kept")
	_eq(e.state.players[0].debt, 30_000, "loan is exactly what was missing")
	_eq(e.state.players[0].money, 0, "no change kept")
	_ok(not e.state.players[0].bankrupt, "still in the match")
	_eq(e.state.players[1].money, e.config.starting_money + rent, "owner paid in full")

	Bank.receive(e.state, 0, 20_000)
	_eq(e.state.players[0].debt, 10_000, "income goes to Lucifer first")
	_eq(e.state.players[0].money, 0, "nothing kept while in debt")

	Bank.receive(e.state, 0, 25_000)
	_eq(e.state.players[0].debt, 0, "debt cleared")
	_eq(e.state.players[0].money, 15_000, "excess kept")
	e.free()

func test_bankruptcy_above_loan_limit() -> void:
	var e := _engine(3)
	var lisbon: int = _tile("CITY_LISBON")
	var paris: int = _tile("CITY_PARIS")
	_own(e, lisbon, 1, GameEnums.Level.CASTLE)
	_own(e, paris, 0)
	e.state.players[0].money = 0
	e.state.tiles[paris].owner = -1

	_land(e, 0, lisbon)
	_ok(e.state.players[0].bankrupt, "missing more than 2x the net worth: bankrupt")
	_eq(e.state.turn, 1, "match goes on with the others")
	e.free()

func test_second_loan_means_bankruptcy() -> void:
	var e := _engine(3)
	var lisbon: int = _tile("CITY_LISBON")
	var paris: int = _tile("CITY_PARIS")
	_own(e, lisbon, 1)
	_own(e, paris, 0, GameEnums.Level.CASTLE)
	e.state.players[0].money = 0
	e.state.players[0].debt = 10_000

	_land(e, 0, lisbon)
	_ok(e.submit_intent(0, Intent.make(Intent.SETTLE)), "gives up without selling")
	_ok(e.state.players[0].bankrupt, "in debt and unable to pay: bankrupt")
	_eq(e.state.players[0].debt, 0, "the debt disappears")
	_eq(e.state.tiles[paris].owner, -1, "properties become free")
	_eq(e.state.tiles[paris].level, 0, "buildings are gone")
	e.free()

func test_selling_covers_a_rent() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	var paris: int = _tile("CITY_PARIS")
	var lyon: int = _tile("CITY_LYON")
	_own(e, lisbon, 1, GameEnums.Level.CASTLE)
	_own(e, paris, 0, GameEnums.Level.SHACK)
	_own(e, lyon, 0)
	var rent: int = Economy.rent(e.state, e.config, lisbon)
	var value: int = Economy.sale_value(e.state, e.config, paris)
	e.state.players[0].money = rent - 30_000

	_land(e, 0, lisbon)
	_eq(e.state.phase, GameEnums.Phase.SELL, "waits for the payer to sell")
	_eq(e.state.actor, 0, "the payer acts")
	_eq(e.state.pending.due, rent, "the payment waits")
	_eq(e.state.players[1].money, e.config.starting_money, "nothing paid yet")
	_ok(not e.submit_intent(0, Intent.sell(lisbon)), "cannot sell what is not theirs")

	_ok(e.submit_intent(0, Intent.sell(paris)), "sells a property")
	_eq(e.state.tiles[paris].owner, -1, "sold property is free")
	_eq(e.state.tiles[paris].level, 0, "its buildings are gone")
	_eq(e.state.players[0].money, rent - 30_000 + value, "sale value received")
	_ok(not e.submit_intent(0, Intent.sell(lyon)), "no more sales once the payment is covered")

	_ok(e.submit_intent(0, Intent.make(Intent.SETTLE)), "pays")
	_eq(e.state.players[0].debt, 0, "no loan needed")
	_eq(e.state.players[0].money, value - 30_000, "rent paid from the sale")
	_eq(e.state.players[1].money, e.config.starting_money + rent, "owner paid in full")
	_eq(e.state.tiles[lyon].owner, 0, "the other property is kept")
	e.free()

func test_selling_saves_a_player_in_debt() -> void:
	var e := _engine(3)
	var lisbon: int = _tile("CITY_LISBON")
	var paris: int = _tile("CITY_PARIS")
	_own(e, lisbon, 1)
	_own(e, paris, 0, GameEnums.Level.CASTLE)
	var rent: int = Economy.rent(e.state, e.config, lisbon)
	var value: int = Economy.sale_value(e.state, e.config, paris)
	e.state.players[0].money = 0
	e.state.players[0].debt = 10_000

	_land(e, 0, lisbon)
	_ok(e.submit_intent(0, Intent.sell(paris)), "sells the castle")
	_eq(e.state.players[0].debt, 0, "the sale pays the debt first")
	_eq(e.state.players[0].money, value - 10_000, "the rest is kept")
	_ok(e.submit_intent(0, Intent.make(Intent.SETTLE)), "pays")
	_ok(not e.state.players[0].bankrupt, "still in the match")
	_eq(e.state.players[0].money, value - 10_000 - rent, "rent paid")
	e.free()

func test_gift_waits_for_a_giver_who_is_short() -> void:
	var e := _engine(3)
	var paris: int = _tile("CITY_PARIS")
	var gift: int = e.config.lucifer_gift_amount
	_own(e, paris, 1)
	e.state.players[1].money = 0

	_draw(e, 0, GameEnums.Card.LUCIFER_GIFT)
	_eq(e.state.phase, GameEnums.Phase.SELL, "the giver may sell")
	_eq(e.state.actor, 1, "the giver acts, not the player of the turn")
	_ok(e.submit_intent(1, Intent.make(Intent.SETTLE)), "borrows instead")
	_eq(e.state.players[1].debt, gift, "loan for the gift")
	_eq(e.state.players[0].money, e.config.starting_money + 2 * gift, "both gifts received")
	_eq(e.state.players[2].money, e.config.starting_money - gift, "the next giver paid too")
	_eq(e.state.turn, 1, "the turn went on")
	e.free()

func test_bot_sells_when_lucifer_does_not_lend() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	var paris: int = _tile("CITY_PARIS")
	_own(e, lisbon, 1)
	_own(e, paris, 0, GameEnums.Level.CASTLE)
	e.state.players[0].money = 0
	e.state.players[0].debt = 10_000

	_land(e, 0, lisbon)
	_eq(SimpleBot.decide(e.state, e.config), Intent.sell(paris), "sells when it cannot borrow")
	e.state.players[0].debt = 0
	_eq(SimpleBot.decide(e.state, e.config), Intent.make(Intent.SETTLE), "borrows when it can")
	e.free()

func test_missing_money_is_reported() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	e.state.players[0].money = 10
	_land(e, 0, lisbon)
	_eq(e.state.phase, GameEnums.Phase.ROLL, "nothing affordable: the turn ends")
	_eq(e.state.turn, 1, "next player")
	e.free()

func test_bankrupt_money_goes_to_nobody() -> void:
	var e := _engine(3)
	var lisbon: int = _tile("CITY_LISBON")
	_own(e, lisbon, 1, GameEnums.Level.CASTLE)
	e.state.players[0].money = 5_000
	e.state.players[0].debt = 10_000

	_land(e, 0, lisbon)
	_ok(e.state.players[0].bankrupt, "bankrupt at once")
	_eq(e.state.players[0].money, 0, "money is gone")
	_eq(e.state.players[1].money, e.config.starting_money, "the creditor gets nothing")
	e.free()

# ====== Hell and the Pope's Call ======

func test_hell_holds_for_three_turns() -> void:
	var e := _engine(2)
	_land(e, 0, _tile("TILE_HELL"))
	_eq(e.state.players[0].hell, 3, "three turns in Hell")

	# The other player plays four turns in a row: the prisoner misses three.
	for i in 4:
		_eq(e.state.turn, 1, "turn %d belongs to the other player" % (i + 1))
		_land(e, 1, _tile("TILE_START"))

	_eq(e.state.turn, 0, "free on the fourth turn")
	_eq(e.state.players[0].hell, 0, "counter is back to zero")
	e.free()

func test_rent_is_received_in_hell() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	_own(e, lisbon, 0)
	_land(e, 0, _tile("TILE_HELL"))

	var before: int = e.state.players[0].money
	_land(e, 1, lisbon)
	_ok(e.state.players[0].money > before, "prisoner still collects rent")
	e.free()

func test_pope_call_targets() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	var paris: int = _tile("CITY_PARIS")
	_own(e, lisbon, 1)

	_land(e, 0, _tile("TILE_POPE_CALL"))
	_eq(e.state.phase, GameEnums.Phase.TARGET, "has to pick a tile")
	_ok(not e.state.pending.targets.has(lisbon), "cannot go to someone else's property")
	_ok(e.state.pending.targets.has(paris), "can go to a free property")
	_ok(not e.submit_intent(0, Intent.target(lisbon)), "invalid target rejected")

	e.submit_intent(0, Intent.target(paris))
	_eq(e.state.players[0].pos, paris, "travelled")
	_eq(e.state.phase, GameEnums.Phase.BUY, "can buy on arrival")
	_eq(e.state.players[0].money, e.config.starting_money, "no salary without passing the Start")
	e.free()

func test_pope_call_pays_salary_when_passing_start() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	_land(e, 0, _tile("TILE_POPE_CALL"))
	e.submit_intent(0, Intent.target(lisbon))
	_eq(e.state.players[0].pos, lisbon, "travelled past the Start")
	_eq(e.state.players[0].money, e.config.starting_money + e.config.salary, "salary received on the way")
	e.free()

# ====== Lucifer Roulette ======

func test_card_lucifer_debt() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	_own(e, lisbon, 0, GameEnums.Level.CASTLE)
	_draw(e, 0, GameEnums.Card.LUCIFER_DEBT)
	_ok(e.state.players[0].debt_card, "debt waits for the next own property")

	var rent: int = Economy.rent(e.state, e.config, lisbon)
	var total: int = e.state.players[0].money + e.state.players[1].money
	_land(e, 1, _tile("TILE_START"))
	_land(e, 0, lisbon)
	_eq(e.state.players[0].money + e.state.players[1].money, total - rent, "rent paid once, to nobody")
	_ok(not e.state.players[0].debt_card, "paid a single time")
	e.free()

func test_card_lucifer_gift() -> void:
	var e := _engine(3)
	_draw(e, 0, GameEnums.Card.LUCIFER_GIFT)
	var gift: int = e.config.lucifer_gift_amount
	_eq(e.state.players[0].money, e.config.starting_money + 2 * gift, "everyone gives")
	_eq(e.state.players[1].money, e.config.starting_money - gift, "giver pays")
	e.free()

func test_card_kings_invasion() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	var porto: int = _tile("CITY_PORTO")
	var church: int = _tiles_of_type(GameEnums.TileType.CHURCH)[0]
	_own(e, lisbon, 1, GameEnums.Level.CASTLE)
	_own(e, porto, 1, GameEnums.Level.HOUSE)
	_own(e, church, 1)

	_draw(e, 0, GameEnums.Card.KINGS_INVASION)
	_ok(not e.state.pending.targets.has(lisbon), "castles cannot be invaded")
	_ok(e.state.pending.targets.has(church), "churches can")

	e.submit_intent(0, Intent.target(porto))
	_eq(e.state.tiles[porto].owner, -1, "land is free again")
	_eq(e.state.tiles[porto].level, 0, "destroyed entirely")
	e.free()

func test_card_shield_blocks_one_invasion() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	_own(e, lisbon, 0, GameEnums.Level.HOUSE)

	_draw(e, 0, GameEnums.Card.SHIELD)
	e.submit_intent(0, Intent.target(lisbon))
	_ok(e.state.tiles[lisbon].shield, "shield placed")

	_draw(e, 1, GameEnums.Card.KINGS_INVASION)
	e.submit_intent(1, Intent.target(lisbon))
	_eq(e.state.tiles[lisbon].owner, 0, "property survives")
	_ok(not e.state.tiles[lisbon].shield, "shield spent")
	e.free()

func test_card_pay_double_and_half() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	_own(e, lisbon, 1, GameEnums.Level.CASTLE)
	var rent: int = Economy.rent(e.state, e.config, lisbon)

	_draw(e, 0, GameEnums.Card.PAY_DOUBLE)
	_land(e, 1, _tile("TILE_START"))
	var before: int = e.state.players[0].money
	_land(e, 0, lisbon)
	_eq(e.state.players[0].money, before - 2 * rent, "next rent is doubled")

	_land(e, 1, _tile("TILE_START"))
	_draw(e, 0, GameEnums.Card.PAY_HALF)
	_land(e, 1, _tile("TILE_START"))
	before = e.state.players[0].money
	_land(e, 0, lisbon)
	_eq(e.state.players[0].money, before - rent / 2, "next rent is halved")
	e.free()

# ====== Victory ======

func test_win_with_four_churches() -> void:
	var e := _engine(2)
	var churches: Array = _tiles_of_type(GameEnums.TileType.CHURCH)
	for i in 3:
		_own(e, churches[i], 0)
	_land(e, 0, churches[3])
	e.submit_intent(0, Intent.buy(GameEnums.Level.LAND))
	_eq(e.state.winner, 0, "winner")
	_eq(e.state.win_reason, GameEnums.WinReason.CHURCHES, "by churches")
	_eq(e.state.phase, GameEnums.Phase.GAME_OVER, "game over")
	_ok(not e.submit_intent(1, Intent.make(Intent.ROLL)), "nobody acts after the end")
	e.free()

func test_win_with_three_empires() -> void:
	var e := _engine(2)
	for key: String in ["CITY_AMSTERDAM", "CITY_ROTTERDAM", "CITY_KYOTO", "CITY_EDO", "CITY_PARIS", "CITY_LYON"]:
		_own(e, _tile(key), 0)
	_eq(Victory.complete_empires(e.state, 0), 2, "two complete empires")
	_eq(Victory.check(e.state, e.config).winner, -1, "not enough yet")

	_own(e, _tile("CITY_MARSEILLE"), 0)
	var result: Dictionary = Victory.check(e.state, e.config)
	_eq(result.winner, 0, "three empires win")
	_eq(result.reason, GameEnums.WinReason.MONOPOLIES, "by monopolies")
	e.free()

func test_win_with_a_line() -> void:
	var e := _engine(2)
	for i in range(1, 8):
		if Economy.is_ownable(_board_def[i]):
			_own(e, i, 1)
	var result: Dictionary = Victory.check(e.state, e.config)
	_eq(result.winner, 1, "a full side wins")
	_eq(result.reason, GameEnums.WinReason.LINE, "by line")

	e.state.tiles[_tiles_of_type(GameEnums.TileType.CHURCH)[0]].owner = -1
	_eq(Victory.check(e.state, e.config).winner, -1, "the church of the line counts")
	e.free()

func test_last_player_standing() -> void:
	var e := _engine(2)
	var lisbon: int = _tile("CITY_LISBON")
	_own(e, lisbon, 1, GameEnums.Level.CASTLE)
	e.state.players[0].money = 0
	_land(e, 0, lisbon)
	_ok(e.state.players[0].bankrupt, "bankrupt")
	_eq(e.state.winner, 1, "the other player wins")
	_eq(e.state.win_reason, GameEnums.WinReason.LAST_STANDING, "last standing")
	e.free()

# ====== Serialisation ======

func test_state_survives_json() -> void:
	var e := _engine(3)
	_own(e, _tile("CITY_LISBON"), 1, GameEnums.Level.HOUSE)
	_land(e, 0, _tile("CITY_LISBON"))

	var snapshot: Dictionary = e.state.to_dict()
	var text: String = JSON.stringify(snapshot)
	var restored: GameState = GameState.from_dict(JSON.parse_string(text))

	_eq(JSON.stringify(restored.to_dict()), text, "identical after a JSON round trip")
	_eq(typeof(restored.players[0].money), TYPE_INT, "numbers come back as ints")
	e.free()

# ====== Room (host side, with a fake network) ======

func test_leaving_the_lobby_frees_the_seat() -> void:
	var net := _host_room()
	_hello("peer-a", "Ana", "device-a")
	_eq(_lobby_names(), ["Host", "Ana"], "the client is in the lobby")

	Session._on_message("peer-a", {"t": "bye"})
	_eq(_lobby_names(), ["Host"], "saying goodbye removes the player at once")

	_hello("peer-a2", "Ana", "device-a")
	_eq(_lobby_names(), ["Host", "Ana"], "back with the same name, not a numbered one")
	_ok(net.types_for("peer-a2").has("welcome"), "welcomed")
	Session.leave()

func test_same_device_keeps_its_seat() -> void:
	var net := _host_room()
	_hello("peer-a", "Ana", "device-a")
	Session._on_message("peer-a", {"t": "ready", "v": true})

	_hello("peer-b", "Ana", "device-a")
	_eq(_lobby_names(), ["Host", "Ana"], "another tab of the same device is the same player")
	_eq(net.types_for("peer-a").back(), "reject", "the old tab is sent away")
	_ok(not Session.lobby[1].ready, "has to say it is ready again")

	# The old tab going away later must not take the seat with it.
	Session._on_peer_disconnected("peer-a")
	_eq(_lobby_names(), ["Host", "Ana"], "the seat stays with the new tab")

	_hello("peer-c", "Ana", "device-c")
	_eq(_lobby_names(), ["Host", "Ana", "Ana 2"], "someone else with the same name is another player")
	Session.leave()

func test_player_returns_to_a_running_match() -> void:
	var net := _host_room()
	_hello("peer-a", "Ana", "device-a")
	Session._on_message("peer-a", {"t": "ready", "v": true})
	Session.set_ready(true)
	Session.start_match()
	_ok(Session.in_match, "match started")

	Session._on_message("peer-a", {"t": "bye"})
	_ok(Session._engine.state.players[1].bot, "a bot plays for whoever left")

	_hello("peer-a2", "Someone else", "device-a")
	_ok(not Session._engine.state.players[1].bot, "the device gets its player back, whatever the name")
	_eq(net.types_for("peer-a2").slice(0, 2), ["start", "state"], "and the current state")

	_hello("peer-x", "Stranger", "device-x")
	_eq(net.types_for("peer-x"), ["reject"], "nobody new joins a running match")
	Session.leave()

func test_host_leaving_tells_everyone() -> void:
	var net := _host_room()
	_hello("peer-a", "Ana", "device-a")
	Session.leave()
	_eq(net.sent.back().m.t, "bye", "the last thing the host says")
	_eq(net.sent.back().to, "*", "to every client")

# ====== Helpers ======

## Opens a room as the host, on a network that only records what is sent.
func _host_room() -> FakeTransport:
	Session.create_room("Host", 0)
	var net := FakeTransport.new()
	Session._transport = net
	return net

func _hello(peer_id: String, player_name: String, device: String) -> void:
	Session._on_message(peer_id, {"t": "hello", "name": player_name, "color": 1, "dev": device})

func _lobby_names() -> Array:
	return Session.lobby.map(func(entry: Dictionary) -> String: return entry.name)

func _engine(player_count: int) -> MatchEngine:
	var engine: MatchEngine = ENGINE_SCENE.instantiate()
	add_child(engine)
	# The tests drive the bot and the timers by hand.
	engine.set_process(false)

	var infos: Array = []
	for i in player_count:
		infos.append({"name": "P%d" % i, "color": i})
	engine.start_match(_board_def, infos)
	return engine

func _tile(key: String) -> int:
	for i in _board_def.size():
		if _board_def[i].key == key:
			return i
	_failures += 1
	printerr("Tile not found: " + key)
	return 0

func _tiles_of_type(type: int) -> Array:
	var found: Array = []
	for i in _board_def.size():
		if _board_def[i].type == type:
			found.append(i)
	return found

func _own(engine: MatchEngine, index: int, pid: int, level: int = GameEnums.Level.LAND) -> void:
	engine.state.tiles[index].owner = pid
	engine.state.tiles[index].level = level

## Makes [param pid] roll a 3 that ends on [param index]. It has to be that player's turn.
## No salary is paid on the way, so tests can compare money.
func _land(engine: MatchEngine, pid: int, index: int) -> void:
	var size: int = _board_def.size()
	var salary: int = engine.config.salary

	# Never a double: that would give an extra turn.
	engine.state.players[pid].pos = (index - 3 + size) % size
	engine.random.forced_rolls = [[1, 2]]
	engine.config.salary = 0
	if not engine.submit_intent(pid, Intent.make(Intent.ROLL)):
		_failures += 1
		printerr("FAIL %s: player %d could not roll" % [_current, pid])
	engine.config.salary = salary

## Makes [param pid] land on a roulette and draw [param card].
func _draw(engine: MatchEngine, pid: int, card: int) -> void:
	engine.random.forced_cards = [card]
	_land(engine, pid, _tiles_of_type(GameEnums.TileType.ROULETTE)[0])

## Levels on offer in the buy pop-up.
func _levels(engine: MatchEngine) -> Array:
	return engine.state.pending.options.map(func(option: Dictionary) -> int: return option.level)

## Prices on offer in the buy pop-up.
func _prices(engine: MatchEngine) -> Array:
	return engine.state.pending.options.map(func(option: Dictionary) -> int: return option.price)

func _ok(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL %s: %s" % [_current, what])

func _eq(actual: Variant, expected: Variant, what: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("FAIL %s: %s (expected %s, got %s)" % [_current, what, expected, actual])
