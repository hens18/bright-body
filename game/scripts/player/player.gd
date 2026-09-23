class_name Player
extends CharacterBody3D
## Third person action hero: camera relative movement, sprint, jump, dodge roll,
## a three hit melee combo, aimed ranged shots and enemy lock on.
##
## The placeholder body lives under "Visual". To use a Blender model, drop its
## .glb under Visual and delete the placeholder meshes. If the model has an
## AnimationPlayer with clips named Idle, Run, Jump, Dodge, Attack1..3, Shoot,
## Hurt or Death, they are played automatically.

signal stamina_changed(current: float, maximum: float)
signal lock_target_changed(target: Node3D)

enum State { MOVE, ATTACK, DODGE, DEAD }

@export_group("Movement")
@export var walk_speed := 6.0
@export var sprint_speed := 9.5
@export var aim_move_speed := 3.5
@export var ground_acceleration := 14.0
@export var air_acceleration := 4.0
@export var jump_velocity := 7.0
@export var turn_speed := 14.0

@export_group("Camera")
@export var mouse_sensitivity := 0.0025
@export var gamepad_look_speed := 3.0
@export var min_pitch := -1.2
@export var max_pitch := 0.45
@export var camera_distance := 4.5
@export var aim_camera_distance := 2.2
@export var lock_on_range := 20.0

@export_group("Stamina")
@export var max_stamina := 100.0
@export var stamina_regen := 35.0
@export var stamina_regen_delay := 0.6
@export var sprint_cost := 15.0 ## Per second.
@export var dodge_cost := 25.0
@export var attack_cost := 10.0

@export_group("Dodge")
@export var dodge_speed := 13.0
@export var dodge_duration := 0.35

@export_group("Melee")
@export var combo_damage: Array[float] = [20.0, 20.0, 35.0]
@export var attack_duration := 0.42
@export var attack_hit_time := 0.14
@export var attack_lunge_speed := 5.0
@export var melee_reach := 1.3
@export var melee_radius := 1.1
@export var melee_knockback := 6.0

@export_group("Ranged")
@export var projectile_scene: PackedScene
@export var shot_damage := 12.0
@export var shot_cooldown := 0.22

@export_group("Damage")
@export var hurt_invulnerability := 0.6

var state := State.MOVE
var stamina: float
var lock_target: Node3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _state_time := 0.0
var _stamina_delay := 0.0
var _combo_index := 0
var _attack_queued := false
var _attack_hit_done := false
var _dodge_dir := Vector3.ZERO
var _shot_timer := 0.0
var _hurt_timer := 0.0
var _aiming := false
var _shake := 0.0
var _swing_tween: Tween
var _oneshot_time := 0.0

