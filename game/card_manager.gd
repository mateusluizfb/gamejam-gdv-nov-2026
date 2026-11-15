@tool
extends Node2D

const Board = preload("res://game/card_board.gd")
const Hand = preload("res://game/card_hand.gd")
const CardData = preload("res://cards/card_data.gd")
const StartingData = preload("res://data/starting_data.gd")
const GameState = preload("res://game/game_state.gd")
const CardTooltip = preload("res://ui/card_tooltip.gd")
const CardParticles = preload("res://game/card_particles.gd")
const RestartTransition = preload("res://game/restart_transition.gd")
const TargetArrow = preload("res://game/target_arrow.gd")
const ScreenEffects = preload("res://game/screen_effects.gd")
const EndScreen = preload("res://game/end_screen.gd")
const Text = preload("res://data/text.gd")
const CARD_SCENE: PackedScene = preload("res://cards/card.tscn")
const MAGIC_BURN_SHADER: Shader = preload("res://cards/magic_burn.gdshader")
const STARTING_DATA_PATH := "res://starting_cards.csv"
const GRID_ORIGIN := Vector2(467, 104)
const GRID_SCALE := 0.9
const HAND_GAP := 18.0
const EFFECT_DELAY := 0.5
const MAGIC_BURN_DURATION := 0.6
const BOARD_HOVER_SCALE := 1.25

var board: Board
var hand_layout: Hand
var state: GameState
var card_views: Dictionary = {}
var dragged_card: Node2D
var drag_offset := Vector2.ZERO
var highlighted_row := -1
var valid_placement_cells: Array[Vector2i] = []
var targeting_arrow: TargetArrow
var cursor_position := Vector2.ZERO
var hovered_board_card: Node2D
var hovered_board_scale := Vector2.ONE
var hovered_board_z_index := 0
var foil_card: Node2D

@onready var card_drop_sound: AudioStreamPlayer = $CardDropSound
@onready var axe_attack_sound: AudioStreamPlayer = $AxeAttackSound
@onready var spear_attack_sound: AudioStreamPlayer = $SpearAttackSound
@onready var magic_entry_sound: AudioStreamPlayer = $MagicEntrySound
@onready var trap_sound: AudioStreamPlayer = $TrapSound
@onready var screen_effects: ScreenEffects = $"../ScreenEffects"
@onready var end_screen: EndScreen = $"../EndScreen"

func _ready() -> void:
	var restart_hint := get_node_or_null("../HUD/RestartHint") as Label
	if restart_hint != null:
		restart_hint.text = Text.get_text("restart_hint")
	var hand_node := get_node_or_null("Hand") as Node2D
	if hand_node == null:
		_fail_startup(Text.get_text("startup_no_hand"))
		return
	var result := StartingData.load_file(STARTING_DATA_PATH)
	if result.has("error"):
		_fail_startup(result["error"])
		return
	var cell_size := _get_cell_size(result["records"])
	if cell_size == Vector2.ZERO:
		_fail_startup(Text.get_text("startup_no_sprite"))
		return
	state = GameState.new(result["records"])
	var board_views: Array = []
	for row in state.board:
		var view_row: Array = []
		for card in row:
			view_row.append(_new_card_view(card) if card != null and not Engine.is_editor_hint() else null)
		board_views.append(view_row)
	board = Board.new(self, board_views, GRID_ORIGIN, cell_size)
	var background := get_node_or_null("../BackgroundLayer/Background") as TextureRect
	if background != null and background.material is ShaderMaterial:
		var last_row := board.cell_position(Vector2i(0, board_views.size() - 1))
		var grid_bottom := to_global(last_row + Vector2(0.0, cell_size.y * 0.5)).y
		background.material.set_shader_parameter("board_bottom", (grid_bottom + 8.0) / 720.0)
	var hand_views: Array = []
	var hand_scenes: Array[PackedScene] = []
	for card in state.player.hand:
		hand_scenes.append(CARD_SCENE)
		if not Engine.is_editor_hint():
			hand_views.append(_new_card_view(card))
	hand_layout = Hand.new(self, hand_node, board, hand_scenes, hand_views, HAND_GAP)
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if not get_tree().root.has_node("RestartTransition"):
		$"../ElephantSound".play()
	state.changed.connect(_refresh_state)
	state.phase_changed.connect(_refresh_targeting)
	state.card_placed.connect(_place_card_view)
	state.card_returned.connect(_return_card_view)
	state.card_removed.connect(_remove_card_view)
	state.card_restored.connect(_restore_card_view)
	state.card_moved.connect(_move_card_view)
	state.effect_started.connect(_resolve_after_delay)
	state.trap_triggered.connect(_show_trap_effect)
	state.magic_applied.connect(screen_effects.play_magic)
	state.axe_attacked.connect(axe_attack_sound.play)
	state.axe_attacked.connect(screen_effects.play_impact)
	state.spear_attacked.connect(spear_attack_sound.play)
	state.spear_attacked.connect(screen_effects.play_impact)
	state.feedback.connect(_show_feedback)
	state.game_finished.connect(_show_game_result)
	board.place_cards()
	hand_layout.place_cards()
	cursor_position = get_viewport().get_mouse_position()
	_refresh_state()
	if state.outcome != GameState.Outcome.IN_PROGRESS:
		_show_game_result(state.outcome)
	queue_redraw()

