@tool
extends RefCounted

const Board = preload("res://game/card_board.gd")
const CARD_SPACING := 0.7
const ARC_RISE := 30.0
const ARC_ANGLE := 0.2
const HOVER_SCALE := 1.2
const HOVER_LIFT := 25.0
const HOVER_SPREAD := 20.0

var container: Node2D
var hand: Node2D
var board: Board
var card_scenes: Array[PackedScene]
var cards: Array
var hovered_card: Node2D
var hand_gap: float
var base_transforms: Dictionary = {}

func _init(card_container: Node2D, hand_node: Node2D, card_board: Board, scenes: Array[PackedScene], hand_cards: Array, gap: float) -> void:
	container = card_container
	hand = hand_node
	board = card_board
	card_scenes = scenes
	cards = hand_cards
	hand_gap = gap

func card_count() -> int:
	if Engine.is_editor_hint():
		return card_scenes.size() - card_scenes.count(null)
	return cards.size() - cards.count(null)

func card_position(index: int) -> Vector2:
	var offset := index - (card_count() - 1) / 2.0
	var curve := _arc_offset(index)
	return Vector2(
		board.center_x() + offset * board.cell_size.x * CARD_SPACING,
		board.origin.y + board.cards.size() * board.cell_size.y + hand_gap - ARC_RISE * (1.0 - curve * curve)
	)

func card_angle(index: int) -> float:
	return _arc_offset(index) * ARC_ANGLE

func _arc_offset(index: int) -> float:
	if card_count() <= 1:
		return 0.0
	return (2.0 * index / (card_count() - 1)) - 1.0

func place_cards(excluded_card: Node2D = null) -> void:
	var index := 0
	var hovered_index := _card_index(hovered_card)
	for card in cards:
		if card != null:
			if card.get_parent() == null:
				hand.add_child(card)
			elif card.get_parent() != hand:
				push_error("Cannot arrange a card outside the hand.")
				continue
			_remember_transform(card)
			if card != excluded_card:
				var position := card_position(index)
				if hovered_index >= 0:
					if index < hovered_index:
						position.x -= HOVER_SPREAD
					elif index > hovered_index:
						position.x += HOVER_SPREAD
					else:
						position.y -= HOVER_LIFT
				card.position = hand.to_local(container.to_global(position))
				_restore_transform(card)
				card.rotation += card_angle(index)
				if card == hovered_card:
					card.scale *= HOVER_SCALE
					card.z_index = _top_z_index() + 1
			index += 1

func _remember_transform(card: Node2D) -> void:
	if not base_transforms.has(card):
		base_transforms[card] = {
			"scale": card.scale,
			"rotation": card.rotation,
			"z_index": card.z_index
		}

func _restore_transform(card: Node2D) -> void:
	if not base_transforms.has(card):
		push_error("Cannot restore a hand card without its original transform.")
		return
	var original: Dictionary = base_transforms[card]
	card.scale = original["scale"]
	card.rotation = original["rotation"]
	card.z_index = original["z_index"]

func _top_z_index() -> int:
	var highest := 0
	for original in base_transforms.values():
		highest = maxi(highest, original["z_index"])
	return highest

func _card_index(target: Node2D) -> int:
	var index := 0
	for card in cards:
		if card != null:
			if card == target:
				return index
			index += 1
	return -1

func card_at(mouse_position: Vector2) -> Node2D:
	if is_instance_valid(hovered_card) and card_contains_point(hovered_card, mouse_position):
		return hovered_card
	var children := hand.get_children()
	children.reverse()
	var selected: Node2D
	for card in children:
		if card is Node2D and cards.has(card) and card_contains_point(card, mouse_position):
			if selected == null or card.z_index > selected.z_index:
				selected = card
	return selected

func card_contains_point(card: Node2D, mouse_position: Vector2) -> bool:
	var sprite := card.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or not sprite.is_visible_in_tree():
		return false
	var local_mouse := sprite.get_global_transform_with_canvas().affine_inverse() * mouse_position
	return sprite.get_rect().has_point(local_mouse)

func set_hovered(card: Node2D) -> void:
	if hovered_card == card:
		return
	hovered_card = card
	place_cards()

func begin_drag(card: Node2D) -> void:
	hovered_card = null
	place_cards(card)
	_restore_transform(card)
	card.z_index = _top_z_index() + 1

func end_drag(card: Node2D) -> void:
	_restore_transform(card)

func remove_card(card: Node2D) -> void:
	if not cards.has(card):
		push_error("Cannot remove a card that is not in the hand.")
		return
	cards.erase(card)
	base_transforms.erase(card)

func return_card(card: Node2D, index: int) -> void:
	card.reparent(hand, false)
	cards.insert(index, card)
	place_cards()

func draw_preview() -> void:
	for index in range(card_count()):
		board.draw_cell(card_position(index), card_angle(index))
