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
	root.add_child(scene)
	current_scene = scene
	var intro = scene.get_node("Intro")
	var button := scene.get_node("Button") as TextureButton
	_check(button.texture_normal == load("res://assets/elefantes.png"), "The menu button should show the elephants.")
	_check((button.material as ShaderMaterial).shader == load("res://ui/elephant_button.gdshader"), "The elephant button should use the glow shader.")
	var opening := scene.get_node("Opening") as CanvasLayer
	var opening_background := opening.get_node("Background") as ColorRect
	var opening_prompt := opening.get_node("Prompt") as Label
	var opening_material := opening_background.material as ShaderMaterial
	var mist := scene.get_node("Mist/Background") as ColorRect
	var mist_material := mist.material as ShaderMaterial
	var font_path := "res://assets/fonts/Macondo-Regular.ttf"
	_check(opening_prompt.get_theme_font("font").resource_path == font_path, "Project theme should apply the main font to the opening prompt.")
	var dynamic_label := Label.new()
	scene.add_child(dynamic_label)
	_check(dynamic_label.get_theme_font("font").resource_path == font_path, "Dynamically created controls should use the main font.")
	dynamic_label.free()
	var wind_audio := scene.get_node("WindAudio") as AudioStreamPlayer
	var menu_audio := scene.get_node("AudioStreamPlayer2D") as AudioStreamPlayer2D
	var gust_audio := intro.get_node("GustAudio") as AudioStreamPlayer
	_check(wind_audio.playing and (wind_audio.stream as AudioStreamMP3).loop and not menu_audio.playing, "Opening should play looping wind instead of menu music.")
	_check(opening.visible and button.disabled and opening_prompt.text == Text.get_text("menu_continue"), "The opening should show only the space prompt over the disabled menu.")
	_check(opening_background.anchor_right == 1.0 and opening_background.anchor_bottom == 1.0 and opening_material.get_shader_parameter("transition_mode") == 2, "Opening clouds should cover the viewport and be ready to reveal the menu.")
	_check(not mist.visible, "Mist should not appear before the opening prompt is dismissed.")
	root.push_input(_key(KEY_ENTER))
	root.push_input(_key(KEY_SPACE, true))
	button.pressed.emit()
	_check(scene.opening_state == scene.OpeningState.WAITING and not intro.visible, "Only a fresh Space press should dismiss the opening, and the menu must be blocked.")
	_check(wind_audio.playing and not menu_audio.playing and not gust_audio.playing, "Other keys should not change the opening audio.")
	root.push_input(_key(KEY_SPACE))
	var opening_story = scene.get_node("StoryScreen")
	_check(scene.opening_state == scene.OpeningState.STORY and opening_story.label.text == Text.get_text("opening_paragraph_1") and opening_story.paragraphs.size() == 3, "Space should open the first of three opening paragraphs.")
	_check(opening_story.label.bbcode_enabled and opening_story.label.get_theme_font("italics_font") is FontVariation, "Story text should render the requested italics.")
	_check(opening_story.prompt.visible and opening_story.prompt.text == "Aperte ESPACO para continuar" and opening_story.prompt.anchor_top == 1.0, "The opening story should show a bottom Space hint.")
	_check((opening_story.get_child(0) as ColorRect).color == Color.BLACK and opening_story.text_material.shader == load("res://ui/card_preview_spawn.gdshader"), "The story should use a black background and the card preview shader.")
	_check(wind_audio.playing and not menu_audio.playing and not mist.visible, "The menu should remain hidden during the opening story.")
	root.push_input(_key(KEY_SPACE))
	await create_timer(0.3).timeout
	_check(opening_story.background.modulate.a > 0.0 and opening_story.background.modulate.a < 1.0 and opening_prompt.modulate.a > 0.0 and opening_prompt.modulate.a < 1.0, "The opening should blend into the story instead of cutting to black.")
	await create_timer(1.0).timeout
	_check(opening_story.paragraph_index == 0, "Space during the reveal should not skip a paragraph.")
	_check(is_zero_approx(opening_prompt.modulate.a) and is_equal_approx(opening_story.background.modulate.a, 1.0), "The initial prompt should be gone once the story is visible.")
	root.push_input(_key(KEY_ENTER))
	root.push_input(_key(KEY_SPACE, true))
	_check(opening_story.paragraph_index == 0, "Other keys and repeated Space should not advance the story.")
	for index in range(1, 3):
		root.push_input(_key(KEY_SPACE))
		await create_timer(1.0).timeout
		_check(opening_story.paragraph_index == index and opening_story.label.text == Text.get_text("opening_paragraph_%d" % (index + 1)), "Each Space should advance exactly one opening paragraph.")
		_check(opening_story.label.get_content_height() <= opening_story.label.size.y - 220.0, "Opening paragraphs should fit above the bottom prompt.")
	root.push_input(_key(KEY_SPACE))
	await create_timer(0.6).timeout
	_check(scene.opening_state == scene.OpeningState.REVEALING and is_zero_approx(opening_prompt.modulate.a), "The initial prompt must not reappear when the story ends.")
	_check(opening_story.background.modulate.a > 0.0 and opening_story.background.modulate.a < 1.0, "The story should fade out while the menu is revealed.")
	_check(not wind_audio.playing and menu_audio.playing, "After the story, wind should switch to menu music.")
	_check(mist.visible and mist.anchor_right == 1.0 and mist.anchor_bottom == 1.0 and mist.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Mist should cover the screen after Space without blocking the menu.")
	_check(mist_material.shader == load("res://ui/menu_mist.gdshader") and not mist.is_processing_input(), "The menu should use mist without reacting to mouse input.")
	_check(gust_audio.playing and gust_audio.stream.resource_path == "res://assets/audio/small-wind.mp3" and not (gust_audio.stream as AudioStreamMP3).loop, "Space should play the one-shot gust sound.")
	root.push_input(_key(KEY_SPACE))
	await create_timer(0.3).timeout
	_check(scene.opening_state == scene.OpeningState.REVEALING and button.disabled and opening_material.get_shader_parameter("transition_progress") > 0.0 and opening_material.get_shader_parameter("transition_progress") < 1.0, "Wind should gradually reveal the menu without accepting input.")
	await create_timer(1.0).timeout
	_check(scene.opening_state == scene.OpeningState.FINISHED and not opening.visible and not button.disabled, "The menu should become usable after the clouds clear.")
	var background := intro.get_node("Background") as ColorRect
	var story := intro.get_node("Story") as RichTextLabel
	var prompt := intro.get_node("Prompt") as Label
	var material := background.material as ShaderMaterial
	intro._input(_key(KEY_SPACE))
	_check(current_scene == scene and not intro.visible, "Space before starting should not leave the menu.")
	button.pressed.emit()
	button.pressed.emit()
	_check(button.disabled and intro.visible and intro.intro_state == intro.IntroState.REVEALING, "New game should start the intro once.")
	_check(mist.visible, "Mist should remain visible over the intro.")
	_check(background.anchor_right == 1.0 and background.anchor_bottom == 1.0 and background.material is ShaderMaterial, "Intro shader should cover the viewport.")
	_check(story.text == Text.get_text("intro_story") and story.text.contains("novo [i]soba[/i]") and story.bbcode_enabled and story.get_theme_font("italics_font") is FontVariation and prompt.text == "Pressione espaço para continuar", "Intro should display the new story with italicized soba and the space prompt.")
	intro._input(_key(KEY_SPACE))
	await create_timer(0.3).timeout
	_check(current_scene == scene and intro.wind_progress > 0.0 and intro.wind_progress < 1.0, "Purple wind should sweep across the screen before accepting input.")
	await create_timer(1.3).timeout
	_check(is_equal_approx(intro.wind_progress, 1.0) and intro.intro_state == intro.IntroState.WAITING and is_equal_approx(prompt.modulate.a, 1.0), "Wind should finish and prompt should be visible before waiting for Space.")
	_check(story.get_content_height() <= story.size.y and story.get_global_rect().end.y <= prompt.get_global_rect().position.y, "The complete intro should fit without overlapping the prompt.")
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
	_check(not is_instance_valid(mist), "The menu mist should not persist into the game.")
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
