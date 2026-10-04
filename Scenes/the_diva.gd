extends Control

signal defeated
signal attacked

@export_range(1, 50) var clicks_required: int = 8
@export_range(0.1, 30.0) var attention_timeout: float = 3.0
@export_range(0.1, 10.0) var pulse_speed: float = 2.0

@export var idle_texture: Texture2D
@export var clicked_texture: Texture2D
@export var click_display_time: float = 0.15

var click_visual_timer: float = 0.0

@onready var spawn_sound: AudioStreamPlayer = $SpawnSound

@onready var visual: TextureRect = $Visual
@onready var jumpscare: AnimatedSprite2D = $"Jumpscare Layer/Jumpscare"
@onready var jumpscare_sound: AudioStreamPlayer = $JumpscareAudio

var clicks: int = 0
var time_since_click: float = 0.0
var pulse_elapsed: float = 0.0
var resolved: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_randomize_position()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.modulate = Color.WHITE
	
	spawn_sound.play()
	visual.texture = idle_texture
	
	jumpscare.stop()
	jumpscare.hide()

	gui_input.connect(_on_gui_input)

	print("Diva spawned clicks needed: ", clicks_required)

# 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if resolved:
		return
		
	if not is_visible_in_tree():
		return
	
	if click_visual_timer > 0.0:
		click_visual_timer = max(click_visual_timer - delta, 0.0)
		
		if click_visual_timer == 0.0:
			visual.texture = idle_texture
	
	time_since_click += delta
	pulse_elapsed += delta
	
	visual.modulate.a = 0.775 + 0.225 * sin(
		pulse_elapsed * TAU * pulse_speed
	)
	
	if time_since_click >= attention_timeout:
		_finish(true)




func _on_gui_input(event: InputEvent) -> void:
	if resolved:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			
			clicks += 1
			visual.texture = clicked_texture
			click_visual_timer = click_display_time
			time_since_click = 0
			
			print("Diva clicked: %d/%d" % [clicks, clicks_required])
			
			if clicks >= clicks_required:
				_finish(false)

func _finish(did_attack: bool) -> void:
	if resolved:
		return
		
	resolved = true
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
		
		print("DIVA JUMPSCAARRREEE - ignored for too long3")
		
		attacked.emit()
		
		await jumpscare.animation_finished
	else:
		defeated.emit()
		print("Diva defeated you showed enough attention")
	queue_free()
	
func _randomize_position() -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	var margin: float = 20.0

	var max_x: float = max(margin, screen_size.x - size.x - margin)
	var max_y: float = max(margin, screen_size.y - size.y - margin)

	global_position = Vector2(
		randf_range(margin, max_x),
		randf_range(margin, max_y)
	)
