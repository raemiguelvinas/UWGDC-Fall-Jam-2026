extends Area2D

@export var initialOpacity: float = 0.0
@export var finalOpacity: float = 0.9
@export var hoverOpacity: float = 0.3
@export var duration: int = 30 # in seconds

var opacityTween: Tween
var opacityFromTween: float
var hovered: bool = false

@export var breathingCooldownMin: float = 1
@export var breathingCooldownMax: float = 5

@onready var animationNode: AnimatedSprite2D = $AnimatedSprite2D
@onready var breathingTimer: Timer = $BreathingTimer

var dead: bool = false
@export var deadFadeOutDuration: int = 1 # in seconds

func start_breathing_cooldown() -> void:
	breathingTimer.start(randf_range(breathingCooldownMin, breathingCooldownMax))

func die() -> void:
	dead = true
	opacityTween.kill()
	animationNode.play("dead")
	var deadTween = create_tween()
	deadTween.tween_property(self, "modulate:a", 0, deadFadeOutDuration)
	await deadTween.finished
	queue_free()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	modulate.a = initialOpacity
	opacityFromTween = initialOpacity
	opacityTween = create_tween()
	opacityTween.tween_property(self, "opacityFromTween", finalOpacity, duration)
	
	# TO-DO: Play sound when after spawn in
	
	start_breathing_cooldown()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not dead:
		if hovered:
			modulate.a = min(opacityFromTween + hoverOpacity, finalOpacity) if modulate.a > hoverOpacity else hoverOpacity
		else:
			modulate.a = opacityFromTween
	
	# TO-DO: Attacks if left alone for too long (does automatically die, or continues attacking after cooldown)?
	# TO-DO Chnage breathing to looping animation


func _on_mouse_entered() -> void:
	hovered = true


func _on_mouse_exited() -> void:
	hovered = false

func _on_breathing_timer_timeout() -> void:
	if not dead:
		animationNode.play("breath")


func _on_animated_sprite_2d_animation_finished() -> void:
	if animationNode.animation == &"breath":
		animationNode.frame = 0
		start_breathing_cooldown()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if dead:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		die()
