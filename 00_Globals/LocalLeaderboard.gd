extends Node

const LOCAL_LEADERBOARD_PATH: String = "user://local_leaderboard.json"
const MAX_LOCAL_RECORDS: int = 20

var scores: Array = []


func _ready() -> void:
	load_scores()


func add_score(score_data: Dictionary) -> void:
	var record := score_data.duplicate(true)
	record["saved_at"] = get_current_datetime_text()

	scores.append(record)

	scores.sort_custom(func(a, b):
		return int(a.get("clear_time_seconds", 999999999)) < int(b.get("clear_time_seconds", 999999999))
	)

	while scores.size() > MAX_LOCAL_RECORDS:
		scores.pop_back()

	save_scores()


func get_scores() -> Array:
	return scores


func save_scores() -> void:
	var file := FileAccess.open(LOCAL_LEADERBOARD_PATH, FileAccess.WRITE)

	if file == null:
		return

	file.store_string(JSON.stringify(scores, "\t"))
	file.close()


func load_scores() -> void:
	if !FileAccess.file_exists(LOCAL_LEADERBOARD_PATH):
		scores = []
		return

	var file := FileAccess.open(LOCAL_LEADERBOARD_PATH, FileAccess.READ)

	if file == null:
		scores = []
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)

	if typeof(parsed) == TYPE_ARRAY:
		scores = parsed
	else:
		scores = []


func get_current_datetime_text() -> String:
	var time := Time.get_datetime_dict_from_system()

	return "%02d/%02d/%04d %02d:%02d:%02d" % [
		time["day"],
		time["month"],
		time["year"],
		time["hour"],
		time["minute"],
		time["second"]
	]
