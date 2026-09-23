class_name ArmorItem
extends Resource
## A piece of armor found in loot chests. Equipping it adds defense and shows the
## matching part of the hero model (a mesh named `model_part`, e.g. "Armor_Helmet").

enum Slot { HEAD, CHEST, HANDS, LEGS }

const SLOT_KEYS := ["head", "chest", "hands", "legs"]

@export var display_name := "Armor"
@export var slot := Slot.CHEST
## 1 iron, 2 steel, 3 to 5 boss sets. See docs/DESIGN.md.
@export_range(1, 5) var tier := 1
## Each point of defense reduces damage taken; see Player.defense_multiplier().
@export var defense := 10.0
@export var model_part := "Armor_Chest"
## Hides the hair while worn (full helmets).
@export var hides_hair := false


## Equipment slot this item occupies in GameState.equipped.
func slot_key() -> String:
	return SLOT_KEYS[slot]


## Used to decide whether a new find beats what is already equipped.
func power() -> float:
	return defense


func summary() -> String:
	return "+%d defense" % defense
