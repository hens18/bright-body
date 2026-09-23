extends Area3D
## An item dropped by a defeated enemy. Floats and spins until the player walks
## into it, then goes to GameState like chest loot.

@export var item: Resource

var _time := 0.0

@onready var _game_state: Node = get_node_or_null(^"/root/GameState")
@onready var _gem: Node3D = $Gem
@onready var _label: Label3D = $Label


func _ready() -> void:
	_label.text = item.display_name if item else ""
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_gem.rotation.y += delta * 2.0
	_gem.position.y = 0.8 + sin(_time * 3.0) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player") or item == null:
		return
	if _game_state:
		_game_state.obtain(item)
	item = null
	queue_free()
