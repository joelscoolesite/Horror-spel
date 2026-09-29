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
	Game.hud.say("Something is inside my house.", 5.0)
	Game.hud.set_objectives([["a", "Turn off the alarm"], ["b", "Make breakfast"]])
	await _settle()
	_shot("hud")
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
