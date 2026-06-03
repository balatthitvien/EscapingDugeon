class_name Mimic
extends CharacterBody2D

signal enemy_died(death_position: Vector2)

enum MimicState {
	CHEST,
	TRANSFORM,
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	HURT,
	DIE
}

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var walk_sound: AudioStreamPlayer2D = get_node_or_null("Audio/Walk") as AudioStreamPlayer2D
@onready var attack_sound: AudioStreamPlayer2D = get_node_or_null("Audio/Attack") as AudioStreamPlayer2D
@onready var hurt_sound: AudioStreamPlayer2D = get_node_or_null("Audio/Hurt") as AudioStreamPlayer2D
@onready var die_sound: AudioStreamPlayer2D = get_node_or_null("Audio/Die") as AudioStreamPlayer2D
@onready var open_sound: AudioStreamPlayer2D = get_node_or_null("Audio/Open") as AudioStreamPlayer2D

@onready var interact_area: Area2D = get_node_or_null("InteractionArea") as Area2D
@onready var interact_collision: CollisionShape2D = get_node_or_null("InteractionArea/CollisionShape2D") as CollisionShape2D
@onready var talk_indicator: Sprite2D = $TalkIndicator

@onready var hit_box: Area2D = $HitBox
@onready var hit_box_collision: CollisionShape2D = $HitBox/CollisionShape2D

@onready var vision_area: Area2D = $VisionArea
@onready var attack_hurt_box: Area2D = $AttackHurtBox
@onready var attack_hurt_box_collision: CollisionShape2D = $AttackHurtBox/CollisionShape2D

@onready var left_point: Node2D = $PatrolPoints/LeftPoint
@onready var right_point: Node2D = $PatrolPoints/RightPoint

const GRAVITY: float = 1000.0

@export var mimic_id: String = "map_3_mimic_1"

@export var max_health: int = 5
@export var damage: int = 1
@export var exp_reward: int = 3

@export var hidden_sprite_scale: Vector2 = Vector2(0.78, 0.78)
@export var normal_sprite_scale: Vector2 = Vector2.ONE

@export var patrol_speed: float = 35.0
@export var chase_speed: float = 75.0
@export var attack_distance: float = 60
@export var attack_y_tolerance: float = 35.0
@export var attack_cooldown_time: float = 1.0
@export var hurt_time: float = 0.3
@export var stop_chase_distance: float = 60.0
@export var knockback_force_x: float = 120.0
@export var knockback_force_y: float = -100.0

@export var vision_chase_distance: float = 260.0
@export var leash_padding: float = 70.0

@export var remove_after_die: bool = true
@onready var enemy_health_bar: Node = get_node_or_null("EnemyHealthBar")
@export var walk_volume_db: float = 5.0
@export var attack_volume_db: float = 4.0
@export var hurt_volume_db: float = 4.0
@export var die_volume_db: float = 4.0
@export var open_volume_db: float = 4.0

@export var ambush_attack_after_open: bool = true
@export var ambush_attack_delay: float = 0.01
@export var counter_attack_after_hurt: bool = true
@export var counter_attack_distance: float = 95.0
@export var hurt_stun_cooldown_time: float = 2.0
var current_state: MimicState = MimicState.CHEST
var current_health: int = 0

var player: Player = null
var player_in_interact_range: bool = false

var facing_direction: int = 1
var is_transformed: bool = false
var is_dead: bool = false
var is_attack_active: bool = false
var has_hit_player_this_attack: bool = false
var has_given_exp: bool = false

var patrol_left_x: float = 0.0
var patrol_right_x: float = 0.0
var patrol_target_x: float = 0.0

