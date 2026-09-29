extends Node
## Ontwikkel-hulpje: loopt langs een paar plekken en maakt screenshots.
## Starten met:  godot --path . res://scenes/main.tscn -- --tour=<map>

var out_dir := ""

const VIEWS := [
	["bedroom", Vector3(3.7, 0, 3.5), Vector3(0.8, 0.9, 1.0)],
	["hall", Vector3(11.2, 0, 4.75), Vector3(0, 1.2, 4.75)],
	["living", Vector3(3.1, 0, 5.8), Vector3(4.6, 0.7, 10)],
	["living2", Vector3(5.5, 0, 9.5), Vector3(1.5, 1.0, 6.0)],
	["kitchen", Vector3(8.0, 0, 6.2), Vector3(10.0, 0.9, 10.0)],
	["bathroom", Vector3(5.75, 0, 3.6), Vector3(5.5, 0.9, 0.5)],
	["parent", Vector3(7.9, 0, 3.6), Vector3(11.0, 0.8, 1.5)],
]


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ap: Apartment = Game.apartment
	var player: Player = Game.player
	Game.hud._fade.color.a = 0.0
	for mood in ["morning", "evening", "night"]:
		ap.set_mood(mood)
		Game.post.set_night(mood == "night")
		player.set_flashlight(mood == "night")
		for v in VIEWS:
			_look(player, v[1], v[2])
			await _settle()
			_shot("%s_%s" % [mood, v[0]])
	# kast open
	ap.closets[0].set_angle(100.0)
	_look(player, Vector3(2.6, 0, 1.0), Vector3(4.3, 1.0, 1.0))
	await _settle()
	_shot("night_closet_open")
	# TV op ruis
	ap.tv.set_mode(TV.Mode.STATIC)
	_look(player, Vector3(4.6, 0, 7.8), Vector3(4.6, 0.8, 10))
	await _settle()
	_shot("night_tv_static")
	ap.tv.set_mode(TV.Mode.OFF)
	# in bed
	player.lie_in_bed(ap.markers.bed_head, ap.markers.bed_side)
	await _settle()
	_shot("night_in_bed")
	ap.set_mood("morning")
	Game.post.set_night(false)
	player._yaw = -1.3
	player._pitch = -0.2
	await _settle()
	_shot("morning_in_bed_clock")
	# school
	ap.set_mood("school")
	Game.post.set_night(false)
	var school: School = Game.school
	school.board_label.text = "MATH  -  p. 42"
	school.figure.visible = true
	player.sit_at(school.seat_marker)
	await _settle()
	_shot("school_seat")
	var to_fig := school.figure.global_position + Vector3(0, 1.3, 0) - player._camera.global_position
	player._yaw = atan2(-to_fig.x, -to_fig.z) - player._lie_yaw
	player._pitch = 0.1
	await _settle()
	_shot("school_figure")

	player._yaw = -0.5
	player._pitch = -0.2
	await _settle()
	_shot("school_look_right")
	school.face(school.starer.get_node("Head"), player.global_position)
	player._yaw = -0.35
	player._pitch = -0.25
	await _settle()
	_shot("school_starer")
	# hand op de kast (nacht)
	ap.set_mood("night")
	Game.post.set_night(true)
	Game.phase = Game.Phase.NIGHT
	ap.closets[0].reset_closed()
	_look(player, Vector3(3.0, 0, 1.0), Vector3(3.9, 1.0, 1.0))
	player.set_flashlight(true)
	await _settle()
	ap.closets[0].interact(player)
	for i in 70:
		await get_tree().process_frame
	_shot("night_hand_grab")
	for i in 120:
		await get_tree().process_frame
	_shot("night_hand_opened")
	Game.phase = Game.Phase.MENU
	# debug-menu
	var dbg = get_parent().get_node("DebugMenu")
	dbg._set_open(true)
	await _settle()
	_shot("debug_menu")
	dbg._set_open(false)
	Game.hud.say("Something is inside my house.", 5.0)
	Game.hud.set_objectives([["a", "Turn off the alarm"], ["b", "Make breakfast"]])
	await _settle()
	_shot("hud")
	# spiegel (overdag en 's nachts)
	ap.set_mood("morning")
	Game.post.set_night(false)
	player.set_flashlight(false)
	ap.switch_for("bathroom").set_on(true)
	_look(player, Vector3(6.2, 0, 2.6), ap.mirror.global_position)
	await _settle()
	_shot("mirror_day")
	player.global_position = Vector3(6.3, 0, 1.9)
	await _settle()
	_shot("mirror_day_moved")
	ap.set_mood("night")
	Game.post.set_night(true)
	player.set_flashlight(true)
	_look(player, Vector3(6.2, 0, 2.4), ap.mirror.global_position)
	await _settle()
	_shot("mirror_night")
	# pakketje
	ap.package.visible = true
	_look(player, Vector3(2.6, 0, 8.6), Vector3(2.6, 0.2, 9.9))
	await _settle()
	_shot("package")
	# droom in de klas
	ap.set_mood("school")
	var sc: School = Game.school
	sc.set_empty(true)
	player.sit_at(sc.seat_marker)
	player.allow_get_up = false
	sc.figure_at_seat(Vector2i(2, 3), player.global_position)
	player._yaw = -0.9
	player._pitch = 0.1
	await _settle()
	_shot("school_dream")
	# nacht 4: de lange gang en de kopie-kamer
	ap.set_mood("night")
	Game.post.set_night(true)
	Game.phase = Game.Phase.NIGHT
	ap.set_long_hall(true)
	player.set_flashlight(true)
	_look(player, Vector3(9.0, 0, 4.75), Vector3(19.0, 1.0, 4.75))
	await _settle()
	_shot("n4_long_hall")
	ap.copy_door.set_angle(90.0)
	_look(player, Vector3(20.2, 0, 4.7), Vector3(22.5, 0.5, 3.0))
	await _settle()
	_shot("n4_copy_room")
	ap.set_long_hall(false)
	# nacht 4: iets in de deuropening
	player.lie_in_bed(ap.markers.bed_head, ap.markers.bed_side)
	ap.doors.bedroom.set_angle(165.0)
	ap.show_shadow(Vector3(3.75, 0, 4.15), ap.markers.bed_head.global_position)
	var bl := OmniLight3D.new()
	bl.omni_range = 4.5
	bl.light_energy = 1.6
	bl.light_color = Color(0.5, 0.55, 0.8)
	ap.add_child(bl)
	bl.global_position = Vector3(3.5, 1.4, 6.1)
	player._yaw = 0.72
	player._pitch = 0.1
	await _settle()
	_shot("n4_doorway")
	ap.shadow.visible = false
	bl.queue_free()
	# nacht 5: koelkast open, TV-tekst
	ap.set_fridge_open(true)
	ap.tv.set_mode(TV.Mode.STATIC)
	ap.tv.set_message("LOOK\nBEHIND\nYOU")
	_look(player, Vector3(5.5, 0, 7.6), Vector3(4.6, 0.8, 10.0))
	await _settle()
	_shot("n5_tv")
	_look(player, Vector3(9.5, 0, 7.0), Vector3(7.5, 1.0, 9.8))
	await _settle()
	_shot("n5_fridge")
	ap.set_fridge_open(false)
	ap.tv.set_mode(TV.Mode.OFF)
	ap.tv.set_message("")
	# nacht 6: het wezen in de gang
	ap.stalker.spawn("hall_par")
	ap.stalker.active = false
	player.set_flashlight(true)
	_look(player, Vector3(3.0, 0, 4.75), Vector3(7.85, 1.3, 4.75))
	await _settle()
	_shot("n6_stalker")
	ap.stalker.despawn()
	# school dag 4: geen ogen
	ap.set_mood("school")
	Game.post.set_night(false)
	player.set_flashlight(false)
	sc.set_empty(false)
	sc.reset_figure()
	sc.set_eyes(false)
	sc.everyone_look_at(player.global_position)
	player.sit_at(sc.seat_marker)
	player._yaw = -0.3
	player._pitch = -0.1
	await _settle()
	_shot("school_noeyes")
	print("TOUR KLAAR")
	get_tree().quit()


func _look(player: Player, pos: Vector3, target: Vector3) -> void:
	player.place_at(Game.apartment.markers.bed_side)
	player.global_position = pos
	var eye := pos + Vector3(0, Player.EYE_HEIGHT, 0)
	var d := target - eye
	player._yaw = atan2(-d.x, -d.z)
	player._pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _settle() -> void:
	for i in 12:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))
	print("shot: ", shot_name)
