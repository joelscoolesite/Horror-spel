class_name Creature
extends Node3D
## Het monster. Lang, mager, voorovergebogen. Ribben die door de huid steken,
## armen tot onder de knieën, lange vingers. Een uitgerekt hoofd op een lange
## nek, gloeiende pupillen in diepe oogkassen en een veel te brede grijns.
##
## Het beweegt "fout": het hoofd knakt schokkerig naar rare hoeken, de vingers
## trekken, en het volgt jou met zijn blik.
## Kijkt naar +z. Oorsprong = tussen de voeten.

const SHADER := preload("res://shaders/creature.gdshader")
const HIPS_Y := 1.11
const TORSO_PITCH := 28.0
const HEAD_PITCH := -55.0
const THIGH_PITCH := -12.0
const KNEE_PITCH := 22.0
const ARM_PITCH := -36.0

enum Mode { IDLE, WALK, CRAWL, PEEK, LUNGE }

## Rustpose (graden). Alle andere poses zijn hiervan afgeleid.
const REST := {
	"torso": Vector3(28, 0, 0), "neck": Vector3(25, 0, 0), "head": Vector3(-55, 0, 0),
	"thigh_l": Vector3(-12, 0, -3), "thigh_r": Vector3(-12, 0, 3),
	"knee_l": Vector3(22, 0, 0), "knee_r": Vector3(22, 0, 0),
	"ankle_l": Vector3(-10, 0, 0), "ankle_r": Vector3(-10, 0, 0),
	"arm_l": Vector3(-36, 0, -6), "arm_r": Vector3(-36, 0, 6),
	"elbow_l": Vector3(-18, 0, 0), "elbow_r": Vector3(-18, 0, 0),
}
const STOP_MOTION_FPS := 12.0 ## schokkerig, net niet vloeiend = eng

var mode := Mode.IDLE
var peek_side := 1.0 ## naar welke kant het leunt bij gluren (1 of -1)
var owl_neck := false ## hoofd kan 180 graden omdraaien
var menace := 0.5 ## 0..1: hoe onrustig (vaker knakken, trekken)
var still := false ## true = staat doodstil (bijv. als je ernaar kijkt)
var walk_speed := 0.0 ## > 0 = loopt (wordt door Stalker gezet)
var track_player := true ## hoofd draait naar jou toe
var breathing := true ## ademgeluid aan/uit

var _skin: ShaderMaterial
var _bone: ShaderMaterial
var _hair: ShaderMaterial
var _teeth: ShaderMaterial
var _black: StandardMaterial3D
var _hips: Node3D
var _torso: Node3D
var _neck: Node3D
var _head: Node3D
var _jaw: Node3D
var _j := {} ## gewrichten: naam -> Node3D
var _legs: Array = [] ## [heup-pivot, knie-pivot]
var _arms: Array = [] ## [schouder-pivot, elleboog-pivot, [vingers]]
var _t := 0.0
var _phase := 0.0
var _jerk := 0.0
var _head_off := Vector3.ZERO
var _jaw_open := 0.08
var _jaw_target := 0.08
var _scream_time := 0.0
var _breath: AudioStreamPlayer3D
var _click_timer := 4.0
var _step_acc := 0.0


func _ready() -> void:
	_build()


# ================================================================== bouwen

