# arduino_manager.gd
extends Node

# ── Signaux ────────────────────────────────────────────
signal arduino_disconnected()
signal arduino_connected()
signal pairing_failed()
signal button_changed(pressed: bool)
signal data_received(key: String, value: String)

# ── Constantes ─────────────────────────────────────────
const BAUD_RATE := 115200

# ── État interne ───────────────────────────────────────
var serial: GdSerial
var _paired: bool = false
var _buffer: String = ""

func _ready() -> void:
	serial = GdSerial.new()
	serial.set_baud_rate(BAUD_RATE)
	serial.set_timeout(10)
	
	# --- CONFIGURATION DU PORT ---
	# Sur Windows : "COM3", "COM8", etc.
	# Sur Mac : "/dev/tty.usbmodemXXXX"
	serial.set_port("COM8") 
	
	if serial.open():
		_paired = true
		print("[Arduino] Connecté sur le port spécifié !")
		emit_signal("arduino_connected")
	else:
		print("[Arduino] Erreur : Impossible d'ouvrir le port.")
		emit_signal("pairing_failed")

# ══ COMMUNICATION EN TEMPS RÉEL ════════════════════════

func _process(_delta: float) -> void:
	if not _paired:
		return

	# Vérification sommaire de la connexion
	if not serial.is_open():
		_paired = false
		emit_signal("arduino_disconnected")
		return

	# Lecture des données entrantes
	while serial.bytes_available() > 0:
		_buffer += serial.read_string(serial.bytes_available())

	# Découpage par ligne (\n)
	while "\n" in _buffer:
		var idx := _buffer.find("\n")
		var line := _buffer.substr(0, idx).strip_edges()
		_buffer = _buffer.substr(idx + 1)
		if line.length() > 0:
			_parse_message(line)

func _parse_message(msg: String) -> void:
	var parts := msg.split(":", false, 1)
	if parts.size() < 2:
		return
		
	match parts[0]:
		"pot_rot":    emit_signal("data_received", "pot_rot",    parts[1])
		"pot_slider": emit_signal("data_received", "pot_slider", parts[1])
		"joy":        emit_signal("data_received", "joy",        parts[1])
		"piezo":      emit_signal("data_received", "piezo",      parts[1])
		"rfid":       emit_signal("data_received", "rfid",       parts[1])
		"button":
				emit_signal("button_changed", parts[1] == "1")
				emit_signal("data_received", "button", parts[1])
		"joy2":       emit_signal("data_received", "joy2",       parts[1])
		"button2":    emit_signal("data_received", "button2",    parts[1])
		"pong":       print("[Arduino] Latence : ", Time.get_ticks_msec() - parts[1].to_int(), " ms")
		_:            pass

# ══ API PUBLIQUE ══════════════════════════════════════

func send_vibe(duration_ms: int = 200) -> void:
	_send("vibe:" + str(duration_ms))

func send_led(on: bool) -> void:
	_send("led:" + ("1" if on else "0"))

func _send(cmd: String) -> void:
	if _paired and serial.is_open():
		serial.writeline(cmd)

func is_connected_to_arduino() -> bool:
	return _paired

func _exit_tree() -> void:
	if serial and serial.is_open():
		serial.close()
