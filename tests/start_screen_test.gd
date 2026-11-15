extends SceneTree

const Text = preload("res://data/text.gd")

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func _key(keycode: Key, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = echo
	return event

func _run() -> void:
	var scene: Node = load("res://ui/start_screen.tscn").instantiate()
	var original_button := Text.get_text("menu_new_game")
	Text.config.set_value("text", "menu_new_game", "Menu editado")
	root.add_child(scene)
	current_scene = scene
	var intro = scene.get_node("Intro")
	var button := scene.get_node("Button") as Button
	_check(button.text == "Menu editado", "Menu text should come from the editable text file.")
	Text.config.set_value("text", "menu_new_game", original_button)
	var opening := scene.get_node("Opening") as CanvasLayer
	var opening_background := opening.get_node("Background") as ColorRect
	var opening_prompt := opening.get_node("Prompt") as Label
	var opening_material := opening_background.material as ShaderMaterial
	var font_path := "res://assets/fonts/Macondo-Regular.ttf"
	_check(button.get_theme_font("font").resource_path == font_path and opening_prompt.get_theme_font("font").resource_path == font_path, "Project theme should apply the main font to buttons and labels.")
	var dynamic_label := Label.new()
	scene.add_child(dynamic_label)
	_check(dynamic_label.get_theme_font("font").resource_path == font_path, "Dynamically created controls should use the main font.")
	dynamic_label.free()
	var wind_audio := scene.get_node("WindAudio") as AudioStreamPlayer
	var menu_audio := scene.get_node("AudioStreamPlayer2D") as AudioStreamPlayer2D
	var gust_audio := intro.get_node("GustAudio") as AudioStreamPlayer
	_check(wind_audio.playing and (wind_audio.stream as AudioStreamMP3).loop and not menu_audio.playing, "Opening should play looping wind instead of menu music.")
	_check(opening.visible and button.disabled and opening_prompt.text == "Aperte ESPACO para continuar", "The opening should show only the space prompt over the disabled menu.")
	_check(opening_background.anchor_right == 1.0 and opening_background.anchor_bottom == 1.0 and opening_material.get_shader_parameter("transition_mode") == 2, "Opening clouds should cover the viewport and be ready to reveal the menu.")
	root.push_input(_key(KEY_ENTER))
	root.push_input(_key(KEY_SPACE, true))
	button.pressed.emit()
	_check(scene.opening_state == scene.OpeningState.WAITING and not intro.visible, "Only a fresh Space press should dismiss the opening, and the menu must be blocked.")
	_check(wind_audio.playing and not menu_audio.playing and not gust_audio.playing, "Other keys should not change the opening audio.")
	root.push_input(_key(KEY_SPACE))
	_check(not wind_audio.playing and menu_audio.playing, "Space should immediately switch from wind to menu music.")
	_check(gust_audio.playing and gust_audio.stream.resource_path == "res://assets/audio/small-wind.mp3" and not (gust_audio.stream as AudioStreamMP3).loop, "Space should play the one-shot gust sound.")
	root.push_input(_key(KEY_SPACE))
	await create_timer(0.3).timeout
	_check(scene.opening_state == scene.OpeningState.REVEALING and button.disabled and opening_material.get_shader_parameter("transition_progress") > 0.0 and opening_material.get_shader_parameter("transition_progress") < 1.0, "Wind should gradually reveal the menu without accepting input.")
	await create_timer(1.0).timeout
	_check(scene.opening_state == scene.OpeningState.FINISHED and not opening.visible and not button.disabled, "The menu should become usable after the clouds clear.")
	var background := intro.get_node("Background") as ColorRect
	var story := intro.get_node("Story") as Label
	var prompt := intro.get_node("Prompt") as Label
	var material := background.material as ShaderMaterial
	intro._input(_key(KEY_SPACE))
	_check(current_scene == scene and not intro.visible, "Space before starting should not leave the menu.")
	button.pressed.emit()
	button.pressed.emit()
	_check(button.disabled and intro.visible and intro.intro_state == intro.IntroState.REVEALING, "New game should start the intro once.")
	_check(background.anchor_right == 1.0 and background.anchor_bottom == 1.0 and background.material is ShaderMaterial, "Intro shader should cover the viewport.")
	_check(story.text == "Para finalizar o monumento seus guerreiros precisam passar pelos elefantes para buscar o marfim restante" and prompt.text == "Pressione espaço para continuar", "Intro should display the requested story and space prompt.")
	intro._input(_key(KEY_SPACE))
	await create_timer(0.3).timeout
	_check(current_scene == scene and intro.wind_progress > 0.0 and intro.wind_progress < 1.0, "Purple wind should sweep across the screen before accepting input.")
	await create_timer(1.3).timeout
	_check(is_equal_approx(intro.wind_progress, 1.0) and intro.intro_state == intro.IntroState.WAITING and is_equal_approx(prompt.modulate.a, 1.0), "Wind should finish and prompt should be visible before waiting for Space.")
	intro._input(_key(KEY_ENTER))
	intro._input(_key(KEY_SPACE, true))
	_check(intro.intro_state == intro.IntroState.WAITING, "Only a fresh Space press should continue.")
	root.push_input(_key(KEY_SPACE))
	_check(gust_audio.playing and intro.get_parent() == root, "The game transition should replay the gust while preserving it across the scene change.")
	root.push_input(_key(KEY_SPACE))
	await create_timer(0.3).timeout
	_check(current_scene == scene and material.get_shader_parameter("transition_mode") == 1 and material.get_shader_parameter("transition_progress") > 0.0 and material.get_shader_parameter("transition_progress") < 1.0, "A gust should cover the intro before changing scenes.")
	await create_timer(1.0).timeout
	_check(current_scene != null and current_scene != scene and current_scene.get_node_or_null("CardManager") != null, "Space should load the main game.")
	if current_scene != null and current_scene != scene:
		_check((current_scene.get_node("ElephantSound") as AudioStreamPlayer2D).playing, "Entering the game from the menu should play the elephant sound.")
	_check(is_instance_valid(intro) and intro.get_parent() == root and background.visible and material.get_shader_parameter("transition_mode") == 2 and material.get_shader_parameter("transition_progress") > 0.0 and material.get_shader_parameter("transition_progress") < 1.0, "Gust should sweep over the new scene as it reveals the game.")
	_check(not story.visible and not prompt.visible, "The old intro text should not appear over the game.")
	await create_timer(1.3).timeout
	_check(is_instance_valid(intro) and not intro.visible and not intro.is_processing_input() and gust_audio.playing, "The overlay should stop blocking the game while the gust finishes.")
	await create_timer(2.0).timeout
	_check(not is_instance_valid(intro), "Transition overlay should be removed after the gust finishes.")
	if current_scene != null:
		current_scene.free()
		current_scene = null
	if not failed:
		print("Start screen checks passed.")
	quit(1 if failed else 0)
