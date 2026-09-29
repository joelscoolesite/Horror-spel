class_name Player
extends CharacterBody3D
## De speler: het kind. First-person.
##
##  WASD  lopen            Muis  rondkijken
##  E     iets doen        LMB   vasthouden = deur/kast langzaam opentrekken
##  F     telefoonlicht    Ctrl  bukken
##  Q     luisteren        Spatie (in bed) onder de deken

signal stepped(surface: String) ## elke voetstap
signal stopped_walking ## net gestopt met lopen (voor "één voetstap te veel")
signal got_up ## uit bed gestapt
signal hide_changed(hiding: bool)

enum State { WALK, LYING }

const DAY_SPEED := 2.3
const NIGHT_SPEED := 1.2 ## 's nachts loop je langzaam...
const CROUCH_SPEED := 0.7
const EYE_HEIGHT := 1.45 ## het is een kind, dus niet zo lang
const CROUCH_EYE := 0.85
const REACH := 2.0
const BATTERY_SECONDS := 200.0

var state := State.WALK
var locked := false ## true = speler kan niks (tijdens tekst/keuzes)
var night_mode := false
var allow_get_up := true
var can_hide := false
var hiding := false
var listening := false
var battery := 1.0
var flashlight_on := false
var current_surface := "wood"
## 0..1: hoe bang het kind is (hartslag). Wordt door de nacht-regie gezet.
var fear := 0.0
## true = je hand ligt op een kast (hart bonkt, beeld zoomt in en trilt)
var gripping := false
## Debug: door muren vliegen / sneller lopen
var noclip := false
var speed_multiplier := 1.0

var _yaw := 0.0
var _pitch := 0.0
var _lie_yaw := 0.0
var _lie_pos := Vector3.ZERO
var _stand_marker: Node3D
var _head: Node3D
var _camera: Camera3D
var _ray: RayCast3D
var _flashlight: SpotLight3D
var _flashlight_spill: SpotLight3D
var _heartbeat: AudioStreamPlayer
var _focus: Interactable = null
var _dragging: Interactable = null
var _stride := 0.0
var _bob := 0.0
var _eye := EYE_HEIGHT
var _moving_time := 0.0
var _still_time := 0.0
var _getting_up := false
var _look_limits := Vector4(-1.6, 1.6, -0.6, 1.2) ## yaw min/max, pitch min/max als je ligt/zit
var _safe_pos := Vector3.ZERO


func _ready() -> void:
	Game.player = self
	collision_layer = 4
	collision_mask = Build.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = 1.5
	shape.shape = capsule
	shape.position.y = 0.75
	add_child(shape)

	_head = Node3D.new()
	_head.position.y = EYE_HEIGHT
	add_child(_head)
	_camera = Camera3D.new()
	_camera.near = 0.03
	_camera.far = 60.0
	_camera.fov = 72.0
	# laag 2 = het lichaam van het kind, dat alleen de spiegel ziet
	_camera.cull_mask = 0xFFFFF & ~(1 << (Mirror.REFLECTION_LAYER - 1))
	_head.add_child(_camera)
	_camera.make_current()

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -REACH)
	_ray.collision_mask = Build.LAYER_WORLD | Build.LAYER_INTERACT
	_ray.collide_with_areas = true
	_ray.add_exception(self)
	_camera.add_child(_ray)

	_flashlight = SpotLight3D.new()
	_flashlight.position = Vector3(0.12, -0.12, 0)
	_flashlight.spot_range = 11.0
	_flashlight.spot_angle = 24.0
	_flashlight.spot_attenuation = 0.8
	_flashlight.spot_angle_attenuation = 3.0
	_flashlight.light_energy = 2.0
	_flashlight.light_color = Color(1.0, 0.96, 0.88)
	_flashlight.visible = false
	_camera.add_child(_flashlight)
	# tweede, zwakkere en bredere bundel eromheen = zachte rand
	_flashlight_spill = SpotLight3D.new()
	_flashlight_spill.spot_range = 9.0
	_flashlight_spill.spot_angle = 42.0
	_flashlight_spill.spot_attenuation = 1.0
	_flashlight_spill.light_energy = 0.45
	_flashlight_spill.light_color = _flashlight.light_color
	_flashlight.add_child(_flashlight_spill)

	_heartbeat = AudioStreamPlayer.new()
	_heartbeat.stream = Sfx.stream("heartbeat")
	_heartbeat.bus = "SFX"
	_heartbeat.volume_db = -80.0
	add_child(_heartbeat)
	_heartbeat.play()


# ------------------------------------------------------------------ plekken

## Zet de speler op een plek (Marker3D uit het appartement).
func place_at(marker: Node3D) -> void:
	_leave_bed_view()
	state = State.WALK
	global_position = marker.global_position
	_safe_pos = global_position
	_yaw = marker.global_rotation.y
	_pitch = 0.0
	velocity = Vector3.ZERO


