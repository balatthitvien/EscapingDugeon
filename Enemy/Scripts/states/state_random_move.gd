class_name EnemyRandomMove
extends EnemyState

@onready var idle := $"../state_idle" as EnemyState
@onready var chase := $"../state_chase" as EnemyState

var move_timer: float = 0.0
var random_direction: Vector2 = Vector2.LEFT


func enter() -> void:
	move_timer = enemy.random_move_time

	if randf() < 0.5:
		random_direction = Vector2.LEFT
	else:
		random_direction = Vector2.RIGHT

	enemy.set_direction(random_direction)
	enemy.update_animation("walk", false)


func physics(delta: float) -> EnemyState:
	if enemy.can_see_player:
		enemy.lost_player_timer = enemy.lost_player_grace_time
	else:
		enemy.lost_player_timer -= delta

	if enemy.lost_player_timer <= 0:
		enemy.velocity.x = 0
		return idle

	move_timer -= delta

	if enemy.is_near_left_limit():
		random_direction = Vector2.RIGHT

	if enemy.is_near_right_limit():
		random_direction = Vector2.LEFT

	enemy.set_direction(random_direction)

	enemy.velocity.x = move_toward(
		enemy.velocity.x,
		random_direction.x * enemy.random_move_speed,
		500 * delta
	)

	enemy.update_animation("walk", true)

	if move_timer <= 0:
		return chase
	return null
