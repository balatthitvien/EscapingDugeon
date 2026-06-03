extends CanvasLayer

var black_rect: ColorRect
var white_rect: ColorRect
var slam_player: AudioStreamPlayer

var is_running: bool = false
var master_bus_index: int = -1
var original_master_volume_db: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 999999

	master_bus_index = AudioServer.get_bus_index("Master")

	if master_bus_index >= 0:
		original_master_volume_db = AudioServer.get_bus_volume_db(master_bus_index)

	create_effect_nodes()


func create_effect_nodes() -> void:
	black_rect = ColorRect.new()
	black_rect.name = "BlackRect"
	add_child(black_rect)

	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_rect.offset_left = 0
	black_rect.offset_top = 0
	black_rect.offset_right = 0
	black_rect.offset_bottom = 0
	black_rect.color = Color(0, 0, 0, 0)
	black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_rect.visible = false

	white_rect = ColorRect.new()
	white_rect.name = "WhiteRect"
	add_child(white_rect)

	white_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	white_rect.offset_left = 0
	white_rect.offset_top = 0
	white_rect.offset_right = 0
	white_rect.offset_bottom = 0
	white_rect.color = Color(1, 1, 1, 0)
	white_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white_rect.visible = false

	slam_player = AudioStreamPlayer.new()
	slam_player.name = "SlamPlayer"
	add_child(slam_player)


func play_to_main_menu(
	main_menu_scene_path: String,
	slam_sound: AudioStream = null,
	light_fade_time: float = 5.0,
	black_hold_time: float = 0.9,
	music_delay_after_menu: float = 3.0,
	music_fade_in_time: float = 2.0
) -> void:
	if is_running:
		return

	is_running = true

	black_rect.visible = true
	white_rect.visible = true

	set_black_alpha(0.0)
	set_white_alpha(0.0)

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Âm thanh nhỏ dần cùng lúc màn hình sáng dần.
	var audio_tween := create_tween()
	audio_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	if master_bus_index >= 0:
		var start_volume := AudioServer.get_bus_volume_db(master_bus_index)
		audio_tween.tween_method(
			Callable(self, "set_master_volume"),
			start_volume,
			-45.0,
			light_fade_time
		)

	# Sáng trắng từ từ trong 5 giây.
	await tween_white_alpha(1.0, light_fade_time)

	# Dừng hẳn nhạc game.
	stop_all_music()

	# Phát tiếng sầm nếu có gán.
	if slam_sound != null:
		slam_player.stream = slam_sound
		slam_player.stop()
		slam_player.play()

	# Tối thui ngay lập tức.
	set_white_alpha(0.0)
	set_black_alpha(1.0)

	await get_tree().create_timer(black_hold_time, true).timeout

	if main_menu_scene_path == "":
		push_warning("FinalExitTransition: Chưa gán đường dẫn Main Menu.")
		reset_effect()
		return

	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene_path)

	# Đợi Main Menu load xong rồi mới xóa màn đen.
	await get_tree().process_frame
	await get_tree().process_frame

	reset_effect()

	# Khôi phục âm lượng Master.
	restore_master_volume()

	# Sau 3 giây ở Main Menu mới bật lại BGM.
	await get_tree().create_timer(music_delay_after_menu, true).timeout

	if MusicManager.has_method("fade_in"):
		MusicManager.fade_in(music_fade_in_time)

	is_running = false


func tween_white_alpha(target_alpha: float, duration: float) -> void:
	var start_alpha := white_rect.color.a

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(
		Callable(self, "set_white_alpha"),
		start_alpha,
		target_alpha,
		duration
	)

	await tween.finished


func set_white_alpha(value: float) -> void:
	white_rect.color = Color(1, 1, 1, clamp(value, 0.0, 1.0))


func set_black_alpha(value: float) -> void:
	black_rect.color = Color(0, 0, 0, clamp(value, 0.0, 1.0))


func set_master_volume(value: float) -> void:
	if master_bus_index < 0:
		return

	AudioServer.set_bus_volume_db(master_bus_index, value)


func restore_master_volume() -> void:
	if master_bus_index < 0:
		return

	AudioServer.set_bus_volume_db(master_bus_index, original_master_volume_db)


func stop_all_music() -> void:
	if MusicManager.has_method("stop_all_music"):
		MusicManager.stop_all_music()
		return

	if MusicManager.has_node("BGM"):
		var bgm := MusicManager.get_node("BGM") as AudioStreamPlayer
		if bgm != null:
			bgm.stop()

	if MusicManager.has_node("BossMusic"):
		var boss_music := MusicManager.get_node("BossMusic") as AudioStreamPlayer
		if boss_music != null:
			boss_music.stop()


func reset_effect() -> void:
	set_white_alpha(0.0)
	set_black_alpha(0.0)

	white_rect.visible = false
	black_rect.visible = false

	get_tree().paused = false
