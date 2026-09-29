extends Node
## Regie van de dag: ochtend, school en de middag/avond.
## Hier staat WAT er gebeurt en welke tekst er komt. Pas gerust aan!

var ap: Apartment:
	get: return Game.apartment
var player: Player:
	get: return Game.player
var hud: Node:
	get: return Game.hud

var _breakfast := false
var _lunch := false
var _busy := false


# ================================================================== OCHTEND

func run_morning(day: int) -> void:
	Game.phase = Game.Phase.MORNING
	_breakfast = false
	_lunch = false
	ap.reset_for(false)
	ap.set_mood("morning")
	ap.set_clock("07:00")
	Game.post.set_night(false)
	player.night_mode = false
	player.can_hide = false
	player.allow_get_up = true
	player.fear = 0.0
	player.lie_in_bed(ap.markers.bed_head, ap.markers.bed_side)
	player.locked = true
	hud.clear_objectives()

	await hud.title_card([Game.DAY_NAMES[day - 1]], 2.0)
	ap.set_alarm(true)
	await hud.fade_in(1.5)
	player.locked = false
	hud.set_objectives([["alarm", "Turn off the alarm"], ["breakfast", "Make breakfast"], ["school", "Go to school"]])
	ap.spots.alarm.activate("Turn off the alarm")
	ap.spots.bread.activate("Make a sandwich")
	ap.spots.lunch.activate("Pack your lunch")
	ap.spots.front_door.activate("Go to school")
	if day == 2:
		hud.say("I'm so tired...", 3.0)
	elif day == 3:
		ap.lunchbox.visible = false # je broodtrommel is weg... (zie nacht 3)
		hud.say("My phone is almost dead. I forgot to charge it. Again.", 3.5)
	elif day == 4:
		_clock_glitch()
	elif day >= 5:
		ap.strange_chair.visible = true
		await Game.wait(1.5)
		hud.say("There's a chair in the corner of your room.\nYou don't own that chair.", 4.5)

	var on_task := _on_morning_task.bind(day)
	Game.task_done.connect(on_task)
	await Game.wait_for_task("front_door")
	Game.task_done.disconnect(on_task)
	player.locked = true
	for id in ["alarm", "bread", "lunch", "front_door"]:
		ap.spots[id].deactivate()

	if not _breakfast:
		Game.exhaustion += 1
		Game.flags["skipped_breakfast_%d" % day] = true
	if not _lunch:
		Game.exhaustion += 1
		Game.flags["forgot_lunch_%d" % day] = true
	ap.set_alarm(false)
	Sfx.play("door_close", -4.0)
	await hud.fade_out(1.0)
	hud.clear_objectives()


## Dag 4: de wekker zegt heel even iets anders...
func _clock_glitch() -> void:
	await Game.wait(4.0)
	ap.set_clock("03:33")
	await Game.wait(0.4)
	ap.set_clock("07:00")
	await Game.wait(1.0)
	hud.say("Did the clock just say 03:33?", 3.0)


## Zaterdag: geen school. Je bent de hele dag thuis. Alleen.
func run_saturday() -> void:
	player.locked = true
	await hud.title_card([Game.DAY_NAMES[5], "No school today.", "The whole day at home. Alone."], 2.5)
	await run_afternoon(6)


func _on_morning_task(id: String, day: int) -> void:
	match id:
		"alarm":
			ap.set_alarm(false)
			ap.spots.alarm.deactivate()
			hud.complete_objective("alarm")
			Sfx.play("switch", -6.0, 0.8)
			hud.say("Ugh. Another day.")
		"bread":
			ap.spots.bread.deactivate()
			_breakfast = true
			Sfx.play("pickup", -6.0)
			await hud.blink()
			hud.complete_objective("breakfast")
			if day == 1:
				await hud.say_wait("You eat a sandwich. Chocolate sprinkles.", 2.5)
				if not _lunch:
					hud.say("Don't forget your lunch.", 3.0)
			elif day == 2:
				hud.say("The bread is almost gone. Nobody bought new bread.", 3.5)
			elif day == 3:
				hud.say("There's no bread left. You eat a dry cracker.", 3.5)
			else:
				hud.say("There's nothing left to eat. Nothing at all.", 3.5)
		"lunch":
			ap.spots.lunch.deactivate()
			if day == 3:
				hud.say("Your lunchbox is gone. You always leave it here...", 3.5)
				return
			if day >= 4:
				hud.say("Your lunchbox is back. You don't want to open it.", 3.5)
				return
			_lunch = true
			Sfx.play("pickup", -6.0, 0.8)
			hud.say("You pack your lunch.", 2.5)


