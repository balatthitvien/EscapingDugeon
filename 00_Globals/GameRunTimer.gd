extends Node

var is_running: bool = false
var elapsed_seconds: float = 0.0
var run_mode: String = "single"
var pending_clear_score: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if !is_running:
		return

	# Khi ESC pause game, get_tree().paused = true,
	# timer sẽ tự dừng dù script vẫn PROCESS_MODE_ALWAYS.
	if get_tree().paused:
		return

	elapsed_seconds += delta


func start_run(mode: String = "single") -> void:
	elapsed_seconds = 0.0
	is_running = true
	run_mode = mode
	pending_clear_score.clear()


func stop_run() -> Dictionary:
	if !is_running and pending_clear_score.is_empty():
		return {}

	is_running = false

	var clear_time_seconds: int = get_elapsed_seconds_int()
	var clear_time_text: String = get_time_text()

	var score_data: Dictionary = {
		"player_name": get_default_player_name(),
		"clear_time_seconds": clear_time_seconds,
		"clear_time_text": clear_time_text,
		"game_mode": run_mode,
		"total_deaths": 0,
		"total_coins": get_player_coin_count(),
		"player_level": get_player_level()
	}

	pending_clear_score = score_data
	return score_data


func finish_run() -> Dictionary:
	return stop_run()


func has_pending_clear_score() -> bool:
	return !pending_clear_score.is_empty()


func get_pending_clear_score() -> Dictionary:
	return pending_clear_score


func clear_pending_clear_score() -> void:
	pending_clear_score.clear()


func get_elapsed_seconds_int() -> int:
	return int(floor(elapsed_seconds))


func get_time_text() -> String:
	return format_seconds_to_time_text(get_elapsed_seconds_int())


func format_seconds_to_time_text(total_seconds: int) -> String:
	total_seconds = max(total_seconds, 0)

	var hours: int = int(floor(float(total_seconds) / 3600.0))
	var minutes: int = int(floor(float(total_seconds % 3600) / 60.0))
	var seconds: int = total_seconds % 60

	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func get_default_player_name() -> String:
	if run_mode == "coop":
		return "Player 1 & 2"

	return "Player"


func get_player_coin_count() -> int:
	var player := get_current_player()

	if player == null:
		return 0

	if has_object_property(player, "coin_count"):
		return int(player.get("coin_count"))

	return 0


func get_player_level() -> int:
	var player := get_current_player()

	if player == null:
		return 1

	if has_object_property(player, "level"):
		return int(player.get("level"))

	return 1


func get_current_player() -> Object:
	var player_manager := get_node_or_null("/root/PlayerManager")

	if player_manager == null:
		return null

	if has_object_property(player_manager, "player"):
		return player_manager.get("player")

	return null


func has_object_property(obj: Object, property_name: String) -> bool:
	if obj == null:
		return false

	for property_info in obj.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true

	return false
