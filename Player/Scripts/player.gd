class_name Player
extends CharacterBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var potion_use_sound: AudioStreamPlayer2D = get_node_or_null("Audio/PotionUse") as AudioStreamPlayer2D
@onready var attack_sound: AudioStreamPlayer2D = $Audio/Attack
@onready var footstep_sound: AudioStreamPlayer2D = $Audio/Footstep
@onready var jump_sound: AudioStreamPlayer2D = $Audio/Jump
@onready var land_sound: AudioStreamPlayer2D = $Audio/Land
@onready var bow_shoot_sound: AudioStreamPlayer2D = get_node_or_null("Audio/BowShoot") as AudioStreamPlayer2D
@onready var interactions: Node2D = $Interactions
@onready var hurt_box: HurtBox = $Interactions/AttackHurtBox
@onready var hurt_box_collision: CollisionShape2D = $Interactions/AttackHurtBox/CollisionShape2D
@onready var arrow_spawn_point: Marker2D = get_node_or_null("ArrowSpawnPoint") as Marker2D
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var audio_listener_2d: AudioListener2D = get_node_or_null("AudioListener2D") as AudioListener2D
var camera_2d: Camera2D = null
const GRAVITY: float = 1000.0
const WITCHER_BUFF_DURATION: float = 15.0
const WITCHER_STRENGTH_DAMAGE_MULTIPLIER: float = 1.5
const WITCHER_DEFENSE_DAMAGE_MULTIPLIER: float = 0.5
const WITCHER_SPEED_MULTIPLIER: float = 1.4
@export var arrow_scene: PackedScene
@export var arrow_damage: int = 1
@export var max_level: int = 7
@export var base_exp_to_next: int = 10
@export var exp_growth: float = 1.4
@export var hurt_time: float = 0.35
@export var hurt_knockback_x: float = 180.0
@export var hurt_knockback_y: float = -120.0
@export var hurt_animation_base: String = "falling"
@export var max_horizontal_speed: float = 135
@export var slow_down_speed: float = 800.0
@export var jump_force: float = -430.0
@export var max_jump_horizontal_speed: float = 145
@export var max_health_units: int = 2
@export var left_map_padding: float = 0.0
@export var right_map_padding: float = 0.0
@export var player_id: int = 1
@export var coop_screen_margin_x: float = 32.0
@export var show_player_marker_in_coop: bool = true
@export var player_marker_offset: Vector2 = Vector2(8, -40)
@export var player_1_marker_texture: Texture2D
@export var player_2_marker_texture: Texture2D
@export var player_marker_scale: Vector2 = Vector2(1.0, 1.0)
@export var player_1_texture: Texture2D
@export var player_2_texture: Texture2D
var is_shooting_arrow: bool = false
var witcher_strength_time_left: float = 0.0
var witcher_defense_time_left: float = 0.0
var witcher_speed_time_left: float = 0.0
var witcher_defense_damage_buffer: float = 0.0
var base_max_horizontal_speed_for_witcher_buff: float = -1.0
var base_max_jump_horizontal_speed_for_witcher_buff: float = -1.0
var can_control: bool = true
var facing_direction: int = 1
var direction_vector: Vector2 = Vector2.RIGHT
var attack_cooldown: bool = false
var current_base_animation: String = ""
var was_on_floor: bool = false
var is_dead: bool = false
var current_health_units: int = 2
var coin_count: int = 0
var potion_count: int = 0
var arrow_spawned_this_shot: bool = false
var strength_potion_count: int = 0
var defense_potion_count: int = 0
var speed_potion_count: int = 0

var selected_item_id: String = "health_potion"
var has_seen_use_item_tip: bool = false
var has_seen_item_switch_tip: bool = false

var is_using_potion: bool = false
var has_seen_potion_tip: bool = false
var has_unlocked_item_slot: bool = false
const INVENTORY_ITEM_IDS := [
	"health_potion",
	"strength_potion",
	"defense_potion",
	"speed_potion"
]

