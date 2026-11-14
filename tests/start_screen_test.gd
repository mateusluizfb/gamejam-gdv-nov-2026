extends SceneTree

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
	root.add_child(scene)
	current_scene = scene
	var intro = scene.get_node("Intro")
	var button := scene.get_node("Button") as Button
	var background := intro.get_node("Background") as ColorRect
	var story := intro.get_node("Story") as Label
	var prompt := intro.get_node("Prompt") as Label
	var fade := intro.get_node("Fade") as ColorRect
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
	intro._input(_key(KEY_SPACE))
	intro._input(_key(KEY_SPACE))
	await create_timer(0.3).timeout
	_check(current_scene == scene and fade.modulate.a > 0.0 and fade.modulate.a < 1.0, "Scene should fade to black before changing.")
	await create_timer(0.4).timeout
	_check(current_scene != null and current_scene != scene and current_scene.get_node_or_null("CardManager") != null, "Space should load the main game.")
	_check(is_instance_valid(intro) and intro.get_parent() == root and fade.modulate.a > 0.0, "Fade should persist over the new scene.")
	_check(not background.visible and not story.visible and not prompt.visible, "Fading out should reveal the game rather than the old intro.")
	await create_timer(0.7).timeout
	_check(not is_instance_valid(intro), "Transition overlay should be removed after fading in.")
	if current_scene != null:
		current_scene.free()
		current_scene = null
	if not failed:
		print("Start screen checks passed.")
	quit(1 if failed else 0)
