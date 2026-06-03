class_name Skeleton
extends CharacterBody2D
signal enemy_died(death_position: Vector2)
enum SkeletonState {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	SHIELD,
	HURT,
	DIE
}

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var body_collision: CollisionShape2D = $CollisionShape2D

@onready var attack_sound: AudioStreamPlayer2D = $Audio/Attack
@onready var hurt_sound: AudioStreamPlayer2D = $Audio/Hurt
@onready var die_sound: AudioStreamPlayer2D = $Audio/Die
@onready var shield_sound: AudioStreamPlayer2D = $Audio/Shield
@onready var walk_sound: AudioStreamPlayer2D = $Audio/Walk

@onready var hit_box: Area2D = $HitBox
@onready var vision_area: Area2D = $VisionArea
@onready var attack_hurt_box: Area2D = $AttackHurtBox
@onready var attack_collision: CollisionShape2D = $AttackHurtBox/CollisionShape2D

@onready var left_point: Node2D = $PatrolPoints/LeftPoint
@onready var right_point: Node2D = $PatrolPoints/RightPoint
@onready var enemy_health_bar: Node = get_node_or_null("EnemyHealthBar")
const GRAVITY: float = 1000.0

@export var max_hp: int = 6
@export var attack_damage: int = 1
@export var exp_reward: int = 2

@export var patrol_speed: float = 35.0
@export var chase_speed: float = 75.0

@export var attack_distance: float = 34.0
@export var attack_y_tolerance: float = 24.0
@export var attack_cooldown_time: float = 1.0
@export var attack_total_time: float = 0.65

@export var hurt_time: float = 0.28
@export var hurt_invincible_time: float = 0.25
@export var knockback_force_x: float = 110.0
@export var knockback_force_y: float = -90.0

@export var shield_duration: float = 0.7
@export var shield_cooldown_time: float = 1.8
@export var shield_chance_on_front_hit: float = 0.8
@export var shield_chance_while_chasing: float = 0.12
@export var shield_trigger_distance: float = 55.0
@export var shield_decision_interval: float = 0.7

@export var leash_padding: float = 45.0
@export var chase_when_seen: bool = true
@export var combat_memory_time: float = 3.0
@export var counter_attack_after_hurt: bool = true
@export var counter_attack_distance: float = 70.0

@export var walk_max_volume_db: float = 4.0
@export var walk_min_volume_db: float = -15
@export var walk_full_volume_distance: float = 45.0
@export var walk_max_hear_distance: float = 400
@export var walk_pitch_min: float = 0.9
@export var walk_pitch_max: float = 1.0

@export var remove_after_die: bool = true
@export var wall_turn_cooldown_time: float = 0.25
@export var wall_push_back_distance: float = 4.0
@export var wall_normal_min_x: float = 0.4
@export var ignore_player_after_wall_time: float = 1.0
@export var hurt_stun_cooldown_time: float = 3.0
var current_state: SkeletonState = SkeletonState.IDLE
var hp: int = 0
var facing_direction: int = 1
var player: Player = null

var patrol_left_x: float = 0.0
var patrol_right_x: float = 0.0
var patrol_target_x: float = 0.0

var attack_cooldown_timer: float = 0.0
var shield_cooldown_timer: float = 0.0
var shield_decision_timer: float = 0.0
var shield_timer: float = 0.0
var hurt_timer: float = 0.0
var damage_lock_timer: float = 0.0
var combat_memory_timer: float = 0.0
var walk_sound_timer: float = 0.0

var is_attack_active: bool = false
var has_hit_player_this_attack: bool = false
var has_given_exp: bool = false
var state_token: int = 0

var vision_base_scale: Vector2 = Vector2.ONE
var attack_base_scale: Vector2 = Vector2.ONE

