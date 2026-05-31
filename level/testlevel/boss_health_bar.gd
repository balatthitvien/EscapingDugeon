extends CanvasLayer

@onready var ui_root: Control = $UIRoot
@onready var boss_bar_root: Control = $UIRoot/BossBarRoot
@onready var boss_hp: TextureProgressBar = $UIRoot/BossBarRoot/BossHP
@onready var boss_frame: TextureRect = $UIRoot/BossBarRoot/BossFrame
@onready var boss_name: TextureRect = $UIRoot/BossBarRoot/BossName


func _ready() -> void:
	visible = false

	await get_tree().process_frame
	setup_position()


func setup_position() -> void:
	# UIRoot phủ toàn màn hình
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.offset_left = 0
	ui_root.offset_top = 0
	ui_root.offset_right = 0
	ui_root.offset_bottom = 0

	# BossBarRoot nằm giữa dưới màn hình
	boss_bar_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	boss_bar_root.offset_left = -260
	boss_bar_root.offset_right = 260
	boss_bar_root.offset_top = -72
	boss_bar_root.offset_bottom = -16
	boss_bar_root.scale = Vector2.ONE

	# Ép các node con không được tự kéo giãn
	reset_control(boss_hp)
	reset_control(boss_frame)
	reset_control(boss_name)

	# Tên boss
	boss_name.position = Vector2(150, 20)
	boss_name.size = Vector2(220, 14)
	boss_name.scale = Vector2.ONE
	boss_name.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Thanh máu đỏ
	boss_hp.position = Vector2(91, 27)
	boss_hp.size = Vector2(300, 6)
	boss_hp.scale = Vector2.ONE
	boss_hp.custom_minimum_size = Vector2.ZERO
	boss_hp.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT

	# Khung/vạch chia
	boss_frame.position = Vector2(90, 24)
	boss_frame.size = Vector2(340, 6)
	boss_frame.scale = Vector2.ONE
	boss_frame.custom_minimum_size = Vector2.ZERO
	boss_frame.stretch_mode = TextureRect.STRETCH_SCALE
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_name.mouse_filter = Control.MOUSE_FILTER_IGNORE

func reset_control(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func show_bar() -> void:
	visible = true


func hide_bar() -> void:
	visible = false


func setup(max_health: int) -> void:
	boss_hp.min_value = 0
	boss_hp.max_value = max_health
	boss_hp.value = max_health


func update_health(current_health: int, max_health: int) -> void:
	print("BossHP value set: ", current_health, "/", max_health)

	boss_hp.max_value = max_health
	boss_hp.value = current_health
