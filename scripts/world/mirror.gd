class_name Mirror
extends Node3D
## Een echte spiegel. Werkt zo:
##  - Een tweede camera staat "achter" de spiegel (gespiegeld t.o.v. de speler)
##    en filmt de kamer. Dat beeld komt op de spiegel.
##  - De speler heeft normaal geen lichaam. Voor de spiegel is er een lichaam
##    (het kind in pyjama) dat alleen de spiegel-camera kan zien.
##  - Met `delay` loopt dat lichaam achter op de speler... (nacht 3)
## De spiegel kijkt naar +z (lokaal).

const REFLECTION_LAYER := 2 ## render-laag die alleen de spiegel ziet

var size := Vector2(0.56, 0.66)
var delay := 0.0 ## seconden dat je spiegelbeeld achterloopt
var frozen := false ## spiegelbeeld beweegt helemaal niet meer

var _viewport: SubViewport
var _camera: Camera3D
var _body: Node3D
var _history: Array = [] ## [[tijd, positie, yaw], ...]
var _time := 0.0


func build(body_parent: Node3D) -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(84, 99)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_FRUSTUM
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = size.y
	_camera.far = 15.0
	_viewport.add_child(_camera)

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/mirror.gdshader")
	mat.set_shader_parameter("reflection", _viewport.get_texture())
	Build.quad(self, size, Vector3.ZERO, mat)

	# het lichaam van het kind (alleen zichtbaar in de spiegel)
	_body = Props.person(body_parent, "Reflection", Vector3.ZERO, 0.0, Color(0.32, 0.38, 0.6), false, false, Color(0.25, 0.16, 0.1))
	_set_layer(_body, 1 << (REFLECTION_LAYER - 1))
	# zwak lichtje dat ALLEEN het spiegelbeeld verlicht (zoals je zaklamp die terugkaatst)
	var glow := OmniLight3D.new()
	glow.light_cull_mask = 1 << (REFLECTION_LAYER - 1)
	glow.position = Vector3(0, 1.4, 0.7)
	glow.omni_range = 2.5
	glow.light_energy = 0.7
	glow.light_color = Color(0.85, 0.9, 1.0)
	_body.add_child(glow)


func _set_layer(node: Node, layer_bits: int) -> void:
	if node is VisualInstance3D:
		node.layers = layer_bits
	for c in node.get_children():
		_set_layer(c, layer_bits)


func _process(delta: float) -> void:
	var player: Player = Game.player
	if player == null or _camera == null:
		return
	_time += delta
	var cam := player.get_camera()
	var n := global_basis.z.normalized()
	var c := global_position
	var d := (cam.global_position - c).dot(n)
	var near := d > 0.05 and cam.global_position.distance_to(c) < 5.0
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if near else SubViewport.UPDATE_DISABLED
	_update_body(player)
	if not near:
		return
	# camera gespiegeld achter de spiegel, recht naar de spiegel kijkend
	var right := global_basis.x.normalized()
	var up := global_basis.y.normalized()
	var p_ref := cam.global_position - 2.0 * d * n
	_camera.global_transform = Transform3D(Basis(-right, up, -n), p_ref)
	_camera.near = maxf(d - 0.01, 0.02)
	var rel := c - p_ref
	_camera.frustum_offset = Vector2(rel.dot(-right), rel.dot(up))


func _update_body(player: Player) -> void:
	_body.visible = player.state == Player.State.WALK
	_history.append([_time, player.global_position, player.rotation.y])
	while _history.size() > 2 and _history[1][0] < _time - delay - 0.1:
		_history.pop_front()
	if frozen:
		return
	var sample: Array = _history[_history.size() - 1]
	if delay > 0.0:
		for h in _history:
			if h[0] >= _time - delay:
				sample = h
				break
	_body.global_position = sample[1]
	_body.global_rotation.y = sample[2] + PI # het poppetje kijkt naar +z, de speler naar -z
