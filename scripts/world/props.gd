class_name Props
## Alle meubels, gemaakt van simpele blokken.
## Elke functie maakt een "groep" op positie `pos` met draaiing `yaw` (in graden).
## Binnen de groep is -Z "achter" (tegen de muur) en +Z "voor" (naar de kamer).


static func bed(parent: Node3D, name: String, pos: Vector3, yaw: float, width: float, length: float, blanket_tex := "blanket") -> Node3D:
	# Het hoofdeinde staat op z=0, het bed loopt naar +z.
	var g := Build.group(parent, name, pos, yaw)
	var wood := Build.mat("wood_dark")
	Build.box(g, Vector3(width, 0.3, length), Vector3(0, 0, length * 0.5), wood)
	Build.box(g, Vector3(width, 0.75, 0.06), Vector3(0, 0, 0.03), wood)
	Build.box(g, Vector3(width - 0.06, 0.14, length - 0.1), Vector3(0, 0.3, length * 0.5 + 0.02), Build.mat("fabric_sheet"), false)
	var pillows := 2 if width > 1.3 else 1
	for i in pillows:
		var px := (i - (pillows - 1) * 0.5) * (width / pillows)
		Build.box(g, Vector3(width / pillows - 0.12, 0.1, 0.35), Vector3(px, 0.44, 0.28), Build.mat("fabric_pillow"), false)
	Build.box(g, Vector3(width + 0.04, 0.12, length * 0.62), Vector3(0, 0.39, length * 0.64), Build.mat(blanket_tex, Color.WHITE, 2.0), false)
	# stukje deken dat over de rand hangt
	Build.box(g, Vector3(0.03, 0.25, length * 0.62), Vector3(width * 0.5 + 0.03, 0.26, length * 0.64), Build.mat(blanket_tex, Color.WHITE, 2.0), false)
	return g


static func nightstand(parent: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var g := Build.group(parent, "Nightstand", pos, yaw)
	Build.box(g, Vector3(0.4, 0.5, 0.38), Vector3(0, 0, -0.19), Build.mat("wood_light"))
	Build.box(g, Vector3(0.34, 0.01, 0.01), Vector3(0, 0.3, 0.005), Build.mat("wood_dark"), false)
	Build.box(g, Vector3(0.08, 0.02, 0.02), Vector3(0, 0.36, 0.01), Build.mat("metal"), false)
	return g


## Een kast met een deur die open kan. Geeft de Door terug.
static func closet(parent: Node3D, name: String, pos: Vector3, yaw: float, w: float, h: float, d: float, material: Material, clothes := true) -> Door:
	# `pos` = midden van de voorkant, op de vloer. De kast loopt naar achter (-z).
	var g := Build.group(parent, name, pos, yaw)
	var t := 0.03
	Build.box(g, Vector3(w, h, t), Vector3(0, 0, -d + t * 0.5), material)
	Build.box(g, Vector3(t, h, d), Vector3(-w * 0.5 + t * 0.5, 0, -d * 0.5), material)
	Build.box(g, Vector3(t, h, d), Vector3(w * 0.5 - t * 0.5, 0, -d * 0.5), material)
	Build.box(g, Vector3(w, t, d), Vector3(0, h - t, -d * 0.5), material)
	Build.box(g, Vector3(w, t, d), Vector3(0, 0, -d * 0.5), material)
	# binnenkant donker maken
	Build.box(g, Vector3(w - 2 * t, h - 2 * t, 0.005), Vector3(0, t, -d + t + 0.003), Build.mat("wood_dark", Color(0.35, 0.35, 0.35)), false)
	if clothes and h > 1.5:
		Build.box(g, Vector3(w - 0.08, 0.02, 0.02), Vector3(0, h - 0.25, -d * 0.5), Build.mat("metal"), false)
		var colors := [Color(0.5, 0.2, 0.2), Color(0.2, 0.25, 0.4), Color(0.6, 0.6, 0.55), Color(0.15, 0.15, 0.15), Color(0.3, 0.4, 0.3)]
		var n := int((w - 0.2) / 0.14)
		for i in n:
			var cx := -w * 0.5 + 0.15 + i * 0.14 + randf_range(-0.02, 0.02)
			var ch := randf_range(0.6, 1.0)
			Build.box(g, Vector3(0.04, ch, d * 0.7), Vector3(cx, h - 0.27 - ch, -d * 0.5), Build.mat("fabric_sheet", colors[i % colors.size()]), false)
	elif h > 0.9:
		# planken
		for sy in [h * 0.33, h * 0.66]:
			Build.box(g, Vector3(w - 2 * t, 0.02, d - t), Vector3(0, sy, -d * 0.5), material, false)
	var door := Door.new()
	door.name = "Door"
	door.width = w
	door.height = h - 0.02
	door.thickness = 0.03
	door.is_closet = true
	door.material = material
	door.open_sign = -1.0
	door.max_angle = 110.0
	door.position = Vector3(-w * 0.5, 0.01, 0.02)
	g.add_child(door)
	door.build()
	return door


static func desk(parent: Node3D, pos: Vector3, yaw: float, w := 1.1, d := 0.55) -> Node3D:
	var g := Build.group(parent, "Desk", pos, yaw)
	var m := Build.mat("wood_white")
	Build.box(g, Vector3(w, 0.04, d), Vector3(0, 0.72, -d * 0.5), m)
	for sx in [-1, 1]:
		Build.box(g, Vector3(0.04, 0.72, d), Vector3(sx * (w * 0.5 - 0.02), 0, -d * 0.5), m)
	return g


static func chair(parent: Node3D, pos: Vector3, yaw: float, material: Material = null) -> Node3D:
	var g := Build.group(parent, "Chair", pos, yaw)
	var m := material if material else Build.mat("wood_light")
	Build.box(g, Vector3(0.42, 0.04, 0.42), Vector3(0, 0.44, 0), m)
	Build.box(g, Vector3(0.42, 0.45, 0.04), Vector3(0, 0.48, -0.19), m, false)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Build.box(g, Vector3(0.04, 0.44, 0.04), Vector3(sx * 0.18, 0, sz * 0.18), m, false)
	# één botsblok voor de hele stoel
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.42, 0.9, 0.42)
	shape.shape = bs
	shape.position.y = 0.45
	body.add_child(shape)
	g.add_child(body)
	return g


