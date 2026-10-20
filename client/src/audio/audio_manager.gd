extends Node

## Autoload: procedural audio. All SFX and the music loop are synthesized at
## startup into AudioStreamWAV resources — the game ships zero audio files and
## still sounds polished. Buses: Master / Music / SFX.

const MIX_RATE := 22050
const POOL_SIZE := 14

var _pool: Array[AudioStreamPlayer] = []
var _cursor := 0
var _sfx: Dictionary = {}
var _music_player: AudioStreamPlayer

func _ready() -> void:
	_build_sfx()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.stream = _build_music()
	add_child(_music_player)
	apply_volumes()

func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(Settings.master_volume, 0.001)))
	AudioServer.set_bus_volume_db(_bus("Music"), linear_to_db(maxf(Settings.music_volume, 0.001)))
	AudioServer.set_bus_volume_db(_bus("SFX"), linear_to_db(maxf(Settings.sfx_volume, 0.001)))

func _bus(name: String) -> int:
	return AudioServer.get_bus_index(name)

func play_music() -> void:
	if not _music_player.playing:
		_music_player.play()

func stop_music() -> void:
	_music_player.stop()

# ---- public SFX API ----

func play(name: String, pitch := 1.0) -> void:
	if not _sfx.has(name):
		return
	var p := _pool[_cursor]
	_cursor = (_cursor + 1) % POOL_SIZE
	p.stream = _sfx[name]
	p.pitch_scale = pitch
	p.play()

func tap() -> void: play("tap")
func pickup() -> void: play("pickup")
func place() -> void: play("place")
func invalid() -> void: play("invalid")
func snap() -> void: play("snap")
func clear_lines(n: int) -> void:
	play("clear" if n <= 1 else ("clear_big" if n == 2 else "clear_huge"))
func combo(n: int) -> void:
	play("combo", 1.0 + minf(n, 6) * 0.06)
func count() -> void: play("count")
func go() -> void: play("go")
func win() -> void: play("win")
func lose() -> void: play("lose")
func draw_sfx() -> void: play("draw")
func game_over() -> void: play("lose")

# ---- synthesis ----

func _build_sfx() -> void:
	_sfx["tap"] = _tone([660.0], 0.05, 0.5, "sine", 0.003)
	_sfx["pickup"] = _tone([280.0, 420.0], 0.09, 0.45, "sine", 0.004)
	_sfx["snap"] = _tone([500.0, 700.0], 0.06, 0.5, "triangle", 0.002)
	_sfx["place"] = _blend([
		_tone([180.0, 120.0], 0.14, 0.8, "sine", 0.002),
		_noise(0.05, 0.25),
	])
	_sfx["invalid"] = _tone([150.0, 110.0], 0.16, 0.5, "saw", 0.004)
	_sfx["clear"] = _arp([523.25, 659.25, 783.99], 0.075, 0.5, "sine")
	_sfx["clear_big"] = _arp([523.25, 659.25, 783.99, 1046.5], 0.06, 0.55, "triangle")
	_sfx["clear_huge"] = _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.055, 0.6, "triangle")
	_sfx["combo"] = _arp([783.99, 1046.5], 0.07, 0.45, "sine")
	_sfx["count"] = _tone([880.0], 0.09, 0.5, "sine", 0.003)
	_sfx["go"] = _tone([1174.66], 0.18, 0.6, "triangle", 0.003)
	_sfx["win"] = _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.11, 0.6, "sine")
	_sfx["lose"] = _arp([392.0, 329.63, 261.63], 0.14, 0.5, "sine")
	_sfx["draw"] = _arp([440.0, 440.0], 0.12, 0.5, "sine")

