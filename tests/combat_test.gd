extends SceneTree

const CardData = preload("res://cards/card_data.gd")
const GameState = preload("res://game/game_state.gd")
const Text = preload("res://data/text.gd")

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
	_check(magic.board_position == null and state.board[2][0] == null and not state.player.hand.has(magic), "Resolved Magic should leave the board and free its cell.")
	_check(state.play_card(magic2, Vector2i(0, 2)), "A second Magic should be playable in the freed cell.")
	_resolve(state)
	_check(state.damage_bonus == 4 and state.board[2][0] == null, "Magic should stack and free its cell after each resolution.")
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
	_check(last_state.phase == GameState.Phase.FINISHED and last_state.outcome == GameState.Outcome.WON and last_state.board[0][0] == null, "Defeating the last enemy should end the game in victory.")

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

func _test_end_state() -> void:
	var enemy := _card(CardData.Type.ELEPHANT)
	var magic := _card(CardData.Type.MAGIC)
	var losing := GameState.new([_record(enemy, Vector2i(0, 0)), _record(magic)])
	var results := []
	losing.game_finished.connect(func(outcome: int) -> void: results.append(outcome))
	_check(losing.play_card(magic, Vector2i(0, 2)) and losing.player.hand.is_empty(), "Last card should be playable.")
	_check(losing.outcome == GameState.Outcome.IN_PROGRESS, "An empty hand should not end a pending play.")
	_check(losing.cancel_play() and losing.outcome == GameState.Outcome.IN_PROGRESS, "Canceling the last card should not end the game.")
	_check(losing.play_card(magic, Vector2i(0, 2)), "The canceled card should be playable again.")
	_resolve(losing)
	_check(losing.outcome == GameState.Outcome.LOST and losing.phase == GameState.Phase.FINISHED and results == [GameState.Outcome.LOST], "Resolving the last card with enemies remaining should lose once.")
	_check(not losing.cancel_play() and not losing.set_card_hp(enemy, 0), "A finished game should reject further gameplay.")

	var axe := _card(CardData.Type.AXE)
	var first := _card(CardData.Type.ELEPHANT, 1)
	var second := _card(CardData.Type.ELEPHANT, 1)
	var chain := GameState.new([_record(first, Vector2i(0, 0)), _record(second, Vector2i(1, 0)), _record(axe)])
	_check(chain.play_card(axe, Vector2i(0, 2)) and chain.select_target(first), "Last Axe should start its chain.")
	_resolve(chain)
	_check(chain.phase == GameState.Phase.TARGETING and chain.outcome == GameState.Outcome.IN_PROGRESS, "A chain must finish before an empty hand causes a loss.")
	_check(chain.cancel_play() and chain.outcome == GameState.Outcome.IN_PROGRESS and first.board_position != null, "Canceling the chain should restore the game.")
	chain.play_card(axe, Vector2i(0, 2))
	chain.select_target(first)
	_resolve(chain)
	chain.select_target(second)
	_resolve(chain)
	_check(chain.outcome == GameState.Outcome.WON and chain.phase == GameState.Phase.FINISHED, "Defeating the last enemy in a chain should win.")

	var spear := _card(CardData.Type.SPEAR)
	var unused := _card(CardData.Type.MAGIC)
	var final_enemy := _card(CardData.Type.ELEPHANT, 1)
	var winning := GameState.new([_record(final_enemy, Vector2i(0, 0)), _record(spear), _record(unused)])
	winning.play_card(spear, Vector2i(0, 3))
	winning.select_target(final_enemy)
	_check(winning.outcome == GameState.Outcome.IN_PROGRESS, "Victory should wait for the attack to resolve.")
	_resolve(winning)
	_check(winning.outcome == GameState.Outcome.WON and winning.player.hand.has(unused), "The last enemy's defeat should win even with cards remaining.")
	var trap := _card(CardData.Type.TRAP)
	var trap_enemy := _card(CardData.Type.ELEPHANT, 5)
	var trap_win := GameState.new([_record(trap_enemy, Vector2i(0, 0)), _record(trap)])
	_check(trap_win.play_card(trap, Vector2i(1, 0)), "Final Trap should be playable.")
	_resolve(trap_win)
	_check(trap_win.outcome == GameState.Outcome.WON, "A final Trap that defeats the last enemy should win, not lose.")
	_check(GameState.new([_record(_card(CardData.Type.MAGIC))]).outcome == GameState.Outcome.WON, "A game starting without enemies should be won.")
	_check(GameState.new([_record(_card(CardData.Type.ELEPHANT), Vector2i(0, 0))]).outcome == GameState.Outcome.LOST, "A game starting with enemies and no cards should be lost.")

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
	_check(manager.valid_placement_cells.size() == 8 and Vector2i(0, 2) in manager.valid_placement_cells and Vector2i(3, 3) in manager.valid_placement_cells and Vector2i(2, 0) not in manager.valid_placement_cells, "Holding an Axe should show every open player cell, but no enemy cells.")
	manager.state.board[2][0] = _card(CardData.Type.MAGIC)
	manager.state.changed.emit()
	_check(Vector2i(0, 2) not in manager.valid_placement_cells, "Occupied cells should not be shown as valid placements.")
	manager.state.board[2][0] = null
	manager.state.changed.emit()
	_check(Vector2i(0, 2) in manager.valid_placement_cells, "Placement hints should update when the board changes.")
	_motion(manager, transform * (manager.board.cell_position(Vector2i(1, 2)) + offset))
	_check(manager.highlighted_row == 2, "A valid upper player row should be highlighted.")
	_motion(manager, transform * (manager.board.cell_position(Vector2i(2, 3)) + offset))
	_check(manager.highlighted_row == 3, "The highlight should follow the dragged card to the bottom row.")
	_motion(manager, transform * (manager.board.cell_position(Vector2i(2, 0)) + offset))
	_check(manager.highlighted_row == -1, "An Axe cannot highlight an enemy row.")
	_motion(manager, transform * (Vector2.ZERO + offset))
	_check(manager.highlighted_row == -1 and manager.valid_placement_cells.size() == 8, "Dragging outside the grid should retain valid placement hints without a drop preview.")
	_motion(manager, transform * (manager.board.cell_position(Vector2i(0, 2)) + offset))
	_escape(manager)
	_check(manager.highlighted_row == -1 and manager.valid_placement_cells.is_empty() and manager.state.player.hand.has(axe.data), "Canceling a drag should clear all highlights.")

	var trap: Node2D = manager.hand_layout.cards[-1]
	_button(manager, transform * (manager.to_local(trap.global_position) + offset), true)
	_check(manager.valid_placement_cells.size() == 5 and Vector2i(2, 0) in manager.valid_placement_cells and Vector2i(0, 1) in manager.valid_placement_cells and Vector2i(0, 0) not in manager.valid_placement_cells and Vector2i(0, 2) not in manager.valid_placement_cells, "Holding a Trap should show only unoccupied enemy cells.")
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
	_check(manager.highlighted_row == -1 and manager.valid_placement_cells.is_empty() and manager.state.board[0][2] == trap.data, "Dropping should clear all highlights and play the card.")
	scene.free()

func _test_row_penalty_badges() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	var manager := scene.get_node("CardManager") as Node2D
	var state = manager.state
	var axe: Node2D = manager.hand_layout.cards[0]
	var spear: Node2D = manager.hand_layout.cards[1]
	var badge := axe.get_node("Bonus") as Label
	var background := axe.get_node("BonusBackground") as ColorRect

	_check(state.play_card(axe.data, Vector2i(0, 2)) and not badge.visible, "Upper-row Axe should have no row penalty badge.")
	state.cancel_play()
	_check(state.play_card(axe.data, Vector2i(0, 3)) and badge.visible and badge.text == "-2 DANO" and background.color.r > background.color.b, "Bottom-row Axe should show its damage penalty.")
	state.cancel_play()
	_check(not badge.visible, "Returning a card to the hand should remove its row penalty.")

	state.damage_bonus = 2
	state.changed.emit()
	_check(badge.visible and badge.text == "+2 DANO" and background.color.b > background.color.r, "Hand cards should continue to show the Magic bonus in blue.")
	_check(state.play_card(axe.data, Vector2i(0, 3)) and badge.text == "-2 DANO", "The row penalty should remain visible independently of a Magic bonus.")
	state.cancel_play()
	_check(badge.text == "+2 DANO" and background.color.b > background.color.r, "Canceling a play should restore the Magic badge.")
	state.damage_bonus = 0
	state.changed.emit()

	badge = spear.get_node("Bonus") as Label
	_check(state.play_card(spear.data, Vector2i(0, 2)) and badge.visible and badge.text == "-1 DANO", "Upper-row Spear should show its damage penalty.")
	state.cancel_play()
	_check(state.play_card(spear.data, Vector2i(0, 3)) and not badge.visible, "Bottom-row Spear should have no row penalty badge.")
	state.cancel_play()
	badge = axe.get_node("Bonus") as Label
	_check(state.play_card(axe.data, Vector2i(0, 3)) and state.select_target(state.board[0][0]), "Axe should be playable for the resolved penalty check.")
	await create_timer(0.6).timeout
	_check(state.phase == GameState.Phase.IDLE and badge.visible and badge.text == "-2 DANO", "The row penalty should remain visible after the attack resolves.")
	scene.free()

