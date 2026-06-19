class_name SlimeBoss
extends CharacterBody2D

signal enemy_died(death_position: Vector2)
signal slime_boss_detected_player
enum BossState {
	IDLE,
	CHASE,
	RETREAT,
	ATTACK,
	HURT,
	DIE
}

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var hit_box: Area2D = $HitBox
@onready var attack_hurt_box: Area2D = $AttackHurtBox
@onready var attack_hurt_box_collision: CollisionShape2D = $AttackHurtBox/CollisionShape2D
@onready var vision_area: Area2D = $VisionArea

@onready var attack_sound: AudioStreamPlayer2D = $Audio/Attack
@onready var footstep_sound: AudioStreamPlayer2D = $Audio/Footstep
@onready var hurt_sound: AudioStreamPlayer2D = $Audio/Hurt
@onready var enemy_health_bar: Node2D = get_node_or_null("EnemyHealthBar") as Node2D
@onready var die_sound: AudioStreamPlayer2D = $Audio/Die
@onready var die_sound_2: AudioStreamPlayer2D = $Audio/Die2
const GRAVITY: float = 1000.0

@export var max_health: int = 30
@export var damage: int = 1
@export var exp_reward: int = 10
@export var chase_give_up_time: float = 8.0
@export var chase_give_up_cooldown_time: float = 2.5
@export var base_chase_speed: float = 70.0
@export var retreat_speed: float = 90.0
@export var max_retreat_time: float = 0.55
@export var retreat_cooldown_time: float = 1.2
@export var force_attack_when_cornered: bool = true
@export var attack_min_x_distance: float = 90.0
@export var attack_max_x_distance: float = 190.0
@export var too_close_x_distance: float = 75.0
@export var retreat_finish_x_distance: float = 120.0

@export var attack_cooldown_time: float = 1.0
@export var attack_hit_min_x_distance: float = 20.0
@export var attack_hit_max_x_distance: float = 230.0
@export var attack_hit_y_tolerance: float = 130.0
@export var hurt_time: float = 0.35
@export var knockback_force_x: float = 130.0
@export var knockback_force_y: float = -90.0

@export var normal_hurt_stun_cooldown_time: float = 1.2
@export var attack_interrupt_cooldown_time: float = 0.7

@export var max_attack_interrupts_before_resist: int = 2

@export var speed_multiplier_above_75: float = 1.0
@export var speed_multiplier_below_75: float = 1.35
@export var speed_multiplier_below_50: float = 1.55
@export var speed_multiplier_below_25: float = 1.8
@export var attack_anim_speed_above_75: float = 1.0
@export var attack_anim_speed_below_75: float = 1.15
@export var attack_anim_speed_below_50: float = 1.3
@export var attack_anim_speed_below_25: float = 1.4
@export var attack_volume_db: float = 4.0
@export var footstep_volume_db: float = 2.0
@export var hurt_volume_db: float = 4.0

@export var body_half_width_fallback: float = 28.0
@export var player_half_width_fallback: float = 10.0
@export var boss_defeated_flag_name: String = "slime_boss_killed"
@export var die_volume_db: float = -5.0
@export var die_2_volume_db: float = 10
var current_state: BossState = BossState.IDLE
var current_health: int = 0

var player: Player = null
var facing_direction: int = 1

var is_dead: bool = false
var is_attack_active: bool = false
var hit_players_this_attack: Dictionary = {}
var has_given_exp: bool = false

var attack_cooldown_timer: float = 0.0
var hurt_timer: float = 0.0
var normal_hurt_stun_cooldown_timer: float = 0.0
var attack_interrupt_cooldown_timer: float = 0.0
var retreat_timer: float = 0.0
var retreat_cooldown_timer: float = 0.0
var attack_interrupt_count: int = 0
var current_speed_multiplier: float = 1.0

var vision_base_scale: Vector2 = Vector2.ONE
var attack_base_scale: Vector2 = Vector2.ONE
var chase_without_attack_timer: float = 0.0
var chase_give_up_cooldown_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	current_health = max_health
	current_speed_multiplier = speed_multiplier_above_75
	setup_enemy_health_bar()
	

	if vision_area != null:
		vision_base_scale = vision_area.scale

	if attack_hurt_box != null:
		attack_base_scale = attack_hurt_box.scale

	stop_attack_hurt_box()
	setup_audio_players()
	connect_signals()

	change_state(BossState.IDLE)


