extends Area2D
class_name Patty

signal picked

@export var rawTexture: Texture2D
@export var cookedTexture: Texture2D
@export var burntTexture: Texture2D
@export var superBurntTexture: Texture2D

@export var cookSpeed = 4.0
@export var hopHeight := 150.0

@export var pattySprite: Sprite2D

enum State { IDLE, FALLING, COOKING, DONE }

var state := State.IDLE
var regularSide := 0.0
var flippedSide := 0.0
var flipped := false
var busy := false
var tween: Tween



func start_cooking(spot: Vector2):
	if tween: tween.kill()
	regularSide = 0.0
	flippedSide = 0.0
	flipped = false
	busy = false
	pattySprite.position = Vector2.ZERO
	pattySprite.rotation = 0.0
	pattySprite.scale = Vector2.ONE
	pattySprite.texture = rawTexture
	visible = true
	state = State.FALLING

	global_position = spot + Vector2(0, -500)
	tween = create_tween()
	tween.tween_property(self, "global_position", spot, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)   # no bounce
	tween.tween_callback(func(): state = State.COOKING)


func _process(delta: float) -> void:
	if state != State.COOKING:
		return
	if flipped:
		flippedSide += cookSpeed * delta
	else:
		regularSide += cookSpeed * delta
	updateSprite()


func updateSprite():
	var worstSide = max(regularSide, flippedSide)

	if worstSide > 70:
		pattySprite.texture = superBurntTexture
	elif worstSide > 55:
		pattySprite.texture = burntTexture
	elif worstSide > 40:
		pattySprite.texture = cookedTexture
	else:
		pattySprite.texture = rawTexture


func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == State.COOKING:
			flip()
		elif state == State.DONE:
			picked.emit()


func flip():
	if busy: return
	busy = true
	flipped = !flipped

	tween = create_tween().set_parallel(true)

	# spin 180 degrees clockwise over 0.3s
	tween.tween_property(pattySprite, "rotation", pattySprite.rotation + PI, 0.3)

	# hop up for the first half
	tween.tween_property(pattySprite, "position:y", -hopHeight, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# and fall back down for the second half (.from() is the fix)
	tween.tween_property(pattySprite, "position:y", 0.0, 0.15)\
		.from(-hopHeight).set_delay(0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# halfway through the spin, flip vertically
	tween.tween_callback(func(): pattySprite.scale.y *= -1).set_delay(0.15)

	# once everything above is done
	tween.chain().tween_callback(func():
		pattySprite.rotation = fposmod(pattySprite.rotation, TAU)
		busy = false)


func finishCooking(spot: Vector2):
	if tween: tween.kill()
	busy = false
	state = State.DONE
	# snap to a clean pose in case we stopped mid-flip
	pattySprite.position = Vector2.ZERO
	pattySprite.rotation = PI if flipped else 0.0
	pattySprite.scale = Vector2(1, -1) if flipped else Vector2.ONE

	tween = create_tween()
	tween.tween_property(self, "global_position", spot, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func putAway():
	state = State.IDLE
	visible = false


func isCooking() -> bool:
	return state == State.COOKING
	
func putBack(spot: Vector2):
	global_position = spot
	visible = true
	state = State.DONE
