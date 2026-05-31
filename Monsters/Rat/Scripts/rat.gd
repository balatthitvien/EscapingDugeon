class_name Rat
extends CharacterBody2D
signal enemy_died(death_position: Vector2)
enum RatState {
	PATROL,
	CHASE,
	ATTACK,
	HURT,
	DIE
}

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# HitBox = vùng Rat bị Player đánh
@onready var hit_box: Area2D = $HitBox
@onready var hit_box_collision: CollisionShape2D = $HitBox/CollisionShape2D

# AttackHurtBox = vùng Rat tấn công Player
@onready var attack_hurt_box: Area2D = $AttackHurtBox
@onready var attack_hurt_box_collision: CollisionShape2D = $AttackHurtBox/CollisionShape2D

@onready var vision_area: Area2D = $VisionArea
@onready var default_patrol_points: Node = get_node_or_null("PatrolPoints")
@onready var attack_sound: AudioStreamPlayer2D = $Audio/Attack
@onready var die_sound: AudioStreamPlayer2D = $Audio/Die
@onready var hurt_sound: AudioStreamPlayer2D = $Audio/Hurt


@export var max_health: int = 3
@export var move_speed: float = 55.0
@export var patrol_speed: float = 35.0
@export var gravity: float = 1000.0
@export var exp_reward: int = 1
@export var attack_distance: float = 24.0
@export var attack_y_tolerance: float = 35.0
@export var attack_cooldown: float = 0.8
@export var damage: int = 1

@export var attack_lunge_speed: float = 95.0
@export var attack_lunge_knock_time: float = 0.12

@export var patrol_points: Node
@export var patrol_point_reach_distance: float = 6.0

@export var patrol_change_min_time: float = 1.5
@export var patrol_change_max_time: float = 3.0

@export var attack_volume_db: float = 8.5
@export var hurt_volume_db: float = 2.0
@export var die_volume_db: float = 5.0

@export var attack_pitch_min: float = 0.95
@export var attack_pitch_max: float = 1.05

@export var hurt_pitch_min: float = 0.95
@export var hurt_pitch_max: float = 1.05

@export var die_pitch_min: float = 0.95
@export var die_pitch_max: float = 1.05

@export var chase_when_seen: bool = true	
@export var patrol_leash_padding: float = 8.0
@export var combat_memory_time: float = 3.0
@export var hurt_stun_cooldown: float = 0.45
@export var anti_stun_after_hit_time: float = 0.8
@export var counter_attack_after_hurt: bool = true
@export var counter_attack_on_repeat_hit: bool = true
@export var force_counter_distance: float = 70.0


var current_health: int
var current_state: RatState = RatState.PATROL

var player: Player = null
var facing_direction: int = -1

var can_attack: bool = true
var is_attack_lunging: bool = false
var is_dead: bool = false
var is_hurt_locked: bool = false
var is_attack_cooling_down: bool = false

var patrol_timer: float = 0.0
var patrol_positions: Array[Vector2] = []
var current_patrol_index: int = 0
var current_patrol_target: Vector2
var patrol_left_limit: float = -999999.0
var patrol_right_limit: float = 999999.0

var hurt_stun_timer: float = 0.0
var anti_stun_timer: float = 0.0
var combat_memory_timer: float = 0.0

var has_given_exp: bool = false
func _ready() -> void:
	randomize()

	current_health = max_health

	setup_patrol_points()

	attack_hurt_box.monitoring = false
	attack_hurt_box.monitorable = true
	attack_hurt_box_collision.disabled = true

	if not vision_area.body_entered.is_connected(_on_vision_area_body_entered):
		vision_area.body_entered.connect(_on_vision_area_body_entered)

	if not vision_area.body_exited.is_connected(_on_vision_area_body_exited):
		vision_area.body_exited.connect(_on_vision_area_body_exited)

	if hit_box.has_signal("Damaged"):
		if not hit_box.Damaged.is_connected(_on_hit_box_damaged):
			hit_box.Damaged.connect(_on_hit_box_damaged)

	if not attack_hurt_box.body_entered.is_connected(_on_attack_hurt_box_body_entered):
		attack_hurt_box.body_entered.connect(_on_attack_hurt_box_body_entered)

	if not attack_hurt_box.area_entered.is_connected(_on_attack_hurt_box_area_entered):
		attack_hurt_box.area_entered.connect(_on_attack_hurt_box_area_entered)

	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

	patrol_timer = randf_range(patrol_change_min_time, patrol_change_max_time)

	change_state(RatState.PATROL)

	await get_tree().physics_frame

	for body in vision_area.get_overlapping_bodies():
		_on_vision_area_body_entered(body)


