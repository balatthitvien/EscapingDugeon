extends Node

var player: Node = null

var saved_player_stats: Dictionary = {}
var has_saved_player_stats: bool = false
var is_respawning: bool = false

const PLAYER_STAT_NAMES: Array[String] = [
	"level",
	"current_exp",
	"exp_to_next",
	"max_level",
	"base_exp_to_next",

	"coin_count",
	"potion_count",
	"has_seen_potion_tip",

	"max_health_units",
	"current_health_units",

	"weapon_bonus_attack"
]


func register_player(new_player: Node) -> void:
	player = new_player

	if has_saved_player_stats:
		apply_saved_stats_to_player()
	else:
		capture_runtime_stats_from_player(false)

	# Dù là load hay vào game thường, vẫn refresh chậm 1 nhịp
	# để HUD chắc chắn đã sẵn sàng.
	call_deferred("call_player_refresh_after_restore")


func clear_player(old_player: Node = null) -> void:
	if old_player == null:
		player = null
		return

	if player == old_player:
		player = null


func capture_runtime_stats_from_player(heal_on_next_spawn: bool = false) -> void:
	if player == null:
		return

	if not is_instance_valid(player):
		return

	for stat_name in PLAYER_STAT_NAMES:
		if has_object_property(player, stat_name):
			saved_player_stats[stat_name] = player.get(stat_name)

	if heal_on_next_spawn:
		make_saved_health_full()

	has_saved_player_stats = true


func prepare_respawn_stats() -> void:
	is_respawning = true
	capture_runtime_stats_from_player(true)


func apply_saved_stats_to_player() -> void:
	if player == null:
		return

	if not is_instance_valid(player):
		return

	for stat_name in saved_player_stats.keys():
		if has_object_property(player, stat_name):
			player.set(stat_name, saved_player_stats[stat_name])

	if is_respawning:
		make_player_health_full()
		is_respawning = false

	reset_player_runtime_state()

	# Không gọi refresh ngay lập tức nữa.
	# Gọi chậm lại để tránh HUD chưa kịp ready sau khi mở game/load scene.
	call_deferred("call_player_refresh_after_restore")


func make_saved_health_full() -> void:
	if saved_player_stats.has("max_health_units"):
		saved_player_stats["current_health_units"] = saved_player_stats["max_health_units"]


func make_player_health_full() -> void:
	if player == null:
		return

	if not is_instance_valid(player):
		return

	if has_object_property(player, "max_health_units") and has_object_property(player, "current_health_units"):
		player.set("current_health_units", player.get("max_health_units"))


func reset_player_runtime_state() -> void:
	if player == null:
		return

	if not is_instance_valid(player):
		return

	if has_object_property(player, "velocity"):
		player.set("velocity", Vector2.ZERO)

	if has_object_property(player, "is_dead"):
		player.set("is_dead", false)

	if has_object_property(player, "is_hurt"):
		player.set("is_hurt", false)

	if has_object_property(player, "hurt_timer"):
		player.set("hurt_timer", 0.0)

	if has_object_property(player, "can_control"):
		player.set("can_control", true)

	if has_object_property(player, "attack_cooldown"):
		player.set("attack_cooldown", false)

	if has_object_property(player, "current_base_animation"):
		player.set("current_base_animation", "")


func reset_runtime_stats() -> void:
	player = null
	saved_player_stats.clear()
	has_saved_player_stats = false
	is_respawning = false


func has_object_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == prop_name:
			return true

	return false


func call_player_refresh_after_restore() -> void:
	# Đợi vài frame để Player, HUD, CanvasLayer, label, heart container...
	# đều kịp chạy _ready().
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	if player == null:
		return

	if not is_instance_valid(player):
		return

	# Ưu tiên hàm chuyên dùng sau khi load.
	if player.has_method("refresh_after_restore"):
		player.call("refresh_after_restore")

	if player.has_method("refresh_after_restore_delayed"):
		player.call("refresh_after_restore_delayed")

	return

	# Các tên hàm dự phòng nếu Player của bạn đang dùng tên khác.
	if player.has_method("update_hud"):
		player.call("update_hud")

	if player.has_method("update_ui"):
		player.call("update_ui")

	if player.has_method("refresh_hud"):
		player.call("refresh_hud")

	if player.has_method("update_health_ui"):
		player.call("update_health_ui")

	if player.has_method("update_coin_ui"):
		player.call("update_coin_ui")

	if player.has_method("update_exp_ui"):
		player.call("update_exp_ui")

	if player.has_method("update_potion_ui"):
		player.call("update_potion_ui")


func force_refresh_player_ui() -> void:
	call_deferred("call_player_refresh_after_restore")
