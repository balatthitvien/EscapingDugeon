class_name HitBox extends Area2D

signal Damaged ( damage:int)

func _ready():
	pass

func _process(delta):
	pass
func TakeDamage (damage:int) ->void:
	print("Take Damage :",damage)
	Damaged.emit(damage)
