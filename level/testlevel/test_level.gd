extends Node2D

@onready var boss: Enemy = $World/Enemy
@onready var boss_health_bar = $BossHealthBar
@onready var story_dialog = $StoryDialog
@onready var you_died_ui = $YouDiedUI

@export var mouse_left_texture: Texture2D

# Flag để Portal biết boss đã chết.
@export var boss_defeated_flag_name: String = "test_level_new_boss_killed"

# Flag này dùng để Portal hiển thị thẳng bảng "Rời khỏi đây".
@export var portal_leave_flag_name: String = "test_level_new_can_leave"

# Thời gian chờ trước khi hiện hội thoại đầu.
@export var intro_start_delay: float = 2.5

var player: Player

var tutorial_layer: CanvasLayer
var tutorial_root: Control
var tutorial_tween: Tween = null

var has_shown_tutorial_hint: bool = false
var has_handled_player_death: bool = false
var has_handled_boss_death: bool = false

var is_intro_running: bool = false
var has_started_intro: bool = false


func _ready() -> void:
	print("TestLevel ready")

	create_tutorial_hint_ui()

	# Tìm và khóa Player càng sớm càng tốt.
	find_player()

	if player != null:
		start_force_lock_intro()

	await get_tree().process_frame
	await get_tree().process_frame

	# Tìm lại sau vài frame để chắc chắn PlayerManager đã cập nhật.
	find_player()

	if player == null:
		push_error("Không tìm thấy Player. Kiểm tra node Player trong test_level_new.")
		return

	print("Player found: ", player)

	start_force_lock_intro()

	await connect_player_signals()
	connect_boss_signals()
	setup_boss_health_bar()
	connect_story_dialog_signal()

	await run_intro_story()


func _physics_process(_delta: float) -> void:
	if is_intro_running:
		force_lock_player()


func find_player() -> void:
	player = get_node_or_null("World/Player") as Player

	if player == null:
		player = get_node_or_null("Player") as Player

	if player == null:
		player = PlayerManager.player

func get_all_players() -> Array:
	return get_tree().get_nodes_in_group("players")
func start_force_lock_intro() -> void:
	is_intro_running = true
	force_lock_player()


func force_lock_player() -> void:
	var players := get_all_players()

	if players.is_empty():
		if player == null:
			player = PlayerManager.player

		if player != null:
			players.append(player)

	for p in players:
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_method("set_control_enabled"):
			p.set_control_enabled(false)

		if has_object_property(p, "can_control"):
			p.set("can_control", false)

		if has_object_property(p, "velocity"):
			var current_velocity: Vector2 = p.get("velocity")
			current_velocity.x = 0.0
			p.set("velocity", current_velocity)


func unlock_player_after_intro() -> void:
	is_intro_running = false

	var players := get_all_players()

	if players.is_empty():
		if player == null:
			player = PlayerManager.player

		if player != null:
			players.append(player)

	for p in players:
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_method("set_control_enabled"):
			p.set_control_enabled(true)

		if has_object_property(p, "can_control"):
			p.set("can_control", true)

func run_intro_story() -> void:
	if has_started_intro:
		return

	has_started_intro = true

	start_force_lock_intro()

	await get_tree().create_timer(intro_start_delay).timeout

	force_lock_player()

	if story_dialog == null:
		push_warning("test_level_new: Không tìm thấy StoryDialog, mở khóa Player.")
		unlock_player_after_intro()
		return

	if not story_dialog.has_method("start_story"):
		push_warning("test_level_new: StoryDialog không có hàm start_story(), mở khóa Player.")
		unlock_player_after_intro()
		return

	story_dialog.start_story([
		"Mình đang ở đâu vậy? Tại sao mình lại ở đây?",
		"Mình phải tìm đường ra khỏi đây ngay."
	])


func connect_player_signals() -> void:
	if is_two_player_mode():
		await get_tree().process_frame
		await get_tree().process_frame

		var players := get_players()

		for p in players:
			if p == null:
				continue

			if !is_instance_valid(p):
				continue

			if p.has_signal("died"):
				if not p.died.is_connected(_on_player_died):
					p.died.connect(_on_player_died)

		return

	# Chế độ 1 người chơi giữ logic cũ.
	if player == null:
		return

	if player.has_signal("died"):
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)

