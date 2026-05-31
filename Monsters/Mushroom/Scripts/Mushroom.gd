extends CharacterBody2D
signal enemy_died(death_position: Vector2)
const STATE_IDLE: int = 0
const STATE_WALK: int = 1
const STATE_CHASE: int = 2
const STATE_ATTACK: int = 3
const STATE_HURT: int = 4
const STATE_DIE: int = 5

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var vision_area: Area2D = $VisionArea
@onready var hit_box: HitBox = $HitBox
@onready var attack_hurt_box: Area2D = $AttackHurtBox

@onready var attack_collision: CollisionShape2D = $AttackHurtBox/CollisionShape2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D

@onready var attack_sound: AudioStreamPlayer2D = $Node2D/Attack
@onready var hurt_sound: AudioStreamPlayer2D = $Node2D/Hurt
@onready var die_sound: AudioStreamPlayer2D = $Node2D/Die

@onready var left_point: Node2D = $PatrolPoints/LeftPoint
@onready var right_point: Node2D = $PatrolPoints/RightPoint


@export var max_hp: int = 5
@export var move_speed: float = 35.0
@export var chase_speed: float = 55.0
@export var attack_damage: int = 1

@export var attack_distance: float = 40.0
@export var stop_distance: float = 22.0
@export var attack_y_tolerance: float = 40.0
@export var gravity: float = 900.0

@export var idle_time_min: float = 0.5
@export var idle_time_max: float = 1.2
@export var walk_time_min: float = 1.0
@export var walk_time_max: float = 2.0

@export var attack_cooldown: float = 1.0

# Nếu true: thấy Player là đuổi.
# Nếu false: chỉ nhìn thấy thì chưa đuổi, bị đánh mới phản ứng.
@export var chase_when_seen: bool = true

# Chống stun-lock / phản đòn khi bị chém sau lưng
@export var combat_memory_time: float = 3.0
@export var hurt_stun_cooldown: float = 0.45
@export var anti_stun_after_hit_time: float = 0.9
@export var counter_attack_after_hurt: bool = true
@export var counter_attack_on_repeat_hit: bool = true
@export var force_counter_distance: float = 90.0
@export var exp_reward: int = 2
var hp: int = 0
var state: int = STATE_IDLE
var state_token: int = 0

var player: Node2D = null

var direction: int = 1
var facing_right: bool = true

var state_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var hurt_stun_timer: float = 0.0
var anti_stun_timer: float = 0.0
var combat_memory_timer: float = 0.0

var patrol_left_x: float = 0.0
var patrol_right_x: float = 0.0

var is_dead: bool = false
var has_dealt_damage: bool = false
var has_given_exp: bool = false

func _ready() -> void:
	randomize()

	hp = max_hp

	patrol_left_x = left_point.global_position.x
	patrol_right_x = right_point.global_position.x

	if patrol_left_x > patrol_right_x:
		var temp_x: float = patrol_left_x
		patrol_left_x = patrol_right_x
		patrol_right_x = temp_x

	attack_collision.disabled = true

	vision_area.monitoring = true
	vision_area.monitorable = true

	hit_box.monitoring = true
	hit_box.monitorable = true

	attack_hurt_box.monitoring = true
	attack_hurt_box.monitorable = true

	if not vision_area.body_entered.is_connected(_on_vision_area_body_entered):
		vision_area.body_entered.connect(_on_vision_area_body_entered)

	if not vision_area.body_exited.is_connected(_on_vision_area_body_exited):
		vision_area.body_exited.connect(_on_vision_area_body_exited)

	if hit_box.has_signal("Damaged"):
		if not hit_box.Damaged.is_connected(_on_hit_box_damaged):
			hit_box.Damaged.connect(_on_hit_box_damaged)

	if not hit_box.area_entered.is_connected(_on_hit_box_area_entered):
		hit_box.area_entered.connect(_on_hit_box_area_entered)

	if not attack_hurt_box.body_entered.is_connected(_on_attack_hurt_box_body_entered):
		attack_hurt_box.body_entered.connect(_on_attack_hurt_box_body_entered)

	if not attack_hurt_box.area_entered.is_connected(_on_attack_hurt_box_area_entered):
		attack_hurt_box.area_entered.connect(_on_attack_hurt_box_area_entered)

	change_state(STATE_IDLE, true)

	await get_tree().physics_frame

	for body in vision_area.get_overlapping_bodies():
		_on_vision_area_body_entered(body)


