extends Node
## Global, persistent game state. Registered as the GameState autoload.
## Grows into the save system: hero name now, skill points and gear later.

const SAVE_PATH := "user://profile.cfg"
const MAX_NAME_LENGTH := 20
const DEFAULT_NAME := "Wanderer"

var hero_name := ""


func _ready() -> void:
	load_profile()


## Stores a cleaned up name. Returns the name actually used.
func set_hero_name(value: String) -> String:
	var cleaned := value.strip_edges().left(MAX_NAME_LENGTH)
	hero_name = cleaned if not cleaned.is_empty() else DEFAULT_NAME
	save_profile()
	return hero_name


func display_name() -> String:
	return hero_name if not hero_name.is_empty() else DEFAULT_NAME


func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("hero", "name", hero_name)
	config.save(SAVE_PATH)


func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		hero_name = config.get_value("hero", "name", "")