var attack_cooldown_timer: float = 0.0
var hurt_timer: float = 0.0
var hurt_stun_cooldown_timer: float = 0.0
var players_near: Dictionary = {}
func _ready() -> void:
	add_to_group("enemy")
	current_health = max_health

	if enemy_health_bar != null and enemy_health_bar.has_method("set_health"):
		enemy_health_bar.set_health(current_health, max_health)

	patrol_left_x = left_point.global_position.x
	patrol_right_x = right_point.global_position.x

	if patrol_left_x > patrol_right_x:
		var temp: float = patrol_left_x
		patrol_left_x = patrol_right_x
		patrol_right_x = temp

	patrol_target_x = patrol_right_x

	connect_signals()
	stop_attack_hurt_box()

	if talk_indicator != null:
		talk_indicator.visible = false
		talk_indicator.z_index = 100
		talk_indicator.z_as_relative = false

	if LevelManager.get_game_flag(get_dead_flag()):
		queue_free()
		return

	if LevelManager.get_game_flag(get_open_flag()):
		set_as_mimic_immediate()
	else:
		set_as_chest()


func connect_signals() -> void:
	if interact_area == null:
		push_error("Mimic thiếu node InteractionArea.")
		return

	if vision_area == null:
		push_error("Mimic thiếu node VisionArea.")
		return

	if hit_box == null:
		push_error("Mimic thiếu node HitBox.")
		return

	if attack_hurt_box == null:
		push_error("Mimic thiếu node AttackHurtBox.")
		return

	if animation_player == null:
		push_error("Mimic thiếu node AnimationPlayer.")
		return

	if not interact_area.body_entered.is_connected(_on_interact_body_entered):
		interact_area.body_entered.connect(_on_interact_body_entered)

	if not interact_area.body_exited.is_connected(_on_interact_body_exited):
		interact_area.body_exited.connect(_on_interact_body_exited)

	if not interact_area.area_entered.is_connected(_on_interact_area_entered):
		interact_area.area_entered.connect(_on_interact_area_entered)

	if not interact_area.area_exited.is_connected(_on_interact_area_exited):
		interact_area.area_exited.connect(_on_interact_area_exited)

	if not vision_area.body_entered.is_connected(_on_vision_body_entered):
		vision_area.body_entered.connect(_on_vision_body_entered)

	if not vision_area.area_entered.is_connected(_on_vision_area_entered):
		vision_area.area_entered.connect(_on_vision_area_entered)

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

	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if current_state == MimicState.CHEST:
		return

	if current_state == MimicState.TRANSFORM:
		return

	if is_dead:
		return

	update_timers(delta)
	apply_gravity(delta)

	match current_state:
		MimicState.IDLE:
			process_idle(delta)

		MimicState.PATROL:
			process_patrol(delta)

		MimicState.CHASE:
			process_chase(delta)

		MimicState.ATTACK:
			process_attack(delta)

		MimicState.HURT:
			process_hurt(delta)

		MimicState.DIE:
			pass

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if current_state != MimicState.CHEST:
		return

	if not player_in_interact_range:
		return

	var action_player := get_player_pressed_interact_event(event)

	if action_player == null:
		return

	player = action_player
	get_viewport().set_input_as_handled()

	await open_mimic_chest(action_player)

func get_open_flag() -> String:
	return mimic_id + "_opened"


func get_dead_flag() -> String:
	return mimic_id + "_dead"


func set_as_chest() -> void:
	current_state = MimicState.CHEST
	is_transformed = false
	is_dead = false
	facing_direction = 1
	velocity = Vector2.ZERO

	if sprite_2d != null:
		sprite_2d.scale = hidden_sprite_scale

	enable_interaction(true)
	enable_enemy_parts(false)

	play_exact_animation("normal_right")


func set_as_mimic_immediate() -> void:
	is_transformed = true
	is_dead = false
	current_state = MimicState.PATROL
	facing_direction = 1

	if sprite_2d != null:
		sprite_2d.scale = normal_sprite_scale

	enable_interaction(false)
	enable_enemy_parts(true)

	play_animation("walk")


