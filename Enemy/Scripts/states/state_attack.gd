class_name EnemyAttack
extends EnemyState

@onready var idle := $"../state_idle" as EnemyState
@onready var random_move := $"../state_random_move" as EnemyState

var attacking: bool = false


func enter() -> void:
	attacking = true

	enemy.velocity.x = 0
	enemy.stop_attack_hurt_box()

	enemy.update_direction_to_player()
	enemy.update_animation("attack", false, true)

	await enemy.animation_player.animation_finished

	attacking = false
	enemy.stop_attack_hurt_box()


func physics(_delta: float) -> EnemyState:
	enemy.velocity.x = 0

	if attacking:
		return null

	if enemy.can_see_player or enemy.lost_player_timer > 0:
		return random_move

	return idle
