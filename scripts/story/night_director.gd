extends Node
## Regie van de nacht. Elke nacht wordt het erger (zie docs/GDD.md §6).
## Nu speelbaar: nacht 1 en 2. Nacht 3-5 volgen.

var ap: Apartment:
	get: return Game.apartment
var player: Player:
	get: return Game.player
var hud: Node:
	get: return Game.hud

const CLOSET_LINES := ["Nothing.", "Empty.", "...Nothing.", "Just clothes.", "Nothing there."]

var _checked := 0


func run_night(day: int) -> void:
	Game.phase = Game.Phase.NIGHT
	ap.reset_for(true)
	ap.set_mood("night")
	ap.set_clock(Game.NIGHT_TIMES[day - 1])
	Game.post.set_night(true)
	player.night_mode = true
	# Je vergeet steeds vaker je telefoon op te laden...
	player.battery = clampf(1.0 - 0.25 * (day - 1), 0.2, 1.0)
	player.lie_in_bed(ap.markers.bed_head, ap.markers.bed_side)
	player.locked = true
	player.allow_get_up = false
	player.can_hide = true
	player.fear = 0.15
	_checked = 0
	hud.clear_objectives()

	await hud.fade_in(3.0)
	await Game.wait(1.5)
	# ergens in huis kraakt iets
	Sfx.play_at("creak_fast", Vector3(6.0, 1.0, 4.75), -16.0, 0.7)
	await Game.wait(2.0)
	player.fear = 0.35
	await hud.say_wait("Something is inside my house.", 3.0)
	if day >= 2:
		hud.say("...Not again.", 2.5)
	player.locked = false
	player.allow_get_up = true

	var result: String = await _wait_get_up_or_hide()
	if result == "hid":
		Game.flags["hid_night_%d" % day] = true
		player.allow_get_up = false
		await hud.say_wait("You stay under the blanket until the sun comes up.", 3.0)
		await hud.fade_out(2.5)
		player.set_hiding(false)
		await Game.wait(1.0)
		return

	Game.closet_opened.connect(_on_closet_opened)
	match day:
		1:
			await _night_1()
		2:
			await _night_2()
		_:
			await _night_1() # TODO: nacht 3, 4 en 5
	Game.closet_opened.disconnect(_on_closet_opened)
	if _checked >= ap.closets.size():
		Game.exhaustion += 1 # alles checken houdt de angst in stand...
	await _go_to_sleep()


## Wacht tot de speler opstaat ("up") of lang onder de deken blijft ("hid").
func _wait_get_up_or_hide() -> String:
	var hidden_time := 0.0
	while true:
		await get_tree().process_frame
		if player.state == Player.State.WALK:
			return "up"
		hidden_time = hidden_time + get_process_delta_time() if player.hiding else 0.0
		if hidden_time > 10.0:
			return "hid"
	return "up"


func _on_closet_opened(_closet: Door) -> void:
	_checked += 1
	if _checked >= ap.closets.size():
		hud.say("Nothing. There's nothing here.\nGo back to bed.", 4.0)
	else:
		hud.say(CLOSET_LINES[(_checked - 1) % CLOSET_LINES.size()], 2.0)


# ================================================================== NACHT 1
# Er gebeurt niets. Helemaal niets. Dat is het punt.

func _night_1() -> void:
	await Game.wait(0.5)
	hud.say("I have to check. Every closet.", 3.0)
	ap.spots.bed.activate("Go back to sleep")
	await _wait_for_bed()


# ================================================================== NACHT 2
# Zelfde als nacht 1... tot de TV ineens aanspringt.

func _night_2() -> void:
	await Game.wait(0.5)
	hud.say("Check the closets. Then back to bed.", 3.0)
	var start := Time.get_ticks_msec()
	while _checked < 3 and Time.get_ticks_msec() - start < 90_000:
		await get_tree().process_frame
	await Game.wait(1.5)
	await _tv_scare()
	ap.spots.bed.activate("Go back to sleep")
	_one_step_too_many()
	await _wait_for_bed()


func _tv_scare() -> void:
	ap.tv.set_mode(TV.Mode.STATIC)
	Sfx.play("stinger", -4.0)
	Game.post.jolt(1.0)
	player.fear = 1.0
	await Game.wait(0.7)
	hud.say("What the—!", 2.5)
	ap.tv.spot.activate("Turn off the TV")
	await Game.wait_for_task("tv")
	ap.tv.spot.deactivate()
	ap.tv.set_mode(TV.Mode.OFF)
	Sfx.play("switch", -6.0, 0.7)
	player.fear = 0.6
	await Game.wait(1.5)
	hud.say("It just... turned on. By itself.", 3.0)


## Als je stilstaat hoor je nog één voetstap. Achter je.
func _one_step_too_many() -> void:
	await player.stopped_walking
	if not _still_awake():
		return
	var behind := player.global_position + player.global_basis.z * 1.4
	Sfx.play_at("step_%s_2" % player.current_surface, behind, -2.0, 0.95)
	player.fear = 0.9
	await Game.wait(1.4)
	if not _still_awake():
		return
	hud.say("...Hello?", 2.5)
	await Game.wait(3.0)
	if not _still_awake():
		return
	player.fear = 0.5
	hud.say("Just go back to bed. Now.", 3.0)


## Is de speler nog wakker en aan het rondlopen?
func _still_awake() -> bool:
	return Game.phase == Game.Phase.NIGHT and player.state == Player.State.WALK and not player.locked


# ================================================================== SLAPEN

func _wait_for_bed() -> void:
	while true:
		await Game.wait_for_task("bed")
		if _checked >= ap.closets.size():
			return
		var pick: int = await hud.choose("You haven't checked every closet.", ["Keep checking", "Go to sleep anyway"])
		if pick == 1:
			return


func _go_to_sleep() -> void:
	ap.spots.bed.deactivate()
	player.set_flashlight(false)
	player.lie_in_bed(ap.markers.bed_head, ap.markers.bed_side)
	player.locked = true
	player.fear = 0.0
	Sfx.play("rustle", -8.0)
	await Game.wait(1.5)
	await hud.fade_out(3.0)
	await Game.wait(1.5)
