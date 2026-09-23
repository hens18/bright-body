class_name Enemy
extends CharacterBody3D
## Basic enemy brain. MELEE enemies close in and swing after a visible windup.
## RANGED enemies keep their distance and fire projectiles. Hitting an enemy
## during its windup staggers it and cancels the attack.
##
## Enemies can drop loot (high tier weapons come from mobs, mini bosses and bosses).
## Give mini bosses and bosses a persistent_id so they stay dead once beaten.

signal defeated(enemy: Enemy)

enum Kind { MELEE, RANGED }
enum State { IDLE, CHASE, WINDUP, RECOVER, STAGGER, DEAD }

const LOOT_DROP := preload("res://scenes/world/loot_drop.tscn")

@export var kind := Kind.MELEE
@export var body_color := Color(0.85, 0.3, 0.25)

@export_group("Movement")
@export var move_speed := 3.8
@export var acceleration := 8.0
@export var turn_speed := 8.0

@export_group("Senses")
@export var detect_range := 14.0
@export var give_up_range := 26.0

@export_group("Attack")
@export var attack_range := 1.9
## Ranged enemies back away when the player is closer than this.
@export var keep_distance := 0.0
@export var damage := 15.0
@export var windup_time := 0.55
@export var recover_time := 0.9
@export var lunge_speed := 7.0
@export var knockback := 7.0
@export var stagger_time := 0.35
## False gives super armor: hits never interrupt it (mini bosses, bosses).
@export var can_stagger := true
@export var projectile_scene: PackedScene

@export_group("Loot")
## Item resource (weapon or armor) this enemy may drop.
@export var drop: Resource
@export_range(0.0, 1.0) var drop_chance := 1.0
## Set for mini bosses and bosses: once defeated they never come back.
@export var persistent_id := ""

var state := State.IDLE
var target: Player

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _state_time := 0.0
var _material := StandardMaterial3D.new()

@onready var _game_state: Node = get_node_or_null(^"/root/GameState")
@onready var visual: Node3D = $Visual
@onready var health: Health = $Health
@onready var _muzzle: Marker3D = $Visual/Muzzle


func _ready() -> void:
	if not persistent_id.is_empty() and _game_state and _game_state.is_defeated(persistent_id):
		state = State.DEAD
		queue_free()
		return
	_material.albedo_color = body_color
	for mesh in visual.find_children("*", "MeshInstance3D"):
		(mesh as MeshInstance3D).material_override = _material
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	_state_time += delta
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Player
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var desired := Vector3.ZERO
	match state:
		State.IDLE:
			if _target_alive() and _distance_to_target() <= detect_range and _can_see_target():
				_set_state(State.CHASE)
		State.CHASE:
			desired = _process_chase(delta)
		State.WINDUP:
			_face(_to_target(), delta * 0.5)
			_material.emission_energy_multiplier = 4.0 * _state_time / windup_time
			if _state_time >= windup_time:
				_attack()
				_set_state(State.RECOVER)
		State.RECOVER, State.STAGGER:
			var wait := recover_time if state == State.RECOVER else stagger_time
			if _state_time >= wait:
				_set_state(State.CHASE)
		State.DEAD:
			pass

	var weight := 1.0 - exp(-acceleration * delta)
	velocity.x = lerpf(velocity.x, desired.x, weight)
	velocity.z = lerpf(velocity.z, desired.z, weight)
	move_and_slide()


func is_alive() -> bool:
	return state != State.DEAD


func apply_knockback(force: Vector3) -> void:
	velocity += force


func _process_chase(delta: float) -> Vector3:
	if not _target_alive() or _distance_to_target() > give_up_range:
		_set_state(State.IDLE)
		return Vector3.ZERO

	var to := _to_target()
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	_face(dir, delta)

	if dist <= attack_range and _can_see_target():
		_set_state(State.WINDUP)
		_material.emission_enabled = true
		_material.emission = body_color.lightened(0.6)
		return Vector3.ZERO
	if dist < keep_distance:
		return -dir * move_speed * 0.7
	return dir * move_speed


func _attack() -> void:
	_material.emission_enabled = false
	var fwd := -visual.global_basis.z
	match kind:
		Kind.MELEE:
			velocity += fwd * lunge_speed
			var center := global_position + Vector3.UP + fwd * 1.1
			Combat.hit_sphere(self, center, 0.9, &"player", damage, fwd * knockback)
		Kind.RANGED:
			if projectile_scene == null or not _target_alive():
				return
			var from := _muzzle.global_position
			var shot := projectile_scene.instantiate() as Projectile
			get_tree().current_scene.add_child(shot)
			shot.launch(from, target.global_position + Vector3.UP - from, self, &"player", damage)


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _target_alive() -> bool:
	return target != null and is_instance_valid(target) and not target.health.is_dead


func _to_target() -> Vector3:
	var to := target.global_position - global_position
	to.y = 0.0
	return to


func _distance_to_target() -> float:
	return global_position.distance_to(target.global_position)


func _can_see_target() -> bool:
	var eye := global_position + Vector3.UP * 1.4
	var query := PhysicsRayQueryParameters3D.create(eye, target.global_position + Vector3.UP, Combat.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _face(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), minf(turn_speed * delta, 1.0))


func _on_damaged(_amount: float, _source: Node) -> void:
	if state == State.DEAD:
		return
	# Getting hit interrupts the windup and makes the enemy aggressive.
	if can_stagger:
		_material.emission_enabled = false
		_set_state(State.STAGGER)
	elif state == State.IDLE:
		_set_state(State.CHASE)
	var flash := create_tween()
	_material.albedo_color = Color.WHITE
	flash.tween_property(_material, "albedo_color", body_color, 0.18)


func _on_died() -> void:
	_set_state(State.DEAD)
	remove_from_group(&"enemy")
	collision_layer = 0
	_material.emission_enabled = false
	defeated.emit(self)
	if not persistent_id.is_empty() and _game_state:
		_game_state.mark_defeated(persistent_id)
	if drop and randf() < drop_chance:
		var loot := LOOT_DROP.instantiate()
		loot.item = drop
		get_tree().current_scene.add_child(loot)
		loot.global_position = global_position
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 0.05, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