var wall_turn_cooldown_timer: float = 0.0
var ignore_player_after_wall_timer: float = 0.0
var hurt_stun_cooldown_timer: float = 0.0
func _ready() -> void:
	add_to_group("enemy")
	randomize()

	hp = max_hp
	if enemy_health_bar != null and enemy_health_bar.has_method("set_health"):
		enemy_health_bar.set_health(hp, max_hp)
	patrol_left_x = left_point.global_position.x
	patrol_right_x = right_point.global_position.x

	if patrol_left_x > patrol_right_x:
		var temp: float = patrol_left_x
		patrol_left_x = patrol_right_x
		patrol_right_x = temp

	patrol_target_x = patrol_right_x

	vision_base_scale = vision_area.scale
	attack_base_scale = attack_hurt_box.scale

	stop_attack_hurt_box()
	setup_audio_players()
	if not vision_area.body_entered.is_connected(_on_vision_area_body_entered):
		vision_area.body_entered.connect(_on_vision_area_body_entered)

	if not vision_area.body_exited.is_connected(_on_vision_area_body_exited):
		vision_area.body_exited.connect(_on_vision_area_body_exited)

	if not vision_area.area_entered.is_connected(_on_vision_area_area_entered):
		vision_area.area_entered.connect(_on_vision_area_area_entered)

	if not vision_area.area_exited.is_connected(_on_vision_area_area_exited):
		vision_area.area_exited.connect(_on_vision_area_area_exited)

	if not hit_box.area_entered.is_connected(_on_hit_box_area_entered):
		hit_box.area_entered.connect(_on_hit_box_area_entered)

	if hit_box.has_signal("Damaged"):
		var damaged_callable := Callable(self, "_on_hit_box_damaged")

		if not hit_box.is_connected("Damaged", damaged_callable):
			hit_box.connect("Damaged", damaged_callable)

	if not attack_hurt_box.body_entered.is_connected(_on_attack_hurt_box_body_entered):
		attack_hurt_box.body_entered.connect(_on_attack_hurt_box_body_entered)

	if not attack_hurt_box.area_entered.is_connected(_on_attack_hurt_box_area_entered):
		attack_hurt_box.area_entered.connect(_on_attack_hurt_box_area_entered)

	change_state(SkeletonState.PATROL)

	await get_tree().physics_frame

	if scan_vision_for_player() and should_chase_player():
		change_state(SkeletonState.CHASE)


func _physics_process(delta: float) -> void:
	update_timers(delta)
	apply_gravity(delta)

	match current_state:
		SkeletonState.IDLE:
			process_idle(delta)

		SkeletonState.PATROL:
			process_patrol(delta)

		SkeletonState.CHASE:
			process_chase(delta)

		SkeletonState.ATTACK:
			process_attack(delta)

		SkeletonState.SHIELD:
			process_shield(delta)

		SkeletonState.HURT:
			process_hurt(delta)

		SkeletonState.DIE:
			process_die(delta)

	move_and_slide()
	handle_wall_after_move()

func update_timers(delta: float) -> void:
	if wall_turn_cooldown_timer > 0.0:
		wall_turn_cooldown_timer -= delta
	if ignore_player_after_wall_timer > 0.0:
		ignore_player_after_wall_timer -= delta
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if shield_cooldown_timer > 0.0:
		shield_cooldown_timer -= delta

	if shield_decision_timer > 0.0:
		shield_decision_timer -= delta

	if damage_lock_timer > 0.0:
		damage_lock_timer -= delta

	if combat_memory_timer > 0.0:
		combat_memory_timer -= delta
	if hurt_stun_cooldown_timer > 0.0:
		hurt_stun_cooldown_timer -= delta
	if hurt_stun_cooldown_timer < 0.0:
		hurt_stun_cooldown_timer = 0.0



func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0


func change_state(new_state: SkeletonState) -> void:
	if current_state == SkeletonState.DIE:
		return

	state_token += 1
	stop_attack_hurt_box()

	current_state = new_state

	match current_state:
		SkeletonState.IDLE:
			velocity.x = 0.0
			play_animation("idle")

		SkeletonState.PATROL:
			play_animation("walk")

		SkeletonState.CHASE:
			play_animation("walk")

		SkeletonState.ATTACK:
			velocity.x = 0.0
			start_attack(state_token)

		SkeletonState.SHIELD:
			velocity.x = 0.0
			shield_timer = shield_duration
			play_animation("shield")
			# Không phát shield sound ở đây.
			# Shield sound chỉ phát khi Player thật sự đánh trúng khiên.

		SkeletonState.HURT:
			hurt_timer = hurt_time
			play_animation("hurt")

			if hurt_sound != null:
				hurt_sound.stop()
				hurt_sound.play()

		SkeletonState.DIE:
			start_die(state_token)


func process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)

	if scan_vision_for_player() and should_chase_player():
		change_state(SkeletonState.CHASE)
		return

	play_animation("idle")


