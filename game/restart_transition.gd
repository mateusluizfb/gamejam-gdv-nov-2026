extends CanvasLayer

signal finished

const WIND_SHADER: Shader = preload("res://ui/start_intro.gdshader")
const GUST_SOUND: AudioStream = preload("res://assets/audio/small-wind.mp3")
const TRANSITION_DURATION := 1.2

var background: ColorRect
var wind_material: ShaderMaterial
var gust_audio: AudioStreamPlayer
var progress := 0.0

func _ready() -> void:
	layer = 100
	background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	wind_material = ShaderMaterial.new()
	wind_material.shader = WIND_SHADER
	wind_material.set_shader_parameter("transition_mode", 1)
	background.material = wind_material
	add_child(background)
	gust_audio = AudioStreamPlayer.new()
	gust_audio.stream = GUST_SOUND
	add_child(gust_audio)

func _set_progress(value: float) -> void:
	progress = value
	wind_material.set_shader_parameter("transition_progress", value)

func start() -> void:
	gust_audio.play()
	var cover := create_tween()
	cover.tween_method(_set_progress, 0.0, 1.0, TRANSITION_DURATION)
	await cover.finished
	var error := get_tree().reload_current_scene()
	if error != OK:
		push_error("Cannot restart the game (error %s)." % error)
	else:
		await get_tree().process_frame
	wind_material.set_shader_parameter("transition_mode", 2)
	_set_progress(0.0)
	var reveal := create_tween()
	reveal.tween_method(_set_progress, 0.0, 1.0, TRANSITION_DURATION)
	await reveal.finished
	if gust_audio.playing:
		gust_audio.reparent(get_tree().root)
		gust_audio.finished.connect(gust_audio.queue_free)
	finished.emit()
	queue_free()
