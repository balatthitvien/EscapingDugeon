class_name Bat
extends CharacterBody2D
signal enemy_died(death_position: Vector2)
enum BatState {
	PATROL,
	CHASE_ABOVE,
	DIVE_ATTACK,
	RETURN_UP,
	HURT,
	FALL,
	DIE
}

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# HitBox = vùng Bat bị Player đánh
@onready var hit_box: HitBox = $HitBox
@onready var hit_box_collision: CollisionShape2D = $HitBox/CollisionShape2D

# AttackHurtBox = vùng Bat tấn công Player
@onready var attack_hurt_box: Area2D = $AttackHurtBox
@onready var attack_hurt_box_collision: CollisionShape2D = $AttackHurtBox/CollisionShape2D

@onready var vision_area: Area2D = $VisionArea

@onready var attack_sound: AudioStreamPlayer2D = $Node2D/Attack
@onready var die_sound: AudioStreamPlayer2D = $Node2D/Die
@onready var hurt_sound: AudioStreamPlayer2D = $Node2D/Hurt
@onready var flying_sound: AudioStreamPlayer2D = $Node2D/Flying


@export var max_health: int = 3

@export var patrol_speed: float = 50.0
@export var chase_speed: float = 90.0
@export var return_speed: float = 110.0
@export var dive_speed: float = 170.0
@export var exp_reward: int = 1
@export var hover_height: float = 70.0
@export var attack_start_distance: float = 85.0
@export var return_finish_distance: float = 12.0

@export var attack_cooldown: float = 0.65
@export var damage: int = 1

@export var aggro_give_up_distance: float = 520.0

@export var patrol_points: Node
@export var patrol_point_reach_distance: float = 6.0

@export var attack_volume_db: float = 5.0
@export var hurt_volume_db: float = 5.0
@export var die_volume_db: float = 5.0
@export var flying_volume_db: float = -5.0

# Dùng cho xác Bat rơi xuống đất
@export var fall_gravity: float = 900.0
@export var fall_max_speed: float = 420.0
@export var return_up_max_time: float = 1.0
@export var return_up_stuck_time: float = 0.25
@export var return_up_min_move_distance: float = 1.0
var is_spawn_bursting: bool = false
var spawn_burst_timer: float = 0.0
var spawn_burst_velocity: Vector2 = Vector2.ZERO
var current_health: int
var current_state: BatState = BatState.PATROL

var player: Player = null
var facing_direction: int = -1

var is_dead: bool = false
var is_hurt_locked: bool = false
var can_attack: bool = true
var is_attack_cooling_down: bool = false

var patrol_positions: Array[Vector2] = []
var current_patrol_index: int = 0
var current_patrol_target: Vector2

var attack_target_position: Vector2
var return_target_position: Vector2

var has_played_fall_animation: bool = false
var return_up_timer: float = 0.0
var return_up_stuck_timer: float = 0.0
var last_return_up_position: Vector2 = Vector2.ZERO
var has_given_exp: bool = false
func _ready() -> void:
	current_health = max_health

	setup_patrol_points()

	hit_box.monitoring = true
	hit_box.monitorable = true
	hit_box_collision.disabled = false

	attack_hurt_box.monitoring = false
	attack_hurt_box.monitorable = true
	attack_hurt_box_collision.disabled = true

	vision_area.body_entered.connect(_on_vision_area_body_entered)
	vision_area.body_exited.connect(_on_vision_area_body_exited)

	hit_box.Damaged.connect(_on_hit_box_damaged)

	attack_hurt_box.body_entered.connect(_on_attack_hurt_box_body_entered)
	attack_hurt_box.area_entered.connect(_on_attack_hurt_box_area_entered)

	animation_player.animation_finished.connect(_on_animation_finished)

	play_flying_sound()

	current_state = BatState.PATROL
	play_animation("walk")

	await get_tree().physics_frame

	for body in vision_area.get_overlapping_bodies():
		_on_vision_area_body_entered(body)


func _physics_process(delta: float) -> void:
	if is_spawn_bursting:
		spawn_burst_timer -= delta
		velocity = spawn_burst_velocity
		move_and_slide()

		if spawn_burst_timer <= 0.0:
			is_spawn_bursting = false

		return

	if is_dead and current_state != BatState.FALL and current_state != BatState.DIE:
		return

	match current_state:
		BatState.PATROL:
			update_patrol(delta)

		BatState.CHASE_ABOVE:
			update_chase_above(delta)

		BatState.DIVE_ATTACK:
			update_dive_attack(delta)

		BatState.RETURN_UP:
			update_return_up(delta)

		BatState.HURT:
			velocity = Vector2.ZERO

		BatState.FALL:
			update_fall(delta)

		BatState.DIE:
			velocity = Vector2.ZERO

	move_and_slide()

	if current_state == BatState.FALL and is_on_floor():
		velocity = Vector2.ZERO
		change_state(BatState.DIE)

