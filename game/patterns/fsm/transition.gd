## Data class defining a transition rule between two states.
## Acts as a configuration node within the FSM scene structure.
class_name Transition extends Node

# ====== Configuration ======

## Trigger key passed to FSM.change_state(). Must match the call-site literal exactly — no normalization is applied.
@export var transition_name: StringName = &""

## The Source State. If null, this is a Global Transition.
@export var from: State = null

## The Target State. Where the FSM will go.
@export var to: State = null