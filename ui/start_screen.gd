extends Control

const Text = preload("res://data/text.gd")
const StoryScreen = preload("res://ui/story_screen.gd")
const CardParticles = preload("res://game/card_particles.gd")

enum OpeningState { WAITING, STORY, REVEALING, FINISHED }

var opening_state := OpeningState.WAITING
var button_highlight_tween: Tween
var button_aura_tween: Tween

@onready var start_button: TextureButton = $Button
@onready var button_material: ShaderMaterial = start_button.material
@onready var button_aura: ColorRect = $Button/Aura
@onready var aura_material: ShaderMaterial = button_aura.material

func _ready() -> void:
	start_button.resized.connect(_update_button_center)
	start_button.mouse_entered.connect(_update_button_highlight)
	start_button.mouse_exited.connect(_update_button_highlight)
	start_button.focus_entered.connect(_update_button_highlight)
	start_button.focus_exited.connect(_update_button_highlight)
	_update_button_center()
	$Opening/Prompt.text = Text.get_text("menu_continue")
	$Intro/Story.text = Text.get_text("intro_story")
	$Intro/Prompt.text = Text.get_text("intro_continue")
	if not $Opening.visible:
		$WindAudio.stop()
		$AudioStreamPlayer2D.play()
		_enable_menu()

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
	_enable_menu()
	start_button.grab_focus()

func _enable_menu() -> void:
	opening_state = OpeningState.FINISHED
	start_button.disabled = false
	_update_button_highlight()

func _update_button_center() -> void:
	button_material.set_shader_parameter("button_center", start_button.size * 0.5)
	var padding := CardParticles.aura_padding(start_button.size, true)
	button_aura.offset_left = -padding.x
	button_aura.offset_top = -padding.y
	button_aura.offset_right = padding.x
	button_aura.offset_bottom = padding.y
	aura_material.set_shader_parameter("shape_size", start_button.size)
	aura_material.set_shader_parameter("aura_size", start_button.size + padding * 2.0)

func _update_button_highlight() -> void:
	var highlighted := not start_button.disabled and (start_button.is_hovered() or start_button.has_focus())
	var aura_opacity := 0.0 if start_button.disabled else (0.95 if start_button.is_hovered() else 0.35)
	if button_highlight_tween:
		button_highlight_tween.kill()
	button_highlight_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	button_highlight_tween.tween_property(button_material, "shader_parameter/highlight", 1.0 if highlighted else 0.0, 0.18)
	if button_aura_tween:
		button_aura_tween.kill()
	button_aura_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	button_aura_tween.tween_property(button_aura, "modulate:a", aura_opacity, 0.18)

func _set_opening_progress(value: float) -> void:
	var material := $Opening/Background.material as ShaderMaterial
	material.set_shader_parameter("transition_progress", value)

func _on_button_pressed() -> void:
	if opening_state != OpeningState.FINISHED:
		return
	$Intro.begin(start_button)
	_update_button_highlight()
