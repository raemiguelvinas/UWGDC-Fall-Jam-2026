class_name PattyProgress
extends Node2D
# Make this a CHILD OF THE PATTY ROOT (not of the patty's Sprite2D).
# It then follows the patty around and hides whenever the patty is hidden.

@export var regularBar: Range
@export var flippedBar: Range
@export var regularLabel: Label
@export var flippedLabel: Label


func _ready() -> void:
	# let clicks fall through to the patty's Area2D
	for c in [regularBar, flippedBar, regularLabel, flippedLabel]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func showValues(regularValue: float, flippedValue: float, flippedActive: bool) -> void:
	regularBar.value = regularValue
	flippedBar.value = flippedValue
	regularLabel.text = "%d%%" % int(regularValue)
	flippedLabel.text = "%d%%" % int(flippedValue)

	# dim the side that isn't cooking right now
	var regularAlpha := 0.5 if flippedActive else 1.0
	var flippedAlpha := 1.0 if flippedActive else 0.5
	regularBar.modulate.a = regularAlpha
	regularLabel.modulate.a = regularAlpha
	flippedBar.modulate.a = flippedAlpha
	flippedLabel.modulate.a = flippedAlpha