# =========================
# STATE
# =========================

func change_state(new_state: BatState) -> void:
	if is_dead and new_state != BatState.DIE and new_state != BatState.FALL:
		return

	if is_hurt_locked and new_state != BatState.DIE and new_state != BatState.FALL:
		return

	if current_state == new_state:
		return

	current_state = new_state

	print("Bat State: ", BatState.keys()[current_state])

	match current_state:
		BatState.PATROL:
			play_animation("walk")

		BatState.CHASE_ABOVE:
			play_animation("walk")

		BatState.DIVE_ATTACK:
			start_dive_attack()

		BatState.RETURN_UP:
			start_return_up()

		BatState.HURT:
			start_hurt()

		BatState.FALL:
			start_fall()

		BatState.DIE:
			start_die()
# =========================
# PATROL
# =========================

func setup_patrol_points() -> void:
	patrol_positions.clear()

	if patrol_points == null:
		return

	for point in patrol_points.get_children():
		patrol_positions.append(point.global_position)

	if patrol_positions.is_empty():
		return

	current_patrol_index = 0
	current_patrol_target = patrol_positions[current_patrol_index]


func update_patrol(_delta: float) -> void:
	if player != null and is_instance_valid(player):
		change_state(BatState.CHASE_ABOVE)
		return

	if patrol_positions.is_empty():
		velocity = Vector2.ZERO
		play_animation("walk")
		return

	var direction_to_target: Vector2 = current_patrol_target - global_position

	if direction_to_target.length() <= patrol_point_reach_distance:
		go_to_next_patrol_point()
		direction_to_target = current_patrol_target - global_position

	if direction_to_target.length() <= 0.1:
		velocity = Vector2.ZERO
	else:
		velocity = direction_to_target.normalized() * patrol_speed

	update_direction_by_velocity()
	play_animation("walk")


func go_to_next_patrol_point() -> void:
	if patrol_positions.is_empty():
		return

	current_patrol_index += 1

	if current_patrol_index >= patrol_positions.size():
		current_patrol_index = 0

	current_patrol_target = patrol_positions[current_patrol_index]


# =========================
# CHASE ABOVE PLAYER
# =========================

func update_chase_above(_delta: float) -> void:
	if player == null or !is_instance_valid(player):
		player = null
		change_state(BatState.PATROL)
		return

	var distance_to_player: float = global_position.distance_to(player.global_position)

	if distance_to_player > aggro_give_up_distance:
		player = null
		change_state(BatState.PATROL)
		return

	var target_position: Vector2 = Vector2(
		player.global_position.x,
		player.global_position.y - hover_height
	)

	var direction_to_target: Vector2 = target_position - global_position

	var x_distance_to_player: float = absf(player.global_position.x - global_position.x)
	var y_distance_to_hover: float = absf(target_position.y - global_position.y)

	if can_attack and x_distance_to_player <= attack_start_distance and y_distance_to_hover <= hover_height:
		change_state(BatState.DIVE_ATTACK)
		return

	if direction_to_target.length() <= 2.0:
		velocity = Vector2.ZERO
	else:
		velocity = direction_to_target.normalized() * chase_speed

	update_direction_to_player()
	play_animation("walk")


# =========================
# DIVE ATTACK
# =========================

func start_dive_attack() -> void:
	if player == null or !is_instance_valid(player):
		player = null
		change_state(BatState.PATROL)
		return

	can_attack = false
	velocity = Vector2.ZERO

	update_direction_to_player()

	attack_target_position = player.global_position + Vector2(0, -8)

	play_animation("attack", true)


func update_dive_attack(_delta: float) -> void:
	var direction_to_target: Vector2 = attack_target_position - global_position

	if direction_to_target.length() <= 6.0:
		velocity = Vector2.ZERO
	else:
		velocity = direction_to_target.normalized() * dive_speed

	update_direction_by_velocity()


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
# RETURN UP
# =========================

func start_return_up() -> void:
	stop_attack_hurt_box()

	velocity = Vector2.ZERO

	return_up_timer = 0.0
	return_up_stuck_timer = 0.0
	last_return_up_position = global_position

	if player != null and is_instance_valid(player):
		return_target_position = Vector2(
			player.global_position.x,
			player.global_position.y - hover_height
		)
	else:
		return_target_position = global_position + Vector2(0, -hover_height)

	play_animation("walk")

