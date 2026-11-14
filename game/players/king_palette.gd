## The eight clothes colours a king can wear. A player's colour is an index into this list.
class_name KingPalette

const COLORS: Array[Color] = [
	Color(0.86, 0.16, 0.18),  # red
	Color(0.18, 0.40, 0.88),  # blue
	Color(0.58, 0.26, 0.80),  # purple
	Color(0.98, 0.82, 0.16),  # yellow
	Color(0.20, 0.68, 0.30),  # green
	Color(0.96, 0.52, 0.12),  # orange
	Color(0.98, 0.50, 0.72),  # pink
	Color(0.78, 0.62, 0.44),  # light brown
]

static func color_of(index: int) -> Color:
	return COLORS[clampi(index, 0, COLORS.size() - 1)]
