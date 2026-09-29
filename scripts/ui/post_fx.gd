extends CanvasLayer
## Legt de PS1-nabewerking (shaders/post.gdshader) over het hele beeld.
## De nacht-regie kan hiermee het beeld "raar" laten doen.

var _mat: ShaderMaterial
var _base := {"darkness": 0.0, "vignette": 0.55}
var _hiding := false
var _listening := false


func _ready() -> void:
	Game.post = self
	layer = 5
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/post.gdshader")
	rect.material = _mat
	add_child(rect)


func set_param(param: String, value: float) -> void:
	_mat.set_shader_parameter(param, value)


## Laat een effect soepel veranderen, bijv. tween_param("distortion", 1.0, 0.5)
func tween_param(param: String, value: float, seconds: float) -> Tween:
	var t := create_tween()
	t.tween_method(func(v): set_param(param, v), _mat.get_shader_parameter(param), value, seconds)
	return t


## Kort schrikeffect: beeld hapert en ruist.
func jolt(strength := 1.0) -> void:
	set_param("distortion", strength)
	set_param("static_amount", 0.35 * strength)
	var t := create_tween().set_parallel()
	t.tween_method(func(v): set_param("distortion", v), strength, 0.0, 1.2)
	t.tween_method(func(v): set_param("static_amount", v), 0.35 * strength, 0.0, 0.6)


func set_night(night: bool) -> void:
	set_param("desaturate", 0.35 if night else 0.12)
	set_param("grain", 0.06 if night else 0.035)


func set_hiding(on: bool) -> void:
	_hiding = on
	tween_param("darkness", 0.88 if on else 0.0, 0.6)


func set_listening(on: bool) -> void:
	if on == _listening:
		return
	_listening = on
	tween_param("vignette", 1.4 if on else 0.55, 0.4)
	# Achtergrondgeluid zachter, al het andere iets harder: je hoort "beter".
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), -12.0 if on else 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), 4.0 if on else 0.0)
