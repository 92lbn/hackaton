# ============================================================
# RepairSystems.gd — Nœud : Node
# ============================================================
extends Node

signal reactor_updated(current: float, target: float)
signal oxygen_updated(pos: float)
signal signal_updated(current: Vector2, target: Vector2)
signal electric_updated(hits: int, needed: int)
signal door_updated(progress: float)
signal repair_flashed(system_id: int)

var reactor_value  := 0.5;  var reactor_target := 0.7
var oxygen_pos     := 0.0;  var oxygen_drift   := 1.0;  var oxygen_hold := 0.0
var signal_angle   := Vector2.ZERO;  var signal_target := Vector2(0.5, 0.3);  var signal_lock := 0.0
var electric_hits  := 0;    var electric_cool  := 0.0
var door_hold      := 0.0

var _launch_waiting := false
var _launch_system  := -1

func _ready() -> void:
	GameManager.connect("system_state_changed", _on_fail)
	GameManager.connect("launch_step_required", _on_launch_step)
	GameManager.connect("launch_success",       func(): _launch_waiting = false)

func _process(delta: float) -> void:
	if not GameManager.is_running() and not GameManager.is_launch_active(): return
	_reactor(delta); _oxygen(delta); _signal(delta); _electric(delta); _door(delta)

func _active(id: int) -> bool:
	return GameManager.is_system_failing(id) or (_launch_waiting and _launch_system == id)

func _reactor(delta: float) -> void:
	if not _active(0): return
	if Input.is_action_pressed("reactor_up"):   reactor_value = clampf(reactor_value + 0.7*delta, 0, 1)
	if Input.is_action_pressed("reactor_down"): reactor_value = clampf(reactor_value - 0.7*delta, 0, 1)
	emit_signal("reactor_updated", reactor_value, reactor_target)
	if abs(reactor_value - reactor_target) < 0.06: _repair(0)

func _oxygen(delta: float) -> void:
	if not _active(1): return
	oxygen_pos += oxygen_drift * 0.8 * delta
	if abs(oxygen_pos) >= 1.0: oxygen_drift *= -1.0
	if Input.is_action_pressed("oxygen_left"):  oxygen_pos -= 1.8 * delta
	if Input.is_action_pressed("oxygen_right"): oxygen_pos += 1.8 * delta
	oxygen_pos = clampf(oxygen_pos, -1, 1)
	emit_signal("oxygen_updated", oxygen_pos)
	if abs(oxygen_pos) < 0.15:
		oxygen_hold += delta
		if oxygen_hold >= 2.0: oxygen_hold = 0.0; _repair(1)
	else:
		oxygen_hold = maxf(oxygen_hold - delta * 0.5, 0)

func _signal(delta: float) -> void:
	if not _active(2): return
	var d := Vector2.ZERO
	if Input.is_action_pressed("signal_up"):    d.y -= 1
	if Input.is_action_pressed("signal_down"):  d.y += 1
	if Input.is_action_pressed("signal_left"):  d.x -= 1
	if Input.is_action_pressed("signal_right"): d.x += 1
	signal_angle = (signal_angle + d * 1.8 * delta).clamp(Vector2(-1,-1), Vector2(1,1))
	emit_signal("signal_updated", signal_angle, signal_target)
	if signal_angle.distance_to(signal_target) < 0.22:
		signal_lock += delta
		if signal_lock >= 1.2: signal_lock = 0.0; _repair(2)
	else:
		signal_lock = maxf(signal_lock - delta, 0)

func _electric(delta: float) -> void:
	if not _active(3): return
	electric_cool = maxf(electric_cool - delta, 0)
	if Input.is_action_just_pressed("electric_hit") and electric_cool <= 0:
		electric_hits += 1; electric_cool = 0.25
		emit_signal("electric_updated", electric_hits, 3)
		if electric_hits >= 3: electric_hits = 0; _repair(3)
	else:
		emit_signal("electric_updated", electric_hits, 3)

func _door(delta: float) -> void:
	if not _active(4): door_hold = 0.0; return
	if Input.is_action_pressed("door_scan"): door_hold += delta
	else: door_hold = maxf(door_hold - delta * 2, 0)
	emit_signal("door_updated", clampf(door_hold / 1.5, 0, 1))
	if door_hold >= 1.5: door_hold = 0.0; _repair(4)

func _repair(id: int) -> void:
	emit_signal("repair_flashed", id)
	if _launch_waiting and _launch_system == id:
		_launch_waiting = false; _launch_system = -1
		GameManager.validate_launch_step(id)
	elif GameManager.is_system_failing(id):
		GameManager.repair_system(id)

func _on_fail(id: int, _s: int) -> void:
	match id:
		0: reactor_target = randf_range(0.15, 0.85); reactor_value = randf_range(0, 1)
		1: oxygen_pos = randf_range(0.5, 0.9) * (1 if randf() > 0.5 else -1)
		2: signal_target = Vector2(randf_range(-0.7,0.7), randf_range(-0.7,0.7))
		3: electric_hits = 0
		4: door_hold = 0.0

func _on_launch_step(step: int, _a: String) -> void:
	var order := [0, 1, 2, 3, 4]
	_launch_waiting = true; _launch_system = order[step]
	_on_fail(_launch_system, 0)



func _on_start_pressed() -> void:
	pass # Replace with function body.

func _on_restart_pressed() -> void:
	pass # Replace with function body.
