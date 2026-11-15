## Every economic value, multiplier and timer of the game, in one place.
## The values below are provisional. Tune them in res://config/game_config.tres through the
## Inspector; nothing else in the code holds a number of this kind.
class_name GameConfig extends Resource

@export_group("Money")
## Money each player starts with.
@export var starting_money: int = 2_000_000
## Salary received when passing (or landing on) the Start tile.
@export var salary: int = 200_000

@export_group("Dice")
@export var dice_count: int = 2
@export var dice_sides: int = 6

@export_group("Cities")
## Land price of a city, indexed by GameEnums.Empire
## (Portugal, Spain, Britain, France, Ottoman, Netherlands, China, Japan).
@export var land_prices: Array[int] = [100_000, 120_000, 240_000, 220_000, 160_000, 140_000, 180_000, 200_000]
## Cost of each level as a fraction of the land price, indexed by GameEnums.Level
## (land, shack, house, castle).
@export var level_cost_factors: Array[float] = [1.0, 0.5, 1.0, 1.5]
## Rent of each level as a fraction of the land price, indexed by GameEnums.Level.
@export var rent_factors: Array[float] = [0.2, 0.5, 1.0, 2.0]
## Rent bonus once the owner holds this many cities of the same empire. Does not stack.
@export var group_rent_min_cities: int = 2
@export var group_rent_bonus: float = 0.25

@export_group("Churches")
@export var church_price: int = 200_000
@export var church_base_rent: int = 50_000
## Compound rent multiplier for each additional church of the same owner.
@export var church_rent_multiplier: float = 1.5

@export_group("Lucifer")
## Fraction of the total invested value paid on the Tax tile.
@export var tax_rate: float = 0.10
## A loan is refused when the missing amount is above this many times the net worth.
@export var loan_limit_multiplier: float = 2.0
## What Lucifer pays for a property sold to cover a payment, as a fraction of its invested value.
@export var sell_value_multiplier: float = 1.0
## Turns spent in Hell.
@export var hell_turns: int = 3
## Amount each other player gives to whoever draws Lucifer Gift.
@export var lucifer_gift_amount: int = 50_000
## Cards the roulette draws from. Repeat a card to make it more likely.
@export var card_deck: Array[GameEnums.Card] = [
	GameEnums.Card.LUCIFER_DEBT, GameEnums.Card.LUCIFER_GIFT, GameEnums.Card.KINGS_INVASION,
	GameEnums.Card.SHIELD, GameEnums.Card.PAY_DOUBLE, GameEnums.Card.PAY_HALF,
]

@export_group("Purchase offers")
## Lowest offer, as a multiple of the invested value.
@export var offer_min_multiplier: float = 1.5
## Highest offer. At this multiple the purchase is forced.
@export var offer_forced_multiplier: float = 3.0
## Seconds the owner has to answer. No answer counts as a refusal.
@export var offer_timeout: float = 20.0
## A bot owner accepts from this multiple up.
@export var bot_accept_multiplier: float = 2.0

@export_group("Victory")
## Complete empires needed to win.
@export var monopolies_to_win: int = 3
## Churches needed to win.
@export var churches_to_win: int = 4

@export_group("Bots")
## Seconds a bot waits before acting, so the other players can follow what happens.
@export var bot_delay: float = 1.0

@export_group("Lobby")
@export var min_players: int = 2
@export var max_players: int = 8
