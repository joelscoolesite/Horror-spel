extends CanvasLayer
## Alles wat over het beeld heen komt: gedachtes, knoppen-hints, taken,
## zwart in-/uitfaden, keuzes en het pauzemenu.

var _root: Control
var _prompt: Label
var _thought: Label
var _objectives: Label
var _battery_bg: ColorRect
var _battery_bar: ColorRect
var _fade: ColorRect
var _card: Label
var _choice: ColorRect
var _choice_label: Label
var _pause: ColorRect

var _objective_list: Array = [] ## [[id, tekst, klaar?], ...]
var _thought_tween: Tween


func _ready() -> void:
	Game.hud = self
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 10
	_root.theme = theme
	add_child(_root)

	# puntje in het midden van het scherm (waar je naar kijkt)
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.5)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -1
	dot.offset_top = -1
	dot.offset_right = 0
	dot.offset_bottom = 0
	_root.add_child(dot)

	_prompt = _label(HORIZONTAL_ALIGNMENT_CENTER, Color(0.9, 0.9, 0.85))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -64
	_prompt.offset_bottom = -50
	_prompt.offset_left = -220
	_prompt.offset_right = 220

	_thought = _label(HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1))
	_thought.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_thought.offset_top = -40
	_thought.offset_bottom = -8
	_thought.offset_left = -220
	_thought.offset_right = 220
	_thought.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thought.modulate.a = 0.0

	_objectives = _label(HORIZONTAL_ALIGNMENT_LEFT, Color(0.85, 0.85, 0.8))
	_objectives.position = Vector2(8, 6)
	_objectives.size = Vector2(220, 100)

	_battery_bg = ColorRect.new()
	_battery_bg.color = Color(0, 0, 0, 0.6)
	_battery_bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_battery_bg.position = Vector2(-34, 8)
	_battery_bg.size = Vector2(24, 8)
	_battery_bg.visible = false
	_battery_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_battery_bg)
	_battery_bar = ColorRect.new()
	_battery_bar.color = Color(0.8, 0.9, 0.8)
	_battery_bar.position = Vector2(1, 1)
	_battery_bar.size = Vector2(22, 6)
	_battery_bg.add_child(_battery_bar)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

	_card = _label(HORIZONTAL_ALIGNMENT_CENTER, Color(0.9, 0.88, 0.85))
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.offset_left = 50
	_card.offset_right = -50
	_card.add_theme_font_size_override("font_size", 12)
	_card.modulate.a = 0.0

	# Keuzes komen BOVEN het zwarte scherm (anders zie je ze niet als het beeld zwart is)
	_choice = ColorRect.new()
	_choice.color = Color(0, 0, 0, 0.8)
	_choice.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice.visible = false
	_root.add_child(_choice)
	_choice_label = _label(HORIZONTAL_ALIGNMENT_LEFT, Color(0.95, 0.95, 0.9), _choice)
	_choice_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_label.offset_left = 70
	_choice_label.offset_right = -70
	_choice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_choice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_build_pause_menu()


func _label(align: HorizontalAlignment, color: Color, parent: Control = null) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else _root).add_child(l)
	return l


# ------------------------------------------------------------------ tekst

## Laat een gedachte van het kind onderin zien.
func say(text: String, seconds := 3.0) -> void:
	if _thought_tween:
		_thought_tween.kill()
	_thought.text = text
	_thought.modulate.a = 1.0
	_thought_tween = create_tween()
	_thought_tween.tween_interval(seconds)
	_thought_tween.tween_property(_thought, "modulate:a", 0.0, 0.8)


## Zelfde als say(), maar wacht tot de tekst weg is.
func say_wait(text: String, seconds := 3.0) -> void:
	say(text, seconds)
	await Game.wait(seconds + 0.8)


func set_prompt(text: String) -> void:
	if _prompt.text != text:
		_prompt.text = text


# ------------------------------------------------------------------ taken

## items: [["alarm", "Turn off the alarm"], ...]
func set_objectives(items: Array) -> void:
	_objective_list.clear()
	for it in items:
		_objective_list.append([it[0], it[1], false])
	_refresh_objectives()


