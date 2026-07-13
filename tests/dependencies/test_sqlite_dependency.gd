extends "res://tests/test_case.gd"


func run() -> void:
	assert_true(ClassDB.class_exists(&"SQLite"), "SQLite GDExtension is registered")
