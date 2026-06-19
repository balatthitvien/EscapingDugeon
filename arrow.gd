extends Area2D

@export var speed: float = 420.0
@export var damage: int = 1
@export var life_time: float = 2.5

var direction: int = 1
var has_hit: bool = false
var life_timer: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = true

	if !area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if !body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	var notifier := get_node_or_null("VisibleOnScreenNotifier2D") as VisibleOnScreenNotifier2D

	if notifier != null:
		notifier.screen_exited.connect(queue_free)


func setup_arrow(new_direction: int, new_damage: int) -> void:
	if new_direction < 0:
		direction = -1
	else:
		direction = 1

	damage = new_damage

	scale.x = abs(scale.x) * float(direction)


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	life_timer += delta

	if life_timer >= life_time:
		queue_free()
		return

	global_position.x += speed * float(direction) * delta


func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return

	print("Arrow touched area: ", area.name, " | parent: ", area.get_parent().name)

	try_hit_target(area)


func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return

	print("Arrow touched body: ", body.name)

	try_hit_target(body)


func try_hit_target(target: Node) -> void:
	if has_hit:
		return

	if target == null:
		return

	if is_player_node(target):
		return

	# Trường hợp trúng trực tiếp HitBox của quái.
	if target is HitBox:
		has_hit = true

		print("Arrow hit HitBox: ", target.name, " | damage = ", damage)

		(target as HitBox).Damaged.emit(damage)

		queue_free()
		return

	# Trường hợp target không cast được HitBox nhưng vẫn có signal Damaged.
	if target.has_signal("Damaged"):
		has_hit = true

		print("Arrow hit signal Damaged: ", target.name, " | damage = ", damage)

		target.emit_signal("Damaged", damage)

		queue_free()
		return

	# Trường hợp chạm child của quái, đi ngược lên parent để tìm take_damage.
	var current := target

	while current != null:
		if is_player_node(current):
			return

		if current.has_method("take_damage"):
			has_hit = true

			print("Arrow hit enemy by take_damage: ", current.name, " | damage = ", damage)

			current.take_damage(damage)

			queue_free()
			return

		current = current.get_parent()


func is_player_node(target: Node) -> bool:
	if target == null:
		return false

	if target is Player:
		return true

	if target.name == "Player":
		return true

	if target.name == "Player2":
		return true

	if target.is_in_group("players"):
		return true

	return false