func _fail_startup(message: String) -> void:
	push_error(message)
	set_process_input(false)
	var error_label := get_node_or_null("../HUD/Error") as Label
	if error_label != null:
		error_label.text = Text.get_text("startup_error") % message
		error_label.show()

func _get_cell_size(records: Array) -> Vector2:
	var sample_card := CARD_SCENE.instantiate() as Node2D
	var sprite := sample_card.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.get_rect().size.x <= 0 or sprite.get_rect().size.y <= 0:
		sample_card.free()
		return Vector2.ZERO
	var max_texture_size := sprite.get_rect().size
	for record in records:
		var card: CardData = record["card"]
		var texture := load(card.image_path) as Texture2D
		max_texture_size = max_texture_size.max(texture.get_size())
	var size := max_texture_size * sprite.scale.abs() * sample_card.scale.abs() + Vector2(Board.COLUMN_GAP, Board.ROW_GAP)
	sample_card.free()
	return size * GRID_SCALE

func _new_card_view(card: CardData) -> Node2D:
	var view := CARD_SCENE.instantiate()
	view.data = card
	if card.board_position != null:
		view.scale *= GRID_SCALE
	view.connect("movement_updated", _on_card_movement.bind(view))
	card_views[card] = view
	return view

func _on_card_movement(view: Node2D) -> void:
	if targeting_arrow != null and state.pending_card == view.data:
		targeting_arrow.set_points(to_local(view.global_position), targeting_arrow.end)
	if foil_card == view:
		view.set_foil_hover(true, cursor_position)

func _refresh_state() -> void:
	for card in card_views:
		var view = card_views[card]
		view.damage_bonus = state.damage_bonus if state.player.hand.has(card) else 0
		view.damage_bonus = _card_damage_bonus(view)
		view.refresh()
		CardParticles.set_magic_buff(view, view.damage_bonus > 0)
	_refresh_targeting()
	if is_instance_valid(dragged_card):
		_update_drop_highlight()
	var tooltip := get_node_or_null("../HUD/CardTooltip") as CardTooltip
	if tooltip != null and tooltip.is_node_ready():
		if is_instance_valid(tooltip.hovered_card):
			tooltip.set_hovered(tooltip.hovered_card, _card_damage_bonus(tooltip.hovered_card))
		tooltip.refresh()

func _refresh_targeting() -> void:
	var targeting := state.phase == GameState.Phase.TARGETING
	for card: CardData in card_views:
		var is_enemy: bool = card.owner == CardData.Owner.ENEMY and card.board_position != null and card.board_position.y < 2
		CardParticles.set_target_aura(card_views[card], targeting and is_enemy)
	if not targeting:
		if targeting_arrow != null:
			remove_child(targeting_arrow)
			targeting_arrow.queue_free()
			targeting_arrow = null
		return
	if targeting_arrow == null:
		targeting_arrow = TargetArrow.new()
		targeting_arrow.name = "TargetArrow"
		targeting_arrow.z_index = 100
		add_child(targeting_arrow)
	var attacker: Node2D = card_views[state.pending_card]
	targeting_arrow.set_points(to_local(attacker.global_position), _mouse_position_in_manager(cursor_position))

