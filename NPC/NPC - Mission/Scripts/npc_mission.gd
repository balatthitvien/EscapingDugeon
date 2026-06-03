extends Node2D

signal first_interact_pressed
signal player_entered_talk_range
signal player_exited_talk_range

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var talk_area: Area2D = $TalkArea
@onready var talk_indicator: Sprite2D = $TalkIndicator

@export var start_direction: String = "right"

@export var player_portrait: Texture2D
@export var npc_portrait: Texture2D

@export var npc_id: String = "npc_mission"

# Flag này phải trùng với flag mà rương vật tư set khi mở.
@export var supply_chest_flag_name: String = "has_found_supply_chest"

# Flag này dùng để biết NPC đã cảm ơn player chưa.
@export var supply_thanks_flag_name: String = "has_finished_supply_thanks_dialog"

# Flag này dùng để tránh nhận thưởng nhiều lần.
@export var supply_reward_flag_name: String = "has_received_supply_reward"

# Số vàng thưởng sau khi hoàn thành nhiệm vụ.
@export var supply_reward_gold: int = 20

# Player phải nói chuyện với NPC-Mission đến đoạn 2 thì NPC mới hiểu chuyện vật tư.
@export var required_talk_count_for_supply_thanks: int = 2

var player_in_range: bool = false
var player: Player = null
var players_near: Dictionary = {}

var is_talking: bool = false
var talk_count: int = 0
var has_pressed_interact_once: bool = false

var current_dialog_type: String = ""


func _ready() -> void:
	talk_count = LevelManager.get_npc_talk_count(npc_id)
	has_pressed_interact_once = LevelManager.has_npc_pressed_interact_once(npc_id)

	if talk_indicator != null:
		talk_indicator.visible = false
		talk_indicator.z_index = 20

	if animation_player != null:
		if start_direction == "left":
			if animation_player.has_animation("idle_left"):
				animation_player.play("idle_left")
		else:
			if animation_player.has_animation("idle_right"):
				animation_player.play("idle_right")

	if talk_area != null:
		if not talk_area.body_entered.is_connected(_on_talk_area_body_entered):
			talk_area.body_entered.connect(_on_talk_area_body_entered)

		if not talk_area.body_exited.is_connected(_on_talk_area_body_exited):
			talk_area.body_exited.connect(_on_talk_area_body_exited)

		if not talk_area.area_entered.is_connected(_on_talk_area_area_entered):
			talk_area.area_entered.connect(_on_talk_area_area_entered)

		if not talk_area.area_exited.is_connected(_on_talk_area_area_exited):
			talk_area.area_exited.connect(_on_talk_area_area_exited)
	else:
		push_warning("NPC-Mission thiếu TalkArea.")


func _unhandled_input(event: InputEvent) -> void:
	if !player_in_range:
		return

	if is_talking:
		return

	var action_player := get_player_pressed_interact_event(event)

	if action_player == null:
		return

	player = action_player

	if !has_pressed_interact_once:
		has_pressed_interact_once = true
		LevelManager.set_npc_pressed_interact_once(npc_id, true)
		first_interact_pressed.emit()

	start_talk()
	get_viewport().set_input_as_handled()


func start_talk() -> void:
	if is_talking:
		return

	if !player_in_range:
		return

	if player == null:
		player = get_any_near_player()

	if player == null:
		return

	is_talking = true
	current_dialog_type = ""

	if talk_indicator != null:
		talk_indicator.visible = false

	set_all_players_control_enabled(false)

	var story_dialog = get_story_dialog()

	if story_dialog == null:
		push_warning("NPC-Mission: Không tìm thấy StoryDialog trong scene hiện tại.")
		finish_talk_without_dialog()
		return

	var dialog_data: Dictionary = get_dialog_data_to_play()
	var dialog_lines: Array = dialog_data.get("lines", [])
	current_dialog_type = dialog_data.get("type", "")

	if dialog_lines.is_empty():
		finish_talk_without_dialog()
		return

	if story_dialog.story_finished.is_connected(_on_dialog_finished):
		story_dialog.story_finished.disconnect(_on_dialog_finished)

	story_dialog.story_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)
	story_dialog.start_story(dialog_lines)


func get_story_dialog() -> Node:
	var current_scene := get_tree().current_scene

	if current_scene == null:
		return null

	return current_scene.get_node_or_null("StoryDialog")


func get_dialog_data_to_play() -> Dictionary:
	talk_count = LevelManager.get_npc_talk_count(npc_id)

	var has_supplies: bool = LevelManager.get_game_flag(supply_chest_flag_name)
	var has_thanked: bool = LevelManager.get_game_flag(supply_thanks_flag_name)

	if has_supplies and !has_thanked and talk_count >= required_talk_count_for_supply_thanks:
		return {
			"type": "third_supply",
			"lines": get_third_supply_dialog()
		}

	if talk_count <= 0:
		return {
			"type": "first",
			"lines": get_first_dialog()
		}

	if talk_count == 1:
		return {
			"type": "second",
			"lines": get_second_dialog()
		}

	return {
		"type": "after_mission",
		"lines": get_after_mission_dialog()
	}


