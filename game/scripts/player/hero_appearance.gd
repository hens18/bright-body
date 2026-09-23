class_name HeroAppearance
extends Resource
## The player's chosen look for their hero. Stored by GameState and applied to the
## hero model at runtime. Recolors surfaces whose material is named "Body" (armor)
## or "Accent" (trim), so any model exported from Blender with those material
## names can be customized.

const ARMOR_COLORS: Array[Color] = [
	Color(0.27, 0.42, 0.72), # Royal blue
	Color(0.6, 0.18, 0.2), # Crimson
	Color(0.24, 0.42, 0.28), # Forest green
	Color(0.42, 0.42, 0.46), # Iron grey
	Color(0.36, 0.26, 0.5), # Royal purple
	Color(0.9, 0.87, 0.8), # Bone white
	Color(0.16, 0.15, 0.17), # Black steel
	Color(0.48, 0.33, 0.2), # Leather brown
]
const TRIM_COLORS: Array[Color] = [
	Color(0.9, 0.72, 0.3), # Gold
	Color(0.78, 0.8, 0.85), # Silver
	Color(0.72, 0.42, 0.22), # Bronze
	Color(0.2, 0.18, 0.2), # Dark iron
	Color(0.85, 0.85, 0.8), # Ivory
	Color(0.55, 0.12, 0.14), # Deep red
]
const HEIGHT_RANGE := Vector2(0.9, 1.1)
const BUILD_RANGE := Vector2(0.85, 1.2)

@export var armor_color := ARMOR_COLORS[0]
@export var trim_color := TRIM_COLORS[0]
## Vertical scale of the model.
@export_range(0.9, 1.1) var height := 1.0
## Horizontal scale of the model: slim to broad.
@export_range(0.85, 1.2) var build := 1.0


## Recolors and scales a hero model instance (the root of the imported .glb).
func apply(model: Node3D) -> void:
	if model == null:
		return
	model.scale = Vector3(build, height, build)
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var source := mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var color: Variant = {"Body": armor_color, "Accent": trim_color}.get(source.resource_name)
			if color == null:
				continue
			var material := source.duplicate() as BaseMaterial3D
			material.albedo_color = color
			mesh_instance.set_surface_override_material(surface, material)


func to_dict() -> Dictionary:
	return {"armor_color": armor_color, "trim_color": trim_color, "height": height, "build": build}


static func from_dict(data: Dictionary) -> HeroAppearance:
	var appearance := HeroAppearance.new()
	appearance.armor_color = data.get("armor_color", appearance.armor_color)
	appearance.trim_color = data.get("trim_color", appearance.trim_color)
	appearance.height = clampf(data.get("height", 1.0), HEIGHT_RANGE.x, HEIGHT_RANGE.y)
	appearance.build = clampf(data.get("build", 1.0), BUILD_RANGE.x, BUILD_RANGE.y)
	return appearance
