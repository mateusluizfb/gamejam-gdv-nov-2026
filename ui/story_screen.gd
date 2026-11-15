extends CanvasLayer

signal finished
signal finishing

const Text = preload("res://data/text.gd")
const STORY_SMOKE_SHADER: Shader = preload("res://ui/story_smoke.gdshader")
const SPAWN_DURATION := 0.6
const VANISH_DURATION := 0.3
const FADE_DURATION := 0.6

var paragraphs: Array[String] = []
var final_text := ""
var paragraph_index := 0
var transitioning := false
var complete := false
var background: ColorRect
var label: RichTextLabel
var prompt: Label
var text_material: ShaderMaterial
var text_viewport: SubViewport

func _ready() -> void:
	layer = 60
	background = ColorRect.new()
	background.color = Color.BLACK
	background.modulate.a = 0.0
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	text_viewport = SubViewport.new()
	text_viewport.transparent_bg = true
	text_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(text_viewport)
	label = RichTextLabel.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.bbcode_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("normal_font_size", 34)
	label.add_theme_font_size_override("italics_font_size", 34)
	text_viewport.add_child(label)
	Text.set_story_italics(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 100.0
	label.offset_right = -100.0

	var text_display := TextureRect.new()
	text_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	text_display.texture = text_viewport.get_texture()
	text_material = ShaderMaterial.new()
	text_material.shader = STORY_SMOKE_SHADER
	text_display.material = text_material
	add_child(text_display)
	text_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	prompt = Label.new()
	prompt.text = Text.get_text("story_continue")
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 22)
	add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -110.0
	prompt.offset_bottom = -50.0
	get_viewport().size_changed.connect(_resize_text_viewport)
	_resize_text_viewport()

func _resize_text_viewport() -> void:
	text_viewport.size = Vector2i(get_viewport().get_visible_rect().size)

func begin(texts: Array[String], ending: String = "") -> void:
	if texts.is_empty():
		push_error("Cannot show a story without paragraphs.")
		return
	paragraphs = texts
	final_text = ending
	paragraph_index = 0
	complete = false
	transitioning = true
	label.text = paragraphs[0]
	text_material.set_shader_parameter("spawn_progress", 0.0)
	background.modulate.a = 0.0
	prompt.modulate.a = 0.0
	prompt.show()
	show()
	var fade := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(background, "modulate:a", 1.0, FADE_DURATION)
	fade.tween_property(prompt, "modulate:a", 1.0, FADE_DURATION)
	await fade.finished
	_show_text(paragraphs[0])

func _unhandled_input(event: InputEvent) -> void:
	if not visible or complete:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if not transitioning:
			_advance()

func _show_text(text: String) -> void:
	transitioning = true
	label.text = text
	text_material.set_shader_parameter("spawn_progress", 0.0)
	var tween := create_tween()
	tween.tween_property(text_material, "shader_parameter/spawn_progress", 1.0, SPAWN_DURATION)
	await tween.finished
	transitioning = false

func _advance() -> void:
	transitioning = true
	var tween := create_tween()
	tween.tween_property(text_material, "shader_parameter/spawn_progress", 0.0, VANISH_DURATION)
	if paragraph_index == paragraphs.size() - 1:
		tween.parallel().tween_property(prompt, "modulate:a", 0.0, VANISH_DURATION)
	await tween.finished
	paragraph_index += 1
	if paragraph_index < paragraphs.size():
		_show_text(paragraphs[paragraph_index])
	elif not final_text.is_empty():
		complete = true
		prompt.hide()
		_show_text(final_text)
	else:
		finishing.emit()
		var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade.tween_property(background, "modulate:a", 0.0, FADE_DURATION)
		await fade.finished
		hide()
		finished.emit()
