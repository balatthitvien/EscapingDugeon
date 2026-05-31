extends Area2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visible_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

@export var speed: float = 260.0
@export var damage: int = 1
@export var life_time: float = 5

# Nếu ảnh mũi tên của bạn mặc định quay sang phải thì để 0.
# Nếu ảnh mặc định quay sang trái thì để 180.
@export var sprite_angle_offset_degrees: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var is_active: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if visible_notifier != null:
		if not visible_notifier.screen_exited.is_connected(_on_screen_exited):
			visible_notifier.screen_exited.connect(_on_screen_exited)

	await get_tree().create_timer(life_time).timeout

	if is_inside_tree():
		queue_free()


func setup_arrow(new_direction: Vector2, new_speed: float, new_damage: int) -> void:
	direction = new_direction.normalized()
	speed = new_speed
	damage = new_damage
	is_active = true

	rotation = direction.angle() + deg_to_rad(sprite_angle_offset_degrees)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	try_hit_target(body)


func _on_area_entered(area: Area2D) -> void:
	try_hit_target(area)


func try_hit_target(target: Node) -> void:
	if not is_active:
		return

	var detected_player: Player = find_player_from_node(target)

	if detected_player != null:
		if detected_player.has_method("take_damage"):
			detected_player.take_damage(damage, global_position)

		queue_free()
		return

	# Nếu mũi tên chạm tường / tilemap / vật cản thì biến mất.
	if target is TileMapLayer:
		queue_free()
		return

	if target is StaticBody2D:
		queue_free()
		return


func _on_screen_exited() -> void:
	queue_free()


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

	if PlayerManager.player != null and PlayerManager.player is Player:
		return PlayerManager.player as Player

	return null
