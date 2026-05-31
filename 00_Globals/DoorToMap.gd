extends Area2D

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var talk_indicator: Node2D = get_node_or_null("TalkIndicator") as Node2D

@export_file("*.tscn") var target_scene_path: String = ""
@export var target_spawn_point_name: String = ""

@export var interact_action: String = "interact"
@export var fade_out_time: float = 0.7
@export var fade_in_time: float = 0.7
@export var transition_lock_extra_time: float = 0.5

var player_in_range: bool = false
var player: Player = null
var is_changing_scene: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = true

	if collision_shape != null:
		collision_shape.disabled = false

	if talk_indicator != null:
		talk_indicator.visible = false
		talk_indicator.z_index = 100
		talk_indicator.z_as_relative = false

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)

	call_deferred("refresh_player_in_range_after_spawn")


func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if is_changing_scene:
		return

	if not LevelManager.can_use_map_transition():
		return

	if event is InputEventKey:
		if event.echo:
			return

	if event.is_action_pressed(interact_action):
		get_viewport().set_input_as_handled()
		await enter_door()


func enter_door() -> void:
	if is_changing_scene:
		return

	if not LevelManager.can_use_map_transition():
		return

	if target_scene_path == "":
		push_warning(name + " chưa gán Target Scene Path.")
		return

	is_changing_scene = true

	if talk_indicator != null:
		talk_indicator.visible = false

	if player != null:
		player.set_control_enabled(false)

	if target_spawn_point_name != "":
		LevelManager.set_next_spawn_point(target_spawn_point_name)

	LevelManager.lock_map_transition(fade_out_time + fade_in_time + transition_lock_extra_time)

	await SceneTransition.change_scene_with_fade(
		target_scene_path,
		fade_out_time,
		fade_in_time
	)


func refresh_player_in_range_after_spawn() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

	if is_changing_scene:
		return

	for body in get_overlapping_bodies():
		try_set_player_in_range(body)

	for area in get_overlapping_areas():
		try_set_player_in_range(area)

		if area.get_parent() != null:
			try_set_player_in_range(area.get_parent())


func _on_body_entered(body: Node2D) -> void:
	try_set_player_in_range(body)


func _on_body_exited(body: Node2D) -> void:
	try_remove_player_from_range(body)


func _on_area_entered(area: Area2D) -> void:
	try_set_player_in_range(area)

	if area.get_parent() != null:
		try_set_player_in_range(area.get_parent())


func _on_area_exited(area: Area2D) -> void:
	try_remove_player_from_range(area)

	if area.get_parent() != null:
		try_remove_player_from_range(area.get_parent())


func try_set_player_in_range(target: Node) -> void:
	var detected_player: Player = find_player_from_node(target)

	if detected_player == null:
		return

	player = detected_player
	player_in_range = true

	if talk_indicator != null:
		talk_indicator.visible = true


func try_remove_player_from_range(target: Node) -> void:
	var detected_player: Player = find_player_from_node(target)

	if detected_player == null:
		return

	if detected_player != player:
		return

	player = null
	player_in_range = false

	if talk_indicator != null:
		talk_indicator.visible = false


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