static func table(parent: Node3D, pos: Vector3, w: float, d: float, h := 0.75, material: Material = null) -> Node3D:
	var g := Build.group(parent, "Table", pos)
	var m := material if material else Build.mat("wood_light")
	Build.box(g, Vector3(w, 0.04, d), Vector3(0, h - 0.04, 0), m)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Build.box(g, Vector3(0.05, h - 0.04, 0.05), Vector3(sx * (w * 0.5 - 0.06), 0, sz * (d * 0.5 - 0.06)), m)
	return g


static func couch(parent: Node3D, pos: Vector3, yaw: float, w := 2.0) -> Node3D:
	var g := Build.group(parent, "Couch", pos, yaw)
	var f := Build.mat("fabric_couch")
	Build.box(g, Vector3(w, 0.42, 0.85), Vector3(0, 0, -0.42), f)
	Build.box(g, Vector3(w, 0.45, 0.2), Vector3(0, 0.42, -0.75), f)
	for sx in [-1, 1]:
		Build.box(g, Vector3(0.18, 0.22, 0.85), Vector3(sx * (w * 0.5 - 0.09), 0.42, -0.42), f, false)
	var cushions := int(w / 0.65)
	for i in cushions:
		var cx := -w * 0.5 + 0.2 + (i + 0.5) * ((w - 0.4) / cushions)
		Build.box(g, Vector3((w - 0.4) / cushions - 0.03, 0.08, 0.62), Vector3(cx, 0.42, -0.34), Build.mat("fabric_couch", Color(1.08, 1.08, 1.08)), false)
	return g


