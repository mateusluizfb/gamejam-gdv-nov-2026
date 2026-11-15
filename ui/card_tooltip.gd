extends PanelContainer

const CardData = preload("res://cards/card_data.gd")
const CardView = preload("res://cards/card.gd")
const Text = preload("res://data/text.gd")
const CARD_SCENE: PackedScene = preload("res://cards/card.tscn")
const SPAWN_SHADER: Shader = preload("res://ui/card_preview_spawn.gdshader")

const GAP := 8.0
const PREVIEW_SCALE := 2.0
const SPAWN_DURATION := 0.6
const VANISH_DURATION := 0.3

@export var preview_offset := Vector2(150, 100)

var hovered_card: CardView
var bonus := 0
var preview: CardView
var spawn_material: ShaderMaterial
var spawn_tween: Tween
var preview_disappearing := false

@onready var hover_timer: Timer = $HoverTimer
@onready var name_label: Label = $Margin/Sections/Name
@onready var text_label: RichTextLabel = $Margin/Sections/Text
@onready var bonus_label: RichTextLabel = $Margin/Sections/Bonus
@onready var manager: Node2D = $"../../CardManager"

func _ready() -> void:
	preview = CARD_SCENE.instantiate() as CardView
	preview.scale = Vector2.ONE * PREVIEW_SCALE
	preview.hide()
	for child in preview.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$"../CardPreview".add_child(preview)
	spawn_material = ShaderMaterial.new()
	spawn_material.shader = SPAWN_SHADER
	preview.sprite.material = spawn_material

func _exit_tree() -> void:
	if is_instance_valid(preview):
		preview.queue_free()

func set_hovered(card: CardView, damage_bonus: int) -> void:
	if hovered_card == card:
		if bonus != damage_bonus:
			bonus = damage_bonus
			refresh()
		return
	hover_timer.stop()
	_vanish_preview()
	hide()
	hovered_card = card
	bonus = damage_bonus
	if is_instance_valid(hovered_card):
		hover_timer.start()

func refresh() -> void:
	if is_node_ready() and visible and is_instance_valid(hovered_card):
		preview.data = hovered_card.data
		preview.sprite.texture = hovered_card.sprite.texture
		preview.damage_bonus = bonus
		preview.refresh()
		name_label.text = hovered_card.data.display_name()
		text_label.text = _effect_description(hovered_card.data, bonus)
		bonus_label.visible = bonus > 0 and hovered_card.data.type in [CardData.Type.AXE, CardData.Type.SPEAR, CardData.Type.TRAP]
		if bonus_label.visible:
			bonus_label.text = (Text.get_text("tooltip_bonus") % _highlight(bonus)).strip_edges()
		size = Vector2.ZERO
		_position_tooltip()

func _on_hover_timer_timeout() -> void:
	if not is_instance_valid(hovered_card) or hovered_card.is_queued_for_deletion():
		set_hovered(null, 0)
		return
	if spawn_tween != null and spawn_tween.is_running():
		spawn_tween.kill()
	preview_disappearing = false
	spawn_material.set_shader_parameter("spawn_progress", 0.0)
	for child in preview.get_children():
		if child is Control:
			child.modulate.a = 0.0
	preview.show()
	show()
	refresh()
	spawn_tween = create_tween().set_parallel(true)
	spawn_tween.tween_property(spawn_material, "shader_parameter/spawn_progress", 1.0, SPAWN_DURATION)
	for child in preview.get_children():
		if child is Control:
			spawn_tween.tween_property(child, "modulate:a", 1.0, SPAWN_DURATION)

func _vanish_preview() -> void:
	if not preview.visible or preview_disappearing:
		return
	if spawn_tween != null and spawn_tween.is_running():
		spawn_tween.kill()
	preview_disappearing = true
	spawn_tween = create_tween().set_parallel(true)
	spawn_tween.tween_property(spawn_material, "shader_parameter/spawn_progress", 0.0, VANISH_DURATION)
	for child in preview.get_children():
		if child is Control:
			spawn_tween.tween_property(child, "modulate:a", 0.0, VANISH_DURATION)
	spawn_tween.chain().tween_callback(preview.hide)

func _process(_delta: float) -> void:
	if hovered_card != null and (not is_instance_valid(hovered_card) or hovered_card.is_queued_for_deletion()):
		set_hovered(null, 0)
	elif visible:
		_position_tooltip()

func _position_tooltip() -> void:
	var board = manager.board
	var columns: int = board.cards[0].size()
	var board_top_right: Vector2 = board.cell_position(Vector2i(columns - 1, 0)) + Vector2(board.cell_size.x / 2.0, -board.cell_size.y / 2.0)
	var preview_size := preview.sprite.get_rect().size * preview.sprite.scale.abs() * PREVIEW_SCALE
	var desired: Vector2 = manager.get_global_transform_with_canvas() * board_top_right + preview_offset
	var viewport := get_viewport_rect()
	var top_left := Vector2(
		clampf(desired.x, viewport.position.x, maxf(viewport.position.x, viewport.end.x - maxf(size.x, preview_size.x))),
		clampf(desired.y, viewport.position.y, maxf(viewport.position.y, viewport.end.y - preview_size.y - GAP - size.y))
	)
	position = top_left + Vector2(0, preview_size.y + GAP)
	preview.position = position + Vector2(size.x / 2.0, -GAP - preview_size.y / 2.0)

func _effect_description(card: CardData, damage_bonus: int) -> String:
	var description := ""
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
	return description

func _highlight(value: int) -> String:
	return "[color=#f0c66c]%d[/color]" % value