func connect_boss_signals() -> void:
	if boss == null:
		push_warning("test_level_new: Không tìm thấy boss World/Enemy.")
		return

	if boss.has_signal("boss_started"):
		if not boss.boss_started.is_connected(_on_boss_started):
			boss.boss_started.connect(_on_boss_started)

	if boss.has_signal("health_changed"):
		if not boss.health_changed.is_connected(_on_boss_health_changed):
			boss.health_changed.connect(_on_boss_health_changed)

	if boss.has_signal("died"):
		if not boss.died.is_connected(_on_boss_died):
			boss.died.connect(_on_boss_died)


func setup_boss_health_bar() -> void:
	if boss == null:
		return

	if boss_health_bar == null:
		return

	boss_health_bar.setup(boss.max_health)
	boss_health_bar.update_health(boss.current_health, boss.max_health)


func connect_story_dialog_signal() -> void:
	if story_dialog == null:
		return

	if story_dialog.has_signal("story_finished"):
		if not story_dialog.story_finished.is_connected(_on_story_finished):
			story_dialog.story_finished.connect(_on_story_finished)


func _on_player_died() -> void:
	if has_handled_player_death:
		return

	has_handled_player_death = true

	print("PLAYER DIED - SHOW YOU DIED")

	force_game_over_lock_players()

	await get_tree().create_timer(1.0).timeout

	if you_died_ui != null:
		you_died_ui.show_you_died()

func _on_boss_started() -> void:
	print("Boss bar show")

	if boss_health_bar != null:
		boss_health_bar.show_bar()

	MusicManager.play_boss_music()


func _on_boss_health_changed(current_health: int, max_health: int) -> void:
	print("Update Boss Bar: ", current_health, "/", max_health)

	if boss_health_bar != null:
		boss_health_bar.update_health(current_health, max_health)


func _on_boss_died() -> void:
	if has_handled_boss_death:
		return

	has_handled_boss_death = true

	print("test_level_new: Boss died, unlock portal.")

	if boss_health_bar != null:
		boss_health_bar.hide_bar()

	MusicManager.stop_boss_music()

	# Mở khóa Portal.
	LevelManager.set_game_flag(boss_defeated_flag_name, true)

	# Cho phép Portal hiện thẳng UI "Rời khỏi đây".
	LevelManager.set_game_flag(portal_leave_flag_name, true)


func _on_story_finished() -> void:
	unlock_player_after_intro()
	show_tutorial_hint_once()


func create_tutorial_hint_ui() -> void:
	tutorial_layer = CanvasLayer.new()
	tutorial_layer.name = "TutorialHintUI"
	tutorial_layer.layer = 1000
	add_child(tutorial_layer)

	tutorial_root = Control.new()
	tutorial_root.name = "TutorialRoot"
	tutorial_layer.add_child(tutorial_root)

	tutorial_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tutorial_root.modulate.a = 0.0
	tutorial_root.visible = false

	if is_two_player_mode():
		create_two_player_tutorial_ui()
	else:
		create_single_player_tutorial_ui()

	set_mouse_filter_ignore_recursive(tutorial_root)

func create_single_player_tutorial_ui() -> void:
	tutorial_root.offset_left = 90
	tutorial_root.offset_top = 90
	tutorial_root.offset_right = 520
	tutorial_root.offset_bottom = 250

	var vbox := VBoxContainer.new()
	vbox.name = "HintVBox"
	tutorial_root.add_child(vbox)

	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 0
	vbox.offset_top = 0
	vbox.offset_right = 0
	vbox.offset_bottom = 0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)

	vbox.add_child(create_hint_label("A-D để di chuyển", 18))
	vbox.add_child(create_hint_label("Space để nhảy", 18))
	vbox.add_child(create_mouse_attack_row("để tấn công", 18))
