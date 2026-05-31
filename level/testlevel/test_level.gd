extends Node2D

@onready var boss: Enemy = $World/Enemy
@onready var boss_health_bar = $BossHealthBar
@onready var story_dialog = $StoryDialog
@onready var you_died_ui = $YouDiedUI
@export var mouse_left_texture: Texture2D
var player: Player
var tutorial_layer: CanvasLayer
var tutorial_root: Control
var tutorial_tween: Tween = null
var has_shown_tutorial_hint: bool = false
var has_handled_player_death: bool = false
func _ready() -> void:
	print("TestLevel ready")

	create_tutorial_hint_ui()

	await get_tree().process_frame

	player = get_node_or_null("World/Player") as Player

	if player == null:
		player = PlayerManager.player

	if player == null:
		push_error("Không tìm thấy Player. Kiểm tra node Player trong test_level.")
		return

	print("Player found: ", player)

	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	player.set_control_enabled(false)

	boss.boss_started.connect(_on_boss_started)
	boss.health_changed.connect(_on_boss_health_changed)
	boss.died.connect(_on_boss_died)

	boss_health_bar.setup(boss.max_health)
	boss_health_bar.update_health(boss.current_health, boss.max_health)

	story_dialog.story_finished.connect(_on_story_finished)

	await get_tree().create_timer(4.0).timeout

	story_dialog.start_story([
		"Mình đang ở đâu vậy? Tại sao mình lại ở đây?",
		"Mình phải tìm đường ra khỏi đây ngay."
	])


func _on_player_died() -> void:
	if has_handled_player_death:
		return

	has_handled_player_death = true

	print("PLAYER DIED SIGNAL RECEIVED")

	await get_tree().create_timer(1.0).timeout

	if you_died_ui != null:
		you_died_ui.show_you_died()

func _on_boss_started() -> void:
	print("Boss bar show")
	boss_health_bar.show_bar()
	MusicManager.play_boss_music()


func _on_boss_health_changed(current_health: int, max_health: int) -> void:
	print("Update Boss Bar: ", current_health, "/", max_health)
	boss_health_bar.update_health(current_health, max_health)


func _on_boss_died() -> void:
	boss_health_bar.hide_bar()
	MusicManager.stop_boss_music()


func _on_story_finished() -> void:
	player.set_control_enabled(true)
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
	tutorial_root.offset_left = 90
	tutorial_root.offset_top = 90
	tutorial_root.offset_right = 520
	tutorial_root.offset_bottom = 250
	tutorial_root.modulate.a = 0.0
	tutorial_root.visible = false

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

	var move_label := Label.new()
	move_label.name = "MoveLabel"
	move_label.text = "AD để di chuyển"
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	move_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(move_label)

	var jump_label := Label.new()
	jump_label.name = "JumpLabel"
	jump_label.text = "Space để nhảy"
	jump_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jump_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	jump_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(jump_label)

	var attack_row := HBoxContainer.new()
	attack_row.name = "AttackRow"
	attack_row.alignment = BoxContainer.ALIGNMENT_CENTER
	attack_row.add_theme_constant_override("separation", 8)
	vbox.add_child(attack_row)

	var mouse_icon := TextureRect.new()
	mouse_icon.name = "MouseLeftIcon"
	mouse_icon.texture = mouse_left_texture
	mouse_icon.custom_minimum_size = Vector2(36, 36)
	mouse_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	attack_row.add_child(mouse_icon)

	var attack_label := Label.new()
	attack_label.name = "AttackLabel"
	attack_label.text = "để tấn công"
	attack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	attack_label.add_theme_font_size_override("font_size", 18)
	attack_row.add_child(attack_label)
	set_mouse_filter_ignore_recursive(tutorial_root)

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
