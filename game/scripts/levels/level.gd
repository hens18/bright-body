extends Node3D
## Wires a level together: hooks the HUD to the player, tracks remaining enemies,
## and handles death: the hero rises again at the last lit checkpoint (or the
## level start). Enemies come back on respawn; opened chests and defeated mini
## bosses do not. Put enemies under the "Enemies" node so they are counted.

const RESPAWN_DELAY := 3.0

@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD
@onready var enemies: Node3D = $Enemies
@onready var _game_state: Node = get_node_or_null(^"/root/GameState")

var _remaining := 0


func _ready() -> void:
	_place_player_at_checkpoint()
	hud.player = player
	for enemy in enemies.get_children():
		if enemy is Enemy and enemy.is_alive():
			_remaining += 1
			enemy.defeated.connect(_on_enemy_defeated)
	hud.set_enemies_remaining(_remaining)
	player.health.died.connect(_on_player_died)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		respawn()


## Reloads the level; the player then starts at the last checkpoint.
func respawn() -> void:
	get_tree().reload_current_scene()


func _place_player_at_checkpoint() -> void:
	if _game_state == null or _game_state.checkpoint_scene != scene_file_path:
		return
	for checkpoint in get_tree().get_nodes_in_group(&"checkpoint"):
		if checkpoint.checkpoint_id == _game_state.checkpoint_id:
			player.global_position = checkpoint.spawn_position()
			return


func _on_enemy_defeated(_enemy: Enemy) -> void:
	_remaining -= 1
	hud.set_enemies_remaining(_remaining)
	if _remaining == 0:
		hud.show_message("Area cleared!")


func _on_player_died() -> void:
	hud.show_message("You fell.\nRising at the last checkpoint...")
	# A connection (not await) so it is dropped if R reloads the level first.
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(respawn)
