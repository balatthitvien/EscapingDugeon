class_name EnemyIdle
extends EnemyState

@onready var chase := $"../state_chase" as EnemyState


func enter() -> void:
	enemy.velocity.x = 0
	enemy.update_animation("idle", false)


func physics(_delta: float) -> EnemyState:
	enemy.velocity.x = 0

	if enemy.can_see_player:
		return chase

	return null