func _on_dialog_finished() -> void:
	match current_dialog_type:
		"first":
			talk_count = 1
			LevelManager.set_npc_talk_count(npc_id, talk_count)
			finish_talk()

		"second":
			talk_count = 2
			LevelManager.set_npc_talk_count(npc_id, talk_count)

			var has_supplies: bool = LevelManager.get_game_flag(supply_chest_flag_name)
			var has_thanked: bool = LevelManager.get_game_flag(supply_thanks_flag_name)

			if has_supplies and !has_thanked:
				play_third_dialog_immediately()
				return

			finish_talk()

		"third_supply":
			await finish_third_supply_dialog()

		"after_mission":
			finish_talk()

		_:
			finish_talk()


func play_third_dialog_immediately() -> void:
	var story_dialog = get_story_dialog()

	if story_dialog == null:
		push_warning("NPC-Mission: Không tìm thấy StoryDialog để mở hội thoại cảm ơn vật tư.")
		finish_talk()
		return

	current_dialog_type = "third_supply"

	if story_dialog.story_finished.is_connected(_on_dialog_finished):
		story_dialog.story_finished.disconnect(_on_dialog_finished)

	story_dialog.story_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)
	story_dialog.start_story(get_third_supply_dialog())


func finish_third_supply_dialog() -> void:
	LevelManager.set_game_flag(supply_thanks_flag_name, true)

	talk_count = 3
	LevelManager.set_npc_talk_count(npc_id, talk_count)

	await give_supply_reward_and_show_dialog()

	finish_talk()


func give_supply_reward_and_show_dialog() -> void:
	if LevelManager.get_game_flag(supply_reward_flag_name):
		return

	LevelManager.set_game_flag(supply_reward_flag_name, true)

	var reward_player := get_reward_stats_player()

	if reward_player != null and reward_player.has_method("add_coin"):
		reward_player.add_coin(supply_reward_gold)

	var reward_dialog: Array = [
		{
			"speaker": "system",
			"text": "Hoàn thành nhiệm vụ."
		},
		{
			"speaker": "system",
			"text": "Bạn nhận được " + str(supply_reward_gold) + " vàng."
		}
	]

	await play_reward_dialog(reward_dialog)


func play_reward_dialog(dialog_lines: Array) -> void:
	var story_dialog = get_story_dialog()

	if story_dialog == null:
		push_warning("NPC-Mission: Không tìm thấy StoryDialog để hiện thông báo nhiệm vụ.")
		return

	if not story_dialog.has_method("start_story"):
		push_warning("NPC-Mission: StoryDialog không có hàm start_story().")
		return

	story_dialog.start_story(dialog_lines)
	await story_dialog.story_finished


func finish_talk() -> void:
	is_talking = false
	current_dialog_type = ""

	set_all_players_control_enabled(true)

	if player_in_range and talk_indicator != null:
		talk_indicator.visible = true


func finish_talk_without_dialog() -> void:
	is_talking = false
	current_dialog_type = ""

	set_all_players_control_enabled(true)

	if player_in_range and talk_indicator != null:
		talk_indicator.visible = true


func _on_talk_area_body_entered(body: Node2D) -> void:
	try_set_player_near(body)


func _on_talk_area_body_exited(body: Node2D) -> void:
	try_remove_player_near(body)


func _on_talk_area_area_entered(area: Area2D) -> void:
	try_set_player_near(area)

	if area.get_parent() != null:
		try_set_player_near(area.get_parent())


func _on_talk_area_area_exited(area: Area2D) -> void:
	try_remove_player_near(area)

	if area.get_parent() != null:
		try_remove_player_near(area.get_parent())


func try_set_player_near(target: Node) -> void:
	var detected_player: Player = find_player_from_node(target)

	if detected_player == null:
		return

	players_near[detected_player.get_instance_id()] = detected_player
	player_in_range = !players_near.is_empty()
	player = detected_player

	player_entered_talk_range.emit()

	if !is_talking and talk_indicator != null:
		talk_indicator.visible = true


func try_remove_player_near(target: Node) -> void:
	var detected_player: Player = find_player_from_node(target)

	if detected_player == null:
		return

	var id := detected_player.get_instance_id()

	if players_near.has(id):
		players_near.erase(id)

	player_in_range = !players_near.is_empty()

	if player == detected_player:
		player = get_any_near_player()

	player_exited_talk_range.emit()

	if !player_in_range and talk_indicator != null:
		talk_indicator.visible = false


func find_player_from_node(node: Node) -> Player:
	var current: Node = node

	while current != null:
		if current is Player:
			return current as Player

		if current.is_in_group("players"):
			return current as Player

		if current.is_in_group("player"):
			return current as Player

		if current.is_in_group("Player"):
			return current as Player

		if current.name == "Player":
			return current as Player

		if current.name == "Player2":
			return current as Player

		current = current.get_parent()

	return null


func get_any_near_player() -> Player:
	for key in players_near.keys():
		var p: Player = players_near[key]

		if p != null and is_instance_valid(p):
			return p

	return null


