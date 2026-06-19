extends CanvasLayer

var fade_rect: ColorRect
var top_mask: ColorRect
var bottom_mask: ColorRect

var is_transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	layer = 999
	create_transition_nodes()
	reset_transition()
	set_transition_input_blocker_enabled(false)


func create_transition_nodes() -> void:
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	add_child(fade_rect)

	top_mask = ColorRect.new()
	top_mask.name = "TopMask"
	add_child(top_mask)

	bottom_mask = ColorRect.new()
	bottom_mask.name = "BottomMask"
	add_child(bottom_mask)

	for rect in [fade_rect, top_mask, bottom_mask]:
		rect.color = Color.BLACK
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.visible = true

	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.offset_left = 0
	fade_rect.offset_top = 0
	fade_rect.offset_right = 0
	fade_rect.offset_bottom = 0


func reset_transition() -> void:
	fade_rect.modulate.a = 0.0

	top_mask.modulate.a = 0.0
	bottom_mask.modulate.a = 0.0

	top_mask.position = Vector2.ZERO
	bottom_mask.position = Vector2.ZERO
	top_mask.size = Vector2.ZERO
	bottom_mask.size = Vector2.ZERO


func get_screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func fade_to_black(duration: float = 1.0) -> void:
	reset_transition()

	var tween := create_transition_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, duration)

	await tween.finished


func fade_from_black(duration: float = 1.0) -> void:
	fade_rect.modulate.a = 1.0

	var tween := create_transition_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration)

	await tween.finished

	reset_transition()
func change_scene_with_fade(
	scene_path: String,
	fade_out_time: float = 1.0,
	fade_in_time: float = 1.0,
	freeze_hold_time: float = 0.12
) -> void:
	if is_transitioning:
		return

	is_transitioning = true
	set_transition_input_blocker_enabled(true)
	release_gameplay_actions()
	lock_players_for_transition()

	get_tree().paused = true

	if freeze_hold_time > 0.0:
		var freeze_timer := get_tree().create_timer(freeze_hold_time, true, false, true)
		await freeze_timer.timeout

	await fade_to_black(fade_out_time)

	release_gameplay_actions()

	get_tree().paused = false

	var error := get_tree().change_scene_to_file(scene_path)

	if error != OK:
		push_error("SceneTransition: Không thể chuyển scene: " + scene_path)
		is_transitioning = false
		set_transition_input_blocker_enabled(false)
		release_gameplay_actions()
		return

	await get_tree().process_frame
	await get_tree().process_frame

	lock_players_for_transition()
	release_gameplay_actions()

	if LevelManager.is_map_1_scene(scene_path) and LevelManager.consume_map_1_eye_open_once():
		await open_eye_transition()
	else:
		await fade_from_black(fade_in_time)

	release_gameplay_actions()
	unlock_players_after_transition()

	set_transition_input_blocker_enabled(false)
	is_transitioning = false
func setup_full_black_eye() -> void:
	var screen_size := get_screen_size()
	var w := screen_size.x
	var h := screen_size.y

	fade_rect.modulate.a = 0.0

	top_mask.modulate.a = 1.0
	bottom_mask.modulate.a = 1.0

	top_mask.position = Vector2(0, 0)
	top_mask.size = Vector2(w, h * 0.5)

	bottom_mask.position = Vector2(0, h * 0.5)
	bottom_mask.size = Vector2(w, h * 0.5)


func open_eye_transition() -> void:
	var screen_size := get_screen_size()
	var w := screen_size.x
	var h := screen_size.y

	setup_full_black_eye()

	# Lần 1: hé mắt rất nhỏ như vừa tỉnh
	var tween_1 := create_tween()
	tween_1.set_parallel(true)

	tween_1.tween_property(top_mask, "size", Vector2(w, h * 0.43), 0.45)
	tween_1.tween_property(bottom_mask, "position", Vector2(0, h * 0.57), 0.45)
	tween_1.tween_property(bottom_mask, "size", Vector2(w, h * 0.43), 0.45)

	await tween_1.finished
	await get_tree().create_timer(0.15).timeout

	# Nhắm lại lần 1
	var close_1 := create_tween()
	close_1.set_parallel(true)

	close_1.tween_property(top_mask, "size", Vector2(w, h * 0.5), 0.28)
	close_1.tween_property(bottom_mask, "position", Vector2(0, h * 0.5), 0.28)
	close_1.tween_property(bottom_mask, "size", Vector2(w, h * 0.5), 0.28)

	await close_1.finished
	await get_tree().create_timer(0.2).timeout

	# Lần 2: mở lớn hơn, thấy khoảng giữa màn hình
	var tween_2 := create_tween()
	tween_2.set_parallel(true)

	tween_2.tween_property(top_mask, "size", Vector2(w, h * 0.30), 0.65)
	tween_2.tween_property(bottom_mask, "position", Vector2(0, h * 0.70), 0.65)
	tween_2.tween_property(bottom_mask, "size", Vector2(w, h * 0.30), 0.65)

	await tween_2.finished
	await get_tree().create_timer(0.18).timeout

	# Nhắm nhẹ lại lần 2
	var close_2 := create_tween()
	close_2.set_parallel(true)

	close_2.tween_property(top_mask, "size", Vector2(w, h * 0.38), 0.25)
	close_2.tween_property(bottom_mask, "position", Vector2(0, h * 0.62), 0.25)
	close_2.tween_property(bottom_mask, "size", Vector2(w, h * 0.38), 0.25)

	await close_2.finished
	await get_tree().create_timer(0.12).timeout

	# Mở hẳn
	var open_final := create_tween()
	open_final.set_parallel(true)

	open_final.tween_property(top_mask, "size", Vector2(w, 0), 0.9)
	open_final.tween_property(bottom_mask, "position", Vector2(0, h), 0.9)
	open_final.tween_property(bottom_mask, "size", Vector2(w, 0), 0.9)

	await open_final.finished

	reset_transition()
