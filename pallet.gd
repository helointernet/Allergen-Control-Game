@tool
class_name Pallet
extends Control

@export var license: LicensePlate:
	set(value):
		license = value
		_apply_item()

@onready var icon: TextureRect = $Icon


func get_license_allergens() -> Array[String]:
	return license.get_allergens() if license != null else []


func get_item() -> ItemDefinition:
	return license.part if license != null else null


func _ready() -> void:
	_apply_item()


func _apply_item() -> void:
	if not is_inside_tree():
		return
	if icon == null:
		return

	var item := license.part if license != null else null
	if item != null:
		icon.texture = item.icon_texture
		tooltip_text = item.display_name
	else:
		icon.texture = null
		tooltip_text = ""


func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := duplicate()
	preview.modulate.a = 0.8
	set_drag_preview(preview)

	# IMPORTANT: No UI node references in the payload.
	return {
		"type": "pallet",
		"license": license
	}
