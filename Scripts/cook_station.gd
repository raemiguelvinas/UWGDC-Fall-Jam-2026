extends Node2D

enum Ingredient { PATTY, CHEESE, TOMATO, LETTUCE }   # 0, 1, 2, 3

signal burger_finished(ingredients: Array[int], regular_side: float, flipped_side: float)

# nodes
@export_group("Nodes")
@export var patty: Patty
@export var stack: Node2D
@export var grill_spot: Marker2D
@export var side_spot: Marker2D

# buttons
@export_group("Buttons")
@export var start_cook_button: BaseButton
@export var restart_button: BaseButton
@export var finish_cook_button: BaseButton
@export var finish_order_button: BaseButton
@export var reset_burger_button: BaseButton
@export var cheese_button: BaseButton
@export var tomato_button: BaseButton
@export var lettuce_button: BaseButton

# textures
@export_group("Textures")
@export var bottom_bun: Texture2D
@export var top_bun: Texture2D
@export var ingredient_textures: Array[Texture2D]   # slot 0 unused (patty), 1 cheese, 2 tomato, 3 lettuce

# toppings
@export_group("Toppings")
@export var limit_toppings := true
@export var max_toppings := 5

@export var layer_height := 25.0

var toppings: Array[int] = []
var patty_regular := 0.0
var patty_flipped := 0.0
var patty_on_burger := false

func _ready():
	patty.visible = false
	finish_order_button.visible = false

	start_cook_button.pressed.connect(patty_start)
	restart_button.pressed.connect(patty_start)
	finish_cook_button.pressed.connect(patty_finish)
	finish_order_button.pressed.connect(finish_order)
	reset_burger_button.pressed.connect(reset_burger)
	patty.picked.connect(add_patty)

	cheese_button.pressed.connect(add_ingredient.bind(Ingredient.CHEESE))
	tomato_button.pressed.connect(add_ingredient.bind(Ingredient.TOMATO))
	lettuce_button.pressed.connect(add_ingredient.bind(Ingredient.LETTUCE))

	cheese_button.modulate.a = 0
	tomato_button.modulate.a = 0
	lettuce_button.modulate.a = 0

func toppings_full() -> bool:
	return limit_toppings and toppings.size() >= max_toppings

func patty_start():
	patty.start_cooking(grill_spot.global_position)

func patty_finish():
	if not patty.isCooking():
		return
	patty.finishCooking(side_spot.global_position)
	if stack.get_child_count() == 0:
		add_layer(bottom_bun)

func add_ingredient(ingredient: int):
	if stack.get_child_count() == 0 or toppings_full():
		return
	toppings.append(ingredient)
	add_layer(ingredient_textures[ingredient])

func add_patty():
	if toppings_full():
		return
	toppings.append(Ingredient.PATTY)
	patty_regular = patty.regularSide
	patty_flipped = patty.flippedSide
	add_layer(patty.pattySprite.texture)
	patty.putAway()
	patty_on_burger = true
	finish_order_button.visible = true

func add_layer(tex: Texture2D):
	var layer = Sprite2D.new()
	layer.texture = tex
	var y = -stack.get_child_count() * layer_height
	layer.position.y = y - 60
	stack.add_child(layer)
	create_tween().tween_property(layer, "position:y", y, 0.15)

func clear_stack():
	for layer in stack.get_children():
		stack.remove_child(layer)   # remove right away so the count is correct
		layer.queue_free()
	toppings.clear()
	patty_on_burger = false
	finish_order_button.visible = false

func reset_burger():
	# bring the patty back if it was put on the burger
	# (only if it's still hidden, so we don't grab a new patty that's cooking)
	if patty_on_burger and patty.state == Patty.State.IDLE:
		patty.putBack(side_spot.global_position)

	clear_stack()

	# put the bottom bun back if there's a finished patty waiting
	if patty.state == Patty.State.DONE:
		add_layer(bottom_bun)

func finish_order():
	finish_order_button.visible = false
	add_layer(top_bun)
	await get_tree().create_timer(0.4).timeout

	burger_finished.emit(toppings.duplicate(), patty_regular, patty_flipped)
	clear_stack()
