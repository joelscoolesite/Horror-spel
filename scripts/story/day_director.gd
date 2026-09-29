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
			else:
				hud.say("The bread is almost gone. Nobody bought new bread.", 3.5)
		"lunch":
			ap.spots.lunch.deactivate()
			_lunch = true
			Sfx.play("pickup", -6.0, 0.8)
			hud.say("You pack your lunch.", 2.5)


# ================================================================== SCHOOL

func run_school(day: int) -> void:
	Game.phase = Game.Phase.SCHOOL
	player.locked = true
	var murmur: AudioStreamPlayer = Sfx.loop("murmur", -14.0, "Ambience", self)
	Sfx.play("school_bell", -10.0)
	match day:
		1:
			await hud.title_card([
				"School.",
				"Math. Dutch. More math.",
				"You can barely keep your eyes open.",
				"Something moves in the corner of your eye.",
				"When you look, there is nothing there.",
			])
		2:
			await hud.title_card([
				"School.",
				"Everything feels slower today.",
				"The teacher keeps looking at you.",
			])
			var pick: int = await hud.choose("\"Hey. Are you okay? You look really tired.\"", [
				"\"I'm fine.\"",
				"\"I haven't been sleeping well.\"",
			])
			if pick == 1:
				Game.help += 1
				Game.flags["told_teacher"] = true
				await hud.title_card(["\"Thanks for telling me.\nMy door is always open, okay?\""], 3.0)
			else:
				await hud.title_card(["\"...Alright.\""], 2.0)
			await hud.title_card([
				"A classmate is staring at you.",
				"You blink. They're looking at the board.",
			])
		_:
			await hud.title_card(["School."])
	if Game.flags.get("forgot_lunch_%d" % day, false):
		await hud.title_card(["You forgot your lunch." if day == 1 else "You forgot your lunch. Again."])
	var t := create_tween()
	t.tween_property(murmur, "volume_db", -60.0, 1.0)
	await t.finished
	murmur.queue_free()


# ================================================================== MIDDAG / AVOND

func run_afternoon(day: int) -> void:
	Game.phase = Game.Phase.AFTERNOON
	ap.reset_for(false)
	ap.set_mood("evening")
	ap.set_clock("20:41")
	player.place_at(ap.markers.front_door_in)
	player.locked = false
	await hud.fade_in(1.2)
	hud.say("Home. Nobody's here. As usual.", 3.0)
	hud.set_objectives([
		["game", "Play a game"],
		["order", "Order something online"],
		["news", "Check the news"],
		["lights", "Turn off all the lights"],
		["bed", "Go to bed"],
	])
	ap.spots.tv.activate("Play a game")
	ap.spots.laptop.activate("Order something")
	ap.spots.phone.activate("Check the news")
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
			ap.tv.set_mode(TV.Mode.GAME)
			player.locked = true
			await hud.say_wait("You play for a while.", 3.0)
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
			else:
				question += "\n\nThere is already something in your cart:\na door lock. You don't remember adding it."
				items = ["The door lock", "A night light", "A sleeping mask"]
			var pick: int = await hud.choose(question, items)
			Game.orders.append(items[pick])
			ap.set_laptop_screen(false)
			hud.say("Order placed. Delivery: tomorrow.", 2.5)
			hud.complete_objective("order")
			_busy = false
		"phone":
			_busy = true
			ap.spots.phone.deactivate()
			await _read_news(day)
			hud.complete_objective("news")
			_busy = false


func _read_news(day: int) -> void:
	if day == 1:
		await hud.show_page("NEWS\n\n- Local bakery wins prize for best 'tompouce'\n- Storm expected this weekend\n- New game console sold out in two hours")
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
