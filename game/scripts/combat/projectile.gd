class_name Projectile
extends Area3D
## A straight flying shot. Spawn it, add it to the tree, then call launch().

@export var speed := 32.0
@export var lifetime := 2.5
@export var knockback := 3.0
@export var color := Color(0.35, 0.85, 1.0)

var damage := 10.0
var direction := Vector3.FORWARD
var target_group: StringName = &"enemy"
var shooter: Node
var _age := 0.0

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _light: OmniLight3D = $Light


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	_mesh.material_override = material
	_light.light_color = color
	body_entered.connect(_on_body_entered)


func launch(from: Vector3, dir: Vector3, from_shooter: Node, group: StringName, dmg: float) -> void:
	global_position = from
	direction = dir.normalized()
	shooter = from_shooter
	target_group = group
	damage = dmg


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body.is_in_group(target_group):
		var hit := Combat.apply_damage(body, damage, direction * knockback, shooter)
		# A dodging target lets the shot fly past.
		if not hit and body.has_method("is_evading") and body.is_evading():
			return
	elif body is CharacterBody3D:
		return # Shots pass through the shooter's allies.
	queue_free()