func _test_card_hover_and_foil() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	var manager = scene.get_node("CardManager")
	manager.position = Vector2(30, 40)
	manager.scale = Vector2(1.3, 1.3)
	var shader: Shader = preload("res://cards/card.gdshader")
	for card in manager.card_views:
		var sprite := manager.card_views[card].get_node("Sprite2D") as Sprite2D
		_check(sprite.material is ShaderMaterial and sprite.material.shader == shader and is_zero_approx(sprite.material.get_shader_parameter("foil_strength")), "Every card should start with an inactive foil, including elephants.")
	var first: Node2D = manager.card_views[manager.state.board[0][0]]
	var second: Node2D = manager.card_views[manager.state.board[0][1]]
	first.scale = Vector2(0.8, 1.1)
	first.z_index = 3
	var sprite := first.get_node("Sprite2D") as Sprite2D
	var material := sprite.material as ShaderMaterial
	var center := sprite.get_global_transform_with_canvas() * sprite.get_rect().get_center()
	_motion(manager, center)
	_check(first.scale.is_equal_approx(Vector2(1.0, 1.375)) and first.z_index > 3, "A hovered board card should grow by 25% and appear above its neighbors.")
	_check(material.get_shader_parameter("foil_strength") == 1.0 and material.get_shader_parameter("cursor_uv").is_equal_approx(Vector2(0.5, 0.5)), "Foil should follow the cursor in transformed card coordinates.")
	var point := sprite.get_rect().position + sprite.get_rect().size * Vector2(0.7, 0.3)
	_motion(manager, sprite.get_global_transform_with_canvas() * point)
	_check(material.get_shader_parameter("cursor_uv").is_equal_approx(Vector2(0.7, 0.3)), "Moving over a card should update its foil position.")
	_motion(manager, second.get_global_transform_with_canvas() * Vector2.ZERO)
	_check(first.scale.is_equal_approx(Vector2(0.8, 1.1)) and first.z_index == 3 and is_zero_approx(material.get_shader_parameter("foil_strength")), "Switching board cards should restore the first card and disable its foil.")
	_check(second.scale.is_equal_approx(Vector2.ONE * 1.25), "The next board card should enlarge.")
	var hand_card: Node2D = manager.hand_layout.cards[0]
	_motion(manager, hand_card.get_global_transform_with_canvas() * Vector2.ZERO)
	var hand_material := hand_card.get_node("Sprite2D").material as ShaderMaterial
	_check(second.scale.is_equal_approx(Vector2.ONE) and hand_material.get_shader_parameter("foil_strength") == 1.0, "Hand cards should receive foil while preserving their existing hover behavior.")
	var old_uv: Vector2 = hand_material.get_shader_parameter("cursor_uv")
	hand_card._set_movement_position(hand_card.position + Vector2(0, 5))
	_check(not hand_material.get_shader_parameter("cursor_uv").is_equal_approx(old_uv), "Foil should track a stationary cursor as the hovered card moves.")
	_button(manager, hand_card.get_global_transform_with_canvas() * Vector2.ZERO, true)
	_check(is_zero_approx(hand_material.get_shader_parameter("foil_strength")), "Dragging should disable the foil.")
	_escape(manager)
	_motion(manager, first.get_global_transform_with_canvas() * Vector2.ZERO)
	manager.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	_check(first.scale.is_equal_approx(Vector2(0.8, 1.1)) and is_zero_approx(material.get_shader_parameter("foil_strength")), "Leaving the window should clear board hover and foil.")
	_check(manager.state.play_card(hand_card.data, Vector2i(0, 2)), "The hand card should be playable for the board hover check.")
	hand_card.stop_moving()
	hand_card.position = manager.board.cell_position(Vector2i(0, 2))
	_motion(manager, hand_card.get_global_transform_with_canvas() * Vector2.ZERO)
	_check(hand_card.scale.is_equal_approx(Vector2.ONE * 1.25) and hand_material.get_shader_parameter("foil_strength") == 1.0, "A played card should enlarge and show foil on the board, including while targeting.")
	manager.state.cancel_play()
	_check(hand_card.scale.is_equal_approx(Vector2.ONE) and is_zero_approx(hand_material.get_shader_parameter("foil_strength")), "Returning a hovered board card to the hand should restore its transform and foil.")
	_motion(manager, first.get_global_transform_with_canvas() * Vector2.ZERO)
	manager.state.set_card_hp(first.data, 0)
	_check(manager.hovered_board_card == null and manager.foil_card == null, "Removing a hovered card should clear hover state.")
	scene.free()

func _test_card_drop_sound() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	var manager := scene.get_node("CardManager") as Node2D
	var sound := manager.get_node("CardDropSound") as AudioStreamPlayer
	var axe: Node2D = manager.hand_layout.cards[0]
	_check(sound.stream != null and sound.stream.get_length() > 0, "Card drop sound should load as a playable audio stream.")
	var wav := sound.stream as AudioStreamWAV
	_check(wav != null and wav.format == AudioStreamWAV.FORMAT_16_BITS, "The converted card-drop sound should retain its 16-bit PCM format.")
	_button(manager, Vector2.ZERO, false)
	_check(not sound.playing, "Releasing without a dragged card should not play the sound.")
	_button(manager, axe.get_global_transform_with_canvas() * Vector2.ZERO, true)
	_escape(manager)
	_check(not sound.playing, "Canceling a drag should not play the drop sound.")
	_drag(manager, axe, Vector2.ZERO)
	_check(sound.playing and manager.state.player.hand.has(axe.data), "An invalid drop should play the sound and return the card to the hand.")
	sound.stop()
	_drag(manager, axe, manager.board.cell_position(Vector2i(1, 2)))
	_check(sound.playing and manager.state.board[2][1] == axe.data, "A valid drop should play the sound and place the card.")
	sound.stop()
	var enemy: Node2D = manager.card_views[manager.state.board[0][0]]
	_click_card(manager, enemy)
	_check(not sound.playing, "Selecting a target should not play the card-drop sound.")
	_escape(manager)
	await create_timer(0.6).timeout
	scene.free()

func _test_axe_attack_sound() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	var manager := scene.get_node("CardManager") as Node2D
	var state = manager.state
	var sound := manager.get_node("AxeAttackSound") as AudioStreamPlayer
	var axe: CardData = state.player.hand[0]
	var first: CardData = state.board[0][0]
	var second: CardData = state.board[0][1]
	_check(sound.stream != null and sound.stream.resource_path == "res://assets/audio/attack3.wav" and sound.stream.get_length() > 0, "Axe attack sound should load the requested audio.")
	state.set_card_hp(first, 1)
	_check(state.play_card(axe, Vector2i(1, 2)) and state.select_target(first), "Axe should start targeting an enemy.")
	await create_timer(0.25).timeout
	_check(not sound.playing and first.current_hp == 1, "The attack sound should wait for the damage delay.")
	_check(state.cancel_play(), "The pending axe attack should be cancelable.")
	await create_timer(0.35).timeout
	_check(not sound.playing and first.current_hp == 1, "A canceled attack should not play the attack sound.")

	_check(state.play_card(axe, Vector2i(1, 2)) and state.select_target(first), "Axe should be playable again after cancellation.")
	await create_timer(0.6).timeout
	_check(sound.playing and first.board_position == null and state.phase == GameState.Phase.TARGETING, "A resolved killing attack should play the sound and start a chain.")
	sound.stop()
	_check(state.select_target(second), "Axe should select the next chain target.")
	await create_timer(0.6).timeout
	_check(sound.playing and second.current_hp == 6 and state.phase == GameState.Phase.IDLE, "A follow-up axe attack should play the sound again.")
	sound.stop()

	var spear: CardData = state.player.hand[0]
	var other: CardData = state.board[1][1]
	_check(state.play_card(spear, Vector2i(0, 2)) and state.select_target(other), "Spear should start its attack.")
	await create_timer(0.6).timeout
	_check(not sound.playing and other.current_hp == 12, "Spear attacks should not play the axe sound.")
	scene.free()
	await create_timer(0.1).timeout

