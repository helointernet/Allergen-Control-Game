@tool
class_name LicensePlate
extends Resource

@export var part: ItemDefinition:
	set(value):
		part = value
		initialize_from_item(false)
@export var pallet_id: String = ""
@export var allergen_modifiers: Array[String] = []
@export var is_packaging: bool = false

func initialize_from_item(force: bool = false) -> void:
	# If we've already got allergens (e.g., returned-from-line contamination), don't overwrite them
	if not force and allergen_modifiers != null and allergen_modifiers.size() > 0:
		return

	allergen_modifiers = []

	if part == null:
		return

	# Copy defaults into the license plate list (so we can modify per-LP later)
	if part.default_allergen_modifiers != null:
		for a in part.default_allergen_modifiers:
			allergen_modifiers.append(a)
	
	is_packaging = part.is_packaging()
	
	emit_changed()

func get_allergens() -> Array[String]:
	# Prefer the per-license-plate list (modifiable later)
	if allergen_modifiers != null and allergen_modifiers.size() > 0:
		return allergen_modifiers

	# Fallback (if not initialized or intentionally empty)
	if part != null and part.default_allergen_modifiers != null:
		return part.default_allergen_modifiers

	return []

func get_packaging() -> bool:
	return is_packaging
