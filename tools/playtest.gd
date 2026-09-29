extends Node
## Ontwikkel-hulpje: een bot die de demo van begin tot eind "speelt",
## om te checken dat het verhaal nergens vastloopt.
## Starten met:  godot --headless --path . res://scenes/main.tscn -- --playtest

var _cooldown := 0.0
var _choices := 0
var _last_phase := -1
var _last_thought := ""
var _pressed: Array[String] = []
var _phone_done := ""
var _kitchen_visited := false
var _copy_visited := false
var _turned := false


func _ready() -> void:
	Engine.time_scale = 6.0
	Game.godmode = not ("--nogod" in OS.get_cmdline_user_args()) # de bot kan niet wegrennen van het wezen
	if "--good" in OS.get_cmdline_user_args():
		Game.help = 5 # test het goede einde

	print("[bot] start")


func _process(delta: float) -> void:
	for a in _pressed:
		_send(a, false)
	_pressed.clear()

	var hud = Game.hud
	var ap: Apartment = Game.apartment
	var player: Player = Game.player
	if hud == null or ap == null or player == null:
		return
	if player.global_position.y < -1.0:
		print("[bot] FOUT: speler valt door de vloer! ", player.global_position)
	if Game.phase != _last_phase:
		_last_phase = Game.phase
		print("[bot] dag %d, fase %s  (uitputting=%d, hulp=%d)" % [Game.day, Game.Phase.keys()[Game.phase], Game.exhaustion, Game.help])
	if hud._thought.text != _last_thought and hud._thought.modulate.a > 0.5:
		_last_thought = hud._thought.text
		print("[bot]   \"%s\"" % _last_thought.replace("\n", " "))

	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = 0.4

	if hud._choice.visible:
		if hud._choice.get_index() < hud._fade.get_index():
			print("[bot] FOUT: keuze zit onder het zwarte scherm!")
		var text: String = hud._choice_label.text
		if text.contains("[E]  Close"):
			print("[bot]   (pagina gelezen)")
			_press("interact")
		else:
			# wissel keuzes af zodat we verschillende paden testen
			var pick := 1 if _choices % 2 == 0 else 0
			if text.contains("You haven't checked"):
				pick = 0
			print("[bot]   keuze: ", text.get_slice("\n", 0), " -> optie ", pick + 1)
			_press("choice_%d" % (pick + 1))
			_choices += 1
		return
	if player.locked:
		return

	match Game.phase:
		Game.Phase.MORNING:
			for id in ["alarm", "bread", "lunch", "front_door"]:
				if ap.spots[id].active:
					print("[bot]   doe: ", id)
					Game.complete_task(id)
					return
		Game.Phase.AFTERNOON:
			for id in ["tv", "laptop", "phone"]:
				if ap.spots[id].active:
					print("[bot]   doe: ", id)
					Game.complete_task(id)
					return
			if not ap.all_lights_off():
				print("[bot]   lichten uit")
				ap.set_all_lights(false)
				return
			if ap.spots.bed.active:
				print("[bot]   naar bed")
				Game.complete_task("bed")
		Game.Phase.NIGHT:
			if hud._phone_hint.text != "" and hud._phone_hint.text != _phone_done:
				_phone_done = hud._phone_hint.text
				print("[bot]   telefoon: ", _phone_done)
				Game.phone_pressed.emit()
				return
			if "--awake" in OS.get_cmdline_user_args() and Game.day >= 6:
				# test het geheime einde: nooit uit bed, altijd onder de deken
				if player.state == Player.State.LYING and not player.hiding and player.allow_get_up:
					print("[bot]   blijf onder de deken...")
					player.set_hiding(true)
				return
			if player.state == Player.State.LYING:
				if ap.shadow.visible and player.can_hide and not player.hiding:
					print("[bot]   verstoppen onder de deken!")
					player.set_hiding(true)
				elif player.hiding and not ap.shadow.visible and not ap.stalker.visible:
					player.set_hiding(false)
				elif player.allow_get_up:
					print("[bot]   uit bed")
					player.get_up()
				return
			if "--nogod" in OS.get_cmdline_user_args() and Game.day >= 6:
				if not _turned:
					_turned = true
					player._yaw += PI # kijk weg van de deur
				return # test: blijf stilstaan tot het wezen je pakt
			if ap.long_hall and not _copy_visited:
				_copy_visited = true
				print("[bot]   naar de kopie-kamer")
				player.global_position = Vector3(21.6, 0, 4.2)
				_cooldown = 3.0
				return
			if ap._fridge_open.visible and not _kitchen_visited:
				_kitchen_visited = true
				print("[bot]   naar de keuken")
				player.global_position = Vector3(9.5, 0, 7.5)
				_cooldown = 3.0
				return
			if ap.spots.package.active:
				print("[bot]   pakketje open")
				Game.complete_task("package")
				return
			if ap.tv.spot.active:
				print("[bot]   TV uit")
				Game.complete_task("tv")
				return
			player.stopped_walking.emit()
			for c in ap.closets:
				if not c.was_opened:
					print("[bot]   kast open (hand erop): ", c.get_parent().name)
					c.interact(player)
					_cooldown = 1.0
					return
			if ap.spots.bed.active:
				print("[bot]   terug naar bed")
				Game.complete_task("bed")


func _press(action: String) -> void:
	_send(action, true)
	_pressed.append(action)


func _send(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)


func _exit_tree() -> void:
	print("[bot] einde: ", Game.flags.get("ending", "?"))
	print("[bot] terug naar menu -> klaar. uitputting=%d hulp=%d flags=%s orders=%s" % [Game.exhaustion, Game.help, Game.flags, Game.orders])
	get_tree().quit()
