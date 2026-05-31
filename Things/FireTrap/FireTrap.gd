extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var damage_area: Area2D = $DamageArea
@onready var damage_collision: CollisionShape2D = $DamageArea/CollisionShape2D
@onready var fire_sound: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D

@export var fire_animation_name: String = "fire"
@export var off_frame: int = 0
@export var damage: int = 1

@export var fire_volume_db: float = 0.0
@export var full_volume_distance: float = 120.0
@export var max_hear_distance: float = 450.0
@export var min_volume_db: float = -35.0

var is_damage_active: bool = false
var hit_targets: Array[Node] = []
var is_firing: bool = false


func _ready() -> void:
	connect_damage_signals()
	force_fire_off()


func _process(_delta: float) -> void:
	if fire_sound == null:
		return

	if not fire_sound.playing:
		return

	fire_sound.volume_db = get_fire_volume_by_distance()


func connect_damage_signals() -> void:
	if damage_area == null:
		push_error(name + " thiếu DamageArea.")
		return

	if not damage_area.body_entered.is_connected(_on_damage_area_body_entered):
		damage_area.body_entered.connect(_on_damage_area_body_entered)

	if not damage_area.area_entered.is_connected(_on_damage_area_area_entered):
		damage_area.area_entered.connect(_on_damage_area_area_entered)

	if animation_player != null:
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)


func play_fire() -> void:
	is_firing = true
	hit_targets.clear()

	if animation_player == null:
		return

	if not animation_player.has_animation(fire_animation_name):
		push_warning(name + " thiếu animation: " + fire_animation_name)
		return

	animation_player.stop()
	animation_player.play(fire_animation_name)


func force_fire_off() -> void:
	is_firing = false
	stop_damage_area()

	if animation_player != null:
		animation_player.stop()

	if sprite_2d != null:
		sprite_2d.frame = off_frame


func start_damage_area() -> void:
	is_damage_active = true
	hit_targets.clear()

	if damage_collision != null:
		damage_collision.disabled = false

	if damage_area != null:
		damage_area.monitoring = true
		damage_area.monitorable = true

	await get_tree().physics_frame

	if damage_area == null:
		return

	for body in damage_area.get_overlapping_bodies():
		try_damage_player(body)

	for area in damage_area.get_overlapping_areas():
		try_damage_player(area)


func stop_damage_area() -> void:
	is_damage_active = false
	hit_targets.clear()

	if damage_area != null:
		damage_area.monitoring = false
		damage_area.monitorable = false

	if damage_collision != null:
		damage_collision.disabled = true


func play_fire_sound() -> void:
	if fire_sound == null:
		return

	if fire_sound.stream == null:
		return

	var volume_by_distance: float = get_fire_volume_by_distance()

	if volume_by_distance <= min_volume_db:
		return

	fire_sound.stop()
	fire_sound.volume_db = volume_by_distance
	fire_sound.play()


func get_fire_volume_by_distance() -> float:
	var target_player: Node2D = get_player_for_sound()

	if target_player == null:
		return fire_volume_db

	var distance_to_player: float = global_position.distance_to(target_player.global_position)

	if distance_to_player <= full_volume_distance:
		return fire_volume_db

	if distance_to_player >= max_hear_distance:
		return min_volume_db

	var distance_ratio: float = inverse_lerp(
		full_volume_distance,
		max_hear_distance,
		distance_to_player
	)

	distance_ratio = clamp(distance_ratio, 0.0, 1.0)

	return lerp(fire_volume_db, min_volume_db, distance_ratio)


func get_player_for_sound() -> Node2D:
	if PlayerManager.player != null and is_instance_valid(PlayerManager.player):
		if PlayerManager.player is Node2D:
			return PlayerManager.player as Node2D

	return null


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == fire_animation_name:
		stop_damage_area()
		is_firing = false


func _on_damage_area_body_entered(body: Node2D) -> void:
	try_damage_player(body)


func _on_damage_area_area_entered(area: Area2D) -> void:
	try_damage_player(area)


func try_damage_player(target: Node) -> void:
	if not is_damage_active:
		return

	var detected_player: Player = find_player_from_node(target)

	if detected_player == null:
		return

	if hit_targets.has(detected_player):
		return

	hit_targets.append(detected_player)

	if detected_player.has_method("take_damage"):
		detected_player.take_damage(damage, global_position)


func find_player_from_node(node: Node) -> Player:
	var current := node

	while current != null:
		if current is Player:
			return current as Player

		if current.is_in_group("player"):
			return current as Player

		if current.is_in_group("Player"):
			return current as Player

		if current.name == "Player":
			return current as Player

		current = current.get_parent()

	if PlayerManager.player != null and PlayerManager.player is Player:
		return PlayerManager.player as Player

	return null
