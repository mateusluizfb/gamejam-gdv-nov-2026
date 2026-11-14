extends SceneTree

var failed := false

func _initialize() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	var hand := scene.get_node("CardManager/Hand") as Node2D
	hand.position = Vector2(20, 10)
	hand.scale = Vector2(0.9, 1.1)
	root.add_child.call_deferred(scene)
	_test_transfers.call_deferred(scene)

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func _button(manager: Node, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	manager._input(event)

func _motion(manager: Node, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	manager._input(event)

func _hover(manager: Node, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	manager._input(event)

func _drag(manager: Node2D, card: Node2D, destination: Vector2) -> void:
	var transform := manager.get_global_transform_with_canvas()
	var offset := Vector2(6, 4)
	var start := manager.to_local(card.global_position)
	_button(manager, transform * (start + offset), true)
	_motion(manager, transform * (destination + offset))
	_button(manager, transform * (destination + offset), false)
	_hover(manager, Vector2.ZERO)

func _check_hand_layout(manager: Node2D) -> void:
	var layout = manager.hand_layout
	var index := 0
	for card in layout.cards:
		if card != null:
			_check(card.get_parent() == layout.hand, "Hand card has the wrong parent.")
			_check(manager.to_local(card.global_position).is_equal_approx(layout.card_position(index)), "Hand card is not in its centered position.")
			index += 1
	_check(index == layout.card_count() and layout.hand.get_child_count() == index, "Hand card count is inconsistent.")

func _test_transfers(scene: Node) -> void:
	var manager := scene.get_node("CardManager") as Node2D
	var board = manager.board
	var hand = manager.hand_layout
	manager.position = Vector2(30, 40)
	manager.scale = Vector2(1.5, 1.5)
	_check(hand.card_count() == 6, "Initial hand does not contain six cards.")
	_check_hand_layout(manager)
	_test_hover(manager)

	var source := Vector2i(0, 0)
	var empty := Vector2i(1, 1)
	var grid_card: Node2D = board.cards[source.y][source.x]
	var empty_position: Vector2 = board.cell_position(empty)
	_drag(manager, grid_card, empty_position)
	_check(board.cards[source.y][source.x] == grid_card and board.cards[empty.y][empty.x] == null, "Grid card moved to another grid cell.")
	_check(grid_card.position.is_equal_approx(board.cell_position(source)), "Grid card did not return to its source.")
	var other_grid_card: Node2D = board.cards[0][1]
	_drag(manager, grid_card, board.cell_position(Vector2i(1, 0)))
	_check(board.cards[0][0] == grid_card and board.cards[0][1] == other_grid_card, "Grid-to-grid drop changed occupied cells.")
	_drag(manager, grid_card, Vector2.ZERO)
	_check(board.cards[source.y][source.x] == grid_card and grid_card.position.is_equal_approx(board.cell_position(source)), "Outside drop removed a grid card.")

	var hand_card: Node2D = hand.cards[0]
	var occupied_position: Vector2 = board.cell_position(source)
	_drag(manager, hand_card, occupied_position)
	_check(hand.cards[0] == hand_card and hand.card_count() == 6 and board.cards[source.y][source.x] == grid_card, "Occupied grid drop changed a card.")
	_check_hand_layout(manager)
	_drag(manager, hand_card, Vector2.ZERO)
	_check(hand.cards[0] == hand_card and hand.card_count() == 6, "Outside drop removed a hand card.")
	_check_hand_layout(manager)

	_drag(manager, hand_card, empty_position + Vector2(8, 6))
	_check(board.cards[empty.y][empty.x] == hand_card and hand_card.get_parent() == manager, "Hand card did not enter the empty grid cell.")
	_check(hand_card.position.is_equal_approx(empty_position) and hand.card_count() == 5, "Hand-to-grid transfer did not snap or update the hand.")
	_check_hand_layout(manager)
	_drag(manager, hand_card, board.cell_position(Vector2i(2, 1)))
	_check(board.cards[empty.y][empty.x] == hand_card and board.cards[1][2] == null, "Transferred card moved between grid cells.")

	var hand_y: float = board.origin.y + board.cards.size() * board.cell_size.y
	var left_drop := Vector2(board.center_x() - 2.4 * board.cell_size.x, hand_y)
	_drag(manager, hand_card, left_drop)
	_check(board.cards[empty.y][empty.x] == null and hand.cards[0] == hand_card, "Grid card was not inserted at the left of the hand.")
	_check_hand_layout(manager)

	var right_drop := Vector2(board.center_x() + 2.9 * board.cell_size.x, hand_y)
	_drag(manager, grid_card, right_drop)
	_check(board.cards[source.y][source.x] == null and hand.cards[-1] == grid_card, "Grid card was not inserted at the right of the hand.")
	_check_hand_layout(manager)

	var first_hand: Node2D = hand.cards[0]
	var left_edge: float = board.origin.x - board.cell_size.x / 2.0
	_drag(manager, first_hand, Vector2(left_edge - 0.01, board.origin.y))
	_check(hand.cards[0] == first_hand and board.cards[0][0] == null, "Drop outside the grid was accepted.")
	_drag(manager, first_hand, Vector2(left_edge + 0.01, board.origin.y))
	_check(board.cards[0][0] == first_hand and first_hand.position.is_equal_approx(board.cell_position(source)), "Drop inside the grid edge was not accepted.")
	_check_hand_layout(manager)

	var middle_card: Node2D = board.cards[0][1]
	_drag(manager, middle_card, Vector2(board.center_x(), hand_y))
	_check(board.cards[0][1] == null and hand.cards[3] == middle_card, "Grid card was not inserted at the middle of the hand.")
	_check_hand_layout(manager)

	_test_empty_hand()
	if not failed:
		print("Card transfer checks passed.")
	quit(1 if failed else 0)

func _test_empty_hand() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var manager := scene.get_node("CardManager") as Node2D
	var board = manager.board
	var hand = manager.hand_layout
	for row in range(board.cards.size()):
		for col in range(board.cards[row].size()):
			if board.cards[row][col] == null and hand.card_count() > 0:
				var card: Node2D = hand.cards[0]
				_drag(manager, card, board.cell_position(Vector2i(col, row)))
	_check(hand.card_count() == 0, "Could not move all hand cards to empty grid cells.")
	var card: Node2D = board.cards[0][0]
	var drop := Vector2(board.center_x(), board.origin.y + board.cards.size() * board.cell_size.y)
	_drag(manager, card, drop)
	_check(board.cards[0][0] == null and hand.card_count() == 1 and hand.cards[0] == card, "An empty hand did not accept a grid card.")
	_check_hand_layout(manager)
	scene.free()

func _test_hover(manager: Node2D) -> void:
	var hand = manager.hand_layout
	var left: Node2D = hand.cards[1]
	var selected: Node2D = hand.cards[2]
	var right: Node2D = hand.cards[3]
	var left_start := manager.to_local(left.global_position)
	var selected_start := manager.to_local(selected.global_position)
	var right_start := manager.to_local(right.global_position)
	var original_scale := selected.scale
	_hover(manager, selected.get_global_transform_with_canvas() * Vector2.ZERO)
	_check(hand.hovered_card == selected, "Hover did not select the hand card.")
	_check(selected.scale.is_equal_approx(original_scale * 1.2), "Hovered card did not grow.")
	_check(selected.z_index > left.z_index and selected.z_index > right.z_index, "Hovered card is not above its neighbors.")
	_check(manager.to_local(left.global_position).x < left_start.x and manager.to_local(right.global_position).x > right_start.x, "Hover did not move neighbors aside.")
	_check(manager.to_local(selected.global_position).y < selected_start.y, "Hovered card was not raised.")
	var highlighted_center := selected.global_position
	var click := selected.get_global_transform_with_canvas() * Vector2.ZERO
	_button(manager, click, true)
	_check(manager.dragged_card == selected and selected.global_position.is_equal_approx(highlighted_center), "Starting a drag moved or selected the wrong hovered card.")
	_check(selected.scale.is_equal_approx(original_scale) and is_zero_approx(selected.rotation), "Dragging did not restore the card transform.")
	var occupied: Vector2 = manager.board.cell_position(Vector2i(0, 0))
	_button(manager, manager.get_global_transform_with_canvas() * occupied, false)
	_hover(manager, Vector2.ZERO)
	_check(hand.hovered_card == null and selected.get_parent() == hand.hand, "Rejected drag did not restore the hand.")
	_check_hand_layout(manager)
