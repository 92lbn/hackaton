# ============================================================
# Player.gd — Mouvement via joystick Arduino
# Nœud : CharacterBody3D + groupe "player"
# ============================================================
extends CharacterBody3D

const SPEED   := 5.0
const GRAVITY := 9.8
const SENS    := 0.002

@onready var head:       Node3D = $Head
@onready var repair_sys: Node   = get_node_or_null("/root/Main/RepairSystems")

var _active := false

func _ready() -> void:
	GameManager.connect("game_over", func(_r): _stop())
	GameManager.connect("game_won",  func():   _stop())

func activate() -> void:
	_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _stop() -> void:
	_active = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	# Rotation caméra avec la souris
	if event is InputEventMouseMotion and _active:
		rotate_y(-event.relative.x * SENS)
		head.rotate_x(-event.relative.y * SENS)
		head.rotation.x = clampf(head.rotation.x, -1.4, 1.4)
	# Échap pour libérer la souris
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)

func _physics_process(delta: float) -> void:
	if not _active: return
	if not is_on_floor(): velocity.y -= GRAVITY * delta

	# Joystick 2 → rotation caméra (comme une souris)
	if repair_sys:
		var joy2: Vector2 = repair_sys.arduino_joy2
		var jx2 := (joy2.x - 0.5) * 2.0
		var jy2 := (joy2.y - 0.5) * 2.0
		if abs(jx2) < 0.15: jx2 = 0.0
		if abs(jy2) < 0.15: jy2 = 0.0
		rotate_y(jx2 * delta * 2.0)
		#head.rotate_x(-jy2 * delta * 2.0)
		#head.rotation.x = clampf(head.rotation.x, -1.4, 1.4)

	# Joystick 1 → déplacement
	var dir := Vector3.ZERO
	if repair_sys:
		var joy: Vector2 = repair_sys.arduino_joy
		var jx := (joy.x - 0.5) * 2.0
		var jy := (joy.y - 0.5) * 2.0
		if abs(jx) < 0.15: jx = 0.0
		if abs(jy) < 0.15: jy = 0.0
		dir = (transform.basis * Vector3(jx, 0, jy)).normalized()
		dir.y = 0

	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()
