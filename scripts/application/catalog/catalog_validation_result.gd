class_name CatalogValidationResult
extends RefCounted

var _codes: Array[StringName] = []
var _messages: Array[String] = []


func add(code: StringName, message: String) -> void:
	_codes.append(code)
	_messages.append(message)


func is_valid() -> bool:
	return _codes.is_empty()


func codes() -> Array[StringName]:
	return _codes.duplicate()


func messages() -> Array[String]:
	return _messages.duplicate()
