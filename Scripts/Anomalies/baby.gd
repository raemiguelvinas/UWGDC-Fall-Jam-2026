extends Node2D
# Build-station anomaly. After a delay it plays A, B, C in random order; the player
# repeats it on the keyboard. Wrong key or too slow = jumpscare.
# Scene: Node2D (this script) -> Sprite2D/AnimatedSprite2D,
#        optional AudioStreamPlayer called "SpawnSound" (leave it out for a silent spawn).

# Main hears this and runs its jumpscare() function
signal jumpscare(texture: Texture2D, sound: AudioStream, damage: float)

enum State { WAITING, PLAYING, INPUT, DONE }
const KEYS := {KEY_A: 0, KEY_B: 1, KEY_C: 2}

@export var noteSounds: Array[AudioStream]   # exactly 3: slot 0 = A, 1 = B, 2 = C
@export var scareTexture: Texture2D
@export var scareSound: AudioStream
@export var scareDamage: float = 25.0
@export var startDelay: float = 2.0      # in seconds
@export var noteGap: float = 0.6         # in seconds, between the noises
@export var inputTime: float = 10.0      # in seconds, to repeat the sequence
@export var fadeInDuration: float = 0.6  # in seconds
@export var deadFadeOutDuration: float = 0.3

@onready var spawnSound: AudioStreamPlayer = get_node_or_null("SpawnSound")

var state := State.WAITING
var sequence: Array[int] = []
var typed := 0
var timeLeft := 0.0


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fadeInDuration)
	if spawnSound:
		spawnSound.play()
	_runSequence()


func _runSequence() -> void:
	await get_tree().create_timer(startDelay).timeout
	if state == State.DONE:
		return

	state = State.PLAYING
	sequence = [0, 1, 2]
	sequence.shuffle()   # e.g. [2, 1, 0] = C, B, A
	for n in sequence:
		_playNote(n)
		await get_tree().create_timer(noteGap).timeout
		if state == State.DONE:
			return

	typed = 0
	timeLeft = inputTime
	state = State.INPUT


func _playNote(n: int) -> void:
	if n < noteSounds.size() and noteSounds[n] != null:
		Audio.play_sfx(noteSounds[n])


func _process(delta: float) -> void:
	if state != State.INPUT:
		return
	timeLeft -= delta
	if timeLeft <= 0.0:
		_scare()


func _unhandled_input(event: InputEvent) -> void:
	if state != State.INPUT:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not KEYS.has(event.keycode):
		return   # other keys are ignored

	var n: int = KEYS[event.keycode]
	if n != sequence[typed]:
		_scare()
		return

	_playNote(n)   # feedback
	typed += 1
	if typed >= sequence.size():
		_finish()


func _scare() -> void:
	if state == State.DONE:
		return
	jumpscare.emit(scareTexture, scareSound, scareDamage)
	_finish()


func _finish() -> void:
	state = State.DONE
	var deadTween = create_tween()
	deadTween.tween_property(self, "modulate:a", 0.0, deadFadeOutDuration)
	await deadTween.finished
	queue_free()