func complete_objective(id: String, done := true) -> void:
	for o in _objective_list:
		if o[0] == id:
			o[2] = done
	_refresh_objectives()


func is_objective_done(id: String) -> bool:
	for o in _objective_list:
		if o[0] == id:
			return o[2]
	return false


func clear_objectives() -> void:
	_objective_list.clear()
	_refresh_objectives()


func _refresh_objectives() -> void:
	var lines := []
	for o in _objective_list:
		lines.append(("[x] " if o[2] else "[ ] ") + o[1])
	_objectives.text = "\n".join(lines)


# ------------------------------------------------------------------ zwart beeld

func fade_out(seconds := 1.0) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, seconds)
	await t.finished


func fade_in(seconds := 1.0) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, seconds)
	await t.finished


## Heel even zwart (bijv. als je uit bed stapt).
func blink() -> void:
	await fade_out(0.25)
	await fade_in(0.35)


## Tekst in het midden van een zwart scherm, regel voor regel.
func title_card(lines: Array, per_line := 2.8) -> void:
	_fade.color.a = 1.0
	for line in lines:
		_card.text = line
		var t := create_tween()
		t.tween_property(_card, "modulate:a", 1.0, 0.6)
		t.tween_interval(per_line)
		t.tween_property(_card, "modulate:a", 0.0, 0.6)
		await t.finished
	await Game.wait(0.3)


# ------------------------------------------------------------------ keuzes

## Laat een vraag zien met opties. Speler kiest met 1, 2, 3 of 4.
## Geeft het nummer van de keuze terug (0 = eerste optie).
func choose(question: String, options: Array) -> int:
	var player := Game.player
	var was_locked: bool = player.locked if player else false
	if player:
		player.locked = true
	var text := question + "\n"
	for i in options.size():
		text += "\n  [%d]  %s" % [i + 1, options[i]]
	_choice_label.text = text
	_choice.visible = true
	var picked := -1
	await get_tree().process_frame
	while picked < 0:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		for i in options.size():
			if Input.is_action_just_pressed("choice_%d" % (i + 1)):
				picked = i
	_choice.visible = false
	Sfx.play("ui_click")
	if player:
		player.locked = was_locked
	return picked


## Een pagina tekst (bijv. een nieuwsbericht). Sluiten met E.
func show_page(text: String) -> void:
	var player := Game.player
	var was_locked: bool = player.locked if player else false
	if player:
		player.locked = true
	_choice_label.text = text + "\n\n  [E]  Close"
	_choice.visible = true
	await get_tree().process_frame
	while true:
		await get_tree().process_frame
		if not get_tree().paused and Input.is_action_just_pressed("interact"):
			break
	_choice.visible = false
	Sfx.play("ui_click")
	if player:
		player.locked = was_locked


# ------------------------------------------------------------------ batterij

func show_battery(on: bool) -> void:
	_battery_bg.visible = on


func set_battery(v: float) -> void:
	_battery_bar.size.x = 22.0 * v
	_battery_bar.color = Color(0.8, 0.9, 0.8) if v > 0.2 else Color(0.9, 0.3, 0.2)


# ------------------------------------------------------------------ pauze

func _build_pause_menu() -> void:
	_pause = ColorRect.new()
	_pause.color = Color(0, 0, 0, 0.85)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	_root.add_child(_pause)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-60, -50)
	box.size = Vector2(120, 100)
	box.add_theme_constant_override("separation", 6)
	_pause.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sens_label := Label.new()
	sens_label.text = "Mouse sensitivity"
	sens_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sens_label)
	var slider := HSlider.new()
	slider.min_value = 0.0005
	slider.max_value = 0.008
	slider.step = 0.0001
	slider.value = Game.mouse_sensitivity
	slider.value_changed.connect(func(v): Game.mouse_sensitivity = v)
	box.add_child(slider)
	for item in [["Resume", _toggle_pause], ["Main menu", _to_menu], ["Quit", func(): get_tree().quit()]]:
		var b := Button.new()
		b.text = item[0]
		b.pressed.connect(item[1])
		box.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
	# Muis "kwijt" (bijv. na alt-tab)? Klik in het venster om hem terug te pakken.
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused and not Game.debug_open:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_pause.visible = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
