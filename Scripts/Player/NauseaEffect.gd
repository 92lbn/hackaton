extends Camera3D

@export var snd_niveau1: AudioStream
@export var snd_niveau2: AudioStream
@export var snd_niveau3: AudioStream
@export var snd_niveau4: AudioStream
@export var snd_niveau5: AudioStream

@onready var ambiance: AudioStreamPlayer = get_node_or_null("/root/Main/AmbianceSnd")

var _time:         float = 0.0
var _intensity:    float = 0.0
var _origin_rot:   Vector3
var _niveau_actuel := 0

func _ready() -> void:
	_origin_rot = rotation
	GameManager.connect("failure_count_changed", _on_failures)
	GameManager.connect("game_over", func(_r): _intensity = 0.0)
	GameManager.connect("game_won",  func():   _intensity = 0.0)
	if ambiance and snd_niveau1:
		ambiance.stream = snd_niveau1
		ambiance.play()

func _process(delta: float) -> void:
	if _intensity <= 0.0: return
	_time += delta
	var sway_x := sin(_time * 0.4) * 0.3 * _intensity
	var sway_y := sin(_time * 0.6) * 0.2 * _intensity
	var sway_z := sin(_time * 0.3) * 0.25 * _intensity
	if _intensity > 0.6:
		sway_x += sin(_time * 8.0) * 0.015 * _intensity
		sway_y += cos(_time * 9.0) * 0.01 * _intensity
	rotation = _origin_rot + Vector3(sway_x, sway_y, sway_z)

func _on_failures(count: int) -> void:
	print("NAUSEE niveau : ", count)
	var target: float
	var nouveau_niveau := 0
	match count:
		0: target = 0.0; nouveau_niveau = 1
		1: target = 0.3; nouveau_niveau = 2
		2: target = 0.7; nouveau_niveau = 3
		3: target = 0.9; nouveau_niveau = 4
		_: target = 1.0; nouveau_niveau = 5
	var tween := create_tween()
	tween.tween_property(self, "_intensity", target, 1.5)
	if nouveau_niveau != _niveau_actuel and ambiance:
		_niveau_actuel = nouveau_niveau
		match nouveau_niveau:
			1: ambiance.stream = snd_niveau1
			2: ambiance.stream = snd_niveau2
			3: ambiance.stream = snd_niveau3
			4: ambiance.stream = snd_niveau4
			5: ambiance.stream = snd_niveau5
		ambiance.play()