var is_hurt: bool = false
var hurt_timer: float = 0.0
var level: int = 1
var current_exp: int = 0
var exp_to_next: int = 10
var weapon_bonus_attack: int = 0
var player_marker_root: Node2D = null
signal DirectionChanged(new_direction: Vector2)
signal died
signal health_changed(current_health: int, max_health: int, old_health: int)
signal coin_changed(coin_count: int)
signal exp_changed(current_exp: int, exp_to_next: int, level: int)
signal level_changed(level: int, max_health: int)
signal potion_changed(potion_count: int)
signal item_inventory_changed
func _ready() -> void:
	if !is_coop_mode() and player_id != 1:
		queue_free()
		return

	apply_player_skin()

	create_player_marker()
	call_deferred("setup_camera_and_audio_listener")


	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(50.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	apply_weapon_upgrade_bonus()
	setup_witcher_buff_base_stats()
	level = 1
	current_exp = 0
	exp_to_next = base_exp_to_next
	current_health_units = max_health_units

	stop_hurt_box()

	was_on_floor = is_on_floor()

	state_machine.Initialize(self)

	add_to_group("players")

	if !is_coop_mode() or player_id == 1:
		PlayerManager.register_player(self)

	call_deferred("refresh_after_restore")
	call_deferred("refresh_after_restore_delayed")

func setup_camera_and_audio_listener() -> void:
	camera_2d = get_node_or_null("Camera2D") as Camera2D

	if camera_2d != null:
		if is_coop_mode():
			camera_2d.enabled = false
		else:
			camera_2d.enabled = true
			camera_2d.make_current()
	else:
		push_warning("Player không tìm thấy Camera2D trong map này.")

	if audio_listener_2d != null:
		if !is_coop_mode() or player_id == 1:
			audio_listener_2d.make_current()
	else:
		push_warning("Player không tìm thấy AudioListener2D.")
func _physics_process(delta: float) -> void:
	if is_dead:
		apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, 100.0 * delta)
		move_and_slide()
		return
	update_witcher_buffs(delta)
	if is_hurt:
		hurt_timer -= delta

		if hurt_timer <= 0.0:
			finish_hurt()

	was_on_floor = is_on_floor()

	apply_gravity(delta)
	move_and_slide()
	clamp_to_tilemap_bounds()
	check_landing_sound()
func apply_gravity(delta: float) -> void:
	if !is_on_floor():
		velocity.y += GRAVITY * delta

func is_coop_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


func get_move_left_action() -> String:
	if !is_coop_mode():
		return "move_left"

	if player_id == 1:
		return "p1_move_left"

	return "p2_move_left"


func get_move_right_action() -> String:
	if !is_coop_mode():
		return "move_right"

	if player_id == 1:
		return "p1_move_right"

	return "p2_move_right"


func get_jump_action() -> String:
	if !is_coop_mode():
		return "jump"

	if player_id == 1:
		return "p1_jump"

	return "p2_jump"


func get_attack_action() -> String:
	if !is_coop_mode():
		return "attack"

	if player_id == 1:
		return "p1_attack"

	return "p2_attack"


func get_interact_action() -> String:
	if !is_coop_mode():
		return "interact"

	if player_id == 1:
		return "p1_interact"

	return "p2_interact"


func get_heal_action() -> String:
	if !is_coop_mode():
		return "use_potion"

	if player_id == 1:
		return "p1_heal"

	return "p2_heal"


func is_jump_just_pressed() -> bool:
	if !can_do_action():
		return false

	return Input.is_action_just_pressed(get_jump_action())


func is_attack_just_pressed() -> bool:
	if !can_do_action():
		return false

	return Input.is_action_just_pressed(get_attack_action())
func is_jump_event_pressed(event: InputEvent) -> bool:
	if !can_do_action():
		return false

	return event.is_action_pressed(get_jump_action())


func is_attack_event_pressed(event: InputEvent) -> bool:
	if !can_do_action():
		return false

	return event.is_action_pressed(get_attack_action())

func is_interact_just_pressed() -> bool:
	if !can_do_action():
		return false

	return Input.is_action_just_pressed(get_interact_action())
func input_movement() -> float:
	if SceneTransition.is_transitioning:
		return 0.0
	if is_dead:
		return 0.0

	if is_hurt:
		return 0.0

	if !can_control:
		return 0.0

	return Input.get_axis(get_move_left_action(), get_move_right_action())

func update_facing_direction(direction: float) -> void:
	if is_dead:
		return

	if direction == 0:
		return

	var new_direction: Vector2

	if direction < 0:
		facing_direction = -1
		new_direction = Vector2.LEFT
	else:
		facing_direction = 1
		new_direction = Vector2.RIGHT

	interactions.rotation_degrees = 0
	interactions.scale = Vector2.ONE

	if new_direction != direction_vector:
		direction_vector = new_direction
		DirectionChanged.emit(direction_vector)
