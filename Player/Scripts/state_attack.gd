class_name State_Attack
extends State

@export var attack_cooldown_time: float = 0.1
@export var attack_pitch_min: float = 1.3
@export var attack_pitch_max: float = 1.5

var attacking: bool = false
var cooldown_running: bool = false

@onready var idle: State = $"../Idle"
@onready var walk: State = $"../Walk"
@onready var jump: State = $"../Jump"


func Enter() -> void:
	if player.is_dead:
		return

	if player.is_hurt:
		return

	if !player.can_control:
		return

	if player.attack_cooldown:
		attacking = false
		return

	player.attack_cooldown = true
	attacking = true

	player.velocity.x = 0
	player.stop_hurt_box()
	player.reset_attack_hit_targets()

	player.interactions.rotation_degrees = 0
	player.interactions.scale = Vector2.ONE

	player.update_animation("attack", false)

	if player.attack_sound != null:
		player.attack_sound.pitch_scale = randf_range(
			attack_pitch_min,
			attack_pitch_max
		)
		player.attack_sound.play()

	var finished_anim: StringName = await player.animation_player.animation_finished

	if player.is_dead or player.is_hurt:
		cancel_attack_immediately()
		return

	if finished_anim != "attack_left" and finished_anim != "attack_right":
		cancel_attack_immediately()
		return

	attacking = false
	player.stop_hurt_box()

	start_attack_cooldown()


func Exit() -> void:
	attacking = false
	player.stop_hurt_box()

	# Nếu bị đánh / chết khi đang attack thì hủy cooldown ngay.
	# Còn nếu attack kết thúc bình thường thì KHÔNG reset ở đây,
	# để start_attack_cooldown() tự reset sau 0.1s.
	if player.is_dead or player.is_hurt:
		cancel_attack_immediately()


func Process(_delta: float) -> State:
	if player.is_dead:
		cancel_attack_immediately()
		return idle

	if player.is_hurt:
		cancel_attack_immediately()
		return idle

	if attacking:
		player.velocity.x = 0
		return null

	if !player.can_control:
		cancel_attack_immediately()
		return idle

	player.velocity.x = 0

	if !player.is_on_floor():
		return jump

	var direction := player.input_movement()

	if direction != 0:
		player.update_facing_direction(direction)
		return walk

	return idle


func start_attack_cooldown() -> void:
	if cooldown_running:
		return

	cooldown_running = true

	await player.get_tree().create_timer(attack_cooldown_time).timeout

	if player.is_dead or player.is_hurt:
		player.attack_cooldown = false
		cooldown_running = false
		return

	player.attack_cooldown = false
	player.reset_attack_hit_targets()

	cooldown_running = false


func cancel_attack_immediately() -> void:
	attacking = false
	cooldown_running = false
	player.attack_cooldown = false
	player.stop_hurt_box()
	player.reset_attack_hit_targets()