static func bookshelf(parent: Node3D, pos: Vector3, yaw: float, w := 0.9, h := 1.9) -> Node3D:
	var g := Build.group(parent, "Bookshelf", pos, yaw)
	var m := Build.mat("wood_dark")
	var d := 0.32
	Build.box(g, Vector3(w, h, 0.02), Vector3(0, 0, -d), m)
	for sx in [-1, 1]:
		Build.box(g, Vector3(0.03, h, d), Vector3(sx * (w * 0.5 - 0.015), 0, -d * 0.5), m)
	var shelves := 5
	var colors := [Color(0.6, 0.15, 0.1), Color(0.15, 0.3, 0.5), Color(0.8, 0.7, 0.4), Color(0.2, 0.4, 0.2), Color(0.4, 0.3, 0.5)]
	for s in shelves:
		var sy := s * (h / shelves)
		Build.box(g, Vector3(w, 0.03, d), Vector3(0, sy, -d * 0.5), m, false)
		var x := -w * 0.5 + 0.06
		while x < w * 0.5 - 0.1:
			var bw := randf_range(0.03, 0.07)
			var bh := randf_range(0.18, 0.3)
			Build.box(g, Vector3(bw, bh, 0.22), Vector3(x + bw * 0.5, sy + 0.03, -d * 0.55), Build.mat("fabric_sheet", colors[randi() % colors.size()]), false)
			x += bw + 0.005
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, h, d)
	shape.shape = bs
	shape.position = Vector3(0, h * 0.5, -d * 0.5)
	body.add_child(shape)
	g.add_child(body)
	return g


static func counter(parent: Node3D, pos: Vector3, yaw: float, w: float, d := 0.6) -> Node3D:
	var g := Build.group(parent, "Counter", pos, yaw)
	Build.box(g, Vector3(w, 0.86, d - 0.05), Vector3(0, 0, -d * 0.5 - 0.025), Build.mat("wood_white"))
	Build.box(g, Vector3(w, 0.04, d), Vector3(0, 0.86, -d * 0.5), Build.mat("counter"))
	# deurtjes (alleen lijntjes)
	var doors := int(w / 0.6)
	for i in doors:
		var dx := -w * 0.5 + (i + 0.5) * (w / doors)
		Build.box(g, Vector3(0.01, 0.7, 0.01), Vector3(dx - w / doors * 0.5, 0.08, 0.0), Build.mat("wood_dark"), false)
		Build.box(g, Vector3(0.1, 0.02, 0.02), Vector3(dx, 0.7, 0.01), Build.mat("metal"), false)
	return g