func process_patrol(_delta: float) -> void:
	if scan_vision_for_player() and should_chase_player():
		change_state(SkeletonState.CHASE)
		return

	if absf(global_position.x - patrol_target_x) <= 4.0:
		if patrol_target_x == patrol_right_x:
			patrol_target_x = patrol_left_x
		else:
			patrol_target_x = patrol_right_x

	if patrol_target_x > global_position.x:
		set_facing_direction(1)
	else:
		set_facing_direction(-1)

	velocity.x = facing_direction * patrol_speed
	play_animation("walk")


func process_chase(_delta: float) -> void:
	if not should_chase_player():
		player = null
		change_state(SkeletonState.PATROL)
		return

	if not is_player_inside_leash():
		player = null
		change_state(SkeletonState.PATROL)
		return

	update_direction_to_player()

	var x_distance: float = get_x_distance_to_player()
	var y_distance: float = get_y_distance_to_player()

	if can_start_shield() and x_distance <= shield_trigger_distance and y_distance <= attack_y_tolerance:
		if shield_decision_timer <= 0.0:
			shield_decision_timer = shield_decision_interval

			if randf() <= shield_chance_while_chasing:
				change_state(SkeletonState.SHIELD)
				return

	if x_distance <= attack_distance and y_distance <= attack_y_tolerance:
		velocity.x = 0.0

		if attack_cooldown_timer <= 0.0:
			change_state(SkeletonState.ATTACK)
			return

		play_animation("idle")
		return

	velocity.x = facing_direction * chase_speed
	play_animation("walk")


func process_attack(_delta: float) -> void:
	velocity.x = 0.0


func process_shield(delta: float) -> void:
	velocity.x = 0.0
	shield_timer -= delta
	play_animation("shield")

	if shield_timer <= 0.0:
		shield_cooldown_timer = shield_cooldown_time

		if should_chase_player():
			if get_x_distance_to_player() <= attack_distance and attack_cooldown_timer <= 0.0:
				change_state(SkeletonState.ATTACK)
			else:
				change_state(SkeletonState.CHASE)
		else:
			change_state(SkeletonState.PATROL)


func process_hurt(delta: float) -> void:
	hurt_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)

	if hurt_timer <= 0.0:
		if counter_attack_after_hurt and can_counter_attack_player() and attack_cooldown_timer <= 0.0:
			change_state(SkeletonState.ATTACK)
			return

		if should_chase_player():
			change_state(SkeletonState.CHASE)
		else:
			change_state(SkeletonState.PATROL)


func process_die(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)


func should_chase_player() -> bool:
	if ignore_player_after_wall_timer > 0.0:
		return false

	if not has_valid_player():
		return false

	if not is_player_inside_leash():
		return false

	if combat_memory_timer > 0.0:
		return true

	if chase_when_seen:
		return true

	return false


func has_valid_player() -> bool:
	return player != null and is_instance_valid(player) and not player.is_dead


func is_player_inside_leash() -> bool:
	if not has_valid_player():
		return false

	if player.global_position.x < patrol_left_x - leash_padding:
		return false

	if player.global_position.x > patrol_right_x + leash_padding:
		return false

	return true


func scan_vision_for_player() -> bool:
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


func remember_player_from_attack(attacker_position: Vector2 = Vector2.ZERO) -> void:
	if PlayerManager.player != null and PlayerManager.player is Player:
		player = PlayerManager.player as Player

	combat_memory_timer = combat_memory_time

	if attacker_position != Vector2.ZERO:
		if attacker_position.x < global_position.x:
			set_facing_direction(-1)
		else:
			set_facing_direction(1)
	elif has_valid_player():
		update_direction_to_player()


func update_direction_to_player() -> void:
	if not has_valid_player():
		return

	if player.global_position.x < global_position.x:
		set_facing_direction(-1)
	else:
		set_facing_direction(1)


func set_facing_direction(value: int) -> void:
	if value < 0:
		facing_direction = -1
	else:
		facing_direction = 1

	update_facing_visual()


func update_facing_visual() -> void:
	vision_area.scale = Vector2(absf(vision_base_scale.x) * float(facing_direction), vision_base_scale.y)
	attack_hurt_box.scale = Vector2(absf(attack_base_scale.x) * float(facing_direction), attack_base_scale.y)


func get_x_distance_to_player() -> float:
	if not has_valid_player():
		return 999999.0

	return absf(player.global_position.x - global_position.x)


func get_y_distance_to_player() -> float:
	if not has_valid_player():
		return 999999.0

	return absf(player.global_position.y - global_position.y)


func can_start_shield() -> bool:
	if shield_cooldown_timer > 0.0:
		return false

	if current_state == SkeletonState.DIE:
		return false

	if current_state == SkeletonState.HURT:
		return false

	if current_state == SkeletonState.ATTACK:
		return false

	return true


