class_name VisualPalette
extends RefCounted

const DefaultSettings = preload("res://config/game_settings.tres")


static func ship_style(ship_class: StringName, settings = DefaultSettings) -> Dictionary:
	return settings.ship_styles.get(
		ship_class,
		settings.ship_styles[&"expedition"]
	).duplicate()


static func star_style(star_type: StringName, settings = DefaultSettings) -> Dictionary:
	return settings.star_styles.get(
		star_type,
		settings.star_styles[&"yellow"]
	).duplicate()


static func planet_style(planet_type: StringName, settings = DefaultSettings) -> Dictionary:
	return settings.planet_styles.get(
		planet_type,
		settings.planet_styles[&"rocky"]
	).duplicate()


static func normalize_owner_color(color: Color, settings = DefaultSettings) -> Color:
	return settings.neutral_owner_color if color.a <= 0.0 else color
