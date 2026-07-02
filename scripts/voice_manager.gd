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

# Mute (M key) overrides every voice mode — nothing transmits while muted.
var muted: bool = false

# For "toggle" mode (and the solo echo test in "open" mode): tracks whether
# the mic was tapped on.
var _toggle_on: bool = false

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
	if Input.is_action_just_pressed("toggle_mute"):
		muted = not muted
		print("[VoiceManager] Muted: ", muted)
	if Input.is_action_just_pressed("push_to_talk"):
		_toggle_on = not _toggle_on  # only read by toggle/echo modes below
	_update_recording_state()
	if is_recording:
		_poll_voice()


func _in_lobby_with_peers() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0


## One-line mic status for the HUD — kept here so all the mode logic
## lives in one script.
func get_status_text() -> String:
	if muted:
		return "MIC MUTED — M to unmute"
	if is_recording:
		match GameConfig.voice_mode:
			"open":
				return "MIC OPEN (always on) — M to mute"
			"toggle":
				return "MIC ON — V to turn off"
			_:
				return "MIC ON"
	match GameConfig.voice_mode:
		"open":
			return "Mic opens automatically in a lobby — M to mute"
		"toggle":
			return "Tap V to talk — M to mute"
		_:
			return "Hold V to talk — M to mute"


## Should the mic be capturing right now? Depends on the voice_mode dial:
##   push_to_talk — while V is held
##   toggle       — tap V on, tap V off
##   open         — always, while in a lobby (solo: V toggles the echo test)
func _wants_recording() -> bool:
	if muted:
		return false
	match GameConfig.voice_mode:
		"open":
			if _in_lobby_with_peers():
				return true
			return _toggle_on  # solo echo test still tap-to-toggle
		"toggle":
			return _toggle_on
		_:  # push_to_talk
			return Input.is_action_pressed("push_to_talk")


func _update_recording_state() -> void:
	var want_recording: bool = _wants_recording()
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
	# Light up "(( talking ))" over the speaker's head, if they have one.
	var avatar: Node = get_node_or_null("/root/World/Players/" + str(sender_peer_id))
	if avatar != null and avatar.has_method("flash_speaking_indicator"):
		avatar.flash_speaking_indicator()
	_play_voice_buffer(compressed, _get_remote_playback(sender_peer_id))


## Where should this remote player's voice come out?
## PROXIMITY VOICE lives in this decision: if the speaker has an avatar in
## the world, their voice plays from the avatar's AudioStreamPlayer3D —
## Godot then applies distance falloff and left/right panning between the
## speaker's capsule and OUR camera automatically. No avatar (still in the
## menu, or not spawned yet) falls back to a flat non-positional stream.
func _get_remote_playback(peer_id: int) -> AudioStreamGeneratorPlayback:
	var avatar: Node = get_node_or_null("/root/World/Players/" + str(peer_id))
	if avatar != null and avatar.has_method("get_voice_playback"):
		var positional: AudioStreamGeneratorPlayback = avatar.get_voice_playback()
		if positional != null:
			return positional

	if not remote_streams.has(peer_id):
		remote_streams[peer_id] = _make_voice_stream()
		print("[VoiceManager] First voice packet from peer ", peer_id, " — flat stream created")
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
