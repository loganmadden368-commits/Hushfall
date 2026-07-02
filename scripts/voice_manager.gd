extends Node
## VoiceManager — Steam voice capture and playback.
##
## MILESTONE 1 (echo test): hold V and your own mic is captured through
## Steam's voice system, decompressed, and played straight back to you.
## No networking yet — this proves the capture -> decompress -> playback
## pipeline works on one machine before we send voice to anyone.
##
## How Steam voice works: while recording is on, Steam compresses your mic
## input internally. We poll getVoice() every frame to drain whatever
## compressed audio has accumulated, then decompressVoice() turns it into
## raw sound samples (16-bit mono PCM) we can push into an audio stream.

# Steam compresses at ~its own rate; decompressVoice resamples to whatever
# rate we ask for. 48000 matches Steam's usual optimal rate. Sender and
# receiver must agree on this once we network it, so it's a const, not a dial.
const VOICE_SAMPLE_RATE: int = 48000

# Steam's k_EVoiceResultOK — "this call returned actual voice data".
const VOICE_RESULT_OK: int = 0

var is_recording: bool = false

# The local echo player: a generator stream we push decompressed samples into.
var echo_playback: AudioStreamGeneratorPlayback = null


func _ready() -> void:
	var echo_player := AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = VOICE_SAMPLE_RATE
	generator.buffer_length = 0.1  # seconds of buffer; lower = less delay
	echo_player.stream = generator
	add_child(echo_player)
	echo_player.play()  # must be playing before we can grab its playback
	echo_playback = echo_player.get_stream_playback()


func _process(_delta: float) -> void:
	if not SteamManager.steam_ready:
		return
	_update_recording_state()
	if is_recording:
		_poll_voice()


## Push-to-talk: recording tracks whether V is held.
func _update_recording_state() -> void:
	var want_recording: bool = Input.is_action_pressed("push_to_talk")
	if want_recording == is_recording:
		return
	is_recording = want_recording
	if is_recording:
		Steam.startVoiceRecording()
		print("[VoiceManager] Mic ON — talk!")
	else:
		Steam.stopVoiceRecording()
		print("[VoiceManager] Mic off")
	# Tells Steam we're speaking in-game so it ducks Steam friend-chat audio.
	Steam.setInGameVoiceSpeaking(SteamManager.steam_id, is_recording)


## Drain whatever compressed voice Steam has captured since last frame.
func _poll_voice() -> void:
	var voice: Dictionary = Steam.getVoice()
	if voice["result"] != VOICE_RESULT_OK or voice["size"] <= 0:
		return  # nothing new this frame — normal, not an error
	# Milestone 1: play it back to ourselves. Milestone 2 sends it to peers.
	_play_voice_buffer(voice["buffer"], echo_playback)


## Decompress a Steam voice packet and push it into an audio stream.
## Reused later for remote players' voices — playback target is a parameter.
func _play_voice_buffer(compressed: PackedByteArray, playback: AudioStreamGeneratorPlayback) -> void:
	var decompressed: Dictionary = Steam.decompressVoice(compressed, VOICE_SAMPLE_RATE)
	if decompressed["result"] != VOICE_RESULT_OK or decompressed["size"] <= 0:
		return

	var pcm: PackedByteArray = decompressed["uncompressed"]
	var byte_count: int = decompressed["size"]

	# The PCM data is 16-bit signed mono: every 2 bytes = one sample.
	# Godot's generator wants stereo float frames in -1..1, so convert:
	# read each sample, scale it, duplicate into left+right channels.
	var frames := PackedVector2Array()
	frames.resize(byte_count / 2.0)
	for i in frames.size():
		var amplitude: float = pcm.decode_s16(i * 2) / 32768.0
		frames[i] = Vector2(amplitude, amplitude)

	# Only push if the stream has room, else we'd stall the game. Dropping
	# a packet under pressure is fine for voice (tiny blip, self-corrects).
	if playback != null and playback.get_frames_available() >= frames.size():
		playback.push_buffer(frames)
