class_name State_Jump
extends State

@onready var idle: State = $"../Idle"
@onready var walk: State = $"../Walk"


func Enter() -> void:
	if !player.can_do_action():
		return

	player.update_animation("jump", false)

	if player.is_on_floor():
		player.velocity.y = player.jump_force
		player.play_jump_sound()


func Process(delta: float) -> State:
	if !player.can_do_action():
		player.velocity.x = 0

		if player.is_on_floor():
			return idle

		return null

	var direction := player.input_movement()

	if direction != 0:
		player.update_facing_direction(direction)
		player.velocity.x = direction * player.max_jump_horizontal_speed
		player.update_animation("jump", true)
	else:
		player.velocity.x = move_toward(
			player.velocity.x,
			0,
			player.slow_down_speed * delta
		)

	if player.is_on_floor() and player.velocity.y >= 0:
		if direction != 0:
			return walk
		else:
			return idle

	return null
