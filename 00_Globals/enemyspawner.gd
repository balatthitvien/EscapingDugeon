extends Node2D

@export var enemy_scene: PackedScene
@export var coin_scene: PackedScene

@export var respawn_time: float = 25.0
@export var coin_drop_count: int = 1
@export var coin_drop_random_x: float = 12.0
@export var coin_drop_y_offset: float = -6.0
@export var set_flag_on_enemy_die: String = ""
var current_enemy: Node = null
var is_respawning: bool = false


func _ready() -> void:
	print("SPAWNER READY: ", name, " at ", global_position)

	await get_tree().process_frame
	spawn_enemy()


func spawn_enemy() -> void:
	if enemy_scene == null:
		push_warning(name + " chưa gán Enemy Scene.")
		return

	var spawn_parent: Node = get_tree().current_scene

	if spawn_parent == null:
		spawn_parent = get_parent()

	current_enemy = enemy_scene.instantiate()

	if current_enemy == null:
		push_warning(name + " không instantiate được Enemy Scene.")
		return

	# Set vị trí trước khi add_child để _ready() của quái lấy đúng PatrolPoints.
	if current_enemy is Node2D:
		if spawn_parent is Node2D:
			current_enemy.position = (spawn_parent as Node2D).to_local(global_position)
		else:
			current_enemy.position = global_position

	spawn_parent.add_child(current_enemy)

	print("SPAWN ENEMY: ", current_enemy.name, " from ", name, " at ", global_position)

	if current_enemy.has_signal("enemy_died"):
		if not current_enemy.enemy_died.is_connected(_on_enemy_died):
			current_enemy.enemy_died.connect(_on_enemy_died)
	else:
		push_warning(str(current_enemy.name) + " chưa có signal enemy_died.")


func _on_enemy_died(death_position: Vector2) -> void:
	if set_flag_on_enemy_die != "":
		LevelManager.set_game_flag(set_flag_on_enemy_die, true)

	drop_coins(death_position)
	start_respawn_timer()


func drop_coins(death_position: Vector2) -> void:
	if coin_scene == null:
		return

	var spawn_parent: Node = get_tree().current_scene

	if spawn_parent == null:
		spawn_parent = get_parent()

	for i in range(coin_drop_count):
		var coin: Node = coin_scene.instantiate()

		if coin is Node2D:
			var random_x: float = randf_range(-coin_drop_random_x, coin_drop_random_x)
			var drop_global_position: Vector2 = death_position + Vector2(random_x, coin_drop_y_offset)

			if spawn_parent is Node2D:
				coin.position = (spawn_parent as Node2D).to_local(drop_global_position)
			else:
				coin.position = drop_global_position

		spawn_parent.add_child(coin)


func start_respawn_timer() -> void:
	if is_respawning:
		return

	is_respawning = true

	await get_tree().create_timer(respawn_time).timeout

	is_respawning = false
	spawn_enemy()
