extends Node3D
## De hoofdscène. Speelt de dagen en nachten achter elkaar af.
##
## Testen vanaf een bepaald punt: zet in Godot bij
## Project > Project Settings > Editor > Run > Main Run Args bijvoorbeeld:
##     -- --day=2 --phase=night
## (phase kan zijn: morning, school, afternoon, night)

@onready var day_director := $DayDirector
@onready var night_director := $NightDirector

const PHASES := ["morning", "school", "afternoon", "night"]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tour="):
			# alleen voor ontwikkelen: screenshots maken (zie tools/tour.gd)
			var tour: Node = load("res://tools/tour.gd").new()
			tour.out_dir = arg.get_slice("=", 1)
			add_child(tour)
			tour.run()
			return
		if arg == "--playtest":
			add_child(load("res://tools/playtest.gd").new())
	_run()


func _run() -> void:
	var start_phase := _read_start_args()
	while Game.day <= Game.PLAYABLE_UNTIL_DAY:
		if start_phase <= 0:
			await day_director.run_morning(Game.day)
		if start_phase <= 1:
			await day_director.run_school(Game.day)
		if start_phase <= 2:
			await day_director.run_afternoon(Game.day)
		await night_director.run_night(Game.day)
		start_phase = 0
		Game.day += 1
	Game.player.locked = true
	await Game.hud.title_card([
		"End of the demo.",
		"Nights 4 and 5 are coming...",
		"Thanks for playing.",
	])
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _read_start_args() -> int:
	if Game.debug_start_phase >= 0:
		var p := Game.debug_start_phase
		Game.debug_start_phase = -1
		return p
	var phase := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--day="):
			Game.day = clampi(int(arg.get_slice("=", 1)), 1, Game.LAST_DAY)
		elif arg.begins_with("--phase="):
			phase = maxi(0, PHASES.find(arg.get_slice("=", 1)))
	return phase
