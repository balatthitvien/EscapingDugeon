extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var damage_area: Area2D = $DamageArea
@onready var damage_collision: CollisionShape2D = $DamageArea/CollisionShape2D
@onready var slam_sound: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D

@export var start_delay: float = 0.0
@export var repeat_delay: float = 0.6

@export var damage: int = 1
@export var animation_name: String = "slam"

@export var slam_volume_db: float = 0.0
@export var slam_full_volume_distance: float = 120.0
@export var slam_max_hear_distance: float = 500.0
@export var slam_min_volume_db: float = -35.0
var is_damage_active: bool = false
var hit_targets: Array[Node] = []
var is_running: bool = true


func _ready() -> void:
	stop_damage_area()

	if not damage_area.body_entered.is_connected(_on_damage_area_body_entered):
		damage_area.body_entered.connect(_on_damage_area_body_entered)

	if not damage_area.area_entered.is_connected(_on_damage_area_area_entered):
		damage_area.area_entered.connect(_on_damage_area_area_entered)

	await get_tree().create_timer(start_delay).timeout

	start_trap_loop()

func _process(_delta: float) -> void:
	if slam_sound == null:
		return

	if not slam_sound.playing:
		return

	slam_sound.volume_db = get_slam_volume_by_distance()
func start_trap_loop() -> void:
	while is_inside_tree() and is_running:
		if animation_player != null and animation_player.has_animation(animation_name):
			animation_player.play(animation_name)

			await animation_player.animation_finished

			stop_damage_area()

			if repeat_delay > 0.0:
				await get_tree().create_timer(repeat_delay).timeout
		else:
			push_warning(name + " thiếu animation: " + animation_name)
			return


func start_damage_area() -> void:
	is_damage_active = true
	hit_targets.clear()

	if damage_collision != null:
		damage_collision.disabled = false

	if damage_area != null:
		damage_area.monitoring = true
		damage_area.monitorable = true

	await get_tree().physics_frame

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


func play_slam_sound() -> void:
	if slam_sound == null:
		return

	if slam_sound.stream == null:
		return

	var volume_by_distance: float = get_slam_volume_by_distance()

	if volume_by_distance <= slam_min_volume_db:
		return

	slam_sound.stop()
	slam_sound.volume_db = volume_by_distance
	slam_sound.play()

func get_slam_volume_by_distance() -> float:
	var target_player: Node2D = get_player_for_sound()

	if target_player == null:
		return slam_volume_db

	var distance_to_player: float = global_position.distance_to(target_player.global_position)

	if distance_to_player <= slam_full_volume_distance:
		return slam_volume_db

	if distance_to_player >= slam_max_hear_distance:
		return slam_min_volume_db

	var distance_ratio: float = inverse_lerp(
		slam_full_volume_distance,
		slam_max_hear_distance,
		distance_to_player
	)

	distance_ratio = clamp(distance_ratio, 0.0, 1.0)

	return lerp(slam_volume_db, slam_min_volume_db, distance_ratio)


func get_player_for_sound() -> Node2D:
	var nearest_player: Node2D = null
	var nearest_distance: float = 999999.0

	for p in get_all_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		var distance: float = global_position.distance_to(p.global_position)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_player = p

	if nearest_player != null:
		return nearest_player

	if PlayerManager.player != null and is_instance_valid(PlayerManager.player):
		if PlayerManager.player is Node2D:
			return PlayerManager.player as Node2D

	return null
func get_all_players() -> Array:
	var result: Array = []
	var added_ids: Dictionary = {}

	var groups_to_check: Array[String] = [
		"players",
		"player",
		"Player"
	]

	for group_name in groups_to_check:
		for node in get_tree().get_nodes_in_group(group_name):
			var detected_player := find_player_from_node(node)

			if detected_player == null:
				continue

			if !is_instance_valid(detected_player):
				continue

			var id := detected_player.get_instance_id()

			if added_ids.has(id):
				continue

			added_ids[id] = true
			result.append(detected_player)

	var player_1_node := get_tree().root.find_child("Player", true, false)
	var player_2_node := get_tree().root.find_child("Player2", true, false)

	for node in [player_1_node, player_2_node]:
		var detected_player := find_player_from_node(node)

		if detected_player == null:
			continue

		if !is_instance_valid(detected_player):
			continue

		var id := detected_player.get_instance_id()

		if added_ids.has(id):
			continue

		added_ids[id] = true
		result.append(detected_player)

	return result
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

		if current.is_in_group("players"):
			return current as Player

		if current.is_in_group("player"):
			return current as Player

		if current.is_in_group("Player"):
			return current as Player

		if current.name == "Player":
			return current as Player

		if current.name == "Player2":
			return current as Player

		current = current.get_parent()

	if node != null and node.owner != null:
		var owner_node := node.owner

		if owner_node is Player:
			return owner_node as Player

		if owner_node.is_in_group("players"):
			return owner_node as Player

		if owner_node.is_in_group("player"):
			return owner_node as Player

		if owner_node.is_in_group("Player"):
			return owner_node as Player

		if owner_node.name == "Player":
			return owner_node as Player

		if owner_node.name == "Player2":
			return owner_node as Player

	return null
