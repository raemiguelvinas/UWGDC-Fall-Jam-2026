extends Area2D
class_name Patty

signal picked

@export var rawTexture: Texture2D
@export var cookedTexture: Texture2D
@export var burntTexture: Texture2D
@export var superBurntTexture: Texture2D

@export var cookSpeed := 4.0
@export var hopHeight := 150.0

@export var pattySprite: Sprite2D
@export var progress: PattyProgress

enum State { IDLE, FALLING, COOKING, DONE }

var state := State.IDLE
var regularSide := 0.0
var flippedSide := 0.0
var flipped := false
var busy := false
var tween: Tween


func _ready() -> void:
	if progress == null:
		push_warning("Patty: the 'progress' slot is empty, so the cooking UI will never update.")


func start_cooking(spot: Vector2):
	if tween: tween.kill()
	regularSide = 0.0
	flippedSide = 0.0
	flipped = false
	busy = false
	pattySprite.position = Vector2.ZERO
	pattySprite.rotation = 0.0
	pattySprite.scale = Vector2.ONE
	updateSprite()
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
	var amount := cookSpeed * delta
	if flipped:
		flippedSide = minf(flippedSide + amount, 100.0)
	else:
		regularSide = minf(regularSide + amount, 100.0)
	updateSprite()


func updateSprite():
	var worstSide := maxf(regularSide, flippedSide)

	if worstSide > 70:
		pattySprite.texture = superBurntTexture
	elif worstSide > 55:
		pattySprite.texture = burntTexture
	elif worstSide > 40:
		pattySprite.texture = cookedTexture
	else:
		pattySprite.texture = rawTexture

	if progress:
		progress.showValues(regularSide, flippedSide, flipped)


func _input_event(viewport, event, shape_idx):
	# a hidden station's patty must not react to clicks
	if not is_visible_in_tree():
		return
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
	# and fall back down for the second half (.from() is what makes it work)
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


func putBack(spot: Vector2):
	if tween: tween.kill()
	global_position = spot
	pattySprite.position = Vector2.ZERO
	visible = true
	state = State.DONE
	updateSprite()


func isCooking() -> bool:
	return state == State.COOKING
