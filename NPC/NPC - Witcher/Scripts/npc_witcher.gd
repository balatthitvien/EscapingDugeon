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
var is_running_behavior: bool = false
var is_talking: bool = false
var talk_count: int = 0


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

	is_talking = true
	current_state = WitcherState.DIALOG
	talk_indicator.visible = false

	if player:
		player.set_control_enabled(false)

	if anim.has_animation("idle_left"):
		anim.play("idle_left")

	var story_dialog = get_tree().current_scene.get_node_or_null("StoryDialog")

	if story_dialog == null:
		push_warning("Không tìm thấy StoryDialog trong scene hiện tại")
		end_dialog()
		return

	story_dialog.story_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)

	if talk_count == 0:
		story_dialog.start_story(get_first_dialog())
	else:
		story_dialog.start_story(get_repeat_dialog())


func _on_dialog_finished() -> void:
	talk_count += 1
	is_talking = false

	if player:
		player.set_control_enabled(true)

	end_dialog()


func end_dialog() -> void:
	if current_state != WitcherState.DIALOG:
		return

	current_state = WitcherState.IDLE

	if player_near:
		talk_indicator.visible = true

	start_random_behavior()


func play_animation(anim_name: String) -> void:
	if anim.has_animation(anim_name):
		anim.play(anim_name)
	else:
		push_warning("NPC Witcher thiếu animation: " + anim_name)


func _on_talk_area_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_near = true
		player = body as Player

		if current_state != WitcherState.DIALOG:
			talk_indicator.visible = true


func _on_talk_area_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_near = false
		player = null
		talk_indicator.visible = false

		if current_state == WitcherState.DIALOG:
			if is_talking:
				return

			end_dialog()


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