func can_counter_attack_player() -> bool:
	if not has_valid_player():
		return false

	if get_x_distance_to_player() > counter_attack_distance:
		return false

	if get_y_distance_to_player() > attack_y_tolerance:
		return false

	return true


func is_position_in_front(position: Vector2) -> bool:
	var dx: float = position.x - global_position.x

	if absf(dx) <= 2.0:
		return true

	if dx > 0.0 and facing_direction > 0:
		return true

	if dx < 0.0 and facing_direction < 0:
		return true

	return false


func play_animation(base_name: String) -> bool:
	var direction_name: String = "right"

	if facing_direction < 0:
		direction_name = "left"

	var directional_anim: String = base_name + "_" + direction_name

	if animation_player.has_animation(directional_anim):
		sprite_2d.flip_h = false

		if animation_player.current_animation != directional_anim:
			animation_player.play(directional_anim)

		return true

	if animation_player.has_animation(base_name):
		sprite_2d.flip_h = facing_direction < 0

		if animation_player.current_animation != base_name:
			animation_player.play(base_name)

		return true

	push_warning("Skeleton thiếu animation: " + directional_anim + " hoặc " + base_name)
	return false


func get_current_animation_length(fallback: float) -> float:
	var length: float = animation_player.current_animation_length

	if length <= 0.0:
		return fallback

	return length


func start_attack(my_token: int) -> void:
	update_direction_to_player()
	play_animation("attack")

	stop_attack_hurt_box()

	var total_time: float = attack_total_time
	var anim_length: float = get_current_animation_length(total_time)
	total_time = maxf(total_time, anim_length)

	await get_tree().create_timer(total_time).timeout

	stop_attack_hurt_box()

	if not is_state_token_valid(SkeletonState.ATTACK, my_token):
		return

	attack_cooldown_timer = attack_cooldown_time

	if should_chase_player():
		change_state(SkeletonState.CHASE)
	else:
		change_state(SkeletonState.PATROL)


func start_attack_hurt_box() -> void:
	if current_state != SkeletonState.ATTACK:
		return

	if current_state == SkeletonState.DIE:
		return

	if attack_sound != null:
		attack_sound.stop()
		attack_sound.play()

	is_attack_active = true
	has_hit_player_this_attack = false

	if attack_collision != null:
		attack_collision.disabled = false

	if attack_hurt_box != null:
		attack_hurt_box.monitoring = true
		attack_hurt_box.monitorable = true

	await get_tree().physics_frame

	if current_state != SkeletonState.ATTACK:
		return

	for body in attack_hurt_box.get_overlapping_bodies():
		try_hit_player(body)

	for area in attack_hurt_box.get_overlapping_areas():
		try_hit_player(area)


func stop_attack_hurt_box() -> void:
	is_attack_active = false
	has_hit_player_this_attack = false

	if attack_collision != null:
		attack_collision.disabled = true

	if attack_hurt_box != null:
		attack_hurt_box.monitoring = false


func try_hit_player(target: Node) -> void:
	if not is_attack_active:
		return

	if has_hit_player_this_attack:
		return

	var detected_player: Player = find_player_from_node(target)

	if detected_player == null:
		return

	has_hit_player_this_attack = true

	if detected_player.has_method("take_damage"):
		detected_player.take_damage(attack_damage, global_position)
	elif detected_player.has_method("die"):
		detected_player.die(global_position)


func receive_player_hit(damage: int, attacker_position: Vector2) -> void:
	if current_state == SkeletonState.DIE:
		return

	remember_player_from_attack(attacker_position)

	if damage_lock_timer > 0.0:
		return

	damage_lock_timer = hurt_invincible_time

	if should_block_attack(attacker_position):
		block_attack(attacker_position)
		return

	take_damage(damage, attacker_position)


func should_block_attack(attacker_position: Vector2) -> bool:
	if not is_position_in_front(attacker_position):
		return false

	if current_state == SkeletonState.SHIELD:
		return true

	if not can_start_shield():
		return false

	if randf() <= shield_chance_on_front_hit:
		return true

	return false


func block_attack(attacker_position: Vector2) -> void:
	if attacker_position != Vector2.ZERO:
		if attacker_position.x < global_position.x:
			set_facing_direction(-1)
		else:
			set_facing_direction(1)

	if shield_sound != null:
		shield_sound.stop()
		shield_sound.play()

	change_state(SkeletonState.SHIELD)


