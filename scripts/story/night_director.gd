extends Node
## Regie van de nacht. Elke nacht wordt het erger (zie docs/GDD.md §6).
## Nacht 1 t/m 6. Nacht 6 is de finale met de drie eindes.

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
var _token := 0 ## wordt elke nacht hoger; oude "losse" gebeurtenissen stoppen dan vanzelf
var _force_sleep := false ## true = je mag meteen slapen (zonder "niet alles gecheckt")
var _phone_mode := "" ## wat T doet: "", "text_mom", "text_nobody", "call"
var _phone_used := false
var _outcome := "" ## nacht 6: "caught", "morning", "check" of "awake"
var _bed_hunt_running := false
var _copy_done := false
var _quiet_closets := false ## geen "Nothing." als er juist WEL iets in zit


## Speelt een nacht. Geeft een einde terug ("morning", "check", "awake") of "" (gewoon verder).
func run_night(day: int) -> String:
	_token += 1
	_force_sleep = false
	_phone_mode = ""
	_phone_used = false
	if not Game.phone_pressed.is_connected(_on_phone):
		Game.phone_pressed.connect(_on_phone)
	if day >= 6:
		return await _night_6()
	await _setup_night(day)
	var result: String
	if day == 3:
		result = await _intro_scratching()
	elif day == 5:
		result = await _intro_mom()
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
		_token += 1
		return ""

	Game.closet_opened.connect(_on_closet_opened)
	match day:
		1:
			await _night_1()
		2:
			await _night_2()
		3:
			await _night_3()
		4:
			await _night_4()
		5:
			await _night_5()
	Game.closet_opened.disconnect(_on_closet_opened)
	_token += 1
	_set_late_steps(0.0)
	_stop_scratch()
	hud.set_phone_hint("")
	if _checked >= ap.closets.size():
		Game.exhaustion += 1 # alles checken houdt de angst in stand...
	if day == 4:
		await _doorway_figure()
	await _go_to_sleep()
	return ""


## Alles klaarzetten en langzaam het beeld in (je ligt in bed).
func _setup_night(day: int) -> void:
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
	ap.strange_chair.visible = day >= 5
	hud.set_phone_hint("")
	await hud.fade_in(3.0)


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
	if _quiet_closets:
		return
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
	var token := _token
	ap.switch_for("hall").broken = true
	_living_light_dies(token)
	_ajar_closet_comment(token)
	ap.package.visible = true
	ap.spots.package.activate("Open the package")
	_package_event(token)
	_set_late_steps(0.5)
	await Game.wait(1.5)
	hud.say("Check the closets. All of them. Then back to bed.", 3.5)
	ap.spots.bed.activate("Go back to sleep")
	_whisper_and_mirror(token)
	await _wait_for_bed()


## Na het pakketje (of 3 kasten): gefluister uit de badkamer. Kijk je in de spiegel...
func _whisper_and_mirror(token: int) -> void:
	await _wait_until(func(): return _package_opened or _checked >= 3, 300.0)
	await Game.wait(2.0)
	if not _alive(token):
		return
	# wacht tot je niet met iets bezig bent (bijv. een kast vasthoudt)
	await _wait_until(func(): return _still_awake() or Game.phase != Game.Phase.NIGHT, 60.0)
	if not _still_awake() or not _alive(token):
		return
	player.fear = 0.7
	Sfx.play_at("whisper", ap.mirror.global_position, 0.0)
	await Game.wait(0.8)
	hud.say("Someone whispers your name. From the bathroom.", 4.0)
	ap.mirror.delay = 0.45
	if await _mirror_stare(600.0) and _alive(token):
		await _mirror_scare()


func _package_event(token: int) -> void:
	await Game.wait_for_task("package")
	if not _alive(token):
		return
	ap.spots.package.deactivate()
	Sfx.play_at("rustle", ap.package.global_position, -4.0, 1.3)
	var ordered: String = Game.orders[1].to_lower() if Game.orders.size() > 1 else "something"
	await hud.show_page("The package from Amazin. It's inside the house.\nThe front door is still locked.\n\nYou ordered: %s.\n\nBut inside is... your lunchbox. The one that was missing.\nThere's a sandwich in it. It's days old." % ordered)
	_package_opened = true
	player.fear = 0.6
	hud.say("Who put this here?", 2.5)


