class_name LightSwitch
extends Interactable
## Lichtknop aan de muur. Zet een of meer lampen aan/uit.

var room := ""
var lights: Array[Light3D] = []
var lamp_materials: Array[ShaderMaterial] = []
var is_on := true
var broken := false ## voor latere nachten: knop doet het niet


func build() -> void:
	var plate := Build.mat("plastic_white")
	Build.box(self, Vector3(0.08, 0.12, 0.02), Vector3(0, -0.06, 0.01), plate, false)
	Build.box(self, Vector3(0.03, 0.05, 0.02), Vector3(0, -0.025, 0.025), Build.mat("plastic_white", Color(0.85, 0.85, 0.8)), false)
	add_hitbox(Vector3(0.25, 0.3, 0.15), Vector3(0, 0, 0.05))


func get_prompt() -> String:
	return "[E] Turn off the light" if is_on else "[E] Turn on the light"


func interact(_player: Node) -> void:
	Sfx.play_at("switch", global_position, -4.0, randf_range(0.95, 1.05))
	if broken:
		if Game.hud:
			Game.hud.say("It doesn't work.")
		return
	set_on(not is_on)


func set_on(on: bool) -> void:
	is_on = on
	for l in lights:
		l.visible = on
	for m in lamp_materials:
		m.set_shader_parameter("emission_energy", 1.4 if on else 0.0)
		m.set_shader_parameter("tint", Color(1, 0.95, 0.8) if on else Color(0.5, 0.5, 0.5))
	Game.lights_changed.emit()


## Laat de lamp kort knipperen (eng!). Eindigt in de stand `end_on`.
func flicker(times := 4, end_on := false) -> void:
	for i in times:
		set_on(not is_on)
		await Game.wait(randf_range(0.05, 0.2))
	set_on(end_on)
