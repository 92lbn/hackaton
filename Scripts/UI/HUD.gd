# ============================================================
# HUD.gd — Nœud : CanvasLayer
# ============================================================
extends CanvasLayer

const COK  := Color(0,0.85,0.3)
const CWRN := Color(0.95,0.75,0)
const CCRT := Color(0.95,0.15,0.1)

@onready var timer_lbl:   Label       = $TimerLabel
@onready var alert_lbl:   Label       = $AlertLabel
@onready var event_lbl:   Label       = $EventLabel
@onready var start_pnl:   Panel       = $StartPanel
@onready var go_pnl:      Panel       = $GameOverPanel
@onready var go_reason:   Label       = $GameOverPanel/Reason
@onready var win_pnl:     Panel       = $WinPanel
@onready var launch_pnl:  Panel       = $LaunchPanel
@onready var launch_lbl:  Label       = $LaunchPanel/Action
@onready var launch_bar:  ProgressBar = $LaunchPanel/Bar
@onready var repair_pnl:  Panel       = $RepairPanel
@onready var repair_title:Label       = $RepairPanel/Title
@onready var repair_status:Label      = $RepairPanel/Status
@onready var repair_widget:Control    = $RepairPanel/Widget
@onready var approach_lbl:Label       = $ApproachLabel
@onready var panne_lbl:Label          = $PanneLabel

@onready var repair_sys: Node = get_node_or_null("../RepairSystems")

var _arduino_pot_rot:    float   = 0.5
var _arduino_pot_slider: float   = 0.5
var _arduino_joy:        Vector2 = Vector2(0.5, 0.5)
var _arduino_piezo:      bool    = false
var _arduino_rfid:       bool    = false

var _cur_system := -1
var _evt_timer  := 0.0

func _ready() -> void:
	ArduinoManager.connect("arduino_connected",    _on_arduino_connected)
	ArduinoManager.connect("arduino_disconnected", _on_arduino_disconnected)
	ArduinoManager.connect("pairing_failed",       _on_pairing_failed)
	GameManager.connect("system_state_changed", _on_state)
	GameManager.connect("timer_updated",        _on_timer)
	GameManager.connect("failure_count_changed",_on_failures)
	GameManager.connect("event_triggered",      _on_event)
	GameManager.connect("game_over",            _on_game_over)
	GameManager.connect("game_won",             func(): win_pnl.visible = true; launch_pnl.visible = false)
	GameManager.connect("launch_sequence_started", func(): launch_pnl.visible = true; event_lbl.text = "SEQUENCE DE LANCEMENT")
	GameManager.connect("launch_step_required", func(i,a): launch_lbl.text = "ETAPE %d/5\n%s"%[i+1,a]; launch_bar.value = i*20)
	if Engine.has_singleton("ArduinoManager") or get_node_or_null("/root/ArduinoManager"):
		ArduinoManager.connect("data_received", _on_arduino_data)
		print("[RepairSystems] Arduino connecté !")
	if repair_sys:
		repair_sys.connect("reactor_updated",  _reactor_ui)
		repair_sys.connect("oxygen_updated",   _oxygen_ui)
		repair_sys.connect("signal_updated",   _signal_ui)
		repair_sys.connect("electric_updated", _electric_ui)
		repair_sys.connect("door_updated",     _door_ui)

	go_pnl.visible    = false
	win_pnl.visible   = false
	launch_pnl.visible= false
	repair_pnl.visible= false
	approach_lbl.text = ""

func _on_arduino_connected() -> void:
	event_lbl.text     = "🎛️ MANETTE CONNECTEE !"
	event_lbl.modulate = COK
	_evt_timer = 3.0

func _on_arduino_disconnected() -> void:
	event_lbl.text     = "⚠️ MANETTE DECONNECTEE"
	event_lbl.modulate = CCRT
	_evt_timer = 999.0

func _on_pairing_failed() -> void:
	event_lbl.text     = "🔌 BRANCHER LA MANETTE..."
	event_lbl.modulate = CWRN
	_evt_timer = 999.0

func _on_arduino_data(key: String, value: String) -> void:
	match key:
		"pot_rot":
			_arduino_pot_rot = clampf(value.to_float() / 1023.0, 0.0, 1.0)
		"pot_slider":
			_arduino_pot_slider = clampf(value.to_float() / 1023.0, 0.0, 1.0)
		"joy":
			var parts := value.split(",")
			if parts.size() == 2:
				_arduino_joy = Vector2(
					clampf(parts[0].to_float() / 1023.0, 0.0, 1.0),
					clampf(parts[1].to_float() / 1023.0, 0.0, 1.0)
				)
		"piezo":
			if value.to_int() > 300:
				_arduino_piezo = true
		"rfid":
			_arduino_rfid = (value == "1")
# ============================================================
func _process(delta: float) -> void:
	if _evt_timer > 0:
		_evt_timer -= delta
		event_lbl.modulate.a = clampf(_evt_timer / 2.0, 0, 1)

