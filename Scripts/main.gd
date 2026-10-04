extends Node2D

@export_group("Nodes")
@export var order_station: OrderStation
@export var build_station: BuildCookStation
@export var ticket: OrderTicket
@export var awakeness_bar: Range   # just a TextureProgressBar, no script needed
@export var money_label: Label
@export var order_nav_button: BaseButton
@export var build_nav_button: BaseButton
@export var vignette: ColorRect   # any ColorRect; shader is applied in code
@export var wipe: ColorRect       # black, NOT anchored; sits last in the tree so it draws on top

@export_group("Game")
@export var win_scene: PackedScene
@export var lose_scene: PackedScene
@export var order_time := 40.0
@export var base_pay := 70.0
@export var max_tip := 15.0
@export_range(0.0, 0.95) var tip_drain_start := 0.3
@export var win_money := 1000.0
@export var wipe_time := 0.25   # seconds for EACH half (fade out, then fade in)

@export_group("Awakeness")
@export var max_awakeness := 100.0
@export var awake_drain_per_second := 1.0
@export var awake_per_order := 20.0                          # refill for a correct order
@export_range(0.05, 1.0) var sleepy_start := 0.5             # effects begin below this fraction
@export_range(0.0, 1.0) var vignette_max := 0.85

@export_group("Sound")
@export var cha_ching: AudioStream
@export var bgMusic: AudioStream


var money_cents := -100   # starts at -$1 lol
var stations: Dictionary
var current := "order"
var transitioning := false
var money_tween: Tween
var pending_time_fraction := 0.0   # tip fraction waiting for the cash register click

var awakeness := 0.0
var game_over := false


func _ready():
	
	
	stations = {"order": order_station, "build": build_station}
	for key in stations:
		stations[key].visible = (key == current)

	order_station.order_taken.connect(_on_order_taken)
	order_station.cashed_out.connect(_on_cashed_out)
	build_station.burger_finished.connect(_on_burger_finished)
	ticket.time_up.connect(_on_time_up)
	order_nav_button.pressed.connect(go_to.bind("order"))
	build_nav_button.pressed.connect(go_to.bind("build"))

	# full-screen black rect, fully transparent until needed
	wipe.set_anchors_preset(Control.PRESET_TOP_LEFT)
	wipe.position = Vector2.ZERO
	wipe.size = get_viewport().get_visible_rect().size
	wipe.modulate.a = 0.0
	wipe.visible = false
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wipe.z_as_relative = false
	wipe.z_index = 100

	_setup_vignette()
	Audio.reset_effects()   # the autoload survives scene changes, so start clean
	Audio.play_music(bgMusic)

	awakeness = max_awakeness
	awakeness_bar.max_value = max_awakeness
	awakeness_bar.step = 0.1
	_update_awakeness()

	update_nav()
	update_money(false)
	
	


func _process(delta: float) -> void:
	if game_over:
		return
	add_awakeness(-awake_drain_per_second * delta)


# --- awakeness ---

func add_awakeness(amount: float):
	if game_over:
		return
	awakeness = clampf(awakeness + amount, 0.0, max_awakeness)
	_update_awakeness()
	if awakeness <= 0.0:
		_lose()


func _update_awakeness():
	awakeness_bar.value = awakeness

	# 0 while above sleepy_start, rising to 1 at zero awakeness
	var fraction := awakeness / max_awakeness
	var sleepy := clampf((sleepy_start - fraction) / sleepy_start, 0.0, 1.0)
	Audio.muffle = sleepy   # reverb + low pass + quieter, all at once

	vignette.visible = sleepy > 0.0
	(vignette.material as ShaderMaterial).set_shader_parameter("strength", sleepy * vignette_max)


func _lose():
	game_over = true
	Audio.reset_effects()
	get_tree().change_scene_to_packed(lose_scene)


func _setup_vignette():
	vignette.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vignette.position = Vector2.ZERO
	vignette.size = get_viewport().get_visible_rect().size
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.z_as_relative = false
	vignette.z_index = 90   # above the game, below the wipe

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	float d = length(UV - vec2(0.5));
	float v = smoothstep(0.2, 0.75, d);
	COLOR = vec4(0.0, 0.0, 0.0, v * strength);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	vignette.material = mat
	vignette.visible = false


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
		# correct: awakeness now, money when the register is clicked
		pending_time_fraction = time_fraction
		add_awakeness(awake_per_order)


# the player clicked the cash register after a correct order
func _on_cashed_out():
	award(pending_time_fraction)


# --- money ---

func award(time_fraction: float):
	# full tip until 30% of the time is gone, then it drains to $0
	var tip_fraction := clampf(time_fraction / (1.0 - tip_drain_start), 0.0, 1.0)
	var tip_cents := roundi(max_tip * 100.0 * tip_fraction)
	money_cents += roundi(base_pay * 100.0) + tip_cents
	update_money(true)
	

	if money_cents >= roundi(win_money * 100.0):
		game_over = true   # stops the drain so you can't lose on the way to the win screen
		Audio.reset_effects()
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


# --- nav ---

func update_nav():
	order_nav_button.disabled = (current == "order")
	build_nav_button.disabled = (current == "build")


# --- screen transition: fade to black, swap stations, fade back ---

func go_to(station_name: String):
	if transitioning or station_name == current:
		return
	transitioning = true
	wipe.mouse_filter = Control.MOUSE_FILTER_STOP   # block clicks mid-fade
	wipe.modulate.a = 0.0
	wipe.visible = true

	var t := create_tween()
	t.tween_property(wipe, "modulate:a", 1.0, wipe_time)
	await t.finished

	for key in stations:
		stations[key].visible = (key == station_name)
	current = station_name
	update_nav()

	t = create_tween()
	t.tween_property(wipe, "modulate:a", 0.0, wipe_time)
	await t.finished

	wipe.visible = false
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transitioning = false