func connect_signals() -> void:
	if hit_box != null:
		if hit_box.has_signal("Damaged"):
			var damaged_callable := Callable(self, "_on_hit_box_damaged")

			if not hit_box.is_connected("Damaged", damaged_callable):
				hit_box.connect("Damaged", damaged_callable)
		else:
			if not hit_box.area_entered.is_connected(_on_hit_box_area_entered):
				hit_box.area_entered.connect(_on_hit_box_area_entered)

	if vision_area != null:
		if not vision_area.body_entered.is_connected(_on_vision_area_body_entered):
			vision_area.body_entered.connect(_on_vision_area_body_entered)

		if not vision_area.area_entered.is_connected(_on_vision_area_area_entered):
			vision_area.area_entered.connect(_on_vision_area_area_entered)

	if attack_hurt_box != null:
		if not attack_hurt_box.body_entered.is_connected(_on_attack_hurt_box_body_entered):
			attack_hurt_box.body_entered.connect(_on_attack_hurt_box_body_entered)

		if not attack_hurt_box.area_entered.is_connected(_on_attack_hurt_box_area_entered):
			attack_hurt_box.area_entered.connect(_on_attack_hurt_box_area_entered)

	if animation_player != null:
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	update_timers(delta)

	if is_dead:
		apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		move_and_slide()
		return

	apply_gravity(delta)

	match current_state:
		BossState.IDLE:
			process_idle(delta)

		BossState.CHASE:
			process_chase(delta)

		BossState.RETREAT:
			process_retreat(delta)

		BossState.ATTACK:
			process_attack(delta)

		BossState.HURT:
			process_hurt(delta)

		BossState.DIE:
			process_die(delta)

	move_and_slide()


func update_timers(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer < 0.0:
			attack_cooldown_timer = 0.0

	if normal_hurt_stun_cooldown_timer > 0.0:
		normal_hurt_stun_cooldown_timer -= delta
		if normal_hurt_stun_cooldown_timer < 0.0:
			normal_hurt_stun_cooldown_timer = 0.0

	if attack_interrupt_cooldown_timer > 0.0:
		attack_interrupt_cooldown_timer -= delta
		if attack_interrupt_cooldown_timer < 0.0:
			attack_interrupt_cooldown_timer = 0.0

	if retreat_cooldown_timer > 0.0:
		retreat_cooldown_timer -= delta
		if retreat_cooldown_timer < 0.0:
			retreat_cooldown_timer = 0.0
	if chase_give_up_cooldown_timer > 0.0:
		chase_give_up_cooldown_timer -= delta
		if chase_give_up_cooldown_timer < 0.0:
			chase_give_up_cooldown_timer = 0.0

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0


func process_idle(_delta: float) -> void:
	velocity.x = 0.0

	if chase_give_up_cooldown_timer <= 0.0:
		if find_valid_player_in_vision():
			change_state(BossState.CHASE)
			return

	play_animation("idle")


func process_chase(delta: float) -> void:
	if not has_valid_player():
		player = null
		velocity.x = 0.0

		if not find_valid_player_in_vision():
			change_state(BossState.IDLE)
			return

	update_direction_to_player()

	var x_distance: float = get_x_distance_to_player()
	if update_chase_give_up_timer(delta, x_distance):
		return
	if x_distance < too_close_x_distance:
		if retreat_cooldown_timer <= 0.0:
			change_state(BossState.RETREAT)
			return

		velocity.x = 0.0

		if attack_cooldown_timer <= 0.0:
			change_state(BossState.ATTACK)
			return

		play_animation("idle")
		return

	if x_distance >= attack_min_x_distance and x_distance <= attack_max_x_distance:
		velocity.x = 0.0

		if attack_cooldown_timer <= 0.0:
			change_state(BossState.ATTACK)
			return

		play_animation("idle")
		return

	if x_distance > attack_max_x_distance:
		move_toward_player()
		play_animation("walk")
		return

	velocity.x = 0.0
	play_animation("idle")

func process_retreat(delta: float) -> void:
	if not has_valid_player():
		change_state(BossState.IDLE)
		return

	retreat_timer -= delta

	var x_distance: float = get_x_distance_to_player()

	if x_distance >= retreat_finish_x_distance:
		finish_retreat_and_attack()
		return

	if retreat_timer <= 0.0:
		if force_attack_when_cornered:
			finish_retreat_and_attack()
		else:
			change_state(BossState.CHASE)
		return

	move_away_from_player_with_back_turned()
	play_animation("walk")

func process_attack(_delta: float) -> void:
	velocity.x = 0.0


func process_hurt(delta: float) -> void:
	hurt_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)

	if hurt_timer <= 0.0:
		if has_valid_player():
			change_state(BossState.CHASE)
		else:
			change_state(BossState.IDLE)