func _physics_process(delta: float) -> void:
	update_timers(delta)

	if is_dead:
		return

	apply_gravity(delta)

	match current_state:
		RatState.PATROL:
			update_patrol(delta)

		RatState.CHASE:
			update_chase()

		RatState.ATTACK:
			if is_attack_lunging:
				velocity.x = facing_direction * attack_lunge_speed
			else:
				velocity.x = 0.0

		RatState.HURT:
			velocity.x = 0.0

		RatState.DIE:
			velocity.x = 0.0

	move_and_slide()
	clamp_to_patrol_bounds()


func update_timers(delta: float) -> void:
	if hurt_stun_timer > 0.0:
		hurt_stun_timer -= delta
		if hurt_stun_timer < 0.0:
			hurt_stun_timer = 0.0

	if anti_stun_timer > 0.0:
		anti_stun_timer -= delta
		if anti_stun_timer < 0.0:
			anti_stun_timer = 0.0

	if combat_memory_timer > 0.0:
		combat_memory_timer -= delta
		if combat_memory_timer < 0.0:
			combat_memory_timer = 0.0


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0


func has_valid_player() -> bool:
	return player != null and is_instance_valid(player)


func should_chase_player() -> bool:
	if not has_valid_player():
		return false

	if not is_player_inside_patrol_bounds():
		return false

	if combat_memory_timer > 0.0:
		return true

	if chase_when_seen:
		return true

	return false
# =========================
# STATE
# =========================

func change_state(new_state: RatState) -> void:
	if is_dead and new_state != RatState.DIE:
		return

	if is_hurt_locked and new_state != RatState.DIE:
		return

	if current_state == new_state:
		return

	current_state = new_state

	print("Rat State: ", RatState.keys()[current_state])

	match current_state:
		RatState.PATROL:
			play_animation("run")

		RatState.CHASE:
			play_animation("run")

		RatState.ATTACK:
			start_attack()

		RatState.HURT:
			start_hurt()

		RatState.DIE:
			start_die()


# =========================
# PATROL
# =========================

func update_patrol(delta: float) -> void:
	if should_chase_player():
		change_state(RatState.CHASE)
		return

	if patrol_positions.is_empty():
		patrol_timer -= delta

		if patrol_timer <= 0.0:
			patrol_timer = randf_range(patrol_change_min_time, patrol_change_max_time)
			facing_direction = [-1, 1].pick_random()

		if is_on_wall():
			facing_direction *= -1

		velocity.x = facing_direction * patrol_speed
		play_animation("run")
		return

	var distance_to_target: float = absf(current_patrol_target.x - global_position.x)

	if distance_to_target <= patrol_point_reach_distance:
		go_to_next_patrol_point()

	update_direction_to_patrol_target()

	velocity.x = facing_direction * patrol_speed
	play_animation("run")


func update_chase() -> void:
	if not should_chase_player():
		lose_player_and_return_to_patrol()
		return

	update_direction_to_player()

	if get_distance_to_player() <= attack_distance and get_y_distance_to_player() <= attack_y_tolerance:
		velocity.x = 0.0

		if can_attack:
			change_state(RatState.ATTACK)

		return

	if patrol_positions.size() >= 2:
		if facing_direction < 0 and global_position.x <= patrol_left_limit:
			lose_player_and_return_to_patrol()
			return

		if facing_direction > 0 and global_position.x >= patrol_right_limit:
			lose_player_and_return_to_patrol()
			return

	velocity.x = facing_direction * move_speed
	play_animation("run")
# =========================
# ATTACK
# =========================

func start_attack() -> void:
	if not can_attack:
		change_state(RatState.CHASE)
		return

	can_attack = false
	is_attack_lunging = false
	velocity.x = 0.0

	remember_player_from_anywhere()
	update_direction_to_player()

	play_animation("attack", true)


func start_attack_cooldown() -> void:
	if is_attack_cooling_down:
		return

	is_attack_cooling_down = true
	can_attack = false

	await get_tree().create_timer(attack_cooldown).timeout

	if is_instance_valid(self) and not is_dead:
		can_attack = true

	is_attack_cooling_down = false


func start_attack_lunge() -> void:
	is_attack_lunging = true


func stop_attack_lunge() -> void:
	is_attack_lunging = false
	velocity.x = 0.0


# =========================
# ATTACK HURT BOX
# Rat tấn công Player
# =========================

