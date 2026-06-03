extends Node

@export var default_point_radius: float = 85.0
@export var default_player_distance: float = 140.0

var message_layer: CanvasLayer = null
var message_label: Label = null
var message_tween: Tween = null
var last_message_msec: int = 0
var message_cooldown_msec: int = 900


func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


func get_players() -> Array[Player]:
	var result: Array[Player] = []
	var nodes := get_tree().get_nodes_in_group("players")

	for n in nodes:
		if n == null:
			continue

		if !is_instance_valid(n):
			continue

		if n is Player:
			result.append(n as Player)

	return result


func can_use_team_point(
	point_position: Vector2,
	point_radius: float = -1.0,
	player_distance: float = -1.0
) -> bool:
	if !is_two_player_mode():
		return true

	if point_radius <= 0.0:
		point_radius = default_point_radius

	if player_distance <= 0.0:
		player_distance = default_player_distance

	var players := get_players()

	if players.size() < 2:
		return false

	var p1: Player = null
	var p2: Player = null

	for p in players:
		if int(p.get("player_id")) == 1:
			p1 = p
		elif int(p.get("player_id")) == 2:
			p2 = p

	if p1 == null or p2 == null:
		return false

	if p1.is_dead or p2.is_dead:
		return false

	var p1_near_point: bool = p1.global_position.distance_to(point_position) <= point_radius
	var p2_near_point: bool = p2.global_position.distance_to(point_position) <= point_radius

	if !p1_near_point or !p2_near_point:
		return false

	var players_close: bool = p1.global_position.distance_to(p2.global_position) <= player_distance

	if !players_close:
		return false

	return true


func show_team_required_message(text_value: String = "") -> void:
	var now := Time.get_ticks_msec()

	if now - last_message_msec < message_cooldown_msec:
		return

	last_message_msec = now

	if text_value == "":
		text_value = "Cả hai cần đứng gần nhau để tiếp tục.\nĐừng bỏ lại đồng đội của mình."

	ensure_message_ui()

	if message_label == null:
		return

	message_label.text = text_value
	message_label.visible = true
	message_label.modulate.a = 0.0

	if message_tween != null:
		message_tween.kill()

	message_tween = create_tween()
	message_tween.tween_property(message_label, "modulate:a", 1.0, 0.25)
	message_tween.tween_interval(2.0)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.35)

	await message_tween.finished

	if message_label != null:
		message_label.visible = false


func ensure_message_ui() -> void:
	if message_layer != null and is_instance_valid(message_layer):
		return

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	message_layer = CanvasLayer.new()
	message_layer.name = "CoopRequiredMessageUI"
	message_layer.layer = 2000
	current_scene.add_child(message_layer)

	message_label = Label.new()
	message_label.name = "CoopRequiredMessageLabel"
	message_layer.add_child(message_label)

	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.offset_left = -180
	message_label.offset_right = 180
	message_label.offset_top = 32
	message_label.offset_bottom = 88

	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	message_label.add_theme_font_size_override("font_size", 10)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 2)

	message_label.visible = false
	message_label.modulate.a = 0.0
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
