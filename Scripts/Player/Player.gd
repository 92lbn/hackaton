# ============================================================
# Player.gd
# Nœud : CharacterBody3D
# Enfants : CollisionShape3D (Capsule), Head/Node3D, Head/Camera3D
# Groupe : "player"
# ============================================================
extends CharacterBody3D

const SPEED   := 5.0
const GRAVITY := 9.8
const SENS    := 0.002

@onready var head: Node3D = $Head

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
	if event is InputEventMouseMotion and _active:
		rotate_y(-event.relative.x * SENS)
		head.rotate_x(-event.relative.y * SENS)
		head.rotation.x = clampf(head.rotation.x, -1.4, 1.4)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)

func _physics_process(delta: float) -> void:
	if not _active: return
	if not is_on_floor(): velocity.y -= GRAVITY * delta
	var d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(d.x, 0, d.y)).normalized()
	dir.y   = 0
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()