func _test_spear_attack_sound() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	var manager := scene.get_node("CardManager") as Node2D
	var state = manager.state
	var sound := manager.get_node("SpearAttackSound") as AudioStreamPlayer
	var spear: CardData = state.player.hand[1]
	var target: CardData = state.board[1][1]
	_check(sound.stream != null and sound.stream.resource_path == "res://assets/audio/arrow.mp3" and sound.stream.get_length() > 0, "Spear attack sound should load the requested audio.")
	_check(state.play_card(spear, Vector2i(1, 2)) and state.select_target(target), "Spear should start targeting an enemy.")
	await create_timer(0.25).timeout
	_check(not sound.playing and target.current_hp == 13, "Spear sound should wait for the damage delay.")
	_check(state.cancel_play(), "The pending spear attack should be cancelable.")
	await create_timer(0.35).timeout
	_check(not sound.playing and target.current_hp == 13, "A canceled spear attack should not play the sound.")

	_check(state.play_card(spear, Vector2i(1, 2)) and state.select_target(target), "Spear should be playable again after cancellation.")
	await create_timer(0.6).timeout
	_check(sound.playing and target.current_hp == 12 and target.board_position == Vector2i(2, 0), "A resolved spear attack should play the sound and move its target.")
	sound.stop()
	var axe: CardData = state.player.hand[0]
	var other: CardData = state.board[0][0]
	_check(state.play_card(axe, Vector2i(0, 2)) and state.select_target(other), "Axe should start its attack.")
	await create_timer(0.6).timeout
	_check(not sound.playing and other.current_hp == 6, "Axe attacks should not play the spear sound.")
	scene.free()
	await create_timer(0.1).timeout

func _test_magic_entry_sound() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	var manager := scene.get_node("CardManager") as Node2D
	var state = manager.state
	var sound := manager.get_node("MagicEntrySound") as AudioStreamPlayer
	var magic: Node2D = manager.hand_layout.cards[2]
	var wav := sound.stream as AudioStreamWAV
	_check(wav != null and wav.format == AudioStreamWAV.FORMAT_16_BITS and wav.get_length() > 0, "Magic entry sound should load as playable 16-bit PCM.")
	_drag(manager, magic, Vector2.ZERO)
	_check(not sound.playing and state.player.hand.has(magic.data), "An invalid magic drop should not play the entry sound.")
	_button(manager, magic.get_global_transform_with_canvas() * Vector2.ZERO, true)
	_escape(manager)
	_check(not sound.playing, "Canceling a magic drag should not play the entry sound.")

	_drag(manager, magic, manager.board.cell_position(Vector2i(1, 2)))
	_check(sound.playing and state.damage_bonus == 0, "Magic should play its entry sound immediately, before its delayed effect.")
	_check(magic.get_node_or_null("MagicBuffAura") == null, "Magic particles should wait until the buff is applied.")
	_escape(manager)
	_check(not sound.playing and state.player.hand.has(magic.data), "Canceling a placed Magic card should stop its entry sound.")
	await create_timer(0.6).timeout
	_check(state.damage_bonus == 0 and not sound.playing and magic.get_node_or_null("MagicBuffAura") == null, "Canceled Magic should not apply its effect or create particles.")

	_drag(manager, magic, manager.board.cell_position(Vector2i(1, 2)))
	_check(sound.playing, "Replaying Magic after cancellation should play the entry sound again.")
	var magic_data: CardData = magic.data
	await create_timer(0.6).timeout
	_check(sound.playing and state.damage_bonus == 2, "The entry sound should continue naturally when Magic resolves.")
	_check(state.board[2][1] == null and manager.board.cards[2][1] == null and not manager.card_views.has(magic_data), "Resolved Magic should immediately free its logical and visual board cell.")
	var burn_material := magic.get_node("Sprite2D").material as ShaderMaterial
	var burn_progress: float = burn_material.get_shader_parameter("burn_progress")
	_check(burn_material.shader == load("res://cards/magic_burn.gdshader") and burn_progress > 0.0 and burn_progress < 1.0, "Resolved Magic should burn away with the fire shader.")
	var axe: Node2D = manager.hand_layout.cards[0]
	var buff_particles := axe.get_node_or_null("MagicBuffAura") as ColorRect
	_check(magic.get_node_or_null("MagicBuffAura") == null, "A played Magic card should not retain the bonus.")
	_check(buff_particles != null and buff_particles.visible and buff_particles.color.r > buff_particles.color.g * 2.0 and buff_particles.material.shader == load("res://cards/continuous_aura.gdshader"), "A buffed card should have a continuous red aura.")
	for card in manager.hand_layout.cards:
		_check(card.get_node_or_null("MagicBuffAura") != null, "Every buffed hand card should show particles.")
	manager._refresh_state()
	_check(axe.get_node_or_null("MagicBuffAura") == buff_particles, "Refreshing state should not restart existing buff particles.")
	sound.stop()
	await create_timer(1.8).timeout
	_check(not is_instance_valid(magic), "The Magic view should be removed after the burn animation.")
	_check(axe.get_node_or_null("MagicBuffAura") == buff_particles and buff_particles.visible, "Buff aura should persist until the bonus expires.")
	_drag(manager, axe, manager.board.cell_position(Vector2i(0, 3)))
	_check(not sound.playing, "Placing a non-Magic card should not play the Magic entry sound.")
	_escape(manager)
	scene.free()
	await create_timer(0.1).timeout