func take_damage(damage: int, attacker_position: Vector2) -> void:
	hp -= damage
	hp = clamp(hp, 0, max_hp)

	if enemy_health_bar != null and enemy_health_bar.has_method("show_damage_health"):
		enemy_health_bar.show_damage_health(hp, max_hp)

	if hp <= 0:
		change_state(SkeletonState.DIE)
		return

	if attacker_position != Vector2.ZERO:
		if attacker_position.x < global_position.x:
			set_facing_direction(-1)
		else:
			set_facing_direction(1)
	var can_apply_stun: bool = hurt_stun_cooldown_timer <= 0.0

	if not can_apply_stun:
		print("Skeleton nhận damage nhưng không bị choáng do đang hồi stun")
		return

	hurt_stun_cooldown_timer = hurt_stun_cooldown_time

	if attacker_position != Vector2.ZERO:
		var knockback_direction: float = 1.0

		if global_position.x < attacker_position.x:
			knockback_direction = -1.0
		else:
			knockback_direction = 1.0

		velocity.x = knockback_direction * knockback_force_x
		velocity.y = knockback_force_y

	change_state(SkeletonState.HURT)


func start_die(my_token: int) -> void:
	give_exp_reward()
	if enemy_health_bar != null:
		enemy_health_bar.visible = false
	stop_attack_hurt_box()
	enemy_died.emit(global_position)
	if die_sound != null:
		die_sound.stop()
		die_sound.play()

	var has_die_animation: bool = play_animation("die")

	if has_die_animation:
		await animation_player.animation_finished

	if not is_state_token_valid(SkeletonState.DIE, my_token):
		return

	if remove_after_die:
		queue_free()


func give_exp_reward() -> void:
	if has_given_exp:
		return

	has_given_exp = true

	if PlayerManager.player != null and PlayerManager.player.has_method("gain_exp"):
		PlayerManager.player.gain_exp(exp_reward)


func is_state_token_valid(expected_state: SkeletonState, token: int) -> bool:
	return current_state == expected_state and state_token == token and is_inside_tree()


func play_walk_sound() -> void:
	if current_state != SkeletonState.PATROL and current_state != SkeletonState.CHASE:
		return

	if absf(velocity.x) < 5.0:
		return

	if not is_on_floor():
		return

	if walk_sound == null:
		return

	var volume_by_distance: float = get_walk_volume_by_distance()

	if volume_by_distance <= -80.0:
		return

	walk_sound.stop()
	walk_sound.volume_db = volume_by_distance
	walk_sound.pitch_scale = randf_range(walk_pitch_min, walk_pitch_max)
	walk_sound.play()
func get_walk_volume_by_distance() -> float:
	var target_player: Node2D = get_player_for_sound()

	if target_player == null:
		return walk_min_volume_db

	var distance_to_player: float = global_position.distance_to(target_player.global_position)

	if distance_to_player <= walk_full_volume_distance:
		return walk_max_volume_db

	if distance_to_player >= walk_max_hear_distance:
		return -80.0

	var distance_ratio: float = inverse_lerp(
		walk_full_volume_distance,
		walk_max_hear_distance,
		distance_to_player
	)

	distance_ratio = clamp(distance_ratio, 0.0, 1.0)

	return lerp(walk_max_volume_db, walk_min_volume_db, distance_ratio)


func get_player_for_sound() -> Node2D:
	if player != null and is_instance_valid(player):
		return player

	if PlayerManager.player != null and PlayerManager.player is Node2D:
		return PlayerManager.player as Node2D

	return null
func _on_vision_area_body_entered(body: Node2D) -> void:
	var detected_player: Player = find_player_from_node(body)

	if detected_player == null:
		return

	player = detected_player

	if current_state == SkeletonState.PATROL or current_state == SkeletonState.IDLE:
		change_state(SkeletonState.CHASE)


func _on_vision_area_body_exited(body: Node2D) -> void:
	var detected_player: Player = find_player_from_node(body)

	if detected_player == null:
		return

	if detected_player != player:
		return

	if combat_memory_timer > 0.0:
		return

	player = null

	if current_state == SkeletonState.CHASE:
		change_state(SkeletonState.PATROL)


func _on_vision_area_area_entered(area: Area2D) -> void:
	var detected_player: Player = find_player_from_node(area)

	if detected_player == null:
		return

	player = detected_player

	if current_state == SkeletonState.PATROL or current_state == SkeletonState.IDLE:
		change_state(SkeletonState.CHASE)


