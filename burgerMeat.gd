extends Area2D

signal attack

@export var timeBeforeAttack: float = 10   # in seconds

var dragging: bool = false
var grab_offset: Vector2 = Vector2.ZERO

var dead: bool = false
@export var grillWaitBeforeFadeout: float = 1   # in seconds
@export var deadFadeOutDuration: float = 0.5   # in seconds

@onready var animationNode: AnimatedSprite2D = $AnimatedSprite2D
@onready var attackTimer: Timer = $AttackTimer
@onready var spawnSound: AudioStreamPlayer = $SpawnSound

func die(play_death_animation: bool = true) -> void:
	if dead:
		return
	
	dead = true
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animationNode.play("idle")
	spawnSound.play()
	attackTimer.start(timeBeforeAttack)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not dead and dragging:
		global_position = get_global_mouse_position() + grab_offset
		global_position = global_position.clamp(Vector2.ZERO, get_viewport_rect().size)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		grab_offset = global_position - get_global_mouse_position()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
		if _grill_check():
			die()


func _on_attack_timer_timeout() -> void:
	if not dead:
		attack.emit()
		die(false)
