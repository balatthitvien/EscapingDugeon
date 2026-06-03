extends Node

var player_count: int = 1


func set_single_player() -> void:
	player_count = 1


func set_two_players() -> void:
	player_count = 2


func is_two_players() -> bool:
	return player_count == 2
