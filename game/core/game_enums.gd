## Stable identifiers shared by the rules, the network and the interface.
## Only these numbers travel over the network: every client turns them into text locally
## through the translation keys built by the helpers at the bottom.
class_name GameEnums

## Empire a city belongs to. All the cities of one empire form a monopoly group.
enum Empire { PORTUGAL, SPAIN, BRITAIN, FRANCE, OTTOMAN, NETHERLANDS, CHINA, JAPAN }

## What a board tile is.
enum TileType { CITY, CHURCH, START, HELL, POPE_CALL, TAX, ROULETTE }

## Building level of an owned city.
enum Level { LAND, SHACK, HOUSE, CASTLE }

## Lucifer Roulette cards.
enum Card { LUCIFER_DEBT, LUCIFER_GIFT, KINGS_INVASION, SHIELD, PAY_DOUBLE, PAY_HALF }

## Turn phase. Mirrors the states of the MatchEngine FSM.
enum Phase { IDLE, ROLL, BUY, OFFER, OFFER_RESPONSE, TARGET, GAME_OVER, SELL }

## Why the acting player has to pick a tile.
enum TargetKind { POPE, INVASION, SHIELD }

## How the match was won.
enum WinReason { NONE, LINE, MONOPOLIES, CHURCHES, LAST_STANDING }

## What a mandatory payment is for.
enum PayKind { RENT, TAX, DEBT_CARD, GIFT }

## Card effect waiting for the next rent the player pays.
enum RentCard { NONE, DOUBLE, HALF }

## Things that happened, sent to the clients for the log.
## Parameters: p = player, q = other player, a = amount, t = tile, c = card, d = dice,
## n = count, l = level, r = win reason, k = pay kind.
enum Event {
	ROLLED, PASSED_START, BOUGHT, UPGRADED, RENT_PAID, TAX_PAID, DEBT_CARD_PAID,
	SENT_TO_HELL, HELL_WAIT, POPE_TRAVEL, CARD_DRAWN, GIFT_PAID, INVASION,
	SHIELD_PLACED, SHIELD_BROKEN, OFFER_MADE, OFFER_ACCEPTED, OFFER_REFUSED,
	OFFER_FORCED, OFFER_TIMEOUT, LOAN_TAKEN, DEBT_GARNISHED, DEBT_CLEARED,
	BANKRUPT, PLAYER_LEFT, PLAYER_RETURNED, WON, EXTRA_TURN,
	CANT_PAY, CANT_BUY, CANT_UPGRADE, CANT_OFFER, PROPERTY_SOLD, POPE_CALLED,
}

static func empire_key(empire: int) -> String:
	return "EMPIRE_" + Empire.keys()[empire]

static func level_key(level: int) -> String:
	return "LEVEL_" + Level.keys()[level]

static func card_title_key(card: int) -> String:
	return "CARD_%s_TITLE" % Card.keys()[card]

static func card_text_key(card: int) -> String:
	return "CARD_%s_TEXT" % Card.keys()[card]

static func event_key(event: int) -> String:
	return "EV_" + Event.keys()[event]

## Text of a CANT_PAY event, which depends on what the payment was for.
static func cant_pay_key(kind: int) -> String:
	return "EV_CANT_PAY_" + PayKind.keys()[kind]

static func win_reason_key(reason: int) -> String:
	return "WIN_" + WinReason.keys()[reason]

static func target_prompt_key(kind: int) -> String:
	return "PROMPT_TARGET_" + TargetKind.keys()[kind]
