# ============================================================
# Cinematic.gd — Cinématique d'intro
# Nœud : Node3D (scène séparée : Cinematic.tscn)
# ============================================================
extends Node3D

signal cinematic_finished

# Nœuds
@onready var camera:        Camera3D       = $CinematicCamera
@onready var anim:          AnimationPlayer = $AnimationPlayer
@onready var text_panel:    Panel          = $HUD/TextPanel
@onready var text_label:    Label          = $HUD/TextPanel/Label
@onready var start_panel:   Panel          = $HUD/StartPanel
@onready var start_btn:     Button         = $HUD/StartPanel/StartButton
@onready var vignette:      ColorRect      = $HUD/Vignette
@onready var light_main:    DirectionalLight3D = $LightMain
@onready var light_green:   OmniLight3D    = $LightGreen
@onready var light_violet:  OmniLight3D    = $LightViolet
@onready var mushrooms:     Node3D         = $Mushrooms
@onready var particles:     GPUParticles3D = $SporeParticles

@onready var ambiance_cine: AudioStreamPlayer = $AmbianceCinematic
@export var snd_intro: AudioStream
@export var snd_contamination: AudioStream

# Textes de la cinématique
const TEXTS := [
	["Jour 247.", 1.5],
	["L'expérience a réussi.", 1.5],
	["Le champignon Mycovita-7 guérit les cellules nerveuses.", 2.5],
	["Je suis fière.", 2.0],
	["...", 1.0],
	["Qu'est-ce que c'est que ce bruit ?", 1.5],
	["NON—", 0.8],
	["NON NON NON—", 0.5],
	["SORTEZ DU LABORATOIRE !", 1.0],
]

var _text_index := 0
var _typing := false
var _skip_pressed := false

# ============================================================
func _ready() -> void:
	start_panel.visible  = false
	text_panel.visible   = false
	light_green.visible  = false
	light_violet.visible = false
	vignette.modulate.a  = 1.0  # Noir au début
	
	# Cacher tous les champignons
	for m in mushrooms.get_children():
		m.scale = Vector3.ZERO
	
	# Lancer la cinématique
	_start()

# ============================================================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_skip()

# ============================================================
func _start() -> void:
	# Fondu depuis le noir
	var tween := create_tween()
	tween.tween_property(vignette, "modulate:a", 0.0, 2.0)
	tween.tween_callback(_phase_calm)

# ============================================================
# PHASE 1 — Calme, labo propre
# ============================================================
func _phase_calm() -> void:
	if ambiance_cine and snd_intro:
		ambiance_cine.stream = snd_intro
		ambiance_cine.play()
	text_panel.visible = true
	await _type_texts(0, 3)  # Textes 0 à 3
	await get_tree().create_timer(0.5).timeout
	_phase_trouble()

# ============================================================
# PHASE 2 — Ça tourne mal
# ============================================================
func _phase_trouble() -> void:
	
	# Lumières qui vacillent
	_flicker_lights()
	await get_tree().create_timer(1.0).timeout
	
	# Texte "..."
	await _type_text(TEXTS[4][0], TEXTS[4][1])
	
	# Son d'alarme (si FMOD dispo)
	# FmodServer.play_one_shot("event:/Alarm", self)
	
	await _type_text(TEXTS[5][0], TEXTS[5][1])
	
	_phase_contamination()

# ============================================================
# PHASE 3 — Contamination
# ============================================================
func _phase_contamination() -> void:
	if ambiance_cine and snd_contamination:
		ambiance_cine.stream = snd_contamination
		ambiance_cine.play()
	# Lumières vertes/violettes
	var tween := create_tween().set_parallel(true)
	tween.tween_property(light_main,   "light_color",  Color(0.1, 0.05, 0.1), 1.0)
	tween.tween_property(light_main,   "light_energy", 0.3, 1.0)
	tween.tween_property(light_green,  "visible",      true, 0.0)
	tween.tween_property(light_violet, "visible",      true, 0.0)
	tween.tween_property(light_green,  "light_energy", 3.0, 1.5)
	tween.tween_property(light_violet, "light_energy", 2.0, 1.5)
	
	# Vignette verte
	var tween2 := create_tween()
	tween2.tween_property(vignette, "color", Color(0.0, 0.3, 0.1, 0.4), 1.5)
	
	# Champignons qui poussent !
	_grow_mushrooms()
	
	# Particules de spores
	particles.emitting = true
	
	await get_tree().create_timer(1.0).timeout
	
	# Textes de panique
	await _type_text(TEXTS[6][0], TEXTS[6][1])
	await _type_text(TEXTS[7][0], TEXTS[7][1])
	
	# Caméra qui tremble
	_shake_camera()
	
	await get_tree().create_timer(0.8).timeout
	await _type_text(TEXTS[8][0], TEXTS[8][1])
	
	await get_tree().create_timer(0.5).timeout
	
	_phase_door()

