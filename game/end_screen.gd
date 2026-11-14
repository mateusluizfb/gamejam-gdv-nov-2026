extends CanvasLayer

const CardData = preload("res://cards/card_data.gd")
const GameState = preload("res://game/game_state.gd")
const Text = preload("res://data/text.gd")
const CARD_SCENE: PackedScene = preload("res://cards/card.tscn")
const HERD_SCALE := 2.0

var panel: Control
var herd: Node2D
var title: Label
var enemies: Array[CardData] = []
var result := GameState.Outcome.IN_PROGRESS

func _ready() -> void:
	layer = 50
	panel = Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.hide()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	herd = Node2D.new()
	herd.name = "Herd"
	panel.add_child(herd)
	title = Label.new()
	title.name = "Result"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.z_index = 100
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_font_size_override("font_size", 72)
	panel.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hint := Label.new()
	hint.name = "RestartHint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = 100
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 5)
	hint.add_theme_font_size_override("font_size", 22)
	hint.text = Text.get_text("restart_hint")
	panel.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint.offset_left = -220.0
	hint.offset_right = 220.0
	hint.offset_top = 65.0
	hint.offset_bottom = 105.0
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func show_result(outcome: GameState.Outcome, remaining_enemies: Array[CardData]) -> void:
	result = outcome
	enemies = remaining_enemies
	title.text = Text.get_text("victory") if outcome == GameState.Outcome.WON else Text.get_text("defeat")
	panel.show()
	if outcome == GameState.Outcome.LOST:
		_spawn_herd()

func _on_viewport_size_changed() -> void:
	if result == GameState.Outcome.LOST:
		_spawn_herd()

func _spawn_herd() -> void:
	for child in herd.get_children():
		herd.remove_child(child)
		child.queue_free()
	if enemies.is_empty():
		push_error("Cannot show a defeat herd without enemy cards.")
		return
	var sample := CARD_SCENE.instantiate()
	var sprite := sample.get_node("Sprite2D") as Sprite2D
	var enemy_texture := load(enemies[0].image_path) as Texture2D
	if enemy_texture == null:
		sample.free()
		push_error("Cannot load the enemy card texture for the defeat herd.")
		return
	var card_size := enemy_texture.get_size() * sprite.scale.abs() * HERD_SCALE
	sample.free()
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var step := card_size * Vector2(0.75, 0.75)
	var columns := ceili(viewport_size.x / step.x) + 1
	var rows := ceili(viewport_size.y / step.y) + 1
	for row in range(rows):
		for column in range(columns):
			var card := CARD_SCENE.instantiate() as Node2D
			card.data = enemies[(row * columns + column) % enemies.size()]
			card.position = Vector2(column * step.x, -card_size.y)
			card.scale = Vector2.ONE * 0.7
			herd.add_child(card)
			var destination := Vector2(column * step.x + (row % 2) * step.x * 0.2, row * step.y)
			var delay := row * 0.18 + (column % 3) * 0.04
			var duration := 0.8 + destination.y / viewport_size.y * 0.9
			var tween := card.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(card, "position", destination, duration).set_delay(delay)
			tween.tween_property(card, "scale", Vector2.ONE * HERD_SCALE, duration).set_delay(delay)
			tween.tween_property(card, "rotation", (float((column + row) % 3) - 1.0) * 0.08, duration).set_delay(delay)
