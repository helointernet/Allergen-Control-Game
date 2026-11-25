@tool
class_name ItemDefinition
extends Resource

@export var icon_texture: Texture2D
@export var part_number: String = ""
@export var display_name: String = ""
@export var default_allergen_modifiers: Array[String] = []

func is_packaging() -> bool:
	var family_code = int(part_number.substr(0, 3))
	return family_code >= 200 and family_code < 300
