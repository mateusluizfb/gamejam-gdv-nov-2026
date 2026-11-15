extends Control

const Text = preload("res://data/text.gd")

enum OpeningState { WAITING, REVEALING, FINISHED }

var opening_state := OpeningState.WAITING
var button_highlight_tween: Tween

@onready var start_button: TextureButton = $Button
@onready var button_material: ShaderMaterial = start_button.material

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
	if opening_state == OpeningState.FINISHED:
		return
	get_viewport().set_input_as_handled()
	if opening_state == OpeningState.WAITING and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_reveal_menu()

func _reveal_menu() -> void:
	opening_state = OpeningState.REVEALING
	$WindAudio.stop()
	$AudioStreamPlayer2D.play()
	$Intro/GustAudio.play()
	var tween := create_tween()
	tween.tween_method(_set_opening_progress, 0.0, 1.0, 1.2)
	tween.parallel().tween_property($Opening/Prompt, "modulate:a", 0.0, 0.3)
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

func _update_button_highlight() -> void:
	var highlighted := not start_button.disabled and (start_button.is_hovered() or start_button.has_focus())
	if button_highlight_tween:
		button_highlight_tween.kill()
	button_highlight_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	button_highlight_tween.tween_property(button_material, "shader_parameter/highlight", 1.0 if highlighted else 0.0, 0.18)

func _set_opening_progress(value: float) -> void:
	var material := $Opening/Background.material as ShaderMaterial
	material.set_shader_parameter("transition_progress", value)

func _on_button_pressed() -> void:
	if opening_state != OpeningState.FINISHED:
		return
	$Intro.begin(start_button)
	_update_button_highlight()
