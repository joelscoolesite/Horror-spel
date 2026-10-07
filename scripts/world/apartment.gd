class_name Apartment
extends Node3D
## Het hele appartement: muren, vloeren, ramen, lampen, meubels en kasten.
## Alles wordt opgebouwd als de game start (zie _ready).
##
## Plattegrond (bovenaanzicht, x naar rechts, z naar beneden, in meters):
##
##   x=0        4.5       7                  12
##   +----------+---------+------------------+  z=0
##   | SLAAPK.  | BADKAMER| KAMER OUDER      |
##   +---[d]----+---[d]---+-[d]--------------+  z=4
##   |[kast]           GANG                  |
##   +------[open]------------------[open]---+  z=5.5
##   | WOONKAMER             | KEUKEN        |
##   |                     [open]            |
##   +--[voordeur]-----------+---------------+  z=10.5

const H := 2.6 ## hoogte van het plafond
const T := 0.15 ## dikte van muren

## Kamers als rechthoek: Rect2(x, z, breedte, diepte)
const ROOMS := {
	"bedroom": Rect2(0, 0, 4.5, 4),
	"bathroom": Rect2(4.5, 0, 2.5, 4),
	"parent": Rect2(7, 0, 5, 4),
	"hall": Rect2(0, 4, 12, 1.5),
	"living": Rect2(0, 5.5, 7, 5),
	"kitchen": Rect2(7, 5.5, 5, 5),
}

var spots := {} ## naam -> TaskSpot
var closets: Array[Door] = [] ## de 5 kasten die je 's nachts checkt
var doors := {} ## naam -> Door (kamerdeuren)
var switches: Array[LightSwitch] = []
var markers := {} ## naam -> Marker3D (plekken waar de speler kan beginnen)
var tv: TV
var mirror: Mirror
var lunchbox: MeshInstance3D
var package: Node3D ## het pakketje van Amazin (nacht 3)
var extension: Node3D ## de gang die langer is dan hij hoort (nacht 4)
var copy_door: Door
var sleeper_head: Node3D ## iemand in jouw bed... (nacht 4)
var shadow: Creature ## het monster, dat de regie overal kan neerzetten
var strange_chair: Node3D ## een stoel die niet van jou is (dag 5+)
var long_hall := false
var stalker: Stalker ## het wezen (nacht 6)
var _hall_end_wall: Array = []
var _fridge_open: Node3D
var clock_label: Label3D
var env: Environment

var _windows: Array[Dictionary] = []
var _alarm: AudioStreamPlayer3D
var _laptop_screen: ShaderMaterial
var _wall_mats := {}
var _outside: ShaderMaterial


func _ready() -> void:
	Game.apartment = self
	seed(42) # zelfde "willekeurige" boeken/kleding elke keer
	_build_environment()
	_build_shell()
	_build_bedroom()
	_build_bathroom()
	_build_parent_room()
	_build_hall()
	_build_living_room()
	_build_kitchen()
	stalker = Stalker.new()
	stalker.name = "Stalker"
	add_child(stalker)
	Sfx.loop("room_tone", -14.0, "Ambience", self)
	randomize()


# ------------------------------------------------------------------ sfeer

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	we.environment = env
	add_child(we)


## "morning", "evening" of "night"
func set_mood(mood: String) -> void:
	match mood:
		"morning":
			env.ambient_light_color = Color(0.78, 0.78, 0.82)
			env.ambient_light_energy = 0.55
			env.fog_light_color = Color(0.65, 0.67, 0.7)
			env.fog_density = 0.025
			_set_windows(Color(0.75, 0.82, 0.92), Color(0.95, 0.93, 0.85), 0.0, Color(0.9, 0.92, 1.0), 1.3, 5.0)
			set_all_lights(false)
		"school":
			env.ambient_light_color = Color(0.8, 0.8, 0.85)
			env.ambient_light_energy = 0.6
			env.fog_light_color = Color(0.7, 0.72, 0.75)
			env.fog_density = 0.02
			set_all_lights(false)
		"evening":
			env.ambient_light_color = Color(0.4, 0.33, 0.42)
			env.ambient_light_energy = 0.3
			env.fog_light_color = Color(0.08, 0.06, 0.08)
			env.fog_density = 0.04
			_set_windows(Color(0.05, 0.05, 0.16), Color(0.4, 0.17, 0.2), 0.5, Color(0.6, 0.4, 0.5), 0.35, 4.0)
			set_all_lights(true)
		"night":
			env.ambient_light_color = Color(0.05, 0.06, 0.1)
			env.ambient_light_energy = 1.0
			env.fog_light_color = Color(0, 0, 0)
			env.fog_density = 0.11
			_set_windows(Color(0.01, 0.015, 0.04), Color(0.03, 0.035, 0.07), 0.35, Color(0.35, 0.42, 0.65), 0.35, 3.5)
			set_all_lights(false)
			# straatlantaarn schijnt oranje door het slaapkamerraam
			_windows[0].mat.set_shader_parameter("glow", 0.9)
			_windows[0].light.light_color = Color(0.9, 0.6, 0.3)
			_windows[0].light.light_energy = 0.4


