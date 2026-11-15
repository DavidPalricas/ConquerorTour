## What a player asks the host to do. Clients only send intents; the host validates them,
## updates the state and sends the new state to everyone.
class_name Intent

const ROLL := "roll"
const BUY := "buy"
const SKIP := "skip"
const OFFER := "offer"
const ACCEPT := "accept"
const REFUSE := "refuse"
const TARGET := "target"
const SELL := "sell"
const SETTLE := "settle"

static func make(type: String) -> Dictionary:
	return {"type": type}

static func buy(level: int) -> Dictionary:
	return {"type": BUY, "level": level}

static func offer(price: int) -> Dictionary:
	return {"type": OFFER, "price": price}

static func target(tile: int) -> Dictionary:
	return {"type": TARGET, "tile": tile}

static func sell(tile: int) -> Dictionary:
	return {"type": SELL, "tile": tile}
