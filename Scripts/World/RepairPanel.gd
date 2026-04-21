# ============================================================
# RepairPanel.gd
# Nœud : Area3D
# Enfants : MeshInstance3D, CollisionShape3D, SpotLight3D
# ============================================================
extends Area3D

@export var system_id: int = 0

@onready var light: SpotLight3D = get_node_or_null("SpotLight3D")
@onready var mesh:  MeshInstance3D = get_node_or_null("MeshInstance3D")

func _ready() -> void:
	connect("body_entered", _on_enter)
	connect("body_exited",  _on_exit)
	GameManager.connect("system_state_changed", _on_state)
	_update_light(GameManager.State.OK)

func _on_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		var hud = get_node_or_null("/root/Main/HUD")
		if hud: hud.show_panel(system_id)

func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		var hud = get_node_or_null("/root/Main/HUD")
		if hud: hud.hide_panel()

func _on_state(id: int, state: int) -> void:
	if id == system_id: _update_light(state)

func _update_light(state: int) -> void:
	if not light: return
	match state:
		GameManager.State.OK:       light.light_color = Color(0, 1, 0.3);  light.light_energy = 1.0
		GameManager.State.WARNING:  light.light_color = Color(1, 0.6, 0);  light.light_energy = 2.5
		GameManager.State.CRITICAL: light.light_color = Color(1, 0.1, 0.1);light.light_energy = 4.0
