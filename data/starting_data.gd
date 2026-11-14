@tool
extends RefCounted

const CardData = preload("res://cards/card_data.gd")
const HEADER := ["type", "owner", "zone", "row", "column", "base_hp", "image_path", "board_rows", "board_columns"]
const TYPES := {
	"elephant": CardData.Type.ELEPHANT,
	"magic": CardData.Type.MAGIC,
	"axe": CardData.Type.AXE,
	"spear": CardData.Type.SPEAR,
	"trap": CardData.Type.TRAP
}

static func load_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "%s: não foi possível abrir o arquivo (erro %s)." % [path, FileAccess.get_open_error()]}
	var records: Array = []
	var definitions := {}
	var occupied := {}
	var board_configured := false
	var line_number := 0
	while not file.eof_reached():
		var line := file.get_line()
		if file.eof_reached() and line.is_empty():
			break
		line_number += 1
		var parsed := _parse_line(line)
		if parsed.has("error"):
			return _error(path, line_number, parsed["error"])
		var fields: Array = parsed["fields"]
		if line_number == 1:
			if fields != HEADER:
				return _error(path, line_number, "Cabeçalho esperado: %s." % ",".join(HEADER))
			continue
		if fields.size() != HEADER.size():
			return _error(path, line_number, "Esperados %d campos, recebidos %d." % [HEADER.size(), fields.size()])
		var type: String = fields[0]
		var owner: String = fields[1]
		var zone: String = fields[2]
		if type.is_empty():
			if board_configured:
				return _error(path, line_number, "Configuração do tabuleiro duplicada.")
			for i in range(7):
				if not fields[i].is_empty():
					return _error(path, line_number, "A configuração do tabuleiro não deve conter campos de carta.")
			if fields[7] != "4" or fields[8] != "4":
				return _error(path, line_number, "board_rows e board_columns devem ser 4.")
			board_configured = true
			continue
		if not TYPES.has(type):
			return _error(path, line_number, "Tipo de carta desconhecido: '%s'." % type)
		if not fields[7].is_empty() or not fields[8].is_empty():
			return _error(path, line_number, "As dimensões do tabuleiro devem aparecer somente na linha de configuração.")
		if not fields[5].is_valid_int() or int(fields[5]) <= 0:
			return _error(path, line_number, "base_hp deve ser um número inteiro positivo.")
		var hp := int(fields[5])
		var image: String = fields[6]
		if not image.begins_with("res://") or not ResourceLoader.exists(image, "Texture2D"):
			return _error(path, line_number, "image_path '%s' não é um recurso de textura." % image)
		var texture := load(image)
		if not texture is Texture2D:
			return _error(path, line_number, "Não foi possível carregar image_path '%s' como textura." % image)
		if definitions.has(type):
			var previous: Array = definitions[type]
			if previous[1] != image or (type != "elephant" and previous[0] != hp):
				return _error(path, line_number, "base_hp ou image_path conflitante para o tipo '%s'." % type)
		definitions[type] = [hp, image]
		var cell: Variant = null
		if type == "elephant":
			if owner != "enemy" or zone != "board":
				return _error(path, line_number, "Elefantes devem ser cartas inimigas no tabuleiro.")
			if not fields[3].is_valid_int() or not fields[4].is_valid_int():
				return _error(path, line_number, "A linha e a coluna do tabuleiro devem ser números inteiros.")
			cell = Vector2i(int(fields[4]), int(fields[3]))
			if cell.x < 0 or cell.x >= 4 or cell.y < 0 or cell.y >= 2:
				return _error(path, line_number, "A posição inimiga deve estar nas linhas 0-1 e colunas 0-3.")
			if occupied.has(cell):
				return _error(path, line_number, "Posição duplicada no tabuleiro (%d, %d)." % [cell.y, cell.x])
			occupied[cell] = true
		else:
			if owner != "player" or zone != "hand" or not fields[3].is_empty() or not fields[4].is_empty():
				return _error(path, line_number, "As cartas do jogador devem começar na mão, com linha e coluna vazias.")
		var card_owner: CardData.Owner = CardData.Owner.ENEMY if owner == "enemy" else CardData.Owner.PLAYER
		var card := CardData.new(TYPES[type], card_owner, hp, image)
		records.append({"card": card, "cell": cell})
	if line_number == 0:
		return _error(path, 1, "Cabeçalho ausente.")
	if not board_configured:
		return _error(path, line_number, "Linha de configuração do tabuleiro ausente.")
	if records.is_empty():
		return _error(path, 2, "Nenhuma carta inicial.")
	return {"records": records}

static func _error(path: String, line: int, message: String) -> Dictionary:
	return {"error": "%s:%d: %s" % [path, line, message]}

static func _parse_line(line: String) -> Dictionary:
	var fields: Array = []
	var field := ""
	var quoted := false
	var closed_quote := false
	var i := 0
	while i < line.length():
		var ch := line[i]
		if quoted:
			if ch == "\"":
				if i + 1 < line.length() and line[i + 1] == "\"":
					field += "\""
					i += 1
				else:
					quoted = false
					closed_quote = true
			else:
				field += ch
		elif ch == ",":
			fields.append(field)
			field = ""
			closed_quote = false
		elif ch == "\"" and field.is_empty() and not closed_quote:
			quoted = true
		elif ch == "\"" or closed_quote:
			return {"error": "Aspas malformadas no CSV."}
		else:
			field += ch
		i += 1
	if quoted:
		return {"error": "Aspas não fechadas no CSV; campos com várias linhas não são aceitos."}
	fields.append(field)
	return {"fields": fields}