func open_mimic_chest(opening_player: Player = null) -> void:
	if is_transformed:
		return

	is_transformed = true
	current_state = MimicState.TRANSFORM

	# Bất kỳ Player nào mở Mimic đều lưu trạng thái đã biến thành quái.
	LevelManager.set_game_flag(get_open_flag(), true)

	if opening_player != null:
		player = opening_player

	if talk_indicator != null:
		talk_indicator.visible = false

	enable_interaction(false)
	enable_enemy_parts(false)

	velocity = Vector2.ZERO
	facing_direction = 1

	if sprite_2d != null:
		sprite_2d.scale = normal_sprite_scale

	play_open_sound()

	if animation_player.has_animation("transform_right"):
		animation_player.play("transform_right")
		await animation_player.animation_finished
	else:
		push_warning(name + " thiếu animation transform_right")

	enable_enemy_parts(true)

	if player == null or !is_instance_valid(player):
		find_valid_player_in_vision()

	if player != null and is_instance_valid(player):
		update_direction_to_player()

		if ambush_attack_after_open:
			await get_tree().create_timer(ambush_attack_delay).timeout

			if not is_dead:
				change_state(MimicState.ATTACK)
				return

		change_state(MimicState.CHASE)
	else:
		change_state(MimicState.PATROL)

func enable_interaction(value: bool) -> void:
	if interact_area != null:
		interact_area.monitoring = value
		interact_area.monitorable = value

	if interact_collision != null:
		interact_collision.disabled = not value

	if not value and talk_indicator != null:
		talk_indicator.visible = false


func enable_enemy_parts(value: bool) -> void:
	if hit_box != null:
		hit_box.monitoring = value
		hit_box.monitorable = value

	if vision_area != null:
		vision_area.monitoring = value
		vision_area.monitorable = value

	if hit_box_collision != null:
		hit_box_collision.disabled = not value

	if value:
		stop_attack_hurt_box()
	else:
		if attack_hurt_box != null:
			attack_hurt_box.monitoring = false
			attack_hurt_box.monitorable = false

		if attack_hurt_box_collision != null:
			attack_hurt_box_collision.disabled = true


func update_timers(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if hurt_stun_cooldown_timer > 0.0:
		hurt_stun_cooldown_timer -= delta
		if hurt_stun_cooldown_timer < 0.0:
			hurt_stun_cooldown_timer = 0.0
func can_counter_attack_player() -> bool:
	if not has_valid_player():
		return false

	var x_distance: float = absf(player.global_position.x - global_position.x)
	var y_distance: float = absf(player.global_position.y - global_position.y)

	if x_distance > counter_attack_distance:
		return false

	if y_distance > attack_y_tolerance:
		return false

	return true
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0


func process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)

	if find_valid_player_in_vision():
		change_state(MimicState.CHASE)
		return

	play_idle_animation()


func process_patrol(_delta: float) -> void:
	if find_valid_player_in_vision():
		change_state(MimicState.CHASE)
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
	if not has_valid_player():
		player = null
		change_state(MimicState.PATROL)
		return

	if not is_player_inside_leash():
		player = null
		change_state(MimicState.PATROL)
		return

	update_direction_to_player()

	var x_distance: float = absf(player.global_position.x - global_position.x)
	var y_distance: float = absf(player.global_position.y - global_position.y)

	if x_distance <= attack_distance and y_distance <= attack_y_tolerance:
		velocity.x = 0.0

		if attack_cooldown_timer <= 0.0:
			change_state(MimicState.ATTACK)
			return

		play_idle_animation()
		return

	velocity.x = facing_direction * chase_speed
	play_animation("walk")

func process_attack(_delta: float) -> void:
	velocity.x = 0.0


func process_hurt(delta: float) -> void:
	hurt_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)

	if hurt_timer <= 0.0:
		if counter_attack_after_hurt and can_counter_attack_player() and attack_cooldown_timer <= 0.0:
			change_state(MimicState.ATTACK)
			return

		if has_valid_player():
			change_state(MimicState.CHASE)
		else:
			change_state(MimicState.PATROL)


func change_state(new_state: MimicState) -> void:
	if is_dead and new_state != MimicState.DIE:
		return

	if current_state == new_state:
		return

	stop_attack_hurt_box()

	current_state = new_state

	match current_state:
		MimicState.IDLE:
			velocity.x = 0.0
			play_idle_animation()

		MimicState.PATROL:
			play_animation("walk")

		MimicState.CHASE:
			play_animation("walk")

		MimicState.ATTACK:
			start_attack()

		MimicState.HURT:
			start_hurt()

		MimicState.DIE:
			start_die()


