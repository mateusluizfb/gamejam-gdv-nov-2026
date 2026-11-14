@tool
extends RefCounted

var container: Node2D
var cards: Array
var origin: Vector2
var cell_size: Vector2

func _init(card_container: Node2D, initial_cards: Array, grid_origin: Vector2, grid_cell_size: Vector2) -> void:
	container = card_container
	cards = initial_cards
	origin = grid_origin
	cell_size = grid_cell_size

func place_cards() -> void:
	for row in range(cards.size()):
		for col in range(cards[row].size()):
			var card: Node2D = cards[row][col]
			if card != null:
				container.add_child(card)
				card.position = cell_position(Vector2i(col, row))

func cell_position(cell: Vector2i) -> Vector2:
	return origin + Vector2(cell) * cell_size

func find_card_cell(card: Node2D) -> Vector2i:
	for row in range(cards.size()):
		for col in range(cards[row].size()):
			if cards[row][col] == card:
				return Vector2i(col, row)
	return Vector2i(-1, -1)

func cell_at(position: Vector2) -> Vector2i:
	var relative_position := (position - origin) / cell_size
	var row := floori(relative_position.y + 0.5)
	var col := floori(relative_position.x + 0.5)
	if row >= 0 and row < cards.size() and col >= 0 and col < cards[row].size():
		return Vector2i(col, row)
	return Vector2i(-1, -1)

func try_add_card(card: Node2D, position: Vector2) -> bool:
	var cell := cell_at(position)
	if cell == Vector2i(-1, -1) or cards[cell.y][cell.x] != null:
		return false
	card.reparent(container, false)
	cards[cell.y][cell.x] = card
	card.position = cell_position(cell)
	return true

func remove_card(card: Node2D, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= cards.size() or cell.x < 0 or cell.x >= cards[cell.y].size() or cards[cell.y][cell.x] != card:
		push_error("Cannot remove a card from a grid cell that does not contain it.")
		return false
	cards[cell.y][cell.x] = null
	return true

func center_x() -> float:
	var columns := 0
	for row in cards:
		columns = maxi(columns, row.size())
	return origin.x + (columns - 1) * cell_size.x / 2.0

func draw_preview() -> void:
	for row in range(cards.size()):
		for col in range(cards[row].size()):
			draw_cell(cell_position(Vector2i(col, row)))

func draw_cell(center: Vector2, angle: float = 0.0) -> void:
	var rect := Rect2(-cell_size / 2.0, cell_size)
	container.draw_set_transform(center, angle)
	container.draw_rect(rect, Color(0.3, 0.6, 1.0, 0.12))
	container.draw_rect(rect, Color(0.3, 0.6, 1.0, 0.8), false, 1.0)
	container.draw_set_transform(Vector2.ZERO)
