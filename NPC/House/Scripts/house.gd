extends CharacterBody2D

@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	play_idle()


func play_idle() -> void:
	if anim.has_animation("idle"):
		anim.play("idle")
	else:
		push_warning("House chưa có animation tên là 'idle'")
