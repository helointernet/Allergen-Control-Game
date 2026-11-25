@tool
class_name Location
extends Resource

@export var location_id: String = ""
@export var bay_id: int = 0
@export var level: int = 0
@export var max_pallets: int = 1
@export var block_entry: bool = false
@export var lpn_occupants: Array[LicensePlate] = [] # A list of Licenses contained in this location

func is_full() -> bool:
	var size = lpn_occupants.size()
	if size >= max_pallets:
		return true
	return false

func get_contents() -> Array[LicensePlate]:
	return lpn_occupants
