extends SceneTree

const CardData = preload("res://cards/card_data.gd")
const GameState = preload("res://game/game_state.gd")

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func _card(type: CardData.Type, hp: int = 10) -> CardData:
	var owner := CardData.Owner.ENEMY if type == CardData.Type.ELEPHANT else CardData.Owner.PLAYER
	return CardData.new(type, owner, hp, "")

func _record(card: CardData, cell: Variant = null) -> Dictionary:
	return {"card": card, "cell": cell}

func _resolve(state: GameState) -> void:
	state.resolve_effect(state.effect_token)

func _test_effects() -> void:
	var axe := _card(CardData.Type.AXE)
	var spear := _card(CardData.Type.SPEAR)
	var trap := _card(CardData.Type.TRAP)
	var magic := _card(CardData.Type.MAGIC)
	var magic2 := _card(CardData.Type.MAGIC)
	var first := _card(CardData.Type.ELEPHANT, 2)
	var second := _card(CardData.Type.ELEPHANT, 5)
	var third := _card(CardData.Type.ELEPHANT, 20)
	var fourth := _card(CardData.Type.ELEPHANT, 10)
	var state := GameState.new([
		_record(first, Vector2i(0, 0)), _record(second, Vector2i(1, 0)),
		_record(third, Vector2i(1, 1)), _record(fourth, Vector2i(2, 0)),
		_record(magic), _record(magic2), _record(axe), _record(spear), _record(trap)
	])
	_check(state.play_card(magic, Vector2i(0, 2)), "First Magic should be playable.")
	_check(state.damage_bonus == 0, "Magic should not apply before resolution.")
	_resolve(state)
	_check(state.damage_bonus == 2, "Magic should add +2.")
	_check(state.play_card(magic2, Vector2i(1, 2)), "Second Magic should be playable.")
	_resolve(state)
	_check(state.damage_bonus == 4, "Magic should stack through another Magic.")
	_check(state.play_card(axe, Vector2i(2, 2)), "Axe should be playable.")
	_check(state.phase == GameState.Phase.TARGETING and state.pending_damage == 8, "Upper Axe should use 4 damage plus stacked bonus.")
	_check(state.select_target(first), "First Axe target should be selectable.")
	_resolve(state)
	_check(first.current_hp == -6 and first.board_position == null, "Overkill HP should remain negative and the target be removed.")
	_check(state.phase == GameState.Phase.TARGETING and state.pending_damage == 8, "A kill should request a follow-up with the same damage.")
	_check(state.select_target(second), "Second Axe target should be selectable.")
	_resolve(state)
	_check(second.current_hp == -3 and state.phase == GameState.Phase.TARGETING, "Successive kills should allow another attack.")
	_check(state.select_target(third), "Third Axe target should be selectable.")
	_resolve(state)
	_check(third.current_hp == 12 and state.phase == GameState.Phase.IDLE and axe.board_position == Vector2i(2, 2), "A surviving target should end the Axe chain.")
	_check(state.damage_bonus == 0 and not state.play_card(axe, Vector2i(3, 2)), "A played Axe must not be replayed and the bonus must be consumed.")

	_check(state.play_card(spear, Vector2i(0, 3)) and state.pending_damage == 2, "Bottom Spear should deal 2.")
	_check(state.select_target(third), "Spear should select an enemy.")
	_resolve(state)
	_check(third.current_hp == 10 and third.board_position == Vector2i(1, 0), "Spear should damage then move its surviving target.")
	_check(state.play_card(trap, Vector2i(3, 0)), "Trap should be playable in an empty enemy-row cell.")
	_resolve(state)
	_check(third.current_hp == 5 and fourth.current_hp == 5, "Trap should damage every enemy in the selected row.")
	_check(trap.board_position == null and state.board[0][3] == null, "Trap should be removed after resolving.")

