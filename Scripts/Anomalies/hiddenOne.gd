extends Area2D

@export var initialOpacity: float = 0.0
@export var finalOpacity: float = 0.9
@export var hoverOpacity: float = 0.3
@export var duration: int = 30 # in seconds

var opacityFromTween: float
var hovered: bool = false

@export var breathingCooldownMin: float = 1
@export var breathingCooldownMax: float = 5

@onready var animationNode: AnimatedSprite2D = $AnimatedSprite2D
@onready var breathingTimer: Timer = $BreathingTimer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	modulate.a = initialOpacity
	opacityFromTween = initialOpacity
	var opacityTween = create_tween()
	opacityTween.tween_property(self, "opacityFromTween", finalOpacity, duration)
	
	# TO-DO: Play sound when after spawn in
	
	start_breathing_cooldown()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if hovered:
		modulate.a = min(opacityFromTween + hoverOpacity, finalOpacity) if modulate.a > hoverOpacity else hoverOpacity
	else:
		modulate.a = opacityFromTween
	
	# TO-DO: Should die when clicked on (breathing animation cant happen)
	# TO-DO: Attacks if left alone for too long (does automatically die, or continues attacking after cooldown)?


func _on_mouse_entered() -> void:
	hovered = true


func _on_mouse_exited() -> void:
	hovered = false


func start_breathing_cooldown() -> void:
	breathingTimer.start(randf_range(breathingCooldownMin, breathingCooldownMax))

func _on_breathing_timer_timeout() -> void:
	animationNode.play("breath")


func _on_animated_sprite_2d_animation_finished() -> void:
	if animationNode.animation == &"breath":
		animationNode.frame = 0
		start_breathing_cooldown()
