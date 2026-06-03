extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var idle_animation_name: String = "idle"
@export var play_on_ready: bool = true

@export var use_collision: bool = false

@export var randomize_start_time: bool = true
@export var randomize_speed: bool = true
@export var min_anim_speed: float = 0.9
@export var max_anim_speed: float = 1.1


func _ready() -> void:
	randomize()

	setup_collision()

	if play_on_ready:
		play_idle()


func setup_collision() -> void:
	if collision_shape_2d == null:
		return

	# Nếu chỉ là vật trang trí thì tắt va chạm đi.
	collision_shape_2d.disabled = not use_collision


func play_idle() -> void:
	if animation_player == null:
		push_warning("Flag thiếu AnimationPlayer.")
		return

	if not animation_player.has_animation(idle_animation_name):
		push_warning("Flag thiếu animation: " + idle_animation_name)
		return

	if randomize_speed:
		animation_player.speed_scale = randf_range(min_anim_speed, max_anim_speed)
	else:
		animation_player.speed_scale = 1.0

	animation_player.play(idle_animation_name)

	# Cho nhiều lá cờ lệch nhịp nhau, nhìn tự nhiên hơn.
	if randomize_start_time:
		var anim_length: float = animation_player.current_animation_length

		if anim_length > 0.0:
			animation_player.seek(randf_range(0.0, anim_length), true)


func stop_idle() -> void:
	if animation_player == null:
		return

	animation_player.stop()


func set_flag_visible(state: bool) -> void:
	visible = state