func update_return_up(delta: float) -> void:
	return_up_timer += delta

	var direction_to_target: Vector2 = return_target_position - global_position
	var distance_to_target: float = direction_to_target.length()

	# Nếu đã về gần điểm hover thì kết thúc RETURN_UP
	if distance_to_target <= return_finish_distance:
		finish_return_up()
		return

	# Nếu bay quá lâu mà chưa tới được điểm hover thì bỏ bay lên
	if return_up_timer >= return_up_max_time:
		print("Bat RETURN_UP quá lâu, bỏ bay lên")
		finish_return_up()
		return

	# Nếu bị kẹt gần như không di chuyển, cũng bỏ bay lên
	var moved_distance: float = global_position.distance_to(last_return_up_position)

	if moved_distance <= return_up_min_move_distance:
		return_up_stuck_timer += delta
	else:
		return_up_stuck_timer = 0.0

	last_return_up_position = global_position

	if return_up_stuck_timer >= return_up_stuck_time:
		print("Bat bị kẹt khi RETURN_UP, chuyển lại chase")
		finish_return_up()
		return

	velocity = direction_to_target.normalized() * return_speed
	update_direction_by_velocity()
	play_animation("walk")
func start_attack_cooldown() -> void:
	if is_attack_cooling_down:
		return

	is_attack_cooling_down = true
	can_attack = false

	await get_tree().create_timer(attack_cooldown).timeout

	if is_instance_valid(self) and !is_dead:
		can_attack = true

	is_attack_cooling_down = false


# =========================
# HURT / FALL / DIE
# =========================

func take_damage(amount: int) -> void:
	if is_dead:
		return

	current_health -= amount
	current_health = clamp(current_health, 0, max_health)

	print("Bat HP: ", current_health, "/", max_health)

	stop_attack_hurt_box()

	if current_health <= 0:
		change_state(BatState.FALL)
		return

	if current_state == BatState.DIVE_ATTACK or current_state == BatState.RETURN_UP:
		print("Bat bị ngắt chiêu, bắt đầu cooldown lại")
		start_attack_cooldown()

	current_state = BatState.HURT
	start_hurt()


func start_hurt() -> void:
	print("Bat hurt: hurt_" + get_direction_name())

	is_hurt_locked = true
	velocity = Vector2.ZERO

	stop_attack_hurt_box()
	play_hurt_sound()
	play_animation("hurt", true)


func start_fall() -> void:
	give_exp_reward()
	enemy_died.emit(global_position)
	is_dead = true
	is_hurt_locked = false
	current_state = BatState.FALL

	player = null
	can_attack = false
	is_attack_cooling_down = false

	stop_attack_hurt_box()
	stop_flying_sound()
	play_die_sound()

	if hit_box:
		hit_box.monitoring = false
		hit_box.monitorable = false

	if attack_hurt_box:
		attack_hurt_box.monitoring = false
		attack_hurt_box.monitorable = false

	if vision_area:
		vision_area.monitoring = false
		vision_area.monitorable = false

	# Không tắt collision_shape ở đây.
	# Cần giữ CollisionShape2D để Bat có thể chạm Ground khi rơi.
	if collision_shape:
		collision_shape.disabled = false

	velocity.x = 0.0
	velocity.y = 0.0

	has_played_fall_animation = true
	play_animation("idle_to_fall", true)


func update_fall(delta: float) -> void:
	velocity.x = 0.0

	if velocity.y < fall_max_speed:
		velocity.y += fall_gravity * delta

	if velocity.y > fall_max_speed:
		velocity.y = fall_max_speed

	# Nếu Bat đã chạm đất từ trước, chuyển luôn sang die.
	if is_on_floor():
		velocity = Vector2.ZERO
		change_state(BatState.DIE)


func start_die() -> void:
	current_state = BatState.DIE
	velocity = Vector2.ZERO

	# Lúc đã nằm xuống đất rồi mới tắt collision body.
	if collision_shape:
		collision_shape.disabled = true

	play_animation("die", true)


func _on_hit_box_damaged(damage_amount: int) -> void:
	print("Bat nhận damage từ HitBox signal: ", damage_amount)
	take_damage(damage_amount)


# =========================
# ANIMATION FINISHED
# =========================

