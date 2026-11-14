## Abstract Base Class for FSM States.
## Defines the lifecycle methods for the State Machine.
class_name State extends Node

# ====== References ======

## Reference to the owning FSM. Injected automatically by FSM._inject_dependencies().
## We ignore the warning because this variable is intended for use by Child classes.
@warning_ignore("unused_private_class_variable")
var _fsm: FSM = null

# ====== Lifecycle Methods ======

## Called when the state becomes active.
func enter() -> void:
    pass

## Called every process frame (visuals, logic).
func execute(_delta: float) -> void:
    pass

## Called every physics frame (movement, collisions).
func handle_physics(_delta: float) -> void:
    pass

## Called when the state is about to be replaced.
func exit() -> void:
    pass