@onready var visual: Node3D = $Visual
@onready var health: Health = $Health
@onready var _muzzle: Marker3D = $Visual/Muzzle
@onready var _weapon: Node3D = get_node_or_null("Visual/WeaponPivot")
@onready var _cam_pivot: Node3D = $CameraPivot
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var _anim: AnimationPlayer = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _ready() -> void:
	stamina = max_stamina
	_spring_arm.spring_length = camera_distance
	_spring_arm.add_excluded_object(get_rid())
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	if _anim:
		for loop_name: StringName in [&"Idle", &"Run"]:
			if _anim.has_animation(loop_name):
				_anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_state_time += delta
	_shot_timer = maxf(_shot_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	_oneshot_time = maxf(_oneshot_time - delta, 0.0)
	health.invulnerable = state == State.DODGE or _hurt_timer > 0.0
	_aiming = state != State.DEAD and Input.is_action_pressed("aim")

	if state != State.DEAD:
		_read_actions()

	match state:
		State.MOVE:
			_process_move(delta)
		State.ATTACK:
			_process_attack(delta)
		State.DODGE:
			_process_dodge(delta)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()

	_update_stamina(delta)
	_update_camera(delta)


# Public API ----------------------------------------------------------------

func is_aiming() -> bool:
	return _aiming


func is_evading() -> bool:
	return state == State.DODGE


func apply_knockback(force: Vector3) -> void:
	velocity += force


func forward() -> Vector3:
	return -visual.global_basis.z


# Input ---------------------------------------------------------------------

func _read_actions() -> void:
	if Input.is_action_just_pressed("lock_on"):
		_toggle_lock_on()
	if Input.is_action_just_pressed("jump"):
		_try_jump()
	if Input.is_action_just_pressed("dodge"):
		_try_dodge()
	if Input.is_action_just_pressed("attack"):
		if _aiming:
			_try_shoot()
		else:
			_try_attack()
	elif _aiming and Input.is_action_pressed("attack"):
		_try_shoot() # Hold to keep firing.


func _move_input() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return Basis(Vector3.UP, _cam_pivot.rotation.y) * Vector3(input.x, 0.0, input.y)


# States --------------------------------------------------------------------

func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _process_move(delta: float) -> void:
	var dir := _move_input()
	var moving := dir.length() > 0.1
	var sprinting := moving and not _aiming and is_on_floor() \
			and stamina > 0.0 and Input.is_action_pressed("sprint")
	var speed := aim_move_speed if _aiming else (sprint_speed if sprinting else walk_speed)
	if sprinting:
		_spend_stamina(sprint_cost * delta)

	var accel := ground_acceleration if is_on_floor() else air_acceleration
	var weight := 1.0 - exp(-accel * delta)
	velocity.x = lerpf(velocity.x, dir.x * speed, weight)
	velocity.z = lerpf(velocity.z, dir.z * speed, weight)

	if _aiming:
		_face(_camera_forward(), delta)
	elif _has_lock_target():
		_face(lock_target.global_position - global_position, delta)
	elif moving:
		_face(dir, delta)

	if _oneshot_time > 0.0:
		pass # Let Hurt / Shoot finish before going back to locomotion.
	elif not is_on_floor():
		_play("Jump")
	elif moving:
		_play("Run")
	else:
		_play("Idle")


func _process_attack(delta: float) -> void:
	# Short lunge until the hit lands, then plant the feet.
	var lunge := attack_lunge_speed if _state_time < attack_hit_time else 0.0
	var fwd := forward()
	velocity.x = move_toward(velocity.x, fwd.x * lunge, 60.0 * delta)
	velocity.z = move_toward(velocity.z, fwd.z * lunge, 60.0 * delta)

	if not _attack_hit_done and _state_time >= attack_hit_time:
		_attack_hit_done = true
		var center := global_position + Vector3.UP + fwd * melee_reach
		var damage := combo_damage[_combo_index]
		if Combat.hit_sphere(self, center, melee_radius, &"enemy", damage, fwd * melee_knockback) > 0:
			_shake = maxf(_shake, 0.12)

	if _state_time >= attack_duration:
		if _attack_queued and _combo_index < combo_damage.size() - 1:
			_start_attack(_combo_index + 1)
		else:
			_set_state(State.MOVE)


func _process_dodge(delta: float) -> void:
	var t := _state_time / dodge_duration
	var speed := dodge_speed * (1.0 - 0.6 * t)
	velocity.x = _dodge_dir.x * speed
	velocity.z = _dodge_dir.z * speed
	_face(_dodge_dir, delta)
	if _state_time >= dodge_duration:
		_set_state(State.MOVE)


# Actions -------------------------------------------------------------------

func _try_jump() -> void:
	if state == State.MOVE and is_on_floor():
		velocity.y = jump_velocity


func _try_dodge() -> void:
	var can_cancel_attack := state == State.ATTACK and _attack_hit_done
	if not (state == State.MOVE or can_cancel_attack) or not is_on_floor() or stamina < dodge_cost:
		return
	var dir := _move_input()
	_dodge_dir = dir.normalized() if dir.length() > 0.1 else -forward()
	_spend_stamina(dodge_cost)
	_set_state(State.DODGE)
	_play("Dodge")
	if _anim == null:
		var squash := create_tween()
		squash.tween_property(visual, "scale", Vector3(1.15, 0.6, 1.15), dodge_duration * 0.3)
		squash.tween_property(visual, "scale", Vector3.ONE, dodge_duration * 0.7)


func _try_attack() -> void:
	if state == State.ATTACK:
		_attack_queued = true
	elif state == State.MOVE and stamina > 0.0:
		_start_attack(0)


func _start_attack(index: int) -> void:
	_set_state(State.ATTACK)
	_combo_index = index
	_attack_queued = false
	_attack_hit_done = false
	_spend_stamina(attack_cost)

	# Turn toward the target (or the stick direction) before swinging.
	var aim_dir := _move_input()
	if _has_lock_target():
		aim_dir = lock_target.global_position - global_position
	if aim_dir.length() > 0.1:
		_face(aim_dir, 1.0)

	_play("Attack%d" % (index + 1))
	if _anim == null and _weapon:
		_swing_placeholder_weapon(index)


func _try_shoot() -> void:
	if _shot_timer > 0.0 or projectile_scene == null or state != State.MOVE:
		return
	_shot_timer = shot_cooldown
	var from := _muzzle.global_position
	var shot := projectile_scene.instantiate() as Projectile
	get_tree().current_scene.add_child(shot)
	shot.launch(from, _aim_point() - from, self, &"enemy", shot_damage)
	_play_oneshot("Shoot")


func _aim_point() -> Vector3:
	var screen_center := get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(screen_center)
	var end := origin + camera.project_ray_normal(screen_center) * 200.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, Combat.LAYER_WORLD | Combat.LAYER_ENEMY)
	var exclude: Array[RID] = [get_rid()]
	query.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return end if hit.is_empty() else hit.position


