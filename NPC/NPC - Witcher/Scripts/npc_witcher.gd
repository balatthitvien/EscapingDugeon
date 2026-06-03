extends CharacterBody2D

enum WitcherState {
	IDLE,
	CHILL,
	WORK,
	DIALOG
}

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var talk_area: Area2D = $TalkArea
@onready var talk_indicator: Sprite2D = $TalkIndicator

@export var player_portrait: Texture2D
@export var npc_portrait: Texture2D

@export var idle_min_time: float = 1.5
@export var idle_max_time: float = 3.5

@export var chill_min_time: float = 2.0
@export var chill_max_time: float = 4.0

@export var work_min_time: float = 2.0
@export var work_max_time: float = 5.0

var current_state: WitcherState = WitcherState.IDLE

var player_near: bool = false
var player: Player = null
var players_near: Dictionary = {}

var is_running_behavior: bool = false
var is_talking: bool = false
var talk_count: int = 0


func _ready() -> void:
	randomize()

	if talk_indicator != null:
		talk_indicator.visible = false
		talk_indicator.z_index = 20

	if talk_area != null:
		if !talk_area.body_entered.is_connected(_on_talk_area_body_entered):
			talk_area.body_entered.connect(_on_talk_area_body_entered)

		if !talk_area.body_exited.is_connected(_on_talk_area_body_exited):
			talk_area.body_exited.connect(_on_talk_area_body_exited)

		if !talk_area.area_entered.is_connected(_on_talk_area_area_entered):
			talk_area.area_entered.connect(_on_talk_area_area_entered)

		if !talk_area.area_exited.is_connected(_on_talk_area_area_exited):
			talk_area.area_exited.connect(_on_talk_area_area_exited)
	else:
		push_warning("NPC Witcher thiếu TalkArea.")

	start_random_behavior()


func _process(_delta: float) -> void:
	if is_talking:
		return

	if current_state == WitcherState.DIALOG:
		return

	if not player_near:
		return

	var action_player := get_player_pressed_interact()

	if action_player == null:
		return

	player = action_player
	start_dialog()


func start_random_behavior() -> void:
	if is_running_behavior:
		return

	is_running_behavior = true

	while is_inside_tree():
		if current_state == WitcherState.DIALOG:
			await get_tree().process_frame
			continue

		var action := randi_range(0, 2)

		match action:
			0:
				await do_idle()
			1:
				await do_chill()
			2:
				await do_work()

	is_running_behavior = false


func do_idle() -> void:
	if current_state == WitcherState.DIALOG:
		return

	current_state = WitcherState.IDLE
	play_animation("idle_left")

	var wait_time := randf_range(idle_min_time, idle_max_time)
	await get_tree().create_timer(wait_time).timeout


func do_chill() -> void:
	if current_state == WitcherState.DIALOG:
		return

	current_state = WitcherState.CHILL
	play_animation("chill_left")

	var wait_time := randf_range(chill_min_time, chill_max_time)
	await get_tree().create_timer(wait_time).timeout


func do_work() -> void:
	if current_state == WitcherState.DIALOG:
		return

	current_state = WitcherState.WORK
	play_animation("work_left")

	var wait_time := randf_range(work_min_time, work_max_time)
	await get_tree().create_timer(wait_time).timeout


func start_dialog() -> void:
	if is_talking:
		return

	if current_state == WitcherState.DIALOG:
		return

	if not player_near:
		return

	if player == null:
		player = get_any_near_player()

	if player == null:
		return

	is_talking = true
	current_state = WitcherState.DIALOG

	if talk_indicator != null:
		talk_indicator.visible = false

	set_all_players_control_enabled(false)

	if anim != null and anim.has_animation("idle_left"):
		anim.play("idle_left")

	var story_dialog = get_tree().current_scene.get_node_or_null("StoryDialog")

	if story_dialog == null:
		push_warning("Không tìm thấy StoryDialog trong scene hiện tại")
		finish_dialog_without_story()
		return

	if story_dialog.story_finished.is_connected(_on_dialog_finished):
		story_dialog.story_finished.disconnect(_on_dialog_finished)

	story_dialog.story_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)

	if talk_count == 0:
		story_dialog.start_story(get_first_dialog())
	else:
		story_dialog.start_story(get_repeat_dialog())


func _on_dialog_finished() -> void:
	talk_count += 1
	is_talking = false

	set_all_players_control_enabled(true)

	end_dialog()


func finish_dialog_without_story() -> void:
	is_talking = false

	set_all_players_control_enabled(true)

	end_dialog()


func end_dialog() -> void:
	if current_state != WitcherState.DIALOG:
		return

	current_state = WitcherState.IDLE

	if player_near and talk_indicator != null:
		talk_indicator.visible = true

	start_random_behavior()


func play_animation(anim_name: String) -> void:
	if anim == null:
		return

	if anim.has_animation(anim_name):
		anim.play(anim_name)
	else:
		push_warning("NPC Witcher thiếu animation: " + anim_name)


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
	var detected_player := find_player_from_node(target)

	if detected_player == null:
		return

	players_near[detected_player.get_instance_id()] = detected_player
	player_near = !players_near.is_empty()
	player = detected_player

	if current_state != WitcherState.DIALOG and talk_indicator != null:
		talk_indicator.visible = true


func try_remove_player_near(target: Node) -> void:
	var detected_player := find_player_from_node(target)

	if detected_player == null:
		return

	var id := detected_player.get_instance_id()

	if players_near.has(id):
		players_near.erase(id)

	player_near = !players_near.is_empty()

	if player == detected_player:
		player = get_any_near_player()

	if !player_near and talk_indicator != null:
		talk_indicator.visible = false


func find_player_from_node(node: Node) -> Player:
	var current := node

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


func get_player_pressed_interact() -> Player:
	for key in players_near.keys():
		var p: Player = players_near[key]

		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_method("is_interact_just_pressed"):
			if p.is_interact_just_pressed():
				return p
		else:
			var action_name := get_interact_action_for_player(p)

			if Input.is_action_just_pressed(action_name):
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


func get_first_dialog() -> Array:
	return [
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Ờm... xin chào bạn."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "..."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "............"
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Hello?"
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Bạn không thấy tôi đang bận sao? Với lại, tôi cũng không phải người nước ngoài."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Xin lỗi, tôi không có ý làm phiền. Tôi chỉ muốn chào hỏi một chút thôi."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Được rồi. Vậy để tôi tự giới thiệu."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Tên tôi là Marie Curie. Một ngày nào đó, tôi sẽ là nhà hóa học nổi tiếng nhất thế giới."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Không có thứ gì trên đời này mà tôi không thể hiểu được bản chất của nó."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Nếu bạn muốn mua gì ở chỗ tôi, cứ đến hỏi."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Nhưng đừng động vào vườn hoa tôi đã trồng."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Chúng đã thiếu nước trong một thời gian dài rồi."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Nơi quái quỷ này thiếu thốn đủ thứ. Đúng là địa ngục."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Ở đây tôi có thể nghiên cứu ra vài loại thuốc giúp cường hóa cơ thể."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Có lẽ chúng sẽ giúp ích cho bạn sau này."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Được rồi, tôi sẽ ghi nhớ."
		}
	]


func get_repeat_dialog() -> Array:
	return [
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Bạn cần mua gì?"
		}
	]
