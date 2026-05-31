class_name EnemyWalk
extends EnemyState

@onready var idle: EnemyState = $"../state_idle"
@onready var chase: EnemyState = $"../state_chase"


func enter() -> void:
	enemy.update_direction_by_target()
	enemy.update_animation("walk", false)


func process(_delta: float) -> EnemyState:
	if enemy.can_see_player and enemy.player != null:
		return chase

	if enemy.point_positions.is_empty():
		return null

	var distance_to_target: float = enemy.current_target.x - enemy.global_position.x

	if abs(distance_to_target) < 5:
		return idle

	return null


func physics(delta: float) -> EnemyState:
	if enemy.point_positions.is_empty():
		enemy.velocity.x = 0
		return null

	enemy.update_direction_by_target()

	enemy.velocity.x = move_toward(
		enemy.velocity.x,
		enemy.direction.x * enemy.move_speed,
		400 * delta
	)

	enemy.update_animation("walk", true)

	return null
