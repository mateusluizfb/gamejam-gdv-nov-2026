@tool
extends RefCounted

const Text = preload("res://data/text.gd")

enum Type { ELEPHANT, MAGIC, AXE, SPEAR, TRAP }
enum Owner { PLAYER, ENEMY }

const AXE_UPPER_DAMAGE := 4
const AXE_BOTTOM_DAMAGE := 2
const SPEAR_UPPER_DAMAGE := 1
const SPEAR_BOTTOM_DAMAGE := 2
const TRAP_DAMAGE := 5
const MAGIC_BONUS := 2
const DISPLAY_NAMES := ["name_elephant", "name_magic", "name_axe", "name_spear", "name_trap"]

var type: Type
var owner: Owner
var base_hp: int
var current_hp: int
var image_path: String
var board_position: Variant = null

func _init(card_type: Type, card_owner: Owner, hp: int, image: String) -> void:
	type = card_type
	owner = card_owner
	base_hp = hp
	current_hp = hp
	image_path = image

func display_name() -> String:
	return Text.get_text(DISPLAY_NAMES[type])

func attack_damage(row: int, bonus: int = 0) -> int:
	match type:
		Type.AXE:
			return (AXE_BOTTOM_DAMAGE if row == 3 else AXE_UPPER_DAMAGE) + bonus
		Type.SPEAR:
			return (SPEAR_UPPER_DAMAGE if row != 3 and row != -1 else SPEAR_BOTTOM_DAMAGE) + bonus
		Type.TRAP:
			return TRAP_DAMAGE + bonus
	return 0
