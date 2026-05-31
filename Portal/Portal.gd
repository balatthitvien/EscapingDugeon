extends Area2D

@export var target_scene: String = "res://Level/test_level_2.tscn"

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var can_enter: bool = true


func _ready() -> void:
	animation_player.play("Portal")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if !can_enter:
		return

	if body.is_in_group("player"):
		can_enter = false
		get_tree().change_scene_to_file(target_scene)
