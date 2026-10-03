extends Button

var min_scale: Vector2
var max_scale: Vector2
var targ_scale: Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	min_scale = scale
	max_scale = scale * 1.1
	targ_scale = min_scale


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	scale = scale.lerp(targ_scale, 15 * delta)


func _on_mouse_entered() -> void:
	targ_scale = max_scale


func _on_mouse_exited() -> void:
	targ_scale = min_scale
