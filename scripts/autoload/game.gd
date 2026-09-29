extends Node
## "Game" — onthoudt alles wat de hele game door bewaard moet blijven:
## welke dag het is, de verborgen stats en wat je gedaan hebt.
## Is een autoload, dus overal bereikbaar als `Game.iets`.

signal task_done(id: String)
signal closet_opened(closet: Node)
signal lights_changed

enum Phase { MENU, MORNING, SCHOOL, AFTERNOON, NIGHT }

const LAST_DAY := 5
## Tot en met deze dag is de game nu speelbaar. Daarna komt "einde demo".
const PLAYABLE_UNTIL_DAY := 2
const DAY_NAMES := ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]
## De klok staat elke nacht later, alsof je steeds minder slaapt.
const NIGHT_TIMES := ["00:13", "01:26", "02:39", "03:33", "03:33"]

var day := 1
var phase := Phase.MENU

## Verborgen stats (de speler ziet deze nooit). Zie docs/GDD.md §7.
var exhaustion := 0 ## Uitputting
var help := 0 ## Hulp

## Losse dingen die we onthouden, bijv. flags["forgot_lunch_1"] = true
var flags := {}
var orders: Array[String] = []

## Instellingen
var mouse_sensitivity := 0.0025

## Snelle verwijzingen naar belangrijke nodes (worden gezet als ze laden).
var player: Node = null
var hud: Node = null
var apartment: Node = null
var post: Node = null
var school: Node = null

## Debug-menu: start bij deze fase na het herladen (-1 = normaal)
var debug_start_phase := -1
var debug_open := false


func reset() -> void:
	day = 1
	phase = Phase.MENU
	exhaustion = 0
	help = 0
	flags.clear()
	orders.clear()


func is_night() -> bool:
	return phase == Phase.NIGHT


func complete_task(id: String) -> void:
	task_done.emit(id)


## Wacht tot een bepaalde taak gedaan is. Gebruik: `await Game.wait_for_task("sleep")`
func wait_for_task(id: String) -> void:
	while true:
		var done: String = await task_done
		if done == id:
			return


## Wacht een aantal seconden. Gebruik: `await Game.wait(2.0)`
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
