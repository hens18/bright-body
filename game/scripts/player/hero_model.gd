class_name HeroModel
extends RefCounted
## Dresses a hero model instance (the root of the imported .glb): body shape and
## colors from HeroAppearance, visible hair style, equipped armor pieces and the
## sword's blade color.
##
## Model contract (see blender/README.md): materials named "Skin", "Hair" and
## "Blade" are recolored; meshes named Hair_Short / Hair_Long and Armor_* are toggled.

const HAIR_PARTS := {
	HeroAppearance.Hairstyle.SHORT: "Hair_Short",
	HeroAppearance.Hairstyle.LONG: "Hair_Long",
}
const ARMOR_PREFIX := "Armor_"


## Pass Color.TRANSPARENT as blade_color to keep the model's own blade material.
static func apply(model: Node3D, appearance: HeroAppearance, armor: Array[ArmorItem] = [],
		blade_color := Color.TRANSPARENT) -> void:
	if model == null:
		return
	model.scale = Vector3(appearance.build, appearance.height, appearance.build)

	var worn_parts := {}
	var hide_hair := false
	for item in armor:
		worn_parts[item.model_part] = true
		hide_hair = hide_hair or item.hides_hair
	var hair_part: String = HAIR_PARTS.get(appearance.hairstyle, "")

	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part := String(mesh_instance.name)
		if part.begins_with(ARMOR_PREFIX):
			mesh_instance.visible = worn_parts.has(part)
		elif part.begins_with("Hair_"):
			mesh_instance.visible = part == hair_part and not hide_hair
		var colors := {"Skin": appearance.skin_tone, "Hair": appearance.hair_color}
		if blade_color.a > 0.0:
			colors["Blade"] = blade_color
		_recolor(mesh_instance, colors)


static func _recolor(mesh_instance: MeshInstance3D, colors: Dictionary) -> void:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return
	for surface in mesh.get_surface_count():
		var source := mesh.surface_get_material(surface) as BaseMaterial3D
		if source == null or not colors.has(source.resource_name):
			continue
		var material := source.duplicate() as BaseMaterial3D
		material.albedo_color = colors[source.resource_name]
		mesh_instance.set_surface_override_material(surface, material)
