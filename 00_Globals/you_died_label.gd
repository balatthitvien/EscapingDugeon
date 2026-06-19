extends CanvasLayer

const YOU_DIED_FONT := preload("res://00_Globals/OptimusPrinceps.ttf")

@export var respawn_scene_path: String = "res://level/testlevel/map_1/map_1.tscn"

@onready var dark_background: ColorRect = $DarkBackground
@onready var label: Label = $YouDiedLabel

var tween: Tween
var can_click_respawn: bool = false
var is_respawning: bool = false
var is_showing_you_died: bool = false


func _ready() -> void:
	layer = 100
	visible = false
	can_click_respawn = false
	is_respawning = false
	is_showing_you_died = false

	setup_layout()


func setup_layout() -> void:
	dark_background.set_anchors_preset(Control.PRESET_CENTER)
	dark_background.offset_left = -500
	dark_background.offset_right = 500
	dark_background.offset_top = -45
	dark_background.offset_bottom = 45
	dark_background.color = Color(0, 0, 0, 0.0)

	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -400
	label.offset_right = 400
	label.offset_top = -55
	label.offset_bottom = 55

	label.text = "YOU DIED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	label.add_theme_font_override("font", YOU_DIED_FONT)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(0.65, 0.0, 0.03))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 2)

	label.modulate.a = 0.0


func show_you_died() -> void:
	if is_showing_you_died:
		return

	is_showing_you_died = true

	print("SHOW YOU DIED UI")

	set_all_players_control_enabled(false)

	visible = true
	layer = 100
	can_click_respawn = false
	is_respawning = false

	dark_background.color = Color(0, 0, 0, 0.0)
	label.modulate.a = 0.0
	label.scale = Vector2(0.98, 0.98)

	if tween:
		tween.kill()

	tween = create_tween()

	tween.tween_property(
		dark_background,
		"color",
		Color(0, 0, 0, 0.68),
		0.9
	)

	tween.parallel().tween_property(
		label,
		"modulate:a",
		1.0,
		1.2
	)

	tween.parallel().tween_property(
		label,
		"scale",
		Vector2(1.0, 1.0),
		1.2
	)

	await tween.finished

	can_click_respawn = true
	print("CAN CLICK RESPAWN NOW")


func _input(event: InputEvent) -> void:
	if !visible:
		return

	if !can_click_respawn:
		return

	if is_respawning:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_respawning = true
			can_click_respawn = false

			get_viewport().set_input_as_handled()

			set_all_players_control_enabled(false)

			# Vì bạn dùng chung máu / EXP / coin / bình máu,
			# chỉ cần lưu stats từ PlayerManager.player.
			PlayerManager.prepare_respawn_stats()

			await hide_you_died_ui()

			MusicManager.stop_boss_music()

			var target_scene_path: String = LevelManager.get_saved_respawn_scene_path(respawn_scene_path)
			var target_spawn_point_name: String = LevelManager.get_saved_respawn_spawn_point_name()

			if target_spawn_point_name != "":
				LevelManager.set_next_spawn_point(target_spawn_point_name)

			await SceneTransition.change_scene_with_fade(
				target_scene_path,
				1.0,
				0.8
			)


func hide_you_died_ui() -> void:
	if tween:
		tween.kill()

	tween = create_tween()

	tween.tween_property(
		label,
		"modulate:a",
		0.0,
		0.45
	)

	tween.parallel().tween_property(
		dark_background,
		"color",
		Color(0, 0, 0, 0.0),
		0.45
	)

	await tween.finished

	visible = false
	is_showing_you_died = false


func set_all_players_control_enabled(state: bool) -> void:
	if is_two_player_mode():
		var players := get_tree().get_nodes_in_group("players")

		for p in players:
			if p == null:
				continue

			if !is_instance_valid(p):
				continue

			if p.has_method("set_control_enabled"):
				p.set_control_enabled(state)

			if has_object_property(p, "can_control"):
				p.set("can_control", state)

			if !state and has_object_property(p, "velocity"):
				var current_velocity: Vector2 = p.get("velocity")
				current_velocity.x = 0.0
				p.set("velocity", current_velocity)

			if !state and p.has_method("stop_hurt_box"):
				p.stop_hurt_box()

		return

	if PlayerManager.player != null and is_instance_valid(PlayerManager.player):
		if PlayerManager.player.has_method("set_control_enabled"):
			PlayerManager.player.set_control_enabled(state)

		if has_object_property(PlayerManager.player, "can_control"):
			PlayerManager.player.set("can_control", state)


func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


func has_object_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == prop_name:
			return true

	return false
