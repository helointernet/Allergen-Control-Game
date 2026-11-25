# res://pallet_view_registry.gd
extends Node

@export var pallet_scene: PackedScene
@export var pool_path: NodePath

# key = instance_id(LicensePlate) -> Pallet view
var _lp_to_view: Dictionary = {}


func _pool() -> Node:
	if pool_path == NodePath():
		return self
	var n := get_node_or_null(pool_path)
	return n if n != null else self


func get_view(lp: LicensePlate) -> Pallet:
	if lp == null:
		return null
	return _lp_to_view.get(lp.get_instance_id(), null)


func get_or_create_view(lp: LicensePlate) -> Pallet:
	if lp == null:
		return null

	var key := lp.get_instance_id()

	# Return existing (if still valid)
	if _lp_to_view.has(key):
		var existing := _lp_to_view[key] as Pallet
		if existing != null and is_instance_valid(existing):
			return existing
		_lp_to_view.erase(key)

	# Create new
	if pallet_scene == null:
		push_error("PalletViewRegistry: pallet_scene not set.")
		return null

	var p := pallet_scene.instantiate() as Pallet
	if p == null:
		push_error("PalletViewRegistry: pallet_scene didn't instantiate a Pallet.")
		return null

	p.license = lp
	_pool().add_child(p)
	_lp_to_view[key] = p
	return p


func park_view(lp: LicensePlate) -> void:
	var p := get_view(lp)
	if p == null:
		return
	if p.get_parent() != _pool():
		p.reparent(_pool())
