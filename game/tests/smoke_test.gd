extends SceneTree
## Headless smoke test: loads the main level, drives the player with simulated
## input and checks that core combat works. Run from the repo root with:
##   godot --headless --path game --script res://tests/smoke_test.gd

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Title screen: naming the hero stores the name and starts the game.
	var game_state := root.get_node("GameState") # Autoload names are not visible to --script runners.
	# Restored at the end so the test leaves the player's profile alone.
	var saved_name: String = game_state.hero_name
	var saved_appearance: HeroAppearance = game_state.appearance
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await _frames(3)
	var name_edit: LineEdit = current_scene.get_node("%NameEdit")
	name_edit.text = "  Sir Testalot  "
	name_edit.text_changed.emit(name_edit.text)
	var crimson := HeroAppearance.ARMOR_COLORS[1]
	(current_scene.get_node("%ArmorSwatches").get_child(1) as Button).pressed.emit()
	(current_scene.get_node("%HeightSlider") as HSlider).value = 1.08
	current_scene.get_node("%BeginButton").pressed.emit()
	await _frames(5)
	_check(game_state.hero_name == "Sir Testalot", "title screen stores the trimmed hero name")
	_check(current_scene.scene_file_path == "res://scenes/levels/main.tscn", "Begin starts the level")
	_check(current_scene.get_node("HUD/Bars/NameLabel").text == "Sir Testalot", "HUD shows the hero name")
	_check(game_state.appearance.armor_color == crimson and is_equal_approx(game_state.appearance.height, 1.08),
			"title screen stores the chosen look")
	_check(_armor_color(current_scene.get_node("Player/Visual/Hero")) == crimson,
			"hero model wears the chosen armor color")

	change_scene_to_file("res://scenes/levels/main.tscn")
	await _frames(5)
	var level := current_scene
	var player: Player = level.get_node("Player")
	var enemies := level.get_node("Enemies").get_children()
	_check(enemies.size() == 5, "level has 5 enemies")

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
	_check(brute.health.current < hp_before, "melee attack damages enemy (%.0f -> %.0f)" % [hp_before, brute.health.current])

	# Dodge spends stamina.
	var stamina_before := player.stamina
	Input.action_press("dodge")
	await _frames(2)
	Input.action_release("dodge")
	_check(player.stamina < stamina_before, "dodge spends stamina")
	await _seconds(0.5)

	# Ranged weapons. Lock on first so the shots have a target to home in on.
	Input.action_press("lock_on")
	await _frames(2)
	Input.action_release("lock_on")
	Input.action_press("aim")
	await _frames(2)

	# Longbow: hold to draw, release to fire.
	_check(player.current_weapon().display_name == "Longbow", "starts with the longbow")
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
	_check(player.current_weapon().display_name == "Crossbow", "Q switches to the crossbow")
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
	Input.action_press("lock_on")
	await _frames(2)
	Input.action_release("lock_on")
	_check(player.lock_target is Enemy, "lock on finds a target")

	# Enemies eventually fight back.
	await _seconds(4.0)
	_check(player.health.current < player.health.max_health, "enemies damage the player")

	# Killing every enemy counts down to zero.
	for enemy in level.get_node("Enemies").get_children():
		if enemy is Enemy and enemy.is_alive():
			enemy.health.take_damage(9999)
	await _seconds(0.6)
	_check(level.get_node("Enemies").get_child_count() == 0, "defeated enemies are removed")

	game_state.hero_name = saved_name
	game_state.appearance = saved_appearance
	game_state.save_profile()

	for failure in _failures:
		printerr("FAIL: ", failure)
	print("Smoke test: %s" % ("PASSED" if _failures.is_empty() else "FAILED"))
	quit(0 if _failures.is_empty() else 1)


func _armor_color(model: Node) -> Color:
	var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.get_surface_override_material(surface) as BaseMaterial3D
		if material and material.resource_name == "Body":
			return material.albedo_color
	return Color.TRANSPARENT


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
