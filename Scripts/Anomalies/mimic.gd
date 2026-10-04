extends Area2D
# Order-station anomaly. Makes noises on a cooldown (each one hurts), click it to beat it.
# Scene: Area2D (this script) -> CollisionShape2D, Sprite2D/AnimatedSprite2D,
#        optional AudioStreamPlayer called "SpawnSound" (leave it out for a silent spawn).

signal attack   # emitted every time it makes a noise; Main deals the damage

@export var sounds: Array[AudioStream]
@export var beatenSound: AudioStream
@export var timeBetweenNoisesMin: float = 3   # in seconds
@export var timeBetweenNoisesMax: float = 6   # in seconds
@export var fadeInDuration: float = 0.6       # in seconds
@export var deadFadeOutDuration: float = 0.3  # in seconds

@onready var spawnSound: AudioStreamPlayer = get_node_or_null("SpawnSound")

var dead: bool = false
var timer: float = 0.0


func _ready() -> void:
	input_event.connect(_on_input_event)
	timer = randf_range(timeBetweenNoisesMin, timeBetweenNoisesMax)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fadeInDuration)
	if spawnSound:
		spawnSound.play()


func _process(delta: float) -> void:
	if dead:
		return
	timer -= delta
	if timer <= 0.0:
		timer = randf_range(timeBetweenNoisesMin, timeBetweenNoisesMax)
		_make_noise()


func _make_noise() -> void:
	var valid: Array[AudioStream] = []
	for s in sounds:
		if s != null:
			valid.append(s)
	if not valid.is_empty():
		Audio.play_sfx(valid.pick_random(), 0.05)
	attack.emit()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if dead or not is_visible_in_tree():   # a hidden station's mimic must not react to clicks
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	if beatenSound:
		Audio.play_sfx(beatenSound)
	var deadTween = create_tween()
	deadTween.tween_property(self, "modulate:a", 0.0, deadFadeOutDuration)
	await deadTween.finished
	queue_free()
