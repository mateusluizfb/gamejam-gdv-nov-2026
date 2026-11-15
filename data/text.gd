@tool
extends RefCounted

const PATH := "res://data/text.cfg"

static var config: ConfigFile

static func set_story_italics(label: RichTextLabel) -> void:
	var italics := FontVariation.new()
	italics.base_font = label.get_theme_default_font()
	italics.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.25, 1.0), Vector2.ZERO)
	label.add_theme_font_override("italics_font", italics)

static func get_text(key: String) -> String:
	if config == null:
		config = ConfigFile.new()
		var error := config.load(PATH)
		if error != OK:
			push_error("Cannot load user-facing text from %s (error %s)." % [PATH, error])
	if not config.has_section_key("text", key):
		push_error("Missing user-facing text key: %s" % key)
		return key
	var value: Variant = config.get_value("text", key)
	if not value is String:
		push_error("User-facing text key is not a string: %s" % key)
		return key
	return value
