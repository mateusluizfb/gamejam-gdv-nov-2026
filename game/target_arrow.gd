extends Node2D

const BEAM_SHADER: Shader = preload("res://game/target_beam.gdshader")
const SEGMENTS := 32

var start := Vector2.ZERO
var end := Vector2.ZERO
var control := Vector2.ZERO
var beam_material: ShaderMaterial

func _ready() -> void:
	beam_material = ShaderMaterial.new()
	beam_material.shader = BEAM_SHADER
	material = beam_material

func set_points(from: Vector2, to: Vector2) -> void:
	start = from
	end = to
	var delta := end - start
	control = (start + end) / 2.0 + delta.normalized().orthogonal() * minf(delta.length() * 0.25, 90.0)
	beam_material.set_shader_parameter("beam_length", delta.length())
	queue_redraw()

func _curve_position(t: float) -> Vector2:
	return start.bezier_interpolate(control, control, end, t)

func _draw() -> void:
	var distance := start.distance_to(end)
	if distance < 0.01:
		return
	var width := minf(28.0, distance * 0.25)
	for i in range(SEGMENTS):
		var t0 := float(i) / SEGMENTS
		var t1 := float(i + 1) / SEGMENTS
		var from := _curve_position(t0)
		var to := _curve_position(t1)
		var side0 := start.bezier_derivative(control, control, end, t0).normalized().orthogonal() * width
		var side1 := start.bezier_derivative(control, control, end, t1).normalized().orthogonal() * width
		var points := PackedVector2Array([from + side0, to + side1, to - side1, from - side0])
		var uvs := PackedVector2Array([Vector2(t0, 0), Vector2(t1, 0), Vector2(t1, 1), Vector2(t0, 1)])
		draw_polygon(points, PackedColorArray([Color.WHITE]), uvs)
