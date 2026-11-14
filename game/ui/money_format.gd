## Money as text, following the chosen language. The separators and the patterns are
## translation keys, so a new language only needs its column in the CSV.
class_name MoneyFormat

## Full amount, for example "1,250,000 ducats".
static func full(amount: int) -> String:
	return _tr("FMT_MONEY").format({"amount": grouped(amount)})

## Short amount for the tiles, for example "112.5K".
static func compact(amount: int) -> String:
	if amount < 1000:
		return grouped(amount)

	var thousands: float = amount / 1000.0
	var text: String = grouped(int(thousands))
	var tenths: int = roundi((thousands - floorf(thousands)) * 10.0)
	if tenths > 0:
		text += _tr("FMT_DECIMAL_SEP") + str(tenths)
	return _tr("FMT_COMPACT_K").format({"amount": text})

## Digits in groups of three.
static func grouped(amount: int) -> String:
	var digits: String = str(absi(amount))
	var separator: String = _tr("FMT_THOUSANDS_SEP")
	var text := ""

	while digits.length() > 3:
		text = separator + digits.right(3) + text
		digits = digits.left(digits.length() - 3)
	text = digits + text

	return "-" + text if amount < 0 else text

static func _tr(key: String) -> String:
	return TranslationServer.translate(key)
