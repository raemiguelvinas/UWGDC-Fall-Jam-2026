extends Area2D
# Build-station anomaly. Drag it onto the grill before the timer runs out, or it attacks.
# Scene: Area2D (this script) -> CollisionShape2D, AnimatedSprite2D ("idle" + "dead"),
#        Timer called "AttackTimer", optional AudioStreamPlayer called "SpawnSound".

signal attack   # plain hit: Main deals the entry's attack_damage
signal jumpscare(texture: Texture2D, sound: AudioStream, damage: float)   # Main runs its jumpscare()

@export_group("Jumpscare")
@export var scareTexture: Texture2D   # leave empty for a plain hit (no jumpscare)
@export var scareSound: AudioStream
@export var scareDamage: float = 20.0

@export_group("Timing")
@export var timeBeforeAttack: float = 10   # in seconds
@export var fadeInDuration: float = 0.5   # in seconds
@export var grillWaitBeforeFadeout: float = 1   # in seconds
@export var deadFadeOutDuration: float = 0.5   # in seconds

var dragging: bool = false
var grab_offset: Vector2 = Vector2.ZERO
var dead: bool = false

@onready var animationNode: AnimatedSprite2D = $AnimatedSprite2D
@onready var attackTimer: Timer = $AttackTimer
@onready var spawnSound: AudioStreamPlayer = get_node_or_null("SpawnSound")   # optional


func _ready() -> void:
	_connect_signals()
	animationNode.play("idle")

	# fade in
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fadeInDuration)

	# spawn noise (skipped if the scene has no SpawnSound node)
	if spawnSound:
		if AudioServer.get_bus_index("SFX") != -1:
			spawnSound.bus = "SFX"
		spawnSound.play()

	attackTimer.start(timeBeforeAttack)


# connects in code, so it works whether or not you connected them in the editor
func _connect_signals() -> void:
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)
	if not attackTimer.timeout.is_connected(_on_attack_timer_timeout):
		attackTimer.timeout.connect(_on_attack_timer_timeout)


func die(play_death_animation: bool = true) -> void:
	if dead:
		return

	dead = true
	dragging = false
	attackTimer.stop()
	if play_death_animation:
		animationNode.play("dead")
		await get_tree().create_timer(grillWaitBeforeFadeout).timeout
	var deadTween = create_tween()
	deadTween.tween_property(self, "modulate:a", 0.0, deadFadeOutDuration)
	await deadTween.finished
	queue_free()


func _grill_check() -> bool:
	for area in get_overlapping_areas():
		if area.is_in_group(&"Grill_Zone"):
			return true
	return false


func _process(_delta: float) -> void:
	if dead or not dragging:
		return
	if not is_visible_in_tree():   # station got hidden mid-drag
		dragging = false
		return
	global_position = get_global_mouse_position() + grab_offset
	global_position = global_position.clamp(Vector2.ZERO, get_viewport_rect().size)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# a hidden station's patty must not react to clicks
	if dead or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		grab_offset = global_position - get_global_mouse_position()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# only react if THIS patty was being dragged, otherwise any click
		# anywhere would kill it while it sits on the grill
		if not dragging:
			return
		dragging = false
		if not dead and _grill_check():
			die()


func _on_attack_timer_timeout() -> void:
	if not dead:
		_attack()
		die(false)


# jumpscare if a texture is set, otherwise a plain hit (never both, so no double damage)
func _attack() -> void:
	if scareTexture != null:
		jumpscare.emit(scareTexture, scareSound, scareDamage)
	else:
		attack.emit()
