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
var players_near: Dictionary = {}

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
	if !player_in_range:
		return

	if is_pulled:
		return

	if is_using:
		return

	var action_player := get_player_pressed_interact_event(event)

	if action_player == null:
		return

	player = action_player
	get_viewport().set_input_as_handled()

	await pull_lever(action_player)


func pull_lever(action_player: Player = null) -> void:
	if is_pulled:
		return

	is_using = true
	is_pulled = true

	if action_player != null:
		player = action_player

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
	players_near.clear()
	player_in_range = false
	player = null

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

	players_near[detected_player.get_instance_id()] = detected_player
	player_in_range = !players_near.is_empty()
	player = detected_player

	if talk_indicator != null and !is_pulled:
		talk_indicator.visible = true


func try_remove_player_from_range(target: Node) -> void:
	var detected_player: Player = find_player_from_node(target)

	if detected_player == null:
		return

	var id := detected_player.get_instance_id()

	if players_near.has(id):
		players_near.erase(id)

	player_in_range = !players_near.is_empty()

	if player == detected_player:
		player = get_any_near_player()

	if !player_in_range and talk_indicator != null:
		talk_indicator.visible = false


func get_any_near_player() -> Player:
	for key in players_near.keys():
		var p: Player = players_near[key]

		if p != null and is_instance_valid(p):
			return p

	return null


func get_player_pressed_interact_event(event: InputEvent) -> Player:
	for key in players_near.keys():
		var p: Player = players_near[key]

		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_method("is_interact_event_pressed"):
			if p.is_interact_event_pressed(event):
				return p
		else:
			var action_name := get_interact_action_for_player(p)

			if event.is_action_pressed(action_name):
				return p

	return null


func get_interact_action_for_player(target_player: Player) -> StringName:
	if !is_two_player_mode():
		return &"interact"

	var id_value: int = int(target_player.get("player_id"))

	if id_value == 1:
		return &"p1_interact"

	return &"p2_interact"


func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


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
