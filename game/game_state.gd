@tool
extends RefCounted

const CardData = preload("res://cards/card_data.gd")
const PlayerData = preload("res://game/player_data.gd")

enum Phase { IDLE, TARGETING, RESOLVING }

signal changed
signal phase_changed
signal card_placed(card, cell)
signal card_returned(card, index, cell)
signal card_removed(card)
signal card_restored(card, cell)
signal card_moved(card, from, to)
signal effect_started(token)
signal trap_triggered(row)
signal magic_applied
signal axe_attacked
signal spear_attacked
signal feedback(message)

var player := PlayerData.new()
var board: Array = []
var phase := Phase.IDLE:
	set(value):
		if phase != value:
			phase = value
			phase_changed.emit()
var damage_bonus := 0
var pending_card: CardData
var pending_target: CardData
var pending_damage := 0
var pending_hand_index := -1
var pending_original_bonus := 0
var axe_hits: Array = []
var effect_token := 0

func _init(records: Array) -> void:
	for row in range(4):
		board.append([null, null, null, null])
	for record in records:
		var card: CardData = record["card"]
		var cell: Variant = record["cell"]
		if cell == null:
			player.hand.append(card)
		else:
			card.board_position = cell
			board[cell.y][cell.x] = card

func _valid_placement(card: CardData, cell: Vector2i) -> bool:
	if phase != Phase.IDLE or not player.hand.has(card) or card.owner != CardData.Owner.PLAYER:
		return false
	if cell.x < 0 or cell.x >= 4 or cell.y < 0 or cell.y >= 4 or board[cell.y][cell.x] != null:
		return false
	if card.type == CardData.Type.TRAP:
		if cell.y >= 2:
			return false
	elif cell.y < 2:
		return false
	return true

func can_play_card(card: CardData, cell: Vector2i) -> bool:
	return _valid_placement(card, cell) and (card.type not in [CardData.Type.AXE, CardData.Type.SPEAR] or _has_enemies())

func play_card(card: CardData, cell: Vector2i) -> bool:
	if not _valid_placement(card, cell):
		return false
	if card.type in [CardData.Type.AXE, CardData.Type.SPEAR] and not _has_enemies():
		feedback.emit("Não há inimigos disponíveis como alvo.")
		return false
	pending_hand_index = player.hand.find(card)
	player.hand.erase(card)
	board[cell.y][cell.x] = card
	card.board_position = cell
	pending_card = card
	pending_original_bonus = damage_bonus
	axe_hits.clear()
	card_placed.emit(card, cell)
	changed.emit()
	match card.type:
		CardData.Type.AXE:
			pending_damage = (CardData.AXE_BOTTOM_DAMAGE if cell.y == 3 else CardData.AXE_UPPER_DAMAGE) + damage_bonus
			phase = Phase.TARGETING
			feedback.emit("Selecione um inimigo para o Machado (%d de dano). Esc cancela." % pending_damage)
		CardData.Type.SPEAR:
			pending_damage = (CardData.SPEAR_BOTTOM_DAMAGE if cell.y == 3 else CardData.SPEAR_UPPER_DAMAGE) + damage_bonus
			phase = Phase.TARGETING
			feedback.emit("Selecione um inimigo para a Lança (%d de dano). Esc cancela." % pending_damage)
		CardData.Type.TRAP:
			pending_damage = CardData.TRAP_DAMAGE + damage_bonus
			_start_effect()
		CardData.Type.MAGIC:
			_start_effect()
	return true

func select_target(target: CardData) -> bool:
	if phase != Phase.TARGETING or not _is_board_enemy(target):
		return false
	pending_target = target
	_start_effect()
	return true

func cancel_play() -> bool:
	if phase == Phase.IDLE or pending_card == null:
		return false
	for hit in axe_hits:
		var target: CardData = hit["card"]
		var target_cell: Vector2i = hit["cell"]
		target.current_hp = hit["hp"]
		target.board_position = target_cell
		board[target_cell.y][target_cell.x] = target
		card_restored.emit(target, target_cell)
	damage_bonus = pending_original_bonus
	var card := pending_card
	var cell: Vector2i = card.board_position
	board[cell.y][cell.x] = null
	card.board_position = null
	player.hand.insert(pending_hand_index, card)
	effect_token += 1
	_reset_pending()
	card_returned.emit(card, pending_hand_index, cell)
	changed.emit()
	feedback.emit("Carta devolvida à mão; ataques pendentes desfeitos.")
	return true

