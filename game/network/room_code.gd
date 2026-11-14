## Room codes the host shares with friends. No letters or digits that are easy to confuse.
class_name RoomCode

const ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const LENGTH := 6

static func generate() -> String:
	var code := ""
	for i in LENGTH:
		code += ALPHABET[randi() % ALPHABET.length()]
	return code

## What the player typed, cleaned up to compare with a generated code.
static func normalise(text: String) -> String:
	return text.strip_edges().to_upper()