func _test_cancellation_and_rows() -> void:
	var axe := _card(CardData.Type.AXE)
	var spear := _card(CardData.Type.SPEAR)
	var target := _card(CardData.Type.ELEPHANT, 10)
	var blocking := _card(CardData.Type.ELEPHANT, 10)
	var state := GameState.new([_record(target, Vector2i(0, 0)), _record(blocking, Vector2i(0, 1)), _record(axe), _record(spear)])
	state.damage_bonus = 2
	_check(not state.play_card(axe, Vector2i(2, 0)), "Axe cannot be played in an enemy row.")
	_check(state.play_card(axe, Vector2i(0, 3)) and state.pending_damage == 4, "Bottom Axe should deal 2 plus its bonus.")
	_check(state.select_target(target), "Enemy should be selectable.")
	var old_token := state.effect_token
	_check(state.cancel_play(), "Escape before resolution should cancel the play.")
	_check(state.player.hand[0] == axe and axe.board_position == null and state.damage_bonus == 2, "Canceled card and bonus should be restored.")
	state.resolve_effect(old_token)
	_check(target.current_hp == 10, "A canceled delayed effect must not fire.")
	_check(state.play_card(spear, Vector2i(0, 2)) and state.pending_damage == 3, "Upper Spear should deal 1 plus bonus.")
	_check(state.select_target(target), "Spear target should be selectable.")
	_resolve(state)
	_check(target.current_hp == 7 and target.board_position == Vector2i(1, 1), "Spear should move to a nearby free cell if its column is occupied.")

	var dead_target := _card(CardData.Type.ELEPHANT, 1)
	var killing_spear := _card(CardData.Type.SPEAR)
	var dead_state := GameState.new([_record(dead_target, Vector2i(0, 0)), _record(killing_spear)])
	_check(dead_state.play_card(killing_spear, Vector2i(0, 2)) and dead_state.select_target(dead_target), "Killing Spear should be playable.")
	_resolve(dead_state)
	_check(dead_target.current_hp == 0 and dead_target.board_position == null, "A killed Spear target should not move.")

	var lonely_axe := _card(CardData.Type.AXE)
	var empty_state := GameState.new([_record(lonely_axe)])
	_check(not empty_state.play_card(lonely_axe, Vector2i(0, 2)) and empty_state.player.hand.has(lonely_axe), "Targeted plays without enemies should remain in hand.")
	_check(not empty_state.can_play_card(lonely_axe, Vector2i(0, 2)), "Targeted plays without enemies should not show a valid destination.")

	var last_axe := _card(CardData.Type.AXE)
	var last_enemy := _card(CardData.Type.ELEPHANT, 1)
	var last_state := GameState.new([_record(last_enemy, Vector2i(0, 0)), _record(last_axe)])
	last_state.play_card(last_axe, Vector2i(0, 2))
	last_state.select_target(last_enemy)
	_resolve(last_state)
	_check(last_state.phase == GameState.Phase.IDLE and last_state.board[0][0] == null, "Axe chain should end when all enemies are dead.")

	var chain_axe := _card(CardData.Type.AXE)
	var killed := _card(CardData.Type.ELEPHANT, 1)
	var killed_again := _card(CardData.Type.ELEPHANT, 2)
	var survivor := _card(CardData.Type.ELEPHANT)
	var chain_state := GameState.new([_record(killed, Vector2i(0, 0)), _record(killed_again, Vector2i(1, 0)), _record(survivor, Vector2i(2, 0)), _record(chain_axe)])
	chain_state.damage_bonus = 2
	chain_state.play_card(chain_axe, Vector2i(0, 2))
	chain_state.select_target(killed)
	_resolve(chain_state)
	chain_state.select_target(killed_again)
	_resolve(chain_state)
	_check(chain_state.cancel_play(), "Escape should cancel an Axe chain.")
	_check(killed.current_hp == 1 and chain_state.board[0][0] == killed and killed_again.current_hp == 2 and chain_state.board[0][1] == killed_again and chain_state.damage_bonus == 2 and chain_state.player.hand.has(chain_axe), "Canceling an Axe chain should undo every attack and restore its bonus.")