func start_attack() -> void:
	velocity.x = 0.0
	update_direction_to_player()
	play_animation("attack", true)


func start_attack_hurt_box() -> void:
	if current_state != MimicState.ATTACK:
		return

	is_attack_active = true
	has_hit_player_this_attack = false

	if attack_hurt_box_collision != null:
		attack_hurt_box_collision.disabled = false

	if attack_hurt_box != null:
		attack_hurt_box.monitoring = true
		attack_hurt_box.monitorable = true

	await get_tree().physics_frame

	if attack_hurt_box == null:
		return

	for body in attack_hurt_box.get_overlapping_bodies():
		try_hit_player(body)

	for area in attack_hurt_box.get_overlapping_areas():
		try_hit_player(area)


func stop_attack_hurt_box() -> void:
	is_attack_active = false
	has_hit_player_this_attack = false

	if attack_hurt_box != null:
		attack_hurt_box.monitoring = false

	if attack_hurt_box_collision != null:
		attack_hurt_box_collision.disabled = true


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
		detected_player.take_damage(damage, global_position)


func start_hurt() -> void:
	hurt_timer = hurt_time
	stop_attack_hurt_box()

	is_attack_active = false
	has_hit_player_this_attack = false
	attack_cooldown_timer = attack_cooldown_time

	play_hurt_sound()

	play_animation("hurt", true)

func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if current_state == MimicState.CHEST:
		return

	if current_state == MimicState.TRANSFORM:
		return

	if is_dead:
		return

	current_health -= amount
	current_health = clamp(current_health, 0, max_health)

	if enemy_health_bar != null and enemy_health_bar.has_method("show_damage_health"):
		enemy_health_bar.show_damage_health(current_health, max_health)

	if current_health <= 0:
		change_state(MimicState.DIE)
		return

	if attacker_position != Vector2.ZERO:
		if attacker_position.x < global_position.x:
			set_facing_direction(-1)
		else:
			set_facing_direction(1)

	if current_state == MimicState.ATTACK:
		play_hurt_sound()
		return

	if hurt_stun_cooldown_timer > 0.0:
		play_hurt_sound()

		if has_valid_player():
			change_state(MimicState.CHASE)

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

	change_state(MimicState.HURT)
func start_die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	if enemy_health_bar != null:
		enemy_health_bar.visible = false
	LevelManager.set_game_flag(get_open_flag(), true)
	LevelManager.set_game_flag(get_dead_flag(), true)

	give_exp_reward()
	enemy_died.emit(global_position)
	stop_attack_hurt_box()

	if die_sound != null:
		die_sound.stop()
		die_sound.volume_db = die_volume_db
		die_sound.play()

	enable_interaction(false)

	if hit_box != null:
		hit_box.monitoring = false
		hit_box.monitorable = false

	if vision_area != null:
		vision_area.monitoring = false
		vision_area.monitorable = false

	if collision_shape != null:
		collision_shape.disabled = true

	play_animation("die", true)


func give_exp_reward() -> void:
	if has_given_exp:
		return

	has_given_exp = true

	if PlayerManager.player != null and PlayerManager.player.has_method("gain_exp"):
		PlayerManager.player.gain_exp(exp_reward)


func find_valid_player_in_vision() -> bool:
	if vision_area == null:
		return false

	for body in vision_area.get_overlapping_bodies():
		var detected_player := find_player_from_node(body)

		if detected_player != null:
			player = detected_player
			return true

	for area in vision_area.get_overlapping_areas():
		var detected_player := find_player_from_node(area)

		if detected_player != null:
			player = detected_player
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

	if global_position.distance_to(player.global_position) > vision_chase_distance:
		return false

	return true


func update_direction_to_player() -> void:
	if not has_valid_player():
		return

	if player.global_position.x > global_position.x:
		set_facing_direction(1)
	else:
		set_facing_direction(-1)


func set_facing_direction(value: int) -> void:
	if value < 0:
		facing_direction = -1
	else:
		facing_direction = 1


func play_idle_animation() -> void:
	if animation_player.has_animation("idle_" + get_direction_name()):
		play_animation("idle")
	else:
		play_animation("walk")


