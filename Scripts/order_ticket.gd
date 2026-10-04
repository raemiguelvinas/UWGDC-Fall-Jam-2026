class_name OrderTicket
extends Control
# Child of Main, anchored to the top-right. Visible from both stations.

signal time_up

@export var orderLabel: RichTextLabel
@export var wheel: Range   # a TextureProgressBar: Under = background circle, Progress = fill circle

var duration := 40.0
var timeLeft := 0.0
var active := false


func _ready() -> void:
	orderLabel.bbcode_enabled = true
	wheel.step = 0.1
	visible = false


func start(order: OrderData, seconds: float):
	duration = seconds
	timeLeft = seconds
	orderLabel.text = order.toBBCode()
	active = true
	visible = true
	updateWheel()


func stop():
	active = false
	visible = false


# 1.0 = full time left, 0.0 = out of time
func fraction() -> float:
	return clampf(timeLeft / duration, 0.0, 1.0)


func _process(delta: float) -> void:
	if not active:
		return
	timeLeft -= delta
	updateWheel()
	if timeLeft <= 0.0:
		stop()
		time_up.emit()


func updateWheel():
	wheel.value = fraction() * 100.0
