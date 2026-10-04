extends Node
# Autoload this as "Audio". Do NOT add class_name.

const DEBUG := true   # set to false once sounds work

const MAX_CUTOFF := 20500.0       # low pass fully open
const MIN_CUTOFF := 600.0         # low pass at full strength
const MAX_REVERB_WET := 0.5
const MAX_QUIET_DB := -14.0       # volume drop at full strength
const POOL_SIZE := 16

var music_player := AudioStreamPlayer.new()
var sfx_players: Array[AudioStreamPlayer] = []
var steal_index := 0

var reverb := AudioEffectReverb.new()
var lowpass := AudioEffectLowPassFilter.new()
var amp := AudioEffectAmplify.new()

var master_idx := 0
var reverb_idx := 0
var lowpass_idx := 0
var amp_idx := 0
var fx_ready := false
var muffle_tween: Tween

# 0.0 = clean, 1.0 = maximum. Sets reverb, low pass and quietness together.
var muffle := 0.0:
	set(value):
		muffle = clampf(value, 0.0, 1.0)
		set_reverb_amount(muffle)
		set_lowpass_amount(muffle)
		set_quiet_amount(muffle)

func _process(_delta):
	var sfx := AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("SFX"), 0)
	var master := AudioServer.get_bus_peak_volume_left_db(0, 0)
	if sfx > -60.0 or master > -60.0:
		print("peak  SFX=", snappedf(sfx, 0.1), "  Master=", snappedf(master, 0.1))

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working if you ever pause the tree

	_ensure_bus("Music")
	_ensure_bus("SFX")

	music_player.bus = "Music"
	add_child(music_player)

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)

	# effects on Master so they hit every sound in the game
	master_idx = AudioServer.get_bus_index("Master")

	reverb.room_size = 0.8
	reverb.damping = 0.5
	reverb.wet = 0.0
	reverb.dry = 1.0

	AudioServer.add_bus_effect(master_idx, reverb)
	reverb_idx = AudioServer.get_bus_effect_count(master_idx) - 1
	AudioServer.add_bus_effect(master_idx, lowpass)
	lowpass_idx = AudioServer.get_bus_effect_count(master_idx) - 1
	AudioServer.add_bus_effect(master_idx, amp)
	amp_idx = AudioServer.get_bus_effect_count(master_idx) - 1

	fx_ready = true
	reset_effects()
	
	print("output device: ", AudioServer.output_device)
	print("device list: ", AudioServer.get_output_device_list())
	print("mix rate: ", AudioServer.get_mix_rate())
	print("master effects: ", AudioServer.get_bus_effect_count(0))
 

	if DEBUG:
		for i in AudioServer.bus_count:
			print("Audio bus ", i, ": ", AudioServer.get_bus_name(i),
				" muted=", AudioServer.is_bus_mute(i),
				" db=", AudioServer.get_bus_volume_db(i))


func _ensure_bus(bus_name: String):
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


# --- global effects (all take 0.0 to 1.0) ---

func set_reverb_amount(amount: float):
	if not fx_ready: return
	amount = clampf(amount, 0.0, 1.0)
	reverb.wet = amount * MAX_REVERB_WET
	AudioServer.set_bus_effect_enabled(master_idx, reverb_idx, amount > 0.001)


func set_lowpass_amount(amount: float):
	if not fx_ready: return
	amount = clampf(amount, 0.0, 1.0)
	# exponential so it sounds even across the range
	lowpass.cutoff_hz = MAX_CUTOFF * pow(MIN_CUTOFF / MAX_CUTOFF, amount)
	AudioServer.set_bus_effect_enabled(master_idx, lowpass_idx, amount > 0.001)


func set_quiet_amount(amount: float):
	if not fx_ready: return
	amount = clampf(amount, 0.0, 1.0)
	amp.volume_db = MAX_QUIET_DB * amount
	AudioServer.set_bus_effect_enabled(master_idx, amp_idx, amount > 0.001)


# smooth change, e.g. Audio.tween_muffle(1.0, 2.0)
func tween_muffle(target: float, time: float):
	if muffle_tween: muffle_tween.kill()
	muffle_tween = create_tween()
	muffle_tween.tween_property(self, "muffle", target, time)


func reset_effects():
	if muffle_tween: muffle_tween.kill()
	muffle = 0.0


# --- music ---

func play_music(stream: AudioStream):
	if stream == null:
		push_warning("Audio.play_music: stream is null")
		return
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stream = stream
	music_player.play()


func stop_music():
	music_player.stop()


# --- sfx ---

# Returns the player used, so you can stop it early if you need to.
func play_sfx(stream: AudioStream, pitch_variance := 0.0, volume_db := 0.0) -> AudioStreamPlayer:
	if stream == null:
		push_warning("Audio.play_sfx: stream is null (empty Inspector slot?)")
		return null

	# find a free player
	var player: AudioStreamPlayer = null
	for p in sfx_players:
		if not p.playing:
			player = p
			break

	# pool full: cut off the oldest-assigned player instead of dropping the new sound
	if player == null:
		player = sfx_players[steal_index]
		steal_index = (steal_index + 1) % sfx_players.size()
		if DEBUG:
			print("Audio: pool full, interrupting a sound")

	player.stream = stream
	player.pitch_scale = maxf(0.01, 1.0 + randf_range(-pitch_variance, pitch_variance))
	player.volume_db = volume_db
	player.play()

	if DEBUG:
		print("Audio: playing ", stream.resource_path, "  len=", stream.get_length(),
			"  bus=", player.bus)
	return player


func stop_all_sfx():
	for p in sfx_players:
		p.stop()


func set_bus_volume(bus_name: String, linear: float):
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		push_warning("Audio.set_bus_volume: no bus named " + bus_name)
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
