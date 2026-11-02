class_name SoundBank
extends Node
## Töne, die das Spiel selbst ausrechnet (Port von `ton.py`), dazu eine Musikschleife. Keine Audiodateien nötig.
## Ohne laufende App (Tests der reinen Spielszene) bleibt `play()` still.

const MIX_RATE := 22050
const MUSIC_RATE := 11025
const VOICES := 8
const SFX_DB := -6.0
const MUSIC_DB := -12.0
const MUSIC_STEP := 0.125              # Sekunden pro Sechzehntel
const MUSIC_BARS := [[45, 0], [45, 0], [41, 1], [43, 1]]   # Grundton (MIDI), 0 = Moll, 1 = Dur

static var _instance: SoundBank = null

var sounds := {}
var play_counts := {}
var music_stream: AudioStreamWAV = null
var music_enabled := true:
	set(value):
		music_enabled = value
		_apply_music()

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _mix := PackedFloat32Array()

static func play(id: StringName) -> void:
	if _instance != null:
		_instance._play(id)

func _ready() -> void:
	_instance = self
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = SFX_DB
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)
	_build_sounds()
	await get_tree().process_frame   # erst das Menü zeigen, die Musik zu rechnen dauert im Browser einen Moment
	music_stream = _build_music()
	_music.stream = music_stream
	_apply_music()

func _exit_tree() -> void:
	if _instance == self:
		_instance = null

func _play(id: StringName) -> void:
	if not sounds.has(id):
		return
	play_counts[id] = play_counts.get(id, 0) + 1
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = sounds[id]
	voice.play()

func _apply_music() -> void:
	if _music == null or _music.stream == null:
		return
	if music_enabled and not _music.playing:
		_music.play()
	elif not music_enabled:
		_music.stop()

# ------------------------------------------------------------ Geräusche

func _build_sounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	sounds = {
		&"punch": _impact(0.12, 140.0, 60.0, 0.55, 0.7, rng),
		&"kick": _impact(0.16, 110.0, 45.0, 0.5, 0.75, rng),
		&"heavy": _impact(0.24, 95.0, 35.0, 0.65, 0.85, rng),
		&"whoosh": _impact(0.10, 0.0, 0.0, 0.6, 0.18, rng, true),
		&"thud": _impact(0.28, 70.0, 30.0, 0.7, 0.8, rng),
		&"smash": _impact(0.30, 300.0, 120.0, 0.8, 0.6, rng),
		&"throw": _impact(0.14, 0.0, 0.0, 0.6, 0.25, rng, true),
		&"crack": _impact(0.24, 220.0, 60.0, 0.7, 0.8, rng),
		&"grab": _melody([[440.0, 0.04], [660.0, 0.05]], 0.22),
		&"jump": _melody([[330.0, 0.05], [494.0, 0.05]], 0.25),
		&"collect": _melody([[660.0, 0.06], [880.0, 0.06], [1320.0, 0.08]], 0.25),
		&"wave": _melody([[220.0, 0.12], [220.0, 0.12], [330.0, 0.25]], 0.3),
		&"win": _melody([[523.0, 0.12], [659.0, 0.12], [784.0, 0.12], [1047.0, 0.35]], 0.3),
		&"lose": _melody([[330.0, 0.14], [294.0, 0.14], [247.0, 0.14], [196.0, 0.40]], 0.3),
	}

## Schlaggeräusch: Sinus mit fallender Tonhöhe plus Rauschen, beides klingt schnell ab.
func _impact(duration: float, f_start: float, f_end: float, noise: float, volume: float,
		rng: RandomNumberGenerator, airy := false) -> AudioStreamWAV:
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	var last := 0.0
	for i in count:
		var t := float(i) / count
		var envelope := pow(sin(PI * t), 2.0) if airy else pow(1.0 - t, 3.0)
		phase += TAU * lerpf(f_start, f_end, t) / MIX_RATE
		var n := rng.randf_range(-1.0, 1.0)
		if not airy:
			last = last * 0.6 + n * 0.4   # etwas dumpfer
			n = last
		samples[i] = (sin(phase) * (1.0 - noise) + n * noise) * envelope * volume
	return _to_stream(samples, MIX_RATE)

## Kleine Melodie aus Rechteck-Tönen (klingt nach Retro-Konsole).
func _melody(notes: Array, volume: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	for note in notes:
		var count := int(MIX_RATE * float(note[1]))
		for i in count:
			var wave := 1.0 if sin(TAU * float(note[0]) * i / MIX_RATE) > 0.0 else -1.0
			samples.append(wave * volume * sqrt(1.0 - float(i) / count))
	return _to_stream(samples, MIX_RATE)

func _to_stream(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

# ------------------------------------------------------------ Musik

## Vier Takte: Bass in Achteln, Arpeggio in Sechzehnteln, einfacher Schlagzeug-Takt.
func _build_music() -> AudioStreamWAV:
	var step := int(MUSIC_RATE * MUSIC_STEP)
	_mix = PackedFloat32Array()
	_mix.resize(step * 16 * MUSIC_BARS.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for bar in MUSIC_BARS.size():
		var root: int = MUSIC_BARS[bar][0]
		var third := 3 if MUSIC_BARS[bar][1] == 0 else 4
		var arpeggio := [12, 12 + third, 19, 12 + third]
		for s in 16:
			var at := (bar * 16 + s) * step
			if s % 2 == 0:
				_add_square(at, step * 2 - step / 4, _midi(root + (12 if s % 4 == 2 else 0)), 0.2)
			_add_square(at, step, _midi(root + 12 + arpeggio[s % 4]), 0.05)
			if s % 8 == 0 or s == 6 or s == 14:
				_add_kick(at, step * 2)
			if s % 8 == 4:
				_add_noise(at, step * 2, 0.22, rng)
			elif s % 2 == 1:
				_add_noise(at, step / 2, 0.06, rng)
	var stream := _to_stream(_mix, MUSIC_RATE)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = _mix.size()
	_mix = PackedFloat32Array()
	return stream

func _midi(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)

func _add_square(at: int, length: int, freq: float, volume: float) -> void:
	for i in length:
		var wave := 1.0 if fmod(freq * i / MUSIC_RATE, 1.0) < 0.5 else -1.0
		_mix[at + i] += wave * volume * (1.0 - float(i) / length)

func _add_kick(at: int, length: int) -> void:
	var phase := 0.0
	for i in length:
		var t := float(i) / length
		phase += TAU * lerpf(130.0, 45.0, t) / MUSIC_RATE
		_mix[at + i] += sin(phase) * 0.4 * pow(1.0 - t, 2.0)

func _add_noise(at: int, length: int, volume: float, rng: RandomNumberGenerator) -> void:
	for i in length:
		_mix[at + i] += rng.randf_range(-1.0, 1.0) * volume * pow(1.0 - float(i) / length, 2.0)
