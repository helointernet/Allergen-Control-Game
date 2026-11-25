@tool
extends Resource
class_name AllergenTable

@export var tags: Array[AllergenTag] = []

func get_tag(id: String) -> AllergenTag:
	for t in tags:
		if t.id == id:
			return t
	return null
