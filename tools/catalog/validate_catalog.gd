extends SceneTree

const Repository = preload(
	"res://scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd"
)
const Validator = preload("res://scripts/application/catalog/catalog_validator.gd")


func _initialize() -> void:
	var repository = Repository.new()
	if not repository.open():
		repository.close()
		push_error("CATALOG_NOT_OPEN")
		quit(1)
		return

	var result = Validator.new().validate(repository)
	repository.close()
	if not result.is_valid():
		push_error("CATALOG_INVALID: %s" % "; ".join(result.messages()))
		quit(1)
		return

	print("CATALOG VALID")
	print("TESTS PASSED")
	quit(0)