func get_direction_name() -> String:
	if facing_direction < 0:
		return "left"
	else:
		return "right"


func update_animation(base_anim_name: String, keep_time: bool = true) -> void:
	if is_dead and base_anim_name != "die":
		return
	if is_hurt and base_anim_name != hurt_animation_base and base_anim_name != "die":
		return
	var anim_name := base_anim_name + "_" + get_direction_name()

	if !animation_player.has_animation(anim_name):
		push_warning("Không tìm thấy animation: " + anim_name)
		return

	var old_position: float = 0.0
	var same_base_animation := current_base_animation == base_anim_name

	if same_base_animation and keep_time:
		old_position = animation_player.current_animation_position

	if animation_player.current_animation == anim_name:
		return

	animation_player.play(anim_name)

	if same_base_animation and keep_time:
		var anim_length := animation_player.current_animation_length
		old_position = clamp(old_position, 0.0, anim_length)
		animation_player.seek(old_position, true)

	current_base_animation = base_anim_name

func reset_attack_hit_targets() -> void:
	hurt_box.reset_hit_targets()


func start_attack_hitbox() -> void:
	if is_dead:
		return

	print("START ATTACK HITBOX, animation = ", animation_player.current_animation)

	if hurt_box != null:
		hurt_box.set("damage", get_attack_damage())

	if hurt_box_collision != null:
		hurt_box_collision.set_deferred("disabled", false)

	if hurt_box != null:
		hurt_box.call_deferred("start_damage")

	await get_tree().physics_frame
	await get_tree().physics_frame

	if is_dead:
		return

	if hurt_box != null:
		hurt_box.check_overlapping_hitboxes()
func stop_hurt_box() -> void:
	if animation_player != null:
		print("STOP ATTACK HITBOX, animation = ", animation_player.current_animation)

	if hurt_box != null:
		hurt_box.call_deferred("stop_damage")

	if hurt_box_collision != null:
		hurt_box_collision.set_deferred("disabled", true)
func get_body_half_width() -> float:
	if body_collision == null:
		return 16.0

	if body_collision.shape is RectangleShape2D:
		return body_collision.shape.size.x * 0.5

	if body_collision.shape is CapsuleShape2D:
		return body_collision.shape.radius

	if body_collision.shape is CircleShape2D:
		return body_collision.shape.radius

	return 16.0


func clamp_to_tilemap_bounds() -> void:
	if !LevelManager.has_bounds():
		return

	var half_width := get_body_half_width()

	var left_limit := LevelManager.get_left_limit() + half_width + left_map_padding
	var right_limit := LevelManager.get_right_limit() - half_width - right_map_padding

	if global_position.x < left_limit:
		global_position.x = left_limit
		velocity.x = 0

	if global_position.x > right_limit:
		global_position.x = right_limit
		velocity.x = 0


func play_footstep_sound() -> void:
	if !is_on_floor():
		return

	if abs(velocity.x) < 10:
		return

	footstep_sound.pitch_scale = randf_range(0.7, 1.0)
	footstep_sound.play()


func play_jump_sound() -> void:
	jump_sound.pitch_scale = randf_range(0.95, 1.08)
	jump_sound.play()


func play_land_sound() -> void:
	land_sound.pitch_scale = randf_range(0.95, 1.08)
	land_sound.play()


func check_landing_sound() -> void:
	if !was_on_floor and is_on_floor():
		play_land_sound()
func set_control_enabled(value: bool) -> void:
	if is_dead:
		return

	can_control = value

	if !can_control:
		velocity.x = 0
		stop_hurt_box()
		update_animation("idle", false)