func _on_vision_area_area_exited(area: Area2D) -> void:
	var detected_player: Player = find_player_from_node(area)

	if detected_player == null:
		return

	if detected_player != player:
		return

	if combat_memory_timer > 0.0:
		return

	player = null

	if current_state == SkeletonState.CHASE:
		change_state(SkeletonState.PATROL)


func _on_hit_box_area_entered(area: Area2D) -> void:
	var detected_player: Player = find_player_from_node(area)
	var attacker_position: Vector2 = Vector2.ZERO

	if detected_player != null:
		attacker_position = detected_player.global_position
	elif PlayerManager.player != null and PlayerManager.player is Node2D:
		attacker_position = PlayerManager.player.global_position

	var damage: int = 1
	var possible_damage = area.get("damage")

	if possible_damage != null:
		damage = int(possible_damage)

	receive_player_hit(damage, attacker_position)


func _on_hit_box_damaged(arg1 = null, arg2 = null, arg3 = null) -> void:
	var damage: int = 1
	var attacker_position: Vector2 = Vector2.ZERO
	var attacker: Node = null

	if typeof(arg1) == TYPE_INT or typeof(arg1) == TYPE_FLOAT:
		damage = int(arg1)
	elif arg1 is Node:
		attacker = arg1

	if arg2 is Vector2:
		attacker_position = arg2
	elif arg2 is Node:
		attacker = arg2

	if arg3 is Node:
		attacker = arg3

	if attacker != null and attacker is Node2D:
		attacker_position = attacker.global_position

	if attacker_position == Vector2.ZERO and PlayerManager.player != null:
		attacker_position = PlayerManager.player.global_position

	receive_player_hit(damage, attacker_position)


func _on_attack_hurt_box_body_entered(body: Node2D) -> void:
	try_hit_player(body)


func _on_attack_hurt_box_area_entered(area: Area2D) -> void:
	try_hit_player(area)


func find_player_from_node(node: Node) -> Player:
	var current: Node = node

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
func handle_wall_after_move() -> void:
	if wall_turn_cooldown_timer > 0.0:
		return

	if current_state != SkeletonState.PATROL and current_state != SkeletonState.CHASE:
		return

	if absf(velocity.x) < 1.0:
		return

	if not is_blocked_by_front_wall():
		return

	print("Skeleton đụng tường, quay đầu")

	wall_turn_cooldown_timer = wall_turn_cooldown_time

	if current_state == SkeletonState.CHASE:
		player = null
		combat_memory_timer = 0.0
		ignore_player_after_wall_timer = ignore_player_after_wall_time

	turn_around_from_wall()

	if current_state == SkeletonState.CHASE:
		change_state(SkeletonState.PATROL)


func is_blocked_by_front_wall() -> bool:
	var moving_direction: int = 0

	if velocity.x > 0.0:
		moving_direction = 1
	elif velocity.x < 0.0:
		moving_direction = -1
	else:
		return false

	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		var normal: Vector2 = collision.get_normal()

		if moving_direction > 0 and normal.x <= -wall_normal_min_x:
			return true

		if moving_direction < 0 and normal.x >= wall_normal_min_x:
			return true

	return false


func turn_around_from_wall() -> void:
	var old_direction: int = facing_direction
	var new_direction: int = -old_direction

	set_facing_direction(new_direction)

	if new_direction > 0:
		patrol_target_x = patrol_right_x
	else:
		patrol_target_x = patrol_left_x

	velocity.x = float(new_direction) * patrol_speed

	# Đẩy ra khỏi tường theo hướng mới
	global_position.x += float(new_direction) * wall_push_back_distance
func setup_audio_players() -> void:
	setup_one_audio_player(attack_sound)
	setup_one_audio_player(hurt_sound)
	setup_one_audio_player(die_sound)
	setup_one_audio_player(shield_sound)
	setup_one_audio_player(walk_sound)


func setup_one_audio_player(sound: AudioStreamPlayer2D) -> void:
	if sound == null:
		return

	sound.stop()
	sound.autoplay = false
	sound.stream_paused = false
	sound.max_distance = 10000.0
	sound.attenuation = 0.0
func is_targeting_player() -> bool:
	if current_state == SkeletonState.DIE:
		return false

	if player == null:
		return false

	if not is_instance_valid(player):
		return false

	if PlayerManager.player == null:
		return false

	return player == PlayerManager.player
