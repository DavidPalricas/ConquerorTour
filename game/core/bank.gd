## Lucifer is the bank: money paid to him leaves the game and loans come from him.
## Every movement of money goes through here, so loans, garnishment and bankruptcy are
## applied in a single place.
class_name Bank

## Payee id meaning "Lucifer": the money leaves the game.
const LUCIFER := -1

## Gives [param amount] to a player. While the player has a debt, the money goes to Lucifer
## first and only the excess is kept.
static func receive(state: GameState, pid: int, amount: int) -> void:
	var p: Dictionary = state.players[pid]
	if amount <= 0 or p.bankrupt:
		return

	var kept: int = amount
	if p.debt > 0:
		var garnished: int = mini(p.debt, amount)
		p.debt -= garnished
		kept -= garnished
		state.log_event(GameEnums.Event.DEBT_GARNISHED, {"p": pid, "a": garnished})
		if p.debt == 0:
			state.log_event(GameEnums.Event.DEBT_CLEARED, {"p": pid})

	p.money += kept

## Mandatory payment (rent, tax or card). When the money is not enough, Lucifer lends exactly
## what is missing, unless the player already has a debt or the missing amount is above the
## loan limit: then the player goes bankrupt. Returns whether the payment was made in full.
static func pay(state: GameState, cfg: GameConfig, pid: int, amount: int, payee: int) -> bool:
	var p: Dictionary = state.players[pid]
	if amount <= 0:
		return true

	if p.money < amount:
		var missing: int = amount - int(p.money)
		var limit: float = cfg.loan_limit_multiplier * Economy.net_worth(state, cfg, pid)
		if p.debt > 0 or missing > limit:
			bankrupt(state, pid)
			return false

		# The loan money itself is not garnished.
		p.debt = missing
		p.money += missing
		state.log_event(GameEnums.Event.LOAN_TAKEN, {"p": pid, "a": missing})

	p.money -= amount
	if payee >= 0:
		receive(state, payee, amount)
	return true

## Eliminates a player at once: the debt disappears, the money that is left goes to nobody
## and the properties become free.
static func bankrupt(state: GameState, pid: int) -> void:
	var p: Dictionary = state.players[pid]

	p.money = 0
	p.debt = 0
	p.bankrupt = true
	p.hell = 0
	p.debt_card = false
	p.rent_card = GameEnums.RentCard.NONE

	for index: int in state.owned_by(pid):
		var ts: Dictionary = state.tiles[index]
		ts.owner = -1
		ts.level = 0
		ts.shield = false

	state.log_event(GameEnums.Event.BANKRUPT, {"p": pid})