func _ajar_closet_comment(token: int) -> void:
	if await _wait_until(func(): return ap.room_at(player.global_position) == "hall", 120.0) and _alive(token):
		if not ap.closets[3].was_opened:
			hud.say("The hall closet is open a little. Was it like that before?", 3.5)


## De woonkamerlamp gaat aan... en dan kapot.
func _living_light_dies(token: int) -> void:
	var sw := ap.switch_for("living")
	if not await _wait_until(func(): return sw.is_on, 300.0) or not _alive(token):
		return
	await Game.wait(3.0)
	if not _alive(token):
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
		if _checked >= ap.closets.size() or _force_sleep:
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


## Loopt deze nacht nog? (voor losse gebeurtenissen die "tegelijk" draaien)
func _alive(token: int) -> bool:
	return token == _token and Game.phase == Game.Phase.NIGHT


# ================================================================== TELEFOON

func _on_phone() -> void:
	if Game.phase != Game.Phase.NIGHT or player.locked:
		return
	match _phone_mode:
		"text_mom":
			_phone_mode = ""
			_phone_used = true
			Game.help += 1
			Game.flags["texted_mom_night"] = true
			hud.set_phone_hint("")
			Sfx.play("ui_click")
			await hud.say_wait("You: \"Mom, can you come home? Please. Something is wrong.\"", 3.5)
			await hud.say_wait("Delivered.", 2.0)
		"text_nobody":
			_phone_mode = ""
			hud.set_phone_hint("")
			Sfx.play("ui_click")
			await hud.say_wait("You: \"Mom, please come home.\"", 2.5)
			await hud.say_wait("Delivered. ...No answer.", 3.0)
		"call":
			_phone_mode = ""
			hud.set_phone_hint("")
			_outcome = "morning"


# ================================================================== NACHT 4
# Het huis klopt niet. De gang is langer. Er is een deur die er nooit was.

func _night_4() -> void:
	var token := _token
	_copy_done = false
	_set_late_steps(0.35)
	ap.set_long_hall(true)
	_closet_nudges(token)
	_long_hall_comment(token)
	_copy_room_event(token)
	await Game.wait(1.0)
	hud.say("It's 03:33. Again.", 3.0)
	# pas naar bed na de kopie-kamer (of na 3 minuten)
	await _wait_until(func(): return not ap.long_hall and _copy_done, 180.0)
	ap.spots.bed.activate("Go back to sleep")
	await _wait_for_bed()


func _long_hall_comment(token: int) -> void:
	if await _wait_until(func(): return ap.room_at(player.global_position) == "hall" and player.is_looking_at(Vector3(15.0, 1.2, 4.75), 30.0), 300.0) and _alive(token):
		player.fear = 0.6
		hud.say("The hallway... it's longer. That's not possible.", 3.5)
		await Game.wait(4.0)
		if _alive(token):
			hud.say("There's a door at the end. There was never a door there.", 3.5)


## Kasten gaan vanzelf een stukje open... terwijl je ernaar kijkt.
func _closet_nudges(token: int) -> void:
	while _alive(token):
		await Game.wait(randf_range(5.0, 9.0))
		if not _alive(token) or not _still_awake():
			continue
		for c in ap.closets:
			var dist := c.center().distance_to(player.global_position)
			if c.angle < 1.0 and not c.was_opened and dist < 5.0 and player.is_looking_at(c.center(), 30.0):
				c.nudge(16.0)
				break


