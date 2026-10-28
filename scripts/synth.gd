class_name MineSynth
extends Node

var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var voice_index := 0
var muted := false
var break_cooldown := 0.0
var variation_rng := RandomNumberGenerator.new()

func _process(delta: float) -> void:
	break_cooldown = maxf(0, break_cooldown - delta)

func _ready() -> void:
	variation_rng.randomize()
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -15.0
		add_child(voice)
		voices.append(voice)
	sounds.hit = make_sound(90, 0.065, 0.65, -40)
	sounds.place = make_sound(72, 0.11, 0.42, -38)
	sounds.break_block = make_sound(130, 0.12, 0.75, -90)
	sounds.pickup = make_sound(660, 0.13, 0.03, 600)
	sounds.freeze = make_sound(360, 0.2, 0.05, -200)
	sounds.ui = make_sound(440, 0.08, 0.01, 180)
	sounds.sell = make_sound(550, 0.32, 0.02, 660)
	sounds.sell_complete = make_chime([660.0, 880.0, 1046.0, 1320.0], 0.065)
	sounds.death = make_sound(230, 0.65, 0.3, -190)
	sounds.death_shake = make_sound(105, 0.12, 0.6, -70)
	sounds.death_arc = make_sound(580, 0.65, 0.15, -540)
	sounds.departure_close = make_sound(210, 0.55, 0.18, 680)
	sounds.discard = make_sound(430, 0.14, 0.48, -340)
	sounds.departure_float = make_sound(260, 0.65, 0.03, 620)
	sounds.enemy_hit = make_sound(165, 0.22, 0.72, -115)
	sounds.step = make_sound(115, 0.035, 0.78, -50)
	sounds.land = make_sound(95, 0.18, 0.55, -65)
	sounds.coin = make_sound(880, 0.06, 0.01, 250)
	sounds.purchase = make_sound(440, 0.15, 0.02, 440)
	sounds.discovery_ore = make_chime([660.0, 880.0, 1100.0], 0.08)
	sounds.discovery_animal = make_chime([440.0, 554.0, 660.0], 0.10)
	sounds.discovery_milestone = make_chime([523.0, 659.0, 784.0, 1046.0], 0.10)
	sounds.depth_record = make_chime([392.0, 523.0, 659.0, 784.0], 0.11)
	sounds.goal_ready = make_chime([660.0, 990.0], 0.10)
	sounds.results_tick = make_sound(760, 0.035, 0.01, 110)
	sounds.results_value = make_chime([660.0, 880.0, 1320.0], 0.07)
	sounds.results_reward = make_chime([784.0, 1046.0], 0.06)

func make_chime(notes: Array, note_length: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	for note in notes:
		samples.append_array(make_sound(float(note), note_length, 0.01, float(note) * 0.06).data)
	stream.data = samples
	return stream

func make_sound(frequency: float, duration: float, noise: float, sweep: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var frames := int(duration * 22050)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(frames):
		var t := float(i) / frames
		phase += TAU * maxf(25, frequency + sweep * t) / 22050.0
		var wave := sin(phase) * 0.7 + sin(phase * 2.0) * 0.2
		wave = lerpf(wave, rng.randf_range(-1, 1), noise)
		var envelope := pow(1.0 - t, 2.0) * minf(t * 40.0, 1.0)
		data.encode_s16(i * 2, int(clampf(wave * envelope, -1, 1) * 24000))
	stream.data = data
	return stream

func play_sound(sound: String, gain_db: float = 0.0, pitch: float = 1.0) -> void:
	if muted or not sounds.has(sound) or voices.is_empty():
		return
	if sound == "break_block":
		if break_cooldown > 0:
			return
		break_cooldown = 0.2
	if sound == "death_shake":
		# Generate a fresh rattling impact for each shake rather than repitching one clip.
		sounds.death_shake = make_sound(variation_rng.randf_range(90, 165), variation_rng.randf_range(0.10, 0.17), variation_rng.randf_range(0.4, 0.75), variation_rng.randf_range(-110, -45))
	var voice := voices[voice_index % voices.size()]
	voice_index += 1
	voice.volume_db = -15.0 + gain_db
	voice.pitch_scale = pitch
	voice.stream = sounds[sound]
	voice.play()
