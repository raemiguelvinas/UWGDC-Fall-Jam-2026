extends Node2D

@export var custImgClosed: Array[Texture2D]
@export var custImgOpen: Array[Texture2D]
@export var custSprite: Sprite2D

var custSpriteIndex: int
var burgerOrder: Array[int] # patty, cheese, tomato, lettuce
var time = 0.0

var popTween: Tween


func resetCustomer():
	custSpriteIndex = randi_range(0, custImgClosed.size()-1)
	
	burgerOrder.clear()
	
	var orderSize = randi_range(3, 5) # random number of toppings
	var pattyPlacement = randi_range(0, orderSize - 1) # only 1 patty, pick a spot then fill the rest
												   # with toppings
	for i in orderSize:
		
		if i != pattyPlacement:
			burgerOrder.append(randi_range(1, 3))
		else:
			burgerOrder.append(0)
		

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	resetCustomer()
	custSprite.texture = custImgClosed[custSpriteIndex]
	talkSetTimes(10)
	
	print(burgerOrder)

# update every frame
func _process(delta: float) -> void:
	time += delta
	custSprite.position.y = sin(time * 2.5) * 20 # bobbing motion
	
	
func talk():
	custSprite.texture = custImgOpen[custSpriteIndex]
	pop()
	await get_tree().create_timer(0.08).timeout
	custSprite.texture = custImgClosed[custSpriteIndex]
	await get_tree().create_timer(0.08).timeout
	
func talkSetTimes(amount: int):
	for i in amount:
		await talk()
	
func pop(scale := 1.1, rotation := 0.1, duration := 0.1):
	if popTween:
		popTween.kill()
	
	var popTween = create_tween()
	var scaleVariant = randf_range(scale -0.02, scale + 0.04)
	popTween.tween_property(custSprite, "scale", Vector2(scaleVariant, scaleVariant), duration)
	popTween.parallel().tween_property(custSprite, "rotation", randf_range(-rotation, rotation), duration)
	
	popTween.tween_property(custSprite, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	popTween.parallel().tween_property(custSprite, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
