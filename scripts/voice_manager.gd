extends Node
## VoiceManager — Steam voice capture, transmission, and playback.
##
## Hold V (push-to-talk) to capture your mic through Steam's voice system.
## - In a lobby: the compressed voice is broadcast to every peer as an
##   UNRELIABLE RPC (a lost packet = a tiny blip; voice must never stall
##   waiting for retransmission). Each sender gets their own playback
##   stream on the receiving side. Flat volume for now — proximity
##   attenuation is the next milestone.
## - Not in a lobby: your voice loops back to your own ears (echo test),
##   so the pipeline stays testable solo.
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

# One playback stream per remote player, created the first time we hear them.
# peer_id -> { "player": AudioStreamPlayer, "playback": AudioStreamGeneratorPlayback }
var remote_streams: Dictionary = {}


func _ready() -> void:
	echo_playback = _make_voice_stream()["playback"]
	# When someone disconnects, drop their playback stream.
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


## Creates an audio player ready to receive pushed voice samples.
## Returns { "player": the node (needed for cleanup), "playback": the
## handle we push samples into }. Used for the echo test AND remote voices.
func _make_voice_stream() -> Dictionary:
	var player := AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = VOICE_SAMPLE_RATE
	generator.buffer_length = 0.1  # seconds of buffer; lower = less delay
	player.stream = generator
	add_child(player)
	player.play()  # must be playing before we can grab its playback
	return { "player": player, "playback": player.get_stream_playback() }


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

	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		# In a lobby with other people: broadcast to every peer.
		# (You don't hear yourself — that's how basically all voice chat works.)
		_receive_voice.rpc(voice["buffer"])
	else:
		# Alone (menu or empty lobby): echo test, hear yourself.
		_play_voice_buffer(voice["buffer"], echo_playback)


## Runs on every OTHER machine when someone transmits voice.
## "unreliable" = packets may drop under bad network, which for voice is
## the correct trade: a missing syllable beats a frozen stream.
@rpc("any_peer", "call_remote", "unreliable")
func _receive_voice(compressed: PackedByteArray) -> void:
	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	_play_voice_buffer(compressed, _get_remote_playback(sender_peer_id))


## Fetch (or lazily create) the playback stream for one remote player.
func _get_remote_playback(peer_id: int) -> AudioStreamGeneratorPlayback:
	if not remote_streams.has(peer_id):
		remote_streams[peer_id] = _make_voice_stream()
		print("[VoiceManager] First voice packet from peer ", peer_id, " — stream created")
	return remote_streams[peer_id]["playback"]


func _on_peer_disconnected(peer_id: int) -> void:
	if remote_streams.has(peer_id):
		remote_streams[peer_id]["player"].queue_free()
		remote_streams.erase(peer_id)


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
