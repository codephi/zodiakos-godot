class_name VisualPalette
extends RefCounted

const NEUTRAL_OWNER := Color(0.5, 0.5, 0.5, 1.0)

const SHIPS := {
	&"expedition": {"color": Color("42d9ff"), "scale": 0.7},
	&"colony": {"color": Color("ffb43c"), "scale": 1.0},
	&"war": {"color": Color("ef4b4b"), "scale": 1.3},
}

const STARS := {
	&"blue": {"color": Color("b9ddff"), "scale": 1.3},
	&"white": {"color": Color.WHITE, "scale": 1.1},
	&"yellow": {"color": Color("ffe58a"), "scale": 1.0},
	&"orange": {"color": Color("ff9b45"), "scale": 0.9},
	&"red": {"color": Color("ff6b60"), "scale": 0.8},
}

const PLANETS := {
	&"rocky": {"color": Color("8f8175")},
	&"gas": {"color": Color("a67ad1")},
	&"ice": {"color": Color("8ed8ef")},
	&"volcanic": {"color": Color("db6a32")},
}


static func ship_style(ship_class: StringName) -> Dictionary:
	return SHIPS.get(ship_class, SHIPS[&"expedition"]).duplicate()


static func star_style(star_type: StringName) -> Dictionary:
	return STARS.get(star_type, STARS[&"yellow"]).duplicate()


static func planet_style(planet_type: StringName) -> Dictionary:
	return PLANETS.get(planet_type, PLANETS[&"rocky"]).duplicate()


static func normalize_owner_color(color: Color) -> Color:
	return NEUTRAL_OWNER if color.a <= 0.0 else color
