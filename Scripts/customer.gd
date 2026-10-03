extends Node2D

@export var custImgClosed: Array[Texture2D]
@export var custImgOpen: Array[Texture2D]
@export var custSprite: Sprite2D

var custSpriteIndex: int
var burgerOrder: Array[int] # patty, cheese, tomato, lettuce
# 

func resetCustomer():
	custSpriteIndex = randi_range(0, custImgClosed.size())
	
	burgerOrder.clear()
	
	var orderSize = randi_range(3, 6)
	for i in orderSize:
		
		var ingredient = randi_range(0, 6)
		# double chance of topping compared to patty to avoid
		# like triple patty burgers being super common lol
		if ingredient > 3:
			ingredient = ingredient % 3 + 1
		
		burgerOrder.append(ingredient)
			
		

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	resetCustomer()
	custSpriteIndex = 1
	custSprite.texture = custImgClosed[custSpriteIndex]
	talk(5)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
func talk(duration := 2.0):
	var t = create_tween().set_loops(int(duration / 0.2))
	t.tween_callback(func(): custSprite.texture = custImgOpen[custSpriteIndex])
	t.tween_interval(0.1)
	t.tween_callback(func(): custSprite.texture = custImgClosed[custSpriteIndex])
	t.tween_interval(0.1)