# ================================================================== SCHOOL
# Een korte cutscene: je zit in de klas en kan rondkijken, maar niet lopen.

var school: School:
	get: return Game.school


func run_school(day: int) -> void:
	Game.phase = Game.Phase.SCHOOL
	if day == 5:
		# je weet niet eens meer dat je naar school ging
		player.locked = true
		await hud.title_card([
			"School.",
			"You don't remember getting there.",
			"Someone says your name. You don't answer.",
			"The bell rings. It's already over.",
		], 2.8)
		return
	ap.set_mood("school")
	Game.post.set_night(false)
	player.night_mode = false
	player.can_hide = false
	player.allow_get_up = false
	player.fear = 0.0
	player.sit_at(school.seat_marker)
	player.locked = true
	school.board_label.text = "MATH  -  p. %d" % (41 + day)
	school.teacher.position = Vector3(4.6, 0, 0.8)
	school.teacher.rotation.y = 0.0
	school.reset_figure()
	school.set_empty(false)
	school.set_eyes(true)
	school.everyone_look_at(null)

	var murmur: AudioStreamPlayer = Sfx.loop("murmur", -16.0, "Ambience", self)
	await hud.title_card(["School."], 1.5)
	Sfx.play("school_bell", -10.0)
	await hud.fade_in(1.5)
	player.locked = false

	match day:
		1:
			await _school_day_1()
		2:
			await _school_day_2(murmur)
		3:
			await _school_day_3(murmur)
		4:
			await _school_day_4()
		_:
			await Game.wait(3.0)

	if Game.flags.get("forgot_lunch_%d" % day, false):
		Sfx.play("school_bell", -10.0)
		await hud.say_wait("Lunch break." if day == 1 else "Lunch break. Again.", 2.0)
		if day >= 3:
			await hud.say_wait("No lunch. Your lunchbox is still missing.", 2.5)
		else:
			await hud.say_wait("You forgot your lunch." if day == 1 else "You forgot your lunch. Again.", 2.5)

	await Game.wait(1.0)
	Sfx.play("school_bell", -8.0)
	player.locked = true
	var t := create_tween()
	t.tween_property(murmur, "volume_db", -60.0, 1.5)
	await hud.fade_out(1.5)
	murmur.queue_free()
	Game.post.set_param("distortion", 0.0)
	Game.post.set_night(false)
	school.reset_figure()
	school.set_empty(false)
	school.everyone_look_at(null)


func _school_day_3(murmur: AudioStreamPlayer) -> void:
	await _teacher("\"Can someone read the next part out loud?\"")
	var t := create_tween()
	t.tween_property(murmur, "volume_db", -26.0, 3.0)
	await hud.say_wait("The voices blur together.", 3.0)
	# je valt in slaap...
	player.locked = true
	await hud.fade_out(2.5)
	# DROOM: de klas is leeg en donker
	school.set_empty(true)
	murmur.volume_db = -80.0
	Game.post.set_night(true)
	Game.post.set_param("distortion", 0.35)
	player.fear = 0.5
	await Game.wait(1.0)
	await hud.fade_in(2.0)
	player.locked = false
	await Game.wait(2.5)
	hud.say("...Where is everyone?", 3.0)
	await Game.wait(2.0)
	# naast je, bij de lege stoel...
	school.figure_at_seat(Vector2i(2, 3), player.global_position)
	Sfx.play_at("breath", school.figure.global_position + Vector3(0, 1.6, 0), -8.0)
	var waited := 0.0
	while waited < 8.0 and not player.is_looking_at(school.figure.global_position + Vector3(0, 1.3, 0), 18.0):
		await get_tree().process_frame
		waited += get_process_delta_time()
	Sfx.play("stinger", -2.0)
	Game.post.jolt(1.0)
	player.fear = 1.0
	await Game.wait(0.25)
	await hud.fade_out(0.1)
	# wakker!
	school.reset_figure()
	school.set_empty(false)
	Game.post.set_night(false)
	Game.post.set_param("distortion", 0.0)
	murmur.volume_db = -16.0
	school.everyone_look_at(player.global_position)
	school.face(school.teacher, player.global_position)
	await hud.fade_in(0.2)
	await _teacher("\"...HEY. Are you with us?\"", 2.5)
	player.fear = 0.4
	await hud.say_wait("You fell asleep. Everyone is looking at you.", 3.0)
	school.everyone_look_at(null)
	player.fear = 0.0
	if Game.flags.get("told_teacher", false):
		await _teacher("\"Come see me after class, okay?\"", 2.5)
		var pick: int = await hud.choose("After class...", ["Go see the teacher", "Leave quickly"])
		if pick == 0:
			Game.help += 1
			Game.flags["talked_after_class"] = true
			await _teacher("\"You don't have to deal with this alone. Talk to someone at home, or the school counselor. Okay?\"", 4.5)
		else:
			await hud.say_wait("You leave before the teacher can say anything.", 3.0)
	school.teacher.rotation.y = 0.0


