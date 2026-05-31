extends CharacterBody2D

enum NPCState {
	IDLE,
	WORKING,
	DIALOG
}

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var talk_indicator: Sprite2D = $TalkIndicator

@export var player_portrait: Texture2D
@export var npc_portrait: Texture2D
@export var npc_id: String = "npc_blacksmith"

@export var upgrade_ui_scene: PackedScene
@export var weapon_texture: Texture2D

var talk_area: Area2D = null
var current_state: NPCState = NPCState.IDLE

var player_near: bool = false
var player: Player = null

var is_busy: bool = false
var is_talking: bool = false
var talk_count: int = 0

var upgrade_ui: CanvasLayer = null
var should_open_upgrade_after_dialog: bool = false


func _ready() -> void:
	randomize()

	talk_count = LevelManager.get_npc_talk_count(npc_id)

	if talk_indicator != null:
		talk_indicator.visible = false
		talk_indicator.z_index = 20

	talk_area = get_node_or_null("TalkArea") as Area2D

	if talk_area == null:
		talk_area = get_node_or_null("Area2D") as Area2D

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
		push_error("NPC Blacksmith thiếu TalkArea hoặc Area2D.")

	start_random_behavior()


func _process(_delta: float) -> void:
	if is_talking:
		return

	if current_state == NPCState.DIALOG:
		return

	if upgrade_ui != null and upgrade_ui.visible:
		return

	if not player_near:
		return

	if Input.is_action_just_pressed("interact"):
		start_dialog()


func start_random_behavior() -> void:
	if is_busy:
		return

	is_busy = true

	while is_inside_tree():
		if current_state == NPCState.DIALOG:
			await get_tree().process_frame
			continue

		var action := randi_range(0, 1)

		if action == 0:
			await do_idle()
		else:
			await do_work()

	is_busy = false


func do_idle() -> void:
	if current_state == NPCState.DIALOG:
		return

	current_state = NPCState.IDLE

	if anim != null and anim.has_animation("idle"):
		anim.play("idle")

	var wait_time := randf_range(1.5, 4.0)
	await get_tree().create_timer(wait_time).timeout


func do_work() -> void:
	if current_state == NPCState.DIALOG:
		return

	current_state = NPCState.WORKING

	if anim != null and anim.has_animation("idle_to_work"):
		anim.play("idle_to_work")
		await anim.animation_finished

	if current_state == NPCState.DIALOG:
		return

	if anim != null and anim.has_animation("work_loop"):
		anim.play("work_loop")

	var work_time := randf_range(2.0, 5.0)
	await get_tree().create_timer(work_time).timeout

	if current_state == NPCState.DIALOG:
		return

	if anim != null and anim.has_animation("work_to_idle"):
		anim.play("work_to_idle")
		await anim.animation_finished


func start_dialog() -> void:
	if is_talking:
		return

	if not player_near:
		return

	is_talking = true
	current_state = NPCState.DIALOG
	should_open_upgrade_after_dialog = false

	if talk_indicator != null:
		talk_indicator.visible = false

	if player != null:
		player.set_control_enabled(false)

	if anim != null:
		if anim.current_animation == "work_loop" or anim.current_animation == "idle_to_work":
			if anim.has_animation("work_to_idle"):
				anim.play("work_to_idle")
				await anim.animation_finished

	if current_state != NPCState.DIALOG:
		return

	if anim != null:
		if anim.has_animation("dialog_stand"):
			anim.play("dialog_stand")
		elif anim.has_animation("idle"):
			anim.play("idle")

	var story_dialog = get_tree().current_scene.get_node_or_null("StoryDialog")

	if story_dialog == null:
		push_error("Không tìm thấy StoryDialog trong scene hiện tại.")
		finish_without_upgrade()
		return

	if story_dialog.story_finished.is_connected(_on_dialog_finished):
		story_dialog.story_finished.disconnect(_on_dialog_finished)

	story_dialog.story_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)

	if talk_count == 0:
		should_open_upgrade_after_dialog = false
		story_dialog.start_story(get_first_dialog())
	else:
		should_open_upgrade_after_dialog = true
		story_dialog.start_story(get_repeat_dialog())


func _on_dialog_finished() -> void:
	talk_count += 1
	LevelManager.set_npc_talk_count(npc_id, talk_count)

	is_talking = false

	if should_open_upgrade_after_dialog:
		open_upgrade_menu()
		return

	finish_without_upgrade()


