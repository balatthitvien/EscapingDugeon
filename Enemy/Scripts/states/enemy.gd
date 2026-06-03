class_name Enemy
extends CharacterBody2D

@onready var attack_sound: AudioStreamPlayer2D = $Audio/Attack
@onready var footstep_sound: AudioStreamPlayer2D = $Audio/Footstep

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var dash_sprite_2d: Sprite2D = $DashSprite2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var state_machine: EnemyStateMachine = $EnemyStateMachine
@onready var vision_area: VisionArea = $VisionArea
@onready var hit_box: HitBox = $HitBox

@onready var attack_hurt_box: Area2D = $Sprite2D/AttackHurtBox
@onready var attack_hurt_box_collision: CollisionShape2D = $Sprite2D/AttackHurtBox/CollisionShape2D

@onready var dash_hurt_box: Area2D = $DashSprite2D/DashHurtBox
@onready var dash_hurt_box_collision: CollisionShape2D = $DashSprite2D/DashHurtBox/CollisionShape2D
@onready var dash_sound: AudioStreamPlayer2D = $Audio/Dash

@export var map_limit_padding: float = 24
@export var patrol_points: Node

@export var move_speed: float = 50
@export var chase_speed: float = 65
@export var random_move_speed: float = 55
@export var gravity: float = 1000
@export var wait_time: float = 1

@export var attack_distance: float = 35
@export var random_move_time: float = 2

@export var chase_speed_min_multiplier: float = 0.85
@export var chase_speed_max_multiplier: float = 1.25

@export var chase_decision_min_time: float = 0.5
@export var chase_decision_max_time: float = 1.1

@export var chase_pause_chance: float = 0.06
@export var chase_backstep_chance: float = 0.08
@export var chase_lunge_chance: float = 0.16

@export var chase_pause_time: float = 0.15
@export var chase_backstep_time: float = 0.22
@export var chase_lunge_time: float = 0.22

@export var max_health: int = 20
@export var lost_player_grace_time: float = 1.5


# =========================
# PHASE SPEED
# =========================
# Khi boss xuống các mốc máu, tốc chạy và tốc đánh sẽ tăng.
@export var speed_multiplier_above_75: float = 1.0
@export var speed_multiplier_below_75: float = 1.3
@export var speed_multiplier_below_50: float = 1.5
@export var speed_multiplier_below_25: float = 1.8

@export var attack_anim_multiplier_above_75: float = 1.0
@export var attack_anim_multiplier_below_75: float = 1.15
@export var attack_anim_multiplier_below_50: float = 1.35
@export var attack_anim_multiplier_below_25: float = 1.6

var base_move_speed: float = 50
var base_chase_speed: float = 65
var base_random_move_speed: float = 55
var base_dash_speed: float = 690
var current_phase_speed_multiplier: float = 1.0
var current_phase_attack_anim_multiplier: float = 1.0


# =========================
# ATTACK FIX
# =========================
# Dùng thêm check khoảng cách thủ công để boss vẫn đánh trúng Player
# kể cả khi Player đứng im sẵn trong vùng đánh.
@export var manual_attack_check_enabled: bool = true
@export var manual_attack_hit_distance_x: float = 58.0
@export var manual_attack_hit_distance_y: float = 42.0
@export var manual_attack_back_tolerance: float = 8.0
@export var attack_only_hits_facing_direction: bool = true

var is_attack_hurt_box_active: bool = false
var has_attack_hit_player: bool = false


# DASH
@export var dash_speed: float = 690.0
@export var dash_cooldown: float = 1
@export var dash_chance: float = 0.65
@export var dash_min_distance: float = 40
@export var dash_max_distance: float = 360
@export var dash_unlock_health_ratio: float = 0.5

var can_dash_now: bool = true


# SOUND
@export var attack_pitch_min: float = 0.5
@export var attack_pitch_max: float = 0.7
@export var attack_volume_db: float = 4.0

