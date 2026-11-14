extends CanvasLayer

signal finished

const FLASH_SHADER: Shader = preload("res://game/restart_flash.gdshader")
const FADE_IN_DURATION := 0.65
const FADE_OUT_DURATION := 0.65

var flash: ColorRect
var flash_material: ShaderMaterial
var progress := 0.0

func _ready() -> void:
	layer = 100
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_STOP
	flash_material = ShaderMaterial.new()
	flash_material.shader = FLASH_SHADER
	flash.material = flash_material
	add_child(flash)

func _set_progress(value: float) -> void:
	progress = value
	flash_material.set_shader_parameter("progress", value)

func start() -> void:
	var fade_in := create_tween()
	fade_in.tween_method(_set_progress, 0.0, 1.0, FADE_IN_DURATION)
	await fade_in.finished
	var error := get_tree().reload_current_scene()
	if error != OK:
		push_error("Cannot restart the game (error %s)." % error)
	else:
		await get_tree().process_frame
	var fade_out := create_tween()
	fade_out.tween_method(_set_progress, 1.0, 0.0, FADE_OUT_DURATION)
	await fade_out.finished
	finished.emit()
	queue_free()