## Achter de nieuwe deur: jouw kamer. Met iemand in jouw bed.
func _copy_room_event(token: int) -> void:
	if not await _wait_until(func(): return player.global_position.x > 19.3 and player.state == Player.State.WALK, 900.0):
		return
	if not _alive(token):
		return
	player.fear = 0.8
	hud.say("This is... my room?", 3.0)
	var head := ap.sleeper_head.global_position
	await _wait_until(func(): return player.global_position.distance_to(head) < 2.0 or (player.is_looking_at(head, 12.0) and player.global_position.distance_to(head) < 3.2), 40.0)
	if not _alive(token):
		return
	# het hoofd draait naar je toe
	var dir := (player.get_camera().global_position - head).normalized()
	ap.sleeper_head.global_basis = Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2.0)
	Sfx.play("stinger", -2.0)
	Game.post.jolt(1.0)
	player.fear = 1.0
	await Game.wait(0.6)
	hud.say("It's me.", 2.0)
	await Game.wait(1.4)
	player.locked = true
	await hud.fade_out(0.1)
	ap.set_long_hall(false)
	ap.sleeper_head.rotation = Vector3.ZERO
	player.place_at(ap.markers.hall_east)
	await Game.wait(1.2)
	await hud.fade_in(1.0)
	player.locked = false
	player.fear = 0.5
	_copy_done = true
	hud.say("...The hallway is normal again.", 3.0)


## Terug in bed... er staat iets in de deuropening. Verstop je!
func _doorway_figure() -> void:
	ap.spots.bed.deactivate()
	player.set_flashlight(false)
	player.lie_in_bed(ap.markers.bed_head, ap.markers.bed_side)
	player.locked = false
	player.allow_get_up = false
	player.can_hide = true
	ap.doors.bedroom.set_angle(165.0)
	await Game.wait(2.5)
	var bed: Vector3 = ap.markers.bed_head.global_position
	# zwak licht in de gang, zodat je het silhouet ziet
	var backlight := OmniLight3D.new()
	backlight.omni_range = 4.5
	backlight.light_energy = 1.6
	backlight.light_color = Color(0.5, 0.55, 0.8)
	ap.add_child(backlight)
	backlight.global_position = Vector3(3.5, 1.4, 6.1)
	ap.show_shadow(Vector3(3.75, 0, 4.15), bed)
	Sfx.play_at("breath", Vector3(3.75, 1.6, 4.1), -2.0, 0.8)
	player.fear = 0.8
	hud.say("There's something in the doorway.", 3.0)
	await Game.wait(2.0)
	hud.say("Hide.  [Space]", 4.0)
	var hidden := await _wait_until(func(): return player.hiding, 8.0)
	if not hidden:
		# dichterbij... aan het voeteneind
		ap.show_shadow(Vector3(1.7, 0, 2.5), bed)
		Sfx.play("stinger", -6.0)
		Game.post.jolt(0.5)
		player.fear = 1.0
		hidden = await _wait_until(func(): return player.hiding, 10.0)
	if hidden:
		await Game.wait(2.5)
		Sfx.play_at("scratch", Vector3(1.2, 0.35, 2.0), 2.0)
		await Game.wait(4.5)
		ap.shadow.visible = false
		await _wait_until(func(): return not player.hiding, 10.0)
		player.fear = 0.3
		hud.say("...It's gone.", 2.5)
		await Game.wait(2.0)
	else:
		# je keek... het staat vlak voor je
		await _jumpscare(ap.shadow, ap.shadow, 0.45)
	ap.shadow.visible = false
	backlight.queue_free()
	if player.hiding:
		player.set_hiding(false)


# ================================================================== NACHT 5
# Mama roept je vanuit de keuken. Maar mama is niet thuis.

func _intro_mom() -> String:
	ap.set_fridge_open(true)
	await Game.wait(2.0)
	Sfx.play_at("whisper", Vector3(9.5, 1.5, 8.5), 4.0, 0.75)
	await Game.wait(0.6)
	await hud.say_wait("\"...Sweetie? Can you come to the kitchen?\"", 3.0)
	player.fear = 0.4
	await hud.say_wait("Mom? You're home?", 2.5)
	player.locked = false
	player.allow_get_up = true
	return await _wait_get_up_or_hide()


func _night_5() -> void:
	_set_late_steps(0.3)
	# geen bed deze nacht: de nacht eindigt pas na de kast in mama's kamer
	_night_5_events(_token)
	_mom_calls_again(_token)
	await _wait_for_bed()


## Blijf je weg uit de keuken? Dan roept "mama" nog een keer.
func _mom_calls_again(token: int) -> void:
	while _alive(token):
		if await _wait_until(func(): return ap.room_at(player.global_position) == "kitchen", 40.0):
			return
		if not _alive(token):
			return
		Sfx.play_at("whisper", Vector3(9.5, 1.5, 8.5), 4.0, 0.7)
		hud.say("\"Sweetie? I'm in the kitchen...\"", 3.0)


