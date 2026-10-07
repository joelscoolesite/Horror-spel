class_name School
extends Node3D
## Het klaslokaal. Staat ver weg van het appartement (x = 100), je ziet het
## alleen tijdens de school-cutscene.
##
## Bovenaanzicht (x naar rechts, z naar achter):
##   z=0   [======= BORD =======]        (figuur)
##          (leraar)  [bureau]
##   z=2.4  [ ] [ ] [ ] [ ]
##   z=3.6  [ ] [ ] [ ] [ ]
##   z=4.8  [ ] [ ] [x] [ ]      x = klasgenoot die gaat staren
##   z=6.0  [ ] [JIJ] [ ] [ ]  [deur]

const ORIGIN := Vector3(100, 0, 0)
const W := 8.0
const D := 7.0
const H := 3.0
const COLUMNS := [1.6, 3.2, 4.8, 6.4]
const ROWS := [2.4, 3.6, 4.8, 6.0]
const PLAYER_SEAT := Vector2i(1, 3) ## kolom, rij
const STARER_SEAT := Vector2i(2, 2)
const EMPTY_SEATS := [Vector2i(2, 3), Vector2i(3, 1)] ## naast jou is leeg...

var seat_marker: Marker3D
var teacher: Node3D
var figure: Node3D ## de gestalte "in je ooghoek"
var starer: Node3D
var board_label: Label3D
var kids: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []


func _ready() -> void:
	Game.school = self
	position = ORIGIN
	seed(7)
	_build_room()
	_build_class()
	randomize()


func _build_room() -> void:
	var wall := Build.mat("wall_plain", Color(0.82, 0.9, 0.82), 1.0, true)
	Build.box(self, Vector3(W, 1.0, D), Vector3(W * 0.5, -1.0, D * 0.5), Build.mat("counter", Color(0.75, 0.7, 0.6), 1.0, true))
	Build.box(self, Vector3(W, 0.1, D), Vector3(W * 0.5, H, D * 0.5), Build.mat("ceiling", Color.WHITE, 1.0, true), false)
	var t := 0.15
	# voor/achter
	Build.box(self, Vector3(W, H, t), Vector3(W * 0.5, 0, -t * 0.5), wall)
	Build.box(self, Vector3(W, H, t), Vector3(W * 0.5, 0, D + t * 0.5), wall)
	# links, met drie ramen
	var z := 0.0
	for wz in [1.2, 3.2, 5.2]:
		Build.box(self, Vector3(t, H, wz - z), Vector3(-t * 0.5, 0, (z + wz) * 0.5), wall)
		Build.box(self, Vector3(t, 0.9, 1.4), Vector3(-t * 0.5, 0, wz + 0.7), wall)
		Build.box(self, Vector3(t, H - 2.3, 1.4), Vector3(-t * 0.5, 2.3, wz + 0.7), wall)
		_window(Vector3(0, 1.6, wz + 0.7))
		z = wz + 1.4
	Build.box(self, Vector3(t, H, D - z), Vector3(-t * 0.5, 0, (z + D) * 0.5), wall)
	# rechts, met een open deur naar een donkere gang
	Build.box(self, Vector3(t, H, 5.3), Vector3(W + t * 0.5, 0, 2.65), wall)
	Build.box(self, Vector3(t, H - 2.1, 1.0), Vector3(W + t * 0.5, 2.1, 5.8), wall)
	Build.box(self, Vector3(t, H, D - 6.3), Vector3(W + t * 0.5, 0, (6.3 + D) * 0.5), wall)
	Build.box(self, Vector3(3.0, 3.0, 3.0), Vector3(W + 1.7, -0.01, 5.8), Build.mat("plastic_black", Color(0.1, 0.1, 0.1)), false)

	# schoolbord
	Build.box(self, Vector3(4.2, 1.3, 0.04), Vector3(4.0, 0.95, 0.02), Build.mat("fabric_couch", Color(0.35, 0.55, 0.4)), false)
	Build.box(self, Vector3(4.2, 0.05, 0.1), Vector3(4.0, 0.9, 0.05), Build.mat("wood_light"), false)
	board_label = Build.label(self, "", Vector3(4.0, 1.75, 0.05), Color(0.95, 0.95, 0.9), 64)
	board_label.pixel_size = 0.004
	# klok
	var clock := Build.cylinder(self, 0.2, 0.04, Vector3(6.8, 2.4, 0.0), Build.mat("plastic_white"), 12)
	clock.rotation_degrees.x = 90.0
	Sfx.loop_at("clock_tick", clock, -12.0)
	# plafondlampen
	for lx in [2.7, 5.3]:
		Build.box(self, Vector3(1.2, 0.05, 0.3), Vector3(lx, H - 0.05, 3.5), Build.glow_mat(Color(1, 1, 0.95), 1.2), false)
		var light := OmniLight3D.new()
		light.position = Vector3(lx, H - 0.4, 3.5)
		light.omni_range = 6.5
		light.light_energy = 0.9
		light.light_color = Color(1.0, 0.98, 0.92)
		add_child(light)
		_lights.append(light)
	# posters
	for px in [2.0, 6.0]:
		Props.poster(self, Vector3(px, 1.4, D - 0.005), 180.0, Vector2(0.6, 0.8))


func _window(pos: Vector3) -> void:
	var g := Build.group(self, "Window", pos, 90.0)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/window.gdshader")
	m.set_shader_parameter("sky_top", Color(0.7, 0.8, 0.92))
	m.set_shader_parameter("sky_bottom", Color(0.92, 0.92, 0.88))
	Build.quad(g, Vector2(1.4, 1.4), Vector3.ZERO, m)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0, 1.0)
	light.omni_range = 4.0
	light.light_energy = 0.8
	light.light_color = Color(0.9, 0.93, 1.0)
	g.add_child(light)


