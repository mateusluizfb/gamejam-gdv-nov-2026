extends CanvasLayer

const MAIN_SCENE: PackedScene = preload("res://game/main.tscn")

enum IntroState { MENU, REVEALING, WAITING, TRANSITIONING }

var intro_state := IntroState.MENU
var wind_progress := 0.0

@onready var background: ColorRect = $Background
@onready var story: Label = $Story
@onready var prompt: Label = $Prompt
@onready var gust_audio: AudioStreamPlayer = $GustAudio

func begin(button: BaseButton) -> void:
	if intro_state != IntroState.MENU:
		return
	intro_state = IntroState.REVEALING
	button.disabled = true
	show()
	var tween := create_tween()
	tween.tween_method(_set_wind_progress, 0.0, 1.0, 1.2)
	tween.parallel().tween_property(background, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(story, "modulate:a", 1.0, 0.6).set_delay(0.45)
	tween.tween_property(prompt, "modulate:a", 1.0, 0.3)
	await tween.finished
	intro_state = IntroState.WAITING

func _set_wind_progress(value: float) -> void:
	wind_progress = value
	var material := background.material as ShaderMaterial
	material.set_shader_parameter("wind_progress", value)

func _input(event: InputEvent) -> void:
	if intro_state == IntroState.TRANSITIONING:
		get_viewport().set_input_as_handled()
		return
	if intro_state != IntroState.WAITING:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_start_game()

func _start_game() -> void:
	intro_state = IntroState.TRANSITIONING
	var tree := get_tree()
	var menu := get_parent()
	reparent(tree.root)
	gust_audio.play()
	var material := background.material as ShaderMaterial
	material.set_shader_parameter("transition_mode", 1)
	var cover := create_tween()
	cover.tween_method(_set_transition_progress, 0.0, 1.0, 1.2)
	cover.parallel().tween_property(story, "modulate:a", 0.0, 0.5)
	cover.parallel().tween_property(prompt, "modulate:a", 0.0, 0.3)
	await cover.finished
	story.hide()
	prompt.hide()
	var error := tree.change_scene_to_packed(MAIN_SCENE)
	if error != OK:
		push_error("Cannot start the game (error %s)." % error)
		reparent(menu)
		story.show()
		prompt.show()
		var recovery := create_tween()
		recovery.tween_method(_set_transition_progress, 1.0, 0.0, 1.2)
		recovery.parallel().tween_property(story, "modulate:a", 1.0, 0.6)
		recovery.parallel().tween_property(prompt, "modulate:a", 1.0, 0.3)
		await recovery.finished
		material.set_shader_parameter("transition_mode", 0)
		intro_state = IntroState.WAITING
		return
	await tree.process_frame
	material.set_shader_parameter("transition_mode", 2)
	_set_transition_progress(0.0)
	var reveal := create_tween()
	reveal.tween_method(_set_transition_progress, 0.0, 1.0, 1.2)
	await reveal.finished
	hide()
	set_process_input(false)
	if gust_audio.playing:
		await gust_audio.finished
	queue_free()

func _set_transition_progress(value: float) -> void:
	var material := background.material as ShaderMaterial
	material.set_shader_parameter("transition_progress", value)