# Lock on -------------------------------------------------------------------

func _toggle_lock_on() -> void:
	if _has_lock_target():
		_set_lock_target(null)
		return
	var best: Node3D = null
	var best_score := INF
	var cam_fwd := _camera_forward()
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		if not (enemy is Node3D) or (enemy.has_method("is_alive") and not enemy.is_alive()):
			continue
		var to: Vector3 = enemy.global_position - global_position
		var dist := to.length()
		if dist > lock_on_range:
			continue
		# Prefer enemies near the centre of the screen, then closer ones.
		var score := cam_fwd.angle_to(Vector3(to.x, 0.0, to.z)) + dist * 0.03
		if score < best_score:
			best_score = score
			best = enemy
	_set_lock_target(best)


func _set_lock_target(target: Node3D) -> void:
	if target == lock_target:
		return
	lock_target = target
	lock_target_changed.emit(target)


func _has_lock_target() -> bool:
	if lock_target == null:
		return false
	var lost: bool = not is_instance_valid(lock_target) \
			or (lock_target.has_method("is_alive") and not lock_target.is_alive()) \
			or global_position.distance_to(lock_target.global_position) > lock_on_range * 1.3
	if lost:
		_set_lock_target(null)
	return lock_target != null


# Camera --------------------------------------------------------------------

func _rotate_camera(yaw: float, pitch: float) -> void:
	if not _has_lock_target():
		_cam_pivot.rotation.y = wrapf(_cam_pivot.rotation.y + yaw, -PI, PI)
	_spring_arm.rotation.x = clampf(_spring_arm.rotation.x + pitch, min_pitch, max_pitch)


func _update_camera(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		_rotate_camera(-look.x * gamepad_look_speed * delta, -look.y * gamepad_look_speed * delta)

	if _has_lock_target():
		var to := lock_target.global_position - global_position
		var yaw := atan2(-to.x, -to.z)
		_cam_pivot.rotation.y = lerp_angle(_cam_pivot.rotation.y, yaw, 1.0 - exp(-8.0 * delta))

	var weight := 1.0 - exp(-12.0 * delta)
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length,
			aim_camera_distance if _aiming else camera_distance, weight)
	_spring_arm.position.x = lerpf(_spring_arm.position.x, 0.9 if _aiming else 0.45, weight)
	camera.fov = lerpf(camera.fov, 55.0 if _aiming else 70.0, weight)

	_shake = maxf(_shake - delta, 0.0)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.5
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.5


func _camera_forward() -> Vector3:
	var yaw := _cam_pivot.rotation.y
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


# Helpers -------------------------------------------------------------------

func _face(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, minf(turn_speed * delta, 1.0))


func _spend_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_stamina_delay = stamina_regen_delay
	stamina_changed.emit(stamina, max_stamina)


func _update_stamina(delta: float) -> void:
	if _stamina_delay > 0.0:
		_stamina_delay -= delta
	elif stamina < max_stamina:
		stamina = minf(stamina + stamina_regen * delta, max_stamina)
		stamina_changed.emit(stamina, max_stamina)


func _play(anim_name: StringName) -> void:
	if _anim and _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.15)


func _play_oneshot(anim_name: StringName) -> void:
	if _anim and _anim.has_animation(anim_name):
		_anim.play(anim_name, 0.05)
		_anim.seek(0.0, true)
		_oneshot_time = _anim.get_animation(anim_name).length


func _swing_placeholder_weapon(index: int) -> void:
	# Stand in for a real attack animation: sweep the blade across the body.
	if _swing_tween:
		_swing_tween.kill()
	var side := -1.0 if index % 2 == 0 else 1.0
	_weapon.rotation = Vector3(0.0, side * 1.4, 0.0)
	_swing_tween = create_tween()
	_swing_tween.tween_property(_weapon, "rotation:y", -side * 1.4, attack_hit_time + 0.06)
	_swing_tween.tween_property(_weapon, "rotation:y", 0.0, attack_duration - attack_hit_time)


func _on_damaged(_amount: float, _source: Node) -> void:
	_hurt_timer = hurt_invulnerability
	_shake = maxf(_shake, 0.25)
	if state == State.MOVE:
		_play_oneshot("Hurt")


func _on_died() -> void:
	_set_state(State.DEAD)
	_set_lock_target(null)
	_play("Death")
	if _anim == null:
		create_tween().tween_property(visual, "rotation:x", PI * 0.5, 0.5) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
