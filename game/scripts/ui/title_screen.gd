extends Control
## Title screen: the player names their hero, then the adventure begins.

const FIRST_LEVEL := "res://scenes/levels/main.tscn"

@onready var _name_edit: LineEdit = %NameEdit
@onready var _begin_button: Button = %BeginButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_name_edit.max_length = GameState.MAX_NAME_LENGTH
	_name_edit.text = GameState.hero_name
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _begin())
	_begin_button.pressed.connect(_begin)
	_on_name_changed(_name_edit.text)
	_name_edit.grab_focus()


func _on_name_changed(text: String) -> void:
	_begin_button.disabled = text.strip_edges().is_empty()


func _begin() -> void:
	if _begin_button.disabled:
		return
	GameState.set_hero_name(_name_edit.text)
	get_tree().change_scene_to_file(FIRST_LEVEL)
