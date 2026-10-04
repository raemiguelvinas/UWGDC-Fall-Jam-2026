extends Node2D
class_name Customer

@export var custImgClosed: Array[Texture2D]
@export var custImgOpen: Array[Texture2D]   # leave a slot empty for customers who don't talk
@export var custSprite: Sprite2D

var custSpriteIndex := 0
var time := 0.0
var walking := false

var popTween: Tween
var walkTween: Tween


func _process(delta: float) -> void:
	# bobbing motion: faster while walking
	time += delta * (9.0 if walking else 2.5)
	custSprite.position.y = sin(time) * 20


# called by the order station for each new customer
func setup(index: int):
	custSpriteIndex = index
	custSprite.texture = custImgClosed[index]
	custSprite.scale = Vector2.ONE
	custSprite.rotation = 0.0


func walkTo(target: Vector2, duration := 1.0):
	if walkTween:
		walkTween.kill()
	walking = true
	walkTween = create_tween()
	walkTween.tween_property(self, "global_position", target, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await walkTween.finished
	walking = false


func talk():
	# customers without a talking sprite just pop
	var hasOpen := custSpriteIndex < custImgOpen.size() and custImgOpen[custSpriteIndex] != null
	if hasOpen:
		custSprite.texture = custImgOpen[custSpriteIndex]
	pop()
	await get_tree().create_timer(0.08).timeout
	custSprite.texture = custImgClosed[custSpriteIndex]
	await get_tree().create_timer(0.08).timeout


func talkSetTimes(amount: int):
	for i in amount:
		await talk()


# talk for roughly this many seconds
func talkFor(seconds: float):
	await talkSetTimes(int(seconds / 0.16))


func pop(scaleAmount := 1.1, rotAmount := 0.1, duration := 0.1):
	if popTween:
		popTween.kill()

	popTween = create_tween()
	var scaleVariant := randf_range(scaleAmount - 0.02, scaleAmount + 0.04)
	popTween.tween_property(custSprite, "scale", Vector2(scaleVariant, scaleVariant), duration)
	popTween.parallel().tween_property(custSprite, "rotation", randf_range(-rotAmount, rotAmount), duration)

	popTween.tween_property(custSprite, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	popTween.parallel().tween_property(custSprite, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
