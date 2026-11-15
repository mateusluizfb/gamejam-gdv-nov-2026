extends RefCounted

const AURA_SHADER = preload("res://cards/continuous_aura.gdshader")
const DRAG_COLOR := Color(1.0, 0.78, 0.32, 0.9)
const DROP_COLOR := Color(1.0, 0.9, 0.55, 0.8)
const DAMAGE_COLOR := Color(1.0, 0.28, 0.12, 0.8)
const TRAP_COLOR := Color(0.75, 0.3, 1.0, 0.8)
const MAGIC_BUFF_COLOR := Color(1.0, 0.12, 0.12, 0.9)
const TARGET_COLOR := Color(0.7, 0.2, 1.0, 0.95)
const PADDING := 27.0

static func aura_padding(shape_size: Vector2, round_shape: bool) -> Vector2:
	if round_shape:
		return shape_size / maxf(minf(shape_size.x, shape_size.y), 1.0) * PADDING
	return Vector2.ONE * PADDING

static func start_drag(card: Node2D) -> void:
	var aura := card.get_node_or_null("DragAura") as ColorRect
	if aura == null:
		aura = _card_aura(card, "DragAura", DRAG_COLOR)
	aura.show()

static func stop_drag(card: Node2D) -> void:
	var aura := card.get_node_or_null("DragAura") as ColorRect
	if aura != null:
		aura.hide()

static func drop(container: Node2D, position: Vector2) -> void:
	_burst(container, "DropAura", Rect2(position - Vector2.ONE * 35.0, Vector2.ONE * 70.0), DROP_COLOR, 0.55, true)

static func damage(container: Node2D, position: Vector2) -> void:
	_burst(container, "DamageAura", Rect2(position - Vector2.ONE * 55.0, Vector2.ONE * 110.0), DAMAGE_COLOR, 0.6, true)

static func set_magic_buff(card: Node2D, active: bool) -> void:
	_set_card_aura(card, "MagicBuffAura", MAGIC_BUFF_COLOR, active)

static func set_target_aura(card: Node2D, active: bool) -> void:
	_set_card_aura(card, "TargetAura", TARGET_COLOR, active)

static func trap_row(container: Node2D, rect: Rect2) -> void:
	_burst(container, "TrapAura", rect, TRAP_COLOR, 0.75, false)

static func _set_card_aura(card: Node2D, node_name: String, color: Color, active: bool) -> void:
	var aura := card.get_node_or_null(node_name) as ColorRect
	if not active:
		if aura != null:
			card.remove_child(aura)
			aura.queue_free()
	elif aura == null:
		_card_aura(card, node_name, color)

static func _card_aura(card: Node2D, node_name: String, color: Color) -> ColorRect:
	var sprite := card.get_node("Sprite2D") as Sprite2D
	var sprite_rect := sprite.get_rect()
	var rect := Rect2(sprite.transform * sprite_rect.position, sprite_rect.size * sprite.scale.abs())
	var aura := _new_aura(rect, color, false)
	aura.name = node_name
	aura.show_behind_parent = true
	card.add_child(aura)
	return aura

static func _new_aura(rect: Rect2, color: Color, round_shape: bool) -> ColorRect:
	var aura := ColorRect.new()
	var padding := aura_padding(rect.size, round_shape)
	aura.position = rect.position - padding
	aura.size = rect.size + padding * 2.0
	aura.pivot_offset = aura.size / 2.0
	aura.color = color
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = AURA_SHADER
	material.set_shader_parameter("shape_size", rect.size)
	material.set_shader_parameter("aura_size", aura.size)
	material.set_shader_parameter("round_shape", round_shape)
	aura.material = material
	return aura

static func _burst(container: Node2D, node_name: String, rect: Rect2, color: Color, duration: float, round_shape: bool) -> void:
	var aura := _new_aura(rect, color, round_shape)
	aura.name = node_name
	aura.z_index = 20
	container.add_child(aura, true)
	var tween := aura.create_tween().set_parallel(true)
	tween.tween_property(aura, "modulate:a", 0.0, duration)
	tween.tween_property(aura, "scale", Vector2(1.3, 1.3), duration)
	tween.chain().tween_callback(aura.queue_free)