## Leg de speler in bed. `head` = plek van je hoofd, `stand` = waar je uitstapt.
func lie_in_bed(head: Node3D, stand: Node3D) -> void:
	_release_drag()
	state = State.LYING
	_stand_marker = stand
	global_position = stand.global_position
	_lie_pos = head.global_position
	_lie_yaw = head.global_rotation.y
	_yaw = 0.0
	_pitch = 0.25
	_look_limits = Vector4(-1.6, 1.6, -0.6, 1.2)
	_head.top_level = true
	_head.global_position = _lie_pos
	set_flashlight(false)


## Ga zitten (bijv. op school). Je kan rondkijken, maar niet lopen.
func sit_at(head: Node3D) -> void:
	lie_in_bed(head, head)
	_pitch = -0.05
	_look_limits = Vector4(-1.9, 1.9, -0.8, 0.6)


func get_camera() -> Camera3D:
	return _camera


## Waar je hand vandaan komt als je iets vastpakt (vlak voor de camera, onderin).
func hand_start_position() -> Vector3:
	var b := _camera.global_basis
	return _camera.global_position - b.z * 0.25 - b.y * 0.3 + b.x * 0.1


## Kijkt de speler ongeveer naar dit punt? (binnen `max_degrees` graden)
func is_looking_at(point: Vector3, max_degrees := 15.0) -> bool:
	var forward := -_camera.global_basis.z
	var to := (point - _camera.global_position).normalized()
	return rad_to_deg(forward.angle_to(to)) < max_degrees


func get_up() -> void:
	if state != State.LYING or _getting_up:
		return
	_getting_up = true
	if hiding:
		set_hiding(false)
	Sfx.play("rustle", -10.0)
	if Game.hud:
		await Game.hud.blink()
	_getting_up = false
	place_at(_stand_marker)
	got_up.emit()


func _leave_bed_view() -> void:
	_head.top_level = false
	_head.position = Vector3(0, _eye, 0)
	_head.rotation = Vector3.ZERO


func set_hiding(on: bool) -> void:
	if hiding == on:
		return
	hiding = on
	Sfx.play("rustle", -6.0 if on else -10.0)
	Sfx.set_muffled(on)
	if Game.post:
		Game.post.set_hiding(on)
	hide_changed.emit(on)


# ------------------------------------------------------------------ invoer

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _dragging:
			_dragging.drag(event.screen_relative)
			return
		if locked or hiding:
			return
		var sens := Game.mouse_sensitivity
		_yaw -= event.screen_relative.x * sens
		_pitch = clampf(_pitch - event.screen_relative.y * sens, -1.45, 1.45)
		if state == State.LYING:
			_yaw = clampf(_yaw, _look_limits.x, _look_limits.y)
			_pitch = clampf(_pitch, _look_limits.z, _look_limits.w)
		return

	if locked:
		return
	if event.is_action_pressed("interact"):
		if _focus:
			_focus.interact(self)
		elif state == State.LYING and allow_get_up and not hiding:
			get_up()
	elif event.is_action_pressed("drag"):
		if _focus and _focus.can_drag() and state == State.WALK:
			_dragging = _focus
			_dragging.drag_begin()
	elif event.is_action_released("drag"):
		_release_drag()
	elif event.is_action_pressed("flashlight"):
		set_flashlight(not flashlight_on)
	elif event.is_action_pressed("hide"):
		if state == State.LYING and can_hide:
			set_hiding(not hiding)


func _release_drag() -> void:
	if _dragging:
		_dragging.drag_end()
		_dragging = null


func set_flashlight(on: bool) -> void:
	if on and battery <= 0.0:
		if Game.hud:
			Game.hud.say("The battery is dead.")
		on = false
	if on != flashlight_on:
		Sfx.play("switch", -14.0, 1.6)
	flashlight_on = on
	_flashlight.visible = on
	if Game.hud:
		Game.hud.show_battery(on)


# ------------------------------------------------------------------ elke frame

func _physics_process(delta: float) -> void:
	match state:
		State.WALK:
			_walk(delta)
		State.LYING:
			velocity = Vector3.ZERO
			var down := -0.25 if hiding else 0.0
			_head.global_position = _head.global_position.lerp(_lie_pos + Vector3(0, down, 0), 6.0 * delta)
			_head.global_rotation = Vector3(_pitch if not hiding else 0.9, _lie_yaw + _yaw, 0)
	_update_focus()
	_update_flashlight(delta)
	_update_heartbeat(delta)
	_update_grip(delta)


func _update_grip(delta: float) -> void:
	_camera.fov = lerpf(_camera.fov, 60.0 if gripping else 72.0, 2.5 * delta)
	if gripping:
		_camera.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.004
	else:
		_camera.position = Vector3.ZERO