func change_scene_with_eye_open(
	scene_path: String,
	fade_out_time: float = 1.0
) -> void:
	if is_transitioning:
		return

	is_transitioning = true
	set_transition_input_blocker_enabled(true)
	release_gameplay_actions()
	lock_players_for_transition()

	await fade_to_black(fade_out_time)

	release_gameplay_actions()

	var error := get_tree().change_scene_to_file(scene_path)

	if error != OK:
		push_error("SceneTransition: Không thể chuyển scene: " + scene_path)
		is_transitioning = false
		set_transition_input_blocker_enabled(false)
		release_gameplay_actions()
		return

	await get_tree().process_frame
	await get_tree().process_frame

	lock_players_for_transition()
	release_gameplay_actions()

	await open_eye_transition()

	release_gameplay_actions()
	unlock_players_after_transition()

	set_transition_input_blocker_enabled(false)
	is_transitioning = false
func create_transition_tween() -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween
func _input(_event: InputEvent) -> void:
	if is_transitioning:
		get_viewport().set_input_as_handled()


func set_transition_input_blocker_enabled(enabled: bool) -> void:
	var filter_value := Control.MOUSE_FILTER_IGNORE

	if enabled:
		filter_value = Control.MOUSE_FILTER_STOP

	for rect in [fade_rect, top_mask, bottom_mask]:
		if rect != null:
			rect.mouse_filter = filter_value


func release_gameplay_actions() -> void:
	var actions := [
		"move_left",
		"move_right",
		"jump",
		"attack",
		"interact",
		"use_potion",
		"shoot_arrow",
		"item_prev",
		"item_next",

		"p1_move_left",
		"p1_move_right",
		"p1_jump",
		"p1_attack",
		"p1_interact",
		"p1_heal",
		"p1_shoot_arrow",
		"p1_dialog_next",
		"p1_dialog_skip",

		"p2_move_left",
		"p2_move_right",
		"p2_jump",
		"p2_attack",
		"p2_interact",
		"p2_heal",
		"p2_shoot_arrow"
	]

	for action in actions:
		if InputMap.has_action(action):
			Input.action_release(action)

	Input.flush_buffered_events()


func lock_players_for_transition() -> void:
	var players := get_tree().get_nodes_in_group("players")

	for p in players:
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_method("cancel_attack_state"):
			p.cancel_attack_state()

		if p.has_method("stop_hurt_box"):
			p.stop_hurt_box()

		if has_object_property(p, "can_control"):
			p.set("can_control", false)

		if has_object_property(p, "velocity"):
			var current_velocity: Vector2 = p.get("velocity")
			current_velocity.x = 0.0
			p.set("velocity", current_velocity)


func unlock_players_after_transition() -> void:
	var players := get_tree().get_nodes_in_group("players")

	for p in players:
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if has_object_property(p, "is_dead") and bool(p.get("is_dead")):
			continue

		if has_object_property(p, "is_shooting_arrow"):
			p.set("is_shooting_arrow", false)

		if has_object_property(p, "is_using_potion"):
			p.set("is_using_potion", false)

		if has_object_property(p, "attack_cooldown"):
			p.set("attack_cooldown", false)

		if has_object_property(p, "is_hurt"):
			p.set("is_hurt", false)

		if has_object_property(p, "hurt_timer"):
			p.set("hurt_timer", 0.0)

		if p.has_method("stop_hurt_box"):
			p.stop_hurt_box()

		if p.has_method("set_control_enabled"):
			p.set_control_enabled(true)
		elif has_object_property(p, "can_control"):
			p.set("can_control", true)


func has_object_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == prop_name:
			return true

	return false
