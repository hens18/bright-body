class_name Combat
extends RefCounted
## Shared helpers for dealing damage. Matches the physics layer names in project.godot.

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_PROJECTILE := 8


## Damages every body in `target_group` overlapping a sphere. Returns how many were hit.
static func hit_sphere(attacker: CollisionObject3D, center: Vector3, radius: float,
		target_group: StringName, damage: float, knockback: Vector3) -> int:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = LAYER_PLAYER | LAYER_ENEMY
	var exclude: Array[RID] = [attacker.get_rid()]
	query.exclude = exclude

	var hits := 0
	var seen := {}
	for result in attacker.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var body: Node = result.collider
		if body == null or seen.has(body) or not body.is_in_group(target_group):
			continue
		seen[body] = true
		if apply_damage(body, damage, knockback, attacker):
			hits += 1
	return hits


## Damages a node through its "Health" child and pushes it if it supports knockback.
static func apply_damage(target: Node, damage: float, knockback: Vector3, source: Node) -> bool:
	var health := target.get_node_or_null("Health") as Health
	if health == null or not health.take_damage(damage, source):
		return false
	if target.has_method("apply_knockback"):
		target.apply_knockback(knockback)
	return true
