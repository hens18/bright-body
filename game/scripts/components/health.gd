class_name Health
extends Node
## Hit points for anything that can be damaged. Add as a child named "Health".

signal changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal died

@export var max_health := 100.0

var current: float
## While true, take_damage() is ignored (dodge frames, post hit grace, cutscenes).
var invulnerable := false
var is_dead := false


func _ready() -> void:
	current = max_health


## Returns true if the damage was applied.
func take_damage(amount: float, source: Node = null) -> bool:
	if is_dead or invulnerable or amount <= 0.0:
		return false
	current = maxf(current - amount, 0.0)
	damaged.emit(amount, source)
	changed.emit(current, max_health)
	if current <= 0.0:
		is_dead = true
		died.emit()
	return true


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current = minf(current + amount, max_health)
	changed.emit(current, max_health)
