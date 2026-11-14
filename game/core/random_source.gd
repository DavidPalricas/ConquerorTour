## Dice and cards. Tests queue forced results to make a match deterministic.
class_name RandomSource extends RefCounted

## Rolls used before any random one. Each entry is an array with one value per die.
var forced_rolls: Array = []

## Cards drawn before any random one.
var forced_cards: Array = []

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func roll(cfg: GameConfig) -> Array:
	if not forced_rolls.is_empty():
		return forced_rolls.pop_front()

	var dice: Array = []
	for i in cfg.dice_count:
		dice.append(_rng.randi_range(1, cfg.dice_sides))
	return dice

func draw_card(cfg: GameConfig) -> int:
	if not forced_cards.is_empty():
		return forced_cards.pop_front()
	return cfg.card_deck[_rng.randi() % cfg.card_deck.size()]