func _test_trap_bonus_and_full_row() -> void:
	var magic := _card(CardData.Type.MAGIC)
	var trap := _card(CardData.Type.TRAP)
	var first := _card(CardData.Type.ELEPHANT, 10)
	var second := _card(CardData.Type.ELEPHANT, 10)
	var state := GameState.new([_record(first, Vector2i(0, 0)), _record(second, Vector2i(1, 0)), _record(magic), _record(trap)])
	state.play_card(magic, Vector2i(0, 2))
	_resolve(state)
	_check(not state.play_card(trap, Vector2i(1, 2)), "Trap should not be placed in a player row.")
	_check(state.play_card(trap, Vector2i(2, 0)), "Trap should select an enemy row.")
	_resolve(state)
	_check(first.current_hp == 3 and second.current_hp == 3 and state.damage_bonus == 0, "Magic should add 2 to every Trap hit and be consumed.")

	var target := _card(CardData.Type.ELEPHANT)
	var spear := _card(CardData.Type.SPEAR)
	var records: Array = [_record(target, Vector2i(0, 0)), _record(spear)]
	for col in range(4):
		records.append(_record(_card(CardData.Type.ELEPHANT), Vector2i(col, 1)))
	var full_state := GameState.new(records)
	full_state.play_card(spear, Vector2i(0, 2))
	full_state.select_target(target)
	_resolve(full_state)
	_check(target.current_hp == 9 and target.board_position == Vector2i(0, 0), "Target should remain in place when the other row is full.")

