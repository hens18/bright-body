extends SceneTree
## Headless smoke test: loads the main level, drives the player with simulated
## input and checks that core combat works. Run from the repo root with:
##   godot --headless --path game --script res://tests/smoke_test.gd

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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

	# Ranged: aim and fire, a projectile should spawn.
	Input.action_press("aim")
	await _frames(2)
	Input.action_press("attack")
	await _frames(3)
	Input.action_release("attack")
	Input.action_release("aim")
	var shots := level.get_children().filter(func(n): return n is Projectile)
	_check(shots.size() > 0, "aimed attack fires a projectile")

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

	for failure in _failures:
		printerr("FAIL: ", failure)
	print("Smoke test: %s" % ("PASSED" if _failures.is_empty() else "FAILED"))
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + label)
	if not condition:
		_failures.append(label)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(time: float) -> void:
	await create_timer(time, true, true).timeout
