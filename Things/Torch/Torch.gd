extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var point_light_2d: PointLight2D = $PointLight2D

@export var animation_name: String = "idle"
@export var random_start_frame: bool = true


func _ready() -> void:
	if point_light_2d != null:
		point_light_2d.enabled = true

	play_animation()


func play_animation() -> void:
	if animation_player == null:
		return

	if not animation_player.has_animation(animation_name):
		push_warning(name + " thiếu animation: " + animation_name)
		return

	animation_player.play(animation_name)

	if random_start_frame:
		var anim_length: float = animation_player.current_animation_length

		if anim_length > 0.0:
			animation_player.seek(randf_range(0.0, anim_length), true)
