extends Node
## Regie van de nacht. Elke nacht wordt het erger (zie docs/GDD.md §6).
## Nu speelbaar: nacht 1, 2 en 3. Nacht 4 en 5 volgen.

var ap: Apartment:
	get: return Game.apartment
var player: Player:
	get: return Game.player
var hud: Node:
	get: return Game.hud

const CLOSET_LINES := ["Nothing.", "Empty.", "...Nothing.", "Just clothes.", "Nothing there."]

var _checked := 0
var _package_opened := false
var _late_delay := 0.0
var _scratching := false
var _scratch_player: AudioStreamPlayer3D


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
	_package_opened = false
	hud.clear_objectives()
	if day == 3:
		ap.closets[3].set_angle(25.0) # de gangkast staat op een kier...

	await hud.fade_in(3.0)
	var result: String
	if day == 3:
		result = await _intro_scratching()
	else:
		result = await _intro_default(day)
	if result == "hid":
		_stop_scratch()
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
		3:
			await _night_3()
		_:
			await _night_1() # TODO: nacht 4 en 5
	Game.closet_opened.disconnect(_on_closet_opened)
	_set_late_steps(0.0)
	_stop_scratch()
	if _checked >= ap.closets.size():
		Game.exhaustion += 1 # alles checken houdt de angst in stand...
	await _go_to_sleep()


func _intro_default(day: int) -> String:
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
	return await _wait_get_up_or_hide()


## Nacht 3: je wordt wakker van gekras op je deur. Het stopt als je opstaat.
func _intro_scratching() -> String:
	_start_scratch(Vector3(3.75, 1.0, 3.95))
	await Game.wait(3.0)
	player.fear = 0.6
	await hud.say_wait("Something is scratching at my door.", 3.0)
	player.locked = false
	player.allow_get_up = true
	var result: String = await _wait_get_up_or_hide()
	if result == "up":
		_stop_scratch()
		await Game.wait(0.6)
		hud.say("...It stopped.", 2.5)
	return result


## Wacht tot `cond` waar is (of de tijd om is). Geeft true als het gelukt is.
func _wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


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


# ================================================================== NACHT 3
# Gekras, een kast op een kier, kapotte lampen, te late voetstappen,
# een pakketje dat er niet hoort... en een spiegelbeeld dat te traag is.

func _night_3() -> void:
	ap.switch_for("hall").broken = true
	_living_light_dies()
	_ajar_closet_comment()
	ap.package.visible = true
	ap.spots.package.activate("Open the package")
	_package_event()
	_set_late_steps(0.5)
	await Game.wait(1.5)
	hud.say("Check the closets. All of them. Then back to bed.", 3.5)
	ap.spots.bed.activate("Go back to sleep")
	_whisper_and_mirror()
	await _wait_for_bed()


## Na het pakketje (of 3 kasten): gefluister uit de badkamer. Kijk je in de spiegel...
func _whisper_and_mirror() -> void:
	await _wait_until(func(): return _package_opened or _checked >= 3, 300.0)
	await Game.wait(2.0)
	# wacht tot je niet met iets bezig bent (bijv. een kast vasthoudt)
	await _wait_until(func(): return _still_awake() or Game.phase != Game.Phase.NIGHT, 60.0)
	if not _still_awake():
		return
	player.fear = 0.7
	Sfx.play_at("whisper", ap.mirror.global_position, 0.0)
	await Game.wait(0.8)
	hud.say("Someone whispers your name. From the bathroom.", 4.0)
	ap.mirror.delay = 0.45
	if await _mirror_stare(600.0):
		await _mirror_scare()


func _package_event() -> void:
	await Game.wait_for_task("package")
	ap.spots.package.deactivate()
	Sfx.play_at("rustle", ap.package.global_position, -4.0, 1.3)
	var ordered: String = Game.orders[1].to_lower() if Game.orders.size() > 1 else "something"
	await hud.show_page("The package from Amazin. It's inside the house.\nThe front door is still locked.\n\nYou ordered: %s.\n\nBut inside is... your lunchbox. The one that was missing.\nThere's a sandwich in it. It's days old." % ordered)
	_package_opened = true
	player.fear = 0.6
	hud.say("Who put this here?", 2.5)


