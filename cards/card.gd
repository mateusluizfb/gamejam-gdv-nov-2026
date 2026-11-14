extends Node2D

const CardData = preload("res://cards/card_data.gd")

var data: CardData
var damage_bonus := 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_label: Label = $HP
@onready var bonus_label: Label = $Bonus
@onready var bonus_background: ColorRect = $BonusBackground
@onready var name_label: Label = $CardName
@onready var category_label: Label = $Category

func _ready() -> void:
	if data != null:
		sprite.texture = load(data.image_path)
		refresh()

func refresh() -> void:
	if is_node_ready() and data != null:
		name_label.text = data.display_name()
		match data.type:
			CardData.Type.ELEPHANT:
				category_label.text = "INIMIGO"
			CardData.Type.MAGIC:
				category_label.text = "MAGIA"
			CardData.Type.TRAP:
				category_label.text = "ARMADILHA"
			_:
				category_label.text = "ATAQUE"
		hp_label.text = "PV: %d" % data.current_hp
		bonus_label.visible = damage_bonus > 0
		bonus_background.visible = damage_bonus > 0
		bonus_label.text = "+%d DANO" % damage_bonus
		var font_size := 13
		var font := bonus_label.get_theme_font("font")
		while font_size > 1 and font.get_string_size(bonus_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > bonus_background.size.x:
			font_size -= 1
		bonus_label.add_theme_font_size_override("font_size", font_size)