func start_attack_hurt_box() -> void:
	play_attack_sound()

	attack_hurt_box_collision.disabled = false
	attack_hurt_box.monitoring = true
	attack_hurt_box.monitorable = true

	await get_tree().physics_frame

	for body in attack_hurt_box.get_overlapping_bodies():
		attack_player(body)

	for area in attack_hurt_box.get_overlapping_areas():
		attack_player(area)


func stop_attack_hurt_box() -> void:
	attack_hurt_box.monitoring = false
	attack_hurt_box_collision.disabled = true


func _on_attack_hurt_box_body_entered(body: Node2D) -> void:
	attack_player(body)


func _on_attack_hurt_box_area_entered(area: Area2D) -> void:
	attack_player(area)


func attack_player(target: Node) -> void:
	if attack_hurt_box_collision.disabled:
		return

	var target_player: Player = find_player_from_node(target)

	if target_player == null:
		return

	if target_player.has_method("take_damage"):
		target_player.take_damage(damage, global_position)
	elif target_player.has_method("die"):
		target_player.die(global_position)

# =========================
# HURT / DIE
# =========================

func take_damage(amount: int) -> void:
	if is_dead:
		return

	remember_player_from_anywhere()
	update_direction_to_player()

	combat_memory_timer = combat_memory_time

	current_health -= amount
	current_health = clamp(current_health, 0, max_health)

	print("Rat HP: ", current_health, "/", max_health)

	if current_health <= 0:
		current_state = RatState.DIE
		start_die()
		return

	# Rat đang attack thì vẫn mất máu nhưng không bị hủy chiêu.
	if current_state == RatState.ATTACK:
		print("Rat bị đánh khi đang attack nhưng vẫn tiếp tục ra đòn")
		return

	# Player spam chém trong lúc Rat đang kháng stun thì Rat phản công ngay.
	if anti_stun_timer > 0.0:
		print("Rat bị chém tiếp trong anti-stun")

		if counter_attack_on_repeat_hit and can_counter_attack_player():
			is_hurt_locked = false
			is_attack_lunging = false
			velocity.x = 0.0
			stop_attack_hurt_box()
			can_attack = true
			change_state(RatState.ATTACK)
			return

		return

	if hurt_stun_timer <= 0.0:
		hurt_stun_timer = hurt_stun_cooldown
		anti_stun_timer = anti_stun_after_hit_time

		stop_attack_hurt_box()
		is_attack_lunging = false
		velocity.x = 0.0

		current_state = RatState.HURT
		start_hurt()
	else:
		print("Rat nhận damage nhưng không bị stun lại")


func start_hurt() -> void:
	print("Rat start hurt animation: hurt_" + get_direction_name())

	remember_player_from_anywhere()
	update_direction_to_player()

	is_hurt_locked = true
	is_attack_lunging = false
	velocity.x = 0.0

	stop_attack_hurt_box()
	play_hurt_sound()
	play_animation("hurt", true)


func start_die() -> void:
	give_exp_reward()
	enemy_died.emit(global_position)
	is_dead = true
	is_hurt_locked = false
	current_state = RatState.DIE
	is_attack_lunging = false
	velocity = Vector2.ZERO

	stop_attack_hurt_box()

	if collision_shape:
		collision_shape.disabled = true

	if hit_box:
		hit_box.monitoring = false

	if attack_hurt_box:
		attack_hurt_box.monitoring = false

	play_die_sound()
	play_animation("die", true)


func can_counter_attack_player() -> bool:
	if not has_valid_player():
		return false

	var x_distance: float = absf(player.global_position.x - global_position.x)
	var y_distance: float = absf(player.global_position.y - global_position.y)

	if x_distance > force_counter_distance:
		return false

	if y_distance > attack_y_tolerance:
		return false

	return true


# =========================
# HIT BOX
# Rat bị Player đánh
# =========================

func _on_hit_box_damaged(damage_amount: int) -> void:
	if is_dead:
		return

	remember_player_from_anywhere()

	print("Rat nhận damage từ HitBox signal: ", damage_amount)
	take_damage(damage_amount)


# =========================
# ANIMATION FINISHED
# =========================

