## Dependency checks that survive an export.
## [method @GDScript.assert] is compiled out of release builds, so a scene shipped with an
## unassigned [annotation @GDScript.@export] would crash on a nil dereference with no message
## at all, instead of reporting which reference is missing. These helpers keep the editor
## behaviour — break into the debugger on the spot — and add a [method @GlobalScope.push_error]
## that is still there in the exported game.
## Call them where the dependency is declared (typically [method Node._ready]) so a missing
## reference is reported the moment the scene loads, rather than on the first attack, hover or
## pickup that happens to need it.
## Both return whether the check passed, so a caller that cannot run without the dependency
## can stop early instead of carrying on half-initialised.
class_name Require

## Checks that [param value] was assigned, reporting [param message] when it was not.
## Returns [code]true[/code] while the dependency is present.
static func not_null(value: Variant, message: String) -> bool:
	return that(value != null, message)


## Checks [param condition], reporting [param message] when it does not hold.
## Returns [param condition] itself.
## push_error() runs before the assert so the message reaches the log even when the editor
## halts on the break, and it is what remains once assert() is stripped from a release build.
static func that(condition: bool, message: String) -> bool:
	if condition:
		return true

	push_error(message)

	assert(false, message)

	return false
