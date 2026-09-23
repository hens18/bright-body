class_name MeleeWeapon
extends Resource
## A sword. Scales the player's combo damage and tints the blade on the hero model.

@export var display_name := "Sword"
@export_range(1, 5) var tier := 1
## Multiplies every hit of the melee combo.
@export var damage_scale := 1.0
@export var blade_color := Color(0.8, 0.82, 0.86)


func slot_key() -> String:
	return "sword"


func power() -> float:
	return damage_scale


func summary() -> String:
	return "x%.2f melee damage" % damage_scale