func play_animation(base_name: String, force_restart: bool = false) -> void:
	var anim_name: String = base_name + "_" + get_direction_name()

	if not animation_player.has_animation(anim_name):
		push_warning(name + " thiếu animation: " + anim_name)
		return

	if animation_player.current_animation == anim_name and not force_restart:
		return

	animation_player.play(anim_name)


func play_exact_animation(anim_name: String) -> void:
	if not animation_player.has_animation(anim_name):
		push_warning(name + " thiếu animation: " + anim_name)
		return

	if animation_player.current_animation == anim_name:
		return

	animation_player.play(anim_name)


func get_direction_name() -> String:
	if facing_direction < 0:
		return "left"

	return "right"


func _on_animation_finished(anim_name: StringName) -> void:
	if current_state == MimicState.ATTACK:
		if anim_name == "attack_left" or anim_name == "attack_right":
			stop_attack_hurt_box()
			attack_cooldown_timer = attack_cooldown_time

			if has_valid_player():
				change_state(MimicState.CHASE)
			else:
				change_state(MimicState.PATROL)

		return

	if current_state == MimicState.DIE:
		if anim_name == "die_left" or anim_name == "die_right":
			if remove_after_die:
				queue_free()

		return


func _on_interact_body_entered(body: Node2D) -> void:
	try_set_player_in_range(body)


func _on_interact_body_exited(body: Node2D) -> void:
	try_remove_player_from_range(body)


func _on_interact_area_entered(area: Area2D) -> void:
	try_set_player_in_range(area)

	if area.get_parent() != null:
		try_set_player_in_range(area.get_parent())


func _on_interact_area_exited(area: Area2D) -> void:
	try_remove_player_from_range(area)

	if area.get_parent() != null:
		try_remove_player_from_range(area.get_parent())


func try_set_player_in_range(target: Node) -> void:
	var detected_player := find_player_from_node(target)

	if detected_player == null:
		return

	players_near[detected_player.get_instance_id()] = detected_player
	player_in_interact_range = !players_near.is_empty()
	player = detected_player

	if talk_indicator != null and current_state == MimicState.CHEST:
		talk_indicator.visible = true


func try_remove_player_from_range(target: Node) -> void:
	var detected_player := find_player_from_node(target)

	if detected_player == null:
		return

	var id := detected_player.get_instance_id()

	if players_near.has(id):
		players_near.erase(id)

	player_in_interact_range = !players_near.is_empty()

	if player == detected_player:
		player = get_any_near_player()

	if !player_in_interact_range and talk_indicator != null:
		talk_indicator.visible = false


func _on_vision_body_entered(body: Node2D) -> void:
	if current_state == MimicState.CHEST:
		return

	if current_state == MimicState.TRANSFORM:
		return

	var detected_player := find_player_from_node(body)

	if detected_player == null:
		return

	player = detected_player

	if current_state == MimicState.PATROL or current_state == MimicState.IDLE:
		change_state(MimicState.CHASE)


func _on_vision_area_entered(area: Area2D) -> void:
	if current_state == MimicState.CHEST:
		return

	if current_state == MimicState.TRANSFORM:
		return

	var detected_player := find_player_from_node(area)

	if detected_player == null and area.get_parent() != null:
		detected_player = find_player_from_node(area.get_parent())

	if detected_player == null:
		return

	player = detected_player

	if current_state == MimicState.PATROL or current_state == MimicState.IDLE:
		change_state(MimicState.CHASE)


func _on_hit_box_area_entered(area: Area2D) -> void:
	var damage_amount: int = 1
	var possible_damage = area.get("damage")

	if possible_damage != null:
		damage_amount = int(possible_damage)

	var attacker_position: Vector2 = Vector2.ZERO
	var attacker_player := find_player_from_node(area)

	if attacker_player == null and area.get_parent() != null:
		attacker_player = find_player_from_node(area.get_parent())

	if attacker_player != null:
		player = attacker_player
		attacker_position = attacker_player.global_position
	elif PlayerManager.player != null:
		attacker_position = PlayerManager.player.global_position

	take_damage(damage_amount, attacker_position)

