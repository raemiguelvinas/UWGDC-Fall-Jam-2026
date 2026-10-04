extends Area2D

signal attack

@export var idleOpacity: float = 0.2
@export var hoverOpacity: float = 0.5

var hovered: bool = false

@export var timeBeforeFirstAttack: float = 10   # in seconds
@export var repeatedAttacks: bool = false
@export var repeatedAttackCooldown: float = 5   # in seconds

@onready var animationNode: AnimatedSprite2D = $AnimatedSprite2D
@onready var spawnSound: AudioStreamPlayer = $SpawnSound
@onready var attackTimer: Timer = $AttackTimer

var dead: bool = false
@export var deadFadeOutDuration: float = 0.5 # in seconds

func die(play_death_animation: bool = true) -> void:
	if dead:
		return
	
	dead = true
	attackTimer.stop()
	if play_death_animation:
		animationNode.play("dead")
	var deadTween = create_tween()
	deadTween.tween_property(self, "modulate:a", 0.0, deadFadeOutDuration)
	await deadTween.finished
	queue_free()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	modulate.a = idleOpacity
	animationNode.play("breath")
	spawnSound.play()
	
	attackTimer.start(timeBeforeFirstAttack)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not dead:
		if hovered:
			modulate.a = hoverOpacity
		else:
			modulate.a = idleOpacity


func _on_mouse_entered() -> void:
	hovered = true


func _on_mouse_exited() -> void:
	hovered = false


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if dead:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		die()


func _on_attack_timer_timeout() -> void:
	if not dead:
		attack.emit()
		if repeatedAttacks:
			attackTimer.start(repeatedAttackCooldown)
		else:
			die(false)
