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

var player_in_range: bool = false
var player: Player = null
var is_talking: bool = false
var talk_count: int = 0
var has_pressed_interact_once: bool = false


func _ready() -> void:
	# Lấy lại lịch sử hội thoại đã lưu trong LevelManager
	talk_count = LevelManager.get_npc_talk_count(npc_id)
	has_pressed_interact_once = LevelManager.has_npc_pressed_interact_once(npc_id)

	talk_indicator.visible = false
	talk_indicator.z_index = 20

	if start_direction == "left":
		animation_player.play("idle_left")
	else:
		animation_player.play("idle_right")

	if not talk_area.body_entered.is_connected(_on_talk_area_body_entered):
		talk_area.body_entered.connect(_on_talk_area_body_entered)

	if not talk_area.body_exited.is_connected(_on_talk_area_body_exited):
		talk_area.body_exited.connect(_on_talk_area_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if !player_in_range:
		return

	if is_talking:
		return

	if event.is_action_pressed("interact"):
		if !has_pressed_interact_once:
			has_pressed_interact_once = true
			LevelManager.set_npc_pressed_interact_once(npc_id, true)
			first_interact_pressed.emit()

		start_talk()
		get_viewport().set_input_as_handled()


func start_talk() -> void:
	is_talking = true
	talk_indicator.visible = false

	if player:
		player.set_control_enabled(false)

	var story_dialog = get_tree().current_scene.get_node_or_null("StoryDialog")

	if story_dialog == null:
		push_warning("Không tìm thấy StoryDialog trong scene hiện tại.")
		is_talking = false

		if player:
			player.set_control_enabled(true)

		if player_in_range:
			talk_indicator.visible = true

		return

	story_dialog.story_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)

	if talk_count == 0:
		story_dialog.start_story(get_first_dialog())
	else:
		story_dialog.start_story(get_second_dialog())


func _on_dialog_finished() -> void:
	is_talking = false

	talk_count += 1
	LevelManager.set_npc_talk_count(npc_id, talk_count)

	if player:
		player.set_control_enabled(true)

	if player_in_range:
		talk_indicator.visible = true


func _on_talk_area_body_entered(body: Node2D) -> void:
	var detected_player: Player = find_player_from_node(body)

	if detected_player == null:
		return

	player_in_range = true
	player = detected_player

	player_entered_talk_range.emit()

	if !is_talking:
		talk_indicator.visible = true


func _on_talk_area_body_exited(body: Node2D) -> void:
	var detected_player: Player = find_player_from_node(body)

	if detected_player == null:
		return

	if detected_player != player:
		return

	player_in_range = false
	player = null

	player_exited_talk_range.emit()

	talk_indicator.visible = false


func find_player_from_node(node: Node) -> Player:
	var current: Node = node

	while current != null:
		if current is Player:
			return current as Player

		if current.is_in_group("player"):
			return current as Player

		if current.name == "Player":
			return current as Player

		current = current.get_parent()

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
			"text": "Tất cả chúng tôi đều bị dịch chuyển đến đây. Không ai biết nơi này thật sự là đâu"
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "và cũng chưa ai tìm được đường thoát ra ngoài."
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
			"text": "Chúng tôi không có khả năng chiến đấu. Vì vậy, chỉ có thể tạm trú, cố gắng sinh tồn ở đây."
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
			"text": "Cậu có thể giúp chúng tôi tìm một ít vật tư không?"
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Lương thực, nước uống, hay bất kể thứ gì đều rất cần thiết cho mọi người."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Nếu cậu giúp được, mọi người sẽ rất biết ơn cậu."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Được. Cứ để đó cho tôi."
		}
	]
