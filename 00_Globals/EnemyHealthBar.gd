extends Node2D

@export var bar_size: Vector2 = Vector2(32, 4)
@export var bar_offset: Vector2 = Vector2(-16, -28)
@export var hide_delay: float = 7.0

var background: ColorRect
var fill: ColorRect
var hide_timer: Timer

var max_value: int = 1
var current_value: int = 1


func _ready() -> void:
	position = bar_offset
	visible = false
	z_index = 100

	create_bar()
	create_timer()


func create_bar() -> void:
	background = ColorRect.new()
	background.name = "Background"
	add_child(background)
	background.position = Vector2.ZERO
	background.size = bar_size
	background.color = Color(0.08, 0.08, 0.08, 0.9)

	fill = ColorRect.new()
	fill.name = "Fill"
	add_child(fill)
	fill.position = Vector2(1, 1)
	fill.size = Vector2(bar_size.x - 2, bar_size.y - 2)
	fill.color = Color(0.85, 0.05, 0.05, 1.0)


func create_timer() -> void:
	hide_timer = Timer.new()
	hide_timer.name = "HideTimer"
	hide_timer.wait_time = hide_delay
	hide_timer.one_shot = true
	add_child(hide_timer)

	hide_timer.timeout.connect(_on_hide_timer_timeout)


func set_health(current_health: int, max_health: int) -> void:
	max_value = max(max_health, 1)
	current_value = clamp(current_health, 0, max_value)

	update_bar()


func show_damage_health(current_health: int, max_health: int) -> void:
	set_health(current_health, max_health)

	visible = true

	hide_timer.stop()
	hide_timer.start()


func update_bar() -> void:
	if fill == null:
		return

	var ratio: float = float(current_value) / float(max_value)
	ratio = clamp(ratio, 0.0, 1.0)

	fill.size.x = (bar_size.x - 2) * ratio


func _on_hide_timer_timeout() -> void:
	visible = false
