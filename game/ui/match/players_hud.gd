## The players' cards, spread over the four corners of the screen, which the isometric board
## leaves free. With more than four players a second card stacks in each corner.
class_name PlayersHud extends Control

const CARD_SCENE := preload("res://ui/match/player_card.tscn")

## Distance from the edges of the screen, and between two cards of the same corner.
const MARGIN := Vector2(16, 10)
const STACK_GAP := 6.0

# Player id -> PlayerCard.
var _cards: Dictionary = {}

func refresh(state: GameState) -> void:
	for p: Dictionary in state.players:
		if not _cards.has(p.id):
			var card: PlayerCard = CARD_SCENE.instantiate()
			add_child(card)
			card.position = _slot(p.id, card.custom_minimum_size)
			_cards[p.id] = card

		var is_turn: bool = p.id == state.turn and state.winner < 0
		(_cards[p.id] as PlayerCard).refresh(p, is_turn)

# Corners in order: top-left, top-right, bottom-left, bottom-right. Players beyond the
# fourth go one step towards the middle of the same corners.
func _slot(index: int, card_size: Vector2) -> Vector2:
	var right: bool = index % 2 == 1
	var bottom: bool = (index % 4) >= 2
	var layer: float = floorf(index / 4.0) * (card_size.y + STACK_GAP)

	var x: float = size.x - MARGIN.x - card_size.x if right else MARGIN.x
	var y: float = size.y - MARGIN.y - card_size.y - layer if bottom else MARGIN.y + layer
	return Vector2(x, y)