func _mat(tint: Color, rim := 0.3, tex := "fabric_sheet", uv := 6.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo_tex", load("res://assets/textures/%s.png" % tex))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("rim_strength", rim)
	m.set_shader_parameter("uv_scale", uv)
	return m


func _pivot(parent: Node3D, pos: Vector3, rot_deg := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot_deg
	parent.add_child(n)
	return n


## Cilinder die vanaf de pivot naar beneden loopt (of omhoog met `up`).
func _limb(parent: Node3D, length: float, r_start: float, r_end: float, mat: Material, up := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.height = length
	m.top_radius = r_end if up else r_start
	m.bottom_radius = r_start if up else r_end
	m.radial_segments = 6
	m.rings = 2
	mi.mesh = m
	mi.material_override = mat
	mi.position.y = length * 0.5 if up else -length * 0.5
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D, radius: float, pos: Vector3, scl: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 8
	m.rings = 5
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _cube(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _build() -> void:
	# ziekelijk bleek: vangt het licht van je zaklamp
	_skin = _mat(Color(0.44, 0.42, 0.4), 0.25)
	_bone = _mat(Color(0.62, 0.58, 0.52), 0.15)
	_hair = _mat(Color(0.03, 0.03, 0.035), 0.12)
	_teeth = _mat(Color(0.8, 0.76, 0.62), 0.05, "ceramic", 20.0)
	_black = StandardMaterial3D.new()
	_black.albedo_color = Color.BLACK
	_black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var glow := Build.glow_mat(Color(0.95, 0.95, 0.82), 4.0)

	# --- heupen en benen
	_hips = _pivot(self, Vector3(0, HIPS_Y, 0))
	_cube(_hips, Vector3(0.26, 0.12, 0.14), Vector3.ZERO, _skin)
	for side in [-1.0, 1.0]:
		var thigh := _pivot(_hips, Vector3(side * 0.1, -0.03, 0), Vector3(THIGH_PITCH, 0, side * 3.0))
		_limb(thigh, 0.55, 0.075, 0.05, _skin)
		var knee := _pivot(thigh, Vector3(0, -0.55, 0), Vector3(KNEE_PITCH, 0, 0))
		_ball(knee, 0.05, Vector3.ZERO, Vector3.ONE, _bone)
		_limb(knee, 0.55, 0.05, 0.035, _skin)
		var ankle := _pivot(knee, Vector3(0, -0.55, 0), Vector3(-10, 0, 0))
		_cube(ankle, Vector3(0.07, 0.035, 0.24), Vector3(0, -0.01, 0.07), _skin)
		for i in 3:
			_cube(ankle, Vector3(0.012, 0.012, 0.09), Vector3(-0.022 + i * 0.022, -0.02, 0.22), _bone)
		_legs.append([thigh, knee])
		var tag := "_l" if side < 0 else "_r"
		_j["thigh" + tag] = thigh
		_j["knee" + tag] = knee
		_j["ankle" + tag] = ankle

	# --- romp, voorovergebogen, met ribben en een ruggengraat
	_torso = _pivot(_hips, Vector3(0, 0.05, 0), Vector3(TORSO_PITCH, 0, 0))
	_limb(_torso, 0.72, 0.11, 0.17, _skin, true)
	for i in 5:
		var y := 0.28 + i * 0.075
		var r := lerpf(0.11, 0.17, y / 0.72)
		_cube(_torso, Vector3(0.21 + i * 0.006, 0.018, 0.035), Vector3(0, y, r - 0.005), _bone)
	for i in 7:
		var y := 0.08 + i * 0.09
		_ball(_torso, 0.024, Vector3(0, y, -lerpf(0.11, 0.17, y / 0.72)), Vector3.ONE, _bone)

	# --- schouders en (veel te lange) armen
	var shoulders := _pivot(_torso, Vector3(0, 0.7, 0))
	_cube(shoulders, Vector3(0.46, 0.07, 0.11), Vector3.ZERO, _skin)
	for side in [-1.0, 1.0]:
		var sh := _pivot(shoulders, Vector3(side * 0.24, 0, 0), Vector3(ARM_PITCH, 0, side * 6.0))
		_ball(sh, 0.055, Vector3.ZERO, Vector3.ONE, _bone)
		_limb(sh, 0.6, 0.052, 0.04, _skin)
		var elbow := _pivot(sh, Vector3(0, -0.6, 0), Vector3(-18, 0, 0))
		_ball(elbow, 0.04, Vector3.ZERO, Vector3.ONE, _bone)
		_limb(elbow, 0.62, 0.04, 0.03, _skin)
		var hand := _pivot(elbow, Vector3(0, -0.62, 0))
		_cube(hand, Vector3(0.075, 0.1, 0.03), Vector3(0, -0.05, 0), _skin)
		var fingers := []
		for i in 4:
			var f := _pivot(hand, Vector3(-0.027 + i * 0.018, -0.1, 0), Vector3(randf_range(-15, 15), 0, 0))
			var length := 0.26 + (0.05 if i in [1, 2] else 0.0)
			_limb(f, length, 0.009, 0.006, _skin)
			_cube(f, Vector3(0.008, 0.045, 0.01), Vector3(0, -length - 0.015, 0.005), _bone, Vector3(25, 0, 0))
			fingers.append(f)
		_arms.append([sh, elbow, fingers])
		var tag := "_l" if side < 0 else "_r"
		_j["arm" + tag] = sh
		_j["elbow" + tag] = elbow

	# --- lange nek en een uitgerekt hoofd
	_neck = _pivot(_torso, Vector3(0, 0.72, 0.03), Vector3(25, 0, 0))
	_limb(_neck, 0.24, 0.045, 0.035, _skin, true)
	_head = _pivot(_neck, Vector3(0, 0.24, 0), Vector3(HEAD_PITCH, 0, 0))
	_ball(_head, 0.12, Vector3(0, 0.13, 0.01), Vector3(0.85, 1.35, 0.95), _skin)
	# diepe oogkassen met gloeiende pupillen
	for side in [-1.0, 1.0]:
		_ball(_head, 0.034, Vector3(side * 0.044, 0.17, 0.106), Vector3(1.0, 0.85, 0.6), _black)
		_ball(_head, 0.012, Vector3(side * 0.044, 0.168, 0.122), Vector3.ONE, glow)
	# een veel te brede grijns
	_cube(_head, Vector3(0.17, 0.03, 0.04), Vector3(0, 0.058, 0.1), _black)
	for i in 9:
		_cube(_head, Vector3(0.012, 0.017, 0.01), Vector3(-0.072 + i * 0.018, 0.066, 0.118), _teeth, Vector3(0, 0, randf_range(-12, 12)))
	# zwart keelgat (zie je als de kaak openklapt)
	_cube(_head, Vector3(0.15, 0.09, 0.06), Vector3(0, 0.02, 0.065), _black)
	# ingescheurde mondhoeken
	for side in [-1.0, 1.0]:
		_cube(_head, Vector3(0.05, 0.008, 0.012), Vector3(side * 0.088, 0.078, 0.092), _black, Vector3(0, side * -25.0, side * 32.0))
	_jaw = _pivot(_head, Vector3(0, 0.05, 0.02))
	_cube(_jaw, Vector3(0.15, 0.035, 0.09), Vector3(0, -0.028, 0.045), _skin)
	_cube(_jaw, Vector3(0.16, 0.02, 0.05), Vector3(0, -0.004, 0.07), _black)
	for i in 8:
		_cube(_jaw, Vector3(0.012, 0.016, 0.01), Vector3(-0.063 + i * 0.018, 0.0, 0.098), _teeth, Vector3(0, 0, randf_range(-12, 12)))
	# lang, sliertig haar (een paar slierten hangen voor het gezicht)
	for k in 14:
		var a := float(k) / 14.0 * TAU
		var front := sin(a) > 0.7
		var pos := Vector3(cos(a) * 0.08, 0.25, sin(a) * 0.075 - 0.015)
		if front:
			pos.x = 0.065 * signf(cos(a) + 0.01)
		var strand := _pivot(_head, pos, Vector3(randf_range(-4, 4) + (6.0 if front else -3.0), 0, randf_range(-4, 4)))
		var length := randf_range(0.32, 0.5) if not front else randf_range(0.22, 0.32)
		_cube(strand, Vector3(0.01, length, 0.008), Vector3(0, -length * 0.5, 0), _hair)

	# geluid: reutelende ademhaling
	_j["torso"] = _torso
	_j["neck"] = _neck
	_j["head"] = _head
	_breath = AudioStreamPlayer3D.new()
	_breath.stream = Sfx.stream("creature_breath")
	_breath.bus = "SFX"
	_breath.volume_db = -6.0
	_breath.unit_size = 1.5
	_breath.max_distance = 9.0
	_head.add_child(_breath)


# ================================================================== acties

## Mond wijd open, hoofd schudt. Met geluid.
func scream(play_sound := true) -> void:
	_jaw_target = 0.8
	_scream_time = 1.0
	if play_sound:
		Sfx.play("scream", 0.0)


## Draai het hele lichaam naar een punt.
func face(point: Vector3) -> void:
	var p := global_position
	global_rotation.y = atan2(point.x - p.x, point.z - p.z)


## Waar het hoofd is (voor jumpscares).
func head_position() -> Vector3:
	return _head.global_position + _head.global_basis.y * 0.13


## Meteen in de huidige pose springen (zonder stop-motion overgang).
func snap_pose() -> void:
	var pose := _pose(_t)
	for joint in REST:
		(_j[joint] as Node3D).rotation_degrees = pose[joint]
	_hips.position.y = pose.hips_y
	_head.rotation_degrees = pose.head


## Hang ondersteboven aan het plafond (op hoogte `ceiling_y`), kruipend.
func set_on_ceiling(on: bool, ceiling_y := 2.6) -> void:
	mode = Mode.CRAWL if on else Mode.IDLE
	rotation.z = PI if on else 0.0
	position.y = ceiling_y if on else 0.0


# ================================================================== poses

func _pose(t: float) -> Dictionary:
	var p := REST.duplicate()
	p["hips_y"] = HIPS_Y
	match mode:
		Mode.IDLE:
			p.torso = Vector3(28 + sin(t * 1.7) * 1.5, 0, 0)
			p.arm_l += Vector3(sin(t * 0.9) * 3.0, 0, 0)
			p.arm_r += Vector3(sin(t * 0.9 + 1.0) * 3.0, 0, 0)
		Mode.WALK:
			var s := sin(_phase)
			p.torso = Vector3(32, 0, sin(_phase * 0.5) * 4.0)
			p.thigh_l = Vector3(-12 + s * 28, 0, -3)
			p.thigh_r = Vector3(-12 - s * 28, 0, 3)
			p.knee_l = Vector3(22 + maxf(0.0, -s) * 40, 0, 0)
			p.knee_r = Vector3(22 + maxf(0.0, s) * 40, 0, 0)
			p.arm_l = Vector3(-36 - s * 17, 0, -8)
			p.arm_r = Vector3(-36 + s * 17, 0, 8)
			p.hips_y = HIPS_Y + absf(s) * 0.035
		Mode.CRAWL:
			# op handen en voeten, als een spin. Hoofd ondersteboven gedraaid.
			var s := sin(_phase)
			p.hips_y = 0.62
			p.torso = Vector3(100, 0, s * 5.0)
			p.neck = Vector3(-30, 0, 0)
			p.head = Vector3(-70, 0, 180)
			p.thigh_l = Vector3(40 + s * 15, 0, -28)
			p.thigh_r = Vector3(40 - s * 15, 0, 28)
			p.knee_l = Vector3(30, 0, 0)
			p.knee_r = Vector3(30, 0, 0)
			p.ankle_l = Vector3(-60, 0, 0)
			p.ankle_r = Vector3(-60, 0, 0)
			p.arm_l = Vector3(-140 - s * 20, 0, -22)
			p.arm_r = Vector3(-140 + s * 20, 0, 22)
			p.elbow_l = Vector3(45 + maxf(0.0, s) * 25, 0, 0)
			p.elbow_r = Vector3(45 + maxf(0.0, -s) * 25, 0, 0)
		Mode.PEEK:
			# leunt zijwaarts om een hoek, hand om de deurpost
			var k := peek_side
			p.torso = Vector3(18, 0, 48 * k)
			p.neck = Vector3(10, 0, 22 * k)
			p.head = Vector3(-45, 0, -40 * k)
			# armen recht naar beneden houden (achter de muur), één hand om de deurpost
			var grip := "_r" if k < 0 else "_l"
			var hang := "_l" if k < 0 else "_r"
			p["arm" + hang] = Vector3(-18, 0, -48 * k)
			p["elbow" + hang] = Vector3(-5, 0, 0)
			p["arm" + grip] = Vector3(-75, 0, -30 * k)
			p["elbow" + grip] = Vector3(-70, 0, 0)
		Mode.LUNGE:
			# grijpt naar je
			p.hips_y = 1.0
			p.torso = Vector3(58, 0, 0)
			p.neck = Vector3(5, 0, 0)
			p.head = Vector3(-55, 0, 0)
			p.arm_l = Vector3(-150, 0, -12)
			p.arm_r = Vector3(-150, 0, 12)
			p.elbow_l = Vector3(-5, 0, 0)
			p.elbow_r = Vector3(-5, 0, 0)
	return p


# ================================================================== animatie

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if _breath.playing:
			_breath.stop()
		return
	_t += delta
	_update_audio(delta)
	_report_proximity()
	if walk_speed > 0.05 and mode == Mode.IDLE:
		mode = Mode.WALK
	elif walk_speed <= 0.05 and mode == Mode.WALK:
		mode = Mode.IDLE
	if mode == Mode.WALK or mode == Mode.CRAWL:
		_phase += delta * maxf(walk_speed, 0.3) * (6.5 if mode == Mode.CRAWL else 4.5)
	if _scream_time > 0.0:
		_scream_time -= delta
		if _scream_time <= 0.0:
			_jaw_target = 0.08
	# stop-motion: maar 12 keer per seconde een nieuwe pose
	_step_acc += delta
	if _step_acc < 1.0 / STOP_MOTION_FPS:
		return
	var dt := _step_acc
	_step_acc = 0.0
	_jaw_open = lerpf(_jaw_open, _jaw_target, minf(1.0, dt * 14.0))
	_jaw.rotation.x = _jaw_open
	if still:
		return

	var pose := _pose(_t)
	var blend := minf(1.0, dt * 9.0)
	for joint in REST:
		var node: Node3D = _j[joint]
		node.rotation_degrees = node.rotation_degrees.lerp(pose[joint], blend)
	_hips.position.y = lerpf(_hips.position.y, pose.hips_y, blend)

	# hoofd: schokkerig knakken + naar jou kijken
	_jerk -= dt
	if _jerk <= 0.0:
		_jerk = randf_range(0.5, 3.0) * (1.5 - menace)
		_head_off = Vector3(randf_range(-0.3, 0.35), randf_range(-0.45, 0.45), randf_range(-0.75, 0.75))
	var look := Vector2.ZERO
	if track_player and Game.player and mode != Mode.PEEK:
		var cam: Vector3 = Game.player.get_camera().global_position
		var local := _neck.global_transform.affine_inverse() * cam - Vector3(0, 0.24, 0)
		var limit := 2.9 if owl_neck else 1.3
		look.y = clampf(atan2(local.x, local.z), -limit, limit)
		look.x = clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.5, 0.5)
	var w := 0.35 if track_player else 1.0
	var base: Vector3 = pose.head * (PI / 180.0)
	_head.rotation = Vector3(base.x + look.x + _head_off.x * w, base.y + look.y + _head_off.y * w, base.z + _head_off.z)
	if _scream_time > 0.0:
		_head.rotation += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.12

	# vingers trekken (en krullen om de deurpost bij gluren)
	for arm in _arms:
		for f in arm[2]:
			if mode == Mode.PEEK:
				f.rotation.x = lerpf(f.rotation.x, 0.9, blend)
			elif randf() < dt * (1.0 + menace * 3.0) * 0.5:
				f.rotation.x = randf_range(-0.6, 0.5)


## Hoe dichter het monster bij jou is, hoe meer ruis en kleurranden in beeld.
func _report_proximity() -> void:
	if Game.player == null or Game.post == null or Game.phase != Game.Phase.NIGHT:
		return
	var d := global_position.distance_to(Game.player.global_position)
	if d < 6.0:
		Game.post.report_proximity(1.0 - d / 6.0)


func _update_audio(delta: float) -> void:
	if breathing and not _breath.playing:
		_breath.play(randf() * 2.0)
	elif not breathing and _breath.playing:
		_breath.stop()
	# keelgeklik als je dichtbij bent
	if Game.player == null:
		return
	_click_timer -= delta
	if _click_timer <= 0.0:
		_click_timer = randf_range(3.0, 7.0)
		if global_position.distance_to(Game.player.global_position) < 7.0:
			Sfx.play_at("clicks", head_position(), -2.0, randf_range(0.85, 1.1))