func get_player_pressed_interact_event(event: InputEvent) -> Player:
	for key in players_near.keys():
		var p: Player = players_near[key]

		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_method("is_interact_event_pressed"):
			if p.is_interact_event_pressed(event):
				return p
		else:
			var action_name := get_interact_action_for_player(p)

			if event.is_action_pressed(action_name):
				return p

	return null


func get_interact_action_for_player(target_player: Player) -> StringName:
	if !is_two_player_mode():
		return &"interact"

	var id_value: int = int(target_player.get("player_id"))

	if id_value == 1:
		return &"p1_interact"

	return &"p2_interact"


func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


func set_all_players_control_enabled(state: bool) -> void:
	if is_two_player_mode():
		var players := get_tree().get_nodes_in_group("players")

		for p in players:
			if p == null:
				continue

			if !is_instance_valid(p):
				continue

			if p.has_method("set_control_enabled"):
				p.set_control_enabled(state)

		return

	if player != null and player.has_method("set_control_enabled"):
		player.set_control_enabled(state)
	elif PlayerManager.player != null and PlayerManager.player.has_method("set_control_enabled"):
		PlayerManager.player.set_control_enabled(state)


func get_reward_stats_player() -> Player:
	if PlayerManager.player != null and PlayerManager.player is Player:
		return PlayerManager.player as Player

	if player != null:
		return player

	var near_player := get_any_near_player()

	if near_player != null:
		return near_player

	return null


func get_first_dialog() -> Array:
	return [
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Ờm... xin chào."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Xin chào. Cậu tỉnh rồi à? Còn đau ở đâu không?"
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Tôi không sao. Cho tôi hỏi... đây là đâu vậy?"
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Đây là nơi trú ngụ của những người tị nạn."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Tất cả chúng tôi đều bị dịch chuyển đến đây. Không ai biết nơi này thật sự là đâu."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Và cũng chưa ai tìm được đường thoát ra ngoài."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Tôi nhớ mình đã bị một kẻ mặc giáp, cao lớn, có cặp sừng vàng đánh gục..."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Kẻ đó là tên canh giữ hầm ngục này."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Chúng tôi thường gọi hắn là [color=yellow]Sừng Vàng[/color]. Hắn ngăn cản bất cứ ai muốn rời khỏi nơi này."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Chúng tôi tìm thấy cậu trong một lần đi thám hiểm, rồi đưa cậu về làng để chữa thương."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Cảm ơn mọi người... vì đã mạo hiểm cứu tôi."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Vậy làm sao để thoát khỏi nơi này?"
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Có lẽ chỉ có một cách: đánh bại [color=yellow]Sừng Vàng[/color]."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Nhưng rất nhiều người từng đối đầu với hắn... đều một đi không trở lại."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Chúng tôi không có khả năng chiến đấu. Vì vậy, chỉ có thể tạm trú và cố gắng sinh tồn ở đây."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Tôi phải thoát khỏi đây. Các bạn có cách nào giúp tôi không?"
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Trong làng có vài người có thể giúp cậu."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Nhưng... cậu thật sự muốn tiếp tục đối đầu với hắn sao?"
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Tôi cần phải quay trở về. Tôi sẽ đánh bại hắn, và giúp mọi người thoát khỏi nơi này."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Được rồi. Vậy hãy thử gặp mọi người trong làng. Có thể ai đó sẽ giúp được cậu."
		}
	]


func get_second_dialog() -> Array:
	return [
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Này, tôi có thể nhờ cậu một việc được không?"
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Cứ nói đi. Nếu giúp được, tôi sẽ giúp."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Chúng tôi đang thiếu rất nhiều vật tư."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Lương thực, nước uống, thuốc men... bất cứ thứ gì cũng có thể giúp mọi người cầm cự thêm."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Nếu trên đường đi cậu tìm thấy gì dùng được, hãy mang về giúp chúng tôi."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Được. Tôi sẽ để ý trên đường đi."
		}
	]


func get_third_supply_dialog() -> Array:
	return [
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Tôi tìm thấy một số vật tư trong rương."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Mong là chúng có thể giúp ích cho mọi người."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Cảm ơn cậu. Những thứ này thật sự rất cần thiết."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Tôi sẽ phân phát chúng cho mọi người trong trại."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Cậu không chỉ dũng cảm, mà còn rất tốt bụng."
		}
	]


func get_after_mission_dialog() -> Array:
	var has_supplies: bool = LevelManager.get_game_flag(supply_chest_flag_name)
	var has_thanked: bool = LevelManager.get_game_flag(supply_thanks_flag_name)

	if has_supplies and has_thanked:
		return [
			{
				"speaker": "npc",
				"portrait": npc_portrait,
				"text": "Nhờ số vật tư cậu mang về, mọi người đã yên tâm hơn rất nhiều."
			},
			{
				"speaker": "npc",
				"portrait": npc_portrait,
				"text": "Cảm ơn cậu. Hãy cẩn thận trên đường đi nhé."
			}
		]

	return [
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Nếu tìm thấy vật tư trên đường, hãy mang về giúp chúng tôi nhé."
		}
	]
