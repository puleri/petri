class_name PetriAudio
extends Node

const SAMPLE_RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _cursor := 0
var _unlocked := false
var _sfx_volume := 0.8
var _music_volume := 0.45
var _ambient: AudioStreamPlayer
var _streams := {}


func _ready() -> void:
	for i in 12:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_ambient = AudioStreamPlayer.new()
	add_child(_ambient)
	_streams = {
		"fire": _tone(690.0, 0.055, 0.42, "square", 160.0),
		"boost": _tone(125.0, 0.18, 0.5, "saw", 220.0),
		"split": _tone(240.0, 0.13, 0.48, "triangle", 520.0),
		"impact": _tone(82.0, 0.16, 0.55, "noise", 0.0),
		"ui": _tone(440.0, 0.07, 0.35, "sine", 120.0),
		"game_over": _tone(210.0, 0.72, 0.5, "triangle", -150.0),
		"elite_spawn": _tone(96.0, 0.34, 0.42, "saw", 120.0),
		"item_appear": _tone(520.0, 0.18, 0.38, "triangle", 360.0),
		"item_pickup": _tone(710.0, 0.22, 0.42, "sine", 520.0),
		"aoe": _tone(130.0, 0.2, 0.42, "sine", 430.0),
		"turret": _tone(880.0, 0.045, 0.28, "square", -180.0),
		"mine": _tone(105.0, 0.18, 0.48, "noise", 0.0),
	}
	_ambient.stream = _ambient_hum()
	apply_levels(_sfx_volume, _music_volume)


func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	if _music_volume > 0.001:
		_ambient.play()


func apply_levels(sfx: float, music: float) -> void:
	_sfx_volume = clampf(sfx, 0.0, 1.0)
	_music_volume = clampf(music, 0.0, 1.0)
	_ambient.volume_db = linear_to_db(maxf(_music_volume, 0.001))
	if _unlocked and _music_volume > 0.001 and not _ambient.playing:
		_ambient.play()
	elif _music_volume <= 0.001:
		_ambient.stop()


func play_sfx(name: String) -> void:
	if not _unlocked or not _streams.has(name) or _sfx_volume <= 0.001:
		return
	var player := _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	player.stream = _streams[name]
	player.volume_db = linear_to_db(maxf(_sfx_volume, 0.001))
	player.play()


func stop_all() -> void:
	_ambient.stop()
	_ambient.stream = null
	for player in _players:
		player.stop()
		player.stream = null
	_streams.clear()


func _tone(start_hz: float, duration: float, gain: float, wave: String, sweep_hz: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(start_hz * 31.0 + duration * 10000.0)
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var hz := maxf(25.0, start_hz + sweep_hz * (t / duration))
		phase += TAU * hz / SAMPLE_RATE
		var raw := 0.0
		match wave:
			"square": raw = 1.0 if sin(phase) >= 0.0 else -1.0
			"saw": raw = 2.0 * fmod(phase / TAU, 1.0) - 1.0
			"triangle": raw = asin(sin(phase)) * 2.0 / PI
			"noise": raw = rng.randf_range(-1.0, 1.0)
			_: raw = sin(phase)
		var envelope := pow(1.0 - t / duration, 2.0)
		bytes.encode_s16(i * 2, int(clampf(raw * gain * envelope, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


func _ambient_hum() -> AudioStreamWAV:
	var duration := 2.0
	var stream := _tone(48.0, duration, 0.12, "sine", 1.5)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(duration * SAMPLE_RATE)
	return stream
