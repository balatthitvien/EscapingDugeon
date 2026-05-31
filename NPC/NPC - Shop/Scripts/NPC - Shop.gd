extends CharacterBody2D

enum ShopState {
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

@export var idle_min_time: float = 2.0
@export var idle_max_time: float = 4.0

@export var chill_min_time: float = 2.0
@export var chill_max_time: float = 4.0

@export var work_min_time: float = 2.0
@export var work_max_time: float = 5.0

var current_state: ShopState = ShopState.IDLE
var player_near: bool = false
var player: Player = null
var is_running_behavior: bool = false
var is_talking: bool = false
var talk_count: int = 0
var should_open_shop_after_dialog: bool = false

func _ready() -> void:
	randomize()

	talk_indicator.visible = false
	talk_indicator.z_index = 20

	if !talk_area.body_entered.is_connected(_on_talk_area_body_entered):
		talk_area.body_entered.connect(_on_talk_area_body_entered)

	if !talk_area.body_exited.is_connected(_on_talk_area_body_exited):
		talk_area.body_exited.connect(_on_talk_area_body_exited)

	start_random_behavior()


func _process(_delta: float) -> void:
	if player_near and Input.is_action_just_pressed("interact"):
		start_dialog()


func start_random_behavior() -> void:
	if is_running_behavior:
		return

	is_running_behavior = true

	while is_inside_tree():
		if current_state == ShopState.DIALOG:
			await get_tree().process_frame
			continue

		var available_actions: Array[String] = []

		if anim.has_animation("idle"):
			available_actions.append("idle")

		if anim.has_animation("chill"):
			available_actions.append("chill")

		if anim.has_animation("work"):
			available_actions.append("work")

		if available_actions.is_empty():
			push_warning("NPC Shop không có animation idle/chill/work")
			await get_tree().create_timer(1.0).timeout
			continue

		var chosen_action: String = available_actions.pick_random()

		match chosen_action:
			"idle":
				await do_idle()
			"chill":
				await do_chill()
			"work":
				await do_work()

	is_running_behavior = false


func do_idle() -> void:
	if current_state == ShopState.DIALOG:
		return

	current_state = ShopState.IDLE
	play_animation("idle")

	var wait_time := randf_range(idle_min_time, idle_max_time)
	await get_tree().create_timer(wait_time).timeout


func do_chill() -> void:
	if current_state == ShopState.DIALOG:
		return

	current_state = ShopState.CHILL
	play_animation("chill")

	var wait_time := randf_range(chill_min_time, chill_max_time)
	await get_tree().create_timer(wait_time).timeout


func do_work() -> void:
	if current_state == ShopState.DIALOG:
		return

	current_state = ShopState.WORK
	play_animation("work")

	var wait_time := randf_range(work_min_time, work_max_time)
	await get_tree().create_timer(wait_time).timeout


func start_dialog() -> void:
	if is_talking:
		return

	if current_state == ShopState.DIALOG:
		return

	is_talking = true
	current_state = ShopState.DIALOG
	talk_indicator.visible = false

	if player:
		player.set_control_enabled(false)

	if anim.has_animation("idle"):
		anim.play("idle")

	var story_dialog = get_tree().current_scene.get_node_or_null("StoryDialog")

	if story_dialog == null:
		push_warning("Không tìm thấy StoryDialog trong scene hiện tại")
		end_dialog()
		return

	story_dialog.story_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)

	should_open_shop_after_dialog = talk_count > 0

	if talk_count == 0:
		story_dialog.start_story(get_first_dialog())
	else:
		story_dialog.start_story(get_repeat_dialog())


func _on_dialog_finished() -> void:
	talk_count += 1
	is_talking = false

	if should_open_shop_after_dialog:
		open_shop_ui()
		return

	if player:
		player.set_control_enabled(true)

	end_dialog()
func open_shop_ui() -> void:
	var shop_ui = get_tree().current_scene.get_node_or_null("ShopUI")

	if shop_ui == null:
		shop_ui = get_tree().current_scene.find_child("ShopUI", true, false)

	if shop_ui == null:
		push_warning("Không tìm thấy ShopUI trong scene hiện tại.")

		if player:
			player.set_control_enabled(true)

		end_dialog()
		return

	if shop_ui.has_signal("closed") and not shop_ui.closed.is_connected(_on_shop_ui_closed):
		shop_ui.closed.connect(_on_shop_ui_closed)

	if shop_ui.has_method("open_shop"):
		shop_ui.open_shop(player)
	else:
		push_warning("ShopUI chưa có hàm open_shop().")

		if player:
			player.set_control_enabled(true)

		end_dialog()


func _on_shop_ui_closed() -> void:
	end_dialog()

func end_dialog() -> void:
	if current_state != ShopState.DIALOG:
		return

	current_state = ShopState.IDLE

	if player_near:
		talk_indicator.visible = true

	start_random_behavior()


func play_animation(anim_name: String) -> void:
	if anim.has_animation(anim_name):
		anim.play(anim_name)
	else:
		push_warning("NPC Shop thiếu animation: " + anim_name)


func _on_talk_area_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_near = true
		player = body as Player

		if current_state != ShopState.DIALOG:
			talk_indicator.visible = true


func _on_talk_area_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_near = false
		player = null
		talk_indicator.visible = false

		if current_state == ShopState.DIALOG:
			if is_talking:
				return

			end_dialog()


func get_first_dialog() -> Array:
	return [
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Xin chào ông. Cảm ơn vì đã cứu tôi."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Thay vì chỉ nói lời cảm ơn, sao cậu không làm điều gì đó thiết thực hơn nhỉ?"
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Thiết thực hơn?"
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Cậu biết đấy, dù ở đâu thì thế giới này vẫn vận hành quanh đồng tiền."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Xin lỗi... nhưng hiện tại tôi chẳng có gì cả."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Không sao. Cậu có thể trả ơn tôi sau cũng được."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Mang ít đồ ăn về cho mọi người cũng là một cách hợp lý đấy."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Đừng thấy tôi to con rồi nghĩ tôi ăn hết phần của mọi người nhé."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Tôi thuộc bộ tộc người khổng lồ, nên cơ thể có hơi lớn hơn người thường một chút thôi."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Tôi cũng đã nói gì đâu..."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Bỏ qua đi. Ở đây tôi có bán một số vật dụng."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Có thể chúng sẽ giúp cậu sống sót lâu hơn... thậm chí là đánh bại tên Sừng Vàng."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Nhưng tất nhiên, mọi thứ đều phải tuân theo quy tắc trao đổi đồng giá."
		},
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Trên đời này không có gì là miễn phí cả."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Cảm ơn ông. Tôi sẽ ghi nhớ."
		}
	]


func get_repeat_dialog() -> Array:
	return [
		{
			"speaker": "npc",
			"portrait": npc_portrait,
			"text": "Cậu cần mua gì? Nhớ nhé, trao đổi đồng giá."
		}
	]