@export var footstep_pitch_min: float = 0.75
@export var footstep_pitch_max: float = 1.15
@export var footstep_volume_min_db: float = -2.0
@export var footstep_volume_max_db: float = 1.0
@export var dash_pitch_min: float = 0.7
@export var dash_pitch_max: float = 0.9
@export var dash_volume_db: float = 6

var player: Player
var current_health: int

var direction: Vector2 = Vector2.LEFT
var facing_direction: int = -1
var current_base_animation: String = ""

var lost_player_timer: float = 0.0
var can_see_player: bool = false

var left_limit: float = -999999.0
var right_limit: float = 999999.0

var point_positions: Array[Vector2] = []
var current_point_index: int = 0
var current_target: Vector2

var can_play_footstep_sound: bool = true


signal direction_changed(new_direction: Vector2)
signal health_changed(current_health: int, max_health: int)
signal boss_started
signal died


func _ready() -> void:
	use_normal_sprite()

	base_move_speed = move_speed
	base_chase_speed = chase_speed
	base_random_move_speed = random_move_speed
	base_dash_speed = dash_speed

	current_health = max_health
	update_health_phase()
	health_changed.emit(current_health, max_health)

	hit_box.Damaged.connect(_on_hit_box_damaged)

	attack_hurt_box.monitoring = false
	attack_hurt_box.monitorable = false
	attack_hurt_box_collision.disabled = true
	attack_hurt_box.body_entered.connect(_on_attack_hurt_box_body_entered)
	attack_hurt_box.area_entered.connect(_on_attack_hurt_box_area_entered)

	dash_hurt_box.monitoring = false
	dash_hurt_box.monitorable = false
	dash_hurt_box_collision.disabled = true
	dash_hurt_box.body_entered.connect(_on_dash_hurt_box_body_entered)
	dash_hurt_box.area_entered.connect(_on_dash_hurt_box_area_entered)

	await get_tree().process_frame

	player = PlayerManager.player

	if player == null:
		push_warning("Enemy chưa lấy được Player từ PlayerManager.")

	vision_area.player_entered.connect(_on_player_entered_vision)
	vision_area.player_exited.connect(_on_player_exited_vision)

	state_machine.initialize(self)


func _physics_process(delta: float) -> void:
	apply_gravity(delta)

	if is_attack_hurt_box_active:
		try_manual_attack_hit_player()

	move_and_slide()
	clamp_to_tilemap_bounds()


func apply_gravity(delta: float) -> void:
	if !is_on_floor():
		velocity.y += gravity * delta


# =========================
# HEALTH PHASE
# =========================

func get_health_ratio() -> float:
	if max_health <= 0:
		return 0.0

	return float(current_health) / float(max_health)


func update_health_phase() -> void:
	var ratio := get_health_ratio()

	if ratio <= 0.25:
		current_phase_speed_multiplier = speed_multiplier_below_25
		current_phase_attack_anim_multiplier = attack_anim_multiplier_below_25
	elif ratio <= 0.5:
		current_phase_speed_multiplier = speed_multiplier_below_50
		current_phase_attack_anim_multiplier = attack_anim_multiplier_below_50
	elif ratio <= 0.75:
		current_phase_speed_multiplier = speed_multiplier_below_75
		current_phase_attack_anim_multiplier = attack_anim_multiplier_below_75
	else:
		current_phase_speed_multiplier = speed_multiplier_above_75
		current_phase_attack_anim_multiplier = attack_anim_multiplier_above_75

	move_speed = base_move_speed * current_phase_speed_multiplier
	chase_speed = base_chase_speed * current_phase_speed_multiplier
	random_move_speed = base_random_move_speed * current_phase_speed_multiplier
	dash_speed = base_dash_speed * current_phase_speed_multiplier

	print(
		"Boss phase update | HP ratio: ",
		ratio,
		" | Speed x",
		current_phase_speed_multiplier,
		" | Attack anim x",
		current_phase_attack_anim_multiplier
	)


func get_animation_speed_for_base_anim(base_anim_name: String) -> float:
	if base_anim_name.contains("attack"):
		return current_phase_attack_anim_multiplier

	if base_anim_name.contains("dash"):
		return current_phase_speed_multiplier

	return 1.0