# ============================================================
# Appelé par RepairPanel.gd
# ============================================================
func show_panel(id: int) -> void:
	_cur_system = id
	var names := ["REACTEUR","OXYGENE","SIGNAL","ELECTRIQUE","PORTES"]
	repair_title.text = names[id]
	_refresh_panel()

func hide_panel() -> void:
	_cur_system = -1
	repair_pnl.visible  = false
	approach_lbl.text   = ""

func _refresh_panel() -> void:
	if _cur_system == -1: return
	var failing := GameManager.is_system_failing(_cur_system)
	repair_pnl.visible = failing
	if not failing:
		approach_lbl.text = "✅ NOMINAL — rien a faire"
	else:
		approach_lbl.text = ""
		var s := GameManager.get_state(_cur_system)
		repair_status.text    = "PANNE" if s == GameManager.State.WARNING else "CRITIQUE"
		repair_status.modulate= CWRN   if s == GameManager.State.WARNING else CCRT

# ============================================================
func _on_timer(t: float) -> void:
	var m := int(t)/60; var s := int(t)%60
	timer_lbl.text     = "%02d:%02d" % [m, s]
	timer_lbl.modulate = CCRT if t < 20 else CWRN if t < 45 else Color.WHITE

func _on_failures(n: int) -> void:
	match n:
		0: alert_lbl.text = ""
		1: alert_lbl.text = "1 SYSTEME EN PANNE";   alert_lbl.modulate = CWRN
		2: alert_lbl.text = "2 SYSTEMES — DANGER";  alert_lbl.modulate = Color.ORANGE
		_: alert_lbl.text = "SURCHARGE IMMINENTE";  alert_lbl.modulate = CCRT

func _on_event(txt: String) -> void:
	event_lbl.text = txt; event_lbl.modulate = Color.WHITE; _evt_timer = 4.0

func _on_state(id: int, state: int) -> void:
	if state == GameManager.State.WARNING or state == GameManager.State.CRITICAL:
		var nom: String = GameManager.SYSTEM_NAMES.get(id, "SYSTEME")
		panne_lbl.text     = "⚠️ " + nom + " EN PANNE — ALLEZ REPARER !"
		panne_lbl.modulate = CWRN if state == GameManager.State.WARNING else CCRT
	elif state == GameManager.State.OK:
		panne_lbl.text     = "✅ " + GameManager.SYSTEM_NAMES.get(id, "") + " REPARE !"
		panne_lbl.modulate = COK
	if id == _cur_system:
		_refresh_panel()

func _on_game_over(reason: String) -> void:
	go_pnl.visible    = true
	launch_pnl.visible= false
	go_reason.text    = reason

# ============================================================
# Widgets de réparation (dans $RepairPanel/Widget)
# Le widget change selon le système actif
# ============================================================
func _reactor_ui(cur: float, tgt: float) -> void:
	if _cur_system != 0: return
	var bar: ProgressBar = repair_widget.get_node_or_null("Bar")
	var lbl: Label       = repair_widget.get_node_or_null("Info")
	if bar: bar.value    = cur * 100
	if lbl: lbl.text     = "CIBLE : %.0f%%\n+/- pour regler" % (tgt * 100)
	var d: float = abs(cur - tgt)
	if bar: bar.modulate = COK if d < 0.06 else CWRN if d < 0.2 else CCRT

func _oxygen_ui(pos: float) -> void:
	if _cur_system != 1: return
	var bar: ProgressBar = repair_widget.get_node_or_null("Bar")
	var lbl: Label       = repair_widget.get_node_or_null("Info")
	if bar: bar.value    = (pos + 1.0) / 2.0 * 100
	var ok: bool = abs(pos) < 0.15
	if bar: bar.modulate = COK if ok else CCRT
	if lbl: lbl.text     = "ZONE VERTE" if ok else "HORS ZONE\n← → pour centrer"

func _signal_ui(cur: Vector2, tgt: Vector2) -> void:
	if _cur_system != 2: return
	var lbl: Label = repair_widget.get_node_or_null("Info")
	var d := cur.distance_to(tgt)
	if lbl:
		lbl.text     = "SIGNAL VERROUILLE" if d < 0.22 else "PROCHE...\nWASD" if d < 0.5 else "CHERCHER\nWASD"
		lbl.modulate = COK if d < 0.22 else CWRN if d < 0.5 else Color.WHITE

func _electric_ui(hits: int, needed: int) -> void:
	if _cur_system != 3: return
	var lbl: Label = repair_widget.get_node_or_null("Info")
	if lbl: lbl.text = "FRAPPES : %d / %d\n[ESPACE]" % [hits, needed]

func _door_ui(progress: float) -> void:
	if _cur_system != 4: return
	var bar: ProgressBar = repair_widget.get_node_or_null("Bar")
	var lbl: Label       = repair_widget.get_node_or_null("Info")
	if bar: bar.value    = progress * 100
	if lbl: lbl.text     = "MAINTENIR [R]\n%.0f%%" % (progress * 100)

# ============================================================
func _on_start_pressed() -> void:
	print("BOUTON CLIQUE !")
	start_pnl.visible = false
	var player := get_node_or_null("../Player")
	if player: player.activate()
	GameManager.start_game()

func _on_restart_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().reload_current_scene()
