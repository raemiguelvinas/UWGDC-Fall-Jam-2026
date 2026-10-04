extends Control

signal defeated
signal attacked

# Seconds of continuous hovering needed to reach full opacity.
@export_range(0.1, 30.0) var reveal_time: float = 3.0

# Seconds needed to fade from fully visibile to invisible
@export_range(0.1, 30.0) var fade_time: float = 2.0

# seconds before anomaly disappears safely
@export_range(0.1, 60.0) var lifetime: float = 10.0

@onready var visual: ColorRect = $ColorRect

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
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if resolved:
		return
	if not is_visible_in_tree():
		hovering = false
		return
	
	elapsed += delta
	if hovering:
		opacity += delta / reveal_time
	else:
		opacity -= delta/fade_time
	
	opacity = clamp(opacity, 0.0, 1.0)
	_update_visual()
	
	if opacity >= 1.0:
		_finish(true)
	elif elapsed >= lifetime:
		_finish(false)
		


func _update_visual() -> void:
	visual.modulate.a = opacity

	
func _on_mouse_entered() -> void:
	hovering = true



func _on_mouse_exited() -> void:
	hovering = false

func _finish(did_attack: bool) -> void:
	if resolved:
		return
		
	resolved = true
	set_process(false)
	
	if did_attack:
		attacked.emit()
	else:
		defeated.emit()
		
	queue_free()
