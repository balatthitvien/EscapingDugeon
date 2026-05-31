extends Node2D

@onready var you_died_ui: CanvasLayer = get_node_or_null("YouDiedUI") as CanvasLayer
var player: Player = null
var has_connected_player_died: bool = false
func _ready() -> void:
	setup_player_death_handler()
	apply_player_spawn_point()


func apply_player_spawn_point() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var spawn_name: String = LevelManager.get_next_spawn_point()

	print("MAP_3 SPAWN NAME = ", spawn_name)

	if spawn_name == "":
		return

	var spawn_point := get_node_or_null("SpawnPoints/" + spawn_name)

	if spawn_point == null:
		push_warning("Không tìm thấy spawn point trong map_3: " + spawn_name)
		LevelManager.clear_next_spawn_point()
		return

	if PlayerManager.player != null:
		PlayerManager.player.global_position = spawn_point.global_position
		PlayerManager.player.velocity = Vector2.ZERO

		print("Đã đưa Player tới spawn point: ", spawn_name, " tại ", spawn_point.global_position)

	LevelManager.clear_next_spawn_point()
func setup_player_death_handler() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	player = get_node_or_null("Player") as Player

	if player == null:
		player = PlayerManager.player

	if player == null:
		push_warning(name + ": Không tìm thấy Player để bắt signal died.")
		return

	if you_died_ui == null:
		you_died_ui = get_node_or_null("YouDiedUI") as CanvasLayer

	if you_died_ui == null:
		push_warning(name + ": Không tìm thấy YouDiedUI trong scene.")
		return

	if has_connected_player_died:
		return

	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	has_connected_player_died = true


func _on_player_died() -> void:
	print(name + ": PLAYER DIED SIGNAL RECEIVED")

	await get_tree().create_timer(1.0).timeout

	if you_died_ui != null and you_died_ui.has_method("show_you_died"):
		you_died_ui.show_you_died()