static func fridge(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var g := Build.group(parent, "Fridge", pos, yaw)
	Build.box(g, Vector3(0.62, 1.8, 0.62), Vector3(0, 0, -0.31), Build.mat("plastic_white"))
	Build.box(g, Vector3(0.6, 0.01, 0.01), Vector3(0, 1.2, 0.005), Build.mat("plastic_black"), false)
	Build.box(g, Vector3(0.03, 0.3, 0.04), Vector3(0.24, 1.3, 0.02), Build.mat("metal"), false)
	Build.box(g, Vector3(0.03, 0.4, 0.04), Vector3(0.24, 0.7, 0.02), Build.mat("metal"), false)
	# magneetjes en een briefje
	Build.box(g, Vector3(0.12, 0.16, 0.005), Vector3(-0.1, 1.35, 0.003), Build.mat("plastic_white", Color(1, 1, 0.7)), false)
	return g


static func stove(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var g := Build.group(parent, "Stove", pos, yaw)
	Build.box(g, Vector3(0.58, 0.02, 0.5), Vector3(0, 0.9, -0.3), Build.mat("plastic_black"), false)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Build.cylinder(g, 0.08, 0.01, Vector3(sx * 0.14, 0.92, -0.3 + sz * 0.12), Build.mat("metal", Color(0.4, 0.4, 0.4)))
	return g


static func sink(parent: Node3D, pos: Vector3, yaw: float, w := 0.5) -> Node3D:
	var g := Build.group(parent, "Sink", pos, yaw)
	Build.box(g, Vector3(w, 0.02, 0.36), Vector3(0, 0.89, -0.3), Build.mat("metal", Color(0.7, 0.7, 0.72)), false)
	Build.box(g, Vector3(0.04, 0.25, 0.04), Vector3(0, 0.9, -0.52), Build.mat("metal"), false)
	Build.box(g, Vector3(0.04, 0.03, 0.18), Vector3(0, 1.12, -0.45), Build.mat("metal"), false)
	return g


static func toilet(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var g := Build.group(parent, "Toilet", pos, yaw)
	var c := Build.mat("ceramic")
	Build.box(g, Vector3(0.36, 0.4, 0.5), Vector3(0, 0, -0.35), c)
	Build.box(g, Vector3(0.4, 0.04, 0.46), Vector3(0, 0.4, -0.33), Build.mat("plastic_white"), false)
	Build.box(g, Vector3(0.44, 0.4, 0.18), Vector3(0, 0.4, -0.6), c)
	return g


static func bathtub(parent: Node3D, pos: Vector3, yaw: float, w := 1.6) -> Node3D:
	var g := Build.group(parent, "Bathtub", pos, yaw)
	var c := Build.mat("ceramic")
	var d := 0.72
	Build.box(g, Vector3(w, 0.12, d), Vector3(0, 0, -d * 0.5), c)
	Build.box(g, Vector3(w, 0.45, 0.07), Vector3(0, 0.12, -0.035), c)
	Build.box(g, Vector3(w, 0.45, 0.07), Vector3(0, 0.12, -d + 0.035), c)
	for sx in [-1, 1]:
		Build.box(g, Vector3(0.07, 0.45, d), Vector3(sx * (w * 0.5 - 0.035), 0.12, -d * 0.5), c)
	# douchegordijn
	Build.box(g, Vector3(w, 0.02, 0.02), Vector3(0, 2.0, -0.05), Build.mat("metal"), false)
	Build.box(g, Vector3(w * 0.45, 1.4, 0.02), Vector3(w * 0.27, 0.6, -0.05), Build.mat("fabric_sheet", Color(0.75, 0.85, 0.85)), false)
	return g


static func bath_sink(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var g := Build.group(parent, "BathSink", pos, yaw)
	var c := Build.mat("ceramic")
	Build.box(g, Vector3(0.55, 0.15, 0.42), Vector3(0, 0.72, -0.21), c)
	Build.box(g, Vector3(0.12, 0.72, 0.12), Vector3(0, 0, -0.15), c)
	Build.box(g, Vector3(0.03, 0.12, 0.03), Vector3(0, 0.87, -0.37), Build.mat("metal"), false)
	# spiegel
	Build.box(g, Vector3(0.6, 0.7, 0.02), Vector3(0, 1.1, -0.43), Build.mat("metal", Color(0.35, 0.42, 0.48)), false)
	return g


static func dresser(parent: Node3D, pos: Vector3, yaw: float, w := 1.0) -> Node3D:
	var g := Build.group(parent, "Dresser", pos, yaw)
	Build.box(g, Vector3(w, 0.85, 0.45), Vector3(0, 0, -0.225), Build.mat("wood_dark"))
	for i in 3:
		Build.box(g, Vector3(w - 0.08, 0.01, 0.01), Vector3(0, 0.27 * (i + 1), 0.0), Build.mat("wood_light"), false)
		Build.box(g, Vector3(0.12, 0.02, 0.02), Vector3(0, 0.27 * i + 0.14, 0.01), Build.mat("metal"), false)
	return g


static func rug(parent: Node3D, pos: Vector3, size: Vector2, tex := "rug") -> void:
	var m: ShaderMaterial = Build.mat(tex, Color.WHITE, 1.0 / maxf(size.x, size.y)).duplicate()
	m.set_shader_parameter("uv_offset", Vector2(0.5, 0.5))
	Build.box(parent, Vector3(size.x, 0.01, size.y), pos, m, false)


static func poster(parent: Node3D, pos: Vector3, yaw: float, size := Vector2(0.5, 0.7)) -> void:
	var g := Build.group(parent, "Poster", pos, yaw)
	var m: ShaderMaterial = Build.mat("poster", Color.WHITE, 1.0 / size.y).duplicate()
	m.set_shader_parameter("uv_offset", Vector2(0.5, 0.5))
	Build.box(g, Vector3(size.x, size.y, 0.005), Vector3.ZERO, m, false)


## Plafondlamp. Geeft het (eigen) materiaal terug zodat de lichtknop hem kan laten gloeien.
static func ceiling_lamp(parent: Node3D, pos: Vector3) -> ShaderMaterial:
	var m := Build.glow_mat(Color(1, 0.95, 0.8), 1.4)
	Build.cylinder(parent, 0.2, 0.08, pos, m)
	Build.cylinder(parent, 0.01, 0.2, pos + Vector3(0, 0.08, 0), Build.mat("plastic_black"), 4)
	return m
