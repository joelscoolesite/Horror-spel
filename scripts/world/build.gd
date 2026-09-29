class_name Build
## Hulpfuncties om de wereld uit simpele blokken op te bouwen.
## Alle "modellen" in de game zijn gemaakt met deze functies.

const PS1_SHADER := preload("res://shaders/ps1.gdshader")

## Physics-lagen: 1 = alles waar je tegenaan loopt, 2 = dingen waar je E op kan drukken.
const LAYER_WORLD := 1
const LAYER_INTERACT := 2

static var _materials := {}


## Maakt (of hergebruikt) een PS1-materiaal met een texture uit assets/textures/.
static func mat(texture: String, tint := Color.WHITE, uv_scale := 1.0, world_uv := false) -> ShaderMaterial:
	var key := "%s|%s|%s|%s" % [texture, tint.to_html(), uv_scale, world_uv]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = PS1_SHADER
	m.set_shader_parameter("albedo_tex", load("res://assets/textures/%s.png" % texture))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("world_uv", world_uv)
	_materials[key] = m
	return m


## Een lichtgevend materiaal (voor lampen, klokjes, schermen...). Niet gedeeld.
static func glow_mat(color: Color, energy := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1_SHADER
	m.set_shader_parameter("albedo_tex", load("res://assets/textures/plastic_white.png"))
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("emission_color", color)
	m.set_shader_parameter("emission_energy", energy)
	return m


## Een blok. `pos` is het midden van de onderkant (handig om dingen op de vloer te zetten).
static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, collide := true, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	# Grote vlakken opdelen, anders vervormt de PS1-texture te erg.
	mesh.subdivide_width = int(size.x / 1.0)
	mesh.subdivide_height = int(size.y / 1.0)
	mesh.subdivide_depth = int(size.z / 1.0)
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos + Vector3(0, size.y * 0.5, 0)
	if name != "":
		mi.name = name
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_WORLD
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		body.add_child(shape)
		mi.add_child(body)
	return mi


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, sides := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos + Vector3(0, height * 0.5, 0)
	parent.add_child(mi)
	return mi


## Een lege node op een plek, met draaiing in graden. Handig als "groep" voor een meubel.
static func group(parent: Node3D, name: String, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	parent.add_child(n)
	return n


## Plat vlak (voor ramen, schermen, posters). Staat rechtop, kijkt naar +Z.
static func quad(parent: Node3D, size: Vector2, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func label(parent: Node3D, text: String, pos: Vector3, color: Color, font_size := 32) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.modulate = color
	l.font_size = font_size
	l.pixel_size = 0.002
	l.shaded = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.outline_size = 0
	parent.add_child(l)
	return l
