extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var lever_sound: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea") as Area2D
@onready var talk_indicator: Sprite2D = get_node_or_null("TalkIndicator") as Sprite2D

@export var lever_id: String = "map_3_lever_1"
@export var open_animation_name: String = "Open"
@export var target_gate_path: NodePath

var player_in_range: bool = false
var player: Player = null
var is_pulled: bool = false
var is_using: bool = false


func _ready() -> void:
	if talk_indicator != null:
		talk_indicator.visible = false
		talk_indicator.z_index = 100
		talk_indicator.z_as_relative = false

	if interaction_area == null:
		push_warning(name + " thiếu InteractionArea.")
	else:
		interaction_area.monitoring = true
		interaction_area.monitorable = true

		if not interaction_area.body_entered.is_connected(_on_body_entered):
			interaction_area.body_entered.connect(_on_body_entered)

		if not interaction_area.body_exited.is_connected(_on_body_exited):
			interaction_area.body_exited.connect(_on_body_exited)

		if not interaction_area.area_entered.is_connected(_on_area_entered):
			interaction_area.area_entered.connect(_on_area_entered)

		if not interaction_area.area_exited.is_connected(_on_area_exited):
			interaction_area.area_exited.connect(_on_area_exited)

	if LevelManager.get_game_flag(get_pulled_flag()):
		set_pulled_immediate()
	else:
		set_not_pulled_state()


func get_pulled_flag() -> String:
	return lever_id + "_pulled"


func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if is_pulled:
		return

	if is_using:
		return

	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		await pull_lever()


func pull_lever() -> void:
	if is_pulled:
		return

	is_using = true
	is_pulled = true

	LevelManager.set_game_flag(get_pulled_flag(), true)

	if talk_indicator != null:
		talk_indicator.visible = false

	if lever_sound != null:
		lever_sound.stop()
		lever_sound.play()

	if animation_player != null and animation_player.has_animation(open_animation_name):
		animation_player.play(open_animation_name)
		await animation_player.animation_finished
	else:
		push_warning(name + " thiếu animation: " + open_animation_name)

	var gate := get_target_gate()

	if gate != null and gate.has_method("open_gate_once"):
		await gate.open_gate_once()
	else:
		push_warning(name + " chưa tìm thấy StoneGate hoặc StoneGate thiếu open_gate_once().")

	is_using = false


func set_not_pulled_state() -> void:
	is_pulled = false
	is_using = false

	if animation_player != null:
		animation_player.stop()


func set_pulled_immediate() -> void:
	is_pulled = true
	is_using = false

	if talk_indicator != null:
		talk_indicator.visible = false

	if animation_player != null and animation_player.has_animation(open_animation_name):
		animation_player.play(open_animation_name)

		var anim_length: float = animation_player.current_animation_length
		if anim_length > 0.0:
			animation_player.seek(anim_length, true)

		animation_player.pause()


func get_target_gate() -> Node:
	if target_gate_path == NodePath(""):
		return null

	return get_node_or_null(target_gate_path)


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

	if talk_indicator != null and not is_pulled:
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
