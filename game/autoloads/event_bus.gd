## Global event bus. Registered as the Autoload "EventBus".
##
## Systems that do not know each other communicate through here: the session does not know
## which screen is open, and the screens do not know whether a change came from the local
## engine or from the network.
##
## Only declare signals here: no state and no logic.
extends Node

## The local player is inside a room (created or joined). The lobby can be shown.
@warning_ignore("unused_signal")
signal lobby_entered

## The list of players in the lobby changed.
@warning_ignore("unused_signal")
signal lobby_changed

## The host started the match (or let this player back into a running one).
@warning_ignore("unused_signal")
signal match_started

## New state of the match. [param snapshot] is GameState.to_dict() and [param events] what
## happened since the previous one.
@warning_ignore("unused_signal")
signal match_updated(snapshot: Dictionary, events: Array)

## The session ended. [param reason_key] is a translation key, or empty when the local
## player left on purpose.
@warning_ignore("unused_signal")
signal session_closed(reason_key: String)