func _ajar_closet_comment() -> void:
	if await _wait_until(func(): return ap.room_at(player.global_position) == "hall", 120.0):
		if not ap.closets[3].was_opened:
			hud.say("The hall closet is open a little. Was it like that before?", 3.5)


## De woonkamerlamp gaat aan... en dan kapot.
func _living_light_dies() -> void:
	var sw := ap.switch_for("living")
	if not await _wait_until(func(): return sw.is_on, 300.0):
		return
	await Game.wait(3.0)
	if Game.phase != Game.Phase.NIGHT:
		return
	await sw.flicker(6, false)
	sw.broken = true
	hud.say("...The bulb just died.", 2.5)


## Kijkt de speler lang genoeg in de spiegel (in de badkamer)?
func _mirror_stare(timeout: float) -> bool:
	var stare := 0.0
	var t := 0.0
	while t < timeout:
		await get_tree().process_frame
		if Game.phase != Game.Phase.NIGHT or player.state != Player.State.WALK and player.locked:
			return false
		var dt := get_process_delta_time()
		t += dt
		var in_bath := ap.room_at(player.global_position) == "bathroom"
		if player.state == Player.State.WALK and in_bath and player.is_looking_at(ap.mirror.global_position, 22.0):
			stare += dt
			if stare > 1.5:
				return true
		else:
			stare = 0.0
	return false


func _mirror_scare() -> void:
	hud.say("My reflection... it's too slow.", 3.0)
	await Game.wait(2.5)
	ap.mirror.frozen = true # ...en nu beweegt hij helemaal niet meer
	Sfx.play("stinger", -3.0)
	Game.post.jolt(1.0)
	player.fear = 1.0
	await Game.wait(0.6)
	hud.say("It's not moving. Why isn't it moving?", 3.0)
	var bath := ap.switch_for("bathroom")
	if bath.is_on:
		bath.flicker(6, false)
	await Game.wait(3.0)
	ap.mirror.frozen = false
	ap.mirror.delay = 0.0
	player.fear = 0.6
	hud.say("Get out. Go back to bed. NOW.", 3.0)


# ------------------------------------------------------------------ gekras

func _start_scratch(pos: Vector3) -> void:
	_scratching = true
	_scratch_player = AudioStreamPlayer3D.new()
	_scratch_player.stream = Sfx.stream("scratch")
	_scratch_player.bus = "SFX"
	_scratch_player.volume_db = 3.0
	_scratch_player.unit_size = 3.0
	ap.add_child(_scratch_player)
	_scratch_player.global_position = pos
	_scratch_player.finished.connect(_on_scratch_finished)
	_scratch_player.play()


func _on_scratch_finished() -> void:
	await Game.wait(randf_range(0.3, 1.2))
	if _scratching and is_instance_valid(_scratch_player):
		_scratch_player.pitch_scale = randf_range(0.85, 1.05)
		_scratch_player.play()


func _stop_scratch() -> void:
	_scratching = false
	if is_instance_valid(_scratch_player):
		_scratch_player.queue_free()
	_scratch_player = null


# ------------------------------------------------------------------ te late voetstappen

## Jouw voetstappen, nog een keer, `delay` seconden later, achter je. 0 = uit.
func _set_late_steps(delay: float) -> void:
	if delay > 0.0 and _late_delay <= 0.0:
		player.stepped.connect(_on_late_step)
		player.stopped_walking.connect(_on_late_stop)
	elif delay <= 0.0 and _late_delay > 0.0:
		player.stepped.disconnect(_on_late_step)
		player.stopped_walking.disconnect(_on_late_stop)
	_late_delay = delay


func _on_late_step(surface: String) -> void:
	await Game.wait(_late_delay)
	if _late_delay <= 0.0 or Game.phase != Game.Phase.NIGHT:
		return
	Sfx.play_at("step_%s_%d" % [surface, randi_range(1, 3)], player.global_position + player.global_basis.z * 1.3, -9.0, 0.9)


## Als jij stilstaat, lopen ze nog twee stappen door.
func _on_late_stop() -> void:
	for i in 2:
		await Game.wait(0.55)
		if _late_delay <= 0.0 or Game.phase != Game.Phase.NIGHT:
			return
		Sfx.play_at("step_%s_%d" % [player.current_surface, randi_range(1, 3)], player.global_position + player.global_basis.z * 1.2, -7.0, 0.9)


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