func die(attacker_position: Vector2 = Vector2.ZERO, force_single_die: bool = false) -> void:
	if is_dead:
		return

	if is_coop_mode() and !force_single_die:
		die_all_players(attacker_position)
		return

	var stats_player := get_shared_stats_player()

	if stats_player != null:
		var old_health: int = stats_player.current_health_units
		stats_player.current_health_units = 0
		stats_player.health_changed.emit(
			stats_player.current_health_units,
			stats_player.max_health_units,
			old_health
		)

	is_dead = true
	died.emit()
	can_control = false

	stop_hurt_box()

	var knockback_direction: float = 1.0

	if attacker_position != Vector2.ZERO:
		if global_position.x < attacker_position.x:
			knockback_direction = -1.0
		else:
			knockback_direction = 1.0
	else:
		knockback_direction = -float(facing_direction)

	velocity.x = knockback_direction * 400.0
	velocity.y = -260.0

	if knockback_direction < 0:
		if animation_player.has_animation("die_left"):
			animation_player.play("die_left")
		else:
			push_warning("Không tìm thấy animation die_left")
	else:
		if animation_player.has_animation("die_right"):
			animation_player.play("die_right")
		else:
			push_warning("Không tìm thấy animation die_right")
func get_death_direction_from_current_animation() -> int:
	var current_anim := animation_player.current_animation

	if current_anim.ends_with("_left"):
		return -1

	if current_anim.ends_with("_right"):
		return 1

	return facing_direction
func can_do_action() -> bool:
	if SceneTransition.is_transitioning:
		return false

	return can_control and !is_dead and !is_hurt and !is_shooting_arrow
func can_start_shoot_arrow() -> bool:
	if !can_do_action():
		return false

	if !is_on_floor():
		return false

	if !LevelManager.has_method("can_shoot_arrow"):
		return false

	if !LevelManager.can_shoot_arrow():
		return false

	if arrow_scene == null:
		push_warning(name + " chưa gán Arrow Scene.")
		return false

	return true