func _set_windows(top: Color, bottom: Color, glow: float, light_color: Color, energy: float, light_range: float) -> void:
	for w in _windows:
		w.mat.set_shader_parameter("sky_top", top)
		w.mat.set_shader_parameter("sky_bottom", bottom)
		w.mat.set_shader_parameter("glow", glow)
		w.light.light_color = light_color
		w.light.light_energy = energy
		w.light.omni_range = light_range


func set_all_lights(on: bool) -> void:
	for s in switches:
		s.set_on(on)


func all_lights_off() -> bool:
	for s in switches:
		if s.is_on:
			return false
	return true


func set_clock(text: String) -> void:
	clock_label.text = text


func set_alarm(on: bool) -> void:
	if on:
		_alarm.play()
	else:
		_alarm.stop()


func set_laptop_screen(on: bool) -> void:
	_laptop_screen.set_shader_parameter("mode", 3 if on else 0)


## Alles klaarzetten voor een nieuwe dag of nacht.
func reset_for(night: bool) -> void:
	for c in closets:
		c.reset_closed()
	doors.bedroom.set_angle(0.0 if night else 85.0)
	doors.bathroom.set_angle(35.0 if night else 85.0)
	doors.parent.set_angle(20.0 if night else 85.0)
	for s in spots.values():
		s.deactivate()
	tv.set_mode(TV.Mode.OFF)
	tv.spot.deactivate()
	for s in switches:
		s.broken = false
	set_long_hall(false)
	set_fridge_open(false)
	tv.set_message("")
	shadow.visible = false
	stalker.despawn()
	sleeper_head.rotation = Vector3.ZERO
	copy_door.reset_closed()
	mirror.delay = 0.0
	mirror.frozen = false
	package.visible = false
	lunchbox.visible = true
	set_laptop_screen(false)
	set_alarm(false)


## Nacht 4: de gang loopt ineens verder, naar een deur die er nooit was.
func set_long_hall(on: bool) -> void:
	long_hall = on
	extension.visible = on
	for box in _hall_end_wall:
		box.visible = not on
		box.get_child(0).collision_layer = 0 if on else Build.LAYER_WORLD


## De vreemde stoel (dag 5+). Onzichtbaar = ook niet botsen!
func set_strange_chair(on: bool) -> void:
	strange_chair.visible = on
	for c in strange_chair.find_children("*", "StaticBody3D", true, false):
		c.collision_layer = Build.LAYER_WORLD if on else 0


func set_fridge_open(on: bool) -> void:
	_fridge_open.visible = on


## Zet de schaduw-gestalte ergens neer, kijkend naar `look_at_pos`.
func show_shadow(pos: Vector3, look_at_pos: Vector3) -> void:
	shadow.global_position = pos
	shadow.global_rotation.y = atan2(look_at_pos.x - pos.x, look_at_pos.z - pos.z)
	shadow.visible = true


func switch_for(room: String) -> LightSwitch:
	for s in switches:
		if s.room == room:
			return s
	return null


## In welke kamer is dit punt? ("" = nergens)
func room_at(pos: Vector3) -> String:
	for room in ROOMS:
		if ROOMS[room].has_point(Vector2(pos.x, pos.z)):
			return room
	return ""


# ------------------------------------------------------------------ bouwstenen

