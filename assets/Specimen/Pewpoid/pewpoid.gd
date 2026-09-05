extends Node2D

@export var rotation_speed: float = .5
@onready var anim_player: AnimationPlayer = $AnimationPlayer
var flash_color = Color(1.3, .5, .5, .5)
var normal_color = Color(1,1,1,1)

func _process(delta: float) -> void:
	rotate(rotation_speed * delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		hit()

func hit():
	var flash = create_tween()
	flash.tween_property(self, "modulate", flash_color, .05)
	flash.tween_property(self, "modulate", normal_color, .2)
	anim_player.seek(0.0, true)
	anim_player.play("Jiggle")