func _test_buff_particles_lifecycle() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	var manager := scene.get_node("CardManager") as Node2D
	var state = manager.state
	var axe: Node2D = manager.hand_layout.cards[0]
	var spear: Node2D = manager.hand_layout.cards[1]
	var magic: Node2D = manager.hand_layout.cards[2]
	var trap: Node2D = manager.hand_layout.cards[3]
	var first: CardData = state.board[0][0]
	var second: CardData = state.board[0][1]
	_check(state.play_card(magic.data, Vector2i(1, 2)), "Magic should be playable for the buff lifecycle test.")
	await create_timer(0.6).timeout
	var particles := axe.get_node_or_null("MagicBuffAura")
	_button(manager, axe.get_global_transform_with_canvas() * Vector2.ZERO, true)
	_check(axe.get_node_or_null("MagicBuffAura") == particles and axe.get_node("DragAura").visible, "Buff and drag auras should coexist on a dragged card.")
	_escape(manager)
	state.set_card_hp(first, 1)
	_drag(manager, axe, manager.board.cell_position(Vector2i(0, 3)))
	_check(axe.get_node_or_null("MagicBuffAura") == particles, "The pending buffed attack should retain particles on the board.")
	_check(state.select_target(first), "Axe should target the first enemy.")
	await create_timer(0.6).timeout
	_check(state.phase == GameState.Phase.TARGETING and state.damage_bonus == 0 and axe.get_node_or_null("MagicBuffAura") == particles, "An Axe chain should retain its original bonus particles.")
	_check(spear.get_node_or_null("MagicBuffAura") == null and trap.get_node_or_null("MagicBuffAura") == null, "Other cards should lose particles when the bonus is consumed.")
	_escape(manager)
	_check(state.damage_bonus == 2 and axe.get_node_or_null("MagicBuffAura") == particles and spear.get_node_or_null("MagicBuffAura") != null and trap.get_node_or_null("MagicBuffAura") != null, "Canceling an Axe chain should restore the bonus and hand particles.")
	_drag(manager, axe, manager.board.cell_position(Vector2i(0, 3)))
	_check(state.select_target(first), "Axe should target the restored enemy.")
	await create_timer(0.6).timeout
	_check(state.select_target(second), "Axe should target a surviving follow-up enemy.")
	await create_timer(0.6).timeout
	_check(state.phase == GameState.Phase.IDLE and axe.get_node_or_null("MagicBuffAura") == null and spear.get_node_or_null("MagicBuffAura") == null, "Completing an attack should remove all expired buff particles.")
	scene.free()
	await create_timer(0.1).timeout

	scene = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	manager = scene.get_node("CardManager") as Node2D
	state = manager.state
	magic = manager.hand_layout.cards[2]
	trap = manager.hand_layout.cards[3]
	spear = manager.hand_layout.cards[1]
	state.play_card(magic.data, Vector2i(1, 2))
	await create_timer(0.6).timeout
	_check(state.play_card(trap.data, Vector2i(2, 0)) and trap.get_node_or_null("MagicBuffAura") != null, "A pending buffed Trap should show particles on the board.")
	_escape(manager)
	_check(state.player.hand.has(trap.data) and trap.get_node_or_null("MagicBuffAura") != null, "A canceled Trap should keep its restored bonus particles.")
	_check(state.play_card(trap.data, Vector2i(2, 0)), "The restored Trap should be playable again.")
	await create_timer(0.6).timeout
	_check(state.damage_bonus == 0 and spear.get_node_or_null("MagicBuffAura") == null and not is_instance_valid(trap), "A resolved Trap should consume the bonus and clean up its particles.")
	state.damage_bonus = 2
	state.changed.emit()
	_check(state.play_card(spear.data, Vector2i(0, 2)) and spear.get_node_or_null("MagicBuffAura") != null, "A pending buffed Spear should show particles on the board.")
	_check(state.select_target(state.board[1][1]), "Spear should target an enemy.")
	await create_timer(0.6).timeout
	_check(state.phase == GameState.Phase.IDLE and spear.get_node_or_null("MagicBuffAura") == null, "A resolved Spear should lose its consumed bonus particles.")
	scene.free()
	await create_timer(0.1).timeout

func _test_particles() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	var manager := scene.get_node("CardManager") as Node2D
	manager.position = Vector2(30, 40)
	manager.scale = Vector2(1.3, 1.3)
	var state = manager.state
	var board = manager.board
	var axe: Node2D = manager.hand_layout.cards[0]
	var start := axe.get_global_transform_with_canvas() * Vector2.ZERO
	_button(manager, start, true)
	var drag := axe.get_node_or_null("DragAura") as ColorRect
	_check(drag != null and drag.visible, "Dragging should show an aura around the card.")
	if drag != null:
		var sprite := axe.get_node("Sprite2D") as Sprite2D
		_check(drag.material.shader == load("res://cards/continuous_aura.gdshader") and drag.size.x > sprite.get_rect().size.x * sprite.scale.x, "Drag aura should surround the card.")
		_motion(manager, manager.get_global_transform_with_canvas() * board.cell_position(Vector2i(0, 2)))
		_check(drag.get_parent() == axe and drag.visible, "Drag aura should follow the moving card.")
	_escape(manager)
	_check(drag != null and not drag.visible, "Canceling a drag should hide its aura.")
	_check(manager.get_node_or_null("DropAura") == null, "Canceling a drag should not create a release burst.")

	_drag(manager, axe, Vector2.ZERO)
	var invalid_drop := manager.get_node_or_null("DropAura") as ColorRect
	_check(invalid_drop != null and (invalid_drop.position + invalid_drop.size / 2.0).distance_to(Vector2.ZERO) < 0.01 and state.player.hand.has(axe.data), "An invalid release should show an aura and return the card to the hand.")
	await create_timer(0.9).timeout
	_check(manager.get_node_or_null("DropAura") == null, "An invalid-release burst should clean itself up.")

	var destination: Vector2 = board.cell_position(Vector2i(1, 2))
	_drag(manager, axe, destination)
	var drop := manager.get_node_or_null("DropAura") as ColorRect
	_check(drop != null and (drop.position + drop.size / 2.0).is_equal_approx(destination) and drop.material.shader == load("res://cards/continuous_aura.gdshader"), "Releasing should create an aura at the drop position.")
	_check(drag != null and not drag.visible, "Releasing should stop the drag particles.")
	_button(manager, manager.get_global_transform_with_canvas() * Vector2.ZERO, true)
	_check(manager.get_node_or_null("DamageAura") == null, "Clicking outside enemy cards should not create damage particles.")
	var enemy: Node2D = manager.card_views[state.board[0][0]]
	var original_hp: int = enemy.data.current_hp
	_click_card(manager, enemy)
	var damage := manager.get_node_or_null("DamageAura") as ColorRect
	_check(damage != null and (damage.position + damage.size / 2.0).is_equal_approx(manager.to_local(enemy.global_position)), "Selecting an enemy should create a damage aura at that enemy.")
	_escape(manager)
	await create_timer(0.65).timeout
	_check(enemy.data.current_hp == original_hp, "Canceling a target selection should still prevent delayed damage.")

	var trap: Node2D = manager.hand_layout.cards[-1]
	var trap_sound := manager.get_node("TrapSound") as AudioStreamPlayer
	_check(trap_sound.stream != null and trap_sound.stream.resource_path == "res://assets/audio/stomp.mp3" and trap_sound.stream.get_length() > 0.0, "Trap sound should load the requested audio.")
	_drag(manager, trap, board.cell_position(Vector2i(2, 0)))
	_check(manager.get_node_or_null("TrapAura") == null and not trap_sound.playing, "Trap particles and sound should wait until the effect resolves.")
	_escape(manager)
	await create_timer(0.65).timeout
	_check(manager.get_node_or_null("TrapAura") == null and not trap_sound.playing, "A canceled Trap should not create a row effect or play the sound.")
	_drag(manager, trap, board.cell_position(Vector2i(2, 1)))
	await create_timer(0.55).timeout
	_check(trap_sound.playing, "The Trap should play its sound when its effect resolves.")
	var row_particles := manager.get_node_or_null("TrapAura") as ColorRect
	var row_size := Vector2(board.cards[1].size() * board.cell_size.x, board.cell_size.y)
	var row_center: Vector2 = board.cell_position(Vector2i(0, 1)) - board.cell_size / 2.0 + row_size / 2.0
	_check(row_particles != null and (row_particles.position + row_particles.size / 2.0).is_equal_approx(row_center) and row_particles.size.x > row_size.x, "Trap aura should cover the resolved enemy row.")
	await create_timer(1.2).timeout
	_check(manager.get_node_or_null("TrapAura") == null and manager.get_node_or_null("DamageAura") == null and manager.get_node_or_null("DropAura") == null, "Finished particle bursts should be removed.")
	var magic: Node2D
	for view in manager.hand_layout.cards:
		if view.data.type == CardData.Type.MAGIC:
			magic = view
	_button(manager, magic.get_global_transform_with_canvas() * Vector2.ZERO, true)
	var magic_drag := magic.get_node("DragAura") as ColorRect
	_check(state.play_card(magic.data, Vector2i(0, 3)) and manager.dragged_card == null and not magic_drag.visible, "A programmatic play should stop any active drag particles.")
	_escape(manager)
	scene.free()

