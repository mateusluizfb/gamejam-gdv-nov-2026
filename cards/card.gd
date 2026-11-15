extends Node2D

signal movement_updated

const CardData = preload("res://cards/card_data.gd")
const Text = preload("res://data/text.gd")
const FOIL_SHADER = preload("res://cards/card.gdshader")
const BONUS_COLOR := Color(0.13, 0.21, 0.45, 0.95)
const PENALTY_COLOR := Color(0.5, 0.12, 0.1, 0.95)
const ELEPHANT_DISPLAY_STRENGTH := 20
const INCREASED_ATTACK_COLOR := Color("#216538")
const REDUCED_ATTACK_COLOR := Color("#9d2828")

var data: CardData
var damage_bonus := 0
var movement_tween: Tween
var movement_target := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_label: Label = $HP
@onready var attack_label: Label = $Attack
@onready var bonus_label: Label = $Bonus
@onready var bonus_background: ColorRect = $BonusBackground

func _ready() -> void:
	if data != null:
		sprite.texture = load(data.image_path)
		var foil_material := ShaderMaterial.new()
		foil_material.shader = FOIL_SHADER
		foil_material.set_shader_parameter("foil_strength", 0.0)
		sprite.material = foil_material
		refresh()

func set_foil_hover(active: bool, mouse_position: Vector2 = Vector2.ZERO) -> void:
	var material := sprite.material as ShaderMaterial
	material.set_shader_parameter("foil_strength", 1.0 if active else 0.0)
	if active:
		var local_mouse := sprite.get_global_transform_with_canvas().affine_inverse() * mouse_position
		var rect := sprite.get_rect()
		material.set_shader_parameter("cursor_uv", (local_mouse - rect.position) / rect.size)

func move_to(target: Vector2) -> void:
	if movement_tween != null and movement_tween.is_running() and movement_target.is_equal_approx(target):
		return
	stop_moving()
	movement_target = target
	if position.is_equal_approx(target):
		return
	movement_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	movement_tween.tween_method(_set_movement_position, position, target, 0.25)

func _set_movement_position(value: Vector2) -> void:
	position = value
	movement_updated.emit()

func stop_moving() -> void:
	if movement_tween != null and movement_tween.is_running():
		movement_tween.kill()
	movement_tween = null

func refresh() -> void:
	if is_node_ready() and data != null:
		_refresh_stats()
		var penalty := _row_penalty()
		bonus_label.visible = damage_bonus > 0 or penalty > 0
		bonus_background.visible = bonus_label.visible
		bonus_background.color = PENALTY_COLOR if penalty > 0 else BONUS_COLOR
		bonus_label.text = Text.get_text("card_damage_penalty") % penalty if penalty > 0 else Text.get_text("card_damage_bonus") % damage_bonus
		var font_size := 13
		var font := bonus_label.get_theme_font("font")
		while font_size > 1 and font.get_string_size(bonus_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > bonus_background.size.x:
			font_size -= 1
		bonus_label.add_theme_font_size_override("font_size", font_size)

func _refresh_stats() -> void:
	# The artwork uses the same hexagon positions even when the texture has transparent padding.
	var art_origin := sprite.get_rect().position
	hp_label.position = (art_origin + Vector2(65.2, 10.0)) * sprite.scale - hp_label.size * 0.5
	attack_label.position = (art_origin + Vector2(65.2, 97.2)) * sprite.scale - attack_label.size * 0.5
	hp_label.text = str(data.current_hp)
	var row: int = data.board_position.y if data.board_position != null else -1
	var natural_strength := ELEPHANT_DISPLAY_STRENGTH if data.type == CardData.Type.ELEPHANT else data.attack_damage(-1)
	var strength := ELEPHANT_DISPLAY_STRENGTH if data.type == CardData.Type.ELEPHANT else data.attack_damage(row, damage_bonus)
	var strength_color := Color.BLACK
	if strength > natural_strength:
		strength_color = INCREASED_ATTACK_COLOR
	elif strength < natural_strength:
		strength_color = REDUCED_ATTACK_COLOR
	attack_label.text = str(strength)
	attack_label.add_theme_color_override("font_color", strength_color)

func _row_penalty() -> int:
	if data.board_position == null:
		return 0
	var cell: Vector2i = data.board_position
	if data.type == CardData.Type.AXE and cell.y == 3:
		return CardData.AXE_UPPER_DAMAGE - CardData.AXE_BOTTOM_DAMAGE
	if data.type == CardData.Type.SPEAR and cell.y == 2:
		return CardData.SPEAR_BOTTOM_DAMAGE - CardData.SPEAR_UPPER_DAMAGE
	return 0
