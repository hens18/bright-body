extends CanvasLayer
## Hero name, health, stamina and mana bars, current weapon, bow draw meter,
## crosshair, lock on marker and center screen messages.

var player: Player:
	set = set_player

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _mana_bar: ProgressBar = %ManaBar
@onready var _name_label: Label = %NameLabel
@onready var _weapon_label: Label = %WeaponLabel
@onready var _draw_bar: ProgressBar = %DrawBar
@onready var _enemy_label: Label = %EnemyLabel
@onready var _message: Label = %Message
@onready var _crosshair: Control = %Crosshair
@onready var _lock_marker: Control = %LockMarker
@onready var _damage_flash: ColorRect = %DamageFlash


func set_player(value: Player) -> void:
	player = value
	player.health.changed.connect(_on_health_changed)
	player.health.damaged.connect(_on_player_damaged)
	player.stamina_changed.connect(_on_stamina_changed)
	player.mana_changed.connect(_on_mana_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	_on_health_changed(player.health.current, player.health.max_health)
	_on_stamina_changed(player.stamina, player.max_stamina)
	_on_mana_changed(player.mana, player.max_mana)
	_on_weapon_changed(player.current_weapon())
	_name_label.text = GameState.display_name()


func _process(_delta: float) -> void:
	if player == null:
		return
	_crosshair.visible = player.is_aiming()
	var draw := player.draw_amount()
	_draw_bar.visible = draw > 0.0
	_draw_bar.value = draw
	var target := player.lock_target
	var show_marker := target != null and is_instance_valid(target) \
			and not player.camera.is_position_behind(target.global_position)
	_lock_marker.visible = show_marker
	if show_marker:
		var screen := player.camera.unproject_position(target.global_position + Vector3.UP * 1.1)
		_lock_marker.position = screen - _lock_marker.size * 0.5


func set_enemies_remaining(count: int) -> void:
	_enemy_label.text = "Enemies: %d" % count


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = true


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current


func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina_bar.max_value = maximum
	_stamina_bar.value = current


func _on_mana_changed(current: float, maximum: float) -> void:
	_mana_bar.max_value = maximum
	_mana_bar.value = current


func _on_weapon_changed(weapon: RangedWeapon) -> void:
	_weapon_label.text = weapon.display_name if weapon else ""


func _on_player_damaged(_amount: float, _source: Node) -> void:
	_damage_flash.color.a = 0.35
	create_tween().tween_property(_damage_flash, "color:a", 0.0, 0.3)