func _school_day_4() -> void:
	await _teacher("\"Today we're going to talk about...\"", 2.5)
	await Game.wait(1.0)
	school.set_eyes(false) # niemand heeft nog ogen
	await _teacher("\"...you ...sleep ...home ...alone ...closets...\"", 3.5)
	player.fear = 0.5
	hud.say("Their faces... something is wrong with their faces.", 4.0)
	await Game.wait(5.0)
	await hud.fade_out(0.12)
	school.set_eyes(true)
	await hud.fade_in(0.12)
	player.fear = 0.0
	await hud.say_wait("You blink. Everything is normal.", 2.5)
	await _teacher("\"...and that's why sleep is so important. Any questions?\"", 3.5)


func _teacher(text: String, seconds := 3.0) -> void:
	await hud.say_wait("Teacher: " + text, seconds)


func _school_day_1() -> void:
	await _teacher("\"Okay everyone. Page 42.\"")
	await hud.say_wait("Math. Dutch. More math.", 2.5)
	# ogen vallen dicht...
	hud.say("You can barely keep your eyes open.", 4.0)
	for i in 2:
		await hud.fade_out(1.2)
		await Game.wait(0.4)
		await hud.fade_in(0.3)
		await Game.wait(1.0)
	# iets in je ooghoek
	school.figure.visible = true
	await Game.wait(1.0)
	player.fear = 0.4
	hud.say("Something moves in the corner of your eye.", 4.0)
	var waited := 0.0
	while waited < 10.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if player.is_looking_at(school.figure.global_position + Vector3(0, 1.2, 0), 16.0):
			break
	# zodra je kijkt: weg
	school.figure.visible = false
	Game.post.jolt(0.35)
	player.fear = 0.15
	await Game.wait(0.8)
	await hud.say_wait("When you look, there is nothing there.", 3.0)
	player.fear = 0.0


func _school_day_2(murmur: AudioStreamPlayer) -> void:
	murmur.pitch_scale = 0.8
	Game.post.tween_param("distortion", 0.12, 3.0)
	await hud.say_wait("Everything feels slower today.", 3.0)
	# de leraar kijkt steeds naar je
	school.face(school.teacher, player.global_position)
	await hud.say_wait("The teacher keeps looking at you.", 3.0)
	await Game.wait(1.0)
	# ...en loopt naar je toe
	await school.walk(school.teacher, [Vector3(4.0, 0, 1.8), Vector3(4.0, 0, 6.0)])
	school.face(school.teacher, player.global_position)
	await Game.wait(0.6)
	var pick: int = await hud.choose("Teacher: \"Hey. Are you okay? You look really tired.\"", [
		"\"I'm fine.\"",
		"\"I haven't been sleeping well.\"",
	])
	if pick == 1:
		Game.help += 1
		Game.flags["told_teacher"] = true
		await _teacher("\"Thanks for telling me. My door is always open, okay?\"", 3.5)
	else:
		await _teacher("\"...Alright.\"", 2.0)
	await school.walk(school.teacher, [Vector3(4.0, 0, 1.8), Vector3(4.6, 0, 0.8)])
	school.teacher.rotation.y = 0.0
	await Game.wait(1.0)
	# een klasgenoot draait zich om en staart
	var head: Node3D = school.starer.get_node("Head")
	school.face(head, player.global_position)
	player.fear = 0.35
	hud.say("A classmate is staring at you.", 4.0)
	var waited := 0.0
	while waited < 6.0 and not player.is_looking_at(head.global_position, 12.0):
		await get_tree().process_frame
		waited += get_process_delta_time()
	await Game.wait(1.5)
	await hud.fade_out(0.12)
	head.rotation.y = 0.0
	await hud.fade_in(0.12)
	player.fear = 0.0
	await hud.say_wait("You blink. They're looking at the board.", 3.0)
	Game.post.tween_param("distortion", 0.0, 2.0)


# ================================================================== MIDDAG / AVOND