func _build_class() -> void:
	# lessenaar + leraar
	Props.table(self, Vector3(1.6, 0, 1.2), 1.3, 0.65, 0.75, Build.mat("wood_dark"))
	Build.box(self, Vector3(0.3, 0.05, 0.22), Vector3(1.4, 0.75, 1.2), Build.mat("fabric_sheet", Color(0.9, 0.9, 0.85)), false)
	teacher = Props.person(self, "Teacher", Vector3(4.6, 0, 0.8), 0.0, Color(0.55, 0.3, 0.25), false, true, Color(0.3, 0.25, 0.2))

	var shirts := [Color(0.7, 0.2, 0.2), Color(0.2, 0.4, 0.7), Color(0.9, 0.8, 0.3), Color(0.3, 0.6, 0.3), Color(0.8, 0.8, 0.8), Color(0.3, 0.3, 0.35), Color(0.6, 0.35, 0.6)]
	var hairs := [Color(0.1, 0.07, 0.05), Color(0.5, 0.35, 0.15), Color(0.85, 0.7, 0.4), Color(0.25, 0.15, 0.1)]
	for c in COLUMNS.size():
		for r in ROWS.size():
			var desk_pos := Vector3(COLUMNS[c], 0, ROWS[r])
			Props.table(self, desk_pos, 0.65, 0.45, 0.7, Build.mat("wood_light"))
			Props.chair(self, desk_pos + Vector3(0, 0, 0.45), 180.0, Build.mat("plastic_black", Color(2.2, 1.2, 0.6)))
			var seat := Vector2i(c, r)
			if seat == PLAYER_SEAT:
				# jouw schrift op tafel
				Build.box(self, Vector3(0.25, 0.01, 0.18), desk_pos + Vector3(0, 0.7, 0.02), Build.mat("fabric_sheet", Color(0.95, 0.95, 0.9)), false)
				seat_marker = Marker3D.new()
				seat_marker.position = desk_pos + Vector3(0, 1.05, 0.5)
				seat_marker.rotation.y = 0.0 # kijkt naar het bord (-z)
				add_child(seat_marker)
				continue
			if seat in EMPTY_SEATS:
				continue
			var kid := Props.person(self, "Kid_%d_%d" % [c, r], desk_pos + Vector3(0, 0, 0.5), 180.0, shirts[(c + r * 3) % shirts.size()], true, false, hairs[(c * 2 + r) % hairs.size()])
			kids.append(kid)
			if seat == STARER_SEAT:
				starer = kid

	# de gestalte: helemaal zwart, geen gezicht
	figure = Creature.new()
	figure.name = "Figure"
	figure.position = Vector3(0.45, 0, 2.0)
	figure.rotation_degrees.y = 31.0
	add_child(figure)
	figure.visible = false


## Laat iemand (bijv. de leraar) langs een paar punten lopen, met voetstappen.
func walk(person: Node3D, points: Array, speed := 1.1) -> void:
	for target in points:
		var from := person.position
		var to: Vector3 = target
		var dir := to - from
		dir.y = 0
		var dist := dir.length()
		if dist < 0.01:
			continue
		person.rotation.y = atan2(dir.x, dir.z)
		var done := 0.0
		var next_step := 0.0
		while done < dist:
			await get_tree().process_frame
			done = minf(done + speed * get_process_delta_time(), dist)
			person.position = from.lerp(to, done / dist)
			person.position.y = absf(sin(done * 5.5)) * 0.03
			if done >= next_step:
				next_step += 0.6
				Sfx.play_at("step_tile_%d" % randi_range(1, 3), person.global_position, -6.0, 0.85)
	person.position.y = 0.0


## Draai iemand (of zijn hoofd) naar een punt in de wereld.
func face(node: Node3D, world_point: Vector3) -> void:
	var p := node.global_position
	node.global_rotation.y = atan2(world_point.x - p.x, world_point.z - p.z)


## Droom: de klas is ineens leeg en donker.
func set_empty(empty: bool) -> void:
	for k in kids:
		k.visible = not empty
	teacher.visible = not empty
	for l in _lights:
		l.light_energy = 0.15 if empty else 0.9
	board_label.visible = not empty


## Ogen aan/uit bij iedereen in de klas (dag 4: niemand heeft ogen...)
func set_eyes(on: bool) -> void:
	for p in kids + [teacher]:
		for n in p.get_node("Head").get_children():
			if n.has_meta("eye"):
				n.visible = on


## Iedereen draait zijn hoofd naar dit punt (of terug naar voren).
func everyone_look_at(point: Variant) -> void:
	for k in kids:
		var head: Node3D = k.get_node("Head")
		if point == null:
			head.rotation.y = 0.0
		else:
			face(head, point)


## De gestalte naast een lege stoel zetten, kijkend naar `point`.
func figure_at_seat(seat: Vector2i, point: Vector3) -> void:
	figure.position = Vector3(COLUMNS[seat.x] + 0.45, 0, ROWS[seat.y] + 0.3)
	figure.visible = true
	face(figure, point)


func reset_figure() -> void:
	figure.position = Vector3(0.45, 0, 2.0)
	figure.rotation_degrees.y = 31.0
	figure.visible = false


func player_seat_world() -> Vector3:
	return seat_marker.global_position
