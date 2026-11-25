extends Node

signal location_occupancy_changed(location_id: String, previous: Array, current: Array)
signal lpn_moved(lpn: LicensePlate, from_location_id: String, to_location_id: String)

# location_id -> Location (Resource)
var _locations: Dictionary = {}

# instance_id(LicensePlate) -> location_id
var _lpn_to_location: Dictionary = {}

@export var allow_auto_create_locations: bool = false
@export var allergen_table: AllergenTable = preload("res://resources/data/allergen_table.tres")

enum AllergenReject {
	OK,
	UNKNOWN_TAG,
	PACKAGING_UNDER_INGREDIENT,
	DRIP_DOWN_MISMATCH,
	PURITY_UP_MISMATCH,
}

func clear_all() -> void:
	_locations.clear()
	_lpn_to_location.clear()

func register_location(loc: Location) -> void:
	if loc == null:
		return
	if loc.location_id == "":
		push_warning("register_location(): location_id is empty.")
		return
	_locations[loc.location_id] = loc

func register_locations(locations: Array[Location]) -> void:
	for loc in locations:
		register_location(loc)

func ensure_location(location_id: String, max_pallets: int = 1) -> Location:
	if _locations.has(location_id):
		return _locations[location_id]

	var loc := Location.new()
	loc.location_id = location_id
	loc.max_pallets = max_pallets
	_locations[location_id] = loc
	return loc


func get_location(location_id: String) -> Location:
	return _locations.get(location_id, null)


func get_location_id_for_lpn(lpn: LicensePlate) -> String:
	if lpn == null:
		return ""
	return _lpn_to_location.get(lpn.get_instance_id(), "")


func _is_ingredient(entry: Variant) -> bool:
	# entry is null OR { license, allergens, is_packaging }
	if entry == null:
		return false
	return not bool(entry.get("is_packaging", false))


func get_occupants(location_id: String) -> Array[LicensePlate]:
	var loc := get_location(location_id)
	if loc == null:
		return []
	return loc.lpn_occupants
	

func _entry_has_tag(entry: Variant, tag_id: String) -> bool:
	if entry == null:
		return false
	var arr: Array = entry.get("allergens", [])
	return arr.has(tag_id)
	
	
func get_locations_in_bay(bay_id: int) -> Array[Location]:
	var out: Array[Location] = []
	for loc in _locations.values():
		var l := loc as Location
		if l != null and l.bay_id == bay_id:
			out.append(l)

	out.sort_custom(func(a: Location, b: Location) -> bool:
		return a.level < b.level
	)

	return out


func can_place_lpn(lpn: LicensePlate, to_location_id: String) -> bool:
	if lpn == null:
		return false

	var loc := get_location(to_location_id)
	if loc == null:
		if allow_auto_create_locations:
			loc = ensure_location(to_location_id, 1)
		else:
			return false

	if loc.block_entry:
		return false
	if loc.is_full():
		return false
	
	# --- Allergen validation (pure business logic) ---
	var from_location_id := get_location_id_for_lpn(lpn)
	var from_loc: Location = null
	if from_location_id != "":
		from_loc = get_location(from_location_id)

	# Validate destination bay with hypothetical placement
	var snap_to := build_bay_snapshot(loc.bay_id, lpn, to_location_id)
	var res_to := validate_bay_snapshot(snap_to)
	if not bool(res_to.get("ok", false)):
		print("REJECT (to bay) ", res_to)
		return false

	return true


func move_lpn(lpn: LicensePlate, to_location_id: String) -> Dictionary:
	if lpn == null:
		return {"ok": false, "error": "NULL_LPN"}

	var to_loc := get_location(to_location_id)
	if to_loc == null:
		if allow_auto_create_locations:
			to_loc = ensure_location(to_location_id, 1)
		else:
			return {"ok": false, "error": "UNKNOWN_DESTINATION_LOCATION", "to": to_location_id}

	if not can_place_lpn(lpn, to_location_id):
		return {"ok": false, "error": "DESTINATION_NOT_ALLOWED", "to": to_location_id}

	var from_location_id := get_location_id_for_lpn(lpn)
	var from_loc: Location = null
	if from_location_id != "":
		from_loc = get_location(from_location_id)

	# Snapshots for signals
	var prev_from: Array = []
	var prev_to: Array = to_loc.lpn_occupants.duplicate()

	if from_loc != null:
		prev_from = from_loc.lpn_occupants.duplicate()

	# Remove from source
	if from_loc != null:
		from_loc.lpn_occupants.erase(lpn)
		from_loc.emit_changed()
		_lpn_to_location.erase(lpn.get_instance_id())

	# Add to destination (avoid duplicates)
	if not to_loc.lpn_occupants.has(lpn):
		to_loc.lpn_occupants.append(lpn)
	to_loc.emit_changed()
	_lpn_to_location[lpn.get_instance_id()] = to_location_id

	# Notify listeners (UI)
	if from_loc != null:
		location_occupancy_changed.emit(from_location_id, prev_from, from_loc.lpn_occupants.duplicate())
	location_occupancy_changed.emit(to_location_id, prev_to, to_loc.lpn_occupants.duplicate())
	lpn_moved.emit(lpn, from_location_id, to_location_id)

	print("MOVE ", lpn.pallet_id, " ", from_location_id, " -> ", to_location_id)
	return {"ok": true, "from": from_location_id, "to": to_location_id}