func take_damage(amount: int = 1, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	if is_hurt:
		return

	var final_amount := get_received_damage_after_witcher_defense(amount)

	if final_amount <= 0:
		return

	var stats_player := get_shared_stats_player()

	if stats_player != self:
		stats_player.take_shared_damage_only(final_amount)

		if stats_player.current_health_units <= 0:
			die_all_players(attacker_position)
			return

		start_hurt(attacker_position)
		return

	take_shared_damage_only(final_amount)

	if current_health_units <= 0:
		if is_coop_mode():
			die_all_players(attacker_position)
		else:
			die(attacker_position)
		return

	start_hurt(attacker_position)
func heal(amount: int = 1) -> void:
	var stats_player := get_shared_stats_player()

	if stats_player != self:
		stats_player.heal(amount)
		return

	if is_dead:
		return

	var old_health: int = current_health_units

	current_health_units += amount
	current_health_units = clamp(current_health_units, 0, max_health_units)

	health_changed.emit(current_health_units, max_health_units, old_health)

func add_coin(amount: int = 1) -> void:
	var stats_player := get_shared_stats_player()

	if stats_player != self:
		stats_player.add_coin(amount)
		return

	coin_count += amount
	coin_changed.emit(coin_count)
	print("Coin: ", coin_count)
func is_interact_event_pressed(event: InputEvent) -> bool:
	if !can_do_action():
		return false

	return event.is_action_pressed(get_interact_action())
func start_hurt(attacker_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	cancel_attack_state()

	is_hurt = true
	hurt_timer = hurt_time
	can_control = false

	var knockback_direction: float = 1.0

	if attacker_position != Vector2.ZERO:
		if global_position.x < attacker_position.x:
			knockback_direction = -1.0
		else:
			knockback_direction = 1.0
	else:
		knockback_direction = -float(facing_direction)

	velocity.x = knockback_direction * hurt_knockback_x
	velocity.y = hurt_knockback_y

	if knockback_direction < 0.0:
		facing_direction = -1
	else:
		facing_direction = 1

	update_animation(hurt_animation_base, false)
func gain_exp(amount: int) -> void:
	var stats_player := get_shared_stats_player()

	if stats_player != self:
		stats_player.gain_exp(amount)
		return
	if is_dead:
		return

	if amount <= 0:
		return

	if level >= max_level:
		current_exp = 0
		exp_changed.emit(current_exp, exp_to_next, level)
		return

	current_exp += amount

	while current_exp >= exp_to_next and level < max_level:
		current_exp -= exp_to_next
		level_up()

	if level >= max_level:
		current_exp = 0

	exp_changed.emit(current_exp, exp_to_next, level)


func level_up() -> void:
	var old_health: int = current_health_units

	level += 1

	max_health_units += 2

	current_health_units = max_health_units

	exp_to_next = int(ceil(float(exp_to_next) * exp_growth))

	health_changed.emit(current_health_units, max_health_units, old_health)
	level_changed.emit(level, max_health_units)

	print("LEVEL UP: ", level, " | Max HP: ", max_health_units, " | Next EXP: ", exp_to_next)
func cancel_attack_state() -> void:
	attack_cooldown = false
	current_base_animation = ""
	stop_hurt_box()


func finish_hurt() -> void:
	is_hurt = false
	can_control = true
	current_base_animation = ""
	attack_cooldown = false
	stop_hurt_box()
func apply_weapon_upgrade_bonus() -> void:
	weapon_bonus_attack = LevelManager.get_weapon_bonus_attack()


func get_attack_damage() -> int:
	var damage: int = max(1, 1 + weapon_bonus_attack)

	if witcher_strength_time_left > 0.0:
		damage = int(ceil(float(damage) * WITCHER_STRENGTH_DAMAGE_MULTIPLIER))

	return max(1, damage)
func _exit_tree() -> void:
	if PlayerManager.player == self:
		PlayerManager.capture_runtime_stats_from_player(false)
		PlayerManager.clear_player(self)
func refresh_after_restore() -> void:
	if !is_inside_tree():
		return

	is_dead = false
	is_hurt = false
	is_shooting_arrow = false
	hurt_timer = 0.0
	can_control = true
	attack_cooldown = false
	current_base_animation = ""

	velocity = Vector2.ZERO

	apply_weapon_upgrade_bonus()
	stop_hurt_box()

	emit_all_stat_signals()

	if animation_player != null:
		update_animation("idle", false)
func refresh_after_restore_delayed() -> void:
	await get_tree().process_frame
	emit_all_stat_signals()

	await get_tree().process_frame
	emit_all_stat_signals()

	await get_tree().create_timer(0.2).timeout
	emit_all_stat_signals()

	await get_tree().create_timer(0.5).timeout
	emit_all_stat_signals()


func emit_all_stat_signals() -> void:
	if !is_inside_tree():
		return

	coin_changed.emit(coin_count)
	potion_changed.emit(potion_count)
	health_changed.emit(current_health_units, max_health_units, current_health_units)
	exp_changed.emit(current_exp, exp_to_next, level)
	level_changed.emit(level, max_health_units)
	item_inventory_changed.emit()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if !can_do_action():
		return

	if event.is_action_pressed(get_shoot_arrow_action()):
		try_shoot_arrow()
		get_viewport().set_input_as_handled()
		return

	if !is_coop_mode() and can_cycle_inventory_items():
		if event.is_action_pressed("item_prev"):
			select_inventory_item(-1)
			get_viewport().set_input_as_handled()
			return

		if event.is_action_pressed("item_next"):
			select_inventory_item(1)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed(get_heal_action()):
		if is_coop_mode():
			use_health_potion()
		else:
			use_selected_item()

		get_viewport().set_input_as_handled()
		return
func add_potion(amount: int = 1) -> void:
	var stats_player := get_shared_stats_player()

	if stats_player != self:
		stats_player.add_potion(amount)
		return

	add_inventory_item("health_potion", amount)


func use_health_potion() -> void:
	var stats_player := get_shared_stats_player()

	if stats_player != self:
		stats_player.use_health_potion()
		return
	if is_dead:
		return

	if is_using_potion:
		return

	if potion_count <= 0:
		return

	if current_health_units >= max_health_units:
		return

	potion_count -= 1
	potion_changed.emit(potion_count)

	ensure_selected_item_valid()
	item_inventory_changed.emit()

	play_potion_use_sound()
	start_potion_heal()

func start_potion_heal() -> void:
	is_using_potion = true

	var heal_times: int = 3

	for i in range(heal_times):
		if is_dead:
			break

		if current_health_units >= max_health_units:
			break

		await get_tree().create_timer(1.0).timeout

		if is_dead:
			break

		heal(1)

	is_using_potion = false
func get_shared_stats_player() -> Player:
	if !is_coop_mode():
		return self

	if PlayerManager.player != null and PlayerManager.player is Player:
		return PlayerManager.player as Player

	return self


func is_shared_stats_proxy() -> bool:
	if !is_coop_mode():
		return false

	return get_shared_stats_player() != self
func take_shared_damage_only(amount: int = 1) -> void:
	var old_health: int = current_health_units

	current_health_units -= amount
	current_health_units = clamp(current_health_units, 0, max_health_units)

	health_changed.emit(current_health_units, max_health_units, old_health)


func die_all_players(attacker_position: Vector2 = Vector2.ZERO) -> void:
	var players := get_tree().get_nodes_in_group("players")

	if players.is_empty():
		die(attacker_position, true)
		return

	for p in players:
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p is Player:
			var target_player := p as Player

			if !target_player.is_dead:
				target_player.die(attacker_position, true)
func create_player_marker() -> void:
	if !show_player_marker_in_coop:
		return

	if !is_coop_mode():
		return

	var marker_texture: Texture2D = null

	if player_id == 1:
		marker_texture = player_1_marker_texture
	else:
		marker_texture = player_2_marker_texture

	if marker_texture == null:
		push_warning("Player %d chưa được gán ảnh marker." % player_id)
		return

	player_marker_root = Node2D.new()
	player_marker_root.name = "PlayerMarker"
	player_marker_root.position = player_marker_offset
	player_marker_root.z_index = 100
	player_marker_root.z_as_relative = false
	add_child(player_marker_root)

	var marker_sprite := Sprite2D.new()
	marker_sprite.name = "MarkerSprite"
	marker_sprite.texture = marker_texture
	marker_sprite.centered = true
	marker_sprite.scale = player_marker_scale
	marker_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_marker_root.add_child(marker_sprite)
func get_shoot_arrow_action() -> String:
	if !is_coop_mode():
		return "shoot_arrow"

	if player_id == 1:
		return "p1_shoot_arrow"

	return "p2_shoot_arrow"


func is_shoot_arrow_just_pressed() -> bool:
	if !can_do_action():
		return false

	return Input.is_action_just_pressed(get_shoot_arrow_action())


func is_shoot_arrow_event_pressed(event: InputEvent) -> bool:
	if !can_do_action():
		return false

	return event.is_action_pressed(get_shoot_arrow_action())
func spend_coin(amount: int) -> bool:
	var stats_player := get_shared_stats_player()

	if stats_player != self:
		return stats_player.spend_coin(amount)

	if amount <= 0:
		return true

	if coin_count < amount:
		return false

	coin_count -= amount
	coin_changed.emit(coin_count)

	print("Spend coin: ", amount, " | Coin left: ", coin_count)

	return true
func play_bow_shoot_sound() -> void:
	if bow_shoot_sound == null:
		return

	if bow_shoot_sound.stream == null:
		return

	bow_shoot_sound.stop()
	bow_shoot_sound.pitch_scale = randf_range(0.95, 1.08)
	bow_shoot_sound.play()
func apply_player_skin() -> void:
	if sprite_2d == null:
		return

	if player_id == 1:
		if player_1_texture != null:
			sprite_2d.texture = player_1_texture
	else:
		if player_2_texture != null:
			sprite_2d.texture = player_2_texture
func play_potion_use_sound() -> void:
	if potion_use_sound == null:
		return

	if potion_use_sound.stream == null:
		return

	potion_use_sound.stop()
	potion_use_sound.pitch_scale = randf_range(0.95, 1.08)
	potion_use_sound.play()
func get_arrow_damage() -> int:
	var damage: int = max(1, arrow_damage)

	if witcher_strength_time_left > 0.0:
		damage = int(ceil(float(damage) * WITCHER_STRENGTH_DAMAGE_MULTIPLIER))

	return max(1, damage)
func setup_witcher_buff_base_stats() -> void:
	if base_max_horizontal_speed_for_witcher_buff < 0.0:
		base_max_horizontal_speed_for_witcher_buff = max_horizontal_speed

	if base_max_jump_horizontal_speed_for_witcher_buff < 0.0:
		base_max_jump_horizontal_speed_for_witcher_buff = max_jump_horizontal_speed


func apply_witcher_buff(item_id: String) -> bool:
	if is_coop_mode():
		return false

	setup_witcher_buff_base_stats()

	match item_id:
		"strength":
			witcher_strength_time_left = WITCHER_BUFF_DURATION
			return true

		"defense":
			witcher_defense_time_left = WITCHER_BUFF_DURATION
			witcher_defense_damage_buffer = 0.0
			return true

		"speed":
			witcher_speed_time_left = WITCHER_BUFF_DURATION
			refresh_witcher_speed_buff()
			return true

	return false


func update_witcher_buffs(delta: float) -> void:
	if witcher_strength_time_left > 0.0:
		witcher_strength_time_left -= delta

		if witcher_strength_time_left < 0.0:
			witcher_strength_time_left = 0.0

	if witcher_defense_time_left > 0.0:
		witcher_defense_time_left -= delta

		if witcher_defense_time_left <= 0.0:
			witcher_defense_time_left = 0.0
			witcher_defense_damage_buffer = 0.0

	if witcher_speed_time_left > 0.0:
		witcher_speed_time_left -= delta

		if witcher_speed_time_left <= 0.0:
			witcher_speed_time_left = 0.0
			refresh_witcher_speed_buff()


func refresh_witcher_speed_buff() -> void:
	setup_witcher_buff_base_stats()

	if witcher_speed_time_left > 0.0:
		max_horizontal_speed = base_max_horizontal_speed_for_witcher_buff * WITCHER_SPEED_MULTIPLIER
		max_jump_horizontal_speed = base_max_jump_horizontal_speed_for_witcher_buff * WITCHER_SPEED_MULTIPLIER
	else:
		max_horizontal_speed = base_max_horizontal_speed_for_witcher_buff
		max_jump_horizontal_speed = base_max_jump_horizontal_speed_for_witcher_buff


func get_received_damage_after_witcher_defense(amount: int) -> int:
	if amount <= 0:
		return 0

	if witcher_defense_time_left <= 0.0:
		return amount

	witcher_defense_damage_buffer += float(amount) * WITCHER_DEFENSE_DAMAGE_MULTIPLIER

	var final_damage := int(floor(witcher_defense_damage_buffer))

	if final_damage > 0:
		witcher_defense_damage_buffer -= float(final_damage)

	return final_damage


func clear_witcher_buffs() -> void:
	witcher_strength_time_left = 0.0
	witcher_defense_time_left = 0.0
	witcher_speed_time_left = 0.0
	witcher_defense_damage_buffer = 0.0

	refresh_witcher_speed_buff()
func add_inventory_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var stats_player := get_shared_stats_player()

	if stats_player != self:
		if stats_player.has_method("add_inventory_item"):
			return stats_player.add_inventory_item(item_id, amount)

		return false

	match item_id:
		"health_potion":
			potion_count += amount
			potion_changed.emit(potion_count)

		"strength_potion":
			strength_potion_count += amount

		"defense_potion":
			defense_potion_count += amount

		"speed_potion":
			speed_potion_count += amount

		_:
			push_warning("Vật phẩm không hợp lệ: " + item_id)
			return false

	has_unlocked_item_slot = true

	selected_item_id = item_id
	ensure_selected_item_valid()

	item_inventory_changed.emit()
	return true


func has_any_inventory_item() -> bool:
	return get_total_inventory_item_count() > 0


func get_total_inventory_item_count() -> int:
	return potion_count + strength_potion_count + defense_potion_count + speed_potion_count


func get_inventory_item_count(item_id: String) -> int:
	match item_id:
		"health_potion":
			return potion_count
		"strength_potion":
			return strength_potion_count
		"defense_potion":
			return defense_potion_count
		"speed_potion":
			return speed_potion_count

	return 0


func get_inventory_item_name(item_id: String) -> String:
	match item_id:
		"health_potion":
			return "Bình máu"
		"strength_potion":
			return "Thuốc sức mạnh"
		"defense_potion":
			return "Thuốc phòng thủ"
		"speed_potion":
			return "Thuốc tốc độ"

	return "Vật phẩm"


func ensure_selected_item_valid() -> void:
	if !has_any_inventory_item():
		return

	if get_inventory_item_count(selected_item_id) > 0:
		return

	for item_id in INVENTORY_ITEM_IDS:
		if get_inventory_item_count(item_id) > 0:
			selected_item_id = item_id
			return


func select_inventory_item(direction: int) -> void:
	if !can_cycle_inventory_items():
		return
	if !has_any_inventory_item():
		return

	ensure_selected_item_valid()

	var current_index := INVENTORY_ITEM_IDS.find(selected_item_id)

	if current_index < 0:
		current_index = 0

	for i in range(1, INVENTORY_ITEM_IDS.size() + 1):
		var next_index := posmod(current_index + direction * i, INVENTORY_ITEM_IDS.size())
		var next_item_id: String = INVENTORY_ITEM_IDS[next_index]

		if get_inventory_item_count(next_item_id) > 0:
			selected_item_id = next_item_id
			item_inventory_changed.emit()
			return


func use_selected_item() -> void:
	if is_coop_mode():
		use_health_potion()
		return

	if is_dead:
		return

	if !has_any_inventory_item():
		return

	ensure_selected_item_valid()

	match selected_item_id:
		"health_potion":
			use_health_potion()

		"strength_potion":
			use_buff_potion("strength_potion", "strength")

		"defense_potion":
			use_buff_potion("defense_potion", "defense")

		"speed_potion":
			use_buff_potion("speed_potion", "speed")


func use_buff_potion(inventory_item_id: String, buff_id: String) -> void:
	if get_inventory_item_count(inventory_item_id) <= 0:
		return

	if !apply_witcher_buff(buff_id):
		return

	remove_inventory_item(inventory_item_id, 1)
	play_potion_use_sound()


func remove_inventory_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return

	match item_id:
		"health_potion":
			potion_count = max(potion_count - amount, 0)
			potion_changed.emit(potion_count)

		"strength_potion":
			strength_potion_count = max(strength_potion_count - amount, 0)

		"defense_potion":
			defense_potion_count = max(defense_potion_count - amount, 0)

		"speed_potion":
			speed_potion_count = max(speed_potion_count - amount, 0)

	ensure_selected_item_valid()
	item_inventory_changed.emit()
func get_owned_inventory_item_type_count() -> int:
	var count := 0

	if potion_count > 0:
		count += 1

	if strength_potion_count > 0:
		count += 1

	if defense_potion_count > 0:
		count += 1

	if speed_potion_count > 0:
		count += 1

	return count


func can_cycle_inventory_items() -> bool:
	if is_coop_mode():
		return false

	return get_owned_inventory_item_type_count() >= 2
func is_item_slot_unlocked() -> bool:
	return has_unlocked_item_slot
func try_shoot_arrow() -> void:
	if !can_start_shoot_arrow():
		return

	is_shooting_arrow = true
	arrow_spawned_this_shot = false
	can_control = false
	velocity.x = 0

	var shoot_anim := "shoot_" + get_direction_name()

	if animation_player != null and animation_player.has_animation(shoot_anim):
		animation_player.stop()
		animation_player.play(shoot_anim)
		animation_player.seek(0.0, true)

		await get_tree().create_timer(0.35).timeout
	else:
		push_warning("Không tìm thấy animation: " + shoot_anim)
		await get_tree().create_timer(0.2).timeout

	is_shooting_arrow = false
	can_control = true
	current_base_animation = ""

func spawn_arrow_projectile() -> void:
	if !is_shooting_arrow:
		return

	if arrow_spawned_this_shot:
		return

	if arrow_scene == null:
		push_warning("Player chưa được gán Arrow Scene.")
		return

	arrow_spawned_this_shot = true

	play_bow_shoot_sound()

	var arrow := arrow_scene.instantiate()

	var arrow_parent: Node = get_tree().current_scene

	if get_parent() != null:
		arrow_parent = get_parent()

	arrow_parent.add_child(arrow)

	var spawn_position := global_position + Vector2(20.0 * float(facing_direction), -8.0)

	if arrow_spawn_point != null:
		spawn_position = arrow_spawn_point.global_position

	if arrow is Node2D:
		(arrow as Node2D).global_position = spawn_position

	if arrow.has_method("setup_arrow"):
		arrow.setup_arrow(facing_direction, get_arrow_damage())
	else:
		arrow.set("direction", facing_direction)
		arrow.set("damage", get_arrow_damage())

	consume_arrow_after_shot()

	print("SHOOT ARROW | dir = ", facing_direction, " | pos = ", spawn_position)


func consume_arrow_after_shot() -> void:
	if LevelManager.has_method("use_arrow"):
		LevelManager.use_arrow()
		return

	if LevelManager.has_method("consume_arrow"):
		LevelManager.consume_arrow()
		return

	if LevelManager.has_method("spend_arrow"):
		LevelManager.spend_arrow(1)
		return

	# Fallback nếu LevelManager không có hàm trừ tên.
	LevelManager.arrow_count = max(LevelManager.arrow_count - 1, 0)

	if LevelManager.has_signal("arrow_changed"):
		LevelManager.arrow_changed.emit(LevelManager.has_bow, LevelManager.arrow_count)
