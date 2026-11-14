@tool
extends RefCounted

const PATH := "res://data/text.cfg"

static var config: ConfigFile

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