func _on_hit_box_damaged(arg1 = null, arg2 = null, arg3 = null) -> void:
	var damage_amount: int = 1
	var attacker_position: Vector2 = Vector2.ZERO
	var attacker: Node = null

	if typeof(arg1) == TYPE_INT or typeof(arg1) == TYPE_FLOAT:
		damage_amount = int(arg1)
	elif arg1 is Node:
		attacker = arg1

	if arg2 is Vector2:
		attacker_position = arg2
	elif arg2 is Node:
		attacker = arg2

	if arg3 is Node:
		attacker = arg3

	if attacker != null:
		var attacker_player := find_player_from_node(attacker)

		if attacker_player != null:
			player = attacker_player
			attacker_position = attacker_player.global_position
		elif attacker is Node2D:
			attacker_position = attacker.global_position

	if attacker_position == Vector2.ZERO and PlayerManager.player != null:
		attacker_position = PlayerManager.player.global_position

	take_damage(damage_amount, attacker_position)


func _on_attack_hurt_box_body_entered(body: Node2D) -> void:
	try_hit_player(body)


func _on_attack_hurt_box_area_entered(area: Area2D) -> void:
	try_hit_player(area)


func find_player_from_node(node: Node) -> Player:
	var current := node

	while current != null:
		if current is Player:
			return current as Player

		if current.is_in_group("players"):
			return current as Player

		if current.is_in_group("player"):
			return current as Player

		if current.is_in_group("Player"):
			return current as Player

		if current.name == "Player":
			return current as Player

		if current.name == "Player2":
			return current as Player

		current = current.get_parent()

	if node != null and node.owner != null:
		var owner_node: Node = node.owner

		if owner_node is Player:
			return owner_node as Player

		if owner_node.is_in_group("players"):
			return owner_node as Player

		if owner_node.is_in_group("player"):
			return owner_node as Player

		if owner_node.is_in_group("Player"):
			return owner_node as Player

		if owner_node.name == "Player":
			return owner_node as Player

		if owner_node.name == "Player2":
			return owner_node as Player

	return null


func play_walk_sound() -> void:
	if walk_sound == null:
		return

	if walk_sound.stream == null:
		return

	if current_state != MimicState.PATROL and current_state != MimicState.CHASE:
		return

	if not is_on_floor():
		return

	if absf(velocity.x) < 5.0:
		return

	walk_sound.stop()
	walk_sound.volume_db = walk_volume_db
	walk_sound.play()


func play_attack_sound() -> void:
	if attack_sound == null:
		return

	if attack_sound.stream == null:
		return

	if current_state != MimicState.ATTACK:
		return

	attack_sound.stop()
	attack_sound.volume_db = attack_volume_db
	attack_sound.play()


func play_open_sound() -> void:
	if open_sound == null:
		return

	if open_sound.stream == null:
		return

	open_sound.stop()
	open_sound.volume_db = open_volume_db
	open_sound.play()
func play_hurt_sound() -> void:
	if hurt_sound == null:
		return

	if hurt_sound.stream == null:
		return

	hurt_sound.stop()
	hurt_sound.volume_db = hurt_volume_db
	hurt_sound.play()
func is_targeting_player() -> bool:
	if is_dead:
		return false

	if player == null:
		return false

	if not is_instance_valid(player):
		return false

	if player is Player:
		return true

	return false
func get_any_near_player() -> Player:
	for key in players_near.keys():
		var p: Player = players_near[key]

		if p != null and is_instance_valid(p):
			return p

	return null
func get_player_pressed_interact_event(event: InputEvent) -> Player:
	for key in players_near.keys():
		var p: Player = players_near[key]

		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_method("is_interact_event_pressed"):
			if p.is_interact_event_pressed(event):
				return p
		else:
			var action_name := get_interact_action_for_player(p)

			if event.is_action_pressed(action_name):
				return p

	return null


func get_interact_action_for_player(target_player: Player) -> StringName:
	if !is_two_player_mode():
		return &"interact"

	var id_value: int = int(target_player.get("player_id"))

	if id_value == 1:
		return &"p1_interact"

	return &"p2_interact"


func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()