# =========================
# PATROL
# =========================

func setup_patrol_points() -> void:
	point_positions.clear()

	if patrol_points == null:
		print("No patrol points assigned")
		return

	for point in patrol_points.get_children():
		point_positions.append(point.global_position)

	if point_positions.is_empty():
		print("No patrol point children found")
		return

	current_point_index = 0
	current_target = point_positions[current_point_index]

	left_limit = point_positions[0].x
	right_limit = point_positions[0].x

	for pos in point_positions:
		left_limit = min(left_limit, pos.x)
		right_limit = max(right_limit, pos.x)


func go_to_next_point() -> void:
	if point_positions.is_empty():
		return

	current_point_index += 1

	if current_point_index >= point_positions.size():
		current_point_index = 0

	current_target = point_positions[current_point_index]


func update_direction_by_target() -> void:
	if point_positions.is_empty():
		return

	var distance_to_target: float = current_target.x - global_position.x

	if distance_to_target > 0:
		set_direction(Vector2.RIGHT)
	else:
		set_direction(Vector2.LEFT)


func update_direction_to_player() -> void:
	if player == null:
		player = PlayerManager.player

	if player == null:
		return

	if player.global_position.x > global_position.x:
		set_direction(Vector2.RIGHT)
	else:
		set_direction(Vector2.LEFT)


func set_direction(new_direction: Vector2) -> void:
	if new_direction == Vector2.ZERO:
		return

	var old_direction := direction

	direction = new_direction

	if direction == Vector2.RIGHT:
		facing_direction = 1
	elif direction == Vector2.LEFT:
		facing_direction = -1

	if old_direction != direction:
		direction_changed.emit(direction)


func get_direction_name() -> String:
	if facing_direction < 0:
		return "left"
	else:
		return "right"


func use_normal_sprite() -> void:
	if sprite_2d != null:
		sprite_2d.visible = true

	if dash_sprite_2d != null:
		dash_sprite_2d.visible = false


func use_dash_sprite() -> void:
	if sprite_2d != null:
		sprite_2d.visible = false

	if dash_sprite_2d != null:
		dash_sprite_2d.visible = true


func can_use_dash() -> bool:
	if !can_dash_now:
		return false

	if player == null:
		player = PlayerManager.player

	if player == null:
		return false

	var unlock_health := float(max_health) * dash_unlock_health_ratio

	if float(current_health) > unlock_health:
		return false

	var distance := get_distance_to_player()

	if distance < dash_min_distance:
		return false

	if distance > dash_max_distance:
		return false

	return true


func update_animation(
	base_anim_name: String,
	keep_time: bool = true,
	force_restart: bool = false
) -> void:
	var is_dash_animation := base_anim_name.contains("dash")

	if is_dash_animation:
		use_dash_sprite()
	else:
		use_normal_sprite()

	var anim_name := base_anim_name + "_" + get_direction_name()

	if !animation_player.has_animation(anim_name):
		push_warning("Enemy không tìm thấy animation: " + anim_name)
		return

	animation_player.speed_scale = get_animation_speed_for_base_anim(base_anim_name)

	var old_position: float = 0.0
	var same_base_animation := current_base_animation == base_anim_name

	if same_base_animation and keep_time:
		old_position = animation_player.current_animation_position

	if animation_player.current_animation == anim_name and !force_restart:
		return

	if force_restart:
		animation_player.stop()
		animation_player.play(anim_name)
		animation_player.seek(0.0, true)
		current_base_animation = base_anim_name
		return

	animation_player.play(anim_name)

	if same_base_animation and keep_time:
		var anim_length := animation_player.current_animation_length
		old_position = clamp(old_position, 0.0, anim_length)
		animation_player.seek(old_position, true)

	current_base_animation = base_anim_name


func get_distance_to_player() -> float:
	if player == null:
		player = PlayerManager.player

	if player == null:
		return 999999.0

	return abs(player.global_position.x - global_position.x)


