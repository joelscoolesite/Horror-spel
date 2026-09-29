extends Node
## "Sfx" — speelt geluiden af. Is een autoload, dus overal bereikbaar.
##   Sfx.play("switch")                       -> gewoon geluid (niet in 3D)
##   Sfx.play_at("scratch", positie)          -> geluid op een plek in de wereld
##   Sfx.loop_at("fridge_hum", node)          -> blijft spelen, vast aan een node
## Geluiden staan in assets/sounds/ (naam zonder .wav).

var _cache := {}
var _muffle_index := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Twee extra audio-kanalen: "Ambience" (achtergrond) en "SFX" (effecten).
	for bus_name in ["Ambience", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	# Filter op Master voor als je onder de deken ligt (alles klinkt gedempt).
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 700.0
	AudioServer.add_bus_effect(0, lp)
	_muffle_index = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, _muffle_index, false)


func stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var path := "res://assets/sounds/%s.wav" % sound
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
		if _cache[sound] == null:
			push_warning("Geluid niet gevonden: " + path)
	return _cache[sound]


func play(sound: String, volume_db := 0.0, pitch := 1.0, bus := "SFX") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer3D:
	var p := _make_3d(sound, volume_db, pitch)
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Een geluid dat blijft herhalen (de .wav moet als loop geïmporteerd zijn).
func loop_at(sound: String, parent: Node3D, volume_db := 0.0, bus := "Ambience") -> AudioStreamPlayer3D:
	var p := _make_3d(sound, volume_db, 1.0)
	p.bus = bus
	parent.add_child(p)
	p.play()
	return p


## Niet-3D geluid dat blijft herhalen. Geef een `parent` mee, dan stopt het
## vanzelf als die node verdwijnt (bijv. bij terug naar het menu).
func loop(sound: String, volume_db := 0.0, bus := "Ambience", parent: Node = null) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.bus = bus
	(parent if parent else self).add_child(p)
	p.play()
	return p


## Alles gedempt laten klinken (onder de deken).
func set_muffled(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(0, _muffle_index, on)


func _make_3d(sound: String, volume_db: float, pitch: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = "SFX"
	p.unit_size = 3.0
	p.max_distance = 25.0
	p.attenuation_filter_cutoff_hz = 6000.0
	return p
