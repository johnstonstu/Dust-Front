extends Node

var profile
var loops: AudioStreamPlayer
var streams := {}
var radio: AudioStreamPlayer
var music: AudioStreamPlayer
var in_flight := false
var cannon_voices: Array[AudioStreamPlayer] = []
var cannon_voice_index := 0
var hit_voice: AudioStreamPlayer
var victory_music: AudioStreamPlayer

func celebrate() -> void:
	victory_music.volume_db=-5+linear_to_db(maxf(.001,profile.music))
	victory_music.play()

func fire_cannon(variant: int) -> void:
	var voice := cannon_voices[cannon_voice_index]
	cannon_voice_index=(cannon_voice_index+1)%cannon_voices.size()
	voice.volume_db=(-9 if variant==1 else -4)+linear_to_db(maxf(.001,profile.effects))
	voice.pitch_scale=randf_range(.96,1.04)*(1.12 if variant==1 else .84 if variant==2 else 1.0)
	voice.play()

func confirm_hit() -> void:
	if hit_voice.playing: return
	hit_voice.volume_db=-7+linear_to_db(maxf(.001,profile.effects))
	hit_voice.pitch_scale=1.4
	hit_voice.play()

func restore_audible() -> void:
	profile.muted=false
	profile.master=.75
	profile.effects=.75
	profile.rotor=.5
	profile.music=.6
	profile.save_profile()
	apply_levels()

func speak(key: String) -> float:
	radio.stop()
	if not streams.has(key) or streams[key]==null: return 0
	radio.stream=streams[key]
	radio.stream_paused=false
	radio.volume_db=-2+linear_to_db(maxf(.001,profile.effects))
	radio.play()
	return radio.stream.get_length()

func setup(p) -> void:
	profile = p
	var files := {"rotor":"rotor_loop.wav", "cannon":"cannon_heavy.wav", "rocket":"rocket_launch.wav", "explosion":"explosionCrunch_000.ogg", "explosion2":"explosionCrunch_002.ogg", "heavy_explosion":"lowFrequency_explosion_000.ogg", "hit":"impactMetal_000.ogg", "enemy":"laserSmall_000.ogg", "heavy":"laserLarge_000.ogg", "lock":"lock.wav", "warning":"warning.wav", "reward":"reward.wav", "click":"click.wav", "radio_briefing":"radio_briefing.wav", "radio_wave":"radio_wave.wav"}
	for key in files:
		streams[key] = load("res://assets/audio/" + files[key])
	for key in ["alpine","volcanic","complete"]:
		streams["radio_"+key]=load("res://assets/audio/radio_"+key+".wav")
	loops = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = streams.rotor.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	loops.stream = stream
	add_child(loops)
	radio=AudioStreamPlayer.new()
	add_child(radio)
	music=AudioStreamPlayer.new()
	var theme: AudioStreamWAV=load("res://assets/audio/dust_front_theme.wav").duplicate()
	theme.loop_mode=AudioStreamWAV.LOOP_FORWARD
	theme.loop_end=theme.data.size()/4
	music.stream=theme
	add_child(music)
	music.volume_db=-18
	music.play()
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		voice.stream=streams.cannon
		add_child(voice)
		cannon_voices.append(voice)
	hit_voice=AudioStreamPlayer.new()
	hit_voice.stream=streams.hit
	add_child(hit_voice)
	AudioServer.add_bus_effect(0,AudioEffectLimiter.new())
	victory_music=AudioStreamPlayer.new()
	victory_music.stream=load("res://assets/audio/victory_theme.wav")
	add_child(victory_music)
	apply_levels()

func _process(delta: float) -> void:
	if not is_instance_valid(music): return
	var target_db := -60.0 if in_flight else -8.0+linear_to_db(maxf(.001,profile.music))
	if radio.playing: target_db-=12
	if victory_music.playing: target_db-=18
	victory_music.volume_db=-5+linear_to_db(maxf(.001,profile.music))-(10 if radio.playing else 0)
	music.volume_db=lerpf(music.volume_db,target_db,1-exp(-delta*3))

func apply_levels() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, profile.master)) - 5)
	AudioServer.set_bus_mute(0, profile.muted)
	loops.volume_db = linear_to_db(maxf(0.001, profile.rotor)) - 8
	music.volume_db=-8+linear_to_db(maxf(.001,profile.music))

func flight(start: bool) -> void:
	victory_music.stop()
	in_flight=start
	loops.stream_paused = false
	if start:
		loops.play()
	else:
		loops.stop()
		radio.stop()

func set_pause(value: bool) -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stream_paused = value

func update_flight(speed: float, delta: float) -> void:
	loops.pitch_scale = lerpf(loops.pitch_scale, 0.94 + speed / 220, minf(delta * 2, 1))
	loops.volume_db = linear_to_db(maxf(.001, profile.rotor)) - 10 + minf(speed / 14, 4)
	if radio.playing: loops.volume_db-=7

func cue(key: String) -> void:
	if not streams.has(key) or get_child_count() > 28:
		return
	var player := AudioStreamPlayer.new()
	player.stream = streams[key]
	player.volume_db = -17 + linear_to_db(maxf(.001, profile.effects))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_at(key: String, location: Vector3, volume: float = -10.0) -> void:
	if not streams.has(key) or get_child_count() > 28:
		return
	var player := AudioStreamPlayer3D.new()
	add_child(player)
	player.global_position = location
	player.stream = streams[key]
	player.volume_db = volume + linear_to_db(maxf(.001, profile.effects))
	player.unit_size = 30
	player.max_distance = 750
	player.pitch_scale = randf_range(.93, 1.05)
	player.finished.connect(player.queue_free)
	player.play()

func shutdown() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stream_paused = false
			child.stop()
			child.stream = null
			child.queue_free()
	streams.clear()