func _remove_card_view(card: CardData) -> void:
	if not card_views.has(card):
		push_error("Removed card has no view.")
		return
	var view: Node2D = card_views[card]
	if hovered_board_card == view:
		_clear_card_hover()
	var tooltip := get_node_or_null("../HUD/CardTooltip") as CardTooltip
	if tooltip != null and tooltip.hovered_card == view:
		tooltip.set_hovered(null, 0)
	var cell := board.find_card_cell(view)
	if not board.remove_card(view, cell):
		return
	card_views.erase(card)
	if card.type == CardData.Type.MAGIC and state.pending_card == card and state.phase == GameState.Phase.RESOLVING:
		view.stop_moving()
		view.position = board.cell_position(cell)
		var material := ShaderMaterial.new()
		material.shader = MAGIC_BURN_SHADER
		material.set_shader_parameter("burn_progress", 0.0)
		view.get_node("Sprite2D").material = material
		var tween := view.create_tween().set_parallel(true)
		tween.tween_property(material, "shader_parameter/burn_progress", 1.0, MAGIC_BURN_DURATION)
		for child in view.get_children():
			if child is Control:
				tween.tween_property(child, "modulate:a", 0.0, MAGIC_BURN_DURATION)
		tween.chain().tween_callback(view.queue_free)
	else:
		view.queue_free()

func _place_card_view(card: CardData, cell: Vector2i) -> void:
	var view: Node2D = card_views[card]
	_clear_card_hover()
	if dragged_card == view:
		CardParticles.stop_drag(view)
		dragged_card = null
		_clear_placement_highlights()
	var tooltip := get_node_or_null("../HUD/CardTooltip") as CardTooltip
	if tooltip != null and tooltip.hovered_card == view:
		tooltip.set_hovered(null, 0)
	hand_layout.set_hovered(null)
	hand_layout.end_drag(view)
	if not board.try_add_card(view, board.cell_position(cell)):
		push_error("Card view could not follow a successful board play.")
		return
	view.scale *= GRID_SCALE
	hand_layout.remove_card(view)
	hand_layout.place_cards()
	if card.type == CardData.Type.MAGIC:
		magic_entry_sound.play()

func _return_card_view(card: CardData, index: int, cell: Vector2i) -> void:
	var view: Node2D = card_views[card]
	if hovered_board_card == view:
		_clear_card_hover()
	if not board.remove_card(view, cell):
		return
	if card.type == CardData.Type.MAGIC:
		magic_entry_sound.stop()
	hand_layout.return_card(view, index)

func _restore_card_view(card: CardData, cell: Vector2i) -> void:
	if card_views.has(card) or board.cards[cell.y][cell.x] != null:
		push_error("Cannot restore an enemy into an occupied board view.")
		return
	var view := _new_card_view(card)
	add_child(view)
	board.cards[cell.y][cell.x] = view
	view.position = board.cell_position(cell)

func _move_card_view(card: CardData, from: Vector2i, to: Vector2i) -> void:
	if hovered_board_card == card_views[card]:
		_clear_card_hover()
	var tooltip := get_node_or_null("../HUD/CardTooltip") as CardTooltip
	if tooltip != null and tooltip.hovered_card == card_views[card]:
		tooltip.set_hovered(null, 0)
	board.move_card(card_views[card], from, to)

func _resolve_after_delay(token: int) -> void:
	if state.pending_target != null:
		var target_view: Node2D = card_views[state.pending_target]
		CardParticles.damage(self, to_local(target_view.global_position))
	await get_tree().create_timer(EFFECT_DELAY).timeout
	var restart_transition := get_tree().root.get_node_or_null("RestartTransition")
	if restart_transition != null:
		await restart_transition.finished
	state.resolve_effect(token)

func _show_trap_effect(row: int) -> void:
	trap_sound.play()
	screen_effects.play_impact()
	var row_size := Vector2(board.cards[row].size() * board.cell_size.x, board.cell_size.y)
	var row_origin := board.cell_position(Vector2i(0, row)) - board.cell_size / 2.0
	CardParticles.trap_row(self, Rect2(row_origin, row_size))

