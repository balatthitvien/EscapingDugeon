extends Node

@onready var bgm: AudioStreamPlayer = $BGM
@onready var boss_music: AudioStreamPlayer = $BossMusic

@export var normal_volume_db: float = -10.0
@export var boss_volume_db: float = 2.0
@export var muted_volume_db: float = -80.0

@export var game_bgm: AudioStream
@export var map_1_music: AudioStream

var volume_tween: Tween
var current_music_key: String = ""


func _ready() -> void:
	if game_bgm == null:
		game_bgm = bgm.stream

	bgm.volume_db = muted_volume_db
	bgm.stop()

	boss_music.volume_db = muted_volume_db
	boss_music.stop()

	if !bgm.finished.is_connected(_on_bgm_finished):
		bgm.finished.connect(_on_bgm_finished)


func _on_bgm_finished() -> void:
	if current_music_key == "game_bgm" or current_music_key == "map_1":
		bgm.play()


func play_game_bgm(duration: float = 1.5, restart: bool = false) -> void:
	if game_bgm == null:
		push_error("Chưa gán game_bgm hoặc BGM node chưa có Stream.")
		return

	play_music_stream(game_bgm, "game_bgm", duration, restart)


func play_game_bgm_after_delay(delay_time: float = 3.0, duration: float = 1.5, restart: bool = true) -> void:
	await get_tree().create_timer(delay_time).timeout
	play_game_bgm(duration, restart)


func play_map_1_music(duration: float = 1.5, restart: bool = true) -> void:
	if map_1_music == null:
		push_error("Chưa gán nhạc map_1 trong MusicManager.")
		return

	play_music_stream(map_1_music, "map_1", duration, restart)


func play_map_1_music_after_delay(delay_time: float = 0.0, duration: float = 1.5, restart: bool = true) -> void:
	if delay_time > 0.0:
		await get_tree().create_timer(delay_time).timeout

	play_map_1_music(duration, restart)


func play_music_stream(stream: AudioStream, music_key: String, duration: float = 1.5, restart: bool = false) -> void:
	if stream == null:
		return

	if volume_tween:
		volume_tween.kill()

	if boss_music.playing:
		boss_music.stop()

	if current_music_key == music_key and bgm.stream == stream and bgm.playing and !restart:
		return

	current_music_key = music_key
	bgm.stream = stream
	bgm.volume_db = muted_volume_db
	bgm.play()

	volume_tween = create_tween()
	volume_tween.tween_property(
		bgm,
		"volume_db",
		normal_volume_db,
		duration
	)


func fade_out(duration: float = 1.0, stop_after: bool = true) -> void:
	if volume_tween:
		volume_tween.kill()

	volume_tween = create_tween()
	volume_tween.tween_property(
		bgm,
		"volume_db",
		muted_volume_db,
		duration
	)

	await volume_tween.finished

	if stop_after:
		bgm.stop()
		current_music_key = ""


func fade_in(duration: float = 2.0) -> void:
	play_game_bgm(duration, false)


func fade_in_after_delay(delay_time: float = 3.0, duration: float = 2.0) -> void:
	await get_tree().create_timer(delay_time).timeout
	play_game_bgm(duration, false)


func play_boss_music() -> void:
	if boss_music.playing:
		return

	if volume_tween:
		volume_tween.kill()

	if !bgm.playing:
		bgm.play()

	boss_music.volume_db = muted_volume_db
	boss_music.play()

	volume_tween = create_tween()
	volume_tween.tween_property(bgm, "volume_db", muted_volume_db, 0.8)
	volume_tween.parallel().tween_property(boss_music, "volume_db", boss_volume_db, 0.8)

	await volume_tween.finished

	if bgm.playing:
		bgm.stop()


func stop_boss_music() -> void:
	if volume_tween:
		volume_tween.kill()

	if !boss_music.playing:
		if !bgm.playing and current_music_key != "":
			bgm.volume_db = muted_volume_db
			bgm.play()

			volume_tween = create_tween()
			volume_tween.tween_property(bgm, "volume_db", normal_volume_db, 1.2)

		return

	if !bgm.playing and current_music_key != "":
		bgm.volume_db = muted_volume_db
		bgm.play()

	volume_tween = create_tween()
	volume_tween.tween_property(boss_music, "volume_db", muted_volume_db, 0.8)
	volume_tween.parallel().tween_property(bgm, "volume_db", normal_volume_db, 0.8)

	await volume_tween.finished

	if boss_music.playing:
		boss_music.stop()


func play_music_for_map(scene_name_or_path: String, delay_time: float = 0.0) -> void:
	var scene_text := scene_name_or_path.to_lower()

	if scene_text.contains("map_1") or scene_text.contains("map1"):
		await play_map_1_music_after_delay(delay_time, 1.5, true)
		return

	await play_game_bgm_after_delay(delay_time, 1.5, true)
