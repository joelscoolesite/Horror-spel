extends Control
## Het startscherm.


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.reset()
	var theme := Theme.new()
	theme.default_font_size = 10
	self.theme = theme

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "SOMETHING'S INSIDE"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 60
	title.offset_left = -200
	title.offset_right = 200
	add_child(title)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-50, 0)
	box.size = Vector2(100, 60)
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var start := Button.new()
	start.text = "Start"
	start.pressed.connect(_on_start)
	box.add_child(start)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)
	start.grab_focus()

	var controls := Label.new()
	controls.text = "WASD  walk\nMouse  look\nE  interact\nHold LMB  pull doors slowly\nF  phone light\nQ  listen\nCtrl  crouch\nSpace  hide (in bed)\nEsc  pause"
	controls.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	controls.position = Vector2(12, 100)
	controls.add_theme_constant_override("line_spacing", -3)
	add_child(controls)

	var hint := Label.new()
	hint.text = "Best played with headphones. In the dark."
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -30
	hint.offset_left = -200
	hint.offset_right = 200
	add_child(hint)

	var post := CanvasLayer.new()
	post.set_script(preload("res://scripts/ui/post_fx.gd"))
	add_child(post)


func _process(_delta: float) -> void:
	if Game.post and randf() < 0.01:
		Game.post.jolt(0.4)


func _on_start() -> void:
	Sfx.play("ui_click")
	get_tree().change_scene_to_file("res://scenes/main.tscn")
