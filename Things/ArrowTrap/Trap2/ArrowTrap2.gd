extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var shoot_sound: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
@onready var vision_area: Area2D = get_node_or_null("VisionArea") as Area2D

@export var arrow_projectile_scene: PackedScene

@export var hide_animation_name: String = "hide"
@export var rise_animation_name: String = "rise"
@export var shoot_animation_name: String = "shoot"

@export var start_delay: float = 0.0
@export var repeat_delay: float = 1.25

@export var delay_after_rise: float = 0.1
@export var delay_after_shoot: float = 0.05

@export var arrow_speed: float = 280.0
@export var arrow_damage: int = 1

@export var shoot_direction: Vector2 = Vector2.LEFT
@export var shoot_volume_db: float = 0.0

@export var use_vision: bool = true
@export var front_dot_threshold: float = 0.0

var shoot_point: Marker2D = null
var player: Player = null

var can_activate: bool = false
var is_active: bool = false
var is_hiding: bool = false
var is_shooting_loop_running: bool = false
var action_token: int = 0


func _ready() -> void:
	shoot_point = get_node_or_null("ShootPoint") as Marker2D

	if shoot_point == null:
		shoot_point = get_node_or_null("Marker2D") as Marker2D

	if animation_player == null:
		push_error(name + " thiếu AnimationPlayer.")
		return

	if use_vision and vision_area == null:
		push_warning(name + " đang bật Use Vision nhưng thiếu VisionArea.")

	play_animation_if_exists(hide_animation_name)

	await get_tree().create_timer(start_delay).timeout

	can_activate = true


func _physics_process(_delta: float) -> void:
	if not can_activate:
		return

	if not use_vision:
		if not is_active and not is_hiding and not is_shooting_loop_running:
			start_active_loop()
		return

	var detected_player: Player = get_valid_detected_player()

	if detected_player != null:
		player = detected_player

		if not is_active and not is_hiding and not is_shooting_loop_running:
			start_active_loop()
	else:
		player = null

		if is_active and not is_hiding:
			hide_trap()


func start_active_loop() -> void:
	if is_active:
		return

	if is_hiding:
		return

	if is_shooting_loop_running:
		return

	is_active = true
	is_hiding = false
	is_shooting_loop_running = true

	action_token += 1
	var my_token: int = action_token

	await play_and_wait(rise_animation_name)

	if not is_loop_valid(my_token):
		is_shooting_loop_running = false
		return

	if delay_after_rise > 0.0:
		await get_tree().create_timer(delay_after_rise).timeout

	if not is_loop_valid(my_token):
		is_shooting_loop_running = false
		return

	while is_loop_valid(my_token):
		await play_and_wait(shoot_animation_name)

		if not is_loop_valid(my_token):
			break

		if delay_after_shoot > 0.0:
			await get_tree().create_timer(delay_after_shoot).timeout

		if not is_loop_valid(my_token):
			break

		if repeat_delay > 0.0:
			await get_tree().create_timer(repeat_delay).timeout

	is_shooting_loop_running = false


func hide_trap() -> void:
	if is_hiding:
		return

	action_token += 1
	is_active = false
	is_hiding = true

	await play_and_wait(hide_animation_name)

	is_hiding = false


func is_loop_valid(token: int) -> bool:
	if token != action_token:
		return false

	if not is_active:
		return false

	if use_vision and get_valid_detected_player() == null:
		return false

	return true


func get_valid_detected_player() -> Player:
	if not use_vision:
		return PlayerManager.player as Player

	var detected_player: Player = get_player_from_vision_area()

	if detected_player == null:
		return null

	if not is_instance_valid(detected_player):
		return null

	if detected_player.is_dead:
		return null

	if not is_player_in_front(detected_player):
		return null

	return detected_player


func is_player_in_front(target_player: Player) -> bool:
	if target_player == null:
		return false

	var direction_to_player: Vector2 = target_player.global_position - global_position

	if direction_to_player.length() <= 0.1:
		return true

	var normalized_shoot_direction: Vector2 = shoot_direction.normalized()
	var normalized_to_player: Vector2 = direction_to_player.normalized()

	var dot_value: float = normalized_shoot_direction.dot(normalized_to_player)

	return dot_value > front_dot_threshold


func play_and_wait(anim_name: String) -> void:
	if animation_player == null:
		return

	if not animation_player.has_animation(anim_name):
		push_warning(name + " thiếu animation: " + anim_name)
		return

	animation_player.play(anim_name)
	await animation_player.animation_finished


func play_animation_if_exists(anim_name: String) -> void:
	if animation_player == null:
		return

	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)


func shoot_arrow() -> void:
	if use_vision and get_valid_detected_player() == null:
		hide_trap()
		return

	if arrow_projectile_scene == null:
		push_warning(name + " chưa gán Arrow Projectile Scene.")
		return

	var arrow: Node = arrow_projectile_scene.instantiate()

	var parent_node: Node = get_tree().current_scene

	if parent_node == null:
		parent_node = get_parent()

	parent_node.add_child(arrow)

	if arrow is Node2D:
		if shoot_point != null:
			(arrow as Node2D).global_position = shoot_point.global_position
		else:
			(arrow as Node2D).global_position = global_position

	if arrow.has_method("setup_arrow"):
		arrow.setup_arrow(
			shoot_direction,
			arrow_speed,
			arrow_damage
		)

	play_shoot_sound()


func play_shoot_sound() -> void:
	if shoot_sound == null:
		return

	if shoot_sound.stream == null:
		return

	shoot_sound.stop()
	shoot_sound.volume_db = shoot_volume_db
	shoot_sound.play()


func get_player_from_vision_area() -> Player:
	if vision_area == null:
		return null

	for body in vision_area.get_overlapping_bodies():
		var detected_player: Player = find_player_from_node(body)

		if detected_player != null:
			return detected_player

	for area in vision_area.get_overlapping_areas():
		var detected_player: Player = find_player_from_node(area)

		if detected_player != null:
			return detected_player

	return null


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
