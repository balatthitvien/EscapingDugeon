class_name HurtBox
extends Area2D

@export var damage: int = 1

var hit_targets: Array[HitBox] = []
var attack_active: bool = false


func _ready() -> void:
	area_entered.connect(AreaEntered)


func start_damage() -> void:
	attack_active = true
	reset_hit_targets()
	monitoring = true


func stop_damage() -> void:
	attack_active = false
	monitoring = false


func reset_hit_targets() -> void:
	hit_targets.clear()


func AreaEntered(a: Area2D) -> void:
	if !attack_active:
		return

	print("Player attack touched: ", a.name)

	if a is HitBox:
		damage_hitbox(a)


func check_overlapping_hitboxes() -> void:
	if !attack_active:
		return

	for area in get_overlapping_areas():
		print("Overlapping area: ", area.name)

		if area is HitBox:
			damage_hitbox(area)


func damage_hitbox(hit_box: HitBox) -> void:
	if hit_targets.has(hit_box):
		return

	hit_targets.append(hit_box)
	hit_box.TakeDamage(damage)
