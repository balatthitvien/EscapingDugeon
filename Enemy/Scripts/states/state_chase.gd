class_name EnemyChase
extends EnemyState

@onready var idle := $"../state_idle" as EnemyState
@onready var attack := $"../state_attack" as EnemyState
@onready var dash := $"../state_dash" as EnemyState

enum ChaseAction {
	DIRECT,
	PAUSE,
	BACKSTEP,
	LUNGE
}

var current_action: ChaseAction = ChaseAction.DIRECT
var action_timer: float = 0.0
var decision_timer: float = 0.0
var speed_multiplier: float = 1.0


func enter() -> void:
	current_action = ChaseAction.DIRECT
	action_timer = 0.0
	decision_timer = 0.0
	speed_multiplier = 1.0

	enemy.lost_player_timer = enemy.lost_player_grace_time
	enemy.update_direction_to_player()
	enemy.update_animation("walk", false)


func process(delta: float) -> EnemyState:
	if enemy.player == null:
		return idle

	if enemy.can_see_player:
		enemy.lost_player_timer = enemy.lost_player_grace_time
	else:
		enemy.lost_player_timer -= delta

	if enemy.lost_player_timer <= 0.0:
		enemy.velocity.x = 0
		return idle
	if enemy.can_use_dash() and randf() < enemy.dash_chance:
		enemy.velocity.x = 0
		return dash
	if enemy.get_distance_to_player() <= enemy.attack_distance:
		enemy.velocity.x = 0
		return attack



	return null


func physics(delta: float) -> EnemyState:
	if enemy.player == null:
		enemy.velocity.x = 0
		return null

	update_chase_action(delta)

	match current_action:
		ChaseAction.DIRECT:
			chase_direct(delta)

		ChaseAction.PAUSE:
			chase_pause(delta)

		ChaseAction.BACKSTEP:
			chase_backstep(delta)

		ChaseAction.LUNGE:
			chase_lunge(delta)

	enemy.update_animation("walk", true)

	return null


func update_chase_action(delta: float) -> void:
	if action_timer > 0.0:
		action_timer -= delta
		return

	decision_timer -= delta

	if decision_timer > 0.0:
		return

	decision_timer = randf_range(
		enemy.chase_decision_min_time,
		enemy.chase_decision_max_time
	)

	speed_multiplier = randf_range(
		enemy.chase_speed_min_multiplier,
		enemy.chase_speed_max_multiplier
	)

	var roll := randf()

	if roll < enemy.chase_pause_chance:
		current_action = ChaseAction.PAUSE
		action_timer = enemy.chase_pause_time
		return

	roll -= enemy.chase_pause_chance

	if roll < enemy.chase_backstep_chance:
		current_action = ChaseAction.BACKSTEP
		action_timer = enemy.chase_backstep_time
		return

	roll -= enemy.chase_backstep_chance

	if roll < enemy.chase_lunge_chance:
		current_action = ChaseAction.LUNGE
		action_timer = enemy.chase_lunge_time
		speed_multiplier = enemy.chase_speed_max_multiplier + 0.45
		return

	current_action = ChaseAction.DIRECT


func chase_direct(delta: float) -> void:
	enemy.update_direction_to_player()

	enemy.velocity.x = move_toward(
		enemy.velocity.x,
		enemy.facing_direction * enemy.chase_speed * speed_multiplier,
		600 * delta
	)


func chase_pause(delta: float) -> void:
	enemy.update_direction_to_player()

	enemy.velocity.x = move_toward(
		enemy.velocity.x,
		0,
		enemy.chase_speed * 6.0 * delta
	)


func chase_backstep(delta: float) -> void:
	if enemy.player == null:
		return

	var away_direction: int

	if enemy.player.global_position.x > enemy.global_position.x:
		away_direction = -1
		enemy.set_direction(Vector2.LEFT)
	else:
		away_direction = 1
		enemy.set_direction(Vector2.RIGHT)

	enemy.velocity.x = move_toward(
		enemy.velocity.x,
		away_direction * enemy.chase_speed * 0.75,
		500 * delta
	)


func chase_lunge(delta: float) -> void:
	enemy.update_direction_to_player()

	enemy.velocity.x = move_toward(
		enemy.velocity.x,
		enemy.facing_direction * enemy.chase_speed * speed_multiplier,
		900 * delta
	)
