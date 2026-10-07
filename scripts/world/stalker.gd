class_name Stalker
extends Node3D
## Het wezen in nacht 6.
##  - Het loopt door het huis (via de deuren) naar je toe...
##  - ...maar ALLEEN als je niet kijkt. Kijk je ernaar, dan staat het stil.
##  - Schijn je er 2,5 seconde met je telefoonlicht op, dan verdwijnt het (even).
##  - Komt het te dichtbij: `caught`.
## Het loopt door dichte deuren heen. Het is geen mens.

signal caught
signal banished

## Punten in het huis waar het langs kan lopen (x, z) en welke met elkaar verbonden zijn.
const NODES := {
	"bed": Vector2(2.2, 2.2), "bed_door": Vector2(3.75, 3.5),
	"hall_w": Vector2(1.8, 4.75), "hall_bed": Vector2(3.75, 4.75), "hall_bath": Vector2(5.75, 4.75),
	"hall_par": Vector2(7.85, 4.75), "hall_kit": Vector2(10.8, 4.75),
	"bath_door": Vector2(5.75, 3.5), "bath": Vector2(5.75, 2.4),
	"par_door": Vector2(7.85, 3.5), "par": Vector2(9.6, 2.2),
	"liv_door": Vector2(3.15, 6.2), "liv": Vector2(3.5, 8.3), "liv_kit": Vector2(7.0, 7.95),
	"kit": Vector2(9.6, 8.6), "kit_door": Vector2(10.8, 6.2),
}
const EDGES := [
	["bed", "bed_door"], ["bed_door", "hall_bed"], ["hall_w", "hall_bed"], ["hall_bed", "hall_bath"],
	["hall_bath", "hall_par"], ["hall_par", "hall_kit"], ["hall_bath", "bath_door"], ["bath_door", "bath"],
	["hall_par", "par_door"], ["par_door", "par"], ["hall_bed", "liv_door"], ["liv_door", "liv"],
	["liv", "liv_kit"], ["liv_kit", "kit"], ["kit", "kit_door"], ["kit_door", "hall_kit"],
]

var active := false
var speed := 0.9
var frozen := false ## door de regie stilgezet (bijv. tijdens het krabben)
var body: Creature

var _path: Array = [] ## punten (Vector2) om naar toe te lopen
var _repath := 0.0
var _stare := 0.0
var _step := 0.0
var _neighbors := {}
var _goal_node := "" ## als dit gezet is, loopt het hierheen i.p.v. naar de speler


func _ready() -> void:
	body = Creature.new()
	body.name = "Body"
	body.menace = 0.8
	add_child(body)
	visible = false
	for n in NODES:
		_neighbors[n] = []
	for e in EDGES:
		_neighbors[e[0]].append(e[1])
		_neighbors[e[1]].append(e[0])


func spawn(node_name: String) -> void:
	var p: Vector2 = NODES[node_name]
	global_position = Vector3(p.x, 0, p.y)
	visible = true
	active = true
	frozen = false
	_path.clear()
	_goal_node = ""
	_stare = 0.0


func despawn() -> void:
	visible = false
	active = false


## Loop naar een bepaald punt (i.p.v. naar de speler). Wacht tot het er is.
func walk_to_node(node_name: String) -> void:
	_goal_node = node_name
	_path = _find_path(_nearest_node(global_position), node_name)
	while active and not _path.is_empty():
		await get_tree().process_frame
	_goal_node = ""


## Ziet de speler het wezen? (in beeld, en geen muur ertussen)
func is_seen() -> bool:
	var player: Player = Game.player
	if not visible or player == null or player.state != Player.State.WALK:
		return false
	var chest := global_position + Vector3(0, 1.3, 0)
	if not player.is_looking_at(chest, 32.0):
		return false
	var cam := player.get_camera()
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, chest, Build.LAYER_WORLD)
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty()


