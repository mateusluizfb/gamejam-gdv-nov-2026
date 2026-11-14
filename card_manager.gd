@tool
extends Node2D

const Board = preload("res://card_board.gd")
const Hand = preload("res://card_hand.gd")
const GRID_ORIGIN := Vector2(450, 100)
const HAND_GAP := 40.0

var CARD_SCENE: PackedScene = preload("res://card.tscn")
var board: Board
var hand_layout: Hand
var dragged_card: Node2D
var drag_offset := Vector2.ZERO
var drag_origin := Vector2i(-1, -1)
var drag_from_hand := false

func _ready() -> void:
	var hand_node := get_node_or_null("Hand") as Node2D
	if hand_node == null:
		push_error("Cannot lay out hand cards without a Hand node.")
		set_process_input(false)
		return

	var cell_size := _get_cell_size()
	if cell_size == Vector2.ZERO:
		set_process_input(false)
		return

	board = Board.new(self, _create_initial_cards(), GRID_ORIGIN, cell_size)
	var hand_scenes: Array[PackedScene] = [
		CARD_SCENE, CARD_SCENE, CARD_SCENE, CARD_SCENE, CARD_SCENE, CARD_SCENE
	]
	hand_layout = Hand.new(self, hand_node, board, hand_scenes, _create_hand_cards(hand_scenes), HAND_GAP)
	if Engine.is_editor_hint():
		queue_redraw()
		return
	board.place_cards()
	hand_layout.place_cards()

func _get_cell_size() -> Vector2:
	var sample_card := CARD_SCENE.instantiate()
	var sprite := sample_card.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.get_rect().size.x <= 0 or sprite.get_rect().size.y <= 0:
		sample_card.free()
		push_error("Cannot lay out cards without a Sprite2D with a texture.")
		return Vector2.ZERO
	var size := sprite.get_rect().size * sprite.scale.abs() + Vector2(Board.COLUMN_GAP, Board.ROW_GAP)
	sample_card.free()
	return size

func _create_initial_cards() -> Array:
	return [
		[_new_card(CARD_SCENE), _new_card(CARD_SCENE), _new_card(CARD_SCENE), _new_card(CARD_SCENE)],
		[_new_card(CARD_SCENE), null, null, null],
		[_new_card(CARD_SCENE), null, null, null],
		[_new_card(CARD_SCENE), _new_card(CARD_SCENE), null, null]
	]

func _create_hand_cards(scenes: Array[PackedScene]) -> Array:
	var cards: Array = []
	for scene in scenes:
		cards.append(_new_card(scene) if scene != null else null)
	return cards

func _new_card(scene: PackedScene) -> Node2D:
	if Engine.is_editor_hint():
		return null
	var card := scene.instantiate()
	if not card is Node2D:
		push_error("Card scene '%s' must have a Node2D root." % scene.resource_path)
		card.free()
		return null
	return card

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or board == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventMouseMotion:
		if is_instance_valid(dragged_card):
			_move_drag(event.position)
		else:
			_update_hand_hover(event.position)

func _begin_drag(mouse_position: Vector2) -> void:
	dragged_card = null
	var hovered := hand_layout.hovered_card
	if is_instance_valid(hovered) and hand_layout.card_at(mouse_position) == hovered:
		if _select_card(hovered, mouse_position):
			return
	var children := get_children()
	children.reverse()
	for card in children:
		if card == hand_layout.hand:
			var hand_card := hand_layout.card_at(mouse_position)
			if hand_card != null and _select_card(hand_card, mouse_position):
				return
			continue
		if not card is Node2D:
			continue
		if _select_card(card, mouse_position):
			return

func _select_card(card: Node2D, mouse_position: Vector2) -> bool:
	var sprite := card.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or not sprite.is_visible_in_tree():
		return false
	var sprite_position := sprite.get_global_transform_with_canvas().affine_inverse() * mouse_position
	if not sprite.get_rect().has_point(sprite_position):
		return false
	drag_from_hand = card.get_parent() == hand_layout.hand
	if drag_from_hand:
		if not hand_layout.cards.has(card):
			push_error("Card '%s' is not in the hand." % card.name)
			return false
	else:
		drag_origin = board.find_card_cell(card)
		if drag_origin == Vector2i(-1, -1):
			push_error("Card '%s' is not in the grid." % card.name)
			return false
	var card_position := to_local(card.global_position)
	if drag_from_hand:
		hand_layout.begin_drag(card)
	else:
		hand_layout.set_hovered(null)
	dragged_card = card
	drag_offset = card_position - _mouse_position_in_manager(mouse_position)
	return true

func _move_drag(mouse_position: Vector2) -> void:
	dragged_card.global_position = to_global(_mouse_position_in_manager(mouse_position) + drag_offset)

func _end_drag(mouse_position: Vector2) -> void:
	if is_instance_valid(dragged_card):
		_move_drag(mouse_position)
		var drop_position := to_local(dragged_card.global_position)
		if drag_from_hand:
			hand_layout.end_drag(dragged_card)
			if board.try_add_card(dragged_card, drop_position):
				hand_layout.remove_card(dragged_card)
			hand_layout.place_cards()
		elif hand_layout.contains_drop(drop_position) and board.remove_card(dragged_card, drag_origin):
			hand_layout.add_card(dragged_card, drop_position)
			hand_layout.place_cards()
		else:
			dragged_card.position = board.cell_position(drag_origin)
	dragged_card = null
	_update_hand_hover(mouse_position)

func _update_hand_hover(mouse_position: Vector2) -> void:
	hand_layout.set_hovered(hand_layout.card_at(mouse_position))

func _mouse_position_in_manager(mouse_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * mouse_position

func _draw() -> void:
	if Engine.is_editor_hint() and board != null and hand_layout != null:
		board.draw_preview()
		hand_layout.draw_preview()
