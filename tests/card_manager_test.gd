extends SceneTree

var failed := false

func _initialize() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	var hand := scene.get_node("CardManager/Hand") as Node2D
	hand.position = Vector2(20, 10)
	root.add_child.call_deferred(scene)
	_test_drops.call_deferred(scene)

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

func _test_drops(scene: Node) -> void:
	var manager := scene.get_node("CardManager") as Node2D
	var hand := manager.get_node("Hand") as Node2D
	_check(manager.HAND_CARDS.size() == 6 and hand.get_child_count() == 4, "Hand did not create its occupied slots.")
	var hand_index := 0
	for col in range(manager.HAND_CARDS.size()):
		var hand_card: Node2D = manager.HAND_CARDS[col]
		if col == 3 or col == 5:
			_check(hand_card == null, "Empty hand slot contains a card.")
		else:
			_check(hand_card != null and hand_card.get_parent() == hand, "Hand card has the wrong parent.")
			if hand_card != null:
				_check(manager.to_local(hand_card.global_position).is_equal_approx(manager._hand_card_position(hand_index)), "Hand card does not match its centered position.")
				hand_index += 1
	var first_hand: Vector2 = manager.to_local(manager.HAND_CARDS[0].global_position)
	var last_hand: Vector2 = manager.to_local(manager.HAND_CARDS[4].global_position)
	var grid_center: Vector2 = (manager._cell_position(Vector2i(0, 0)) + manager._cell_position(Vector2i(3, 0))) / 2.0
	_check(is_equal_approx((first_hand.x + last_hand.x) / 2.0, grid_center.x), "Hand is not centered under the grid.")
	_check(is_equal_approx(last_hand.x - first_hand.x, 3 * manager.cell_size.x), "Empty hand slots leave gaps between cards.")
	manager.hand_card_scenes.append(manager.CARD_SCENE)
	var middle_hand: Vector2 = manager._hand_card_position(2)
	_check(is_equal_approx(middle_hand.x, grid_center.x), "An odd number of hand cards is not centered under the grid.")
	manager.hand_card_scenes.pop_back()
	_check(manager.INITIAL_CARDS[0][0] is Node2D and manager.INITIAL_CARDS[1][1] == null, "Initial grid does not contain card instances and empty slots.")
	manager.position = Vector2(30, 40)
	manager.scale = Vector2(1.5, 1.5)
	var card: Node2D = manager.cards_in_game[0][0]
	var occupied: Node2D = manager.cards_in_game[0][1]
	var transform := manager.get_global_transform_with_canvas()
	var click_offset := Vector2(10, 5)
	var start: Vector2 = manager._cell_position(Vector2i(0, 0))
	var empty: Vector2 = manager._cell_position(Vector2i(1, 1))

	_button(manager, transform * (start + click_offset), true)
	_motion(manager, transform * (empty + click_offset + Vector2(8, 6)))
	_check(manager.cards_in_game[0][0] == card and manager.cards_in_game[1][1] == null, "Grid changed before release.")
	_button(manager, transform * (empty + click_offset + Vector2(8, 6)), false)
	_check(card.position.is_equal_approx(empty), "Card did not snap to the empty cell.")
	_check(manager.cards_in_game[0][0] == null and manager.cards_in_game[1][1] == card, "Grid did not update after a valid drop.")

	_button(manager, transform * (empty + click_offset), true)
	_button(manager, transform * (occupied.position + click_offset), false)
	_check(card.position.is_equal_approx(empty), "Card did not return after an occupied drop.")
	_check(manager.cards_in_game[1][1] == card and manager.cards_in_game[0][1] == occupied, "Occupied drop changed the grid.")

	var left_edge: float = manager.GRID_ORIGIN.x - manager.cell_size.x / 2.0
	var outside := Vector2(left_edge - 0.01, manager.GRID_ORIGIN.y)
	_button(manager, transform * (empty + click_offset), true)
	_button(manager, transform * (outside + click_offset), false)
	_check(card.position.is_equal_approx(empty) and manager.cards_in_game[1][1] == card, "Outside drop did not return the card.")

	var inside := Vector2(left_edge + 0.01, manager.GRID_ORIGIN.y)
	_button(manager, transform * (empty + click_offset), true)
	_button(manager, transform * (inside + click_offset), false)
	_check(card.position.is_equal_approx(start), "Drop just inside the grid did not snap to the edge cell.")
	_check(manager.cards_in_game[0][0] == card and manager.cards_in_game[1][1] == null, "Edge drop did not update the grid.")

	var last: Vector2 = manager._cell_position(Vector2i(3, 3))
	var far_edge: Vector2 = manager.GRID_ORIGIN + manager.cell_size * 3.5
	_button(manager, transform * (start + click_offset), true)
	_button(manager, transform * (far_edge - Vector2(0.01, 0.01) + click_offset), false)
	_check(card.position.is_equal_approx(last) and manager.cards_in_game[3][3] == card, "Drop inside the far corner did not snap to the last cell.")
	var outside_positions := [
		Vector2(far_edge.x + 0.01, last.y),
		Vector2(last.x, far_edge.y + 0.01),
		Vector2(last.x, manager.GRID_ORIGIN.y - manager.cell_size.y / 2.0 - 0.01),
	]
	for outside_position in outside_positions:
		_button(manager, transform * (last + click_offset), true)
		_button(manager, transform * (outside_position + click_offset), false)
		_check(card.position.is_equal_approx(last) and manager.cards_in_game[3][3] == card, "Outside drop changed the last cell.")

	if not failed:
		print("Card drop checks passed.")
	quit(1 if failed else 0)