func create_two_player_tutorial_ui() -> void:
	tutorial_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_root.offset_left = 0
	tutorial_root.offset_top = 0
	tutorial_root.offset_right = 0
	tutorial_root.offset_bottom = 0

	var hbox := HBoxContainer.new()
	hbox.name = "TwoPlayerHintHBox"
	tutorial_root.add_child(hbox)

	# Viewport game của bạn là 480x270,
	# nên khung này phải nằm gọn trong khoảng ngang 480.
	hbox.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hbox.offset_left = -220
	hbox.offset_right = 220
	hbox.offset_top = 55
	hbox.offset_bottom = 185

	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)

	var p1_box := VBoxContainer.new()
	p1_box.name = "Player1HintBox"
	p1_box.custom_minimum_size = Vector2(200, 130)
	p1_box.alignment = BoxContainer.ALIGNMENT_CENTER
	p1_box.add_theme_constant_override("separation", 4)
	hbox.add_child(p1_box)

	p1_box.add_child(create_hint_label("PLAYER 1", 12, Color(1.0, 0.78, 0.25)))
	p1_box.add_child(create_hint_label("A-D để di chuyển", 10))
	p1_box.add_child(create_hint_label("W để nhảy", 10))
	p1_box.add_child(create_hint_label("J để tấn công", 10))

	var p2_box := VBoxContainer.new()
	p2_box.name = "Player2HintBox"
	p2_box.custom_minimum_size = Vector2(200, 130)
	p2_box.alignment = BoxContainer.ALIGNMENT_CENTER
	p2_box.add_theme_constant_override("separation", 4)
	hbox.add_child(p2_box)

	p2_box.add_child(create_hint_label("PLAYER 2", 12, Color(1.0, 0.78, 0.25)))
	p2_box.add_child(create_hint_label("← / → để di chuyển", 10))
	p2_box.add_child(create_hint_label("↑ để nhảy", 10))
	p2_box.add_child(create_mouse_attack_row("để tấn công", 10, 24))
func create_hint_label(
	text_value: String,
	font_size: int = 18,
	font_color: Color = Color.WHITE
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)

	return label


func create_mouse_attack_row(
	text_value: String,
	font_size: int = 18,
	icon_size: int = 32
) -> HBoxContainer:
	var attack_row := HBoxContainer.new()
	attack_row.name = "AttackRow"
	attack_row.alignment = BoxContainer.ALIGNMENT_CENTER
	attack_row.add_theme_constant_override("separation", 5)

	var mouse_icon := TextureRect.new()
	mouse_icon.name = "MouseLeftIcon"
	mouse_icon.texture = mouse_left_texture
	mouse_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	attack_row.add_child(mouse_icon)

	var attack_label := create_hint_label(text_value, font_size)
	attack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	attack_row.add_child(attack_label)

	return attack_row
func show_tutorial_hint_once() -> void:
	if has_shown_tutorial_hint:
		return

	has_shown_tutorial_hint = true

	if tutorial_root == null:
		return

	if tutorial_tween != null:
		tutorial_tween.kill()

	tutorial_root.visible = true
	tutorial_root.modulate.a = 0.0

	tutorial_tween = create_tween()
	tutorial_tween.tween_property(tutorial_root, "modulate:a", 1.0, 0.8)
	tutorial_tween.tween_interval(5.0)
	tutorial_tween.tween_property(tutorial_root, "modulate:a", 0.0, 0.8)

	await tutorial_tween.finished

	tutorial_root.visible = false


func set_mouse_filter_ignore_recursive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child in node.get_children():
		set_mouse_filter_ignore_recursive(child)


func has_object_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == prop_name:
			return true

	return false
func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()
func get_players() -> Array:
	var players := get_tree().get_nodes_in_group("players")

	if players.is_empty():
		if player != null:
			players.append(player)
		elif PlayerManager.player != null:
			players.append(PlayerManager.player)

	return players


func force_game_over_lock_players() -> void:
	var players := get_players()

	if players.is_empty():
		if player != null:
			players.append(player)
		elif PlayerManager.player != null:
			players.append(PlayerManager.player)

	for p in players:
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_method("set_control_enabled"):
			p.set_control_enabled(false)

		if has_object_property(p, "can_control"):
			p.set("can_control", false)

		if has_object_property(p, "velocity"):
			var current_velocity: Vector2 = p.get("velocity")
			current_velocity.x = 0.0
			p.set("velocity", current_velocity)

		if p.has_method("stop_hurt_box"):
			p.stop_hurt_box()
