extends CanvasLayer

@onready var root: Control = $Root
@onready var vbox: VBoxContainer = $Root/VBoxContainer

@onready var top_container: SubViewportContainer = $Root/VBoxContainer/TopViewportContainer
@onready var bottom_container: SubViewportContainer = $Root/VBoxContainer/BottomViewportContainer

@onready var viewport_p1: SubViewport = $Root/VBoxContainer/TopViewportContainer/SubViewportP1
@onready var viewport_p2: SubViewport = $Root/VBoxContainer/BottomViewportContainer/SubViewportP2

@onready var camera_p1: Camera2D = $Root/VBoxContainer/TopViewportContainer/SubViewportP1/CameraP1
@onready var camera_p2: Camera2D = $Root/VBoxContainer/BottomViewportContainer/SubViewportP2/CameraP2

@onready var divider: ColorRect = $Root/VBoxContainer/Divider

@export var camera_smooth_speed: float = 12.0
@export var camera_vertical_offset: float = -20.0

var player_1: Node2D = null
var player_2: Node2D = null


func _ready() -> void:
	layer = 50

	if !is_coop_mode():
		visible = false
		return

	visible = true

	await get_tree().process_frame
	await get_tree().process_frame

	setup_layout()
	setup_viewports()
	find_players()

	get_viewport().size_changed.connect(update_viewport_size)


func is_coop_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


func setup_layout() -> void:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 0
	vbox.offset_top = 0
	vbox.offset_right = 0
	vbox.offset_bottom = 0
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 0)

	top_container.stretch = true
	bottom_container.stretch = true

	top_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	divider.custom_minimum_size = Vector2(0, 4)
	divider.color = Color.BLACK
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE

	update_viewport_size()

func setup_viewports() -> void:
	viewport_p1.world_2d = get_viewport().world_2d
	viewport_p2.world_2d = get_viewport().world_2d

	viewport_p1.disable_3d = true
	viewport_p2.disable_3d = true

	viewport_p1.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_p2.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	camera_p1.enabled = true
	camera_p2.enabled = true

	camera_p1.make_current()
	camera_p2.make_current()

	top_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bottom_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vbox.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func update_viewport_size() -> void:
	var screen_size: Vector2i = get_viewport().get_visible_rect().size
	var divider_height: int = 4
	var half_height: int = int((screen_size.y - divider_height) / 2.0)

	top_container.custom_minimum_size = Vector2(screen_size.x, half_height)
	bottom_container.custom_minimum_size = Vector2(screen_size.x, half_height)

	viewport_p1.size = Vector2i(screen_size.x, half_height)
	viewport_p2.size = Vector2i(screen_size.x, half_height)


func find_players() -> void:
	player_1 = null
	player_2 = null

	var players := get_tree().get_nodes_in_group("players")

	for p in players:
		if !(p is Node2D):
			continue

		var id_value: int = int(p.get("player_id"))

		if id_value == 1:
			player_1 = p as Node2D
		elif id_value == 2:
			player_2 = p as Node2D

	if player_1 == null:
		player_1 = get_node_or_null("../World/Player") as Node2D

	if player_2 == null:
		player_2 = get_node_or_null("../World/Player2") as Node2D

	if player_1 != null:
		camera_p1.global_position = player_1.global_position + Vector2(0, camera_vertical_offset)

	if player_2 != null:
		camera_p2.global_position = player_2.global_position + Vector2(0, camera_vertical_offset)


func _process(delta: float) -> void:
	if !is_coop_mode():
		return

	if player_1 == null or player_2 == null:
		find_players()

	update_camera_follow(delta)


func update_camera_follow(delta: float) -> void:
	if player_1 != null:
		var target_p1 := player_1.global_position + Vector2(0, camera_vertical_offset)
		var new_pos_p1 := camera_p1.global_position.lerp(
			target_p1,
			camera_smooth_speed * delta
		)
		camera_p1.global_position = new_pos_p1.round()

	if player_2 != null:
		var target_p2 := player_2.global_position + Vector2(0, camera_vertical_offset)
		var new_pos_p2 := camera_p2.global_position.lerp(
			target_p2,
			camera_smooth_speed * delta
		)
		camera_p2.global_position = new_pos_p2.round()
