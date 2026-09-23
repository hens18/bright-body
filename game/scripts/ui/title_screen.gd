extends Control
## Title screen and character creation: the player names their hero, picks armor
## and trim colors, height and build, then the adventure begins.

const FIRST_LEVEL := "res://scenes/levels/main.tscn"
const SWATCH_SIZE := Vector2(34, 34)

var _appearance: HeroAppearance

@onready var _name_edit: LineEdit = %NameEdit
@onready var _begin_button: Button = %BeginButton
@onready var _armor_swatches: GridContainer = %ArmorSwatches
@onready var _trim_swatches: GridContainer = %TrimSwatches
@onready var _height_slider: HSlider = %HeightSlider
@onready var _build_slider: HSlider = %BuildSlider
@onready var _preview_hero: Node3D = %PreviewHero


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_appearance = GameState.appearance.duplicate() as HeroAppearance

	_name_edit.max_length = GameState.MAX_NAME_LENGTH
	_name_edit.text = GameState.hero_name
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _begin())
	_begin_button.pressed.connect(_begin)
	_on_name_changed(_name_edit.text)

	_build_swatches(_armor_swatches, HeroAppearance.ARMOR_COLORS, "armor_color")
	_build_swatches(_trim_swatches, HeroAppearance.TRIM_COLORS, "trim_color")
	_setup_slider(_height_slider, HeroAppearance.HEIGHT_RANGE, "height")
	_setup_slider(_build_slider, HeroAppearance.BUILD_RANGE, "build")
	_refresh_preview()
	_name_edit.grab_focus()


func _process(delta: float) -> void:
	_preview_hero.rotate_y(delta * 0.6)


func _build_swatches(grid: GridContainer, colors: Array[Color], property: StringName) -> void:
	var group := ButtonGroup.new()
	for color in colors:
		var swatch := Button.new()
		swatch.custom_minimum_size = SWATCH_SIZE
		swatch.toggle_mode = true
		swatch.button_group = group
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.tooltip_text = color.to_html(false)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			swatch.add_theme_stylebox_override(state, _swatch_style(color, state.ends_with("pressed")))
		swatch.button_pressed = color.is_equal_approx(_appearance.get(property))
		swatch.pressed.connect(func() -> void:
			_appearance.set(property, color)
			_refresh_preview())
		grid.add_child(swatch)


func _swatch_style(color: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.set_border_width_all(3 if selected else 1)
	style.border_color = Color(1, 0.9, 0.6) if selected else Color(0, 0, 0, 0.6)
	return style


func _setup_slider(slider: HSlider, value_range: Vector2, property: StringName) -> void:
	slider.min_value = value_range.x
	slider.max_value = value_range.y
	slider.step = 0.01
	slider.value = _appearance.get(property)
	slider.value_changed.connect(func(value: float) -> void:
		_appearance.set(property, value)
		_refresh_preview())


func _refresh_preview() -> void:
	_appearance.apply(_preview_hero)


func _on_name_changed(text: String) -> void:
	_begin_button.disabled = text.strip_edges().is_empty()


func _begin() -> void:
	if _begin_button.disabled:
		return
	GameState.appearance = _appearance
	GameState.set_hero_name(_name_edit.text) # Also saves the appearance.
	get_tree().change_scene_to_file(FIRST_LEVEL)
