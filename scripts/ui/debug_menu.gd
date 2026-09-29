extends CanvasLayer
## Debug-menu: druk op = om het te openen/sluiten.
## Handig om snel iets te testen zonder de hele game te spelen.
## Zet ENABLED op false als je de game aan anderen geeft.

const ENABLED := true

var _panel: ColorRect
var _info: Label
var _show_info := false
var _locked_player := false
var _day_label: Label
var _picked_day := 1


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 8
	root.theme = theme
	add_child(root)

	_info = Label.new()
	_info.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info.offset_left = -150
	_info.offset_top = 20
	_info.offset_right = -6
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_info.add_theme_color_override("font_shadow_color", Color.BLACK)
	_info.add_theme_constant_override("line_spacing", -2)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	root.add_child(_info)

	_panel = ColorRect.new()
	_panel.color = Color(0, 0, 0, 0.75)
	_panel.position = Vector2(4, 4)
	_panel.size = Vector2(318, 266)
	_panel.visible = false
	root.add_child(_panel)
	var title := Label.new()
	title.text = "DEBUG  (= sluiten)"
	title.position = Vector2(6, 2)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_panel.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(6, 16)
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 2)
	_panel.add_child(grid)

	var buttons := [
		["< Dag", _pick_day.bind(-1)], ["", Callable()], ["Dag >", _pick_day.bind(1)],
		["Ochtend", _jump_phase.bind(0)], ["School", _jump_phase.bind(1)], ["Avond", _jump_phase.bind(2)],
		["Nacht", _jump_phase.bind(3)], ["Godmode", _toggle_god], ["Het wezen: kom!", _summon],
		["Lange gang", _long_hall], ["Spiegel traag", _mirror_delay], ["Info aan/uit", _toggle_info],
		["Noclip (vliegen)", _toggle_noclip], ["Snel lopen", _toggle_fast], ["Batterij vol", _full_battery],
		["Lichten aan", _lights.bind(true)], ["Lichten uit", _lights.bind(false)], ["Kasten open", _closets.bind(true)],
		["Kasten dicht", _closets.bind(false)], ["TV ruis", _tv.bind(TV.Mode.STATIC)], ["TV uit", _tv.bind(TV.Mode.OFF)],
		["Gekras", _scratch], ["Voetstap achter je", _footstep], ["Schrik-effect", _jolt],
		["Uitputting +1", _stat.bind("exhaustion", 1)], ["Uitputting -1", _stat.bind("exhaustion", -1)], ["Hulp +1", _stat.bind("help", 1)],
		["Hulp -1", _stat.bind("help", -1)], ["Nacht-sfeer", _mood.bind("night")], ["Dag-sfeer", _mood.bind("morning")],
	]
	for b in buttons:
		if b[0] == "":
			_day_label = Label.new()
			_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_day_label.custom_minimum_size = Vector2(100, 15)
			grid.add_child(_day_label)
			continue
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(100, 15)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(b[1])
		grid.add_child(btn)


func _input(event: InputEvent) -> void:
	if ENABLED and event.is_action_pressed("debug"):
		_set_open(not _panel.visible)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	_panel.visible = open
	if open:
		_picked_day = Game.day
		_pick_day(0)
	Game.debug_open = open
	_info.visible = open or _show_info
	var player: Player = Game.player
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if player and not player.locked:
			player.locked = true
			_locked_player = true
	else:
		if not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if player and _locked_player:
			player.locked = false
		_locked_player = false


func _process(_delta: float) -> void:
	if not _info.visible:
		return
	var p: Player = Game.player
	var lines := [
		"FPS %d" % Engine.get_frames_per_second(),
		"Dag %d  %s" % [Game.day, Game.Phase.keys()[Game.phase]],
		"Uitputting %d  Hulp %d" % [Game.exhaustion, Game.help],
	]
	if p:
		var pos := p.global_position
		lines.append("Pos %.1f %.1f %.1f" % [pos.x, pos.y, pos.z])
		if Game.apartment:
			lines.append("Kamer: %s" % Game.apartment.room_at(pos))
		lines.append("Batterij %d%%  Angst %.1f" % [p.battery * 100.0, p.fear])
		if p.noclip:
			lines.append("NOCLIP")
		if Game.godmode:
			lines.append("GODMODE")
	_info.text = "\n".join(lines)


# ------------------------------------------------------------------ acties

func _pick_day(step: int) -> void:
	_picked_day = clampi(_picked_day + step, 1, Game.LAST_DAY)
	_day_label.text = "Dag %d (%s)" % [_picked_day, Game.DAY_NAMES[_picked_day - 1].capitalize()]


func _jump_phase(phase: int) -> void:
	if _picked_day >= 6 and phase < 2:
		phase = 2 # zaterdag: geen ochtend/school
	_jump(_picked_day, phase)


func _toggle_god() -> void:
	Game.godmode = not Game.godmode


func _summon() -> void:
	var s: Stalker = Game.apartment.stalker
	s.spawn(s._nearest_node(Game.player.global_position + Game.player.global_basis.z * 3.0))


func _long_hall() -> void:
	Game.apartment.set_long_hall(not Game.apartment.long_hall)


func _jump(day: int, phase: int) -> void:
	Game.day = day
	Game.debug_start_phase = phase
	Sfx.set_muffled(false)
	get_tree().paused = false
	get_tree().reload_current_scene()


func _mirror_delay() -> void:
	var m: Mirror = Game.apartment.mirror
	m.delay = 0.0 if m.delay > 0.0 else 0.45


func _toggle_info() -> void:
	_show_info = not _show_info
	_info.visible = _panel.visible or _show_info


func _toggle_noclip() -> void:
	Game.player.noclip = not Game.player.noclip


func _toggle_fast() -> void:
	Game.player.speed_multiplier = 1.0 if Game.player.speed_multiplier > 1.0 else 3.0


func _full_battery() -> void:
	Game.player.battery = 1.0
	Game.hud.set_battery(1.0)


func _lights(on: bool) -> void:
	Game.apartment.set_all_lights(on)


func _closets(open: bool) -> void:
	for c in Game.apartment.closets:
		c.set_angle(c.max_angle if open else 0.0)


func _tv(mode: TV.Mode) -> void:
	Game.apartment.tv.set_mode(mode)


func _scratch() -> void:
	Sfx.play_at("scratch", Game.apartment.doors.bedroom.global_position + Vector3(0.45, 1.0, 0), 0.0)


func _footstep() -> void:
	var p: Player = Game.player
	Sfx.play_at("step_%s_2" % p.current_surface, p.global_position + p.global_basis.z * 1.4, -2.0)


func _jolt() -> void:
	Sfx.play("stinger", -4.0)
	Game.post.jolt(1.0)


func _stat(stat: String, amount: int) -> void:
	Game.set(stat, Game.get(stat) + amount)


func _mood(mood: String) -> void:
	Game.apartment.set_mood(mood)
	Game.post.set_night(mood == "night")