func _on_player_entered_vision() -> void:
	can_see_player = true
	lost_player_timer = lost_player_grace_time
	boss_started.emit()
	print("Boss thấy Player")


func _on_player_exited_vision() -> void:
	can_see_player = false
	lost_player_timer = lost_player_grace_time
	print("Boss mất dấu Player")


func _on_hurt_box_area_entered(area: Area2D) -> void:
	print("Enemy HurtBox area entered")


func get_left_limit() -> float:
	if LevelManager.has_bounds():
		return LevelManager.get_left_limit() + map_limit_padding

	return left_limit + map_limit_padding


func get_right_limit() -> float:
	if LevelManager.has_bounds():
		return LevelManager.get_right_limit() - map_limit_padding

	return right_limit - map_limit_padding


func is_near_left_limit() -> bool:
	return global_position.x <= get_left_limit() + 10.0


func is_near_right_limit() -> bool:
	return global_position.x >= get_right_limit() - 10.0


func clamp_to_tilemap_bounds() -> void:
	if !LevelManager.has_bounds():
		return

	var current_left_limit := get_left_limit()
	var current_right_limit := get_right_limit()

	if global_position.x < current_left_limit:
		global_position.x = current_left_limit
		velocity.x = 0

	if global_position.x > current_right_limit:
		global_position.x = current_right_limit
		velocity.x = 0


func take_damage(amount: int) -> void:
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)

	print("Boss HP: ", current_health, "/", max_health)

	update_health_phase()

	if can_use_dash():
		print("Boss đã xuống nửa máu, dash đã được mở khóa")

	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()


func die() -> void:
	if animation_player != null:
		animation_player.speed_scale = 1.0

	died.emit()
	queue_free()


func _on_hit_box_damaged(damage: int) -> void:
	take_damage(damage)


# =========================
# ATTACK HURT BOX
# =========================

func start_attack_hurt_box() -> void:
	print("BOSS START ATTACK HURT BOX")

	is_attack_hurt_box_active = true
	has_attack_hit_player = false

	attack_hurt_box_collision.disabled = false
	attack_hurt_box.monitoring = true
	attack_hurt_box.monitorable = true

	# Check ngay khi animation bật hitbox.
	try_manual_attack_hit_player()

	await get_tree().physics_frame
	await get_tree().physics_frame

	print("Attack bodies overlap: ", attack_hurt_box.get_overlapping_bodies().size())
	print("Attack areas overlap: ", attack_hurt_box.get_overlapping_areas().size())

	for body in attack_hurt_box.get_overlapping_bodies():
		kill_player_from_attack(body)

	for area in attack_hurt_box.get_overlapping_areas():
		kill_player_from_attack(area)

	# Check thêm lần nữa sau khi physics cập nhật overlap.
	try_manual_attack_hit_player()


func stop_attack_hurt_box() -> void:
	print("BOSS STOP ATTACK HURT BOX")

	is_attack_hurt_box_active = false
	attack_hurt_box.monitoring = false
	attack_hurt_box.monitorable = false
	attack_hurt_box_collision.disabled = true


func _on_attack_hurt_box_body_entered(body: Node2D) -> void:
	print("Boss attack hit body: ", body.name)
	kill_player_from_attack(body)


func _on_attack_hurt_box_area_entered(area: Area2D) -> void:
	print("Boss attack hit area: ", area.name)
	kill_player_from_attack(area)


func kill_player_from_attack(target: Node) -> void:
	if !is_attack_hurt_box_active:
		return

	if attack_hurt_box_collision.disabled:
		return

	if has_attack_hit_player:
		return

	var target_player := find_player_from_node(target)

	if target_player == null:
		print("Không tìm thấy Player từ node: ", target.name)
		return

	has_attack_hit_player = true
	kill_player(target_player)


