class_name TV
extends Node3D
## Ouderwetse beeldbuis-TV op een kastje, met spelcomputer.
## Kan uit staan, een spelletje laten zien, of... op ruis springen.

enum Mode { OFF, GAME, STATIC }

const SCREEN_SHADER := preload("res://shaders/screen.gdshader")

var mode := Mode.OFF
var spot: TaskSpot

var _screen_mat: ShaderMaterial
var _light: OmniLight3D
var _audio: AudioStreamPlayer3D


func build() -> void:
	# kastje
	Build.box(self, Vector3(1.3, 0.5, 0.45), Vector3(0, 0, -0.25), Build.mat("wood_dark"))
	# spelcomputer met een groen lampje
	Build.box(self, Vector3(0.28, 0.07, 0.22), Vector3(0.45, 0.5, -0.2), Build.mat("plastic_black"), false)
	Build.box(self, Vector3(0.015, 0.015, 0.005), Vector3(0.36, 0.53, -0.088), Build.glow_mat(Color(0.2, 1.0, 0.3), 1.0), false)
	# controller-snoer ligt op de grond
	Build.box(self, Vector3(0.14, 0.03, 0.09), Vector3(0.35, 0.0, 0.5), Build.mat("plastic_black"), false)
	# de TV zelf (dikke beeldbuis)
	Build.box(self, Vector3(0.74, 0.58, 0.5), Vector3(-0.05, 0.5, -0.3), Build.mat("plastic_black", Color(1.3, 1.3, 1.3)))
	Build.box(self, Vector3(0.5, 0.4, 0.2), Vector3(-0.05, 0.58, -0.6), Build.mat("plastic_black"), false)
	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = SCREEN_SHADER
	Build.quad(self, Vector2(0.6, 0.45), Vector3(-0.05, 0.79, -0.03), _screen_mat)

	_light = OmniLight3D.new()
	_light.position = Vector3(-0.05, 0.8, 0.5)
	_light.omni_range = 4.5
	_light.light_color = Color(0.7, 0.8, 1.0)
	_light.visible = false
	add_child(_light)

	_audio = AudioStreamPlayer3D.new()
	_audio.position = Vector3(-0.05, 0.8, 0.0)
	_audio.bus = "SFX"
	_audio.unit_size = 4.0
	add_child(_audio)

	spot = TaskSpot.new()
	spot.task_id = "tv"
	add_child(spot)
	spot.add_hitbox(Vector3(1.0, 0.8, 0.8), Vector3(0, 0.8, -0.1))


func set_mode(m: Mode) -> void:
	if m != Mode.OFF and mode == Mode.OFF:
		Sfx.play_at("tv_on", _audio.global_position, -4.0)
	mode = m
	_screen_mat.set_shader_parameter("mode", int(m))
	_light.visible = m != Mode.OFF
	match m:
		Mode.OFF:
			_audio.stop()
		Mode.GAME:
			_audio.stream = Sfx.stream("tv_game")
			_audio.volume_db = -8.0
			_audio.play()
		Mode.STATIC:
			_audio.stream = Sfx.stream("tv_static")
			_audio.volume_db = 6.0
			_audio.play()


func _process(_delta: float) -> void:
	match mode:
		Mode.STATIC:
			_light.light_energy = randf_range(0.5, 1.6)
			_light.light_color = Color(0.85, 0.9, 1.0)
		Mode.GAME:
			_light.light_energy = 0.5 + sin(Time.get_ticks_msec() * 0.004) * 0.15
			_light.light_color = Color(0.4, 0.5, 1.0)