func _night_5_events(token: int) -> void:
	# 1. de keuken: niemand. Alleen de koelkast, wagenwijd open.
	if not await _wait_until(func(): return ap.room_at(player.global_position) == "kitchen", 100000.0) or not _alive(token):
		return
	await hud.say_wait("Mom?", 1.5)
	await hud.say_wait("Nobody. Just the fridge. Wide open.", 3.0)
	await Game.wait(2.0)
	if not _alive(token):
		return
	# 2. de TV
	ap.tv.set_mode(TV.Mode.STATIC)
	ap.tv.set_message("LOOK\nBEHIND\nYOU")
	Sfx.play("stinger", -8.0)
	Game.post.jolt(0.4)
	player.fear = 0.8
	await Game.wait(1.5)
	hud.say("The TV. There's something on the screen...\nLOOK BEHIND YOU.", 4.0)
	await _wait_until(func(): return player.is_looking_at(ap.tv.global_position + Vector3(0, 0.8, 0), 15.0), 20.0)
	await Game.wait(1.2)
	if not _alive(token):
		return
	# 3. achter je...
	await _wait_until(func(): return _still_awake(), 30.0)
	var back := player.get_camera().global_basis.z
	back.y = 0.0
	var pos := player.global_position + back.normalized() * 1.3
	ap.show_shadow(pos, player.global_position)
	Sfx.play_at("breath", pos + Vector3(0, 1.6, 0), 0.0)
	await _wait_until(func(): return player.is_looking_at(ap.shadow.global_position + Vector3(0, 1.3, 0), 25.0), 6.0)
	ap.shadow.scream()
	Game.post.jolt(1.0)
	await Game.wait(0.45)
	ap.shadow.visible = false
	player.fear = 1.0
	ap.tv.set_mode(TV.Mode.OFF)
	ap.tv.set_message("")
	await Game.wait(2.0)
	if not _alive(token):
		return
	hud.say("It was right behind me.", 3.0)
	player.fear = 0.6
	await Game.wait(4.0)
	if not _alive(token):
		return
	# 4. gekras... IN de kast in mama's kamer
	var closet: Door = ap.closets[2]
	closet.reset_closed()
	Sfx.play_at("door_close", closet.center(), -4.0, 1.3)
	var thing := Creature.new()
	thing.name = "Thing"
	thing.position = Vector3(0, 0, -0.32)
	thing.scale = Vector3(0.82, 0.82, 0.82)
	thing.menace = 1.0
	closet.get_parent().add_child(thing)
	_start_scratch(closet.center())
	_quiet_closets = true
	hud.say("Scratching. From inside the closet in Mom's room.", 3.5)
	await _wait_until(func(): return closet.angle > 40.0, 100000.0)
	_stop_scratch()
	if not _alive(token):
		thing.queue_free()
		_quiet_closets = false
		return
	# het springt eruit
	player.fear = 1.0
	await _jumpscare(thing, thing, 0.35, true)
	player.locked = true
	await hud.fade_out(0.05)
	thing.queue_free()
	_quiet_closets = false
	# wakker in bed
	player.allow_get_up = false
	player.lie_in_bed(ap.markers.bed_head, ap.markers.bed_side)
	player.fear = 0.4
	await Game.wait(2.0)
	await hud.fade_in(2.0)
	await hud.say_wait("...You're in bed. You don't remember walking back.", 3.5)
	player.locked = false
	player.allow_get_up = false
	_phone_mode = "text_mom"
	hud.set_phone_hint("[T] Text Mom")
	hud.say("Maybe you should text Mom.", 3.0)
	await _wait_until(func(): return _phone_used, 14.0)
	await Game.wait(4.0)
	hud.set_phone_hint("")
	_phone_mode = ""
	_force_sleep = true
	Game.complete_task("bed")


# ================================================================== NACHT 6
# De finale. Het is er echt. Het beweegt alleen als je niet kijkt.

func _night_6() -> String:
	while true:
		var result: String = await _night_6_attempt()
		if result != "caught":
			return result
		await _caught_sequence()
		_token += 1
	return ""