func _show_feedback(message: String) -> void:
	var label := get_node_or_null("../HUD/EffectMessage") as Label
	if label != null:
		label.text = message

func _show_game_result(outcome: GameState.Outcome) -> void:
	_clear_card_hover()
	var tooltip := get_node_or_null("../HUD/CardTooltip") as CardTooltip
	if tooltip != null and tooltip.is_node_ready():
		tooltip.set_hovered(null, 0)
	if is_instance_valid(dragged_card):
		CardParticles.stop_drag(dragged_card)
		hand_layout.end_drag(dragged_card)
		dragged_card = null
		_clear_placement_highlights()
		hand_layout.place_cards()
	hand_layout.set_hovered(null)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var enemies: Array[CardData] = []
	for row in range(2):
		for card in state.board[row]:
			if card != null and card.owner == CardData.Owner.ENEMY:
				enemies.append(card)
	end_screen.show_result(outcome, enemies)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and not Engine.is_editor_hint():
		_clear_card_hover()
		var tooltip := get_node_or_null("../HUD/CardTooltip") as CardTooltip
		if tooltip != null and tooltip.is_node_ready():
			tooltip.set_hovered(null, 0)
		if hand_layout != null and not is_instance_valid(dragged_card):
			hand_layout.set_hovered(null)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or board == null:
		return
	if get_tree().root.has_node("RestartTransition"):
		return
	if event is InputEventMouse:
		cursor_position = event.position
	if event.is_action_pressed("restart") and not event.is_echo():
		var transition := RestartTransition.new()
		transition.name = "RestartTransition"
		get_tree().root.add_child(transition)
		transition.start()
		return
	if state.phase == GameState.Phase.FINISHED:
		return
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(dragged_card):
			CardParticles.stop_drag(dragged_card)
			hand_layout.end_drag(dragged_card)
			dragged_card = null
			_clear_placement_highlights()
			hand_layout.place_cards()
		else:
			state.cancel_play()
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	if event is InputEventMouseMotion and not is_instance_valid(dragged_card):
		if state.phase == GameState.Phase.IDLE:
			_update_hand_hover(event.position)
		else:
			hand_layout.set_hovered(null)
		_update_tooltip_hover(event.position)
	if state.phase == GameState.Phase.TARGETING:
		if event is InputEventMouseMotion:
			targeting_arrow.set_points(targeting_arrow.start, _mouse_position_in_manager(event.position))
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if _enemy_at(event.position) != null else Input.CURSOR_ARROW)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var target := _enemy_at(event.position)
			if target != null:
				state.select_target(target)
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	if state.phase != GameState.Phase.IDLE:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventMouseMotion:
		if is_instance_valid(dragged_card):
			_move_drag(event.position)

func _enemy_at(mouse_position: Vector2) -> CardData:
	var view := _board_card_at(mouse_position)
	if view != null and view.data.owner == CardData.Owner.ENEMY and view.data.board_position.y < 2:
		return view.data
	return null

func _begin_drag(mouse_position: Vector2) -> void:
	var card := hand_layout.card_at(mouse_position)
	if card == null:
		return
	_clear_card_hover()
	var tooltip := get_node_or_null("../HUD/CardTooltip") as CardTooltip
	if tooltip != null:
		tooltip.set_hovered(null, 0)
	var card_position := to_local(card.global_position)
	hand_layout.begin_drag(card)
	dragged_card = card
	CardParticles.start_drag(card)
	drag_offset = card_position - _mouse_position_in_manager(mouse_position)
	_update_drop_highlight()

func _move_drag(mouse_position: Vector2) -> void:
	dragged_card.global_position = to_global(_mouse_position_in_manager(mouse_position) + drag_offset)
	_update_drop_highlight()