func _test_screen_effects() -> void:
	var scene: Node2D = load("res://game/main.tscn").instantiate()
	scene.position = Vector2(30, 20)
	root.add_child(scene)
	var manager = scene.get_node("CardManager")
	var effects = scene.get_node("ScreenEffects")
	var state = manager.state
	var magic = manager.hand_layout.cards[2].data
	_check(state.play_card(magic, Vector2i(1, 2)), "Magic should begin before the screen effect.")
	_check(not effects.overlay.visible and effects.magic_strength == 0.0, "Magic should not affect the screen before it resolves.")
	state.cancel_play()
	await create_timer(0.55).timeout
	_check(effects.magic_strength == 0.0 and not effects.overlay.visible, "Canceled Magic should not trigger a screen effect.")
	_check(state.play_card(magic, Vector2i(1, 2)), "Magic should be playable again.")
	state.resolve_effect(state.effect_token)
	await create_timer(0.2).timeout
	_check(effects.magic_strength > 0.0 and effects.overlay.visible and effects.overlay.material.shader == load("res://game/screen_effects.gdshader"), "Resolved Magic should show a screen-wide shader.")
	_check(effects.overlay.anchor_right == 1.0 and effects.overlay.anchor_bottom == 1.0, "Screen effects should cover the viewport.")
	var axe = manager.hand_layout.cards[0].data
	var enemy: CardData = state.board[0][0]
	_check(state.play_card(axe, Vector2i(0, 2)) and state.select_target(enemy), "Axe should start an attack.")
	_check(effects.impact_strength == 0.0, "Selecting a target should not trigger impact before damage.")
	state.resolve_effect(state.effect_token)
	await create_timer(0.12).timeout
	_check(effects.impact_strength > 0.0 and effects.magic_strength > 0.0 and not scene.position.is_equal_approx(Vector2(30, 20)), "Axe impact should overlap Magic and shake the screen.")
	await create_timer(0.5).timeout
	_check(is_zero_approx(effects.impact_strength) and effects.magic_strength > 0.0 and scene.position.is_equal_approx(Vector2(30, 20)), "Impact should end after half a second and restore the original screen position.")
	await create_timer(0.9).timeout
	_check(is_zero_approx(effects.magic_strength) and not effects.overlay.visible, "Magic screen effect should finish after about 1.5 seconds.")
	var spear = manager.hand_layout.cards[0].data
	_check(state.play_card(spear, Vector2i(2, 2)) and state.select_target(state.board[1][1]), "Spear should start an attack.")
	state.resolve_effect(state.effect_token)
	await create_timer(0.1).timeout
	_check(effects.impact_strength > 0.0, "Spear hits should trigger the impact effect.")
	var trap = manager.hand_layout.cards[-1].data
	_check(state.play_card(trap, Vector2i(3, 0)), "Trap should start while a previous impact is fading.")
	state.resolve_effect(state.effect_token)
	await create_timer(0.1).timeout
	_check(effects.impact_strength > 0.0 and not scene.position.is_equal_approx(Vector2(30, 20)), "Trap should retrigger the impact effect and shake.")
	await create_timer(0.55).timeout
	_check(is_zero_approx(effects.impact_strength) and scene.position.is_equal_approx(Vector2(30, 20)) and not effects.overlay.visible, "Repeated impacts should finish and restore the screen.")
	scene.free()

func _test_card_movement() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	var hand := scene.get_node("CardManager/Hand") as Node2D
	hand.position = Vector2(20, 10)
	hand.scale = Vector2(0.9, 1.1)
	root.add_child(scene)
	var manager = scene.get_node("CardManager")
	manager.position = Vector2(30, 40)
	manager.scale = Vector2(1.3, 1.3)
	var state = manager.state
	var axe = manager.hand_layout.cards[0]
	var start: Vector2 = axe.global_position
	var destination: Vector2 = manager.to_global(manager.board.cell_position(Vector2i(1, 2)))
	_check(state.play_card(axe.data, Vector2i(1, 2)), "Programmatic play should start a card movement.")
	_check(axe.global_position.is_equal_approx(start), "Moving from hand to board should preserve the starting position.")
	await create_timer(0.1).timeout
	_check(axe.global_position.distance_to(start) > 1.0 and axe.global_position.distance_to(destination) > 1.0, "A played card should move through intermediate positions.")
	await process_frame
	_check(manager.targeting_arrow.start.is_equal_approx(manager.to_local(axe.global_position)), "Targeting beam should follow the moving attacker.")
	var interrupted: Vector2 = axe.global_position
	state.cancel_play()
	_check(axe.global_position.is_equal_approx(interrupted), "Canceling a moving card should return it from its current position.")
	await create_timer(0.35).timeout
	_check(manager.to_local(axe.global_position).is_equal_approx(manager.hand_layout.card_position(0)), "Canceled card should reach its hand position with transformed parents.")
	_check(axe.scale.is_equal_approx(Vector2.ONE), "Returning a card should restore its original hand scale.")
	var spear = manager.hand_layout.cards[1]
	var enemy: CardData = state.board[1][1]
	var enemy_view: Node2D = manager.card_views[enemy]
	var enemy_start := enemy_view.position
	_check(state.play_card(spear.data, Vector2i(0, 2)) and state.select_target(enemy), "Spear should start a row movement.")
	await create_timer(0.56).timeout
	var enemy_end: Vector2 = manager.board.cell_position(Vector2i(2, 0))
	_check(enemy.board_position == Vector2i(2, 0) and enemy_view.position.distance_to(enemy_start) > 0.0 and enemy_view.position.distance_to(enemy_end) > 1.0, "Enemy row changes should animate after their logical move.")
	await create_timer(0.3).timeout
	_check(enemy_view.position.is_equal_approx(enemy_end), "Enemy should finish moving into the new row.")
	axe.move_to(axe.position + Vector2(-100, 0))
	await create_timer(0.08).timeout
	manager._begin_drag(axe.get_global_transform_with_canvas() * Vector2.ZERO)
	var drag_position: Vector2 = axe.position
	await create_timer(0.3).timeout
	_check(manager.dragged_card == axe and axe.position.is_equal_approx(drag_position), "Dragging should interrupt an in-flight animation without pulling the card away.")
	_escape(manager)
	scene.free()

