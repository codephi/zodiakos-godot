class_name SeedMixer
extends RefCounted

const SectorCoordinateType = preload("res://scripts/domain/universe/sector_coordinate.gd")


static func mix(
	global_seed: int,
	coordinate: SectorCoordinateType,
	tag: String,
	first_index := -1,
	second_index := -1
) -> int:
	var input := "%d|%d|%d|%s|%d|%d" % [
		global_seed,
		coordinate.x,
		coordinate.y,
		tag,
		first_index,
		second_index,
	]
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(input.to_utf8_buffer())
	var digest := context.finish()
	var result := 0
	for index in range(7):
		result = (result << 8) | int(digest[index])
	return result
