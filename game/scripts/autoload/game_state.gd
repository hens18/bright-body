extends Node
## Global, persistent game state. Registered as the GameState autoload.
## Holds the hero's name and body, equipped armor and which chests are opened,
## and saves them to disk. Skill points will live here too.

signal equipment_changed
signal item_obtained(item: ArmorItem)

const SAVE_PATH := "user://profile.cfg"
const MAX_NAME_LENGTH := 20
const DEFAULT_NAME := "Wanderer"

var hero_name := ""
var appearance := HeroAppearance.new()
## ArmorItem.Slot -> ArmorItem
var equipped := {}
## Chest ids already looted, so they stay open across reloads.
var opened_chests := {}


func _ready() -> void:
	load_profile()


## Starts a fresh adventure: no armor, every chest closed. Keeps name and body.
func new_game() -> void:
	equipped.clear()
	opened_chests.clear()
	equipment_changed.emit()
	save_profile()


## Stores a cleaned up name. Returns the name actually used.
func set_hero_name(value: String) -> String:
	var cleaned := value.strip_edges().left(MAX_NAME_LENGTH)
	hero_name = cleaned if not cleaned.is_empty() else DEFAULT_NAME
	save_profile()
	return hero_name


func display_name() -> String:
	return hero_name if not hero_name.is_empty() else DEFAULT_NAME


# Equipment -----------------------------------------------------------------

## Picks up an item from a chest. Armor goes on straight away if it is at least as
## good as what is in that slot. Returns true if it was equipped.
func obtain(item: ArmorItem) -> bool:
	item_obtained.emit(item)
	var current: ArmorItem = equipped.get(item.slot)
	if current != null and current.defense > item.defense:
		return false
	equipped[item.slot] = item
	equipment_changed.emit()
	save_profile()
	return true


func equipped_items() -> Array[ArmorItem]:
	var items: Array[ArmorItem] = []
	for item: ArmorItem in equipped.values():
		items.append(item)
	return items


func total_defense() -> float:
	var total := 0.0
	for item: ArmorItem in equipped.values():
		total += item.defense
	return total


# Chests --------------------------------------------------------------------

func is_chest_opened(chest_id: String) -> bool:
	return opened_chests.has(chest_id)


func mark_chest_opened(chest_id: String) -> void:
	opened_chests[chest_id] = true
	save_profile()


# Saving --------------------------------------------------------------------

func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("hero", "name", hero_name)
	config.set_value("hero", "appearance", appearance.to_dict())
	var equipped_paths := {}
	for slot: int in equipped:
		equipped_paths[slot] = (equipped[slot] as ArmorItem).resource_path
	config.set_value("progress", "equipped", equipped_paths)
	config.set_value("progress", "opened_chests", opened_chests.keys())
	config.save(SAVE_PATH)


func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	hero_name = config.get_value("hero", "name", "")
	appearance = HeroAppearance.from_dict(config.get_value("hero", "appearance", {}))
	equipped.clear()
	var equipped_paths: Dictionary = config.get_value("progress", "equipped", {})
	for slot: int in equipped_paths:
		var item := load(equipped_paths[slot]) as ArmorItem
		if item:
			equipped[slot] = item
	opened_chests.clear()
	for chest_id: String in config.get_value("progress", "opened_chests", []):
		opened_chests[chest_id] = true