func try_manual_attack_hit_player() -> void:
	if !manual_attack_check_enabled:
		return

	if !is_attack_hurt_box_active:
		return

	if has_attack_hit_player:
		return

	if player == null:
		player = PlayerManager.player

	if player == null:
		return

	if !is_instance_valid(player):
		return

	if !is_player_inside_manual_attack_range():
		return

	print("Boss đánh trúng Player bằng manual attack check")
	has_attack_hit_player = true
	kill_player(player)


func is_player_inside_manual_attack_range() -> bool:
	if player == null:
		return false

	var delta_to_player: Vector2 = player.global_position - global_position
	var dx: float = delta_to_player.x
	var dy: float = abs(delta_to_player.y)

	if dy > manual_attack_hit_distance_y:
		return false

	if abs(dx) > manual_attack_hit_distance_x:
		return false

	if attack_only_hits_facing_direction:
		if facing_direction > 0 and dx < -manual_attack_back_tolerance:
			return false

		if facing_direction < 0 and dx > manual_attack_back_tolerance:
			return false

	return true


# =========================
# DASH HURT BOX
# =========================

func start_dash_hurt_box() -> void:
	print("BOSS START DASH HURT BOX")

	dash_hurt_box_collision.disabled = false
	dash_hurt_box.monitoring = true
	dash_hurt_box.monitorable = true

	await get_tree().physics_frame

	print("Dash bodies overlap: ", dash_hurt_box.get_overlapping_bodies().size())
	print("Dash areas overlap: ", dash_hurt_box.get_overlapping_areas().size())

	for body in dash_hurt_box.get_overlapping_bodies():
		kill_player_from_dash(body)

	for area in dash_hurt_box.get_overlapping_areas():
		kill_player_from_dash(area)


func stop_dash_hurt_box() -> void:
	print("BOSS STOP DASH HURT BOX")

	dash_hurt_box.monitoring = false
	dash_hurt_box.monitorable = false
	dash_hurt_box_collision.disabled = true


func _on_dash_hurt_box_body_entered(body: Node2D) -> void:
	print("Boss dash hit body: ", body.name)
	kill_player_from_dash(body)


func _on_dash_hurt_box_area_entered(area: Area2D) -> void:
	print("Boss dash hit area: ", area.name)
	kill_player_from_dash(area)


func kill_player_from_dash(target: Node) -> void:
	if dash_hurt_box_collision.disabled:
		return

	kill_player(target)


# =========================
# KILL PLAYER
# =========================

func find_player_from_node(node: Node) -> Player:
	var current := node

	while current != null:
		if current is Player:
			return current as Player

		if current.is_in_group("player"):
			return current as Player

		current = current.get_parent()

	return null


func kill_player(target: Node) -> void:
	if target == null:
		return

	var target_player := find_player_from_node(target)

	if target_player == null:
		print("Không tìm thấy Player từ node: ", target.name)
		return

	print("Boss đánh trúng Player")

	if target_player.has_method("die"):
		target_player.die(global_position)


# =========================
# SOUND
# =========================

func play_attack_sound() -> void:
	if attack_sound == null:
		return

	attack_sound.stop()
	attack_sound.pitch_scale = randf_range(attack_pitch_min, attack_pitch_max)
	attack_sound.volume_db = attack_volume_db
	attack_sound.play()


func play_dash_sound() -> void:
	if dash_sound == null:
		return

	dash_sound.stop()
	dash_sound.pitch_scale = randf_range(dash_pitch_min, dash_pitch_max)
	dash_sound.volume_db = dash_volume_db
	dash_sound.play()


func play_footstep_sound() -> void:
	if !can_play_footstep_sound:
		return

	if footstep_sound == null:
		return

	if !is_on_floor():
		return

	if abs(velocity.x) < 10:
		return

	can_play_footstep_sound = false

	footstep_sound.stop()
	footstep_sound.pitch_scale = randf_range(footstep_pitch_min, footstep_pitch_max)
	footstep_sound.volume_db = randf_range(footstep_volume_min_db, footstep_volume_max_db)
	footstep_sound.play()

	await get_tree().create_timer(0.16).timeout

	can_play_footstep_sound = true
