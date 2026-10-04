extends Node2D

@export_group("Nodes")
@export var order_station: OrderStation
@export var build_station: BuildCookStation
@export var ticket: OrderTicket
@export var awakeness_bar: Range   # just a TextureProgressBar, no script needed
@export var money_label: Label
@export var order_nav_button: BaseButton
@export var build_nav_button: BaseButton
@export var vignette: ColorRect        # any ColorRect; shader is applied in code
@export var damage_flash: ColorRect    # fully red ColorRect, any size
@export var wipe: ColorRect            # black, NOT anchored; sits last in the tree so it draws on top
@export var jumpscare_sprite: Sprite2D   # empty Sprite2D, centered; texture is set per jumpscare

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
@export var awake_per_order := 20.0
@export_range(0.05, 1.0) var sleepy_start := 0.5
@export_range(0.0, 1.0) var vignette_max := 0.85

@export_group("Anomalies")
@export var anomaly_entries: Array[AnomalyEntry]
@export var order_anomaly_spot: Marker2D   # a Marker2D inside the order station
@export var build_anomaly_spot: Marker2D   # a Marker2D inside the build station
@export var random_spawn_margin := 150.0   # keeps random spawns this far from the screen edges
@export var random_spawn_area := Rect2()   # optional: set a size to use this exact area instead (screen coords)
@export var first_spawn_delay := 10.0
@export var spawn_cooldown_min := 15.0
@export var spawn_cooldown_max := 30.0

@export_group("Damage")
@export_range(0.0, 1.0) var flash_start_alpha := 0.7
@export var flash_time := 0.6

@export_group("Jumpscare")
@export_range(0.01, 1.0) var jumpscare_start_size := 0.05   # 1.0 = texture just covers the screen
@export_range(0.5, 3.0) var jumpscare_end_size := 1.2
@export var jumpscare_grow_time := 0.25
@export var jumpscare_hold_time := 0.6   # how long it stays up after hitting full size

var money_cents := -100   # starts at -$1 lol
var stations: Dictionary
var current := "order"
var transitioning := false
var money_tween: Tween
var pending_time_fraction := 0.0   # tip fraction waiting for the cash register click

var awakeness := 0.0
var game_over := false

var active_anomalies: Dictionary = {}   # type_id -> how many are alive
var spawn_timer := 0.0
var flash_tween: Tween
var jumpscare_busy := false


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
	_setup_flash()
	_setup_jumpscare()
	Audio.reset_effects()   # the autoload survives scene changes, so start clean

	awakeness = max_awakeness
	awakeness_bar.max_value = max_awakeness
	awakeness_bar.step = 0.1
	_update_awakeness()

	spawn_timer = first_spawn_delay
	update_nav()
	update_money(false)


func _process(delta: float) -> void:
	if game_over:
		return
	add_awakeness(-awake_drain_per_second * delta)
	if game_over:
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = randf_range(spawn_cooldown_min, spawn_cooldown_max)
		spawn_anomaly()


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


# --- damage ---

func _setup_flash():
	damage_flash.set_anchors_preset(Control.PRESET_TOP_LEFT)
	damage_flash.position = Vector2.ZERO
	damage_flash.size = get_viewport().get_visible_rect().size
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash.z_as_relative = false
	damage_flash.z_index = 95   # above the vignette, below the wipe
	damage_flash.modulate.a = 0.0


