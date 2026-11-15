extends Control

const Text = preload("res://data/text.gd")
const StoryScreen = preload("res://ui/story_screen.gd")

enum OpeningState { WAITING, STORY, REVEALING, FINISHED }

var opening_state := OpeningState.WAITING

func _ready() -> void:
	$Button.text = Text.get_text("menu_new_game")
	$Opening/Prompt.text = Text.get_text("menu_continue")
	$Intro/Story.text = Text.get_text("intro_story")
	$Intro/Prompt.text = Text.get_text("intro_continue")

func _input(event: InputEvent) -> void:
	if opening_state == OpeningState.FINISHED or opening_state == OpeningState.STORY:
		return
	get_viewport().set_input_as_handled()
	if opening_state == OpeningState.WAITING and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		opening_state = OpeningState.STORY
		var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade.tween_property($Opening/Prompt, "modulate:a", 0.0, StoryScreen.FADE_DURATION)
		var story := StoryScreen.new()
		story.name = "StoryScreen"
		add_child(story)
		story.finishing.connect(_reveal_menu)
		story.finished.connect(story.queue_free)
		story.begin([
			Text.get_text("opening_paragraph_1"),
			Text.get_text("opening_paragraph_2"),
			Text.get_text("opening_paragraph_3"),
		])

func _reveal_menu() -> void:
	opening_state = OpeningState.REVEALING
	$Mist/Background.show()
	$WindAudio.stop()
	$AudioStreamPlayer2D.play()
	$Intro/GustAudio.play()
	var tween := create_tween()
	tween.tween_method(_set_opening_progress, 0.0, 1.0, 1.2)
	await tween.finished
	$Opening.hide()
	$Button.disabled = false
	opening_state = OpeningState.FINISHED

func _set_opening_progress(value: float) -> void:
	var material := $Opening/Background.material as ShaderMaterial
	material.set_shader_parameter("transition_progress", value)

func _on_button_pressed() -> void:
	if opening_state != OpeningState.FINISHED:
		return
	$Intro.begin($Button)