func _physics_process(delta: float) -> void:
	update_timers(delta)

	if is_dead:
		return

	apply_gravity(delta)

	match state:
		STATE_IDLE:
			process_idle(delta)

		STATE_WALK:
			process_walk(delta)

		STATE_CHASE:
			process_chase(delta)

		STATE_ATTACK:
			velocity.x = 0.0

		STATE_HURT:
			velocity.x = 0.0

		STATE_DIE:
			velocity.x = 0.0

	move_and_slide()


func update_timers(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer < 0.0:
			attack_cooldown_timer = 0.0

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

	# Nếu Mushroom đang trong combat vì bị đánh,
	# thì dù Player ở trước hay sau vẫn được phép đuổi / phản công.
	if combat_memory_timer > 0.0:
		return true

	# Nếu chỉ nhìn thấy Player, chỉ chase khi Player ở trước mặt Mushroom.
	if chase_when_seen and is_player_in_front():
		return true

	return false


# =========================
# PROCESS STATE
# =========================

func process_idle(delta: float) -> void:
	velocity.x = 0.0

	if should_chase_player():
		change_state(STATE_CHASE)
		return

	state_timer -= delta

	if state_timer <= 0.0:
		direction = choose_patrol_direction()
		change_state(STATE_WALK)


func process_walk(delta: float) -> void:
	if should_chase_player():
		change_state(STATE_CHASE)
		return

	check_patrol_limit()

	velocity.x = float(direction) * move_speed

	update_facing_by_direction(direction)
	play_walk_animation()

	state_timer -= delta

	if state_timer <= 0.0:
		change_state(STATE_IDLE)


func process_chase(_delta: float) -> void:
	if not should_chase_player():
		player = null
		change_state(STATE_IDLE)
		return

	var dx: float = player.global_position.x - global_position.x
	var x_distance: float = absf(dx)
	var y_distance: float = absf(player.global_position.y - global_position.y)

	if dx > 2.0:
		direction = 1
	elif dx < -2.0:
		direction = -1

	update_facing_by_direction(direction)

	if x_distance <= attack_distance and y_distance <= attack_y_tolerance:
		velocity.x = 0.0

		if attack_cooldown_timer <= 0.0:
			change_state(STATE_ATTACK)
		else:
			play_idle_animation()

		return

	if x_distance <= stop_distance:
		velocity.x = 0.0
		play_idle_animation()
		return

	velocity.x = float(direction) * chase_speed
	play_walk_animation()


# =========================
# CHANGE STATE
# =========================

func change_state(new_state: int, force: bool = false) -> void:
	if is_dead and new_state != STATE_DIE:
		return

	if state == new_state and not force:
		return

	state = new_state
	state_token += 1

	match state:
		STATE_IDLE:
			velocity.x = 0.0
			attack_collision.disabled = true
			state_timer = randf_range(idle_time_min, idle_time_max)
			play_idle_animation()

		STATE_WALK:
			attack_collision.disabled = true
			state_timer = randf_range(walk_time_min, walk_time_max)
			play_walk_animation()

		STATE_CHASE:
			attack_collision.disabled = true
			play_walk_animation()

		STATE_ATTACK:
			start_attack(state_token)

		STATE_HURT:
			start_hurt(state_token)

		STATE_DIE:
			start_die(state_token)


func is_state_valid(check_state: int, check_token: int) -> bool:
	if is_dead and check_state != STATE_DIE:
		return false

	if state != check_state:
		return false

	if state_token != check_token:
		return false

	return true


# =========================
# ATTACK
# =========================

func start_attack(my_token: int) -> void:
	velocity.x = 0.0
	has_dealt_damage = false
	attack_collision.disabled = true

	remember_player_from_anywhere()
	face_player_if_possible()

	play_attack_animation()

	if attack_sound != null:
		attack_sound.play()

	var attack_anim_name: String = get_current_attack_animation_name()
	var attack_anim_length: float = get_animation_length(attack_anim_name)

	await get_tree().create_timer(attack_anim_length).timeout

	attack_collision.disabled = true

	if not is_state_valid(STATE_ATTACK, my_token):
		return

	attack_cooldown_timer = attack_cooldown

	if should_chase_player():
		change_state(STATE_CHASE)
	else:
		player = null
		change_state(STATE_IDLE)


func enable_attack_hitbox() -> void:
	if is_dead:
		return

	if state != STATE_ATTACK:
		return

	attack_collision.disabled = false
	has_dealt_damage = false

	await get_tree().physics_frame
	check_attack_hit_now()


func disable_attack_hitbox() -> void:
	attack_collision.disabled = true


func check_attack_hit_now() -> void:
	for body in attack_hurt_box.get_overlapping_bodies():
		try_damage_player(body)

	for area in attack_hurt_box.get_overlapping_areas():
		try_damage_player(area)

		if area.get_parent() != null:
			try_damage_player(area.get_parent())

	if has_valid_player() and is_player_in_attack_range():
		try_damage_player(player)


func is_player_in_attack_range() -> bool:
	if not has_valid_player():
		return false

	var dx: float = player.global_position.x - global_position.x
	var x_distance: float = absf(dx)
	var y_distance: float = absf(player.global_position.y - global_position.y)

	if x_distance > attack_distance + 12.0:
		return false

	if y_distance > attack_y_tolerance:
		return false

	if facing_right and dx < -4.0:
		return false

	if not facing_right and dx > 4.0:
		return false

	return true


func _on_attack_hurt_box_body_entered(body: Node2D) -> void:
	try_damage_player(body)


func _on_attack_hurt_box_area_entered(area: Area2D) -> void:
	try_damage_player(area)

	if area.get_parent() != null:
		try_damage_player(area.get_parent())


func try_damage_player(target: Node) -> void:
	if is_dead:
		return

	if state != STATE_ATTACK:
		return

	if has_dealt_damage:
		return

	if target == null:
		return

	var real_target: Node = get_player_node_from_target(target)

	if real_target == null:
		return

	has_dealt_damage = true

	print("Mushroom đánh trúng Player: ", real_target.name)

	if real_target.has_method("die"):
		real_target.die(global_position)
		return

	if real_target.has_method("take_damage"):
		real_target.take_damage(attack_damage)
		return

	if real_target.has_method("hurt"):
		real_target.hurt(attack_damage)
		return

	print("Player không có hàm die(), take_damage() hoặc hurt().")


# =========================
# HURT / DIE
# =========================

func start_hurt(my_token: int) -> void:
	velocity.x = 0.0
	attack_collision.disabled = true
	has_dealt_damage = false

	remember_player_from_anywhere()
	face_player_if_possible()

	play_hurt_animation()

	if hurt_sound != null:
		hurt_sound.play()

	var hurt_anim_name: String = get_current_hurt_animation_name()
	var hurt_anim_length: float = get_animation_length(hurt_anim_name)

	await get_tree().create_timer(hurt_anim_length).timeout

	if not is_state_valid(STATE_HURT, my_token):
		return

	remember_player_from_anywhere()
	face_player_if_possible()

	if counter_attack_after_hurt and can_counter_attack_player():
		attack_cooldown_timer = 0.0
		change_state(STATE_ATTACK)
		return

	if should_chase_player():
		change_state(STATE_CHASE)
	else:
		player = null
		change_state(STATE_IDLE)


func start_die(my_token: int) -> void:
	give_exp_reward()
	enemy_died.emit(global_position)
	if is_dead:
		return

	is_dead = true
	state = STATE_DIE

	velocity = Vector2.ZERO
	attack_collision.disabled = true

	if body_collision != null:
		body_collision.disabled = true

	if hit_box != null:
		hit_box.monitoring = false
		hit_box.monitorable = false

	if vision_area != null:
		vision_area.monitoring = false
		vision_area.monitorable = false

	if attack_hurt_box != null:
		attack_hurt_box.monitoring = false
		attack_hurt_box.monitorable = false

	play_die_animation()

	if die_sound != null:
		die_sound.play()

	var die_anim_name: String = get_current_die_animation_name()
	var die_anim_length: float = get_animation_length(die_anim_name)

	await get_tree().create_timer(die_anim_length).timeout

	if my_token == state_token:
		queue_free()


func take_damage(damage: int = 1) -> void:
	if is_dead:
		return

	remember_player_from_anywhere()
	face_player_if_possible()

	combat_memory_timer = combat_memory_time

	hp -= damage
	hp = clamp(hp, 0, max_hp)

	print("Mushroom HP: ", hp, "/", max_hp)

	if hp <= 0:
		change_state(STATE_DIE, true)
		return

	if state == STATE_ATTACK:
		print("Mushroom đang attack nên không bị stun")
		return

	if anti_stun_timer > 0.0:
		print("Mushroom bị chém tiếp trong anti-stun")

		if counter_attack_on_repeat_hit and can_counter_attack_player():
			attack_cooldown_timer = 0.0
			change_state(STATE_ATTACK, true)
			return

		return

	if hurt_stun_timer <= 0.0:
		hurt_stun_timer = hurt_stun_cooldown
		anti_stun_timer = anti_stun_after_hit_time
		change_state(STATE_HURT, true)
	else:
		print("Mushroom nhận damage nhưng không bị stun lại")


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
# HITBOX - MUSHROOM BỊ PLAYER ĐÁNH
# =========================

func _on_hit_box_damaged(damage_amount: int) -> void:
	if is_dead:
		return

	remember_player_from_anywhere()

	print("Mushroom nhận damage từ HitBox signal: ", damage_amount)
	take_damage(damage_amount)


func _on_hit_box_area_entered(area: Area2D) -> void:
	if is_dead:
		return

	remember_player_from_target(area)

	# Nếu HitBox.gd đã phát signal Damaged thì không gây damage ở đây nữa,
	# tránh bị trừ máu 2 lần.
	if hit_box.has_signal("Damaged"):
		return

	if area.is_in_group("PlayerAttack"):
		take_damage(get_damage_from_area(area))
		return

	if area.has_method("get_damage"):
		take_damage(area.get_damage())
		return

	if area.get_parent() != null and area.get_parent().has_method("get_damage"):
		take_damage(area.get_parent().get_damage())
		return


func get_damage_from_area(area: Area2D) -> int:
	if area.has_method("get_damage"):
		return area.get_damage()

	if area.get_parent() != null and area.get_parent().has_method("get_damage"):
		return area.get_parent().get_damage()

	return 1


# =========================
# PLAYER MEMORY
# =========================

func remember_player_from_anywhere() -> void:
	if remember_player_from_hitbox():
		return

	if remember_player_from_vision_area():
		return

	var found_player: Node = find_player_anywhere()

	if found_player != null:
		player = found_player


func remember_player_from_hitbox() -> bool:
	if hit_box == null:
		return false

	for area in hit_box.get_overlapping_areas():
		if remember_player_from_target(area):
			return true

	for body in hit_box.get_overlapping_bodies():
		if remember_player_from_target(body):
			return true

	return false


func remember_player_from_vision_area() -> bool:
	if vision_area == null:
		return false

	for body in vision_area.get_overlapping_bodies():
		if remember_player_from_target(body):
			return true

	for area in vision_area.get_overlapping_areas():
		if remember_player_from_target(area):
			return true

	return false


func remember_player_from_target(target: Node) -> bool:
	var detected_player: Node = get_player_node_from_target(target)

	if detected_player == null:
		return false

	player = detected_player
	return true


func find_player_anywhere() -> Node:
	for node in get_tree().get_nodes_in_group("player"):
		var detected_player: Node = get_player_node_from_target(node)
		if detected_player != null:
			return detected_player

	for node in get_tree().get_nodes_in_group("Player"):
		var detected_player: Node = get_player_node_from_target(node)
		if detected_player != null:
			return detected_player

	var by_name: Node = get_tree().root.find_child("Player", true, false)

	if by_name != null:
		return by_name

	return null


func get_player_node_from_target(target: Node) -> Node:
	var current: Node = target

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

	if target != null and target.owner != null:
		var owner_node: Node = target.owner

		if owner_node is Player:
			return owner_node

		if owner_node.is_in_group("player"):
			return owner_node

		if owner_node.is_in_group("Player"):
			return owner_node

		if owner_node.name == "Player":
			return owner_node

	return null


# =========================
# VISION
# =========================

func _on_vision_area_body_entered(body: Node2D) -> void:
	if is_dead:
		return

	if not remember_player_from_target(body):
		return

	if state == STATE_ATTACK or state == STATE_HURT or state == STATE_DIE:
		return

	if should_chase_player():
		change_state(STATE_CHASE)

func _on_vision_area_body_exited(body: Node2D) -> void:
	if is_dead:
		return

	var detected_player: Node = get_player_node_from_target(body)

	if detected_player == null:
		return

	if detected_player != player:
		return

	if combat_memory_timer > 0.0:
		return

	player = null

	if state == STATE_CHASE:
		change_state(STATE_IDLE)


# =========================
# PATROL
# =========================

func choose_patrol_direction() -> int:
	if global_position.x <= patrol_left_x + 2.0:
		return 1

	if global_position.x >= patrol_right_x - 2.0:
		return -1

	if randi() % 2 == 0:
		return -1

	return 1


func check_patrol_limit() -> void:
	if direction > 0 and global_position.x >= patrol_right_x:
		direction = -1
		change_state(STATE_IDLE)
		return

	if direction < 0 and global_position.x <= patrol_left_x:
		direction = 1
		change_state(STATE_IDLE)
		return


# =========================
# DIRECTION
# =========================

func face_player_if_possible() -> void:
	if not has_valid_player():
		return

	var dx: float = player.global_position.x - global_position.x

	if dx > 0.0:
		direction = 1
	elif dx < 0.0:
		direction = -1

	update_facing_by_direction(direction)


func update_facing_by_direction(dir: int) -> void:
	if dir > 0:
		facing_right = true
	elif dir < 0:
		facing_right = false


# =========================
# ANIMATION
# =========================

func safe_play(anim_name: String) -> void:
	if animation_player.current_animation == anim_name and animation_player.is_playing():
		return

	animation_player.play(anim_name)


func play_idle_animation() -> void:
	if facing_right:
		safe_play("idle_right")
	else:
		safe_play("idle_left")


func play_walk_animation() -> void:
	if facing_right:
		safe_play("walk_right")
	else:
		safe_play("walk_left")


func play_attack_animation() -> void:
	if facing_right:
		safe_play("attack_right")
	else:
		safe_play("attack_left")


func play_hurt_animation() -> void:
	if facing_right:
		safe_play("hurt_right")
	else:
		safe_play("hurt_left")


func play_die_animation() -> void:
	if facing_right:
		safe_play("die_right")
	else:
		safe_play("die_left")


func get_current_attack_animation_name() -> String:
	if facing_right:
		return "attack_right"

	return "attack_left"


func get_current_hurt_animation_name() -> String:
	if facing_right:
		return "hurt_right"

	return "hurt_left"


func get_current_die_animation_name() -> String:
	if facing_right:
		return "die_right"

	return "die_left"


func get_animation_length(anim_name: String) -> float:
	if animation_player.has_animation(anim_name):
		var anim: Animation = animation_player.get_animation(anim_name)
		return max(anim.length, 0.05)

	return 0.5
func is_player_in_front() -> bool:
	if not has_valid_player():
		return false

	var dx: float = player.global_position.x - global_position.x

	if facing_right and dx > 0.0:
		return true

	if not facing_right and dx < 0.0:
		return true

	return false
func give_exp_reward() -> void:
	if has_given_exp:
		return

	has_given_exp = true

	if PlayerManager.player != null and PlayerManager.player.has_method("gain_exp"):
		PlayerManager.player.gain_exp(exp_reward)
