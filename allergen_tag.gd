@tool
extends Resource
class_name AllergenTag

enum Behavior { DRIP_DOWN, PURITY_UP }

@export var id: String            # "peanut", "organic"
@export var display_name: String  # "Peanut", "Organic"
@export var behavior: Behavior = Behavior.DRIP_DOWN
