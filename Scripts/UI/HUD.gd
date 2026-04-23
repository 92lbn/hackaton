# ============================================================
# HUD.gd — Nœud : CanvasLayer
# ============================================================
extends CanvasLayer

const COK  := Color(0, 0.85, 0.3)
const CWRN := Color(0.95, 0.75, 0)
const CCRT := Color(0.95, 0.15, 0.1)

@onready var timer_lbl:    Label       = $TimerLabel
@onready var alert_lbl:    Label       = $AlertLabel
@onready var event_lbl:    Label       = $EventLabel
@onready var panne_lbl:    Label       = $PanneLabel
@onready var approach_lbl: Label       = $ApproachLabel
@onready var start_pnl:    Panel       = $StartPanel
@onready var go_pnl:       Panel       = $GameOverPanel
@onready var go_reason:    Label       = $GameOverPanel/Reason
@onready var win_pnl:      Panel       = $WinPanel
@onready var launch_pnl:   Panel       = $LaunchPanel
@onready var launch_lbl:   Label       = $LaunchPanel/Action
@onready var launch_bar:   ProgressBar = $LaunchPanel/Bar
@onready var repair_pnl:    Panel = $RepairPanel
@onready var repair_title:  Label          = $RepairPanel/MarginContainer/VBoxContainer/Title
@onready var repair_status: Label          = $RepairPanel/MarginContainer/VBoxContainer/Status
@onready var repair_widget: Control  = $RepairPanel/MarginContainer/VBoxContainer/Widget

@onready var repair_sys: Node = get_node_or_null("../RepairSystems")

var _cur_system := -1
var _evt_timer  := 0.0

# ── Liste des pannes (créée par code) ─────────────────
var _fail_panel: Panel
var _fail_labels: Array[Label] = []

# ══════════════════════════════════════════════════════
func _ready() -> void:
	# Arduino
	if get_node_or_null("/root/ArduinoManager"):
		ArduinoManager.connect("arduino_connected",    _on_arduino_connected)
		ArduinoManager.connect("arduino_disconnected", _on_arduino_disconnected)
		ArduinoManager.connect("pairing_failed",       _on_pairing_failed)

	# GameManager
	GameManager.connect("system_state_changed",    _on_state)
	GameManager.connect("timer_updated",           _on_timer)
	GameManager.connect("failure_count_changed",   _on_failures)
	GameManager.connect("event_triggered",         _on_event)
	GameManager.connect("game_over",               _on_game_over)
	GameManager.connect("game_won",                func(): win_pnl.visible = true; launch_pnl.visible = false)
	GameManager.connect("launch_sequence_started", func(): launch_pnl.visible = true)
	GameManager.connect("launch_step_required",    func(i, a): launch_lbl.text = "ETAPE %d/5\n%s" % [i+1, a]; launch_bar.value = i * 20)

	# RepairSystems
	if repair_sys:
		repair_sys.connect("reactor_updated",  _reactor_ui)
		repair_sys.connect("oxygen_updated",   _oxygen_ui)
		repair_sys.connect("signal_updated",   _signal_ui)
		repair_sys.connect("electric_updated", _electric_ui)
		repair_sys.connect("door_updated",     _door_ui)

	# État initial
	go_pnl.visible     = false
	win_pnl.visible    = false
	launch_pnl.visible = false
	repair_pnl.visible = false
	approach_lbl.text  = ""
	alert_lbl.text     = ""
	panne_lbl.text     = ""

	# Créer le panneau de liste des pannes par code
	_create_fail_panel()

