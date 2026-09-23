extends Node3D
## A chest the player opens with the interact action to receive its loot
## (armor and low tier weapons).
## Opened chests are remembered by GameState, so they stay empty after a reload.

signal opened(item: Resource)

## Unique id used to remember that this chest was looted. Defaults to the node path.
@export var chest_id := ""
## Any item: ArmorItem, MeleeWeapon or RangedWeapon.
@export var loot: Resource

var is_open := false
var _player_near := false

@onready var _game_state: Node = get_node_or_null(^"/root/GameState")
@onready var _lid: Node3D = $LidPivot
@onready var _prompt: Label3D = $Prompt
@onready var _glow: OmniLight3D = $Glow
@onready var _zone: Area3D = $InteractZone


func _ready() -> void:
	if chest_id.is_empty():
		chest_id = str(get_path())
	_zone.body_entered.connect(func(body: Node3D) -> void: _player_near = _player_near or body.is_in_group(&"player"))
	_zone.body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group(&"player"):
			_player_near = false)
	if _game_state and _game_state.is_chest_opened(chest_id):
		is_open = true
		_lid.rotation.x = 1.9
		_glow.visible = false
	_prompt.visible = false


func _process(_delta: float) -> void:
	_prompt.visible = _player_near and not is_open
	if _prompt.visible and Input.is_action_just_pressed("interact"):
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	if _game_state:
		_game_state.mark_chest_opened(chest_id)
		if loot:
			_game_state.obtain(loot)
	opened.emit(loot)
	var tween := create_tween()
	tween.tween_property(_lid, "rotation:x", 1.9, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_glow, "light_energy", 4.0, 0.2)
	tween.tween_property(_glow, "light_energy", 0.0, 0.8)
