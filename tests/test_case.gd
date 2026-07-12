extends RefCounted

var failures := 0


func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures += 1
		push_error("%s: expected %s, got %s" % [message, expected, actual])


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
