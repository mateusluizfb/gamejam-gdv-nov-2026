extends Control

const Text = preload("res://data/text.gd")

func _ready() -> void:
	$Button.text = Text.get_text("menu_new_game")
	$Intro/Story.text = Text.get_text("intro_story")
	$Intro/Prompt.text = Text.get_text("intro_continue")

func _on_button_pressed() -> void:
	$Intro.begin($Button)
