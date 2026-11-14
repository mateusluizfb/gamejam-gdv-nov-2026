@tool
extends Node2D

var CARDS_COUNT = 20
var CARD_SCENE: PackedScene = preload("res://card.tscn")
var HAND: Node2D
const GRID_ORIGIN := Vector2(450, 100)
const GRID_GAP := 25.0

var HAND_CARDS: Array = []
var INITIAL_CARDS: Array = []
var hand_card_scenes: Array[PackedScene] = []

var dragged_card: Node2D
var drag_offset := Vector2.ZERO
var drag_origin := Vector2i(-1, -1)
var cell_size := Vector2.ZERO

var cards_in_game: Array = []

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragged_card = null
			var cards = get_children()
			cards.reverse()
			for card in cards:
				if not card is Node2D:
					continue
				var sprite := card.get_node_or_null("Sprite2D") as Sprite2D
				if sprite != null and sprite.is_visible_in_tree() and sprite.get_rect().has_point(sprite.get_global_transform_with_canvas().affine_inverse() * event.position):
					var cell := _find_card_cell(card)
					if cell == Vector2i(-1, -1):
						push_error("Card '%s' is not in the grid." % card.name)
						continue
					dragged_card = card
					drag_origin = cell
					drag_offset = card.position - get_global_transform_with_canvas().affine_inverse() * event.position
					break
		else:
			if is_instance_valid(dragged_card):
				dragged_card.position = get_global_transform_with_canvas().affine_inverse() * event.position + drag_offset
				_finish_drag()
			dragged_card = null
	elif event is InputEventMouseMotion and is_instance_valid(dragged_card):
		dragged_card.position = get_global_transform_with_canvas().affine_inverse() * event.position + drag_offset

func _find_card_cell(card: Node2D) -> Vector2i:
	for row in range(cards_in_game.size()):
		for col in range(cards_in_game[row].size()):
			if cards_in_game[row][col] == card:
				return Vector2i(col, row)
	return Vector2i(-1, -1)

func _cell_position(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell) * cell_size

func _hand_card_position(index: int) -> Vector2:
	var grid_columns := 0
	for row in INITIAL_CARDS:
		grid_columns = maxi(grid_columns, row.size())
	var grid_center_x := GRID_ORIGIN.x + (grid_columns - 1) * cell_size.x / 2.0
	var card_count := hand_card_scenes.size() - hand_card_scenes.count(null)
	return Vector2(
		grid_center_x + (index - (card_count - 1) / 2.0) * cell_size.x,
		GRID_ORIGIN.y + INITIAL_CARDS.size() * cell_size.y
	)

func _finish_drag() -> void:
	var relative_position := (dragged_card.position - GRID_ORIGIN) / cell_size
	var row := floori(relative_position.y + 0.5)
	var col := floori(relative_position.x + 0.5)
	var destination := drag_origin
	if row >= 0 and row < cards_in_game.size() and col >= 0 and col < cards_in_game[row].size():
		if cards_in_game[row][col] == null or cards_in_game[row][col] == dragged_card:
			cards_in_game[drag_origin.y][drag_origin.x] = null
			cards_in_game[row][col] = dragged_card
			destination = Vector2i(col, row)
	dragged_card.position = _cell_position(destination)

func _draw() -> void:
	if not Engine.is_editor_hint() or cell_size == Vector2.ZERO:
		return
	for row in range(INITIAL_CARDS.size()):
		for col in range(INITIAL_CARDS[row].size()):
			_draw_cell(_cell_position(Vector2i(col, row)))
	var card_count := hand_card_scenes.size() - hand_card_scenes.count(null)
	for index in range(card_count):
		_draw_cell(_hand_card_position(index))

func _draw_cell(center: Vector2) -> void:
	var rect := Rect2(center - cell_size / 2.0, cell_size)
	draw_rect(rect, Color(0.3, 0.6, 1.0, 0.12))
	draw_rect(rect, Color(0.3, 0.6, 1.0, 0.8), false, 1.0)

func _new_card(scene: PackedScene) -> Node2D:
	if Engine.is_editor_hint():
		return null
	var card := scene.instantiate()
	if not card is Node2D:
		push_error("Card scene '%s' must have a Node2D root." % scene.resource_path)
		card.free()
		return null
	return card

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	HAND = get_node_or_null("Hand") as Node2D
	if HAND == null:
		push_error("Cannot lay out hand cards without a Hand node.")
		set_process_input(false)
		return
	var sample_card := CARD_SCENE.instantiate()
	var sprite := sample_card.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.get_rect().size.x <= 0 or sprite.get_rect().size.y <= 0:
		sample_card.free()
		push_error("Cannot lay out cards without a Sprite2D with a texture.")
		set_process_input(false)
		return
	cell_size = sprite.get_rect().size * sprite.scale.abs() + Vector2.ONE * GRID_GAP
	sample_card.free()

	INITIAL_CARDS = [
		[_new_card(CARD_SCENE), _new_card(CARD_SCENE), _new_card(CARD_SCENE), _new_card(CARD_SCENE)],
		[_new_card(CARD_SCENE), null, null, null],
		[_new_card(CARD_SCENE), null, null, null],
		[_new_card(CARD_SCENE), _new_card(CARD_SCENE), null, null]
	]
	hand_card_scenes = [
		CARD_SCENE, CARD_SCENE, CARD_SCENE, CARD_SCENE, CARD_SCENE, CARD_SCENE
	]
	for scene in hand_card_scenes:
		HAND_CARDS.append(_new_card(scene) if scene != null else null)

	if Engine.is_editor_hint():
		queue_redraw()
		return

	cards_in_game = INITIAL_CARDS
	for row_index in range(INITIAL_CARDS.size()):
		for col_index in range(INITIAL_CARDS[row_index].size()):
			var card: Node2D = INITIAL_CARDS[row_index][col_index]
			if card != null:
				add_child(card)
				card.position = _cell_position(Vector2i(col_index, row_index))
	var hand_index := 0
	for card in HAND_CARDS:
		if card != null:
			HAND.add_child(card)
			card.position = HAND.to_local(to_global(_hand_card_position(hand_index)))
			hand_index += 1
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