func _process(delta: float) -> void:
	if not active:
		return
	var player: Player = Game.player
	var seen := is_seen()
	body.still = seen # als je kijkt: doodstil
	if seen:
		body.walk_speed = 0.0
		_stare += delta if player.flashlight_on else delta * 0.3
		if _stare > 2.5:
			_banish()
		return
	_stare = maxf(0.0, _stare - delta * 0.5)
	if frozen:
		body.walk_speed = 0.0
		return
	# pad naar de speler (of naar een opgegeven punt)
	_repath -= delta
	if _goal_node != "":
		pass
	elif _repath <= 0.0 and player.state == Player.State.WALK:
		_repath = 0.6
		var target_node := _nearest_node(player.global_position, Game.apartment.room_at(player.global_position))
		_path = _find_path(_nearest_node(global_position), target_node)
		_path.append(Vector2(player.global_position.x, player.global_position.z))
	_move(delta)
	# te dichtbij?
	# (ook als je hand op een kast ligt: dan ben je juist kwetsbaar)
	if player.state == Player.State.WALK and not Game.debug_open:
		var d := Vector2(global_position.x - player.global_position.x, global_position.z - player.global_position.z).length()
		if d < 0.9 and not Game.godmode:
			active = false
			caught.emit()


func _move(delta: float) -> void:
	if _path.is_empty():
		body.walk_speed = 0.0
		return
	body.walk_speed = speed
	var target: Vector2 = _path[0]
	var pos := Vector2(global_position.x, global_position.z)
	var to := target - pos
	if to.length() < 0.15:
		_path.pop_front()
		return
	var step := minf(speed * delta, to.length())
	pos += to.normalized() * step
	global_position = Vector3(pos.x, 0, pos.y)
	global_rotation.y = atan2(to.x, to.y)
	# eigen voetstappen, in een eigen tempo
	_step += step
	if _step > 0.55:
		_step = 0.0
		var surface := "wood"
		var room: String = Game.apartment.room_at(global_position)
		if room == "bedroom":
			surface = "carpet"
		elif room in ["bathroom", "kitchen"]:
			surface = "tile"
		Sfx.play_at("step_%s_%d" % [surface, randi_range(1, 3)], global_position, -3.0, 0.75)


func _banish() -> void:
	_stare = 0.0
	Game.post.jolt(0.6)
	Sfx.play_at("breath", global_position + Vector3(0, 1.6, 0), 0.0, 0.7)
	# weg... en ergens anders weer op, ver van de speler
	var far := ""
	var best := -1.0
	for n in NODES:
		var p: Vector2 = NODES[n]
		var d := p.distance_to(Vector2(Game.player.global_position.x, Game.player.global_position.z))
		if d > best:
			best = d
			far = n
	visible = false
	active = false
	banished.emit()
	await get_tree().create_timer(6.0).timeout
	if is_inside_tree() and Game.phase == Game.Phase.NIGHT:
		spawn(far)


func _nearest_node(pos: Vector3, room := "") -> String:
	var best := ""
	var best_d := INF
	for n in NODES:
		var p: Vector2 = NODES[n]
		if room != "" and Game.apartment.room_at(Vector3(p.x, 0, p.y)) != room:
			continue
		var d := p.distance_to(Vector2(pos.x, pos.z))
		if d < best_d:
			best_d = d
			best = n
	if best == "":
		return _nearest_node(pos)
	return best


## Kortste route over de punten (breadth-first search).
func _find_path(from: String, to: String) -> Array:
	var prev := {from: ""}
	var queue := [from]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == to:
			break
		for nb in _neighbors[cur]:
			if not prev.has(nb):
				prev[nb] = cur
				queue.append(nb)
	var out := []
	var node := to
	while node != "" and prev.has(node):
		out.push_front(NODES[node])
		node = prev[node]
	# Zijn we al verder dan het eerste punt? Sla het over (anders loopt het terug).
	var pos := Vector2(global_position.x, global_position.z)
	if out.size() > 1 and pos.distance_to(out[1]) < (out[0] as Vector2).distance_to(out[1]):
		out.pop_front()
	return out