# Red flash + lose awakeness. Call from anywhere: damage(15.0)
func damage(amount: float):
	if game_over:
		return
	add_awakeness(-amount)
	if game_over:
		return   # that hit killed you, lose scene is loading

	if flash_tween: flash_tween.kill()
	damage_flash.modulate.a = flash_start_alpha
	flash_tween = create_tween()
	flash_tween.tween_property(damage_flash, "modulate:a", 0.0, flash_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# --- jumpscare ---

func _setup_jumpscare():
	jumpscare_sprite.visible = false
	jumpscare_sprite.z_as_relative = false
	jumpscare_sprite.z_index = 98   # above the flash, below the wipe


# Shows `texture` small in the middle of the screen, blows it up fast while `sound`
# plays, then deals `dmg` when it hits full size. Works from either station.
#   jumpscare(my_texture, my_sound, 25.0)
func jumpscare(texture: Texture2D, sound: AudioStream, dmg: float):
	if game_over:
		return
	if sound:
		Audio.play_sfx(sound)
	# no texture, or one is already playing: skip the visuals, still deal the damage
	if texture == null or jumpscare_busy:
		damage(dmg)
		return

	jumpscare_busy = true
	var vp := get_viewport().get_visible_rect().size
	var tex_size := texture.get_size()
	var cover := maxf(vp.x / tex_size.x, vp.y / tex_size.y)   # scale where the texture fills the screen

	jumpscare_sprite.texture = texture
	jumpscare_sprite.global_position = vp / 2.0
	jumpscare_sprite.scale = Vector2.ONE * cover * jumpscare_start_size
	jumpscare_sprite.visible = true

	var t := create_tween()
	t.tween_property(jumpscare_sprite, "scale", Vector2.ONE * cover * jumpscare_end_size, jumpscare_grow_time)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)   # slow start, explosive finish
	t.tween_callback(damage.bind(dmg))
	t.tween_interval(jumpscare_hold_time)
	t.tween_callback(_end_jumpscare)


func _end_jumpscare():
	jumpscare_sprite.visible = false
	jumpscare_busy = false


# --- anomalies ---

func spawn_anomaly():
	# everything that isn't blocked by a "unique" one already being alive
	var pool: Array[AnomalyEntry] = []
	var total := 0.0
	for e in anomaly_entries:
		if e == null or e.scene == null:
			continue
		if e.unique and active_anomalies.get(e.type_id, 0) > 0:
			continue
		pool.append(e)
		total += e.weight
	if pool.is_empty():
		return   # everything is blocked, nothing spawns this cycle

	# weighted random pick
	var roll := randf() * total
	var chosen: AnomalyEntry = pool[0]
	for e in pool:
		roll -= e.weight
		if roll <= 0.0:
			chosen = e
			break
	_place_anomaly(chosen)


func _place_anomaly(entry: AnomalyEntry):
	var inst := entry.scene.instantiate()
	var a := inst as Node2D
	if a == null:
		push_warning("Anomaly '%s': scene root must be a Node2D (Area2D, Sprite2D...)" % entry.type_id)
		inst.free()
		return

	var station: Node2D = stations[entry.station]

	# where it goes: a random spot on screen, or the station's marker
	var world_pos: Vector2
	if entry.random_position:
		world_pos = _random_screen_point()
	else:
		var spot := order_anomaly_spot if entry.station == "order" else build_anomaly_spot
		world_pos = spot.global_position

	# position BEFORE add_child so the anomaly's own _ready already sees the right spot
	a.position = station.to_local(world_pos)
	station.add_child(a)   # child of the station, so it hides with it

	active_anomalies[entry.type_id] = active_anomalies.get(entry.type_id, 0) + 1
	a.tree_exited.connect(_on_anomaly_gone.bind(entry.type_id), CONNECT_ONE_SHOT)

	# optional hooks: a scene only needs the signals it actually uses
	if a.has_signal("attack"):                # attack()
		a.connect("attack", damage.bind(entry.attack_damage))
	if a.has_signal("jumpscare"):             # jumpscare(texture, sound, damage)
		a.connect("jumpscare", jumpscare)


func _random_screen_point() -> Vector2:
	var area := random_spawn_area
	if area.size == Vector2.ZERO:
		var vp := get_viewport().get_visible_rect().size
		area = Rect2(Vector2.ONE * random_spawn_margin, vp - Vector2.ONE * random_spawn_margin * 2.0)
	return Vector2(
		randf_range(area.position.x, area.end.x),
		randf_range(area.position.y, area.end.y))


func _on_anomaly_gone(type_id: String):
	active_anomalies[type_id] = maxi(0, active_anomalies.get(type_id, 0) - 1)


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
