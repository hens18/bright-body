class_name ArmorItem
extends Resource
## A piece of armor found in loot chests. Equipping it adds defense and shows the
## matching part of the hero model (a mesh named `model_part`, e.g. "Armor_Helmet").

enum Slot { HEAD, CHEST, HANDS, LEGS }

@export var display_name := "Armor"
@export var slot := Slot.CHEST
## Each point of defense reduces damage taken; see Player.defense_multiplier().
@export var defense := 10.0
@export var model_part := "Armor_Chest"
## Hides the hair while worn (full helmets).
@export var hides_hair := false