func _build_shell() -> void:
	var w := Color.WHITE
	_outside = Build.mat("wall_plain", Color(0.5, 0.5, 0.5), 1.0, true)
	_wall_mats = {
		"bedroom": Build.mat("wall_bedroom", w, 1.0, true),
		"bathroom": Build.mat("bath_tile", w, 1.0, true),
		"parent": Build.mat("wallpaper", Color(0.9, 0.85, 0.85), 1.0, true),
		"hall": Build.mat("wall_plain", w, 1.0, true),
		"living": Build.mat("wallpaper", w, 1.0, true),
		"kitchen": Build.mat("wall_plain", Color(1.0, 0.96, 0.86), 1.0, true),
	}
	var floors := {
		"bedroom": ["carpet", 1.0, "carpet"],
		"bathroom": ["bath_tile", 2.0, "tile"],
		"parent": ["wood_floor", 1.0, "wood"],
		"hall": ["wood_floor", 1.0, "wood"],
		"living": ["wood_floor", 1.0, "wood"],
		"kitchen": ["kitchen_floor", 1.0, "tile"],
	}
	for room in ROOMS:
		var r: Rect2 = ROOMS[room]
		var center := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
		var f: Array = floors[room]
		# dikke vloer (1 meter), zodat je er nooit doorheen kan zakken
		var fl := Build.box(self, Vector3(r.size.x, 1.0, r.size.y), center - Vector3(0, 1.0, 0), Build.mat(f[0], w, f[1], true), true, "Floor_" + room)
		fl.get_child(0).set_meta("surface", f[2])
		Build.box(self, Vector3(r.size.x, 0.1, r.size.y), center + Vector3(0, H, 0), Build.mat("ceiling", w, 1.0, true), false, "Ceiling_" + room)

	var m := _wall_mats
	# buitenmuren  (openingen: [begin, eind, onderkant, bovenkant])
	_wall_x(0.0, 0.0, 4.5, _outside, m.bedroom, [[1.4, 3.0, 0.9, 2.0]])
	_wall_x(0.0, 4.5, 7.0, _outside, m.bathroom)
	_wall_x(0.0, 7.0, 12.0, _outside, m.parent, [[9.0, 10.6, 0.9, 2.0]])
	_wall_x(10.5, 0.0, 7.0, m.living, _outside, [[1.2, 2.2, 0.0, 2.1]])
	_wall_x(10.5, 7.0, 12.0, m.kitchen, _outside)
	_wall_z(0.0, 0.0, 4.0, _outside, m.bedroom)
	_wall_z(0.0, 4.0, 5.5, _outside, m.hall)
	_wall_z(0.0, 5.5, 10.5, _outside, m.living, [[7.0, 8.6, 0.9, 2.0]])
	_wall_z(12.0, 0.0, 4.0, m.parent, _outside)
	_hall_end_wall = _wall_z(12.0, 4.0, 5.5, m.hall, _outside)
	_wall_z(12.0, 5.5, 10.5, m.kitchen, _outside, [[7.5, 8.8, 1.0, 2.0]])
	# binnenmuren
	_wall_x(4.0, 0.0, 4.5, m.bedroom, m.hall, [[3.3, 4.2, 0.0, 2.1]])
	_wall_x(4.0, 4.5, 7.0, m.bathroom, m.hall, [[5.3, 6.2, 0.0, 2.1]])
	_wall_x(4.0, 7.0, 12.0, m.parent, m.hall, [[7.4, 8.3, 0.0, 2.1]])
	_wall_z(4.5, 0.0, 4.0, m.bedroom, m.bathroom)
	_wall_z(7.0, 0.0, 4.0, m.bathroom, m.parent)
	_wall_x(5.5, 0.0, 7.0, m.hall, m.living, [[2.4, 3.9, 0.0, 2.2]])
	_wall_x(5.5, 7.0, 12.0, m.hall, m.kitchen, [[10.3, 11.3, 0.0, 2.1]])
	_wall_z(7.0, 5.5, 10.5, m.living, m.kitchen, [[7.2, 8.7, 0.0, 2.1]])

	# kamerdeuren
	_room_door("bedroom", 3.3, 4.2, 4.0)
	_room_door("bathroom", 5.3, 6.2, 4.0)
	_room_door("parent", 7.4, 8.3, 4.0)

	# ramen
	_window(Vector3(2.2, 1.45, 0.0), 0.0, Vector2(1.6, 1.1))
	_window(Vector3(9.8, 1.45, 0.0), 0.0, Vector2(1.6, 1.1))
	_window(Vector3(0.0, 1.45, 7.8), 90.0, Vector2(1.6, 1.1))
	_window(Vector3(12.0, 1.5, 8.15), -90.0, Vector2(1.3, 1.0))
	_build_extension()