# ============================================================
# PHASE 4 — Marche vers la porte
# ============================================================
func _phase_door() -> void:
	text_panel.visible = false
	
	var start_angle: float = camera.rotation_degrees.y
	var end_angle: float = start_angle - 45.0
	
	var tween := create_tween().set_parallel(true)
	
	# Avance sur l'axe X
	tween.tween_property(camera, "position", 
		Vector3(camera.position.x + 8.0, camera.position.y, camera.position.z), 
		3.0).set_trans(Tween.TRANS_SINE)
	
	# Tourne 90° depuis l'angle actuel
	tween.tween_method(_rotate_camera, start_angle, end_angle, 5.0)
	
	await tween.finished
	
	# Fade to black
	var fade := create_tween()
	fade.tween_property(vignette, "modulate:a", 1.0, 1.5)
	await fade.finished
	
	_phase_start()

func _rotate_camera(angle: float) -> void:
	camera.rotation_degrees.y = angle

# ============================================================
# PHASE 5 — Bouton DEMARRER
# ============================================================
func _phase_start() -> void:
	# Changer la couleur de la vignette en noir
	vignette.color = Color(0, 0, 0, 1)
	
	# Afficher le texte final
	text_panel.visible = true
	text_label.text    = ""
	
	await _type_text("RÉPAREZ LES SYSTÈMES.\nSORTEZ VIVANTE.", 2.0)
	
	await get_tree().create_timer(1.0).timeout
	
	# Afficher le bouton
	start_panel.visible = true
	var tween := create_tween()
	tween.tween_property(start_panel, "modulate:a", 1.0, 1.0)

# ============================================================
# HELPERS
# ============================================================
func _type_text(text: String, duration: float) -> void:
	text_label.text = ""
	var delay : float = duration / max(text.length(), 1) * 0.5
	for c in text:
		text_label.text += c
		await get_tree().create_timer(delay).timeout
	await get_tree().create_timer(duration * 0.5).timeout

func _type_texts(from: int, to: int) -> void:
	for i in range(from, to + 1):
		await _type_text(TEXTS[i][0], TEXTS[i][1])

func _flicker_lights() -> void:
	for i in range(6):
		var t := create_tween()
		t.tween_property(light_main, "light_energy", randf_range(0.1, 1.5), 0.08)
		await get_tree().create_timer(0.1).timeout
	var t2 := create_tween()
	t2.tween_property(light_main, "light_energy", 1.0, 0.2)

func _grow_mushrooms() -> void:
	for m in mushrooms.get_children():
		var delay: float = randf_range(0.0, 1.5)
		var duration: float = randf_range(0.5, 1.2)
		_grow_one(m, delay, duration)

func _grow_one(m: Node3D, delay: float, duration: float) -> void:
	await get_tree().create_timer(delay).timeout
	var tween := create_tween()
	tween.tween_property(m, "scale", Vector3(1, 1, 1), duration).set_trans(Tween.TRANS_BOUNCE)
func _shake_camera() -> void:
	for i in range(20):
		var tween := create_tween()
		var offset := Vector3(randf_range(-0.05, 0.05), randf_range(-0.03, 0.03), 0)
		tween.tween_property(camera, "position", camera.position + offset, 0.05)
		await get_tree().create_timer(0.05).timeout

func _skip() -> void:
	if _skip_pressed: return
	_skip_pressed = true
	get_tree().change_scene_to_file("res://main.tscn")

# ============================================================
func _on_start_pressed() -> void:
	var fade := create_tween()
	fade.tween_property(vignette, "modulate:a", 1.0, 1.0)
	await fade.finished
	get_tree().change_scene_to_file("res://main.tscn")
