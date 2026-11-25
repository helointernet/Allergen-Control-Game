class_name Board
extends Control

@export var level: LevelDefinition
@export var rack_slot_scene: PackedScene

@onready var grid: GridContainer = $Rack
@onready var pallet_registry := $PalletViewRegistry


var slots: Array = []  # slots[x][y] = RackSlot

func _ready() -> void:
	if level == null:
		push_error("Main: 'level' not set.")
		return

	grid.columns = level.rack_width
	_build_rack_from_level()
	_seed_level_from_definition()

func _build_rack_from_level() -> void:
	slots.clear()

	for xx in range(level.rack_width):
		slots.append([])
		for yy in range(level.rack_height):
			slots[xx].append(null)

	# Register all locations first (warehouse master data)
	for loc in level.build_locations():
		WarehouseService.register_location(loc)

	# Build UI slots and assign location_ids from the same scheme
	for yy in range(level.rack_height):
		for xx in range(level.rack_width):
			var slot := rack_slot_scene.instantiate() as RackSlot
			slot.board = self
			slot.pallet_registry = pallet_registry
			slot.x = xx
			slot.y = yy
			slot.max_pallets = level.max_pallets_per_slot

			var bay_id := xx + 1
			var lvl := yy + 1
			slot.location_id = level.make_location_id(bay_id, lvl)

			grid.add_child(slot)
			slots[xx][yy] = slot

func get_slot(xx: int, yy: int) -> RackSlot:
	if xx < 0 or xx >= level.rack_width: return null
	if yy < 0 or yy >= level.rack_height: return null
	return slots[xx][yy]

func _seed_level_from_definition() -> void:
	var n: int = min(level.initial_lpns.size(), level.initial_location_ids.size())
	for i in range(n):
		var lp := level.initial_lpns[i]
		var loc_id := level.initial_location_ids[i]
		if lp == null or loc_id == "":
			continue
		lp.initialize_from_item(true)
		WarehouseService.move_lpn(lp, loc_id)