func process_die(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)


func change_state(new_state: BossState) -> void:
	if current_state == BossState.DIE:
		return

	if current_state == new_state:
		return

	var old_state: BossState = current_state

	if current_state == BossState.ATTACK and new_state != BossState.ATTACK:
		if animation_player != null:
			animation_player.speed_scale = 1.0
	stop_attack_hurt_box()

	current_state = new_state

	if old_state == BossState.IDLE and new_state == BossState.CHASE:
		slime_boss_detected_player.emit()

	match current_state:
		BossState.IDLE:
			velocity.x = 0.0
			play_animation("idle")

		BossState.CHASE:
			play_animation("walk")

		BossState.RETREAT:
			start_retreat()

		BossState.ATTACK:
			start_attack()

		BossState.HURT:
			start_hurt()

		BossState.DIE:
			start_die()


func start_attack() -> void:
	print("SLIME BOSS START ATTACK")
	chase_without_attack_timer = 0.0
	velocity.x = 0.0

	update_direction_to_player()

	stop_attack_hurt_box()
	play_animation("attack", true)


func start_hurt() -> void:
	hurt_timer = hurt_time
	stop_attack_hurt_box()

	play_hurt_sound()
	play_animation("hurt", true)


func start_die() -> void:
	is_dead = true
	current_state = BossState.DIE

	velocity = Vector2.ZERO
	stop_attack_hurt_box()

	if body_collision != null:
		body_collision.set_deferred("disabled", true)

	if hit_box != null:
		hit_box.set_deferred("monitoring", false)
		hit_box.set_deferred("monitorable", false)

	if vision_area != null:
		vision_area.set_deferred("monitoring", false)
		vision_area.set_deferred("monitorable", false)

	if attack_hurt_box != null:
		attack_hurt_box.set_deferred("monitoring", false)
		attack_hurt_box.set_deferred("monitorable", false)

	if attack_hurt_box_collision != null:
		attack_hurt_box_collision.set_deferred("disabled", true)
	if boss_defeated_flag_name != "":
		LevelManager.set_game_flag(boss_defeated_flag_name, true)

	play_die_sounds()

	give_exp_reward()
	enemy_died.emit(global_position)

	play_animation("die", true)


# =========================
# ATTACK HITBOX
# =========================

func start_attack_hurt_box() -> void:
	if current_state != BossState.ATTACK:
		return

	if is_dead:
		return

	print("SLIME BOSS START ATTACK HIT CHECK")

	is_attack_active = true
	hit_players_this_attack.clear()

	if attack_hurt_box_collision != null:
		attack_hurt_box_collision.set_deferred("disabled", false)

	if attack_hurt_box != null:
		attack_hurt_box.set_deferred("monitoring", true)
		attack_hurt_box.set_deferred("monitorable", true)

	await get_tree().physics_frame
	await get_tree().physics_frame

	if current_state != BossState.ATTACK:
		return

	if is_dead:
		return

	if attack_hurt_box == null:
		return

	for body in attack_hurt_box.get_overlapping_bodies():
		try_hit_player(body)

	for area in attack_hurt_box.get_overlapping_areas():
		try_hit_player(area)

		if area.get_parent() != null:
			try_hit_player(area.get_parent())

	try_hit_player_by_attack_range()