## Muur langs de x-as (op diepte z). Kant a = noord (-z), kant b = zuid (+z).
func _wall_x(z: float, x0: float, x1: float, mat_a: Material, mat_b: Material, openings := [], parent: Node3D = null) -> Array:
	var boxes := []
	for s in _segments(x0, x1, openings):
		var size := Vector3(s[1] - s[0], s[3] - s[2], T * 0.5)
		var cx: float = (s[0] + s[1]) * 0.5
		boxes.append(Build.box(parent if parent else self, size, Vector3(cx, s[2], z - T * 0.25), mat_a))
		boxes.append(Build.box(parent if parent else self, size, Vector3(cx, s[2], z + T * 0.25), mat_b))
	return boxes


## Muur langs de z-as (op x). Kant a = west (-x), kant b = oost (+x).
func _wall_z(x: float, z0: float, z1: float, mat_a: Material, mat_b: Material, openings := [], parent: Node3D = null) -> Array:
	var boxes := []
	for s in _segments(z0, z1, openings):
		var size := Vector3(T * 0.5, s[3] - s[2], s[1] - s[0])
		var cz: float = (s[0] + s[1]) * 0.5
		boxes.append(Build.box(parent if parent else self, size, Vector3(x - T * 0.25, s[2], cz), mat_a))
		boxes.append(Build.box(parent if parent else self, size, Vector3(x + T * 0.25, s[2], cz), mat_b))
	return boxes


## De gang die langer wordt (nacht 4), met aan het eind een kopie van jouw kamer.
func _build_extension() -> void:
	extension = Node3D.new()
	extension.name = "Extension"
	add_child(extension)
	var w := Color.WHITE
	var hall_m: Material = _wall_mats.hall
	var room_m: Material = _wall_mats.bedroom
	# gang: x 12 -> 19
	var fl := Build.box(extension, Vector3(7.0, 1.0, 1.5), Vector3(15.5, -1.0, 4.75), Build.mat("wood_floor", w, 1.0, true), true)
	fl.get_child(0).set_meta("surface", "wood")
	Build.box(extension, Vector3(7.0, 0.1, 1.5), Vector3(15.5, H, 4.75), Build.mat("ceiling", w, 1.0, true), false)
	_wall_x(4.0, 12.0, 19.0, _outside, hall_m, [], extension)
	_wall_x(5.5, 12.0, 19.0, hall_m, _outside, [], extension)
	# kopie-kamer: x 19 -> 23.5, z 2.5 -> 7
	var cf := Build.box(extension, Vector3(4.5, 1.0, 4.5), Vector3(21.25, -1.0, 4.75), Build.mat("carpet", w, 1.0, true), true)
	cf.get_child(0).set_meta("surface", "carpet")
	Build.box(extension, Vector3(4.5, 0.1, 4.5), Vector3(21.25, H, 4.75), Build.mat("ceiling", w, 1.0, true), false)
	_wall_z(19.0, 2.5, 7.0, hall_m, room_m, [[4.3, 5.2, 0.0, 2.1]], extension)
	_wall_z(23.5, 2.5, 7.0, room_m, _outside, [], extension)
	_wall_x(2.5, 19.0, 23.5, _outside, room_m, [], extension)
	_wall_x(7.0, 19.0, 23.5, room_m, _outside, [], extension)
	copy_door = Door.new()
	copy_door.name = "CopyDoor"
	copy_door.width = 0.86
	copy_door.height = 2.08
	copy_door.thickness = 0.05
	copy_door.open_sign = 1.0
	copy_door.max_angle = 95.0
	copy_door.material = Build.mat("wood_white")
	copy_door.position = Vector3(19.0, 0.0, 4.32)
	copy_door.rotation_degrees.y = -90.0
	extension.add_child(copy_door)
	copy_door.build()
	# precies jouw kamer... bijna
	Props.bed(extension, "CopyBed", Vector3(22.5, 0, 2.575), 0.0, 1.0, 2.0)
	Props.nightstand(extension, Vector3(21.7, 0, 2.955))
	var clock := Build.label(extension, "03:33", Vector3(21.7, 0.56, 2.9), Color(1.0, 0.15, 0.1), 20)
	clock.rotation_degrees.y = 0.0
	var red := OmniLight3D.new()
	red.position = Vector3(21.7, 0.8, 3.1)
	red.omni_range = 2.5
	red.light_energy = 0.5
	red.light_color = Color(1.0, 0.2, 0.15)
	extension.add_child(red)
	Props.poster(extension, Vector3(23.42, 1.3, 4.5), -90.0)
	# iemand ligt in het bed
	var skin := Build.mat("plastic_white", Color(0.86, 0.66, 0.54))
	Build.box(extension, Vector3(0.55, 0.22, 1.2), Vector3(22.5, 0.42, 3.75), Build.mat("blanket", w, 2.0), false)
	sleeper_head = Build.group(extension, "SleeperHead", Vector3(22.5, 0.62, 2.95))
	Build.box(sleeper_head, Vector3(0.22, 0.22, 0.24), Vector3(0, -0.11, 0), skin, false)
	Build.box(sleeper_head, Vector3(0.24, 0.24, 0.08), Vector3(0, -0.12, -0.13), Build.mat("fabric_sheet", Color(0.25, 0.16, 0.1)), false)
	for sx in [-1, 1]:
		Build.box(sleeper_head, Vector3(0.035, 0.01, 0.025), Vector3(sx * 0.05, 0.11, 0.02), Build.mat("plastic_black"), false)
	extension.visible = false


