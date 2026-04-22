# ============================================================
# NauseaEffect.gd — Effet de nausée sur la caméra
# Attacher sur Camera3D dans main.tscn
# ============================================================
extends Camera3D

var _time:      float = 0.0
var _intensity: float = 0.0  # 0 = normal, 1 = max nausée
var _origin_rot: Vector3

func _ready() -> void:
	_origin_rot = rotation
	GameManager.connect("failure_count_changed", _on_failures)
	GameManager.connect("game_over",  func(_r): _intensity = 0.0)
	GameManager.connect("game_won",   func():   _intensity = 0.0)

func _process(delta: float) -> void:
	if _intensity <= 0.0: return
	_time += delta

	# Plus fort !
	var sway_x := sin(_time * 0.4) * 0.3 * _intensity
	var sway_y := sin(_time * 0.6) * 0.2 * _intensity
	var sway_z := sin(_time * 0.3) * 0.25 * _intensity

	# Tremblement rapide si CRITIQUE
	if _intensity > 0.6:
		sway_x += sin(_time * 8.0) * 0.015 * _intensity
		sway_y += cos(_time * 9.0) * 0.01 * _intensity

	rotation = _origin_rot + Vector3(sway_x, sway_y, sway_z)

func _on_failures(count: int) -> void:
	print("NAUSEE niveau : ", count)
	var target: float
	match count:
		0: target = 0.0
		1: target = 0.3
		2: target = 0.7
		3: target = 0.9
		_: target = 1.0
	var tween := create_tween()
	tween.tween_property(self, "_intensity", target, 1.5)
	
