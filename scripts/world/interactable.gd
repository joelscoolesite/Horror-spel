class_name Interactable
extends Node3D
## Basis voor alles waar de speler op kan kijken en iets mee kan doen.
## De speler zoekt vanaf wat hij raakt omhoog naar de eerste Interactable.


## Tekst die onderin beeld verschijnt, bijv. "Turn off the light". Leeg = niks tonen.
func get_prompt() -> String:
	return ""


## Wordt aangeroepen als de speler op E drukt.
func interact(_player: Node) -> void:
	pass


## Kan je dit vastpakken en met de muis bewegen? (deuren/kasten)
func can_drag() -> bool:
	return false


func drag_begin() -> void:
	pass


func drag(_mouse_motion: Vector2) -> void:
	pass


func drag_end() -> void:
	pass


## Onzichtbaar blok waar de "kijk-straal" van de speler op kan landen.
func add_hitbox(size: Vector3, offset := Vector3.ZERO) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = Build.LAYER_INTERACT
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	area.position = offset
	add_child(area)
	return area