## Knipt een muur in stukken rond deuren en ramen.
func _segments(from: float, to: float, openings: Array) -> Array:
	var out := []
	var cur := from
	for o in openings:
		if o[0] > cur:
			out.append([cur, o[0], 0.0, H])
		if o[2] > 0.0:
			out.append([o[0], o[1], 0.0, o[2]])
		if o[3] < H:
			out.append([o[0], o[1], o[3], H])
		cur = o[1]
	if cur < to:
		out.append([cur, to, 0.0, H])
	return out


func _room_door(room_name: String, x0: float, x1: float, z: float) -> void:
	var d := Door.new()
	d.name = "Door_" + room_name
	d.width = x1 - x0 - 0.04
	d.height = 2.08
	d.thickness = 0.05
	d.open_sign = 1.0
	d.max_angle = 95.0
	d.material = Build.mat("wood_white")
	d.position = Vector3(x0 + 0.02, 0.0, z)
	if room_name == "bedroom":
		d.max_angle = 165.0 # kan helemaal plat tegen de muur
	add_child(d)
	d.build()
	doors[room_name] = d
	# deurlijst
	var trim := Build.mat("wood_white", Color(0.9, 0.9, 0.88))
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(0.06, 2.1, T + 0.04), Vector3(x0 if side < 0 else x1, 0, z), trim, false)
	Build.box(self, Vector3(x1 - x0 + 0.12, 0.06, T + 0.04), Vector3((x0 + x1) * 0.5, 2.1, z), trim, false)


func _window(pos: Vector3, yaw: float, size: Vector2) -> void:
	var g := Build.group(self, "Window", pos, yaw)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/window.gdshader")
	Build.quad(g, size, Vector3.ZERO, m)
	# vensterbank (net boven de muur eronder, zodat ze niet flikkeren)
	Build.box(g, Vector3(size.x + 0.1, 0.04, 0.25), Vector3(0, -size.y * 0.5 + 0.005, 0.05), Build.mat("wood_white"), false)
	# gordijnen
	for side in [-1.0, 1.0]:
		Build.box(g, Vector3(0.3, size.y + 0.5, 0.04), Vector3(side * (size.x * 0.5 + 0.05), -size.y * 0.5 - 0.3, 0.15), Build.mat("fabric_sheet", Color(0.55, 0.45, 0.5)), false)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.1, 0.8)
	light.omni_attenuation = 1.5
	g.add_child(light)
	_windows.append({"mat": m, "light": light})


func _room_light(room: String, lamp_pos: Vector3, light_range: float, switch_pos: Vector3, switch_yaw: float) -> LightSwitch:
	var lamp_mat := Props.ceiling_lamp(self, lamp_pos + Vector3(0, H - 0.2, 0))
	var light := OmniLight3D.new()
	light.position = lamp_pos + Vector3(0, H - 0.35, 0)
	light.omni_range = light_range
	light.light_color = Color(1.0, 0.86, 0.66)
	light.light_energy = 1.1
	add_child(light)
	var sw := LightSwitch.new()
	sw.name = "Switch_" + room
	sw.room = room
	sw.position = switch_pos
	sw.rotation_degrees.y = switch_yaw
	sw.lights.append(light)
	sw.lamp_materials.append(lamp_mat)
	add_child(sw)
	sw.build()
	switches.append(sw)
	return sw


