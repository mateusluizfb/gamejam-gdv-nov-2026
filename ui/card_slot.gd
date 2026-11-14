extends PanelContainer

const Text = preload("res://data/text.gd")

@onready var card_image: TextureRect = $MarginContainer/Content/CardImage
@onready var card_name: Label = $MarginContainer/Content/CardName

func set_card(card_data: Dictionary) -> void:
	card_image.texture = card_data.get("image")
	card_name.text = str(card_data.get("name", Text.get_text("empty_card")))