# ══ PANNEAU LISTE PANNES (créé par code) ══════════════
func _create_fail_panel() -> void:
	_fail_panel = Panel.new()
	_fail_panel.position = Vector2(20, 100)
	_fail_panel.size     = Vector2(220, 160)
	_fail_panel.visible  = false
	add_child(_fail_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(10, 8)
	vbox.size     = Vector2(200, 150)
	_fail_panel.add_child(vbox)

	# Titre
	var title := Label.new()
	title.text = "PANNES EN COURS"
	title.modulate = Color.WHITE
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	# Une ligne par système
	var names := ["VENTILATION", "TEMPERATURE", "LUMIERES UV", "PRESSION", "SAS"]
	for i in range(5):
		var lbl := Label.new()
		lbl.text = names[i]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.visible = false
		vbox.add_child(lbl)
		_fail_labels.append(lbl)

func _update_fail_panel() -> void:
	var any_fail := false
	for i in range(5):
		var state := GameManager.get_state(i)
		if state == GameManager.State.OK:
			_fail_labels[i].visible = false
		else:
			_fail_labels[i].visible = true
			any_fail = true
			if state == GameManager.State.WARNING:
				_fail_labels[i].text     = "⚠ " + GameManager.SYSTEM_NAMES[i]
				_fail_labels[i].modulate = CWRN
			else:
				_fail_labels[i].text     = "🔴 " + GameManager.SYSTEM_NAMES[i]
				_fail_labels[i].modulate = CCRT
	_fail_panel.visible = any_fail

# ══════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if _evt_timer > 0:
		_evt_timer -= delta
		event_lbl.modulate.a = clampf(_evt_timer / 2.0, 0.0, 1.0)

# ══ ARDUINO STATUS ════════════════════════════════════
func _on_arduino_connected() -> void:
	event_lbl.text     = "MANETTE CONNECTEE !"
	event_lbl.modulate = COK
	_evt_timer = 3.0

func _on_arduino_disconnected() -> void:
	event_lbl.text     = "MANETTE DECONNECTEE"
	event_lbl.modulate = CCRT
	_evt_timer = 999.0

func _on_pairing_failed() -> void:
	event_lbl.text     = "BRANCHER LA MANETTE..."
	event_lbl.modulate = CWRN
	_evt_timer = 999.0

# ══ PANEL 3D ═════════════════════════════════════════
func show_panel(id: int) -> void:
	_cur_system = id
	var names := ["VENTILATION", "TEMPERATURE", "LUMIERES UV", "PRESSION", "SAS"]
	repair_title.text = names[id]
	_refresh_panel()

func hide_panel() -> void:
	_cur_system        = -1
	repair_pnl.visible = false
	approach_lbl.text  = ""

func _refresh_panel() -> void:
	if _cur_system == -1: return
	var failing: bool = GameManager.is_system_failing(_cur_system)
	repair_pnl.visible = failing
	if not failing:
		approach_lbl.text = "NOMINAL"
	else:
		approach_lbl.text = ""
		var s: int = GameManager.get_state(_cur_system)
		repair_status.text     = "PANNE" if s == 1 else "CRITIQUE"
		repair_status.modulate = CWRN   if s == 1 else CCRT
		match _cur_system:
			0: repair_widget.get_node_or_null("Info").text = "TOURNER LE POTENTIOMETRE" if repair_widget.get_node_or_null("Info") else ""
			1: repair_widget.get_node_or_null("Info").text = "GLISSER LE SLIDER" if repair_widget.get_node_or_null("Info") else ""
			2: repair_widget.get_node_or_null("Info").text = "APPUYER SUR LE BOUTON JOYSTICK"
			3: repair_widget.get_node_or_null("Info").text = "TAPER SUR LE PIEZO" if repair_widget.get_node_or_null("Info") else ""
			4: repair_widget.get_node_or_null("Info").text = "SCANNER LE BADGE" if repair_widget.get_node_or_null("Info") else ""

# ══ TIMER ═════════════════════════════════════════════
func _on_timer(t: float) -> void:
	var m := int(t) / 60
	var s := int(t) % 60
	timer_lbl.text     = "%02d:%02d" % [m, s]
	timer_lbl.modulate = CCRT if t < 20 else CWRN if t < 45 else Color.WHITE

# ══ ALERTES ═══════════════════════════════════════════
func _on_failures(n: int) -> void:
	match n:
		0: alert_lbl.text = ""
		1: alert_lbl.text = "1 SYSTEME EN PANNE";  alert_lbl.modulate = CWRN
		2: alert_lbl.text = "2 SYSTEMES DANGER";   alert_lbl.modulate = Color.ORANGE
		_: alert_lbl.text = "SURCHARGE IMMINENTE"; alert_lbl.modulate = CCRT
	if get_node_or_null("/root/ArduinoManager"):
		ArduinoManager._send("alarm:" + ("1" if n > 0 else "0"))

func _on_event(txt: String) -> void:
	event_lbl.text     = txt
	event_lbl.modulate = Color.WHITE
	_evt_timer = 4.0

func _on_state(id: int, state: int) -> void:
	if state == 1 or state == 2:
		var nom: String = GameManager.SYSTEM_NAMES.get(id, "SYSTEME")
		panne_lbl.text     = nom + " EN PANNE — APPROCHEZ !"
		panne_lbl.modulate = CWRN if state == 1 else CCRT
	elif state == GameManager.State.OK:
		panne_lbl.text     = GameManager.SYSTEM_NAMES.get(id, "") + " REPARE !"
		panne_lbl.modulate = COK
	if id == _cur_system:
		_refresh_panel()
	# Mettre à jour la liste des pannes
	_update_fail_panel()

func _on_game_over(reason: String) -> void:
	go_pnl.visible     = true
	launch_pnl.visible = false
	go_reason.text     = reason

# ══ WIDGETS DE RÉPARATION ═════════════════════════════
func _reactor_ui(cur: float, tgt: float) -> void:
	if _cur_system != 0: return
	var bar:     ProgressBar = repair_widget.get_node_or_null("Bar")
	var bar_lbl: Label       = repair_widget.get_node_or_null("BarLabel")
	var info:    Label       = repair_widget.get_node_or_null("Info")
	if bar:     bar.value    = cur * 100
	if bar_lbl: bar_lbl.text = "Actuel : %.0f%%   Cible : %.0f%%" % [cur*100, tgt*100]
	var d : float = abs(cur - tgt)
	if bar:  bar.modulate    = COK if d < 0.06 else CWRN if d < 0.2 else CCRT
	if info: info.text       = "✅ DANS LA ZONE !" if d < 0.06 else "TOURNER LE POTENTIOMETRE"

func _oxygen_ui(pos: float) -> void:
	if _cur_system != 1: return
	var bar: ProgressBar = repair_widget.get_node_or_null("Bar")
	var lbl: Label       = repair_widget.get_node_or_null("Info")
	if bar: bar.value    = (pos + 1.0) / 2.0 * 100
	var ok: bool = abs(pos) < 0.15
	if bar: bar.modulate = COK if ok else CCRT
	if lbl: lbl.text     = "ZONE VERTE" if ok else "HORS ZONE\nGLISSER LE SLIDER"

func _signal_ui(cur: Vector2, tgt: Vector2) -> void:
	if _cur_system != 2: return
	var lbl: Label = repair_widget.get_node_or_null("Info")
	var hits: int = int(cur.x)
	var needed: int = int(tgt.x)
	if lbl:
		lbl.text     = "APPUIS : %d / %d\nAPPUYER SUR LE BOUTON JOYSTICK" % [hits, needed]
		lbl.modulate = COK if hits >= needed else Color.WHITE

func _electric_ui(hits: int, needed: int) -> void:
	if _cur_system != 3: return
	var lbl: Label = repair_widget.get_node_or_null("Info")
	if lbl: lbl.text = "FRAPPES : %d / %d\nTAPER SUR LE PIEZO" % [hits, needed]

func _door_ui(progress: float) -> void:
	if _cur_system != 4: return
	var bar: ProgressBar = repair_widget.get_node_or_null("Bar")
	var lbl: Label       = repair_widget.get_node_or_null("Info")
	if bar: bar.value    = progress * 100
	if lbl: lbl.text     = "SCANNER LE BADGE\n%.0f%%" % (progress * 100)

# ══ BOUTONS ═══════════════════════════════════════════
func _on_start_pressed() -> void:
	start_pnl.visible = false
	var player := get_node_or_null("../Player")
	if player: player.activate()
	GameManager.start_game()

func _on_restart_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().reload_current_scene()
