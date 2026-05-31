class_name EnemyDash
extends EnemyState

@onready var chase := $"../state_chase" as EnemyState
@onready var attack := $"../state_attack" as EnemyState
@onready var idle := $"../state_idle" as EnemyState

var dash_direction: int = -1
var dash_animation_finished: bool = false
var is_dashing_forward: bool = false


func enter() -> void:
	if !enemy.can_use_dash():
		enemy.use_normal_sprite()
		dash_animation_finished = true
		return

	enemy.can_dash_now = false
	dash_animation_finished = false
	is_dashing_forward = false

	enemy.update_direction_to_player()
	dash_direction = enemy.facing_direction

	# Quan trọng: lúc bắt đầu chiêu dash, boss phải đứng im
	enemy.velocity.x = 0

	enemy.update_animation("dash", false, true)

	if !enemy.animation_player.animation_finished.is_connected(_on_dash_animation_finished):
		enemy.animation_player.animation_finished.connect(_on_dash_animation_finished)


func process(_delta: float) -> EnemyState:
	if enemy.player == null:
		return idle

	if dash_animation_finished:
		return finish_dash()

	return null


func physics(_delta: float) -> EnemyState:
	if dash_animation_finished:
		enemy.velocity.x = 0
		return null

	if is_dashing_forward:
		enemy.velocity.x = enemy.dash_speed * dash_direction
	else:
		enemy.velocity.x = 0

	if enemy.is_near_left_limit() and dash_direction < 0:
		stop_dash_movement()
		return null

	if enemy.is_near_right_limit() and dash_direction > 0:
		stop_dash_movement()
		return null

	return null


func exit() -> void:
	enemy.velocity.x = 0
	is_dashing_forward = false

	enemy.stop_dash_hurt_box()
	enemy.use_normal_sprite()

	if enemy.animation_player.animation_finished.is_connected(_on_dash_animation_finished):
		enemy.animation_player.animation_finished.disconnect(_on_dash_animation_finished)

	start_dash_cooldown()


func _on_dash_animation_finished(anim_name: StringName) -> void:
	if anim_name == "dash_left" or anim_name == "dash_right":
		dash_animation_finished = true


func finish_dash() -> EnemyState:
	enemy.velocity.x = 0
	is_dashing_forward = false

	if enemy.player == null:
		return idle

	if enemy.get_distance_to_player() <= enemy.attack_distance:
		return attack

	return chase


func start_dash_movement() -> void:
	is_dashing_forward = true


func stop_dash_movement() -> void:
	is_dashing_forward = false
	enemy.velocity.x = 0


func start_dash_cooldown() -> void:
	await enemy.get_tree().create_timer(enemy.dash_cooldown).timeout

	if is_instance_valid(enemy):
		enemy.can_dash_now = true
