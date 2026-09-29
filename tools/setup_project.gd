extends SceneTree
## Zet de project-instellingen (toetsen, resolutie, autoloads...) goed.
## Draaien met:  godot --headless --path . --script res://tools/setup_project.gd

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.device = -1
	return e

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.device = -1
	return e

func _init() -> void:
	var actions := {
		"move_forward": [_key(KEY_W), _key(KEY_UP)],
		"move_back": [_key(KEY_S), _key(KEY_DOWN)],
		"move_left": [_key(KEY_A), _key(KEY_LEFT)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT)],
		"interact": [_key(KEY_E)],
		"drag": [_mouse(MOUSE_BUTTON_LEFT)],
		"flashlight": [_key(KEY_F)],
		"crouch": [_key(KEY_CTRL), _key(KEY_C)],
		"listen": [_key(KEY_Q)],
		"hide": [_key(KEY_SPACE)],
		"pause": [_key(KEY_ESCAPE)],
		"choice_1": [_key(KEY_1)],
		"choice_2": [_key(KEY_2)],
		"choice_3": [_key(KEY_3)],
		"choice_4": [_key(KEY_4)],
	}
	for a in actions:
		ProjectSettings.set_setting("input/" + a, {"deadzone": 0.2, "events": actions[a]})

	var s := {
		"application/config/name": "Something's Inside",
		"application/config/description": "Psychologische horror in PS1-stijl.",
		"application/run/main_scene": "res://scenes/menu.tscn",
		"application/config/icon": "res://icon.svg",
		"autoload/Game": "*res://scripts/autoload/game.gd",
		"autoload/Sfx": "*res://scripts/autoload/sfx.gd",
		# Lage resolutie, opgeschaald = grote pixels (PS1-look)
		"display/window/size/viewport_width": 480,
		"display/window/size/viewport_height": 270,
		"display/window/size/window_width_override": 1440,
		"display/window/size/window_height_override": 810,
		"display/window/stretch/mode": "viewport",
		"display/window/stretch/aspect": "keep",
		"gui/theme/default_font_antialiasing": 0,
		"gui/theme/default_font_hinting": 2,
		"rendering/renderer/rendering_method": "gl_compatibility",
		"rendering/renderer/rendering_method.mobile": "gl_compatibility",
		"rendering/textures/canvas_textures/default_texture_filter": 0,
		"rendering/anti_aliasing/quality/msaa_3d": 0,
		"physics/common/physics_ticks_per_second": 60,
	}
	for k in s:
		ProjectSettings.set_setting(k, s[k])
	ProjectSettings.set_setting("shader_globals/ps1_snap", {"type": "float", "value": 140.0})
	ProjectSettings.set_setting("shader_globals/ps1_affine", {"type": "float", "value": 0.35})
	var err := ProjectSettings.save()
	print("Project settings opgeslagen: ", error_string(err))
	quit()
