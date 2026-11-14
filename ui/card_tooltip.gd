extends PanelContainer

const CardData = preload("res://cards/card_data.gd")
const CardView = preload("res://cards/card.gd")
const Text = preload("res://data/text.gd")

const GAP := 8.0

var hovered_card: CardView
var bonus := 0

@onready var hover_timer: Timer = $HoverTimer
@onready var text_label: RichTextLabel = $Margin/Text

func set_hovered(card: CardView, damage_bonus: int) -> void:
	if hovered_card == card:
		if bonus != damage_bonus:
			bonus = damage_bonus
			refresh()
		return
	hover_timer.stop()
	hide()
	hovered_card = card
	bonus = damage_bonus
	if is_instance_valid(hovered_card):
		hover_timer.start()

func refresh() -> void:
	if is_node_ready() and visible and is_instance_valid(hovered_card):
		text_label.text = _description(hovered_card.data, bonus)
		size = Vector2.ZERO
		_position_tooltip()

func _on_hover_timer_timeout() -> void:
	if not is_instance_valid(hovered_card) or hovered_card.is_queued_for_deletion():
		set_hovered(null, 0)
		return
	text_label.text = _description(hovered_card.data, bonus)
	size = Vector2.ZERO
	_position_tooltip()
	show()

func _process(_delta: float) -> void:
	if hovered_card != null and (not is_instance_valid(hovered_card) or hovered_card.is_queued_for_deletion()):
		set_hovered(null, 0)
	elif visible:
		_position_tooltip()

func _position_tooltip() -> void:
	var sprite := hovered_card.sprite
	var rect := sprite.get_rect()
	var transform := sprite.get_global_transform_with_canvas()
	var corners := [
		transform * rect.position,
		transform * Vector2(rect.end.x, rect.position.y),
		transform * rect.end,
		transform * Vector2(rect.position.x, rect.end.y)
	]
	var left: float = corners[0].x
	var right: float = left
	var top: float = corners[0].y
	var bottom: float = top
	for corner in corners:
		left = minf(left, corner.x)
		right = maxf(right, corner.x)
		top = minf(top, corner.y)
		bottom = maxf(bottom, corner.y)
	var viewport := get_viewport_rect()
	var x := left - size.x - GAP
	if x < viewport.position.x:
		x = right + GAP
	var desired := Vector2(x, (top + bottom - size.y) / 2.0)
	position = Vector2(
		clampf(desired.x, viewport.position.x, maxf(viewport.position.x, viewport.end.x - size.x)),
		clampf(desired.y, viewport.position.y, maxf(viewport.position.y, viewport.end.y - size.y))
	)

func _description(card: CardData, damage_bonus: int) -> String:
	var description := "[b]%s[/b]\n" % card.display_name()
	match card.type:
		CardData.Type.ELEPHANT:
			description += Text.get_text("tooltip_elephant") % _highlight(card.current_hp)
		CardData.Type.AXE:
			description += Text.get_text("tooltip_axe") % [
				_highlight(CardData.AXE_UPPER_DAMAGE + damage_bonus),
				_highlight(CardData.AXE_BOTTOM_DAMAGE + damage_bonus)
			]
		CardData.Type.SPEAR:
			description += Text.get_text("tooltip_spear") % [
				_highlight(CardData.SPEAR_UPPER_DAMAGE + damage_bonus),
				_highlight(CardData.SPEAR_BOTTOM_DAMAGE + damage_bonus)
			]
		CardData.Type.TRAP:
			description += Text.get_text("tooltip_trap") % _highlight(CardData.TRAP_DAMAGE + damage_bonus)
		CardData.Type.MAGIC:
			description += Text.get_text("tooltip_magic") % _highlight(CardData.MAGIC_BONUS)
	if damage_bonus > 0 and card.type in [CardData.Type.AXE, CardData.Type.SPEAR, CardData.Type.TRAP]:
		description += Text.get_text("tooltip_bonus") % _highlight(damage_bonus)
	return description

func _highlight(value: int) -> String:
	return "[color=#f0c66c]%d[/color]" % value
