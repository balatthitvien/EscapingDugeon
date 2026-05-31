extends Node2D

@onready var talk_hint_ui: CanvasLayer = $TalkHintUI
@onready var talk_hint_label: Label = $TalkHintUI/TalkHintLabel
@onready var you_died_ui: CanvasLayer = get_node_or_null("YouDiedUI") as CanvasLayer

var player: Player = null
var has_connected_player_died: bool = false


func _ready() -> void:
	MusicManager.stop_boss_music()
	MusicManager.play_map_1_music()

	setup_talk_hint_ui()

	if !LevelManager.has_shown_map_1_interact_hint:
		show_interact_hint_once()

	setup_player_death_handler()
	apply_player_spawn_point()


func setup_talk_hint_ui() -> void:
	talk_hint_ui.visible = false
	talk_hint_ui.layer = 1000

	talk_hint_label.text = "Ấn E để tương tác"
	talk_hint_label.visible = true
	talk_hint_label.modulate.a = 0.0

	talk_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	talk_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	talk_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	talk_hint_label.offset_left = -300
	talk_hint_label.offset_right = 20
	talk_hint_label.offset_top = -180
	talk_hint_label.offset_bottom = -135

	talk_hint_label.add_theme_font_size_override("font_size", 18)


func show_interact_hint_once() -> void:
	await get_tree().create_timer(4.0).timeout

	LevelManager.has_shown_map_1_interact_hint = true

	talk_hint_ui.visible = true
	talk_hint_label.visible = true
	talk_hint_label.modulate.a = 0.0

	var tween := create_tween()

	tween.tween_property(talk_hint_label, "modulate:a", 1.0, 1.0)
	tween.tween_interval(5.0)
	tween.tween_property(talk_hint_label, "modulate:a", 0.0, 1.0)

	await tween.finished

	talk_hint_ui.visible = false


func apply_player_spawn_point() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var spawn_name: String = LevelManager.get_next_spawn_point()

	if spawn_name == "":
		return

	var spawn_point := get_node_or_null("SpawnPoints/" + spawn_name)

	if spawn_point == null:
		push_warning("Không tìm thấy spawn point: " + spawn_name)
		LevelManager.clear_next_spawn_point()
		return

	if PlayerManager.player != null:
		PlayerManager.player.global_position = spawn_point.global_position
		PlayerManager.player.velocity = Vector2.ZERO

	LevelManager.clear_next_spawn_point()


func setup_player_death_handler() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	player = get_node_or_null("Player") as Player

	if player == null:
		player = PlayerManager.player

	if player == null:
		push_warning("map_1: Không tìm thấy Player để bắt signal died.")
		return

	if you_died_ui == null:
		you_died_ui = get_node_or_null("YouDiedUI") as CanvasLayer

	if you_died_ui == null:
		push_warning("map_1: Không tìm thấy YouDiedUI trong scene.")
		return

	if has_connected_player_died:
		return

	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	has_connected_player_died = true
	print("map_1: Đã kết nối Player died với YouDiedUI.")


func _on_player_died() -> void:
	print("map_1: PLAYER DIED SIGNAL RECEIVED")

	await get_tree().create_timer(1.0).timeout

	if you_died_ui != null and you_died_ui.has_method("show_you_died"):
		you_died_ui.show_you_died()
