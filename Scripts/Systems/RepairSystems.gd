# ============================================================
# RepairSystems.gd — Nœud : Node
# Toutes les mécaniques de réparation via Arduino uniquement
# ============================================================
extends Node

signal reactor_updated(current: float, target: float)
signal oxygen_updated(pos: float)
signal signal_updated(current: Vector2, target: Vector2)
signal electric_updated(hits: int, needed: int)
signal door_updated(progress: float)
signal repair_flashed(system_id: int)


# ── Variables Arduino ──────────────────────────────────
var arduino_joy:         Vector2 = Vector2(0.5, 0.5)  # Joystick X,Y (0-1)
var _arduino_pot_rot:    float   = 0.5                 # Potentiomètre rotatif (0-1)
var _arduino_pot_slider: float   = 0.5                 # Slider (0-1)
var _arduino_piezo:      bool    = false               # Choc piézo
var _arduino_rfid:       bool    = false               # Badge RFID

# ── Variables de jeu ───────────────────────────────────
var reactor_value  := 0.5;  var reactor_target := 0.7
var oxygen_pos     := 0.0;  var oxygen_drift   := 1.0;  var oxygen_hold := 0.0
var signal_angle   := Vector2.ZERO
var signal_target  := Vector2(0.5, 0.3)
var signal_lock    := 0.0
var electric_hits  := 0;    var electric_cool  := 0.0
var door_hold      := 0.0
var _arduino_button: bool = false

var signal_hits: int = 0
var signal_cool: float = 0.0

var _launch_waiting := false
var _launch_system  := -1

# ══════════════════════════════════════════════════════
func _ready() -> void:
	GameManager.connect("system_state_changed", _on_fail)
	GameManager.connect("launch_step_required", _on_launch_step)
	GameManager.connect("launch_success", func(): _launch_waiting = false)
	# Attendre que tout soit prêt avant de connecter Arduino
	call_deferred("_connect_arduino")

func _connect_arduino() -> void:
	if get_node_or_null("/root/ArduinoManager"):
		ArduinoManager.connect("data_received", _on_arduino_data)
		print("[RepairSystems] Arduino connecté !")
	else:
		print("[RepairSystems] Pas d'Arduino")

func _process(delta: float) -> void:
	if not GameManager.is_running() and not GameManager.is_launch_active(): return
	
	# DEBUG — affiche les valeurs Arduino toutes les secondes
	if Engine.get_process_frames() % 60 == 0:
		print("=== ARDUINO DEBUG ===")
		print("  joystick     : ", arduino_joy)
		print("  pot_rotatif  : ", _arduino_pot_rot)
		print("  slider       : ", _arduino_pot_slider)
		print("  piezo        : ", _arduino_piezo)
		print("  rfid         : ", _arduino_rfid)
		print("  button       : ", _arduino_button)  # ← ajoute cette ligne
		print("  reactor_val  : ", reactor_value, " / cible : ", reactor_target)
		print("  oxygen_pos   : ", oxygen_pos)
		print("  signal_angle : ", signal_angle, " / cible : ", signal_target)
		print("  electric_hits: ", electric_hits)
		print("  door_hold    : ", door_hold)
	
	_reactor(delta)
	_oxygen(delta)
	_signal_sys(delta)
	_electric(delta)
	_door(delta)

func _active(id: int) -> bool:
	return GameManager.is_system_failing(id) or (_launch_waiting and _launch_system == id)

# ══ RÉACTEUR — Potentiomètre rotatif ══════════════════
# Tourner jusqu'à la valeur cible ± 6%
func _reactor(delta: float) -> void:
	if not _active(0): return
	reactor_value = _arduino_pot_rot
	emit_signal("reactor_updated", reactor_value, reactor_target)
	if abs(reactor_value - reactor_target) < 0.06:
		_repair(0)

# ══ OXYGÈNE — Slider ══════════════════════════════════
# Maintenir le slider dans la zone centrale 2 secondes
func _oxygen(delta: float) -> void:
	if not _active(1): return
	# Dérive automatique
	oxygen_pos += oxygen_drift * 0.8 * delta
	if abs(oxygen_pos) >= 1.0: oxygen_drift *= -1.0
	# Slider Arduino : 0-1 → -1 à 1
	var slider_pos := (_arduino_pot_slider - 0.5) * 2.0
	oxygen_pos = clampf(oxygen_pos + slider_pos * 1.5 * delta, -1.0, 1.0)
	emit_signal("oxygen_updated", oxygen_pos)
	if abs(oxygen_pos) < 0.15:
		oxygen_hold += delta
		if oxygen_hold >= 2.0:
			oxygen_hold = 0.0
			_repair(1)
	else:
		oxygen_hold = maxf(oxygen_hold - delta * 0.5, 0.0)