func _on_animation_finished(anim_name: StringName) -> void:
	if current_state == RatState.DIE:
		if anim_name == "die_left" or anim_name == "die_right":
			queue_free()
		return

	if current_state == RatState.HURT:
		if anim_name == "hurt_left" or anim_name == "hurt_right":
			is_hurt_locked = false

			remember_player_from_anywhere()
			update_direction_to_player()

			if counter_attack_after_hurt and can_counter_attack_player():
				can_attack = true
				change_state(RatState.ATTACK)
				return

			if should_chase_player():
				change_state(RatState.CHASE)
			else:
				player = null
				change_state(RatState.PATROL)

		return

	if current_state == RatState.ATTACK:
		if anim_name == "attack_left" or anim_name == "attack_right":
			is_attack_lunging = false
			stop_attack_hurt_box()
			start_attack_cooldown()

			if should_chase_player():
				change_state(RatState.CHASE)
			else:
				player = null
				change_state(RatState.PATROL)

		return


# =========================
# PLAYER MEMORY
# =========================

func remember_player_from_anywhere() -> void:
	if remember_player_from_hitbox():
		return

	if remember_player_from_vision_area():
		return

	var found_player: Player = find_player_anywhere()

	if found_player != null:
		player = found_player


func remember_player_from_hitbox() -> bool:
	if hit_box == null:
		return false

	for area in hit_box.get_overlapping_areas():
		var detected_player: Player = find_player_from_node(area)
		if detected_player != null:
			player = detected_player
			return true

	for body in hit_box.get_overlapping_bodies():
		var detected_player: Player = find_player_from_node(body)
		if detected_player != null:
			player = detected_player
			return true

	return false


func remember_player_from_vision_area() -> bool:
	if vision_area == null:
		return false

	for body in vision_area.get_overlapping_bodies():
		var detected_player: Player = find_player_from_node(body)
		if detected_player != null:
			player = detected_player
			return true

	for area in vision_area.get_overlapping_areas():
		var detected_player: Player = find_player_from_node(area)
		if detected_player != null:
			player = detected_player
			return true

	return false


func find_player_anywhere() -> Player:
	for node in get_tree().get_nodes_in_group("player"):
		var detected_player: Player = find_player_from_node(node)
		if detected_player != null:
			return detected_player

	for node in get_tree().get_nodes_in_group("Player"):
		var detected_player: Player = find_player_from_node(node)
		if detected_player != null:
			return detected_player

	var by_name: Node = get_tree().root.find_child("Player", true, false)

	if by_name != null:
		var detected_player: Player = find_player_from_node(by_name)
		if detected_player != null:
			return detected_player

	return null


# =========================
# VISION AREA
# =========================

func _on_vision_area_body_entered(body: Node2D) -> void:
	var detected_player: Player = find_player_from_node(body)

	if detected_player == null:
		return

	player = detected_player

	if current_state == RatState.PATROL and should_chase_player():
		change_state(RatState.CHASE)


func _on_vision_area_body_exited(body: Node2D) -> void:
	var detected_player: Player = find_player_from_node(body)

	if detected_player == null:
		return

	if detected_player != player:
		return

	if combat_memory_timer > 0.0:
		return

	player = null

	if current_state == RatState.CHASE:
		change_state(RatState.PATROL)


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

	if node != null and node.owner != null:
		var owner_node: Node = node.owner

		if owner_node is Player:
			return owner_node as Player

		if owner_node.is_in_group("player"):
			return owner_node as Player

		if owner_node.is_in_group("Player"):
			return owner_node as Player

		if owner_node.name == "Player":
			return owner_node as Player

	return null


# =========================
# DIRECTION / DISTANCE
# =========================

func update_direction_to_player() -> void:
	if not has_valid_player():
		return

	if player.global_position.x > global_position.x:
		facing_direction = 1
	else:
		facing_direction = -1


func get_direction_name() -> String:
	if facing_direction < 0:
		return "left"

	return "right"


func get_distance_to_player() -> float:
	if not has_valid_player():
		return 999999.0

	return absf(player.global_position.x - global_position.x)


func get_y_distance_to_player() -> float:
	if not has_valid_player():
		return 999999.0

	return absf(player.global_position.y - global_position.y)


# =========================
# SOUND
# =========================

func play_attack_sound() -> void:
	if attack_sound == null:
		push_warning("Rat thiếu sound Attack")
		return

	attack_sound.stop()
	attack_sound.volume_db = attack_volume_db
	attack_sound.pitch_scale = randf_range(attack_pitch_min, attack_pitch_max)
	attack_sound.play()


func play_hurt_sound() -> void:
	if hurt_sound == null:
		push_warning("Rat thiếu sound Hurt")
		return

	hurt_sound.stop()
	hurt_sound.volume_db = hurt_volume_db
	hurt_sound.pitch_scale = randf_range(hurt_pitch_min, hurt_pitch_max)
	hurt_sound.play()


