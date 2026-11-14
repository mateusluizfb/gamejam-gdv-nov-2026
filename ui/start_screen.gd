extends Control

var button: Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button = $Button

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_button_pressed() -> void:
	# get sound node from child AudioStreamPlayer2D
	var sound = get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
	if sound != null:
		sound.play()
	get_tree().change_scene_to_file("res://game/main.tscn")
