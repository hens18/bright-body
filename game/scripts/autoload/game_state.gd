extends Node
## Global, persistent game state. Registered as the GameState autoload.
## Holds the hero's name and body, equipped gear, opened chests, defeated
## mini bosses and the last checkpoint, and saves them to disk.
##
## Items are ArmorItem, MeleeWeapon or RangedWeapon resources. Each has
## slot_key(), power(), summary() and display_name, and fills one slot:
## head, chest, hands, legs, sword, bow, crossbow, spell.

signal equipment_changed
signal item_obtained(item: Resource, equipped: bool)
signal checkpoint_reached(checkpoint_id: String)

const SAVE_PATH := "user://profile.cfg"
const MAX_NAME_LENGTH := 20
const DEFAULT_NAME := "Wanderer"
const STARTING_GEAR: Array[String] = ["res://resources/weapons/worn_sword.tres"]
const RANGED_SLOTS: Array[String] = ["bow", "crossbow", "spell"]

var hero_name := ""
var appearance := HeroAppearance.new()
## Slot key -> item resource.
var equipped := {}
## Chest ids already looted, so they stay open across reloads.
var opened_chests := {}
## Ids of mini bosses and bosses that stay dead.
var defeated := {}
## Id of the last checkpoint touched ("" = level start) and the scene it is in.
var checkpoint_id := ""
var checkpoint_scene := ""


func _ready() -> void:
	load_profile()


## Starts a fresh adventure: starting gear only, every chest closed, no checkpoint.
## Keeps name and body.
func new_game() -> void:
	equipped.clear()
	for path in STARTING_GEAR:
		var item: Resource = load(path)
		equipped[item.slot_key()] = item
	opened_chests.clear()
	defeated.clear()
	checkpoint_id = ""
	checkpoint_scene = ""
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

## Picks up an item from a chest or a drop. It is equipped straight away if it is
## at least as good as what fills that slot. Returns true if it was equipped.
func obtain(item: Resource) -> bool:
	var key: String = item.slot_key()
	var current: Resource = equipped.get(key)
	var better: bool = current == null or item.power() >= current.power()
	if better:
		equipped[key] = item
		equipment_changed.emit()
		save_profile()
	item_obtained.emit(item, better)
	return better


func equipped_armor() -> Array[ArmorItem]:
	var items: Array[ArmorItem] = []
	for item: Resource in equipped.values():
		if item is ArmorItem:
			items.append(item)
	return items


func equipped_sword() -> MeleeWeapon:
	return equipped.get("sword")


## Ranged weapons in switching order: bow, crossbow, spell.
func equipped_ranged() -> Array[RangedWeapon]:
	var weapons: Array[RangedWeapon] = []
	for key in RANGED_SLOTS:
		if equipped.has(key):
			weapons.append(equipped[key])
	return weapons


func total_defense() -> float:
	var total := 0.0
	for item in equipped_armor():
		total += item.defense
	return total


# World state ---------------------------------------------------------------

func is_chest_opened(chest_id: String) -> bool:
	return opened_chests.has(chest_id)


func mark_chest_opened(chest_id: String) -> void:
	opened_chests[chest_id] = true
	save_profile()


func is_defeated(enemy_id: String) -> bool:
	return defeated.has(enemy_id)


func mark_defeated(enemy_id: String) -> void:
	defeated[enemy_id] = true
	save_profile()


func set_checkpoint(scene_path: String, id: String) -> void:
	if checkpoint_scene == scene_path and checkpoint_id == id:
		return
	checkpoint_scene = scene_path
	checkpoint_id = id
	save_profile()
	checkpoint_reached.emit(id)


# Saving --------------------------------------------------------------------

func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("hero", "name", hero_name)
	config.set_value("hero", "appearance", appearance.to_dict())
	var equipped_paths := {}
	for key: String in equipped:
		equipped_paths[key] = (equipped[key] as Resource).resource_path
	config.set_value("progress", "equipped", equipped_paths)
	config.set_value("progress", "opened_chests", opened_chests.keys())
	config.set_value("progress", "defeated", defeated.keys())
	config.set_value("progress", "checkpoint_scene", checkpoint_scene)
	config.set_value("progress", "checkpoint_id", checkpoint_id)
	config.save(SAVE_PATH)


func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	hero_name = config.get_value("hero", "name", "")
	appearance = HeroAppearance.from_dict(config.get_value("hero", "appearance", {}))
	equipped.clear()
	var equipped_paths: Dictionary = config.get_value("progress", "equipped", {})
	for key: Variant in equipped_paths:
		var item: Resource = load(equipped_paths[key]) if ResourceLoader.exists(equipped_paths[key]) else null
		if key is String and item != null and item.has_method("slot_key"):
			equipped[key] = item
	opened_chests.clear()
	for chest_id: String in config.get_value("progress", "opened_chests", []):
		opened_chests[chest_id] = true
	defeated.clear()
	for enemy_id: String in config.get_value("progress", "defeated", []):
		defeated[enemy_id] = true
	checkpoint_scene = config.get_value("progress", "checkpoint_scene", "")
	checkpoint_id = config.get_value("progress", "checkpoint_id", "")
