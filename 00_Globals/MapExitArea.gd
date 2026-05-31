extends Area2D

@export_file("*.tscn") var target_scene_path: String
@export var target_spawn_point_name: String = ""

@export var fade_out_time: float = 0.7
@export var fade_in_time: float = 0.7

var is_changing_scene: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_changing_scene:
		return

	var player := find_player_from_node(body)

	if player == null:
		return

	if target_scene_path == "":
		push_warning("MapExitArea chưa set Target Scene Path.")
		return

	is_changing_scene = true

	LevelManager.set_next_spawn_point(target_spawn_point_name)

	await SceneTransition.change_scene_with_fade(
		target_scene_path,
		fade_out_time,
		fade_in_time
	)


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

	return null