func _spot(spot_name: String, pos: Vector3, size: Vector3) -> TaskSpot:
	var s := TaskSpot.new()
	s.name = "Spot_" + spot_name
	s.task_id = spot_name
	s.position = pos
	add_child(s)
	s.add_hitbox(size)
	spots[spot_name] = s
	return s


## Een plek waar de speler kan staan, die naar `look_at_pos` kijkt.
func _marker(marker_name: String, pos: Vector3, look_at_pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = "Marker_" + marker_name
	m.position = pos
	m.rotation.y = atan2(-(look_at_pos.x - pos.x), -(look_at_pos.z - pos.z))
	add_child(m)
	markers[marker_name] = m


# ------------------------------------------------------------------ kamers

func _build_bedroom() -> void:
	Props.bed(self, "Bed", Vector3(0.65, 0, 0.075), 0.0, 1.0, 2.0)
	Props.nightstand(self, Vector3(1.45, 0, 0.455))
	# wekker
	Build.box(self, Vector3(0.07, 0.09, 0.16), Vector3(1.42, 0.5, 0.28), Build.mat("plastic_black"), false)
	clock_label = Build.label(self, "07:00", Vector3(1.37, 0.545, 0.28), Color(1.0, 0.15, 0.1), 20)
	clock_label.rotation_degrees.y = -90.0
	_alarm = AudioStreamPlayer3D.new()
	_alarm.stream = Sfx.stream("alarm")
	_alarm.bus = "SFX"
	_alarm.volume_db = -6.0
	_alarm.position = Vector3(1.42, 0.55, 0.28)
	add_child(_alarm)
	_spot("alarm", Vector3(1.42, 0.55, 0.28), Vector3(0.3, 0.3, 0.4))
	_spot("bed", Vector3(0.65, 0.5, 1.2), Vector3(1.0, 0.5, 1.8))

	closets.append(Props.closet(self, "Closet_Bedroom", Vector3(3.825, 0, 1.0), -90.0, 1.2, 2.0, 0.6, Build.mat("wood_light")))
	Props.desk(self, Vector3(0.625, 0, 3.0), 90.0)
	Props.chair(self, Vector3(1.05, 0, 3.0), -90.0)
	Props.poster(self, Vector3(0.08, 1.2, 3.0), 90.0)
	Props.rug(self, Vector3(2.4, 0, 2.3), Vector2(1.6, 1.2))
	# spullen op het bureau
	Build.box(self, Vector3(0.3, 0.03, 0.22), Vector3(0.35, 0.76, 2.8), Build.mat("fabric_sheet", Color(0.9, 0.9, 0.8)), false)
	Build.box(self, Vector3(0.35, 0.3, 0.12), Vector3(0.3, 0.76, 3.35), Build.mat("fabric_couch", Color(0.6, 0.4, 0.9)), false)

	_room_light("bedroom", Vector3(2.25, 0, 2.0), 5.0, Vector3(3.0, 1.2, 3.92), 180.0)
	# een stoel in de hoek, gericht op je bed. Die is niet van jou. (dag 5+)
	strange_chair = Props.chair(self, Vector3(4.1, 0, 2.55), -115.0, Build.mat("wood_dark"))
	set_strange_chair(false)
	# de schaduw-gestalte (hergebruikt in nacht 4 en 5)
	shadow = Creature.new()
	shadow.name = "Shadow"
	add_child(shadow)
	shadow.visible = false
	_marker("bed_head", Vector3(0.65, 0.62, 0.42), Vector3(0.65, 0.9, 3.0))
	_marker("bed_side", Vector3(1.6, 0, 1.4), Vector3(3.5, 0, 4.0))


func _build_bathroom() -> void:
	Props.bathtub(self, Vector3(5.55, 0, 0.795), 0.0)
	Props.toilet(self, Vector3(6.235, 0, 2.0), -90.0)
	Props.bath_sink(self, Vector3(5.015, 0, 2.2), 90.0)
	mirror = Mirror.new()
	mirror.name = "Mirror"
	mirror.position = Vector3(4.597, 1.45, 2.2)
	mirror.rotation_degrees.y = 90.0
	add_child(mirror)
	mirror.build(self)
	closets.append(Props.closet(self, "Closet_Bathroom", Vector3(6.525, 0, 3.0), -90.0, 0.6, 1.8, 0.4, Build.mat("wood_white"), false))
	Props.rug(self, Vector3(5.6, 0, 1.7), Vector2(0.9, 0.6), "carpet")
	_room_light("bathroom", Vector3(5.75, 0, 2.0), 4.0, Vector3(5.05, 1.2, 3.92), 180.0)


func _build_parent_room() -> void:
	Props.bed(self, "ParentBed", Vector3(11.925, 0, 2.0), -90.0, 1.6, 2.0, "fabric_parent")
	closets.append(Props.closet(self, "Closet_Parent", Vector3(7.675, 0, 1.2), 90.0, 1.2, 2.0, 0.6, Build.mat("wood_dark")))
	Props.dresser(self, Vector3(8.4, 0, 0.525), 0.0)
	Props.nightstand(self, Vector3(11.925, 0, 0.8), -90.0)
	_room_light("parent", Vector3(9.5, 0, 2.0), 5.5, Vector3(8.6, 1.2, 3.92), 180.0)


func _build_hall() -> void:
	closets.append(Props.closet(self, "Closet_Hall", Vector3(0.675, 0, 4.75), 90.0, 1.1, 2.1, 0.6, Build.mat("wood_white")))
	# schoenen en een kapstok
	Build.box(self, Vector3(0.8, 0.35, 0.3), Vector3(6.3, 0, 5.27), Build.mat("wood_dark"))
	Build.box(self, Vector3(0.28, 0.1, 0.12), Vector3(6.1, 0.35, 5.25), Build.mat("plastic_black"), false)
	Build.box(self, Vector3(0.28, 0.1, 0.12), Vector3(6.45, 0.35, 5.25), Build.mat("fabric_sheet", Color(0.8, 0.2, 0.2)), false)
	Build.box(self, Vector3(1.0, 0.04, 0.08), Vector3(9.3, 1.7, 5.4), Build.mat("wood_dark"), false)
	Build.box(self, Vector3(0.4, 0.9, 0.1), Vector3(9.0, 0.85, 5.33), Build.mat("fabric_couch", Color(0.6, 0.6, 0.7)), false)
	_room_light("hall", Vector3(6.0, 0, 4.75), 7.0, Vector3(2.9, 1.2, 4.08), 0.0)
	_marker("hall_east", Vector3(10.8, 0, 4.75), Vector3(0, 0, 4.75))


func _build_living_room() -> void:
	tv = TV.new()
	tv.name = "TV"
	tv.position = Vector3(4.6, 0, 9.975)
	tv.rotation_degrees.y = 180.0
	add_child(tv)
	tv.build()
	spots["tv"] = tv.spot

	Props.couch(self, Vector3(4.6, 0, 7.3), 0.0, 2.1)
	Props.table(self, Vector3(4.6, 0, 8.4), 1.0, 0.5, 0.42, Build.mat("wood_dark"))
	Props.rug(self, Vector3(4.6, 0, 8.4), Vector2(2.4, 1.8))
	Props.bookshelf(self, Vector3(0.395, 0, 9.5), 90.0)

	# laptop op de salontafel
	Build.box(self, Vector3(0.32, 0.02, 0.22), Vector3(4.3, 0.42, 8.4), Build.mat("metal", Color(0.5, 0.5, 0.55)), false)
	var lid := Build.group(self, "LaptopLid", Vector3(4.3, 0.44, 8.29), 180.0)
	lid.rotation_degrees.x = -15.0
	Build.box(lid, Vector3(0.32, 0.22, 0.01), Vector3(0, 0, 0), Build.mat("metal", Color(0.5, 0.5, 0.55)), false)
	_laptop_screen = ShaderMaterial.new()
	_laptop_screen.shader = preload("res://shaders/screen.gdshader")
	Build.quad(lid, Vector2(0.28, 0.18), Vector3(0, 0.11, 0.015), _laptop_screen)
	_spot("laptop", Vector3(4.3, 0.55, 8.35), Vector3(0.4, 0.3, 0.35))
	# telefoon
	Build.box(self, Vector3(0.07, 0.01, 0.14), Vector3(4.95, 0.42, 8.45), Build.mat("plastic_black"), false)
	_spot("phone", Vector3(4.95, 0.47, 8.45), Vector3(0.25, 0.15, 0.3))

	# voordeur
	Build.box(self, Vector3(0.96, 2.08, 0.06), Vector3(1.7, 0, 10.5), Build.mat("wood_dark", Color(0.8, 0.6, 0.6)))
	Build.box(self, Vector3(0.1, 0.03, 0.05), Vector3(2.05, 1.0, 10.45), Build.mat("metal"), false)
	Build.box(self, Vector3(0.02, 0.02, 0.02), Vector3(1.7, 1.45, 10.465), Build.mat("plastic_black"), false)
	_spot("front_door", Vector3(1.7, 1.05, 10.4), Vector3(1.0, 2.0, 0.3))
	_marker("front_door_in", Vector3(1.7, 0, 9.9), Vector3(2.8, 0, 6.0))
	# pakketje (alleen in nacht 3 zichtbaar)
	package = Build.group(self, "Package", Vector3(2.6, 0, 9.9), 20.0)
	Build.box(package, Vector3(0.45, 0.3, 0.35), Vector3.ZERO, Build.mat("wood_light", Color(0.9, 0.7, 0.45)), false)
	Build.box(package, Vector3(0.46, 0.02, 0.08), Vector3(0, 0.3, 0), Build.mat("plastic_white", Color(0.8, 0.75, 0.6)), false)
	Build.box(package, Vector3(0.12, 0.005, 0.08), Vector3(0.1, 0.301, 0.1), Build.mat("plastic_white"), false)
	package.visible = false
	_spot("package", Vector3(2.6, 0.2, 9.9), Vector3(0.6, 0.5, 0.5))

	_room_light("living", Vector3(3.5, 0, 8.0), 6.5, Vector3(2.1, 1.2, 5.58), 0.0)


func _build_kitchen() -> void:
	Props.counter(self, Vector3(9.95, 0, 9.825), 180.0, 3.9)
	Props.stove(self, Vector3(11.2, 0, 9.825), 180.0)
	Props.sink(self, Vector3(10.2, 0, 9.825), 180.0)
	var fridge := Props.fridge(self, Vector3(7.51, 0, 9.8), 180.0)
	# open koelkastdeur + licht (nacht 5)
	_fridge_open = Build.group(self, "FridgeOpen", Vector3(7.2, 0, 9.78))
	Build.box(_fridge_open, Vector3(0.05, 1.75, 0.6), Vector3(0, 0.03, -0.3), Build.mat("plastic_white"), false)
	var cold := OmniLight3D.new()
	cold.position = Vector3(0.3, 1.1, -0.35)
	cold.omni_range = 3.5
	cold.light_energy = 1.3
	cold.light_color = Color(0.85, 0.95, 1.0)
	_fridge_open.add_child(cold)
	_fridge_open.visible = false
	Sfx.loop_at("fridge_hum", fridge, -8.0).position = Vector3(0, 0.3, -0.3)
	closets.append(Props.closet(self, "Closet_Pantry", Vector3(11.325, 0, 6.4), -90.0, 0.8, 2.0, 0.6, Build.mat("wood_white"), false))
	Props.table(self, Vector3(9.3, 0, 7.9), 1.0, 0.7)
	Props.chair(self, Vector3(9.3, 0, 7.3), 0.0)
	Props.chair(self, Vector3(9.3, 0, 8.5), 180.0)

	# brood en broodtrommel op het aanrecht
	Build.box(self, Vector3(0.35, 0.02, 0.22), Vector3(8.6, 0.9, 10.1), Build.mat("wood_light"), false)
	Build.box(self, Vector3(0.24, 0.1, 0.12), Vector3(8.6, 0.92, 10.1), Build.mat("fabric_sheet", Color(0.85, 0.6, 0.3)), false)
	_spot("bread", Vector3(8.6, 1.0, 10.1), Vector3(0.4, 0.25, 0.35))
	lunchbox = Build.box(self, Vector3(0.2, 0.08, 0.14), Vector3(9.2, 0.9, 10.1), Build.mat("plastic_white", Color(0.3, 0.5, 0.9)), false)
	_spot("lunch", Vector3(9.2, 1.0, 10.1), Vector3(0.3, 0.25, 0.3))

	# klok aan de muur (tikt)
	var clock := Build.cylinder(self, 0.16, 0.03, Vector3(8.5, 1.9, 5.59), Build.mat("plastic_white"), 12)
	clock.rotation_degrees.x = 90.0
	Build.box(self, Vector3(0.01, 0.1, 0.01), Vector3(8.5, 1.95, 5.62), Build.mat("plastic_black"), false)
	Sfx.loop_at("clock_tick", clock, -10.0)

	_room_light("kitchen", Vector3(9.5, 0, 8.0), 6.0, Vector3(10.0, 1.2, 5.58), 0.0)
