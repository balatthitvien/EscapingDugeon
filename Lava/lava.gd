extends Area2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_stream_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@export var animation_name: String = "idle"
@export var kill_player: bool = true

@export var play_sound_when_near: bool = true
@export var sound_distance: float = 200.0
@export var max_volume_db: float = 7
@export var min_volume_db: float = 0

var has_killed_player: bool = false
var player: Node2D = null


func _ready() -> void:
	monitoring = true
	monitorable = true

	if collision_shape != null:
		collision_shape.disabled = false

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	play_lava_animation()

	await get_tree().physics_frame
	find_player_in_scene()

	if audio_stream_player != null:
		audio_stream_player.stop()
		audio_stream_player.volume_db = min_volume_db


func _physics_process(_delta: float) -> void:
	update_lava_sound()


func play_lava_animation() -> void:
	if animation_player == null:
		return

	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
	else:
		push_warning("Lava thiếu animation: " + animation_name)


func update_lava_sound() -> void:
	if not play_sound_when_near:
		return

	if audio_stream_player == null:
		return

	if player == null or not is_instance_valid(player):
		find_player_in_scene()

	if player == null:
		if audio_stream_player.playing:
			audio_stream_player.stop()
		return

	var distance_to_lava: float = get_distance_from_player_to_lava()

	if distance_to_lava <= sound_distance:
		var volume_ratio: float = 1.0 - clamp(distance_to_lava / sound_distance, 0.0, 1.0)
		audio_stream_player.volume_db = lerp(min_volume_db, max_volume_db, volume_ratio)

		if not audio_stream_player.playing:
			audio_stream_player.play()
	else:
		if audio_stream_player.playing:
			audio_stream_player.stop()


func get_distance_from_player_to_lava() -> float:
	if player == null:
		return 999999.0

	if collision_shape == null:
		return global_position.distance_to(player.global_position)

	if collision_shape.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = collision_shape.shape

		var half_size: Vector2 = rect_shape.size * 0.5
		half_size.x *= abs(collision_shape.global_scale.x)
		half_size.y *= abs(collision_shape.global_scale.y)

		var center: Vector2 = collision_shape.global_position
		var player_pos: Vector2 = player.global_position

		var closest_x: float = clamp(player_pos.x, center.x - half_size.x, center.x + half_size.x)
		var closest_y: float = clamp(player_pos.y, center.y - half_size.y, center.y + half_size.y)

		var closest_point: Vector2 = Vector2(closest_x, closest_y)

		return player_pos.distance_to(closest_point)

	return collision_shape.global_position.distance_to(player.global_position)


func _on_body_entered(body: Node2D) -> void:
	try_remember_player(body)
	try_kill_player(body)


func _on_area_entered(area: Area2D) -> void:
	try_remember_player(area)
	try_kill_player(area)

	if area.get_parent() != null:
		try_remember_player(area.get_parent())
		try_kill_player(area.get_parent())


func try_kill_player(target: Node) -> void:
	if not kill_player:
		return

	if has_killed_player:
		return

	if target == null:
		return

	var detected_player: Node = find_player_from_node(target)

	if detected_player == null:
		return

	has_killed_player = true

	if death_sound != null:
		death_sound.stop()
		death_sound.play()

	if detected_player.has_method("die"):
		detected_player.die(global_position)
	else:
		push_warning("Player không có hàm die().")


func try_remember_player(target: Node) -> void:
	var detected_player: Node = find_player_from_node(target)

	if detected_player == null:
		return

	if detected_player is Node2D:
		player = detected_player as Node2D


func find_player_in_scene() -> void:
	# Ưu tiên PlayerManager vì Player.gd của bạn đang có PlayerManager.player = self
	if PlayerManager != null and PlayerManager.player != null:
		if PlayerManager.player is Node2D:
			player = PlayerManager.player
			return

	var found_player: Node = null

	for node in get_tree().get_nodes_in_group("player"):
		found_player = find_player_from_node(node)
		if found_player != null:
			break

	if found_player == null:
		for node in get_tree().get_nodes_in_group("Player"):
			found_player = find_player_from_node(node)
			if found_player != null:
				break

	if found_player == null:
		found_player = get_tree().root.find_child("Player", true, false)

	if found_player != null and found_player is Node2D:
		player = found_player as Node2D


func find_player_from_node(node: Node) -> Node:
	var current: Node = node

	while current != null:
		if current is Player:
			return current

		if current.is_in_group("player"):
			return current

		if current.is_in_group("Player"):
			return current

		if current.name == "Player":
			return current

		current = current.get_parent()

	return null
