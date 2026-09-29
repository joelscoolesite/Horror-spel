class_name Door
extends Interactable
## Een deur of kastdeur die draait rond een scharnier.
##  - E: snel open/dicht (maakt veel lawaai!)
##  - Linkermuisknop vasthouden + muis naar beneden: langzaam opentrekken.
## De node zelf staat op de plek van het scharnier.

signal opened ## als de deur ver genoeg open is om erin te kijken

var width := 0.9
var height := 2.05
var thickness := 0.05
var open_sign := 1.0 ## 1 of -1: welke kant hij opendraait
var max_angle := 100.0
var is_closet := false
var locked := false
var material: Material

var angle := 0.0 ## hoe ver open, in graden
var was_opened := false ## is hij (deze nacht) al opengeweest?
var held := false

var _pivot: Node3D
var _creak: AudioStreamPlayer3D
var _target := -1.0
var _last_angle := 0.0
var _creak_level := 0.0


func build() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	var body := AnimatableBody3D.new()
	body.collision_layer = Build.LAYER_WORLD | Build.LAYER_INTERACT
	body.sync_to_physics = false
	body.position = Vector3(width * 0.5, height * 0.5, 0)
	_pivot.add_child(body)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width - 0.02, height, thickness)
	shape.shape = bs
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	bm.subdivide_height = 2
	mesh.mesh = bm
	mesh.material_override = material
	body.add_child(mesh)
	# klink
	var knob_mat := Build.mat("metal", Color(0.8, 0.75, 0.6))
	for side in [-1.0, 1.0]:
		Build.box(body, Vector3(0.1, 0.03, 0.04), Vector3(width * 0.5 - 0.12, -0.06 if not is_closet else 0.0, side * (thickness * 0.5 + 0.02)), knob_mat, false)
	_creak = AudioStreamPlayer3D.new()
	_creak.stream = Sfx.stream("creak_loop")
	_creak.bus = "SFX"
	_creak.volume_db = -80.0
	_creak.unit_size = 2.0
	_creak.position = Vector3(width * 0.5, height * 0.5, 0)
	add_child(_creak)
	_apply()


func get_prompt() -> String:
	if angle > 30.0:
		return "[E] Close"
	return "[E] Open   [Hold LMB] Pull slowly"


func interact(_player: Node) -> void:
	if locked:
		Sfx.play_at("door_close", global_position, -12.0, 1.6)
		if Game.hud:
			Game.hud.say("It won't open.")
		return
	if angle > 30.0:
		_target = 0.0
	else:
		_target = max_angle
		Sfx.play_at("creak_fast", _creak.global_position, -2.0, randf_range(0.9, 1.1))


func can_drag() -> bool:
	return not locked


func drag_begin() -> void:
	held = true
	_target = -1.0


func drag(motion: Vector2) -> void:
	# Muis naar beneden = naar je toe trekken = open.
	set_angle(angle + motion.y * 0.18)


func drag_end() -> void:
	held = false


func set_angle(a: float) -> void:
	angle = clampf(a, 0.0, max_angle)
	_apply()


## Direct dicht zonder geluid (bijv. aan het begin van een nacht).
func reset_closed() -> void:
	_target = -1.0
	angle = 0.0
	_last_angle = 0.0
	was_opened = false
	_apply()


func _apply() -> void:
	if _pivot:
		_pivot.rotation_degrees.y = angle * open_sign
	if angle > 45.0 and not was_opened:
		was_opened = true
		opened.emit()
		if is_closet:
			Game.closet_opened.emit(self)


func _process(delta: float) -> void:
	if _pivot == null:
		return
	if _target >= 0.0:
		set_angle(move_toward(angle, _target, 260.0 * delta))
		if is_equal_approx(angle, _target):
			_target = -1.0
	# Piepen: hoe sneller je trekt, hoe harder.
	var speed := absf(angle - _last_angle) / maxf(delta, 0.0001)
	_creak_level = lerpf(_creak_level, clampf(speed / 90.0, 0.0, 1.0), 10.0 * delta)
	if _creak_level > 0.03:
		if not _creak.playing:
			_creak.play(randf() * 1.5)
		_creak.volume_db = linear_to_db(_creak_level) - 4.0
		_creak.pitch_scale = 0.8 + _creak_level * 0.5
	elif _creak.playing:
		_creak.stop()
	if _last_angle > 2.0 and angle <= 0.5:
		Sfx.play_at("door_close", _creak.global_position, -6.0 if not is_closet else -10.0, 1.0 if not is_closet else 1.4)
	_last_angle = angle
