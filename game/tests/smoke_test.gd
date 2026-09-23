extends SceneTree
## Headless smoke test: plays through the title screen and the arena with
## simulated input and checks the core features. Run from the repo root with:
##   godot --headless --path game --script res://tests/smoke_test.gd

const LEVEL := "res://scenes/levels/main.tscn"

var _failures: Array[String] = []
var game_state: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game_state = root.get_node("GameState") # Autoload names are not visible to --script runners.
	# The profile is restored at the end so the test leaves the player's save alone.
	var saved_profile := FileAccess.get_file_as_bytes(game_state.SAVE_PATH)

	await _test_character_creation()
	await _test_armor_chests()
	await _test_weapon_loot()
	await _test_combat()
	await _test_drops_and_mini_boss()
	await _test_checkpoints()

	if saved_profile.is_empty():
		DirAccess.remove_absolute(game_state.SAVE_PATH)
	else:
		FileAccess.open(game_state.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_profile)

	for failure in _failures:
		printerr("FAIL: ", failure)
	print("Smoke test: %s" % ("PASSED" if _failures.is_empty() else "FAILED"))
	quit(0 if _failures.is_empty() else 1)


func _test_character_creation() -> void:
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	while current_scene == null or current_scene.name != "TitleScreen":
		await _frames(1)
	var name_edit: LineEdit = current_scene.get_node("%NameEdit")
	name_edit.text = "  Sir Testalot  "
	name_edit.text_changed.emit(name_edit.text)
	var dark_skin := HeroAppearance.SKIN_TONES[4]
	(current_scene.get_node("%SkinSwatches").get_child(4) as Button).pressed.emit()
	(current_scene.get_node("%Hairstyle") as OptionButton).item_selected.emit(HeroAppearance.Hairstyle.LONG)
	(current_scene.get_node("%HeightSlider") as HSlider).value = 1.08
	current_scene.get_node("%BeginButton").pressed.emit()
	await _frames(5)
	_check(game_state.hero_name == "Sir Testalot", "title screen stores the trimmed hero name")
	_check(current_scene.scene_file_path == LEVEL, "Begin starts the level")
	_check(current_scene.get_node("HUD/Bars/NameLabel").text == "Sir Testalot", "HUD shows the hero name")
	_check(game_state.appearance.skin_tone == dark_skin and is_equal_approx(game_state.appearance.height, 1.08),
			"title screen stores the chosen body")
	var hero: Node = current_scene.get_node("Player/Visual/Hero")
	_check(_material_color(hero, "Skin") == dark_skin, "hero model has the chosen skin tone")
	_check(_part_visible(hero, "Hair_Long") and not _part_visible(hero, "Hair_Short"), "hero has the chosen hairstyle")
	_check(game_state.total_defense() == 0.0 and not _part_visible(hero, "Armor_Chest"), "new game starts without armor")


func _test_armor_chests() -> void:
	# Walk up to a chest, press interact: the armor is equipped and shown.
	var hero: Node = current_scene.get_node("Player/Visual/Hero")
	var chest: Node3D = current_scene.get_node("Chests/GauntletsChest")
	var player: Player = current_scene.get_node("Player")
	player.global_position = chest.global_position + Vector3(0, 0.1, 1.5)
	await _frames(4)
	_check(chest.get_node("Prompt").visible, "chest shows an open prompt nearby")
	await _tap("interact")
	_check(chest.is_open and game_state.total_defense() > 0.0, "interact opens the chest and grants armor")
	_check(_part_visible(hero, "Armor_Gauntlets"), "equipped gauntlets appear on the hero")
	_check(player.health.damage_multiplier < 1.0, "armor reduces damage taken")
	current_scene.get_node("Chests/HelmChest").open()
	await _frames(1)
	_check(_part_visible(hero, "Armor_Helmet") and not _part_visible(hero, "Hair_Long"), "a helmet hides the hair")

	# Opened chests stay opened after a reload.
	reload_current_scene()
	await _frames(5)
	_check(current_scene.get_node("Chests/GauntletsChest").is_open, "opened chests stay open after reloading")
	_check(not current_scene.get_node("Chests/CuirassChest").is_open, "unopened chests stay closed")


