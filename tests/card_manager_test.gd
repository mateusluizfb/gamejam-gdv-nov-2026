extends SceneTree

const CardData = preload("res://cards/card_data.gd")
const StartingData = preload("res://data/starting_data.gd")
const GameState = preload("res://game/game_state.gd")

var failed := false

func _initialize() -> void:
	_test_loader()
	if not failed:
		print("CSV checks passed.")
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func _test_loader() -> void:
	var result := StartingData.load_file("res://starting_cards.csv")
	_check(not result.has("error"), "Default CSV should load: %s" % result.get("error", ""))
	if result.has("error"):
		return
	var records: Array = result["records"]
	var state := GameState.new(records)
	_check(records.size() == 7, "Default setup should have three board cards and four hand cards.")
	_check(state.board[0][0].current_hp == 10 and state.board[0][1].current_hp == 10 and state.board[1][1].current_hp == 13, "Elephants should start with their specified HP.")
	_check(state.board[0][2] == null and state.board[0][3] == null and state.board[1][0] == null and state.board[1][2] == null and state.board[1][3] == null, "Unexpected starting enemy card.")
	_check(state.player.hand.size() == 4, "Default hand should have four cards.")
	if state.player.hand.size() == 4:
		var types: Array = []
		for card in state.player.hand:
			types.append(card.type)
		_check(types == [CardData.Type.AXE, CardData.Type.SPEAR, CardData.Type.MAGIC, CardData.Type.TRAP], "Hand should contain one of each player card type.")
	var missing_path := "user://missing-starting-cards-%d-%d.csv" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(StartingData.load_file(missing_path).has("error"), "Missing CSV should fail.")

	var file := FileAccess.open("res://starting_cards.csv", FileAccess.READ)
	var valid := file.get_as_text()
	file.close()
	var cases := [
		["header", valid.replace("type,owner,zone", "name,owner,zone")],
		["unknown type", valid.replace("elephant,enemy", "unknown,enemy")],
		["wrong owner", valid.replace("axe,player,hand", "axe,enemy,hand")],
		["duplicate cell", valid.replace("elephant,enemy,board,0,1", "elephant,enemy,board,0,0")],
		["wrong side", valid.replace("elephant,enemy,board,0,0", "elephant,enemy,board,2,0")],
		["wrong zone", valid.replace("axe,player,hand,,,", "axe,player,board,2,0,")],
		["inconsistent player hp", valid + "axe,player,hand,,,5,res://assets/x1/action_cards/attack/cleave.png,,\n"],
		["inconsistent image", valid.replace("elephant,enemy,board,0,0,10,res://assets/x1/action_cards/defense/block.png", "elephant,enemy,board,0,0,10,res://assets/x1/action_cards/attack/cleave.png")],
		["invalid hp", valid.replace("elephant,enemy,board,0,0,10", "elephant,enemy,board,0,0,0")],
		["bad image", valid.replace("res://assets/x1/action_cards/defense/block.png", "res://missing.png")],
		["dimensions", valid.replace(",,,,,,,4,4", ",,,,,,,5,4")],
		["missing board configuration", valid.replace(",,,,,,,4,4\n", "")],
		["duplicate board configuration", valid + ",,,,,,,4,4\n"],
		["dimensions on card", valid.replace("block.png,,", "block.png,4,4")],
		["malformed quote", valid.replace("elephant,enemy,board,0,0", "\"elephant,enemy,board,0,0")]
	]
	var test_path := "user://starting-cards-test-%d-%d.csv" % [OS.get_process_id(), Time.get_ticks_usec()]
	if FileAccess.file_exists(test_path):
		_check(false, "Temporary CSV path unexpectedly exists.")
		return
	var quoted := FileAccess.open(test_path, FileAccess.WRITE)
	_check(quoted != null, "Could not create temporary CSV.")
	if quoted == null:
		return
	quoted.store_string(valid.replace("elephant,enemy,board", "\"elephant\",enemy,board"))
	quoted.close()
	_check(not StartingData.load_file(test_path).has("error"), "Quoted CSV fields should load.")
	for case in cases:
		var output := FileAccess.open(test_path, FileAccess.WRITE)
		_check(output != null, "Could not create temporary CSV.")
		if output == null:
			return
		output.store_string(case[1])
		output.close()
		var invalid := StartingData.load_file(test_path)
		_check(invalid.has("error") and not invalid.has("records"), "Invalid %s should fail without partial records." % case[0])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