## Multi-frequency tone with pitch glide + decay envelope.
func _tone(freqs: Array, dur: float, vol: float, wave := "sine", attack := 0.005) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / MIX_RATE
		var frac := t / dur
		var f: float = freqs[0] if freqs.size() == 1 else lerpf(freqs[0], freqs[freqs.size() - 1], frac)
		var ph := TAU * f * t
		var s := 0.0
		match wave:
			"sine": s = sin(ph)
			"triangle": s = 2.0 * absf(2.0 * fmod(ph / TAU, 1.0) - 1.0) - 1.0
			"saw": s = 2.0 * fmod(ph / TAU, 1.0) - 1.0
			"square": s = 1.0 if sin(ph) >= 0.0 else -1.0
		var env := minf(t / attack, 1.0) * pow(1.0 - frac, 1.6)
		_put16(data, i, s * env * vol)
	return _wav(data)

func _arp(notes: Array, note_dur: float, vol: float, wave := "sine") -> AudioStreamWAV:
	var total := int(note_dur * notes.size() * MIX_RATE) + int(0.12 * MIX_RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var t := float(i) / MIX_RATE
		var idx := mini(int(t / note_dur), notes.size() - 1)
		var local := t - idx * note_dur
		var ph := TAU * float(notes[idx]) * local
		var s: float
		match wave:
			"triangle": s = 2.0 * absf(2.0 * fmod(ph / TAU, 1.0) - 1.0) - 1.0
			"saw": s = 2.0 * fmod(ph / TAU, 1.0) - 1.0
			_: s = sin(ph)
		var env := minf(local / 0.005, 1.0) * exp(-4.0 * local)
		_put16(data, i, s * env * vol)
	return _wav(data)

func _noise(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var frac := float(i) / n
		_put16(data, i, rng.randf_range(-1.0, 1.0) * (1.0 - frac) * vol)
	return _wav(data)

## Sum a list of WAVs (same mix rate) into one, clamping.
func _blend(parts: Array) -> AudioStreamWAV:
	var longest := 0
	var bufs: Array = []
	for w in parts:
		var d: PackedByteArray = (w as AudioStreamWAV).data
		bufs.append(d)
		longest = maxi(longest, d.size())
	var out := PackedByteArray()
	out.resize(longest)
	for d in bufs:
		for i in range(0, d.size(), 2):
			var a := _get16(d, i)
			var b := _get16(out, i)
			_put16(out, i / 2, float(a + b) / 32767.0 * 0.9)
	return _wav(out)

## Gentle ambient pad loop (~8s): slow I–V–vi–IV-ish chord wash.
func _build_music() -> AudioStreamWAV:
	var dur := 8.0
	var n := int(dur * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var chords := [
		[261.63, 329.63, 392.0, 493.88],   # Cmaj7
		[196.0, 246.94, 293.66, 392.0],    # G
		[220.0, 261.63, 329.63, 440.0],    # Am
		[174.61, 220.0, 261.63, 349.23],   # F
	]
	var seg := dur / chords.size()
	for i in n:
		var t := float(i) / MIX_RATE
		var idx := mini(int(t / seg), chords.size() - 1)
		var chord: Array = chords[idx]
		var local := t - idx * seg
		var fade := minf(local / 0.6, 1.0) * minf((seg - local) / 0.6, 1.0)
		var s := 0.0
		for f in chord:
			s += sin(TAU * float(f) * t) * 0.25
			s += sin(TAU * float(f) * 2.0 * t) * 0.05
		var lfo := 0.85 + 0.15 * sin(TAU * 0.25 * t)
		_put16(data, i, s * fade * lfo * 0.5)
	var wav := _wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w

func _put16(data: PackedByteArray, i: int, sample: float) -> void:
	var v := int(clampf(sample, -1.0, 1.0) * 32767.0)
	data[i * 2] = v & 0xFF
	data[i * 2 + 1] = (v >> 8) & 0xFF

func _get16(data: PackedByteArray, byte_idx: int) -> int:
	var v := data[byte_idx] | (data[byte_idx + 1] << 8)
	return v - 65536 if v >= 32768 else v
