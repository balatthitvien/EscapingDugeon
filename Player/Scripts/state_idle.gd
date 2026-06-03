class_name State_Idle
extends State

@onready var walk: State = $"../Walk"
@onready var jump: State = $"../Jump"
@onready var attack: State = $"../Attack"


func Enter() -> void:
	player.velocity.x = 0
	player.update_animation("idle")


func Process(_delta: float) -> State:
	if !player.can_do_action():
		player.velocity.x = 0
		return null

	var direction := player.input_movement()

	if !player.is_on_floor():
		return jump

	if direction != 0:
		player.update_facing_direction(direction)
		return walk

	return null


func HandleInput(event: InputEvent) -> State:
	if !player.can_do_action():
		return null

	if player.is_attack_event_pressed(event):
		return attack

	if player.is_jump_event_pressed(event) and player.is_on_floor():
		return jump

	return null
