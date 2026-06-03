class_name State_Walk
extends State

@onready var idle: State = $"../Idle"
@onready var jump: State = $"../Jump"
@onready var attack: State = $"../Attack"


func Enter() -> void:
	player.update_animation("walk", false)


func Process(delta: float) -> State:
	if !player.can_do_action():
		player.velocity.x = 0
		return idle

	var direction := player.input_movement()

	if !player.is_on_floor():
		return jump

	if direction != 0:
		player.update_facing_direction(direction)
		player.velocity.x = direction * player.max_horizontal_speed
		player.update_animation("walk", true)
	else:
		player.velocity.x = move_toward(
			player.velocity.x,
			0,
			player.slow_down_speed * delta
		)

		if abs(player.velocity.x) < 1:
			player.velocity.x = 0
			return idle

	return null


func HandleInput(event: InputEvent) -> State:
	if !player.can_do_action():
		return null

	if player.is_attack_event_pressed(event):
		return attack

	if player.is_jump_event_pressed(event) and player.is_on_floor():
		return jump

	return null