func stop_attack_hurt_box() -> void:
	is_attack_active = false
	hit_players_this_attack.clear()

	if attack_hurt_box != null:
		attack_hurt_box.set_deferred("monitoring", false)
		attack_hurt_box.set_deferred("monitorable", false)

	if attack_hurt_box_collision != null:
		attack_hurt_box_collision.set_deferred("disabled", true)

func try_hit_player(target: Node) -> void:
	if not is_attack_active:
		return

	var detected_player: Player = find_player_from_node(target)

	if detected_player == null:
		return

	if !is_instance_valid(detected_player):
		return

	if has_object_property(detected_player, "is_dead") and bool(detected_player.get("is_dead")):
		return

	var id: int = detected_player.get_instance_id()

	if hit_players_this_attack.has(id):
		return

	hit_players_this_attack[id] = true

	print("SLIME BOSS HIT PLAYER: ", detected_player.name)

	if detected_player.has_method("take_damage"):
		detected_player.take_damage(damage, global_position)
	elif detected_player.has_method("die"):
		detected_player.die(global_position)

# =========================
# DAMAGE / STUN
# =========================

func take_damage(amount: int = 1, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	chase_without_attack_timer = 0.0
	chase_give_up_cooldown_timer = 0.0
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)

	print("SlimeBoss HP: ", current_health, "/", max_health)
	show_enemy_health_bar()
	update_speed_by_health()

	if current_health <= 0:
		change_state(BossState.DIE)
		return

	remember_player_from_attack(attacker_position)

	if attacker_position != Vector2.ZERO:
		face_position(attacker_position)

	if current_state == BossState.ATTACK:
		handle_damage_while_attacking(attacker_position)
		return

	if normal_hurt_stun_cooldown_timer > 0.0:
		play_hurt_sound()
		print("Boss nhận damage nhưng không bị choáng do đang hồi stun thường.")
		return

	normal_hurt_stun_cooldown_timer = normal_hurt_stun_cooldown_time
	apply_knockback(attacker_position)
	change_state(BossState.HURT)


func handle_damage_while_attacking(attacker_position: Vector2) -> void:
	play_hurt_sound()

	if attack_interrupt_cooldown_timer > 0.0:
		print("Boss đang attack, nhận damage nhưng không bị ngắt do cooldown.")
		return

	attack_interrupt_cooldown_timer = attack_interrupt_cooldown_time

	if attack_interrupt_count < max_attack_interrupts_before_resist:
		attack_interrupt_count += 1
		print("Boss bị ngắt attack lần: ", attack_interrupt_count)
		apply_knockback(attacker_position)
		change_state(BossState.HURT)
		return

	print("Boss kháng ngắt chiêu attack lần này.")
	attack_interrupt_count = 0


func apply_knockback(attacker_position: Vector2 = Vector2.ZERO) -> void:
	if attacker_position == Vector2.ZERO:
		velocity.x = -float(facing_direction) * knockback_force_x
		velocity.y = knockback_force_y
		return

	var knockback_direction: float = 1.0

	if global_position.x < attacker_position.x:
		knockback_direction = -1.0
	else:
		knockback_direction = 1.0

	velocity.x = knockback_direction * knockback_force_x
	velocity.y = knockback_force_y


func update_speed_by_health() -> void:
	var health_ratio: float = float(current_health) / float(max_health)

	var new_multiplier: float = speed_multiplier_above_75

	if health_ratio <= 0.25:
		new_multiplier = speed_multiplier_below_25
	elif health_ratio <= 0.50:
		new_multiplier = speed_multiplier_below_50
	elif health_ratio <= 0.75:
		new_multiplier = speed_multiplier_below_75

	if new_multiplier != current_speed_multiplier:
		current_speed_multiplier = new_multiplier
		print("Boss tăng tốc. Multiplier = ", current_speed_multiplier)


func get_current_chase_speed() -> float:
	return base_chase_speed * current_speed_multiplier


# =========================
# SIGNALS
# =========================

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
	elif PlayerManager.player != null and PlayerManager.player is Node2D:
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


func _on_vision_area_body_entered(body: Node2D) -> void:
	var detected_player: Player = find_player_from_node(body)

	if !is_alive_player(detected_player):
		return

	player = detected_player

	if current_state == BossState.IDLE:
		change_state(BossState.CHASE)


