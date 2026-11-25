class_name LevelDefinition
extends Resource

@export var rack_width: int = 3
@export var rack_height: int = 4
@export var max_pallets_per_slot: int = 1

# Starting placements: lpns[i] starts at location_ids[i]
@export var initial_lpns: Array[LicensePlate] = []
@export var initial_location_ids: Array[String] = []


func make_location_id(bay_id: int, level: int) -> String:
	return "%02d-%02d" % [bay_id, level]


func build_locations() -> Array[Location]:
	var out: Array[Location] = []
	for yy in range(rack_height):
		for xx in range(rack_width):
			var loc := Location.new()
			loc.bay_id = xx + 1
			loc.level = yy + 1
			loc.location_id = make_location_id(loc.bay_id, loc.level)
			loc.max_pallets = max_pallets_per_slot
			out.append(loc)
	return out
