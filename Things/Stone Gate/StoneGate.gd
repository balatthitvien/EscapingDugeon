extends Node2D
@onready var bat_spawn_sound: AudioStreamPlayer2D = get_node_or_null("BatSpawnSound") as AudioStreamPlayer2D
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var open_sound: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var bat_spawn_point: Marker2D = get_node_or_null("BatSpawnPoint") as Marker2D
@onready var gate_body: StaticBody2D = get_node_or_null("GateBody") as StaticBody2D

@export var gate_id: String = "map_3_stone_gate_1"
@export var open_animation_name: String = "open"

@export var bat_scene: PackedScene
@export var bat_count: int = 10
@export var bat_spawn_random_x: float = 20.0
@export var bat_spawn_random_y: float = 14.0
@export var bat_spawn_delay: float = 0.08
@export var bat_burst_speed_min: float = 90.0
@export var bat_burst_speed_max: float = 170.0
@export var bat_burst_time: float = 0.55
var is_open: bool = false
var is_opening: bool = false


func _ready() -> void:
	if LevelManager.get_game_flag(get_open_flag()):
		set_opened_immediate()
	else:
		set_closed_state()


func get_open_flag() -> String:
	return gate_id + "_opened"


func get_bat_spawn_flag() -> String:
	return gate_id + "_spawned_bats"


func open_gate_once() -> void:
	if is_open:
		return

	if is_opening:
		return

	is_opening = true
	LevelManager.set_game_flag(get_open_flag(), true)

	if open_sound != null:
		open_sound.stop()
		open_sound.play()

	if animation_player != null and animation_player.has_animation(open_animation_name):
		animation_player.play(open_animation_name)
		await animation_player.animation_finished
	else:
		push_warning(name + " thiếu animation: " + open_animation_name)

	is_open = true
	is_opening = false

	disable_gate_collision()

	if not LevelManager.get_game_flag(get_bat_spawn_flag()):
		LevelManager.set_game_flag(get_bat_spawn_flag(), true)
		await spawn_bats_from_gate()


func set_closed_state() -> void:
	is_open = false
	is_opening = false

	if gate_body != null:
		gate_body.process_mode = Node.PROCESS_MODE_INHERIT

	if animation_player != null:
		animation_player.stop()


func set_opened_immediate() -> void:
	is_open = true
	is_opening = false

	disable_gate_collision()

	if animation_player != null and animation_player.has_animation(open_animation_name):
		animation_player.play(open_animation_name)

		var anim_length: float = animation_player.current_animation_length
		if anim_length > 0.0:
			animation_player.seek(anim_length, true)

		animation_player.pause()


func disable_gate_collision() -> void:
	if gate_body == null:
		return

	for child in gate_body.get_children():
		if child is CollisionShape2D:
			child.disabled = true

	gate_body.process_mode = Node.PROCESS_MODE_DISABLED


func spawn_bats_from_gate() -> void:
	if bat_scene == null:
		push_warning(name + " chưa gán Bat Scene.")
		return

	if bat_spawn_sound != null:
		bat_spawn_sound.stop()
		bat_spawn_sound.play()

	var spawn_parent: Node = get_tree().current_scene

	if spawn_parent == null:
		spawn_parent = get_parent()

	var base_position: Vector2 = global_position

	if bat_spawn_point != null:
		base_position = bat_spawn_point.global_position

	for i in range(bat_count):
		var bat: Node = bat_scene.instantiate()
		spawn_parent.add_child(bat)

		var angle: float = (TAU / float(bat_count)) * float(i)
		angle += randf_range(-0.35, 0.35)

		var speed: float = randf_range(bat_burst_speed_min, bat_burst_speed_max)
		var burst_velocity: Vector2 = Vector2(cos(angle), sin(angle)) * speed

		burst_velocity.y -= randf_range(40.0, 90.0)

		if bat is Node2D:
			var random_offset := Vector2(
				randf_range(-bat_spawn_random_x, bat_spawn_random_x),
				randf_range(-bat_spawn_random_y, bat_spawn_random_y)
			)

			(bat as Node2D).global_position = base_position + random_offset

		if bat.has_method("start_spawn_burst"):
			bat.start_spawn_burst(burst_velocity, bat_burst_time)
		elif bat is CharacterBody2D:
			(bat as CharacterBody2D).velocity = burst_velocity

		await get_tree().create_timer(bat_spawn_delay).timeout