func build_bay_snapshot(
	bay_id: int,
	moving_lpn: LicensePlate = null,
	target_location_id: String = ""
) -> Array:
	var col := get_locations_in_bay(bay_id)

	var from_location_id := ""
	if moving_lpn != null:
		from_location_id = get_location_id_for_lpn(moving_lpn)

	var out: Array = []
	for loc in col:
		var lp: LicensePlate = null
		if not loc.lpn_occupants.is_empty():
			lp = loc.lpn_occupants[0] as LicensePlate

		# Hypothetical remove from source
		if moving_lpn != null and loc.location_id == from_location_id and lp == moving_lpn:
			lp = null

		# Hypothetical place into target
		if moving_lpn != null and target_location_id != "" and loc.location_id == target_location_id:
			lp = moving_lpn

		if lp == null:
			out.append(null)
		else:
			#print("SNAP LP=", lp.pallet_id, " allergens=", lp.get_allergens())
			out.append({
				"license": lp,
				"allergens": lp.get_allergens(),
				"is_packaging": lp.get_packaging()
			})

	return out


func validate_bay_snapshot(snapshot: Array) -> Dictionary:
	# snapshot indices: 0 = top, last = bottom
	# Returns: { ok: bool, code: AllergenReject, ...details... }

	if allergen_table == null:
		# If you ever hit this, loading the .tres failed.
		return {"ok": false, "code": AllergenReject.UNKNOWN_TAG, "error": "MISSING_ALLERGEN_TABLE"}

	# Build sets of tags by behavior from the table.
	var drip_tags: Array[String] = []
	var purity_tags: Array[String] = []

	for t in allergen_table.tags:
		if t == null:
			continue
		match t.behavior:
			AllergenTag.Behavior.DRIP_DOWN:
				drip_tags.append(t.id)
			AllergenTag.Behavior.PURITY_UP:
				purity_tags.append(t.id)

	# 1) Packaging rule:
	# Packaging cannot be BELOW any ingredient.
	# So: if we see packaging at i, and any ingredient exists above i => reject.
	var seen_ingredient_above := false
	for i in range(snapshot.size()):
		var e = snapshot[i]
		if _is_ingredient(e):
			seen_ingredient_above = true
		if e != null and bool(e.get("is_packaging", false)):
			if seen_ingredient_above:
				return {
					"ok": false,
					"code": AllergenReject.PACKAGING_UNDER_INGREDIENT,
					"at_index": i,
				}

	# 2) DRIP_DOWN rule:
	# Any DRIP_DOWN allergen present above must also be present in every ingredient below it.
	# (Packaging doesn’t “block” drips; it just can’t be below ingredients anyway.)
	var active_drip: Array[String] = []
	for i in range(snapshot.size()):
		var e = snapshot[i]

		# Empty or packaging: skip checking (nothing to contaminate here)
		if e == null or not _is_ingredient(e):
			continue

		# Check this ingredient contains all active drip tags
		for a in active_drip:
			if not _entry_has_tag(e, a):
				return {
					"ok": false,
					"code": AllergenReject.DRIP_DOWN_MISMATCH,
					"tag": a,
					"at_index": i,
				}

		# Add this ingredient's drip tags to the active set
		for a in drip_tags:
			if _entry_has_tag(e, a) and not active_drip.has(a):
				active_drip.append(a)

	# 3) PURITY_UP rule:
	# Once a non-packaging ingredient WITHOUT purity tag P exists above,
	# no ingredient below may have P.
	var purity_allowed: Dictionary = {}
	for p in purity_tags:
		purity_allowed[p] = true

	for i in range(snapshot.size()):
		var e = snapshot[i]
		if e == null or not _is_ingredient(e):
			continue

		# If this ingredient HAS a purity tag, it must still be "allowed"
		for p in purity_tags:
			if _entry_has_tag(e, p) and not bool(purity_allowed[p]):
				return {
					"ok": false,
					"code": AllergenReject.PURITY_UP_MISMATCH,
					"tag": p,
					"at_index": i,
				}

		# Any purity tag missing here becomes disallowed for below pallets
		for p in purity_tags:
			if not _entry_has_tag(e, p):
				purity_allowed[p] = false

	return {"ok": true, "code": AllergenReject.OK}