func _test_weapon_loot() -> void:
	game_state.new_game()
	change_scene_to_file(LEVEL)
	await _frames(5)
	var player: Player = current_scene.get_node("Player")
	var sword: MeleeWeapon = game_state.equipped_sword()
	_check(sword != null and sword.display_name == "Worn Sword" and player.weapons.is_empty(),
			"new game starts with only a worn sword")
	_check(current_scene.get_node("HUD/WeaponLabel").text == "No ranged weapon", "HUD shows no ranged weapon")

	current_scene.get_node("Chests/SwordChest").open()
	await _frames(1)
	_check(game_state.equipped_sword().display_name == "Iron Sword", "sword chest upgrades the sword")
	_check(_material_color(current_scene.get_node("Player/Visual/Hero"), "Blade") == game_state.equipped_sword().blade_color,
			"hero blade takes the new sword's color")
	for chest_name in ["BowChest", "CrossbowChest", "SpellChest"]:
		current_scene.get_node("Chests/" + chest_name).open()
	await _frames(1)
	var names := player.weapons.map(func(w: RangedWeapon) -> String: return w.display_name)
	_check(names == ["Hunting Bow", "Light Crossbow", "Arcane Bolt"], "chests grant low tier ranged weapons %s" % [names])


func _test_combat() -> void:
	var level := current_scene
	var player: Player = level.get_node("Player")
	var enemies := level.get_node("Enemies").get_children()
	_check(enemies.size() == 6, "level has 6 enemies")

	# Walk forward for a second.
	var start := player.global_position
	Input.action_press("move_forward")
	await _seconds(1.0)
	var anim: AnimationPlayer = player.visual.find_child("AnimationPlayer", true, false)
	_check(anim != null and anim.current_animation == "Run", "hero model plays Run while moving")
	Input.action_release("move_forward")
	_check(player.global_position.z < start.z - 3.0, "player walks forward (moved %.2f)" % (start.z - player.global_position.z))
	_check(player.is_on_floor(), "player stands on the floor")

	# Melee: put an enemy right in front of the player and swing.
	var brute: Enemy = enemies[0]
	brute.global_position = player.global_position + player.forward() * 1.5
	await _frames(2)
	var hp_before := brute.health.current
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	await _seconds(0.5)
	_check(is_equal_approx(hp_before - brute.health.current, 20.0 * 1.25),
			"iron sword melee hit deals 25 (%.0f -> %.0f)" % [hp_before, brute.health.current])

	# Dodge spends stamina.
	var stamina_before := player.stamina
	await _tap("dodge")
	_check(player.stamina < stamina_before, "dodge spends stamina")
	await _seconds(0.5)

	# Ranged weapons. Lock on first so the shots have a target to home in on.
	await _tap("lock_on")
	Input.action_press("aim")
	await _frames(2)

	# Bow: hold to draw, release to fire.
	_check(player.current_weapon().display_name == "Hunting Bow", "first ranged weapon is the bow")
	Input.action_press("attack")
	await _seconds(0.5)
	_check(player.draw_amount() > 0.4, "holding attack draws the bow (%.2f)" % player.draw_amount())
	_check(_count_shots(level) == 0, "bow does not fire while drawing")
	Input.action_release("attack")
	await _frames(3)
	_check(_count_shots(level) > 0, "releasing the bow fires an arrow")

	# Crossbow: fires on press, then has to reload.
	await _seconds(0.3)
	await _tap("switch_weapon")
	_check(player.current_weapon().display_name == "Light Crossbow", "Q switches to the crossbow")
	var before := _count_shots(level)
	await _tap("attack")
	await _tap("attack")
	_check(_count_shots(level) == before + 1, "crossbow fires once, then reloads")

	# Magic: costs mana.
	await _tap("switch_weapon")
	_check(player.current_weapon().display_name == "Arcane Bolt", "Q switches to magic")
	var mana_before := player.mana
	await _tap("attack")
	_check(player.mana < mana_before, "magic spends mana")
	Input.action_release("aim")
	await _tap("lock_on")

	# Lock on picks a living enemy.
	await _tap("lock_on")
	_check(player.lock_target is Enemy, "lock on finds a target")

	# Enemies eventually fight back.
	await _seconds(4.0)
	_check(player.health.current < player.health.max_health, "enemies damage the player")


