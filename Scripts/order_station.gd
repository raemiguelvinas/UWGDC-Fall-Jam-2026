extends Node2D
class_name OrderStation

# Main starts the ticket when it hears this
signal order_taken(order: OrderData)
# the player clicked the register after a correct order; Main pays out
signal cashed_out

@export_group("Nodes")
@export var customer: Customer
@export var bubble: SpeechBubble
@export var spawn_spot: Marker2D   # off-screen, left
@export var stand_spot: Marker2D   # where the customer waits
@export var exit_spot: Marker2D    # off-screen, right
@export var start_order_button: BaseButton    # sits on top of the register, only visible when a customer is waiting
@export var cash_register_button: BaseButton  # always visible, only enabled when there's a payment to collect

@export_group("Textures")
@export var good_icon: Texture2D
@export var bad_icon: Texture2D

@export_group("Timing")
@export var walk_time := 1.0
@export var speech_time := 3.0    # how long the order bubble stays up
@export var result_time := 1.2    # how long the bad icon stays up
@export var tolerance := 5.0      # how far off each patty side can be

@export var chaChing: AudioStream 
@export var fail: AudioStream 
@export var ding: AudioStream 

var order: OrderData
var last_customer := -1
var awaiting_cash := false


func _ready():
	start_order_button.visible = false
	start_order_button.pressed.connect(_on_start_order_pressed)
	cash_register_button.disabled = true
	cash_register_button.pressed.connect(_on_cash_register_pressed)
	next_customer()


func next_customer():
	var count := customer.custImgClosed.size()
	order = OrderData.makeRandom(count)
	# don't show the same customer twice in a row
	while count > 1 and order.customerIndex == last_customer:
		order.customerIndex = randi_range(0, count - 1)
	last_customer = order.customerIndex

	customer.setup(order.customerIndex)
	customer.global_position = spawn_spot.global_position
	await customer.walkTo(stand_spot.global_position, walk_time)
	start_order_button.visible = true


func _on_start_order_pressed():
	customer.playTalk()
	start_order_button.visible = false
	bubble.showOrder(order.toBBCode())

	await customer.talkFor(speech_time)

	bubble.hideBubble()
	order_taken.emit(order)


# Main calls this when a burger is served. Returns true if the order was right.
func serve_burger(ingredients: Array[int], regular: float, flipped: float) -> bool:
	var ok := order.isCorrect(ingredients, regular, flipped, tolerance)
	_show_result(ok)   # plays out on its own, no await needed
	return ok


func _show_result(ok: bool):
	bubble.showResult(good_icon if ok else bad_icon)
	if ok:
		# customer stays until the player clicks the register
		Audio.play_sfx(ding)
		customer.pop(1.3, 0.3)
		awaiting_cash = true
		cash_register_button.disabled = false
		
		return
	Audio.play_sfx(fail)
	# wrong order: customer leaves by themselves
	await get_tree().create_timer(result_time).timeout
	bubble.hideBubble()
	await _customer_leaves()


func _on_cash_register_pressed():
	if not awaiting_cash:
		return
	awaiting_cash = false
	cash_register_button.disabled = true
	bubble.hideBubble()
	cashed_out.emit()      # Main pays out
	Audio.play_sfx(chaChing)
	_customer_leaves()     # then they leave and the next one walks in


# Main calls this when the ticket's timer runs out
func order_timed_out():
	_customer_leaves()


func _customer_leaves():
	await customer.walkTo(exit_spot.global_position, walk_time)
	next_customer()
