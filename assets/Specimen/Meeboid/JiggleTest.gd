extends Node2D

@export var rotation_speed: float = .1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hit()

func _process(delta: float) -> void:
	rotate(rotation_speed * delta)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		hit()


func hit():
	var jiggleUp = create_tween()
	jiggleUp.set_parallel(true)

	jiggleUp.tween_property($Layer4, "scale", Vector2(1.2,1.2), .2).set_trans(Tween.TRANS_ELASTIC)
	jiggleUp.tween_property($Layer3, "scale", Vector2(1.2,1.2), .25).set_trans(Tween.TRANS_ELASTIC)
	jiggleUp.tween_property($Layer2, "scale", Vector2(1.2,1.2), .3).set_trans(Tween.TRANS_ELASTIC)
	jiggleUp.tween_property($Layer1, "scale", Vector2(1.2,1.2), .35).set_trans(Tween.TRANS_ELASTIC)

	jiggleUp.chain().tween_property($Layer4, "scale", Vector2(1,1), .4).set_trans(Tween.TRANS_ELASTIC)
	jiggleUp.tween_property($Layer3, "scale", Vector2(1,1), .45).set_trans(Tween.TRANS_ELASTIC)
	jiggleUp.tween_property($Layer2, "scale", Vector2(1,1), .5).set_trans(Tween.TRANS_ELASTIC)
	jiggleUp.tween_property($Layer1, "scale", Vector2(1,1), .55).set_trans(Tween.TRANS_ELASTIC)
