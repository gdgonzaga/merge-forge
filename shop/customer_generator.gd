extends RefCounted

var _customers: Array = []


func generate_customers() -> Array[Dictionary]:
	if _customers.is_empty():
		_load()
	var result: Array[Dictionary] = []
	result.assign(_customers.duplicate(true))
	return result


func _load() -> void:
	var path := "res://data/customers.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data = json.data
	if data is Dictionary and data.has("customers"):
		_customers = data["customers"]