# ══ SIGNAL — Joystick (bouton) ════════════════════════
# Orienter vers la cible avec le joystick
func _signal_sys(delta: float) -> void:
	if not _active(2): return
	signal_cool = maxf(signal_cool - delta, 0.0)
	if _arduino_button and signal_cool <= 0:
		_arduino_button = false
		signal_hits += 1
		signal_cool = 0.5
		emit_signal("signal_updated", Vector2(signal_hits, 0), Vector2(3, 0))
		if signal_hits >= 3:
			signal_hits = 0
			_repair(2)
	else:
		emit_signal("signal_updated", Vector2(signal_hits, 0), Vector2(3, 0))

# ══ ÉLECTRIQUE — Piézo ════════════════════════════════
# Taper 3 fois fort sur le piézo
func _electric(delta: float) -> void:
	if not _active(3): return
	electric_cool = maxf(electric_cool - delta, 0.0)
	if _arduino_piezo and electric_cool <= 0:
		_arduino_piezo = false
		electric_hits  += 1
		electric_cool   = 0.4
		emit_signal("electric_updated", electric_hits, 3)
		if electric_hits >= 3:
			electric_hits = 0
			_repair(3)
	else:
		emit_signal("electric_updated", electric_hits, 3)

# ══ PORTES — RFID ═════════════════════════════════════
# Scanner le badge RFID
func _door(delta: float) -> void:
	if not _active(4):
		door_hold = 0.0
		return
	if _arduino_rfid:
		door_hold += delta
	else:
		door_hold = maxf(door_hold - delta * 2.0, 0.0)
	emit_signal("door_updated", clampf(door_hold / 1.5, 0.0, 1.0))
	if door_hold >= 1.5:
		door_hold    = 0.0
		_arduino_rfid = false
		_repair(4)

# ══ RÉPARATION ════════════════════════════════════════
func _repair(id: int) -> void:
	emit_signal("repair_flashed", id)
	# Vibration feedback
	if get_node_or_null("/root/ArduinoManager"):
		ArduinoManager.send_vibe(150)
	if _launch_waiting and _launch_system == id:
		_launch_waiting = false
		_launch_system  = -1
		GameManager.validate_launch_step(id)
	elif GameManager.is_system_failing(id):
		GameManager.repair_system(id)

# ══ CALLBACKS ═════════════════════════════════════════
func _on_fail(id: int, _s: int) -> void:
	match id:
		0: reactor_target = randf_range(0.15, 0.85); reactor_value = randf_range(0.0, 1.0)
		1: oxygen_pos = randf_range(0.5, 0.9) * (1 if randf() > 0.5 else -1)
		2: signal_target = Vector2(randf_range(-0.7, 0.7), randf_range(-0.7, 0.7))
		3: electric_hits = 0
		4: door_hold = 0.0

func _on_launch_step(step: int, _a: String) -> void:
	var order := [0, 1, 2, 3, 4]
	_launch_waiting = true
	_launch_system  = order[step]
	_on_fail(_launch_system, 0)

# ══ DONNÉES ARDUINO ═══════════════════════════════════
func _on_arduino_data(key: String, value: String) -> void:
	match key:
		"pot_rot":
			_arduino_pot_rot = clampf(value.to_float() / 1023.0, 0.0, 1.0)
		"pot_slider":
			_arduino_pot_slider = clampf(value.to_float() / 1023.0, 0.0, 1.0)
		"joy":
			var parts := value.split(",")
			if parts.size() == 2:
				arduino_joy = Vector2(
					clampf(parts[0].to_float() / 1023.0, 0.0, 1.0),
					clampf(parts[1].to_float() / 1023.0, 0.0, 1.0)
				)
		"piezo":
			if value.to_int() > 300:
				_arduino_piezo = true
		"rfid":
			if value == "1":
				_arduino_rfid = true
		"button":
			if value == "1":
				_arduino_button = true
