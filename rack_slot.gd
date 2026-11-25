class_name RackSlot
extends PanelContainer

@export var location_id: String = ""
@export var max_pallets: int = 1

var x: int = 0
var y: int = 0
var board: Node = null

# injected from Main after instantiation
var pallet_registry: Node = null

@onready var anchor: Control = $CenterContainer


func _ready() -> void:
	WarehouseService.location_occupancy_changed.connect(_on_location_occupancy_changed)
	_sync_from_service()


func _on_location_occupancy_changed(changed_location_id: String, _previous: Array, _current: Array) -> void:
	if changed_location_id != location_id:
		return
	_sync_from_service()


func _sync_from_service() -> void:
	if location_id == "":
		return

	var occupants := WarehouseService.get_occupants(location_id)

	# Empty slot: park whatever view was here
	if occupants.is_empty():
		if anchor.get_child_count() > 0:
			var child := anchor.get_child(0) as Pallet
			if child != null and child.license != null and pallet_registry != null:
				pallet_registry.park_view(child.license)
			else:
				# fallback: detach it (shouldn't happen often once registry is in use)
				anchor.remove_child(anchor.get_child(0))
		return

	# For now: 1 pallet displayed per slot
	var lp := occupants[0] as LicensePlate
	if lp == null:
		return
	if pallet_registry == null:
		push_warning("RackSlot has no pallet_registry assigned.")
		return

	var pallet_view := pallet_registry.get_or_create_view(lp) as Pallet
	if pallet_view == null:
		return

	if pallet_view.get_parent() != anchor:
		pallet_view.reparent(anchor)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if data.get("type", "") != "pallet":
		return false

	var lp := data.get("license", null) as LicensePlate
	if lp == null:
		return false

	return WarehouseService.can_place_lpn(lp, location_id)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var lp := data.get("license", null) as LicensePlate
	if lp == null:
		return

	WarehouseService.move_lpn(lp, location_id)