func play_die_sound() -> void:
	if die_sound == null:
		push_warning("Rat thiếu sound Die")
		return

	die_sound.stop()
	die_sound.volume_db = die_volume_db
	die_sound.pitch_scale = randf_range(die_pitch_min, die_pitch_max)
	die_sound.play()


# =========================
# ANIMATION
# =========================

func play_animation(base_name: String, force_restart: bool = false) -> void:
	var anim_name := base_name + "_" + get_direction_name()

	if not animation_player.has_animation(anim_name):
		push_warning("Rat thiếu animation: " + anim_name)
		return

	if animation_player.current_animation == anim_name and not force_restart:
		return

	animation_player.play(anim_name)


# =========================
# PATROL POINTS
# =========================

func setup_patrol_points() -> void:
	patrol_positions.clear()

	var points_node: Node = patrol_points

	if points_node == null:
		points_node = default_patrol_points

	if points_node == null:
		push_warning("Rat chưa có PatrolPoints. Rat sẽ patrol tự do.")
		return

	for point in points_node.get_children():
		if point is Node2D:
			patrol_positions.append(point.global_position)

	if patrol_positions.is_empty():
		push_warning("PatrolPoints không có điểm con Node2D.")
		return

	patrol_positions.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.x < b.x
	)

	current_patrol_index = 0
	current_patrol_target = patrol_positions[current_patrol_index]

	patrol_left_limit = patrol_positions[0].x
	patrol_right_limit = patrol_positions[patrol_positions.size() - 1].x

	print("Rat patrol left: ", patrol_left_limit)
	print("Rat patrol right: ", patrol_right_limit)

func go_to_next_patrol_point() -> void:
	if patrol_positions.is_empty():
		return

	current_patrol_index += 1

	if current_patrol_index >= patrol_positions.size():
		current_patrol_index = 0

	current_patrol_target = patrol_positions[current_patrol_index]


func update_direction_to_patrol_target() -> void:
	if patrol_positions.is_empty():
		return

	if current_patrol_target.x > global_position.x:
		facing_direction = 1
	else:
		facing_direction = -1


func is_outside_patrol_left() -> bool:
	if patrol_positions.is_empty():
		return false

	return global_position.x <= patrol_left_limit


func is_outside_patrol_right() -> bool:
	if patrol_positions.is_empty():
		return false

	return global_position.x >= patrol_right_limit


func clamp_to_patrol_bounds() -> void:
	if patrol_positions.is_empty():
		return

	if global_position.x < patrol_left_limit:
		global_position.x = patrol_left_limit
		velocity.x = 0.0

	if global_position.x > patrol_right_limit:
		global_position.x = patrol_right_limit
		velocity.x = 0.0
func is_player_in_front() -> bool:
	if not has_valid_player():
		return false

	var dx: float = player.global_position.x - global_position.x

	if facing_direction > 0 and dx > 0.0:
		return true

	if facing_direction < 0 and dx < 0.0:
		return true

	return false
func is_player_inside_patrol_bounds() -> bool:
	if not has_valid_player():
		return false

	if patrol_positions.size() < 2:
		return true

	if player.global_position.x < patrol_left_limit - patrol_leash_padding:
		return false

	if player.global_position.x > patrol_right_limit + patrol_leash_padding:
		return false

	return true


func lose_player_and_return_to_patrol() -> void:
	player = null
	combat_memory_timer = 0.0
	anti_stun_timer = 0.0

	is_attack_lunging = false
	velocity.x = 0.0

	stop_attack_hurt_box()

	if patrol_positions.size() >= 2:
		if global_position.x <= patrol_left_limit + 1.0:
			global_position.x = patrol_left_limit
			current_patrol_index = 1
			current_patrol_target = patrol_positions[current_patrol_index]

		elif global_position.x >= patrol_right_limit - 1.0:
			global_position.x = patrol_right_limit
			current_patrol_index = 0
			current_patrol_target = patrol_positions[current_patrol_index]

		else:
			var nearest_index: int = 0
			var nearest_distance: float = 999999.0

			for i in range(patrol_positions.size()):
				var distance: float = absf(patrol_positions[i].x - global_position.x)

				if distance < nearest_distance:
					nearest_distance = distance
					nearest_index = i

			current_patrol_index = nearest_index
			current_patrol_target = patrol_positions[current_patrol_index]

	update_direction_to_patrol_target()
	change_state(RatState.PATROL)
func give_exp_reward() -> void:
	if has_given_exp:
		return

	has_given_exp = true

	if PlayerManager.player != null and PlayerManager.player.has_method("gain_exp"):
		PlayerManager.player.gain_exp(exp_reward)
