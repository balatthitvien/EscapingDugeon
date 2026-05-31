extends Area2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collect_sound: AudioStreamPlayer2D = $AudioStreamPlayer2D

@export var idle_animation_name: String = "idle"
@export var collected_animation_name: String = ""
@export var coin_value: int = 1

var is_collected: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = true

	if collision_shape != null:
		collision_shape.disabled = false

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	play_idle_animation()


func play_idle_animation() -> void:
	if animation_player == null:
		return

	if animation_player.has_animation(idle_animation_name):
		animation_player.play(idle_animation_name)
	else:
		push_warning("Coin thiếu animation: " + idle_animation_name)


func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return

	var player: Node = find_player_from_node(body)

	if player == null:
		return

	collect_coin(player)


func collect_coin(player: Node) -> void:
	is_collected = true

	if collision_shape != null:
		collision_shape.disabled = true

	monitoring = false
	monitorable = false

	# Nếu Player có hàm cộng coin thì gọi
	if player.has_method("add_coin"):
		player.add_coin(coin_value)
	elif player.has_method("add_coins"):
		player.add_coins(coin_value)
	else:
		print("Player chưa có hàm add_coin() hoặc add_coins(). Coin vẫn được nhặt.")

	if collect_sound != null:
		collect_sound.play()

	# Nếu có animation nhặt coin riêng thì chạy
	if collected_animation_name != "" and animation_player.has_animation(collected_animation_name):
		animation_player.play(collected_animation_name)
		await animation_player.animation_finished
	else:
		sprite_2d.visible = false

	# Đợi sound phát xong rồi mới xóa coin
	if collect_sound != null and collect_sound.stream != null:
		await collect_sound.finished

	queue_free()


func find_player_from_node(node: Node) -> Node:
	var current: Node = node

	while current != null:
		if current is Player:
			return current

		if current.is_in_group("player"):
			return current

		if current.is_in_group("Player"):
			return current

		if current.name == "Player":
			return current

		current = current.get_parent()

	return null