func _on_vision_area_area_entered(area: Area2D) -> void:
	var detected_player: Player = find_player_from_node(area)

	if detected_player == null and area.get_parent() != null:
		detected_player = find_player_from_node(area.get_parent())

	if !is_alive_player(detected_player):
		return

	player = detected_player

	if current_state == BossState.IDLE:
		change_state(BossState.CHASE)


func _on_attack_hurt_box_body_entered(body: Node2D) -> void:
	try_hit_player(body)


func _on_attack_hurt_box_area_entered(area: Area2D) -> void:
	try_hit_player(area)

	if area.get_parent() != null:
		try_hit_player(area.get_parent())


func _on_animation_finished(anim_name: StringName) -> void:
	if current_state == BossState.ATTACK:
		if String(anim_name).begins_with("attack"):
			stop_attack_hurt_box()
			animation_player.speed_scale = 1.0
			attack_cooldown_timer = attack_cooldown_time

			if has_valid_player():
				change_state(BossState.CHASE)
			else:
				change_state(BossState.IDLE)

			return

	if current_state == BossState.DIE:
		if String(anim_name).begins_with("die"):
			queue_free()
			return


# =========================
# PLAYER / DIRECTION
# =========================

func find_valid_player_in_vision() -> bool:
	if vision_area == null:
		return false
	if chase_give_up_cooldown_timer > 0.0:
		return false
	if !vision_area.monitoring:
		return false

	for body in vision_area.get_overlapping_bodies():
		var detected_player: Player = find_player_from_node(body)

		if !is_alive_player(detected_player):
			continue

		player = detected_player
		return true

	for area in vision_area.get_overlapping_areas():
		var detected_player: Player = find_player_from_node(area)

		if detected_player == null and area.get_parent() != null:
			detected_player = find_player_from_node(area.get_parent())

		if !is_alive_player(detected_player):
			continue

		player = detected_player
		return true

	return false


func has_valid_player() -> bool:
	return is_alive_player(player)

func has_object_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == prop_name:
			return true

	return false
func remember_player_from_attack(attacker_position: Vector2 = Vector2.ZERO) -> void:
	if attacker_position != Vector2.ZERO:
		var nearest_player := find_nearest_player_to_position(attacker_position)

		if nearest_player != null:
			player = nearest_player

	if attacker_position != Vector2.ZERO:
		face_position(attacker_position)
	elif has_valid_player():
		update_direction_to_player()

func find_nearest_player_to_position(target_position: Vector2) -> Player:
	var nearest_player: Player = null
	var nearest_distance: float = 999999.0

	for p in get_all_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if has_object_property(p, "is_dead") and bool(p.get("is_dead")):
			continue

		var distance: float = p.global_position.distance_to(target_position)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_player = p

	return nearest_player


func get_all_players() -> Array[Player]:
	var result: Array[Player] = []
	var added_ids: Dictionary = {}

	var groups_to_check: Array[String] = [
		"players",
		"player",
		"Player"
	]

	for group_name in groups_to_check:
		for node in get_tree().get_nodes_in_group(group_name):
			var detected_player := find_player_from_node(node)

			if detected_player == null:
				continue

			if !is_instance_valid(detected_player):
				continue

			var id: int = detected_player.get_instance_id()

			if added_ids.has(id):
				continue

			added_ids[id] = true
			result.append(detected_player)

	var player_1_node := get_tree().root.find_child("Player", true, false)
	var player_2_node := get_tree().root.find_child("Player2", true, false)

	for node in [player_1_node, player_2_node]:
		var detected_player := find_player_from_node(node)

		if detected_player == null:
			continue

		if !is_instance_valid(detected_player):
			continue

		var id: int = detected_player.get_instance_id()

		if added_ids.has(id):
			continue

		added_ids[id] = true
		result.append(detected_player)

	return result
func update_direction_to_player() -> void:
	if not has_valid_player():
		return

	if player.global_position.x < global_position.x:
		set_facing_direction(-1)
	else:
		set_facing_direction(1)


func face_position(target_position: Vector2) -> void:
	if target_position.x < global_position.x:
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
	if vision_area != null:
		vision_area.scale = Vector2(
			absf(vision_base_scale.x) * float(facing_direction),
			vision_base_scale.y
		)


