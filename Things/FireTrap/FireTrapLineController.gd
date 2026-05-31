extends Node2D

@export var trap_paths: Array[NodePath] = []

@export var start_delay: float = 0.0
@export var step_delay: float = 0.25
@export var pause_at_end: float = 0.0

var traps: Array[Node] = []
var current_index: int = 0
var direction: int = 1
var previous_trap: Node = null
var is_running: bool = true


func _ready() -> void:
	collect_traps()
	force_all_traps_off()

	await get_tree().create_timer(start_delay).timeout

	start_wave_loop()


func collect_traps() -> void:
	traps.clear()

	for path in trap_paths:
		var trap := get_node_or_null(path)

		if trap != null:
			traps.append(trap)

	if traps.is_empty():
		push_warning(name + " chưa gán trap_paths.")


func force_all_traps_off() -> void:
	for trap in traps:
		if trap != null and trap.has_method("force_fire_off"):
			trap.force_fire_off()


func start_wave_loop() -> void:
	if traps.is_empty():
		return

	current_index = 0
	direction = 1

	while is_inside_tree() and is_running:
		var current_trap: Node = traps[current_index]

		if previous_trap != null and previous_trap.has_method("force_fire_off"):
			previous_trap.force_fire_off()

		if current_trap != null and current_trap.has_method("play_fire"):
			current_trap.play_fire()

		previous_trap = current_trap

		await get_tree().create_timer(step_delay).timeout

		var next_index: int = current_index + direction

		if next_index >= traps.size():
			direction = -1
			next_index = traps.size() - 2

			if pause_at_end > 0.0:
				await get_tree().create_timer(pause_at_end).timeout

		elif next_index < 0:
			direction = 1
			next_index = 1

			if pause_at_end > 0.0:
				await get_tree().create_timer(pause_at_end).timeout

		current_index = next_index