func _test_targeting_effects() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	var manager := scene.get_node("CardManager") as Node2D
	manager.position = Vector2(30, 40)
	manager.scale = Vector2(1.3, 1.3)
	var state = manager.state
	var axe: Node2D = manager.hand_layout.cards[0]
	var spear: Node2D = manager.hand_layout.cards[1]
	var first: CardData = state.board[0][0]
	var second: CardData = state.board[0][1]
	var third: CardData = state.board[1][1]
	var first_view: Node2D = manager.card_views[first]
	var second_view: Node2D = manager.card_views[second]
	var third_view: Node2D = manager.card_views[third]
	_check(first_view.get_node_or_null("TargetAura") == null and manager.get_node_or_null("TargetArrow") == null, "Targeting effects should be absent while idle.")
	state.set_card_hp(first, 1)
	var destination: Vector2 = manager.board.cell_position(Vector2i(1, 2))
	_drag(manager, axe, destination)
	var arrow = manager.get_node_or_null("TargetArrow")
	var aura := first_view.get_node_or_null("TargetAura")
	_check(arrow != null and aura != null and second_view.get_node_or_null("TargetAura") != null and third_view.get_node_or_null("TargetAura") != null, "Targeting should show an arrow and an aura on every enemy.")
	_check(axe.get_node_or_null("TargetAura") == null and spear.get_node_or_null("TargetAura") == null, "Player cards should not show target auras.")
	if arrow != null:
		_check(arrow.start.is_equal_approx(manager.to_local(axe.global_position)) and arrow.end.is_equal_approx(destination + Vector2(6, 4)), "Arrow should initially connect the attacking card to the cursor.")
		var cursor := Vector2(810, 240)
		_motion(manager, manager.get_global_transform_with_canvas() * cursor)
		_check(arrow.end.is_equal_approx(cursor), "Arrow should track cursor motion with transformed managers.")
		_check(arrow.material is ShaderMaterial and arrow.material.shader == load("res://game/target_beam.gdshader"), "Targeting beam should use its animated shader.")
		var midpoint: Vector2 = arrow._curve_position(0.5)
		_check(arrow._curve_position(0.0).is_equal_approx(arrow.start) and arrow._curve_position(1.0).is_equal_approx(arrow.end) and midpoint.distance_to((arrow.start + arrow.end) / 2.0) > 1.0, "Beam should arc between the attacking card and the cursor.")
		arrow.set_points(cursor, cursor)
		_check(arrow._curve_position(0.5).is_equal_approx(cursor), "A zero-length beam should remain anchored at the cursor.")
		arrow.set_points(manager.to_local(axe.global_position), cursor)
		_motion(manager, manager.get_global_transform_with_canvas() * cursor)
	if aura != null:
		_check(aura is ColorRect and aura.material.shader == load("res://cards/continuous_aura.gdshader") and aura.get_child_count() == 0, "Enemy targeting should use a continuous aura without particle dots.")
	manager._refresh_state()
	_check(first_view.get_node_or_null("TargetAura") == aura, "Refreshing targeting should preserve existing aura particles.")
	_click_card(manager, first_view)
	_check(state.phase == GameState.Phase.RESOLVING and manager.get_node_or_null("TargetArrow") == null and second_view.get_node_or_null("TargetAura") == null, "Effects should disappear as soon as a target is selected.")
	await create_timer(0.6).timeout
	_check(state.phase == GameState.Phase.TARGETING and manager.get_node_or_null("TargetArrow") != null and second_view.get_node_or_null("TargetAura") != null and third_view.get_node_or_null("TargetAura") != null, "Axe chains should restore effects on surviving enemies.")
	_escape(manager)
	first_view = manager.card_views[first]
	_check(manager.get_node_or_null("TargetArrow") == null and first_view.get_node_or_null("TargetAura") == null and second_view.get_node_or_null("TargetAura") == null, "Canceling a chain should clear targeting effects, including restored enemies.")
	_check(state.play_card(spear.data, Vector2i(0, 2)) and manager.get_node_or_null("TargetArrow") != null and first_view.get_node_or_null("TargetAura") != null, "Programmatic spear play should also show targeting effects.")
	_check(state.select_target(second), "Spear should select an enemy.")
	_check(manager.get_node_or_null("TargetArrow") == null and first_view.get_node_or_null("TargetAura") == null, "Programmatic target selection should clear targeting effects.")
	await create_timer(0.6).timeout
	_check(state.phase == GameState.Phase.IDLE and manager.get_node_or_null("TargetArrow") == null, "Completed attacks should leave no targeting arrow.")
	_check(state.play_card(axe.data, Vector2i(1, 2)), "Axe should enter targeting before restart.")
	current_scene = scene
	var restart := InputEventKey.new()
	restart.keycode = KEY_R
	restart.pressed = true
	manager._input(restart)
	await create_timer(1.3).timeout
	_check(current_scene != null and current_scene != scene, "Restart should reload while targeting.")
	if current_scene != null and current_scene != scene:
		var new_manager = current_scene.get_node("CardManager")
		var new_enemy: Node2D = new_manager.card_views[new_manager.state.board[0][0]]
		_check(new_manager.get_node_or_null("TargetArrow") == null and new_enemy.get_node_or_null("TargetAura") == null, "Restarted game should not retain targeting effects.")
	await create_timer(1.3).timeout
	if current_scene != null:
		current_scene.free()
		current_scene = null

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
	await create_timer(0.3).timeout
	_check(spear_board.cards[0][2] == target_view and target_view.position.is_equal_approx(spear_board.cell_position(Vector2i(2, 0))), "Spear should move the target's board view.")
	spear_scene.free()

	var layout_scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(layout_scene)
	var layout_manager := layout_scene.get_node("CardManager") as Node2D
	var layout_magic: Node2D = layout_manager.hand_layout.cards[2]
	_check(layout_manager.state.play_card(layout_magic.data, Vector2i(0, 3)), "Programmatic Magic play should be accepted.")
	_check(is_zero_approx(layout_magic.rotation), "A programmatically played card should not retain hand rotation.")
	await create_timer(0.3).timeout
	var hand_index := 0
	for view in layout_manager.hand_layout.cards:
		_check(layout_manager.to_local(view.global_position).is_equal_approx(layout_manager.hand_layout.card_position(hand_index)), "Hand should relayout after a programmatic play.")
		hand_index += 1
	layout_scene.free()

func _test_result_story(end_screen: Node, prefix: String) -> void:
	var original := Text.get_text(prefix + "_paragraph_2")
	Text.config.set_value("text", prefix + "_paragraph_2", prefix + " second paragraph")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space)
	var story = end_screen.get_node_or_null("StoryScreen")
	_check(story != null, "Space on a result should open its story.")
	if story == null:
		Text.config.set_value("text", prefix + "_paragraph_2", original)
		return
	_check(story.label.text == Text.get_text(prefix + "_paragraph_1") and story.layer > end_screen.layer, "The result story should cover the result with its first paragraph.")
	_check(story.paragraphs.size() == 3, "The result story should contain three paragraphs.")
	_check(story.prompt.visible and story.prompt.text == "Aperte ESPACO para continuar" and story.prompt.anchor_top == 1.0, "Result paragraphs should show the bottom Space hint.")
	root.push_input(space)
	await create_timer(0.3).timeout
	_check(story.background.modulate.a > 0.0 and story.background.modulate.a < 1.0, "The result should gradually blend into the story.")
	await create_timer(1.0).timeout
	_check(story.paragraph_index == 0, "Space during the reveal should not skip the result paragraph.")
	root.push_input(space)
	await create_timer(0.15).timeout
	var progress: float = story.text_material.get_shader_parameter("spawn_progress")
	_check(progress > 0.0 and progress < 1.0 and story.label.text == Text.get_text(prefix + "_paragraph_1"), "The current paragraph should vanish with the preview shader before changing.")
	await create_timer(0.85).timeout
	_check(story.label.text == prefix + " second paragraph", "The correct result's second paragraph should be shown.")
	root.push_input(space)
	await create_timer(1.0).timeout
	_check(story.label.text == Text.get_text(prefix + "_paragraph_3") and not story.complete, "The correct result's third paragraph should precede the finished screen.")
	_check(story.label.get_content_height() <= story.label.size.y - 220.0, "Result paragraphs should fit above the bottom prompt.")
	root.push_input(space)
	await create_timer(1.0).timeout
	_check(story.complete and story.label.text == "Fim de jogo" and not story.prompt.visible, "The result story should end on the finished screen without a Space hint.")
	root.push_input(space)
	_check(story.label.text == "Fim de jogo", "Space should not leave the finished screen.")
	Text.config.set_value("text", prefix + "_paragraph_2", original)

func _test_end_screens() -> void:
	var victory_scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(victory_scene)
	var victory_manager = victory_scene.get_node("CardManager")
	var victory_state = victory_manager.state
	var last: CardData = victory_state.board[1][1]
	victory_state.set_card_hp(victory_state.board[0][0], 0)
	victory_state.set_card_hp(victory_state.board[0][1], 0)
	_check(not victory_scene.get_node("EndScreen").panel.visible, "Victory should wait until the last enemy is defeated.")
	var dragged: Node2D = victory_manager.hand_layout.cards[0]
	_button(victory_manager, dragged.get_global_transform_with_canvas() * Vector2.ZERO, true)
	victory_state.set_card_hp(last, 0)
	var victory = victory_scene.get_node("EndScreen")
	_check(victory_state.outcome == GameState.Outcome.WON and victory.panel.visible and victory.title.text == "VITÓRIA!" and victory.herd.get_child_count() == 0, "Victory should show its large message without a herd.")
	_check(victory_manager.dragged_card == null and not dragged.get_node("DragAura").visible, "Victory should stop any active drag.")
	await _test_result_story(victory, "victory")
	victory_scene.free()

	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var manager = scene.get_node("CardManager")
	var state = manager.state
	var enemy: CardData = state.board[0][0]
	var magic: CardData = state.player.hand[2]
	var axe: CardData = state.player.hand[0]
	var spear: CardData = state.player.hand[1]
	var trap: CardData = state.player.hand[3]
	_check(state.play_card(magic, Vector2i(0, 2)), "Magic should be playable in the loss scenario.")
	_resolve(state)
	_check(state.play_card(axe, Vector2i(1, 2)) and state.select_target(enemy), "Axe should be playable in the loss scenario.")
	_resolve(state)
	_check(state.play_card(spear, Vector2i(2, 2)) and state.select_target(enemy), "Spear should be playable in the loss scenario.")
	_resolve(state)
	_check(state.play_card(trap, Vector2i(2, 0)), "The final Trap should be playable in the loss scenario.")
	_check(state.outcome == GameState.Outcome.IN_PROGRESS, "Defeat should wait for the final Trap.")
	_resolve(state)
	var end_screen = scene.get_node("EndScreen")
	_check(state.outcome == GameState.Outcome.LOST and end_screen.panel.visible and end_screen.title.text == "DERROTA", "Defeat should show the loss screen.")
	var cards: Array[Node] = end_screen.herd.get_children()
	_check(cards.size() > 20, "Defeat should spawn a herd of enemy cards.")
	if not cards.is_empty():
		var first_card: Node2D = cards[0]
		var start_y := first_card.position.y
		_check(start_y < 0.0, "Herd cards should start above the screen.")
		await create_timer(0.3).timeout
		_check(first_card.position.y > start_y and first_card.scale.x > 0.7, "Herd cards should move down and grow toward the player.")
		await create_timer(3.0).timeout
		var bounds := Rect2()
		var first_bounds := true
		for card in cards:
			var sprite := card.get_node("Sprite2D") as Sprite2D
			var card_size: Vector2 = sprite.get_rect().size * sprite.scale.abs() * card.scale.abs()
			var card_bounds := Rect2(card.position - card_size / 2.0, card_size)
			bounds = card_bounds if first_bounds else bounds.merge(card_bounds)
			first_bounds = false
		var viewport_size := root.get_visible_rect().size
		_check(bounds.position.x <= 0.0 and bounds.position.y <= 0.0 and bounds.end.x >= viewport_size.x and bounds.end.y >= viewport_size.y, "The herd should cover the viewport.")
	await _test_result_story(end_screen, "defeat")
	var restart := InputEventKey.new()
	restart.keycode = KEY_R
	restart.pressed = true
	manager._input(restart)
	await create_timer(1.3).timeout
	_check(current_scene != null and current_scene != scene, "Restart should work after defeat.")
	if current_scene != null and current_scene != scene:
		_check(current_scene.get_node("CardManager").state.outcome == GameState.Outcome.IN_PROGRESS and not current_scene.get_node("EndScreen").panel.visible, "Restart should clear the end screen and restore the game.")
	await create_timer(1.3).timeout
	if current_scene != null:
		current_scene.free()
		current_scene = null