func _on_animation_finished(anim_name: StringName) -> void:
	if current_state == BatState.DIVE_ATTACK:
		if anim_name == "attack_left" or anim_name == "attack_right":
			stop_attack_hurt_box()
			change_state(BatState.RETURN_UP)
		return

	if current_state == BatState.HURT:
		if anim_name == "hurt_left" or anim_name == "hurt_right":
			is_hurt_locked = false

			if !can_attack and !is_attack_cooling_down:
				start_attack_cooldown()

			if player != null and is_instance_valid(player):
				change_state(BatState.CHASE_ABOVE)
			else:
				change_state(BatState.PATROL)

		return

	if current_state == BatState.FALL:
		# Không chuyển DIE khi idle_to_fall kết thúc nữa.
		# DIE chỉ được chạy khi Bat thật sự chạm đất trong update_fall().
		return

	if current_state == BatState.DIE:
		if anim_name == "die_left" or anim_name == "die_right":
			queue_free()
		return


# =========================
# VISION
# =========================

func _on_vision_area_body_entered(body: Node2D) -> void:
	if is_dead:
		return

	var detected_player: Player = find_player_from_node(body)

	if detected_player == null:
		return

	player = detected_player

	if current_state == BatState.PATROL:
		change_state(BatState.CHASE_ABOVE)


func _on_vision_area_body_exited(body: Node2D) -> void:
	if is_dead:
		return

	var detected_player: Player = find_player_from_node(body)

	if detected_player == null:
		return

	if detected_player != player:
		return

	if current_state == BatState.CHASE_ABOVE:
		return

	if current_state == BatState.DIVE_ATTACK:
		return

	if current_state == BatState.RETURN_UP:
		return

	if current_state == BatState.HURT:
		return

	player = null

	if current_state != BatState.PATROL:
		change_state(BatState.PATROL)


# =========================
# DIRECTION / PLAYER
# =========================

func update_direction_to_player() -> void:
	if player == null or !is_instance_valid(player):
		return

	if player.global_position.x > global_position.x:
		facing_direction = 1
	else:
		facing_direction = -1


func update_direction_by_velocity() -> void:
	if absf(velocity.x) < 1.0:
		return

	if velocity.x > 0:
		facing_direction = 1
	else:
		facing_direction = -1


func get_direction_name() -> String:
	if facing_direction < 0:
		return "left"

	return "right"


func find_player_from_node(node: Node) -> Player:
	var current := node

	while current != null:
		if current is Player:
			return current as Player

		if current.is_in_group("player"):
			return current as Player

		current = current.get_parent()

	return null


# =========================
# SOUND
# =========================

func play_attack_sound() -> void:
	if attack_sound == null:
		return

	attack_sound.stop()
	attack_sound.volume_db = attack_volume_db
	attack_sound.play()


func play_hurt_sound() -> void:
	if hurt_sound == null:
		return

	hurt_sound.stop()
	hurt_sound.volume_db = hurt_volume_db
	hurt_sound.play()


func play_die_sound() -> void:
	if die_sound == null:
		return

	die_sound.stop()
	die_sound.volume_db = die_volume_db
	die_sound.play()


func play_flying_sound() -> void:
	if flying_sound == null:
		return

	flying_sound.volume_db = flying_volume_db

	if !flying_sound.playing:
		flying_sound.play()


func stop_flying_sound() -> void:
	if flying_sound == null:
		return

	flying_sound.stop()


# =========================
# ANIMATION
# =========================

func play_animation(base_name: String, force_restart: bool = false) -> void:
	var anim_name: String = base_name + "_" + get_direction_name()

	if !animation_player.has_animation(anim_name):
		push_warning("Bat thiếu animation: " + anim_name)
		return

	if animation_player.current_animation == anim_name and !force_restart:
		return

	animation_player.play(anim_name)
func finish_return_up() -> void:
	velocity = Vector2.ZERO

	start_attack_cooldown()

	if player != null and is_instance_valid(player):
		change_state(BatState.CHASE_ABOVE)
	else:
		change_state(BatState.PATROL)
func give_exp_reward() -> void:
	if has_given_exp:
		return

	has_given_exp = true

	if PlayerManager.player != null and PlayerManager.player.has_method("gain_exp"):
		PlayerManager.player.gain_exp(exp_reward)
func start_spawn_burst(burst_velocity: Vector2, burst_time: float = 0.55) -> void:
	is_spawn_bursting = true
	spawn_burst_timer = burst_time
	spawn_burst_velocity = burst_velocity
	velocity = burst_velocity

	update_direction_by_velocity()
	play_animation("walk", true)
