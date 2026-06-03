extends CharacterBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collect_sound: AudioStreamPlayer2D = $AudioStreamPlayer2D

@onready var collect_area: Area2D = $CollectArea
@onready var collect_area_collision: CollisionShape2D = $CollectArea/CollisionShape2D

@export var idle_animation_name: String = "idle"
@export var collected_animation_name: String = ""
@export var coin_value: int = 1

# false = coin đặt sẵn trên map, không rơi, không văng
# true = coin rơi ra từ quái, có gravity và văng nhẹ
@export var is_drop_coin: bool = false

@export var gravity: float = 900.0
@export var bounce_force: float = -180.0
@export var horizontal_force: float = 60.0
@export var max_fall_speed: float = 500.0
@export var ground_friction: float = 400.0

var is_collected: bool = false
var has_landed: bool = false


func _ready() -> void:
	randomize()

	floor_snap_length = 6.0

	setup_collect_area()

	if is_drop_coin:
		start_drop_motion()
	else:
		# Coin đặt sẵn trên map đứng yên tại vị trí đã đặt
		velocity = Vector2.ZERO
		has_landed = true

	play_idle_animation()


func setup_collect_area() -> void:
	if collect_area != null:
		collect_area.monitoring = true
		collect_area.monitorable = true

		if not collect_area.body_entered.is_connected(_on_collect_area_body_entered):
			collect_area.body_entered.connect(_on_collect_area_body_entered)

		if not collect_area.area_entered.is_connected(_on_collect_area_area_entered):
			collect_area.area_entered.connect(_on_collect_area_area_entered)

	if collect_area_collision != null:
		collect_area_collision.disabled = false


func start_drop_motion() -> void:
	has_landed = false

	velocity.x = randf_range(-horizontal_force, horizontal_force)
	velocity.y = bounce_force


func _physics_process(delta: float) -> void:
	if is_collected:
		return

	# Coin đặt sẵn trên map thì không chạy vật lý
	if not is_drop_coin:
		return

	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	else:
		if not has_landed:
			has_landed = true
			velocity.y = 0.0

		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)

	move_and_slide()


func play_idle_animation() -> void:
	if animation_player == null:
		return

	if animation_player.has_animation(idle_animation_name):
		animation_player.play(idle_animation_name)
	else:
		push_warning("Coin thiếu animation: " + idle_animation_name)


func _on_collect_area_body_entered(body: Node2D) -> void:
	if is_collected:
		return

	var player: Node = find_player_from_node(body)

	if player == null:
		return

	collect_coin(player)


func _on_collect_area_area_entered(area: Area2D) -> void:
	if is_collected:
		return

	var player: Node = find_player_from_node(area)

	if player == null:
		return

	collect_coin(player)


func collect_coin(player: Node) -> void:
	is_collected = true

	if collision_shape != null:
		collision_shape.disabled = true

	if collect_area != null:
		collect_area.monitoring = false
		collect_area.monitorable = false

	if collect_area_collision != null:
		collect_area_collision.disabled = true

	if player.has_method("add_coin"):
		player.add_coin(coin_value)
	elif player.has_method("add_coins"):
		player.add_coins(coin_value)
	else:
		print("Player chưa có hàm add_coin() hoặc add_coins(). Coin vẫn được nhặt.")

	if collect_sound != null:
		collect_sound.play()

	if collected_animation_name != "" and animation_player != null and animation_player.has_animation(collected_animation_name):
		animation_player.play(collected_animation_name)
		await animation_player.animation_finished
	else:
		sprite_2d.visible = false

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
