extends Node2D

@export_group("Nodes")
@export var order_station: OrderStation
@export var build_station: BuildCookStation
@export var ticket: OrderTicket
@export var money_label: Label
@export var order_nav_button: BaseButton
@export var build_nav_button: BaseButton
@export var wipe: ColorRect   # black, NOT anchored; sits last in the tree so it draws on top

@export_group("Game")
@export var win_scene: PackedScene
@export var order_time := 40.0
@export var base_pay := 70.0
@export var max_tip := 15.0
@export_range(0.0, 0.95) var tip_drain_start := 0.3   # tip starts shrinking after this much time is gone
@export var win_money := 1000.0
@export var wipe_time := 0.5   # seconds for EACH half (slide in, then slide out)

var money_cents := -100   # starts at -$1 lol
var stations: Dictionary
var current := "order"
var transitioning := false
var money_tween: Tween


func _ready():
	stations = {"order": order_station, "build": build_station}
	for key in stations:
		stations[key].visible = (key == current)

	order_station.order_taken.connect(_on_order_taken)
	build_station.burger_finished.connect(_on_burger_finished)
	ticket.time_up.connect(_on_time_up)
	order_nav_button.pressed.connect(go_to.bind("order"))
	build_nav_button.pressed.connect(go_to.bind("build"))

	# park the wipe off-screen to the left
	# (top-left anchors so the layout system can't fight the slide)
	wipe.set_anchors_preset(Control.PRESET_TOP_LEFT)
	wipe.position = Vector2.ZERO
	wipe.size = get_viewport().get_visible_rect().size
	wipe.modulate.a = 0.0
	wipe.visible = false
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wipe.z_as_relative = false
	wipe.z_index = 100
	# no z_index stuff needed anymore

	update_nav()
	update_money(false)

# --- extra ---
func update_nav():
	order_nav_button.disabled = (current == "order")
	build_nav_button.disabled = (current == "build")

# --- order flow ---

func _on_order_taken(order: OrderData):
	ticket.start(order, order_time)
	build_station.can_serve = true


func _on_time_up():
	build_station.can_serve = false
	order_station.order_timed_out()


func _on_burger_finished(ingredients: Array[int], regular: float, flipped: float):
	if not ticket.active:
		return
	var time_fraction := ticket.fraction()   # grab this before stopping the ticket
	ticket.stop()
	build_station.can_serve = false

	await go_to("order")

	if order_station.serve_burger(ingredients, regular, flipped):
		award(time_fraction)


# --- money ---

func award(time_fraction: float):
	# full tip until 30% of the time is gone, then it drains to $0
	var tip_fraction := clampf(time_fraction / (1.0 - tip_drain_start), 0.0, 1.0)
	var tip_cents := roundi(max_tip * 100.0 * tip_fraction)
	money_cents += roundi(base_pay * 100.0) + tip_cents
	update_money(true)

	if money_cents >= roundi(win_money * 100.0):
		get_tree().change_scene_to_packed(win_scene)


func money_text(cents: int) -> String:
	var neg := "-" if cents < 0 else ""
	return "%s$%.2f" % [neg, absi(cents) / 100.0]


func update_money(do_pop: bool):
	money_label.text = money_text(money_cents)
	if not do_pop:
		return
	money_label.pivot_offset = money_label.size / 2
	if money_tween: money_tween.kill()
	money_label.scale = Vector2.ONE * 1.4
	money_label.rotation = randf_range(-0.15, 0.15)
	money_tween = create_tween().set_parallel(true)
	money_tween.tween_property(money_label, "scale", Vector2.ONE, 0.5)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	money_tween.tween_property(money_label, "rotation", 0.0, 0.5)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --- screen transition ---

func go_to(station_name: String):
	if transitioning or station_name == current:
		return
	transitioning = true
	wipe.mouse_filter = Control.MOUSE_FILTER_STOP   # block clicks mid-fade
	wipe.modulate.a = 0.0
	wipe.visible = true

	# fade to black
	var t := create_tween()
	t.tween_property(wipe, "modulate:a", 1.0, wipe_time)
	await t.finished

	for key in stations:
		stations[key].visible = (key == station_name)
	current = station_name
	update_nav()

	# fade back in
	t = create_tween()
	t.tween_property(wipe, "modulate:a", 0.0, wipe_time)
	await t.finished

	wipe.visible = false
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transitioning = false
