extends CanvasLayer

const SCREEN_SHADER: Shader = preload("res://game/screen_effects.gdshader")

var overlay: ColorRect
var effect_material: ShaderMaterial
var magic_strength := 0.0
var impact_strength := 0.0
var magic_tween: Tween
var impact_tween: Tween
var shake_tween: Tween
var shake_origin := Vector2.ZERO

@onready var world: Node2D = get_parent() as Node2D

func _ready() -> void:
	layer = 90
	overlay = ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.hide()
	effect_material = ShaderMaterial.new()
	effect_material.shader = SCREEN_SHADER
	overlay.material = effect_material
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func play_magic() -> void:
	if magic_tween != null and magic_tween.is_running():
		magic_tween.kill()
	magic_tween = create_tween()
	magic_tween.tween_method(_set_magic_strength, magic_strength, 1.0, 0.1)
	magic_tween.tween_method(_set_magic_strength, 1.0, 0.0, 1.4)

func play_impact() -> void:
	if impact_tween != null and impact_tween.is_running():
		impact_tween.kill()
	impact_tween = create_tween()
	impact_tween.tween_method(_set_impact_strength, impact_strength, 1.0, 0.06)
	impact_tween.tween_method(_set_impact_strength, 1.0, 0.0, 0.44)
	if shake_tween != null and shake_tween.is_running():
		shake_tween.kill()
		world.position = shake_origin
	else:
		shake_origin = world.position
	shake_tween = create_tween()
	for offset in [Vector2(5, -3), Vector2(-4, 2), Vector2(3, 2), Vector2(-2, -1), Vector2.ZERO]:
		shake_tween.tween_property(world, "position", shake_origin + offset, 0.1)

func _set_magic_strength(value: float) -> void:
	magic_strength = value
	effect_material.set_shader_parameter("magic_strength", value)
	overlay.visible = magic_strength > 0.0 or impact_strength > 0.0

func _set_impact_strength(value: float) -> void:
	impact_strength = value
	effect_material.set_shader_parameter("impact_strength", value)
	overlay.visible = magic_strength > 0.0 or impact_strength > 0.0