func _button(manager: Node, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	manager._input(event)

func _drag(manager: Node2D, card: Node2D, destination: Vector2) -> void:
	var transform := manager.get_global_transform_with_canvas()
	var offset := Vector2(6, 4)
	var start := manager.to_local(card.global_position)
	_button(manager, transform * (start + offset), true)
	_button(manager, transform * (destination + offset), false)

func _click_card(manager: Node2D, card: Node2D) -> void:
	var position := card.get_global_transform_with_canvas() * Vector2.ZERO
	_button(manager, position, true)
	_button(manager, position, false)

func _motion(manager: Node, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	manager._input(event)

func _escape(manager: Node) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	manager._input(event)

func _test_row_highlight() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	var hand_node := scene.get_node("CardManager/Hand") as Node2D
	hand_node.position = Vector2(20, 10)
	hand_node.scale = Vector2(0.9, 1.1)
	root.add_child(scene)
	var manager := scene.get_node("CardManager") as Node2D
	manager.position = Vector2(30, 40)
	manager.scale = Vector2(1.5, 1.5)
	var transform := manager.get_global_transform_with_canvas()
	var offset := Vector2(6, 4)
	var axe: Node2D = manager.hand_layout.cards[0]
	_button(manager, transform * (manager.to_local(axe.global_position) + offset), true)
	_motion(manager, transform * (manager.board.cell_position(Vector2i(1, 2)) + offset))
	_check(manager.highlighted_row == 2, "A valid upper player row should be highlighted.")
	_motion(manager, transform * (manager.board.cell_position(Vector2i(2, 3)) + offset))
	_check(manager.highlighted_row == 3, "The highlight should follow the dragged card to the bottom row.")
	_motion(manager, transform * (manager.board.cell_position(Vector2i(2, 0)) + offset))
	_check(manager.highlighted_row == -1, "An Axe cannot highlight an enemy row.")
	_motion(manager, transform * (Vector2.ZERO + offset))
	_check(manager.highlighted_row == -1, "Dragging outside the grid should clear the highlight.")
	_motion(manager, transform * (manager.board.cell_position(Vector2i(0, 2)) + offset))
	_escape(manager)
	_check(manager.highlighted_row == -1 and manager.state.player.hand.has(axe.data), "Canceling a drag should clear the highlight.")

	var trap: Node2D = manager.hand_layout.cards[-1]
	_button(manager, transform * (manager.to_local(trap.global_position) + offset), true)
	_motion(manager, transform * (manager.board.cell_position(Vector2i(0, 0)) + offset))
	_check(manager.highlighted_row == -1, "An occupied enemy cell should not be highlighted.")
	_motion(manager, transform * (manager.board.cell_position(Vector2i(2, 0)) + offset))
	_check(manager.highlighted_row == 0, "A Trap should highlight its target enemy row.")
	_motion(manager, transform * (manager.board.cell_position(Vector2i(0, 1)) + offset))
	_check(manager.highlighted_row == 1, "A Trap should highlight the other enemy row when moved there.")
	_motion(manager, transform * (manager.board.cell_position(Vector2i(0, 2)) + offset))
	_check(manager.highlighted_row == -1, "A Trap cannot highlight a player row.")
	_motion(manager, transform * (manager.board.cell_position(Vector2i(2, 0)) + offset))
	_button(manager, transform * (manager.board.cell_position(Vector2i(2, 0)) + offset), false)
	_check(manager.highlighted_row == -1 and manager.state.board[0][2] == trap.data, "Dropping should clear the highlight and play the card.")
	scene.free()

func _test_ui() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	var hand_node := scene.get_node("CardManager/Hand") as Node2D
	hand_node.position = Vector2(20, 10)
	hand_node.scale = Vector2(0.9, 1.1)
	root.add_child(scene)
	var manager := scene.get_node("CardManager") as Node2D
	manager.position = Vector2(30, 40)
	manager.scale = Vector2(1.5, 1.5)
	var state = manager.state
	var board = manager.board
	var axe: Node2D = manager.hand_layout.cards[0]
	var first: Node2D = manager.card_views[state.board[0][0]]
	var first_data: CardData = first.data
	_drag(manager, axe, board.cell_position(Vector2i(1, 2)))
	_check(state.phase == GameState.Phase.TARGETING and first_data.current_hp == 10, "Placement should wait for a target without neighbor damage.")
	_motion(manager, first.get_global_transform_with_canvas() * Vector2.ZERO)
	_check(manager._enemy_at(first.get_global_transform_with_canvas() * Vector2.ZERO) == first_data, "Hover should identify the enemy under the cursor.")
	_motion(manager, Vector2.ZERO)
	_check(manager._enemy_at(Vector2.ZERO) == null, "Hover outside the board should not target an enemy.")
	_escape(manager)
	_check(state.player.hand[0] == axe.data and axe.get_parent() == hand_node and state.board[2][1] == null, "Escape should return an uncommitted card to its original hand position.")
	state.set_card_hp(first_data, 1)
	_drag(manager, axe, board.cell_position(Vector2i(1, 2)))
	_click_card(manager, first)
	await create_timer(0.6).timeout
	_check(first_data.board_position == null and state.phase == GameState.Phase.TARGETING, "Axe kill should request another target.")
	_escape(manager)
	_check(state.board[0][0] == first_data and first_data.current_hp == 1 and manager.card_views.has(first_data) and state.player.hand.has(axe.data), "Canceling an Axe chain should restore the enemy view and hand card.")
	first = manager.card_views[first_data]
	state.set_card_hp(first_data, 10)
	_drag(manager, axe, board.cell_position(Vector2i(1, 2)))
	_click_card(manager, first)
	_check(state.phase == GameState.Phase.RESOLVING, "Click should select the enemy.")
	await create_timer(0.25).timeout
	_check(first_data.current_hp == 10, "Damage must not apply before the 0.5-second delay.")
	await create_timer(0.35).timeout
	_check(first_data.current_hp == 6 and state.phase == GameState.Phase.IDLE, "Axe damage should apply after the delay.")
	_check(scene.get_node("HUD/EffectMessage").text.contains("4 de dano"), "Damage should be displayed.")
	_drag(manager, axe, board.cell_position(Vector2i(0, 3)))
	_check(state.board[2][1] == axe.data, "A played card should not be draggable again.")

	var spear_in_hand: Node2D = manager.hand_layout.cards[0]
	var transform := manager.get_global_transform_with_canvas()
	var offset := Vector2(6, 4)
	_button(manager, transform * (manager.to_local(spear_in_hand.global_position) + offset), true)
	_motion(manager, transform * (board.cell_position(Vector2i(1, 2)) + offset))
	_check(manager.highlighted_row == -1, "An occupied player cell should not show a valid row.")
	_motion(manager, transform * (board.cell_position(Vector2i(0, 2)) + offset))
	_check(manager.highlighted_row == 2, "A free player cell should highlight its row.")
	_escape(manager)

	var magic: Node2D = manager.hand_layout.cards[1]
	_drag(manager, magic, board.cell_position(Vector2i(2, 3)))
	_escape(manager)
	await create_timer(0.6).timeout
	_check(state.damage_bonus == 0 and state.player.hand.has(magic.data), "Canceling Magic should prevent its delayed buff.")
	_drag(manager, magic, board.cell_position(Vector2i(2, 3)))
	await create_timer(0.6).timeout
	_check(state.damage_bonus == 2, "Magic should apply after its delay.")
	for card in state.player.hand:
		var view: Node2D = manager.card_views[card]
		_check(view.get_node("Bonus").visible and view.get_node("Bonus").text == "+2 DANO", "Every hand card should show the Magic bonus.")
	_check(scene.get_node("HUD/EffectMessage").text.contains("+2"), "Magic buff should be displayed.")

	var trap: Node2D = manager.hand_layout.cards[-1]
	var trap_data: CardData = trap.data
	var other_enemy: CardData = state.board[0][1]
	_drag(manager, trap, board.cell_position(Vector2i(2, 0)))
	_check(trap_data.board_position == Vector2i(2, 0), "Trap should temporarily occupy the selected enemy row.")
	_escape(manager)
	await create_timer(0.6).timeout
	_check(state.damage_bonus == 2 and first_data.current_hp == 6 and state.player.hand.has(trap_data), "Canceling Trap should preserve enemies and the buff.")
	_drag(manager, trap, board.cell_position(Vector2i(2, 0)))
	await create_timer(0.6).timeout
	_check(first_data.current_hp == -1 and other_enemy.current_hp == 3, "Buffed Trap should damage all targets in its row.")
	_check(trap_data.board_position == null and not manager.card_views.has(trap_data) and state.damage_bonus == 0, "Resolved Trap should disappear and consume its buff.")
	_check(scene.get_node("HUD/EffectMessage").text.contains("7 de dano"), "Trap damage should be displayed.")
	scene.free()

	var spear_scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(spear_scene)
	var spear_manager := spear_scene.get_node("CardManager") as Node2D
	var spear_state = spear_manager.state
	var spear_board = spear_manager.board
	var spear: Node2D = spear_manager.hand_layout.cards[1]
	var target: CardData = spear_state.board[1][1]
	var target_view: Node2D = spear_manager.card_views[target]
	_drag(spear_manager, spear, spear_board.cell_position(Vector2i(0, 2)))
	_click_card(spear_manager, target_view)
	await create_timer(0.6).timeout
	_check(target.current_hp == 12 and target.board_position == Vector2i(2, 0), "Spear should damage and move the target to a free neighboring column.")
	_check(spear_board.cards[0][2] == target_view and target_view.position.is_equal_approx(spear_board.cell_position(Vector2i(2, 0))), "Spear should move the target's board view.")
	spear_scene.free()

	var layout_scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(layout_scene)
	var layout_manager := layout_scene.get_node("CardManager") as Node2D
	var layout_magic: Node2D = layout_manager.hand_layout.cards[2]
	_check(layout_manager.state.play_card(layout_magic.data, Vector2i(0, 3)), "Programmatic Magic play should be accepted.")
	_check(is_zero_approx(layout_magic.rotation), "A programmatically played card should not retain hand rotation.")
	var hand_index := 0
	for view in layout_manager.hand_layout.cards:
		_check(layout_manager.to_local(view.global_position).is_equal_approx(layout_manager.hand_layout.card_position(hand_index)), "Hand should relayout after a programmatic play.")
		hand_index += 1
	layout_scene.free()

func _test_restart() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var manager := scene.get_node("CardManager") as Node2D
	var old_state = manager.state
	var hint := scene.get_node("HUD/RestartHint") as Label
	_check(hint.visible and hint.text == "Pressione R para reiniciar" and hint.anchor_right == 1.0, "Restart hint should appear at the top right.")
	var hint_rect := hint.get_global_rect()
	var viewport_size := root.get_visible_rect().size
	_check(hint_rect.position.x > viewport_size.x / 2.0 and hint_rect.end.x <= viewport_size.x and hint_rect.position.y >= 0.0, "Restart hint should be visible in the top-right portion of the viewport.")
	old_state.set_card_hp(old_state.board[0][0], 3)
	var magic: CardData = old_state.player.hand[2]
	_check(old_state.play_card(magic, Vector2i(0, 3)), "Magic should start before restart.")
	var event := InputEventKey.new()
	event.keycode = KEY_R
	event.pressed = true
	event.echo = true
	manager._input(event)
	_check(current_scene == scene, "Repeated key events should not restart the game.")
	event.echo = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	_check(current_scene != scene, "Pressing R should reload the scene.")
	if current_scene == null or current_scene == scene:
		return
	var restarted = current_scene.get_node("CardManager").state
	_check(restarted.board[0][0].current_hp == 10 and restarted.player.hand.size() == 4 and restarted.damage_bonus == 0, "Restart should restore the starting state.")
	await create_timer(0.6).timeout
	_check(restarted.damage_bonus == 0 and old_state.damage_bonus == 0, "Pending effects should not resolve after restart.")
	current_scene.free()
	current_scene = null

func _test_tooltips() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	var manager := scene.get_node("CardManager") as Node2D
	var tooltip = scene.get_node("HUD/CardTooltip")
	var text := tooltip.get_node("Margin/Text") as RichTextLabel
	var axe: Node2D = manager.hand_layout.cards[0]
	var spear: Node2D = manager.hand_layout.cards[1]
	var magic: Node2D = manager.hand_layout.cards[2]
	var trap: Node2D = manager.hand_layout.cards[3]
	var enemy: Node2D = manager.card_views[manager.state.board[0][0]]

	_motion(manager, axe.get_global_transform_with_canvas() * Vector2.ZERO)
	_check(not tooltip.visible, "Tooltip must wait before appearing.")
	await create_timer(0.15).timeout
	_motion(manager, spear.get_global_transform_with_canvas() * Vector2.ZERO)
	await create_timer(0.2).timeout
	_check(not tooltip.visible, "Changing cards should restart the tooltip delay.")
	await create_timer(0.15).timeout
	_check(tooltip.visible and text.text.contains("Lança"), "Hovering a hand card should show its tooltip after the delay.")
	_check(text.text.contains("]1[/color] (linha 3)") and text.text.contains("]2[/color] (linha 4)"), "Spear tooltip should show both row damage values.")

	manager.state.damage_bonus = 2
	manager.state.changed.emit()
	await process_frame
	await process_frame
	_check(text.text.contains("]3[/color] (linha 3)") and text.text.contains("]4[/color] (linha 4)") and text.text.contains("Bônus de magia"), "An open tooltip should update damage and bonus when Magic changes.")
	_check(text.get_content_height() <= text.size.y, "Tooltip text must fit without clipping.")
	_check(tooltip._description(axe.data, 2).contains("]6[/color] (linha 3)") and tooltip._description(axe.data, 2).contains("]4[/color] (linha 4)"), "Axe tooltip should include its bonus on both rows.")
	_check(tooltip._description(trap.data, 2).contains("]7[/color] de dano"), "Trap tooltip should include the active bonus.")
	_check(tooltip._description(magic.data, 2).contains("Bônus acumulam"), "Magic tooltip should explain stacking.")

	manager.state.damage_bonus = 100
	manager.state.changed.emit()
	await process_frame
	var badge := spear.get_node("Bonus") as Label
	_check(badge.text == "+100 DANO" and badge.size.x <= spear.get_node("BonusBackground").size.x, "Large stacked bonuses should fit their localized badge.")
	manager.state.damage_bonus = 2
	manager.state.changed.emit()

	_button(manager, spear.get_global_transform_with_canvas() * Vector2.ZERO, true)
	_check(not tooltip.visible and tooltip.hovered_card == null, "Dragging should immediately hide the tooltip.")
	await create_timer(0.35).timeout
	_check(not tooltip.visible, "Tooltip should remain hidden during a drag.")
	_escape(manager)

	_motion(manager, enemy.get_global_transform_with_canvas() * Vector2.ZERO)
	await create_timer(0.35).timeout
	_check(tooltip.visible and text.text.contains("Elefante") and text.text.contains("]10[/color]"), "Board tooltip should show the enemy's current HP.")
	manager.state.set_card_hp(enemy.data, 7)
	_check(text.text.contains("]7[/color]"), "An open enemy tooltip should update its HP.")
	manager.position = Vector2(-450, -100)
	await process_frame
	var bounds: Rect2 = root.get_visible_rect()
	var tooltip_rect: Rect2 = tooltip.get_global_rect()
	_check(tooltip_rect.position.x >= bounds.position.x and tooltip_rect.position.y >= bounds.position.y and tooltip_rect.end.x <= bounds.end.x and tooltip_rect.end.y <= bounds.end.y, "Tooltip should stay inside the viewport near the top-left edge.")
	manager.position = Vector2(700, 500)
	await process_frame
	tooltip_rect = tooltip.get_global_rect()
	_check(tooltip_rect.position.x >= bounds.position.x and tooltip_rect.position.y >= bounds.position.y and tooltip_rect.end.x <= bounds.end.x and tooltip_rect.end.y <= bounds.end.y, "Tooltip should stay inside the viewport near the bottom-right edge.")
	manager.state.set_card_hp(enemy.data, 0)
	_check(not tooltip.visible and tooltip.hovered_card == null, "Removing a hovered card should hide its tooltip.")
	_motion(manager, Vector2.ZERO)
	_check(not tooltip.visible, "Leaving the cards should hide the tooltip.")
	manager.position = Vector2.ZERO
	var chain_target: CardData = manager.state.board[0][1]
	manager.state.set_card_hp(chain_target, 1)
	_check(manager.state.play_card(axe.data, Vector2i(0, 2)) and manager.state.select_target(chain_target), "A buffed Axe should start its chain.")
	await create_timer(0.6).timeout
	_check(manager.state.phase == GameState.Phase.TARGETING and manager.state.damage_bonus == 0, "Axe chain should retain its attack after consuming the bonus.")
	_motion(manager, axe.get_global_transform_with_canvas() * Vector2.ZERO)
	await create_timer(0.35).timeout
	_check(tooltip.visible and text.text.contains("]6[/color] (linha 3)") and text.text.contains("]4[/color] (linha 4)"), "The played Axe tooltip should show the retained bonus during a chain.")
	manager.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	_check(not tooltip.visible, "Leaving the game window should hide the tooltip.")
	scene.free()

func _run() -> void:
	_test_effects()
	_test_cancellation_and_rows()
	_test_trap_bonus_and_full_row()
	_test_row_highlight()
	await _test_tooltips()
	await _test_ui()
	await _test_restart()
	if not failed:
		print("Combat checks passed.")
	quit(1 if failed else 0)
