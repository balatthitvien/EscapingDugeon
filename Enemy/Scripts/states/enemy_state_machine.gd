class_name EnemyStateMachine
extends Node

@export var starting_state: EnemyState

var states: Array[EnemyState] = []
var prev_state: EnemyState
var current_state: EnemyState


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	if current_state == null:
		return

	change_state(current_state.process(delta))


func _physics_process(delta: float) -> void:
	if current_state == null:
		return

	change_state(current_state.physics(delta))


func initialize(_enemy: Enemy) -> void:
	states.clear()

	for child in get_children():
		if child is EnemyState:
			child.enemy = _enemy
			child.state_machine = self
			child.init()
			states.append(child)

	if starting_state != null:
		change_state(starting_state)
	elif states.size() > 0:
		change_state(states[0])

	process_mode = Node.PROCESS_MODE_INHERIT


func change_state(new_state: EnemyState) -> void:
	if new_state == null:
		return

	if new_state == current_state:
		return

	if current_state != null:
		current_state.exit()

	prev_state = current_state
	current_state = new_state
	current_state.enter()

	print("Enemy State: ", current_state.name)
