extends Control

signal defeated
signal attacked

# Seconds of continuous hovering needed to reach full opacity. CAN EDIT THIS
@export_range(0.1, 30.0) var reveal_time: float = 1.0

# Seconds needed to fade from fully visibile to invisible CAN EDIT THIS
@export_range(0.1, 30.0) var fade_time: float = 2.0

# seconds before anomaly disappears safely CAN EDIT THIS
@export_range(0.1, 60.0) var lifetime: float = 5.0



@onready var spawn_sound: AudioStreamPlayer = $SpawnSound

@onready var visual: TextureRect = $Visual
@onready var jumpscare: AnimatedSprite2D = $"Jumpscare Layer/Jumpscare"
@onready var jumpscare_sound: AudioStreamPlayer = $JumpscareAudio

# WHAT DOES THIS CODE DO
# Starts off with 0 opacity. If the player hovers for too long it will send back an attack signal (jumpscare signal)
# jumpscare and sound is handled in here. Just need to do the sanity calcs


# Initial parameters
var opacity: float = 0.0
var elapsed: float = 0.0
var hovering: bool = false
var resolved : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	spawn_sound.play()
	
	jumpscare.stop()
	jumpscare.hide()
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if resolved:
		return
	if not is_visible_in_tree():
		hovering = false
		return
	
	elapsed += delta
	print("Time left: %.1f seconds" % max(lifetime - elapsed, 0.0))
	if hovering:
		opacity += delta / reveal_time
	else:
		opacity -= delta/fade_time
	
	opacity = clamp(opacity, 0.0, 1.0) #change these parameters for min, max opacity
	_update_visual()
	
	if opacity >= 1.0: #finishes the anamoly if opacity is maxed out
		_finish(true)
	elif elapsed >= lifetime:
		_finish(false)
		


func _update_visual() -> void:
	visual.modulate.a = opacity

	
func _on_mouse_entered() -> void:
	hovering = true



func _on_mouse_exited() -> void:
	hovering = false
	print("Mouse exited - fading")

func _finish(did_attack: bool) -> void:
	if resolved:
		return
		
	resolved = true
	hovering = false
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if did_attack:
		
		visual.hide()
		jumpscare.position = get_viewport_rect().size / 2.0
		jumpscare.frame = 0
		
		# Plays the jumpscare 
		jumpscare.show()
		jumpscare.play("Jumpscare")
		jumpscare_sound.play()
		
		print("ShyOne JUMPSCAARRREEE - reached full opacity")
		
		attacked.emit()
		
		await jumpscare.animation_finished
	else:
		defeated.emit()
		print("PLAYER SUCESS - lifetime expired")


	queue_free()