func run_afternoon(day: int) -> void:
	Game.phase = Game.Phase.AFTERNOON
	ap.reset_for(false)
	ap.set_mood("evening")
	ap.set_clock("20:41")
	ap.strange_chair.visible = day >= 5
	player.place_at(ap.markers.bed_side if day >= 6 else ap.markers.front_door_in)
	player.locked = false
	await hud.fade_in(1.2)
	match day:
		1, 2:
			hud.say("Home. Nobody's here. As usual.", 3.0)
		3:
			hud.say("Home. Nobody's here. And the package never came.", 3.5)
		4:
			hud.say("Home. Your lunchbox is on the counter. You don't touch it.", 3.5)
		5:
			hud.say("Home. The door was unlocked. You're sure you locked it this morning.", 4.0)
		_:
			hud.say("The day goes by. It's already dark outside.", 3.5)
	var objectives := [["game", "Play a game"]]
	if day <= 5:
		objectives.append(["order", "Order something online"])
		ap.spots.laptop.activate("Order something")
	objectives.append(["news", "Check the news" if day <= 3 else "Check your phone"])
	objectives.append(["lights", "Turn off all the lights"])
	objectives.append(["bed", "Go to bed"])
	hud.set_objectives(objectives)
	ap.spots.tv.activate("Play a game")
	ap.spots.phone.activate("Check the news" if day <= 3 else "Check your phone")
	ap.spots.bed.activate("Go to bed")
	Game.lights_changed.connect(_on_lights_changed)
	var on_task := _on_afternoon_task.bind(day)
	Game.task_done.connect(on_task)
	while true:
		await Game.wait_for_task("bed")
		if _busy:
			continue
		if ap.all_lights_off():
			break
		hud.say("I should turn off all the lights first.", 3.0)
	Game.task_done.disconnect(on_task)
	Game.lights_changed.disconnect(_on_lights_changed)
	ap.spots.bed.deactivate()
	hud.complete_objective("bed")
	player.lie_in_bed(ap.markers.bed_head, ap.markers.bed_side)
	player.locked = true
	Sfx.play("rustle", -8.0)
	await Game.wait(1.0)
	await hud.fade_out(2.5)
	hud.clear_objectives()
	await Game.wait(1.0)


func _on_lights_changed() -> void:
	hud.complete_objective("lights", ap.all_lights_off())


func _on_afternoon_task(id: String, day: int) -> void:
	if _busy:
		return
	match id:
		"tv":
			_busy = true
			ap.spots.tv.deactivate()
			ap.tv.set_mode(TV.Mode.STATIC if day == 5 else TV.Mode.GAME)
			player.locked = true
			match day:
				1, 2:
					await hud.say_wait("You play for a while.", 3.0)
				3:
					await hud.say_wait("In the game, your character keeps opening doors. Closets. One after another.", 3.5)
					await hud.say_wait("You don't remember this level.", 2.5)
				4:
					await hud.say_wait("In the game, your character walks down a hallway. It never ends.", 3.5)
				5:
					await hud.say_wait("The game won't start. Just static.", 3.0)
				_:
					await hud.say_wait("You play. You don't really see the screen.", 3.0)
			var pick: int = await hud.choose("It's getting late...", ["\"Just one more round.\"", "\"No, that's enough.\""])
			if pick == 0:
				Game.exhaustion += 1
				await hud.fade_out(0.8)
				ap.set_clock("23:52")
				await Game.wait(1.0)
				await hud.fade_in(0.8)
				hud.say("It's almost midnight. Oops.", 3.0)
			ap.tv.set_mode(TV.Mode.OFF)
			player.locked = false
			hud.complete_objective("game")
			_busy = false
		"laptop":
			_busy = true
			ap.spots.laptop.deactivate()
			ap.set_laptop_screen(true)
			var items: Array
			var question := "AMAZIN  -  Recommended for you"
			if day == 1:
				items = ["Wireless headphones", "A night light", "Comic book: 'Deep Space Kid'"]
			elif day == 4:
				question = "AMAZIN  -  Your cart:\n\n'Something Is Inside My House' (book)\nYou didn't add this."
				items = ["Remove it", "Order it anyway"]
			elif day >= 5:
				question = "AMAZIN  -  Order status:\n\nDELIVERED.\nDelivered to: your bedroom closet."
				items = ["Close the laptop"]
			elif day >= 3:
				question += "\n\nYesterday's order says: DELIVERED.\nYou never got anything."
				items = ["Batteries", "A night light", "A lock for your bedroom door"]
			else:
				question += "\n\nThere is already something in your cart:\na door lock. You don't remember adding it."
				items = ["The door lock", "A night light", "A sleeping mask"]
			var pick: int = await hud.choose(question, items)
			ap.set_laptop_screen(false)
			if day == 4 and pick == 0:
				hud.say("You remove it. When you look again, it's back in your cart.", 3.5)
			elif day >= 5:
				hud.say("You close the laptop. Fast.", 2.5)
			else:
				if day == 4:
					Game.exhaustion += 1
				Game.orders.append(items[pick])
				hud.say("Order placed. Delivery: tomorrow.", 2.5)
			hud.complete_objective("order")
			_busy = false
		"phone":
			_busy = true
			ap.spots.phone.deactivate()
			if day <= 3:
				await _read_news(day)
			else:
				await _phone_menu(day)
			hud.complete_objective("news")
			_busy = false


