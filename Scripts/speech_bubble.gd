class_name SpeechBubble
extends Node2D
# Children: a bg Sprite2D, a RichTextLabel (orderLabel) and a Sprite2D (resultIcon).
# Place the bubble where it should REST; it slides in from the left to that spot.

@export var orderLabel: RichTextLabel
@export var resultIcon: Sprite2D
@export var slideDistance := 200.0
@export var slideTime := 0.35

var restPosition: Vector2
var tween: Tween
var iconTween: Tween


func _ready() -> void:
	restPosition = position
	orderLabel.bbcode_enabled = true
	visible = false


func showOrder(bbcode: String):
	orderLabel.text = bbcode
	orderLabel.visible = true
	resultIcon.visible = false
	_slideIn()


func showResult(tex: Texture2D):
	orderLabel.visible = false
	resultIcon.texture = tex
	resultIcon.visible = true
	_slideIn()

	# the icon just fades in
	if iconTween: iconTween.kill()
	resultIcon.modulate.a = 0.0
	iconTween = create_tween()
	iconTween.tween_property(resultIcon, "modulate:a", 1.0, 0.25)


func hideBubble():
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): visible = false)


func _slideIn():
	if tween: tween.kill()
	visible = true
	modulate.a = 1.0
	position = restPosition + Vector2(-slideDistance, 0)
	tween = create_tween()
	tween.tween_property(self, "position", restPosition, slideTime)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
