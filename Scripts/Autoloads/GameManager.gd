# ============================================================
# GameManager.gd — AUTOLOAD
# Projet > Généraux > Chargement Auto > GameManager
# ============================================================
extends Node

signal system_state_changed(system_id: int, state: int)
signal game_over(reason: String)
signal game_won
signal timer_updated(seconds_left: float)
signal failure_count_changed(count: int)
signal event_triggered(text: String)
signal launch_sequence_started
signal launch_step_required(step_index: int, action: String)
signal launch_success

enum System  { REACTOR=0, OXYGEN=1, SIGNAL=2, ELECTRIC=3, DOOR=4 }
enum State   { OK=0, WARNING=1, CRITICAL=2 }

const SYSTEM_NAMES := {
	0: "VENTILATION",
	1: "TEMPERATURE",
	2: "LUMIERES UV",
	3: "PRESSION CUVES",
	4: "SAS CONFINEMENT"
}

const CASCADES := {
	0: [1, 3], 1: [], 2: [], 3: [4], 4: []
}

const EVENTS := [
	[20.0, "ALERTE : spores detectees dans le couloir B3"],
	[40.0, "SIGNAL CAPTE : quelqu'un... au secours..."],
	[60.0, "SURTENSION — contamination en cours !"],
]

const LAUNCH_SEQUENCE := [
	"Stabiliser le REACTEUR",
	"Pressuriser l'OXYGENE",
	"Verrouiller le SIGNAL",
	"Couper l'ELECTRIQUE",
	"Ouvrir les PORTES",
]

# ── Constantes de timing ────────────────────────────────────
const GAME_DURATION    := 120.0
const FIRST_FAIL_DELAY := 15.0
const FAIL_INTERVAL    := 20.0
const DEGRADE_TIME     := 12.0
const CASCADE_TIME     := 15.0
const MAX_ACTIVE_FAILS := 3

var system_states   := { 0:0, 1:0, 2:0, 3:0, 4:0 }
var game_timer      := GAME_DURATION
var _running        := false
var _elapsed        := 0.0
var _fail_timer     := 0.0
var _fail_interval  := FAIL_INTERVAL
var _next_event     := 0
var _cascade_timers := { 0:0.0, 1:0.0, 2:0.0, 3:0.0, 4:0.0 }
var _degrade_timers := { 0:0.0, 1:0.0, 2:0.0, 3:0.0, 4:0.0 }
var _launch_active  := false
var _launch_step    := 0
var _launch_timer   := 0.0

func _ready() -> void:
	for s in System.values():
		system_states[s]   = State.OK
		_cascade_timers[s] = 0.0
		_degrade_timers[s] = 0.0

func start_game() -> void:
	_running       = true
	game_timer     = GAME_DURATION
	_elapsed       = 0.0
	_fail_timer    = FIRST_FAIL_DELAY
	_fail_interval = FAIL_INTERVAL
	_next_event    = 0
	_launch_active = false
	_launch_step   = 0
	for s in System.values():
		system_states[s]   = State.OK
		_cascade_timers[s] = 0.0
		_degrade_timers[s] = 0.0
	emit_signal("failure_count_changed", 0)

func _process(delta: float) -> void:
	if not _running: return
	game_timer -= delta
	_elapsed   += delta
	emit_signal("timer_updated", game_timer)

	if _launch_active:
		_launch_timer += delta
		if _launch_timer >= 4.0:
			_end("SEQUENCE DE LANCEMENT ECHOUEE")
		return

	if game_timer <= 15.0 and not _launch_active:
		_start_launch()
		return

	if game_timer <= 0:
		_end("TEMPS ECOULE")
		return

	if _next_event < EVENTS.size() and _elapsed >= EVENTS[_next_event][0]:
		emit_signal("event_triggered", EVENTS[_next_event][1])
		if _next_event == 2: _spawn_fail(); _spawn_fail()
		_next_event += 1

	_fail_timer -= delta
	if _fail_timer <= 0:
		_spawn_fail()
		_fail_timer    = _fail_interval
		_fail_interval = maxf(_fail_interval - 0.4, 5.0)

	for s in System.values():
		if system_states[s] == State.WARNING:
			_degrade_timers[s] += delta
			if _degrade_timers[s] >= DEGRADE_TIME:
				_degrade_timers[s] = 0.0
				_set_state(s, State.CRITICAL)
		elif system_states[s] == State.CRITICAL:
			_cascade_timers[s] += delta
			if _cascade_timers[s] >= CASCADE_TIME:
				_cascade_timers[s] = 0.0
				for n in CASCADES.get(s, []):
					if system_states[n] == State.OK and _count_failing() < MAX_ACTIVE_FAILS:
						_set_state(n, State.WARNING)
		else:
			_degrade_timers[s] = 0.0
			_cascade_timers[s] = 0.0

func _count_failing() -> int:
	return system_states.values().filter(func(v): return v != State.OK).size()

func _spawn_fail() -> void:
	if _count_failing() >= MAX_ACTIVE_FAILS: return
	var ok := system_states.keys().filter(func(k): return system_states[k] == State.OK)
	if ok.is_empty(): return
	ok.shuffle()
	_set_state(ok[0], State.WARNING)

func _set_state(id: int, state: int) -> void:
	if system_states[id] == state: return
	system_states[id] = state
	emit_signal("system_state_changed", id, state)
	var fail := _count_failing()
	emit_signal("failure_count_changed", fail)
	if fail > MAX_ACTIVE_FAILS:
		_end("SURCHARGE TOTALE — %d SYSTEMES EN PANNE" % fail)

func repair_system(id: int) -> void:
	if system_states[id] != State.OK:
		_degrade_timers[id] = 0.0
		_cascade_timers[id] = 0.0
		_set_state(id, State.OK)

func _start_launch() -> void:
	_launch_active = true
	_launch_step   = 0
	_launch_timer  = 0.0
	emit_signal("launch_sequence_started")
	emit_signal("launch_step_required", 0, LAUNCH_SEQUENCE[0])

func validate_launch_step(id: int) -> void:
	if not _launch_active: return
	var order := [0, 1, 2, 3, 4]
	if id == order[_launch_step]:
		_launch_step  += 1
		_launch_timer  = 0.0
		if _launch_step >= LAUNCH_SEQUENCE.size():
			_running       = false
			_launch_active = false  # ← FIX : empêche RepairSystems de continuer après la victoire
			emit_signal("launch_success")
			emit_signal("game_won")
		else:
			emit_signal("launch_step_required", _launch_step, LAUNCH_SEQUENCE[_launch_step])
	else:
		_end("MAUVAISE SEQUENCE")

func _end(reason: String) -> void:
	_running = false
	emit_signal("game_over", "CONTAMINATION — " + reason)

func is_running()               -> bool:  return _running
func is_system_failing(id: int) -> bool:  return system_states.get(id, 0) != State.OK
func get_state(id: int)         -> int:   return system_states.get(id, State.OK)
func is_launch_active()         -> bool:  return _launch_active
func get_elapsed()              -> float: return _elapsed
