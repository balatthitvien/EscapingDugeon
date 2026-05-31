extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var full_frame: int = 0
@export var half_frame: int = 1
@export var empty_frame: int = 2

@export var damage_to_half_animation: String = "half-heart"
@export var damage_to_empty_animation: String = "1-heart"
@export var heal_one_heart_animation: String = "heal-1-heart"
@export var heal_half_heart_animation: String = "heal-half-heart"

var current_state: int = 2
var animation_token: int = 0


func set_heart_state(value: int) -> void:
	animation_token += 1
	current_state = clamp(value, 0, 2)

	if animation_player != null:
		animation_player.stop()

	match current_state:
		0:
			sprite_2d.frame = empty_frame
		1:
			sprite_2d.frame = half_frame
		2:
			sprite_2d.frame = full_frame


func play_change_from_to(old_value: int, new_value: int) -> void:
	old_value = clamp(old_value, 0, 2)
	new_value = clamp(new_value, 0, 2)

	if old_value == new_value:
		set_heart_state(new_value)
		return

	current_state = new_value
	animation_token += 1
	var my_token: int = animation_token

	var anim_name: String = ""

	if new_value < old_value:
		if new_value == 1:
			anim_name = damage_to_half_animation
		else:
			anim_name = damage_to_empty_animation
	else:
		if new_value - old_value >= 2:
			anim_name = heal_one_heart_animation
		else:
			anim_name = heal_half_heart_animation

	if animation_player != null and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
		await animation_player.animation_finished

		if my_token != animation_token:
			return

	set_heart_state(new_value)