func _test_drops_and_mini_boss() -> void:
	var level := current_scene
	var player: Player = level.get_node("Player")

	# A mob drop: the caster's Ember Bolt beats the Arcane Bolt from the chest.
	var caster: Enemy = level.get_node("Enemies/Caster2")
	caster.drop_chance = 1.0
	caster.health.take_damage(9999)
	await _frames(2)
	var drop := _find_drop(level)
	_check(drop != null, "defeated enemy drops loot")
	if drop:
		player.global_position = drop.global_position
		await _frames(4)
	_check(player.current_weapon().display_name == "Ember Bolt", "picking up a drop equips the stronger spell")

	# Mini boss: tough, super armor, drops a high tier sword and stays dead.
	var captain: Enemy = level.get_node("Enemies/BruteCaptain")
	_check(captain.health.max_health == 240.0, "brute captain has 240 health")
	captain.health.take_damage(10)
	_check(captain.state != Enemy.State.STAGGER, "brute captain is not staggered by hits")
	captain.health.take_damage(9999)
	await _frames(2)
	drop = _find_drop(level)
	if drop:
		player.global_position = drop.global_position
		await _frames(4)
	_check(game_state.equipped_sword().display_name == "Captain's Longsword", "brute captain drops a high tier sword")
	reload_current_scene()
	await _frames(5)
	_check(not current_scene.get_node("Enemies").get_children().any(
			func(e: Node) -> bool: return e.name == "BruteCaptain" and e.is_alive()),
			"defeated mini boss stays dead after reloading")
	_check(current_scene.get_node("Enemies/Caster2").is_alive(), "regular enemies come back after reloading")


func _test_checkpoints() -> void:
	var player: Player = current_scene.get_node("Player")
	var shrine: Node3D = current_scene.get_node("Checkpoints/CenterShrine")
	player.health.take_damage(30)
	player.global_position = shrine.spawn_position()
	await _frames(4)
	_check(shrine.is_lit and game_state.checkpoint_id == "CenterShrine", "touching a shrine lights it as the checkpoint")
	_check(player.health.current == player.health.max_health, "shrine restores health")

	# Die away from the shrine: the hero rises at the shrine a few seconds later.
	player.global_position = Vector3(0, 0.1, 20)
	await _frames(2)
	player.health.invulnerable = false
	player.health.take_damage(9999)
	await _seconds(3.5)
	var respawned: Player = current_scene.get_node("Player")
	_check(respawned != player and not respawned.health.is_dead, "hero respawns after dying")
	var respawn_shrine: Node3D = current_scene.get_node("Checkpoints/CenterShrine")
	_check(respawned.global_position.distance_to(respawn_shrine.spawn_position()) < 1.0,
			"hero respawns at the last checkpoint")

	# Killing every enemy counts down to zero.
	for enemy in current_scene.get_node("Enemies").get_children():
		if enemy is Enemy and enemy.is_alive():
			enemy.health.take_damage(9999)
	await _seconds(0.6)
	_check(current_scene.get_node("Enemies").get_child_count() == 0, "defeated enemies are removed")


func _find_drop(level: Node) -> Node3D:
	for child in level.get_children():
		if child.scene_file_path == "res://scenes/world/loot_drop.tscn":
			return child
	return null


func _material_color(model: Node, material_name: String) -> Color:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface) as BaseMaterial3D
			if material and material.resource_name == material_name:
				return material.albedo_color
	return Color.TRANSPARENT


func _part_visible(model: Node, part: String) -> bool:
	var mesh := model.find_child(part, true, false) as MeshInstance3D
	return mesh != null and mesh.visible


func _count_shots(level: Node) -> int:
	return level.get_children().filter(func(n: Node) -> bool: return n is Projectile and n.shooter is Player).size()


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(1)


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + label)
	if not condition:
		_failures.append(label)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(time: float) -> void:
	await create_timer(time, true, true).timeout