func move_toward_player() -> void:
	if not has_valid_player():
		velocity.x = 0.0
		return

	update_direction_to_player()
	velocity.x = float(facing_direction) * get_current_chase_speed()


func move_away_from_player_with_back_turned() -> void:
	if not has_valid_player():
		velocity.x = 0.0
		return

	if player.global_position.x > global_position.x:
		set_facing_direction(-1)
		velocity.x = -retreat_speed
	else:
		set_facing_direction(1)
		velocity.x = retreat_speed


func find_player_from_node(node: Node) -> Player:
	var current: Node = node

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


# =========================
# DISTANCE
# =========================

func get_body_half_width() -> float:
	if body_collision == null:
		return body_half_width_fallback

	if body_collision.shape is RectangleShape2D:
		return body_collision.shape.size.x * 0.5

	if body_collision.shape is CapsuleShape2D:
		return body_collision.shape.radius

	if body_collision.shape is CircleShape2D:
		return body_collision.shape.radius

	return body_half_width_fallback


func get_player_half_width() -> float:
	if not has_valid_player():
		return player_half_width_fallback

	if player.has_method("get_body_half_width"):
		return player.get_body_half_width()

	return player_half_width_fallback


func get_edge_distance_to_player() -> float:
	if not has_valid_player():
		return 999999.0

	var center_distance: float = absf(player.global_position.x - global_position.x)
	var edge_distance: float = center_distance - get_body_half_width() - get_player_half_width()

	return maxf(edge_distance, 0.0)


# =========================
# ANIMATION / SOUND
# =========================

func play_animation(base_name: String, force_restart: bool = false) -> void:
	var anim_name: String = base_name + "-" + get_direction_name()

	if animation_player == null:
		return

	if not animation_player.has_animation(anim_name):
		push_warning(name + " thiếu animation: " + anim_name)
		return

	if base_name == "attack":
		animation_player.speed_scale = get_current_attack_animation_speed()
	else:
		animation_player.speed_scale = 1.0

	if animation_player.current_animation == anim_name and not force_restart:
		return

	animation_player.play(anim_name)


func get_direction_name() -> String:
	if facing_direction < 0:
		return "left"

	return "right"


func play_attack_sound() -> void:
	if attack_sound == null:
		return

	attack_sound.stop()
	attack_sound.volume_db = attack_volume_db
	attack_sound.play()


func play_walk_sound() -> void:
	if footstep_sound == null:
		return

	if current_state != BossState.CHASE and current_state != BossState.RETREAT:
		return

	if absf(velocity.x) < 5.0:
		return

	if not is_on_floor():
		return

	footstep_sound.stop()
	footstep_sound.volume_db = footstep_volume_db
	footstep_sound.pitch_scale = randf_range(0.9, 1.05)
	footstep_sound.play()


func play_hurt_sound() -> void:
	if hurt_sound == null:
		return

	hurt_sound.stop()
	hurt_sound.volume_db = hurt_volume_db
	hurt_sound.play()


func setup_audio_players() -> void:
	setup_one_audio_player(attack_sound)
	setup_one_audio_player(footstep_sound)
	setup_one_audio_player(hurt_sound)
	setup_one_audio_player(die_sound)
	setup_one_audio_player(die_sound_2)


func setup_one_audio_player(sound: AudioStreamPlayer2D) -> void:
	if sound == null:
		return

	sound.stop()
	sound.autoplay = false
	sound.stream_paused = false
	sound.max_distance = 10000.0
	sound.attenuation = 0.0


func give_exp_reward() -> void:
	if has_given_exp:
		return

	has_given_exp = true

	if PlayerManager.player != null and PlayerManager.player.has_method("gain_exp"):
		PlayerManager.player.gain_exp(exp_reward)
func get_x_distance_to_player() -> float:
	if not has_valid_player():
		return 999999.0

	return absf(player.global_position.x - global_position.x)
