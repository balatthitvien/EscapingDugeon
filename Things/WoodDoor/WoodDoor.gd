extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var open_sound: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea") as Area2D
@onready var talk_indicator: Node2D = get_node_or_null("TalkIndicator") as Node2D

@export var door_id: String = "wood_door_1"

@export var open_animation_name: String = "Open"
@export var interact_action: String = "interact"

@export var required_chest_id: String = "master_key_chest_map_3"
@export var locked_message: String = "Bạn thiếu chìa khóa vạn năng"

@export_file("*.tscn") var target_scene_path: String = ""
@export var target_spawn_point_name: String = ""

@export var fade_out_time: float = 0.7
@export var fade_in_time: float = 0.7
@export var transition_lock_extra_time: float = 0.5

@export var save_open_state: bool = true

var player_in_range: bool = false
var player: Player = null
var is_opened: bool = false
var is_opening: bool = false
var is_changing_scene: bool = false

var message_layer: CanvasLayer
var message_label: Label
var message_tween: Tween = null


func _ready() -> void:
	if talk_indicator != null:
		talk_indicator.visible = false

	if interaction_area == null:
		push_warning(name + " thiếu InteractionArea. Hãy thêm Area2D tên InteractionArea.")
	else:
		interaction_area.monitoring = true
		interaction_area.monitorable = true

		if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
			interaction_area.body_entered.connect(_on_interaction_area_body_entered)

		if not interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
			interaction_area.body_exited.connect(_on_interaction_area_body_exited)

		if not interaction_area.area_entered.is_connected(_on_interaction_area_area_entered):
			interaction_area.area_entered.connect(_on_interaction_area_area_entered)

		if not interaction_area.area_exited.is_connected(_on_interaction_area_area_exited):
			interaction_area.area_exited.connect(_on_interaction_area_area_exited)

		call_deferred("refresh_player_in_range_after_spawn")

	create_message_ui()

	if save_open_state and LevelManager.get_game_flag(get_open_flag_name()):
		set_opened_immediate()
	else:
		is_opened = false


func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if is_opening:
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
		await try_use_door()


func try_use_door() -> void:
	if is_opening:
		return

	if is_changing_scene:
		return

	if not has_required_key():
		show_bottom_message(locked_message)
		return

	if not is_opened:
		await open_door_only()
		return

	await change_to_target_scene()


func has_required_key() -> bool:
	if required_chest_id == "":
		return true

	return LevelManager.is_chest_opened(required_chest_id)


func open_door_only() -> void:
	if is_opening:
		return

	is_opening = true
	is_opened = true

	if save_open_state:
		LevelManager.set_game_flag(get_open_flag_name(), true)

	if talk_indicator != null:
		talk_indicator.visible = false

	play_open_sound()

	if animation_player != null and animation_player.has_animation(open_animation_name):
		animation_player.play(open_animation_name)
		await animation_player.animation_finished
	else:
		push_warning(name + " thiếu animation: " + open_animation_name)

	is_opening = false

	if player_in_range and talk_indicator != null:
		talk_indicator.visible = true

	show_bottom_message("Cửa đã mở. Ấn E lần nữa để đi tiếp.")


func set_opened_immediate() -> void:
	is_opened = true
	is_opening = false

	if animation_player != null and animation_player.has_animation(open_animation_name):
		animation_player.play(open_animation_name)

		var anim_length: float = animation_player.current_animation_length
		animation_player.seek(anim_length, true)
		animation_player.stop()


func play_open_sound() -> void:
	if open_sound == null:
		return

	if open_sound.stream == null:
		return

	open_sound.stop()
	open_sound.bus = "SFX"
	open_sound.play()


func change_to_target_scene() -> void:
	if is_changing_scene:
		return

	if not LevelManager.can_use_map_transition():
		return

	if target_scene_path == "":
		show_bottom_message("Cửa đã mở, nhưng chưa gán map đích.")
		return

	is_changing_scene = true

	if talk_indicator != null:
		talk_indicator.visible = false

	if target_spawn_point_name != "":
		LevelManager.set_next_spawn_point(target_spawn_point_name)

	if player != null:
		player.set_control_enabled(false)

	LevelManager.lock_map_transition(fade_out_time + fade_in_time + transition_lock_extra_time)

	await SceneTransition.change_scene_with_fade(
		target_scene_path,
		fade_out_time,
		fade_in_time
	)


func refresh_player_in_range_after_spawn() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

	if interaction_area == null:
		return

	if is_changing_scene:
		return

	for body in interaction_area.get_overlapping_bodies():
		try_set_player(body)

	for area in interaction_area.get_overlapping_areas():
		try_set_player(area)

		if area.get_parent() != null:
			try_set_player(area.get_parent())


func get_open_flag_name() -> String:
	return "wood_door_opened_" + door_id


func create_message_ui() -> void:
	message_layer = CanvasLayer.new()
	message_layer.layer = 1000
	add_child(message_layer)

	message_label = Label.new()
	message_layer.add_child(message_label)

	message_label.visible = false
	message_label.text = ""
	message_label.modulate.a = 0.0

	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	message_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.offset_left = -330
	message_label.offset_right = 330
	message_label.offset_top = -55
	message_label.offset_bottom = -15

	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 2)


func show_bottom_message(text: String) -> void:
	if message_label == null:
		return

	if message_tween != null:
		message_tween.kill()

	message_label.text = text
	message_label.visible = true
	message_label.modulate.a = 0.0

	message_tween = create_tween()
	message_tween.tween_property(message_label, "modulate:a", 1.0, 0.2)
	message_tween.tween_interval(1.8)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.3)

	await message_tween.finished

	message_label.visible = false


func _on_interaction_area_body_entered(body: Node2D) -> void:
	try_set_player(body)


func _on_interaction_area_body_exited(body: Node2D) -> void:
	try_remove_player(body)


func _on_interaction_area_area_entered(area: Area2D) -> void:
	try_set_player(area)

	if area.get_parent() != null:
		try_set_player(area.get_parent())


func _on_interaction_area_area_exited(area: Area2D) -> void:
	try_remove_player(area)

	if area.get_parent() != null:
		try_remove_player(area.get_parent())


func try_set_player(target: Node) -> void:
	var detected_player: Player = find_player_from_node(target)

	if detected_player == null:
		return

	player = detected_player
	player_in_range = true

	if talk_indicator != null and not is_changing_scene:
		talk_indicator.visible = true


func try_remove_player(target: Node) -> void:
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