func _start_effect() -> void:
	phase = Phase.RESOLVING
	effect_token += 1
	feedback.emit("Aplicando efeito de %s..." % pending_card.display_name())
	effect_started.emit(effect_token)

func resolve_effect(token: int) -> void:
	if phase != Phase.RESOLVING or token != effect_token or pending_card == null:
		return
	var card := pending_card
	var message := ""
	match card.type:
		CardData.Type.MAGIC:
			damage_bonus += CardData.MAGIC_BONUS
			magic_applied.emit()
			message = "Magia: +%d de dano ao próximo ataque (total +%d)." % [CardData.MAGIC_BONUS, damage_bonus]
		CardData.Type.TRAP:
			damage_bonus = 0
			var row: int = card.board_position.y
			trap_triggered.emit(row)
			var hits := 0
			for target in board[row].duplicate():
				if target != null and target.owner == CardData.Owner.ENEMY:
					set_card_hp(target, target.current_hp - pending_damage)
					hits += 1
			message = "Armadilha: %d de dano a %d inimigos na linha %d." % [pending_damage, hits, row + 1]
			_remove_board_card(card)
		CardData.Type.AXE, CardData.Type.SPEAR:
			var target := pending_target
			if not _is_board_enemy(target):
				push_error("Cannot resolve an attack without its enemy target.")
				_reset_pending()
				changed.emit()
				return
			damage_bonus = 0
			if card.type == CardData.Type.AXE:
				axe_hits.append({"card": target, "cell": target.board_position, "hp": target.current_hp})
			set_card_hp(target, target.current_hp - pending_damage)
			if card.type == CardData.Type.AXE:
				axe_attacked.emit()
			else:
				spear_attacked.emit()
			message = "%s: %d de dano (PV do alvo: %d)." % [card.display_name(), pending_damage, target.current_hp]
			if card.type == CardData.Type.AXE and target.current_hp <= 0 and _has_enemies():
				pending_target = null
				phase = Phase.TARGETING
				changed.emit()
				feedback.emit(message + " Selecione outro inimigo; Esc desfaz a jogada.")
				return
			if card.type == CardData.Type.SPEAR and target.current_hp > 0:
				if not _move_enemy_to_other_row(target):
					message += " A outra linha inimiga está cheia; o alvo permanece."
	_reset_pending()
	changed.emit()
	feedback.emit(message)

func _reset_pending() -> void:
	phase = Phase.IDLE
	pending_card = null
	pending_target = null
	pending_damage = 0
	axe_hits.clear()

func _is_board_enemy(card: CardData) -> bool:
	if card == null or card.owner != CardData.Owner.ENEMY or card.board_position == null:
		return false
	var cell: Vector2i = card.board_position
	return cell.x >= 0 and cell.x < 4 and cell.y >= 0 and cell.y < 2 and board[cell.y][cell.x] == card

func _has_enemies() -> bool:
	for row in range(2):
		for card in board[row]:
			if card != null and card.owner == CardData.Owner.ENEMY:
				return true
	return false

func _move_enemy_to_other_row(card: CardData) -> bool:
	var from: Vector2i = card.board_position
	var destination_row := 1 - from.y
	var column := -1
	for distance in range(4):
		for candidate in [from.x - distance, from.x + distance]:
			if candidate >= 0 and candidate < 4 and board[destination_row][candidate] == null:
				column = candidate
				break
		if column >= 0:
			break
	if column < 0:
		return false
	var to := Vector2i(column, destination_row)
	board[from.y][from.x] = null
	board[to.y][to.x] = card
	card.board_position = to
	card_moved.emit(card, from, to)
	return true

func set_card_hp(card: CardData, hp: int) -> bool:
	if card.board_position == null:
		push_error("Cannot change HP on a card outside the board.")
		return false
	var cell: Vector2i = card.board_position
	if cell.x < 0 or cell.x >= 4 or cell.y < 0 or cell.y >= 4 or board[cell.y][cell.x] != card:
		push_error("Cannot change HP on a card not present at its board position.")
		return false
	card.current_hp = hp
	if hp <= 0:
		_remove_board_card(card)
	changed.emit()
	return true

func _remove_board_card(card: CardData) -> void:
	var cell: Vector2i = card.board_position
	board[cell.y][cell.x] = null
	card.board_position = null
	card_removed.emit(card)
