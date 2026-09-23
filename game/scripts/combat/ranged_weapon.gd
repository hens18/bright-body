class_name RangedWeapon
extends Resource
## Data for one ranged weapon (bow, crossbow, spell). Create new ones as .tres files
## in res://resources/weapons/ and add them to the player's `weapons` list.

@export var display_name := "Weapon"
@export var projectile_scene: PackedScene
@export var color := Color.WHITE

@export_group("Damage")
@export var damage := 12.0
## Seconds between shots. For crossbows this is the reload time.
@export var cooldown := 0.3

@export_group("Flight")
@export var projectile_speed := 30.0
## 0 flies straight, 1 falls with full gravity.
@export var gravity_scale := 0.0
## How hard the shot steers toward the locked on target. 0 disables homing.
@export var homing_strength := 0.0

@export_group("Charge")
## Seconds to fully draw. 0 fires instantly on press; above 0 fires on release.
@export var charge_time := 0.0
## Damage and speed multiplier for a shot released with no draw at all.
@export_range(0.0, 1.0) var min_charge_scale := 0.35

@export_group("Cost")
@export var mana_cost := 0.0


## Scale applied to damage and speed for a given draw amount (0 to 1).
func charge_scale(charge: float) -> float:
	if charge_time <= 0.0:
		return 1.0
	return lerpf(min_charge_scale, 1.0, clampf(charge, 0.0, 1.0))