func _end_drag(mouse_position: Vector2) -> void:
	if is_instance_valid(dragged_card):
		_move_drag(mouse_position)
		var drop_position := to_local(dragged_card.global_position)
		var cell := board.cell_at(drop_position)
		CardParticles.stop_drag(dragged_card)
		CardParticles.drop(self, drop_position)
		card_drop_sound.play()
		hand_layout.end_drag(dragged_card)
		state.play_card(dragged_card.data, cell)
		hand_layout.place_cards()
	dragged_card = null
	_clear_placement_highlights()
	if state.phase != GameState.Phase.FINISHED:
		_update_hand_hover(mouse_position)
		_update_tooltip_hover(mouse_position)

func _update_drop_highlight() -> void:
	var cells: Array[Vector2i] = []
	for row in range(state.board.size()):
		for column in range(state.board[row].size()):
			var candidate := Vector2i(column, row)
			if state.can_play_card(dragged_card.data, candidate):
				cells.append(candidate)
	if valid_placement_cells != cells:
		valid_placement_cells = cells
		queue_redraw()
	var cell := board.cell_at(to_local(dragged_card.global_position))
	_set_highlighted_row(cell.y if state.can_play_card(dragged_card.data, cell) else -1)

func _clear_placement_highlights() -> void:
	if not valid_placement_cells.is_empty():
		valid_placement_cells.clear()
		queue_redraw()
	_set_highlighted_row(-1)

func _set_highlighted_row(row: int) -> void:
	if highlighted_row != row:
		highlighted_row = row
		queue_redraw()

func _update_hand_hover(mouse_position: Vector2) -> void:
	hand_layout.set_hovered(hand_layout.card_at(mouse_position))

func _update_tooltip_hover(mouse_position: Vector2) -> void:
	var view: Node2D
	if state.phase == GameState.Phase.IDLE:
		view = hand_layout.hovered_card
	if view == null:
		view = _board_card_at(mouse_position)
	_set_board_hover(view if view != null and board.find_card_cell(view) != Vector2i(-1, -1) else null)
	if foil_card != view:
		if is_instance_valid(foil_card):
			foil_card.set_foil_hover(false)
		foil_card = view
	if is_instance_valid(foil_card):
		foil_card.set_foil_hover(true, mouse_position)
	var tooltip := get_node_or_null("../HUD/CardTooltip") as CardTooltip
	if tooltip != null:
		tooltip.set_hovered(view, _card_damage_bonus(view) if view != null else 0)

func _board_card_at(mouse_position: Vector2) -> Node2D:
	for row in board.cards:
		for candidate in row:
			if candidate != null and candidate != hovered_board_card and hand_layout.card_contains_point(candidate, mouse_position):
				return candidate
	if is_instance_valid(hovered_board_card) and hand_layout.card_contains_point(hovered_board_card, mouse_position):
		return hovered_board_card
	return null

func _set_board_hover(view: Node2D) -> void:
	if hovered_board_card == view:
		return
	if is_instance_valid(hovered_board_card):
		hovered_board_card.scale = hovered_board_scale
		hovered_board_card.z_index = hovered_board_z_index
	hovered_board_card = view
	if view != null:
		hovered_board_scale = view.scale
		hovered_board_z_index = view.z_index
		var top_z := view.z_index
		for row in board.cards:
			for candidate in row:
				if candidate != null:
					top_z = maxi(top_z, candidate.z_index)
		view.scale = hovered_board_scale * BOARD_HOVER_SCALE
		view.z_index = mini(top_z + 1, RenderingServer.CANVAS_ITEM_Z_MAX)

func _clear_card_hover() -> void:
	_set_board_hover(null)
	if is_instance_valid(foil_card):
		foil_card.set_foil_hover(false)
	foil_card = null

func _card_damage_bonus(view: Node2D) -> int:
	if state.pending_card == view.data and view.data.type in [CardData.Type.AXE, CardData.Type.SPEAR, CardData.Type.TRAP]:
		return state.pending_original_bonus
	return view.damage_bonus

func _mouse_position_in_manager(mouse_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * mouse_position

func _draw() -> void:
	if board == null:
		return
	if Engine.is_editor_hint() and hand_layout != null:
		board.draw_preview()
		hand_layout.draw_preview()
	else:
		for cell in valid_placement_cells:
			board.draw_placement_cell(cell)
		if highlighted_row >= 0:
			board.draw_row_highlight(highlighted_row)
	board.draw_row_dividers()
