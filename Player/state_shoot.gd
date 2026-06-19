class_name StateShoot
extends State

@onready var idle: State = $"../Idle" as State

var is_finished: bool = false
var shoot_anim_name: String = ""


func Enter() -> void:
	is_finished = false
	shoot_anim_name = ""

	player.is_shooting_arrow = true
	player.arrow_spawned_this_shot = false
	player.can_control = false
	player.velocity.x = 0

	if !LevelManager.can_shoot_arrow():
		is_finished = true
		return

	if player.facing_direction < 0:
		shoot_anim_name = "shoot_left"
	else:
		shoot_anim_name = "shoot_right"

	if player.animation_player.has_animation(shoot_anim_name):
		player.animation_player.stop()
		player.animation_player.play(shoot_anim_name)
		player.animation_player.seek(0.0, true)
	else:
		push_warning("Player thiếu animation: " + shoot_anim_name)
		is_finished = true
		return

	if !player.animation_player.animation_finished.is_connected(_on_animation_finished):
		player.animation_player.animation_finished.connect(_on_animation_finished)


func Exit() -> void:
	player.is_shooting_arrow = false
	player.arrow_spawned_this_shot = false

	if !player.is_dead and !player.is_hurt:
		player.can_control = true

	player.velocity.x = 0

	if player.animation_player.animation_finished.is_connected(_on_animation_finished):
		player.animation_player.animation_finished.disconnect(_on_animation_finished)


func Process(_delta: float) -> State:
	return null


func Physics(delta: float) -> State:
	player.velocity.x = 0

	if player.is_dead:
		return null

	if player.is_hurt:
		return idle

	if !player.is_on_floor():
		player.velocity.y += player.GRAVITY * delta

	if is_finished:
		return idle

	return null


func HandleInput(_event: InputEvent) -> State:
	return null


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == shoot_anim_name:
		is_finished = true
