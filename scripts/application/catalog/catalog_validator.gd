class_name CatalogValidator
extends RefCounted

const Result = preload("res://scripts/application/catalog/catalog_validation_result.gd")
const Repository = preload("res://scripts/application/ports/scientific_catalog_repository.gd")
const SUPPORTED_SCHEMA_VERSION := 1


func validate(repository: Repository) -> Result:
	var result = Result.new()
	var technical_findings: Array[Dictionary] = repository.technical_validation_errors()
	for finding: Dictionary in technical_findings:
		result.add(StringName(finding.get("code", &"SQLITE_QUERY")), String(finding.get("message", "")))

	var finding_codes: Array[StringName] = result.codes()
	if finding_codes.has(&"CATALOG_NOT_OPEN"):
		return result
	if finding_codes.has(&"SQLITE_INTEGRITY") or finding_codes.has(&"SQLITE_QUERY"):
		return result

	var catalog_metadata = repository.metadata()
	if catalog_metadata == null:
		if not finding_codes.has(&"METADATA_COUNT"):
			result.add(&"METADATA_COUNT", "Catalog must contain exactly one metadata row")
		return result

	if catalog_metadata.schema_version != SUPPORTED_SCHEMA_VERSION:
		result.add(
			&"SCHEMA_UNSUPPORTED",
			"Catalog schema version %d is unsupported" % catalog_metadata.schema_version
		)
	return result
