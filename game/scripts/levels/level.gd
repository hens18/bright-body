extends Node3D
## Wires a level together: hooks the HUD to the player and tracks remaining enemies.
## Put enemies under the "Enemies" node so they are counted.

@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD
@onready var enemies: Node3D = $Enemies

var _remaining := 0


func _ready() -> void:
	hud.player = player
	for enemy in enemies.get_children():
		if enemy is Enemy:
			_remaining += 1
			enemy.defeated.connect(_on_enemy_defeated)
	hud.set_enemies_remaining(_remaining)
	player.health.died.connect(_on_player_died)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()


func _on_enemy_defeated(_enemy: Enemy) -> void:
	_remaining -= 1
	hud.set_enemies_remaining(_remaining)
	if _remaining == 0:
		hud.show_message("Area cleared!\nPress R to play again")


func _on_player_died() -> void:
	hud.show_message("You fell.\nPress R to try again")