func try_hit_player_by_attack_range() -> void:
	if not is_attack_active:
		return

	for target_player in get_all_players():
		if target_player == null:
			continue

		if !is_instance_valid(target_player):
			continue

		if has_object_property(target_player, "is_dead") and bool(target_player.get("is_dead")):
			continue

		if !is_specific_player_in_attack_range(target_player):
			continue

		var id: int = target_player.get_instance_id()

		if hit_players_this_attack.has(id):
			continue

		hit_players_this_attack[id] = true

		print("SLIME BOSS RANGE HIT PLAYER: ", target_player.name)

		if target_player.has_method("take_damage"):
			target_player.take_damage(damage, global_position)
		elif target_player.has_method("die"):
			target_player.die(global_position)
func find_player_in_attack_range() -> Player:
	for p in get_all_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if has_object_property(p, "is_dead") and bool(p.get("is_dead")):
			continue

		if is_specific_player_in_attack_range(p):
			return p

	return null


func is_specific_player_in_attack_range(target_player: Player) -> bool:
	if target_player == null:
		return false

	var signed_x_distance: float = target_player.global_position.x - global_position.x
	var x_distance: float = absf(signed_x_distance)
	var y_distance: float = absf(target_player.global_position.y - global_position.y)

	if facing_direction > 0 and signed_x_distance < 0.0:
		return false

	if facing_direction < 0 and signed_x_distance > 0.0:
		return false

	if x_distance < attack_hit_min_x_distance:
		return false

	if x_distance > attack_hit_max_x_distance:
		return false

	if y_distance > attack_hit_y_tolerance:
		return false

	return true
func start_retreat() -> void:
	retreat_timer = max_retreat_time
	move_away_from_player_with_back_turned()
	play_animation("walk")
func finish_retreat_and_attack() -> void:
	velocity.x = 0.0
	retreat_cooldown_timer = retreat_cooldown_time

	update_direction_to_player()

	if attack_cooldown_timer <= 0.0:
		change_state(BossState.ATTACK)
		return

	change_state(BossState.CHASE)
func setup_enemy_health_bar() -> void:
	if enemy_health_bar == null:
		push_warning("SlimeBoss: Không tìm thấy EnemyHealthBar.")
		return

	if enemy_health_bar.has_method("set_health"):
		enemy_health_bar.set_health(current_health, max_health)

	enemy_health_bar.visible = false
func show_enemy_health_bar() -> void:
	if enemy_health_bar == null:
		push_warning("SlimeBoss: Không tìm thấy EnemyHealthBar để hiển thị.")
		return

	if enemy_health_bar.has_method("show_damage_health"):
		enemy_health_bar.show_damage_health(current_health, max_health)
		return

	if enemy_health_bar.has_method("set_health"):
		enemy_health_bar.set_health(current_health, max_health)

	enemy_health_bar.visible = true
func get_current_attack_animation_speed() -> float:
	var health_ratio: float = float(current_health) / float(max_health)

	if health_ratio <= 0.25:
		return attack_anim_speed_below_25

	if health_ratio <= 0.50:
		return attack_anim_speed_below_50

	if health_ratio <= 0.75:
		return attack_anim_speed_below_75

	return attack_anim_speed_above_75
func play_die_sounds() -> void:
	if die_sound != null:
		die_sound.stop()
		die_sound.volume_db = die_volume_db
		die_sound.play()

	if die_sound_2 != null:
		die_sound_2.stop()
		die_sound_2.volume_db = die_2_volume_db
		die_sound_2.play()
func is_alive_player(target_player: Player) -> bool:
	if target_player == null:
		return false

	if !is_instance_valid(target_player):
		return false

	if has_object_property(target_player, "is_dead"):
		if bool(target_player.get("is_dead")):
			return false

	return true
func update_chase_give_up_timer(delta: float, x_distance: float) -> bool:
	if chase_give_up_time <= 0.0:
		return false

	if x_distance > attack_max_x_distance:
		chase_without_attack_timer += delta
	else:
		chase_without_attack_timer = 0.0

	if chase_without_attack_timer >= chase_give_up_time:
		give_up_chase()
		return true

	return false


func give_up_chase() -> void:
	print("SLIME BOSS GIVE UP CHASE")

	chase_without_attack_timer = 0.0
	chase_give_up_cooldown_timer = chase_give_up_cooldown_time

	player = null
	velocity.x = 0.0

	stop_attack_hurt_box()

	if current_state != BossState.DIE:
		change_state(BossState.IDLE)
