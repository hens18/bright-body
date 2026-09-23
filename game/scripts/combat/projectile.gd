class_name Projectile
extends Area3D
## A flying shot: arrow, bolt or spell. Set speed, gravity_scale, homing and color
## before adding it to the tree, then call launch().

@export var speed := 32.0
@export var lifetime := 2.5
@export var knockback := 3.0
@export var color := Color(0.35, 0.85, 1.0)
## 0 flies straight, 1 falls with full gravity.
@export var gravity_scale := 0.0
@export var homing_strength := 0.0
## Glowing shots (magic) get emission and a light; arrows and bolts do not.
@export var glow := true

var damage := 10.0
var velocity := Vector3.ZERO
var target_group: StringName = &"enemy"
var shooter: Node
var homing_target: Node3D
var _age := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _light: OmniLight3D = $Light


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.0
	_mesh.material_override = material
	_light.light_color = color
	_light.visible = glow
	body_entered.connect(_on_body_entered)


func launch(from: Vector3, dir: Vector3, from_shooter: Node, group: StringName, dmg: float) -> void:
	global_position = from
	velocity = dir.normalized() * speed
	shooter = from_shooter
	target_group = group
	damage = dmg
	_orient()


func _physics_process(delta: float) -> void:
	if homing_strength > 0.0 and is_instance_valid(homing_target):
		var desired := (homing_target.global_position + Vector3.UP - global_position).normalized() * speed
		velocity = velocity.lerp(desired, minf(homing_strength * delta, 1.0)).normalized() * speed
	velocity.y -= _gravity * gravity_scale * delta
	global_position += velocity * delta
	_orient()
	_age += delta
	if _age >= lifetime:
		queue_free()


## Points the shot's -Z along its flight so arrows and bolts face where they fly.
func _orient() -> void:
	if velocity.length_squared() > 0.001 and absf(velocity.normalized().dot(Vector3.UP)) < 0.99:
		look_at(global_position + velocity)


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	var direction := velocity.normalized()
	if body.is_in_group(target_group):
		var hit := Combat.apply_damage(body, damage, direction * knockback, shooter)
		# A dodging target lets the shot fly past.
		if not hit and body.has_method("is_evading") and body.is_evading():
			return
	elif body is CharacterBody3D:
		return # Shots pass through the shooter's allies.
	queue_free()
