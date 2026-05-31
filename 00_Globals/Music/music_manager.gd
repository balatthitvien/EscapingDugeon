extends Node

@onready var bgm: AudioStreamPlayer = $BGM
@onready var boss_music: AudioStreamPlayer = $BossMusic

@export var normal_volume_db: float = -10.0
@export var boss_volume_db: float = 2.0
@export var muted_volume_db: float = -80.0
@export var map_1_music: AudioStream
var volume_tween: Tween


func _ready() -> void:
	bgm.volume_db = muted_volume_db
	bgm.play()

	boss_music.volume_db = muted_volume_db
	boss_music.stop()

	fade_in(2.0)


func fade_in(duration: float = 2.0) -> void:
	if volume_tween:
		volume_tween.kill()

	if boss_music.playing:
		boss_music.stop()

	if !bgm.playing:
		bgm.play()

	bgm.volume_db = muted_volume_db

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


func fade_in_after_delay(delay_time: float = 3.0, duration: float = 2.0) -> void:
	await get_tree().create_timer(delay_time).timeout
	fade_in(duration)


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
		if !bgm.playing:
			bgm.volume_db = muted_volume_db
			bgm.play()
		fade_in(1.2)
		return

	if !bgm.playing:
		bgm.volume_db = muted_volume_db
		bgm.play()

	volume_tween = create_tween()
	volume_tween.tween_property(boss_music, "volume_db", muted_volume_db, 0.8)
	volume_tween.parallel().tween_property(bgm, "volume_db", normal_volume_db, 0.8)

	await volume_tween.finished

	if boss_music.playing:
		boss_music.stop()
func play_map_music(stream: AudioStream, duration: float = 2.0) -> void:
	if stream == null:
		push_error("Chưa gán nhạc map.")
		return

	if volume_tween:
		volume_tween.kill()

	if boss_music.playing:
		boss_music.stop()

	if bgm.stream == stream and bgm.playing:
		return

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


func play_map_1_music() -> void:
	play_map_music(map_1_music, 2.0)