func _night_6_attempt() -> String:
	var stalker: Stalker = ap.stalker
	await _setup_night(6)
	_outcome = ""
	_checked = 0
	_bed_hunt_running = false
	var token := _token
	await hud.say_wait("Something is inside my house.", 3.0)
	player.fear = 0.6
	await hud.say_wait("No. Someone. It's really here.", 3.0)
	player.locked = false
	player.allow_get_up = true
	stalker.speed = clampf(0.75 + 0.06 * Game.exhaustion, 0.75, 1.3)
	stalker.spawn("kit")
	var on_caught := func(): _outcome = "caught"
	stalker.caught.connect(on_caught)
	Game.closet_opened.connect(_on_closet_opened_n6)
	var good := Game.help >= Game.HELP_FOR_GOOD_ENDING
	_phone_mode = "call" if good else "text_nobody"
	hud.set_phone_hint("[T] Call Mom" if good else "[T] Text Mom")
	if good:
		_mom_message(token)
	await Game.wait(1.0)
	hud.say("Don't let it get close. Don't look away.", 4.0)

	var hide_time := 0.0
	var lie_time := 0.0
	var got_up := false
	while _outcome == "":
		await get_tree().process_frame
		var dt := get_process_delta_time()
		if player.state == Player.State.WALK:
			got_up = true
			lie_time = 0.0
		else:
			lie_time += dt
		if player.hiding:
			hide_time += dt
			if not got_up and hide_time > 75.0:
				_outcome = "awake"
		# in bed: het komt naar je toe
		if player.state == Player.State.LYING and stalker.active and not _bed_hunt_running and (player.hiding or lie_time > 15.0):
			_bed_hunt(stalker)
		# gluren terwijl het vlakbij is = gepakt
		if player.state == Player.State.LYING and not player.hiding and stalker.visible and not Game.godmode:
			if stalker.global_position.distance_to(ap.markers.bed_head.global_position) < 2.3:
				_outcome = "caught"

	stalker.caught.disconnect(on_caught)
	Game.closet_opened.disconnect(_on_closet_opened_n6)
	hud.set_phone_hint("")
	_phone_mode = ""
	match _outcome:
		"caught":
			return "caught"
		"morning":
			stalker.despawn()
			return "morning"
		"check":
			stalker.despawn()
			return "check"
		"awake":
			stalker.despawn()
			return "awake"
	return _outcome


func _mom_message(token: int) -> void:
	await Game.wait(20.0)
	if not _alive(token) or _outcome != "":
		return
	Sfx.play("ui_click", -2.0, 0.6)
	await Game.wait(0.3)
	Sfx.play("ui_click", -2.0, 0.6)
	hud.say("Your phone buzzes.\nMom: \"Are you awake? I have a bad feeling. Call me.\"", 5.0)


## Je ligt in bed. Het komt naar je kamer. Krab... krab... krab.
func _bed_hunt(stalker: Stalker) -> void:
	_bed_hunt_running = true
	var token := _token
	await stalker.walk_to_node("bed_door")
	if not _alive(token) or _outcome != "":
		_bed_hunt_running = false
		return
	stalker.frozen = true
	for spot in [Vector3(3.75, 1.0, 3.9), Vector3(4.35, 1.0, 2.2), Vector3(1.25, 0.35, 1.9)]:
		if not _alive(token) or _outcome != "" or player.state != Player.State.LYING:
			break
		stalker.global_position = Vector3(spot.x - 0.3 if spot.x > 4 else spot.x + 0.4, 0, spot.z)
		Sfx.play_at("scratch", spot, 3.0, randf_range(0.8, 1.0))
		player.fear = 1.0
		await Game.wait(3.8)
	stalker.frozen = false
	if _alive(token) and _outcome == "" and player.hiding:
		# je hebt niet gekeken. Het gaat weg.
		stalker.spawn("kit")
		await Game.wait(1.0)
		hud.say("...It's gone. For now.", 2.5)
		player.fear = 0.5
	await Game.wait(12.0)
	_bed_hunt_running = false