func finish_without_upgrade() -> void:
	if player != null:
		player.set_control_enabled(true)

	end_dialog()


func end_dialog() -> void:
	current_state = NPCState.IDLE
	is_busy = false

	if player_near and talk_indicator != null:
		talk_indicator.visible = true

	start_random_behavior()


func open_upgrade_menu() -> void:
	create_upgrade_ui()

	if upgrade_ui == null:
		push_error("Không mở được menu upgrade. Kiểm tra đã gán Upgrade UI Scene chưa.")

		if player != null:
			player.set_control_enabled(true)

		end_dialog()
		return

	if upgrade_ui.has_method("open_menu"):
		upgrade_ui.open_menu(player)
	else:
		push_error("Upgrade UI thiếu hàm open_menu().")

		if player != null:
			player.set_control_enabled(true)

		end_dialog()


func create_upgrade_ui() -> void:
	if upgrade_ui != null:
		return

	if upgrade_ui_scene == null:
		push_error("NPC Blacksmith chưa gán Upgrade UI Scene trong Inspector.")
		return

	var ui_instance: Node = upgrade_ui_scene.instantiate()

	if not ui_instance is CanvasLayer:
		push_error("Upgrade UI Scene phải có root là CanvasLayer.")
		ui_instance.queue_free()
		return

	upgrade_ui = ui_instance as CanvasLayer
	get_tree().current_scene.add_child(upgrade_ui)

	upgrade_ui.set("weapon_texture", weapon_texture)

	if upgrade_ui.has_signal("closed"):
		if not upgrade_ui.closed.is_connected(_on_upgrade_ui_closed):
			upgrade_ui.closed.connect(_on_upgrade_ui_closed)


func _on_upgrade_ui_closed() -> void:
	if player != null:
		player.set_control_enabled(true)

	end_dialog()


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

	player_near = true
	player = detected_player

	if current_state != NPCState.DIALOG and talk_indicator != null:
		talk_indicator.visible = true


func try_remove_player_near(target: Node) -> void:
	var detected_player := find_player_from_node(target)

	if detected_player == null:
		return

	if detected_player != player:
		return

	player_near = false
	player = null

	if talk_indicator != null:
		talk_indicator.visible = false


func find_player_from_node(node: Node) -> Player:
	var current := node

	while current != null:
		if current is Player:
			return current as Player

		if current.is_in_group("player"):
			return current as Player

		if current.is_in_group("Player"):
			return current as Player

		if current.name == "Player":
			return current as Player

		current = current.get_parent()

	return null


func get_first_dialog() -> Array:
	return [
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Ồ... cuối cùng cậu cũng tỉnh rồi."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Là mọi người đã cứu tôi sao? Cảm ơn... tôi thật sự rất biết ơn."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Đừng cảm ơn vội. Thành thật mà nói, chúng tôi cũng chỉ may mắn thôi."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Lúc tìm thấy cậu, tên Sừng Vàng vẫn còn đang canh giữ gần đó."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Không phải ai cũng muốn mạo hiểm cứu cậu. Có người đã bỏ cuộc ngay khi nhìn thấy hắn."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Nhưng Jack thì khác. Hắn lao vào kéo cậu ra, dù chỉ cần sơ suất một chút là hắn đã bỏ mạng."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "May cho hắn là không làm kinh động đến tên quái vật đó."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Jack? Anh có thể cho tôi biết Jack là ai không?"
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Cậu có thấy gã khổng lồ ở đằng kia không? Chính là hắn đấy."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Bình thường tôi không ưa hắn lắm."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Jack hay hành động ích kỷ, lại chẳng mấy khi nghe lời ai."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Nhưng chuyện hắn cứu cậu... tôi phải thừa nhận là rất đáng nể."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Nếu sau này cậu cần rèn, sửa hay đúc vũ khí, cứ đến chỗ tôi."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Tôi nghe nói cậu muốn đánh bại Sừng Vàng. Nếu thật vậy, tôi cũng muốn góp chút sức."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Tôi đã mắc kẹt ở nơi này quá lâu rồi."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Tôi hiểu rồi. Tôi sẽ ghi nhớ điều đó."
		}
	]


func get_repeat_dialog() -> Array:
	return [
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Cậu cần tôi giúp gì sao?"
		}
	]