func _test_restart() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var elephant_sound := scene.get_node("ElephantSound") as AudioStreamPlayer2D
	_check(elephant_sound.playing, "The elephant sound should play when the game first starts.")
	var music := scene.get_node("AudioStreamPlayer2D") as AudioStreamPlayer2D
	var music_stream := music.stream as AudioStreamMP3
	_check(music.playing and music_stream != null and music_stream.loop, "Combat music should start with looping enabled.")
	if music_stream != null and music_stream.get_length() > 2.0:
		music.play(music_stream.get_length() - 0.5)
		await create_timer(1.0).timeout
		_check(music.playing and music.get_playback_position() < 2.0, "Combat music should restart after reaching the end.")
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
	await create_timer(0.4).timeout
	var event := InputEventKey.new()
	event.keycode = KEY_R
	event.pressed = true
	event.echo = true
	manager._input(event)
	_check(current_scene == scene, "Repeated key events should not restart the game.")
	event.echo = false
	Input.parse_input_event(event)
	await process_frame
	var transition := root.get_node_or_null("RestartTransition")
	_check(transition != null and current_scene == scene, "Restart should begin with wind before reloading.")
	if transition == null:
		scene.free()
		current_scene = null
		return
	var reload_progress := []
	scene.tree_exiting.connect(func() -> void: reload_progress.append(transition.progress))
	_check(transition.background.anchor_right == 1.0 and transition.background.anchor_bottom == 1.0 and transition.layer > 50, "Wind should cover the viewport above the HUD and end screen.")
	_check(transition.wind_material.shader == load("res://ui/start_intro.gdshader") and transition.wind_material.get_shader_parameter("transition_mode") == 1, "Restart should use the start-screen wind shader to cover the game.")
	_check(transition.gust_audio.playing and transition.gust_audio.stream.resource_path == "res://assets/audio/small-wind.mp3", "Restart should play the same gust as the start-screen transition.")
	var gust_audio: AudioStreamPlayer = transition.gust_audio
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	manager._input(cancel)
	_check(old_state.pending_card == magic, "Gameplay input should be blocked during the wind transition.")
	Input.parse_input_event(event)
	await create_timer(0.25).timeout
	var progress: float = transition.progress
	_check(progress > 0.0 and progress < 1.0 and current_scene == scene, "Wind should sweep across the screen before reloading.")
	_check(old_state.damage_bonus == 0, "Pending effects should not resolve during the restart transition.")
	await create_timer(1.05).timeout
	_check(current_scene != scene and root.get_node_or_null("RestartTransition") == transition, "Scene should reload while the wind remains visible.")
	if current_scene == null or current_scene == scene:
		transition.queue_free()
		scene.free()
		current_scene = null
		return
	var restarted = current_scene.get_node("CardManager").state
	_check(not (current_scene.get_node("ElephantSound") as AudioStreamPlayer2D).playing, "Restart should not replay the elephant sound.")
	_check(reload_progress.size() == 1 and is_equal_approx(reload_progress[0], 1.0), "Scene should reload at full wind coverage.")
	_check(transition.wind_material.get_shader_parameter("transition_mode") == 2 and transition.progress < 0.2, "Wind should start revealing the new scene after reload.")
	_check(restarted.board[0][0].current_hp == 10 and restarted.player.hand.size() == 4 and restarted.damage_bonus == 0, "Restart should restore the starting state.")
	var restarted_scene := current_scene
	var reveal_progress: float = transition.progress
	Input.parse_input_event(event)
	await create_timer(0.15).timeout
	progress = transition.progress
	_check(progress > reveal_progress and progress < 1.0 and current_scene == restarted_scene, "Wind should reveal the game and block another restart.")
	await create_timer(1.1).timeout
	_check(root.get_node_or_null("RestartTransition") == null, "Wind overlay should be removed after revealing the game.")
	_check(restarted.damage_bonus == 0 and old_state.damage_bonus == 0, "Pending effects should not resolve after restart.")
	if is_instance_valid(gust_audio) and gust_audio.playing:
		_check(gust_audio.get_parent() == root, "The gust should keep playing without blocking the restarted game.")
		await gust_audio.finished
		await process_frame
		_check(not is_instance_valid(gust_audio), "The gust should be removed after finishing.")
	current_scene.get_node("CardManager")._input(event)
	await create_timer(1.3).timeout
	_check(current_scene != null and current_scene != restarted_scene, "A subsequent restart should reload the game.")
	if current_scene != null and current_scene != restarted_scene:
		_check(not (current_scene.get_node("ElephantSound") as AudioStreamPlayer2D).playing, "Subsequent restarts should not replay the elephant sound.")
	await create_timer(1.3).timeout
	if current_scene != null:
		current_scene.free()
	current_scene = null

func _test_preview_spawn() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	var manager = scene.get_node("CardManager")
	var tooltip = scene.get_node("HUD/CardTooltip")
	var axe: Node2D = manager.hand_layout.cards[0]
	var spear: Node2D = manager.hand_layout.cards[1]
	_motion(manager, axe.get_global_transform_with_canvas() * Vector2.ZERO)
	await create_timer(0.35).timeout
	var progress: float = tooltip.spawn_material.get_shader_parameter("spawn_progress")
	_check(tooltip.visible and progress > 0.0 and progress < 1.0 and tooltip.preview.name_label.modulate.a > 0.0 and tooltip.preview.name_label.modulate.a < 1.0 and is_equal_approx(tooltip.preview.modulate.a, 1.0), "Wind should reveal the card while its labels fade in independently.")
	tooltip.refresh()
	_check(is_equal_approx(tooltip.spawn_material.get_shader_parameter("spawn_progress"), progress), "Refreshing a preview should not restart its spawn animation.")
	_motion(manager, spear.get_global_transform_with_canvas() * Vector2.ZERO)
	_check(not tooltip.visible and tooltip.preview.visible and tooltip.preview_disappearing, "Changing cards should hide the description and start the wind disappearance.")
	await create_timer(0.1).timeout
	var vanishing_progress: float = tooltip.spawn_material.get_shader_parameter("spawn_progress")
	_check(vanishing_progress < progress and vanishing_progress > 0.0, "Wind should gradually remove the previous preview.")
	await create_timer(0.25).timeout
	progress = tooltip.spawn_material.get_shader_parameter("spawn_progress")
	_check(tooltip.visible and tooltip.preview.data == spear.data and progress > 0.0 and progress < 1.0, "The next card should begin a new spawn animation.")
	await create_timer(0.65).timeout
	_check(is_equal_approx(tooltip.spawn_material.get_shader_parameter("spawn_progress"), 1.0) and is_equal_approx(tooltip.preview.name_label.modulate.a, 1.0), "The spawn animation should finish with the card fully visible.")
	_motion(manager, Vector2.ZERO)
	_check(not tooltip.visible and tooltip.preview.visible, "Leaving the card should hide the description while the preview disappears.")
	await create_timer(0.15).timeout
	progress = tooltip.spawn_material.get_shader_parameter("spawn_progress")
	_check(progress > 0.0 and progress < 1.0, "The preview should vanish gradually in the wind.")
	await create_timer(0.25).timeout
	_check(not tooltip.preview.visible and is_equal_approx(tooltip.spawn_material.get_shader_parameter("spawn_progress"), 0.0), "The preview should be hidden after the wind clears it.")
	scene.free()