## Nacht 6: de laatste kast die je opent... daar zit iets in.
func _on_closet_opened_n6(closet: Door) -> void:
	_checked += 1
	if _checked < ap.closets.size():
		hud.say(CLOSET_LINES[(_checked - 1) % CLOSET_LINES.size()], 2.0)
		return
	var you := Props.person(closet.get_parent(), "You", Vector3(0, 0, -0.3), 0.0, Color(0.32, 0.38, 0.6), false, false, Color(0.25, 0.16, 0.1))
	you.scale = Vector3(0.95, 0.95, 0.95)
	ap.stalker.despawn()
	player.locked = true
	player.fear = 1.0
	await Game.wait(0.8)
	await hud.say_wait("It's you.", 2.0)
	Sfx.play_at("whisper", closet.center() + Vector3(0, 0.4, 0), 2.0, 0.9)
	await hud.say_wait("\"Something is inside my house.\"", 3.0)
	Sfx.play("stinger", 0.0)
	Game.post.jolt(1.2)
	await hud.fade_out(0.1)
	you.queue_free()
	_outcome = "check"


## Het monster vlak voor je gezicht, mond open, schreeuw, beeld schudt.
## `lunge` = het springt naar je toe in plaats van er ineens te staan.
func _jumpscare(root: Node3D, creature: Creature, dist := 0.4, lunge := false) -> void:
	var cam := player.get_camera()
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	root.visible = true
	creature.still = false
	root.global_rotation.y = atan2(-fwd.x, -fwd.z) # gezicht naar jou toe
	var target := root.global_position + (cam.global_position + fwd * dist) - creature.head_position()
	creature.scream()
	Game.post.jolt(1.6)
	player.gripping = true # beeld schudt en zoomt in
	if lunge:
		var t := create_tween()
		t.tween_property(root, "global_position", target, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		await t.finished
		await Game.wait(0.45)
	else:
		root.global_position = target
		await Game.wait(0.75)
	player.gripping = false


func _caught_sequence() -> void:
	player.locked = true
	var stalker: Stalker = ap.stalker
	stalker.active = false
	await _jumpscare(stalker, stalker.body, 0.38)
	await hud.fade_out(0.05)
	stalker.despawn()
	if player.hiding:
		player.set_hiding(false)
	Sfx.set_muffled(false)
	await Game.wait(1.0)
	await hud.title_card(["It got you."], 2.0)
	await hud.title_card(["03:33"], 1.5)


# ================================================================== EINDES

func play_ending(ending: String) -> void:
	Game.flags["ending"] = ending
	player.locked = true
	match ending:
		"morning":
			Sfx.play("ui_click")
			await hud.say_wait("You call Mom.", 2.0)
			await hud.say_wait("Mom: \"Sweetie? What's wrong? ...Okay. Okay. I'm coming home right now. Stay on the phone with me.\"", 5.0)
			ap.stalker.despawn()
			ap.set_all_lights(true)
			Game.post.set_night(false)
			player.fear = 0.0
			await hud.say_wait("You tell her everything. The closets. The footsteps. The mirror.", 4.5)
			await hud.fade_out(3.0)
			await hud.title_card([
				"She comes home.",
				"She sits with you until the sun comes up.",
				"In the morning there's a sandwich waiting for you. And a note:",
				"\"Tomorrow we'll go talk to someone. Together.\nWe'll figure this out. Love, Mom.\"",
			], 3.5)
			await hud.title_card(["ENDING 1 / 3\n\nMORNING"], 3.5)
			await hud.title_card(["If you ever feel like this:\ntalk to someone you trust.\nYou don't have to deal with it alone."], 4.5)
		"check":
			await hud.title_card([
				"You close the closet.",
				"Then you check the next one.",
				"And the next one.",
				"Every night.",
			], 2.5)
			await hud.title_card(["ENDING 2 / 3\n\nCHECK AGAIN"], 3.5)
		"awake":
			ap.set_alarm(true)
			await hud.fade_out(3.0)
			ap.set_alarm(false)
			await hud.title_card([
				"You never looked.",
				"The alarm goes off. The sun is up.",
				"Was it ever really there?",
			], 3.0)
			await hud.title_card(["ENDING 3 / 3\n\nAWAKE"], 3.5)
	player.set_hiding(false)
	Sfx.set_muffled(false)
