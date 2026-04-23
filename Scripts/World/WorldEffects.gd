# ============================================================
# WorldEffects.gd — Nœud : Node
# À ajouter dans main.tscn
# ============================================================
extends Node

@onready var world_env: WorldEnvironment = get_node_or_null("../WorldEnvironment")

var _fog_active    := false
var _fog_timer     := 0.0
const FOG_DURATION := 20.0

var _mushrooms: Array = []

func _ready() -> void:
	GameManager.connect("event_triggered", _on_event)

func _process(delta: float) -> void:
	if not _fog_active: return
	_fog_timer -= delta

	var env := world_env.environment

	if _fog_timer <= 5.0:
		env.fog_density = clampf((_fog_timer / 5.0) * 0.08, 0.0, 0.08)
	
	if _fog_timer <= 0.0:
		env.fog_enabled = false
		_fog_active     = false

func _on_event(text: String) -> void:
	if "spores" in text:
		_start_fog()
	if "contamination" in text:
		_spawn_mushrooms()

func _start_fog() -> void:
	if world_env == null: return
	var env := world_env.environment
	env.fog_enabled     = true
	env.fog_light_color = Color(0.1, 0.9, 0.2)
	env.fog_density     = 0.08
	_fog_active         = true
	_fog_timer          = FOG_DURATION

func _spawn_mushrooms() -> void:
	for i in range(50):
		var mushroom := MeshInstance3D.new()
		
		# Tailles très variées
		var mesh := CapsuleMesh.new()
		mesh.radius = randf_range(0.02, 0.3)
		mesh.height = randf_range(0.1, 1.2)
		mushroom.mesh = mesh
		
		# Matériau vert moisissure
		var mat := StandardMaterial3D.new()
		var colors := [
			Color(0.2, 0.5, 0.05),
			Color(0.15, 0.4, 0.1),
			Color(0.3, 0.55, 0.0),
			Color(0.1, 0.35, 0.05),
			Color(0.25, 0.45, 0.15),
		]
		var c: Color = colors[randi() % colors.size()]
		mat.albedo_color               = c
		mat.emission_enabled           = true
		mat.emission                   = c * 0.6
		mat.emission_energy_multiplier = randf_range(1.0, 4.0)
		mushroom.material_override     = mat
		
		# Position aléatoire dans la map
		var pos := Vector3(
			randf_range(-5.0, 5.0),
			0.0,
			randf_range(-5.0, 5.0)
		)
		mushroom.position = pos
		mushroom.scale    = Vector3.ZERO
		
		get_parent().add_child(mushroom)
		_mushrooms.append(mushroom)
		
		# Animation BOUNCE scale 0 → 1
		var tween := create_tween()
		tween.tween_property(mushroom, "scale", Vector3.ONE, 0.6)\
			.set_trans(Tween.TRANS_ELASTIC)\
			.set_ease(Tween.EASE_OUT)\
			.set_delay(i * 0.1)