## Dag 4+: je telefoon. Nieuws lezen, of... mama appen.
func _phone_menu(day: int) -> void:
	var options := ["Read the news", "Text Mom"]
	if day == 5 and Game.flags.get("talked_after_class", false):
		options.append("Call the school counselor")
	options.append("Put it away")
	var pick: int = await hud.choose("Your phone.  3% battery.", options)
	match options[pick]:
		"Read the news":
			await _read_news(day)
		"Text Mom":
			await _text_mom(day)
		"Call the school counselor":
			Game.help += 1
			Game.flags["called_counselor"] = true
			await hud.show_page("Voicemail: \"Hi, you've reached the school counselor. Leave a message and I'll call you back on Monday.\"\n\nYou leave a message. Your voice shakes.\nBut it feels a little better.")


func _text_mom(day: int) -> void:
	var pick: int = await hud.choose("Text Mom:", [
		"\"When are you coming home?\"",
		"\"I can't sleep. I think something is really wrong.\"",
		"(don't send anything)",
	])
	if pick == 2:
		return
	if pick == 1:
		Game.help += 1
		Game.flags["texted_mom_%d" % day] = true
	await hud.say_wait("Delivered.", 1.5)
	await Game.wait(1.5)
	var reply := "\"Working late again, sorry sweetie. Try to get some sleep.\""
	if pick == 1:
		match day:
			4:
				reply = "\"Oh no. Are you okay? I'm on night shift, but call me if you need me.\""
			5:
				reply = "\"I'm worried about you. We'll talk this weekend, okay? Keep your phone close.\""
			_:
				if Game.help >= Game.HELP_FOR_GOOD_ENDING:
					reply = "\"I'm coming home early tomorrow. Tonight, if anything happens: CALL me. Promise?\""
				else:
					reply = "\"Late shift again tonight. Sorry. Tomorrow, okay?\""
	Sfx.play("ui_click", -4.0, 0.7)
	await hud.show_page("Mom:\n\n" + reply)


func _read_news(day: int) -> void:
	if day == 4:
		Game.exhaustion += 1
		await hud.show_page("NEWS\n\n'Neighbours worried about kid on the 3rd floor'\n\n\"We hear footsteps at night. Every night. Doors opening and closing. The kid lives alone with their mother, who works night shifts.\"")
		return
	if day == 5:
		await hud.show_page("NEWS\n\n\n\n(The page is empty.)")
		return
	if day >= 6:
		await hud.show_page("NEWS\n\nNo new articles.")
		return
	if day == 1:
		await hud.show_page("NEWS\n\n- Local bakery wins prize for best 'tompouce'\n- Storm expected this weekend\n- New game console sold out in two hours")
		return
	if day >= 3:
		var p3: int = await hud.choose("NEWS", [
			"Read: 'Strange break-in on your street'",
			"Read: 'Can't sleep? Try this'",
			"Close",
		])
		match p3:
			0:
				Game.exhaustion += 1
				await hud.show_page("\"The resident says someone walks through the house every night. Police found no signs of a break-in. 'Nothing was taken,' they say. 'But things are never where I left them.'\"")
			1:
				Game.help += 1
				Game.flags["read_sleep_tips"] = true
				await hud.show_page("\"Put your phone away an hour before bed. Keep a normal rhythm. And if worries keep you awake: say them out loud to someone you trust.\"")
		return
	var pick: int = await hud.choose("NEWS", [
		"Read: 'Study: 1 in 3 teens don't get enough sleep'",
		"Read: 'Break-ins in the area: police ask residents to lock doors'",
		"Close",
	])
	match pick:
		0:
			Game.help += 1
			Game.flags["read_sleep_article"] = true
			await hud.show_page("\"Not sleeping enough can make you anxious. Some people even start to see or hear things that aren't there.\n\nIf you recognise this: talk to someone you trust.\"")
		1:
			Game.exhaustion += 1
			await hud.show_page("\"...residents are advised to check their doors and windows every night before going to bed.\"")
