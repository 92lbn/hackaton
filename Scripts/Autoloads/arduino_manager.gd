# arduino_manager.gd
extends Node

# ── Signaux ────────────────────────────────────────────
signal arduino_disconnected()
signal arduino_connected()
signal pairing_success(port: String)
signal pairing_failed()
signal button_changed(pressed: bool)
signal data_received(key: String, value: String)

# ── Constantes de pairing ──────────────────────────────
const DISCOVER_MSG  := "DISCOVER"
const ACK_PREFIX    := "GDSERIAL_ACK"
const BAUD_RATE     := 115200

# ── État interne ───────────────────────────────────────
var serial: GdSerial
var _paired: bool    = false
var _wasPaired: bool = false
var _buffer: String  = ""
var paired_port: String = ""
var timerHeartBeat: float    = 0.0
var timerHeartBeatMax: float = 2.0
var lastPortNameUsed

func _ready() -> void:
	serial = GdSerial.new()
	serial.set_baud_rate(BAUD_RATE)
	serial.set_timeout(10)
	serial.set_port("COM8")
	if serial.open():
		_paired = true
		_wasPaired = true
		paired_port = "COM8"
		print("[Arduino] Connecté sur COM8 !")
		emit_signal("arduino_connected")
	else:
		print("[Arduino] Impossible d'ouvrir COM8")
		emit_signal("pairing_failed")

# ══ PAIRING ═══════════════════════════════════════════

func start_pairing() -> void:
	_paired      = false
	_wasPaired   = false
	paired_port  = ""
	var ports: Dictionary = serial.list_ports()
	if ports.is_empty():
		emit_signal("pairing_failed")
		return
	_scan_ports(ports.values())

func _scan_ports(port_list: Array) -> void:
	for port_info in port_list:
		var port_name: String = port_info["port_name"]
		serial.set_port(port_name)
		if not serial.open():
			continue
		serial.clear_buffer()
		await get_tree().create_timer(0.5).timeout
		for i in range(3):
			serial.writeline(DISCOVER_MSG)
			await get_tree().create_timer(0.1).timeout
			var response := _read_all_available()
			if ACK_PREFIX in response:
				paired_port    = port_name
				_paired        = true
				_wasPaired     = true
				lastPortNameUsed = port_name
				print("[Pairing] CONNECTÉ sur ", port_name)
				emit_signal("pairing_success", port_name)
				emit_signal("arduino_connected")
				return
		serial.close()
	
	# Pas d'Arduino trouvé — continuer sans
	print("[Pairing] Pas d'Arduino — mode sans manette")
	emit_signal("pairing_failed")
	# NE PAS relancer le scan automatiquement !

func _read_all_available() -> String:
	var result := ""
	if serial.bytes_available() > 0:
		result = serial.read_string(serial.bytes_available())
	return result

# ══ COMMUNICATION EN TEMPS RÉEL ════════════════════════

func _process(_delta: float) -> void:
	timerHeartBeat -= _delta
	if _paired:
		if timerHeartBeat < 0:
			timerHeartBeat = timerHeartBeatMax
			if not serial.is_open():
				emit_signal("arduino_disconnected")
				_paired = false


	while serial.bytes_available() > 0:
		_buffer += serial.read_string(serial.bytes_available())

	while "\n" in _buffer:
		var idx  := _buffer.find("\n")
		var line := _buffer.substr(0, idx).strip_edges()
		_buffer   = _buffer.substr(idx + 1)
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
		"pong":       print("[Arduino] Latence : ", Time.get_ticks_msec() - parts[1].to_int(), " ms")
		"ack":        print("[Arduino] Ack : ", parts[1])
		"joy2":   emit_signal("data_received", "joy2",    parts[1])
		"button2": emit_signal("data_received", "button2", parts[1])
		_:            pass

# ══ API PUBLIQUE ══════════════════════════════════════

func send_vibe(duration_ms: int = 200) -> void:
	_send("vibe:" + str(duration_ms))

func send_led(on: bool) -> void:
	_send("led:" + ("1" if on else "0"))

func send_ping() -> void:
	_send("ping:" + str(Time.get_ticks_msec()))

func _send(cmd: String) -> void:
	if not _paired:
		return
	serial.writeline(cmd)

func is_connected_to_arduino() -> bool:
	return _paired

func _exit_tree() -> void:
	if serial and serial.is_open():
		serial.close()
