class_name TaskSpot
extends Interactable
## Een plek waar je een taak doet (brood smeren, gamen, naar bed...).
## Het verhaal (de "directors") zet hem aan met `activate("Make a sandwich")`
## en wacht dan met `await Game.wait_for_task(task_id)`.

var task_id := ""
var prompt := ""
var active := false


func activate(text: String) -> void:
	prompt = text
	active = true


func deactivate() -> void:
	active = false


func get_prompt() -> String:
	return ("[E] " + prompt) if active else ""


func interact(_player: Node) -> void:
	if active:
		Game.complete_task(task_id)
