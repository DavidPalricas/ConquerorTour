## Generic Finite State Machine (FSM).
## Uses a Dictionary-based lookup for O(1) complexity transitions.
## Subclass and override _inject_dependencies() to specialize for specific entities.
class_name FSM extends Node


## List of states available in this machine.
## The first state in this list is the default/initial state.
@export var _states: Array[State] = []

## List of transitions defining state changes.
@export var _transitions: Array[Transition] = []

# ====== Runtime ======

## The currently active state.
var current_state: State = null

# Precomputed lookup: StringName trigger -> { from_instance_id (or -1 for global) -> State }
var _transition_map: Dictionary = {}

## Initializes the FSM.
## The first state of _states becomes the active one.
func _ready() -> void:
	if _states.is_empty():
		push_error("FSM Error: No states defined in inspector.")
		return

	_inject_dependencies()
	_build_transition_map()

	current_state = _states[0]
	current_state.enter()


## Injects the FSM reference into every state. Override in subclasses to inject additional
## entity-specific references (e.g. the character controller) before calling state lifecycle methods.
func _inject_dependencies() -> void:
	for state in _states:
		state._fsm = self

## Precomputes the transition lookup table from the exported _transitions array.
## Keyed by [StringName trigger][from instance_id], with -1 as the from key for global transitions.
func _build_transition_map() -> void:
	for t in _transitions:
		var key: StringName = t.transition_name
		if not _transition_map.has(key):
			_transition_map[key] = {}
		var from_id: int = t.from.get_instance_id() if t.from != null else -1
		_transition_map[key][from_id] = t.to


## Forwards the render-frame tick to the active state for visual logic and non-physics updates.
func _process(delta: float) -> void:
	current_state.execute(delta)


## Forwards the physics tick to the active state for movement and collision logic.
func _physics_process(delta: float) -> void:
	current_state.handle_physics(delta)

## Looks up [param trigger] in the precomputed transition map and switches to the target state.
## Prefers a transition whose [member Transition.from] matches the current state; falls back to a
## global transition (from == null) if no specific one exists. Calls exit() on the old state and
## enter() on the new one.
func change_state(trigger: StringName) -> void:
	var by_trigger: Dictionary = _transition_map.get(trigger, {})

	if by_trigger.is_empty():
		push_error("FSM: Transition '%s' not found from state '%s'." % [trigger, current_state.name])
		return

	var next: State = by_trigger.get(current_state.get_instance_id(), by_trigger.get(-1))

	if next == null:
		push_error("FSM: Transition '%s' not found from state '%s'." % [trigger, current_state.name])
		return

	current_state.exit()
	current_state = next
	current_state.enter()