func _test_tooltips() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	var manager := scene.get_node("CardManager") as Node2D
	var tooltip = scene.get_node("HUD/CardTooltip")
	var name_label := tooltip.get_node("Margin/Sections/Name") as Label
	var text := tooltip.get_node("Margin/Sections/Text") as RichTextLabel
	var bonus_label := tooltip.get_node("Margin/Sections/Bonus") as RichTextLabel
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
	_check(tooltip.visible and name_label.text == "Lança", "Hovering a hand card should show its tooltip after the delay.")
	await process_frame
	await process_frame
	_check(text.get_global_rect().position.y - name_label.get_global_rect().end.y >= 12.0 and not bonus_label.visible, "The name and effect should have visible spacing without an empty bonus section.")
	_check(text.text.contains("]1[/color] de dano a um inimigo se esta carta estiver na linha 3") and text.text.contains("]2[/color] na linha 4"), "Spear tooltip should show both row damage values and identify the attacking card's row.")
	var preview = tooltip.preview
	var board_right: float = (manager.get_global_transform_with_canvas() * (manager.board.cell_position(Vector2i(3, 0)) + Vector2(manager.board.cell_size.x / 2.0, 0))).x
	var preview_size: Vector2 = preview.sprite.get_rect().size * preview.sprite.scale.abs() * preview.scale.abs()
	var preview_top: Vector2 = preview.get_global_transform_with_canvas().origin - preview_size / 2.0
	_check(preview.data == spear.data and preview.sprite.texture == spear.sprite.texture and preview.scale.x > 1.0, "Preview should show a larger copy of the hovered card.")
	_check(preview_top.x >= board_right and preview_top.y + preview_size.y <= tooltip.get_global_rect().position.y, "Preview should appear to the right of the grid with the description below it.")
	var original_position: Vector2 = tooltip.position
	tooltip.preview_offset += Vector2(12, 14)
	await process_frame
	await process_frame
	_check(tooltip.position.is_equal_approx(original_position + Vector2(12, 14)), "Preview offset should move the card and description together.")
	tooltip.preview_offset -= Vector2(12, 14)

	var original_description := Text.get_text("tooltip_spear")
	Text.config.set_value("text", "tooltip_spear", "Dano editado: %s / %s.")
	tooltip.refresh()
	_check(text.text.contains("Dano editado:"), "Tooltip text should come from the editable text file.")
	Text.config.set_value("text", "tooltip_spear", original_description)
	tooltip.refresh()

	manager.state.damage_bonus = 2
	manager.state.changed.emit()
	await process_frame
	await process_frame
	_check(text.text.contains("]3[/color] de dano") and text.text.contains("]4[/color] na linha 4") and bonus_label.text.contains("Bônus de magia"), "An open tooltip should update damage and bonus when Magic changes.")
	_check(bonus_label.visible and bonus_label.get_global_rect().position.y - text.get_global_rect().end.y >= 12.0, "The bonus should be visibly separated from the effect.")
	var original_bonus := Text.get_text("tooltip_bonus")
	Text.config.set_value("text", "tooltip_bonus", "Bônus editado: +%s.")
	tooltip.refresh()
	_check(bonus_label.text.begins_with("Bônus editado:"), "The bonus should use editable text without depending on a leading newline.")
	Text.config.set_value("text", "tooltip_bonus", original_bonus)
	tooltip.refresh()
	_check(preview.damage_bonus == 2 and preview.bonus_label.text == spear.bonus_label.text, "Preview should update the displayed damage bonus.")
	_check(text.get_content_height() <= text.size.y, "Tooltip text must fit without clipping.")
	_check(tooltip._effect_description(axe.data, 2).contains("]6[/color] de dano") and tooltip._effect_description(axe.data, 2).contains("]4[/color] na linha 4"), "Axe tooltip should include its bonus on both rows.")
	_check(tooltip._effect_description(trap.data, 2).contains("]7[/color] de dano"), "Trap tooltip should include the active bonus.")
	_check(tooltip._effect_description(magic.data, 2).contains("incluindo Armadilha") and tooltip._effect_description(magic.data, 2).contains("acumulam esse bônus"), "Magic tooltip should explain trap bonuses and stacking.")

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
	_check(tooltip.visible and name_label.text == "Elefante" and text.text.contains("]10[/color]") and not bonus_label.visible, "Board tooltip should show the enemy's current HP without a bonus section.")
	_check(preview.data == enemy.data and preview.sprite.texture == enemy.sprite.texture, "Preview should switch to the hovered board card.")
	manager.state.set_card_hp(enemy.data, 7)
	_check(text.text.contains("]7[/color]"), "An open enemy tooltip should update its HP.")
	_check(preview.hp_label.text == enemy.hp_label.text, "Preview should update the enemy's HP.")
	manager.position = Vector2(-450, -100)
	await process_frame
	var bounds: Rect2 = root.get_visible_rect()
	var tooltip_rect: Rect2 = tooltip.get_global_rect()
	_check(tooltip_rect.position.x >= bounds.position.x and tooltip_rect.position.y >= bounds.position.y and tooltip_rect.end.x <= bounds.end.x and tooltip_rect.end.y <= bounds.end.y, "Tooltip should stay inside the viewport near the top-left edge.")
	preview_size = preview.sprite.get_rect().size * preview.sprite.scale.abs() * preview.scale.abs()
	preview_top = preview.get_global_transform_with_canvas().origin - preview_size / 2.0
	_check(preview_top.x >= bounds.position.x and preview_top.y >= bounds.position.y, "Preview should stay visible near the top-left edge.")
	manager.position = Vector2(700, 500)
	await process_frame
	tooltip_rect = tooltip.get_global_rect()
	_check(tooltip_rect.position.x >= bounds.position.x and tooltip_rect.position.y >= bounds.position.y and tooltip_rect.end.x <= bounds.end.x and tooltip_rect.end.y <= bounds.end.y, "Tooltip should stay inside the viewport near the bottom-right edge.")
	preview_top = preview.get_global_transform_with_canvas().origin - preview_size / 2.0
	_check(preview_top.x + preview_size.x <= bounds.end.x and preview_top.y + preview_size.y <= tooltip_rect.position.y, "Preview should stay visible above the description near the bottom-right edge.")
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
	_check(tooltip.visible and text.text.contains("]6[/color] de dano") and text.text.contains("]4[/color] na linha 4"), "The played Axe tooltip should show the retained bonus during a chain.")
	manager.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	_check(not tooltip.visible, "Leaving the game window should hide the tooltip.")
	scene.free()

func _run() -> void:
	_test_effects()
	_test_cancellation_and_rows()
	_test_trap_bonus_and_full_row()
	_test_end_state()
	_test_row_highlight()
	await _test_row_penalty_badges()
	_test_card_hover_and_foil()
	await _test_card_drop_sound()
	await _test_axe_attack_sound()
	await _test_spear_attack_sound()
	await _test_magic_entry_sound()
	await _test_buff_particles_lifecycle()
	await _test_particles()
	await _test_screen_effects()
	await _test_card_movement()
	await _test_targeting_effects()
	await _test_preview_spawn()
	await _test_tooltips()
	await _test_ui()
	await _test_end_screens()
	await _test_restart()
	if not failed:
		print("Combat checks passed.")
	quit(1 if failed else 0)
