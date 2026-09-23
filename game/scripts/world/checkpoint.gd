extends Node3D
## A candlelit shrine. Touching it lights the candles, makes it the respawn point
## and restores the hero's health. After dying, the hero rises at the last one lit.

## Unique within its level. Defaults to the node name.
@export var checkpoint_id := ""

var is_lit := false

@onready var _game_state: Node = get_node_or_null(^"/root/GameState")
@onready var _flames: Node3D = $Flames
@onready var _light: OmniLight3D = $Light
@onready var _zone: Area3D = $Zone


func _ready() -> void:
	if checkpoint_id.is_empty():
		checkpoint_id = name
	_zone.body_entered.connect(_on_body_entered)
	_set_lit(_game_state != null and _game_state.checkpoint_scene == _scene_path() \
			and _game_state.checkpoint_id == checkpoint_id)


## Where the hero stands when respawning here: just in front of the shrine.
func spawn_position() -> Vector3:
	return global_position + global_basis.z * 1.6


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player") or (body.has_method("is_alive") and not body.is_alive()):
		return
	body.health.heal(body.health.max_health)
	if is_lit:
		return
	# Only one shrine is lit at a time: the latest respawn point.
	for other in get_tree().get_nodes_in_group(&"checkpoint"):
		other._set_lit(false)
	_set_lit(true)
	if _game_state:
		_game_state.set_checkpoint(_scene_path(), checkpoint_id)


func _set_lit(lit: bool) -> void:
	is_lit = lit
	_flames.visible = lit
	_light.visible = lit


func _scene_path() -> String:
	return get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
