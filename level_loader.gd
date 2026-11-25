extends Node

func load_level(def: LevelDefinition) -> void:
	if def == null:
		push_error("LevelLoader.load_level(): def is null")
		return

	# Model reset + master data registration
	WarehouseService.clear_all()
	WarehouseService.register_locations(def.build_locations())

	# Seed initial placements (still model setup)
	_apply_initial_placements(def)

func _apply_initial_placements(def: LevelDefinition) -> void:
	var n: int = min(def.initial_lpns.size(), def.initial_location_ids.size())
	for i in range(n):
		var lp := def.initial_lpns[i]
		var loc_id := def.initial_location_ids[i]
		if lp == null or loc_id == "":
			continue
		lp.initialize_from_item(true)
		WarehouseService.move_lpn(lp, loc_id)