func _walk(delta: float) -> void:
	rotation.y = _yaw
	_head.rotation.x = _pitch

	var input := Vector2.ZERO
	listening = not locked and Input.is_action_pressed("listen")
	if not locked and not listening:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var crouching := not locked and Input.is_action_pressed("crouch")
	var speed := CROUCH_SPEED if crouching else (NIGHT_SPEED if night_mode else DAY_SPEED)
	if noclip:
		var fly := _camera.global_basis * Vector3(input.x, 0, input.y)
		if Input.is_action_pressed("hide"):
			fly.y += 1.0
		if crouching:
			fly.y -= 1.0
		global_position += fly * 5.0 * speed_multiplier * delta
		velocity = Vector3.ZERO
		return
	speed *= speed_multiplier
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var target := dir * speed
	velocity.x = lerpf(velocity.x, target.x, 10.0 * delta)
	velocity.z = lerpf(velocity.z, target.z, 10.0 * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	# Veiligheid: val je ergens doorheen, dan sta je weer op de laatste veilige plek.
	if is_on_floor():
		_safe_pos = global_position
	elif global_position.y < -3.0:
		global_position = _safe_pos
		velocity = Vector3.ZERO

	var hspeed := Vector2(velocity.x, velocity.z).length()
	# voetstappen
	_stride += hspeed * delta
	var stride_len := 0.55 if night_mode else 0.7
	if _stride > stride_len:
		_stride = 0.0
		_footstep(crouching)
	# stoppen met lopen detecteren
	if hspeed > 0.4:
		_moving_time += delta
		_still_time = 0.0
	else:
		if _moving_time > 0.5:
			_still_time += delta
			if _still_time > 0.35:
				_moving_time = 0.0
				stopped_walking.emit()
		else:
			_moving_time = 0.0
	# hoofd wiebelt een beetje bij het lopen
	_bob += hspeed * delta * 7.0
	_eye = lerpf(_eye, CROUCH_EYE if crouching else EYE_HEIGHT, 8.0 * delta)
	_head.position.y = _eye + sin(_bob) * 0.025 * clampf(hspeed, 0.0, 1.0)
	_head.position.x = cos(_bob * 0.5) * 0.015 * clampf(hspeed, 0.0, 1.0)

	# vastgehouden deur loslaten als je wegloopt
	if _dragging and _dragging.global_position.distance_to(global_position) > 2.8:
		_release_drag()


func _footstep(crouching: bool) -> void:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 0.4, Build.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and hit.collider.has_meta("surface"):
		current_surface = hit.collider.get_meta("surface")
	var vol := -14.0 if crouching else (-8.0 if night_mode else -5.0)
	Sfx.play("step_%s_%d" % [current_surface, randi_range(1, 3)], vol, randf_range(0.9, 1.1))
	stepped.emit(current_surface)


func _update_focus() -> void:
	var found: Interactable = null
	if not locked and not hiding and _dragging == null:
		_ray.force_raycast_update()
		if _ray.is_colliding():
			var n: Node = _ray.get_collider()
			while n and not (n is Interactable):
				n = n.get_parent()
			if n and (n as Interactable).get_prompt() != "":
				found = n
	_focus = found
	if Game.hud == null:
		return
	var prompt := ""
	if locked:
		prompt = ""
	elif _dragging:
		prompt = "Move the mouse down to pull"
	elif hiding:
		prompt = "[Space] Peek out"
	elif _focus:
		prompt = _focus.get_prompt()
	elif state == State.LYING and allow_get_up:
		prompt = "[E] Get up" + ("    [Space] Hide under the blanket" if can_hide else "")
	Game.hud.set_prompt(prompt)


func _update_flashlight(delta: float) -> void:
	if not flashlight_on:
		return
	battery = maxf(0.0, battery - delta / BATTERY_SECONDS)
	if Game.hud:
		Game.hud.set_battery(battery)
	var e := 1.0
	if battery < 0.15:
		# bijna leeg: flikkeren
		e = battery / 0.15 * (0.4 + 0.6 * float(randf() > 0.1))
	_flashlight.light_energy = 2.0 * e
	_flashlight_spill.light_energy = 0.45 * e
	if battery <= 0.0:
		set_flashlight(false)


func _update_heartbeat(delta: float) -> void:
	var target := fear
	if (_dragging and night_mode) or gripping:
		target = maxf(target, 0.9)
	if listening:
		target = maxf(target, 0.4)
	var level := db_to_linear(_heartbeat.volume_db)
	level = lerpf(level, target, 2.0 * delta)
	_heartbeat.volume_db = linear_to_db(maxf(level, 0.0001))
	_heartbeat.pitch_scale = 1.0 + level * 0.35
	if Game.post:
		Game.post.set_listening(listening)
